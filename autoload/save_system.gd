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

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("[SaveSystem] Impossible d'écrire : %s" % SAVE_PATH)
		return false

	file.store_string(JSON.stringify(data, "\t"))
	file.close()
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
	return data
