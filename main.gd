extends Node3D
## Point d'entrée du jeu (scène main.tscn).
##
## Rôle : assembler le monde, placer le joueur, brancher le HUD,
## et gérer les commandes globales (sauvegarde, souris, mort, outils de dev).

@onready var world: Island = $World
@onready var player: Player = $Player
@onready var hud: Hud = $HUD
@onready var crafting_panel: CraftingPanel = $HUD/CraftingPanel
@onready var menu: MenuPanel = $HUD/MenuPanel
@onready var settings_panel: SettingsPanel = $HUD/SettingsPanel
@onready var construction: Construction = $Construction


func _ready() -> void:
	player.global_position = world.find_spawn_point()
	hud.setup(player)
	construction.setup(player, hud)
	GameState.died.connect(_on_player_died)
	crafting_panel.opened.connect(_on_crafting_opened)
	crafting_panel.closed.connect(_on_crafting_closed)
	menu.new_game_requested.connect(_on_menu_new_game)
	menu.continue_requested.connect(_on_menu_continue)
	menu.resume_requested.connect(_on_menu_resume)
	menu.save_requested.connect(_on_menu_save)
	menu.settings_requested.connect(_on_menu_settings)
	menu.main_menu_requested.connect(_on_menu_main_menu)
	settings_panel.closed.connect(_on_settings_closed)
	menu.quit_requested.connect(_on_menu_quit)

	if _is_dev_run():
		GameState.notify("Bienvenue — approche un arbre et appuie sur E")
	else:
		_show_start_menu()

	if "--overview" in OS.get_cmdline_user_args():
		_apply_overview_camera()

	# Outil de développement : ouvre un panneau au démarrage pour les captures.
	if "--show-crafting" in OS.get_cmdline_user_args():
		crafting_panel.open()

	if "--smoke-test" in OS.get_cmdline_user_args():
		await _run_smoke_test()


## Les outils de dev (tests, captures) démarrent directement en jeu.
func _is_dev_run() -> bool:
	var args := OS.get_cmdline_user_args()
	return "--smoke-test" in args or "--overview" in args or "--show-crafting" in args


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if crafting_panel.is_open():
			crafting_panel.close()
			return
		if construction.is_active():
			construction.toggle()
			return
		if not GameState.is_dead:
			_open_pause_menu()
			return

	if GameState.is_dead:
		if event.is_action_pressed("ui_accept"):
			_respawn()
		return

	if event.is_action_pressed("toggle_crafting"):
		if construction.is_active():
			construction.toggle()
		crafting_panel.toggle()
		return

	if event.is_action_pressed("toggle_build"):
		if crafting_panel.is_open():
			crafting_panel.close()
		construction.toggle()
		return

	if crafting_panel.is_open():
		return

	if event.is_action_pressed("save_game"):
		if SaveSystem.save_game(player, construction):
			GameState.notify("Partie sauvegardée")
		else:
			GameState.notify("Échec de la sauvegarde")

	if event.is_action_pressed("load_game"):
		if SaveSystem.load_game_into(player, world, construction):
			GameState.notify("Partie chargée")
		else:
			GameState.notify("Aucune sauvegarde")

	if event.is_action_pressed("use_item"):
		GameState.use_selected_item()

	for index in GameState.hotbar_items.size():
		var hotbar_action: String = "hotbar_%d" % (index + 1)
		if InputMap.has_action(hotbar_action) and event.is_action_pressed(hotbar_action):
			GameState.select_hotbar(index)


# --- Menus -------------------------------------------------------------------

func _show_start_menu() -> void:
	menu.open_start()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _open_pause_menu() -> void:
	if crafting_panel.is_open():
		crafting_panel.close()
	if construction.is_active():
		construction.toggle()
	menu.open_pause()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _resume_game() -> void:
	get_tree().paused = false
	menu.close()
	player.set_controls_enabled(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_menu_new_game() -> void:
	GameState.reset()
	construction.clear_all()
	world.regenerate(randi())
	player.global_position = world.find_spawn_point()
	player.velocity = Vector3.ZERO
	hud.hide_death()
	_resume_game()
	GameState.notify("Nouvelle île, nouvelle vie.")


func _on_menu_continue() -> void:
	if not SaveSystem.load_game_into(player, world, construction):
		GameState.notify("Aucune sauvegarde")
		return
	hud.hide_death()
	_resume_game()
	GameState.notify("Partie chargée")


func _on_menu_resume() -> void:
	_resume_game()


func _on_menu_save() -> void:
	if SaveSystem.save_game(player, construction):
		GameState.notify("Partie sauvegardée")
	else:
		GameState.notify("Échec de la sauvegarde")


func _on_settings_closed() -> void:
	if menu.is_open():
		menu.visible = true
		menu.reopen()

func _on_menu_settings() -> void:
	settings_panel.open()
	menu.visible = false


func _on_menu_main_menu() -> void:
	_show_start_menu()


func _on_menu_quit() -> void:
	get_tree().quit()


func _on_player_died() -> void:
	if crafting_panel.is_open():
		crafting_panel.close()
	if construction.is_active():
		construction.toggle()
	Sfx.play_ui("death")
	player.set_controls_enabled(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_crafting_opened() -> void:
	if construction.is_active():
		construction.toggle()
	player.set_controls_enabled(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_crafting_closed() -> void:
	if GameState.is_dead:
		return
	player.set_controls_enabled(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _respawn() -> void:
	GameState.respawn()
	player.global_position = world.find_spawn_point()
	player.velocity = Vector3.ZERO
	player.set_controls_enabled(true)
	hud.hide_death()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	GameState.notify("Tu te réveilles sur la plage...")


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
	if menu == null:
		errors.append("menu absent")
	if Database.items.size() < 5:
		errors.append("base d'objets incomplète (%d)" % Database.items.size())
	if Database.recipes.size() < 2:
		errors.append("recettes incomplètes (%d)" % Database.recipes.size())
	if Database.buildables.size() < 3:
		errors.append("constructibles incomplets (%d)" % Database.buildables.size())
	if player != null and player.global_position.y < 0.0:
		errors.append("joueur sous le niveau de la mer")

	# Végétation : l'île doit contenir de quoi survivre (bois, fibres, cocos).
	var kinds := {"arbre": 0, "palmier": 0, "rocher": 0, "buisson": 0}
	for child in world.get_children():
		if child is Harvestable:
			kinds[child.kind] = int(kinds.get(child.kind, 0)) + 1
	print("[Test] végétation : ", kinds)
	if int(kinds["palmier"]) == 0:
		errors.append("aucun palmier généré")
	if int(kinds["arbre"]) == 0:
		errors.append("aucun arbre généré")

	# Récolte : butin ajouté et ressource déplétée (elle repoussera plus tard).
	var test_tree: Harvestable = null
	for child in world.get_children():
		if child is Harvestable and child.kind == "arbre":
			test_tree = child
			break
	if test_tree == null:
		errors.append("arbre introuvable pour le test de récolte")
	else:
		var wood_before_harvest := GameState.get_item_count("wood")
		test_tree.interact(player)
		if GameState.get_item_count("wood") <= wood_before_harvest:
			errors.append("récolte KO")
		if test_tree.visible:
			errors.append("ressource non déplétée après récolte")

	# Sons synthétisés : tous les effets doivent exister.
	var sound_names := PackedStringArray(["harvest", "eat", "craft", "build", "step", "splash", "death", "ui"])
	for sound in sound_names:
		var wav := Sfx.get_stream(sound) as AudioStreamWAV
		if wav == null or wav.data.is_empty():
			errors.append("son manquant : %s" % sound)

	# Nage : on place le joueur au-dessus d'un fond profond, au large.
	var swim_point := Vector3.ZERO
	var radii: Array[float] = [120.0, 124.0, 127.0]
	for radius in radii:
		for i in 24:
			var angle := i * TAU / 24.0
			var sx: float = cos(angle) * radius
			var sz: float = sin(angle) * radius
			var ground := world.get_height_at(sx, sz)
			if ground < -2.0:
				swim_point = Vector3(sx, ground + 0.2, sz)
				break
		if swim_point != Vector3.ZERO:
			break
	if swim_point == Vector3.ZERO:
		errors.append("aucune zone profonde trouvée")
	else:
		player.global_position = swim_point
		await get_tree().physics_frame
		await get_tree().physics_frame
		if not player.is_swimming():
			errors.append("nage KO")
		if not player.is_underwater():
			errors.append("caméra sous-marine KO")
		player.global_position = world.find_spawn_point()
		await get_tree().physics_frame

	# Inventaire
	var wood_before := GameState.get_item_count("wood")
	GameState.add_item("wood", 3)
	if GameState.get_item_count("wood") != wood_before + 3:
		errors.append("ajout d'objet KO")
	if not GameState.remove_item("wood", 1):
		errors.append("retrait d'objet KO")

	# Consommation (case 1 = noix de coco)
	GameState.add_item("coconut", 1)
	GameState.stats.thirst = 40.0
	GameState.select_hotbar(0)
	if not GameState.use_selected_item():
		errors.append("consommation KO")
	if GameState.stats.thirst <= 40.0:
		errors.append("soif non restaurée")
	if GameState.get_item_count("coconut") != 0:
		errors.append("objet non consommé")

	# Artisanat (torche : 2 bois + 2 fibres)
	GameState.add_item("wood", 2)
	GameState.add_item("fiber", 2)
	var torch_recipe: RecipeData = Database.get_recipe("torch")
	if not GameState.craft(torch_recipe):
		errors.append("artisanat KO")
	if GameState.get_item_count("torch") < 1:
		errors.append("objet fabriqué absent")

	# Interface d'artisanat : ouverture, bouton actif, fabrication, fermeture.
	GameState.add_item("wood", 4)
	GameState.add_item("fiber", 4)
	var torches_before_ui := GameState.get_item_count("torch")
	crafting_panel.open()
	if not crafting_panel.is_open():
		errors.append("panneau d'artisanat non ouvert")
	var ui_button: Button = null
	for child in crafting_panel.recipes_box.get_children():
		if child is Button and not (child as Button).disabled:
			var txt := (child as Button).text
			if txt.contains("Torch") or txt.contains("Torche"):
				ui_button = child
				break
	if ui_button == null:
		# Fallback : premier bouton actif.
		for child in crafting_panel.recipes_box.get_children():
			if child is Button and not (child as Button).disabled:
				ui_button = child
				break
	if ui_button == null:
		errors.append("aucun bouton d'artisanat actif")
	else:
		ui_button.pressed.emit()
		if GameState.get_item_count("torch") <= torches_before_ui:
			errors.append("bouton d'artisanat sans effet")
	crafting_panel.close()
	if crafting_panel.is_open():
		errors.append("panneau d'artisanat non fermé")

	# Mort et renaissance
	GameState.stats.health = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	if not GameState.is_dead:
		errors.append("mort non détectée")
	GameState.respawn()
	if GameState.is_dead:
		errors.append("renaissance KO")

	# Réglages : sauvegarde/chargement et application immédiate.
	Settings.master_volume = 0.3
	Settings.mouse_sensitivity = 1.5
	Settings.save_settings()
	Settings.load_settings()
	if abs(Settings.master_volume - 0.3) > 0.01:
		errors.append("volume non sauvegardé/chargé")
	if abs(Settings.mouse_sensitivity - 1.5) > 0.01:
		errors.append("sensibilité non sauvegardée/chargée")

	# Construction : pose gratuite, bascule, sauvegarde/chargement.
	var foundation_data: BuildableData = Database.get_buildable("foundation")
	if foundation_data == null:
		errors.append("constructible 'fondation' absent")
	elif not GameState.has_items(foundation_data.costs):
		GameState.add_item("wood", 10)
		if not GameState.consume_items(foundation_data.costs):
			errors.append("coût de construction KO")
	var placed := construction.place_free("foundation", "foundation", Vector3(3.5, 0.0, 3.5), 0.0)
	if placed == null:
		errors.append("pose de construction KO")

	# Niveaux de construction : alignement fantome, niveau manuel, verrou.
	var neighbor_cell := Vector2i(4, 3)
	var aligned_y := construction._compute_ghost_y(world.get_height_at(4.5, 3.5) + 0.5, neighbor_cell, "foundation")
	if abs(aligned_y - placed.position.y) > 0.01:
		errors.append("alignement fantome KO")

	construction.toggle()
	construction._change_level(2)
	var y_up := construction._compute_ghost_y(0.0, Vector2i(0, 0), "foundation")
	if abs(y_up - (2 * construction.LEVEL_STEP)) > 0.01:
		errors.append("niveau + KO")
	construction._change_level(-2)
	var y_down := construction._compute_ghost_y(0.0, Vector2i(0, 0), "foundation")
	if abs(y_down) > 0.01:
		errors.append("niveau - KO")

	construction._toggle_level_lock()
	construction._locked_y = construction._compute_ghost_y(0.0, Vector2i(0, 0), "foundation")
	var y_locked := construction._compute_ghost_y(7.5, Vector2i(0, 0), "foundation")
	if abs(y_locked - construction._locked_y) > 0.01:
		errors.append("niveau verrouille KO")
	construction._level_locked = false
	construction._build_level = 0
	construction.toggle()

	construction._selected = 4
	var stacked_cell := Vector2i(6, 6)
	var stacked0 := construction.place_free("foundation", "foundation", Vector3(6.5, 0.0, 6.5), 0.0)
	if stacked0 == null:
		errors.append("pose fondation niv 0 KO")
	if construction._can_place(stacked_cell, 0):
		errors.append("doublon fondation niv 0 accepte")
	var stacked1 := construction.place_free("foundation", "foundation", Vector3(6.5, 0.2, 6.5), 0.0)
	if stacked1 == null:
		errors.append("pose fondation niv 1 KO")
	if construction._can_place(stacked_cell, 1):
		errors.append("doublon fondation niv 1 accepte")
	if not construction._can_place(stacked_cell, 2):
		errors.append("fondation niv 2 refusee")
	construction.clear_all()

	# Mode construction : entrée puis sortie (le fantôme doit être créé/nettoyé).
	construction.toggle()
	if not construction.is_active():
		errors.append("mode construction non activé")
	construction.toggle()
	if construction.is_active():
		errors.append("mode construction non désactivé")

	# Sauvegarde robuste : un fichier corrompu doit être rejeté sans erreur de script.
	if not SaveSystem.save_game(player, construction):
		errors.append("écriture de sauvegarde KO")
	var corrupt_file := FileAccess.open(SaveSystem.SAVE_PATH, FileAccess.WRITE)
	if corrupt_file == null:
		errors.append("écriture sauvegarde corrompue KO")
	else:
		corrupt_file.store_string('{"stats": []}')
		corrupt_file.close()
	if SaveSystem.load_game_into(player, world, construction):
		errors.append("sauvegarde corrompue acceptée")

	# Sauvegarde / chargement
	var expected := GameState.get_item_count("wood")
	var expected_buildings := construction.to_save_data().size()
	if not SaveSystem.save_game(player, construction):
		errors.append("écriture de sauvegarde KO")
	GameState.inventory.clear()
	construction.clear_all()
	if not SaveSystem.load_game_into(player, world, construction):
		errors.append("lecture de sauvegarde KO")
	if GameState.get_item_count("wood") != expected:
		errors.append("inventaire non restauré")
	if construction.to_save_data().size() != expected_buildings:
		errors.append("constructions non restaurées")

	# Hotbar : chaque case sélectionnable doit avoir une action InputMap.
	for index in GameState.hotbar_items.size():
		if not InputMap.has_action("hotbar_%d" % (index + 1)):
			errors.append("hotbar_%d manquant" % (index + 1))

	if errors.is_empty():
		Sfx.stop_all()
		await get_tree().process_frame
		print("SMOKE_TEST OK")
		get_tree().quit(0)
	else:
		print("SMOKE_TEST ECHEC : ", ", ".join(errors))
		get_tree().quit(1)
