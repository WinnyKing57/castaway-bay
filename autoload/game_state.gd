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
signal trader_opened(trader: Node)
signal reputation_changed
signal quests_changed
signal journal_changed

## Durée d'un jour complet en secondes réelles (10 min).
const DAY_LENGTH_SECONDS := 600.0
const SECONDS_PER_DAY := 86400.0
const SAVE_VERSION := 2
## Nombre maximum d'entrées conservées dans le livre de bord.
const MAX_JOURNAL_ENTRIES := 120

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

# --- Marchand, réputation et journal ----------------------------------------

## Réputation auprès du marchand itinérant (0 à 100).
var reputation := 0
## Quêtes acceptées mais pas encore rendues (ids de Database.quests).
var accepted_quests: Array[String] = []
## Quêtes déjà accomplies (une quête ne se refait pas).
var completed_quests: Array[String] = []
## Livre de bord : entrées {"time": secondes du monde, "text": String}.
var journal: Array[Dictionary] = []


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


# --- Marchand, réputation, quêtes et journal --------------------------------

## Titre lisible correspondant au palier de réputation courant.
func reputation_title() -> String:
	return _reputation_title_for(reputation)


func _reputation_title_for(value: int) -> String:
	if value >= 80:
		return "Allié"
	if value >= 50:
		return "Amical"
	if value >= 20:
		return "Neutre"
	return "Méfiant"


## Ajuste la réputation en la bornant à 0-100. Un changement de palier est
## consigné dans le journal.
func add_reputation(amount: int) -> void:
	if amount == 0:
		return
	var before := reputation
	reputation = clampi(reputation + amount, 0, 100)
	if reputation == before:
		return
	reputation_changed.emit()
	var before_title := _reputation_title_for(before)
	var after_title := reputation_title()
	if before_title != after_title:
		add_journal("Réputation : le marchand te considère désormais comme « %s »." % after_title)


func is_quest_accepted(quest_id: String) -> bool:
	return accepted_quests.has(quest_id)


func is_quest_completed(quest_id: String) -> bool:
	return completed_quests.has(quest_id)


## Accepte une quête si elle existe, n'est pas déjà prise et que la réputation
## est suffisante.
func accept_quest(quest_id: String) -> bool:
	var quest: QuestData = Database.get_quest(quest_id)
	if quest == null or accepted_quests.has(quest_id) or completed_quests.has(quest_id):
		return false
	if reputation < quest.min_reputation:
		notify("Réputation insuffisante pour cette quête (%d requise)" % quest.min_reputation)
		return false
	accepted_quests.append(quest_id)
	quests_changed.emit()
	add_journal("Quête acceptée : %s — %s" % [quest.display_name, quest.description])
	notify("Quête acceptée : %s" % quest.display_name)
	return true


## Vrai si la quête acceptée peut être rendue (tous les objets sont là).
func can_complete_quest(quest_id: String) -> bool:
	if not accepted_quests.has(quest_id):
		return false
	var quest: QuestData = Database.get_quest(quest_id)
	return quest != null and has_items(quest.required_items)


## Rend une quête : consomme les objets, donne la récompense et la réputation.
func complete_quest(quest_id: String) -> bool:
	var quest: QuestData = Database.get_quest(quest_id)
	if quest == null or not accepted_quests.has(quest_id):
		return false
	if not consume_items(quest.required_items):
		return false
	for item_id in quest.reward_items:
		add_item(str(item_id), int(quest.reward_items[item_id]))
	accepted_quests.erase(quest_id)
	completed_quests.append(quest_id)
	add_reputation(quest.reward_reputation)
	quests_changed.emit()
	add_journal("Quête accomplie : %s (+%d réputation)" % [quest.display_name, quest.reward_reputation])
	notify("Quête accomplie : %s" % quest.display_name)
	return true


## Ajoute une entrée au livre de bord (les plus anciennes sont oubliées).
func add_journal(text: String) -> void:
	var clean := text.strip_edges()
	if clean.is_empty():
		return
	journal.append({"time": world_time, "text": clean})
	while journal.size() > MAX_JOURNAL_ENTRIES:
		journal.pop_front()
	journal_changed.emit()


func npc_save_state() -> Dictionary:
	return {
		"reputation": reputation,
		"accepted_quests": accepted_quests.duplicate(),
		"completed_quests": completed_quests.duplicate(),
		"journal": journal.duplicate(true),
	}


## Restaure la progression du marchand. Les identifiants inconnus, les doublons
## et les entrées de journal invalides sont ignorés.
func restore_npc_state(state: Dictionary) -> void:
	reputation = clampi(int(_num_or(state.get("reputation"), 0.0)), 0, 100)

	accepted_quests.clear()
	completed_quests.clear()
	var raw_completed: Variant = state.get("completed_quests", [])
	if typeof(raw_completed) == TYPE_ARRAY:
		for value in raw_completed:
			var quest_id := str(value)
			if Database.quests.has(quest_id) and not completed_quests.has(quest_id):
				completed_quests.append(quest_id)
	var raw_accepted: Variant = state.get("accepted_quests", [])
	if typeof(raw_accepted) == TYPE_ARRAY:
		for value in raw_accepted:
			var quest_id := str(value)
			if Database.quests.has(quest_id) and not completed_quests.has(quest_id) and not accepted_quests.has(quest_id):
				accepted_quests.append(quest_id)

	journal.clear()
	var raw_journal: Variant = state.get("journal", [])
	if typeof(raw_journal) == TYPE_ARRAY:
		for entry in raw_journal:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var text := str((entry as Dictionary).get("text", "")).strip_edges()
			if text.is_empty():
				continue
			var time := 0.0
			var raw_time: Variant = (entry as Dictionary).get("time")
			if _is_number(raw_time):
				time = clampf(float(raw_time), 0.0, SECONDS_PER_DAY)
			journal.append({"time": time, "text": text.left(240)})
	while journal.size() > MAX_JOURNAL_ENTRIES:
		journal.pop_front()

	reputation_changed.emit()
	quests_changed.emit()
	journal_changed.emit()


func _is_number(value: Variant) -> bool:
	return (typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT) and is_finite(float(value))


func _num_or(value: Variant, fallback: float) -> float:
	return float(value) if _is_number(value) else fallback


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
	reputation = 0
	accepted_quests.clear()
	completed_quests.clear()
	journal.clear()
	inventory_changed.emit()
	hotbar_changed.emit()
	reputation_changed.emit()
	quests_changed.emit()
	add_journal("Naufragé sur une île inconnue. Survivre, explorer, construire.")
