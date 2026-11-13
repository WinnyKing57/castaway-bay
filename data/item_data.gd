class_name ItemData
extends Resource
## Définition d'un objet du jeu.
##
## Un objet = un fichier .tres dans res://data/items/.
## L'inventaire, l'artisanat et l'interface lisent tous cette même définition.

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""

@export_enum("ressource", "outil", "nourriture", "materiel", "construction", "divers")
var category: String = "ressource"

## Tags pour le filtrage / l'icônes (ex. "bois", "metal", "combustible").
@export var tags: Array[String] = []

## Commun / rare / epique (modulate l'icône et la rareté de l'objet).
@export var rarity: String = "commun"

## Couleur de l'icône procédurale (RGB).
@export var icon_color: Color = Color(0.75, 0.75, 0.75)

## Forme de l'icône procédurale : cercle, carre, losange, goutte, feuille, lingot, buche, outil.
@export_enum("cercle", "carre", "losange", "goutte", "feuille", "lingot", "buche", "outil")
var icon_shape: String = "cercle"

## Poids en grammes (optionnel, pour l'inventaire pondéré futur).
@export var weight: float = 0.0

@export var max_stack: int = 99

## Valeur de revente éventuelle (utilisée plus tard par les marchands).
@export var value: int = 1

@export_group("Consommation")
## Si vrai, l'objet peut être mangé / bu (touche F sur la barre rapide).
@export var is_consumable: bool = false
@export var hunger_restore: float = 0.0
@export var thirst_restore: float = 0.0
@export var health_restore: float = 0.0
@export var fatigue_restore: float = 0.0
