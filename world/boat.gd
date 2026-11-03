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
	if global_position.y > 0.0:
		velocity = Vector3.ZERO
		return
	var input := Input.get_vector("move_forward", "move_backward", "move_left", "move_right")
	var direction := (transform.basis * Vector3(input.x, 0.0, input.y)).normalized()
	if direction.length() > 0.0 and fuel > 0.0:
		velocity = direction * SPEED
		fuel = maxf(0.0, fuel - _delta * 5.0)
		if fuel <= 0.0 and GameState.get_item_count(FUEL_ITEM_ID) > 0:
			GameState.remove_item(FUEL_ITEM_ID, 1)
			fuel = FUEL_MAX
	else:
		velocity = Vector3.ZERO
	move_and_slide()
	if _player is CharacterBody3D:
		(_player as CharacterBody3D).velocity = velocity


func interact(player: Node) -> void:
	if not _controlled and fuel <= 0.0 and GameState.get_item_count(METAL_ITEM_ID) > 0:
		repair()
		return
	_controlled = not _controlled
	_player = player if is_instance_valid(player) else null
	if not _controlled:
		if _player is CharacterBody3D:
			(_player as CharacterBody3D).exit_boat()
		_player = null
		return
	if fuel <= 0.0 and GameState.get_item_count(FUEL_ITEM_ID) <= 0:
		_controlled = false
		GameState.notify("Bateau : carburant insuffisant")
		return
	if _player is CharacterBody3D:
		(_player as CharacterBody3D).enter_boat()


func get_interaction_prompt() -> String:
	if not _controlled:
		if fuel <= 0.0 and GameState.get_item_count(METAL_ITEM_ID) > 0:
			return "Réparer le bateau"
		return "Monter à bord"
	if fuel <= 0.0:
		return "Pas de carburant"
	return "Descendre"


func repair() -> void:
	if metal > 0 and GameState.get_item_count(METAL_ITEM_ID) > 0:
		GameState.remove_item(METAL_ITEM_ID, 1)
		metal -= 1
		fuel = FUEL_MAX
		GameState.notify("Bateau réparé")
