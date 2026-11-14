class_name QuestData
extends Resource
## Quête d'approvisionnement donnée par le marchand itinérant.
##
## Une quête = un fichier .tres dans res://data/quests/.
## `required_items` est consommé à la remise, `reward_items` est donné en plus
## d'un gain de réputation. Une quête ne peut être accomplie qu'une fois.

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""

## item_id -> quantité à rapporter
@export var required_items: Dictionary = {}
## item_id -> quantité offerte en récompense
@export var reward_items: Dictionary = {}
@export var reward_reputation: int = 5
## Réputation minimale pour que le marchand propose la quête.
@export var min_reputation: int = 0
