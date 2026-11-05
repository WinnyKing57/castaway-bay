class_name TradeData
extends Resource
## Offre de troc du marchand itinérant.
##
## Un échange = un fichier .tres dans res://data/trades/.
## Le joueur donne `give` et reçoit `receive`. Une offre est répétable.

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""

## item_id -> quantité cédée par le joueur
@export var give: Dictionary = {}
## item_id -> quantité reçue par le joueur
@export var receive: Dictionary = {}
## Réputation minimale pour débloquer l'offre.
@export var min_reputation: int = 0
