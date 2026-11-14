class_name BuildableData
extends Resource
## Définition d'un élément constructible.
##
## Un constructible = un fichier .tres dans res://data/buildables/.
## `kind` détermine le visuel construit en code par world/buildable.gd.

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""

## foundation | wall | half_wall | campfire | chest | door | roof | roof_slope | roof_ridge | roof_corner_out | roof_corner_in | window | furnace | tent | bed | stairs | house | torch
@export_enum("foundation", "wall", "half_wall", "campfire", "chest", "door", "roof", "roof_slope", "roof_ridge", "roof_corner_out", "roof_corner_in", "window", "furnace", "tent", "bed", "generator", "stairs", "house", "torch", "gate", "fence", "bridge") var kind: String = "foundation"

## item_id -> quantité consommée à la pose
@export var costs: Dictionary = {}

## Taille d'occupation sur la grille (en cases).
@export var grid_size: int = 1

## Catégorie : fondations, murs, ouvertures, toits, escaliers, mobilier, stations, énergie, défense, extérieur.
@export_enum("fondations", "murs", "ouvertures", "toits", "escaliers", "mobilier", "stations", "energie", "defense", "exterieur") var category: String = "murs"

## Palier (bois -> pierre -> brique -> métal).
@export var tier: int = 1

## Id du palier suivant ("" si aucun).
@export var upgrade_to: String = ""

## Points de vie (défaut constructible).
@export var health: float = 100.0

## Id de la recette / quete / item qui debloque celui-ci ("" = débloqué).
@export var unlocked_by: String = ""

## Échelle de la vignette de prévisualisation (1.0 = taille normale).
@export var preview_scale: float = 1.0
