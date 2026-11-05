extends Node
## Sauvegarde / chargement (autoload "SaveSystem").
##
## Format JSON lisible et versionné : on stocke des données (positions, ids,
## quantités), jamais des scènes sérialisées. C'est ce qui permet de faire
## évoluer le jeu sans casser les anciennes sauvegardes.

const SAVE_PATH := "user://savegame.json"
## Quantité maximale d'un objet restaurée depuis une sauvegarde.
const MAX_STACK := 99999


const BACKUP_PATH := SAVE_PATH + ".bak"


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(BACKUP_PATH)


func delete_save() -> void:
	delete_backup()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func delete_backup() -> void:
	if FileAccess.file_exists(BACKUP_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BACKUP_PATH))


## Écrit la sauvegarde complète : état du joueur (position, regard, bateau),
## jauges, inventaire, barre rapide, fabrication en cours, constructions et état
## du monde (ressources récoltées, cultures, bateau).
## L'écriture est sûre : fichier temporaire, puis la sauvegarde précédente est
## conservée en `.bak` ; en cas d'échec on restaure l'ancienne.
func save_game(player: Node3D, construction: Node = null, world: Node = null) -> bool:
	var player_data := {
		"position": [player.global_position.x, player.global_position.y, player.global_position.z],
		"rotation_y": player.rotation.y,
	}
	if player.has_method("get_pitch"):
		player_data["pitch"] = player.call("get_pitch")
	if player.has_method("is_in_boat"):
		player_data["in_boat"] = bool(player.call("is_in_boat"))

	var data := {
		"version": GameState.SAVE_VERSION,
		"saved_at": Time.get_datetime_string_from_system(),
		"world_time": GameState.world_time,
		"world_seed": GameState.world_seed,
		"stats": GameState.stats.duplicate(),
		"inventory": GameState.inventory.duplicate(),
		"hotbar_index": GameState.hotbar_index,
		"player": player_data,
		"npc": GameState.npc_save_state(),
	}
	var craft_state := GameState.craft_save_state()
	if not craft_state.is_empty():
		data["craft"] = craft_state
	if construction != null:
		data["construction"] = construction.to_save_data()
	if world != null and world.has_method("to_save_data"):
		data["world_state"] = world.call("to_save_data")

	var tmp_path := SAVE_PATH + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		push_error("[SaveSystem] Impossible d'écrire : %s" % tmp_path)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

	var save_abs := ProjectSettings.globalize_path(SAVE_PATH)
	var tmp_abs := ProjectSettings.globalize_path(tmp_path)
	var bak_abs := ProjectSettings.globalize_path(BACKUP_PATH)
	var had_save := FileAccess.file_exists(SAVE_PATH)
	if had_save:
		DirAccess.copy_absolute(save_abs, bak_abs)

	if DirAccess.rename_absolute(tmp_abs, save_abs) != OK:
		# Certaines plateformes refusent de remplacer un fichier existant.
		if had_save:
			DirAccess.remove_absolute(save_abs)
		if DirAccess.rename_absolute(tmp_abs, save_abs) != OK:
			push_error("[SaveSystem] Impossible de renommer la sauvegarde : %s" % SAVE_PATH)
			if had_save and not FileAccess.file_exists(SAVE_PATH):
				DirAccess.copy_absolute(bak_abs, save_abs)
			return false
	return true


## Lit la sauvegarde et l'applique à l'état global + au joueur.
## Si `world` est fourni et que la graine a changé, l'île est régénérée
## avant de replacer le joueur (sinon il tomberait dans le vide).
## La sauvegarde est entièrement validée (types, valeurs finies, bornes) avant
## que le moindre état du jeu ne soit modifié. Si le fichier principal est
## illisible, la copie de secours `.bak` est essayée.
func load_game_into(player: Node3D, world: Node = null, construction: Node = null) -> bool:
	var data := _read_save()
	if data.is_empty():
		return false

	# Le joueur ne doit pas rester bloqué « à bord » d'un bateau après un chargement.
	if player.has_method("exit_boat"):
		player.call("exit_boat")

	GameState.world_time = fposmod(_num(data.get("world_time"), GameState.world_time), GameState.SECONDS_PER_DAY)

	var saved_seed := int(_num(data.get("world_seed"), 0.0))
	if world != null and saved_seed != 0 and saved_seed != GameState.world_seed:
		world.regenerate(saved_seed)

	var saved_stats: Dictionary = data.get("stats", {})
	for key in saved_stats:
		if GameState.stats.has(key):
			GameState.stats[key] = clampf(_num(saved_stats[key], GameState.stats[key]), 0.0, 100.0)

	# Inventaire : seuls les objets connus, avec une quantité entière positive.
	GameState.inventory.clear()
	var saved_inventory: Dictionary = data.get("inventory", {})
	for key in saved_inventory:
		var item_id := str(key)
		var amount := int(_num(saved_inventory[key], 0.0))
		if amount <= 0:
			continue
		if not Database.items.has(item_id):
			push_warning("[SaveSystem] Objet inconnu ignoré : %s" % item_id)
			continue
		GameState.inventory[item_id] = mini(amount, MAX_STACK)
	GameState.inventory_changed.emit()
	if data.has("hotbar_index"):
		GameState.select_hotbar(int(_num(data["hotbar_index"], 0.0)))

	# Fabrication en cours (ingrédients déjà consommés à la sauvegarde).
	GameState.clear_craft()
	if data.has("craft"):
		GameState.restore_craft(data["craft"])

	# Réputation, quêtes et journal du marchand (absent des sauvegardes v1).
	if data.has("npc") and typeof(data["npc"]) == TYPE_DICTIONARY:
		GameState.restore_npc_state(data["npc"])
	else:
		GameState.restore_npc_state({})

	if construction != null:
		construction.load_save_data(data.get("construction", []))

	# État du monde : ressources récoltées, cultures, bateau (absent des v1).
	if world != null and data.has("world_state") and world.has_method("apply_save_data"):
		world.call("apply_save_data", data["world_state"])

	var saved_player: Dictionary = data.get("player", {})
	var pos: Array = saved_player.get("position", [])
	if pos.size() == 3:
		player.global_position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
		# Position aberrante (hors du monde) : on replace le joueur sur la plage.
		var horizontal := Vector2(player.global_position.x, player.global_position.z)
		var max_horizontal := 230.0
		if world != null and world.has_method("world_radius"):
			max_horizontal = float(world.call("world_radius")) + 20.0
		if world != null and world.has_method("find_spawn_point") \
				and (horizontal.length() > max_horizontal or player.global_position.y < -20.0 or player.global_position.y > 300.0):
			player.global_position = world.call("find_spawn_point")
	player.rotation.y = _num(saved_player.get("rotation_y"), 0.0)
	if player.has_method("set_pitch"):
		player.call("set_pitch", _num(saved_player.get("pitch"), 0.0))
	if player is CharacterBody3D:
		(player as CharacterBody3D).velocity = Vector3.ZERO

	# Le joueur reprend la barre du bateau s'il naviguait à la sauvegarde.
	if saved_player.get("in_boat", false) == true and world != null and world.has_method("get_boat"):
		var boat: Node = world.call("get_boat")
		if boat != null and boat.has_method("board"):
			boat.call("board", player)

	GameState.is_dead = false
	return true


func _read_save() -> Dictionary:
	for path in [SAVE_PATH, BACKUP_PATH]:
		var data := _read_file(path)
		if not data.is_empty():
			if path == BACKUP_PATH:
				push_warning("[SaveSystem] Sauvegarde principale illisible : copie de secours utilisée")
			return data
	return {}


func _read_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()

	# JSON.new().parse() (et non parse_string) : un fichier corrompu ne déclenche
	# pas d'erreur moteur, on le traite nous-mêmes.
	var json := JSON.new()
	var parsed: Variant = json.data if json.parse(text) == OK else null
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("[SaveSystem] Sauvegarde illisible : %s" % path)
		return {}

	var data: Dictionary = parsed
	var version := int(data.get("version", 0)) if _is_number(data.get("version", 0)) else 0
	if version > GameState.SAVE_VERSION:
		push_warning("[SaveSystem] Sauvegarde d'une version plus récente (%d)" % version)
	if not _is_valid(data):
		return {}
	return data


## Valide une sauvegarde avant de l'appliquer : structure, types et valeurs
## numériques finies. Toute incohérence rejette la sauvegarde entière (on
## préfère refuser un fichier douteux que charger un état à moitié valide).
func _is_valid(data: Dictionary) -> bool:
	if typeof(data.get("stats")) != TYPE_DICTIONARY:
		return false
	if typeof(data.get("inventory")) != TYPE_DICTIONARY:
		return false
	if typeof(data.get("player")) != TYPE_DICTIONARY:
		return false
	if typeof(data.get("construction", [])) != TYPE_ARRAY:
		return false
	if not _is_number(data.get("version", 0)):
		return false
	if int(data.get("version", 0)) > GameState.SAVE_VERSION:
		return false

	# Champs scalaires optionnels : s'ils existent, ils doivent être numériques.
	for key in ["world_time", "world_seed"]:
		if data.has(key) and not _is_number(data[key]):
			return false

	var stats: Dictionary = data["stats"]
	for key in stats:
		if not _is_number(stats[key]):
			return false

	var inventory: Dictionary = data["inventory"]
	for key in inventory:
		if typeof(key) != TYPE_STRING:
			return false
		if not _is_number(inventory[key]):
			return false

	for key in ["hotbar_index"]:
		if data.has(key) and not _is_number(data[key]):
			return false
	if data.has("craft") and typeof(data["craft"]) != TYPE_DICTIONARY:
		return false
	if data.has("world_state") and typeof(data["world_state"]) != TYPE_DICTIONARY:
		return false
	if data.has("npc"):
		if typeof(data["npc"]) != TYPE_DICTIONARY:
			return false
		var npc: Dictionary = data["npc"]
		if npc.has("reputation") and not _is_number(npc["reputation"]):
			return false
		for key in ["accepted_quests", "completed_quests", "journal"]:
			if npc.has(key) and typeof(npc[key]) != TYPE_ARRAY:
				return false

	var player_data: Dictionary = data["player"]
	if player_data.has("rotation_y") and not _is_number(player_data["rotation_y"]):
		return false
	if player_data.has("pitch") and not _is_number(player_data["pitch"]):
		return false
	if player_data.has("in_boat") and typeof(player_data["in_boat"]) != TYPE_BOOL:
		return false
	if player_data.has("position"):
		var pos: Variant = player_data["position"]
		if typeof(pos) != TYPE_ARRAY or (pos as Array).size() != 3:
			return false
		for value in pos:
			if not _is_number(value) or absf(float(value)) > 100000.0:
				return false
	return true


func _is_number(value: Variant) -> bool:
	return (typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT) and is_finite(float(value))


## Convertit en float si `value` est un nombre fini, sinon renvoie `fallback`.
func _num(value: Variant, fallback: float) -> float:
	if _is_number(value):
		return float(value)
	return fallback
