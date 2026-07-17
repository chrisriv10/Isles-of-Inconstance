extends Control
class_name MainMenuUI

## Styled main menu with animated starfield, tweened button effects,
## and a themed pixel-art farming adventure aesthetic.

signal new_game_requested(seed: int)
signal continue_requested()
signal quit_requested()

@onready var new_game_button: Button = $ContentCenter/ButtonContainer/NewGameButton
@onready var continue_button: Button = $ContentCenter/ButtonContainer/ContinueButton
@onready var quit_button: Button = $ContentCenter/ButtonContainer/QuitButton
@onready var seed_input: LineEdit = $ContentCenter/ButtonContainer/SeedBox/SeedInput
@onready var random_seed_button: Button = $ContentCenter/ButtonContainer/SeedBox/RandomSeedButton
@onready var title_panel: PanelContainer = $TitlePanel
@onready var content_center: Control = $ContentCenter
@onready var star_field: Node2D = $StarField

# Star particle data
var _stars: Array[Dictionary] = []
var _star_count: int = 60

func _ready() -> void:
	new_game_button.pressed.connect(_on_new_game_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	random_seed_button.pressed.connect(_on_random_seed_pressed)
	
	# Disable continue button if no save exists
	continue_button.disabled = not SaveManager.has_save_file()
	
	# Style the seed input
	seed_input.text = "0"
	
	# Set up entrance animation
	_setup_entrance_animation()
	
	# Generate star particles
	_generate_stars()

func _setup_entrance_animation() -> void:
	# Start invisible
	for child in [title_panel, content_center]:
		child.modulate.a = 0.0
	
	# Title: fade in and slide down
	var title_tween := create_tween()
	title_tween.set_parallel(true)
	title_tween.set_ease(Tween.EASE_OUT)
	title_tween.set_trans(Tween.TRANS_CUBIC)
	title_tween.tween_property(title_panel, "modulate:a", 1.0, 0.8).from(0.0)
	
	# Content: delay then fade in
	var content_tween := create_tween().set_parallel(true)
	content_tween.tween_interval(0.4)
	content_tween.tween_property(content_center, "modulate:a", 1.0, 0.7)
	content_tween.set_ease(Tween.EASE_OUT)
	content_tween.set_trans(Tween.TRANS_CUBIC)

## Restore visual state after returning from game.
## Called by Bootstrap._on_exit_to_menu() to undo the fade-out effect.
func reset_visual_state() -> void:
	modulate.a = 1.0
	title_panel.modulate.a = 1.0
	content_center.modulate.a = 1.0

	# Re-enable buttons
	for child in content_center.find_children("*", "Button", true, false):
		if child is Button:
			child.disabled = false

	# Update continue button state (save may have been created)
	continue_button.disabled = not SaveManager.has_save_file()

func _generate_stars() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	
	var viewport_size := get_viewport_rect().size
	_stars.clear()
	for i in _star_count:
		var star: Dictionary = {
			"pos": Vector2(rng.randf_range(0, viewport_size.x), rng.randf_range(0, viewport_size.y)),
			"speed": rng.randf_range(2.0, 8.0),
			"brightness": rng.randf_range(0.3, 1.0),
			"twinkle_offset": rng.randf_range(0, TAU),
			"size": rng.randf_range(1.0, 2.5),
		}
		_stars.append(star)

func _process(delta: float) -> void:
	_animate_stars(delta)

func _animate_stars(delta: float) -> void:
	if _stars.is_empty():
		return
	
	var viewport_size := get_viewport_rect().size
	var time := Time.get_ticks_msec() / 1000.0
	
	# Update star positions
	for star in _stars:
		star["pos"].y -= star["speed"] * delta * 5.0
		if star["pos"].y < -5:
			star["pos"].y = viewport_size.y + 5
			star["pos"].x = randf_range(0, viewport_size.x)
	
	# Queue redraw for visual update
	star_field.queue_redraw()

func _draw() -> void:
	# Draw animated stars on the star_field node
	if _stars.is_empty():
		return
	var time := Time.get_ticks_msec() / 1000.0
	for star in _stars:
		var twinkle: float = sin(time * 2.0 + star["twinkle_offset"]) * 0.3 + 0.7
		var alpha: float = star["brightness"] * twinkle
		var color := Color(1.0, 0.95, 0.8, alpha * 0.6)
		draw_circle(star["pos"], star["size"], color)

# ---- Button Effects ----

func _on_new_game_pressed() -> void:
	print("MainMenu: New Game clicked!")
	if SaveManager.has_save_file():
		SaveManager.delete_save()
	
	AudioManager.play(AudioManager.Sound.UI_CLICK)
	var seed_value := seed_input.text.to_int()
	_fade_out_and_emit("new_game", seed_value)

func _on_random_seed_pressed() -> void:
	seed_input.text = str(randi())
	AudioManager.play(AudioManager.Sound.UI_CLICK)

func _on_continue_pressed() -> void:
	print("MainMenu: Continue clicked!")
	AudioManager.play(AudioManager.Sound.UI_CLICK)
	_fade_out_and_emit("continue")

func _on_quit_pressed() -> void:
	print("MainMenu: Quit clicked!")
	AudioManager.play(AudioManager.Sound.UI_CLICK)
	_fade_out_and_emit("quit")

## Fade out the whole menu before emitting the signal for a polished transition
func _fade_out_and_emit(action: String, seed_val: int = 0) -> void:
	# Disable all buttons during transition
	for child in content_center.find_children("*", "Button", true, false):
		if child is Button:
			child.disabled = true
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_property(title_panel, "modulate:a", 0.0, 0.3)
	tween.tween_property(content_center, "modulate:a", 0.0, 0.3)
	
	tween.tween_callback(func():
		print("MainMenu: Fade complete, emitting signal: ", action)
		match action:
			"new_game":
				new_game_requested.emit(seed_val)
			"continue":
				continue_requested.emit()
			"quit":
				quit_requested.emit()
	)
