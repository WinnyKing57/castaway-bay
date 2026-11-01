class_name ItemData
extends Resource
## Définition d'un objet du jeu.
##
## Un objet = un fichier .tres dans res://data/items/.
## L'inventaire, l'artisanat et l'interface lisent tous cette même définition.

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""

@export_enum("ressource", "outil", "nourriture", "construction", "divers")
var category: String = "ressource"

@export var max_stack: int = 99

## Valeur de revente éventuelle (utilisée plus tard par les marchands).
@export var value: int = 1
