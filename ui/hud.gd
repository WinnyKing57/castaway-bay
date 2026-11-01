class_name Hud
extends CanvasLayer
## Interface de jeu : jauges, horloge, invite d'interaction, inventaire, toasts.
##
## La vue ne décide de rien : elle lit GameState et écoute ses signaux.

@onready var health_bar: ProgressBar = $Root/Stats/HealthRow/Bar
@onready var hunger_bar: ProgressBar = $Root/Stats/HungerRow/Bar
@onready var thirst_bar: ProgressBar = $Root/Stats/ThirstRow/Bar
@onready var clock_label: Label = $Root/Clock
@onready var prompt_label: Label = $Root/Prompt
@onready var inventory_label: Label = $Root/Inventory
@onready var toast_label: Label = $Root/Toast

const TOAST_DURATION := 2.5

var _toast_time_left := 0.0


func _ready() -> void:
	GameState.inventory_changed.connect(_refresh_inventory)
	GameState.toast.connect(_show_toast)
	_refresh_inventory()
	toast_label.text = ""


## Branché par main.gd une fois le joueur instancié.
func setup(player: Player) -> void:
	player.interaction_target_changed.connect(_on_prompt_changed)


func _process(delta: float) -> void:
	health_bar.value = GameState.stats.health
	hunger_bar.value = GameState.stats.hunger
	thirst_bar.value = GameState.stats.thirst
	clock_label.text = _format_time(GameState.world_time)

	if _toast_time_left > 0.0:
		_toast_time_left -= delta
		if _toast_time_left <= 0.0:
			toast_label.text = ""


func _on_prompt_changed(prompt: String) -> void:
	prompt_label.text = prompt


func _show_toast(text: String) -> void:
	toast_label.text = text
	_toast_time_left = TOAST_DURATION


func _refresh_inventory() -> void:
	if GameState.inventory.is_empty():
		inventory_label.text = "Inventaire : vide"
		return

	var lines := PackedStringArray(["Inventaire :"])
	var ids := GameState.inventory.keys()
	ids.sort()
	for item_id in ids:
		lines.append("  %s x%d" % [GameState.display_name(str(item_id)), GameState.get_item_count(str(item_id))])
	inventory_label.text = "\n".join(lines)


func _format_time(seconds: float) -> String:
	var total := int(seconds)
	return "%02d:%02d" % [(total / 3600) % 24, (total / 60) % 60]
