extends Node
## Base de données du jeu (autoload "Database").
##
## Charge tous les fichiers .tres des dossiers data/items et data/recipes
## et les indexe par leur champ `id`. Ajouter un objet = déposer un .tres,
## aucune ligne de code à écrire.

const ITEMS_DIR := "res://data/items"
const RECIPES_DIR := "res://data/recipes"
const BUILDABLES_DIR := "res://data/buildables"
const QUESTS_DIR := "res://data/quests"
const TRADES_DIR := "res://data/trades"

## item_id -> ItemData
var items: Dictionary = {}
## recipe_id -> RecipeData
var recipes: Dictionary = {}
## buildable_id -> BuildableData
var buildables: Dictionary = {}
## quest_id -> QuestData
var quests: Dictionary = {}
## trade_id -> TradeData
var trades: Dictionary = {}


func _ready() -> void:
	_load_dir(ITEMS_DIR, items)
	_load_dir(RECIPES_DIR, recipes)
	_load_dir(BUILDABLES_DIR, buildables)
	_load_dir(QUESTS_DIR, quests)
	_load_dir(TRADES_DIR, trades)
	print("[Database] %d objets, %d recettes, %d constructions, %d quêtes, %d trocs chargés" % [
		items.size(), recipes.size(), buildables.size(), quests.size(), trades.size()
	])


func get_item(item_id: String) -> Resource:
	return items.get(item_id)


func get_recipe(recipe_id: String) -> Resource:
	return recipes.get(recipe_id)


func get_buildable(buildable_id: String) -> Resource:
	return buildables.get(buildable_id)


func get_quest(quest_id: String) -> Resource:
	return quests.get(quest_id)


func get_trade(trade_id: String) -> Resource:
	return trades.get(trade_id)


func _load_dir(dir_path: String, target: Dictionary) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_warning("[Database] Dossier introuvable : %s" % dir_path)
		return

	for file_name in dir.get_files():
		var clean_name := file_name.trim_suffix(".remap")
		if not clean_name.ends_with(".tres"):
			continue
		var res: Resource = load(dir_path.path_join(clean_name))
		if res == null:
			push_warning("[Database] Chargement impossible : %s" % clean_name)
			continue
		var id: String = str(res.get("id"))
		if id.is_empty():
			push_warning("[Database] Ressource sans 'id' : %s" % clean_name)
			continue
		target[id] = res
