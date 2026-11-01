class_name Island
extends Node3D
## Génère l'île de façon procédurale : relief, couleurs, collision, végétation.
##
## M0 : un seul îlot, généré au démarrage avec une graine aléatoire.
## Les jalons suivants remplaceront ce générateur par des scènes de zones
## (village, phare, épave...) chargées à la demande.

const ISLAND_SIZE := 260.0
const GRID_RES := 96
const PROP_COUNT := 70
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

	_build_terrain()
	_spawn_props()


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
		if height > 9.0:
			prop.kind = "rocher"
		elif rng.randf() < 0.55:
			prop.kind = "arbre"
		else:
			prop.kind = "buisson"

		prop.position = Vector3(x, height, z)
		prop.rotation.y = rng.randf() * TAU
		add_child(prop)
		placed += 1
