class_name Quad
extends CharacterBody3D
## Quad tout-terrain : locomotion sur les reliefs (buggy/quad).
##
## Moteur integre, pas de carburant : le joueur accélere via les actions de
## deplacement et consomme l'inertie du vehicule. Le joueur (CharacterBody3D)
## est suspendu de la physique tant qu'il est « a bord ».

const SPEED := 6.0
const TURN_SPEED := 3.0
const SEAT_OFFSET := Vector3(0.0, 1.2, 0.0)


var _controlled := false
var _player: Node3D = null


func _ready() -> void:
	collision_layer = 1
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.55
	capsule.height = 1.3
	shape.shape = capsule
	add_child(shape)


func _physics_process(_delta: float) -> void:
	if not _controlled:
		velocity = Vector3.ZERO
		return
	if GameState.is_dead or not _player_is_aboard():
		_release()
		return
	var can_steer := true
	if is_instance_valid(_player) and _player.has_method("are_controls_enabled"):
		can_steer = bool(_player.call("are_controls_enabled"))
	var input := Vector2.ZERO
	if can_steer:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	if absf(input.x) > 0.01:
		rotate_y(-input.x * TURN_SPEED * _delta)
	var throttle := -input.y
	if absf(throttle) > 0.01:
		velocity = -transform.basis.z * throttle * SPEED
	else:
		velocity = Vector3.ZERO
	move_and_slide()
	if is_instance_valid(_player):
		_player.global_position = global_position + SEAT_OFFSET
		if _player is CharacterBody3D:
			(_player as CharacterBody3D).velocity = Vector3.ZERO


## Embarque `player` sans condition (restauration d'une sauvegarde).
func board(player: Node) -> void:
	_player = player if is_instance_valid(player) else null
	if _player == null or not _player is CharacterBody3D:
		_player = null
		return
	_controlled = true
	(_player as CharacterBody3D).enter_boat(self)
	_player.global_position = global_position + SEAT_OFFSET


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
			if Vector2(target.x, target.z).length() <= 140.0 and target.y <= 0.0 and target.y >= -20.0:
				global_position = target
	var rot: Variant = state.get("rotation_y")
	if (typeof(rot) == TYPE_FLOAT or typeof(rot) == TYPE_INT) and is_finite(float(rot)):
		rotation.y = float(rot)


func interact(player: Node) -> void:
	if _controlled:
		_release()
		return
	_player = player if is_instance_valid(player) else null
	if _player == null:
		return
	_controlled = true
	if _player is CharacterBody3D:
		(_player as CharacterBody3D).enter_boat(self)
		_player.global_position = global_position + SEAT_OFFSET


func _player_is_aboard() -> bool:
	if not is_instance_valid(_player):
		return false
	if _player.has_method("is_in_boat"):
		return bool(_player.call("is_in_boat"))
	return true


## Rend les commandes au joueur et remet le vehicule au repos.
func _release() -> void:
	_controlled = false
	velocity = Vector3.ZERO
	if is_instance_valid(_player) and _player is CharacterBody3D:
		(_player as CharacterBody3D).exit_boat()
	_player = null


func get_interaction_prompt() -> String:
	if not _controlled:
		return "Monter à bord"
	return "Descendre"
