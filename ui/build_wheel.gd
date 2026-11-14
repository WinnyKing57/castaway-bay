class_name BuildWheel
extends Control
## Roue de construction (Tab) : sélection rapide des éléments de la catégorie
## courante, disposés en cercle autour du curseur.
##
## Purement visuelle : elle affiche les `BuildableData` fournies par le système
## de construction et émet `buildable_chosen(id)`. Aucune pose n'est faite ici.

signal buildable_chosen(buildable_id: String)

const SLOT_SIZE := Vector2(186, 58)
const BASE_RADIUS := 165.0

var _icon_factory: IconFactory
var _dim: ColorRect
var _title: Label
var _hint: Label
var _slot_layer: Control
var _entries: Array[BuildableData] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_icon_factory = IconFactory.new()
	add_child(_icon_factory)
	_build_shell()


func _build_shell() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0.02, 0.03, 0.05, 0.6)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 26)
	_title.anchor_left = 0.0
	_title.anchor_right = 1.0
	_title.offset_top = 40.0
	_title.offset_bottom = 80.0
	add_child(_title)

	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.text = "Clic : sélectionner — relâche Tab pour fermer"
	_hint.modulate = Color(0.82, 0.82, 0.82)
	_hint.anchor_left = 0.0
	_hint.anchor_right = 1.0
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_top = -60.0
	_hint.offset_bottom = -20.0
	add_child(_hint)

	_slot_layer = Control.new()
	_slot_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_slot_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_slot_layer)


func is_open() -> bool:
	return visible


## Ouvre la roue avec les éléments d'une catégorie. `title` est le libellé
## affiché en haut (ex. « Murs »). Sans élément, la roue ne s'ouvre pas.
func open(entries: Array[BuildableData], selected_id: String, title: String) -> void:
	if entries.is_empty():
		return
	_entries = entries
	_title.text = title
	visible = true
	_rebuild_slots(selected_id)


func close() -> void:
	visible = false
	for child in _slot_layer.get_children():
		_slot_layer.remove_child(child)
		child.queue_free()
	_entries.clear()


## Sélection programmatique (utilisée par les tests et le clavier).
func choose(buildable_id: String) -> void:
	if not Database.buildables.has(buildable_id):
		return
	buildable_chosen.emit(buildable_id)
	close()


func _rebuild_slots(selected_id: String) -> void:
	for child in _slot_layer.get_children():
		_slot_layer.remove_child(child)
		child.queue_free()

	var count := _entries.size()
	var center := _center()
	var radius := BASE_RADIUS + (40.0 if count > 8 else 0.0)
	var group := ButtonGroup.new()
	for i in count:
		var data: BuildableData = _entries[i]
		var angle := -PI * 0.5 + TAU * float(i) / float(count)
		var offset := Vector2(cos(angle), sin(angle)) * radius

		var button := Button.new()
		button.text = data.display_name
		button.icon = _icon_factory.get_buildable_icon(data)
		button.add_theme_constant_override("icon_max_width", 40)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = data.id == selected_id
		button.custom_minimum_size = SLOT_SIZE
		button.size = SLOT_SIZE
		button.position = center + offset - SLOT_SIZE * 0.5
		button.pressed.connect(func() -> void: choose(data.id))
		_slot_layer.add_child(button)


func _center() -> Vector2:
	var viewport := get_viewport_rect().size
	var area := size
	if area.x <= 1.0 or area.y <= 1.0:
		area = viewport
	return area * 0.5
