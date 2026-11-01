class_name Harvestable
extends StaticBody3D
## Ressource récoltable : arbre, rocher ou buisson.
##
## Le visuel et la collision sont construits en code selon `kind`, ce qui
## évite trois scènes quasi identiques. La scène ne contient que ce script.

@export_enum("arbre", "rocher", "buisson") var kind: String = "arbre"

var _item_id := "wood"
var _amount := 3


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	match kind:
		"rocher":
			_item_id = "stone"
			_amount = 2
			_build_rock()
		"buisson":
			_item_id = "fiber"
			_amount = 4
			_build_bush()
		_:
			_item_id = "wood"
			_amount = 3
			_build_tree()


func get_interaction_prompt() -> String:
	return "Récolter : %s (E)" % GameState.display_name(_item_id)


func interact(_player: Node) -> void:
	GameState.add_item(_item_id, _amount)
	queue_free()


# --- Construction visuelle ---------------------------------------------------

func _build_tree() -> void:
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.13
	trunk_mesh.bottom_radius = 0.22
	trunk_mesh.height = 2.4
	trunk_mesh.radial_segments = 6
	trunk_mesh.rings = 1
	trunk.mesh = trunk_mesh
	trunk.position.y = 1.2
	trunk.material_override = _make_material(Color(0.36, 0.24, 0.15))
	add_child(trunk)

	var leaves := MeshInstance3D.new()
	var leaves_mesh := CylinderMesh.new()
	leaves_mesh.top_radius = 0.05
	leaves_mesh.bottom_radius = 1.5
	leaves_mesh.height = 2.8
	leaves_mesh.radial_segments = 7
	leaves_mesh.rings = 1
	leaves.mesh = leaves_mesh
	leaves.position.y = 3.3
	leaves.material_override = _make_material(Color(0.16, 0.42, 0.18))
	add_child(leaves)

	_add_box_collision(Vector3(0.7, 4.6, 0.7), Vector3(0.0, 2.3, 0.0))


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
