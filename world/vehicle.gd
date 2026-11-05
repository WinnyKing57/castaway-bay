class_name Vehicle
extends CharacterBody3D
## Vehicule de transport (bateau / quad) : locomotion pilotee, embarquement du
## joueur, suivi du passager et sauvegarde position/cap partagees.

const FUEL_ITEM_ID := "fuel"
const METAL_ITEM_ID := "metal"

var _controlled := false
var _player: Node3D = null
var _spd := 5.0
var _turn_spd := 2.5
var _rev_spd := 2.5
var _fuel_on := false
var _fuel_max_v := 30.0
var _fuel_per_item_v := 30.0
var fuel := 30.0
var metal := 0


func _ready() -> void:
	collision_layer = 1
	collision_mask = _collision_mask()
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = _shape_radius()
	capsule.height = _shape_height()
	shape.shape = capsule
	add_child(shape)


func _speed() -> float:
	return _spd


func _turn_speed() -> float:
	return _turn_spd


func _reverse_speed() -> float:
	return _rev_spd


func _fuel_enabled() -> bool:
	return _fuel_on


func _fuel_max() -> float:
	return _fuel_max_v


func _fuel_per_item() -> float:
	return _fuel_per_item_v


func _seat_offset() -> Vector3:
	return Vector3(0.0, 1.0, 0.0)


func _collision_mask() -> int:
	return 0


func _shape_radius() -> float:
	return 0.9


func _shape_height() -> float:
	return 2.4


func _physics_process(delta: float) -> void:
	if not _controlled:
		velocity = Vector3.ZERO
		return
	if GameState.is_dead or not _player_is_aboard():
		_release()
		return
	if _fuel_on and global_position.y > 0.5:
		velocity = Vector3.ZERO
		return
	var can_steer := true
	if is_instance_valid(_player) and _player.has_method("are_controls_enabled"):
		can_steer = bool(_player.call("are_controls_enabled"))
	var input := Vector2.ZERO
	if can_steer:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	if absf(input.x) > 0.01:
		rotate_y(-input.x * _turn_speed() * delta)
	var throttle := -input.y
	if absf(throttle) > 0.01 and _fuel_on:
		if fuel <= 0.0 and GameState.remove_item(FUEL_ITEM_ID, int(_fuel_per_item())):
			fuel = _fuel_max()
	if absf(throttle) > 0.01 and (fuel > 0.0 if _fuel_on else true):
		var speed := _speed() if throttle > 0.0 else _reverse_speed()
		velocity = -transform.basis.z * throttle * speed
		if _fuel_on:
			fuel = maxf(0.0, fuel - delta * 3.0)
	else:
		velocity = Vector3.ZERO
	move_and_slide()
	_follow_player()


func board(player: Node) -> void:
	_player = player if is_instance_valid(player) else null
	if _player == null or not _player is CharacterBody3D:
		_player = null
		return
	_controlled = true
	(_player as CharacterBody3D).enter_boat(self)
	_player.global_position = global_position + _seat_offset()


func _player_is_aboard() -> bool:
	if not is_instance_valid(_player):
		return false
	if _player.has_method("is_in_boat"):
		return bool(_player.call("is_in_boat"))
	return true


func _release() -> void:
	_controlled = false
	velocity = Vector3.ZERO
	if is_instance_valid(_player) and _player is CharacterBody3D:
		(_player as CharacterBody3D).exit_boat()
	_player = null


func _follow_player() -> void:
	if is_instance_valid(_player):
		_player.global_position = global_position + _seat_offset()
		if _player is CharacterBody3D:
			(_player as CharacterBody3D).velocity = Vector3.ZERO


func get_save_state() -> Dictionary:
	return {
		"position": [global_position.x, global_position.y, global_position.z],
		"rotation_y": rotation.y,
	}


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
			if Vector2(target.x, target.z).length() <= max_radius and target.y <= 0.0 and target.y >= -20.0:
				global_position = target
	var rot: Variant = state.get("rotation_y")
	if (typeof(rot) == TYPE_FLOAT or typeof(rot) == TYPE_INT) and is_finite(float(rot)):
		rotation.y = float(rot)
