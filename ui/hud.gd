class_name Hud
extends CanvasLayer
## Interface de jeu : jauges, horloge, invite d'interaction, inventaire, toasts,
## barre rapide, écran de mort et informations de construction.
##
## La vue ne décide de rien : elle lit GameState et écoute ses signaux.

@onready var health_bar: ProgressBar = $Root/Stats/HealthRow/Bar
@onready var hunger_bar: ProgressBar = $Root/Stats/HungerRow/Bar
@onready var thirst_bar: ProgressBar = $Root/Stats/ThirstRow/Bar
@onready var clock_label: Label = $Root/Clock
@onready var prompt_label: Label = $Root/Prompt
@onready var inventory_label: Label = $Root/Inventory
@onready var toast_label: Label = $Root/Toast
@onready var hotbar: HBoxContainer = $Root/Hotbar
@onready var build_info: Label = $Root/BuildInfo
@onready var death_overlay: ColorRect = $Root/DeathOverlay
@onready var underwater_tint: ColorRect = $Root/UnderwaterTint

const TOAST_DURATION := 2.5
const SLOT_COLORS := {
	"selected": Color(1.0, 0.92, 0.55),
	"normal": Color(1.0, 1.0, 1.0),
	"empty": Color(0.6, 0.6, 0.6),
}

var _toast_time_left := 0.0
var _player: Player
var _slot_panels: Array[PanelContainer] = []
var _slot_names: Array[Label] = []
var _slot_counts: Array[Label] = []


func _ready() -> void:
	GameState.inventory_changed.connect(_refresh_inventory)
	GameState.inventory_changed.connect(_refresh_hotbar)
	GameState.hotbar_changed.connect(_refresh_hotbar)
	GameState.toast.connect(_show_toast)
	GameState.died.connect(_on_died)

	_build_hotbar()
	_refresh_inventory()
	_refresh_hotbar()
	toast_label.text = ""


## Branché par main.gd une fois le joueur instancié.
func setup(player: Player) -> void:
	_player = player
	player.interaction_target_changed.connect(_on_prompt_changed)


func _process(delta: float) -> void:
	health_bar.value = GameState.stats.health
	hunger_bar.value = GameState.stats.hunger
	thirst_bar.value = GameState.stats.thirst
	clock_label.text = _format_time(GameState.world_time)

	if _player != null:
		underwater_tint.visible = _player.is_underwater()

	if _toast_time_left > 0.0:
		_toast_time_left -= delta
		if _toast_time_left <= 0.0:
			toast_label.text = ""


func _on_prompt_changed(prompt: String) -> void:
	prompt_label.text = prompt


func _show_toast(text: String) -> void:
	toast_label.text = text
	_toast_time_left = TOAST_DURATION


func _on_died() -> void:
	death_overlay.visible = true
	prompt_label.text = ""


func hide_death() -> void:
	death_overlay.visible = false


## Affiche les infos du mode construction (vide = masqué).
func set_build_info(text: String) -> void:
	build_info.text = text
	build_info.visible = not text.is_empty()


# --- Barre rapide ------------------------------------------------------------

func _build_hotbar() -> void:
	for child in hotbar.get_children():
		child.queue_free()
	_slot_panels.clear()
	_slot_names.clear()
	_slot_counts.clear()

	for index in GameState.hotbar_items.size():
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(104, 58)

		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 0)
		panel.add_child(column)

		var name_label := Label.new()
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 14)
		name_label.text = "%d. %s" % [index + 1, GameState.display_name(GameState.hotbar_items[index])]
		column.add_child(name_label)

		var count_label := Label.new()
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count_label.add_theme_font_size_override("font_size", 16)
		count_label.text = "0"
		column.add_child(count_label)

		hotbar.add_child(panel)
		_slot_panels.append(panel)
		_slot_names.append(name_label)
		_slot_counts.append(count_label)


func _refresh_hotbar() -> void:
	for index in _slot_panels.size():
		if index >= GameState.hotbar_items.size():
			continue
		var item_id := GameState.hotbar_items[index]
		var count := GameState.get_item_count(item_id)
		_slot_names[index].text = "%d. %s" % [index + 1, GameState.display_name(item_id)]
		_slot_counts[index].text = "x%d" % count
		if index == GameState.hotbar_index:
			_slot_panels[index].modulate = SLOT_COLORS.selected
		elif count > 0:
			_slot_panels[index].modulate = SLOT_COLORS.normal
		else:
			_slot_panels[index].modulate = SLOT_COLORS.empty


# --- Inventaire --------------------------------------------------------------

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
