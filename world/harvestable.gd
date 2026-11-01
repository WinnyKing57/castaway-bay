class_name Harvestable
extends StaticBody3D
## Ressource récoltable : arbre, palmier, rocher ou buisson.
##
## Le visuel et la collision sont construits en code selon `kind`, ce qui
## évite quatre scènes quasi identiques. La scène ne contient que ce script.
## Le butin est un dictionnaire item_id -> quantité, pour pouvoir donner
## plusieurs objets d'un coup (un palmier donne du bois ET une noix de coco).

@export_enum("arbre", "palmier", "rocher", "buisson") var kind: String = "arbre"

## Temps de repousse : une ressource récoltée redevient disponible après
## ce délai, ce qui évite d'épuiser l'île lors d'une longue partie.
const REGROW_SECONDS := 120.0

var _loot: Dictionary = {}
var _depleted := false
var _regrow_left := 0.0


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	match kind:
		"palmier":
			_loot = {"wood": 3, "coconut": 2}
			_build_palm()
		"rocher":
			_loot = {"stone": 3}
			_build_rock()
		"buisson":
			_loot = {"fiber": 5}
			if randf() < 0.4:
				_loot["berry"] = 3
			_build_bush()
		_:
			_loot = {"wood": 4}
			_build_tree()


func get_interaction_prompt() -> String:
	if _depleted:
		return ""
	var parts := PackedStringArray()
	for item_id in _loot:
		parts.append("%s x%d" % [GameState.display_name(str(item_id)), _amount_for(str(item_id))])
	return "Récolter : %s (E)" % ", ".join(parts)


func interact(_player: Node) -> void:
	if _depleted:
		return
	Sfx.play("harvest", global_position)
	for item_id in _loot:
		GameState.add_item(str(item_id), _amount_for(str(item_id)))
	_start_regrow()


func _process(delta: float) -> void:
	if not _depleted:
		return
	_regrow_left -= delta
	if _regrow_left <= 0.0:
		_regrow()


func _start_regrow() -> void:
	_depleted = true
	_regrow_left = REGROW_SECONDS
	visible = false
	collision_layer = 0


func _regrow() -> void:
	_depleted = false
	visible = true
	collision_layer = 1


## La hache en pierre double le bois récolté : elle donne un intérêt concret
## à l'artisanat, sans ajouter d'étape d'équipement.
func _amount_for(item_id: String) -> int:
	var amount := int(_loot[item_id])
	if item_id == "wood" and GameState.get_item_count("stone_axe") > 0:
		amount *= 2
	return amount


# --- Construction visuelle ---------------------------------------------------

func _build_tree() -> void:
	_add_trunk(2.4, 0.13, 0.22)
	_add_cone(3.3, 1.5, 2.8, Color(0.16, 0.42, 0.18))
	_add_box_collision(Vector3(0.7, 4.6, 0.7), Vector3(0.0, 2.3, 0.0))


func _build_palm() -> void:
	_add_trunk(4.2, 0.11, 0.2)
	# Feuillage : quelques palmes aplaties autour du sommet.
	for i in 5:
		var leaf := MeshInstance3D.new()
		var leaf_mesh := SphereMesh.new()
		leaf_mesh.radius = 0.75
		leaf_mesh.height = 0.35
		leaf_mesh.radial_segments = 6
		leaf_mesh.rings = 2
		leaf.mesh = leaf_mesh
		leaf.material_override = _make_material(Color(0.22, 0.5, 0.2))
		leaf.position = Vector3(cos(i * TAU / 5.0) * 0.8, 4.15, sin(i * TAU / 5.0) * 0.8)
		leaf.scale = Vector3(1.0, 1.0, 1.9)
		leaf.rotation.y = i * TAU / 5.0
		add_child(leaf)
	_add_box_collision(Vector3(0.6, 4.4, 0.6), Vector3(0.0, 2.2, 0.0))


func _build_rock() -> void:
	var rock := MeshInstance3D.new()
	var rock_mesh := SphereMesh.new()
	rock_mesh.radius = 0.9
	rock_mesh.height = 1.6
	rock_mesh.radial_segments = 7
	rock_mesh.rings = 3
	rock.mesh = rock_mesh
	rock.position.y = 0.55
	rock.scale = Vector3(1.25, 0.85, 1.05)
	rock.rotation.y = randf() * TAU
	rock.material_override = _make_material(Color(0.46, 0.45, 0.43))
	add_child(rock)

	_add_box_collision(Vector3(1.9, 1.2, 1.6), Vector3(0.0, 0.55, 0.0))


func _build_bush() -> void:
	var bush := MeshInstance3D.new()
	var bush_mesh := SphereMesh.new()
	bush_mesh.radius = 0.75
	bush_mesh.height = 1.0
	bush_mesh.radial_segments = 7
	bush_mesh.rings = 3
	bush.mesh = bush_mesh
	bush.position.y = 0.45
	bush.scale = Vector3(1.2, 0.8, 1.1)
	bush.material_override = _make_material(Color(0.22, 0.46, 0.2))
	add_child(bush)

	_add_box_collision(Vector3(1.5, 0.9, 1.4), Vector3(0.0, 0.45, 0.0))


func _add_trunk(height: float, top_radius: float, bottom_radius: float) -> void:
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = top_radius
	trunk_mesh.bottom_radius = bottom_radius
	trunk_mesh.height = height
	trunk_mesh.radial_segments = 6
	trunk_mesh.rings = 1
	trunk.mesh = trunk_mesh
	trunk.position.y = height * 0.5
	trunk.material_override = _make_material(Color(0.36, 0.24, 0.15))
	add_child(trunk)


func _add_cone(y: float, radius: float, height: float, color: Color) -> void:
	var leaves := MeshInstance3D.new()
	var leaves_mesh := CylinderMesh.new()
	leaves_mesh.top_radius = 0.05
	leaves_mesh.bottom_radius = radius
	leaves_mesh.height = height
	leaves_mesh.radial_segments = 7
	leaves_mesh.rings = 1
	leaves.mesh = leaves_mesh
	leaves.position.y = y
	leaves.material_override = _make_material(color)
	add_child(leaves)


func _add_box_collision(size: Vector3, offset: Vector3) -> void:
	var shape_node := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape_node.shape = box
	shape_node.position = offset
	add_child(shape_node)


func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	material.metallic = 0.0
	return material
