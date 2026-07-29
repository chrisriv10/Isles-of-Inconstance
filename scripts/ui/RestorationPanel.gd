## RestorationPanel — material dump UI for contributing resources to a ruin.
## Shows needed materials, contributed amounts, progress bar, and deposit buttons.

extends Control
class_name RestorationPanel

## Emitted when the panel is closed
signal panel_closed()

var _ruin_id: String = ""
var _building_name: String = ""
var _item_buttons: Dictionary = {}  # item_id -> Button
# TownManager is NOT cached — it's looked up fresh each time via
# _get_town_manager() because the TownManager node is destroyed and
# recreated when a new game starts (World regeneration), leaving any
# stored reference as a freed object.

@onready var title_label: Label = %TitleLabel
@onready var progress_label: Label = %ProgressLabel
@onready var materials_container: VBoxContainer = %MaterialsContainer
@onready var close_button: Button = %CloseButton
@onready var overall_bar: ProgressBar = %OverallBar

func _ready() -> void:
	if close_button:
		close_button.pressed.connect(_on_close)
	
	hide()

## Open the panel for a specific ruin
func open(ruin_id: String, building_name: String) -> void:
	_ruin_id = ruin_id
	_building_name = building_name
	_refresh()
	show()

func close() -> void:
	hide()
	panel_closed.emit()

func _get_town_manager() -> TownManager:
	return get_tree().get_first_node_in_group("town_manager") as TownManager

func _refresh() -> void:
	var tm := _get_town_manager()
	if not tm or _ruin_id.is_empty():
		return
	
	var def: TownManager.RuinDef = tm.get_ruin_def(_ruin_id)
	if not def:
		return
	
	title_label.text = "Restore: %s" % [def.building_name]
	
	# Clear old item rows
	for child in materials_container.get_children():
		child.queue_free()
	_item_buttons.clear()
	
	# Create rows for each needed material
	for item_id: String in def.needs:
		var needed: int = def.needs[item_id]
		var contributed: int = tm.get_contributed(_ruin_id, item_id)
		var remaining: int = needed - contributed
		
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		# Item icon/name
		var item_data := DataManager.get_item(item_id)
		var item_label := Label.new()
		item_label.text = (item_data.display_name if item_data else item_id) + ":"
		item_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_label.add_theme_font_size_override("font_size", 12)
		row.add_child(item_label)
		
		# Count label
		var count_label := Label.new()
		count_label.text = "%d / %d" % [contributed, needed]
		count_label.add_theme_font_size_override("font_size", 12)
		count_label.add_theme_color_override("font_color", Color(0.8, 0.9, 0.6))
		row.add_child(count_label)
		
		# Deposit button
		var deposit_btn := Button.new()
		deposit_btn.text = "Deposit"
		deposit_btn.disabled = remaining <= 0
		deposit_btn.pressed.connect(_on_deposit_pressed.bind(item_id, 1))
		row.add_child(deposit_btn)
		
		# Deposit 10 button
		if remaining > 1:
			var deposit10_btn := Button.new()
			deposit10_btn.text = "x10"
			deposit10_btn.disabled = remaining <= 0
			deposit10_btn.pressed.connect(_on_deposit_pressed.bind(item_id, 10))
			row.add_child(deposit10_btn)
		
		materials_container.add_child(row)
		_item_buttons[item_id] = deposit_btn
	
	# Overall progress
	var pct: float = tm.get_restoration_pct(_ruin_id)
	overall_bar.value = pct * 100.0
	progress_label.text = "%d%% complete" % [int(pct * 100.0)]

func _on_deposit_pressed(item_id: String, count: int) -> void:
	var tm := _get_town_manager()
	if not tm or _ruin_id.is_empty():
		return
	
	# Check inventory BEFORE accepting the contribution. The town's
	# contribute_materials() does not verify player inventory, so we
	# must guard against depositing items the player doesn't have.
	if not InventoryManager.has_item(item_id, count):
		ToastNotification.show_toast("You don't have that item!", ToastNotification.ToastType.WARNING, 2.0)
		return
	
	var contributed: int = tm.contribute_materials(_ruin_id, item_id, count)
	if contributed > 0:
		# Actually remove items from inventory
		InventoryManager.remove_item(item_id, contributed)
		_refresh()
		
		var def: TownManager.RuinDef = tm.get_ruin_def(_ruin_id)
		if def and tm._is_fully_supplied(_ruin_id):
			# Building fully restored!
			ToastNotification.show_toast(
				"%s has been fully restored!" % [def.building_name],
				ToastNotification.ToastType.SUCCESS,
				5.0
			)
			# Close panel after a short delay
			get_tree().create_timer(1.0).timeout.connect(close)
	else:
		ToastNotification.show_toast("You don't have that item!", ToastNotification.ToastType.WARNING, 2.0)

func _on_close() -> void:
	close()

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		accept_event()
