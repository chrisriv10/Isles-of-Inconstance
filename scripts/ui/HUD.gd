extends CanvasLayer

## Pure presentation layer. Listens to GameManager / player interactor
## signals and updates labels - contains no game logic of its own so new UI
## panels can be added without risk of coupling gameplay to display code.
## Extended for day/night cycle with smooth transitions, season display,
## and phase-based ambient overlay updates.

signal exit_to_menu_requested()

@onready var day_label: Label = %DayLabel
@onready var time_label: Label = %TimeLabel
@onready var money_label: Label = %MoneyLabel
@onready var interaction_prompt: Label = %InteractionPrompt/Label
@onready var interaction_prompt_panel: PanelContainer = %InteractionPrompt
@onready var seed_display_label: Label = %SeedDisplayLabel
@onready var join_code_label: Label = %JoinCodeLabel
@onready var menu_button: Button = %MenuButton
@onready var tool_label: Label = %ToolLabel
@onready var mutation_label: Label = %MutationLabel/Label
@onready var mutation_label_panel: PanelContainer = %MutationLabel
@onready var mutation_toast_timer: Timer = %MutationToastTimer
@onready var fade_overlay: ColorRect = %FadeOverlay
@onready var tutorial_hint: Label = %TutorialHint/Label
@onready var tutorial_hint_panel: PanelContainer = %TutorialHint
@onready var tutorial_hint_timer: Timer = %TutorialHintTimer
@onready var daynight_overlay: ColorRect = %DayNightOverlay
@onready var health_bar: ProgressBar = %HealthBar
@onready var hunger_bar: ProgressBar = %HungerBar
@onready var armor_bar: ProgressBar = %ArmorBar
@onready var objective_panel: PanelContainer = %ObjectiveLabel
@onready var objective_label_vbox: VBoxContainer = %ObjectiveLabel/VBox
@onready var objective_label: Label = %ObjectiveLabel/VBox/Label
@onready var objective_completed_label: Label = %ObjectiveLabel/VBox/CompletedLabel
@onready var objective_progress_bar: ProgressBar = null  # created at runtime
@onready var objective_progress_label: Label = null  # created at runtime
@onready var objective_desc_label: Label = null  # created at runtime
@onready var objective_toggle_button: Button = %ObjectiveToggleButton

## Whether the objective panel is collapsed to just the toggle button.
var _objective_minimized: bool = false
@onready var level_label: Label = %LevelLabel
@onready var xp_bar: ProgressBar = %XPBar
@onready var pet_indicator: Label = %PetIndicator
# CoordLabel removed (debug display no longer needed)

# Eat progress bar (created at runtime)
var _eat_bar: ProgressBar = null
var _eat_label: Label = null

# Mine hold interaction progress bar (created at runtime)
var _mine_bar: ProgressBar = null
var _mine_label: Label = null
var _showing_mine_prompt: bool = false  # whether we're showing a mine prompt at the bottom

# Rubble clearing progress bar (created at runtime)
var _rubble_bar: ProgressBar = null
var _rubble_label: Label = null

# Fishing reel progress bar (created at runtime)
var _fishing_bar: ProgressBar = null
var _fishing_label: Label = null
var _showing_fishing_prompt: bool = false

# Ore mining progress bar (created at runtime)
var _ore_mining_bar: ProgressBar = null
var _ore_mining_label: Label = null
var _showing_ore_mining: bool = false
var _active_ore_deposit: Node = null  # the ore deposit currently being mined

var _fade_tween: Tween
var _in_game_menu: InGameMenuUI = null

# Boss bar
var _boss_bar: PanelContainer = null
var _boss_name_label: Label = null
var _boss_hp_bar: ProgressBar = null
var _current_boss: Node = null

# Buff display
var _buff_container: VBoxContainer = null
var _buff_panels: Dictionary = {}  # buff_type -> PanelContainer
var _buff_update_timer: float = 0.0
var _buff_toggle_button: Button = null
var _buff_minimized: bool = false

# Bow charge progress bar
var _bow_charge_bar: ProgressBar = null
var _bow_charge_label: Label = null
var _showing_bow_charge: bool = false

# Player list (multiplayer roster)
var _player_list_panel: PanelContainer = null
var _player_list_vbox: VBoxContainer = null

# Chat (bottom-left)
var _chat_panel: PanelContainer = null
var _chat_text: RichTextLabel = null
var _chat_input: LineEdit = null
var _chat_scroll: ScrollContainer = null
var _chat_open: bool = false
var _chat_hidden: bool = false
var _chat_hide_button: Button = null

func _ready() -> void:
	add_to_group("HUD")
	GameManager.day_changed.connect(_on_day_changed)
	GameManager.time_changed.connect(_on_time_changed)
	GameManager.money_changed.connect(_on_money_changed)
	GameManager.crop_mutated.connect(_on_crop_mutated)
	GameManager.season_changed.connect(_on_season_changed)
	GameManager.phase_changed.connect(_on_phase_changed)
	GameManager.health_changed.connect(_on_health_changed)
	GameManager.hunger_changed.connect(_on_hunger_changed)
	GameManager.armor_changed.connect(_on_armor_changed)
	
	# Build enhanced objective widget (progress bar + progress label)
	_build_objective_widget()
	if objective_toggle_button:
		objective_toggle_button.pressed.connect(_toggle_objective_minimized)
	var obj_mgr := get_tree().get_first_node_in_group("objective_manager")
	if obj_mgr and obj_mgr.has_signal("objective_completed"):
		obj_mgr.objective_completed.connect(_on_objective_completed)
	if obj_mgr and obj_mgr.has_signal("objectives_updated"):
		obj_mgr.objectives_updated.connect(_on_objectives_updated)
	if mutation_toast_timer:
		mutation_toast_timer.timeout.connect(_on_mutation_toast_timeout)
	
	# Create boss bar
	_create_boss_bar()
	# Poll for boss tracking every 0.5s
	var boss_timer := Timer.new()
	boss_timer.name = "BossScanTimer"
	boss_timer.wait_time = 0.5
	boss_timer.timeout.connect(_scan_for_boss)
	add_child(boss_timer)
	boss_timer.start()

	# Mine proximity prompt timer — poll every 0.3s to show/hide [E] prompt at bottom
	var mine_prompt_timer := Timer.new()
	mine_prompt_timer.name = "MinePromptTimer"
	mine_prompt_timer.wait_time = 0.3
	mine_prompt_timer.timeout.connect(_check_mine_proximity_prompt)
	add_child(mine_prompt_timer)
	mine_prompt_timer.start()

	# Fishing prompt timer — poll every 0.2s to show/hide [E] reel prompt + progress at bottom
	var fishing_prompt_timer := Timer.new()
	fishing_prompt_timer.name = "FishingPromptTimer"
	fishing_prompt_timer.wait_time = 0.2
	fishing_prompt_timer.timeout.connect(_check_fishing_prompt)
	add_child(fishing_prompt_timer)
	fishing_prompt_timer.start()

	# Add numeric text overlays to health/hunger/armor bars
	_add_bar_numeric_label(health_bar, "health")
	_add_bar_numeric_label(hunger_bar, "hunger")
	_add_bar_numeric_label(armor_bar, "armor")

	# Show initial objective after delay
	get_tree().create_timer(3.0).timeout.connect(_update_objective_display)

	_on_day_changed(GameManager.current_day)
	_on_time_changed(GameManager.get_hour(), GameManager.get_minute())
	_on_money_changed(GameManager.money)
	_update_weather_display()
	if GameManager.weather_system:
		GameManager.weather_system.weather_changed.connect(_update_weather_display)

	# Initialize armor bar from current state
	_on_armor_changed(GameManager.get_armor_defense())
	
	# HUD panel visibility
	if interaction_prompt_panel:
		interaction_prompt_panel.visible = false
	
	# Initialize fade overlay
	if fade_overlay:
		fade_overlay.color = Color.BLACK
		fade_overlay.visible = false
	
	# Initialize tutorial hints
	if tutorial_hint:
		tutorial_hint.visible = false
	if tutorial_hint_panel:
		tutorial_hint_panel.visible = false
	if tutorial_hint_timer:
		tutorial_hint_timer.timeout.connect(_on_tutorial_hint_timeout)
		tutorial_hint_timer.one_shot = true
	
	# Onboarding hints are scheduled once the game mode is actually chosen.
	# HUD._ready runs at boot (before save select), so is_creative() is always
	# false here; game_mode_changed fires on new game / load / host / join.
	if not GameManager.game_mode_changed.is_connected(_on_onboarding_mode_changed):
		GameManager.game_mode_changed.connect(_on_onboarding_mode_changed)

	# Level & XP display
	if not LevelManager.xp_changed.is_connected(_on_xp_changed):
		LevelManager.xp_changed.connect(_on_xp_changed)
	if not LevelManager.level_up.is_connected(_on_player_leveled):
		LevelManager.level_up.connect(_on_player_leveled)
	_on_xp_changed(LevelManager.get_xp(), LevelManager.get_xp_for_next_level())
	if level_label:
		level_label.text = "Lv. %d" % LevelManager.get_level()
	
	# Town level badge
	_setup_town_badge()

	# Pet indicator
	if PetManager.active_pet_changed.is_connected(_on_pet_changed):
		PetManager.active_pet_changed.disconnect(_on_pet_changed)
	PetManager.active_pet_changed.connect(_on_pet_changed)
	_update_pet_indicator()

	# Creative mode indicator
	_setup_creative_indicator()
	GameManager.game_mode_changed.connect(_on_game_mode_changed)

	# In-game menu (Tutorial / Controls / Settings / Return to Menu)
	_in_game_menu = load("res://scenes/ui/InGameMenu.tscn").instantiate()
	_in_game_menu.exit_to_menu_requested.connect(_on_menu_confirmed)
	add_child(_in_game_menu)

	if menu_button:
		menu_button.pressed.connect(_on_menu_pressed)
	
	# Ensure the toast notification is discoverable via the "toasts" group
	# (scene-file group assignment is unreliable for CanvasLayer children)
	var toast_node := $ToastNotification
	if toast_node:
		toast_node.add_to_group("toasts")
	
	# Player list (multiplayer roster) — hidden until a session is active
	_setup_player_list()
	
	# Chat panel (bottom-left)
	_setup_chat()
	
	# Create pirate raid alert label (hidden by default)
	_setup_raid_alert()
	
	# Create blood moon alert label (hidden by default)
	_setup_blood_moon_alert()

	# Create buff display container at top-left, below all top bars
	_buff_container = VBoxContainer.new()
	_buff_container.name = "BuffDisplay"
	_buff_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_buff_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_buff_container.add_theme_constant_override("separation", 4)
	$Root.add_child(_buff_container)

	# Small toggle button to minimize/expand the buff bars
	_buff_toggle_button = Button.new()
	_buff_toggle_button.name = "BuffToggleButton"
	_buff_toggle_button.text = "−"
	_buff_toggle_button.tooltip_text = "Minimize buff bars"
	_buff_toggle_button.focus_mode = Control.FOCUS_NONE
	_buff_toggle_button.visible = false
	_buff_toggle_button.custom_minimum_size = Vector2(22, 20)
	_buff_toggle_button.add_theme_font_size_override("font_size", 12)
	_buff_toggle_button.add_theme_color_override("font_color", Color(0.8, 0.95, 0.7, 0.9))
	_buff_toggle_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var buff_btn_style := StyleBoxFlat.new()
	buff_btn_style.bg_color = Color(0.1, 0.12, 0.1, 0.85)
	buff_btn_style.border_color = Color(0.5, 0.7, 0.4, 0.9)
	buff_btn_style.set_border_width_all(1)
	buff_btn_style.set_corner_radius_all(4)
	var buff_btn_pressed := buff_btn_style.duplicate()
	buff_btn_pressed.bg_color = Color(0.25, 0.3, 0.2, 0.9)
	_buff_toggle_button.add_theme_stylebox_override("normal", buff_btn_style)
	_buff_toggle_button.add_theme_stylebox_override("hover", buff_btn_style)
	_buff_toggle_button.add_theme_stylebox_override("pressed", buff_btn_pressed)
	$Root.add_child(_buff_toggle_button)
	_buff_toggle_button.pressed.connect(_toggle_buff_minimized)
	_refresh_buff_position()
	
	# Listen for buff changes
	if BuffManager and BuffManager.has_signal("buffs_updated"):
		if not BuffManager.buffs_updated.is_connected(_on_buffs_changed):
			BuffManager.buffs_updated.connect(_on_buffs_changed)

	
# Setup eat progress bar (needs $Root)
	_setup_eat_bar()

	# Setup mine hold interaction progress bar
	_setup_mine_bar()

	# Setup rubble clearing progress bar
	_setup_rubble_bar()

	# Setup fishing reel progress bar
	_setup_fishing_bar()

	# Setup ore mining progress bar (pickaxe mining of deposits)
	_setup_ore_mining_bar()

	# Setup bow charge progress bar
	_setup_bow_charge_bar()

	# Ore mining polling timer — check every frame for active mining
	var ore_timer := Timer.new()
	ore_timer.name = "OreMiningTimer"
	ore_timer.wait_time = 0.05  # 20 fps check for smooth bar updates
	ore_timer.timeout.connect(_check_ore_mining_progress)
	add_child(ore_timer)
	ore_timer.start()

	# Bow charge polling timer — check every frame for smooth charge bar
	var bow_charge_timer := Timer.new()
	bow_charge_timer.name = "BowChargeTimer"
	bow_charge_timer.wait_time = 0.05
	bow_charge_timer.timeout.connect(_check_bow_charge_progress)
	add_child(bow_charge_timer)
	bow_charge_timer.start()

	# Listen for root resize
	$Root.resized.connect(_on_root_resized)

	var player := get_tree().get_first_node_in_group("player")
	if player:
		if player.has_signal("active_tool_changed"):
			player.active_tool_changed.connect(_on_active_tool_changed)
		
		var interactor: Area2D = player.get_node_or_null("Interactor")
		if interactor:
			interactor.interactable_in_range.connect(_on_interactable_in_range)
			interactor.interactable_out_of_range.connect(_on_interactable_out_of_range)
		
		# Connect eating signals
		if player.has_signal("eating_started"):
			player.eating_started.connect(_on_eating_started)
			player.eating_progress.connect(_on_eating_progress)
			player.eating_completed.connect(_on_eating_completed)
			player.eating_cancelled.connect(_on_eating_cancelled)
		
		# Connect mine hold interaction signals
		if player.has_signal("mine_interact_started"):
			player.mine_interact_started.connect(_on_mine_interact_started)
			player.mine_interact_progress.connect(_on_mine_interact_progress)
			player.mine_interact_completed.connect(_on_mine_interact_completed)
			player.mine_interact_cancelled.connect(_on_mine_interact_cancelled)

		# Connect rubble clearing signals
		if player.has_signal("rubble_clear_started"):
			player.rubble_clear_started.connect(_on_rubble_clear_started)
			player.rubble_clear_progress.connect(_on_rubble_clear_progress)
			player.rubble_clear_completed.connect(_on_rubble_clear_completed)
			player.rubble_clear_cancelled.connect(_on_rubble_clear_cancelled)

# Biome info label removed (debug display no longer needed)

func _on_root_resized() -> void:
	_refresh_raid_alert_position()
	_refresh_blood_moon_alert_position()
	_refresh_creative_label_position()
	_refresh_eat_bar_position()
	_refresh_mine_bar_position()
	_refresh_rubble_bar_position()
	_refresh_fishing_bar_position()
	_refresh_ore_mining_bar_position()
	_refresh_buff_position()


# ---------------------------------------------------------------------------
# Eat progress bar (hold E to eat, Minecraft-style)
# ---------------------------------------------------------------------------
func _setup_eat_bar() -> void:
	_eat_bar = ProgressBar.new()
	_eat_bar.name = "EatProgressBar"
	_eat_bar.size = Vector2(120, 10)
	_eat_bar.visible = false
	_eat_bar.max_value = 1.0
	_eat_bar.value = 0.0
	_eat_bar.show_percentage = false
	
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	bg_style.set_corner_radius_all(3)
	_eat_bar.add_theme_stylebox_override("background", bg_style)
	
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.8, 0.6, 0.2, 0.9)
	fill_style.set_corner_radius_all(3)
	_eat_bar.add_theme_stylebox_override("fill", fill_style)
	$Root.add_child(_eat_bar)
	
	_eat_label = Label.new()
	_eat_label.name = "EatLabel"
	_eat_label.visible = false
	_eat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_eat_label.size = Vector2(160, 18)
	_eat_label.add_theme_font_size_override("font_size", 12)
	_eat_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.95))
	_eat_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_eat_label.add_theme_constant_override("shadow_offset_x", 1)
	_eat_label.add_theme_constant_override("shadow_offset_y", 1)
	$Root.add_child(_eat_label)
	
	_refresh_eat_bar_position()


func _refresh_eat_bar_position() -> void:
	if not _eat_bar or not _eat_label:
		return
	var root_size: Vector2 = $Root.get_rect().size
	var bar_x: float = root_size.x / 2.0 - _eat_bar.size.x / 2.0
	var bar_y: float = root_size.y - 180.0  # just above the hotbar area
	_eat_bar.position = Vector2(bar_x, bar_y)
	_eat_label.position = Vector2(root_size.x / 2.0 - 80.0, bar_y - 20.0)


func _on_eating_started(item_name: String) -> void:
	_eat_bar.value = 0.0
	_eat_bar.visible = true
	_eat_label.text = "Eating %s..." % item_name
	_eat_label.visible = true
	_refresh_eat_bar_position()


func _on_eating_progress(progress: float) -> void:
	if _eat_bar:
		_eat_bar.value = progress


func _on_eating_completed(_item_name: String) -> void:
	_eat_bar.visible = false
	_eat_label.visible = false
	_eat_bar.value = 0.0


func _on_eating_cancelled() -> void:
	_eat_bar.visible = false
	_eat_label.visible = false
	_eat_bar.value = 0.0


# ---------------------------------------------------------------------------
# Mine hold interaction progress bar (hold E near entrance/exit/descent)
# ---------------------------------------------------------------------------

func _setup_mine_bar() -> void:
	_mine_bar = ProgressBar.new()
	_mine_bar.name = "MineHoldProgressBar"
	_mine_bar.size = Vector2(140, 12)
	_mine_bar.visible = false
	_mine_bar.max_value = 1.0
	_mine_bar.value = 0.0
	_mine_bar.show_percentage = false
	
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	bg_style.set_corner_radius_all(3)
	_mine_bar.add_theme_stylebox_override("background", bg_style)
	
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.3, 0.5, 0.9, 0.9)  # blue-ish tint (different from eat bar's orange)
	fill_style.set_corner_radius_all(3)
	_mine_bar.add_theme_stylebox_override("fill", fill_style)
	$Root.add_child(_mine_bar)
	
	_mine_label = Label.new()
	_mine_label.name = "MineHoldLabel"
	_mine_label.visible = false
	_mine_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mine_label.size = Vector2(180, 18)
	_mine_label.add_theme_font_size_override("font_size", 12)
	_mine_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.95))
	_mine_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_mine_label.add_theme_constant_override("shadow_offset_x", 1)
	_mine_label.add_theme_constant_override("shadow_offset_y", 1)
	$Root.add_child(_mine_label)
	
	_refresh_mine_bar_position()


func _refresh_mine_bar_position() -> void:
	if not _mine_bar or not _mine_label:
		return
	var root_size: Vector2 = $Root.get_rect().size
	var bar_x: float = root_size.x / 2.0 - _mine_bar.size.x / 2.0
	var bar_y: float = root_size.y - 170.0  # just above the hotbar, slightly above eat bar area
	_mine_bar.position = Vector2(bar_x, bar_y)
	_mine_label.position = Vector2(root_size.x / 2.0 - 90.0, bar_y - 20.0)


func _on_mine_interact_started(prompt_text: String) -> void:
	_mine_bar.value = 0.0
	_mine_bar.visible = true
	_mine_label.text = prompt_text
	_mine_label.visible = true
	_refresh_mine_bar_position()


func _on_mine_interact_progress(progress: float) -> void:
	if _mine_bar:
		_mine_bar.value = progress


func _on_mine_interact_completed() -> void:
	_mine_bar.visible = false
	_mine_label.visible = false
	_rubble_bar.value = 0.0

func _on_mine_interact_cancelled() -> void:
	_mine_bar.visible = false
	_mine_label.visible = false
	_rubble_bar.value = 0.0


## Periodically checks if the player is near a mine interactable
## (entrance/exit/descent) and shows/hides the bottom [E] prompt.
## Uses the existing interaction_prompt panel but only when no
## Interactable object is in range (Interactables take priority).
func _check_mine_proximity_prompt() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if not player:
		if _showing_mine_prompt:
			_showing_mine_prompt = false
			if not _last_interactable:
				interaction_prompt_panel.visible = false
		return
	
	# Only show mine prompt if no Interactable is currently in range
	if _last_interactable and is_instance_valid(_last_interactable):
		if _showing_mine_prompt:
			_showing_mine_prompt = false
		return
	
	if player.has_method("can_mine_interact") and player.can_mine_interact():
		if not _showing_mine_prompt:
			_showing_mine_prompt = true
			var prompt_text: String = ""
			if player.has_method("get_mine_interact_prompt"):
				prompt_text = player.get_mine_interact_prompt()
			if prompt_text != "":
				interaction_prompt.text = "[E] %s" % prompt_text
				interaction_prompt_panel.visible = true
	else:
		if _showing_mine_prompt:
			_showing_mine_prompt = false
			interaction_prompt_panel.visible = false


func _setup_rubble_bar() -> void:
	_rubble_bar = ProgressBar.new()
	_rubble_bar.name = "RubbleClearProgressBar"
	_rubble_bar.size = Vector2(160, 14)
	_rubble_bar.visible = false
	_rubble_bar.max_value = 1.0
	_rubble_bar.value = 0.0
	_rubble_bar.show_percentage = false

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.1, 0.1, 0.85)
	bg_style.set_corner_radius_all(4)
	_rubble_bar.add_theme_stylebox_override("background", bg_style)

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.7, 0.45, 0.2, 0.9)  # warm brown/orange for rubble
	fill_style.set_corner_radius_all(4)
	_rubble_bar.add_theme_stylebox_override("fill", fill_style)
	$Root.add_child(_rubble_bar)

	_rubble_label = Label.new()
	_rubble_label.name = "RubbleClearLabel"
	_rubble_label.text = "Clearing rubble..."
	_rubble_label.visible = false
	_rubble_label.add_theme_font_size_override("font_size", 12)
	_rubble_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.95))
	_rubble_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_rubble_label.add_theme_constant_override("shadow_offset_x", 1)
	_rubble_label.add_theme_constant_override("shadow_offset_y", 1)
	$Root.add_child(_rubble_label)

	_refresh_rubble_bar_position()


func _refresh_rubble_bar_position() -> void:
	if not _rubble_bar or not _rubble_label:
		return
	var root_size: Vector2 = $Root.get_rect().size
	var bar_x: float = root_size.x / 2.0 - _rubble_bar.size.x / 2.0
	var bar_y: float = root_size.y - 195.0  # above the mine bar area
	_rubble_bar.position = Vector2(bar_x, bar_y)
	_rubble_label.position = Vector2(root_size.x / 2.0 - 100.0, bar_y - 22.0)


func _on_rubble_clear_started(prompt_text: String) -> void:
	_rubble_bar.value = 0.0
	_rubble_bar.visible = true
	_rubble_label.text = prompt_text
	_rubble_label.visible = true
	_refresh_rubble_bar_position()


func _on_rubble_clear_progress(progress: float) -> void:
	if _rubble_bar:
		_rubble_bar.value = progress


func _on_rubble_clear_completed() -> void:
	_rubble_bar.visible = false
	_rubble_label.visible = false
	_rubble_bar.value = 0.0


func _on_rubble_clear_cancelled() -> void:
	_rubble_bar.visible = false
	_rubble_label.visible = false
	_rubble_bar.value = 0.0


# ---------------------------------------------------------------------------
# Fishing reel progress bar — shows "Press [E] to reel!" + progress at bottom
# ---------------------------------------------------------------------------

func _setup_fishing_bar() -> void:
	_fishing_bar = ProgressBar.new()
	_fishing_bar.name = "FishingReelProgressBar"
	_fishing_bar.size = Vector2(180, 14)
	_fishing_bar.visible = false
	_fishing_bar.max_value = 1.0
	_fishing_bar.value = 0.0
	_fishing_bar.show_percentage = false

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.1, 0.1, 0.85)
	bg_style.set_corner_radius_all(4)
	_fishing_bar.add_theme_stylebox_override("background", bg_style)

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.2, 0.7, 0.9, 0.9)  # ocean blue for fishing
	fill_style.set_corner_radius_all(4)
	_fishing_bar.add_theme_stylebox_override("fill", fill_style)
	$Root.add_child(_fishing_bar)

	_fishing_label = Label.new()
	_fishing_label.name = "FishingReelLabel"
	_fishing_label.text = "Press [E] to reel!"
	_fishing_label.visible = false
	_fishing_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fishing_label.size = Vector2(220, 18)
	_fishing_label.add_theme_font_size_override("font_size", 12)
	_fishing_label.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0, 0.95))
	_fishing_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_fishing_label.add_theme_constant_override("shadow_offset_x", 1)
	_fishing_label.add_theme_constant_override("shadow_offset_y", 1)
	$Root.add_child(_fishing_label)

	_refresh_fishing_bar_position()


func _refresh_fishing_bar_position() -> void:
	if not _fishing_bar or not _fishing_label:
		return
	var root_size: Vector2 = $Root.get_rect().size
	var bar_x: float = root_size.x / 2.0 - _fishing_bar.size.x / 2.0
	var bar_y: float = root_size.y - 160.0  # near bottom, above the hotbar
	_fishing_bar.position = Vector2(bar_x, bar_y)
	_fishing_label.position = Vector2(root_size.x / 2.0 - 110.0, bar_y - 22.0)


func _check_fishing_prompt() -> void:
	if not GameManager.weather_system:
		return
	var fishing_system: FishingSystem = GameManager.weather_system.get_node_or_null("FishingSystem")
	if not fishing_system:
		if _showing_fishing_prompt:
			_showing_fishing_prompt = false
			_fishing_bar.visible = false
			_fishing_label.visible = false
		return

	if fishing_system.state == FishingSystem.FishingState.REELING:
		var progress: float = fishing_system._reel_progress / fishing_system._reel_target
		_fishing_bar.value = progress
		if not _showing_fishing_prompt:
			_showing_fishing_prompt = true
			_refresh_fishing_bar_position()
		_fishing_bar.visible = true
		var pct: int = int(progress * 100)
		_fishing_label.text = "Press [E] to reel! (%d%%)" % pct
		_fishing_label.visible = true
	else:
		if _showing_fishing_prompt:
			_showing_fishing_prompt = false
			_fishing_bar.visible = false
			_fishing_label.visible = false


# ---------------------------------------------------------------------------
# Ore mining progress bar — shows when pickaxe-mining an ore deposit
# ---------------------------------------------------------------------------

func _setup_ore_mining_bar() -> void:
	_ore_mining_bar = ProgressBar.new()
	_ore_mining_bar.name = "OreMiningProgressBar"
	_ore_mining_bar.size = Vector2(140, 10)
	_ore_mining_bar.visible = false
	_ore_mining_bar.max_value = 1.0
	_ore_mining_bar.value = 0.0
	_ore_mining_bar.show_percentage = false

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	bg_style.set_corner_radius_all(3)
	_ore_mining_bar.add_theme_stylebox_override("background", bg_style)

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.6, 0.6, 0.7, 0.9)  # stone/grey for mining
	fill_style.set_corner_radius_all(3)
	_ore_mining_bar.add_theme_stylebox_override("fill", fill_style)
	$Root.add_child(_ore_mining_bar)

	_ore_mining_label = Label.new()
	_ore_mining_label.name = "OreMiningLabel"
	_ore_mining_label.visible = false
	_ore_mining_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ore_mining_label.size = Vector2(180, 18)
	_ore_mining_label.add_theme_font_size_override("font_size", 12)
	_ore_mining_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9, 0.95))
	_ore_mining_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_ore_mining_label.add_theme_constant_override("shadow_offset_x", 1)
	_ore_mining_label.add_theme_constant_override("shadow_offset_y", 1)
	$Root.add_child(_ore_mining_label)

	_refresh_ore_mining_bar_position()


func _refresh_ore_mining_bar_position() -> void:
	if not _ore_mining_bar or not _ore_mining_label:
		return
	var root_size: Vector2 = $Root.get_rect().size
	var bar_x: float = root_size.x / 2.0 - _ore_mining_bar.size.x / 2.0
	var bar_y: float = root_size.y - 146.0  # just above the fishing bar area
	_ore_mining_bar.position = Vector2(bar_x, bar_y)
	_ore_mining_label.position = Vector2(root_size.x / 2.0 - 90.0, bar_y - 20.0)


## Polls for an active ore deposit mining session and updates the progress bar.
func _check_ore_mining_progress() -> void:
	var deposits: Array[Node] = get_tree().get_nodes_in_group("ore_deposits")
	var active: Node = null

	for d in deposits:
		if not is_instance_valid(d):
			continue
		if d.get("_is_mining") == true:
			active = d
			break

	if active and is_instance_valid(active):
		var progress: float = active._mining_progress if "_mining_progress" in active else 0.0
		var gather_time: float = active._gather_time if "_gather_time" in active else 1.5
		var ore_type_val: String = active.ore_type if "ore_type" in active else "ore"
		var ratio: float = minf(progress / gather_time, 1.0)

		_ore_mining_bar.value = ratio
		if not _showing_ore_mining:
			_showing_ore_mining = true
			_active_ore_deposit = active
			_ore_mining_label.text = "Mining %s..." % ore_type_val.replace("_", " ")
			_refresh_ore_mining_bar_position()

		_ore_mining_bar.visible = true
		_ore_mining_label.visible = true
	else:
		if _showing_ore_mining:
			_showing_ore_mining = false
			_active_ore_deposit = null
			_ore_mining_bar.visible = false
			_ore_mining_label.visible = false
			_ore_mining_bar.value = 0.0


# ---------------------------------------------------------------------------
# Bow charge progress bar — shows while holding LMB with a bow equipped
# ---------------------------------------------------------------------------

func _setup_bow_charge_bar() -> void:
	_bow_charge_bar = ProgressBar.new()
	_bow_charge_bar.name = "BowChargeProgressBar"
	_bow_charge_bar.size = Vector2(140, 10)
	_bow_charge_bar.visible = false
	_bow_charge_bar.max_value = 1.0
	_bow_charge_bar.value = 0.0
	_bow_charge_bar.show_percentage = false

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	bg_style.set_corner_radius_all(3)
	_bow_charge_bar.add_theme_stylebox_override("background", bg_style)

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.5, 0.8, 1.0, 0.9)  # cyan/blue for bow charge
	fill_style.set_corner_radius_all(3)
	_bow_charge_bar.add_theme_stylebox_override("fill", fill_style)
	$Root.add_child(_bow_charge_bar)

	_bow_charge_label = Label.new()
	_bow_charge_label.name = "BowChargeLabel"
	_bow_charge_label.visible = false
	_bow_charge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bow_charge_label.size = Vector2(180, 18)
	_bow_charge_label.add_theme_font_size_override("font_size", 12)
	_bow_charge_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0, 0.95))
	_bow_charge_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_bow_charge_label.add_theme_constant_override("shadow_offset_x", 1)
	_bow_charge_label.add_theme_constant_override("shadow_offset_y", 1)
	$Root.add_child(_bow_charge_label)

	_refresh_bow_charge_bar_position()


func _refresh_bow_charge_bar_position() -> void:
	if not _bow_charge_bar or not _bow_charge_label:
		return
	var root_size: Vector2 = $Root.get_rect().size
	var bar_x: float = root_size.x / 2.0 - _bow_charge_bar.size.x / 2.0
	var bar_y: float = root_size.y - 160.0  # just above the ore mining bar
	_bow_charge_bar.position = Vector2(bar_x, bar_y)
	_bow_charge_label.position = Vector2(root_size.x / 2.0 - 90.0, bar_y - 20.0)


## Polls for bow charging and updates the progress bar.
func _check_bow_charge_progress() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return
	var charging: bool = player._bow_charging if "_bow_charging" in player else false
	if charging:
		var start_time: float = player._bow_charge_start if "_bow_charge_start" in player else 0.0
		var max_time: float = player.BOW_CHARGE_MAX_TIME if "BOW_CHARGE_MAX_TIME" in player else 1.0
		var held_time: float = Time.get_unix_time_from_system() - start_time
		var ratio: float = clampf(held_time / max_time, 0.0, 1.0)

		_bow_charge_bar.value = ratio
		if not _showing_bow_charge:
			_showing_bow_charge = true
			_bow_charge_label.text = "Charging Shot..."
			_refresh_bow_charge_bar_position()

		_bow_charge_bar.visible = true
		_bow_charge_label.visible = true
	else:
		if _showing_bow_charge:
			_showing_bow_charge = false
			_bow_charge_bar.visible = false
			_bow_charge_label.visible = false
			_bow_charge_bar.value = 0.0


# --- Game mode indicator ---
var _creative_label: Label = null

func _setup_creative_indicator() -> void:
	_creative_label = Label.new()
	_creative_label.name = "CreativeModeLabel"
	_creative_label.add_theme_font_size_override("font_size", 16)
	_creative_label.add_theme_color_override("font_outline_color", Color(0.3, 0.2, 0.0))
	_creative_label.add_theme_constant_override("outline_size", 2)
	_creative_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	$Root.add_child(_creative_label)
	_refresh_creative_label_position()
	
	# Update display based on current game mode
	_on_game_mode_changed(GameManager.game_mode)


func _refresh_creative_label_position() -> void:
	if _creative_label:
		var root_size: Vector2 = $Root.get_rect().size
		# Position at top-right side of the TopBar area (12px margin from right edge)
		_creative_label.position = Vector2(root_size.x - 160.0, 16.0)

# --- Pirate Raid Alert ---
var _raid_alert: Label = null

func _setup_raid_alert() -> void:
	_raid_alert = Label.new()
	_raid_alert.name = "RaidAlertLabel"
	_raid_alert.text = "🏴‍☠️ RAID IN PROGRESS! Defeat the pirates!"
	_raid_alert.add_theme_font_size_override("font_size", 18)
	_raid_alert.add_theme_color_override("font_color", Color(1.0, 0.2, 0.1))
	_raid_alert.add_theme_color_override("font_outline_color", Color(0.3, 0.0, 0.0))
	_raid_alert.add_theme_constant_override("outline_size", 2)
	_raid_alert.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_raid_alert.visible = false
	$Root.add_child(_raid_alert)
	_refresh_raid_alert_position()
	
	# Connect to pirate raid signals
	var world: Node = get_tree().get_first_node_in_group("world")
	if world and "pirate_raid" in world:
		var raid = world.pirate_raid
		if raid and raid.has_signal("raid_started"):
			raid.raid_started.connect(_on_raid_started)
		if raid and raid.has_signal("raid_wave_spawned"):
			raid.raid_wave_spawned.connect(_on_raid_wave_spawned)
		if raid and raid.has_signal("raid_ended"):
			raid.raid_ended.connect(_on_raid_ended)


# --- Town Badge ---
var _town_badge: Label = null

func _setup_town_badge() -> void:
	_town_badge = Label.new()
	_town_badge.name = "TownBadge"
	_town_badge.text = ""
	_town_badge.add_theme_font_size_override("font_size", 10)
	_town_badge.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
	_town_badge.add_theme_constant_override("outline_size", 1)
	_town_badge.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.6))
	_town_badge.visible = false
	$Root.add_child(_town_badge)
	_refresh_town_badge_position()
	
	# Connect to town manager signals
	var tm := get_tree().get_first_node_in_group("town_manager")
	if tm and tm.has_signal("town_level_changed"):
		tm.town_level_changed.connect(_on_town_level_changed)
	if tm and tm.has_signal("all_ruins_restored"):
		tm.all_ruins_restored.connect(_on_all_ruins_restored)
	# Initial update
	_update_town_badge()

func _refresh_town_badge_position() -> void:
	if _town_badge:
		var root_size: Vector2 = $Root.get_rect().size
		_town_badge.position = Vector2(root_size.x - 160.0, 120.0)

func _update_town_badge() -> void:
	var tm := get_tree().get_first_node_in_group("town_manager")
	if not tm:
		_town_badge.visible = false
		return
	
	# Override: show "Restored" when town is fully restored
	if "town_fully_restored" in tm and tm.town_fully_restored:
		_town_badge.text = "🌟 Town: Restored"
		_town_badge.visible = true
		return
	
	var level_names: Dictionary = {
		0: "",
		1: "🌅 Town: Clearing",
		2: "🌿 Town: Settlement",
		3: "🏘️ Town: Village",
		4: "🏙️ Town: Town",
		5: "🌟 Town: Thriving",
	}
	var level: int = 0
	if "town_level" in tm:
		level = tm.town_level
	if level > 0:
		_town_badge.text = level_names.get(level, "")
		_town_badge.visible = true
	else:
		_town_badge.visible = false

func _on_town_level_changed(_level: int) -> void:
	_update_town_badge()

## Called when all ruins are restored — show a toast directing player to TownUI.
func _on_all_ruins_restored() -> void:
	ToastNotification.show_toast(
		"🏛️ Town fully restored! Press [N] for daily tribute.",
		ToastNotification.ToastType.SUCCESS,
		6.0
	)

func _refresh_raid_alert_position() -> void:
	if _raid_alert:
		var root_size: Vector2 = $Root.get_rect().size
		# Position at top-center. The objective panel occupies y=132..178 when
		# expanded, so the alerts sit below it; when it's minimized they move up.
		var raid_y: float = 190.0 if _objective_minimized else 236.0
		_raid_alert.position = Vector2(root_size.x / 2.0 - 200.0, raid_y)


func _on_raid_wave_spawned(wave: int, total_waves: int) -> void:
	if _raid_alert:
		_raid_alert.text = "🏴‍☠️ RAID IN PROGRESS — Wave %d/%d" % [wave, total_waves]


func _on_raid_started(_wave_count: int) -> void:
	if _raid_alert:
		_raid_alert.text = "🏴‍☠️ RAID IN PROGRESS! Defeat the pirates!"
		_raid_alert.visible = true
		# Add pulsing effect
		var tween := _raid_alert.create_tween()
		tween.set_loops()
		tween.tween_property(_raid_alert, "modulate:a", 0.4, 0.5)
		tween.tween_property(_raid_alert, "modulate:a", 1.0, 0.5)


func _on_raid_ended(_victory: bool) -> void:
	if _raid_alert:
		_raid_alert.visible = false
		_raid_alert.modulate = Color.WHITE  # reset alpha


# --- Blood Moon Alert ---
var _blood_moon_alert: Label = null

func _setup_blood_moon_alert() -> void:
	_blood_moon_alert = Label.new()
	_blood_moon_alert.name = "BloodMoonAlertLabel"
	_blood_moon_alert.text = "🌕 BLOOD MOON ACTIVE! Seek shelter!"
	_blood_moon_alert.add_theme_font_size_override("font_size", 18)
	_blood_moon_alert.add_theme_color_override("font_color", Color(1.0, 0.15, 0.05))
	_blood_moon_alert.add_theme_color_override("font_outline_color", Color(0.4, 0.0, 0.0))
	_blood_moon_alert.add_theme_constant_override("outline_size", 2)
	_blood_moon_alert.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_blood_moon_alert.visible = false
	$Root.add_child(_blood_moon_alert)
	_refresh_blood_moon_alert_position()
	
	# Connect to blood moon event signals
	var world: Node = get_tree().get_first_node_in_group("world")
	if world and "blood_moon_event" in world:
		var bm = world.blood_moon_event
		if bm and bm.has_signal("blood_moon_started"):
			bm.blood_moon_started.connect(_on_blood_moon_started)
		if bm and bm.has_signal("blood_moon_ended"):
			bm.blood_moon_ended.connect(_on_blood_moon_ended)


func _refresh_blood_moon_alert_position() -> void:
	if _blood_moon_alert:
		var root_size: Vector2 = $Root.get_rect().size
		# Position at top-center, above the raid alert but still below the
		# objective panel (y=132..178 expanded); moves up when minimized.
		var bm_y: float = 144.0 if _objective_minimized else 190.0
		_blood_moon_alert.position = Vector2(root_size.x / 2.0 - 200.0, bm_y)


func _on_blood_moon_started() -> void:
	if _blood_moon_alert:
		_blood_moon_alert.text = "🌕 BLOOD MOON ACTIVE! Seek shelter!"
		_blood_moon_alert.visible = true
		# Pulsing red glow effect
		var tween := _blood_moon_alert.create_tween()
		tween.set_loops()
		tween.tween_property(_blood_moon_alert, "modulate:a", 0.3, 0.6)
		tween.tween_property(_blood_moon_alert, "modulate:a", 1.0, 0.6)


func _on_blood_moon_ended() -> void:
	if _blood_moon_alert:
		_blood_moon_alert.visible = false
		_blood_moon_alert.modulate = Color.WHITE  # reset alpha


func _on_game_mode_changed(mode: int) -> void:
	if _creative_label:
		var mode_name: String = "MODE"
		match mode:
			GameManager.GameMode.PEACEFUL:
				mode_name = "PEACEFUL"
				_creative_label.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
			GameManager.GameMode.SURVIVAL:
				mode_name = "SURVIVAL"
				_creative_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.3))
			GameManager.GameMode.CREATIVE:
				mode_name = "CREATIVE"
				_creative_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
			GameManager.GameMode.HARDCORE:
				mode_name = "HARDCORE"
				_creative_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.1))
		_creative_label.text = mode_name
		_creative_label.visible = true
		_refresh_creative_label_position()





func _on_active_tool_changed(tool_name: String) -> void:
	tool_label.text = "Tool: " + tool_name

# ── Bar numeric label helpers ──

## Adds a Label child to a ProgressBar that shows the numeric value.
## The label is positioned to overlay the bar's fill area.
var _bar_labels: Dictionary = {}

func _add_bar_numeric_label(bar: ProgressBar, key: String) -> void:
	if not bar:
		return
	var label := Label.new()
	label.name = key + "_numeric_label"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.9))
	label.add_theme_font_size_override("font_size", 9)
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(label)
	_bar_labels[key] = {"label": label, "bar": bar}

func _update_bar_label(key: String, value: int, max_value: int) -> void:
	var entry: Dictionary = _bar_labels.get(key, {})
	if entry.is_empty():
		return
	var label: Label = entry.get("label")
	if label:
		label.text = "%d/%d" % [value, max_value]

func set_seed_display(seed_value: int) -> void:
	seed_display_label.text = "Seed: %d" % seed_value

## Shows the join code in the top bar while hosting. Empty code hides it.
func set_join_code_display(join_code: String) -> void:
	if join_code.is_empty():
		clear_join_code_display()
		return
	join_code_label.text = "Join Code: %s" % join_code
	join_code_label.visible = true

func clear_join_code_display() -> void:
	join_code_label.visible = false

# ── Weather display ──

func _update_weather_display(_new_weather: WeatherSystem.WeatherType = WeatherSystem.WeatherType.CLEAR) -> void:
	if not GameManager.weather_system:
		return
	var ws := GameManager.weather_system
	var weather_name: String = ""
	match ws.current_weather:
		WeatherSystem.WeatherType.CLEAR:
			weather_name = "☀ Clear"
		WeatherSystem.WeatherType.RAIN:
			weather_name = "🌧 Rain"
		WeatherSystem.WeatherType.STORM:
			weather_name = "⛈ Storm"
		WeatherSystem.WeatherType.FOG:
			weather_name = "🌫 Fog"
	# Find or create weather label in the top-left info area
	var info_container: Control = get_node_or_null("InfoContainer")
	if not info_container:
		return
	var weather_label: Label = info_container.get_node_or_null("WeatherLabel")
	if not weather_label:
		weather_label = Label.new()
		weather_label.name = "WeatherLabel"
		weather_label.add_theme_font_size_override("font_size", 11)
		weather_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
		info_container.add_child(weather_label)
		# Position after seed label
		if seed_display_label:
			weather_label.position = Vector2(0, seed_display_label.position.y + 16)
	weather_label.text = weather_name

func open_ingame_menu() -> void:
	_in_game_menu.open()

func _on_menu_pressed() -> void:
	AudioManager.play(AudioManager.Sound.UI_CLICK)
	open_ingame_menu()

func _on_menu_confirmed() -> void:
	exit_to_menu_requested.emit()

func _on_day_changed(day: int) -> void:
	var season_name := GameManager.get_season_name()
	day_label.text = "Day %d - %s" % [day, season_name]
	_update_weather_display()

func _on_time_changed(hour: int, minute: int) -> void:
	var phase := GameManager.get_season_phase()
	var phase_icon := ""
	match phase:
		DayNightCycle.Phase.DAWN: phase_icon = "🌅"
		DayNightCycle.Phase.DAY: phase_icon = "☀️"
		DayNightCycle.Phase.DUSK: phase_icon = "🌆"
		DayNightCycle.Phase.NIGHT: phase_icon = "🌙"
	time_label.text = "%s %02d:%02d" % [phase_icon, hour, minute]
	_update_daynight_overlay(hour)

func _on_season_changed(_season: int, season_name: String) -> void:
	ToastNotification.show_toast("🌸 Welcome to %s!" % season_name, ToastNotification.ToastType.SUCCESS, 4.0)
	_on_day_changed(GameManager.current_day)

var _hint_night_shown: bool = false
var _hint_animal_shown: bool = false
var _hint_collect_shown: bool = false

func _on_phase_changed(phase: int) -> void:
	if phase == DayNightCycle.Phase.NIGHT:
		ToastNotification.show_toast("🌙 Night falls...", ToastNotification.ToastType.INFO, 3.0)
		if not _hint_night_shown:
			_hint_night_shown = true
			show_night_hint()
	elif phase == DayNightCycle.Phase.DAWN:
		ToastNotification.show_toast("🌅 A new dawn rises.", ToastNotification.ToastType.INFO, 3.0)

func _on_money_changed(amount: int) -> void:
	money_label.text = "$%d" % amount

func _on_health_changed(health: int, max_health: int) -> void:
	health_bar.value = health
	health_bar.max_value = max_health
	_update_bar_label("health", health, max_health)
	# Color shifts from green → yellow → red as health drops
	if health > max_health * 0.6:
		health_bar.modulate = Color(0.3, 1.0, 0.3, 1.0)
	elif health > max_health * 0.3:
		health_bar.modulate = Color(1.0, 0.8, 0.2, 1.0)
	else:
		health_bar.modulate = Color(1.0, 0.2, 0.2, 1.0)

func _on_hunger_changed(hunger: int, max_hunger: int) -> void:
	hunger_bar.value = hunger
	hunger_bar.max_value = max_hunger
	_update_bar_label("hunger", hunger, max_hunger)
	# Hunger bar fades as hunger drops
	var ratio: float = float(hunger) / float(max_hunger)
	hunger_bar.modulate = Color(1.0, 0.7 + 0.3 * ratio, 0.1 + 0.2 * ratio, 0.4 + 0.6 * ratio)

func _on_armor_changed(defense: int) -> void:
	armor_bar.value = defense
	_update_bar_label("armor", defense, 30)
	# Show a subtle color based on defense level
	if defense >= 20:
		armor_bar.modulate = Color(0.4, 1.0, 0.6, 1.0)  # Strong green
	elif defense >= 12:
		armor_bar.modulate = Color(0.6, 0.8, 1.0, 1.0)  # Bright blue
	elif defense >= 5:
		armor_bar.modulate = Color(0.6, 0.6, 1.0, 0.8)  # Blue
	else:
		armor_bar.modulate = Color(0.6, 0.6, 1.0, 0.3)  # Faded


# ---------------------------------------------------------------------------
# Level & XP display
# ---------------------------------------------------------------------------

func _on_xp_changed(current_xp: int, xp_for_next: int) -> void:
	xp_bar.max_value = float(xp_for_next)
	xp_bar.value = float(current_xp) if xp_for_next > 0 else 0.0

func _on_player_leveled(new_level: int) -> void:
	level_label.text = "Lv. %d" % new_level
	_on_xp_changed(LevelManager.get_xp(), LevelManager.get_xp_for_next_level())


# ---------------------------------------------------------------------------
# Pet indicator
# ---------------------------------------------------------------------------

func _on_pet_changed(_pet_id: String) -> void:
	_update_pet_indicator()

func _update_pet_indicator() -> void:
	if not PetManager.active_pet_id.is_empty():
		var display_name: String = PetManager.get_pet_display_name(PetManager.active_pet_id)
		pet_indicator.text = "🐾 " + display_name
		pet_indicator.show()
	else:
		pet_indicator.text = ""
		pet_indicator.hide()


# ---------------------------------------------------------------------------
# Boss bar — appears at top of screen during boss encounters
# ---------------------------------------------------------------------------

func _create_boss_bar() -> void:
	_boss_bar = PanelContainer.new()
	_boss_bar.name = "BossBar"
	_boss_bar.visible = false
	_boss_bar.anchor_left = 0.35
	_boss_bar.anchor_right = 0.65
	_boss_bar.offset_top = 100
	_boss_bar.offset_bottom = 146
	_boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.102, 0.063, 0.031, 0.85)
	bg.set_corner_radius_all(8)
	_boss_bar.add_theme_stylebox_override("panel", bg)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.custom_minimum_size = Vector2(0, 40)
	
	# Boss name label
	_boss_name_label = Label.new()
	_boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_name_label.add_theme_font_size_override("font_size", 14)
	_boss_name_label.add_theme_color_override("font_color", Color(0.95, 0.8, 0.3))
	_boss_name_label.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(_boss_name_label)
	
	# Boss HP bar
	_boss_hp_bar = ProgressBar.new()
	_boss_hp_bar.custom_minimum_size = Vector2(0, 16)
	_boss_hp_bar.show_percentage = false
	_boss_hp_bar.max_value = 1.0
	_boss_hp_bar.value = 1.0
	
	var hp_bg := StyleBoxFlat.new()
	hp_bg.bg_color = Color(0.2, 0.02, 0.02, 0.9)
	hp_bg.set_corner_radius_all(4)
	_boss_hp_bar.add_theme_stylebox_override("background", hp_bg)
	
	var hp_fill := StyleBoxFlat.new()
	hp_fill.bg_color = Color(0.9, 0.15, 0.15, 1.0)
	hp_fill.set_corner_radius_all(4)
	_boss_hp_bar.add_theme_stylebox_override("fill", hp_fill)
	
	vbox.add_child(_boss_hp_bar)
	
	_boss_bar.add_child(vbox)
	
	# Add to Root
	var root := get_node_or_null("Root")
	if root:
		root.add_child(_boss_bar)
	else:
		add_child(_boss_bar)


## Tracks a boss enemy for the boss bar. Connects to its health signal.
func _track_boss(boss: Node) -> void:
	if _current_boss and is_instance_valid(_current_boss):
		if _current_boss.boss_health_changed.is_connected(_update_boss_bar):
			_current_boss.boss_health_changed.disconnect(_update_boss_bar)
	
	_current_boss = boss
	if not boss or not is_instance_valid(boss):
		_boss_bar.visible = false
		return
	
	_boss_name_label.text = boss.display_name if "display_name" in boss else "BOSS"
	_boss_bar.visible = true
	
	if boss.has_signal("health_ratio_changed"):
		if boss.health_ratio_changed.is_connected(_update_boss_bar):
			boss.health_ratio_changed.disconnect(_update_boss_bar)
		boss.health_ratio_changed.connect(_update_boss_bar)
	
	_update_boss_bar(1.0)


func _update_boss_bar(ratio: float) -> void:
	if _boss_hp_bar:
		_boss_hp_bar.value = ratio
		# Color transitions from red -> orange -> yellow as HP decreases
		var color := Color.RED.lerp(Color.YELLOW, 1.0 - ratio)
		var fill_style := _boss_hp_bar.get_theme_stylebox("fill")
		if fill_style:
			fill_style.bg_color = color


func _on_boss_defeated() -> void:
	_boss_bar.visible = false
	_current_boss = null
	# Brief flash effect
	if _boss_bar:
		var flash := ColorRect.new()
		flash.color = Color(1.0, 0.85, 0.3, 0.3)
		flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var root := get_node_or_null("Root")
		if root:
			root.add_child(flash)
			var tween := flash.create_tween()
			tween.tween_property(flash, "modulate:a", 0.0, 0.8)
			tween.tween_callback(flash.queue_free)


## Scans for living bosses and tracks the first one found for the boss bar.
func _scan_for_boss() -> void:
	# If we already track a valid boss, skip
	if _current_boss and is_instance_valid(_current_boss):
		return
	
	var bosses := get_tree().get_nodes_in_group("bosses")
	var found: Node = null
	for b in bosses:
		if is_instance_valid(b) and b.has_method("is_inside_tree") and b.is_inside_tree():
			if "current_health" in b and b.current_health > 0:
				found = b
				break
	
	if found:
		_track_boss(found)
	else:
		if _boss_bar:
			_boss_bar.visible = false
		_current_boss = null


# ---------------------------------------------------------------------------
# Objective display — enhanced with progress bar, pulse, and fanfare
# ---------------------------------------------------------------------------

## Builds the progress bar, desc label, and numeric label inside the objective widget.
func _build_objective_widget() -> void:
	if not objective_label_vbox or not objective_panel:
		return
	
	# Progress bar (inserted after the labels)
	var bar := ProgressBar.new()
	bar.name = "ObjectiveProgressBar"
	bar.custom_minimum_size = Vector2(240, 6)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.max_value = 1.0
	bar.value = 0.0
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.15, 0.15, 0.15, 0.7)
	bg_style.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg_style)
	
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.3, 0.7, 0.4, 0.9)
	fill_style.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill_style)
	
	objective_label_vbox.add_child(bar)
	objective_progress_bar = bar
	
	# Description / hint label (shows what to do)
	var desc_label := Label.new()
	desc_label.name = "ObjectiveDescLabel"
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.add_theme_font_size_override("font_size", 10)
	desc_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.65, 0.75))
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objective_label_vbox.add_child(desc_label)
	objective_desc_label = desc_label
	
	# Numeric progress label below the bar
	var prog_label := Label.new()
	prog_label.name = "ObjectiveProgressLabel"
	prog_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prog_label.add_theme_font_size_override("font_size", 10)
	prog_label.add_theme_color_override("font_color", Color(0.7, 0.85, 0.6, 0.85))
	prog_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objective_label_vbox.add_child(prog_label)
	objective_progress_label = prog_label


## Toggle the objective goal panel between expanded and minimized (button-only) states.
func _toggle_objective_minimized() -> void:
	_objective_minimized = not _objective_minimized
	# Mirror the button tooltip so the affordance stays discoverable in both states.
	if objective_toggle_button:
		objective_toggle_button.tooltip_text = (
			"Show objective panel" if _objective_minimized else "Minimize objective panel"
		)
	_update_objective_display()
	# The raid / blood moon alerts sit below the objective panel, so they
	# slide up when the panel is minimized and drop back down when expanded.
	_refresh_raid_alert_position()
	_refresh_blood_moon_alert_position()


func _on_objective_completed(_id: int, _name_str: String) -> void:
	# Toast is already shown by ObjectiveManager
	# Show completion fanfare in the widget
	if objective_panel and objective_completed_label and objective_label:
		objective_completed_label.visible = true
		objective_label.visible = false
		if objective_progress_bar:
			objective_progress_bar.value = 1.0
			_fade_progress_bar_color(objective_progress_bar, Color(0.3, 0.7, 0.4, 0.9), Color(0.2, 1.0, 0.3, 0.9), 0.3)
		if objective_progress_label:
			objective_progress_label.visible = false
		
		# Flash green and scale up briefly
		var fanfare_tween := create_tween().set_parallel(true)
		fanfare_tween.tween_property(objective_panel, "modulate", Color(1, 1.2, 1, 1.2), 0.15)
		fanfare_tween.tween_property(objective_completed_label, "modulate:a", 1.2, 0.15)
		
		# Then settle back
		await get_tree().create_timer(1.0).timeout
		
		if not is_inside_tree():
			return
		objective_completed_label.visible = false
		objective_label.visible = true
		objective_panel.modulate = Color.WHITE
		objective_completed_label.modulate.a = 1.0
	
	# Update to next objective
	_update_objective_display()


## Tween the progress bar fill color smoothly.
func _fade_progress_bar_color(bar: ProgressBar, from: Color, to: Color, duration: float) -> void:
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = from
	fill_style.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill_style)
	
	var tween := create_tween()
	tween.tween_method(func(c: Color): 
		var s := StyleBoxFlat.new()
		s.bg_color = c
		s.set_corner_radius_all(3)
		if is_instance_valid(bar):
			bar.add_theme_stylebox_override("fill", s)
	, from, to, duration)


func _on_objectives_updated() -> void:
	_update_objective_display()


func _update_objective_display() -> void:
	if not objective_panel or not objective_label:
		return
	var obj_mgr := get_tree().get_first_node_in_group("objective_manager")
	if not obj_mgr or not obj_mgr.has_method("get_active_objective"):
		return
	var obj: Dictionary = obj_mgr.get_active_objective()
	
	# Hide completed label if it was showing from a previous completion
	if objective_completed_label:
		objective_completed_label.visible = false
	if objective_label:
		objective_label.visible = true
	
	if obj.is_empty():
		objective_panel.visible = false
		if objective_toggle_button:
			objective_toggle_button.visible = false
		if objective_progress_bar:
			objective_progress_bar.visible = false
		if objective_progress_label:
			objective_progress_label.visible = false
		if objective_desc_label:
			objective_desc_label.visible = false
		return
	
	# When minimized, collapse the panel to just the toggle button
	if _objective_minimized:
		objective_panel.visible = false
		if objective_toggle_button:
			objective_toggle_button.visible = true
			objective_toggle_button.text = "＋"
		_stop_near_completion_pulse()
		return
	if objective_toggle_button:
		objective_toggle_button.visible = true
		objective_toggle_button.text = "−"
	
	objective_panel.visible = true
	objective_label.text = "%s %s" % [obj.icon, obj.name]
	
	# Show description hint
	if objective_desc_label:
		var desc: String = obj.get("desc", "")
		if not desc.is_empty():
			objective_desc_label.text = desc
			objective_desc_label.visible = true
		else:
			objective_desc_label.visible = false
	
	var is_threshold: bool = obj.get("threshold", 1) > 1
	var current: int = mini(obj.get("progress", 0), obj.get("threshold", 1))
	var threshold: int = obj.get("threshold", 1)
	var ratio: float = float(current) / float(max(threshold, 1))
	
	if is_threshold:
		# Show progress bar
		if objective_progress_bar:
			objective_progress_bar.visible = true
			objective_progress_bar.value = ratio
			objective_progress_bar.max_value = 1.0
			# Color-code: green <50% → yellow 50-75% → orange 75-90% → red/pulse 90%+
			var bar_color: Color
			if ratio >= 0.9:
				bar_color = Color(0.95, 0.2, 0.2, 0.9)  # red = almost there
			elif ratio >= 0.75:
				bar_color = Color(1.0, 0.6, 0.1, 0.9)   # orange = close
			elif ratio >= 0.5:
				bar_color = Color(0.95, 0.85, 0.15, 0.9) # yellow = getting there
			else:
				bar_color = Color(0.3, 0.7, 0.4, 0.9)    # green = normal
			var fill_style := StyleBoxFlat.new()
			fill_style.bg_color = bar_color
			fill_style.set_corner_radius_all(3)
			objective_progress_bar.add_theme_stylebox_override("fill", fill_style)
		
		# Show numeric label
		if objective_progress_label:
			objective_progress_label.text = "%d / %d" % [current, threshold]
			objective_progress_label.visible = true
		
		# Near-completion pulse animation (≥80%)
		if ratio >= 0.8 and not _is_near_completion_pulsing():
			_start_near_completion_pulse(ratio)
		elif ratio < 0.8 and _is_near_completion_pulsing():
			_stop_near_completion_pulse()
	else:
		# Non-threshold objective: hide bar and label
		if objective_progress_bar:
			objective_progress_bar.visible = false
		if objective_progress_label:
			objective_progress_label.visible = false
		_stop_near_completion_pulse()


# --- Near-completion pulse animation ---
var _pulse_tween: Tween = null

func _is_near_completion_pulsing() -> bool:
	return _pulse_tween != null and _pulse_tween.is_valid()


func _start_near_completion_pulse(ratio: float) -> void:
	_stop_near_completion_pulse()
	if not objective_panel:
		return
	
	# Intensity scales with closeness (faster + brighter as you approach 100%)
	var intensity: float = (ratio - 0.8) / 0.2  # 0.0 at 80%, 1.0 at 100%
	var pulse_duration: float = 0.6 - intensity * 0.3  # 0.6s → 0.3s
	var max_alpha: float = 1.0 + intensity * 0.3  # 1.0 → 1.3
	
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(objective_panel, "modulate:a", max_alpha, pulse_duration * 0.5)
	_pulse_tween.tween_property(objective_panel, "modulate:a", 1.0, pulse_duration * 0.5)


func _stop_near_completion_pulse() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = null
	if objective_panel:
		objective_panel.modulate.a = 1.0

var _last_interactable: Interactable = null

## Called by RuinStructure (and other external objects) when the player's
## body enters an interaction area — shows a prompt with full text
## (e.g. "Press [E] to clear rubble").
func show_interaction_prompt(text: String) -> void:
	interaction_prompt.text = text
	interaction_prompt.visible = true
	interaction_prompt_panel.visible = true

## Called by RuinStructure when the player's body exits an interaction area.
func hide_interaction_prompt() -> void:
	interaction_prompt_panel.visible = false

## Returns true if a regular Interactable (tree, rock, animal, etc.) is
## currently driving the shared interaction prompt. Used by RuinStructure so
## its periodic prompt re-assertion doesn't fight with the PlayerInteractor.
func is_interactable_prompt_active() -> bool:
	return _last_interactable != null and is_instance_valid(_last_interactable)

func _on_interactable_in_range(interactable: Interactable) -> void:
	# Ignore signals while the HUD is leaving the tree (session teardown on
	# the client): get_tree() returns null there, which crashes with
	# "Parameter "data.tree" is null" via PlayerInteractor.
	if not is_inside_tree():
		return
	# The interactable can be freed between the area signal and here (world
	# regen, remote player cleanup) — a dangling reference is not null.
	if not is_instance_valid(interactable):
		_on_interactable_out_of_range()
		return
	if interactable:
		_last_interactable = interactable
		# If this is an animal and the player hasn't seen the animal hint, show it
		if not _hint_animal_shown and interactable is Animal:
			_hint_animal_shown = true
			show_animal_hint()
		# Context-aware prompt: if the interactable requires a tool the player
		# doesn't have, check if the player has food they could eat instead.
		var interact_tree := get_tree()
		var player := interact_tree.get_first_node_in_group("player") as Player if interact_tree else null
		if player \
				and interactable.required_tool >= 0 \
				and not player.has_tool_active(interactable.required_tool):
			var consumable_id: String = player.get_hotbar_consumable_id()
			if consumable_id != "":
				var item: ItemData = DataManager.get_item(consumable_id)
				var food_name: String = item.display_name if item else "food"
				interaction_prompt.text = "[E] Eat %s" % food_name
			else:
				# No food either — show a greyed-out version of the original prompt
				interaction_prompt.text = "[E] %s" % interactable.interaction_prompt
		else:
			interaction_prompt.text = "[E] %s" % interactable.interaction_prompt
		interaction_prompt.visible = true
		interaction_prompt_panel.visible = true
		# Start periodic refresh (e.g., every 0.3s) so prompts update for animals' context
		if not is_queued_for_deletion():
			var tree := get_tree()
			if tree:
				var timer := tree.create_timer(0.3)
				timer.timeout.connect(_refresh_interaction_prompt)

func _on_interactable_out_of_range() -> void:
	_last_interactable = null
	interaction_prompt_panel.visible = false

func _refresh_interaction_prompt() -> void:
	if not _last_interactable or not is_instance_valid(_last_interactable):
		_on_interactable_out_of_range()
		return
	# Animal objects change their interaction_prompt based on context — refresh it
	if _last_interactable.has_method("_update_contextual_prompt"):
		_last_interactable._update_contextual_prompt()
	# Context-aware prompt: same logic as _on_interactable_in_range
	var tree := get_tree()
	var player := tree.get_first_node_in_group("player") as Player if tree else null
	if player \
			and _last_interactable.required_tool >= 0 \
			and not player.has_tool_active(_last_interactable.required_tool):
		var consumable_id: String = player.get_hotbar_consumable_id()
		if consumable_id != "":
			var item: ItemData = DataManager.get_item(consumable_id)
			var food_name: String = item.display_name if item else "food"
			interaction_prompt.text = "[E] Eat %s" % food_name
		else:
			interaction_prompt.text = "[E] %s" % _last_interactable.interaction_prompt
	else:
		interaction_prompt.text = "[E] %s" % _last_interactable.interaction_prompt
	# Continue periodic refresh
	if _last_interactable:
		var refresh_tree := get_tree()
		if refresh_tree:
			var timer := refresh_tree.create_timer(0.3)
			timer.timeout.connect(_refresh_interaction_prompt)

func _on_crop_mutated(old_name: String, new_name: String, mutation_name: String) -> void:
	mutation_label.text = "✨ %s mutated into %s! (%s mutation)" % [old_name, new_name, mutation_name]
	mutation_label.visible = true
	mutation_label_panel.visible = true
	mutation_toast_timer.start()
	
	# Show toast notification for extra polish
	ToastNotification.show_toast("%s → %s!" % [old_name, new_name], ToastNotification.ToastType.SUCCESS, 4.0)

func _on_mutation_toast_timeout() -> void:
	mutation_label_panel.visible = false

## Updates the day/night color overlay to reflect the current hour.
## Produces a dark blue tint at night and a warm orange glow at dawn/dusk.
func _update_daynight_overlay(hour: int) -> void:
	if not daynight_overlay:
		return
	
	# Don't apply the day/night overlay inside mines and buildings — they have
	# their own ambient lighting/darkness. Expedition islands are outdoor spaces
	# and should still get the day/night cycle visual effect.
	var world: Node = get_tree().get_first_node_in_group("world")
	if world and (world.get("current_mine_room") != null or world.get("current_interior") != null):
		daynight_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
		return
	
	# Use the DayNightCycle system for smooth transitions
	if GameManager.day_night:
		daynight_overlay.color = GameManager.day_night.get_overlay_color(hour)
	else:
		# Fallback legacy calculation
		var darkness: float
		if hour >= 6 and hour < 18:
			darkness = 0.0
		elif hour >= 18 and hour < 20:
			darkness = lerpf(0.0, 0.4, (hour - 18) / 2.0)
		elif hour >= 20 or hour < 5:
			darkness = 0.4
		elif hour >= 5 and hour < 6:
			darkness = lerpf(0.4, 0.0, (hour - 5) / 1.0)
		
		var tint_color: Color
		if hour >= 5 and hour < 7:
			tint_color = Color(0.8, 0.5, 0.2, darkness)
		elif hour >= 17 and hour < 20:
			tint_color = Color(0.7, 0.4, 0.15, darkness)
		else:
			tint_color = Color(0.05, 0.05, 0.15, darkness)
		daynight_overlay.color = tint_color


## Fade screen to black, call callback, then fade back in
func fade_to_black(duration: float = 0.5, callback: Callable = Callable()) -> void:
	if not fade_overlay:
		if callback.is_valid():
			callback.call()
		return
	
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	
	fade_overlay.visible = true
	fade_overlay.modulate.a = 0.0
	
	_fade_tween = create_tween()
	_fade_tween.set_parallel(false)
	_fade_tween.tween_property(fade_overlay, "modulate:a", 1.0, duration)
	
	if callback.is_valid():
		_fade_tween.tween_callback(callback.call)
	
	_fade_tween.tween_property(fade_overlay, "modulate:a", 0.0, duration)
	_fade_tween.tween_callback(func(): fade_overlay.visible = false)

## Quick flash effect (for day changes, etc.)
func flash_screen(color: Color = Color.WHITE, duration: float = 0.3) -> void:
	if not fade_overlay:
		return
	
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	
	fade_overlay.visible = true
	fade_overlay.color = color
	fade_overlay.modulate.a = 0.5
	
	var flash_tween := create_tween()
	flash_tween.tween_property(fade_overlay, "modulate:a", 0.0, duration)
	flash_tween.tween_callback(func(): fade_overlay.visible = false)

# ---------------------------------------------------------------------------
# Tutorial hints
# ---------------------------------------------------------------------------

## Called whenever the game mode is set (new game, load, host, join) — the
## moment the game actually starts. Schedules the right onboarding hint now
## that the mode is known (HUD._ready runs before the mode is chosen).
func _on_onboarding_mode_changed(mode: int) -> void:
	if mode == GameManager.GameMode.CREATIVE:
		if not _first_action_hints.has("creative_panel"):
			get_tree().create_timer(2.0).timeout.connect(_show_creative_hint)
	else:
		if not _first_action_hints.has("first_steps"):
			get_tree().create_timer(2.0).timeout.connect(_show_first_step_hint)

## First-steps directive shown shortly after spawn. Tells the player the exact
## first action; the moment-of-action hints below then carry the teaching chain.
func _show_first_step_hint() -> void:
	# Mode guard: a stale timer from a previous mode change must not fire.
	if GameManager.is_creative():
		return
	# If the player already tilled before this fired, skip the directive so it
	# doesn't overwrite the "Tilled!" moment hint.
	if _first_action_hints.has("first_till"):
		return
	show_first_action_hint("first_steps",
		"Goal: Plant your first crop! The Hoe is equipped — press [F] or left-click the ground to till soil.",
		10.0)

func _show_creative_hint() -> void:
	# Mode guard: a stale timer from a previous mode change must not fire.
	if not GameManager.is_creative():
		return
	show_first_action_hint("creative_panel",
		"Creative mode: Press ` (backtick) to open the Creative Panel — spawn items, control time, summon creatures, and more!",
		8.0)

## Session-scoped first-time flags for moment-of-action hints.
## Maps action_id -> true once that hint has been shown this session.
var _first_action_hints: Dictionary = {}

## Shows a hint only the first time the given action happens per session.
## Returns true if the hint was shown, false if it already fired before.
func show_first_action_hint(action_id: String, text: String, duration: float = 5.0) -> bool:
	if _first_action_hints.has(action_id):
		return false
	_first_action_hints[action_id] = true
	show_tutorial_hint(text, duration)
	return true

# --- Event-triggered contextual tutorial hints (fire once per session) ---

## Called when the player opens inventory for the first time.
func show_inventory_hint() -> void:
	show_tutorial_hint("Inventory: drag items to move them, right-click to view description, Delete to discard. Armor slots on the right side!")

## Called when the player opens crafting for the first time.
func show_crafting_hint() -> void:
	show_tutorial_hint("Crafting [C]: Switch between Crafting (tools, armor, buildings) and Alchemy (potions) using the tabs at the top!")

## Called when the player first equips a fishing rod.
func show_fishing_hint() -> void:
	show_tutorial_hint("Fishing: stand near water with the fishing rod in your hotbar and press E to cast! Press E again when a fish bites to reel it in.")

## Called when the player first enters a building interior.
func show_interior_hint() -> void:
	show_tutorial_hint("Inside a building: interact with beds to sleep, crafting stations to craft, chests to store items. Press ESC to leave.")

## Called when the player first encounters night.
func show_night_hint() -> void:
	show_tutorial_hint("Night has fallen! In Survival mode, enemies spawn at night. Stay near light sources or sleep in your bed until dawn.")

## Called when the player first approaches an animal.
func show_animal_hint() -> void:
	show_tutorial_hint("Animals have favorite foods! Hold their food in your hotbar and they'll follow you. Press [E] to feed them → love mode! Feed two of the same type to breed. Press [G] for farming overview.")

func show_tutorial_hint(text: String, duration: float = 5.0) -> void:
	if not tutorial_hint:
		return
	
	tutorial_hint.text = text
	tutorial_hint.visible = true
	tutorial_hint_panel.visible = true
	
	if tutorial_hint_timer:
		tutorial_hint_timer.start(duration)

func _on_tutorial_hint_timeout() -> void:
	tutorial_hint_panel.visible = false


# ---------------------------------------------------------------------------
# Active buff display
# ---------------------------------------------------------------------------

func _on_buffs_changed() -> void:
	_refresh_buff_display()

func _refresh_buff_display() -> void:
	if not _buff_container:
		return
	
	# Clear old buff panels
	for child in _buff_container.get_children():
		child.queue_free()
	_buff_panels.clear()
	
	if not BuffManager:
		return
	
	var buffs: Array = BuffManager.get_all_buffs()
	if buffs.is_empty():
		_buff_container.visible = false
		if _buff_toggle_button:
			_buff_toggle_button.visible = false
		return
	
	# Show the toggle button whenever there's at least one active buff
	if _buff_toggle_button:
		_buff_toggle_button.visible = true
		_buff_toggle_button.text = "＋" if _buff_minimized else "−"
		_buff_toggle_button.tooltip_text = (
			"Show buff bars" if _buff_minimized else "Minimize buff bars"
		)

	# When minimized, collapse to just the toggle button
	_buff_container.visible = not _buff_minimized
	if _buff_minimized:
		return
	
	for buff in buffs:
		var panel := PanelContainer.new()
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = _buff_color(buff.buff_type, 0.85)
		style.set_corner_radius_all(4)
		style.set_border_width_all(1)
		style.border_color = _buff_color(buff.buff_type, 1.0)
		panel.add_theme_stylebox_override("panel", style)
		
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		panel.add_child(hbox)
		
		# Icon label
		var icon_label := Label.new()
		icon_label.text = _buff_icon(buff.buff_type)
		icon_label.add_theme_font_size_override("font_size", 16)
		hbox.add_child(icon_label)
		
		# Name and remaining time
		var text_label := Label.new()
		var mins_left: int = buff.remaining_minutes
		var hours_left: int = floori(mins_left / 60.0)
		var mins_part: int = mins_left % 60
		text_label.text = "%s (%dh %dm)" % [buff.source_name, hours_left, mins_part]
		text_label.add_theme_font_size_override("font_size", 12)
		text_label.add_theme_color_override("font_color", Color.WHITE)
		hbox.add_child(text_label)
		
		_buff_container.add_child(panel)
		_buff_panels[buff.buff_type] = panel


## Toggle the buff bars between expanded and minimized (button-only) states.
func _toggle_buff_minimized() -> void:
	_buff_minimized = not _buff_minimized
	_refresh_buff_display()


## Positions the buff container below the stat cluster normally, but drops
## it below the chat panel whenever chat is visible so the two never overlap.
func _refresh_buff_position() -> void:
	if not _buff_container:
		return
	var y: float = 148.0
	if _chat_panel and _chat_panel.visible:
		y = 340.0  # below the chat panel (which ends at y=315)
	# The toggle button sits where the bars normally start; the bars render
	# below it so the button never overlaps the first buff panel.
	if _buff_toggle_button:
		_buff_toggle_button.position = Vector2(12.0, y - 2.0)
	_buff_container.position = Vector2(12.0, y + 22.0)


func _periodic_buff_refresh(delta: float) -> void:
	# Periodically refresh buff display to update remaining time
	if not _buff_container or not _buff_container.visible:
		return
	_buff_update_timer += delta
	if _buff_update_timer > 5.0:  # update every 5 seconds
		_buff_update_timer = 0.0
		_refresh_buff_display()


func _buff_icon(buff_type: String) -> String:
	match buff_type:
		"speed": return "⚡"
		"growth": return "🌱"
		"energy": return "⚡"
		"luck": return "🍀"
		"health": return "❤️‍🩹"
		_: return "✨"

func _buff_color(buff_type: String, alpha: float) -> Color:
	match buff_type:
		"speed": return Color(0.2, 0.6, 1.0, alpha)
		"growth": return Color(0.2, 0.8, 0.3, alpha)
		"energy": return Color(1.0, 0.8, 0.2, alpha)
		"luck": return Color(0.3, 1.0, 0.3, alpha)
		"health": return Color(1.0, 0.3, 0.3, alpha)
		_: return Color(0.5, 0.5, 0.5, alpha)


# ── Player list (multiplayer roster) ──────────────────────────────────────

## Build the player list panel (top-right, below the toasts). Pure
## presentation: reads GameManager.get_roster() on a timer and rebuilds rows.
func _setup_player_list() -> void:
	_player_list_panel = PanelContainer.new()
	_player_list_panel.name = "PlayerList"
	_player_list_panel.visible = false
	_player_list_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player_list_panel.add_theme_stylebox_override("panel", _make_player_list_style())
	$Root.add_child(_player_list_panel)
	_player_list_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_player_list_panel.anchor_right = 1.0
	_player_list_panel.anchor_bottom = 0.0
	_player_list_panel.offset_left = -276
	_player_list_panel.offset_right = -52
	_player_list_panel.offset_top = 192
	_player_list_panel.offset_bottom = 192

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	_player_list_panel.add_child(margin)

	_player_list_vbox = VBoxContainer.new()
	_player_list_vbox.name = "Rows"
	_player_list_vbox.add_theme_constant_override("separation", 4)
	margin.add_child(_player_list_vbox)

	var timer := Timer.new()
	timer.name = "PlayerListTimer"
	timer.wait_time = 0.5
	timer.timeout.connect(_refresh_player_list)
	add_child(timer)
	timer.start()

	if not GameManager.player_list_changed.is_connected(_refresh_player_list):
		GameManager.player_list_changed.connect(_refresh_player_list)


func _make_player_list_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.45)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style


func _refresh_player_list() -> void:
	if not is_instance_valid(_player_list_panel) or not is_instance_valid(_player_list_vbox):
		return
	var active: bool = NetworkManager.is_network_active()
	if not active:
		_player_list_panel.visible = false
		return
	for child in _player_list_vbox.get_children():
		child.queue_free()
	var roster: Array = GameManager.get_roster()
	if roster.is_empty():
		_player_list_panel.visible = false
		return
	_player_list_panel.visible = true
	for entry: Dictionary in roster:
		_player_list_vbox.add_child(_build_player_row(entry))


func _build_player_row(entry: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var name_text: String = str(entry.get("name", "Player"))
	if entry.get("is_host", false):
		name_text += " (Host)"
	if entry.get("is_me", false):
		name_text += " (You)"

	var name_label := Label.new()
	name_label.text = name_text
	name_label.add_theme_font_size_override("font_size", 14)
	if entry.get("is_host", false):
		name_label.add_theme_color_override("font_color", Color("#ffd54f"))
	elif entry.get("is_me", false):
		name_label.add_theme_color_override("font_color", Color("#7ec8ff"))
	row.add_child(name_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var stats_label := Label.new()
	stats_label.text = "Lv.%d  HP %d/%d" % [
		int(entry.get("level", 1)),
		int(entry.get("health", 0)),
		int(entry.get("max_health", 100)),
	]
	stats_label.add_theme_font_size_override("font_size", 12)
	stats_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	row.add_child(stats_label)
	return row


# ── Chat (top-left) ───────────────────────────────────────────────────

## Build the chat log + input, anchored at the top-left. Works both solo
## (local echo) and multiplayer (host relay). Input opens with Enter.
func _setup_chat() -> void:
	_chat_panel = PanelContainer.new()
	_chat_panel.name = "ChatPanel"
	_chat_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chat_panel.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.35)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	_chat_panel.add_theme_stylebox_override("panel", style)
	$Root.add_child(_chat_panel)

	# Anchored top-left, grows downward. Starts below the HUD bars (which
	# occupy y=12..84 full-width) and stays left of the objective widget.
	_chat_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_chat_panel.anchor_left = 0.0
	_chat_panel.anchor_top = 0.0
	_chat_panel.offset_left = 12
	_chat_panel.offset_top = 130
	_chat_panel.offset_right = 420
	_chat_panel.offset_bottom = 315

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)

	var title := Label.new()
	title.text = "💬 Chat"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	header.add_child(title)

	var hint := Label.new()
	hint.text = "Enter to type, Enter sends, Esc closes"
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	header.add_child(hint)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	_chat_hide_button = Button.new()
	_chat_hide_button.name = "HideChatButton"
	_chat_hide_button.text = "✕"
	_chat_hide_button.tooltip_text = "Hide chat (press Enter to bring it back)"
	_chat_hide_button.flat = true
	_chat_hide_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_chat_hide_button.add_theme_font_size_override("font_size", 12)
	_chat_hide_button.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	_chat_hide_button.add_theme_color_override("font_hover_color", Color.WHITE)
	_chat_hide_button.pressed.connect(_on_chat_hide_pressed)
	header.add_child(_chat_hide_button)

	_chat_scroll = ScrollContainer.new()
	_chat_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_chat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_chat_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chat_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_scroll.custom_minimum_size = Vector2(200, 120)
	vbox.add_child(_chat_scroll)

	_chat_text = RichTextLabel.new()
	_chat_text.bbcode_enabled = true
	_chat_text.fit_content = false
	_chat_text.scroll_following = true
	_chat_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_chat_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chat_text.add_theme_font_size_override("normal_font_size", 14)
	_chat_text.add_theme_color_override("default_color", Color(1, 1, 1, 0.9))
	_chat_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chat_text.custom_minimum_size = Vector2(200, 0)
	_chat_scroll.add_child(_chat_text)

	_chat_input = LineEdit.new()
	_chat_input.name = "ChatInput"
	_chat_input.placeholder_text = "Message..."
	_chat_input.custom_minimum_size = Vector2(0, 28)
	_chat_input.visible = false
	_chat_input.text_submitted.connect(_on_chat_submitted)
	_chat_input.add_to_group("chat_input")
	vbox.add_child(_chat_input)

	if not GameManager.chat_message_received.is_connected(_on_chat_message):
		GameManager.chat_message_received.connect(_on_chat_message)

	# Polite hint once a session is active (same timer as the player list).
	var chat_timer := Timer.new()
	chat_timer.name = "ChatVisibilityTimer"
	chat_timer.wait_time = 0.5
	chat_timer.timeout.connect(_refresh_chat_visibility)
	add_child(chat_timer)
	chat_timer.start()

	_refresh_chat_visibility()


## Chat panel shows whenever the user hasn't explicitly hidden it. Message
## sending works offline (local echo) and in multiplayer (host relay), so the
## panel is kept usable in both rather than being multiplayer-only.
func _refresh_chat_visibility() -> void:
	if not is_instance_valid(_chat_panel):
		return
	_chat_panel.visible = not _chat_hidden
	_refresh_buff_position()
	if not _chat_panel.visible and _chat_open:
		_close_chat_input()


func _on_chat_hide_pressed() -> void:
	_chat_hidden = not _chat_hidden
	_refresh_chat_visibility()


func _on_chat_message(sender_name: String, text: String) -> void:
	_append_chat_line("<%s> %s" % [sender_name, text])


func _append_chat_line(line: String) -> void:
	if not _chat_text:
		return
	_chat_text.append_text(line + "\n")
	# Keep the log bounded — drop the top lines once it gets tall.
	if _chat_text.get_line_count() > 120:
		var all: Array[String] = []
		for line_i: String in _chat_text.text.split("\n", false):
			all.append(line_i)
		while all.size() > 100:
			all.pop_front()
		_chat_text.text = "\n".join(all) + "\n"
	_chat_text.scroll_to_line(_chat_text.get_line_count())


func _on_chat_submitted(text: String) -> void:
	if text.strip_edges().is_empty():
		_close_chat_input()
		return
	if GameManager:
		GameManager.send_chat_message(text)
	_chat_input.text = ""
	_chat_input.release_focus()
	_chat_open = false
	_chat_input.visible = false
	# Keep chat log visible so recent messages stay readable
	_chat_panel.visible = true
	_refresh_buff_position()


func _toggle_chat_input() -> void:
	if _chat_open:
		_close_chat_input()
		return
	# Entering a message brings the panel back even if the user hid it.
	_chat_hidden = false
	_chat_open = true
	_chat_panel.visible = true
	_refresh_buff_position()
	_chat_input.visible = true
	_chat_input.grab_focus()


func _close_chat_input() -> void:
	_chat_open = false
	_chat_input.visible = false
	_chat_input.text = ""
	if _chat_input.has_focus():
		_chat_input.release_focus()


func _unhandled_input(event: InputEvent) -> void:
	# [Enter] toggles the chat input; [Esc] closes it while open. Works both
	# solo (local echo) and multiplayer (host relay).
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_toggle_chat_input()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and _chat_open:
			_close_chat_input()
			get_viewport().set_input_as_handled()
