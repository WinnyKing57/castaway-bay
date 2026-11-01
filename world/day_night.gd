extends DirectionalLight3D
## Cycle jour / nuit.
##
## Le soleil tourne autour de l'île en fonction de GameState.world_time
## et l'ambiance (lumière, brouillard, ciel) suit l'élévation du soleil.

@export var max_energy := 1.6
@export var night_energy := 0.06
@export var day_color := Color(1.0, 0.96, 0.88)
@export var sunset_color := Color(1.0, 0.62, 0.38)

var _environment: Environment
var _sky_material: ProceduralSkyMaterial


func _ready() -> void:
	_environment = get_viewport().world_3d.environment
	if _environment != null and _environment.sky != null:
		_sky_material = _environment.sky.sky_material as ProceduralSkyMaterial


func _process(_delta: float) -> void:
	var day_ratio: float = GameState.world_time / GameState.SECONDS_PER_DAY

	# 0.25 = 6 h (lever), 0.5 = midi, 0.75 = 18 h (coucher).
	var sun_angle := (day_ratio - 0.25) * TAU
	var sun_direction := Vector3(cos(sun_angle), sin(sun_angle), 0.35).normalized()

	# La lumière éclaire depuis le soleil vers le sol.
	look_at_from_position(Vector3.ZERO, -sun_direction, Vector3.UP)

	var elevation := clampf(sin(sun_angle), 0.0, 1.0)
	light_energy = lerpf(night_energy, max_energy, elevation)
	light_color = sunset_color.lerp(day_color, clampf(elevation * 2.5, 0.0, 1.0))

	if _environment != null:
		_environment.ambient_light_energy = lerpf(0.25, 0.9, elevation)
		_environment.fog_light_color = Color(0.05, 0.08, 0.14).lerp(Color(0.62, 0.72, 0.82), elevation)

	if _sky_material != null:
		_sky_material.sky_top_color = Color(0.02, 0.03, 0.09).lerp(Color(0.18, 0.36, 0.62), elevation)
		_sky_material.sky_horizon_color = Color(0.05, 0.07, 0.13).lerp(Color(0.62, 0.74, 0.86), elevation)
