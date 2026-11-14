class_name TraderPanel
extends Control
## Panneau du marchand itinérant : dialogue, réputation, trocs et quêtes.
##
## Le panneau ne décide de rien : il lit Database (offres et quêtes) et délègue
## les échanges au Trader, les quêtes à GameState.

signal opened
signal closed

@onready var dialogue_label: Label = $Panel/Margin/VBox/Header/Dialogue
@onready var rep_label: Label = $Panel/Margin/VBox/Header/Reputation/RepLabel
@onready var rep_bar: ProgressBar = $Panel/Margin/VBox/Header/Reputation/RepBar
@onready var trades_box: VBoxContainer = $Panel/Margin/VBox/Columns/TradesCol/TradesScroll/Trades
@onready var quests_box: VBoxContainer = $Panel/Margin/VBox/Columns/QuestsCol/QuestsScroll/Quests
@onready var status_label: Label = $Panel/Margin/VBox/Status
@onready var close_button: Button = $Panel/Margin/VBox/Close

var _trader: Trader = null


func _ready() -> void:
	visible = false
	close_button.pressed.connect(close)
	GameState.trader_opened.connect(open)
	GameState.inventory_changed.connect(_on_state_changed)
	GameState.quests_changed.connect(_on_state_changed)
	GameState.reputation_changed.connect(_on_state_changed)


func is_open() -> bool:
	return visible


func open(trader: Node) -> void:
	if not (trader is Trader):
		return
	_trader = trader as Trader
	visible = true
	status_label.text = "Choisis un troc ou une quête."
	_rebuild()
	opened.emit()


func close() -> void:
	if not visible:
		return
	visible = false
	_trader = null
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		close()


func _on_state_changed() -> void:
	if visible:
		_rebuild()


func _rebuild() -> void:
	if _trader == null or not is_instance_valid(_trader):
		close()
		return

	dialogue_label.text = _trader.get_dialogue()
	rep_label.text = "Réputation : %d/100 — %s" % [GameState.reputation, GameState.reputation_title()]
	rep_bar.value = GameState.reputation

	_clear(trades_box)
	_clear(quests_box)

	var trades := _trader.get_available_trades()
	if trades.is_empty():
		_add_empty(trades_box, "Aucune offre accessible pour l'instant.")
	for trade in trades:
		_add_trade_row(trade)

	var quest_ids := Database.quests.keys()
	quest_ids.sort()
	if quest_ids.is_empty():
		_add_empty(quests_box, "Aucune quête disponible.")
	for quest_id in quest_ids:
		var quest: QuestData = Database.quests[quest_id]
		if quest != null:
			_add_quest_row(quest)


func _add_trade_row(trade: TradeData) -> void:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 2)

	var row := HBoxContainer.new()
	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text = "%s : %s → %s" % [
		trade.display_name,
		_items_text(trade.give),
		_items_text(trade.receive),
	]
	row.add_child(label)

	var button := Button.new()
	button.text = "Échanger"
	button.disabled = not _trader.can_execute_trade(trade)
	button.pressed.connect(_on_trade_pressed.bind(trade))
	row.add_child(button)
	block.add_child(row)

	var description := Label.new()
	description.text = trade.description
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 13)
	description.modulate = Color(0.72, 0.76, 0.8)
	block.add_child(description)

	trades_box.add_child(block)
	trades_box.add_child(HSeparator.new())


func _add_quest_row(quest: QuestData) -> void:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 2)

	var title := Label.new()
	title.text = quest.display_name
	title.add_theme_font_size_override("font_size", 17)
	block.add_child(title)

	var description := Label.new()
	description.text = quest.description
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 13)
	description.modulate = Color(0.78, 0.82, 0.86)
	block.add_child(description)

	var required := Label.new()
	required.text = "À fournir : %s" % _items_text(quest.required_items)
	block.add_child(required)

	var reward := Label.new()
	reward.text = "Récompense : %s + %d réputation" % [
		_items_text(quest.reward_items),
		quest.reward_reputation,
	]
	reward.modulate = Color(0.95, 0.85, 0.5)
	block.add_child(reward)

	var button := Button.new()
	if GameState.is_quest_completed(quest.id):
		button.text = "Quête terminée"
		button.disabled = true
	elif not GameState.is_quest_accepted(quest.id):
		button.text = "Accepter la quête"
		button.disabled = GameState.reputation < quest.min_reputation
		button.pressed.connect(_on_accept_quest.bind(quest.id))
	else:
		var ready := GameState.can_complete_quest(quest.id)
		button.text = "Rendre la quête" if ready else "En attente des objets"
		button.disabled = not ready
		button.pressed.connect(_on_complete_quest.bind(quest.id))
	block.add_child(button)

	if GameState.reputation < quest.min_reputation and not GameState.is_quest_accepted(quest.id) \
			and not GameState.is_quest_completed(quest.id):
		var lock := Label.new()
		lock.text = "Réputation requise : %d" % quest.min_reputation
		lock.add_theme_font_size_override("font_size", 13)
		lock.modulate = Color(0.9, 0.5, 0.4)
		block.add_child(lock)

	quests_box.add_child(block)
	quests_box.add_child(HSeparator.new())


func _on_trade_pressed(trade: TradeData) -> void:
	if _trader != null and _trader.execute_trade(trade):
		status_label.text = "Troc conclu : %s" % trade.display_name
	else:
		status_label.text = "Ressources insuffisantes pour ce troc."
	_rebuild()


func _on_accept_quest(quest_id: String) -> void:
	if GameState.accept_quest(quest_id):
		status_label.text = "Quête acceptée. Rapporte les objets au marchand."
	else:
		status_label.text = "Impossible d'accepter cette quête."
	_rebuild()


func _on_complete_quest(quest_id: String) -> void:
	if GameState.complete_quest(quest_id):
		status_label.text = "Quête rendue. Réputation gagnée."
	else:
		status_label.text = "Il manque encore des objets."
	_rebuild()


func _items_text(items: Dictionary) -> String:
	var parts := PackedStringArray()
	var ids := items.keys()
	ids.sort()
	for item_id in ids:
		parts.append("%s x%d" % [GameState.display_name(str(item_id)), int(items[item_id])])
	return ", ".join(parts)


func _clear(box: Node) -> void:
	for child in box.get_children():
		child.queue_free()


func _add_empty(box: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.modulate = Color(0.7, 0.7, 0.7)
	box.add_child(label)
