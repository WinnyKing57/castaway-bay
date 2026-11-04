class_name Player
extends CharacterBody3D
## Contrôleur joueur à la première personne.
##
## M0 : déplacement, course, saut, regard souris et interaction au raycast.
## Les états (nage, véhicule, construction) viendront dans les jalons suivants,
## d'où la séparation déjà nette entre input / physique / interaction.

signal interaction_target_changed(prompt: String)

const WALK_SPEED := 4.5
const SPRINT_SPEED := 7.5
const JUMP_VELOCITY := 5.0
## Multiplicateur appliqué à la sensibilité de base de la souris (0.0022).
## Les valeurs viennent de l'autoload Settings (réglages persistants).
const MOUSE_SENSITIVITY := 0.0022
const PITCH_LIMIT := deg_to_rad(89.0)

## Niveau de la mer (doit correspondre à Island.SEA_LEVEL).
const WATER_LEVEL := 0.0
const SWIM_SPEED := 3.2
const SWIM_FAST_SPEED := 5.0
const SWIM_UP_SPEED := 3.6
## Seuils d'entrée/sortie de l'eau (hystérésis : évite le clignotement).
const SWIM_ENTER_DEPTH := 1.4
const SWIM_EXIT_DEPTH := 0.5
## Profondeur à laquelle le joueur flotte (le corps est à moitié immergé).
const SWIM_FLOAT_DEPTH := 1.0
## Limite du monde : le terrain fait ±130 m, on reste dans ce cercle.
const WORLD_RADIUS := 128.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var ray: RayCast3D = $Head/Camera3D/RayCast3D

var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
var _current_prompt := ""
var _controls_enabled := true
var _torch_light: OmniLight3D
var _swimming := false
var _step_timer := 0.0
var _in_boat := false


func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Lumière portée : allumée seulement quand la torche est sélectionnée.
	_torch_light = OmniLight3D.new()
	_torch_light.light_color = Color(1.0, 0.62, 0.28)
	_torch_light.light_energy = 1.6
	_torch_light.omni_range = 8.0
	_torch_light.position = Vector3(0.0, 1.2, 0.0)
	_torch_light.visible = false
	add_child(_torch_light)

	GameState.hotbar_changed.connect(_update_torch_light)
	GameState.inventory_changed.connect(_update_torch_light)
	_update_torch_light()


func _update_torch_light() -> void:
	if _torch_light == null:
		return
	var item := GameState.selected_hotbar_item()
	_torch_light.visible = item == "torch" and GameState.get_item_count("torch") > 0


## Active/désactive les commandes (utilisé par les menus et le mode construction).
func set_controls_enabled(enabled: bool) -> void:
	_controls_enabled = enabled
	set_physics_process(enabled)
	set_process_unhandled_input(enabled)
	if not enabled:
		velocity.x = 0.0
		velocity.z = 0.0
		_current_prompt = ""
		interaction_target_changed.emit("")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY * Settings.mouse_sensitivity)
		head.rotate_x(-event.relative.y * MOUSE_SENSITIVITY * Settings.mouse_sensitivity)
		head.rotation.x = clampf(head.rotation.x, -PITCH_LIMIT, PITCH_LIMIT)

	if event.is_action_pressed("interact"):
		_try_interact()


func _physics_process(delta: float) -> void:
	if _in_boat:
		return
	var was_swimming := _swimming
	# Hystérésis : on entre dans l'eau plus profond qu'on n'en sort.
	var depth := WATER_LEVEL - global_position.y
	_swimming = depth > (SWIM_EXIT_DEPTH if _swimming else SWIM_ENTER_DEPTH)
	if _swimming != was_swimming:
		Sfx.play("splash", global_position, -5.0)

	if _swimming:
		# L'eau porte le joueur : il remonte vers la surface puis flotte.
		var target_y := WATER_LEVEL - SWIM_FLOAT_DEPTH
		var desired := clampf((target_y - global_position.y) * 2.0, -2.0, 2.5)
		velocity.y = move_toward(velocity.y, desired, 12.0 * delta)
		if Input.is_action_pressed("jump"):
			velocity.y = SWIM_UP_SPEED
	else:
		if not is_on_floor():
			velocity.y -= _gravity * delta
		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = JUMP_VELOCITY

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	var speed := WALK_SPEED
	if _swimming:
		speed = SWIM_FAST_SPEED if Input.is_action_pressed("sprint") else SWIM_SPEED
	elif Input.is_action_pressed("sprint"):
		speed = SPRINT_SPEED

	if direction.length_squared() > 0.0:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)

	move_and_slide()
	# Limite du monde : on clamp le joueur dans le cercle de rayon WORLD_RADIUS.
	var horizontal := Vector2(global_position.x, global_position.z)
	if horizontal.length() > WORLD_RADIUS:
		var angle := atan2(global_position.z, global_position.x)
		global_position.x = cos(angle) * WORLD_RADIUS
		global_position.z = sin(angle) * WORLD_RADIUS
	_update_interaction_prompt()
	_update_footsteps(delta)


## Vrai quand le joueur nage (l'eau lui arrive au-dessus de la taille).
func enter_boat() -> void:
	_in_boat = true


func exit_boat() -> void:
	_in_boat = false


func is_in_boat() -> bool:
	return _in_boat


func is_swimming() -> bool:
	return _swimming


## Vrai quand la caméra est sous la surface (utilisé par le HUD).
func is_underwater() -> bool:
	return camera.global_position.y < WATER_LEVEL


func _update_footsteps(delta: float) -> void:
	if _swimming or not is_on_floor():
		_step_timer = 0.0
		return

	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if horizontal_speed < 0.6:
		_step_timer = 0.0
		return

	_step_timer -= delta
	if _step_timer <= 0.0:
		var sprinting := Input.is_action_pressed("sprint")
		_step_timer = 0.3 if sprinting else 0.45
		Sfx.play("step", global_position, -14.0)


# --- Interaction ------------------------------------------------------------

func _update_interaction_prompt() -> void:
	var prompt := ""
	var target := _get_interaction_target()
	if target != null:
		prompt = str(target.get_interaction_prompt())

	if prompt != _current_prompt:
		_current_prompt = prompt
		interaction_target_changed.emit(prompt)


func _try_interact() -> void:
	var target := _get_interaction_target()
	if target != null:
		target.interact(self)
		ray.force_raycast_update()
		_update_interaction_prompt()


func _get_interaction_target() -> Node:
	if not ray.is_colliding():
		return null
	var collider := ray.get_collider()
	if collider != null and collider.has_method("interact") and collider.has_method("get_interaction_prompt"):
		return collider
	return null
