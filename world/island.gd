class_name Island
extends Node3D
## Génère l'île de façon procédurale : relief, couleurs, collision, végétation.
##
## M0 : un seul îlot, généré au démarrage avec une graine aléatoire.
## La graine est mémorisée dans GameState.world_seed et sauvegardée, afin
## qu'un chargement retrouve exactement le même relief.

const ISLAND_SIZE := 260.0
const GRID_RES := 96
const PROP_COUNT := 80
const SEA_LEVEL := 0.0

var _noise: FastNoiseLite
var _mesh_instance: MeshInstance3D
var _generated := false


func _ready() -> void:
	generate()


func generate(seed_value: int = 0) -> void:
	if _generated:
		return
	_generated = true

	_noise = FastNoiseLite.new()
	_noise.seed = seed_value if seed_value != 0 else randi()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.006
	_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise.fractal_octaves = 4

	GameState.world_seed = _noise.seed

	_build_terrain()
	_spawn_props()
	_spawn_boat()
	_spawn_crops()


## Détruit le monde et le reconstruit avec une autre graine (chargement).
func regenerate(seed_value: int) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_generated = false
	_mesh_instance = null
	generate(seed_value)


## Hauteur du terrain (y monde) à une position donnée.
func get_height_at(x: float, z: float) -> float:
	if _noise == null:
		return SEA_LEVEL

	var distance := Vector2(x, z).length() / (ISLAND_SIZE * 0.5)
	var falloff := clampf(1.0 - distance * distance, 0.0, 1.0)
	var n := _noise.get_noise_2d(x, z) * 0.5 + 0.5
	var height := pow(n, 1.7) * 26.0 * falloff
	height -= 3.5 * (1.0 - falloff)
	return height


## Point de départ praticable, près du centre de l'île.
func find_spawn_point() -> Vector3:
	var radii: Array[float] = [0.0, 8.0, 16.0, 24.0, 34.0, 44.0]
	for radius in radii:
		for step in 12:
			var angle := step * TAU / 12.0
			var x: float = cos(angle) * radius
			var z: float = sin(angle) * radius
			var height := get_height_at(x, z)
			if height > 2.5 and height < 8.0:
				return Vector3(x, height + 1.2, z)
	return Vector3(0.0, 30.0, 0.0)


func get_mesh_instance() -> MeshInstance3D:
	return _mesh_instance


# --- Construction du terrain -------------------------------------------------

func _build_terrain() -> void:
	var step := ISLAND_SIZE / float(GRID_RES)
	var vertices_per_side := GRID_RES + 1

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)

	for gz in vertices_per_side:
		for gx in vertices_per_side:
			var x := -ISLAND_SIZE * 0.5 + gx * step
			var z := -ISLAND_SIZE * 0.5 + gz * step
			var height := get_height_at(x, z)
			surface.set_color(_color_for_height(height))
			surface.set_normal(_normal_at(x, z, step))
			surface.set_uv(Vector2(gx, gz) / float(GRID_RES))
			surface.add_vertex(Vector3(x, height, z))

	for gz in GRID_RES:
		for gx in GRID_RES:
			var i0 := gz * vertices_per_side + gx
			var i1 := i0 + 1
			var i2 := i0 + vertices_per_side
			var i3 := i2 + 1
			# Ordre horaire (sens des faces avant dans Godot), vu du dessus.
			surface.add_index(i0)
			surface.add_index(i1)
			surface.add_index(i2)
			surface.add_index(i1)
			surface.add_index(i3)
			surface.add_index(i2)

	var mesh: ArrayMesh = surface.commit()

	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	material.metallic = 0.0

	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "Terrain"
	_mesh_instance.mesh = mesh
	_mesh_instance.material_override = material
	add_child(_mesh_instance)

	var body := StaticBody3D.new()
	body.name = "TerrainBody"
	body.collision_layer = 1
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	collision.shape = mesh.create_trimesh_shape()
	body.add_child(collision)
	add_child(body)


func _normal_at(x: float, z: float, step: float) -> Vector3:
	var left := get_height_at(x - step, z)
	var right := get_height_at(x + step, z)
	var back := get_height_at(x, z - step)
	var front := get_height_at(x, z + step)
	return Vector3(left - right, 2.0 * step, back - front).normalized()


func _color_for_height(height: float) -> Color:
	if height < 0.6:
		return Color(0.72, 0.68, 0.52)
	if height < 2.2:
		return Color(0.87, 0.80, 0.58)
	if height < 9.0:
		return Color(0.28, 0.48, 0.22)
	if height < 14.0:
		return Color(0.42, 0.40, 0.34)
	return Color(0.82, 0.83, 0.86)


# --- Végétation --------------------------------------------------------------

func _spawn_props() -> void:
	var scene: PackedScene = load("res://world/harvestable.tscn")
	if scene == null:
		push_error("[Island] harvestable.tscn introuvable")
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = 1234567

	var placed := 0
	var attempts := 0
	while placed < PROP_COUNT and attempts < 4000:
		attempts += 1
		var angle := rng.randf() * TAU
		var radius := sqrt(rng.randf()) * ISLAND_SIZE * 0.44
		var x := cos(angle) * radius
		var z := sin(angle) * radius
		var height := get_height_at(x, z)
		if height < 1.4:
			continue

		var prop: Harvestable = scene.instantiate()
		if height < 1.5:
			prop.kind = "argile"
		elif height < 4.0:
			prop.kind = "palmier" if rng.randf() < 0.6 else ("seed" if rng.randf() < 0.3 else "buisson")
		elif height > 12.0:
			prop.kind = "fer"
		elif height > 9.0:
			prop.kind = "rocher"
		elif rng.randf() < 0.55:
			prop.kind = "arbre"
		else:
			prop.kind = "buisson"

		prop.position = Vector3(x, height, z)
		prop.rotation.y = rng.randf() * TAU
		prop.save_id = placed
		add_child(prop)
		placed += 1


func _spawn_boat() -> void:
	var boat := Boat.new()
	boat.name = "Boat"
	boat.position = Vector3(0.0, -2.0, 0.0)
	add_child(boat)


func _spawn_crops() -> void:
	var count := 6
	var rng := RandomNumberGenerator.new()
	rng.seed = 9876543
	var placed := 0
	var attempts := 0
	while placed < count and attempts < 2000:
		attempts += 1
		var angle := rng.randf() * TAU
		var radius := sqrt(rng.randf()) * ISLAND_SIZE * 0.44
		var x := cos(angle) * radius
		var z := sin(angle) * radius
		var height := get_height_at(x, z)
		if height < 4.0:
			continue
		var crop := Crop.new()
		crop.item_id = "berry"
		crop.position = Vector3(x, height, z)
		crop.save_id = placed
		add_child(crop)
		placed += 1


# --- Sauvegarde de l'état du monde ------------------------------------------

## Ressources épuisées, cultures plantées et bateau. Les ressources intactes ne
## sont pas listées : tout ce qui n'est pas dans la sauvegarde est « neuf ».
func to_save_data() -> Dictionary:
	var harvested: Array = []
	var crops: Array = []
	var boat_state := {}
	for child in get_children():
		if child is Harvestable and child.save_id >= 0 and child.is_depleted():
			harvested.append(child.get_save_state())
		elif child is Crop and child.save_id >= 0 and child.is_planted():
			crops.append(child.get_save_state())
		elif child is Boat:
			boat_state = child.get_save_state()
	return {"harvestables": harvested, "crops": crops, "boat": boat_state}


## Applique l'état sauvegardé. Les entrées invalides sont ignorées ; tout ce qui
## n'est pas listé est remis à neuf (le monde a pu changer depuis la sauvegarde).
func apply_save_data(data: Dictionary) -> void:
	var harvested := {}
	var raw_harvested: Variant = data.get("harvestables", [])
	if typeof(raw_harvested) == TYPE_ARRAY:
		for entry in raw_harvested:
			if typeof(entry) == TYPE_DICTIONARY and _is_num(entry.get("id")):
				harvested[int(entry["id"])] = float(entry["regrow_left"]) if _is_num(entry.get("regrow_left")) else 0.0

	var planted := {}
	var raw_crops: Variant = data.get("crops", [])
	if typeof(raw_crops) == TYPE_ARRAY:
		for entry in raw_crops:
			if typeof(entry) == TYPE_DICTIONARY and _is_num(entry.get("id")):
				planted[int(entry["id"])] = float(entry["progress"]) if _is_num(entry.get("progress")) else 0.0

	for child in get_children():
		if child is Harvestable and child.save_id >= 0:
			var is_gone: bool = harvested.has(child.save_id)
			child.apply_save_state(is_gone, float(harvested.get(child.save_id, 0.0)))
		elif child is Crop and child.save_id >= 0:
			var is_planted: bool = planted.has(child.save_id)
			child.apply_save_state(is_planted, float(planted.get(child.save_id, 0.0)))
		elif child is Boat:
			var boat_state: Variant = data.get("boat", {})
			if typeof(boat_state) == TYPE_DICTIONARY and not (boat_state as Dictionary).is_empty():
				child.apply_save_state(boat_state)


func get_boat() -> Boat:
	for child in get_children():
		if child is Boat:
			return child
	return null


func _is_num(value: Variant) -> bool:
	return (typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT) and is_finite(float(value))
