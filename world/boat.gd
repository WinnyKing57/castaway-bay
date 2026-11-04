class_name Boat
extends CharacterBody3D
## Bateau du portage d'Ocean Is Home : locomotion sur l'eau.
##
## Physique simple : le bateau est propulsé par l'utilisateur via les actions
## de la barre rapide / de déplacement, et consomme du carburant.

const SPEED := 5.0
const TURN_SPEED := 2.5
const FUEL_MAX := 30.0
const FUEL_PER_ITEM := 30.0
const FUEL_ITEM_ID := "fuel"
const METAL_ITEM_ID := "metal"
## Position du joueur par rapport au bateau (le corps flotte à mi-hauteur).
const SEAT_OFFSET := Vector3(0.0, 1.0, 0.0)

var fuel := FUEL_MAX
var metal := 0
var _controlled := false
var _player: Node3D = null


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.9
	capsule.height = 2.4
	shape.shape = capsule
	add_child(shape)


func _physics_process(delta: float) -> void:
	if not _controlled:
		velocity = Vector3.ZERO
		return
	# Le joueur a quitté le bateau sans passer par interact() (mort, chargement,
	# nouvelle partie, respawn) : on libère les commandes pour ne pas rester
	# piloté « dans le vide ».
	if GameState.is_dead or not _player_is_aboard():
		_release()
		return
	if global_position.y > 0.5:
		velocity = Vector3.ZERO
		return
	# Menus ouverts (artisanat, mort...) : le bateau ne répond plus aux touches.
	var can_steer := true
	if is_instance_valid(_player) and _player.has_method("are_controls_enabled"):
		can_steer = bool(_player.call("are_controls_enabled"))
	var input := Vector2.ZERO
	if can_steer:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")

	# Rotation du gouvernail (touches gauche / droite)
	if absf(input.x) > 0.01:
		rotate_y(-input.x * TURN_SPEED * delta)

	# Propulsion avant / arrière (touches avancer / reculer)
	var throttle := -input.y
	# Recharge automatique quand le réservoir est vide et qu'on a du carburant.
	if absf(throttle) > 0.01 and fuel <= 0.0 and GameState.remove_item(FUEL_ITEM_ID, 1):
		fuel = FUEL_MAX

	if absf(throttle) > 0.01 and fuel > 0.0:
		var speed := SPEED if throttle > 0.0 else SPEED * 0.5
		velocity = -transform.basis.z * throttle * speed
		fuel = maxf(0.0, fuel - delta * 3.0)
	else:
		velocity = Vector3.ZERO
	move_and_slide()
	# Le joueur est assis dans le bateau : il suit sa position (sa propre
	# physique est suspendue pendant la navigation).
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
		"fuel": fuel,
	}


## Restaure position, cap et carburant (valeurs sûres : finies, dans le monde).
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
	var saved_fuel: Variant = state.get("fuel")
	if (typeof(saved_fuel) == TYPE_FLOAT or typeof(saved_fuel) == TYPE_INT) and is_finite(float(saved_fuel)):
		fuel = clampf(float(saved_fuel), 0.0, FUEL_MAX)


func interact(player: Node) -> void:
	if not _controlled and fuel <= 0.0 and GameState.get_item_count(METAL_ITEM_ID) > 0:
		repair()
		return
	if _controlled:
		_release()
		return
	if fuel <= 0.0 and GameState.get_item_count(FUEL_ITEM_ID) <= 0:
		GameState.notify("Bateau : carburant insuffisant")
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


## Rend les commandes au joueur et remet le bateau au repos.
func _release() -> void:
	_controlled = false
	velocity = Vector3.ZERO
	if is_instance_valid(_player) and _player is CharacterBody3D:
		(_player as CharacterBody3D).exit_boat()
	_player = null


func get_interaction_prompt() -> String:
	if not _controlled:
		if fuel <= 0.0 and GameState.get_item_count(METAL_ITEM_ID) > 0:
			return "Réparer le bateau"
		return "Monter à bord"
	if fuel <= 0.0:
		return "Pas de carburant"
	return "Descendre"


func repair() -> void:
	# Une réparation consomme 1 métal de l'inventaire du joueur.
	if GameState.remove_item(METAL_ITEM_ID, 1):
		fuel = FUEL_MAX
		GameState.notify("Bateau réparé")
