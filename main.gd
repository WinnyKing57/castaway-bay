extends Node3D
## Point d'entrée du jeu (scène main.tscn).
##
## Rôle : assembler le monde, placer le joueur, brancher le HUD,
## et gérer les commandes globales (sauvegarde, souris, mort, outils de dev).

@onready var world: Island = $World
@onready var player: Player = $Player
@onready var hud: Hud = $HUD
@onready var crafting_panel: CraftingPanel = $HUD/CraftingPanel
@onready var storage_panel: StoragePanel = $HUD/StoragePanel
@onready var menu: MenuPanel = $HUD/MenuPanel
@onready var settings_panel: SettingsPanel = $HUD/SettingsPanel
@onready var construction: Construction = $Construction

## Intervalle de la sauvegarde automatique (secondes de jeu).
const AUTOSAVE_SECONDS := 120.0

## Vrai uniquement pendant une vraie partie (pas au menu, pas en test/outils).
var _in_game := false


func _ready() -> void:
	player.global_position = world.find_spawn_point()
	hud.setup(player)
	construction.setup(player, hud)
	GameState.died.connect(_on_player_died)
	crafting_panel.opened.connect(_on_crafting_opened)
	crafting_panel.closed.connect(_on_crafting_closed)
	storage_panel.opened.connect(_on_storage_opened)
	storage_panel.closed.connect(_on_storage_closed)
	menu.new_game_requested.connect(_on_menu_new_game)
	menu.continue_requested.connect(_on_menu_continue)
	menu.resume_requested.connect(_on_menu_resume)
	menu.save_requested.connect(_on_menu_save)
	menu.settings_requested.connect(_on_menu_settings)
	menu.main_menu_requested.connect(_on_menu_main_menu)
	settings_panel.closed.connect(_on_settings_closed)
	menu.quit_requested.connect(_on_menu_quit)

	var autosave_timer := Timer.new()
	autosave_timer.wait_time = AUTOSAVE_SECONDS
	autosave_timer.timeout.connect(_autosave.bind(false))
	add_child(autosave_timer)
	autosave_timer.start()

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
		if storage_panel.is_open():
			storage_panel.close()
			return
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

	if storage_panel.is_open():
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
		if SaveSystem.save_game(player, construction, world):
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
	_in_game = false
	menu.open_start()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _open_pause_menu() -> void:
	if storage_panel.is_open():
		storage_panel.close()
	if crafting_panel.is_open():
		crafting_panel.close()
	if construction.is_active():
		construction.toggle()
	menu.open_pause()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _resume_game() -> void:
	_in_game = true
	get_tree().paused = false
	menu.close()
	player.set_controls_enabled(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_menu_new_game() -> void:
	GameState.reset()
	construction.clear_all()
	world.regenerate(randi())
	player.exit_boat()
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
	if SaveSystem.save_game(player, construction, world):
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
	_autosave(true)
	_show_start_menu()


func _on_menu_quit() -> void:
	_autosave(true)
	get_tree().quit()


## Sauvegarde automatique : périodique, à la sortie vers le menu, à la fermeture
## de la fenêtre et quand l'application passe en arrière-plan. Jamais au menu
## principal, pendant la mort ni en test : on ne remplace pas une bonne partie
## par un état invalide. L'ancienne sauvegarde reste en `.bak`.
func _autosave(silent: bool) -> void:
	if not _in_game or GameState.is_dead or _is_dev_run():
		return
	if SaveSystem.save_game(player, construction, world):
		if not silent:
			GameState.notify("Sauvegarde automatique")
	else:
		push_warning("[Main] Échec de la sauvegarde automatique")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_autosave(true)


func _on_player_died() -> void:
	if storage_panel.is_open():
		storage_panel.close()
	if crafting_panel.is_open():
		crafting_panel.close()
	if construction.is_active():
		construction.toggle()
	Sfx.play_ui("death")
	player.set_controls_enabled(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_storage_opened() -> void:
	if construction.is_active():
		construction.toggle()
	if crafting_panel.is_open():
		crafting_panel.close()
	player.set_controls_enabled(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_storage_closed() -> void:
	if GameState.is_dead:
		return
	player.set_controls_enabled(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


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
	player.exit_boat()
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

	# Le test écrit dans user:// : on met de côté la vraie sauvegarde et les
	# vrais réglages du joueur pour les restaurer à la fin.
	var user_backup := _backup_user_files()
	Settings.infinite_resources = false

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
	if not SaveSystem.save_game(player, construction, world):
		errors.append("écriture de sauvegarde KO")
	SaveSystem.delete_backup()
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
	if not SaveSystem.save_game(player, construction, world):
		errors.append("écriture de sauvegarde KO")
	GameState.inventory.clear()
	construction.clear_all()
	if not SaveSystem.load_game_into(player, world, construction):
		errors.append("lecture de sauvegarde KO")
	if GameState.get_item_count("wood") != expected:
		errors.append("inventaire non restauré")
	if construction.to_save_data().size() != expected_buildings:
		errors.append("constructions non restaurées")

	# --- Non-régression : stabilité -------------------------------------------
	_run_stability_tests(errors)
	_run_persistence_tests(errors)

	# Hotbar : chaque case sélectionnable doit avoir une action InputMap.
	for index in GameState.hotbar_items.size():
		if not InputMap.has_action("hotbar_%d" % (index + 1)):
			errors.append("hotbar_%d manquant" % (index + 1))

	_restore_user_files(user_backup)

	if errors.is_empty():
		Sfx.stop_all()
		await get_tree().process_frame
		print("SMOKE_TEST OK")
		get_tree().quit(0)
	else:
		print("SMOKE_TEST ECHEC : ", ", ".join(errors))
		get_tree().quit(1)


## Copie en mémoire les fichiers utilisateur que le test va écraser.
func _backup_user_files() -> Dictionary:
	var backup := {}
	for path in [SaveSystem.SAVE_PATH, SaveSystem.BACKUP_PATH, Settings.PATH]:
		backup[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	return backup


func _restore_user_files(backup: Dictionary) -> void:
	for path in backup:
		var content: Variant = backup[path]
		if content == null:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
			continue
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_buffer(content)
			file.close()


func _catalog_index(buildable_id: String) -> int:
	for index in construction._catalog.size():
		if construction._catalog[index].id == buildable_id:
			return index
	return -1


func _write_raw_save(text: String) -> void:
	SaveSystem.delete_backup()
	var file := FileAccess.open(SaveSystem.SAVE_PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()


## Tests de non-régression de la passe de stabilisation.
func _run_stability_tests(errors: PackedStringArray) -> void:
	# Inventaire : une quantité <= 0 ne doit jamais modifier le stock.
	GameState.add_item("stone", 5)
	var stone_before := GameState.get_item_count("stone")
	if GameState.remove_item("stone", -3):
		errors.append("retrait négatif accepté")
	if GameState.remove_item("stone", 0):
		errors.append("retrait nul accepté")
	if GameState.get_item_count("stone") != stone_before:
		errors.append("retrait invalide a modifié le stock")
	if GameState.has_items({"stone": -1}) or GameState.consume_items({"stone": 0}):
		errors.append("coût négatif/nul accepté")
	if GameState.get_item_count("stone") != stone_before:
		errors.append("coût invalide a modifié le stock")

	# Construction : on se donne de quoi tout poser.
	for item_id in Database.items.keys():
		GameState.add_item(str(item_id), 50)
	construction.clear_all()
	var cell := Vector2i(10, 10)
	construction.place_free("foundation", "foundation", Vector3(10.5, 0.0, 10.5), 0.0)

	# Chevauchement inter-catégories : coffre / feu sur une fondation de même niveau.
	for other in ["chest", "campfire", "roof"]:
		construction._selected = _catalog_index(other)
		if construction._selected < 0:
			errors.append("constructible absent : %s" % other)
			continue
		if construction._can_place(cell, 0):
			errors.append("%s accepté sur une fondation (même niveau)" % other)
		if not construction._can_place(cell, 1):
			errors.append("%s refusé au niveau supérieur" % other)

	# Murs : l'empreinte est par bord, et doit survivre à une sauvegarde.
	var wall_cell := Vector2i(12, 12)
	var wall_rot := 3.0 * PI * 0.5
	var wall_base := Vector3(12.5, 0.0, 12.5)
	var wall_pos := wall_base + Vector3(sin(wall_rot), 0.0, cos(wall_rot)) * 0.5
	construction.place_free("wall", "wall", wall_pos, wall_rot)
	construction.place_free("campfire", "campfire", Vector3(14.5, 0.0, 14.5), 0.0)
	construction._selected = _catalog_index("wall")
	if construction._can_place(wall_cell, 0, 3):
		errors.append("mur doublon (même bord) accepté")
	if not construction._can_place(wall_cell, 0, 0):
		errors.append("mur sur un autre bord refusé")
	construction._selected = _catalog_index("door")
	if construction._can_place(wall_cell, 0, 3):
		errors.append("porte acceptée sur le bord d'un mur")

	# Éléments de bord canoniques : cell (12, 12) rot 3 partage la même frontière que cell (11, 12) rot 1
	var neighbor_wall_cell := Vector2i(11, 12)
	construction._selected = _catalog_index("wall")
	if construction._can_place(neighbor_wall_cell, 0, 1):
		errors.append("mur partagé depuis la case voisine accepté (doublon canonique)")
	construction._selected = _catalog_index("window")
	if construction._can_place(neighbor_wall_cell, 0, 1):
		errors.append("fenêtre partagée sur le bord d'un mur acceptée")

	# Mode créatif (matériaux infinis) : artisanat et construction sans consommer
	Settings.infinite_resources = true
	var plank_recipe: RecipeData = Database.get_recipe("plank")
	GameState.inventory.clear()
	if not GameState.can_craft(plank_recipe):
		errors.append("mode créatif : fabrication refusée sans ressources")
	if not GameState.craft(plank_recipe):
		errors.append("mode créatif : craft KO")
	if GameState.get_item_count("plank") < 1:
		errors.append("mode créatif : objet non produit")
	Settings.infinite_resources = false

	var count_before := construction.to_save_data().size()
	if not SaveSystem.save_game(player, construction, world):
		errors.append("sauvegarde (stabilité) KO")
	GameState.clear_stations()
	construction.clear_all()
	if not SaveSystem.load_game_into(player, world, construction):
		errors.append("chargement (stabilité) KO")
	if construction.to_save_data().size() != count_before:
		errors.append("constructions perdues/dupliquées après chargement")
	construction._selected = _catalog_index("wall")
	if construction._can_place(wall_cell, 0, 3):
		errors.append("empreinte du mur perdue après chargement")
	if not GameState.has_station("campfire"):
		errors.append("station de fabrication non restaurée")

	# Sauvegarde : entrées dupliquées / inconnues / non numériques ignorées.
	construction.load_save_data([
		{"kind": "foundation", "data_id": "foundation", "position": [20.5, 0.0, 20.5], "rotation_y": 0.0},
		{"kind": "foundation", "data_id": "foundation", "position": [20.5, 0.0, 20.5], "rotation_y": 0.0},
		{"kind": "foundation", "data_id": "inexistant", "position": [30.5, 0.0, 30.5], "rotation_y": 0.0},
		{"kind": "foundation", "data_id": "foundation", "position": [1.0, "x", 1.0], "rotation_y": 0.0},
		"pas un dictionnaire",
	])
	if construction.to_save_data().size() != 1:
		errors.append("chargement construction : %d élément(s) au lieu de 1" % construction.to_save_data().size())
	construction.clear_all()

	# Sauvegardes malformées : toutes doivent être rejetées sans toucher à l'état.
	var wood_marker := GameState.get_item_count("wood")
	var bad_saves := [
		'{"version": 1, "stats": {"health": "abc"}, "inventory": {}, "player": {}}',
		'{"version": 1, "stats": {}, "inventory": {"wood": "beaucoup"}, "player": {}}',
		'{"version": 1, "stats": {}, "inventory": {}, "player": {"position": [1, 2]}}',
		'{"version": 1, "stats": {}, "inventory": {}, "player": {"position": [1, "a", 3]}}',
		'{"version": 999, "stats": {}, "inventory": {}, "player": {}}',
		'{"version": 1, "world_time": "midi", "stats": {}, "inventory": {}, "player": {}}',
		'{"version": 1, "stats": {}, "inventory": {}, "player": {}, "construction": {}}',
		'[1, 2, 3]',
	]
	for raw in bad_saves:
		_write_raw_save(raw)
		if SaveSystem.load_game_into(player, world, construction):
			errors.append("sauvegarde malformée acceptée : %s" % raw.left(60))
	if GameState.get_item_count("wood") != wood_marker:
		errors.append("une sauvegarde rejetée a modifié l'inventaire")

	# Sauvegarde valide mais « sale » : quantités négatives et objets inconnus filtrés.
	_write_raw_save('{"version": 1, "stats": {"health": 500, "hunger": -20}, "inventory": {"wood": -3, "fantome": 5, "stone": 2}, "player": {"position": [0, 5, 0]}}')
	if not SaveSystem.load_game_into(player, world, construction):
		errors.append("sauvegarde valide refusée")
	else:
		if GameState.get_item_count("wood") != 0 or GameState.inventory.has("fantome"):
			errors.append("inventaire non assaini au chargement")
		if GameState.get_item_count("stone") != 2:
			errors.append("objet valide perdu au chargement")
		if GameState.stats.health > 100.0 or GameState.stats.hunger < 0.0:
			errors.append("jauges non bornées au chargement")

	# Bateau : un chargement ou un respawn doit libérer le joueur.
	var boat: Boat = null
	for child in world.get_children():
		if child is Boat:
			boat = child
			break
	if boat == null:
		errors.append("bateau introuvable")
	else:
		boat.interact(player)
		if not player.is_in_boat():
			errors.append("embarquement KO")
		player.exit_boat()
		boat._physics_process(0.016)
		if boat._controlled:
			errors.append("bateau toujours piloté après sortie forcée du joueur")
		if player.is_in_boat():
			errors.append("joueur toujours à bord")
		# Retrait de métal : la réparation consomme du métal du joueur.
		boat.fuel = 0.0
		GameState.inventory.erase("fuel")
		GameState.add_item("metal", 1)
		boat.interact(player)
		if boat.fuel <= 0.0 or GameState.get_item_count("metal") != 0:
			errors.append("réparation du bateau KO")
		player.exit_boat()
		boat._physics_process(0.016)

	# Coffres : stockage, persistance et interface
	construction.clear_all()
	var chest_node := construction.place_free("chest", "chest", Vector3(15.5, 0.0, 15.5), 0.0)
	if chest_node == null:
		errors.append("pose coffre KO")
	else:
		if not chest_node.get_interaction_prompt().contains("vide"):
			errors.append("prompt coffre vide KO")
		GameState.inventory.clear()
		GameState.add_item("wood", 10)
		GameState.add_item("fiber", 5)
		storage_panel.open(chest_node)
		if not storage_panel.is_open():
			errors.append("panneau coffre non ouvert")
		storage_panel._put_in_chest("wood", 6)
		if chest_node.chest_inventory.get("wood", 0) != 6 or GameState.get_item_count("wood") != 4:
			errors.append("dépôt dans le coffre KO")
		storage_panel._on_deposit_all()
		if GameState.get_item_count("wood") != 0 or GameState.get_item_count("fiber") != 0:
			errors.append("tout déposer dans le coffre KO")
		if not SaveSystem.save_game(player, construction, world):
			errors.append("sauvegarde avec coffre KO")
		construction.clear_all()
		if not SaveSystem.load_game_into(player, world, construction):
			errors.append("chargement avec coffre KO")
		var restored_chest: Buildable = null
		for obj in construction._objects:
			if obj.kind == "chest":
				restored_chest = obj
				break
		if restored_chest == null or restored_chest.chest_inventory.get("wood", 0) != 10:
			errors.append("contenu du coffre non restauré après chargement")
		if restored_chest != null:
			storage_panel.open(restored_chest)
			storage_panel._take_from_chest("wood", 4)
			if GameState.get_item_count("wood") != 4 or restored_chest.chest_inventory.get("wood", 0) != 6:
				errors.append("retrait du coffre KO")
			storage_panel._on_take_all()
			if not restored_chest.chest_inventory.is_empty() or GameState.get_item_count("wood") != 10 or GameState.get_item_count("fiber") != 5:
				errors.append("tout retirer du coffre KO")
			storage_panel.close()
			if storage_panel.is_open():
				errors.append("panneau coffre non fermé")

	# Compatibilité v1 : sauvegarde v1 sans world_state, ni craft, ni in_boat
	var v1_json := '{"version": 1, "saved_at": "2026-01-01T12:00:00", "world_time": 43200.0, "world_seed": 12345, "stats": {"health": 85.0, "hunger": 75.0, "thirst": 65.0, "fatigue": 90.0}, "inventory": {"wood": 12, "stone": 8}, "hotbar_index": 1, "player": {"position": [10.0, 5.0, 10.0], "rotation_y": 0.5, "pitch": -0.2}, "construction": [{"kind": "foundation", "data_id": "foundation", "position": [10.5, 0.0, 10.5], "rotation_y": 0.0}]}'
	_write_raw_save(v1_json)
	GameState.inventory.clear()
	construction.clear_all()
	if not SaveSystem.load_game_into(player, world, construction):
		errors.append("chargement sauvegarde v1 KO")
	else:
		if GameState.get_item_count("wood") != 12 or GameState.get_item_count("stone") != 8:
			errors.append("inventaire sauvegarde v1 non restauré")
		if absf(GameState.stats.health - 85.0) > 0.01:
			errors.append("jauges sauvegarde v1 non restaurées")
		if construction.to_save_data().size() != 1:
			errors.append("constructions sauvegarde v1 non restaurées")
	construction.clear_all()


## Tests de persistance : « rien de ce que fait le joueur ne doit se perdre ».
func _run_persistence_tests(errors: PackedStringArray) -> void:
	for item_id in Database.items.keys():
		GameState.add_item(str(item_id), 20)
	construction.clear_all()
	GameState.clear_craft()

	# Ressources : deux arbres/rochers (un récolté, un intact) + une culture plantée.
	var props: Array[Harvestable] = []
	for child in world.get_children():
		if child is Harvestable and child.save_id >= 0:
			props.append(child)
			if props.size() == 2:
				break
	var crop: Crop = null
	for child in world.get_children():
		if child is Crop and child.save_id >= 0:
			crop = child
			break
	var boat: Boat = world.get_boat()
	if props.size() < 2 or crop == null or boat == null:
		errors.append("monde incomplet pour le test de persistance")
		return
	props[0].apply_save_state(false, 0.0)
	props[1].apply_save_state(false, 0.0)
	props[0].interact(player)
	props[0]._regrow_left = 77.0
	crop.apply_save_state(false, 0.0)
	crop.interact(player)
	crop.progress = 40.0

	# Bateau déplacé, carburant entamé.
	boat.apply_save_state({"position": [10.0, -2.0, 15.0], "rotation_y": 0.7, "fuel": 12.0})

	# Joueur : position, cap, regard, barre rapide.
	var spawn := world.find_spawn_point()
	player.global_position = spawn
	player.rotation.y = 1.2
	player.set_pitch(-0.4)
	GameState.select_hotbar(2)

	# Fabrication chronométrée en cours (hache : 1,5 s).
	var axe: RecipeData = Database.get_recipe("stone_axe")
	var axes_before := GameState.get_item_count("stone_axe")
	if not GameState.craft(axe) or not GameState.is_crafting():
		errors.append("fabrication chronométrée non lancée")
	GameState._advance_craft(0.5)

	# Constructions, dont un élément 2 x 2 et deux stations différentes.
	construction.place_free("foundation", "foundation", Vector3(40.5, 0.0, 40.5), 0.0)
	construction.place_free("campfire", "campfire", Vector3(44.5, 0.0, 44.5), 0.0)
	construction.place_free("furnace", "furnace", Vector3(46.5, 0.0, 46.5), 0.0)
	if not (GameState.has_station("campfire") and GameState.has_station("furnace")):
		errors.append("deux stations ne coexistent pas")
	var buildings := construction.to_save_data().size()

	if not SaveSystem.save_game(player, construction, world):
		errors.append("sauvegarde complète KO")

	# On casse tout, comme si le joueur quittait puis relançait le jeu.
	player.global_position = spawn + Vector3(5.0, 0.0, 5.0)
	player.rotation.y = 0.0
	player.set_pitch(0.3)
	GameState.select_hotbar(0)
	props[0].apply_save_state(false, 0.0)
	crop.apply_save_state(false, 0.0)
	boat.apply_save_state({"position": [-30.0, -2.0, -30.0], "rotation_y": 0.0, "fuel": 30.0})
	GameState.clear_craft()
	GameState.inventory.clear()
	GameState.clear_stations()
	construction.clear_all()

	if not SaveSystem.load_game_into(player, world, construction):
		errors.append("chargement complet KO")
	else:
		if player.global_position.distance_to(spawn) > 0.05:
			errors.append("position du joueur non restaurée")
		if absf(player.rotation.y - 1.2) > 0.01 or absf(player.get_pitch() + 0.4) > 0.01:
			errors.append("orientation du joueur non restaurée")
		if GameState.hotbar_index != 2:
			errors.append("barre rapide non restaurée")
		if not props[0].is_depleted() or absf(props[0]._regrow_left - 77.0) > 1.0:
			errors.append("ressource récoltée non restaurée")
		if props[1].is_depleted():
			errors.append("ressource intacte marquée épuisée")
		if not crop.is_planted() or absf(crop.progress - 40.0) > 1.0:
			errors.append("culture non restaurée")
		if boat.global_position.distance_to(Vector3(10.0, -2.0, 15.0)) > 0.05 or absf(boat.fuel - 12.0) > 0.01:
			errors.append("bateau non restauré")
		if not GameState.is_crafting() or GameState.current_craft["recipe"].id != axe.id:
			errors.append("fabrication en cours non restaurée")
		if construction.to_save_data().size() != buildings:
			errors.append("constructions non restaurées (persistance)")
		if not (GameState.has_station("campfire") and GameState.has_station("furnace")):
			errors.append("stations non restaurées")
	GameState._advance_craft(10.0)
	if GameState.get_item_count("stone_axe") != axes_before + 1 and GameState.get_item_count("stone_axe") < 1:
		errors.append("fabrication restaurée non terminée")

	# Annulation : les ingrédients sont rendus, rien n'est produit.
	GameState.inventory.clear()
	for item_id in axe.inputs:
		GameState.inventory[str(item_id)] = int(axe.inputs[item_id])
	GameState.craft(axe)
	if GameState.has_items(axe.inputs):
		errors.append("ingrédients non consommés au lancement")
	GameState.cancel_craft()
	if not GameState.has_items(axe.inputs) or GameState.get_item_count("stone_axe") != 0 or GameState.is_crafting():
		errors.append("annulation de fabrication KO")

	# Joueur à bord pendant la sauvegarde : il reprend la barre au chargement.
	boat.fuel = 20.0
	boat.interact(player)
	if not player.is_in_boat():
		errors.append("embarquement (persistance) KO")
	if not SaveSystem.save_game(player, construction, world):
		errors.append("sauvegarde en navigation KO")
	player.exit_boat()
	boat._physics_process(0.016)
	if not SaveSystem.load_game_into(player, world, construction):
		errors.append("chargement en navigation KO")
	elif not player.is_in_boat() or not boat._controlled:
		errors.append("joueur non remis à bord au chargement")
	player.exit_boat()
	boat._physics_process(0.016)

	# Sauvegarde de secours : un fichier principal corrompu n'efface pas la partie.
	SaveSystem.save_game(player, construction, world)
	SaveSystem.save_game(player, construction, world)
	if not FileAccess.file_exists(SaveSystem.BACKUP_PATH):
		errors.append("copie de secours absente")
	var broken := FileAccess.open(SaveSystem.SAVE_PATH, FileAccess.WRITE)
	broken.store_string("{ pas du json")
	broken.close()
	if not SaveSystem.load_game_into(player, world, construction):
		errors.append("copie de secours non utilisée")

	# Empreinte n x n : tente et lit occupent 2 x 2 cases.
	for item_id in Database.items.keys():
		GameState.inventory[str(item_id)] = 20
	construction.clear_all()
	var tent_index := _catalog_index("tent")
	construction._selected = tent_index
	construction.place_free("tent", "tent", Vector3(61.0, 0.0, 61.0), 0.0)
	for blocked_cell in [Vector2i(60, 60), Vector2i(61, 61), Vector2i(60, 61), Vector2i(59, 59)]:
		if construction._can_place(blocked_cell, 0):
			errors.append("tente : empreinte 2x2 non respectée en %s" % str(blocked_cell))
	if not construction._can_place(Vector2i(62, 60), 0):
		errors.append("tente : case voisine refusée à tort")
	var tent_saved: Array = construction.to_save_data()
	construction.load_save_data(tent_saved)
	if construction._can_place(Vector2i(61, 61), 0):
		errors.append("tente : empreinte perdue après chargement")
	construction.clear_all()

	# Ne pas se murer : un élément qui recouvre le joueur est refusé.
	player.global_position = Vector3(50.5, 5.0, 50.5)
	if not construction._blocked_by_player(Vector3(50.5, 5.0, 50.5), 0.0, "chest", 1):
		errors.append("coffre posé sur le joueur accepté")
	if construction._blocked_by_player(Vector3(54.5, 5.0, 50.5), 0.0, "chest", 1):
		errors.append("coffre éloigné refusé à tort")
	if not construction._blocked_by_player(Vector3(50.5, 5.0, 50.5), 0.0, "wall", 1):
		errors.append("mur posé sur le joueur accepté")
	if construction._blocked_by_player(Vector3(50.5, 7.5, 50.5), 0.0, "roof", 1):
		errors.append("toit au-dessus de la tête refusé à tort")
	if construction._blocked_by_player(Vector3(50.5, 5.0, 50.5), 0.0, "foundation", 1):
		errors.append("fondation sous le joueur refusée à tort")
	player.global_position = world.find_spawn_point()

	# Nettoyage : monde remis à neuf pour la suite.
	world.apply_save_data({})
	construction.clear_all()
