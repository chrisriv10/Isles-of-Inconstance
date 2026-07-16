extends Node

## Bootstrap node that manages the main menu to game transition.
## This is the entry point for the application.

var main_menu: Control
var game: Node2D

func _ready() -> void:
	call_deferred("_connect_signals")

func _connect_signals() -> void:
	main_menu = get_node("CanvasLayer/MainMenu") as Control
	game = get_node("Game")
	
	if main_menu:
		main_menu.new_game_requested.connect(_on_new_game)
		main_menu.continue_requested.connect(_on_continue)
		main_menu.quit_requested.connect(_on_quit)

func _on_new_game(p_seed: int) -> void:
	print("New Game requested with seed: ", p_seed) # Debug print
	# Fade to black (optional visual feedback)
	var tween := create_tween()
	tween.tween_interval(0.2)
	tween.tween_callback(_start_new_game.bind(p_seed))

func _on_continue() -> void:
	print("Continue requested") # Debug print
	# Fade to black
	var tween := create_tween()
	tween.tween_interval(0.2)
	tween.tween_callback(_load_game)

func _on_quit() -> void:
	get_tree().quit()

func _start_new_game(p_seed: int) -> void:
	# CRITICAL FIX: Explicitly hide and disable the menu first
	if main_menu:
		main_menu.visible = false
		main_menu.process_mode = Node.PROCESS_MODE_DISABLED
	
	if game:
		game.process_mode = Node.PROCESS_MODE_INHERIT
		game.visible = true

	# Show HUD now that game is starting
	var hud: CanvasLayer = null
	if game and game.has_node("HUD"):
		hud = game.get_node("HUD") as CanvasLayer
		hud.visible = true
		# Connect exit-to-menu signal if not already connected
		if not hud.exit_to_menu_requested.is_connected(_on_exit_to_menu):
			hud.exit_to_menu_requested.connect(_on_exit_to_menu)
	
	# Re-show all UI CanvasLayers (they were hidden on exit to menu)
	_show_ui_canvas_layers()
	
	# Reset game state
	SaveManager.delete_save()
	
	# Reinitialize the game with the chosen seed
	var world: Node2D = null
	if game and game.has_node("World"):
		world = game.get_node("World")
		world.world_seed = p_seed
		world.generate_world()
		
		if hud and hud.has_method("set_seed_display"):
			hud.set_seed_display(p_seed)
		
		var player: CharacterBody2D = null
		if game and game.has_node("Player"):
			player = game.get_node("Player")
			if world and player:
				var spawn_cell := Vector2i(world.world_width / 2, world.world_height / 2)
				player.global_position = world.cell_to_world(spawn_cell)
	
	# Reset managers
	GameManager.current_day = 1
	GameManager.current_minute_of_day = 6 * 60
	GameManager.money = 500
	InventoryManager.clear()
	# Give the player starter seeds for each procedural crop so they can
	# begin farming immediately without first finding the shop.
	var starter_crops := DataManager.get_procedural_crops()
	for starter_crop in starter_crops:
		if starter_crop.seed_item_id != "":
			InventoryManager.add_item(starter_crop.seed_item_id, 5)
	# Also give a few compost to get started
	InventoryManager.add_item("compost", 3)
	# Give some stone for crafting
	InventoryManager.add_item("stone", 10)
	InventoryManager.add_item("wood", 5)
	UpgradeManager.levels = {
		UpgradeManager.Upgrade.INVENTORY: 0,
		UpgradeManager.Upgrade.TOOLS: 0,
		UpgradeManager.Upgrade.FARMING_SPEED: 0,
		UpgradeManager.Upgrade.RARE_SEEDS: 0,
	}
	
	# Emit signals to update UI
	GameManager.day_changed.emit(GameManager.current_day)
	GameManager.time_changed.emit(GameManager.get_hour(), GameManager.get_minute())
	GameManager.money_changed.emit(GameManager.money)
	
	# Fade in (re-use the 'hud' variable defined above)
	if hud and hud.has_method("fade_to_black"):
		hud.fade_to_black(0.3)

func _load_game() -> void:
	# CRITICAL FIX: Explicitly hide and disable the menu first
	if main_menu:
		main_menu.visible = false
		main_menu.process_mode = Node.PROCESS_MODE_DISABLED
	
	if game:
		game.process_mode = Node.PROCESS_MODE_INHERIT
		game.visible = true

	# Show HUD now that game is starting
	var hud: CanvasLayer = null
	if game and game.has_node("HUD"):
		hud = game.get_node("HUD") as CanvasLayer
		hud.visible = true
		# Connect exit-to-menu signal if not already connected
		if not hud.exit_to_menu_requested.is_connected(_on_exit_to_menu):
			hud.exit_to_menu_requested.connect(_on_exit_to_menu)
	
	# Re-show all UI CanvasLayers (they were hidden on exit to menu)
	_show_ui_canvas_layers()
	
	# Load the save file
	SaveManager.load_game()
	
	# Show the loaded seed in the HUD
	if hud and hud.has_method("set_seed_display"):
		var world_node: Node2D = game.get_node_or_null("World")
		if world_node:
			hud.set_seed_display(world_node.world_seed)
	
	# Fade in (re-use the 'hud' variable defined above)
	if hud and hud.has_method("fade_to_black"):
		hud.fade_to_black(0.3)

## Helper to re-show all CanvasLayer UIs after returning from the main menu.
## They are explicitly hidden in _on_exit_to_menu() because CanvasLayer renders
## independently of its parent Node2D's visibility.
func _show_ui_canvas_layers() -> void:
	if not game:
		return
	for child in game.get_children():
		if child is CanvasLayer:
			child.visible = true

func _on_exit_to_menu() -> void:
	# Save current game state before exiting
	SaveManager.save_game()
	
	# Hide game and HUD
	if game:
		game.visible = false
		game.process_mode = Node.PROCESS_MODE_DISABLED
		# Explicitly hide all CanvasLayer children (HUD, Shop, Inventory, Crafting)
		# CanvasLayer renders independently of parent visibility, so hiding the
		# parent Node2D does NOT hide them.
		for child in game.get_children():
			if child is CanvasLayer:
				child.visible = false
	
	# Show main menu
	if main_menu:
		main_menu.visible = true
		main_menu.process_mode = Node.PROCESS_MODE_INHERIT
		# Update continue button state (now that we just saved)
		if main_menu.has_node("TitleContainer/ButtonContainer/ContinueButton"):
			var continue_btn: Button = main_menu.get_node("TitleContainer/ButtonContainer/ContinueButton")
			continue_btn.disabled = not SaveManager.has_save_file()
