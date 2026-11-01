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
	_ghost.visible = true
	_ghost.global_position = Vector3(cell.x + 0.5, position.y, cell.y + 0.5)
	_ghost.rotation.y = _rotation_steps * PI * 0.5
	_valid = _can_place(cell)
	_ghost.set_ghost_valid(_valid)


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return

	if event.is_action_pressed("rotate_build"):
		_rotation_steps = (_rotation_steps + 1) % 4
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


func _can_place(cell: Vector2i) -> bool:
	var data := _selected_data()
	if data == null:
		return false
	if not GameState.has_items(data.costs):
		return false
	return not _occupied.has(_cell_key(data.kind, cell))


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
	_spawn(data.kind, data.id, position, _ghost.rotation.y)
	_occupied[_cell_key(data.kind, cell)] = true
	Sfx.play("build", position)
	GameState.notify("Construit : %s" % data.display_name)


## Pose un élément sans vérifier ni consommer de ressources.
## Utilisé par le chargement de sauvegarde et par les tests d'intégration.
func place_free(kind: String, data_id: String, position: Vector3, rotation_y: float) -> Buildable:
	var node := _spawn(kind, data_id, position, rotation_y)
	var cell := Vector2i(floori(position.x), floori(position.z))
	_occupied[_cell_key(node.kind, cell)] = true
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

	_hud.set_build_info(
		"Construction : %s (%d/%d) — %s · Clic gauche : poser · R : tourner · Molette : changer · B : quitter"
		% [data.display_name, _selected + 1, _catalog.size(), ", ".join(costs)]
	)


func _raycast() -> Dictionary:
	if _camera == null:
		return {}
	var from := _camera.global_position
	var to := from - _camera.global_transform.basis.z * REACH
	var exclude: Array[RID] = [_player.get_rid()]
	var params := PhysicsRayQueryParameters3D.create(from, to, WORLD_MASK, exclude)
	return get_world_3d().direct_space_state.intersect_ray(params)


func _cell_key(kind: String, cell: Vector2i) -> String:
	return "%s:%d:%d" % [kind, cell.x, cell.y]


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
