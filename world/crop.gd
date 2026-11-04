class_name Crop
extends StaticBody3D
## Culture du portage d'Ocean Is Home : plantation, croissance, récolte.

const GROWTH_SECONDS := 90.0
const SEED_ITEM_ID := "seed"

const COLOR_SOIL := Color(0.38, 0.28, 0.18)
const COLOR_GROWING := Color(0.24, 0.62, 0.24)
const COLOR_MATURE := Color(0.85, 0.28, 0.22)

@export var item_id: String = "berry"

## Identifiant stable (ordre de génération) pour la sauvegarde. -1 = aucun.
var save_id := -1

var progress := 0.0
var _planted := false
var _visual: MeshInstance3D
var _material: StandardMaterial3D


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
	_material = _make_material(COLOR_SOIL)
	visual.material_override = _material
	add_child(visual)
	_visual = visual
	_update_visual()


func is_planted() -> bool:
	return _planted


func get_save_state() -> Dictionary:
	return {"id": save_id, "progress": progress}


## Restaure l'état de la culture (plantée + progression, ou vide).
func apply_save_state(planted: bool, saved_progress: float) -> void:
	_planted = planted
	progress = clampf(saved_progress, 0.0, GROWTH_SECONDS * 4.0) if planted else 0.0
	_update_visual()


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
			_update_visual()
			GameState.notify("Culture plantée")
		return
	if progress < GROWTH_SECONDS:
		return
	GameState.add_item(item_id, 2)
	# Rendement pérenne : une récolte mature fournit aussi des graines
	GameState.add_item(SEED_ITEM_ID, 1)
	_planted = false
	progress = 0.0
	_update_visual()
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
	_update_visual()


func _update_visual() -> void:
	if _visual == null or _material == null:
		return
	if not _planted:
		_visual.scale = Vector3(1.0, 0.2, 1.0)
		_material.albedo_color = COLOR_SOIL
		return
	var growth := clampf(progress / GROWTH_SECONDS, 0.0, 1.0)
	_visual.scale = Vector3(1.0, 0.2 + 0.8 * growth, 1.0)
	var tint := COLOR_GROWING.lerp(COLOR_MATURE, clampf((growth - 0.7) / 0.3, 0.0, 1.0))
	_material.albedo_color = tint
