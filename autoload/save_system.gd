extends Node
## Sauvegarde / chargement (autoload "SaveSystem").
##
## Format JSON lisible et versionné : on stocke des données (positions, ids,
## quantités), jamais des scènes sérialisées. C'est ce qui permet de faire
## évoluer le jeu sans casser les anciennes sauvegardes.

const SAVE_PATH := "user://savegame.json"
## Quantité maximale d'un objet restaurée depuis une sauvegarde.
const MAX_STACK := 99999


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func save_game(player: Node3D, construction: Node = null) -> bool:
	var data := {
		"version": GameState.SAVE_VERSION,
		"saved_at": Time.get_datetime_string_from_system(),
		"world_time": GameState.world_time,
		"world_seed": GameState.world_seed,
		"stats": GameState.stats.duplicate(),
		"inventory": GameState.inventory.duplicate(),
		"player": {
			"position": [player.global_position.x, player.global_position.y, player.global_position.z],
			"rotation_y": player.rotation.y,
		},
	}
	if construction != null:
		data["construction"] = construction.to_save_data()

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
## La sauvegarde est entièrement validée (types, valeurs finies, bornes) avant
## que le moindre état du jeu ne soit modifié.
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

	if construction != null:
		construction.load_save_data(data.get("construction", []))

	var saved_player: Dictionary = data.get("player", {})
	var pos: Array = saved_player.get("position", [])
	if pos.size() == 3:
		player.global_position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
		# Position aberrante (hors du monde) : on replace le joueur sur la plage.
		var horizontal := Vector2(player.global_position.x, player.global_position.z)
		if world != null and world.has_method("find_spawn_point") \
				and (horizontal.length() > 140.0 or player.global_position.y < -20.0 or player.global_position.y > 300.0):
			player.global_position = world.call("find_spawn_point")
	player.rotation.y = _num(saved_player.get("rotation_y"), 0.0)
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
		push_warning("[SaveSystem] Sauvegarde illisible")
		return {}

	var data: Dictionary = parsed
	var version := int(data.get("version", 0))
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

	var player_data: Dictionary = data["player"]
	if player_data.has("rotation_y") and not _is_number(player_data["rotation_y"]):
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
