class_name Crop
extends StaticBody3D
## Culture du portage d'Ocean Is Home : plantation, croissance, récolte.

const GROWTH_SECONDS := 90.0
const SEED_ITEM_ID := "seed"

@export var item_id: String = "berry"

var progress := 0.0
var _planted := false
var _visual: MeshInstance3D

## État sérialisable pour SaveSystem : vide si la parcelle est en jachère,
## sinon le temps de croissance écoulé en secondes.
func get_save_state() -> String:
	if not _planted:
		return "E"
	return "P" + str(progress)


func apply_save_state(state: String) -> void:
	if state.is_empty():
		return
	if state == "E":
		# Jachère sauvegardée (parcelle récoltée avant la sauvegarde).
		_planted = false
		progress = 0.0
		if _visual != null:
			_visual.scale = Vector3(1.0, 0.2, 1.0)
		return
	var p := float(state.substr(1)) if state.begins_with("P") else float(state)
	if p <= 0.0:
		return
	_planted = true
	progress = p
	if _visual != null:
		var growth := clampf(progress / GROWTH_SECONDS, 0.0, 1.0)
		_visual.scale = Vector3(1.0, 0.2 + 0.9 * growth, 1.0)
		var mat := _visual.material_override as StandardMaterial3D
		if mat != null:
			if growth >= 1.0:
				mat.albedo_color = Color(0.85, 0.25, 0.3)
			else:
				mat.albedo_color = Color(0.2 + 0.3 * growth, 0.55 + 0.2 * growth, 0.2)


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 0.2, 1.0)
	shape.shape = box
	add_child(shape)

	var visual := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(1.0, 0.5, 1.0)
	visual.mesh = box_mesh
	visual.position = Vector3(0.0, 0.25, 0.0)
	visual.material_override = _make_material(Color(0.2, 0.55, 0.2))
	add_child(visual)
	_visual = visual


func get_interaction_prompt() -> String:
	if not _planted:
		return "Cultiver : %s (E)" % GameState.display_name(SEED_ITEM_ID)
	if progress < GROWTH_SECONDS:
		return "En croissance…"
	return "Récolter : %s (E)" % GameState.display_name(item_id)


func interact(_player: Node) -> void:
	if not _planted:
		if GameState.get_item_count(SEED_ITEM_ID) > 0:
			GameState.remove_item(SEED_ITEM_ID, 1)
			_planted = true
			progress = 0.0
			GameState.notify("Culture plantée")
		return
	if progress < GROWTH_SECONDS:
		return
	GameState.add_item(item_id, 2)
	# Rendement pérenne : une récolte mature fournit aussi des graines
	GameState.add_item(SEED_ITEM_ID, 1)
	_planted = false
	progress = 0.0
	GameState.notify("Récolte (+2 %s, +1 %s)" % [GameState.display_name(item_id), GameState.display_name(SEED_ITEM_ID)])


func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	material.metallic = 0.0
	return material


func _process(delta: float) -> void:
	if not _planted:
		return
	progress += delta
	if _visual != null:
		var growth := clampf(progress / GROWTH_SECONDS, 0.0, 1.0)
		_visual.scale = Vector3(1.0, 0.2 + 0.9 * growth, 1.0)
