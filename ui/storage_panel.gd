class_name StoragePanel
extends Control
## Panneau de stockage (coffres).
##
## Permet de déposer et retirer des objets entre l'inventaire du joueur
## et le coffre sélectionné.

signal opened
signal closed

var _current_chest: Buildable = null

@onready var chest_items_box: VBoxContainer = $Panel/Margin/VBox/Columns/ChestCol/ChestScroll/ChestItems
@onready var player_items_box: VBoxContainer = $Panel/Margin/VBox/Columns/PlayerCol/PlayerScroll/PlayerItems
@onready var deposit_all_btn: Button = $Panel/Margin/VBox/QuickActions/DepositAll
@onready var take_all_btn: Button = $Panel/Margin/VBox/QuickActions/TakeAll
@onready var close_button: Button = $Panel/Margin/VBox/Close


func _ready() -> void:
	visible = false
	close_button.pressed.connect(close)
	deposit_all_btn.pressed.connect(_on_deposit_all)
	take_all_btn.pressed.connect(_on_take_all)
	GameState.chest_opened.connect(open)
	GameState.inventory_changed.connect(_on_inventory_changed)


func is_open() -> bool:
	return visible


func open(chest: Node) -> void:
	if not chest is Buildable or (chest as Buildable).kind != "chest":
		return
	_current_chest = chest as Buildable
	visible = true
	_rebuild()
	opened.emit()


func close() -> void:
	if not visible:
		return
	visible = false
	_current_chest = null
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		close()


func _on_inventory_changed() -> void:
	if visible:
		_rebuild()


func _rebuild() -> void:
	if _current_chest == null or not is_instance_valid(_current_chest):
		close()
		return

	for child in chest_items_box.get_children():
		child.queue_free()
	for child in player_items_box.get_children():
		child.queue_free()

	# Objets du coffre
	var chest_keys := _current_chest.chest_inventory.keys()
	chest_keys.sort()
	if chest_keys.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Coffre vide"
		empty_lbl.modulate = Color(0.7, 0.7, 0.7)
		chest_items_box.add_child(empty_lbl)
	else:
		for item_id in chest_keys:
			var count: int = _current_chest.chest_inventory[item_id]
			if count <= 0:
				continue
			var row := HBoxContainer.new()
			var name_lbl := Label.new()
			name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_lbl.text = "%s x%d" % [GameState.display_name(str(item_id)), count]
			row.add_child(name_lbl)

			var take_one := Button.new()
			take_one.text = "+1"
			take_one.pressed.connect(_take_from_chest.bind(str(item_id), 1))
			row.add_child(take_one)

			var take_all := Button.new()
			take_all.text = "Tout"
			take_all.pressed.connect(_take_from_chest.bind(str(item_id), count))
			row.add_child(take_all)

			chest_items_box.add_child(row)

	# Objets du joueur
	var player_keys := GameState.inventory.keys()
	player_keys.sort()
	if player_keys.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Inventaire vide"
		empty_lbl.modulate = Color(0.7, 0.7, 0.7)
		player_items_box.add_child(empty_lbl)
	else:
		for item_id in player_keys:
			var count: int = GameState.get_item_count(str(item_id))
			if count <= 0:
				continue
			var row := HBoxContainer.new()
			var name_lbl := Label.new()
			name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_lbl.text = "%s x%d" % [GameState.display_name(str(item_id)), count]
			row.add_child(name_lbl)

			var put_one := Button.new()
			put_one.text = "+1"
			put_one.pressed.connect(_put_in_chest.bind(str(item_id), 1))
			row.add_child(put_one)

			var put_all := Button.new()
			put_all.text = "Tout"
			put_all.pressed.connect(_put_in_chest.bind(str(item_id), count))
			row.add_child(put_all)

			player_items_box.add_child(row)


func _take_from_chest(item_id: String, amount: int) -> void:
	if _current_chest == null or not is_instance_valid(_current_chest):
		return
	var available: int = _current_chest.chest_inventory.get(item_id, 0)
	var to_take := mini(amount, available)
	if to_take <= 0:
		return
	_current_chest.chest_inventory[item_id] = available - to_take
	if _current_chest.chest_inventory[item_id] <= 0:
		_current_chest.chest_inventory.erase(item_id)
	GameState.add_item(item_id, to_take)
	Sfx.play_ui("ui")
	_rebuild()


func _put_in_chest(item_id: String, amount: int) -> void:
	if _current_chest == null or not is_instance_valid(_current_chest):
		return
	var player_has := GameState.get_item_count(item_id)
	var to_put := mini(amount, player_has)
	if to_put <= 0:
		return
	if GameState.remove_item(item_id, to_put):
		_current_chest.chest_inventory[item_id] = _current_chest.chest_inventory.get(item_id, 0) + to_put
		Sfx.play_ui("ui")
		_rebuild()


func _on_deposit_all() -> void:
	if _current_chest == null or not is_instance_valid(_current_chest):
		return
	var items := GameState.inventory.keys()
	var deposited := false
	for item_id in items:
		var count := GameState.get_item_count(str(item_id))
		if count > 0 and GameState.remove_item(str(item_id), count):
			_current_chest.chest_inventory[str(item_id)] = _current_chest.chest_inventory.get(str(item_id), 0) + count
			deposited = true
	if deposited:
		Sfx.play_ui("ui")
		_rebuild()


func _on_take_all() -> void:
	if _current_chest == null or not is_instance_valid(_current_chest):
		return
	var keys := _current_chest.chest_inventory.keys()
	var taken := false
	for item_id in keys:
		var count: int = _current_chest.chest_inventory[item_id]
		if count > 0:
			GameState.add_item(str(item_id), count)
			taken = true
	_current_chest.chest_inventory.clear()
	if taken:
		Sfx.play_ui("ui")
		_rebuild()
