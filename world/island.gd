class_name Island
extends Node3D
## Génère l'île de façon procédurale : relief, couleurs, collision, végétation.
##
## M0 : un seul îlot, généré au démarrage avec une graine aléatoire.
## La graine est mémorisée dans GameState.world_seed et sauvegardée, afin
## qu'un chargement retrouve exactement le même relief.

const ISLAND_SIZE := 520.0          # Île principale agrandie (~520 m de diamètre)
const GRID_RES := 240               # Grille de terrain plus détaillée
const SEA_LEVEL := 0.0

## Biomes de surface. La plage et les sommets sont déterminés par l'altitude,
## les autres par un bruit basse fréquence + une modulation angulaire.
const BIOME_PLAINS := 0
const BIOME_FOREST := 1
const BIOME_WOODLAND := 2
const BIOME_HIGHLANDS := 3
const BIOME_FARM := 4
const BIOME_BEACH := 5           # Nouveaux biomes
const BIOME_PLAINS_PLATEAU := 6  # Plateaux agricoles
const BIOME_MEADOW := 7          # Préaux fleuris
const BIOME_MOUNTAIN := 8        # Sommets rocheux
const BIOME_SECONDARY_ISLAND := 9 # Îlots secondaires

## Altitudes limites.
const BEACH_MAX_HEIGHT := 2.4
const FARM_RADIUS := 22.0
const MOUNTAIN_TOP_HEIGHT := 30.0

## Radius de detection d'une grotte pour l'ambiance dark/torche.
const CAVE_PROXIMITY := 5.0
## nombre maxi de grottes générées par île.
const CAVE_COUNT := 8           # Augmenté de 6 à 8

## Positions des grottes stockées pour la détection d'ambiance.
var caves: Array = []

## Facteur d'extension pour les îles secondaires.
const SECONDARY_ISLAND_RADIUS := 340.0   # rayon à partir duquel apparaissent les îles secondaires
const SECONDARY_ISLAND_COUNT := 3        # nombre d'îlots secondaires

var _noise: FastNoiseLite
var _noise2: FastNoiseLite
var _biome_noise: FastNoiseLite
var _biome_phase := 0.0
var _farm_center := Vector2.ZERO
var _mesh_instance: MeshInstance3D
var _generated := false


func _ready() -> void:
	generate()


## Demi-largeur du monde (rayon de l'île), pour valider les positions sauvegardées.
func world_radius() -> float:
	return ISLAND_SIZE * 0.5


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
	_noise2 = FastNoiseLite.new()
	_noise2.seed = _noise.seed + 777
	_noise2.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise2.frequency = 0.004
	_noise2.fractal_type = FastNoiseLite.FRACTAL_FBM
	_noise2.fractal_octaves = 3
	_biome_noise = FastNoiseLite.new()
	_biome_noise.seed = _noise.seed + 1234
	_biome_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_biome_noise.frequency = 0.0035
	_biome_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_biome_noise.fractal_octaves = 2

	_biome_phase = float(abs(_noise.seed) % 1000) / 1000.0 * TAU
	var farm_angle := _biome_phase * 1.7
	_farm_center = Vector2(cos(farm_angle), sin(farm_angle)) * (ISLAND_SIZE * 0.10)

	GameState.world_seed = _noise.seed

	_build_terrain()
	_spawn_props()
	_generate_caves()
	_spawn_secondary_islands()
	_spawn_boat()
	_spawn_quad()
	_spawn_crops()
	_spawn_trader()


## Détruit le monde et le reconstruit avec une autre graine (chargement).
func regenerate(seed_value: int) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_generated = false
	_mesh_instance = null
	generate(seed_value)


## Hauteur du terrain (y monde) à une position donnée.
## Le relief est ensuite modelé par biome : plaines et ferme aplaties,
## forêt légèrement adoucie, hauteurs rocheuses accentuées.
func get_height_at(x: float, z: float) -> float:
	if _noise == null:
		return SEA_LEVEL

	var distance := Vector2(x, z).length() / (ISLAND_SIZE * 0.5)
	var falloff := clampf(1.0 - distance * distance, 0.0, 1.0)
	var n := _noise.get_noise_2d(x, z) * 0.5 + 0.5
	var height := pow(n, 1.7) * 26.0 * falloff
	height -= 3.5 * (1.0 - falloff)
	if _noise2 != null:
		var n2 := _noise2.get_noise_2d(x, z) * 0.5 + 0.5
		height += pow(n2, 1.6) * 12.0 * falloff

	var v := _sector_value(x, z)
	var forest_w := _band_weight(v, 0.2, 1.2, 0.22)    # secteur forêt (moins élevé)
	var plateau_w := _band_weight(v, 3.6, 4.6, 0.22)   # secteur plateau/plaine agricole (plat)
	var mountain_w := _band_weight(v, 6.8, 7.9, 0.22)  # secteur montagne (accentué)
	if forest_w > 0.0:
		height *= lerpf(1.0, 0.92, forest_w)   # forêt un peu plus douce
	if plateau_w > 0.0:
		height = lerpf(height, 3.0, 0.85 * falloff * plateau_w)   # plateau plat
	if mountain_w > 0.0:
		height *= lerpf(1.0, 1.28, mountain_w)   # montagnes plus hautes

	# Zone agricole : plateau plat garanti, fondu progressif jusqu'au bord.
	var farm_dist := Vector2(x, z).distance_to(_farm_center)
	if farm_dist < FARM_RADIUS:
		var flat := clampf(1.0 - farm_dist / FARM_RADIUS, 0.0, 1.0)
		height = lerpf(height, 3.0, 0.85 * flat)
	return height


## Biome de surface à une position (hors plage/sommets, gérés par l'altitude).
## Combine un bruit basse fréquence et une modulation angulaire pour garantir
## des régions variées (plaines, forêt, bocage, hauteurs) sur chaque île.
func _biome_at(x: float, z: float) -> int:
	if _biome_noise == null:
		return BIOME_WOODLAND
	var height := get_height_at(x, z)

	# Plage : altitude basse, proche du bord.
	if height < BEACH_MAX_HEIGHT and height >= SEA_LEVEL:
		return BIOME_BEACH

	# Sommets rocheux : très haute altitude.
	if height > 22.0:
		return BIOME_MOUNTAIN

	# Îles secondaires : hors de l'île principale.
	if Vector2(x, z).length() > ISLAND_SIZE * 0.5 + 60.0:
		return BIOME_SECONDARY_ISLAND

	# Zone agricole principale.
	if Vector2(x, z).distance_to(_farm_center) < FARM_RADIUS:
		return BIOME_FARM

	var v := _sector_value(x, z)
	if v < 1.2:
		return BIOME_FOREST
	if v < 2.2:
		return BIOME_MEADOW
	if v < 3.6:
		return BIOME_PLAINS
	if v < 4.6:
		return BIOME_PLAINS_PLATEAU
	if v < 6.8:
		return BIOME_WOODLAND
	return BIOME_HIGHLANDS


## Coordonnée continue de biome (0..4) : secteurs angulaires déformés par un
## bruit basse fréquence. Garantit de grandes régions variées sur chaque île.
func _sector_value(x: float, z: float) -> float:
	if _biome_noise == null:
		return 0.0
	var sector := (atan2(z, x) + PI) / TAU
	var warp := _biome_noise.get_noise_2d(x, z) * 0.16
	return fposmod(sector + warp, 1.0) * 8.0   # 8 biomes au lieu de 4


## Poids lissé d'un intervalle [lo, hi] avec fondu de largeur `blend` aux bords.
func _band_weight(v: float, lo: float, hi: float, blend: float) -> float:
	if v <= lo or v >= hi:
		return 0.0
	var w := 1.0
	if v < lo + blend:
		w = (v - lo) / blend
	if v > hi - blend:
		w = minf(w, (hi - v) / blend)
	w = clampf(w, 0.0, 1.0)
	return w * w * (3.0 - 2.0 * w)


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
			var biome := _biome_at(x, z)
			surface.set_color(_color_for(biome, height))
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


func _color_for(biome: int, height: float) -> Color:
	# Plage et fonds marins.
	if height < -1.0:
		return Color(0.34, 0.40, 0.30)
	if height < 1.1:
		return Color(0.58, 0.52, 0.36)
	if height < BEACH_MAX_HEIGHT:
		return Color(0.78, 0.70, 0.47)
	# Sommets rocheux.
	if height > 22.0:
		return Color(0.82, 0.83, 0.86)
	if height > 15.0:
		return Color(0.52, 0.49, 0.45)
	if height > 12.0:
		return Color(0.46, 0.44, 0.40)

	# Couleurs des biomes de plaine.
	match biome:
		BIOME_FARM:
			return Color(0.40, 0.31, 0.19)
		BIOME_FOREST:
			return Color(0.13, 0.30, 0.13)
		BIOME_PLAINS:
			return Color(0.46, 0.64, 0.27)
		BIOME_WOODLAND:
			return Color(0.24, 0.42, 0.19)
		BIOME_MEADOW:
			return Color(0.38, 0.58, 0.22)      # Vert plus clair, pré fleuri
		BIOME_PLAINS_PLATEAU:
			return Color(0.42, 0.48, 0.24)      # Plateau agricole plus foncé
		BIOME_HIGHLANDS:
			return Color(0.36, 0.40, 0.28)
		BIOME_MOUNTAIN:
			return Color(0.50, 0.48, 0.44)
		BIOME_SECONDARY_ISLAND:
			return Color(0.20, 0.45, 0.20)      # Jungle/îlot tropical
		_:
			return Color(0.36, 0.40, 0.28)


# --- Végétation --------------------------------------------------------------

func _spawn_props() -> void:
	var scene: PackedScene = load("res://world/harvestable.tscn")
	if scene == null:
		push_error("[Island] harvestable.tscn introuvable")
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = _noise.seed + 1337

	# Budgets par biome : garantit une forêt dense, des plaines aérées,
	# un bocage mixte, des hauteurs minérales et un carré agricole.
	var next_id := 0
	next_id = _scatter_forest(scene, rng, next_id)
	next_id = _scatter_biome(scene, rng, BIOME_PLAINS, 120, next_id)
	next_id = _scatter_biome(scene, rng, BIOME_WOODLAND, 100, next_id)
	next_id = _scatter_biome(scene, rng, BIOME_HIGHLANDS, 80, next_id)
	next_id = _scatter_biome(scene, rng, BIOME_MEADOW, 60, next_id)
	next_id = _scatter_biome(scene, rng, BIOME_PLAINS_PLATEAU, 40, next_id)
	next_id = _scatter_biome(scene, rng, BIOME_FARM, 24, next_id)
	next_id = _scatter_biome(scene, rng, BIOME_MOUNTAIN, 30, next_id)
	next_id = _scatter_beach(scene, rng, 90, next_id)

	_ensure_deep_minerals(scene)


## Forêt dense : groupes d'arbres serrés (clairières entre les bosquets),
## pour un vrai rendu de sous-bois sans saturer toute l'île.
func _scatter_forest(scene: PackedScene, rng: RandomNumberGenerator, id_start: int) -> int:
	var placed := 0
	var clusters := 0
	while placed < 240 and clusters < 70:
		clusters += 1
		var anchor := Vector3.ZERO
		var found := false
		for attempt in 40:
			var angle := rng.randf() * TAU
			var radius := sqrt(rng.randf()) * ISLAND_SIZE * 0.44
			var ax := cos(angle) * radius
			var az := sin(angle) * radius
			var ah := get_height_at(ax, az)
			if ah < BEACH_MAX_HEIGHT or ah > 15.0:
				continue
			if _biome_at(ax, az) != BIOME_FOREST:
				continue
			anchor = Vector3(ax, ah, az)
			found = true
			break
		if not found:
			continue

		var cluster_size := rng.randi_range(6, 13)
		for tree_index in cluster_size:
			if placed >= 240:
				break
			var off := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * 11.0
			var fx := anchor.x + off.x
			var fz := anchor.z + off.y
			var fh := get_height_at(fx, fz)
			if fh < BEACH_MAX_HEIGHT or fh > 15.0:
				continue
			if _biome_at(fx, fz) != BIOME_FOREST:
				continue
			_spawn_prop(scene, "arbre", Vector3(fx, fh, fz), rng.randf() * TAU, id_start + placed)
			placed += 1
	return id_start + placed


## Disperse `count` ressources d'un biome donné, en rejetant les positions hors
## biome/altitude. Retourne le prochain identifiant de sauvegarde libre.
func _scatter_biome(scene: PackedScene, rng: RandomNumberGenerator, biome: int, count: int, id_start: int) -> int:
	var placed := 0
	var attempts := 0
	var max_attempts := count * 160
	while placed < count and attempts < max_attempts:
		attempts += 1
		var angle := rng.randf() * TAU
		var radius := sqrt(rng.randf()) * ISLAND_SIZE * 0.46
		var x := cos(angle) * radius
		var z := sin(angle) * radius
		var height := get_height_at(x, z)
		if height < BEACH_MAX_HEIGHT or height > 15.0:
			continue
		if _biome_at(x, z) != biome:
			continue
		var kind := _pick_prop(biome, height, rng)
		if kind.is_empty():
			continue
		_spawn_prop(scene, kind, Vector3(x, height, z), rng.randf() * TAU, id_start + placed)
		placed += 1
	return id_start + placed


## Disperse la végétation de plage (palmiers, argile, buissons) sur le littoral.
func _scatter_beach(scene: PackedScene, rng: RandomNumberGenerator, count: int, id_start: int) -> int:
	var placed := 0
	var attempts := 0
	var max_attempts := count * 160
	while placed < count and attempts < max_attempts:
		attempts += 1
		var angle := rng.randf() * TAU
		var radius := sqrt(rng.randf()) * ISLAND_SIZE * 0.46
		var x := cos(angle) * radius
		var z := sin(angle) * radius
		var height := get_height_at(x, z)
		if height < 0.8 or height > BEACH_MAX_HEIGHT:
			continue
		if Vector2(x, z).length() < ISLAND_SIZE * 0.32:
			continue
		var kind := _pick_beach_prop(rng)
		if kind.is_empty():
			continue
		_spawn_prop(scene, kind, Vector3(x, height, z), rng.randf() * TAU, id_start + placed)
		placed += 1
	return id_start + placed


func _spawn_prop(scene: PackedScene, kind: String, pos: Vector3, yaw: float, save_id: int) -> void:
	var prop: Harvestable = scene.instantiate()
	prop.kind = kind
	prop.position = pos
	prop.rotation.y = yaw
	prop.save_id = save_id
	add_child(prop)


## Choisit une ressource cohérente avec le biome et l'altitude.
func _pick_prop(biome: int, height: float, rng: RandomNumberGenerator) -> String:
	if height > 14.0:
		return "or" if rng.randf() < 0.3 else "charbon"
	if height > 12.0:
		return "fer" if rng.randf() < 0.5 else "cristal"
	if height > 9.0:
		return "rocher" if rng.randf() < 0.75 else "arbre"
	if height > 7.0:
		return "fer" if rng.randf() < 0.6 else "cristal"

	var r := rng.randf()
	match biome:
		BIOME_FOREST:
			if r < 0.78:
				return "arbre"
			if r < 0.90:
				return "buisson"
			if r < 0.97:
				return "seed"
			return "rocher"
		BIOME_PLAINS:
			if r < 0.22:
				return "arbre"
			if r < 0.62:
				return "buisson"
			if r < 0.90:
				return "seed"
			return "rocher"
		BIOME_WOODLAND:
			if r < 0.50:
				return "arbre"
			if r < 0.68:
				return "buisson"
			if r < 0.85:
				return "rocher"
			return "fer"
		BIOME_HIGHLANDS:
			if r < 0.50:
				return "rocher"
			if r < 0.72:
				return "fer"
			if r < 0.88:
				return "cristal"
			return "arbre"
		BIOME_MEADOW:
			if r < 0.30:
				return "buisson"
			if r < 0.65:
				return "seed"
			return "arbre"
		BIOME_PLAINS_PLATEAU:
			if r < 0.25:
				return "arbre"
			if r < 0.55:
				return "buisson"
			if r < 0.80:
				return "seed"
			return "rocher"
		BIOME_MOUNTAIN:
			if r < 0.40:
				return "rocher"
			if r < 0.65:
				return "fer"
			if r < 0.85:
				return "cristal"
			return "arbre"
		BIOME_BEACH:
			if r < 0.42:
				return "palmier"
			if r < 0.60:
				return "argile"
			if r < 0.75:
				return "buisson"
			if r < 0.84:
				return "rocher"
			return ""
		BIOME_SECONDARY_ISLAND:
			if r < 0.30:
				return "palmier"
			if r < 0.50:
				return "cristal"
			if r < 0.70:
				return "buisson"
			if r < 0.85:
				return "rocher"
			if r < 0.95:
				return "or"
			return "arbre"
	return "arbre"


func _pick_beach_prop(rng: RandomNumberGenerator) -> String:
	var r := rng.randf()
	if r < 0.42:
		return "palmier"
	if r < 0.60:
		return "argile"
	if r < 0.75:
		return "buisson"
	if r < 0.84:
		return "rocher"
	return ""



## Garantit la présence de charbon et d'or sur les points les plus hauts,
## même si le tirage aléatoire n'a rien placé au-dessus du seuil de profondeur.
func _ensure_deep_minerals(scene: PackedScene) -> void:
	var peaks: Array[Vector3] = []
	var peak_heights: Array[float] = []
	for i in range(-52, 53):
		for j in range(-52, 53):
			var x := i * 4.0
			var z := j * 4.0
			var h := get_height_at(x, z)
			if h <= 1.5:
				continue
			peaks.append(Vector3(x, h, z))
			peak_heights.append(h)
	if peaks.is_empty():
		return

	# Tri décroissant simple pour choisir les quatre sommets les plus hauts.
	var order: Array[int] = []
	for idx in peaks.size():
		order.append(idx)
	order.sort_custom(func(a: int, b: int) -> bool: return peak_heights[a] > peak_heights[b])

	var deep_kinds := ["charbon", "charbon", "or", "or"]
	for k in mini(deep_kinds.size(), order.size()):
		var prop: Harvestable = scene.instantiate()
		prop.kind = deep_kinds[k]
		prop.position = peaks[order[k]]
		prop.save_id = 9000 + k
		add_child(prop)


## Point d'échouage du bateau sur l'eau près du rivage (hauteur sous l'eau entre -2.0 et -0.3).
## Rayons dynamiques proportionnels à ISLAND_SIZE.
func find_boat_spawn_point() -> Vector3:
	var radii: Array[float] = [
		ISLAND_SIZE * 0.38,
		ISLAND_SIZE * 0.40,
		ISLAND_SIZE * 0.42,
		ISLAND_SIZE * 0.44,
		ISLAND_SIZE * 0.46,
		ISLAND_SIZE * 0.48,
		ISLAND_SIZE * 0.50
	]
	for radius in radii:
		for step in 24:
			var angle := step * TAU / 24.0
			var x: float = cos(angle) * radius
			var z: float = sin(angle) * radius
			var height := get_height_at(x, z)
			if height >= -2.0 and height <= -0.3:
				return Vector3(x, 0.0, z)
	return Vector3(0.0, 0.0, ISLAND_SIZE * 0.25)


func _spawn_boat() -> void:
	var boat := Boat.new()
	boat.name = "Boat"
	boat.position = find_boat_spawn_point()
	add_child(boat)


func _spawn_quad() -> void:
	var quad := Quad.new()
	quad.name = "Quad"
	quad.position = Vector3(40.0, get_height_at(40.0, 40.0), 40.0)
	add_child(quad)


func _spawn_trader() -> void:
	var trader := Trader.new()
	trader.name = "Trader"
	trader.position = Vector3(60.0, get_height_at(60.0, 60.0), 60.0)
	add_child(trader)


func _generate_caves() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _noise.seed + 4242
	var attempts := 0
	var generated: Array[Vector3] = []
	while generated.size() < CAVE_COUNT and attempts < 600:
		attempts += 1
		var angle := rng.randf() * TAU
		var radius := sqrt(rng.randf()) * ISLAND_SIZE * 0.42
		var x := cos(angle) * radius
		var z := sin(angle) * radius
		var height := get_height_at(x, z)
		# Une grotte s'ouvre uniquement sur les flancs rocheux élevés.
		if height < 10.0:
			continue
		var pos := Vector3(x, height, z)
		generated.append(pos)
		_build_cave_entrance(pos, rng.randf() * TAU)

	# Filet de sécurité : au moins une grotte sur le point culminant.
	if generated.is_empty():
		var apex := Vector3.ZERO
		var apex_height := -INF
		for i in range(-52, 53):
			for j in range(-52, 53):
				var px := i * 4.0
				var pz := j * 4.0
				var ph := get_height_at(px, pz)
				if ph > apex_height:
					apex_height = ph
					apex = Vector3(px, ph, pz)
		if apex_height > 1.5:
			generated.append(apex)
			_build_cave_entrance(apex, 0.0)

	self.caves = generated


## Entrée de grotte visible : arche de roche sombre, creusée dans le flanc.
func _build_cave_entrance(pos: Vector3, yaw: float) -> void:
	var entrance := Node3D.new()
	entrance.name = "CaveEntrance"
	entrance.position = pos
	entrance.rotation.y = yaw

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.15, 0.14)
	mat.roughness = 1.0

	# Deux montants massifs.
	for side in [-1.0, 1.0]:
		var pillar := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(1.3, 3.2, 1.3)
		pillar.mesh = box
		pillar.position = Vector3(side * 1.7, 1.6, 0.0)
		pillar.material_override = mat
		entrance.add_child(pillar)

	# Linteau.
	var lintel := MeshInstance3D.new()
	var lintel_box := BoxMesh.new()
	lintel_box.size = Vector3(4.7, 1.0, 1.3)
	lintel.mesh = lintel_box
	lintel.position = Vector3(0.0, 3.7, 0.0)
	lintel.material_override = mat
	entrance.add_child(lintel)

	# Fond noir : donne l'impression d'une cavité qui s'enfonce.
	var dark := MeshInstance3D.new()
	var dark_box := BoxMesh.new()
	dark_box.size = Vector3(2.6, 3.0, 0.2)
	dark.mesh = dark_box
	dark.position = Vector3(0.0, 1.5, -0.9)
	var dark_mat := StandardMaterial3D.new()
	dark_mat.albedo_color = Color(0.01, 0.01, 0.015)
	dark_mat.roughness = 1.0
	dark.material_override = dark_mat
	entrance.add_child(dark)

	add_child(entrance)


## Spawn secondary islands with unique biomes and resources.
func _spawn_secondary_islands() -> void:
	var scene: PackedScene = load("res://world/harvestable.tscn")
	if scene == null:
		push_error("[Island] harvestable.tscn introuvable")
		return
	
	var rng := RandomNumberGenerator.new()
	rng.seed = _noise.seed + 5555
	
	for i in SECONDARY_ISLAND_COUNT:
		var island_radius := rng.randf_range(SECONDARY_ISLAND_RADIUS * 0.7, SECONDARY_ISLAND_RADIUS * 0.9)
		var island_angle := rng.randf() * TAU
		var center_x := cos(island_angle) * island_radius
		var center_z := sin(island_angle) * island_radius
		var island_center := Vector2(center_x, center_z)
		
		var island_biome := rng.randi() % 4 + 5  # 5-8 (beach, plains, meadow, mountain)
		var island_biome_noise := FastNoiseLite.new()
		island_biome_noise.seed = _noise.seed + i * 1000
		island_biome_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		island_biome_noise.frequency = 0.0025
		island_biome_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
		island_biome_noise.fractal_octaves = 1
		
		var island_spawned := 0
		var max_trees := 0
		match island_biome:
			5:  # BIOME_BEACH
				max_trees = 60
				var props := ["palmier", "buisson", "rocher", "argile"]
				for j in max_trees:
					var angle := rng.randf() * TAU
					var radius := sqrt(rng.randf()) * island_radius * 0.3
					var x := cos(angle) * radius + center_x
					var z := sin(angle) * radius + center_z
					var height := get_height_at(x, z)
					if height < 0.5 or height > BEACH_MAX_HEIGHT:
						continue
					var kind := rng.randf_range(0, len(props))
					var kind_str := props[int(kind)]
					_spawn_prop(scene, kind_str, Vector3(x, height, z), rng.randf() * TAU, island_spawned + j)
			6:  # BIOME_PLAINS_PLATEAU
				max_trees = 100
				var props := ["buisson", "seed", "rocher", "fer"]
				for j in max_trees:
					var angle := rng.randf() * TAU
					var radius := sqrt(rng.randf()) * island_radius * 0.35
					var x := cos(angle) * radius + center_x
					var z := sin(angle) * radius + center_z
					var height := get_height_at(x, z)
					if height < 1.5 or height > 12.0:
						continue
					var kind_idx := rng.randf_range(0, len(props))
					var kind_str := props[int(kind_idx)]
					_spawn_prop(scene, kind_str, Vector3(x, height, z), rng.randf() * TAU, island_spawned + j)
			7:  # BIOME_MEADOW
				max_trees = 80
				var props := ["buisson", "seed", "rocher", "cristal"]
				for j in max_trees:
					var angle := rng.randf() * TAU
					var radius := sqrt(rng.randf()) * island_radius * 0.4
					var x := cos(angle) * radius + center_x
					var z := sin(angle) * radius + center_z
					var height := get_height_at(x, z)
					if height < 2.0 or height > 15.0:
						continue
					var kind_idx := rng.randf_range(0, len(props))
					var kind_str := props[int(kind_idx)]
					_spawn_prop(scene, kind_str, Vector3(x, height, z), rng.randf() * TAU, island_spawned + j)
			8:  # BIOME_MOUNTAIN
				max_trees = 70
				var props := ["rocher", "fer", "cristal", "or"]
				for j in max_trees:
					var angle := rng.randf() * TAU
					var radius := sqrt(rng.randf()) * island_radius * 0.35
					var x := cos(angle) * radius + center_x
					var z := sin(angle) * radius + center_z
					var height := get_height_at(x, z)
					if height < 5.0 or height > 25.0:
						continue
					var kind_idx := rng.randf_range(0, len(props))
					var kind_str := props[int(kind_idx)]
					_spawn_prop(scene, kind_str, Vector3(x, height, z), rng.randf() * TAU, island_spawned + j)
	# Spawn merchant wreck and survivor
	var wreck_scene := load("res://world/merchant_wreck.tscn")
	if wreck_scene != null:
		var wreck := wreck_scene.instantiate()
		wreck.position = Vector3(
			rng.randf_range(-80.0, 80.0),
			0.0,
			rng.randf_range(-80.0, 80.0)
		)
		wreck.rotation.y = rng.randf() * TAU
		add_child(wreck)
		
		var survivor := Trader.new()
		survivor.position = wreck.position + Vector3(0.0, 0.5, 0.0)
		survivor.rotation.y = wreck.rotation.y + deg_to_rad(90.0)
		add_child(survivor)


## Vrai si le joueur est proche d'une grotte (proximité < CAVE_PROXIMITY).
## Utilisé pour activer l'éclairage sombre et l'ambiance sonore.
func is_in_cave(position: Vector3) -> bool:
	for c in caves:
		if position.distance_to(c) < CAVE_PROXIMITY:
			return true
	return false


func _spawn_crops() -> void:
	# La zone agricole est un plateau plat dédié : on y sème quelques plants.
	var count := 14
	var rng := RandomNumberGenerator.new()
	rng.seed = _noise.seed + 987654
	var placed := 0
	var attempts := 0
	while placed < count and attempts < 400:
		attempts += 1
		var off := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * (FARM_RADIUS - 3.0)
		var x := _farm_center.x + off.x
		var z := _farm_center.y + off.y
		if _biome_at(x, z) != BIOME_FARM:
			continue
		var height := get_height_at(x, z)
		if height < 2.0:
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
	var quad_state := {}
	var trader_state := {}
	for child in get_children():
		if child is Harvestable and child.save_id >= 0 and child.is_depleted():
			harvested.append(child.get_save_state())
		elif child is Crop and child.save_id >= 0 and child.is_planted():
			crops.append(child.get_save_state())
		elif child is Boat:
			boat_state = child.get_save_state()
		elif child is Quad:
			quad_state = child.get_save_state()
		elif child is Trader:
			trader_state = child.get_save_state()
	return {"harvestables": harvested, "crops": crops, "boat": boat_state, "quad": quad_state, "trader": trader_state}


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
		elif child is Quad:
			var quad_state: Variant = data.get("quad", {})
			if typeof(quad_state) == TYPE_DICTIONARY and not (quad_state as Dictionary).is_empty():
				child.apply_save_state(quad_state)
		elif child is Trader:
			var trader_state: Variant = data.get("trader", {})
			if typeof(trader_state) == TYPE_DICTIONARY and not (trader_state as Dictionary).is_empty():
				child.apply_save_state(trader_state)


func get_boat() -> Boat:
	for child in get_children():
		if child is Boat:
			return child
	return null


func get_quad() -> Quad:
	for child in get_children():
		if child is Quad:
			return child
	return null


func get_trader() -> Trader:
	for child in get_children():
		if child is Trader:
			return child
	return null


func _is_num(value: Variant) -> bool:
	return (typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT) and is_finite(float(value))
