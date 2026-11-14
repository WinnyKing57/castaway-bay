class_name JournalPanel
extends Control
## Livre de bord : journal d'aventure chronologique.
##
## Les entrées viennent de GameState.journal (quêtes, rencontres, événements).
## Le panneau est en lecture seule et se met à jour à chaque nouvelle entrée.

signal opened
signal closed

@onready var entries_box: VBoxContainer = $Panel/Margin/VBox/Scroll/Entries
@onready var close_button: Button = $Panel/Margin/VBox/Close


func _ready() -> void:
	visible = false
	close_button.pressed.connect(close)
	GameState.journal_changed.connect(_on_journal_changed)


func is_open() -> bool:
	return visible


func open() -> void:
	visible = true
	_rebuild()
	opened.emit()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _on_journal_changed() -> void:
	if visible:
		_rebuild()


func _rebuild() -> void:
	for child in entries_box.get_children():
		child.queue_free()

	if GameState.journal.is_empty():
		var empty := Label.new()
		empty.text = "Aucun événement consigné pour l'instant."
		empty.modulate = Color(0.7, 0.7, 0.7)
		entries_box.add_child(empty)
		return

	# Du plus récent au plus ancien.
	for index in range(GameState.journal.size() - 1, -1, -1):
		var entry: Dictionary = GameState.journal[index]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)

		var time_label := Label.new()
		time_label.text = _format_time(float(entry.get("time", 0.0)))
		time_label.custom_minimum_size = Vector2(58, 0)
		time_label.modulate = Color(0.65, 0.78, 0.9)
		row.add_child(time_label)

		var text_label := Label.new()
		text_label.text = str(entry.get("text", ""))
		text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(text_label)

		entries_box.add_child(row)


func _format_time(seconds: float) -> String:
	var total := int(seconds)
	return "%02d:%02d" % [(total / 3600) % 24, (total / 60) % 60]
