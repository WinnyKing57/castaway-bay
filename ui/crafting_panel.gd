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

## Fabrication en cours (recette, temps restant) : le craft_time des
## recettes est honoré ici, les ressources sont consommées au départ.
var _craft_recipe: RecipeData = null
var _craft_left := 0.0


func _ready() -> void:
	visible = false
	close_button.pressed.connect(close)
	GameState.inventory_changed.connect(_on_inventory_changed)


func _process(delta: float) -> void:
	if _craft_recipe == null:
		return
	# Un craft ne se poursuit ni pendant la pause, ni après la mort du joueur :
	# les ressources déjà consommées sont perdues si le panneau est fermé
	# (close()) — mais jamais fabriquées "dans l'autre monde".
	if get_tree().paused or GameState.is_dead:
		return
	_craft_left -= delta
	if _craft_left > 0.0:
		status_label.text = "Fabrication de %s… %.1f s" % [_craft_recipe.display_name, _craft_left]
		return
	var finished := _craft_recipe
	_craft_recipe = null
	for item_id in finished.outputs:
		GameState.add_item(str(item_id), int(finished.outputs[item_id]))
	Sfx.play_ui("craft")
	GameState.notify("Fabriqué : %s" % finished.display_name)
	status_label.text = "Fabriqué : %s" % finished.display_name
	_rebuild()


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
	# Une fabrication interrompue par la fermeture du panneau rembourse les
	# ressources consommées au départ (pas de perte punitive).
	if _craft_recipe != null and _craft_left > 0.0:
		for item_id in _craft_recipe.inputs:
			GameState.add_item(str(item_id), int(_craft_recipe.inputs[item_id]))
		GameState.notify("Fabrication annulée — ressources rendues")
	_craft_recipe = null
	_craft_left = 0.0
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


func _rebuild() -> void:
	for child in recipes_box.get_children():
		child.queue_free()

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
	if _craft_recipe != null:
		status_label.text = "Fabrication en cours…"
		return
	if not GameState.can_craft(recipe):
		if not recipe.required_station.is_empty():
			status_label.text = "Nécessite un établi : %s à proximité." % recipe.required_station
		else:
			status_label.text = "Ressources insuffisantes."
		return
	GameState.consume_items(recipe.inputs)
	if recipe.craft_time > 0.0:
		_craft_recipe = recipe
		_craft_left = recipe.craft_time
		status_label.text = "Fabrication de %s…" % recipe.display_name
	else:
		for item_id in recipe.outputs:
			GameState.add_item(str(item_id), int(recipe.outputs[item_id]))
		Sfx.play_ui("craft")
		GameState.notify("Fabriqué : %s" % recipe.display_name)
		status_label.text = "Fabriqué : %s" % recipe.display_name
	_rebuild()
