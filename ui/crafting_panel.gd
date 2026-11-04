class_name CraftingPanel
extends Control
## Panneau d'artisanat.
##
## Les recettes viennent entièrement de Database (fichiers .tres) : ajouter
## une recette ne demande aucune modification de cette interface.
## Le panneau ne fabrique rien lui-même, il délègue à GameState.craft().

signal opened
signal closed

@onready var recipes_box: VBoxContainer = $Panel/Margin/VBox/Scroll/Recipes
@onready var status_label: Label = $Panel/Margin/VBox/Status
@onready var close_button: Button = $Panel/Margin/VBox/Close


func _ready() -> void:
	visible = false
	close_button.pressed.connect(close)
	GameState.inventory_changed.connect(_on_inventory_changed)
	GameState.craft_changed.connect(_on_craft_changed)


func is_open() -> bool:
	return visible


func open() -> void:
	visible = true
	_rebuild()
	status_label.text = "Choisis une recette."
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


func _on_inventory_changed() -> void:
	if visible:
		_rebuild()


func _on_craft_changed() -> void:
	if visible:
		_rebuild()
		if not GameState.is_crafting():
			status_label.text = "Choisis une recette."


## Pendant une fabrication chronométrée, le panneau affiche la progression.
## Fermer le panneau ne l'interrompt pas : elle continue en arrière-plan.
func _process(_delta: float) -> void:
	if visible and GameState.is_crafting():
		var recipe: RecipeData = GameState.current_craft["recipe"]
		status_label.text = "Fabrication : %s — %d %%" % [recipe.display_name, int(GameState.craft_progress() * 100.0)]


func _rebuild() -> void:
	for child in recipes_box.get_children():
		child.queue_free()

	if GameState.is_crafting():
		var cancel := Button.new()
		cancel.custom_minimum_size = Vector2(0, 46)
		cancel.text = "Annuler la fabrication (ingrédients rendus)"
		cancel.pressed.connect(func() -> void: GameState.cancel_craft())
		recipes_box.add_child(cancel)

	var ids := Database.recipes.keys()
	ids.sort()
	for recipe_id in ids:
		var recipe: RecipeData = Database.recipes[recipe_id]
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 46)
		button.text = _row_text(recipe)
		button.tooltip_text = recipe.description
		button.disabled = not GameState.can_craft(recipe)
		button.pressed.connect(_on_craft_pressed.bind(recipe))
		recipes_box.add_child(button)


func _row_text(recipe: RecipeData) -> String:
	var outputs := PackedStringArray()
	for item_id in recipe.outputs:
		outputs.append("%s x%d" % [GameState.display_name(str(item_id)), int(recipe.outputs[item_id])])

	var costs := PackedStringArray()
	for item_id in recipe.inputs:
		var needed := int(recipe.inputs[item_id])
		var owned := GameState.get_item_count(str(item_id))
		costs.append("%s %d/%d" % [GameState.display_name(str(item_id)), owned, needed])

	return "%s   ( %s )" % [", ".join(outputs), ", ".join(costs)]


func _on_craft_pressed(recipe: RecipeData) -> void:
	if GameState.craft(recipe):
		status_label.text = (
			"Fabrication : %s…" % recipe.display_name if GameState.is_crafting()
			else "Fabriqué : %s" % recipe.display_name
		)
	else:
		status_label.text = "Ressources insuffisantes."
	_rebuild()
