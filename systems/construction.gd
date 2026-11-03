class_name Construction
extends Node3D
## Mode construction : aperçu fantôme, accrochage à une grille de 1 m,
## validation des ressources, pose et sauvegarde des éléments construits.
##
## Les éléments sont des enfants de ce nœud, ce qui rend le nettoyage et la
## sauvegarde triviaux (une seule liste à parcourir).

const REACH := 8.0
const WORLD_MASK := 1 | 8  # terrain/props + objets construits

var active := false

var _player: Player
var _hud: Hud
var _camera: Camera3D

var _catalog: Array[BuildableData] = []
var _selected := 0
var _rotation_steps := 0

var _ghost: Buildable
var _valid := false

var _occupied: Dictionary = {}
var _objects: Array[Buildable] = []

## Pas de niveau de construction : 1 niveau = LEVEL_STEP (0.2 m, = 1 fondation).
const LEVEL_STEP := 0.2
var _build_level := 0
var _level_locked := false
var _locked_y := 0.0
var _ghost_y := 0.0


func setup(player: Player, hud: Hud) -> void:
	_player = player
	_hud = hud
	_camera = player.get_node("Head/Camera3D")

	_catalog.clear()
	var ids := Database.buildables.keys()
	ids.sort()
	for id in ids:
		_catalog.append(Database.buildables[id])


func toggle() -> void:
	set_active(not active)


## Active ou désactive le mode construction. Idempotent : contrairement à
## toggle(), un appel redondant ne peut pas réactiver la construction (par
## exemple après une mort, quand main.gd ferme déjà le mode).
func set_active(value: bool) -> void:
	if active == value:
		return
	active = value
	if active:
		_ensure_ghost()
		_update_build_info()
	else:
		if _ghost != null:
			_ghost.visible = false
		if _hud != null:
			_hud.set_build_info("")
		_level_locked = false
		_build_level = 0
	GameState.notify("Mode construction %s" % ("activé" if active else "désactivé"))


func is_active() -> bool:
	return active


func _process(_delta: float) -> void:
	# Le mode construction se fige si le jeu est en pause ou le joueur mort :
	# sans ce garde-fou, on pouvait poser des bâtiments via la souris pendant
	# les menus (process_mode permet à cette boucle de tourner en pause).
	if not active or _ghost == null or GameState.is_dead or get_tree().paused:
		return

	var hit := _raycast()
	if hit.is_empty():
		_valid = false
		_ghost.visible = false
		return

	var position: Vector3 = hit["position"]
	var cell := Vector2i(floori(position.x), floori(position.z))
	var ghost_y := _compute_ghost_y(position.y, cell, _ghost.kind)
	_ghost.visible = true
	_ghost.global_position = Vector3(cell.x + 0.5, ghost_y, cell.y + 0.5)
	_ghost.rotation.y = _rotation_steps * PI * 0.5
	_ghost_y = ghost_y
	_valid = _placement_ok(hit, cell, ghost_y)
	_ghost.set_ghost_valid(_valid)


func _unhandled_input(event: InputEvent) -> void:
	if not active or GameState.is_dead or get_tree().paused:
		return

	if event.is_action_pressed("rotate_build"):
		_rotation_steps = (_rotation_steps + 1) % 4
		return

	if event.is_action_pressed("build_level_up"):
		_change_level(1)
		return
	if event.is_action_pressed("build_level_down"):
		_change_level(-1)
		return
	if event.is_action_pressed("build_level_lock"):
		_toggle_level_lock()
		return

	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_cycle(1)
			MOUSE_BUTTON_WHEEL_DOWN:
				_cycle(-1)
			MOUSE_BUTTON_LEFT:
				_place()


# --- Sélection / pose --------------------------------------------------------

func _selected_data() -> BuildableData:
	if _catalog.is_empty():
		return null
	return _catalog[_selected]


func _cycle(direction: int) -> void:
	if _catalog.is_empty():
		return
	_selected = wrapi(_selected + direction, 0, _catalog.size())
	_rotation_steps = 0
	_ensure_ghost()
	_update_build_info()


func _can_place(cell: Vector2i, level: int = 0, rotation: int = 0) -> bool:
	var data := _selected_data()
	if data == null:
		return false
	if not GameState.has_items(data.costs):
		return false
	return not _occupied.has(_cell_key(data.kind, cell, level, rotation))


## Valide la pose fantôme : on refuse les supports inexploitables (ressource
## récoltable, surface trop verticale, niveau sous l'eau) avant de tester la
## disponibilité de la cellule.
func _placement_ok(hit: Dictionary, cell: Vector2i, ghost_y: float) -> bool:
	if hit.is_empty():
		return false
	var collider: Node = hit["collider"]
	if collider is Harvestable:
		return false
	if ghost_y < Island.SEA_LEVEL + 0.3:
		return false
	if collider is Buildable:
		return _can_place(cell, int(round(ghost_y / LEVEL_STEP)), _rotation_steps)
	var normal: Vector3 = hit["normal"]
	if normal.y < 0.8:
		return false
	return _can_place(cell, int(round(ghost_y / LEVEL_STEP)), _rotation_steps)


func _place() -> void:
	var data := _selected_data()
	if data == null:
		return
	if not _valid:
		GameState.notify("Placement impossible ici")
		return
	if not GameState.consume_items(data.costs):
		GameState.notify("Ressources insuffisantes")
		return

	var position := _ghost.global_position
	var cell := Vector2i(floori(position.x), floori(position.z))
	var level := int(round(position.y / LEVEL_STEP))
	var rotation := _rotation_steps * PI * 0.5
	if data.kind == "wall":
		position = position + Vector3(sin(rotation), 0.0, cos(rotation)) * 0.5
	_spawn(data.kind, data.id, position, _ghost.rotation.y)
	_occupied[_cell_key(data.kind, cell, level, _rotation_steps)] = true
	if data.kind == "campfire" or data.kind == "furnace":
		GameState.craft_station = "campfire" if data.kind == "campfire" else "furnace"
	Sfx.play("build", position)
	GameState.notify("Construit : %s" % data.display_name)


## Pose un élément sans vérifier ni consommer de ressources.
## Utilisé par le chargement de sauvegarde et par les tests d'intégration.
func place_free(kind: String, data_id: String, position: Vector3, rotation_y: float) -> Buildable:
	var node := _spawn(kind, data_id, position, rotation_y)
	var cell := Vector2i(floori(position.x), floori(position.z))
	var level := int(round(position.y / LEVEL_STEP))
	_occupied[_cell_key(node.kind, cell, level, 0)] = true
	return node


func _spawn(kind: String, data_id: String, position: Vector3, rotation_y: float) -> Buildable:
	var node := Buildable.new()
	node.kind = kind
	node.data_id = data_id
	node.position = position
	node.rotation.y = rotation_y
	add_child(node)
	_objects.append(node)
	return node


func _ensure_ghost() -> void:
	if _ghost != null and is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null

	var data := _selected_data()
	if data == null:
		return

	_ghost = Buildable.new()
	_ghost.kind = data.kind
	_ghost.data_id = data.id
	add_child(_ghost)
	_ghost.make_ghost()


func _update_build_info() -> void:
	var data := _selected_data()
	if data == null or _hud == null:
		return

	var costs := PackedStringArray()
	for item_id in data.costs:
		costs.append("%s %d" % [GameState.display_name(str(item_id)), int(data.costs[item_id])])

	var level_height := _locked_y if _level_locked else (_build_level * LEVEL_STEP)
	var level_text := "Niveau +" + str("%.1f" % level_height) + " m"
	if _level_locked:
		level_text += " [verrouillé]"
	_hud.set_build_info(
		"%s · Construction : %s (%d/%d) — %s · Clic gauche : poser · R : tourner · Molette : changer · B : quitter · PgUp/PgDn : niveau · V : verrouiller"
		% [level_text, data.display_name, _selected + 1, _catalog.size(), ", ".join(costs)]
	)


func _raycast() -> Dictionary:
	if _camera == null:
		return {}
	var from := _camera.global_position
	var to := from - _camera.global_transform.basis.z * REACH
	var exclude: Array[RID] = [_player.get_rid()]
	var params := PhysicsRayQueryParameters3D.create(from, to, WORLD_MASK, exclude)
	return get_world_3d().direct_space_state.intersect_ray(params)


func _cell_key(kind: String, cell: Vector2i, level: int = 0, rotation: int = 0) -> String:
	return "%s:%d:%d:%d:%d" % [kind, cell.x, cell.y, level, rotation]


## Calcule le y du fantome : fondation alignee sur une voisine, puis decalage
## de niveau (LEVEL_STEP par niveau) ; le mode verrouille impose un y absolu.
func _compute_ghost_y(hit_y: float, cell: Vector2i, kind: String) -> float:
	var base_y := hit_y
	if kind == "foundation":
		base_y = _aligned_neighbor_y(cell, hit_y)
	var y := base_y + _build_level * LEVEL_STEP
	if _level_locked:
		return _locked_y
	return y


func _aligned_neighbor_y(cell: Vector2i, hit_y: float) -> float:
	var best_y := hit_y
	var best_diff: float = abs(hit_y - hit_y)
	var found := false
	for obj in _objects:
		if not is_instance_valid(obj):
			continue
		if obj.kind != "foundation":
			continue
		var obj_cell := Vector2i(floori(obj.position.x), floori(obj.position.z))
		var dx := obj_cell.x - cell.x
		var dz := obj_cell.y - cell.y
		if not ((dx != 0 or dz != 0) and (dx == 0 or dz == 0)):
			continue
		var diff: float = abs(obj.position.y - hit_y)
		if not found or diff < best_diff:
			found = true
			best_diff = diff
			best_y = obj.position.y
	if not found:
		return hit_y
	return best_y


## Avance / recule le niveau de construction (delta en niveaux).
func _change_level(delta: int) -> void:
	if _level_locked:
		_locked_y += delta * LEVEL_STEP
		_update_build_info()
		return
	_build_level += delta
	_update_build_info()


## Verrouille / deverrouille le niveau (y absolu mémorisé).
func _toggle_level_lock() -> void:
	if not active:
		return
	if _level_locked:
		_level_locked = false
		_update_build_info()
		return
	_level_locked = true
	_locked_y = _ghost_y
	_update_build_info()


# --- Sauvegarde --------------------------------------------------------------

func to_save_data() -> Array:
	var result := []
	for obj in _objects:
		if not is_instance_valid(obj):
			continue
		result.append({
			"kind": obj.kind,
			"data_id": obj.data_id,
			"position": [obj.position.x, obj.position.y, obj.position.z],
			"rotation_y": obj.rotation.y,
		})
	return result


func load_save_data(entries: Variant) -> void:
	clear_all()
	if typeof(entries) != TYPE_ARRAY:
		return

	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var pos_array: Array = entry.get("position", [])
		if pos_array.size() != 3:
			continue
		var position := Vector3(float(pos_array[0]), float(pos_array[1]), float(pos_array[2]))
		place_free(
			str(entry.get("kind", "foundation")),
			str(entry.get("data_id", "")),
			position,
			float(entry.get("rotation_y", 0.0))
		)


func clear_all() -> void:
	for obj in _objects:
		if is_instance_valid(obj):
			obj.queue_free()
	_objects.clear()
	_occupied.clear()
