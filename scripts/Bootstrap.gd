extends Node

## Bootstrap node that manages the main menu to game transition.
## This is the entry point for the application.

var main_menu: Control
var save_select_ui: SaveSelectUI
var game: Node2D

# Pending data for new game (set when MainMenu emits new_game_requested, consumed when
# the player picks a slot from the save select UI)
var _pending_new_game_seed: int = 0

func _ready() -> void:
	print("Bootstrap._ready() running")
	_setup_emoji_font_fallback()
	# CRITICAL: CanvasLayer children render independently of parent Node2D
	# visibility. Even with game.visible = false, HUD/Shop/Inventory/etc.
	# CanvasLayers still render on top of the main menu. Hide them explicitly.
	var game_node: Node2D = get_node("Game") as Node2D
	if game_node:
		for child in game_node.get_children():
			if child is CanvasLayer:
				child.visible = false
	
	# Place the world background at the CanvasLayer level so it stays
	# visible behind MainMenu AND SaveSelectUI regardless of menu states.
	call_deferred("_place_persistent_background")
	call_deferred("_connect_signals")
	call_deferred("_check_cli_join")


## Standalone clients launched with --eos-join=<CODE> route through the
## normal join flow so the game starts after connecting.
func _check_cli_join() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--eos-join="):
			var code: String = arg.get_slice("=", 1).strip_edges()
			if not code.is_empty():
				print("Bootstrap: CLI join code: ", code)
				_on_join_online(code)
			break


func _setup_emoji_font_fallback() -> void:
	# FarmTheme.tres intentionally has no default_font set — this wires
	# NotoColorEmoji in as a FALLBACK (for glyphs the built-in font can't
	# render, e.g. emoji), while keeping the engine's default font as primary.
	var project_theme: Theme = ThemeDB.get_project_theme()
	if not project_theme:
		return
	var emoji_font: Font = load("res://fonts/NotoColorEmoji.ttf")
	if not emoji_font:
		push_warning("NotoColorEmoji.ttf not found — skipping emoji fallback setup.")
		return
	var base_font: Font = ThemeDB.fallback_font.duplicate()
	base_font.fallbacks = [emoji_font]
	project_theme.default_font = base_font


func _place_persistent_background() -> void:
	var canvas: CanvasLayer = get_node("CanvasLayer") as CanvasLayer
	if not canvas:
		return
	# Skip if already added
	for c in canvas.get_children():
		if c is TextureRect and c.name == "BgPersistent":
			return
	var bg_tex: Texture2D = load("res://assets/generated/world_background.png")
	if not bg_tex:
		return
	var bg_rect := TextureRect.new()
	bg_rect.name = "BgPersistent"
	bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_rect.texture = bg_tex
	canvas.add_child(bg_rect)
	canvas.move_child(bg_rect, 0)

func _connect_signals() -> void:
	print("Bootstrap._connect_signals() running")
	main_menu = get_node("CanvasLayer/MainMenu") as Control
	save_select_ui = get_node("CanvasLayer/SaveSelectUI") as SaveSelectUI
	game = get_node("Game")
	
	if main_menu:
		main_menu.new_game_requested.connect(_on_new_game)
		main_menu.continue_requested.connect(_show_save_select)
		main_menu.quit_requested.connect(_on_quit)
		main_menu.host_game_requested.connect(_on_host_game)
		main_menu.join_game_requested.connect(_on_join_game)
		main_menu.host_online_requested.connect(_on_host_online)
		main_menu.join_online_requested.connect(_on_join_online)
	
	if save_select_ui:
		save_select_ui.save_selected.connect(_on_continue)
		save_select_ui.back_requested.connect(_on_save_select_back)
		save_select_ui.new_save_requested.connect(_on_new_save_from_slot)
	
	# Listen for hardcore death — game over deletes save and returns to main menu
	if not GameManager.hardcore_death_occurred.is_connected(_on_hardcore_death):
		GameManager.hardcore_death_occurred.connect(_on_hardcore_death)

	if not NetworkManager.server_disconnected.is_connected(_on_mp_server_disconnected):
		NetworkManager.server_disconnected.connect(_on_mp_server_disconnected)
	if not NetworkManager.peer_disconnected.is_connected(_on_mp_peer_disconnected):
		NetworkManager.peer_disconnected.connect(_on_mp_peer_disconnected)

func _show_save_select() -> void:
	# Force the main menu fully opaque so its background scene is visible
	# behind the save select dialog instead of a gray void.
	main_menu.modulate.a = 1.0
	save_select_ui.show_ui()

func _on_save_select_back() -> void:
	# Hide save select — main menu with its scenic background was never hidden.
	save_select_ui.close_ui()
	main_menu.reset_visual_state()

func _on_host_game(p_seed: int, p_mode: int = GameManager.GameMode.SURVIVAL) -> void:
	print("Bootstrap: Host Game requested, seed=", p_seed, " mode=", p_mode)
	GameManager.set_game_mode(p_mode)
	_pending_new_game_seed = p_seed
	_connect_mp_success_signal(_on_host_started)
	_connect_mp_fail_signal()
	NetworkManager.host()

func _on_host_started(_peer_id: int) -> void:
	print("Bootstrap: Host started successfully")
	_cleanup_mp_signals()
	_show_save_select()

func _on_join_game(ip: String) -> void:
	print("Bootstrap: Join Game requested to ", ip)
	_connect_mp_success_signal(_on_join_success)
	_connect_mp_fail_signal()
	NetworkManager.join(ip)

func _on_host_online(p_seed: int, p_mode: int = GameManager.GameMode.SURVIVAL) -> void:
	print("Bootstrap: Host Online requested, seed=", p_seed, " mode=", p_mode)
	GameManager.set_game_mode(p_mode)
	_pending_new_game_seed = p_seed
	_connect_mp_success_signal(_on_host_started)
	_connect_mp_fail_signal()
	NetworkManager.host_via_eos()

func _on_join_online(join_code: String) -> void:
	print("Bootstrap: Join Online requested, code=", join_code)
	_connect_mp_success_signal(_on_join_success)
	_connect_mp_fail_signal()
	NetworkManager.join_via_eos_code(join_code)

func _on_join_success(peer_id: int) -> void:
	print("Bootstrap: Joined game successfully, peer ID: ", peer_id)
	_cleanup_mp_signals()
	_save_and_load_game_for_mp()

func _on_mp_connect_failed() -> void:
	print("Bootstrap: Multiplayer connection failed!")
	_cleanup_mp_signals()
	if main_menu:
		main_menu.visible = true
		main_menu.modulate.a = 1.0
		main_menu.process_mode = Node.PROCESS_MODE_INHERIT
		main_menu.reset_visual_state()

func _on_mp_server_disconnected() -> void:
	print("Bootstrap: Server disconnected!")
	NetworkManager.disconnect_from_server()
	_hide_game_and_show_menu()

func _on_mp_peer_disconnected(id: int) -> void:
	print("Bootstrap: Peer disconnected: ", id)

func _connect_mp_success_signal(callback: Callable) -> void:
	if NetworkManager.connection_succeeded.is_connected(_on_host_started):
		NetworkManager.connection_succeeded.disconnect(_on_host_started)
	if NetworkManager.connection_succeeded.is_connected(_on_join_success):
		NetworkManager.connection_succeeded.disconnect(_on_join_success)
	NetworkManager.connection_succeeded.connect(callback)

func _connect_mp_fail_signal() -> void:
	if NetworkManager.connection_failed.is_connected(_on_mp_connect_failed):
		NetworkManager.connection_failed.disconnect(_on_mp_connect_failed)
	NetworkManager.connection_failed.connect(_on_mp_connect_failed)

func _cleanup_mp_signals() -> void:
	if NetworkManager.connection_succeeded.is_connected(_on_host_started):
		NetworkManager.connection_succeeded.disconnect(_on_host_started)
	if NetworkManager.connection_succeeded.is_connected(_on_join_success):
		NetworkManager.connection_succeeded.disconnect(_on_join_success)
	if NetworkManager.connection_failed.is_connected(_on_mp_connect_failed):
		NetworkManager.connection_failed.disconnect(_on_mp_connect_failed)

func _save_and_load_game_for_mp() -> void:
	# For multiplayer, start a new game directly without save select
	if not NetworkManager.is_host():
		# Clients go straight to game
		_load_mp_game_as_client.call_deferred()
	else:
		# Host uses the normal new game flow via save select
		pass

func _load_mp_game_as_client() -> void:
	# Start game in client mode — world will be synced in later chunks
	print("Bootstrap: Starting game as client")
	GameManager.set_game_mode(GameManager.GameMode.SURVIVAL)
	_show_persistent_background()
	if main_menu:
		main_menu.visible = false
		main_menu.process_mode = Node.PROCESS_MODE_DISABLED
	var hud: CanvasLayer = null
	if game and game.has_node("HUD"):
		hud = game.get_node("HUD") as CanvasLayer
		hud.visible = true
	if game:
		game.process_mode = Node.PROCESS_MODE_INHERIT
		game.visible = true
	_show_ui_canvas_layers()

func _on_new_game(p_seed: int, p_mode: int = GameManager.GameMode.SURVIVAL) -> void:
	print("Bootstrap._on_new_game received! seed=", p_seed, " mode=", p_mode)
	GameManager.set_game_mode(p_mode)
	
	# Restore main menu opacity (faded out by button click tween) so the
	# scenic background is visible behind the save select dialog.
	main_menu.modulate.a = 1.0
	
	# Store the pending seed and show save select so the player picks a slot
	_pending_new_game_seed = p_seed
	if save_select_ui:
		save_select_ui.show_ui()


func _on_new_save_from_slot(slot_idx: int) -> void:
	# Player clicked an empty slot in the save select to start a new game there
	var p_seed: int = _pending_new_game_seed
	print("Bootstrap._on_new_save_from_slot: slot=", slot_idx, " seed=", p_seed)
	SaveManager.current_slot = slot_idx
	# Show the save select before starting the game (hides during load)
	if save_select_ui:
		save_select_ui.close_ui()
	
	# Start the new game in the chosen slot
	var tween := create_tween()
	tween.tween_interval(0.2)
	tween.tween_callback(_start_new_game.bind(p_seed))

func _on_continue(_slot: int = -1) -> void:
	print("Continue requested, slot=", SaveManager.current_slot)
	load_save_from_slot()
	# Fade to black
	var tween := create_tween()
	tween.tween_interval(0.2)
	tween.tween_callback(_load_game)


## Hide the save select UI before loading.
func load_save_from_slot() -> void:
	if save_select_ui and save_select_ui.visible:
		save_select_ui.close_ui()

func _on_quit() -> void:
	get_tree().quit()

func _hide_persistent_background() -> void:
	var canvas: CanvasLayer = get_node("CanvasLayer") as CanvasLayer
	if not canvas:
		return
	var bg: Node = canvas.get_node_or_null("BgPersistent")
	if bg:
		bg.visible = false


func _show_persistent_background() -> void:
	var canvas: CanvasLayer = get_node("CanvasLayer") as CanvasLayer
	if not canvas:
		return
	var bg: Node = canvas.get_node_or_null("BgPersistent")
	if bg:
		bg.visible = true


func _start_new_game(p_seed: int) -> void:
	# Stop main menu music — game ambience takes over via day/night cycle
	var am_node: Node = get_node("/root/AudioManager") if has_node("/root/AudioManager") else null
	if am_node and am_node.has_method("stop_music"):
		am_node.stop_music(1.0)
	
	# Hide persistent background so game world is visible
	_hide_persistent_background()
	
	# CRITICAL FIX: Explicitly hide and disable the menu first
	if main_menu:
		main_menu.visible = false
		main_menu.process_mode = Node.PROCESS_MODE_DISABLED
	
	# Show HUD first so we can set up the fade overlay before the game appears.
	var hud: CanvasLayer = null
	if game and game.has_node("HUD"):
		hud = game.get_node("HUD") as CanvasLayer
		hud.visible = true
		# Reset the day/night overlay to fully transparent
		if hud.has_node("Root/DayNightOverlay"):
			var overlay: ColorRect = hud.get_node("Root/DayNightOverlay") as ColorRect
			if overlay:
				overlay.color = Color(0.0, 0.0, 0.1, 0.0)
		# Cover screen with black so the game doesn't flash when it becomes visible.
		if hud.has_node("Root/FadeOverlay"):
			var fo: ColorRect = hud.get_node("Root/FadeOverlay") as ColorRect
			if fo:
				fo.visible = true
				fo.modulate = Color(0.0, 0.0, 0.0, 1.0)
		# Connect exit-to-menu signal if not already connected
		if not hud.exit_to_menu_requested.is_connected(_on_exit_to_menu):
			hud.exit_to_menu_requested.connect(_on_exit_to_menu)

	if game:
		game.process_mode = Node.PROCESS_MODE_INHERIT
		game.visible = true
	
	# Re-show all UI CanvasLayers (they were hidden on exit to menu)
	_show_ui_canvas_layers()
	
	# Remove any enemy/boss/animal nodes left from previous creative sessions
	for group_name in ["enemies", "bosses", "animals"]:
		for node in get_tree().get_nodes_in_group(group_name):
			if is_instance_valid(node):
				node.queue_free()
	
	# Reset interior/mine static flags that may be stale from a previous
	# mine session. These are static vars on GameManager and persist
	# across the entire Bootstrap lifetime.
	GameManager.inside_interior = false
	GameManager.near_campfire = false

	# Reset game state — delete current slot's save
	SaveManager.delete_save_in_slot(SaveManager.current_slot)
	
	# Reinitialize the game with the chosen seed
	var world: Node2D = null
	if game and game.has_node("World"):
		world = game.get_node("World")
		world.world_seed = p_seed
		world.generate_world()
		
		# Notify Main that the world is ready (sends seed to any pending clients)
		if game.has_method("notify_world_generated"):
			game.notify_world_generated(p_seed)
		
		if hud and hud.has_method("set_seed_display"):
			hud.set_seed_display(p_seed)
		
		var player: CharacterBody2D = null
		if game:
			# In multiplayer the local player node is renamed Player_<id> so
			# path-based RPC routing matches remote copies; in single-player
			# it keeps the scene name "Player".
			if NetworkManager.is_network_active():
				player = game.get_node_or_null("Player_%d" % multiplayer.get_unique_id())
			if player == null:
				player = game.get_node_or_null("Player")
			if player:
				# Update name label with whatever the user typed (Player._ready ran before they typed)
				player.name_label.text = GameManager.player_name
			if world and player:
				# Spawn 6 cells inland from the coastline (away from the Boat's StaticBody2D)
				var spawn_cell := Vector2i(world.world_width - 35, world.world_height / 2)
				player.global_position = world.cell_to_world(spawn_cell)
				# Spawn starter animals near the player so they're visible immediately
				if world.has_method("spawn_starter_animals_near"):
					world.spawn_starter_animals_near(player.global_position)
					# Show a subtle hint dialogue above the player
					player.show_dialogue("Huh, those animals seem curious. Maybe if I had the right food they'd come closer...", 4.0)
	
	# Reset managers
	GameManager.current_day = 1
	GameManager.current_minute_of_day = 6 * 60
	GameManager.money = 50
	GameManager.reset_health()
	GameManager.reset_hunger()
	InventoryManager.clear()
	# Player starts with only the Hoe and Watering Can.
	# Give 3 seeds of a common-rarity procedural crop so they can begin farming.
	var starter_crops: Array[CropData] = DataManager.get_procedural_crops()
	for starter_crop in starter_crops:
		if starter_crop.rarity == "Common":
			InventoryManager.add_item(starter_crop.seed_item_id, 3)
			break	
	UpgradeManager.levels = {
		UpgradeManager.Upgrade.INVENTORY: 0,
		UpgradeManager.Upgrade.TOOLS: 0,
		UpgradeManager.Upgrade.FARMING_SPEED: 0,
		UpgradeManager.Upgrade.RARE_SEEDS: 0,
	}
	
	# Pet reset — start with no pets
	PetManager.owned_pets.clear()
	PetManager.active_pet_id = ""
	
	# Recalculate day/night phase to match the reset time
	var reset_hour := GameManager.get_hour()
	var reset_phase := GameManager.day_night.get_phase_for_hour(reset_hour)
	GameManager.day_night.current_phase = reset_phase
	GameManager.phase_changed.emit(reset_phase)
	
	# Emit signals to update UI
	GameManager.day_changed.emit(GameManager.current_day)
	GameManager.time_changed.emit(GameManager.get_hour(), GameManager.get_minute())
	GameManager.money_changed.emit(GameManager.money)
	
	# Fade in from black (overlay was set to full black before game appeared)
	if hud and hud.has_node("Root/FadeOverlay"):
		var fo: ColorRect = hud.get_node("Root/FadeOverlay") as ColorRect
		if fo:
			fo.modulate = Color(0.0, 0.0, 0.0, 1.0)
			var ftween := create_tween()
			ftween.tween_property(fo, "modulate:a", 0.0, 0.5)
			ftween.tween_callback(func(): fo.visible = false)


func _load_game() -> void:
	# Stop main menu music — game ambience takes over via day/night cycle
	var am_node: Node = get_node("/root/AudioManager") if has_node("/root/AudioManager") else null
	if am_node and am_node.has_method("stop_music"):
		am_node.stop_music(1.0)
	
	# Hide persistent background so game world is visible
	_hide_persistent_background()
	
	# CRITICAL FIX: Explicitly hide and disable the menu first
	if main_menu:
		main_menu.visible = false
		main_menu.process_mode = Node.PROCESS_MODE_DISABLED
	
	# Show HUD first so we can set up the fade overlay before the game appears.
	var hud: CanvasLayer = null
	if game and game.has_node("HUD"):
		hud = game.get_node("HUD") as CanvasLayer
		hud.visible = true
		# Reset the day/night overlay to fully transparent
		if hud.has_node("Root/DayNightOverlay"):
			var overlay: ColorRect = hud.get_node("Root/DayNightOverlay") as ColorRect
			if overlay:
				overlay.color = Color(0.0, 0.0, 0.1, 0.0)
		# Cover screen with black so the game doesn't flash when it becomes visible.
		if hud.has_node("Root/FadeOverlay"):
			var fo: ColorRect = hud.get_node("Root/FadeOverlay") as ColorRect
			if fo:
				fo.visible = true
				fo.modulate = Color(0.0, 0.0, 0.0, 1.0)
		# Connect exit-to-menu signal if not already connected
		if not hud.exit_to_menu_requested.is_connected(_on_exit_to_menu):
			hud.exit_to_menu_requested.connect(_on_exit_to_menu)

	if game:
		game.process_mode = Node.PROCESS_MODE_INHERIT
		game.visible = true
	
	# Re-show all UI CanvasLayers (they were hidden on exit to menu)
	_show_ui_canvas_layers()
	
	# Reset pet state before loading (prevents stale active_pet_id flicker)
	var pm_node: Node = get_node("/root/PetManager") if has_node("/root/PetManager") else null
	if pm_node:
		pm_node.owned_pets.clear()
		pm_node.active_pet_id = ""
	
	# Load the save file
	SaveManager.load_game()
	
	# Emit phase_changed after loading so ambient music starts
	var loaded_hour := GameManager.get_hour()
	var loaded_phase := GameManager.day_night.get_phase_for_hour(loaded_hour)
	GameManager.day_night.current_phase = loaded_phase
	GameManager.phase_changed.emit(loaded_phase)
	
	# Show the loaded seed in the HUD
	if hud and hud.has_method("set_seed_display"):
		var world_node: Node2D = game.get_node_or_null("World")
		if world_node:
			hud.set_seed_display(world_node.world_seed)
	
	# Fade in from black (overlay was set to full black before game appeared)
	if hud and hud.has_node("Root/FadeOverlay"):
		var fo: ColorRect = hud.get_node("Root/FadeOverlay") as ColorRect
		if fo:
			fo.modulate = Color(0.0, 0.0, 0.0, 1.0)
			var ftween := create_tween()
			ftween.tween_property(fo, "modulate:a", 0.0, 0.5)
			ftween.tween_callback(func(): fo.visible = false)

## Helper to re-show all CanvasLayer UIs after returning from the main menu.
## They are explicitly hidden in _on_exit_to_menu() because CanvasLayer renders
## independently of its parent Node2D's visibility.
func _show_ui_canvas_layers() -> void:
	if not game:
		return
	for child in game.get_children():
		if child is CanvasLayer and child.name != "TownUI":
			child.visible = true

func _on_hardcore_death() -> void:
	print("Bootstrap._on_hardcore_death() — save already deleted, returning to menu")
	
	# Clean up like exit-to-menu but WITHOUT saving (save already deleted).
	# NOTE: this must run BEFORE showing the death overlay because it kills all
	# active tweens (cleaning up main-menu button animations).  If we created
	# the death-label tween first, it would be killed here and never fade out.
	_hide_game_and_show_menu()
	
	# Show a temporary "Game Over" label in the CanvasLayer on top of the menu.
	_show_hardcore_death_overlay()


func _show_hardcore_death_overlay() -> void:
	var canvas: CanvasLayer = get_node("CanvasLayer") as CanvasLayer
	if not canvas:
		return
	# Remove any stale game-over label
	var old_label := canvas.get_node_or_null("HardcoreDeathLabel")
	if old_label:
		old_label.queue_free()
	
	var death_label := Label.new()
	death_label.name = "HardcoreDeathLabel"
	death_label.text = "☠ GAME OVER ☠\nYour world has been deleted."
	death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	death_label.add_theme_font_size_override("font_size", 48)
	death_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.1, 1.0))
	death_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	death_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	death_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(death_label)
	
	# Fade out after 2.5 seconds — this tween is created AFTER _hide_game_and_show_menu
	# has already killed all stale tweens, so it won't be interrupted.
	var dtween := create_tween()
	dtween.tween_interval(2.5)
	dtween.tween_property(death_label, "modulate:a", 0.0, 1.0)
	dtween.tween_callback(func():
		if is_instance_valid(death_label):
			death_label.queue_free()
	)

func _hide_game_and_show_menu() -> void:
	# Hide game and HUD
	if game:
		var wm: Node = game.get_node_or_null("WorldMap")
		if wm and wm.has_method("close"):
			wm.close()
		var op: Node = game.get_node_or_null("ObjectivesPanel")
		if op and op.has_method("close"):
			op.close()
		
		game.visible = false
		game.process_mode = Node.PROCESS_MODE_DISABLED
		for child in game.get_children():
			if child is CanvasLayer:
				child.visible = false
	
	if main_menu:
		for t: Tween in get_tree().get_processed_tweens():
			if t.is_valid():
				t.kill()
		main_menu.reset_visual_state()
		main_menu.visible = true
		main_menu.process_mode = Node.PROCESS_MODE_INHERIT
	
	# Restart main menu music when returning from game
	var am_node: Node = get_node("/root/AudioManager") if has_node("/root/AudioManager") else null
	if am_node and am_node.has_method("play_music"):
		am_node.play_music(am_node.Sound.MAIN_MENU, 1.0)
	
	_show_persistent_background()

func _on_exit_to_menu() -> void:
	print("Bootstrap._on_exit_to_menu() running")

	# Exit the mine first if inside one, so the save records a valid
	# overworld player position instead of the INTERIOR_VOID mine offset.
	# Without this, loading the save later places the player in the void
	# with stale camera limits and a broken inside_interior flag.
	var world_boot := get_tree().get_first_node_in_group("world")
	var was_in_mine: bool = false
	if world_boot:
		was_in_mine = world_boot.get("current_mine_room") != null
		if world_boot.has_method("emergency_exit_mine"):
			world_boot.emergency_exit_mine()
	
	# If the player was in the mine, teleport them to the overworld spawn
	# so the save records a sensible position.
	if was_in_mine and world_boot:
		var player := get_tree().get_first_node_in_group("player")
		if player:
			var spawn_cell := Vector2i(world_boot.world_width - 35, world_boot.world_height / 2)
			player.global_position = world_boot.cell_to_world(spawn_cell)

	# Save current game state before exiting
	SaveManager.save_game()

	# Disconnect from multiplayer session if active
	if NetworkManager.is_network_active():
		NetworkManager.disconnect_from_server()
	
	_hide_game_and_show_menu()
	
	if main_menu:
		print("  main_menu.visible after: ", main_menu.visible)
		print("  main_menu.modulate after: ", main_menu.modulate)
