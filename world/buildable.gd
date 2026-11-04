class_name Buildable
extends StaticBody3D
## Élément construit : fondation, mur, toit, fenêtre, porte, escalier, etc.
##
## Le visuel et la collision sont générés en code selon `kind`. La couche
## physique 4 ("construit") permet de tester les chevauchements sans toucher
## au terrain.

var kind := "foundation"
var data_id := ""
## Contenu stocké dans le coffre (item_id -> quantité).
var chest_inventory: Dictionary = {}
## État d'ouverture pour les portes et fenêtres.
var is_open: bool = false

var _door_pivot: Node3D = null
var _door_shape: CollisionShape3D = null
var _window_pivot: Node3D = null
var _window_shape: CollisionShape3D = null
var _ghost_material: StandardMaterial3D

## Cache de matériaux partagés (couleur hex → StandardMaterial3D).
## Évite de créer une nouvelle ressource par élément posé.
static var _mat_cache: Dictionary = {}

## Hauteur interne d'un mur (offset des toits pour reposer au-dessus des murs).
const WALL_H := 2.4
## Offset Y interne des dalles de toit (WALL_H + 0.06 demi-épaisseur).
const ROOF_Y := WALL_H + 0.06


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
	elif kind == "window":
		return "Fermer la fenêtre (E)" if is_open else "Ouvrir la fenêtre (E)"
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
	elif kind == "window":
		toggle_window()
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


func toggle_window() -> void:
	is_open = not is_open
	_apply_window_state()
	Sfx.play_ui("ui")
	GameState.notify("Fenêtre %s" % ("ouverte" if is_open else "fermée"))


func _apply_window_state() -> void:
	if _window_pivot != null:
		_window_pivot.rotation.y = PI * 0.5 if is_open else 0.0
	if _window_shape != null:
		_window_shape.disabled = is_open


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
		"half_wall":
			_build_half_wall()
		"roof":
			_build_roof()
		"roof_slope":
			_build_roof_slope()
		"roof_ridge":
			_build_roof_ridge()
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


# ── Fondation ────────────────────────────────────────────────────────────────

func _build_foundation() -> void:
	_add_box(Vector3(1.0, 0.2, 1.0), Vector3(0.0, 0.1, 0.0), Color(0.45, 0.32, 0.2))
	# Planches décoratives légèrement en relief pour éviter le z-fighting.
	for i in 3:
		var plank := MeshInstance3D.new()
		var plank_mesh := BoxMesh.new()
		plank_mesh.size = Vector3(0.9, 0.04, 0.26)
		plank.mesh = plank_mesh
		plank.position = Vector3(0.0, 0.21, -0.32 + i * 0.32)
		plank.material_override = _make_material(Color(0.56, 0.42, 0.27))
		add_child(plank)


# ── Mur ──────────────────────────────────────────────────────────────────────

func _build_wall() -> void:
	# Corps principal 1.0 × 2.4 × 0.16.
	_add_box(Vector3(1.0, 2.4, 0.16), Vector3(0.0, 1.2, 0.0), Color(0.52, 0.38, 0.24))
	# Planches avec micro-variation de teinte pour casser l'aspect monochrome.
	var plank_colors := [Color(0.54, 0.40, 0.26), Color(0.50, 0.36, 0.22),
						 Color(0.55, 0.41, 0.25), Color(0.49, 0.35, 0.21),
						 Color(0.53, 0.39, 0.25)]
	for i in 5:
		var plank := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.18, 2.36, 0.02)
		plank.mesh = pm
		plank.position = Vector3(-0.4 + i * 0.2, 1.2, 0.09)
		plank.material_override = _make_material(plank_colors[i])
		add_child(plank)
	# Poutre horizontale mi-hauteur.
	var beam := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.02, 0.1, 0.18)
	beam.mesh = bm
	beam.position = Vector3(0.0, 1.2, 0.0)
	beam.material_override = _make_material(Color(0.38, 0.27, 0.16))
	add_child(beam)
	# Poutre horizontale en haut.
	var top_beam := MeshInstance3D.new()
	var tbm := BoxMesh.new()
	tbm.size = Vector3(1.02, 0.1, 0.18)
	top_beam.mesh = tbm
	top_beam.position = Vector3(0.0, 2.3, 0.0)
	top_beam.material_override = _make_material(Color(0.38, 0.27, 0.16))
	add_child(top_beam)


# ── Demi-mur ─────────────────────────────────────────────────────────────────

func _build_half_wall() -> void:
	_add_box(Vector3(1.0, 1.2, 0.16), Vector3(0.0, 0.6, 0.0), Color(0.52, 0.38, 0.24))
	var plank_colors := [Color(0.54, 0.40, 0.26), Color(0.50, 0.36, 0.22),
						 Color(0.55, 0.41, 0.25), Color(0.49, 0.35, 0.21),
						 Color(0.53, 0.39, 0.25)]
	for i in 5:
		var plank := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.18, 1.16, 0.02)
		plank.mesh = pm
		plank.position = Vector3(-0.4 + i * 0.2, 0.6, 0.09)
		plank.material_override = _make_material(plank_colors[i])
		add_child(plank)
	var beam := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.02, 0.1, 0.18)
	beam.mesh = bm
	beam.position = Vector3(0.0, 1.1, 0.0)
	beam.material_override = _make_material(Color(0.38, 0.27, 0.16))
	add_child(beam)


# ── Toit plat ────────────────────────────────────────────────────────────────
## Le nœud est posé au Y de la fondation porteuse (via snap construction.gd).
## ROOF_Y = 2.46 m place la dalle exactement sur le sommet des murs (2.4 m).

func _build_roof() -> void:
	_add_box(Vector3(1.0, 0.12, 1.0), Vector3(0.0, ROOF_Y, 0.0), Color(0.48, 0.34, 0.20))
	var tile_color_a := Color(0.55, 0.38, 0.22)
	var tile_color_b := Color(0.60, 0.43, 0.27)
	for row in 3:
		var offset_x := 0.0 if row % 2 == 0 else 0.12
		for col in 4:
			var tile := MeshInstance3D.new()
			var tm := BoxMesh.new()
			tm.size = Vector3(0.22, 0.03, 0.30)
			tile.mesh = tm
			tile.position = Vector3(-0.33 + col * 0.22 + offset_x,
									ROOF_Y + 0.075, -0.32 + row * 0.32)
			tile.material_override = _make_material(
				tile_color_a if (row + col) % 2 == 0 else tile_color_b)
			add_child(tile)
	_add_collision_box(Vector3(1.0, 0.12, 1.0), Vector3(0.0, ROOF_Y, 0.0))


# ── Toit pente simple ─────────────────────────────────────────────────────────
## Pan incliné. Nœud posé à la Y de la fondation, offset ROOF_Y interne.

func _build_roof_slope() -> void:
	_add_box(Vector3(1.0, 0.1, 1.0), Vector3(0.0, ROOF_Y, 0.0), Color(0.48, 0.34, 0.20))
	var slope := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(1.0, 0.8, 1.0)
	slope.mesh = pm
	slope.position = Vector3(0.0, ROOF_Y + 0.4, 0.0)
	slope.material_override = _make_material(Color(0.52, 0.37, 0.22))
	add_child(slope)
	var tile_color_a := Color(0.55, 0.38, 0.22)
	var tile_color_b := Color(0.60, 0.43, 0.27)
	for row in 3:
		var offset_x := 0.0 if row % 2 == 0 else 0.12
		for col in 4:
			var tile := MeshInstance3D.new()
			var tm := BoxMesh.new()
			tm.size = Vector3(0.22, 0.03, 0.30)
			tile.mesh = tm
			var rz := -0.32 + row * 0.32
			var ry := ROOF_Y + 0.06 + row * 0.26
			tile.position = Vector3(-0.33 + col * 0.22 + offset_x, ry, rz)
			tile.rotation.x = deg_to_rad(-15.0)
			tile.material_override = _make_material(
				tile_color_a if (row + col) % 2 == 0 else tile_color_b)
			add_child(tile)
	_add_collision_box(Vector3(1.0, 0.8, 1.0), Vector3(0.0, ROOF_Y + 0.4, 0.0))


# ── Toit faîtage ─────────────────────────────────────────────────────────────
## Deux pans symétriques. Nœud posé à la Y de la fondation, offset ROOF_Y.

func _build_roof_ridge() -> void:
	var mat_tile := _make_material(Color(0.55, 0.38, 0.22))
	var mat_dark := _make_material(Color(0.42, 0.30, 0.18))

	for side in 2:
		var half := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(1.0, 0.7, 0.5)
		half.mesh = pm
		half.position = Vector3(0.0, ROOF_Y + 0.29, (side * 2 - 1) * 0.25)
		half.rotation.z = deg_to_rad(180.0) if side == 1 else 0.0
		half.rotation.x = deg_to_rad(180.0) if side == 1 else 0.0
		half.material_override = mat_tile
		add_child(half)

	var ridge := MeshInstance3D.new()
	var rm := BoxMesh.new()
	rm.size = Vector3(1.0, 0.08, 0.14)
	ridge.mesh = rm
	ridge.position = Vector3(0.0, ROOF_Y + 0.61, 0.0)
	ridge.material_override = mat_dark
	add_child(ridge)

	_add_box(Vector3(1.0, 0.1, 1.0), Vector3(0.0, ROOF_Y, 0.0), Color(0.48, 0.34, 0.20))
	_add_collision_box(Vector3(1.0, 0.7, 1.0), Vector3(0.0, ROOF_Y + 0.35, 0.0))


# ── Fenêtre ───────────────────────────────────────────────────────────────────
## Fenêtre haute (1.2 m) centrée dans le mur, avec bandes de remplissage,
## vitrage transparent, montants en croix et ouverture/fermeture (E).

func _build_window() -> void:
	var wood := Color(0.52, 0.38, 0.24)
	var frame := Color(0.42, 0.30, 0.18)

	# Bande inférieure de remplissage mur (sol → bas de la fenêtre).
	_add_box(Vector3(1.0, 0.75, 0.16), Vector3(0.0, 0.375, 0.0), wood)
	# Bande supérieure de remplissage mur (haut de la fenêtre → sommet du mur).
	_add_box(Vector3(1.0, 0.45, 0.16), Vector3(0.0, 2.175, 0.0), wood)

	# Cadre de fenêtre (encadrement fixe).
	# Montant gauche.
	_add_box(Vector3(0.1, 1.2, 0.16), Vector3(-0.45, 1.35, 0.0), frame)
	# Montant droit.
	_add_box(Vector3(0.1, 1.2, 0.16), Vector3(0.45, 1.35, 0.0), frame)
	# Linteau.
	_add_box(Vector3(1.0, 0.08, 0.16), Vector3(0.0, 1.96, 0.0), frame)
	# Appui de fenêtre.
	_add_box(Vector3(1.0, 0.08, 0.20), Vector3(0.0, 0.74, 0.0), frame)

	# Pivot du vitrage (battant ouvrant côté gauche).
	_window_pivot = Node3D.new()
	_window_pivot.position = Vector3(-0.38, 0.0, 0.0)
	add_child(_window_pivot)

	# Vitrage transparent (BaseMaterial3D avec alpha).
	var glass_mat := StandardMaterial3D.new()
	glass_mat.albedo_color = Color(0.78, 0.88, 1.0, 0.22)
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.roughness = 0.0
	glass_mat.metallic = 0.2
	glass_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var glass := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(0.76, 1.12, 0.04)
	glass.mesh = gm
	glass.position = Vector3(0.38, 1.35, 0.0)
	glass.material_override = glass_mat
	_window_pivot.add_child(glass)

	# Montants en croix (sur le vitrage, partie du pivot).
	var cross_mat := _make_material(frame)
	for bar in 2:
		# Horizontal.
		var h_bar := MeshInstance3D.new()
		var hm := BoxMesh.new()
		hm.size = Vector3(0.76, 0.05, 0.05)
		h_bar.mesh = hm
		h_bar.position = Vector3(0.38, 1.35 + (bar * 2 - 1) * 0.28, 0.02)
		h_bar.material_override = cross_mat
		_window_pivot.add_child(h_bar)
	# Vertical central.
	var v_bar := MeshInstance3D.new()
	var vm := BoxMesh.new()
	vm.size = Vector3(0.05, 1.12, 0.05)
	v_bar.mesh = vm
	v_bar.position = Vector3(0.38, 1.35, 0.02)
	v_bar.material_override = cross_mat
	_window_pivot.add_child(v_bar)

	# Collision du vitrage (désactivée quand ouverte).
	_window_shape = CollisionShape3D.new()
	var ws := BoxShape3D.new()
	ws.size = Vector3(0.76, 1.12, 0.08)
	_window_shape.shape = ws
	_window_shape.position = Vector3(0.38, 1.35, 0.0)
	_window_pivot.add_child(_window_shape)

	_apply_window_state()


# ── Porte ─────────────────────────────────────────────────────────────────────

func _build_door() -> void:
	# Bâti de porte (cadre fixe).
	_add_box(Vector3(0.1, 2.4, 0.16), Vector3(-0.45, 1.2, 0.0), Color(0.42, 0.3, 0.18))
	_add_box(Vector3(0.1, 2.4, 0.16), Vector3(0.45, 1.2, 0.0), Color(0.42, 0.3, 0.18))
	_add_box(Vector3(1.0, 0.1, 0.16), Vector3(0.0, 2.35, 0.0), Color(0.42, 0.3, 0.18))

	# Pivot et battant ouvrant.
	_door_pivot = Node3D.new()
	_door_pivot.position = Vector3(-0.4, 0.0, 0.0)
	add_child(_door_pivot)

	var panel := MeshInstance3D.new()
	var panel_mesh := BoxMesh.new()
	panel_mesh.size = Vector3(0.8, 2.25, 0.08)
	panel.mesh = panel_mesh
	panel.position = Vector3(0.4, 1.13, 0.0)
	panel.material_override = _make_material(Color(0.52, 0.38, 0.24))
	_door_pivot.add_child(panel)

	# Rainures décoratives sur le battant.
	for rail in 3:
		var r := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(0.68, 0.06, 0.02)
		r.mesh = rm
		r.position = Vector3(0.4, 0.55 + rail * 0.8, 0.05)
		r.material_override = _make_material(Color(0.40, 0.28, 0.16))
		_door_pivot.add_child(r)

	# Poignée.
	var knob := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.06
	sphere.radial_segments = 6
	sphere.rings = 3
	knob.mesh = sphere
	knob.position = Vector3(0.72, 1.13, 0.07)
	knob.material_override = _make_material(Color(0.8, 0.65, 0.2))
	_door_pivot.add_child(knob)

	_door_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.8, 2.25, 0.12)
	_door_shape.shape = box
	_door_shape.position = Vector3(0.4, 1.13, 0.0)
	_door_pivot.add_child(_door_shape)

	_apply_door_state()


# ── Escalier ──────────────────────────────────────────────────────────────────
## 5 marches montant sur 1.0 m (5 × LEVEL_STEP = 1.0 m), collision en rampe
## inclinée à ~22° pour une montée fluide.

func _build_stairs() -> void:
	const STEP_COUNT := 5
	const STEP_HEIGHT := 0.2    # = LEVEL_STEP → sommet à exactement 1.0 m
	const STEP_DEPTH := 0.18
	# Les marches occupent 5 × 0.18 = 0.90 m de profondeur sur 1.0 m → ok.

	var color_step := Color(0.54, 0.40, 0.26)   # marches plus claires
	var color_struc := Color(0.36, 0.26, 0.15)  # structure plus foncée

	for i in STEP_COUNT:
		var h := (i + 1) * STEP_HEIGHT
		var y := h * 0.5
		var z := 0.36 - i * STEP_DEPTH
		# Contremarche (structure portante, foncée).
		var riser := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(0.84, h, STEP_DEPTH)
		riser.mesh = rm
		riser.position = Vector3(0.0, y, z)
		riser.material_override = _make_material(color_struc)
		add_child(riser)
		var rc := CollisionShape3D.new()
		var rb := BoxShape3D.new()
		rb.size = Vector3(0.84, h, STEP_DEPTH)
		rc.shape = rb
		rc.position = Vector3(0.0, y, z)
		add_child(rc)
		# Surface de marche (claire, légèrement en saillie).
		var tread := MeshInstance3D.new()
		var tm := BoxMesh.new()
		tm.size = Vector3(0.90, 0.04, STEP_DEPTH + 0.04)
		tread.mesh = tm
		tread.position = Vector3(0.0, h + 0.01, z)
		tread.material_override = _make_material(color_step)
		add_child(tread)

	# Limons latéraux (structure inclinée).
	_add_box(Vector3(0.08, 0.96, 1.0), Vector3(-0.46, 0.5, 0.0), color_struc)
	_add_box(Vector3(0.08, 0.96, 1.0), Vector3(0.46, 0.5, 0.0), color_struc)

	# Rambardes (barres fines au-dessus des limons).
	for side in [-1, 1]:
		var bar := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.06, 0.06, 1.0)
		bar.mesh = bm
		bar.position = Vector3(side * 0.46, 1.05, 0.0)
		bar.material_override = _make_material(Color(0.42, 0.30, 0.18))
		add_child(bar)

	# Collision en rampe inclinée à ~22° (doux, compatible capsule joueur).
	var ramp := CollisionShape3D.new()
	var rb2 := BoxShape3D.new()
	rb2.size = Vector3(0.88, 0.12, 1.10)
	ramp.shape = rb2
	ramp.position = Vector3(0.0, 0.50, 0.0)
	ramp.rotation.x = deg_to_rad(-22.0)
	add_child(ramp)


# ── Feu de camp ───────────────────────────────────────────────────────────────

func _build_campfire() -> void:
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


# ── Four ──────────────────────────────────────────────────────────────────────

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


# ── Tente ─────────────────────────────────────────────────────────────────────

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


# ── Lit ───────────────────────────────────────────────────────────────────────

func _build_bed() -> void:
	_add_box(Vector3(1.8, 0.35, 0.6), Vector3(0.0, 0.35, 0.0), Color(0.42, 0.3, 0.2))
	_add_box(Vector3(1.7, 0.25, 0.5), Vector3(0.0, 0.7, 0.0), Color(0.75, 0.68, 0.58))
	# Oreillers.
	for side in [-1, 1]:
		var pillow := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.5, 0.1, 0.38)
		pillow.mesh = pm
		pillow.position = Vector3(side * 0.4, 0.88, 0.0)
		pillow.material_override = _make_material(Color(0.88, 0.84, 0.78))
		add_child(pillow)


# ── Générateur ───────────────────────────────────────────────────────────────

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


# ── Coffre ────────────────────────────────────────────────────────────────────

func _build_chest() -> void:
	var wood_dark := Color(0.38, 0.27, 0.16)
	var wood_mid  := Color(0.48, 0.34, 0.21)
	var metal     := Color(0.28, 0.26, 0.22)
	var metal_lt  := Color(0.45, 0.42, 0.36)

	_add_box(Vector3(0.9, 0.65, 0.58), Vector3(0.0, 0.325, 0.0), wood_dark)
	# Lames de bois sur le corps.
	for i in 3:
		var lame := MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(0.88, 0.18, 0.02)
		lame.mesh = lm
		lame.position = Vector3(0.0, 0.16 + i * 0.22, 0.30)
		lame.material_override = _make_material(wood_mid)
		add_child(lame)

	# Couvercle.
	_add_box(Vector3(0.88, 0.1, 0.56), Vector3(0.0, 0.70, 0.0), wood_mid)
	# Lames du couvercle.
	for i in 2:
		var lame := MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(0.86, 0.02, 0.52)
		lame.mesh = lm
		lame.position = Vector3(0.0, 0.76, -0.12 + i * 0.24)
		lame.material_override = _make_material(wood_mid)
		add_child(lame)

	# Ferrures métalliques aux 4 coins avant.
	for cx in [-1, 1]:
		for cy in [0, 1]:
			var fitting := MeshInstance3D.new()
			var fm := BoxMesh.new()
			fm.size = Vector3(0.07, 0.07, 0.04)
			fitting.mesh = fm
			fitting.position = Vector3(cx * 0.38, 0.10 + cy * 0.56, 0.31)
			fitting.material_override = _make_material(metal)
			add_child(fitting)

	# Bandes métalliques cerclant le coffre.
	for band_y in [0.22, 0.52]:
		var band := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.92, 0.06, 0.02)
		band.mesh = bm
		band.position = Vector3(0.0, band_y, 0.30)
		band.material_override = _make_material(metal_lt)
		add_child(band)

	# Serrure centrale.
	var lock := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(0.10, 0.10, 0.04)
	lock.mesh = lm
	lock.position = Vector3(0.0, 0.68, 0.30)
	lock.material_override = _make_material(metal)
	add_child(lock)


# --- Helpers -----------------------------------------------------------------

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


## Retourne un matériau partagé pour la couleur donnée (cache statique).
## Les matériaux à transparence ou émission sont créés à part (non mis en cache).
func _make_material(color: Color) -> StandardMaterial3D:
	var key := color.to_html(true)
	if _mat_cache.has(key):
		return _mat_cache[key] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	material.metallic = 0.0
	_mat_cache[key] = material
	return material
