class_name ConstructionPanel
extends Control
## Panneau de construction : catalogue filtrable des éléments, coûts détaillés.
##
## Les éléments viennent de Database (fichiers .tres) : ajouter un constructible
## ne demande aucune modification de cette interface. Le panneau ne pose rien
## lui-même, il signale la sélection au système de construction (par id) via
## `selection_requested`.

signal opened
signal closed
signal selection_requested(buildable_id: String)

const CATEGORY_ORDER: Array[String] = [
	"fondations", "murs", "ouvertures", "toits", "escaliers",
	"mobilier", "stations", "energie", "defense", "exterieur",
]
const CATEGORY_LABELS := {
	"fondations": "Fondations",
	"murs": "Murs",
	"ouvertures": "Ouvertures",
	"toits": "Toits",
	"escaliers": "Escaliers",
	"mobilier": "Mobilier",
	"stations": "Stations",
	"energie": "Énergie",
	"defense": "Défense",
	"exterieur": "Extérieur",
}
const CATEGORY_ALL := ""

@onready var _panel: PanelContainer = $Panel

## Liste affichée (une Button par constructible, exposée pour les tests).
var buildables_box: VBoxContainer

var _icon_factory: IconFactory
var _tabs_box: HBoxContainer
var _search: LineEdit
var _status: Label
var _selected_id := ""
var _filter_category := CATEGORY_ALL
var _rows: Array[Button] = []
var _row_group := ButtonGroup.new()


func _ready() -> void:
	visible = false
	_icon_factory = IconFactory.new()
	add_child(_icon_factory)
	_build_ui()
	GameState.inventory_changed.connect(_on_inventory_changed)


func is_open() -> bool:
	return visible


func open() -> void:
	visible = true
	_rebuild()
	_select_current_or_first()
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


## Id du constructible sélectionné ("" si aucun).
func current_selection() -> String:
	return _selected_id


## Sélectionne un constructible par id. Renvoie false si inconnu.
func select_buildable(buildable_id: String) -> bool:
	if not Database.buildables.has(buildable_id):
		return false
	_selected_id = buildable_id
	_sync_selection()
	selection_requested.emit(buildable_id)
	return true


## Filtre la liste sur une catégorie (`""` = toutes).
func set_category_filter(category: String) -> void:
	_filter_category = category
	for tab in _tabs_box.get_children():
		if tab is Button:
			(tab as Button).set_pressed_no_signal(tab.get_meta("category", "") == category)
	_rebuild()
	_select_current_or_first()


func current_category_filter() -> String:
	return _filter_category


## Filtre la liste par texte (nom / description / coût).
func set_search(text: String) -> void:
	if _search != null:
		_search.text = text
	_rebuild()
	_select_current_or_first()


# --- Interface --------------------------------------------------------------

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 16)
	_panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)

	var title := Label.new()
	title.text = "Construction"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 30)
	header.add_child(title)

	var close_button := Button.new()
	close_button.text = "Fermer (B)"
	close_button.custom_minimum_size = Vector2(150, 40)
	close_button.pressed.connect(close)
	header.add_child(close_button)

	_search = LineEdit.new()
	_search.placeholder_text = "Rechercher un élément…"
	_search.clear_button_enabled = true
	_search.text_changed.connect(func(_text: String) -> void:
		_rebuild()
		_select_current_or_first()
	)
	root.add_child(_search)

	_tabs_box = HBoxContainer.new()
	_tabs_box.add_theme_constant_override("separation", 5)
	root.add_child(_tabs_box)
	_build_tabs()

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	buildables_box = VBoxContainer.new()
	buildables_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buildables_box.add_theme_constant_override("separation", 6)
	scroll.add_child(buildables_box)

	_status = Label.new()
	_status.text = "Choisis un élément."
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_status)

	var hint := Label.new()
	hint.text = "Clic : sélectionner — Molette : élément suivant — R : tourner — B / Échap : fermer — F1 : aide"
	hint.modulate = Color(0.82, 0.82, 0.82)
	hint.add_theme_font_size_override("font_size", 14)
	root.add_child(hint)


func _build_tabs() -> void:
	for child in _tabs_box.get_children():
		_tabs_box.remove_child(child)
		child.queue_free()
	var group := ButtonGroup.new()
	_add_tab("Tout", CATEGORY_ALL, group)
	for category in CATEGORY_ORDER:
		if not _category_has_buildables(category):
			continue
		_add_tab(CATEGORY_LABELS[category], category, group)


func _add_tab(label: String, category: String, group: ButtonGroup) -> void:
	var tab := Button.new()
	tab.text = label
	tab.toggle_mode = true
	tab.button_group = group
	tab.button_pressed = category == _filter_category
	tab.set_meta("category", category)
	tab.custom_minimum_size = Vector2(0, 32)
	tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab.pressed.connect(func() -> void: set_category_filter(category))
	_tabs_box.add_child(tab)


func _category_has_buildables(category: String) -> bool:
	for buildable_id in Database.buildables:
		if str(Database.buildables[buildable_id].category) == category:
			return true
	return false


func _rebuild() -> void:
	if buildables_box == null:
		return
	_clear(buildables_box)
	_rows.clear()

	var ids := Database.buildables.keys()
	ids.sort_custom(_sort_buildables)
	var query := _search.text.strip_edges().to_lower()
	for buildable_id in ids:
		var data: BuildableData = Database.buildables[buildable_id]
		if not _matches(data, query):
			continue
		buildables_box.add_child(_make_row(data))

	if buildables_box.get_child_count() == 0:
		var empty := Label.new()
		empty.text = "Aucun élément ne correspond à ce filtre."
		buildables_box.add_child(empty)
	_sync_selection()


func _matches(data: BuildableData, query: String) -> bool:
	if not _filter_category.is_empty() and str(data.category) != _filter_category:
		return false
	if query.is_empty():
		return true
	if data.display_name.to_lower().contains(query) or data.id.to_lower().contains(query):
		return true
	if data.description.to_lower().contains(query):
		return true
	for item_id in data.costs:
		if GameState.display_name(str(item_id)).to_lower().contains(query):
			return true
	return false


## Tri : catégorie (ordre du panneau), puis palier, puis nom.
func _sort_buildables(a: String, b: String) -> bool:
	var data_a: BuildableData = Database.get_buildable(a)
	var data_b: BuildableData = Database.get_buildable(b)
	var index_a := CATEGORY_ORDER.find(str(data_a.category))
	var index_b := CATEGORY_ORDER.find(str(data_b.category))
	if index_a != index_b:
		return index_a < index_b
	if data_a.tier != data_b.tier:
		return data_a.tier < data_b.tier
	return data_a.display_name.naturalnocasecmp_to(data_b.display_name) < 0


func _make_row(data: BuildableData) -> Button:
	var button := Button.new()
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 54)
	button.text = _row_text(data)
	button.tooltip_text = data.description
	button.icon = _icon_factory.get_buildable_icon(data)
	button.add_theme_constant_override("icon_max_width", 38)
	button.toggle_mode = true
	button.button_group = _row_group
	button.button_pressed = data.id == _selected_id
	button.add_theme_color_override("font_color", _row_color(data))
	button.set_meta("buildable_id", data.id)
	button.pressed.connect(func() -> void: select_buildable(data.id))
	_rows.append(button)
	return button


func _row_text(data: BuildableData) -> String:
	var tier := maxi(data.tier, 1)
	var costs := PackedStringArray()
	for item_id in data.costs:
		var needed := int(data.costs[item_id])
		var owned := GameState.get_item_count(str(item_id))
		costs.append("%s %d/%d" % [GameState.display_name(str(item_id)), owned, needed])
	var suffix := "  (%s)" % ", ".join(costs) if not costs.is_empty() else "  (gratuit)"
	return "%s · palier %d%s" % [data.display_name, tier, suffix]


func _row_color(data: BuildableData) -> Color:
	if not GameState.has_items(data.costs):
		return Color(0.92, 0.66, 0.55)
	return Color(0.94, 0.98, 0.9)


func _sync_selection() -> void:
	for row in _rows:
		if is_instance_valid(row):
			var is_selected: bool = row.get_meta("buildable_id", "") == _selected_id
			row.set_pressed_no_signal(is_selected)
			if is_selected:
				_status.text = _status_text(Database.get_buildable(_selected_id))


func _status_text(data: BuildableData) -> String:
	if data == null:
		return "Choisis un élément."
	var costs := PackedStringArray()
	for item_id in data.costs:
		var needed := int(data.costs[item_id])
		var owned := GameState.get_item_count(str(item_id))
		costs.append("%s %d/%d" % [GameState.display_name(str(item_id)), owned, needed])
	var missing := not GameState.has_items(data.costs)
	return "%s — %s%s" % [
		data.display_name,
		", ".join(costs),
		"  · ressources manquantes" if missing else "  · prêt à poser",
	]


## Sélectionne l'élément courant s'il est visible, sinon le premier de la liste.
func _select_current_or_first() -> void:
	if not _selected_id.is_empty() and _row_visible(_selected_id):
		_sync_selection()
		return
	for row in _rows:
		if is_instance_valid(row):
			select_buildable(str(row.get_meta("buildable_id", "")))
			return


func _row_visible(buildable_id: String) -> bool:
	for row in _rows:
		if is_instance_valid(row) and row.get_meta("buildable_id", "") == buildable_id:
			return true
	return false


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


# --- Signaux ----------------------------------------------------------------

func _on_inventory_changed() -> void:
	if not visible:
		return
	# Rafraîchit uniquement l'apparence des lignes (pas de reconstruction).
	for row in _rows:
		if not is_instance_valid(row):
			continue
		var data: BuildableData = Database.get_buildable(str(row.get_meta("buildable_id", "")))
		if data == null:
			continue
		row.text = _row_text(data)
		row.add_theme_color_override("font_color", _row_color(data))
	_status.text = _status_text(Database.get_buildable(_selected_id))
