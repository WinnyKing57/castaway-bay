class_name Buildable
extends StaticBody3D
## Élément construit : fondation, mur ou feu de camp.
##
## Le visuel et la collision sont générés en code selon `kind`, comme pour
## les ressources récoltables. La couche physique 4 ("construit") permet de
## tester les chevauchements sans toucher au terrain.

var kind := "foundation"
var data_id := ""

var _ghost_material: StandardMaterial3D


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	if get_child_count() == 0:
		_build_visuals()


## Transforme l'objet en aperçu translucide, sans collision.
func make_ghost() -> void:
	collision_layer = 0
	collision_mask = 0
	_ghost_material = StandardMaterial3D.new()
	_ghost_material.albedo_color = Color(0.35, 1.0, 0.45, 0.45)
	_ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_material.no_depth_test = true
	_apply_ghost_material()


func set_ghost_valid(valid: bool) -> void:
	if _ghost_material == null:
		return
	_ghost_material.albedo_color = (
		Color(0.35, 1.0, 0.45, 0.45) if valid else Color(1.0, 0.3, 0.3, 0.45)
	)


func _apply_ghost_material() -> void:
	for child in get_children():
		if child is MeshInstance3D:
			child.material_override = _ghost_material


# --- Visuels -----------------------------------------------------------------

func _build_visuals() -> void:
	match kind:
		"wall":
			_build_wall()
		"roof":
			_build_roof()
		"door":
			_build_door()
		"window":
			_build_window()
		"chest":
			_build_chest()
		"campfire":
			_build_campfire()
		"furnace":
			_build_furnace()
		"tent":
			_build_tent()
		"bed":
			_build_bed()
		"generator":
			_build_generator()
		_:
			_build_foundation()


func _build_foundation() -> void:
	_add_box(Vector3(1.0, 0.2, 1.0), Vector3(0.0, 0.1, 0.0), Color(0.45, 0.32, 0.2))
	# Planches décoratives sur le dessus.
	for i in 3:
		var plank := MeshInstance3D.new()
		var plank_mesh := BoxMesh.new()
		plank_mesh.size = Vector3(0.9, 0.04, 0.26)
		plank.mesh = plank_mesh
		plank.position = Vector3(0.0, 0.22, -0.32 + i * 0.32)
		plank.material_override = _make_material(Color(0.56, 0.42, 0.27))
		add_child(plank)


func _build_wall() -> void:
	_add_box(Vector3(1.0, 2.4, 0.16), Vector3(0.0, 1.2, 0.0), Color(0.52, 0.38, 0.24))
	# Poutre horizontale pour casser la monotonie.
	var beam := MeshInstance3D.new()
	var beam_mesh := BoxMesh.new()
	beam_mesh.size = Vector3(1.0, 0.14, 0.2)
	beam.mesh = beam_mesh
	beam.position = Vector3(0.0, 2.2, 0.0)
	beam.material_override = _make_material(Color(0.38, 0.27, 0.16))
	add_child(beam)


func _build_campfire() -> void:
	# Cercle de pierres.
	for i in 7:
		var stone := MeshInstance3D.new()
		var stone_mesh := SphereMesh.new()
		stone_mesh.radius = 0.16
		stone_mesh.height = 0.24
		stone_mesh.radial_segments = 6
		stone_mesh.rings = 2
		stone.mesh = stone_mesh
		stone.position = Vector3(cos(i * TAU / 7.0) * 0.5, 0.1, sin(i * TAU / 7.0) * 0.5)
		stone.material_override = _make_material(Color(0.45, 0.44, 0.42))
		add_child(stone)

	# Bûches croisées.
	for i in 3:
		var log_mesh := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.07
		cylinder.bottom_radius = 0.08
		cylinder.height = 0.8
		cylinder.radial_segments = 5
		cylinder.rings = 1
		log_mesh.mesh = cylinder
		log_mesh.rotation = Vector3(deg_to_rad(75.0), i * TAU / 3.0, 0.0)
		log_mesh.position.y = 0.16
		log_mesh.material_override = _make_material(Color(0.3, 0.2, 0.12))
		add_child(log_mesh)

	# Flamme et lumière.
	var flame := MeshInstance3D.new()
	var flame_mesh := SphereMesh.new()
	flame_mesh.radius = 0.16
	flame_mesh.height = 0.42
	flame_mesh.radial_segments = 6
	flame_mesh.rings = 3
	flame.mesh = flame_mesh
	flame.position.y = 0.35
	var flame_material := StandardMaterial3D.new()
	flame_material.albedo_color = Color(1.0, 0.55, 0.15)
	flame_material.emission_enabled = true
	flame_material.emission = Color(1.0, 0.45, 0.1)
	flame_material.emission_energy_multiplier = 3.0
	flame.material_override = flame_material
	add_child(flame)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.62, 0.28)
	light.light_energy = 1.6
	light.omni_range = 7.0
	light.position.y = 0.9
	add_child(light)

	_add_collision_box(Vector3(1.0, 0.6, 1.0), Vector3(0.0, 0.3, 0.0))


func _build_furnace() -> void:
	_add_box(Vector3(1.1, 2.2, 0.9), Vector3(0.0, 1.1, 0.0), Color(0.5, 0.48, 0.45))
	var chimney := MeshInstance3D.new()
	var chimney_mesh := BoxMesh.new()
	chimney_mesh.size = Vector3(0.25, 1.6, 0.25)
	chimney.mesh = chimney_mesh
	chimney.position = Vector3(0.3, 2.9, 0.0)
	chimney.material_override = _make_material(Color(0.55, 0.5, 0.42))
	add_child(chimney)
	var glow := MeshInstance3D.new()
	var glow_mesh := SphereMesh.new()
	glow_mesh.radius = 0.22
	glow_mesh.height = 0.5
	glow_mesh.radial_segments = 6
	glow_mesh.rings = 3
	glow.mesh = glow_mesh
	glow.position = Vector3(0.3, 3.4, 0.0)
	var glow_material := StandardMaterial3D.new()
	glow_material.albedo_color = Color(1.0, 0.75, 0.45)
	glow_material.emission_enabled = true
	glow_material.emission = Color(1.0, 0.6, 0.25)
	glow_material.emission_energy_multiplier = 4.0
	glow.material_override = glow_material
	add_child(glow)
	_add_collision_box(Vector3(1.1, 2.2, 0.9), Vector3(0.0, 1.1, 0.0))


func _build_tent() -> void:
	var canvas := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(2.0, 1.0, 1.6)
	canvas.mesh = prism
	canvas.position = Vector3(0.0, 0.9, 0.0)
	canvas.rotation = Vector3(deg_to_rad(45.0), 0.0, 0.0)
	canvas.material_override = _make_material(Color(0.6, 0.45, 0.3))
	add_child(canvas)
	_add_collision_box(Vector3(2.0, 1.0, 1.6), Vector3(0.0, 0.5, 0.0))


func _build_bed() -> void:
	_add_box(Vector3(1.8, 0.35, 0.6), Vector3(0.0, 0.35, 0.0), Color(0.42, 0.3, 0.2))
	_add_box(Vector3(1.7, 0.25, 0.5), Vector3(0.0, 0.7, 0.0), Color(0.75, 0.68, 0.58))


func _build_generator() -> void:
	_add_box(Vector3(1.0, 1.0, 0.8), Vector3(0.0, 0.5, 0.0), Color(0.45, 0.44, 0.42))
	var pole := MeshInstance3D.new()
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.06
	pole_mesh.bottom_radius = 0.06
	pole_mesh.height = 2.2
	pole_mesh.radial_segments = 6
	pole.mesh = pole_mesh
	pole.position = Vector3(0.4, 1.1, 0.0)
	pole.material_override = _make_material(Color(0.35, 0.34, 0.32))
	add_child(pole)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.9, 0.7)
	light.light_energy = 2.0
	light.omni_range = 6.0
	light.position = Vector3(0.0, 1.2, 0.0)
	add_child(light)
	_add_collision_box(Vector3(1.0, 1.0, 0.8), Vector3(0.0, 0.5, 0.0))


func _add_box(size: Vector3, offset: Vector3, color: Color) -> void:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.position = offset
	mesh_instance.material_override = _make_material(color)
	add_child(mesh_instance)
	_add_collision_box(size, offset)


func _add_collision_box(size: Vector3, offset: Vector3) -> void:
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

func _build_roof() -> void:
	_add_box(Vector3(1.0, 0.1, 1.2), Vector3(0.0, 2.3, 0.0), Color(0.55, 0.38, 0.22))
	# Pente.
	var slope := MeshInstance3D.new()
	var slope_mesh := PrismMesh.new()
	slope_mesh.size = Vector3(0.9, 0.2, 1.0)
	slope.mesh = slope_mesh
	slope.position = Vector3(0.0, 2.35, 0.0)
	slope.rotation = Vector3(deg_to_rad(30.0), 0.0, 0.0)
	slope.material_override = _make_material(Color(0.6, 0.42, 0.28))
	add_child(slope)
	_add_collision_box(Vector3(1.0, 0.3, 1.2), Vector3(0.0, 2.3, 0.0))

func _build_door() -> void:
	_add_box(Vector3(0.8, 2.0, 0.16), Vector3(0.0, 1.0, 0.0), Color(0.52, 0.38, 0.24))
	var knob := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.06
	sphere.radial_segments = 6
	sphere.rings = 3
	knob.mesh = sphere
	knob.position = Vector3(0.35, 1.0, 0.0)
	knob.material_override = _make_material(Color(0.3, 0.25, 0.12))
	add_child(knob)
	_add_collision_box(Vector3(0.8, 2.0, 0.16), Vector3(0.0, 1.0, 0.0))

func _build_window() -> void:
	_add_box(Vector3(0.8, 0.7, 0.16), Vector3(0.0, 1.3, 0.0), Color(0.7, 0.65, 0.55))
	var glass := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(0.7, 0.55)
	glass.mesh = plane
	glass.position = Vector3(0.0, 1.3, 0.05)
	glass.rotation = Vector3(0.0, PI / 2.0, 0.0)
	glass.material_override = _make_material(Color(0.85, 0.9, 1.0))
	add_child(glass)
	_add_collision_box(Vector3(0.8, 0.7, 0.16), Vector3(0.0, 1.3, 0.0))

func _build_chest() -> void:
	_add_box(Vector3(0.9, 0.7, 0.6), Vector3(0.0, 0.35, 0.0), Color(0.42, 0.3, 0.18))
	# Couvercle avec charnière.
	var lid := MeshInstance3D.new()
	var lid_mesh := BoxMesh.new()
	lid_mesh.size = Vector3(0.85, 0.08, 0.55)
	lid.mesh = lid_mesh
	lid.position = Vector3(0.0, 0.75, 0.0)
	lid.material_override = _make_material(Color(0.5, 0.36, 0.24))
	add_child(lid)
	_add_collision_box(Vector3(0.9, 0.7, 0.6), Vector3(0.0, 0.35, 0.0))
