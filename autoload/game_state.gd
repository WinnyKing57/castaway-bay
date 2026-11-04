extends Node
## État global de la partie (autoload "GameState").
##
## Centralise ce qui doit survivre aux changements de scène :
## inventaire, jauges de survie, horloge du monde et barre rapide.
## Les vues (HUD) lisent cet état et écoutent ses signaux.

signal inventory_changed
signal hotbar_changed
signal toast(text: String)
signal died
signal craft_changed
signal chest_opened(chest: Node)

## Durée d'un jour complet en secondes réelles (10 min).
const DAY_LENGTH_SECONDS := 600.0
const SECONDS_PER_DAY := 86400.0
const SAVE_VERSION := 2

## Objets accessibles depuis la barre rapide (touches 1 à 5).
var hotbar_items: Array[String] = ["coconut", "berry", "torch", "stone_axe", "cooked"]
var hotbar_index := 0

## item_id -> quantité
var inventory: Dictionary = {}

var stats := {
	"health": 100.0,
	"hunger": 100.0,
	"thirst": 100.0,
	"fatigue": 100.0,
}

## Secondes écoulées depuis minuit dans le monde du jeu.
var world_time := 8.0 * 3600.0

## Graine de génération de l'île : sauvegardée pour retrouver le même monde.
var world_seed := 0

var is_dead := false

## Stations de fabrication disponibles (ex. "campfire" pour la cuisine), posées
## par le joueur : station_id -> true. Plusieurs peuvent coexister.
var craft_stations: Dictionary = {}

## Fabrication chronométrée en cours : {"recipe": RecipeData, "remaining": float}.
## Les ingrédients sont consommés au lancement ; vide si rien n'est en cours.
var current_craft: Dictionary = {}


func _process(delta: float) -> void:
	if Settings.always_day:
		world_time = 12.0 * 3600.0  # Midi fixe
	else:
		world_time = fmod(world_time + delta * (SECONDS_PER_DAY / DAY_LENGTH_SECONDS), SECONDS_PER_DAY)
	_advance_craft(delta)

	if is_dead:
		return

	# Les jauges baissent lentement : ~20 min pour vider la faim, ~14 min pour la soif.
	stats.hunger = maxf(0.0, stats.hunger - delta * 0.08)
	stats.thirst = maxf(0.0, stats.thirst - delta * 0.12)

	if stats.hunger <= 0.0 or stats.thirst <= 0.0:
		stats.health = maxf(0.0, stats.health - delta * 1.0)
	elif stats.health > 0.0 and stats.hunger > 60.0 and stats.thirst > 60.0 and stats.health < 100.0:
		# Récupération lente quand on est rassasié et hydraté.
		stats.health = minf(100.0, stats.health + delta * 0.6)

	# Fatigue : baisse avec l'activité, se restaure au repos.
	stats.fatigue = maxf(0.0, stats.fatigue - delta * 0.015)
	if stats.fatigue >= 100.0 and stats.health > 0.0 and stats.hunger > 60.0 and stats.thirst > 60.0:
		stats.fatigue = minf(100.0, stats.fatigue + delta * 0.05)

	if stats.fatigue <= 0.0:
		stats.health = maxf(0.0, stats.health - delta * 0.5)

	if stats.health <= 0.0:
		is_dead = true
		# Une fabrication en cours est annulée (ingrédients rendus) à la mort.
		cancel_craft()
		died.emit()


# --- Inventaire -------------------------------------------------------------

func get_item_count(item_id: String) -> int:
	return int(inventory.get(item_id, 0))


func add_item(item_id: String, amount: int = 1) -> void:
	if amount <= 0:
		return
	inventory[item_id] = get_item_count(item_id) + amount
	inventory_changed.emit()
	notify("+%d %s" % [amount, display_name(item_id)])


func remove_item(item_id: String, amount: int = 1) -> bool:
	# Une quantité <= 0 est refusée : sinon un retrait négatif créerait des objets.
	if amount <= 0:
		return false
	if get_item_count(item_id) < amount:
		return false
	inventory[item_id] = get_item_count(item_id) - amount
	if int(inventory[item_id]) <= 0:
		inventory.erase(item_id)
	inventory_changed.emit()
	return true


func has_items(costs: Dictionary) -> bool:
	for item_id in costs:
		var needed := int(costs[item_id])
		# Un coût <= 0 est invalide (donnée corrompue) : on refuse plutôt que de
		# laisser consume_items() fabriquer des objets.
		if needed <= 0:
			return false
		if not Settings.infinite_resources and get_item_count(str(item_id)) < needed:
			return false
	return true


func consume_items(costs: Dictionary) -> bool:
	if not has_items(costs):
		return false
	if Settings.infinite_resources:
		return true
	for item_id in costs:
		remove_item(str(item_id), int(costs[item_id]))
	return true


## Nom affichable d'un objet, lu depuis la base de données si possible.
func display_name(item_id: String) -> String:
	if Database.items.has(item_id):
		return Database.items[item_id].display_name
	return item_id.capitalize()


# --- Barre rapide et consommation -------------------------------------------

func select_hotbar(index: int) -> void:
	hotbar_index = clampi(index, 0, hotbar_items.size() - 1)
	hotbar_changed.emit()


func selected_hotbar_item() -> String:
	if hotbar_items.is_empty():
		return ""
	return hotbar_items[hotbar_index]


## Utilise l'objet de la case sélectionnée (manger, boire...).
func use_selected_item() -> bool:
	var item_id := selected_hotbar_item()
	if item_id.is_empty():
		return false
	if get_item_count(item_id) <= 0:
		notify("Pas de %s en stock" % display_name(item_id))
		return false

	var data: ItemData = Database.get_item(item_id)
	if data == null:
		return false

	if not data.is_consumable:
		notify("Équipé : %s" % data.display_name)
		return false

	stats.hunger = minf(100.0, stats.hunger + data.hunger_restore)
	stats.thirst = minf(100.0, stats.thirst + data.thirst_restore)
	stats.health = minf(100.0, stats.health + data.health_restore)
	stats.fatigue = minf(100.0, stats.fatigue + data.fatigue_restore)
	remove_item(item_id, 1)
	Sfx.play_ui("eat")
	notify("Consommé : %s" % data.display_name)
	return true


# --- Artisanat --------------------------------------------------------------

func has_station(station_id: String) -> bool:
	return craft_stations.has(station_id)


func register_station(station_id: String) -> void:
	craft_stations[station_id] = true


func clear_stations() -> void:
	craft_stations.clear()


func is_crafting() -> bool:
	return not current_craft.is_empty()


## Progression de la fabrication en cours (0.0 à 1.0).
func craft_progress() -> float:
	if not is_crafting():
		return 0.0
	var recipe: RecipeData = current_craft["recipe"]
	if recipe.craft_time <= 0.0:
		return 1.0
	return clampf(1.0 - float(current_craft["remaining"]) / recipe.craft_time, 0.0, 1.0)


func can_craft(recipe: RecipeData) -> bool:
	if recipe == null or is_crafting():
		return false
	if not recipe.required_station.is_empty() and not has_station(recipe.required_station):
		return false
	return has_items(recipe.inputs)


## Lance une fabrication. Instantanée si `craft_time` vaut 0, sinon chronométrée :
## les ingrédients sont pris tout de suite et rendus en cas d'annulation.
func craft(recipe: RecipeData) -> bool:
	if recipe == null or not can_craft(recipe):
		return false
	consume_items(recipe.inputs)
	if recipe.craft_time > 0.0:
		current_craft = {"recipe": recipe, "remaining": recipe.craft_time}
		craft_changed.emit()
		notify("Fabrication : %s…" % recipe.display_name)
		return true
	_finish_craft(recipe)
	return true


func _finish_craft(recipe: RecipeData) -> void:
	for item_id in recipe.outputs:
		add_item(str(item_id), int(recipe.outputs[item_id]))
	Sfx.play_ui("craft")
	notify("Fabriqué : %s" % recipe.display_name)


func _advance_craft(delta: float) -> void:
	if not is_crafting():
		return
	current_craft["remaining"] = float(current_craft["remaining"]) - delta
	if float(current_craft["remaining"]) > 0.0:
		return
	var recipe: RecipeData = current_craft["recipe"]
	current_craft = {}
	_finish_craft(recipe)
	craft_changed.emit()


## Annule la fabrication en cours et rend les ingrédients.
func cancel_craft() -> bool:
	if not is_crafting():
		return false
	var recipe: RecipeData = current_craft["recipe"]
	current_craft = {}
	for item_id in recipe.inputs:
		var amount := int(recipe.inputs[item_id])
		if amount > 0:
			inventory[str(item_id)] = get_item_count(str(item_id)) + amount
	inventory_changed.emit()
	craft_changed.emit()
	notify("Fabrication annulée")
	return true


## Abandonne la fabrication sans rembourser (nouvelle partie, chargement).
func clear_craft() -> void:
	if current_craft.is_empty():
		return
	current_craft = {}
	craft_changed.emit()


func craft_save_state() -> Dictionary:
	if not is_crafting():
		return {}
	var recipe: RecipeData = current_craft["recipe"]
	return {"recipe_id": recipe.id, "remaining": float(current_craft["remaining"])}


## Reprend une fabrication sauvegardée (données déjà validées structurellement).
func restore_craft(state: Dictionary) -> void:
	clear_craft()
	var recipe_id := str(state.get("recipe_id", ""))
	var remaining: Variant = state.get("remaining")
	if not Database.recipes.has(recipe_id):
		return
	if typeof(remaining) != TYPE_FLOAT and typeof(remaining) != TYPE_INT:
		return
	var recipe: RecipeData = Database.recipes[recipe_id]
	var left := clampf(float(remaining), 0.01, maxf(recipe.craft_time, 0.01))
	current_craft = {"recipe": recipe, "remaining": left}
	craft_changed.emit()


# --- Mort / renaissance -----------------------------------------------------

func respawn() -> void:
	stats = {"health": 60.0, "hunger": 60.0, "thirst": 60.0, "fatigue": 60.0}
	is_dead = false
	inventory_changed.emit()


# --- Divers -----------------------------------------------------------------

func notify(text: String) -> void:
	toast.emit(text)


## Remet la partie à zéro (nouvelle partie).
func reset() -> void:
	inventory.clear()
	stats = {"health": 100.0, "hunger": 100.0, "thirst": 100.0, "fatigue": 100.0}
	world_time = 8.0 * 3600.0
	hotbar_index = 0
	clear_stations()
	clear_craft()
	is_dead = false
	inventory_changed.emit()
	hotbar_changed.emit()
