extends Control
class_name Hotbar

## Quick-slot bar showing tools and seed counts.
## 6 slots matching hotkeys 1-6: Hoe, Watering Can, 3 seed slots, selected seed.
## Syncs with Player.active_tool and InventoryManager.

const SLOT_COUNT: int = 6
const SLOT_SIZE: int = 52
const CELL_PAD: int = 4

var _slots: Array[PanelContainer] = []
var _icon_rects: Array[TextureRect] = []
var _count_labels: Array[Label] = []
var _key_labels: Array[Label] = []

var _selected_border_color: Color = Color(1.0, 0.9, 0.3, 1.0)   # gold
var _normal_border_color: Color = Color(0.3, 0.3, 0.3, 0.6)

# Cached icons
var _hoe_tex: Texture2D
var _water_tex: Texture2D
var _seed_tex: Texture2D

var _player_ref: Node                                  # cached Player node
var _proc_crops: Array                                 # procedural crops list


func _ready() -> void:
	# Load pre-generated icons
	_hoe_tex = load("res://assets/generated/icon_hoe_frame_0.png")
	_water_tex = load("res://assets/generated/icon_watering_can_frame_0.png")
	_seed_tex = load("res://assets/generated/icon_seed_default_frame_0.png")
	if not _hoe_tex or not _water_tex:
		_hoe_tex = _make_placeholder(Color(0.6, 0.4, 0.2))
		_water_tex = _make_placeholder(Color(0.2, 0.5, 0.9))
	if not _seed_tex:
		_seed_tex = _make_placeholder(Color(0.2, 0.7, 0.2))

	_build_ui()

	# Connect to player after a short delay
	call_deferred("_connect_player")

	# Listen for inventory changes
	if InventoryManager.changed.is_connected(_refresh_all):
		InventoryManager.changed.disconnect(_refresh_all)
	InventoryManager.changed.connect(_refresh_all)


func _connect_player() -> void:
	_player_ref = get_tree().get_first_node_in_group("player")
	if _player_ref:
		if not _player_ref.active_tool_changed.is_connected(_on_tool_changed):
			_player_ref.active_tool_changed.connect(_on_tool_changed)
		_proc_crops = DataManager.get_procedural_crops()
		_refresh_all()
	else:
		call_deferred("_connect_player")


# ---------------------------------------------------------------------------
# UI construction
# ---------------------------------------------------------------------------
func _build_ui() -> void:
	# Container: background panel
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.0, 0.0, 0.0, 0.6)
	bg.set_corner_radius_all(6)

	var panel := Panel.new()
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.add_theme_stylebox_override("panel", bg)
	add_child(panel)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", CELL_PAD / 2)
	panel.add_child(hbox)

	# Anchor this Control to the bottom of the screen
	anchors_preset = PRESET_BOTTOM_WIDE
	offset_top = -68
	offset_bottom = -12
	mouse_filter = Control.MOUSE_FILTER_PASS

	for i in range(SLOT_COUNT):
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		slot.mouse_filter = Control.MOUSE_FILTER_STOP

		var normal_style := StyleBoxFlat.new()
		normal_style.bg_color = Color(0.15, 0.15, 0.15, 0.85)
		normal_style.set_border_width_all(2)
		normal_style.border_color = _normal_border_color
		normal_style.set_corner_radius_all(4)
		slot.add_theme_stylebox_override("panel", normal_style)

		# Icon area (clickable)
		var icon_rect := TextureRect.new()
		icon_rect.mouse_filter = Control.MOUSE_FILTER_STOP
		icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		icon_rect.custom_minimum_size = Vector2(40, 40)
		icon_rect.gui_input.connect(_on_slot_gui_input.bind(i))
		slot.add_child(icon_rect)
		_icon_rects.append(icon_rect)

		# Hotkey label (top-left)
		var key_label := Label.new()
		key_label.text = str(i + 1)
		key_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.8))
		key_label.add_theme_font_size_override("font_size", 10)
		key_label.position = Vector2(3, 0)
		key_label.mouse_filter = Control.MOUSE_FILTER_PASS
		slot.add_child(key_label)
		_key_labels.append(key_label)

		# Count label (bottom-right)
		var count_label := Label.new()
		count_label.text = ""
		count_label.add_theme_color_override("font_color", Color.WHITE)
		count_label.add_theme_font_size_override("font_size", 11)
		count_label.add_theme_constant_override("outline_size", 1)
		count_label.add_theme_color_override("font_outline_color", Color.BLACK)
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		count_label.size = Vector2(SLOT_SIZE - 6, SLOT_SIZE - 6)
		count_label.position = Vector2(3, 3)
		count_label.mouse_filter = Control.MOUSE_FILTER_PASS
		slot.add_child(count_label)
		_count_labels.append(count_label)

		hbox.add_child(slot)
		_slots.append(slot)


# ---------------------------------------------------------------------------
# Refresh — called on inventory change or tool change
# ---------------------------------------------------------------------------
func _refresh_all() -> void:
	if not is_inside_tree():
		return
	if not _player_ref:
		_connect_player()
		return
	_proc_crops = DataManager.get_procedural_crops()
	_update_icons()
	_update_highlight()


func _update_icons() -> void:
	for i in range(SLOT_COUNT):
		var icon: Texture2D
		var count: int = 0
		var has_content := true

		match i:
			0:  # Hoe — always has content
				icon = _hoe_tex
			1:  # Watering Can — always has content
				icon = _water_tex
			2:  # Seed slot 1
				if _proc_crops.size() > 0:
					icon = _get_seed_icon(_proc_crops[0])
					count = InventoryManager.get_count(_proc_crops[0].seed_item_id)
				if count == 0:
					icon = null
				if _proc_crops.size() <= 0:
					has_content = false
			3:  # Seed slot 2
				if _proc_crops.size() > 1:
					icon = _get_seed_icon(_proc_crops[1])
					count = InventoryManager.get_count(_proc_crops[1].seed_item_id)
				if count == 0:
					icon = null
				if _proc_crops.size() <= 1:
					has_content = false
			4:  # Seed slot 3
				if _proc_crops.size() > 2:
					icon = _get_seed_icon(_proc_crops[2])
					count = InventoryManager.get_count(_proc_crops[2].seed_item_id)
				if count == 0:
					icon = null
				if _proc_crops.size() <= 2:
					has_content = false
			5:  # Selected seed
				if _player_ref and _player_ref.has_method("_get_crop_for_active_slot"):
					var crop = _player_ref._get_crop_for_active_slot()
					if crop != null:
						icon = _get_seed_icon(crop)
						count = InventoryManager.get_count(crop.seed_item_id)
				if count == 0:
					icon = null
				if count == 0 and not _has_selected_seed():
					has_content = false

		_icon_rects[i].texture = icon
		_icon_rects[i].modulate = Color(1, 1, 1, 0.15) if not has_content and i >= 2 else Color.WHITE
		_count_labels[i].text = "x%d" % count if count > 0 else ""


## Returns the seed icon for a crop, falling back to the default seed
## texture if the crop has no custom icon.
func _get_seed_icon(crop_data) -> Texture2D:
	if crop_data == null:
		return _seed_tex
	var seed_item := DataManager.get_item(crop_data.seed_item_id)
	if seed_item and seed_item.icon:
		return seed_item.icon
	return _seed_tex


func _has_selected_seed() -> bool:
	return _player_ref != null and _player_ref.selected_seed_crop_id != ""


func _update_highlight() -> void:
	if not _player_ref:
		return

	var active_tool_val: int = _player_ref.active_tool  # Player.Tool enum value
	var active_idx: int = _tool_to_slot_idx(active_tool_val)

	for i in range(SLOT_COUNT):
		var is_active: bool = (i == active_idx)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.2, 0.2, 0.25, 0.9) if is_active else Color(0.15, 0.15, 0.15, 0.85)
		style.set_border_width_all(3 if is_active else 2)
		style.border_color = _selected_border_color if is_active else _normal_border_color
		style.set_corner_radius_all(4)
		_slots[i].add_theme_stylebox_override("panel", style)


func _tool_to_slot_idx(tool_val: int) -> int:
	match tool_val:
		1: return 0    # HOE
		2: return 1    # WATERING_CAN
		3: return 2    # SEED_SLOT_1
		4: return 3    # SEED_SLOT_2
		5: return 4    # SEED_SLOT_3
		6: return 5    # SEED_SLOT_SELECTED
	return -1


# ---------------------------------------------------------------------------
# Click handling
# ---------------------------------------------------------------------------
func _on_slot_gui_input(event: InputEvent, slot_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not _player_ref or not _player_ref.has_method("set_tool"):
			# Fallback: try direct property + signal
			if _player_ref and _player_ref.has_method("_set_tool"):
				_player_ref._set_tool(_slot_to_tool_val(slot_idx))
			return
		_player_ref.set_tool(_slot_to_tool_val(slot_idx))
		get_viewport().set_input_as_handled()


func _slot_to_tool_val(slot_idx: int) -> int:
	match slot_idx:
		0: return 1    # HOE
		1: return 2    # WATERING_CAN
		2: return 3    # SEED_SLOT_1
		3: return 4    # SEED_SLOT_2
		4: return 5    # SEED_SLOT_3
		5: return 6    # SEED_SLOT_SELECTED
	return 0           # NONE


# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------
func _on_tool_changed(_tool_name: String) -> void:
	_update_highlight()
	_update_icons()


# ---------------------------------------------------------------------------
# Placeholder icon (fallback)
# ---------------------------------------------------------------------------
func _make_placeholder(color: Color) -> Texture2D:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)
