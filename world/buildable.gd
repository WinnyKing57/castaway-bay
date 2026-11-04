class_name Buildable
extends StaticBody3D
## Élément construit : fondation, mur ou feu de camp.
##
## Le visuel et la collision sont générés en code selon `kind`, comme pour
## les ressources récoltables. La couche physique 4 ("construit") permet de
## tester les chevauchements sans toucher au terrain.

var kind := "foundation"
var data_id := ""
## Contenu stocké dans le coffre (item_id -> quantité).
var chest_inventory: Dictionary = {}
## État d'ouverture pour les portes.
var is_open: bool = false

var _door_pivot: Node3D = null
var _door_shape: CollisionShape3D = null
var _ghost_material: StandardMaterial3D


func get_interaction_prompt() -> String:
	if kind == "chest":
		var total_items := 0
		for count in chest_inventory.values():
			total_items += int(count)
		if total_items > 0:
			return "Ouvrir le coffre (%d objets) (E)" % total_items
		return "Ouvrir le coffre (vide) (E)"
	elif kind == "door":
		return "Fermer la porte (E)" if is_open else "Ouvrir la porte (E)"
	elif kind == "bed":
		var hour := (int(GameState.world_time) / 3600) % 24
		var is_night := hour >= 19 or hour < 6
		if is_night:
			return "Dormir jusqu'au matin (E)"
		return "Se reposer (la nuit seulement) (E)"
	return ""


func interact(_player: Node) -> void:
	if kind == "chest":
		GameState.chest_opened.emit(self)
	elif kind == "door":
		toggle_door()
	elif kind == "bed":
		_use_bed()


func toggle_door() -> void:
	is_open = not is_open
	_apply_door_state()
	Sfx.play_ui("ui")
	GameState.notify("Porte %s" % ("ouverte" if is_open else "fermée"))


func _apply_door_state() -> void:
	if _door_pivot != null:
		_door_pivot.rotation.y = PI * 0.5 if is_open else 0.0
	if _door_shape != null:
		_door_shape.disabled = is_open


func _use_bed() -> void:
	var hour := (int(GameState.world_time) / 3600) % 24
	var is_night := hour >= 19 or hour < 6
	if is_night:
		GameState.world_time = 6.0 * 3600.0
		GameState.stats.fatigue = 100.0
		GameState.stats.health = minf(100.0, GameState.stats.health + 30.0)
		Sfx.play_ui("eat")
		GameState.notify("Tu te réveilles reposé au lever du jour.")
	else:
		GameState.notify("Le soleil brille encore, impossible de dormir.")


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	if kind == "campfire" or kind == "furnace":
		add_to_group("craft_station")
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
	for child in find_children("*", "MeshInstance3D"):
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
		"stairs":
			_build_stairs()
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
	# Bâti de porte (cadre fixe)
	_add_box(Vector3(0.1, 2.1, 0.16), Vector3(-0.45, 1.05, 0.0), Color(0.42, 0.3, 0.18))
	_add_box(Vector3(0.1, 2.1, 0.16), Vector3(0.45, 1.05, 0.0), Color(0.42, 0.3, 0.18))
	_add_box(Vector3(1.0, 0.1, 0.16), Vector3(0.0, 2.05, 0.0), Color(0.42, 0.3, 0.18))

	# Pivot et battant de porte ouvrant
	_door_pivot = Node3D.new()
	_door_pivot.position = Vector3(-0.4, 0.0, 0.0)
	add_child(_door_pivot)

	var panel := MeshInstance3D.new()
	var panel_mesh := BoxMesh.new()
	panel_mesh.size = Vector3(0.8, 1.95, 0.08)
	panel.mesh = panel_mesh
	panel.position = Vector3(0.4, 1.0, 0.0)
	panel.material_override = _make_material(Color(0.52, 0.38, 0.24))
	_door_pivot.add_child(panel)

	var knob := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.06
	sphere.radial_segments = 6
	sphere.rings = 3
	knob.mesh = sphere
	knob.position = Vector3(0.72, 1.0, 0.06)
	knob.material_override = _make_material(Color(0.8, 0.65, 0.2))
	_door_pivot.add_child(knob)

	_door_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.8, 1.95, 0.12)
	_door_shape.shape = box
	_door_shape.position = Vector3(0.4, 1.0, 0.0)
	_door_pivot.add_child(_door_shape)

	_apply_door_state()

func _build_stairs() -> void:
	var step_count := 4
	var step_height := 0.25
	var step_depth := 0.25
	for i in step_count:
		var h := (i + 1) * step_height
		var y := h * 0.5
		var z := 0.375 - i * step_depth
		_add_box(Vector3(1.0, h, step_depth), Vector3(0.0, y, z), Color(0.48, 0.35, 0.22))

	# Limons latéraux (rambardes décoratives)
	_add_box(Vector3(0.08, 0.8, 1.0), Vector3(-0.46, 0.6, 0.0), Color(0.38, 0.26, 0.16))
	_add_box(Vector3(0.08, 0.8, 1.0), Vector3(0.46, 0.6, 0.0), Color(0.38, 0.26, 0.16))

	# Collision en pente douce pour une ascension fluide
	var ramp_shape := CollisionShape3D.new()
	var ramp_box := BoxShape3D.new()
	ramp_box.size = Vector3(1.0, 0.15, 1.42)
	ramp_shape.shape = ramp_box
	ramp_shape.position = Vector3(0.0, 0.5, 0.0)
	ramp_shape.rotation.x = deg_to_rad(-45.0)
	add_child(ramp_shape)

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
