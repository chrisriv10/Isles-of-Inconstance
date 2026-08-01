extends Control
class_name SaveSelectUI

## Save selection screen showing 5 save slots with metadata.
## Lets the player pick a save to continue, delete saves, or start fresh.
## Empty slots can be clicked to start a new game there.
##
## The screen has three modes:
##  - NEW_GAME: shows seed + game-mode options; empty slot starts a new game
##    there (filled slots ask for overwrite confirmation).
##  - CONTINUE: filled slots continue the save; empty slots are inert.
##  - HOST: filled slots emit host_save_selected() so Bootstrap can host that
##    save online; empty slots are inert.

enum Mode { NEW_GAME, CONTINUE, HOST }

signal save_selected(slot_index: int)
signal back_requested()
signal new_save_requested(slot_index: int, seed: int, game_mode: int)
signal host_save_selected(slot_index: int)

const SLOT_COUNT: int = 5
const SAVE_SLOT_NAMES: Array[String] = ["Slot 1", "Slot 2", "Slot 3", "Slot 4", "Slot 5"]

@onready var grid: GridContainer = $Panel/Margin/VBox/Grid
@onready var back_button: Button = $Panel/Margin/VBox/BackButton
@onready var options_box: VBoxContainer = $Panel/Margin/VBox/OptionsBox
@onready var seed_input: LineEdit = $Panel/Margin/VBox/OptionsBox/SeedRow/SeedInput
@onready var random_seed_button: Button = $Panel/Margin/VBox/OptionsBox/SeedRow/RandomSeedButton
@onready var peaceful_btn: Button = $Panel/Margin/VBox/OptionsBox/ModeRow/ModeButtons/PeacefulBtn
@onready var survival_btn: Button = $Panel/Margin/VBox/OptionsBox/ModeRow/ModeButtons/SurvivalBtn
@onready var creative_btn: Button = $Panel/Margin/VBox/OptionsBox/ModeRow/ModeButtons/CreativeBtn
@onready var hardcore_btn: Button = $Panel/Margin/VBox/OptionsBox/ModeRow/ModeButtons/HardcoreBtn
@onready var status_label: Label = $Panel/Margin/VBox/OptionsBox/StatusLabel

# Slot panel references: slot_index -> { panel, name_label, info_label, ts_label, delete_btn, rename_btn }
var _slot_widgets: Array[Dictionary] = []

var _current_mode: Mode = Mode.CONTINUE
var _selected_mode: int = GameManager.GameMode.SURVIVAL


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	random_seed_button.pressed.connect(_on_random_seed_pressed)
	peaceful_btn.pressed.connect(_on_mode_button_pressed.bind(GameManager.GameMode.PEACEFUL))
	survival_btn.pressed.connect(_on_mode_button_pressed.bind(GameManager.GameMode.SURVIVAL))
	creative_btn.pressed.connect(_on_mode_button_pressed.bind(GameManager.GameMode.CREATIVE))
	hardcore_btn.pressed.connect(_on_mode_button_pressed.bind(GameManager.GameMode.HARDCORE))
	_build_slot_grid()


func _on_random_seed_pressed() -> void:
	seed_input.text = str(randi())
	AudioManager.play(AudioManager.Sound.UI_CLICK)


func _on_mode_button_pressed(mode_id: int) -> void:
	_selected_mode = mode_id
	AudioManager.play(AudioManager.Sound.UI_CLICK)


func _build_slot_grid() -> void:
	# Clear any existing children from grid
	for child in grid.get_children():
		child.queue_free()
	_slot_widgets.clear()
	
	grid.columns = 5  # Single row, all 5 slots spread evenly
	
	for i in range(SLOT_COUNT):
		var slot_widget := _create_slot_widget(i)
		grid.add_child(slot_widget.panel)
		_slot_widgets.append(slot_widget)
	
	_refresh_all()


func _create_slot_widget(slot_idx: int) -> Dictionary:
	# Main panel for this slot
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(220, 110)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.1, 0.12, 0.7)
	bg.set_border_width_all(2)
	bg.border_color = Color(0.3, 0.3, 0.35)
	bg.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", bg)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	
	# Slot header row
	var header := HBoxContainer.new()
	
	var slot_label := Label.new()
	slot_label.text = SAVE_SLOT_NAMES[slot_idx]
	slot_label.add_theme_font_size_override("font_size", 14)
	slot_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.85))
	slot_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(slot_label)
	
	# Rename button (pencil icon)
	var rename_btn := Button.new()
	rename_btn.text = "✎"
	rename_btn.custom_minimum_size = Vector2(24, 24)
	rename_btn.add_theme_font_size_override("font_size", 12)
	rename_btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	rename_btn.tooltip_text = "Rename this save"
	rename_btn.visible = false
	rename_btn.pressed.connect(_on_rename_save.bind(slot_idx))
	header.add_child(rename_btn)
	
	# Delete button
	var delete_btn := Button.new()
	delete_btn.text = "X"
	delete_btn.custom_minimum_size = Vector2(24, 24)
	delete_btn.add_theme_font_size_override("font_size", 10)
	delete_btn.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	delete_btn.tooltip_text = "Delete this save"
	delete_btn.visible = false
	delete_btn.pressed.connect(_on_delete_slot.bind(slot_idx))
	header.add_child(delete_btn)
	
	vbox.add_child(header)
	
	# Save name (display name shown below the slot header)
	var name_label := Label.new()
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.9))
	name_label.text = "Empty"
	vbox.add_child(name_label)
	
	# Info line (Day, Money)
	var info_label := Label.new()
	info_label.add_theme_font_size_override("font_size", 10)
	info_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 0.55))
	vbox.add_child(info_label)
	
	# Timestamp line
	var ts_label := Label.new()
	ts_label.add_theme_font_size_override("font_size", 9)
	ts_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 0.4))
	vbox.add_child(ts_label)
	
	# Hint label for empty slots ("Click to start new game")
	var hint_label := Label.new()
	hint_label.add_theme_font_size_override("font_size", 10)
	hint_label.add_theme_color_override("font_color", Color(0.5, 0.7, 0.5, 0.6))
	hint_label.text = "Click to start new game"
	hint_label.visible = false
	vbox.add_child(hint_label)
	
	# Click action — select the slot on left-click
	panel.gui_input.connect(_on_slot_gui_input.bind(slot_idx))
	
	panel.add_child(vbox)
	
	return {
		"panel": panel,
		"name_label": name_label,
		"info_label": info_label,
		"ts_label": ts_label,
		"delete_btn": delete_btn,
		"rename_btn": rename_btn,
		"hint_label": hint_label,
	}


func _refresh_all() -> void:
	for i in range(SLOT_COUNT):
		_refresh_slot(i)


func _refresh_slot(slot_idx: int) -> void:
	var w: Dictionary = _slot_widgets[slot_idx]
	var has_save: bool = SaveManager.has_save_in_slot(slot_idx)
	var bg: StyleBoxFlat = w["panel"].get_theme_stylebox("panel") as StyleBoxFlat
	var name_label: Label = w["name_label"]
	var info_label: Label = w["info_label"]
	var ts_label: Label = w["ts_label"]
	var delete_btn: Button = w["delete_btn"]
	var rename_btn: Button = w["rename_btn"]
	var hint_label: Label = w["hint_label"]
	
	if has_save:
		var info: Dictionary = SaveManager.get_save_slot_info(slot_idx)
		# Show save_name if available, otherwise fall back to player_name
		var display_name: String = info.get("save_name", "")
		if display_name.is_empty():
			display_name = info.get("player_name", "Unknown Farmer")
		name_label.text = display_name
		var day: int = info.get("current_day", 1)
		var money: int = info.get("money", 0)
		var seed: int = info.get("world_seed", 0)
		if _current_mode == Mode.HOST:
			info_label.text = "Day %d  |  $%d  |  Seed %d" % [day, money, seed]
		else:
			info_label.text = "Day %d  |  $%d" % [day, money]
		
		var ts: float = info.get("save_timestamp", 0.0)
		if ts > 0.0:
			var dt: Dictionary = Time.get_datetime_dict_from_unix_time(int(ts))
			ts_label.text = "%04d-%02d-%02d %02d:%02d" % [dt.year, dt.month, dt.day, dt.hour, dt.minute]
		else:
			ts_label.text = ""
		
		bg.bg_color = Color(0.15, 0.15, 0.18, 0.7)
		bg.border_color = Color(0.4, 0.4, 0.5)
		delete_btn.visible = true
		rename_btn.visible = true
		hint_label.visible = false
	else:
		name_label.text = "Empty"
		hint_label.visible = _current_mode == Mode.NEW_GAME
		ts_label.text = ""
		if _current_mode == Mode.CONTINUE:
			info_label.text = "No save"
		elif _current_mode == Mode.HOST:
			info_label.text = "No save"
		else:
			info_label.text = "Start a new game here"
		bg.bg_color = Color(0.12, 0.18, 0.12, 0.7)
		bg.border_color = Color(0.25, 0.35, 0.25)
		delete_btn.visible = false
		rename_btn.visible = false


func _on_slot_gui_input(event: InputEvent, slot_idx: int) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var has_save: bool = SaveManager.has_save_in_slot(slot_idx)
	match _current_mode:
		Mode.NEW_GAME:
			if has_save:
				_confirm_overwrite(slot_idx)
			else:
				_emit_new_save(slot_idx)
		Mode.CONTINUE:
			if has_save:
				SaveManager.current_slot = slot_idx
				_fade_out_and_emit("select", slot_idx)
		Mode.HOST:
			if has_save:
				host_save_selected.emit(slot_idx)


func _emit_new_save(slot_idx: int) -> void:
	var seed: int = seed_input.text.to_int()
	_fade_out_and_emit("new", slot_idx, seed, _selected_mode)


## Ask for confirmation before overwriting a filled slot in NEW_GAME mode.
func _confirm_overwrite(slot_idx: int) -> void:
	var info: Dictionary = SaveManager.get_save_slot_info(slot_idx)
	var display_name: String = info.get("save_name", "")
	if display_name.is_empty():
		display_name = SAVE_SLOT_NAMES[slot_idx]

	var dialog := ConfirmationDialog.new()
	dialog.title = "Overwrite Save"
	dialog.dialog_text = "Start a new game in \"%s\"?\nThe existing save will be deleted." % display_name
	dialog.ok_button_text = "Overwrite"
	dialog.cancel_button_text = "Cancel"
	dialog.exclusive = true
	dialog.min_size = Vector2(320, 120)

	dialog.confirmed.connect(func():
		AudioManager.play(AudioManager.Sound.UI_CLICK)
		_emit_new_save(slot_idx)
	)
	dialog.canceled.connect(func():
		AudioManager.play(AudioManager.Sound.UI_CLICK)
	)

	add_child(dialog)
	dialog.popup_centered()


func _on_rename_save(slot_idx: int) -> void:
	if not SaveManager.has_save_in_slot(slot_idx):
		return
	
	var info: Dictionary = SaveManager.get_save_slot_info(slot_idx)
	var current_name: String = info.get("save_name", "")
	if current_name.is_empty():
		current_name = info.get("player_name", "Unknown Farmer")
	
	# Show a simple rename dialog
	var dialog := AcceptDialog.new()
	dialog.title = "Rename Save"
	dialog.ok_button_text = "Save"
	
	var vbox := VBoxContainer.new()
	var label := Label.new()
	label.text = "Enter a new name for this save:"
	vbox.add_child(label)
	
	var line_edit := LineEdit.new()
	line_edit.text = current_name
	line_edit.select_all()
	line_edit.placeholder_text = "Save name..."
	vbox.add_child(line_edit)
	
	dialog.add_child(vbox)
	dialog.min_size = Vector2(320, 140)
	dialog.confirmed.connect(_on_rename_confirmed.bind(slot_idx, line_edit, dialog))
	dialog.canceled.connect(dialog.queue_free)
	dialog.close_requested.connect(dialog.queue_free)
	
	add_child(dialog)
	dialog.popup_centered()
	
	# Focus the LineEdit after popup
	line_edit.grab_focus.call_deferred()


func _on_rename_confirmed(slot_idx: int, line_edit: LineEdit, dialog: AcceptDialog) -> void:
	var new_name: String = line_edit.text.strip_edges()
	if new_name.is_empty():
		dialog.queue_free()
		return
	
	# Write the new save_name directly to the save file
	var path: String = "user://save_%d.json" % slot_idx
	if not FileAccess.file_exists(path):
		dialog.queue_free()
		return
	
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		dialog.queue_free()
		return
	
	var json_string := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	if json.parse(json_string) != OK:
		dialog.queue_free()
		return
	
	var save_data: Dictionary = json.data
	save_data["save_name"] = new_name
	
	# Write back
	var new_json := JSON.stringify(save_data)
	var write_file := FileAccess.open(path, FileAccess.WRITE)
	if write_file:
		write_file.store_string(new_json)
		write_file.close()
	
	dialog.queue_free()
	
	# Refresh the display
	_refresh_slot(slot_idx)
	AudioManager.play(AudioManager.Sound.UI_CLICK)


func _on_delete_slot(slot_idx: int) -> void:
	# Look up the save display name for the confirmation text
	var info: Dictionary = SaveManager.get_save_slot_info(slot_idx)
	var display_name: String = info.get("save_name", "")
	if display_name.is_empty():
		display_name = SAVE_SLOT_NAMES[slot_idx]

	# Build confirmation dialog
	var dialog := ConfirmationDialog.new()
	dialog.title = "Delete Save"
	dialog.dialog_text = "Delete \"%s\"?\nThis cannot be undone." % display_name
	dialog.ok_button_text = "Delete"
	dialog.cancel_button_text = "Cancel"
	dialog.exclusive = true
	dialog.min_size = Vector2(320, 120)

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

	# Style the Delete button to stand out (red-ish accent)
	var ok_btn := dialog.get_ok_button()
	if ok_btn:
		ok_btn.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		ok_btn.add_theme_stylebox_override("normal", btn_style_normal)
		ok_btn.add_theme_stylebox_override("hover", btn_style_hover)
	var cancel_btn := dialog.get_cancel_button()
	if cancel_btn:
		cancel_btn.add_theme_color_override("font_color", Color(0.8, 0.7, 0.6))
		cancel_btn.add_theme_stylebox_override("normal", btn_style_normal)
		cancel_btn.add_theme_stylebox_override("hover", btn_style_hover)

	dialog.confirmed.connect(func():
		SaveManager.delete_save_in_slot(slot_idx)
		_refresh_slot(slot_idx)
		AudioManager.play(AudioManager.Sound.UI_CLICK)
	)
	dialog.canceled.connect(func():
		AudioManager.play(AudioManager.Sound.UI_CLICK)
	)

	add_child(dialog)
	dialog.popup_centered()


func _on_back_pressed() -> void:
	AudioManager.play(AudioManager.Sound.UI_CLICK)
	_fade_out_and_emit("back")


func _fade_out_and_emit(action: String, slot_idx: int = -1, seed: int = 0, game_mode: int = 0) -> void:
	# Disable all inputs
	for w: Dictionary in _slot_widgets:
		var panel_ctrl: Control = w["panel"]
		panel_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back_button.disabled = true
	
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.tween_callback(func():
		match action:
			"select":
				save_selected.emit(slot_idx)
			"new":
				new_save_requested.emit(slot_idx, seed, game_mode)
			"back":
				back_requested.emit()
	)


## Show this panel with a fade-in.
## mode controls which slot actions are available (see Mode enum).
func show_ui(p_mode: Mode = Mode.CONTINUE) -> void:
	_current_mode = p_mode
	visible = true
	modulate.a = 0.0
	back_button.disabled = false
	options_box.visible = _current_mode == Mode.NEW_GAME
	status_label.visible = _current_mode == Mode.HOST
	if _current_mode == Mode.HOST:
		status_label.text = "Pick a save to host"
	_refresh_all()
	# Re-enable slot panel mouse filters (they were set to IGNORE by fade-out)
	for w: Dictionary in _slot_widgets:
		var panel_ctrl: Control = w["panel"]
		panel_ctrl.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "modulate:a", 1.0, 0.25)


func close_ui() -> void:
	visible = false


## Public helper: show a status line (e.g. the host's join code) at the top
## of the options area. Visible whenever the screen is in HOST mode.
func set_status(text: String) -> void:
	status_label.text = text
	status_label.visible = true
