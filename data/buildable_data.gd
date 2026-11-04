class_name BuildableData
extends Resource
## Définition d'un élément constructible.
##
## Un constructible = un fichier .tres dans res://data/buildables/.
## `kind` détermine le visuel construit en code par world/buildable.gd.

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""

## foundation | wall | campfire | chest | door | roof | window | furnace | tent | bed | stairs
@export_enum("foundation", "wall", "campfire", "chest", "door", "roof", "window", "furnace", "tent", "bed", "generator", "stairs") var kind: String = "foundation"

## item_id -> quantité consommée à la pose
@export var costs: Dictionary = {}

## Taille d'occupation sur la grille (en cases).
@export var grid_size: int = 1
