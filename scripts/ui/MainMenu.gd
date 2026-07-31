extends Control
class_name MainMenuUI

## Styled main menu with animated starfield, tweened button effects,
## and a themed pixel-art farming adventure aesthetic.

signal new_game_requested(seed: int, game_mode: int)
signal continue_requested()
signal quit_requested()
signal host_game_requested(seed: int, game_mode: int)
signal join_game_requested(ip: String)
signal host_online_requested(seed: int, game_mode: int)
signal join_online_requested(join_code: String)

@onready var new_game_button: Button = $ContentCenter/ButtonContainer/NewGameButton
@onready var continue_button: Button = $ContentCenter/ButtonContainer/ContinueButton
@onready var quit_button: Button = $ContentCenter/ButtonContainer/QuitButton
@onready var name_input: LineEdit = $ContentCenter/ButtonContainer/NameBox/NameInput
@onready var seed_input: LineEdit = $ContentCenter/ButtonContainer/SeedBox/SeedInput
@onready var random_seed_button: Button = $ContentCenter/ButtonContainer/SeedBox/RandomSeedButton
@onready var peaceful_btn: Button = $ContentCenter/ButtonContainer/ModeBox/ModeButtons/PeacefulBtn
@onready var survival_btn: Button = $ContentCenter/ButtonContainer/ModeBox/ModeButtons/SurvivalBtn
@onready var creative_btn: Button = $ContentCenter/ButtonContainer/ModeBox/ModeButtons/CreativeBtn
@onready var hardcore_btn: Button = $ContentCenter/ButtonContainer/ModeBox/ModeButtons/HardcoreBtn
@onready var title_panel: PanelContainer = $TitlePanel
@onready var content_center: Control = $ContentCenter
@onready var star_field: Node2D = $StarField
@onready var host_game_button: Button = $ContentCenter/ButtonContainer/HostGameButton
@onready var join_game_button: Button = $ContentCenter/ButtonContainer/JoinGameButton
@onready var join_ip_box: HBoxContainer = $ContentCenter/ButtonContainer/JoinIPBox
@onready var join_ip_input: LineEdit = $ContentCenter/ButtonContainer/JoinIPBox/JoinIPInput
@onready var join_connect_button: Button = $ContentCenter/ButtonContainer/JoinIPBox/JoinConnectButton
@onready var title_vbox: VBoxContainer = $TitlePanel/TitleVBox

var _lan_button: Button = null
var _lan_list: ItemList = null
var _lan_list_refresh_timer: float = 0.0

var _online_button: Button = null
var _online_panel: VBoxContainer = null
var _online_code_label: Label = null
var _online_status_label: Label = null
var _online_join_code_input: LineEdit = null

# Star particle data
var _stars: Array[Dictionary] = []
var _star_count: int = 60
var _selected_mode: int = GameManager.GameMode.SURVIVAL

func _ready() -> void:
	# Show the game world behind the menu
	_setup_world_background()
	
	new_game_button.pressed.connect(_on_new_game_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	host_game_button.pressed.connect(_on_host_game_pressed)
	join_game_button.pressed.connect(_on_join_game_pressed)
	join_connect_button.pressed.connect(_on_join_connect_pressed)
	random_seed_button.pressed.connect(_on_random_seed_pressed)
	peaceful_btn.pressed.connect(_on_mode_button_pressed.bind(GameManager.GameMode.PEACEFUL))
	survival_btn.pressed.connect(_on_mode_button_pressed.bind(GameManager.GameMode.SURVIVAL))
	creative_btn.pressed.connect(_on_mode_button_pressed.bind(GameManager.GameMode.CREATIVE))
	hardcore_btn.pressed.connect(_on_mode_button_pressed.bind(GameManager.GameMode.HARDCORE))

	# Add LAN discovery button after Join Game
	_lan_button = Button.new()
	_lan_button.text = "LAN"
	_lan_button.custom_minimum_size = Vector2(120, 36)
	_lan_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var lan_parent := join_game_button.get_parent()
	var lan_idx := join_game_button.get_index() + 1
	lan_parent.add_child(_lan_button)
	lan_parent.move_child(_lan_button, lan_idx)
	_lan_button.pressed.connect(_on_lan_pressed)

	# Add Online button after LAN
	_online_button = Button.new()
	_online_button.text = "Online"
	_online_button.custom_minimum_size = Vector2(120, 36)
	_online_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var online_idx := _lan_button.get_index() + 1
	lan_parent.add_child(_online_button)
	lan_parent.move_child(_online_button, online_idx)
	_online_button.pressed.connect(_on_online_pressed)

	# Create online panel (hidden by default)
	_online_panel = VBoxContainer.new()
	_online_panel.name = "OnlinePanel"
	_online_panel.visible = false
	_online_panel.custom_minimum_size = Vector2(280, 0)
	_online_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	lan_parent.add_child(_online_panel)
	lan_parent.move_child(_online_panel, online_idx + 1)

	_build_online_panel()
	
	# Enable continue if any save exists
	var save_count: int = SaveManager.count_saves()
	continue_button.disabled = save_count == 0
	if save_count > 0:
		continue_button.text = "Continue (%d)" % save_count
	else:
		continue_button.text = "Continue"
	
	# Style the seed input
	seed_input.text = "0"
	
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
	_hide_lan_list()
	_hide_online_panel()
	join_ip_box.visible = false

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
	# Periodically refresh LAN server list
	if _lan_list and _lan_list.visible:
		_lan_list_refresh_timer += delta
		if _lan_list_refresh_timer >= 1.0:
			_lan_list_refresh_timer = 0.0
			_refresh_lan_list()

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
	var seed_value := seed_input.text.to_int()
	_fade_out_and_emit("new_game", seed_value)

func _on_random_seed_pressed() -> void:
	seed_input.text = str(randi())
	AudioManager.play(AudioManager.Sound.UI_CLICK)

func _on_mode_button_pressed(mode_id: int) -> void:
	_selected_mode = mode_id
	AudioManager.play(AudioManager.Sound.UI_CLICK)

func _get_selected_mode() -> int:
	return _selected_mode

func _on_host_game_pressed() -> void:
	print("MainMenu: Host Game clicked!")
	var p_name: String = name_input.text.strip_edges()
	if p_name.is_empty():
		p_name = "Farmer"
	GameManager.player_name = p_name
	GameManager.save_name = "My Island"
	AudioManager.play(AudioManager.Sound.UI_CLICK)
	join_ip_box.visible = false
	_fade_out_and_emit("host", seed_input.text.to_int(), "", _get_selected_mode())

func _on_join_game_pressed() -> void:
	print("MainMenu: Join Game clicked!")
	AudioManager.play(AudioManager.Sound.UI_CLICK)
	join_ip_box.visible = not join_ip_box.visible

func _on_join_connect_pressed() -> void:
	print("MainMenu: Join Connect clicked!")
	var ip: String = join_ip_input.text.strip_edges()
	if ip.is_empty():
		ip = "127.0.0.1"
	AudioManager.play(AudioManager.Sound.UI_CLICK)
	join_ip_box.visible = false
	_fade_out_and_emit("join", 0, ip)

func _on_lan_pressed() -> void:
	print("MainMenu: LAN pressed!")
	AudioManager.play(AudioManager.Sound.UI_CLICK)
	if _lan_list and _lan_list.visible:
		_hide_lan_list()
		return
	_show_lan_list()

func _show_lan_list() -> void:
	_ensure_lan_list()
	if not _lan_list:
		return
	_lan_list.clear()
	_lan_list.visible = true
	NetworkManager.start_lan_discovery()
	if not NetworkManager.lan_server_found.is_connected(_on_lan_server_found):
		NetworkManager.lan_server_found.connect(_on_lan_server_found)

func _hide_lan_list() -> void:
	if _lan_list:
		_lan_list.visible = false
	NetworkManager.stop_lan_discovery()

func _hide_online_panel() -> void:
	if _online_panel:
		_online_panel.visible = false
	_hide_online_status()

func _ensure_lan_list() -> void:
	if _lan_list and is_instance_valid(_lan_list):
		return
	_lan_list = ItemList.new()
	_lan_list.custom_minimum_size = Vector2(240, 160)
	_lan_list.visible = false
	_lan_list.add_theme_color_override("font_color", Color(1, 1, 1))
	_lan_list.add_theme_constant_override("v_separation", 4)
	content_center.add_child(_lan_list)
	_lan_list.item_selected.connect(_on_lan_item_selected)

func _on_lan_server_found(_srv_name: String, _ip: String, _port: int) -> void:
	_refresh_lan_list()

func _refresh_lan_list() -> void:
	if not _lan_list or not _lan_list.visible:
		return
	_lan_list.clear()
	var servers: Array[Dictionary] = NetworkManager.get_lan_servers()
	for srv in servers:
		var label: String = srv.get("name", "Unknown") + "  (" + srv.get("ip", "?") + ")"
		_lan_list.add_item(label)
	if servers.is_empty():
		_lan_list.add_item("(scanning...)")

func _on_lan_item_selected(idx: int) -> void:
	var servers: Array[Dictionary] = NetworkManager.get_lan_servers()
	if idx < 0 or idx >= servers.size():
		return
	var srv: Dictionary = servers[idx]
	_hide_lan_list()
	_fade_out_and_emit("join", 0, srv.get("ip", "127.0.0.1"))

func _build_online_panel() -> void:
	var title := Label.new()
	title.text = "Online Play"
	title.add_theme_font_size_override("font_size", 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_online_panel.add_child(title)

	var host_btn := Button.new()
	host_btn.text = "Host Online"
	host_btn.custom_minimum_size = Vector2(200, 32)
	host_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_online_panel.add_child(host_btn)
	host_btn.pressed.connect(_on_online_host_pressed)

	var join_hbox := HBoxContainer.new()
	join_hbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var code_label := Label.new()
	code_label.text = "Code:"
	code_label.custom_minimum_size = Vector2(45, 0)
	join_hbox.add_child(code_label)
	_online_join_code_input = LineEdit.new()
	_online_join_code_input.placeholder_text = "ABC123"
	_online_join_code_input.custom_minimum_size = Vector2(100, 0)
	join_hbox.add_child(_online_join_code_input)
	var join_btn := Button.new()
	join_btn.text = "Join"
	join_btn.pressed.connect(_on_online_join_pressed)
	join_hbox.add_child(join_btn)
	_online_panel.add_child(join_hbox)

	_online_code_label = Label.new()
	_online_code_label.text = ""
	_online_code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_online_code_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	_online_code_label.visible = false
	_online_panel.add_child(_online_code_label)

	_online_status_label = Label.new()
	_online_status_label.text = ""
	_online_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_online_status_label.visible = false
	_online_panel.add_child(_online_status_label)

func _on_online_pressed() -> void:
	AudioManager.play(AudioManager.Sound.UI_CLICK)
	if _lan_list and _lan_list.visible:
		_hide_lan_list()
	_online_panel.visible = not _online_panel.visible
	if not _online_panel.visible:
		_hide_online_status()
	_connect_ezcha_listeners()

func _connect_ezcha_listeners() -> void:
	if not NetworkManager.ezcha_lobby_created.is_connected(_on_ezcha_lobby_created):
		NetworkManager.ezcha_lobby_created.connect(_on_ezcha_lobby_created)
	if not NetworkManager.ezcha_lobby_error.is_connected(_on_ezcha_lobby_error):
		NetworkManager.ezcha_lobby_error.connect(_on_ezcha_lobby_error)
	if not NetworkManager.connection_failed.is_connected(_on_online_connect_failed):
		NetworkManager.connection_failed.connect(_on_online_connect_failed)

func _on_online_host_pressed() -> void:
	AudioManager.play(AudioManager.Sound.UI_CLICK)
	var p_name: String = name_input.text.strip_edges()
	if p_name.is_empty():
		p_name = "Farmer"
	GameManager.player_name = p_name
	GameManager.save_name = "My Island"
	_hide_online_status()
	_online_status_label.text = "Connecting to relay..."
	_online_status_label.visible = true
	host_online_requested.emit(seed_input.text.to_int(), _get_selected_mode())

func _on_online_join_pressed() -> void:
	AudioManager.play(AudioManager.Sound.UI_CLICK)
	var code: String = _online_join_code_input.text.strip_edges()
	if code.is_empty():
		return
	_hide_online_status()
	_online_status_label.text = "Joining lobby..."
	_online_status_label.visible = true
	join_online_requested.emit(code)

func _on_ezcha_lobby_created(join_code: String) -> void:
	_hide_online_status()
	_online_code_label.text = "Join code: " + join_code
	_online_code_label.visible = true
	# Bootstrap will handle connection_succeeded to show save select

func _on_ezcha_lobby_error(_code: int, _message: String) -> void:
	_online_status_label.text = "Connection failed"
	_online_status_label.visible = true

func _on_online_connect_failed() -> void:
	if not _online_panel.visible:
		return
	_online_status_label.text = "Connection failed"
	_online_status_label.visible = true

func _hide_online_status() -> void:
	_online_code_label.visible = false
	_online_status_label.visible = false

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
func _fade_out_and_emit(action: String, seed_val: int = 0, join_ip: String = "", game_mode: int = -1) -> void:
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
				new_game_requested.emit(seed_val, _get_selected_mode())
			"continue":
				continue_requested.emit()
			"host":
				host_game_requested.emit(seed_val, game_mode if game_mode >= 0 else _get_selected_mode())
			"join":
				join_game_requested.emit(join_ip)
			"quit":
				quit_requested.emit()
	)
