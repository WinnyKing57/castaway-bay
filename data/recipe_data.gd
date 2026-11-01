class_name RecipeData
extends Resource
## Recette d'artisanat.
##
## inputs  : item_id -> quantité consommée
## outputs : item_id -> quantité produite
## Exemple : {"wood": 5, "stone": 3} -> {"campfire": 1}

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""

@export var inputs: Dictionary = {}
@export var outputs: Dictionary = {}

## Temps de fabrication en secondes (0 = instantané).
@export var craft_time: float = 0.0

## Établi requis ("", "workbench", "gunbench"...).
@export var required_station: String = ""
