class_name Construction
extends Node3D
## Mode construction : aperçu fantôme, accrochage à une grille de 1 m,
## validation des ressources, pose et sauvegarde des éléments construits.
##
## Les éléments sont des enfants de ce nœud, ce qui rend le nettoyage et la
## sauvegarde triviaux (une seule liste à parcourir).

const REACH := 8.0
const WORLD_MASK := 1 | 8  # terrain/props + objets construits
## Coordonnées max acceptées dans une sauvegarde (le terrain fait ±130 m).
const MAX_COORD := 1000.0
## Éléments posés sur un bord de case (et non au centre).
const EDGE_KINDS := ["wall", "door", "window"]

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
	active = not active
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
	if not active or _ghost == null:
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
	var shift := (maxi(1, _selected_data().grid_size) - 1) * 0.5
	_ghost.global_position = Vector3(cell.x + 0.5 + shift, ghost_y, cell.y + 0.5 + shift)
	_ghost.rotation.y = _rotation_steps * PI * 0.5
	_ghost_y = ghost_y
	_valid = _placement_ok(hit, cell, ghost_y)
	_ghost.set_ghost_valid(_valid)


func _unhandled_input(event: InputEvent) -> void:
	if not active:
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
	for key in _keys_for(data.kind, cell, level, rotation, data.grid_size):
		if _occupied.has(key):
			return false
	return true


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
	if not collider is Buildable:
		var normal: Vector3 = hit["normal"]
		if normal.y < 0.8:
			return false
	if not _can_place(cell, int(round(ghost_y / LEVEL_STEP)), _rotation_steps):
		return false
	return not _ghost_blocked_by_player()


## Vrai si le fantôme recouvrirait le joueur (on ne se mure pas dans un bloc).
func _ghost_blocked_by_player() -> bool:
	var data := _selected_data()
	if data == null or _ghost == null:
		return false
	var center := _ghost.global_position
	if data.kind == "wall":
		var rot := _rotation_steps * PI * 0.5
		center += Vector3(sin(rot), 0.0, cos(rot)) * 0.5
	return _blocked_by_player(center, _rotation_steps * PI * 0.5, data.kind, data.grid_size)


## Test géométrique simple (boîte) entre un élément et la capsule du joueur
## (origine aux pieds, rayon 0,35 m, hauteur 1,8 m).
func _blocked_by_player(center: Vector3, rot_y: float, kind: String, size: int) -> bool:
	if _player == null or kind == "foundation":
		return false
	var is_edge := EDGE_KINDS.has(kind)
	var height := 2.4 if (is_edge or kind == "roof") else 1.0
	var p := _player.global_position
	if center.y >= p.y + 1.8 or center.y + height <= p.y:
		return false
	var local := Vector3(p.x - center.x, 0.0, p.z - center.z).rotated(Vector3.UP, -rot_y)
	var half := maxi(1, size) * 0.5 + 0.35
	var half_x := 0.5 + 0.35 if is_edge else half
	var half_z := 0.08 + 0.35 if is_edge else half
	return absf(local.x) < half_x and absf(local.z) < half_z


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

	if _ghost == null:
		return
	var position := _ghost.global_position
	var rotation := _rotation_steps * PI * 0.5
	if data.kind == "wall":
		position = position + Vector3(sin(rotation), 0.0, cos(rotation)) * 0.5
	var node := _spawn(data.kind, data.id, position, _ghost.rotation.y)
	_register_object(node)
	Sfx.play("build", position)
	GameState.notify("Construit : %s" % data.display_name)


## Pose un élément sans vérifier ni consommer de ressources.
## Utilisé par le chargement de sauvegarde et par les tests d'intégration.
func place_free(kind: String, data_id: String, position: Vector3, rotation_y: float) -> Buildable:
	var node := _spawn(kind, data_id, position, rotation_y)
	_register_object(node)
	return node


## Enregistre l'empreinte d'un élément posé (clé d'occupation + station).
## Une seule voie pour la pose et le chargement : la clé est recalculée depuis
## la position/rotation réelles du nœud, donc identique avant et après une
## sauvegarde.
func _register_object(node: Buildable) -> void:
	for key in _key_for_object(node.kind, node.position, node.rotation.y, _grid_size_of(node.data_id)):
		_occupied[key] = true
	if node.kind == "campfire" or node.kind == "furnace":
		GameState.register_station(node.kind)


func _grid_size_of(data_id: String) -> int:
	var data: Variant = Database.buildables.get(data_id)
	if data is BuildableData:
		return maxi(1, (data as BuildableData).grid_size)
	return 1


## Clés d'occupation d'un élément déjà posé (position réelle du nœud).
## Les murs sont décalés d'un demi-mètre vers leur bord : on retire ce décalage
## pour retrouver la case d'origine, comme au moment de la pose. Un élément
## de grid_size n est centré sur son empreinte n x n : on retire aussi ce décalage.
func _key_for_object(kind: String, position: Vector3, rotation_y: float, size: int = 1) -> Array[String]:
	var base := position
	if kind == "wall":
		base = position - Vector3(sin(rotation_y), 0.0, cos(rotation_y)) * 0.5
	elif size > 1 and not EDGE_KINDS.has(kind):
		var shift := (size - 1) * 0.5
		base = position - Vector3(shift, 0.0, shift)
	var cell := Vector2i(floori(base.x), floori(base.z))
	var level := int(round(position.y / LEVEL_STEP))
	var steps := wrapi(int(round(rotation_y / (PI * 0.5))), 0, 4)
	return _keys_for(kind, cell, level, steps, size)


## Toutes les clés occupées par un élément : une seule pour un bord ou une
## empreinte 1 x 1, n x n sinon.
func _keys_for(kind: String, cell: Vector2i, level: int, rotation: int, size: int) -> Array[String]:
	var keys: Array[String] = []
	if EDGE_KINDS.has(kind) or size <= 1:
		keys.append(_cell_key(kind, cell, level, rotation))
		return keys
	for dx in size:
		for dz in size:
			keys.append(_cell_key(kind, Vector2i(cell.x + dx, cell.y + dz), level, rotation))
	return keys


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


## Clé d'occupation. Deux familles, indépendantes de la catégorie exacte :
##  - éléments « de bord » (mur, porte, fenêtre) : un bord par case, niveau et
##    orientation ; un mur et une porte ne peuvent donc pas partager un bord ;
##  - tout le reste occupe le centre de la case à un niveau donné : fondation,
##    toit, feu, coffre... ne peuvent pas se superposer, quelle que soit leur
##    catégorie.
func _cell_key(kind: String, cell: Vector2i, level: int = 0, rotation: int = 0) -> String:
	if EDGE_KINDS.has(kind):
		return "edge:%d:%d:%d:%d" % [cell.x, cell.y, level, wrapi(rotation, 0, 4)]
	return "cell:%d:%d:%d" % [cell.x, cell.y, level]


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
		var pos_array: Variant = entry.get("position", [])
		if typeof(pos_array) != TYPE_ARRAY or (pos_array as Array).size() != 3:
			continue
		var coords: Array = pos_array
		var numeric := true
		for value in coords:
			if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
				numeric = false
			elif not is_finite(float(value)) or absf(float(value)) > MAX_COORD:
				numeric = false
		if not numeric:
			continue
		var raw_rot: Variant = entry.get("rotation_y", 0.0)
		if (typeof(raw_rot) != TYPE_FLOAT and typeof(raw_rot) != TYPE_INT) or not is_finite(float(raw_rot)):
			continue

		# L'identifiant doit exister dans la base ; la catégorie vient de la base
		# (source de vérité), pas du fichier. Anciennes sauvegardes sans
		# identifiant : on retombe sur la catégorie enregistrée.
		var data_id := str(entry.get("data_id", ""))
		var kind := ""
		if Database.buildables.has(data_id):
			kind = str((Database.buildables[data_id] as BuildableData).kind)
		elif data_id.is_empty():
			var saved_kind := str(entry.get("kind", ""))
			for candidate in Database.buildables.values():
				if (candidate as BuildableData).kind == saved_kind:
					kind = saved_kind
					data_id = (candidate as BuildableData).id
					break
		if kind.is_empty():
			push_warning("[Construction] Élément ignoré (identifiant inconnu : %s)" % data_id)
			continue

		var position := Vector3(float(coords[0]), float(coords[1]), float(coords[2]))
		var rotation_y := float(raw_rot)
		# Anti-duplication : une sauvegarde qui contient deux fois la même
		# empreinte ne recrée qu'un seul élément.
		var duplicate := false
		for key in _key_for_object(kind, position, rotation_y, _grid_size_of(data_id)):
			if _occupied.has(key):
				duplicate = true
		if duplicate:
			push_warning("[Construction] Doublon ignoré à %s" % str(position))
			continue
		place_free(kind, data_id, position, rotation_y)


func clear_all() -> void:
	for obj in _objects:
		if is_instance_valid(obj):
			obj.queue_free()
	_objects.clear()
	_occupied.clear()
	GameState.clear_stations()
