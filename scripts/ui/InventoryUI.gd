extends CanvasLayer
class_name InventoryUI

## Minecraft-style inventory: grid of slots showing all carried items.
## Left-click to pick up a stack, click another slot to place it.
## Right-click to view an item's description, equip armor, pick up half,
## or place one from a held stack.
## The first row (slots 0-5) is the hotbar — visually separated with
## a gold highlight on the active slot.
## Right sidebar shows the right-clicked item's icon + item info.

const SLOT_SIZE: float = 48.0
const HOTBAR_COUNT: int = 8  # slots 0-7 are the hotbar (inv slots 0-7)

@onready var dim: ColorRect = $Dim
@onready var panel: PanelContainer = $Panel
@onready var capacity_label: Label = %CapacityLabel
@onready var grid: GridContainer = %Grid
@onready var drag_icon: TextureRect = %DragIcon

# Right sidebar nodes
@onready var portrait_rect: TextureRect = %PortraitTexture
@onready var item_name_label: Label = %ItemNameLabel
@onready var item_category_label: Label = %ItemCategoryLabel
@onready var item_description_label: RichTextLabel = %ItemDescriptionLabel
@onready var use_button: Button = %UseButton
var _sell_price_label: Label

var is_open: bool = false

# Slot UI children — indexed same as InventoryManager.slots
var _slot_panels: Array[PanelContainer] = []
var _slot_icon_rects: Array[TextureRect] = []
var _slot_count_labels: Array[Label] = []

# Drag state
var _held_item_id: String = ""
var _held_count: int = 0
var _held_from_idx: int = -1  # -1 = not dragging

# Hover state
var _hovered_slot_idx: int = -1  # -1 = not hovering any slot

# Selected/pinned state — the item whose description is shown until another is clicked
var _selected_slot_idx: int = -1  # -1 = nothing selected

# Placeholder icon for items with no texture
var _placeholder_tex: Texture2D


func _ready() -> void:
	add_to_group("inventory_ui")
	InventoryManager.changed.connect(_on_inventory_changed)
	InventoryManager.capacity_changed.connect(_on_capacity_changed)
	_placeholder_tex = _make_placeholder_icon()
	_build_slots()
	_restructure_layout()
	_style_right_panel()
	# Connect discard button (deferred to ensure scene is fully parsed)
	call_deferred("_connect_discard_button")
	call_deferred("_add_sort_button")
	
	# Connect to player for active tool
	var player := get_tree().get_first_node_in_group("player")
	if player:
		if player.has_signal("active_tool_changed"):
			player.active_tool_changed.connect(_on_player_tool_changed)
	else:
		await get_tree().process_frame
		player = get_tree().get_first_node_in_group("player")
		if player and player.has_signal("active_tool_changed"):
			player.active_tool_changed.connect(_on_player_tool_changed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_inventory"):
		if Input.is_key_pressed(KEY_SHIFT):
			return
		toggle()
		get_viewport().set_input_as_handled()
	elif is_open and event.is_action_pressed("close_menu"):
		close()
		get_viewport().set_input_as_handled()
	elif is_open and event is InputEventKey and event.pressed and event.keycode == KEY_DELETE:
		_discard_held_or_hovered()
		get_viewport().set_input_as_handled()
	elif is_open and event is InputEventKey and event.pressed and event.keycode == KEY_E:
		_equip_hovered_armor()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


var _hint_inventory_shown: bool = false

func open() -> void:
	is_open = true
	AudioManager.play(AudioManager.Sound.MENU_OPEN)
	_selected_slot_idx = -1
	_clear_item_info()
	_hovered_slot_idx = -1
	dim.visible = true
	panel.visible = true
	# Show inventory tutorial hint once
	if not _hint_inventory_shown:
		_hint_inventory_shown = true
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_inventory_hint"):
			hud.show_inventory_hint()
	# Fade-in only; position tween breaks anchored panels
	panel.modulate.a = 0.0
	var tween := panel.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(panel, "modulate:a", 1.0, 0.25)
	_refresh_all()
	_update_tool_highlight()
	_update_item_info()


func close() -> void:
	is_open = false
	AudioManager.play(AudioManager.Sound.MENU_CLOSE)
	_selected_slot_idx = -1
	_drop_held_stack()
	var tween := panel.create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(panel, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func():
		dim.visible = false
		panel.visible = false
	)


func _on_close_pressed() -> void:
	close()

func _on_discard_pressed() -> void:
	_discard_held_or_hovered()

## Discard the held stack, or if not holding, discard the hovered stack.
func _discard_held_or_hovered() -> void:
	if _held_from_idx >= 0:
		# Drop the entire held stack
		InventoryManager.slots[_held_from_idx] = null
		_clear_held()
		InventoryManager.changed.emit()
	elif _hovered_slot_idx >= 0 and _hovered_slot_idx < InventoryManager.slots.size():
		# Discard the hovered stack (right-click to clear)
		var slot_data = InventoryManager.slots[_hovered_slot_idx]
		if slot_data != null:
			InventoryManager.slots[_hovered_slot_idx] = null
			InventoryManager.changed.emit()


# ---------------------------------------------------------------------------
# Slot UI building
# ---------------------------------------------------------------------------
func _build_slots() -> void:
	# Clear old slots
	for child in grid.get_children():
		child.queue_free()
	_slot_panels.clear()
	_slot_icon_rects.clear()
	_slot_count_labels.clear()
	
	# Style for hotbar row separators
	var hotbar_style := StyleBoxFlat.new()
	hotbar_style.bg_color = Color(0.15, 0.15, 0.15, 0.85)
	hotbar_style.set_border_width_all(2)
	hotbar_style.border_color = Color(0.25, 0.2, 0.12)  # slightly warm border
	hotbar_style.set_corner_radius_all(4)
	
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.12, 0.12, 0.12, 0.85)
	normal_style.set_border_width_all(2)
	normal_style.border_color = Color(0.25, 0.25, 0.25)
	normal_style.set_corner_radius_all(4)
	
	for i in range(InventoryManager.capacity):
		var is_hotbar := i < HOTBAR_COUNT
		
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.add_theme_stylebox_override("panel", hotbar_style if is_hotbar else normal_style)
		slot.set_meta("slot_index", i)
		
		# Click + hover handlers
		slot.gui_input.connect(_on_slot_gui_input.bind(i))
		slot.mouse_entered.connect(_on_slot_mouse_entered.bind(i))
		slot.mouse_exited.connect(_on_slot_mouse_exited.bind(i))
		
		# Icon
		var icon_rect := TextureRect.new()
		icon_rect.mouse_filter = Control.MOUSE_FILTER_PASS
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.custom_minimum_size = Vector2(40, 40)
		icon_rect.texture = null
		slot.add_child(icon_rect)
		_slot_icon_rects.append(icon_rect)
		
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
		_slot_count_labels.append(count_label)
		
		grid.add_child(slot)
		_slot_panels.append(slot)
	
	# Build armor slots BEFORE refresh so _refresh_armor_slots() has valid slots
	_build_armor_slots()
	
	_refresh_all()


# ---------------------------------------------------------------------------
# Right sidebar styling
# ---------------------------------------------------------------------------
func _restructure_layout() -> void:
	# Scene now has the correct layout natively (MainVBox > SideBySide + ItemInfo).
	# This function just applies styling to the item info panel.
	var item_info: PanelContainer = $Panel/Margin/MainVBox/ItemInfo
	
	# Style the item info panel
	var info_bg := StyleBoxFlat.new()
	info_bg.bg_color = Color(0.08, 0.08, 0.08, 0.9)
	info_bg.set_border_width_all(2)
	info_bg.border_color = Color(0.2, 0.2, 0.25)
	info_bg.set_corner_radius_all(4)
	item_info.add_theme_stylebox_override("panel", info_bg)
	
	# Update ItemNameLabel for autowrap
	item_name_label.custom_minimum_size = Vector2(80, 0)
	
	# Update InfoMargin margins
	var info_margin: MarginContainer = item_info.get_node("InfoMargin")
	info_margin.add_theme_constant_override("margin_left", 8)
	info_margin.add_theme_constant_override("margin_top", 8)
	info_margin.add_theme_constant_override("margin_right", 8)
	info_margin.add_theme_constant_override("margin_bottom", 8)

func _style_right_panel() -> void:
	# Player portrait background
	var portrait_bg := StyleBoxFlat.new()
	portrait_bg.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	portrait_bg.set_border_width_all(2)
	portrait_bg.border_color = Color(0.35, 0.3, 0.2)
	portrait_bg.set_corner_radius_all(4)
	var portrait_panel := portrait_rect.get_parent().get_parent() as PanelContainer
	if portrait_panel:
		portrait_panel.add_theme_stylebox_override("panel", portrait_bg)
	
	# Sell price label (below UseButton)
	_sell_price_label = Label.new()
	_sell_price_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.4, 0.85))
	_sell_price_label.add_theme_font_size_override("font_size", 11)
	_sell_price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_sell_price_label.visible = false
	var info_layout: VBoxContainer = item_description_label.get_parent() as VBoxContainer
	if not info_layout:
		info_layout = use_button.get_parent() as VBoxContainer if use_button else null
	if info_layout:
		info_layout.add_child(_sell_price_label)
		info_layout.move_child(_sell_price_label, info_layout.get_child_count())
	
	# Label styling
	item_name_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.9))
	item_name_label.add_theme_font_size_override("font_size", 14)
	item_category_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.5, 0.8))
	item_category_label.add_theme_font_size_override("font_size", 11)
	item_description_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 0.75))
	item_description_label.add_theme_font_size_override("font_size", 12)
	
	# Default text state
	_clear_item_info()


# ── Minecraft-style armor slots ──
# 4 dedicated equipment slots in the right column, each with a background
# icon showing the armor type. Visual design inspired by Minecraft's
# inventory UI where empty slots show what belongs there.

var _armor_panel: PanelContainer         # the outer armor panel container (for cleanup)
var _armor_slots: Dictionary = {}       # slot_name -> PanelContainer (the clickable slot)
var _armor_icon_rects: Dictionary = {}  # slot_name -> TextureRect (equipped item icon)
var _armor_bg_rects: Dictionary = {}    # slot_name -> TextureRect (ghost bg icon)
var _armor_stat_labels: Dictionary = {} # slot_name -> Label (defense value per piece)
var _defense_total_label: Label          # shows total defense below armor grid

const ARMOR_SLOT_NAMES: Array[String] = ["helmet", "chestplate", "leggings", "boots", "accessory"]
const ARMOR_SLOT_LABELS: Dictionary = {
	"helmet": "Helmet",
	"chestplate": "Chestplate",
	"leggings": "Leggings",
	"boots": "Boots",
	"accessory": "Accessory",
}
const ARMOR_SLOT_ORDER: Array[String] = ["helmet", "chestplate", "leggings", "boots", "accessory"]

# Background icons for each slot type (ghost images shown when empty)
var _armor_bg_icons: Dictionary = {}

func _preload_armor_bg_icons() -> void:
	_armor_bg_icons["helmet"] = load("res://assets/generated/slot_helmet_frame_0.png")
	_armor_bg_icons["chestplate"] = load("res://assets/generated/slot_chestplate_frame_0.png")
	_armor_bg_icons["leggings"] = load("res://assets/generated/slot_leggings_frame_0.png")
	_armor_bg_icons["boots"] = load("res://assets/generated/slot_boots_frame_0.png")
	_armor_bg_icons["accessory"] = load("res://assets/generated/slot_accessory_frame_0.png")


func _build_armor_slots() -> void:
	_preload_armor_bg_icons()
	
	# Find the right column container by unique name
	var right_col: VBoxContainer = %RightCol as VBoxContainer
	if not right_col:
		return
	
	# Remove old armor panel to prevent duplicates on capacity upgrades
	if _armor_panel:
		# Disconnect to avoid duplicate signal connections
		if GameManager.armor_changed.is_connected(_on_armor_changed):
			GameManager.armor_changed.disconnect(_on_armor_changed)
		right_col.remove_child(_armor_panel)
		_armor_panel.queue_free()
	
	var armor_panel := PanelContainer.new()
	_armor_panel = armor_panel
	
	var armor_bg := StyleBoxFlat.new()
	armor_bg.bg_color = Color(0.08, 0.08, 0.08, 0.85)
	armor_bg.set_border_width_all(2)
	armor_bg.border_color = Color(0.3, 0.25, 0.35)
	armor_bg.set_corner_radius_all(4)
	armor_panel.add_theme_stylebox_override("panel", armor_bg)
	
	var armor_vbox := VBoxContainer.new()
	armor_vbox.add_theme_constant_override("separation", 4)
	
	# ── Title row: "Armor" + Total Defense ──
	var title_row := HBoxContainer.new()
	var title := Label.new()
	title.text = "Armor"
	title.add_theme_color_override("font_color", Color(0.7, 0.5, 0.9))
	title.add_theme_font_size_override("font_size", 12)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	_defense_total_label = Label.new()
	_defense_total_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5, 0.9))
	_defense_total_label.add_theme_font_size_override("font_size", 11)
	_defense_total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_defense_total_label.text = ""
	
	title_row.add_child(title)
	title_row.add_child(_defense_total_label)
	armor_vbox.add_child(title_row)
	
	# ── Slot background style ──
	var slot_bg := StyleBoxFlat.new()
	slot_bg.bg_color = Color(0.12, 0.10, 0.15, 0.9)
	slot_bg.set_border_width_all(2)
	slot_bg.border_color = Color(0.35, 0.25, 0.45)
	slot_bg.set_corner_radius_all(4)
	
	# Hovered slot border color
	var slot_hover := StyleBoxFlat.new()
	slot_hover.bg_color = Color(0.15, 0.12, 0.20, 0.95)
	slot_hover.set_border_width_all(2)
	slot_hover.border_color = Color(0.7, 0.5, 0.9, 0.8)
	slot_hover.set_corner_radius_all(4)
	
	for slot_name: String in ARMOR_SLOT_ORDER:
		# ── Slot container (clickable area) ──
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(48, 48)
		slot.size_flags_horizontal = 0
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.add_theme_stylebox_override("panel", slot_bg)
		slot.set_meta("slot_name", slot_name)
		slot.gui_input.connect(_on_armor_slot_gui_input.bind(slot_name))
		slot.mouse_entered.connect(_on_armor_slot_hover.bind(slot_name, true))
		slot.mouse_exited.connect(_on_armor_slot_hover.bind(slot_name, false))
		
		# Background ghost icon (faded armor piece silhouette)
		var bg_rect := TextureRect.new()
		bg_rect.mouse_filter = Control.MOUSE_FILTER_PASS
		bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		bg_rect.custom_minimum_size = Vector2(44, 44)
		bg_rect.texture = _armor_bg_icons.get(slot_name)
		bg_rect.modulate = Color(0.6, 0.6, 0.6, 0.2)
		slot.add_child(bg_rect)
		_armor_bg_rects[slot_name] = bg_rect
		
		# Equipped item icon (stacked on top of bg, same position)
		var icon_rect := TextureRect.new()
		icon_rect.mouse_filter = Control.MOUSE_FILTER_PASS
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.custom_minimum_size = Vector2(44, 44)
		icon_rect.texture = null
		slot.add_child(icon_rect)
		_armor_icon_rects[slot_name] = icon_rect
		
		# Defense overlay (small number, bottom-right corner)
		var stat_label := Label.new()
		stat_label.text = ""
		stat_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
		stat_label.add_theme_font_size_override("font_size", 10)
		stat_label.add_theme_constant_override("outline_size", 1)
		stat_label.add_theme_color_override("font_outline_color", Color.BLACK)
		stat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		stat_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		stat_label.size = Vector2(30, 30)
		stat_label.position = Vector2(3, 3)
		stat_label.mouse_filter = Control.MOUSE_FILTER_PASS
		slot.add_child(stat_label)
		_armor_stat_labels[slot_name] = stat_label
		
		armor_vbox.add_child(slot)
		_armor_slots[slot_name] = slot
	
	armor_panel.add_child(armor_vbox)
	
	# Insert after PlayerPortrait (index 0), before ItemInfo (last)
	var info_idx := right_col.get_child_count() - 1
	right_col.add_child(armor_panel)
	right_col.move_child(armor_panel, info_idx)
	
	# Listen for armor changes to refresh display
	if not GameManager.armor_changed.is_connected(_on_armor_changed):
		GameManager.armor_changed.connect(_on_armor_changed)


## Visual hover feedback on armor slots.
## Shows a green highlight when dragging a compatible armor piece over a slot.
func _on_armor_slot_hover(slot_name: String, hovering: bool) -> void:
	var slot: PanelContainer = _armor_slots.get(slot_name)
	if not slot:
		return
	
	# Determine if we're dragging an item that matches this slot
	var is_compatible_drag: bool = false
	if _held_from_idx >= 0 and not _held_item_id.is_empty() and hovering:
		var drag_slot: String = GameManager._armor_slot_for(_held_item_id)
		is_compatible_drag = (drag_slot == slot_name)
	
	var bg: Color
	var border: Color
	
	if is_compatible_drag:
		# Green highlight to show "drop here to equip"
		bg = Color(0.12, 0.25, 0.15, 0.95)
		border = Color(0.4, 1.0, 0.4, 0.9)
	elif hovering:
		bg = Color(0.15, 0.12, 0.20, 0.95)
		border = Color(0.7, 0.5, 0.9, 0.8)
	else:
		bg = Color(0.12, 0.10, 0.15, 0.9)
		border = Color(0.35, 0.25, 0.45)
	
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_border_width_all(2)
	style.border_color = border
	style.set_corner_radius_all(4)
	slot.add_theme_stylebox_override("panel", style)


## Refresh armor slot displays — shows equipped item + defense values
func _refresh_armor_slots() -> void:
	if not GameManager:
		return
	
	var total_defense: int = 0
	for slot_name: String in ARMOR_SLOT_ORDER:
		var item_id: String = GameManager.equipped_armor.get(slot_name, "")
		var icon_rect: TextureRect = _armor_icon_rects.get(slot_name)
		var bg_rect: TextureRect = _armor_bg_rects.get(slot_name)
		var stat_label: Label = _armor_stat_labels.get(slot_name)
		
		if item_id.is_empty():
			# Empty slot — show ghost background, hide item icon
			if icon_rect:
				icon_rect.texture = null
			if bg_rect:
				bg_rect.modulate = Color(0.6, 0.6, 0.6, 0.2)
			if stat_label:
				stat_label.text = ""
		else:
			# Equipped — show item icon over hidden background
			var item: ItemData = DataManager.get_item(item_id)
			if icon_rect:
				icon_rect.texture = item.icon if (item and item.icon) else _placeholder_tex
			if bg_rect:
				bg_rect.modulate = Color(0.6, 0.6, 0.6, 0.05)  # nearly hide bg
			
			# Show defense value for this piece
			var defense_val: int = GameManager.ARMOR_DEFENSE.get(item_id, 0)
			if stat_label:
				stat_label.text = "+%d" % defense_val
			total_defense += defense_val
	
	# Update total defense label
	if _defense_total_label:
		if total_defense > 0:
			_defense_total_label.text = "Defense: %d" % total_defense
			_defense_total_label.visible = true
		else:
			_defense_total_label.text = ""
			_defense_total_label.visible = false
	
	# Update slot tooltips
	for slot_name: String in ARMOR_SLOT_ORDER:
		var slot: PanelContainer = _armor_slots.get(slot_name)
		if not slot:
			continue
		var item_id: String = GameManager.equipped_armor.get(slot_name, "")
		if item_id.is_empty():
			var slot_label: String = ARMOR_SLOT_LABELS.get(slot_name, slot_name.capitalize())
			slot.tooltip_text = "%s\n(Drag an item from inventory to equip)" % slot_label
		else:
			var item: ItemData = DataManager.get_item(item_id)
			var item_name: String = item.display_name if item else item_id
			var def_val: int = GameManager.ARMOR_DEFENSE.get(item_id, 0)
			slot.tooltip_text = "%s\n%s\n+%d Defense\n(Left-click to unequip)" % [ARMOR_SLOT_LABELS.get(slot_name, ""), item_name, def_val]


## Handle clicks on armor slots — left-click to unequip, or drop a dragged
## armor item from inventory to equip it.
func _on_armor_slot_gui_input(event: InputEvent, slot_name: String) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	if not GameManager:
		return
	
	# ── Drag-and-drop from inventory → equip ──
	if _held_from_idx >= 0 and not _held_item_id.is_empty():
		if event.button_index == MOUSE_BUTTON_LEFT:
			var armor_slot: String = GameManager._armor_slot_for(_held_item_id)
			if armor_slot == slot_name:
				# Equip the dragged item into this armor slot
				var held_id: String = _held_item_id
				var held_slot: int = _held_from_idx
				var old_item: String = GameManager.equip_armor(held_id)
				# Remove the item from the inventory slot it was dragged from
				InventoryManager.slots[held_slot] = null
				_clear_held()
				# If there was an old item in that armor slot, put it back
				if not old_item.is_empty():
					InventoryManager.add_item(old_item, 1)
					var old_data: ItemData = DataManager.get_item(old_item)
					var old_name: String = old_data.display_name if old_data else old_item
					ToastNotification.show_toast("Equipped (swapped " + old_name + ")", ToastNotification.ToastType.SUCCESS, 2.0)
				else:
					var item_data: ItemData = DataManager.get_item(held_id)
					ToastNotification.show_toast("Equipped " + (item_data.display_name if item_data else held_id) + "!", ToastNotification.ToastType.SUCCESS, 2.0)
				AudioManager.play(AudioManager.Sound.EQUIP_ARMOR)
				_refresh_armor_slots()
				InventoryManager.changed.emit()
				return
		# Dragging something that doesn't match this slot — ignore click
		return
	
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	
	# ── Left-click on equipped armor to unequip ──
	var item_id: String = GameManager.equipped_armor.get(slot_name, "")
	if item_id.is_empty():
		return
	
	GameManager.unequip_armor(slot_name)
	if InventoryManager.add_item(item_id, 1) == 0:
		var item: ItemData = DataManager.get_item(item_id)
		var display: String = item.display_name if item else item_id
		ToastNotification.show_toast("Unequipped " + display, ToastNotification.ToastType.INFO, 1.5)
		AudioManager.play(AudioManager.Sound.MENU_CLOSE)
	_refresh_armor_slots()


## React to GameManager.armor_changed signal
func _on_armor_changed(_defense: int) -> void:
	if is_open:
		_refresh_armor_slots()


## Equip the armor item in the currently hovered inventory slot (E key).
func _equip_hovered_armor() -> void:
	if _held_from_idx >= 0:
		return  # don't equip while dragging
	var idx: int = _hovered_slot_idx
	if idx < 0 or idx >= InventoryManager.slots.size():
		return
	var slot_data = InventoryManager.slots[idx]
	if slot_data == null:
		return
	if not (slot_data is Dictionary):
		return
	var item_id: String = slot_data["item_id"]
	_try_equip_armor(item_id, idx)


## Try to equip an armor item from a slot click (right-click on armor item in inventory)
func _try_equip_armor(item_id: String, slot_idx: int) -> bool:
	var slot: String = GameManager._armor_slot_for(item_id)
	if slot.is_empty():
		return false
	
	# Remove from inventory
	InventoryManager.slots[slot_idx] = null
	
	# Equip — swap with any existing piece in that slot
	var old_item: String = GameManager.equip_armor(item_id)
	if not old_item.is_empty():
		InventoryManager.add_item(old_item, 1)
	
	_refresh_armor_slots()
	InventoryManager.changed.emit()
	
	var item: ItemData = DataManager.get_item(item_id)
	var msg: String = "Equipped " + (item.display_name if item else item_id)
	ToastNotification.show_toast(msg, ToastNotification.ToastType.SUCCESS, 2.0)
	AudioManager.play(AudioManager.Sound.EQUIP_ARMOR)
	return true


# ---------------------------------------------------------------------------
# Refresh
# ---------------------------------------------------------------------------
func _refresh_all() -> void:
	_update_slots()
	_update_capacity_label()
	_refresh_armor_slots()


func _update_slots() -> void:
	var slots := InventoryManager.slots
	for i in range(min(slots.size(), _slot_panels.size())):
		var slot_data = slots[i]
		if slot_data != null and slot_data is Dictionary:
			var item: ItemData = DataManager.get_item(slot_data["item_id"])
			_slot_icon_rects[i].texture = item.icon if (item and item.icon) else _placeholder_tex
			# Apply tint if the slot has one (for tinted berries/flowers/mushrooms)
			var slot_tint: Color = slot_data.get("tint", Color.WHITE)
			_slot_icon_rects[i].modulate = slot_tint
			_slot_count_labels[i].modulate = Color.WHITE
			_slot_count_labels[i].text = "x%d" % slot_data["count"]
		else:
			_slot_icon_rects[i].texture = null
			_slot_count_labels[i].modulate = Color.WHITE
			_slot_count_labels[i].text = ""
	
	# If we're dragging something, dim (don't fully hide) the source slot
	# so it's clear the item is being held, not deleted.
	if _held_from_idx >= 0 and _held_from_idx < _slot_icon_rects.size():
		_slot_icon_rects[_held_from_idx].modulate = Color(1, 1, 1, 0.35)
		_slot_count_labels[_held_from_idx].modulate = Color(1, 1, 1, 0.35)
	
	_update_tool_highlight()
	_update_item_info()


func _update_capacity_label() -> void:
	var used := InventoryManager.get_used_slot_count()
	capacity_label.text = "%d / %d slots" % [used, InventoryManager.capacity]


func _on_inventory_changed() -> void:
	if is_open:
		_refresh_all()


func _on_capacity_changed(_new_capacity: int) -> void:
	# Always rebuild slots so new empty ones appear (even if inventory was closed)
	_build_slots()


func _on_player_tool_changed(_tool_name: String) -> void:
	if is_open:
		_update_tool_highlight()


func _update_tool_highlight() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	var tool_value: int = player.active_tool
	var active_idx: int = _tool_to_hotbar_idx(tool_value)
	
	for i in range(min(HOTBAR_COUNT, _slot_panels.size())):
		var style := StyleBoxFlat.new()
		var is_hotbar := i < HOTBAR_COUNT
		if is_hotbar:
			style.bg_color = Color(0.2, 0.2, 0.25, 0.9) if i == active_idx else Color(0.15, 0.15, 0.15, 0.85)
			style.set_border_width_all(3 if i == active_idx else 2)
			style.border_color = Color(1.0, 0.9, 0.3, 1.0) if i == active_idx else Color(0.25, 0.2, 0.12)
		else:
			style.bg_color = Color(0.12, 0.12, 0.12, 0.85)
			style.set_border_width_all(2)
			style.border_color = Color(0.25, 0.25, 0.25)
		style.set_corner_radius_all(4)
		_slot_panels[i].add_theme_stylebox_override("panel", style)


func _tool_to_hotbar_idx(tool_val: int) -> int:
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
# Hover -> item info
# ---------------------------------------------------------------------------
func _on_slot_mouse_entered(slot_idx: int) -> void:
	_hovered_slot_idx = slot_idx
	# Don't update item info on hover — only clicking pins/selects an item.
	# This lets the description persist from the last clicked item.


func _on_slot_mouse_exited(slot_idx: int) -> void:
	# Don't clear info on mouse exit — the Eat button needs to stay clickable
	# while the mouse moves from the slot to the button. Info is cleared when
	# hovering a different slot, clicking away, or closing the inventory.
	pass


func _update_item_info() -> void:
	# Use the clicked/selected slot, not the hovered one.
	# Description persists until another item is clicked.
	var idx: int = _selected_slot_idx if _selected_slot_idx >= 0 else -1
	if idx < 0 or idx >= InventoryManager.slots.size():
		_clear_item_info()
		return
	
	var slot_data = InventoryManager.slots[idx]
	if slot_data == null:
		_clear_item_info()
		return
	if not (slot_data is Dictionary):
		_clear_item_info()
		return
	
	# Don't show info for the slot we're dragging FROM
	if _held_from_idx >= 0 and idx == _held_from_idx:
		_clear_item_info()
		return
	
	var item: ItemData = DataManager.get_item(slot_data["item_id"])
	if not item:
		_clear_item_info()
		return
	
	# Show hovered item's icon in the portrait slot
	portrait_rect.texture = item.icon if item.icon else _placeholder_tex
	portrait_rect.modulate = slot_data.get("tint", Color.WHITE)
	
	# Prepend color name for tinted items (berries, flowers, mushrooms)
	var display_name := item.display_name
	var slot_tint: Color = slot_data.get("tint", Color.WHITE)
	if slot_tint != Color.WHITE and item.id == "berry":
		display_name = Bush.get_berry_color_name(slot_tint) + " " + display_name
	item_name_label.text = display_name
	
	# Category
	var cat_display: String = item.category.capitalize()
	item_category_label.text = cat_display
	item_category_label.visible = true
	
	# Description (BBCode supported via RichTextLabel)
	if item.description and item.description != "":
		item_description_label.bbcode_text = item.description
		item_description_label.visible = true
	else:
		item_description_label.bbcode_text = ""
		item_description_label.visible = false
	
	# Sell price
	if _sell_price_label:
		if item.sell_price > 0:
			_sell_price_label.text = "Sells for " + str(item.sell_price) + " coins"
			_sell_price_label.visible = true
		else:
			_sell_price_label.visible = false
	
	# Show Use/Eat button for food, meal, pet eggs, or Inconstant Fruits
	# (The eat button provides quick consumption from inventory;
	#  in the game world, hold E to eat food/meal/potion instead)
	var can_use: bool = item.category in ["food", "meal", "pet_egg", "consumable"]
	use_button.visible = can_use
	if can_use:
		if item.category == "meal":
			use_button.text = "Eat Meal"
		elif item.category == "pet_egg":
			use_button.text = "Hatch"
		else:
			use_button.text = "Eat"
		# Disconnect old and reconnect
		if use_button.pressed.is_connected(_on_use_pressed):
			use_button.pressed.disconnect(_on_use_pressed)
		use_button.pressed.connect(_on_use_pressed.bind(slot_data["item_id"]))


# ---------------------------------------------------------------------------
# Item consumption (eat food / meals)
# ---------------------------------------------------------------------------

func _on_use_pressed(item_id: String) -> void:
	var item: ItemData = DataManager.get_item(item_id)
	if not item or not InventoryManager.has_item(item_id, 1):
		return
	
	if item.category == "meal":
		InventoryManager.remove_item(item_id, 1)
		GameManager.change_hunger(35)
		GameManager.heal(15)
		AudioManager.play(AudioManager.Sound.EAT)
		
		# Apply meal buff via CookingSystem
		var world: Node = get_tree().get_first_node_in_group("world")
		var cooking: CookingSystem = world.get_cooking_system() if world and world.has_method("get_cooking_system") else null
		if cooking:
			var meal := cooking.get_meal(item_id)
			if meal and meal.buff_type != "none":
				BuffManager.apply_meal_buff(meal)
				var buff_name: String = meal.buff_type.capitalize()
				ToastNotification.show_toast("Ate %s! +%s Buff (%s)" % [meal.display_name, buff_name, str(meal.buff_duration) + "h"], ToastNotification.ToastType.SUCCESS, 2.5)
			else:
				ToastNotification.show_toast("Ate a delicious meal! +35 Hunger, +15 HP", ToastNotification.ToastType.SUCCESS, 2.5)
		_refresh_all()
		_update_item_info()
	elif item.category == "food":
		InventoryManager.remove_item(item_id, 1)
		GameManager.change_hunger(8)
		AudioManager.play(AudioManager.Sound.EAT)
		ToastNotification.show_toast("Ate some %s. +8 Hunger" % item.display_name, ToastNotification.ToastType.SUCCESS, 2.0)
		_refresh_all()
		_update_item_info()
	elif item.category == "pet_egg":
		# Map egg item ID to pet ID (e.g. "cat_egg" -> "cat")
		var pet_id := item_id.trim_suffix("_egg")
		if PetManager.unlock_pet(pet_id):
			InventoryManager.remove_item(item_id, 1)
			var pet_name: String = PetManager.get_pet_display_name(pet_id)
			ToastNotification.show_toast("🐣 %s hatched! %s is now your companion!" % [item.display_name, pet_name], ToastNotification.ToastType.SUCCESS, 4.0)
			AudioManager.play(AudioManager.Sound.LEVEL_UP)
		else:
			if PetManager.has_pet(pet_id):
				ToastNotification.show_toast("You already have this pet!", ToastNotification.ToastType.WARNING, 2.0)
			else:
				ToastNotification.show_toast("Something went wrong hatching this egg.", ToastNotification.ToastType.ERROR, 2.0)
	elif item.category == "consumable" and item.get_meta("inconstant_power", false):
		# Inconstant Fruit — delegate to the player's consumption logic
		# (player method handles inventory management itself)
		var player: Node = get_tree().get_first_node_in_group("player")
		if player and player.has_method("_consume_inconstant_fruit"):
			player._consume_inconstant_fruit(item_id, item)
		else:
			ToastNotification.show_toast("The fruit crumbles to ash...", ToastNotification.ToastType.ERROR, 2.0)
	else:
		ToastNotification.show_toast("Can't use that!", ToastNotification.ToastType.WARNING, 2.0)

func _clear_item_info() -> void:
	portrait_rect.texture = null
	item_name_label.text = "Select an item"
	item_category_label.text = ""
	item_category_label.visible = false
	item_description_label.bbcode_text = "Right click on an item to view its details."
	item_description_label.visible = true
	use_button.visible = false
	if _sell_price_label:
		_sell_price_label.visible = false


# ---------------------------------------------------------------------------
# Click-to-reorganize (drag & drop)
# ---------------------------------------------------------------------------
func _on_slot_gui_input(event: InputEvent, slot_idx: int) -> void:
	if not event is InputEventMouseButton:
		return
	
	var mb := event as InputEventMouseButton
	if not mb.pressed:
		return
	
	if mb.button_index == MOUSE_BUTTON_LEFT:
		_on_left_click(slot_idx)
		get_viewport().set_input_as_handled()
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		_on_right_click(slot_idx)
		get_viewport().set_input_as_handled()


func _on_left_click(slot_idx: int) -> void:
	# Left-click is purely for drag-and-drop — no description pinning.
	# Right-click now handles description pinning.
	
	var slot_data = InventoryManager.slots[slot_idx] if slot_idx < InventoryManager.slots.size() else null
	
	if _held_from_idx >= 0:
		# Clicking the same slot we picked up from — just put it back
		if slot_idx == _held_from_idx:
			_clear_held()
			InventoryManager.changed.emit()
			_update_drag_icon()
			return
		if slot_data != null and slot_data["item_id"] == _held_item_id:
			var item: ItemData = DataManager.get_item(_held_item_id)
			var stack_size: int = item.stack_size if item else 99
			var room: int = stack_size - slot_data["count"]
			if room >= _held_count:
				slot_data["count"] += _held_count
				InventoryManager.slots[_held_from_idx] = null
				_clear_held()
			else:
				slot_data["count"] = stack_size
				_held_count -= room
				var next_idx := _find_next_empty_or_same(slot_idx)
				if next_idx < 0:
					_swap_or_place(slot_idx)
				else:
					if InventoryManager.slots[next_idx] == null:
						InventoryManager.slots[next_idx] = {"item_id": _held_item_id, "count": _held_count}
					else:
						InventoryManager.slots[next_idx]["count"] += _held_count
					InventoryManager.slots[_held_from_idx] = null
					_clear_held()
		elif slot_data != null:
			_swap_or_place(slot_idx)
		else:
			InventoryManager.slots[slot_idx] = {"item_id": _held_item_id, "count": _held_count}
			InventoryManager.slots[_held_from_idx] = null
			_clear_held()
	else:
		if slot_data != null:
			_held_item_id = slot_data["item_id"]
			_held_count = slot_data["count"]
			_held_from_idx = slot_idx
	
	InventoryManager.changed.emit()
	_update_drag_icon()


func _on_right_click(slot_idx: int) -> void:
	# Right-click only shows the item's description — no drag/split/equip.
	_selected_slot_idx = slot_idx
	_update_item_info()


func _swap_or_place(slot_idx: int) -> void:
	var target_data = InventoryManager.slots[slot_idx]
	InventoryManager.slots[slot_idx] = {"item_id": _held_item_id, "count": _held_count}
	InventoryManager.slots[_held_from_idx] = target_data
	_clear_held()


func _find_next_empty_or_same(skip_idx: int) -> int:
	for i in range(InventoryManager.slots.size()):
		if i == skip_idx:
			continue
		var s = InventoryManager.slots[i]
		if s == null:
			return i
		if s["item_id"] == _held_item_id:
			var item: ItemData = DataManager.get_item(_held_item_id)
			var stack_size: int = item.stack_size if item else 99
			if s["count"] < stack_size:
				return i
	return -1


func _clear_held() -> void:
	_held_item_id = ""
	_held_count = 0
	_held_from_idx = -1
	drag_icon.visible = false


func _drop_held_stack() -> void:
	if _held_from_idx >= 0:
		if _held_from_idx < InventoryManager.slots.size():
			var existing = InventoryManager.slots[_held_from_idx]
			if existing != null and existing["item_id"] == _held_item_id:
				existing["count"] += _held_count
			else:
				InventoryManager.slots[_held_from_idx] = {"item_id": _held_item_id, "count": _held_count}
		_clear_held()
		InventoryManager.changed.emit()


func _update_drag_icon() -> void:
	if _held_from_idx >= 0:
		var item: ItemData = DataManager.get_item(_held_item_id)
		drag_icon.texture = item.icon if (item and item.icon) else _placeholder_tex
		drag_icon.visible = true
		drag_icon.global_position = get_viewport().get_mouse_position() - Vector2(SLOT_SIZE / 2, SLOT_SIZE / 2)
	else:
		drag_icon.visible = false


func _process(_delta: float) -> void:
	if _held_from_idx >= 0 and drag_icon.visible:
		drag_icon.global_position = get_viewport().get_mouse_position() - Vector2(SLOT_SIZE / 2, SLOT_SIZE / 2)


# ---------------------------------------------------------------------------
# Placeholder
# ---------------------------------------------------------------------------
func _add_sort_button() -> void:
	var bottom_row: HBoxContainer = find_child("BottomRow", true, false) as HBoxContainer
	if not bottom_row:
		return
	var sort_btn := Button.new()
	sort_btn.text = "Sort"
	sort_btn.custom_minimum_size = Vector2(60, 0)
	sort_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	sort_btn.pressed.connect(_on_sort_pressed)
	bottom_row.add_child(sort_btn)
	bottom_row.move_child(sort_btn, 0)


func _on_sort_pressed() -> void:
	InventoryManager.sort_inventory()
	_refresh_all()
	ToastNotification.show_toast("Inventory sorted!", ToastNotification.ToastType.INFO, 1.0)


func _connect_discard_button() -> void:
	var btn: Button = find_child("DiscardButton", true, false) as Button
	if btn:
		if not btn.pressed.is_connected(_on_discard_pressed):
			btn.pressed.connect(_on_discard_pressed)


func _make_placeholder_icon() -> Texture2D:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.3, 0.3, 0.3))
	return ImageTexture.create_from_image(img)
