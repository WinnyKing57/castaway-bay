class_name Trader
extends StaticBody3D
## Automate de troc / marchand itinérant : échange d'objets avec le joueur.

var stock: Dictionary = {"metal": 2, "crystal": 1}
var _sell_item := "metal"
var _sell_qty := 1


func get_interaction_prompt() -> String:
	return "Échanger avec le marchand (E)"


func interact(_player: Node) -> void:
	if not _can_trade():
		GameState.notify("Marchand : objet insuffisant")
		return
	var gave := GameState.remove_item(_sell_item, _sell_qty)
	if not gave:
		GameState.notify("Marchand : objet insuffisant")
		return
	var keys := PackedStringArray()
	for item_id in stock:
		keys.append(str(item_id))
	for key in keys:
		var item_key: String = key
		var qty := int(stock.get(item_key, 0))
		if qty > 0:
			GameState.add_item(item_key, qty)
			stock[item_key] = qty - 1
	GameState.notify("Marchand : échange effectué")


func _can_trade() -> bool:
	return GameState.get_item_count(_sell_item) >= _sell_qty and not stock.is_empty()


func get_save_state() -> Dictionary:
	return {
		"position": [global_position.x, global_position.y, global_position.z],
		"rotation_y": rotation.y,
		"stock": stock.duplicate(),
	}


func apply_save_state(state: Dictionary) -> void:
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
	var saved_stock: Variant = state.get("stock", {})
	if typeof(saved_stock) == TYPE_DICTIONARY:
		var new_stock := {}
		for key in saved_stock:
			var item_key: String = str(key)
			var qty := int(float(saved_stock[item_key]))
			if qty > 0:
				new_stock[item_key] = qty
		stock = new_stock
