extends Node
## Base de données du jeu (autoload "Database").
##
## Charge tous les fichiers .tres des dossiers data/items et data/recipes
## et les indexe par leur champ `id`. Ajouter un objet = déposer un .tres,
## aucune ligne de code à écrire.

const ITEMS_DIR := "res://data/items"
const RECIPES_DIR := "res://data/recipes"

## item_id -> ItemData
var items: Dictionary = {}
## recipe_id -> RecipeData
var recipes: Dictionary = {}


func _ready() -> void:
	_load_dir(ITEMS_DIR, items)
	_load_dir(RECIPES_DIR, recipes)
	print("[Database] %d objets, %d recettes chargés" % [items.size(), recipes.size()])


func get_item(item_id: String) -> Resource:
	return items.get(item_id)


func get_recipe(recipe_id: String) -> Resource:
	return recipes.get(recipe_id)


func _load_dir(dir_path: String, target: Dictionary) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_warning("[Database] Dossier introuvable : %s" % dir_path)
		return

	for file_name in dir.get_files():
		if not file_name.ends_with(".tres"):
			continue
		var res: Resource = load(dir_path.path_join(file_name))
		if res == null:
			push_warning("[Database] Chargement impossible : %s" % file_name)
			continue
		var id: String = str(res.get("id"))
		if id.is_empty():
			push_warning("[Database] Ressource sans 'id' : %s" % file_name)
			continue
		target[id] = res
