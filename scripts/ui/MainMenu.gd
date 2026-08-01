extends Control
class_name MainMenuUI

## Styled main menu with animated starfield, tweened button effects,
## and a themed pixel-art farming adventure aesthetic.

signal new_game_requested()
signal continue_requested()
signal quit_requested()
signal host_game_requested()
signal join_online_requested(join_code: String)

@onready var new_game_button: Button = $ContentCenter/ButtonContainer/NewGameButton
@onready var continue_button: Button = $ContentCenter/ButtonContainer/ContinueButton
@onready var quit_button: Button = $ContentCenter/ButtonContainer/QuitButton
@onready var name_input: LineEdit = $ContentCenter/ButtonContainer/NameBox/NameInput
@onready var title_panel: PanelContainer = $TitlePanel
@onready var content_center: Control = $ContentCenter
@onready var star_field: Node2D = $StarField
@onready var host_game_button: Button = $ContentCenter/ButtonContainer/HostGameButton
@onready var join_game_button: Button = $ContentCenter/ButtonContainer/JoinGameButton
@onready var join_code_box: HBoxContainer = $ContentCenter/ButtonContainer/JoinCodeBox
@onready var join_code_input: LineEdit = $ContentCenter/ButtonContainer/JoinCodeBox/JoinCodeInput
@onready var join_connect_button: Button = $ContentCenter/ButtonContainer/JoinCodeBox/JoinConnectButton
@onready var title_vbox: VBoxContainer = $TitlePanel/TitleVBox

# Star particle data
var _stars: Array[Dictionary] = []
var _star_count: int = 60

func _ready() -> void:
	# Show the game world behind the menu
	_setup_world_background()
	
	new_game_button.pressed.connect(_on_new_game_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	host_game_button.pressed.connect(_on_host_game_pressed)
	join_game_button.pressed.connect(_on_join_game_pressed)
	join_connect_button.pressed.connect(_on_join_connect_pressed)
	
	# Enable continue if any save exists
	var save_count: int = SaveManager.count_saves()
	continue_button.disabled = save_count == 0
	if save_count > 0:
		continue_button.text = "Continue (%d)" % save_count
	else:
		continue_button.text = "Continue"
	
	# Set up entrance animation
	_setup_entrance_animation()
	
	# Add logo texture replacing title text (before entrance animation)
	_setup_logo()
	
	# Generate star particles
	_generate_stars()
	
	# Start main menu music
	var audio_mgr: Node = get_node("/root/AudioManager") if has_node("/root/AudioManager") else null
	if audio_mgr and audio_mgr.has_method("play_music"):
		audio_mgr.play_music(audio_mgr.Sound.MAIN_MENU)

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
	join_code_box.visible = false

	# Restore mouse filter (might have been set to IGNORE during fade)
	content_center.mouse_filter = Control.MOUSE_FILTER_PASS

	# Re-enable buttons
	for child in content_center.find_children("*", "Button", true, false):
		if child is Button:
			child.disabled = false

	# Update continue button state (save may have been created)
	var save_count: int = SaveManager.count_saves()
	continue_button.disabled = save_count == 0
	if save_count > 0:
		continue_button.text = "Continue (%d)" % save_count
	else:
		continue_button.text = "Continue"

func _setup_world_background() -> void:
	# Load the world background texture
	var bg_tex: Texture2D = load("res://assets/generated/world_background.png")
	if not bg_tex:
		return
	var bg_rect := TextureRect.new()
	bg_rect.name = "BgWorldTexture"
	bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg_rect)
	move_child(bg_rect, 1)
	bg_rect.texture = bg_tex
	# Force anchors to take effect after being added to tree
	bg_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _setup_logo() -> void:
	# Give title panel a rounded wooden sign look
	var sign_style := StyleBoxFlat.new()
	sign_style.bg_color = Color(0.361, 0.239, 0.118, 1.0)
	sign_style.border_width_left = 4
	sign_style.border_width_top = 4
	sign_style.border_width_right = 4
	sign_style.border_width_bottom = 4
	sign_style.border_color = Color(0.290, 0.180, 0.078, 1.0)
	sign_style.corner_radius_top_left = 34
	sign_style.corner_radius_top_right = 34
	sign_style.corner_radius_bottom_right = 24
	sign_style.corner_radius_bottom_left = 24
	sign_style.anti_aliasing = true
	sign_style.corner_detail = 10
	sign_style.shadow_size = 8
	sign_style.shadow_color = Color(0.0, 0.0, 0.0, 0.4)
	sign_style.shadow_offset = Vector2(0, 4)
	title_panel.add_theme_stylebox_override(&"panel", sign_style)
	
	# Replace title label + subtitle + divider with logo texture
	var logo_tex: Texture2D = load("res://assets/generated/logo_isles_of_inconstance_frame_0.png")
	if logo_tex:
		# Add top spacer to push logo down in the panel
		var top_spacer := Control.new()
		top_spacer.name = "LogoTopSpacer"
		top_spacer.custom_minimum_size = Vector2(0, 28)
		title_vbox.add_child(top_spacer)
		
		var logo_rect := TextureRect.new()
		logo_rect.name = "LogoTexture"
		logo_rect.texture = logo_tex
		logo_rect.stretch_mode = TextureRect.STRETCH_SCALE
		logo_rect.custom_minimum_size = Vector2(440, 130)
		logo_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		logo_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		
		var title_label: Label = title_vbox.get_node("TitleLabel")
		var subtitle: Label = title_vbox.get_node("Subtitle")
		var divider: ColorRect = title_vbox.get_node("Divider")
		
		# Hide original text nodes instead of removing (safer)
		title_label.hide()
		divider.hide()
		subtitle.hide()
		title_vbox.add_child(logo_rect)

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
		var color := Color(0.8, 0.6, 0.15, alpha * 0.6)
		draw_circle(star["pos"], star["size"], color)

# ---- Button Effects ----

func _on_new_game_pressed() -> void:
	print("MainMenu: New Game clicked!")
	
	# Store player name
	var p_name: String = name_input.text.strip_edges()
	if p_name.is_empty():
		p_name = "Farmer"
	GameManager.player_name = p_name
	# Use a descriptive default save name (rename any time via Save Select)
	GameManager.save_name = "My Island"
	
	AudioManager.play(AudioManager.Sound.UI_CLICK)
	_fade_out_and_emit("new_game")

func _on_host_game_pressed() -> void:
	print("MainMenu: Host Game clicked!")
	var p_name: String = name_input.text.strip_edges()
	if p_name.is_empty():
		p_name = "Farmer"
	GameManager.player_name = p_name
	AudioManager.play(AudioManager.Sound.UI_CLICK)
	_fade_out_and_emit("host")

func _on_join_game_pressed() -> void:
	print("MainMenu: Join Game clicked!")
	AudioManager.play(AudioManager.Sound.UI_CLICK)
	join_code_box.visible = not join_code_box.visible
	if join_code_box.visible:
		join_code_input.grab_focus.call_deferred()

func _on_join_connect_pressed() -> void:
	print("MainMenu: Join Connect clicked!")
	var code: String = join_code_input.text.strip_edges()
	if code.is_empty():
		return
	AudioManager.play(AudioManager.Sound.UI_CLICK)
	join_code_box.visible = false
	_fade_out_and_emit("join", code)

func _on_quit_pressed() -> void:
	print("MainMenu: Quit clicked!")
	AudioManager.play(AudioManager.Sound.UI_CLICK)
	_fade_out_and_emit("quit")

func _on_continue_pressed() -> void:
	print("MainMenu: Continue clicked!")
	AudioManager.play(AudioManager.Sound.UI_CLICK)
	_fade_out_and_emit("continue")

## Fade out the whole menu before emitting the signal for a polished transition.
## Uses mouse_filter instead of child.disabled so it can never get stuck
## in a broken state if the tween is killed mid-flight.
func _fade_out_and_emit(action: String, join_code: String = "") -> void:
	# Block input during transition via mouse_filter (safer than child.disabled)
	content_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_property(title_panel, "modulate:a", 0.0, 0.3)
	tween.tween_property(content_center, "modulate:a", 0.0, 0.3)
	
	tween.tween_callback(func():
		print("MainMenu: Fade complete, emitting signal: ", action)
		# Restore mouse filter in case nobody calls reset_visual_state
		if is_instance_valid(content_center):
			content_center.mouse_filter = Control.MOUSE_FILTER_PASS
		match action:
			"new_game":
				new_game_requested.emit()
			"continue":
				continue_requested.emit()
			"host":
				host_game_requested.emit()
			"join":
				join_online_requested.emit(join_code)
			"quit":
				quit_requested.emit()
	)
