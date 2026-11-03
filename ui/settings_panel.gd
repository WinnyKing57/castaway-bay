class_name SettingsPanel
extends Control
## Panneau de réglages (volume, sensibilité souris, plein écran).
##
## Il modifie directement l'autoload Settings, qui applique et sauvegarde.
## Utilisé depuis le menu principal et depuis la pause.

signal closed

@onready var volume_slider: HSlider = $Center/Panel/Margin/VBox/VolumeRow/Slider
@onready var sensitivity_slider: HSlider = $Center/Panel/Margin/VBox/SensitivityRow/Slider
@onready var fullscreen_check: CheckButton = $Center/Panel/Margin/VBox/FullscreenRow/Check
@onready var infinite_check: CheckButton = $Center/Panel/Margin/VBox/InfiniteRow/Check
@onready var back_button: Button = $Center/Panel/Margin/VBox/Back


func _ready() -> void:
	# Comme le menu, ce panneau doit fonctionner quand l'arbre est en pause.
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	volume_slider.min_value = 0.0
	volume_slider.max_value = 1.0
	volume_slider.step = 0.01
	sensitivity_slider.min_value = Settings.SENSITIVITY_MIN
	sensitivity_slider.max_value = Settings.SENSITIVITY_MAX
	sensitivity_slider.step = 0.05

	volume_slider.value_changed.connect(_on_volume_changed)
	sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	infinite_check.toggled.connect(_on_infinite_toggled)
	back_button.pressed.connect(close)


func open() -> void:
	# set_value_no_signal : évite de rejouer les callbacks à l'ouverture.
	volume_slider.set_value_no_signal(Settings.master_volume)
	sensitivity_slider.set_value_no_signal(Settings.mouse_sensitivity)
	fullscreen_check.set_pressed_no_signal(Settings.fullscreen)
	infinite_check.set_pressed_no_signal(Settings.infinite_resources)
	visible = true


func close() -> void:
	if not visible:
		return
	Settings.save_settings()
	visible = false
	closed.emit()


func is_open() -> bool:
	return visible


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _on_volume_changed(value: float) -> void:
	Settings.master_volume = value
	Settings.apply()


func _on_sensitivity_changed(value: float) -> void:
	Settings.mouse_sensitivity = value


func _on_fullscreen_toggled(pressed: bool) -> void:
	Settings.fullscreen = pressed
	Settings.apply()


func _on_infinite_toggled(pressed: bool) -> void:
	Settings.infinite_resources = pressed
	# Sauvegarde immédiate : le mode créatif doit être effectif tout de suite
	# (has_items/consume_items lisent Settings en direct).
	Settings.save_settings()
	GameState.notify("Matériaux infinis : %s" % ("activé" if pressed else "désactivé"))
