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


func _physics_process(_delta: float) -> void:
	if not _controlled:
		velocity = Vector3.ZERO
		return
	# Le joueur a quitté le bateau sans passer par interact() (mort, chargement,
	# nouvelle partie, respawn) : on libère les commandes pour ne pas rester
	# piloté « dans le vide ».
	if GameState.is_dead or not _player_is_aboard():
		_release()
		return
	if global_position.y > 0.0:
		velocity = Vector3.ZERO
		return
	var input := Input.get_vector("move_forward", "move_backward", "move_left", "move_right")
	var direction := (transform.basis * Vector3(input.x, 0.0, input.y)).normalized()
	# Recharge automatique quand le réservoir est vide et qu'on a du carburant.
	if fuel <= 0.0 and direction.length() > 0.0 and GameState.remove_item(FUEL_ITEM_ID, 1):
		fuel = FUEL_MAX
	if direction.length() > 0.0 and fuel > 0.0:
		velocity = direction * SPEED
		fuel = maxf(0.0, fuel - _delta * 5.0)
	else:
		velocity = Vector3.ZERO
	move_and_slide()
	# Le joueur est assis dans le bateau : il suit sa position (sa propre
	# physique est suspendue pendant la navigation).
	if is_instance_valid(_player):
		_player.global_position = global_position + SEAT_OFFSET
		if _player is CharacterBody3D:
			(_player as CharacterBody3D).velocity = Vector3.ZERO


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
		(_player as CharacterBody3D).enter_boat()
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
