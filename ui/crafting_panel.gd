class_name CraftingPanel
extends Control
## Panneau d'artisanat.
##
## Trois zones : filtres (catégories + recherche), liste des recettes, détail de
## la recette sélectionnée avec quantités possédées / requises et fabrication.
## Toutes les données viennent de Database (fichiers .tres) : ajouter une recette
## ne demande aucune modification de cette interface.
## Le panneau ne fabrique rien lui-même, il délègue à GameState.

signal opened
signal closed

const CATEGORY_ORDER: Array[String] = [
	"survie", "outils", "cuisine", "materiels", "construction",
	"electricite", "agriculture", "navigation",
]
const CATEGORY_LABELS := {
	"survie": "Survie",
	"outils": "Outils",
	"cuisine": "Cuisine",
	"materiels": "Matériaux",
	"construction": "Construction",
	"electricite": "Électricité",
	"agriculture": "Agriculture",
	"navigation": "Navigation",
}
const CATEGORY_ALL := ""

@onready var _panel: PanelContainer = $Panel

## Liste des recettes affichées (une Button par recette, exposée pour les tests).
var recipes_box: VBoxContainer

var _icon_factory: IconFactory
var _tabs_box: HBoxContainer
var _search: LineEdit
var _detail_box: VBoxContainer
var _status: Label
var _progress: ProgressBar
var _cancel_button: Button
var _filter_category := CATEGORY_ALL
var _selected_id := ""
var _batch := 1
var _suppress_rebuild := false
var _row_group := ButtonGroup.new()
var _rows: Array[Button] = []


func _ready() -> void:
	visible = false
	_icon_factory = IconFactory.new()
	add_child(_icon_factory)
	_build_ui()
	GameState.inventory_changed.connect(_on_inventory_changed)
	GameState.craft_changed.connect(_on_craft_changed)


func is_open() -> bool:
	return visible


func open() -> void:
	visible = true
	_rebuild()
	_status.text = "Choisis une recette."
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


## Id de la recette actuellement sélectionnée ("" si aucune).
func selected_recipe_id() -> String:
	return _selected_id


## Sélectionne une recette par id (ouvre le détail). Renvoie false si inconnue.
func select_recipe(recipe_id: String) -> bool:
	if not Database.recipes.has(recipe_id):
		return false
	_selected_id = recipe_id
	_refresh_detail()
	_highlight_rows()
	return true


## Filtre la liste sur une catégorie (`""` = toutes).
func set_category_filter(category: String) -> void:
	_filter_category = category
	for tab in _tabs_box.get_children():
		if tab is Button:
			(tab as Button).set_pressed_no_signal(tab.get_meta("category", "") == category)
	_rebuild()


func current_category_filter() -> String:
	return _filter_category


## Fabrique la recette sélectionnée. `batch` <= 0 signifie « maximum possible ».
func craft_selected(batch: int = 1) -> bool:
	if _selected_id.is_empty():
		return false
	var recipe: RecipeData = Database.get_recipe(_selected_id)
	if recipe == null or not is_recipe_unlocked(recipe):
		return false

	var count := 1
	if recipe.craft_time <= 0.0:
		count = batch if batch > 0 else _max_craftable(recipe)
	count = maxi(count, 0)

	var crafted := 0
	_suppress_rebuild = true
	for _i in count:
		if not GameState.craft(recipe):
			break
		crafted += 1
	_suppress_rebuild = false

	if crafted <= 0:
		_status.text = "Ressources insuffisantes."
		_rebuild()
		return false
	if crafted == 1:
		_status.text = "Fabriqué : %s" % recipe.display_name
	else:
		_status.text = "Fabriqué : %s x%d" % [recipe.display_name, crafted]
	_rebuild()
	return true


## Une recette est débloquée si `unlocked_by` est vide, ou si le débloqueur est
## une station disponible, une quête accomplie ou un objet possédé.
func is_recipe_unlocked(recipe: RecipeData) -> bool:
	if recipe == null:
		return false
	if recipe.unlocked_by.is_empty():
		return true
	if GameState.has_station(recipe.unlocked_by):
		return true
	if GameState.completed_quests.has(recipe.unlocked_by):
		return true
	return GameState.get_item_count(recipe.unlocked_by) > 0


# --- Construction de l'interface --------------------------------------------

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
	title.text = "Artisanat"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 30)
	header.add_child(title)

	var close_button := Button.new()
	close_button.text = "Fermer (C)"
	close_button.custom_minimum_size = Vector2(140, 40)
	close_button.pressed.connect(close)
	header.add_child(close_button)

	_search = LineEdit.new()
	_search.placeholder_text = "Rechercher une recette…"
	_search.clear_button_enabled = true
	_search.text_changed.connect(func(_text: String) -> void: _rebuild())
	root.add_child(_search)

	_tabs_box = HBoxContainer.new()
	_tabs_box.add_theme_constant_override("separation", 6)
	root.add_child(_tabs_box)
	_build_tabs()

	var body := HSplitContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.split_offset = 540
	root.add_child(body)

	var list_scroll := ScrollContainer.new()
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_scroll.custom_minimum_size = Vector2(500, 0)
	list_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(list_scroll)

	recipes_box = VBoxContainer.new()
	recipes_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recipes_box.add_theme_constant_override("separation", 6)
	list_scroll.add_child(recipes_box)

	var detail_scroll := ScrollContainer.new()
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(detail_scroll)

	_detail_box = VBoxContainer.new()
	_detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_box.add_theme_constant_override("separation", 8)
	detail_scroll.add_child(_detail_box)

	_progress = ProgressBar.new()
	_progress.min_value = 0.0
	_progress.max_value = 100.0
	_progress.custom_minimum_size = Vector2(0, 18)
	_progress.visible = false
	root.add_child(_progress)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	root.add_child(bottom)

	_status = Label.new()
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.text = "Choisis une recette."
	bottom.add_child(_status)

	_cancel_button = Button.new()
	_cancel_button.text = "Annuler la fabrication"
	_cancel_button.custom_minimum_size = Vector2(220, 36)
	_cancel_button.visible = false
	_cancel_button.pressed.connect(func() -> void: GameState.cancel_craft())
	bottom.add_child(_cancel_button)

	var hint := Label.new()
	hint.text = "↑/↓ : parcourir — Entrée : fabriquer — Échap/C : fermer — F1 : aide"
	hint.modulate = Color(0.82, 0.82, 0.82)
	hint.add_theme_font_size_override("font_size", 14)
	root.add_child(hint)


func _build_tabs() -> void:
	_clear(_tabs_box)
	var group := ButtonGroup.new()
	_add_tab("Tout", CATEGORY_ALL, group)
	for category in CATEGORY_ORDER:
		if not _category_has_recipes(category):
			continue
		_add_tab(CATEGORY_LABELS[category], category, group)


func _add_tab(label: String, category: String, group: ButtonGroup) -> void:
	var tab := Button.new()
	tab.text = label
	tab.toggle_mode = true
	tab.button_group = group
	tab.button_pressed = category == _filter_category
	tab.set_meta("category", category)
	tab.custom_minimum_size = Vector2(0, 34)
	tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab.pressed.connect(func() -> void: set_category_filter(category))
	_tabs_box.add_child(tab)


func _category_has_recipes(category: String) -> bool:
	for recipe_id in Database.recipes:
		if str(Database.recipes[recipe_id].category) == category:
			return true
	return false


func _rebuild() -> void:
	if recipes_box == null:
		return
	_clear(recipes_box)
	_rows.clear()
	var ids := Database.recipes.keys()
	ids.sort()
	var query := _search.text.strip_edges().to_lower()
	var first_id := ""
	for recipe_id in ids:
		var recipe: RecipeData = Database.recipes[recipe_id]
		if not _matches(recipe, query):
			continue
		if first_id.is_empty():
			first_id = str(recipe_id)
		recipes_box.add_child(_make_row(recipe))

	if _selected_id.is_empty() or not Database.recipes.has(_selected_id):
		_selected_id = first_id
	elif not _matches(Database.get_recipe(_selected_id), query):
		_selected_id = first_id

	if first_id.is_empty():
		var empty := Label.new()
		empty.text = "Aucune recette ne correspond à ce filtre."
		recipes_box.add_child(empty)
		_selected_id = ""

	_refresh_detail()
	_highlight_rows()


func _matches(recipe: RecipeData, query: String) -> bool:
	if not _filter_category.is_empty() and str(recipe.category) != _filter_category:
		return false
	if query.is_empty():
		return true
	if recipe.display_name.to_lower().contains(query) or recipe.id.to_lower().contains(query):
		return true
	if recipe.description.to_lower().contains(query):
		return true
	for item_id in recipe.outputs:
		if GameState.display_name(str(item_id)).to_lower().contains(query):
			return true
	return false


func _make_row(recipe: RecipeData) -> Button:
	var button := Button.new()
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 50)
	button.text = _row_text(recipe)
	button.tooltip_text = recipe.description
	button.icon = _recipe_icon(recipe)
	button.add_theme_constant_override("icon_max_width", 34)
	button.toggle_mode = true
	button.button_group = _row_group
	button.button_pressed = recipe.id == _selected_id
	button.add_theme_color_override("font_color", _row_color(recipe))
	button.pressed.connect(_on_row_pressed.bind(recipe.id))
	button.set_meta("recipe_id", recipe.id)
	_rows.append(button)
	return button


func _row_text(recipe: RecipeData) -> String:
	var parts := PackedStringArray()
	for item_id in recipe.outputs:
		parts.append("%s ×%d" % [
			GameState.display_name(str(item_id)),
			int(recipe.outputs[item_id]) * maxi(recipe.batch_size, 1),
		])
	var costs := PackedStringArray()
	for item_id in recipe.inputs:
		costs.append("%s %d" % [
			GameState.display_name(str(item_id)),
			int(recipe.inputs[item_id]),
		])
	var suffix := "  (%s)" % ", ".join(costs) if not costs.is_empty() else ""
	if not is_recipe_unlocked(recipe):
		suffix = "  — verrouillée"
	return "%s%s" % [", ".join(parts), suffix]


func _row_color(recipe: RecipeData) -> Color:
	if not is_recipe_unlocked(recipe):
		return Color(0.55, 0.55, 0.55)
	if not GameState.has_items(recipe.inputs):
		return Color(0.9, 0.62, 0.55)
	if not recipe.required_station.is_empty() and not GameState.has_station(recipe.required_station):
		return Color(0.85, 0.8, 0.5)
	return Color(0.94, 0.98, 0.9)


func _recipe_icon(recipe: RecipeData) -> Texture2D:
	for item_id in recipe.outputs:
		var item: ItemData = Database.get_item(str(item_id))
		if item != null:
			return _icon_factory.get_item_icon(item)
	return null


func _highlight_rows() -> void:
	for row in _rows:
		if is_instance_valid(row):
			row.set_pressed_no_signal(row.get_meta("recipe_id", "") == _selected_id)


func _on_row_pressed(recipe_id: String) -> void:
	_selected_id = recipe_id
	_refresh_detail()
	_highlight_rows()


# --- Détail de la recette ---------------------------------------------------

func _refresh_detail() -> void:
	if _detail_box == null:
		return
	_clear(_detail_box)
	if _selected_id.is_empty():
		_add_detail_label("Sélectionne une recette pour voir ses détails.", 16, Color(0.8, 0.8, 0.8))
		return
	var recipe: RecipeData = Database.get_recipe(_selected_id)
	if recipe == null:
		return

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	_detail_box.add_child(header)

	var icon := TextureRect.new()
	icon.texture = _recipe_icon(recipe)
	icon.custom_minimum_size = Vector2(64, 64)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(icon)

	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	_add_label_to(titles, recipe.display_name, 24)
	_add_label_to(titles, _category_label(recipe.category), 14, Color(0.75, 0.82, 0.95))

	if not recipe.description.is_empty():
		_add_detail_label(recipe.description, 15, Color(0.88, 0.88, 0.88))

	_add_detail_label("Produit :", 16, Color(0.75, 0.85, 1.0))
	for item_id in recipe.outputs:
		var amount := int(recipe.outputs[item_id]) * maxi(recipe.batch_size, 1)
		_add_detail_label("  %s ×%d" % [GameState.display_name(str(item_id)), amount], 15)

	_add_detail_label("Ingrédients :", 16, Color(0.75, 0.85, 1.0))
	for item_id in recipe.inputs:
		var needed := int(recipe.inputs[item_id])
		var owned := GameState.get_item_count(str(item_id))
		var color := Color(0.6, 0.95, 0.6) if owned >= needed else Color(0.95, 0.6, 0.5)
		_add_detail_label("  %s  %d/%d" % [GameState.display_name(str(item_id)), owned, needed], 15, color)

	if recipe.craft_time > 0.0:
		_add_detail_label("Durée : %.1f s" % recipe.craft_time, 15)
	else:
		_add_detail_label("Durée : instantanée", 15)

	if not recipe.required_station.is_empty():
		var station_name := recipe.required_station.capitalize()
		var station: BuildableData = Database.get_buildable(recipe.required_station)
		if station != null:
			station_name = station.display_name
		var available := GameState.has_station(recipe.required_station)
		_add_detail_label(
			"Station : %s%s" % [station_name, "" if available else " (absente)"],
			15,
			Color(0.6, 0.95, 0.6) if available else Color(0.95, 0.65, 0.55),
		)

	if not is_recipe_unlocked(recipe):
		_add_detail_label("Verrouillée : %s" % recipe.unlocked_by, 15, Color(0.95, 0.8, 0.5))

	if recipe.craft_time <= 0.0:
		_detail_box.add_child(_build_batch_row())
	else:
		_add_detail_label("Fabrication chronométrée : une unité à la fois.", 14, Color(0.8, 0.8, 0.8))

	var craft := Button.new()
	craft.custom_minimum_size = Vector2(0, 44)
	craft.text = _craft_button_text(recipe)
	craft.disabled = not _can_craft_selected(recipe)
	craft.pressed.connect(func() -> void: craft_selected(_batch))
	_detail_box.add_child(craft)


func _craft_button_text(recipe: RecipeData) -> String:
	if GameState.is_crafting():
		return "Fabrication en cours…"
	if not is_recipe_unlocked(recipe):
		return "Recette verrouillée"
	var amount := maxi(_batch, 1) if recipe.craft_time <= 0.0 else 1
	if amount <= 1:
		return "Fabriquer"
	return "Fabriquer ×%d" % amount


func _can_craft_selected(recipe: RecipeData) -> bool:
	if GameState.is_crafting() or not is_recipe_unlocked(recipe):
		return false
	if not recipe.required_station.is_empty() and not GameState.has_station(recipe.required_station):
		return false
	return GameState.has_items(recipe.inputs)


func _build_batch_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_add_label_to(row, "Quantité :", 15, Color(0.75, 0.85, 1.0))
	for amount in [1, 5, 10, 0]:
		var button := Button.new()
		button.text = "Max" if amount == 0 else "×%d" % amount
		button.toggle_mode = true
		button.button_pressed = amount == _batch
		button.custom_minimum_size = Vector2(0, 32)
		button.pressed.connect(func() -> void:
			_batch = amount
			_refresh_detail()
		)
		row.add_child(button)
	return row


func _max_craftable(recipe: RecipeData) -> int:
	var max_count := 999
	for item_id in recipe.inputs:
		var needed := int(recipe.inputs[item_id])
		if needed <= 0:
			continue
		max_count = mini(max_count, GameState.get_item_count(str(item_id)) / needed)
	return maxi(max_count, 0)


func _category_label(category: String) -> String:
	return CATEGORY_LABELS.get(category, str(category).capitalize())


func _add_detail_label(text: String, font_size: int, color: Color = Color(1, 1, 1)) -> void:
	_add_label_to(_detail_box, text, font_size, color)


func _add_label_to(parent: Node, text: String, font_size: int, color: Color = Color(1, 1, 1)) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


# --- Signaux et boucle ------------------------------------------------------

func _on_inventory_changed() -> void:
	if visible and not _suppress_rebuild:
		_rebuild()


func _on_craft_changed() -> void:
	if visible and not _suppress_rebuild:
		_rebuild()
		if not GameState.is_crafting():
			_status.text = "Choisis une recette."


func _process(_delta: float) -> void:
	if not visible:
		return
	var crafting := GameState.is_crafting()
	_progress.visible = crafting
	_cancel_button.visible = crafting
	if crafting:
		var recipe: RecipeData = GameState.current_craft["recipe"]
		_progress.value = GameState.craft_progress() * 100.0
		_status.text = "Fabrication : %s — %d %%" % [
			recipe.display_name,
			int(GameState.craft_progress() * 100.0),
		]
