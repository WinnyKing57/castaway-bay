extends Node
## Sauvegarde / chargement (autoload "SaveSystem").
##
## Format JSON lisible et versionné : on stocke des données (positions, ids,
## quantités), jamais des scènes sérialisées. C'est ce qui permet de faire
## évoluer le jeu sans casser les anciennes sauvegardes.

const SAVE_PATH := "user://savegame.json"


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func save_game(player: Node3D, world: Node = null, construction: Node = null) -> bool:
	var data := {
		"version": GameState.SAVE_VERSION,
		"saved_at": Time.get_datetime_string_from_system(),
		"world_time": GameState.world_time,
		"world_seed": GameState.world_seed,
		"stats": _stats_to_plain(GameState.stats),
		"inventory": _dict_to_plain(GameState.inventory),
		"player": {
			"position": [player.global_position.x, player.global_position.y, player.global_position.z],
			"rotation_y": player.rotation.y,
		},
	}
	if construction != null:
		data["construction"] = construction.to_save_data()
	if world != null:
		var boat := world.get_node_or_null("Boat")
		if boat != null and boat.has_method("get_save_data"):
			data["boat"] = boat.call("get_save_data")

	# État des ressources du monde : repousse des récoltables et croissance
	# des cultures. Sans cela, tout l'île se régénérait à chaque chargement.
	if world != null:
		var resources: Array = []
		for node in world.get_children():
			if node is Harvestable or node is Crop:
				var state: String = node.get_save_state()
				if not state.is_empty():
					var entry := {
						"type": "crop" if node is Crop else "harvest",
						"state": state,
					}
					if node is Harvestable:
						# Clé stable : index d'apparition sur l'ile (reproduit a
						# lidentique grace a la graine), ou save_key si defini.
						entry["id"] = str(node.save_key) if not node.save_key.is_empty() \
							else str(node.get_meta("save_index", -1))
					else:
						entry["id"] = str(node.get_meta("crop_index", -1))
					resources.append(entry)
		data["world_resources"] = resources

	var tmp_path := SAVE_PATH + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		push_error("[SaveSystem] Impossible d'écrire : %s" % tmp_path)
		return false

	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp_path), ProjectSettings.globalize_path(SAVE_PATH)) != OK:
		push_error("[SaveSystem] Impossible de renommer la sauvegarde : %s" % SAVE_PATH)
		return false
	return true


## Lit la sauvegarde et l'applique à l'état global + au joueur.
## Si `world` est fourni et que la graine a changé, l'île est régénérée
## avant de replacer le joueur (sinon il tomberait dans le vide).
func load_game_into(player: Node3D, world: Node = null, construction: Node = null) -> bool:
	var data := _read_save()
	if data.is_empty():
		return false

	GameState.world_time = float(data.get("world_time", GameState.world_time))

	var saved_seed := int(data.get("world_seed", 0))
	if world != null and saved_seed != 0 and saved_seed != GameState.world_seed:
		world.regenerate(saved_seed)

	var saved_stats: Dictionary = data.get("stats", {})
	for key in saved_stats:
		if GameState.stats.has(key):
			GameState.stats[key] = float(saved_stats[key])

	GameState.inventory.clear()
	var saved_inventory: Dictionary = data.get("inventory", {})
	for key in saved_inventory:
		GameState.inventory[key] = int(saved_inventory[key])
	GameState.inventory_changed.emit()

	if construction != null:
		construction.load_save_data(data.get("construction", []))

	# Le bateau est recréé avec l'île : on restaure sa position, son état de
	# coque et son carburant. Le contrôle reste désactivé au chargement.
	if world != null:
		var boat := world.get_node_or_null("Boat")
		var saved_boat: Variant = data.get("boat", {})
		if boat != null and boat.has_method("apply_save_data") and typeof(saved_boat) == TYPE_DICTIONARY:
			boat.call("apply_save_data", saved_boat)
	if player.has_method("exit_boat"):
		player.call("exit_boat")

	# Repopulation des ressources : la graine régénère une île identique,
	# on y réapplique ensuite l'état sauvegardé (repousse / cultures).
	if world != null:
		var saved_resources: Array = data.get("world_resources", [])
		var by_key := {}
		var crop_by_index := {}
		for entry in saved_resources:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var key := str(entry.get("id", "-1"))
			var state := str(entry.get("state", ""))
			if str(entry.get("type", "")) == "crop":
				crop_by_index[key] = state
			else:
				by_key[key] = state
		var harvest_idx := 0
		for node in world.get_children():
			if node is Harvestable:
				node.set_meta("save_index", harvest_idx)
				var hkey := str(node.save_key) if not node.save_key.is_empty() else str(harvest_idx)
				if by_key.has(hkey):
					node.apply_save_state(str(by_key[hkey]))
				harvest_idx += 1
			elif node is Crop:
				var ci := int(node.get_meta("crop_index", -1)) if node.has_meta("crop_index") else -1
				if crop_by_index.has(str(ci)):
					node.apply_save_state(str(crop_by_index[str(ci)]))

	var saved_player: Dictionary = data.get("player", {})
	var pos: Array = saved_player.get("position", [])
	if pos.size() == 3:
		player.global_position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
	player.rotation.y = float(saved_player.get("rotation_y", 0.0))
	if player is CharacterBody3D:
		(player as CharacterBody3D).velocity = Vector3.ZERO

	GameState.is_dead = false
	return true


func _read_save() -> Dictionary:
	if not has_save():
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[SaveSystem] Sauvegarde illisible")
		return {}

	var data: Dictionary = parsed
	var version := int(data.get("version", 0))
	if version > GameState.SAVE_VERSION:
		push_warning("[SaveSystem] Sauvegarde d'une version plus récente (%d)" % version)
	if not _is_valid(data):
		return {}
	return data


## Valide la structure minimale d'une sauvegarde avant de l'appliquer.
func _is_valid(data: Dictionary) -> bool:
	if typeof(data.get("stats")) != TYPE_DICTIONARY:
		return false
	if typeof(data.get("inventory")) != TYPE_DICTIONARY:
		return false
	if typeof(data.get("player")) != TYPE_DICTIONARY:
		return false
	if typeof(data.get("construction", [])) != TYPE_ARRAY:
		return false
	if typeof(data.get("world_resources", [])) != TYPE_ARRAY:
		return false
	return int(data.get("version", 0)) <= GameState.SAVE_VERSION


## JSON n'accepte que des dictionnaires "plain" : les Dictionary de Godot
## marqués en lecture seule (duplicates profondes de Resource) peuvent sinon
## faire échouer JSON.stringify. On re-crée donc des dicos neufs.
func _stats_to_plain(stats: Dictionary) -> Dictionary:
	var out := {}
	for key in stats:
		out[str(key)] = float(stats[key])
	return out


func _dict_to_plain(source: Dictionary) -> Dictionary:
	var out := {}
	for key in source:
		out[str(key)] = int(source[key])
	return out
