class_name BuildableData
extends Resource
## Définition d'un élément constructible.
##
## Un constructible = un fichier .tres dans res://data/buildables/.
## `kind` détermine le visuel construit en code par world/buildable.gd.

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""

## foundation | wall | half_wall | campfire | chest | door | roof | roof_slope | roof_ridge | roof_corner_out | roof_corner_in | window | furnace | tent | bed | stairs
@export_enum("foundation", "wall", "half_wall", "campfire", "chest", "door", "roof", "roof_slope", "roof_ridge", "roof_corner_out", "roof_corner_in", "window", "furnace", "tent", "bed", "generator", "stairs") var kind: String = "foundation"

## item_id -> quantité consommée à la pose
@export var costs: Dictionary = {}

## Taille d'occupation sur la grille (en cases).
@export var grid_size: int = 1
