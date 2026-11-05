class_name Trader
extends StaticBody3D
## Automate de troc / marchand itinérant.
##
## Le marchand propose des offres de troc (data/trades) débloquées par la
## réputation, et confie des quêtes d'approvisionnement (data/quests).
## Son état (position, rencontres, nombre d'échanges) est sauvegardé.

## Nombre d'échanges nécessaires entre deux entrées de journal.
const JOURNAL_TRADE_STEP := 5

var trade_count := 0
var _met := false


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	_build_visual()


func get_interaction_prompt() -> String:
	return "Parler au marchand itinérant (E)"


func interact(_player: Node) -> void:
	var first_meeting := not _met
	# Le panneau se construit immédiatement : on l'ouvre avant de marquer la
	# rencontre pour qu'il affiche le dialogue de première entrevue.
	GameState.trader_opened.emit(self)
	if first_meeting:
		_met = true
		GameState.add_journal("Rencontre avec un automate de troc rouillé, seul habitant de l'île.")
		GameState.notify("L'automate s'anime dans un grincement de rouages.")


func has_met_player() -> bool:
	return _met


func get_trade_count() -> int:
	return trade_count


## Phrase d'accueil qui évolue avec la réputation et les quêtes en cours.
func get_dialogue() -> String:
	if not _met:
		return "« … » L'automate est immobile, une lueur bleue pulse sous sa plaque frontale."
	var ready_quest := false
	for quest_id in GameState.accepted_quests:
		if GameState.can_complete_quest(str(quest_id)):
			ready_quest = true
			break
	if ready_quest:
		return "« Marchandise… conforme. Dépose, je pèse, tu reçois. » Il fixe ton sac avec insistance."
	if GameState.reputation >= 80:
		return "« Camarade de naufrage. Ma réserve t'est ouverte, sans méfiance. »"
	if GameState.reputation >= 50:
		return "« Tu reviens souvent. Les rouages te reconnaissent. »"
	if GameState.reputation >= 20:
		return "« Échange honnête possible. Pas de mauvaises surprises. »"
	return "« Visiteur inconnu. Montre patte blanche… ou du métal. »"


## Offres de troc visibles pour la réputation actuelle, triées par identifiant.
func get_available_trades() -> Array[TradeData]:
	var result: Array[TradeData] = []
	var ids := Database.trades.keys()
	ids.sort()
	for trade_id in ids:
		var trade: TradeData = Database.trades[trade_id]
		if trade != null and GameState.reputation >= trade.min_reputation:
			result.append(trade)
	return result


func can_execute_trade(trade: TradeData) -> bool:
	if trade == null:
		return false
	if GameState.reputation < trade.min_reputation:
		return false
	return GameState.has_items(trade.give)


## Exécute un troc : cède `give`, reçoit `receive`, gagne un point de réputation.
func execute_trade(trade: TradeData) -> bool:
	if not can_execute_trade(trade):
		return false
	if not GameState.consume_items(trade.give):
		return false
	for item_id in trade.receive:
		GameState.add_item(str(item_id), int(trade.receive[item_id]))
	trade_count += 1
	GameState.add_reputation(1)
	Sfx.play_ui("ui")
	if trade_count % JOURNAL_TRADE_STEP == 0:
		GameState.add_journal("Le marchand a conclu %d échanges avec toi." % trade_count)
	GameState.notify("Troc conclu avec le marchand")
	return true


func get_save_state() -> Dictionary:
	return {
		"position": [global_position.x, global_position.y, global_position.z],
		"rotation_y": rotation.y,
		"met": _met,
		"trade_count": trade_count,
	}


func apply_save_state(state: Dictionary) -> void:
	var pos: Variant = state.get("position")
	if typeof(pos) == TYPE_ARRAY and (pos as Array).size() == 3:
		var ok := true
		for value in pos:
			if (typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT) or not is_finite(float(value)):
				ok = false
		if ok:
			var target := Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
			if Vector2(target.x, target.z).length() <= 240.0 and target.y <= 60.0 and target.y >= -20.0:
				global_position = target
	var rot: Variant = state.get("rotation_y")
	if (typeof(rot) == TYPE_FLOAT or typeof(rot) == TYPE_INT) and is_finite(float(rot)):
		rotation.y = float(rot)
	_met = state.get("met", false) == true
	var saved_trades: Variant = state.get("trade_count")
	trade_count = 0
	if (typeof(saved_trades) == TYPE_FLOAT or typeof(saved_trades) == TYPE_INT) and is_finite(float(saved_trades)):
		trade_count = maxi(0, int(saved_trades))


# --- Visuel de l'automate ----------------------------------------------------

## Petit automate de troc : corps de ferraille, tête pivotante, œil lumineux.
## Construit en code pour rester sans asset externe.
func _build_visual() -> void:
	var rust := _make_material(Color(0.42, 0.29, 0.20))
	var dark := _make_material(Color(0.18, 0.17, 0.16))
	var brass := _make_material(Color(0.72, 0.55, 0.22))

	# Jambes et corps.
	for side in [-1.0, 1.0]:
		_add_box(Vector3(0.24, 0.6, 0.24), Vector3(side * 0.22, 0.3, 0.0), dark)
	_add_box(Vector3(0.8, 0.9, 0.55), Vector3(0.0, 1.05, 0.0), rust)
	# Plaque de poitrine et rivets.
	_add_box(Vector3(0.5, 0.4, 0.06), Vector3(0.0, 1.1, -0.3), brass)
	for rx in [-0.18, 0.18]:
		for ry in [0.95, 1.25]:
			_add_box(Vector3(0.05, 0.05, 0.05), Vector3(rx, ry, -0.34), dark)
	# Bras.
	for side in [-1.0, 1.0]:
		_add_box(Vector3(0.18, 0.7, 0.18), Vector3(side * 0.52, 1.1, 0.0), dark)
		_add_box(Vector3(0.24, 0.18, 0.24), Vector3(side * 0.52, 0.72, 0.0), rust)
	# Tête, œil et antenne.
	_add_box(Vector3(0.55, 0.5, 0.5), Vector3(0.0, 1.75, 0.0), dark)
	_add_box(Vector3(0.32, 0.12, 0.04), Vector3(0.0, 1.8, -0.27), _make_emissive(Color(0.25, 0.85, 1.0)))
	_add_cylinder(0.03, 0.5, Vector3(0.0, 2.2, 0.0), brass)
	_add_sphere(0.09, Vector3(0.0, 2.45, 0.0), _make_emissive(Color(1.0, 0.35, 0.2)))

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.1, 2.2, 0.9)
	shape.shape = box
	shape.position = Vector3(0.0, 1.1, 0.0)
	add_child(shape)


func _add_box(size: Vector3, pos: Vector3, material: Material) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = pos
	node.material_override = material
	add_child(node)


func _add_cylinder(radius: float, height: float, pos: Vector3, material: Material) -> void:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 6
	node.mesh = mesh
	node.position = pos
	node.material_override = material
	add_child(node)


func _add_sphere(radius: float, pos: Vector3, material: Material) -> void:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	node.mesh = mesh
	node.position = pos
	node.material_override = material
	add_child(node)


func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	material.metallic = 0.35
	return material


func _make_emissive(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.6
	material.roughness = 0.4
	return material
