extends Node3D
## Point d'entrée du jeu (scène main.tscn).
##
## Rôle : assembler le monde, placer le joueur, brancher le HUD,
## et gérer les commandes globales (sauvegarde, souris, outils de dev).

@onready var world: Island = $World
@onready var player: Player = $Player
@onready var hud: Hud = $HUD


func _ready() -> void:
	player.global_position = world.find_spawn_point()
	hud.setup(player)
	GameState.notify("Bienvenue — approche un arbre et appuie sur E")

	if "--overview" in OS.get_cmdline_user_args():
		_apply_overview_camera()

	if "--smoke-test" in OS.get_cmdline_user_args():
		await _run_smoke_test()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = (
			Input.MOUSE_MODE_VISIBLE
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
			else Input.MOUSE_MODE_CAPTURED
		)

	if event.is_action_pressed("save_game"):
		if SaveSystem.save_game(player):
			GameState.notify("Partie sauvegardée")
		else:
			GameState.notify("Échec de la sauvegarde")

	if event.is_action_pressed("load_game"):
		if SaveSystem.load_game_into(player):
			GameState.notify("Partie chargée")
		else:
			GameState.notify("Aucune sauvegarde")


## Outil de développement : vue aérienne pour inspecter l'île générée.
## Usage : ./run.sh --overview
func _apply_overview_camera() -> void:
	player.set_physics_process(false)
	player.global_position = Vector3(0.0, 140.0, 0.1)
	player.rotation = Vector3.ZERO
	var head: Node3D = player.get_node("Head")
	head.rotation.x = -deg_to_rad(89.0)


# --- Test d'intégration (./run.sh --test) ------------------------------------

func _run_smoke_test() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	var errors: PackedStringArray = []

	if player == null:
		errors.append("joueur absent")
	if world == null or world.get_mesh_instance() == null:
		errors.append("terrain absent")
	if hud == null:
		errors.append("HUD absent")
	if Database.items.size() < 3:
		errors.append("base d'objets incomplète (%d)" % Database.items.size())
	if Database.recipes.size() < 1:
		errors.append("aucune recette chargée")
	if player != null and player.global_position.y < 0.0:
		errors.append("joueur sous le niveau de la mer")

	var wood_before := GameState.get_item_count("wood")
	GameState.add_item("wood", 3)
	if GameState.get_item_count("wood") != wood_before + 3:
		errors.append("ajout d'objet KO")
	if not GameState.remove_item("wood", 1):
		errors.append("retrait d'objet KO")

	var expected := GameState.get_item_count("wood")
	if not SaveSystem.save_game(player):
		errors.append("écriture de sauvegarde KO")
	GameState.inventory.clear()
	if not SaveSystem.load_game_into(player):
		errors.append("lecture de sauvegarde KO")
	if GameState.get_item_count("wood") != expected:
		errors.append("inventaire non restauré")

	if errors.is_empty():
		print("SMOKE_TEST OK")
		get_tree().quit(0)
	else:
		print("SMOKE_TEST ECHEC : ", ", ".join(errors))
		get_tree().quit(1)
