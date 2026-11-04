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
const FUEL_DRAIN_PER_SECOND := 0.5
const FUEL_ITEM_ID := "fuel"
const METAL_ITEM_ID := "metal"

## État de réparation : true = coque percée (immobile), false = réparé.
var broken := true
var fuel := FUEL_MAX
var _fuel_warning_shown := false
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
	if not _controlled or broken:
		velocity = Vector3.ZERO
		return
	if global_position.y > 0.0:
		velocity = Vector3.ZERO
		return
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (transform.basis * Vector3(input.x, 0.0, input.y)).normalized()
	if direction.length() > 0.0 and fuel > 0.0:
		velocity = direction * SPEED
		fuel = maxf(0.0, fuel - _delta * FUEL_DRAIN_PER_SECOND)
		if fuel <= 0.0 and GameState.get_item_count(FUEL_ITEM_ID) > 0:
			GameState.remove_item(FUEL_ITEM_ID, 1)
			fuel = FUEL_MAX
	else:
		velocity = Vector3.ZERO
	move_and_slide()
	if _player is CharacterBody3D:
		# Le joueur voyage avec le bateau : on le déplace et on le garde
		# au-dessus de l'eau tant qu'il est à bord.
		_player.global_position = global_position + Vector3(0.0, 1.2, 0.0)


func interact(player: Node) -> void:
	if broken:
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
		(_player as CharacterBody3D).enter_boat(self)


func get_interaction_prompt() -> String:
	if broken:
		return "Réparer le bateau (1 métal)"
	if not _controlled:
		if fuel <= 0.0 and GameState.get_item_count(FUEL_ITEM_ID) <= 0:
			return "Bateau : pas de carburant"
		return "Monter à bord"
	if fuel <= 0.0:
		return "Descendre (plus de carburant)"
	return "Descendre"


## Répare la coque : consomme 1 métal dans l'inventaire du joueur.
func repair(player: Node = null) -> bool:
	if not broken:
		return false
	if GameState.remove_item(METAL_ITEM_ID, 1):
		broken = false
		fuel = FUEL_MAX
		GameState.notify("Bateau réparé ! Prêt à appareiller.")
		return true
	else:
		GameState.notify("Réparation impossible : il faut 1 morceau de métal.")
		return false


## Données persistantes du bateau. Le contrôle n'est jamais restauré :
## le joueur recharge toujours à pied pour éviter un état d'entrée incohérent.
func get_save_data() -> Dictionary:
	return {
		"position": [global_position.x, global_position.y, global_position.z],
		"rotation_y": rotation.y,
		"broken": broken,
		"fuel": fuel,
	}


func apply_save_data(data: Dictionary) -> void:
	var saved_position: Array = data.get("position", [])
	if saved_position.size() == 3:
		global_position = Vector3(float(saved_position[0]), float(saved_position[1]), float(saved_position[2]))
	rotation.y = float(data.get("rotation_y", rotation.y))
	broken = bool(data.get("broken", broken))
	fuel = clampf(float(data.get("fuel", fuel)), 0.0, FUEL_MAX)
	_controlled = false
	_player = null
	velocity = Vector3.ZERO
