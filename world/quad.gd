class_name Quad
extends Vehicle
## Quad tout-terrain : locomotion sur les reliefs (buggy/quad).
##
## Moteur integre, pas de carburant : le joueur accélere via les actions de
## deplacement et consomme l'inertie du vehicule. Le joueur (CharacterBody3D)
## est suspendu de la physique tant qu'il est « a bord ».

func _speed() -> float:
	return 6.0


func _turn_speed() -> float:
	return 3.0


func _reverse_speed() -> float:
	return 6.0


func _seat_offset() -> Vector3:
	return Vector3(0.0, 1.2, 0.0)


func _collision_mask() -> int:
	return 1


func _shape_radius() -> float:
	return 0.55


func _shape_height() -> float:
	return 1.3


func interact(player: Node) -> void:
	if _controlled:
		_release()
		return
	board(player)


func get_interaction_prompt() -> String:
	if not _controlled:
		return "Monter à bord"
	return "Descendre"
