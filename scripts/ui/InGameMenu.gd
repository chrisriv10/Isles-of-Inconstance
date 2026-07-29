extends CanvasLayer
class_name InGameMenuUI

## In-game pause/options menu opened from the TopBar MenuButton.
## Provides Tutorial, Controls, Settings info panels and Return to Main Menu.

signal exit_to_menu_requested()

@onready var bg_click_catcher: ColorRect = $BgClickCatcher
@onready var panel_container: PanelContainer = $Panel
@onready var tutorial_btn: Button = $Panel/Margin/VBox/TutorialButton
@onready var controls_btn: Button = $Panel/Margin/VBox/ControlsButton
@onready var settings_btn: Button = $Panel/Margin/VBox/SettingsButton
@onready var return_btn: Button = $Panel/Margin/VBox/ReturnToMenuButton
@onready var close_btn: Button = $Panel/Margin/VBox/CloseButton

var _info_panel: PanelContainer = null
var _current_info: String = ""

func _ready() -> void:
	tutorial_btn.pressed.connect(_on_tutorial_pressed)
	controls_btn.pressed.connect(_on_controls_pressed)
	settings_btn.pressed.connect(_on_settings_pressed)
	return_btn.pressed.connect(_on_return_pressed)
	close_btn.pressed.connect(_close)
	bg_click_catcher.gui_input.connect(_on_bg_input)
	
	# Start hidden
	visible = false

func open() -> void:
	_close_info_panel()
	visible = true
	AudioManager.play(AudioManager.Sound.MENU_OPEN)
	panel_container.modulate.a = 0.0
	bg_click_catcher.modulate.a = 0.0
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel_container, "modulate:a", 1.0, 0.15)
	tween.tween_property(bg_click_catcher, "modulate:a", 1.0, 0.15)

func close() -> void:
	_close_info_panel()
	visible = false
	AudioManager.play(AudioManager.Sound.MENU_CLOSE)

func _close() -> void:
	AudioManager.play(AudioManager.Sound.UI_CLICK)
	close()

func _on_bg_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close()

func _on_return_pressed() -> void:
	AudioManager.play(AudioManager.Sound.UI_CLICK)
	_show_return_confirmation()

func _show_return_confirmation() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Return to Main Menu"
	dialog.dialog_text = "Return to the main menu?\nYour game will be saved first."
	dialog.ok_button_text = "Yes, Return"
	dialog.cancel_button_text = "Cancel"
	dialog.exclusive = true
	dialog.min_size = Vector2(300, 120)
	
	# Style the dialog panel to match the golden theme
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.102, 0.063, 0.031, 0.95)
	panel_style.border_width_left = 3
	panel_style.border_width_top = 3
	panel_style.border_width_right = 3
	panel_style.border_width_bottom = 3
	panel_style.border_color = Color(0.722, 0.525, 0.176, 1.0)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.corner_radius_bottom_left = 8
	dialog.add_theme_stylebox_override("panel", panel_style)
	
	# Style the title to golden
	dialog.add_theme_color_override("title_color", Color(0.9, 0.7, 0.2))
	
	# Style buttons to match the menu
	var btn_style_normal := StyleBoxFlat.new()
	btn_style_normal.bg_color = Color(0.361, 0.239, 0.118, 0.9)
	btn_style_normal.border_width_left = 2
	btn_style_normal.border_width_top = 2
	btn_style_normal.border_width_right = 2
	btn_style_normal.border_width_bottom = 2
	btn_style_normal.border_color = Color(0.545, 0.412, 0.122, 0.6)
	btn_style_normal.corner_radius_top_left = 8
	btn_style_normal.corner_radius_top_right = 8
	btn_style_normal.corner_radius_bottom_right = 8
	btn_style_normal.corner_radius_bottom_left = 8
	
	var btn_style_hover := StyleBoxFlat.new()
	btn_style_hover.bg_color = Color(0.478, 0.333, 0.188, 1.0)
	btn_style_hover.border_width_left = 2
	btn_style_hover.border_width_top = 2
	btn_style_hover.border_width_right = 2
	btn_style_hover.border_width_bottom = 2
	btn_style_hover.border_color = Color(0.722, 0.525, 0.176, 0.8)
	btn_style_hover.corner_radius_top_left = 8
	btn_style_hover.corner_radius_top_right = 8
	btn_style_hover.corner_radius_bottom_right = 8
	btn_style_hover.corner_radius_bottom_left = 8
	
	var ok_btn := dialog.get_ok_button()
	if ok_btn:
		ok_btn.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
		ok_btn.add_theme_stylebox_override("normal", btn_style_normal)
		ok_btn.add_theme_stylebox_override("hover", btn_style_hover)
	var cancel_btn := dialog.get_cancel_button()
	if cancel_btn:
		cancel_btn.add_theme_color_override("font_color", Color(0.8, 0.7, 0.6))
		cancel_btn.add_theme_stylebox_override("normal", btn_style_normal)
		cancel_btn.add_theme_stylebox_override("hover", btn_style_hover)
	
	dialog.confirmed.connect(_on_return_confirmed)
	dialog.canceled.connect(_on_return_canceled)
	
	add_child(dialog)
	dialog.popup_centered()

func _on_return_confirmed() -> void:
	visible = false
	exit_to_menu_requested.emit()

func _on_return_canceled() -> void:
	AudioManager.play(AudioManager.Sound.UI_CLICK)

func _on_tutorial_pressed() -> void:
	AudioManager.play(AudioManager.Sound.UI_CLICK)
	_toggle_info_panel("tutorial")

func _on_controls_pressed() -> void:
	AudioManager.play(AudioManager.Sound.UI_CLICK)
	_toggle_info_panel("controls")

func _on_settings_pressed() -> void:
	AudioManager.play(AudioManager.Sound.UI_CLICK)
	_toggle_info_panel("settings")

func _toggle_info_panel(panel_id: String) -> void:
	if _current_info == panel_id and _info_panel:
		_close_info_panel()
		return
	_close_info_panel()
	_current_info = panel_id
	_info_panel = _create_info_panel(panel_id)
	add_child(_info_panel)

func _close_info_panel() -> void:
	if _info_panel:
		_info_panel.queue_free()
		_info_panel = null
	_current_info = ""

func _create_info_panel(panel_id: String) -> PanelContainer:
	var panel := PanelContainer.new()
	var viewport_size := get_viewport().get_visible_rect().size
	var pw: float = min(550.0, viewport_size.x * 0.85)
	var ph: float = min(420.0, viewport_size.y * 0.75)
	
	panel.position = Vector2((viewport_size.x - pw) / 2.0, (viewport_size.y - ph) / 2.0)
	panel.size = Vector2(pw, ph)
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.102, 0.063, 0.031, 0.95)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.722, 0.525, 0.176, 1.0)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	panel.add_theme_stylebox_override("panel", style)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)
	
	var vbox := VBoxContainer.new()
	margin.add_child(vbox)
	
	var title := Label.new()
	title.text = panel_id.capitalize()
	title.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
	title.add_theme_font_size_override("font_size", 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(200, 2)
	divider.color = Color(0.722, 0.525, 0.176, 0.6)
	vbox.add_child(divider)
	
	if panel_id == "settings":
		var settings_vbox := _create_settings_content(pw)
		vbox.add_child(settings_vbox)
	else:
		var content := RichTextLabel.new()
		content.custom_minimum_size = Vector2(pw - 64, ph - 120)
		content.bbcode_enabled = true
		content.fit_content = false
		content.scroll_active = true
		content.add_theme_color_override("default_color", Color(0.85, 0.8, 0.7))
		content.add_theme_font_size_override("normal_font_size", 14)
		match panel_id:
			"tutorial":
				content.text = _get_tutorial_text()
			"controls":
				content.text = _get_controls_text()
		vbox.add_child(content)
	
	var info_close_btn := Button.new()
	info_close_btn.text = "Close"
	info_close_btn.custom_minimum_size = Vector2(150, 36)
	info_close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	info_close_btn.pressed.connect(_close_info_panel)
	vbox.add_child(info_close_btn)
	
	panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.15)
	
	return panel

func _get_tutorial_text() -> String:
	return """[b][color=#e8c84a]Welcome to Isles of Inconstance![/color][/b]

You've arrived on a mysterious, ever-changing island. Your goal is to [b]survive, farm, craft, and explore[/b] while uncovering its secrets.

[b][color=#7fc97f]Getting Started:[/color][/b]
• Press [b]C[/b] to open the Crafting menu and craft basic tools
• Press [b]I[/b] to open your inventory
• Use the hotbar (keys [b]1-0[/b]) to select items
• Left-click to use tools, right-click to interact

[b][color=#7fc97f]Farming:[/color][/b]
• Hoe the ground (press [b]F[/b] or left-click with hoe equipped)
• Plant seeds in tilled soil
• Water crops daily with the watering can
• Harvest when fully grown!

[b][color=#7fc97f]Building:[/color][/b]
• Press [b]V[/b] to enter build mode
• Select a building kit from your hotbar
• Aim at a tile and press [b]E[/b] to place
• Enter buildings through their doorways

[b][color=#7fc97f]Animals & Breeding:[/color][/b]
• Find animals in the wild — approach and press [b][color=#e8c84a]E[/color][/b] to interact
• [b]Pet[/b] animals daily to build affection and earn drops (eggs, milk, wool, etc.)
• Each animal type has [b]favorite foods[/b] — hold one in your hotbar and nearby animals will follow you!
• Press [b][color=#e8c84a]E[/color][/b] to feed them → they enter [b]love mode[/b] ❤️ for 15 seconds
• Feed [b]two of the same type[/b] while both are in love mode to produce a baby!
• Babies grow to adults in 2 minutes and can breed too
• Build [b]fences[/b] to keep animals contained on your farm
• Press [b][color=#e8c84a]G[/color][/b] for the farming overview — see all crops and animal info

[b][color=#7fc97f]Pro Tips:[/color][/b]
• Sleep in a bed to skip the night
• Cook food for better nutrition
• Build fences to contain animals
• Upgrade your tools at the Upgrade station
• Press [b]P[/b] to manage pets and their bonuses"""

func _get_controls_text() -> String:
	return """[b][color=#e8c84a]Controls[/color][/b]

[b][color=#7fc97f]Movement:[/color][/b]
• [b]W A S D[/b] / Arrow Keys — Move
• [b]Space[/b] / [b]F[/b] — Use equipped tool / Attack

[b][color=#7fc97f]Inventory & Hotbar:[/color][/b]
• [b]1, 2[/b] — Select hoe / watering can
• [b]3, 4, 5, 6, 7, 8, 9, 0[/b] — Select hotbar slots
• [b]I[/b] — Open/close inventory
• [b]Delete[/b] — Discard item (in inventory)
• [b]Right-click[/b] in inventory — Split stacks / Equip armor

[b][color=#7fc97f]Crafting & Building:[/color][/b]
• [b]C[/b] — Open crafting menu
• [b]K[/b] — Open cooking menu (near campfire/kitchen)
• [b]V[/b] — Enter/exit build mode
• [b]E[/b] — Interact / Harvest / Cast fishing line / Clear rubble
• Hold [b]E[/b] — Eat food / Drink potions / Use mine entrances

[b][color=#7fc97f]Menus & Navigation:[/color][/b]
• [b]B[/b] — Open shop (near a shop stand)
• [b]H[/b] — Open encyclopedia
• [b]M[/b] — Open world map
• [b]O[/b] — Toggle objectives
• [b]P[/b] — Open pets panel
• [b]G[/b] — Open farming overview
• [b]N[/b] — Open town overview
• [b]L[/b] — Open collections / item compendium
• [b]R[/b] — Repair/restore nearby ruin
• [b]Esc[/b] — Close menus
• [b]`[/b] — Toggle creative panel (creative mode only)

[b][color=#7fc97f]Mouse:[/color][/b]
• [b]Left-click[/b] — Use tool / Attack at cursor position
• [b]Right-click[/b] — Interact / Harvest / Equip armor"""

func _create_settings_content(pw: float) -> VBoxContainer:
	var settings_vbox := VBoxContainer.new()
	settings_vbox.add_theme_constant_override("separation", 12)
	
	# --- Fullscreen toggle ---
	var fs_hbox := HBoxContainer.new()
	fs_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fs_label := Label.new()
	fs_label.text = "Fullscreen"
	fs_label.add_theme_color_override("font_color", Color(0.91, 0.78, 0.29))
	fs_label.add_theme_font_size_override("font_size", 14)
	fs_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fs_hbox.add_child(fs_label)
	
	var fs_check := CheckButton.new()
	fs_check.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	fs_check.button_pressed = (DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN or DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	fs_check.toggled.connect(_on_fullscreen_toggled)
	fs_hbox.add_child(fs_check)
	settings_vbox.add_child(fs_hbox)
	
	# --- Master Volume ---
	var vol_hbox := HBoxContainer.new()
	vol_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var vol_label := Label.new()
	vol_label.text = "Master Volume"
	vol_label.add_theme_color_override("font_color", Color(0.91, 0.78, 0.29))
	vol_label.add_theme_font_size_override("font_size", 14)
	vol_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vol_hbox.add_child(vol_label)
	
	var vol_slider := HSlider.new()
	vol_slider.min_value = 0.0
	vol_slider.max_value = 100.0
	vol_slider.value = _get_master_volume_percent()
	vol_slider.step = 5
	vol_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vol_slider.custom_minimum_size = Vector2(pw * 0.35, 0)
	vol_slider.value_changed.connect(_on_master_volume_changed)
	vol_hbox.add_child(vol_slider)
	
	var vol_value := Label.new()
	vol_value.text = "%d%%" % _get_master_volume_percent()
	vol_value.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
	vol_value.add_theme_font_size_override("font_size", 13)
	vol_value.custom_minimum_size = Vector2(40, 0)
	vol_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vol_slider.value_changed.connect(func(v: float): vol_value.text = "%d%%" % v)
	vol_hbox.add_child(vol_value)
	settings_vbox.add_child(vol_hbox)
	
	return settings_vbox

func _on_fullscreen_toggled(enabled: bool) -> void:
	if enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _get_master_volume_percent() -> float:
	var master_idx := AudioServer.get_bus_index("Master")
	if master_idx < 0:
		return 100.0
	var db := AudioServer.get_bus_volume_db(master_idx)
	# Map -40 dB → 0%, 0 dB → 100%
	return clamp((db + 40.0) / 40.0 * 100.0, 0.0, 100.0)

func _on_master_volume_changed(value: float) -> void:
	var master_idx := AudioServer.get_bus_index("Master")
	if master_idx < 0:
		return
	# Map 0% → -40 dB, 100% → 0 dB
	var db := (value / 100.0) * 40.0 - 40.0
	AudioServer.set_bus_volume_db(master_idx, db)

## Handle Escape key to close menu
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		if _info_panel:
			_close_info_panel()
		else:
			_close()
