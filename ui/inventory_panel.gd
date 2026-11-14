class_name InventoryPanel
extends Control
## Panneau d'inventaire : grille de tous les objets possédés, filtrable, avec
## glisser-déposer vers les cases de la barre rapide.
##
## La vue ne modifie jamais `GameState.inventory` : elle lit l'état et délègue
## les changements à `GameState.set_hotbar_item()` / `swap_hotbar_items()`.

signal opened
signal closed

const CATEGORY_ORDER: Array[String] = [
	"ressource", "nourriture", "materiel", "outil", "construction", "divers",
]
const CATEGORY_LABELS := {
	"ressource": "Ressources",
	"nourriture": "Nourriture",
	"materiel": "Matériel",
	"outil": "Outils",
	"construction": "Construction",
	"divers": "Divers",
}
const GRID_COLUMNS := 6


## Case d'objet : source de glisser-déposer (aucun clic requis).
class ItemTile extends PanelContainer:
	var item_id := ""

	func _get_drag_data(_at_position: Vector2) -> Variant:
		if item_id.is_empty():
			return null
		var preview := PanelContainer.new()
		var label := Label.new()
		label.text = GameState.display_name(item_id)
		preview.add_child(label)
		set_drag_preview(preview)
		return {"kind": "item", "item_id": item_id}


## Case de barre rapide : cible de dépôt (objet) et source de réorganisation.
class HotbarSlot extends Button:
	var index := 0
	var on_drop: Callable

	func _get_drag_data(_at_position: Vector2) -> Variant:
		return {"kind": "hotbar", "index": index}

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		if not (data is Dictionary):
			return false
		return data.get("kind", "") in ["item", "hotbar"]

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		if not on_drop.is_valid():
			return
		if data.get("kind", "") == "hotbar":
			on_drop.call("swap:%d" % int(data.get("index", index)))
		else:
			on_drop.call(str(data.get("item_id", "")))


@onready var _panel: PanelContainer = $Panel

## Grille des objets (exposée pour les tests).
var grid: GridContainer
## Rangée des cinq cases de barre rapide.
var hotbar_row: HBoxContainer

var _icon_factory: IconFactory
var _tabs_box: HBoxContainer
var _search: LineEdit
var _summary: Label
var _filter_category := ""
var _tiles: Array[ItemTile] = []


func _ready() -> void:
	visible = false
	_icon_factory = IconFactory.new()
	add_child(_icon_factory)
	_build_ui()
	GameState.inventory_changed.connect(_on_inventory_changed)
	GameState.hotbar_changed.connect(_on_hotbar_changed)


# --- API publique ------------------------------------------------------------

func is_open() -> bool:
	return visible


func open() -> void:
	visible = true
	_rebuild_grid()
	_rebuild_hotbar()
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


func set_category_filter(category: String) -> void:
	_filter_category = category
	for tab in _tabs_box.get_children():
		if tab is Button:
			(tab as Button).set_pressed_no_signal(str(tab.get_meta("category", "")) == category)
	_rebuild_grid()


func current_category_filter() -> String:
	return _filter_category


func set_search(text: String) -> void:
	if _search != null:
		_search.text = text
	_rebuild_grid()


## Ids des objets actuellement affichés (ordre trié).
func visible_item_ids() -> Array[String]:
	var ids: Array[String] = []
	for tile in _tiles:
		if is_instance_valid(tile):
			ids.append(tile.item_id)
	return ids


## Assigne un objet à une case de la barre rapide (même chemin que le dépôt).
func assign_hotbar(index: int, item_id: String) -> bool:
	var ok := GameState.set_hotbar_item(index, item_id)
	if ok:
		_rebuild_hotbar()
	return ok


# --- Interface ---------------------------------------------------------------

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
	title.text = "Inventaire"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 30)
	header.add_child(title)

	var close_button := Button.new()
	close_button.text = "Fermer (I)"
	close_button.custom_minimum_size = Vector2(150, 40)
	close_button.pressed.connect(close)
	header.add_child(close_button)

	_search = LineEdit.new()
	_search.placeholder_text = "Rechercher un objet…"
	_search.clear_button_enabled = true
	_search.text_changed.connect(func(_text: String) -> void: _rebuild_grid())
	root.add_child(_search)

	_tabs_box = HBoxContainer.new()
	_tabs_box.add_theme_constant_override("separation", 5)
	root.add_child(_tabs_box)
	_build_tabs()

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	grid = GridContainer.new()
	grid.columns = GRID_COLUMNS
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)

	_summary = Label.new()
	_summary.modulate = Color(0.86, 0.90, 0.82)
	root.add_child(_summary)

	var hotbar_title := Label.new()
	hotbar_title.text = "Barre rapide — glisse un objet sur une case"
	hotbar_title.add_theme_font_size_override("font_size", 16)
	root.add_child(hotbar_title)

	hotbar_row = HBoxContainer.new()
	hotbar_row.add_theme_constant_override("separation", 6)
	root.add_child(hotbar_row)

	var hint := Label.new()
	hint.text = "Glisser-déposer : objet → case rapide, case → case pour échanger — I / Échap : fermer — F1 : aide"
	hint.modulate = Color(0.82, 0.82, 0.82)
	hint.add_theme_font_size_override("font_size", 14)
	root.add_child(hint)


func _build_tabs() -> void:
	var group := ButtonGroup.new()
	_add_tab("Tout", "", group)
	for category in CATEGORY_ORDER:
		_add_tab(str(CATEGORY_LABELS[category]), category, group)


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


# --- Grille ------------------------------------------------------------------

func _rebuild_grid() -> void:
	if grid == null:
		return
	_clear(grid)
	_tiles.clear()

	var query := _search.text.strip_edges().to_lower()
	var ids: Array[String] = []
	for key in GameState.inventory:
		var item_id := str(key)
		if GameState.get_item_count(item_id) <= 0:
			continue
		var item: ItemData = Database.get_item(item_id)
		if item == null or not _matches(item, query):
			continue
		ids.append(item_id)
	ids.sort_custom(_sort_items)

	for item_id in ids:
		var tile := _make_tile(item_id)
		grid.add_child(tile)
		_tiles.append(tile)

	if ids.is_empty():
		var empty := Label.new()
		empty.text = "Aucun objet ne correspond à ce filtre."
		grid.add_child(empty)

	var total := 0
	for key in GameState.inventory:
		total += GameState.get_item_count(str(key))
	_summary.text = "%d objet(s) affiché(s) — %d au total" % [ids.size(), total]


func _matches(item: ItemData, query: String) -> bool:
	if not _filter_category.is_empty() and str(item.category) != _filter_category:
		return false
	if query.is_empty():
		return true
	return (
		item.display_name.to_lower().contains(query)
		or item.id.to_lower().contains(query)
		or item.description.to_lower().contains(query)
	)


func _sort_items(a: String, b: String) -> bool:
	var item_a: ItemData = Database.get_item(a)
	var item_b: ItemData = Database.get_item(b)
	var index_a := CATEGORY_ORDER.find(str(item_a.category))
	var index_b := CATEGORY_ORDER.find(str(item_b.category))
	if index_a != index_b:
		return index_a < index_b
	return item_a.display_name.naturalnocasecmp_to(item_b.display_name) < 0


func _make_tile(item_id: String) -> ItemTile:
	var item: ItemData = Database.get_item(item_id)
	var tile := ItemTile.new()
	tile.item_id = item_id
	tile.custom_minimum_size = Vector2(76, 76)
	tile.mouse_filter = Control.MOUSE_FILTER_STOP
	tile.tooltip_text = "%s\n%s" % [item.display_name, item.description]

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 0)
	tile.add_child(box)

	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = _icon_factory.get_item_icon(item)
	icon.custom_minimum_size = Vector2(44, 44)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(icon)

	var count := Label.new()
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.text = "x%d" % GameState.get_item_count(item_id)
	box.add_child(count)
	return tile


# --- Barre rapide ------------------------------------------------------------

func _rebuild_hotbar() -> void:
	if hotbar_row == null:
		return
	_clear(hotbar_row)
	for index in GameState.hotbar_items.size():
		var slot := HotbarSlot.new()
		slot.index = index
		slot.custom_minimum_size = Vector2(190, 46)
		slot.toggle_mode = true
		slot.button_pressed = index == GameState.hotbar_index
		slot.tooltip_text = "Dépose un objet ici (case %d)" % (index + 1)
		_apply_hotbar_slot_content(slot, index)
		slot.pressed.connect(_on_hotbar_slot_pressed.bind(index))
		slot.on_drop = func(payload: String) -> void: _on_hotbar_drop(index, payload)
		hotbar_row.add_child(slot)


func _apply_hotbar_slot_content(slot: HotbarSlot, index: int) -> void:
	var item_id := GameState.hotbar_items[index]
	var item: ItemData = Database.get_item(item_id)
	slot.icon = _icon_factory.get_item_icon(item) if item != null else null
	slot.add_theme_constant_override("icon_max_width", 30)
	slot.text = "%d. %s" % [index + 1, item.display_name if item != null else "vide"]


func _on_hotbar_drop(index: int, payload: String) -> void:
	if payload.begins_with("swap:"):
		var other := int(payload.substr(5))
		GameState.swap_hotbar_items(index, other)
		_rebuild_hotbar()
		return
	if assign_hotbar(index, payload):
		GameState.notify("%s → case %d" % [GameState.display_name(payload), index + 1])


func _on_hotbar_slot_pressed(index: int) -> void:
	GameState.select_hotbar(index)
	_rebuild_hotbar()


# --- Signaux -----------------------------------------------------------------

func _on_inventory_changed() -> void:
	if visible:
		_rebuild_grid()


func _on_hotbar_changed() -> void:
	if visible:
		_rebuild_hotbar()


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
