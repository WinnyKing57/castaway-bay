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


func apply_save_state(state: Dictionary) -> void:
	_release()
	var pos: Variant = state.get("position")
	if typeof(pos) == TYPE_ARRAY and (pos as Array).size() == 3:
		var ok := true
		for value in pos:
			if (typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT) or not is_finite(float(value)):
				ok = false
		if ok:
			var target := Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
			var world_node := get_node_or_null("/root/Main/World")
			var max_radius := 140.0
			if world_node != null and world_node.has_method("world_radius"):
				max_radius = float(world_node.call("world_radius")) + 20.0
			if Vector2(target.x, target.z).length() <= max_radius and target.y <= 60.0 and target.y >= -20.0:
				global_position = target
	var rot: Variant = state.get("rotation_y")
	if (typeof(rot) == TYPE_FLOAT or typeof(rot) == TYPE_INT) and is_finite(float(rot)):
		rotation.y = float(rot)


func interact(player: Node) -> void:
	if _controlled:
		_release()
		return
	board(player)


func get_interaction_prompt() -> String:
	if not _controlled:
		return "Monter à bord"
	return "Descendre"
