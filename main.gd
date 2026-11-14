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
@onready var construction_panel: ConstructionPanel = $HUD/ConstructionPanel
@onready var trader_panel: TraderPanel = $HUD/TraderPanel
@onready var journal_panel: JournalPanel = $HUD/JournalPanel
@onready var inventory_panel: InventoryPanel = $HUD/InventoryPanel
@onready var menu: MenuPanel = $HUD/MenuPanel
@onready var settings_panel: SettingsPanel = $HUD/SettingsPanel
@onready var construction: Construction = $Construction
@onready var sun = $Sun

## Intervalle de la sauvegarde automatique (secondes de jeu).
const AUTOSAVE_SECONDS := 120.0

## Vrai uniquement pendant une vraie partie (pas au menu, pas en test/outils).
var _in_game := false

## Ambiance de grotte : état courant et cadence des sons d'ambiance.
var _cave_sound_cooldown := 0.0
var _cave_warned := false
var _cave_journaled := false


func _ready() -> void:
	player.global_position = world.find_spawn_point()
	hud.setup(player)
	construction.setup(player, hud, world)
	GameState.died.connect(_on_player_died)
	crafting_panel.opened.connect(_on_crafting_opened)
	crafting_panel.closed.connect(_on_crafting_closed)
	construction_panel.opened.connect(_on_construction_opened)
	construction_panel.closed.connect(_on_construction_closed)
	storage_panel.opened.connect(_on_storage_opened)
	storage_panel.closed.connect(_on_storage_closed)
	trader_panel.opened.connect(_on_trader_opened)
	trader_panel.closed.connect(_on_trader_closed)
	journal_panel.opened.connect(_on_journal_opened)
	journal_panel.closed.connect(_on_journal_closed)
	inventory_panel.opened.connect(_on_inventory_opened)
	inventory_panel.closed.connect(_on_inventory_closed)
	menu.new_game_requested.connect(_on_menu_new_game)
	menu.continue_requested.connect(_on_menu_continue)
	menu.resume_requested.connect(_on_menu_resume)
	menu.save_requested.connect(_on_menu_save)
	menu.settings_requested.connect(_on_menu_settings)
	menu.main_menu_requested.connect(_on_menu_main_menu)
	settings_panel.closed.connect(_on_settings_closed)
	menu.quit_requested.connect(_on_menu_quit)
	construction_panel.selection_requested.connect(_on_construction_selection_requested)
	hud.build_wheel.buildable_chosen.connect(_on_construction_selection_requested)

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

	if "--show-inventory" in OS.get_cmdline_user_args():
		inventory_panel.open()

	if "--smoke-test" in OS.get_cmdline_user_args():
		await _run_smoke_test()


## Les outils de dev (tests, captures) démarrent directement en jeu.
func _is_dev_run() -> bool:
	var args := OS.get_cmdline_user_args()
	return ( "--smoke-test" in args or "--overview" in args
		or "--show-crafting" in args or "--show-inventory" in args )


## Ambiance des grottes : obscurité progressive + sons réverbérants.
## S'exécute à chaque image tant que le jeu n'est pas en pause.
func _process(delta: float) -> void:
	if get_tree().paused or GameState.is_dead:
		return
	if player == null or world == null or sun == null:
		return

	var in_cave: bool = world.is_in_cave(player.global_position)
	var target := 1.0 if in_cave else 0.0
	sun.cave_darkness = move_toward(sun.cave_darkness, target, delta * 2.5)
	Sfx.set_cave(in_cave)

	if not in_cave:
		_cave_warned = false
		return

	# Sons d'ambiance espacés : souffle de grotte et gouttes d'eau.
	_cave_sound_cooldown -= delta
	if _cave_sound_cooldown <= 0.0:
		_cave_sound_cooldown = 12.0
		Sfx.play("cave", player.global_position, -6.0)

	if not _cave_journaled:
		_cave_journaled = true
		GameState.add_journal("Découverte d'une grotte : l'air est froid, l'obscurité presque totale.")

	if not _cave_warned:
		_cave_warned = true
		var has_torch: bool = GameState.selected_hotbar_item() == "torch" and GameState.get_item_count("torch") > 0
		if has_torch:
			GameState.notify("Grotte : la torche éclaire faiblement autour de toi.")
		else:
			GameState.notify("Grotte sombre : sélectionne une torche (touche 3) pour voir clair.")


func _unhandled_input(event: InputEvent) -> void:
	# Aide (F1) : superposée au jeu, bloque les contrôles tant qu'elle est ouverte.
	if event.is_action_pressed("toggle_help") and _in_game and not GameState.is_dead:
		if hud.is_help_open():
			hud.close_help()
			player.set_controls_enabled(true)
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			hud.toggle_help()
			player.set_controls_enabled(false)
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	if hud.is_help_open():
		if event.is_action_pressed("ui_cancel"):
			hud.close_help()
			player.set_controls_enabled(true)
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return

	if event.is_action_pressed("ui_cancel"):
		if journal_panel.is_open():
			journal_panel.close()
			return
		if trader_panel.is_open():
			trader_panel.close()
			return
		if storage_panel.is_open():
			storage_panel.close()
			return
		if inventory_panel.is_open():
			inventory_panel.close()
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

	# Roue de construction : Tab maintenu affiche les éléments de la catégorie
	# courante ; un clic sélectionne, relâcher ferme.
	if construction.is_active():
		if event.is_action_pressed("build_wheel"):
			_open_build_wheel()
			return
		if event.is_action_released("build_wheel"):
			hud.build_wheel.close()
			return

	if event.is_action_pressed("toggle_journal"):
		_toggle_journal()
		return

	if journal_panel.is_open() or trader_panel.is_open() or storage_panel.is_open() or inventory_panel.is_open():
		return

	if event.is_action_pressed("toggle_inventory"):
		if construction.is_active():
			construction.toggle()
		inventory_panel.toggle()
		return

	if event.is_action_pressed("toggle_crafting"):
		if construction.is_active():
			construction.toggle()
		crafting_panel.toggle()
		return

	if event.is_action_pressed("toggle_build"):
		if crafting_panel.is_open():
			crafting_panel.close()
		var entering := not construction.is_active()
		construction.toggle()
		# Mode construction : on n'ouvre PAS le catalogue. L'aperçu (ghost) et les
		# infos de sélection (HUD BuildInfo) affichent ce qui sera construit ; la
		# roue de sélection (Tab) reste disponible pour changer d'élément.
		construction_panel.close()
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
	hud.close_help()
	if inventory_panel.is_open():
		inventory_panel.close()
	if journal_panel.is_open():
		journal_panel.close()
	if trader_panel.is_open():
		trader_panel.close()
	menu.open_start()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _open_pause_menu() -> void:
	hud.close_help()
	if inventory_panel.is_open():
		inventory_panel.close()
	if journal_panel.is_open():
		journal_panel.close()
	if trader_panel.is_open():
		trader_panel.close()
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
	_cave_journaled = false
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


## Indique si le menu (principal ou pause) était ouvert avant d'aller dans les réglages.
var _menu_was_open := false

func _on_settings_closed() -> void:
	if _menu_was_open:
		_menu_was_open = false
		menu.visible = true
		menu.reopen()

func _on_menu_settings() -> void:
	_menu_was_open = menu.is_open()
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
	if inventory_panel.is_open():
		inventory_panel.close()
	if journal_panel.is_open():
		journal_panel.close()
	if trader_panel.is_open():
		trader_panel.close()
	if storage_panel.is_open():
		storage_panel.close()
	if crafting_panel.is_open():
		crafting_panel.close()
	if construction.is_active():
		construction.toggle()
	GameState.add_journal("Tu t'es effondré, à bout de forces. L'île a failli te garder.")
	Sfx.play_ui("death")
	player.set_controls_enabled(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_storage_opened() -> void:
	if journal_panel.is_open():
		journal_panel.close()
	if trader_panel.is_open():
		trader_panel.close()
	if construction.is_active():
		construction.toggle()
	if inventory_panel.is_open():
		inventory_panel.close()
	if crafting_panel.is_open():
		crafting_panel.close()
	player.set_controls_enabled(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_storage_closed() -> void:
	if GameState.is_dead:
		return
	player.set_controls_enabled(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_inventory_opened() -> void:
	if journal_panel.is_open():
		journal_panel.close()
	if trader_panel.is_open():
		trader_panel.close()
	if storage_panel.is_open():
		storage_panel.close()
	if crafting_panel.is_open():
		crafting_panel.close()
	if construction.is_active():
		construction.toggle()
	player.set_controls_enabled(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_inventory_closed() -> void:
	if GameState.is_dead:
		return
	player.set_controls_enabled(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_crafting_opened() -> void:
	if journal_panel.is_open():
		journal_panel.close()
	if trader_panel.is_open():
		trader_panel.close()
	if construction.is_active():
		construction.toggle()
	player.set_controls_enabled(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_crafting_closed() -> void:
	if GameState.is_dead:
		return
	player.set_controls_enabled(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_construction_opened() -> void:
	if journal_panel.is_open():
		journal_panel.close()
	if trader_panel.is_open():
		trader_panel.close()
	if storage_panel.is_open():
		storage_panel.close()
	if inventory_panel.is_open():
		inventory_panel.close()
	if crafting_panel.is_open():
		crafting_panel.close()
	player.set_controls_enabled(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_construction_closed() -> void:
	hud.build_wheel.close()
	if GameState.is_dead:
		return
	if construction.is_active():
		construction.toggle()
	player.set_controls_enabled(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_construction_selection_requested(buildable_id: String) -> void:
	construction.select_buildable_by_id(buildable_id)


## Ouvre la roue de construction sur la catégorie de l'élément sélectionné.
func _open_build_wheel() -> void:
	var category := construction.current_category()
	var entries := construction.catalog_for_category(category)
	var label: String = ConstructionPanel.CATEGORY_LABELS.get(category, str(category).capitalize())
	hud.build_wheel.open(entries, construction.selected_id(), label)


func _toggle_journal() -> void:
	if journal_panel.is_open():
		journal_panel.close()
		return
	if crafting_panel.is_open():
		crafting_panel.close()
	if storage_panel.is_open():
		storage_panel.close()
	if trader_panel.is_open():
		trader_panel.close()
	if inventory_panel.is_open():
		inventory_panel.close()
	if construction.is_active():
		construction.toggle()
	journal_panel.open()


func _on_trader_opened() -> void:
	if journal_panel.is_open():
		journal_panel.close()
	if storage_panel.is_open():
		storage_panel.close()
	if crafting_panel.is_open():
		crafting_panel.close()
	if construction.is_active():
		construction.toggle()
	player.set_controls_enabled(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_trader_closed() -> void:
	if GameState.is_dead:
		return
	player.set_controls_enabled(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_journal_opened() -> void:
	if trader_panel.is_open():
		trader_panel.close()
	if storage_panel.is_open():
		storage_panel.close()
	if crafting_panel.is_open():
		crafting_panel.close()
	if construction.is_active():
		construction.toggle()
	player.set_controls_enabled(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_journal_closed() -> void:
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
	GameState.add_journal("Tu te réveilles sur la plage, les idées embrouillées.")
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

## Lance le smoke test (implémentation : `tests/smoke_test.gd`).
func _run_smoke_test() -> void:
	var smoke := SmokeTest.new()
	smoke.setup(self)
	await smoke.run()
	smoke.queue_free()
