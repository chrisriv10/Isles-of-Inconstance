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
	# Fade to black
	var tween := create_tween()
	tween.tween_interval(0.2)
	tween.tween_callback(_start_new_game)

func _on_continue() -> void:
	# Fade to black
	var tween := create_tween()
	tween.tween_interval(0.2)
	tween.tween_callback(_load_game)

func _on_quit() -> void:
	get_tree().quit()

func _start_new_game() -> void:
	main_menu.visible = false
	game.visible = true
	
	# Reset game state
	SaveManager.delete_save()
	
	# Reinitialize the game
	var world := game.get_node("World")
	if world:
		world.generate_world()
		
		var player := game.get_node("Player")
		if player:
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
	
	# Fade in
	var hud := game.get_node("HUD")
	if hud and hud.has_method("fade_to_black"):
		hud.fade_to_black(0.3)

func _load_game() -> void:
	main_menu.visible = false
	game.visible = true
	
	# Load the save file
	SaveManager.load_game()
	
	# Fade in
	var hud := game.get_node("HUD")
	if hud and hud.has_method("fade_to_black"):
		hud.fade_to_black(0.3)
