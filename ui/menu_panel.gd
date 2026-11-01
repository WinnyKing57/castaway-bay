class_name MenuPanel
extends Control
## Menu principal et menu de pause.
##
## Un seul panneau pour les deux usages : la liste des boutons est construite
## en code selon le mode ("start" ou "pause"). Le panneau émet des signaux,
## main.gd décide de ce qui se passe (nouvelle partie, chargement, quitter).

signal new_game_requested
signal continue_requested
signal resume_requested
signal save_requested
signal settings_requested
signal main_menu_requested
signal quit_requested

const ENTRIES := {
	"new": "Nouvelle partie",
	"continue": "Continuer",
	"resume": "Reprendre",
	"save": "Sauvegarder",
	"settings": "Réglages",
	"menu": "Menu principal",
	"quit": "Quitter",
}

@onready var title_label: Label = $Center/Panel/Margin/VBox/Title
@onready var subtitle_label: Label = $Center/Panel/Margin/VBox/Subtitle
@onready var buttons: VBoxContainer = $Center/Panel/Margin/VBox/Buttons

var _mode := "start"


func _ready() -> void:
	# Le menu doit répondre même quand l'arbre est en pause.
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func open_start() -> void:
	_mode = "start"
	title_label.text = "Castaway Bay"
	subtitle_label.text = "Survis. Récolte. Fabrique. Construis."
	_rebuild(["new", "continue", "settings", "quit"])
	visible = true


func open_pause() -> void:
	_mode = "pause"
	title_label.text = "Pause"
	subtitle_label.text = ""
	_rebuild(["resume", "save", "settings", "menu", "quit"])
	visible = true


## Réaffiche le menu dans le mode courant (retour depuis les réglages).
func reopen() -> void:
	if _mode == "pause":
		open_pause()
	else:
		open_start()


func close() -> void:
	visible = false


func is_open() -> bool:
	return visible


func _unhandled_input(event: InputEvent) -> void:
	# Échap referme la pause (mais pas le menu principal).
	if not visible or _mode != "pause":
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		resume_requested.emit()


func _rebuild(entries: PackedStringArray) -> void:
	for child in buttons.get_children():
		child.queue_free()

	for entry in entries:
		var button := Button.new()
		button.text = ENTRIES[entry]
		button.custom_minimum_size = Vector2(280, 50)
		button.add_theme_font_size_override("font_size", 20)
		# "Continuer" n'a de sens que si une sauvegarde existe.
		if entry == "continue":
			button.disabled = not SaveSystem.has_save()
		button.pressed.connect(_on_button_pressed.bind(entry))
		buttons.add_child(button)


func _on_button_pressed(entry: String) -> void:
	match entry:
		"new":
			new_game_requested.emit()
		"continue":
			continue_requested.emit()
		"resume":
			resume_requested.emit()
		"save":
			save_requested.emit()
		"settings":
			settings_requested.emit()
		"menu":
			main_menu_requested.emit()
		"quit":
			quit_requested.emit()
