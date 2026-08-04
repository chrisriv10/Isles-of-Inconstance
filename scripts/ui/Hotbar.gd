extends Control
class_name Hotbar

## Quick-slot bar showing tools and inventory hotbar items.
## Slots 0-1: Hoe/Watering Can (always available, keys 1-2).
## Slots 2-9: 8 freely assignable inventory slots (inv slots 0-7, keys 3-0).
## Syncs with Player.active_tool and InventoryManager.

const SLOT_COUNT: int = 10
const SLOT_SIZE: int = 58
const CELL_PAD: int = 4

# UI Style constants
var LIGHT_WOOD: StyleBoxTexture
var DARK_WOOD: StyleBoxTexture
var DARK_SLOT: StyleBoxFlat

static func _make_dark_slot() -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.12, 0.12, 0.12, 0.85)
	s.border_color = Color(0.25, 0.25, 0.25, 1.0)
	s.set_border_width_all(2)
	s.set_corner_radius_all(4)
	return s

var _slots: Array[PanelContainer] = []
var _icon_rects: Array[TextureRect] = []
var _count_labels: Array[Label] = []
var _key_labels: Array[Label] = []

var _tooltip_panel: Panel
var _tooltip_name_label: RichTextLabel
var _tooltip_desc_label: RichTextLabel
var _hovered_slot: int = -1

var _selected_border_color: Color = Color(1.0, 0.9, 0.3, 1.0)   # gold
var _normal_border_color: Color = Color(0.3, 0.3, 0.3, 0.6)
var _boss_bait_border_color: Color = Color(0.85, 0.3, 0.95, 1.0)  # purple glow for boss bait

# IDs of boss bait items
const _BOSS_BAIT_IDS: Array[String] = ["soulberry_pie", "golden_hay_bale", "nectar_brew", "essence_of_inconstance"]

# Cached icons for fallback tool display
var _hoe_tex: Texture2D
var _water_tex: Texture2D
var _placeholder_tex: Texture2D

var _player_ref: Node                                  # cached Player node


func _ready() -> void:
	LIGHT_WOOD = preload("res://resources/ui/wood_panel.tres")
	DARK_WOOD = preload("res://resources/ui/dark_wood_panel.tres")
	DARK_SLOT = _make_dark_slot()
	# Load pre-generated icons
	_hoe_tex = load("res://assets/generated/icon_hoe_frame_0.png")
	_water_tex = load("res://assets/generated/icon_watering_can_frame_0.png")
	if not _hoe_tex:
		_hoe_tex = _make_placeholder(Color(0.6, 0.4, 0.2))
	if not _water_tex:
		_water_tex = _make_placeholder(Color(0.2, 0.5, 0.9))
	_placeholder_tex = _make_placeholder(Color(0.3, 0.3, 0.3))

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
		_refresh_all()
	else:
		call_deferred("_connect_player")


# ---------------------------------------------------------------------------
# UI construction
# ---------------------------------------------------------------------------
func _build_ui() -> void:
	# Container: background panel - light wood with dark wood border
	var bg := LIGHT_WOOD.duplicate()
	bg.modulate_color = Color(1, 1, 1, 0.6)

	var panel := Panel.new()
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.add_theme_stylebox_override("panel", bg)
	add_child(panel)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", CELL_PAD / 2)
	panel.add_child(hbox)

	mouse_filter = Control.MOUSE_FILTER_IGNORE

	for i in range(SLOT_COUNT):
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		slot.mouse_filter = Control.MOUSE_FILTER_STOP   # whole slot clickable, not just icon

		var normal_style := DARK_SLOT
		slot.add_theme_stylebox_override("panel", normal_style)

		# Icon area — clicks are handled by the slot itself (full area clickable)
		var icon_rect := TextureRect.new()
		icon_rect.mouse_filter = Control.MOUSE_FILTER_PASS
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.custom_minimum_size = Vector2(52, 52)
		slot.add_child(icon_rect)
		slot.mouse_entered.connect(_on_slot_mouse_entered.bind(i))
		slot.mouse_exited.connect(_on_slot_mouse_exited.bind(i))
		slot.gui_input.connect(_on_slot_gui_input.bind(i))
		_icon_rects.append(icon_rect)

		# Hotkey label (top-left) — now uses outline for readability over scaled icons
		var key_label := Label.new()
		key_label.text = "0" if i == 9 else str(i + 1)
		key_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.8))
		key_label.add_theme_font_size_override("font_size", 10)
		key_label.add_theme_constant_override("outline_size", 1)
		key_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
		key_label.position = Vector2(3, 0)
		key_label.mouse_filter = Control.MOUSE_FILTER_PASS
		slot.add_child(key_label)
		_key_labels.append(key_label)

		# Count label (top-right)
		var count_label := Label.new()
		count_label.text = ""
		count_label.add_theme_color_override("font_color", Color.WHITE)
		count_label.add_theme_font_size_override("font_size", 11)
		count_label.add_theme_constant_override("outline_size", 1)
		count_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		count_label.size = Vector2(SLOT_SIZE - 6, SLOT_SIZE - 6)
		count_label.position = Vector2(3, 1)
		count_label.mouse_filter = Control.MOUSE_FILTER_PASS
		slot.add_child(count_label)
		_count_labels.append(count_label)

		hbox.add_child(slot)
		_slots.append(slot)

	# Build custom tooltip panel above the hotbar
	_tooltip_panel = Panel.new()
	_tooltip_panel.visible = false
	_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_panel.size = Vector2(240, 70)
	_tooltip_panel.position = Vector2(0, -76)  # above the hotbar
	var tooltip_bg := DARK_WOOD
	_tooltip_panel.add_theme_stylebox_override("panel", tooltip_bg)
	panel.add_child(_tooltip_panel)

	_tooltip_name_label = RichTextLabel.new()
	_tooltip_name_label.bbcode_enabled = true
	_tooltip_name_label.size = Vector2(230, 26)
	_tooltip_name_label.position = Vector2(5, 3)
	_tooltip_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_panel.add_child(_tooltip_name_label)

	_tooltip_desc_label = RichTextLabel.new()
	_tooltip_desc_label.bbcode_enabled = true
	_tooltip_desc_label.size = Vector2(230, 38)
	_tooltip_desc_label.position = Vector2(5, 28)
	_tooltip_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tooltip_desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_panel.add_child(_tooltip_desc_label)


# ---------------------------------------------------------------------------
# Refresh — called on inventory change or tool change
# ---------------------------------------------------------------------------
func _refresh_all() -> void:
	if not is_inside_tree():
		return
	if not _player_ref:
		_connect_player()
		return
	_update_icons()
	_update_highlight()


func _update_icons() -> void:
	for i in range(SLOT_COUNT):
		var icon: Texture2D = null
		var count: int = 0
		var dimmed := false

		var slot_tint := Color.WHITE

		if i <= 1:
			# Slots 0-1: fixed Hoe / Watering Can
			icon = _hoe_tex if i == 0 else _water_tex
		else:
			# Slots 2-9: read from inventory slots 0-7
			var inv_idx := i - 2  # slot2→inv0, slot3→inv1, ..., slot9→inv7
			if inv_idx < InventoryManager.slots.size():
				var sd = InventoryManager.slots[inv_idx]
				if sd is Dictionary:
					var item: ItemData = DataManager.get_item(sd["item_id"])
					if item and item.icon:
						icon = item.icon
					count = sd.get("count", 0)
					# Apply tint for tinted items (berries, flowers, mushrooms)
					slot_tint = sd.get("tint", Color.WHITE)
				else:
					dimmed = true
			else:
				dimmed = true

		_icon_rects[i].texture = icon
		_icon_rects[i].modulate = slot_tint if not dimmed else Color(1, 1, 1, 0.2)
		_count_labels[i].text = "x%d" % count if count > 0 else ""


func _update_highlight() -> void:
	if not _player_ref:
		return

	var active_tool_val: int = _player_ref.active_tool  # Player.Tool enum value
	var active_idx: int = _tool_to_slot_idx(active_tool_val)

	for i in range(SLOT_COUNT):
		var is_active: bool = (i == active_idx)
		var style := DARK_SLOT.duplicate()
		style.set_border_width_all(3 if is_active else 2)
		style.border_color = _normal_border_color
		
		# Use boss bait purple glow if this slot holds a boss bait item
		if is_active and _is_boss_bait_slot(i):
			style.border_color = _boss_bait_border_color
		elif is_active:
			style.border_color = _selected_border_color
		
		_slots[i].add_theme_stylebox_override("panel", style)

func _is_boss_bait_slot(slot_idx: int) -> bool:
	if slot_idx <= 1:
		return false
	var inv_idx := slot_idx - 2
	if inv_idx < InventoryManager.slots.size():
		var sd = InventoryManager.slots[inv_idx]
		if sd is Dictionary:
			var item_id: String = sd.get("item_id", "")
			return item_id in _BOSS_BAIT_IDS
	return false


func _tool_to_slot_idx(tool_val: int) -> int:
	match tool_val:
		1: return 0    # HOE
		2: return 1    # WATERING_CAN
		3: return 2    # HOTBAR_0
		4: return 3    # HOTBAR_1
		5: return 4    # HOTBAR_2
		6: return 5    # HOTBAR_3
		12: return 6   # HOTBAR_4
		13: return 7   # HOTBAR_5
		14: return 8   # HOTBAR_6
		15: return 9   # HOTBAR_7
	return -1


# ---------------------------------------------------------------------------
# Click handling
# ---------------------------------------------------------------------------
func _on_slot_gui_input(event: InputEvent, slot_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not _player_ref:
			return
		_player_ref.set_tool(_slot_to_tool_val(slot_idx))
		get_viewport().set_input_as_handled()


func _slot_to_tool_val(slot_idx: int) -> int:
	match slot_idx:
		0: return 1    # HOE
		1: return 2    # WATERING_CAN
		2: return 3    # HOTBAR_0
		3: return 4    # HOTBAR_1
		4: return 5    # HOTBAR_2
		5: return 6    # HOTBAR_3
		6: return 12   # HOTBAR_4
		7: return 13   # HOTBAR_5
		8: return 14   # HOTBAR_6
		9: return 15   # HOTBAR_7
	return 0           # NONE


# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------
func _on_tool_changed(_tool_name: String) -> void:
	_update_highlight()
	_update_icons()


# ---------------------------------------------------------------------------
# Tooltip helpers
# ---------------------------------------------------------------------------

func _on_slot_mouse_entered(slot_idx: int) -> void:
	_hovered_slot = slot_idx
	_update_tooltip()

func _on_slot_mouse_exited(_slot_idx: int) -> void:
	_hovered_slot = -1
	_tooltip_panel.visible = false

func _update_tooltip() -> void:
	if _hovered_slot < 0 or _hovered_slot >= SLOT_COUNT:
		_tooltip_panel.visible = false
		return

	var item_name := ""
	var item_desc := ""

	if _hovered_slot <= 1:
		# Tool slots
		item_name = "Hoe" if _hovered_slot == 0 else "Watering Can"
		item_desc = "Tills soil / Waters crops"
	else:
		var inv_idx := _hovered_slot - 2
		if inv_idx < InventoryManager.slots.size():
			var sd = InventoryManager.slots[inv_idx]
			if sd is Dictionary:
				var item: ItemData = DataManager.get_item(sd["item_id"])
				if item:
					item_name = item.display_name
					item_desc = item.description
					# Prepend color name for tinted items (berries)
					var slot_tint: Color = sd.get("tint", Color.WHITE)
					if slot_tint != Color.WHITE and item.id == "berry":
						item_name = Bush.get_berry_color_name(slot_tint) + " " + item_name

	if item_name.is_empty():
		_tooltip_panel.visible = false
		return

	# Determine the item ID for this hovered slot
	var hovered_item_id := ""
	if _hovered_slot > 1:
		var inv_idx := _hovered_slot - 2
		if inv_idx < InventoryManager.slots.size():
			var sd = InventoryManager.slots[inv_idx]
			if sd is Dictionary:
				hovered_item_id = sd.get("item_id", "")

	var is_inconstant := item_desc.contains("Inconstant Fruit")
	var is_boss_bait := hovered_item_id in _BOSS_BAIT_IDS
	
	if is_inconstant:
		_tooltip_name_label.text = "[color=#FFD700]✦ %s[/color]" % item_name
		_tooltip_desc_label.text = item_desc
	elif is_boss_bait:
		_tooltip_name_label.text = "[color=#FFD700]★ %s[/color]" % item_name
		_tooltip_desc_label.text = "[color=#A0A0A0]%s[/color]\n[color=#D080FF]★ Use SPACE/click to summon![/color]" % item_desc
	else:
		_tooltip_name_label.text = "[color=#FFE0A0]%s[/color]" % item_name
		_tooltip_desc_label.text = "[color=#A0A0A0]%s[/color]" % item_desc

	# Position tooltip centered over the hovered slot
	var slot_x_offset := _hovered_slot * (SLOT_SIZE + 2)
	_tooltip_panel.position = Vector2(slot_x_offset - 60, -80)
	_tooltip_panel.visible = true


# ---------------------------------------------------------------------------
# Placeholder icon (fallback)
# ---------------------------------------------------------------------------
func _make_placeholder(color: Color) -> Texture2D:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)
