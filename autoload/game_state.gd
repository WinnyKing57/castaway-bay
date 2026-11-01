extends Node
## État global de la partie (autoload "GameState").
##
## Centralise ce qui doit survivre aux changements de scène :
## inventaire, jauges de survie et horloge du monde.
## Les vues (HUD) lisent cet état et écoutent ses signaux.

signal inventory_changed
signal toast(text: String)

## Durée d'un jour complet en secondes réelles (10 min).
const DAY_LENGTH_SECONDS := 600.0
const SECONDS_PER_DAY := 86400.0
const SAVE_VERSION := 1

## item_id -> quantité
var inventory: Dictionary = {}

var stats := {
	"health": 100.0,
	"hunger": 100.0,
	"thirst": 100.0,
}

## Secondes écoulées depuis minuit dans le monde du jeu.
var world_time := 8.0 * 3600.0


func _process(delta: float) -> void:
	world_time = fmod(world_time + delta * (SECONDS_PER_DAY / DAY_LENGTH_SECONDS), SECONDS_PER_DAY)

	# Les jauges baissent lentement : ~5 min pour vider la faim, ~3 min pour la soif.
	stats.hunger = maxf(0.0, stats.hunger - delta * 0.35)
	stats.thirst = maxf(0.0, stats.thirst - delta * 0.55)

	if stats.hunger <= 0.0 or stats.thirst <= 0.0:
		stats.health = maxf(0.0, stats.health - delta * 2.0)


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
	if get_item_count(item_id) < amount:
		return false
	inventory[item_id] = get_item_count(item_id) - amount
	if int(inventory[item_id]) <= 0:
		inventory.erase(item_id)
	inventory_changed.emit()
	return true


func has_items(costs: Dictionary) -> bool:
	for item_id in costs:
		if get_item_count(item_id) < int(costs[item_id]):
			return false
	return true


func consume_items(costs: Dictionary) -> bool:
	if not has_items(costs):
		return false
	for item_id in costs:
		remove_item(item_id, int(costs[item_id]))
	return true


## Nom affichable d'un objet, lu depuis la base de données si possible.
func display_name(item_id: String) -> String:
	if Database.items.has(item_id):
		return Database.items[item_id].display_name
	return item_id.capitalize()


# --- Divers -----------------------------------------------------------------

func notify(text: String) -> void:
	toast.emit(text)


## Remet la partie à zéro (nouvelle partie).
func reset() -> void:
	inventory.clear()
	stats = {"health": 100.0, "hunger": 100.0, "thirst": 100.0}
	world_time = 8.0 * 3600.0
	inventory_changed.emit()
