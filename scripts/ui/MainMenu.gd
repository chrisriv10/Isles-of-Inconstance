extends Control

signal new_game_requested(seed: int)
signal continue_requested()
signal quit_requested()

@onready var new_game_button: Button = $TitleContainer/ButtonContainer/NewGameButton
@onready var continue_button: Button = $TitleContainer/ButtonContainer/ContinueButton
@onready var quit_button: Button = $TitleContainer/ButtonContainer/QuitButton
@onready var seed_input: LineEdit = $TitleContainer/SeedBox/SeedInput
@onready var random_seed_button: Button = $TitleContainer/SeedBox/RandomSeedButton

func _ready() -> void:
	new_game_button.pressed.connect(_on_new_game_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	random_seed_button.pressed.connect(_on_random_seed_pressed)
	
	# Disable continue button if no save exists
	continue_button.disabled = not SaveManager.has_save_file()
	
	# Add hover effects
	_setup_button_effects(new_game_button)
	_setup_button_effects(continue_button)
	_setup_button_effects(quit_button)
	_setup_button_effects(random_seed_button)

func _setup_button_effects(button: Button) -> void:
	button.mouse_entered.connect(func(): _on_button_hover(button, true))
	button.mouse_exited.connect(func(): _on_button_hover(button, false))

func _on_button_hover(button: Button, is_hovered: bool) -> void:
	var tween := create_tween()
	var target_scale := Vector2(1.05, 1.05) if is_hovered else Vector2.ONE
	tween.tween_property(button, "scale", target_scale, 0.1)

func _on_new_game_pressed() -> void:
	# Delete existing save if it exists
	if SaveManager.has_save_file():
		SaveManager.delete_save()
	
	AudioManager.play(AudioManager.Sound.UI_CLICK)
	var seed_value := seed_input.text.to_int()
	new_game_requested.emit(seed_value)

func _on_random_seed_pressed() -> void:
	seed_input.text = str(randi())

func _on_continue_pressed() -> void:
	AudioManager.play(AudioManager.Sound.UI_CLICK)
	continue_requested.emit()

func _on_quit_pressed() -> void:
	AudioManager.play(AudioManager.Sound.UI_CLICK)
	quit_requested.emit()
