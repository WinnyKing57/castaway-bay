class_name Boat
extends Vehicle
## Bateau du portage d'Ocean Is Home : locomotion sur l'eau.
##
## Physique simple : le bateau est propulsé par l'utilisateur via les actions de
## la barre rapide / de deplacement, et consomme du carburant.

const FUEL_MAX := 30.0
const FUEL_PER_ITEM := 30.0


func _speed() -> float:
	return 5.0


func _turn_speed() -> float:
	return 2.5


func _reverse_speed() -> float:
	return 2.5


func _fuel_enabled() -> bool:
	return true


func _fuel_max() -> float:
	return FUEL_MAX


func _fuel_per_item() -> float:
	return FUEL_PER_ITEM


func _seat_offset() -> Vector3:
	return Vector3(0.0, 1.0, 0.0)


func _collision_mask() -> int:
	return 0


func _shape_radius() -> float:
	return 0.9


func _shape_height() -> float:
	return 2.4


func get_save_state() -> Dictionary:
	var state := super.get_save_state()
	state["fuel"] = fuel
	return state


func apply_save_state(state: Dictionary) -> void:
	super.apply_save_state(state)
	var saved_fuel: Variant = state.get("fuel")
	if (typeof(saved_fuel) == TYPE_FLOAT or typeof(saved_fuel) == TYPE_INT) and is_finite(float(saved_fuel)):
		fuel = clampf(float(saved_fuel), 0.0, _fuel_max())


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
	board(player)


func get_interaction_prompt() -> String:
	if not _controlled:
		if fuel <= 0.0 and GameState.get_item_count(METAL_ITEM_ID) > 0:
			return "Réparer le bateau"
		return "Monter à bord"
	if fuel <= 0.0:
		return "Pas de carburant"
	return "Descendre"


func repair() -> void:
	if GameState.remove_item(METAL_ITEM_ID, 1):
		fuel = _fuel_max()
		GameState.notify("Bateau réparé")
