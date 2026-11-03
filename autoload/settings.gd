extends Node
## Réglages du joueur (autoload "Settings").
##
## Sauvegardés dans `user://settings.cfg` (indépendant de la partie, donc
## conservés même si l'on efface la sauvegarde du monde).
## Les valeurs sont appliquées immédiatement : volume, sensibilité, écran.

const PATH := "user://settings.cfg"
const SENSITIVITY_MIN := 0.25
const SENSITIVITY_MAX := 3.0

## Volume général, de 0 (muet) à 1 (maximum).
var master_volume := 0.8
## Multiplicateur appliqué à la sensibilité de base de la souris.
var mouse_sensitivity := 1.0
var fullscreen := false
## Mode créatif : les coûts de construction et d'artisanat sont ignorés
## ( cheat optionnel, hors sauvegarde — réglage persistant comme le volume).
var infinite_resources := false


func _ready() -> void:
	load_settings()
	apply()


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return
	master_volume = clampf(float(config.get_value("audio", "master_volume", master_volume)), 0.0, 1.0)
	mouse_sensitivity = clampf(
		float(config.get_value("input", "mouse_sensitivity", mouse_sensitivity)),
		SENSITIVITY_MIN,
		SENSITIVITY_MAX
	)
	fullscreen = bool(config.get_value("video", "fullscreen", fullscreen))
	infinite_resources = bool(config.get_value("gameplay", "infinite_resources", infinite_resources))


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("input", "mouse_sensitivity", mouse_sensitivity)
	config.set_value("video", "fullscreen", fullscreen)
	config.set_value("gameplay", "infinite_resources", infinite_resources)
	config.save(PATH)


## Applique les réglages au moteur (à appeler après chaque modification).
func apply() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.0001)))
	AudioServer.set_bus_mute(0, master_volume <= 0.001)

	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	)
