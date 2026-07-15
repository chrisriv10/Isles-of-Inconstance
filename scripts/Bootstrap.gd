extends Node

## Bootstrap node that manages the main menu to game transition.
## This is the entry point for the application.

var main_menu: Control
var game: Node2D

func _ready() -> void:
	call_deferred("_connect_signals")

func _connect_signals() -> void:
	main_menu = get_node("MainMenu")
	game = get_node("Game")
	
	if main_menu:
		main_menu.new_game_requested.connect(_on_new_game)
		main_menu.continue_requested.connect(_on_continue)
		main_menu.quit_requested.connect(_on_quit)

func _on_new_game() -> void:
	print("New Game requested") # Debug print
	# Fade to black (optional visual feedback)
	var tween := create_tween()
	tween.tween_interval(0.2)
	tween.tween_callback(_start_new_game)

func _on_continue() -> void:
	print("Continue requested") # Debug print
	# Fade to black
	var tween := create_tween()
	tween.tween_interval(0.2)
	tween.tween_callback(_load_game)

func _on_quit() -> void:
	get_tree().quit()

func _start_new_game() -> void:
	# CRITICAL FIX: Explicitly hide and disable the menu first
	if main_menu:
		main_menu.visible = false
		main_menu.process_mode = Node.PROCESS_MODE_DISABLED
	
	if game:
		game.process_mode = Node.PROCESS_MODE_INHERIT
		game.visible = true

	# Show HUD now that game is starting
	var hud: Control = null
	if game and game.has_node("HUD"):
		hud = game.get_node("HUD")
		hud.visible = true
	
	# Reset game state
	SaveManager.delete_save()
	
	# Reinitialize the game
	var world: Node2D = null
	if game and game.has_node("World"):
		world = game.get_node("World")
		world.generate_world()
		
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
	var hud: Control = null
	if game and game.has_node("HUD"):
		hud = game.get_node("HUD")
		hud.visible = true
	
	# Load the save file
	SaveManager.load_game()
	
	# Fade in (re-use the 'hud' variable defined above)
	if hud and hud.has_method("fade_to_black"):
		hud.fade_to_black(0.3)
