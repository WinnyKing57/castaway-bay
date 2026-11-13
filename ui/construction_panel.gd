class_name ConstructionPanel
extends Control
## Panneau de construction dédié : catalogue des éléments, coûts, sélection.
##
## Écrite comme le panneau d'artisanat : les éléments viennent de Database
## (fichiers .tres), aucune modification de cette interface n'est nécessaire
## pour ajouter un nouvel élément.
##
## Le panneau ne pose rien lui-même : il signale la sélection au système de
## construction via `selection_requested`, qui bascule le fantôme.

signal opened
signal closed
signal selection_requested(index: int)


@onready var buildables_box: VBoxContainer = $Panel/Margin/VBox/Scroll/Buildables
@onready var status_label: Label = $Panel/Margin/VBox/Status
@onready var close_button: Button = $Panel/Margin/VBox/Close

var _selected_index := 0


func _ready() -> void:
	visible = false
	close_button.pressed.connect(close)
	selection_requested.connect(_on_selection_requested)


func is_open() -> bool:
	return visible


func open() -> void:
	visible = true
	_rebuild()
	status_label.text = "Choisis un élément."
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


func _rebuild() -> void:
	for child in buildables_box.get_children():
		child.queue_free()

	var ids := Database.buildables.keys()
	ids.sort()
	for i in ids.size():
		var buildable_id: String = str(ids[i])
		var data: BuildableData = Database.buildables[buildable_id]
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 44)
		button.text = _row_text(data)
		button.tooltip_text = data.description
		button.disabled = not GameState.has_items(data.costs)
		button.pressed.connect(_on_buildable_pressed.bind(i))
		buildables_box.add_child(button)
		if i == _selected_index:
			button.modulate = Color(0.9, 0.95, 1.0)
			status_label.text = "Element : %s" % data.display_name


func _on_buildable_pressed(index: int) -> void:
	_selected_index = index
	selection_requested.emit(index)


func _on_selection_requested(index: int) -> void:
	_selected_index = index


func _row_text(data: BuildableData) -> String:
	var costs := PackedStringArray()
	for item_id in data.costs:
		costs.append("%s %d" % [GameState.display_name(str(item_id)), int(data.costs[item_id])])
	return "%s   (%s)" % [data.display_name, ", ".join(costs)]
