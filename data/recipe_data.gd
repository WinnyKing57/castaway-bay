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

## Catégorie : survie, outils, cuisine, materiels, construction, electricite, agriculture, navigation.
@export_enum("survie", "outils", "cuisine", "materiels", "construction", "electricite", "agriculture", "navigation") var category: String = "survie"

## Palier requis (1 a 4).
@export var tier: int = 1

## Id de la recette / quete / station qui debloque celle-ci ("" = connue d'emblee).
@export var unlocked_by: String = ""

## Taille de la production (1 = production unique).
@export var batch_size: int = 1

## Établi requis ("", "workbench", "gunbench"...).
@export var required_station: String = ""
