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

## Station de fabrication en cours (ex. "campfire" pour la cuisine).
var craft_station := ""


func _process(delta: float) -> void:
	world_time = fmod(world_time + delta * (SECONDS_PER_DAY / DAY_LENGTH_SECONDS), SECONDS_PER_DAY)

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

	# Fatigue : baisse avec l'activité, se restaure quand le joueur est nourri
	# et hydraté (récupération doublée la nuit). Jamais bloquée à 100 : sans
	# cette correction, un respawn à 60 de fatigue menait à la mort inévitable.
	stats.fatigue = maxf(0.0, stats.fatigue - delta * 0.015)
	var is_night := world_time < 6.0 * 3600.0 or world_time >= 20.0 * 3600.0
	if stats.fatigue < 100.0 and stats.health > 0.0 and stats.hunger > 60.0 and stats.thirst > 60.0:
		var regen_rate := 0.05 if is_night else 0.02
		stats.fatigue = minf(100.0, stats.fatigue + delta * regen_rate)

	if stats.fatigue <= 0.0:
		stats.health = maxf(0.0, stats.health - delta * 0.5)

	if stats.health <= 0.0:
		is_dead = true
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
	if Settings.infinite_resources:
		return true
	for item_id in costs:
		var needed := int(costs[item_id])
		# Un coût <= 0 est invalide (donnée corrompue) : on refuse plutôt que de
		# laisser consume_items() fabriquer des objets.
		if needed <= 0:
			return false
		if get_item_count(str(item_id)) < needed:
			return false
	return true


func consume_items(costs: Dictionary) -> bool:
	if not has_items(costs):
		return false
	if Settings.infinite_resources:
		# Mode créatif : on pose/fabrique sans rien consommer.
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

func can_craft(recipe: RecipeData) -> bool:
	if recipe == null:
		return false
	if not recipe.required_station.is_empty() and craft_station != recipe.required_station:
		return false
	return has_items(recipe.inputs)


func craft(recipe: RecipeData) -> bool:
	if recipe == null or not can_craft(recipe):
		return false
	if not consume_items(recipe.inputs):
		return false
	for item_id in recipe.outputs:
		add_item(str(item_id), int(recipe.outputs[item_id]))
	Sfx.play_ui("craft")
	notify("Fabriqué : %s" % recipe.display_name)
	return true


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
	craft_station = ""
	is_dead = false
	inventory_changed.emit()
	hotbar_changed.emit()
