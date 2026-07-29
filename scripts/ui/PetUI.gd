extends CanvasLayer

## UI panel for managing pets — view owned pets, equip/unequip, see stats.

var is_open: bool = false

@onready var dim: ColorRect = $Dim
@onready var panel: Control = $Panel
@onready var title_label: Label = $Panel/VBoxContainer/Title
@onready var pet_container: VBoxContainer = $Panel/VBoxContainer/ScrollContainer/PetList
@onready var stats_label: RichTextLabel = $Panel/VBoxContainer/StatsLabel
@onready var empty_label: Label = $Panel/VBoxContainer/EmptyLabel
@onready var close_button: Button = $Panel/VBoxContainer/CloseButton

# Prebuilt pet-row scenes are stored here for reuse
var _pet_rows: Dictionary = {}  # pet_id -> PetRow (HBoxContainer)

# Rename dialog (created once and reused)
var _rename_dialog: AcceptDialog = null
var _renaming_pet_id: String = ""
var _rename_line_edit: LineEdit = null


func _ready() -> void:
	add_to_group("pet_ui")
	close_button.pressed.connect(close)
	PetManager.active_pet_changed.connect(_on_active_pet_changed)
	PetManager.pet_unlocked.connect(_on_pet_unlocked)
	PetManager.pet_name_changed.connect(_on_pet_name_changed)
	_build_rename_dialog()


func _unhandled_input(event: InputEvent) -> void:
	# Opening is handled by Main.gd P key; we only close via Escape here
	if is_open and event.is_action_pressed("close_menu"):
		close()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func open() -> void:
	if is_open:
		return
	is_open = true
	AudioManager.play(AudioManager.Sound.MENU_OPEN)
	dim.visible = true
	panel.visible = true
	panel.modulate.a = 0.0
	var tween := panel.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(panel, "modulate:a", 1.0, 0.2)
	_refresh()


func close() -> void:
	if not is_open:
		return
	is_open = false
	AudioManager.play(AudioManager.Sound.MENU_CLOSE)
	var tween := panel.create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(panel, "modulate:a", 0.0, 0.15)
	tween.tween_callback(func():
		dim.visible = false
		panel.visible = false
	)


func _refresh() -> void:
	# Clear existing rows
	for child in pet_container.get_children():
		child.queue_free()
	_pet_rows.clear()
	
	var owned: Array[String] = PetManager.owned_pets
	if owned.is_empty():
		empty_label.visible = true
		stats_label.text = ""
		return
	
	empty_label.visible = false
	
	# Build a row for each owned pet
	for pid in owned:
		var data: Dictionary = PetManager.get_pet_data(pid)
		if data == null or data.is_empty():
			continue
		
		var row := HBoxContainer.new()
		row.name = "Row_" + pid
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		# Pet name + description
		var name_label := Label.new()
		name_label.text = PetManager.get_pet_display_name(pid)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.custom_minimum_size = Vector2(80, 0)
		row.add_child(name_label)
		
		# Bonus description
		var bonus_text: String = _bonus_string(data)
		var bonus_label := Label.new()
		bonus_label.text = bonus_text
		bonus_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bonus_label.custom_minimum_size = Vector2(120, 0)
		bonus_label.set("theme_override_colors/font_color", Color(0.8, 0.8, 0.5))
		row.add_child(bonus_label)
		
		# Rename button
		var rename_btn := Button.new()
		rename_btn.text = "✏️"
		rename_btn.tooltip_text = "Rename this pet"
		rename_btn.pressed.connect(_on_rename_pressed.bind(pid))
		row.add_child(rename_btn)
		
		# Equip/Unequip button
		var btn := Button.new()
		var is_active: bool = (pid == PetManager.active_pet_id)
		btn.text = "Equipped" if is_active else "Equip"
		btn.disabled = is_active
		btn.pressed.connect(_on_equip_pressed.bind(pid, btn))
		row.add_child(btn)
		
		pet_container.add_child(row)
		_pet_rows[pid] = row
	
	_update_stats()


func _bonus_string(data: Dictionary) -> String:
	var bt: String = data["bonus_type"]
	var bv: float = data["bonus_val"]
	match bt:
		"combat":
			return "+%.0f combat dmg" % bv
		"loot":
			return "+%.0f%% rare loot" % (bv * 100.0)
		"gather":
			return "+%.0f%% gather yield" % (bv * 100.0)
		"scout":
			return "Map reveal"
		"defense":
			return "+%.0f defense" % bv
		"growth":
			return "+%.0f%% crop growth" % (bv * 100.0)
	return bt


func _update_stats() -> void:
	var active: Dictionary = PetManager.get_active_pet_data()
	if not active.is_empty():
		var display_name: String = PetManager.get_pet_display_name(PetManager.active_pet_id)
		stats_label.text = "[b]Active:[/b] " + display_name + "\n"
		stats_label.text += active["desc"]
	else:
		stats_label.text = "No pet equipped."
	stats_label.text += "\n\n[color=#aaaaaa]Press [b]P[/b] to toggle this panel."


func _on_equip_pressed(pet_id: String, _btn: Button) -> void:
	PetManager.active_pet_id = pet_id
	ToastNotification.show_toast(
		PetManager.get_pet_display_name(pet_id) + " is now your active pet!",
		ToastNotification.ToastType.SUCCESS
	)
	_refresh()


# --------------------------------------------------------------------------
# Rename dialog
# --------------------------------------------------------------------------

func _build_rename_dialog() -> void:
	_rename_dialog = AcceptDialog.new()
	_rename_dialog.title = "Rename Pet"
	_rename_dialog.dialog_text = "Enter a new name for your pet:"
	_rename_dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_SCREEN_WITH_MOUSE_FOCUS
	_rename_dialog.close_requested.connect(_close_rename_dialog)
	_rename_dialog.confirmed.connect(_confirm_rename)
	add_child(_rename_dialog)
	
	_rename_line_edit = LineEdit.new()
	_rename_line_edit.custom_minimum_size = Vector2(250, 0)
	_rename_line_edit.placeholder_text = "Enter a name..."
	_rename_line_edit.max_length = 24
	# Allow pressing Enter in the LineEdit to confirm
	_rename_line_edit.text_submitted.connect(_on_rename_text_submitted)
	_rename_dialog.add_child(_rename_line_edit)


func _on_rename_pressed(pet_id: String) -> void:
	_renaming_pet_id = pet_id
	var current_name: String = PetManager.get_pet_display_name(pet_id)
	_rename_line_edit.text = current_name
	_rename_line_edit.select_all()
	_rename_dialog.popup_centered()
	# Give focus to the LineEdit after the popup opens
	_rename_line_edit.grab_focus.call_deferred()


func _on_rename_text_submitted(_text: String) -> void:
	_confirm_rename()


func _confirm_rename() -> void:
	if _renaming_pet_id.is_empty():
		return
	var new_name: String = _rename_line_edit.text.strip_edges()
	var final_name: String = PetManager.rename_pet(_renaming_pet_id, new_name)
	if new_name.is_empty():
		# Reset to default
		pass
	ToastNotification.show_toast(
		"Pet renamed to " + final_name + "!",
		ToastNotification.ToastType.INFO
	)
	_renaming_pet_id = ""
	_rename_dialog.hide()
	_refresh()


func _close_rename_dialog() -> void:
	_renaming_pet_id = ""
	_rename_dialog.hide()


func _on_pet_name_changed(_pet_id: String, _display_name: String) -> void:
	if is_open:
		_refresh()


func _on_active_pet_changed(_pet_id: String) -> void:
	if is_open:
		_refresh()


func _on_pet_unlocked(_pet_id: String) -> void:
	if is_open:
		_refresh()
