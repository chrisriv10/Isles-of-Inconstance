extends CanvasLayer
class_name CollectionsUI

## Collections UI — completion log showing all items in the game.
## Items are grouped into tabs by category (like the Creative Panel).
## Undiscovered items show a gray placeholder + dimmed name.
## Discovered items show icon, colored name, and description.
## Search bar filters items across the currently selected tab.

signal closed()

@onready var dim: ColorRect = $Dim
@onready var panel: PanelContainer = $Panel
@onready var title_label: Label = $Panel/VBox/TitleBar/TitleLabel
@onready var progress_label: Label = $Panel/VBox/TitleBar/ProgressLabel
@onready var close_btn: Button = $Panel/VBox/TitleBar/CloseButton
@onready var search_input: LineEdit = $Panel/VBox/SearchInput
@onready var tab_row: HBoxContainer = $Panel/VBox/TabRow
@onready var item_list: VBoxContainer = $Panel/VBox/MainBody/ScrollContainer/ItemList

@onready var detail_panel: PanelContainer = $Panel/VBox/MainBody/DetailPanel
@onready var detail_icon: TextureRect = $Panel/VBox/MainBody/DetailPanel/DetailMargin/DetailVBox/DetailIcon
@onready var detail_name: Label = $Panel/VBox/MainBody/DetailPanel/DetailMargin/DetailVBox/DetailName
@onready var detail_desc: RichTextLabel = $Panel/VBox/MainBody/DetailPanel/DetailMargin/DetailVBox/DetailDescription
@onready var detail_empty_hint: Label = $Panel/VBox/MainBody/DetailPanel/DetailMargin/DetailVBox/DetailEmptyHint

var is_open: bool = false
var _needs_refresh: bool = true
var _is_refreshing: bool = false

var _selected_item_id: String = ""

# ── Category definitions (matching CreativePanel) ──
const CATEGORY_ORDER: Array[String] = ["resource", "seed", "crop", "food", "meal", "tool", "armor", "misc"]
const CATEGORY_DISPLAY_NAMES: Dictionary = {
	"resource": "Resources",
	"seed": "Seeds",
	"crop": "Crops",
	"food": "Food",
	"meal": "Meals",
	"tool": "Tools",
	"armor": "Armor",
	"misc": "Miscellaneous"
}
const CATEGORY_COLORS: Dictionary = {
	"resource": Color(0.6, 0.7, 0.9),
	"seed": Color(0.6, 0.9, 0.5),
	"crop": Color(1.0, 0.7, 0.3),
	"food": Color(0.8, 0.9, 0.4),
	"meal": Color(1.0, 0.8, 0.6),
	"tool": Color(0.6, 0.6, 1.0),
	"armor": Color(0.7, 0.5, 0.9),
	"misc": Color(0.8, 0.7, 0.9)
}

## Building kit IDs get their own tab.
const BUILDING_KIT_IDS: Array[String] = [
	"small_home_kit", "medium_home_kit", "large_home_kit",
	"barn_kit", "storage_shed_kit",
	"fence_material", "stone_fence_material",
	"campfire_kit", "gate_kit", "garden_bed_kit",
	"windmill_kit", "greenhouse_kit",
	"decorative_statue_kit", "decorative_fountain_kit",
	"decorative_bench_kit", "decorative_lantern_kit", "decorative_sign_kit",
	"silo_kit", "well_kit",
	"hotel_kit",
	"scarecrow_kit", "compost_bin_kit",
]

# Tab state
var _tab_keys: Array[String] = []          # ordered list of tab identifiers
var _tab_buttons: Dictionary = {}           # tab_key -> Button
var _active_tab: String = ""

# Pre-cached item groupings
var _by_category: Dictionary = {}           # category_name -> Array[String]
var _building_ids: Array[String] = []
var _legendary_fruit_ids: Array[String] = []

var _placeholder_tex: Texture2D


func _ready() -> void:
	if dim:
		dim.visible = false
	if panel:
		panel.visible = false

	_ensure_collections_action()

	close_btn.pressed.connect(_on_close_pressed)
	search_input.text_changed.connect(_on_search_changed)

	_placeholder_tex = _make_placeholder_icon()

	DataManager.item_discovered.connect(_on_item_discovered)


func _ensure_collections_action() -> void:
	if not InputMap.has_action("open_collections"):
		InputMap.add_action("open_collections")
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_L
		InputMap.action_add_event("open_collections", ev)


func _make_placeholder_icon() -> Texture2D:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var gray := Color(0.25, 0.25, 0.25, 0.6)
	for px in range(32):
		for py in range(32):
			img.set_pixel(px, py, gray)
	var border := Color(0.35, 0.35, 0.35, 0.8)
	for b in range(32):
		img.set_pixel(b, 0, border)
		img.set_pixel(b, 31, border)
		img.set_pixel(0, b, border)
		img.set_pixel(31, b, border)
	var tex := ImageTexture.create_from_image(img)
	return tex


func _on_item_discovered(_item_id: String) -> void:
	_needs_refresh = true
	if is_open:
		refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_collections"):
		toggle()
		get_viewport().set_input_as_handled()
	elif is_open and event.is_action_pressed("close_menu"):
		close()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func open() -> void:
	is_open = true
	AudioManager.play(AudioManager.Sound.MENU_OPEN)
	if dim:
		dim.visible = true
	if panel:
		panel.visible = true
	if _needs_refresh:
		refresh()
		_needs_refresh = false


func close() -> void:
	is_open = false
	AudioManager.play(AudioManager.Sound.MENU_CLOSE)
	if dim:
		dim.visible = false
	if panel:
		panel.visible = false
	_needs_refresh = true
	closed.emit()


func _on_close_pressed() -> void:
	close()


# ── Refresh ────────────────────────────────────────────────────────────────

func refresh() -> void:
	if not panel or not item_list:
		return
	if _is_refreshing:
		return
	_is_refreshing = true
	_needs_refresh = false

	# In creative mode, auto-unlock all items
	if GameManager.is_creative():
		for item_id: String in DataManager.items.keys():
			DataManager.mark_item_discovered(item_id)

	_group_items()
	_build_tab_keys()
	_build_tab_buttons()
	_update_progress()

	if _active_tab.is_empty() or _active_tab not in _tab_keys:
		_select_tab(_tab_keys[0] if not _tab_keys.is_empty() else "")
	else:
		_render_tab(_active_tab)
	
	_is_refreshing = false


func _group_items() -> void:
	_by_category.clear()
	_building_ids.clear()
	_legendary_fruit_ids.clear()

	for item_id: String in DataManager.items.keys():
		var item_data: ItemData = DataManager.get_item(item_id)
		if not item_data:
			continue
		if item_id in BUILDING_KIT_IDS:
			_building_ids.append(item_id)
			continue
		if item_data.get_meta("inconstant_power", false):
			_legendary_fruit_ids.append(item_id)
			continue
		var cat: String = item_data.category
		if not _by_category.has(cat):
			_by_category[cat] = []
		_by_category[cat].append(item_id)


func _build_tab_keys() -> void:
	_tab_keys.clear()
	for cat in CATEGORY_ORDER:
		if _by_category.has(cat) and not _by_category[cat].is_empty():
			_tab_keys.append(cat)
	if not _building_ids.is_empty():
		_tab_keys.append("buildings")
	if not _legendary_fruit_ids.is_empty():
		_tab_keys.append("legendary_fruits")


func _get_tab_display_name(key: String) -> String:
	if key == "buildings":
		return "Buildings"
	if key == "legendary_fruits":
		return "Legendary Fruits"
	return CATEGORY_DISPLAY_NAMES.get(key, key.capitalize())


func _get_tab_color(key: String) -> Color:
	if key == "buildings":
		return Color(0.8, 0.65, 0.35)
	if key == "legendary_fruits":
		return Color(1.0, 0.6, 0.0)
	return CATEGORY_COLORS.get(key, Color(0.8, 0.8, 0.8))


func _get_items_for_tab(key: String) -> Array[String]:
	if key == "buildings":
		return _building_ids.duplicate()
	if key == "legendary_fruits":
		return _legendary_fruit_ids.duplicate()
	var raw: Array = _by_category.get(key, [])
	var result: Array[String] = []
	result.assign(raw)
	return result


func _count_discovered_in_tab(key: String) -> int:
	var ids: Array = _get_items_for_tab(key)
	var count: int = 0
	for item_id in ids:
		if DataManager.is_item_discovered(item_id):
			count += 1
	return count


# ── Tab buttons ────────────────────────────────────────────────────────────

func _build_tab_buttons() -> void:
	for child in tab_row.get_children():
		child.queue_free()
	_tab_buttons.clear()

	for key: String in _tab_keys:
		var display_name: String = _get_tab_display_name(key)
		var discovered: int = _count_discovered_in_tab(key)
		var total: int = _get_items_for_tab(key).size()

		var btn := Button.new()
		btn.text = "%s (%d/%d)" % [display_name, discovered, total]
		btn.custom_minimum_size = Vector2(0, 26)
		btn.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_SHRINK_CENTER
		btn.add_theme_font_size_override("font_size", 10)

		var is_active: bool = (key == _active_tab)
		var color: Color = _get_tab_color(key)
		btn.add_theme_color_override("font_color", color if is_active else Color(0.6, 0.6, 0.6))

		btn.pressed.connect(_on_tab_pressed.bind(key))
		tab_row.add_child(btn)
		_tab_buttons[key] = btn


func _on_tab_pressed(key: String) -> void:
	_select_tab(key)


func _select_tab(key: String) -> void:
	_active_tab = key
	_clear_selection()
	_render_tab(key)

	# Update button colors
	for k: String in _tab_buttons:
		var btn: Button = _tab_buttons[k]
		var color: Color = _get_tab_color(k)
		btn.add_theme_color_override("font_color", color if k == key else Color(0.6, 0.6, 0.6))


# ── Rendering ──────────────────────────────────────────────────────────────

func _render_tab(key: String) -> void:
	for child in item_list.get_children():
		child.queue_free()

	var search_text: String = search_input.text.strip_edges().to_lower()
	var items: Array[String] = _get_items_for_tab(key)
	items.sort()

	var rendered_count: int = 0
	for item_id: String in items:
		if not search_text.is_empty():
			var item_data: ItemData = DataManager.get_item(item_id)
			if not item_data:
				continue
			if not item_id.to_lower().contains(search_text) and \
			   not item_data.display_name.to_lower().contains(search_text):
				continue

		var row := _make_item_row(item_id)
		item_list.add_child(row)
		rendered_count += 1

	if rendered_count == 0:
		var hint := Label.new()
		if search_text.is_empty():
			hint.text = "No items in this category."
		else:
			hint.text = "No items match your search."
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		hint.custom_minimum_size = Vector2(0, 40)
		item_list.add_child(hint)


func _on_search_changed(_new_text: String) -> void:
	if _active_tab.is_empty() or _active_tab not in _tab_keys:
		return
	_clear_selection()
	_render_tab(_active_tab)


func _update_progress() -> void:
	var total: int = DataManager.items.size()
	var discovered: int = DataManager.discovered_item_ids.size()
	progress_label.text = "%d / %d" % [discovered, total]


# ── Item row ───────────────────────────────────────────────────────────────

func _make_item_row(item_id: String) -> HBoxContainer:
	var item_data: ItemData = DataManager.get_item(item_id)
	if not item_data:
		return HBoxContainer.new()

	var discovered: bool = DataManager.is_item_discovered(item_id)
	var cat_color: Color = CATEGORY_COLORS.get(item_data.category, Color(0.8, 0.8, 0.8))
	var is_selected: bool = (item_id == _selected_item_id)

	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 40)
	row.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_FILL
	row.add_theme_color_override("background_color", Color(0.3, 0.2, 0.08, 0.5) if is_selected else Color.TRANSPARENT)

	# Icon
	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(36, 36)
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if discovered and item_data.icon:
		icon_rect.texture = item_data.icon
		icon_rect.modulate = Color.WHITE
	else:
		icon_rect.texture = _placeholder_tex
		icon_rect.modulate = Color(0.5, 0.5, 0.5, 0.7)
	row.add_child(icon_rect)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(8, 0)
	row.add_child(spacer)

	# Text area
	var text_vbox := VBoxContainer.new()
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_FILL

	# Item name (no inline description — it's in the detail panel)
	var name_label := Label.new()
	name_label.text = item_data.display_name
	if discovered:
		name_label.add_theme_color_override("font_color", cat_color)
		name_label.add_theme_font_size_override("font_size", 13)
	else:
		name_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 0.7))
		name_label.add_theme_font_size_override("font_size", 12)
	text_vbox.add_child(name_label)

	row.add_child(text_vbox)

	# Make the entire row clickable
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.gui_input.connect(_on_row_gui_input.bind(item_id, row))

	return row


func _on_row_gui_input(event: InputEvent, item_id: String, _row: HBoxContainer) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_item(item_id)


func _select_item(item_id: String) -> void:
	if item_id == _selected_item_id:
		return
	_selected_item_id = item_id
	_update_details(item_id)
	# Re-render so the selected row gets the highlight
	_render_tab(_active_tab)


func _update_details(item_id: String) -> void:
	var item_data: ItemData = DataManager.get_item(item_id)
	if not item_data:
		_hide_details()
		return

	var discovered: bool = DataManager.is_item_discovered(item_id)
	var cat_color: Color = CATEGORY_COLORS.get(item_data.category, Color(0.8, 0.8, 0.8))

	# Show detail content, hide empty hint
	detail_icon.show()
	detail_name.show()
	detail_desc.show()
	detail_empty_hint.hide()

	# Big icon
	if discovered and item_data.icon:
		detail_icon.texture = item_data.icon
		detail_icon.modulate = Color.WHITE
	else:
		detail_icon.texture = _placeholder_tex
		detail_icon.modulate = Color(0.5, 0.5, 0.5, 0.7)

	# Name
	detail_name.text = item_data.display_name
	if discovered:
		detail_name.add_theme_color_override("font_color", cat_color)
	else:
		detail_name.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 0.7))

	# Description (in RichTextLabel so BBCode renders)
	if discovered and not item_data.description.is_empty():
		detail_desc.show()
		detail_desc.bbcode_text = item_data.description
	else:
		detail_desc.hide()


func _hide_details() -> void:
	detail_icon.hide()
	detail_name.hide()
	detail_desc.hide()
	detail_empty_hint.show()

func _clear_selection() -> void:
	_selected_item_id = ""
	_hide_details()
