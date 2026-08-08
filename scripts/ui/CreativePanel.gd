extends CanvasLayer
class_name CreativePanel

## Creative-mode panel: item spawner + time controls + settings.
## Opened via ` (backtick) key in creative mode only.
## Uses Dim + PanelContainer pattern matching CraftingUI / InventoryUI.

var _is_open: bool = false

## Cached reference to the World node for expedition travel.
var _world: Node = null

@onready var dim: ColorRect = $Dim
@onready var panel: PanelContainer = $Panel

# Tab buttons
@onready var items_btn: Button = $Panel/Margin/Layout/TabRow/ItemsBtn
@onready var time_btn: Button = $Panel/Margin/Layout/TabRow/TimeBtn
@onready var settings_btn: Button = $Panel/Margin/Layout/TabRow/SettingsBtn
@onready var creatures_btn: Button = $Panel/Margin/Layout/TabRow/CreaturesBtn
@onready var pets_btn: Button = $Panel/Margin/Layout/TabRow/PetsBtn
@onready var town_btn: Button = $Panel/Margin/Layout/TabRow/TownBtn

# Tab content containers
@onready var items_content: VBoxContainer = $Panel/Margin/Layout/ItemsContent
@onready var time_content: VBoxContainer = $Panel/Margin/Layout/TimeContent
@onready var settings_content: VBoxContainer = $Panel/Margin/Layout/SettingsContent
@onready var creatures_content: VBoxContainer = $Panel/Margin/Layout/CreaturesContent
@onready var enemy_grid: GridContainer = $Panel/Margin/Layout/CreaturesContent/EnemyGrid
@onready var boss_grid: GridContainer = $Panel/Margin/Layout/CreaturesContent/BossGrid
@onready var animal_grid: GridContainer = $Panel/Margin/Layout/CreaturesContent/AnimalGrid
@onready var pirate_raid_btn: Button = $Panel/Margin/Layout/CreaturesContent/PirateRaidBtn
@onready var blood_moon_btn: Button = $Panel/Margin/Layout/CreaturesContent/BloodMoonBtn

# Pets tab
@onready var pets_content: VBoxContainer = $Panel/Margin/Layout/PetsContent
@onready var pet_list: VBoxContainer = $Panel/Margin/Layout/PetsContent/ScrollContainer/PetList

# Town tab
@onready var town_content: VBoxContainer = $Panel/Margin/Layout/TownContent
@onready var restore_all_btn: Button = $Panel/Margin/Layout/TownContent/TownActions/RestoreAllBtn
@onready var list_residents_btn: Button = $Panel/Margin/Layout/TownContent/TownActions/ListResidentsBtn
@onready var recruit_visitor_btn: Button = $Panel/Margin/Layout/TownContent/TownActions/RecruitVisitorBtn
@onready var spawn_visitor_boat_btn: Button = $Panel/Margin/Layout/TownContent/TownActions/SpawnVisitorBoatBtn

# Expeditions tab
@onready var expeditions_btn: Button = $Panel/Margin/Layout/TabRow/ExpeditionsBtn
@onready var expeditions_content: VBoxContainer = $Panel/Margin/Layout/ExpeditionsContent
@onready var expedition_list: VBoxContainer = $Panel/Margin/Layout/ExpeditionsContent/ExpeditionList

# Items tab
@onready var search_input: LineEdit = $Panel/Margin/Layout/ItemsContent/SearchInput
@onready var category_list: VBoxContainer = $Panel/Margin/Layout/ItemsContent/ScrollContainer/CategoryList

# Time tab
@onready var pause_btn: Button = $Panel/Margin/Layout/TimeContent/PauseBtn
@onready var hour_slider: HSlider = $Panel/Margin/Layout/TimeContent/HourBox/HourSlider
@onready var hour_label: Label = $Panel/Margin/Layout/TimeContent/HourBox/HourLabel
@onready var advance_day_btn: Button = $Panel/Margin/Layout/TimeContent/AdvanceDayBtn
@onready var instant_growth_toggle: CheckButton = $Panel/Margin/Layout/TimeContent/InstantGrowthToggle
@onready var weather_clear_btn: Button = $Panel/Margin/Layout/TimeContent/WeatherGrid/ClearBtn
@onready var weather_rain_btn: Button = $Panel/Margin/Layout/TimeContent/WeatherGrid/RainBtn
@onready var weather_storm_btn: Button = $Panel/Margin/Layout/TimeContent/WeatherGrid/StormBtn
@onready var weather_fog_btn: Button = $Panel/Margin/Layout/TimeContent/WeatherGrid/FogBtn

# Settings tab
@onready var settings_list: VBoxContainer = $Panel/Margin/Layout/SettingsContent/SettingsList

var _all_items: Array[String] = []
var _filtered_items: Array[String] = []
var _item_buttons: Array[Button] = []
var _animal_buttons: Array[Button] = []
var _build_retries: int = 0
var _feedback_label: Label

# Animal scene for instantiation
const ANIMAL_SCENE := preload("res://scenes/world/Animal.tscn")

### Convert a BBCode-formatted string (e.g. an item description containing
## [color=#...] / [b] tags) into plain text for tooltips. Godot's built-in
## tooltip_text does NOT parse BBCode, so without this the raw [color=...]
## tags would show literally in the creative panel hover tooltip. The
## inventory panel shows the same descriptions correctly because it assigns
## them to a Label's bbcode_text, which parses BBCode.
func _bbcode_to_plain(text: String) -> String:
	if text.is_empty():
		return text
	# RichTextLabel supports BBCode parsing and get_parsed_text(); a plain Label
	# has no bbcode_enabled property, so we must use RichTextLabel here.
	var parser := RichTextLabel.new()
	parser.bbcode_enabled = true
	parser.text = text
	var parsed: String = parser.get_parsed_text()
	parser.free()
	return parsed

# Item IDs that are building kits — grouped in their own section
## rather than appearing under "Miscellaneous".
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



# Category ordering for display
const CATEGORY_ORDER: Array[String] = ["resource", "seed", "crop", "food", "meal", "potion", "tool", "armor", "misc"]
const CATEGORY_DISPLAY_NAMES: Dictionary = {
	"resource": "Resources",
	"seed": "Seeds",
	"crop": "Crops",
	"food": "Food",
	"meal": "Meals",
	"potion": "Potions",
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
	"potion": Color(0.4, 0.8, 1.0),
	"tool": Color(0.6, 0.6, 1.0),
	"armor": Color(0.7, 0.5, 0.9),
	"misc": Color(0.8, 0.7, 0.9)
}


func _ready() -> void:
	dim.visible = false
	panel.visible = false

	# Connect tab buttons
	items_btn.pressed.connect(_on_items_tab_pressed)
	time_btn.pressed.connect(_on_time_tab_pressed)
	settings_btn.pressed.connect(_on_settings_tab_pressed)
	creatures_btn.pressed.connect(_on_creatures_tab_pressed)
	pets_btn.pressed.connect(_on_pets_tab_pressed)
	town_btn.pressed.connect(_on_town_tab_pressed)
	expeditions_btn.pressed.connect(_on_expeditions_tab_pressed)
	restore_all_btn.pressed.connect(_on_restore_all_pressed)
	list_residents_btn.pressed.connect(_on_list_residents_pressed)
	recruit_visitor_btn.pressed.connect(_on_recruit_visitor_pressed)
	spawn_visitor_boat_btn.pressed.connect(_on_spawn_visitor_boat_pressed)

	# Build creature buttons
	_build_creature_buttons()

	# Connect search
	search_input.text_changed.connect(_on_search_changed)

	# Connect time controls
	pause_btn.pressed.connect(_on_pause_pressed)
	hour_slider.value_changed.connect(_on_hour_changed)
	advance_day_btn.pressed.connect(_on_advance_day)
	instant_growth_toggle.toggled.connect(_on_instant_growth_toggled)

	# Connect weather buttons
	weather_clear_btn.pressed.connect(_on_weather_pressed.bind(WeatherSystem.WeatherType.CLEAR))
	weather_rain_btn.pressed.connect(_on_weather_pressed.bind(WeatherSystem.WeatherType.RAIN))
	weather_storm_btn.pressed.connect(_on_weather_pressed.bind(WeatherSystem.WeatherType.STORM))
	weather_fog_btn.pressed.connect(_on_weather_pressed.bind(WeatherSystem.WeatherType.FOG))

	# Set initial time display
	_on_hour_changed(hour_slider.value)

	# Set initial instant growth state
	instant_growth_toggle.button_pressed = GameManager.creative_instant_growth if GameManager else true

	# Create feedback label at bottom of items content
	_feedback_label = Label.new()
	_feedback_label.name = "FeedbackLabel"
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_feedback_label.custom_minimum_size = Vector2(0, 28)
	_feedback_label.modulate.a = 0.0
	items_content.add_child(_feedback_label)
	items_content.move_child(_feedback_label, items_content.get_child_count())

	# Start with Items tab active
	_show_tab(0)

	# Defer building item list
	call_deferred("_build_item_list")


func _show_tab(index: int) -> void:
	items_content.visible = (index == 0)
	time_content.visible = (index == 1)
	settings_content.visible = (index == 2)
	creatures_content.visible = (index == 3)
	pets_content.visible = (index == 4)
	town_content.visible = (index == 5)
	expeditions_content.visible = (index == 6)

	var active_color := Color(1, 0.85, 0.3)
	var inactive_color := Color(0.7, 0.7, 0.7)
	items_btn.add_theme_color_override("font_color", active_color if index == 0 else inactive_color)
	time_btn.add_theme_color_override("font_color", active_color if index == 1 else inactive_color)
	settings_btn.add_theme_color_override("font_color", active_color if index == 2 else inactive_color)
	creatures_btn.add_theme_color_override("font_color", active_color if index == 3 else inactive_color)
	pets_btn.add_theme_color_override("font_color", active_color if index == 4 else inactive_color)
	town_btn.add_theme_color_override("font_color", active_color if index == 5 else inactive_color)
	expeditions_btn.add_theme_color_override("font_color", active_color if index == 6 else inactive_color)

	# Refresh tab content when switching to it
	if index == 6:
		_build_expeditions_tab()

	# Refresh tab content when switching to it
	if index == 2:
		_refresh_settings()
	elif index == 3:
		_refresh_animal_buttons()
	elif index == 4:
		_build_pets_tab()


func _on_items_tab_pressed() -> void:
	_show_tab(0)


func _on_time_tab_pressed() -> void:
	_show_tab(1)


func _on_settings_tab_pressed() -> void:
	_show_tab(2)


func _on_creatures_tab_pressed() -> void:
	_show_tab(3)


func _on_pets_tab_pressed() -> void:
	_show_tab(4)

func _on_town_tab_pressed() -> void:
	_show_tab(5)

func _on_expeditions_tab_pressed() -> void:
	_show_tab(6)

func _on_restore_all_pressed() -> void:
	var tm := get_tree().get_first_node_in_group("town_manager") as TownManager
	if not tm:
		ToastNotification.show_toast("No TownManager found!", ToastNotification.ToastType.ERROR, 2.0)
		return
	
	# Use RPC to forward to host in multiplayer
	if NetworkManager.is_network_active():
		if not multiplayer.is_server():
			# This is a client, request from host
			tm.rpc_id(1, "_server_request_creative_restore_all")
		else:
			# This is the host, execute directly
			tm.creative_restore_all()
	else:
		# Single player
		tm.creative_restore_all()
	ToastNotification.show_toast("All ruins restored!", ToastNotification.ToastType.SUCCESS, 3.0)


func _on_list_residents_pressed() -> void:
	## Print all residents and their assigned homes to the console/log.
	# Check TownManager residents
	var town_mgr := get_tree().get_first_node_in_group("town_manager") as TownManager
	if not town_mgr:
		ToastNotification.show_toast("No TownManager found!", ToastNotification.ToastType.ERROR, 2.0)
		return
	
	var lines: Array[String] = []
	if town_mgr.residents.is_empty():
		lines.append("No residents registered in TownManager.")
	else:
		lines.append("--- Town Residents (TownManager) ---")
		for rid: String in town_mgr.residents:
			var rd = town_mgr.residents[rid] as TownManager.ResidentData
			if rd:
				var def := town_mgr.get_ruin_def(rd.home_ruin_id)
				var building_name: String = def.building_name if def else "Unknown"
				lines.append("  %s (%s) — home: %s (%s)" % [rd.npc_name, rd.role, building_name, rd.home_ruin_id])
		lines.append("Total: %d" % town_mgr.residents.size())
	
	# Also check for actual TownResidentNPC nodes in the world
	var npcs: Array[Node] = get_tree().get_nodes_in_group("town_residents")
	lines.append("--- TownResidentNPC nodes in world ---")
	if npcs.is_empty():
		lines.append("  None found.")
	else:
		for n in npcs:
			if n is TownResidentNPC:
				lines.append("  %s (role=%d, visitor_type=%d) @ %s" % [n.npc_name, n.role, n.visitor_type, n.global_position])
		lines.append("Total: %d" % npcs.size())
	
	var output: String = "\n".join(lines)
	print(output)
	ToastNotification.show_toast("Residents listed (%d in TownManager, %d in world)" % [town_mgr.residents.size(), npcs.size()], ToastNotification.ToastType.INFO, 3.0)


func _on_recruit_visitor_pressed() -> void:
	## Directly recruit a visitor to a vacant building (bypasses conversation).
	var recruiter := get_tree().get_first_node_in_group("resident_recruiter") as ResidentRecruiter
	if not recruiter or not recruiter.has_method("try_recruit"):
		ToastNotification.show_toast("No ResidentRecruiter found!", ToastNotification.ToastType.ERROR, 2.0)
		return
	var result: Dictionary = recruiter.try_recruit()
	if not result.is_empty():
		ToastNotification.show_toast(
			"%s has moved into %s!" % [result.get("npc_name", "A visitor"), result.get("building_name", "a building")],
			ToastNotification.ToastType.SUCCESS,
			4.0
		)
	else:
		# Give specific feedback so the player knows which condition blocked it.
		var reason: String = _recruit_failure_reason()
		ToastNotification.show_toast(reason, ToastNotification.ToastType.WARNING, 2.5)


func _recruit_failure_reason() -> String:
	var town_mgr := get_tree().get_first_node_in_group("town_manager") as TownManager
	if town_mgr and town_mgr.get_vacancy_count() <= 0:
		return "No vacant buildings available — restore more ruins first!"
	var ship_npcs: int = 0
	var vm := get_tree().get_first_node_in_group("visitor_manager")
	if vm and vm.has_method("has_active_visitors") and vm.has_active_visitors():
		ship_npcs = 1
	var island_npcs: Array[Node] = get_tree().get_nodes_in_group("visitor_npcs")
	if ship_npcs > 0 or not island_npcs.is_empty():
		return "Visitors are present but no matching home was found for them."
	return "No visitors on the island — spawn a visitor boat first, or wait for one to arrive."


func _on_spawn_visitor_boat_pressed() -> void:
	## Spawn a visitor ship immediately (bypasses arrival schedule).
	var vm := get_tree().get_first_node_in_group("visitor_manager")
	if not vm or not vm.has_method("creative_spawn_ship"):
		ToastNotification.show_toast("No VisitorManager found!", ToastNotification.ToastType.ERROR, 2.0)
		return
	vm.creative_spawn_ship()


# --------------------------------------------------------------------------
# Pets tab — unlock and equip pets in creative mode
# --------------------------------------------------------------------------

# All available pet IDs, matching PetManager data
const CREATIVE_PET_IDS: Array[String] = ["cat", "dog", "fox", "bird", "turtle", "rabbit", "ice_cream_sandwich", "gingerbread_man"]

const PET_COLORS: Dictionary = {
	"cat": Color(1.0, 0.65, 0.0),    # Orange
	"dog": Color(0.6, 0.4, 0.2),     # Brown
	"fox": Color(0.9, 0.3, 0.1),     # Red
	"bird": Color(0.3, 0.5, 0.9),    # Blue
	"turtle": Color(0.2, 0.7, 0.3),  # Green
	"rabbit": Color(1.0, 0.6, 0.8),  # Pink
	"ice_cream_sandwich": Color(0.55, 0.28, 0.1),  # Chocolate brown
	"gingerbread_man": Color(0.7, 0.38, 0.15),  # Gingerbread brown
}

var _pet_buttons: Array[Button] = []

func _build_pets_tab() -> void:
	# Clear ALL pet list children (not just buttons) to prevent duplication
	# each time the tab is shown
	for child in pet_list.get_children():
		child.queue_free()
	_pet_buttons.clear()
	
	# Info label
	var info := Label.new()
	info.text = "In Creative Mode, all pets are freely available. Just select one to equip it."
	info.autowrap_mode = TextServer.AUTOWRAP_WORD
	info.custom_minimum_size = Vector2(0, 36)
	info.add_theme_color_override("font_color", Color(0.8, 0.8, 0.6))
	info.add_theme_font_size_override("font_size", 11)
	pet_list.add_child(info)
	
	pet_list.add_child(HSeparator.new())
	
	# Individual pet equip buttons
	for pet_id: String in CREATIVE_PET_IDS:
		var hbox := HBoxContainer.new()
		hbox.custom_minimum_size = Vector2(0, 34)
		
		var name_label := Label.new()
		name_label.text = pet_id.capitalize()
		name_label.custom_minimum_size = Vector2(100, 0)
		name_label.add_theme_color_override("font_color", PET_COLORS.get(pet_id, Color.WHITE))
		name_label.add_theme_font_size_override("font_size", 13)
		hbox.add_child(name_label)
		
		# Equip button (no unlock needed in creative)
		var equip_btn := Button.new()
		equip_btn.text = "Equip"
		equip_btn.custom_minimum_size = Vector2(100, 30)
		equip_btn.pressed.connect(_on_creative_equip_pet.bind(pet_id))
		hbox.add_child(equip_btn)
		
		pet_list.add_child(hbox)
		_pet_buttons.append(equip_btn)
	
	# Status display
	pet_list.add_child(HSeparator.new())
	var status_label := Label.new()
	status_label.name = "PetStatusLabel"
	status_label.add_theme_font_size_override("font_size", 11)
	status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	pet_list.add_child(status_label)
	_update_pet_status()


func _update_pet_status() -> void:
	var status := pet_list.get_node_or_null("PetStatusLabel") as Label
	if not status:
		return
	var owned: Array = PetManager.owned_pets
	var active: String = PetManager.active_pet_id
	var owned_str := "None" if owned.is_empty() else ", ".join(owned)
	var active_str := active if not active.is_empty() else "None"
	status.text = "Owned: %s\nActive: %s" % [owned_str, active_str]


func _on_creative_equip_pet(pet_id: String) -> void:
	# In creative mode, auto-unlock and equip freely
	if not PetManager.has_pet(pet_id):
		PetManager.unlock_pet(pet_id)
	PetManager.active_pet_id = pet_id
	ToastNotification.show_toast("🐾 " + PetManager.get_pet_display_name(pet_id) + " is now your active pet!", ToastNotification.ToastType.SUCCESS, 2.0)
	_update_pet_status()


# --------------------------------------------------------------------------
# Items tab — category-grouped item spawning
# --------------------------------------------------------------------------

func _build_item_list() -> void:
	_build_retries += 1
	if _build_retries > 30:
		push_warning("CreativePanel: DataManager not ready after 30 retries, giving up")
		return
	if not DataManager or DataManager.items.is_empty():
		call_deferred("_build_item_list")
		return
	_build_retries = 0

	_all_items.clear()
	for item_id: String in DataManager.items.keys():
		_all_items.append(item_id)

	_filtered_items = _all_items.duplicate()
	_rebuild_grid()


func _rebuild_grid() -> void:
	# Clear existing buttons and category list
	for btn in _item_buttons:
		btn.queue_free()
	_item_buttons.clear()
	for child in category_list.get_children():
		child.queue_free()

	# Group filtered items by category (skip building kits & inconstant fruits — they get their own sections)
	var by_category: Dictionary = {}  # category_name -> Array[String] item_ids
	var visible_building_ids: Array[String] = []
	var legendary_fruit_ids: Array[String] = []
	for item_id: String in _filtered_items:
		var item_data: ItemData = DataManager.get_item(item_id)
		if not item_data:
			continue
		if item_id in BUILDING_KIT_IDS:
			visible_building_ids.append(item_id)
			continue
		if item_data.get_meta("inconstant_power", false):
			legendary_fruit_ids.append(item_id)
			continue
		var cat: String = item_data.category
		# Fold lone categories into broader groups for display
		if cat == "weapon":
			cat = "tool"
		if not by_category.has(cat):
			by_category[cat] = []
		by_category[cat].append(item_id)

	# Render each category section
	for cat in CATEGORY_ORDER:
		var items_in_cat: Array = by_category.get(cat, [])
		if items_in_cat.is_empty():
			continue

		items_in_cat.sort()

		# Header label
		var header := Label.new()
		header.text = CATEGORY_DISPLAY_NAMES.get(cat, cat.capitalize())
		if CATEGORY_COLORS.has(cat):
			header.add_theme_color_override("font_color", CATEGORY_COLORS[cat])
		header.add_theme_font_size_override("font_size", 13)
		header.custom_minimum_size = Vector2(0, 22)
		category_list.add_child(header)

		# Grid for items in this category
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 4)
		category_list.add_child(grid)

		for item_id: String in items_in_cat:
			var item_data: ItemData = DataManager.get_item(item_id)
			if not item_data:
				continue

			var btn := Button.new()
			btn.custom_minimum_size = Vector2(140, 28)
			btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			btn.text = item_data.display_name
			btn.tooltip_text = _bbcode_to_plain(item_data.description)
			btn.pressed.connect(_on_item_pressed.bind(item_id))

			var cat_color: Color = CATEGORY_COLORS.get(item_data.category, Color.WHITE)
			btn.add_theme_color_override("font_color", cat_color)

			grid.add_child(btn)
			_item_buttons.append(btn)

	# If no categories matched (all items filtered out), show a hint
	if category_list.get_child_count() == 0:
		var hint := Label.new()
		hint.text = "No items match your search."
		hint.modulate = Color(0.7, 0.7, 0.7)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		category_list.add_child(hint)

	# --- Buildings section (always shown, even during search) ---
	if not visible_building_ids.is_empty():
		var sep := HSeparator.new()
		category_list.add_child(sep)

		var b_header := Label.new()
		b_header.text = "Buildings"
		b_header.add_theme_color_override("font_color", Color(0.8, 0.65, 0.35))
		b_header.add_theme_font_size_override("font_size", 13)
		b_header.custom_minimum_size = Vector2(0, 22)
		category_list.add_child(b_header)

		var b_grid := GridContainer.new()
		b_grid.columns = 3
		b_grid.add_theme_constant_override("h_separation", 6)
		b_grid.add_theme_constant_override("v_separation", 4)
		category_list.add_child(b_grid)

		visible_building_ids.sort()
		for item_id: String in visible_building_ids:
			var item_data: ItemData = DataManager.get_item(item_id)
			if not item_data:
				continue
			var btn := Button.new()
			btn.custom_minimum_size = Vector2(140, 28)
			btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			btn.text = item_data.display_name
			btn.tooltip_text = _bbcode_to_plain(item_data.description)
			btn.pressed.connect(_on_item_pressed.bind(item_id))
			btn.add_theme_color_override("font_color", Color(0.8, 0.65, 0.35))
			b_grid.add_child(btn)
			_item_buttons.append(btn)

	# --- Legendary Fruits section ---
	if not legendary_fruit_ids.is_empty():
		var sep := HSeparator.new()
		category_list.add_child(sep)

		var lf_header := Label.new()
		lf_header.text = "Legendary Fruits"
		lf_header.add_theme_color_override("font_color", Color(1.0, 0.6, 0.0))
		lf_header.add_theme_font_size_override("font_size", 13)
		lf_header.custom_minimum_size = Vector2(0, 22)
		category_list.add_child(lf_header)

		var lf_grid := GridContainer.new()
		lf_grid.columns = 3
		lf_grid.add_theme_constant_override("h_separation", 6)
		lf_grid.add_theme_constant_override("v_separation", 4)
		category_list.add_child(lf_grid)

		legendary_fruit_ids.sort()
		for item_id: String in legendary_fruit_ids:
			var item_data: ItemData = DataManager.get_item(item_id)
			if not item_data:
				continue
			var btn := Button.new()
			btn.custom_minimum_size = Vector2(140, 28)
			btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			btn.text = item_data.display_name
			btn.tooltip_text = _bbcode_to_plain(item_data.description)
			btn.pressed.connect(_on_item_pressed.bind(item_id))
			btn.add_theme_color_override("font_color", Color(1.0, 0.6, 0.0))
			lf_grid.add_child(btn)
			_item_buttons.append(btn)


func _on_search_changed(filter_text: String) -> void:
	_filtered_items.clear()
	var lower := filter_text.to_lower()
	for item_id: String in _all_items:
		var item_data: ItemData = DataManager.get_item(item_id)
		if not item_data:
			continue
		if lower.is_empty() or \
		   item_id.to_lower().contains(lower) or \
		   item_data.display_name.to_lower().contains(lower):
			_filtered_items.append(item_id)
	_rebuild_grid()


func _on_item_pressed(item_id: String) -> void:
	# Add item to inventory — cap at stack_size (tools get 1, seeds get up to 10)
	var item_data_check: ItemData = DataManager.get_item(item_id)
	var spawn_amount := clampi(item_data_check.stack_size if item_data_check else 10, 1, 10)
	var leftover := InventoryManager.add_item(item_id, spawn_amount)
	var added := spawn_amount - leftover
	if added > 0:
		var item_data: ItemData = DataManager.get_item(item_id)
		var name_str := item_data.display_name if item_data else item_id
		_show_feedback("+%d %s" % [added, name_str])
	else:
		_show_feedback("Inventory full!")


func _show_feedback(text: String) -> void:
	if not _feedback_label or not is_instance_valid(_feedback_label):
		return
	_feedback_label.text = text
	_feedback_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.5)
	tw.tween_property(_feedback_label, "modulate:a", 0.0, 0.5)


# --------------------------------------------------------------------------
# Time tab
# --------------------------------------------------------------------------

func _on_pause_pressed() -> void:
	if GameManager:
		GameManager.toggle_creative_time_pause()
		_update_pause_button()


func _update_pause_button() -> void:
	if not GameManager:
		return
	pause_btn.text = "Resume Time" if GameManager.creative_time_paused else "Pause Time"


func _on_hour_changed(value: float) -> void:
	var h := int(value)
	hour_label.text = "%02d:00" % [h]
	if GameManager:
		GameManager.set_time(h, 0)


func _on_advance_day() -> void:
	if GameManager:
		GameManager.request_advance_days(1)


func _on_instant_growth_toggled(pressed: bool) -> void:
	if GameManager:
		GameManager.set_creative_instant_growth(pressed)


func _on_weather_pressed(weather: WeatherSystem.WeatherType) -> void:
	if not GameManager:
		return
	# Host-authoritative: on a client this forwards to the host, which applies
	# and broadcasts _receive_time_state so every peer sees the same weather.
	GameManager.request_force_weather(int(weather))
	var weather_name: String = WeatherSystem.WeatherType.keys()[weather]
	ToastNotification.show_toast("☁ Weather set to " + weather_name, ToastNotification.ToastType.INFO, 2.0)


# --------------------------------------------------------------------------
# Settings tab
# --------------------------------------------------------------------------

func _refresh_settings() -> void:
	for child in settings_list.get_children():
		child.queue_free()

	# Creative mode info
	var info := Label.new()
	info.text = "Toggle individual Creative Mode perks below."
	info.autowrap_mode = TextServer.AUTOWRAP_WORD
	info.custom_minimum_size = Vector2(0, 30)
	info.add_theme_color_override("font_color", Color(0.8, 0.8, 0.6))
	info.add_theme_font_size_override("font_size", 11)
	settings_list.add_child(info)

	settings_list.add_child(HSeparator.new())

	# Infinite Health toggle
	var health_toggle := _make_toggle_row("Infinite Health", GameManager.creative_infinite_health, _on_infinite_health_toggled)
	settings_list.add_child(health_toggle)

	# No Hunger toggle
	var hunger_toggle := _make_toggle_row("No Hunger", GameManager.creative_no_hunger, _on_no_hunger_toggled)
	settings_list.add_child(hunger_toggle)

	# Enable Enemy Spawning toggle
	var enemy_toggle := _make_toggle_row("Enable Enemy Spawning", GameManager.creative_enemy_spawning, _on_enemy_spawning_toggled)
	settings_list.add_child(enemy_toggle)

	settings_list.add_child(HSeparator.new())

	# Refill Health button
	var heal_btn := Button.new()
	heal_btn.text = "Refill Health & Hunger"
	heal_btn.custom_minimum_size = Vector2(160, 32)
	heal_btn.pressed.connect(_on_heal_pressed)
	settings_list.add_child(heal_btn)

	# Kill All Enemies button
	var kill_btn := Button.new()
	kill_btn.text = "Kill All Enemies"
	kill_btn.custom_minimum_size = Vector2(160, 32)
	kill_btn.pressed.connect(_on_kill_enemies_pressed)
	settings_list.add_child(kill_btn)

	settings_list.add_child(HSeparator.new())

	# Level editor section
	var level_title := Label.new()
	level_title.text = "Player Level"
	level_title.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	level_title.add_theme_font_size_override("font_size", 13)
	settings_list.add_child(level_title)

	if LevelManager:
		var level_info := Label.new()
		level_info.name = "LevelInfo"
		level_info.text = "Level: %d | XP: %d / %d" % [
			LevelManager.player_level,
			LevelManager.current_xp,
			LevelManager.get_xp_for_next_level(),
		]
		level_info.add_theme_font_size_override("font_size", 11)
		level_info.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		settings_list.add_child(level_info)

		# Custom XP amount row
		var xp_row := HBoxContainer.new()
		var xp_spin := SpinBox.new()
		xp_spin.name = "XPSpinBox"
		xp_spin.min_value = 0
		xp_spin.max_value = 99999
		xp_spin.value = 500
		xp_spin.custom_minimum_size = Vector2(80, 28)
		xp_row.add_child(xp_spin)
		var grant_xp_btn := Button.new()
		grant_xp_btn.text = "Grant XP"
		grant_xp_btn.custom_minimum_size = Vector2(100, 28)
		grant_xp_btn.pressed.connect(_on_add_xp.bind(xp_spin.get_node(".")))
		xp_row.add_child(grant_xp_btn)
		settings_list.add_child(xp_row)

		# Level shortcut buttons
		var level_row := HBoxContainer.new()
		var add_level_btn := Button.new()
		add_level_btn.text = "+1 Level"
		add_level_btn.custom_minimum_size = Vector2(100, 28)
		add_level_btn.pressed.connect(_on_add_xp.bind(-1))  # -1 = add exactly 1 level's worth
		level_row.add_child(add_level_btn)

		var max_level_btn := Button.new()
		max_level_btn.text = "Max Level"
		max_level_btn.custom_minimum_size = Vector2(100, 28)
		max_level_btn.pressed.connect(_on_max_level)
		level_row.add_child(max_level_btn)

		settings_list.add_child(level_row)

	settings_list.add_child(HSeparator.new())

	# Money section
	var money_title := Label.new()
	money_title.text = "Money"
	money_title.add_theme_color_override("font_color", Color(0.95, 0.82, 0.2))
	money_title.add_theme_font_size_override("font_size", 13)
	settings_list.add_child(money_title)

	var money_row := HBoxContainer.new()
	var money_spin := SpinBox.new()
	money_spin.name = "MoneySpinBox"
	money_spin.min_value = 0
	money_spin.max_value = 999999
	money_spin.value = 1000
	money_spin.custom_minimum_size = Vector2(80, 28)
	money_row.add_child(money_spin)
	var grant_money_btn := Button.new()
	grant_money_btn.text = "Grant Money"
	grant_money_btn.custom_minimum_size = Vector2(100, 28)
	grant_money_btn.pressed.connect(_on_grant_money.bind(money_spin.get_node(".")))
	money_row.add_child(grant_money_btn)
	settings_list.add_child(money_row)

	settings_list.add_child(HSeparator.new())

	# Game stats
	var stats_title := Label.new()
	stats_title.text = "Current Stats"
	stats_title.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	stats_title.add_theme_font_size_override("font_size", 13)
	settings_list.add_child(stats_title)

	if GameManager:
		var stats := Label.new()
		var day_str: String = "Day %d" % GameManager.current_day
		var time_str: String = GameManager.get_time_string()
		var season_str: String = GameManager.get_season_name()
		var money_str: String = "$%d" % GameManager.money
		var health_str: String = "HP: %d/%d" % [GameManager.health, GameManager.MAX_HEALTH]
		var hunger_str: String = "Hunger: %d/%d" % [GameManager.hunger, GameManager.MAX_HUNGER]
		stats.text = "%s | %s | %s\n%s | %s | %s" % [day_str, time_str, season_str, money_str, health_str, hunger_str]
		stats.autowrap_mode = TextServer.AUTOWRAP_WORD
		stats.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		stats.add_theme_font_size_override("font_size", 11)
		settings_list.add_child(stats)


func _on_heal_pressed() -> void:
	if GameManager:
		GameManager.reset_health()
		GameManager.reset_hunger()
		ToastNotification.show_toast("Health & Hunger fully restored!", ToastNotification.ToastType.SUCCESS, 2.0)


func _on_kill_enemies_pressed() -> void:
	if NetworkManager.is_network_active() and not multiplayer.is_server():
		# Client: ask the host to kill, so every peer's enemy copies die via the
		# host's _sync_enemy_died broadcast (a local-only kill leaves the other
		# players' copies alive).
		rpc_id(1, "_server_request_kill_all_enemies")
		ToastNotification.show_toast("Kill-all requested from host…", ToastNotification.ToastType.INFO, 2.0)
		return
	_kill_all_enemies_local()


## Host: receive a client's kill-all request and apply it on the authority copy.
@rpc("any_peer", "reliable")
func _server_request_kill_all_enemies() -> void:
	if not multiplayer.is_server():
		return
	_kill_all_enemies_local()


func _kill_all_enemies_local() -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var count := 0
	for enemy in enemies:
		if enemy.has_method("die"):
			enemy.die()
			count += 1
	if count > 0:
		ToastNotification.show_toast("Killed %d enemies!" % count, ToastNotification.ToastType.SUCCESS, 2.0)
	else:
		ToastNotification.show_toast("No enemies to kill.", ToastNotification.ToastType.INFO, 2.0)


func _on_add_xp(source) -> void:
	if not LevelManager:
		return
	var amount: int
	if source is SpinBox:
		amount = int(source.value)
	elif source is int:
		amount = source
	else:
		return
	if amount == -1:
		# "Add 1 level" — add exactly enough XP for the next level
		var needed: int = LevelManager.get_xp_for_next_level()
		LevelManager.add_xp(needed, "creative_debug")
	else:
		LevelManager.add_xp(amount, "creative_debug")

	# Refresh the settings display
	_refresh_settings()
	ToastNotification.show_toast("Level: %d | XP: %d/%d" % [
		LevelManager.player_level,
		LevelManager.current_xp,
		LevelManager.get_xp_for_next_level(),
	], ToastNotification.ToastType.SUCCESS, 2.0)


func _on_max_level() -> void:
	if not LevelManager:
		return
	# Grant enough XP to reach level 100
	var total_needed := 0
	for lvl in range(LevelManager.player_level, 100):
		total_needed += LevelManager.xp_to_next(lvl)
	if total_needed > 0:
		LevelManager.add_xp(total_needed, "creative_debug")
	_refresh_settings()
	ToastNotification.show_toast("Maxed out at Level 100!", ToastNotification.ToastType.SUCCESS, 2.5)


func _on_grant_money(source) -> void:
	if not GameManager:
		return
	var amount: int
	if source is SpinBox:
		amount = int(source.value)
	else:
		return
	GameManager.money = amount
	GameManager.money_changed.emit(GameManager.money)
	_refresh_settings()
	ToastNotification.show_toast("Money set to $%d!" % amount, ToastNotification.ToastType.SUCCESS, 2.0)


# --------------------------------------------------------------------------
# Creative mode toggle helpers
# --------------------------------------------------------------------------

func _on_infinite_health_toggled(toggled_on: bool) -> void:
	if GameManager:
		GameManager.creative_infinite_health = toggled_on
		var msg := "Infinite Health " + ("ON" if toggled_on else "OFF")
		ToastNotification.show_toast(msg, ToastNotification.ToastType.INFO, 2.0)


func _on_no_hunger_toggled(toggled_on: bool) -> void:
	if GameManager:
		GameManager.creative_no_hunger = toggled_on
		var msg := "No Hunger " + ("ON" if toggled_on else "OFF")
		ToastNotification.show_toast(msg, ToastNotification.ToastType.INFO, 2.0)


func _on_enemy_spawning_toggled(toggled_on: bool) -> void:
	if not GameManager:
		return
	GameManager.creative_enemy_spawning = toggled_on
	if toggled_on:
		# Force the existence check: the EnemySpawner is a child of the World node
		var world := get_tree().get_first_node_in_group("world")
		if world:
			var spawner := world.get_node_or_null("EnemySpawner")
			if spawner and spawner.has_method("_on_game_mode_changed"):
				# Refresh the spawner so it picks up the toggle immediately
				spawner._on_game_mode_changed(GameManager.game_mode)
		ToastNotification.show_toast("Enemy spawning ENABLED — they will spawn at night", ToastNotification.ToastType.WARNING, 3.0)
	else:
		# Despawn all current enemies when toggling off
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(enemy):
				enemy.queue_free()
		ToastNotification.show_toast("Enemy spawning DISABLED — all enemies removed", ToastNotification.ToastType.INFO, 2.0)


## Helper: creates a labeled toggle/checkbox row.
func _make_toggle_row(label_text: String, default_state: bool, callback: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 28)
	
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(160, 0)
	label.add_theme_font_size_override("font_size", 13)
	row.add_child(label)
	
	var check := CheckButton.new()
	check.button_pressed = default_state
	check.toggled.connect(callback)
	row.add_child(check)
	
	return row


# --------------------------------------------------------------------------
# Creatures tab — enemy & animal spawning
# --------------------------------------------------------------------------

# Enemy types: [display_name, class_reference]
const CREATURE_ENEMIES: Array[Dictionary] = [
	{"name": "Casper (Ghost)",        "scene": "res://scripts/world/enemies/GhostEnemy.gd",     "color": Color(0.6, 0.8, 1.0)},
	{"name": "Sporeling",             "scene": "res://scripts/world/enemies/SporelingEnemy.gd", "color": Color(0.9, 0.5, 0.5)},
	{"name": "Cinder Imp",            "scene": "res://scripts/world/enemies/CinderImp.gd",      "color": Color(1.0, 0.5, 0.1)},
	{"name": "Shadow Hound",          "scene": "res://scripts/world/enemies/ShadowHound.gd",    "color": Color(0.4, 0.3, 0.5)},
	{"name": "Frost Wisp",            "scene": "res://scripts/world/enemies/FrostWisp.gd",      "color": Color(0.5, 0.7, 1.0)},
]

# Boss types (use scene paths for proper instantiation with child nodes)
const CREATURE_BOSSES: Array[Dictionary] = [
	{"name": "Root Warden",           "scene": "res://scenes/enemies/RootWarden.tscn",     "color": Color(0.5, 0.25, 0.1)},
	{"name": "Hollow Stag",           "scene": "res://scenes/enemies/HollowStag.tscn",     "color": Color(0.9, 0.75, 0.2)},
	{"name": "Blooming Wyrm",         "scene": "res://scenes/enemies/BloomingWyrm.tscn",   "color": Color(0.85, 0.3, 0.55)},
	{"name": "Inconstant Soul",      "scene": "res://scenes/enemies/InconstantSoul.tscn", "color": Color(0.5, 0.15, 0.7)},
]

# Animal buttons are built dynamically from animals alive on the map.


func _build_creature_buttons() -> void:
	# Enemies
	for entry in CREATURE_ENEMIES:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(130, 28)
		btn.text = entry["name"]
		btn.add_theme_color_override("font_color", entry["color"])
		btn.tooltip_text = "Spawn " + entry["name"] + " near the player"
		btn.pressed.connect(_spawn_enemy.bind(entry["scene"]))
		enemy_grid.add_child(btn)

	# Bosses
	for entry in CREATURE_BOSSES:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(150, 28)
		btn.text = entry["name"]
		btn.add_theme_color_override("font_color", entry["color"])
		btn.tooltip_text = "Spawn " + entry["name"] + " near the player"
		btn.pressed.connect(_spawn_boss.bind(entry["scene"]))
		boss_grid.add_child(btn)

	# Pirate Raid trigger
	pirate_raid_btn.pressed.connect(_on_pirate_raid_pressed)
	
	# Blood Moon trigger
	blood_moon_btn.pressed.connect(_on_blood_moon_pressed)

	# Animals — one button per living animal on the map.
	# Each button spawns an identical copy (same name, type, colours, pattern).
	_refresh_animal_buttons()


## Clears and re-builds the animal buttons from currently living animals.
## Called during initial build and whenever the Creatures tab is shown.
func _refresh_animal_buttons() -> void:
	# Clear existing animal buttons
	for btn in _animal_buttons:
		btn.queue_free()
	_animal_buttons.clear()

	var all_animals := get_tree().get_nodes_in_group("animals")
	
	if all_animals.is_empty():
		var label := Label.new()
		label.text = "No animals on the map yet"
		label.modulate = Color(0.6, 0.6, 0.6)
		label.add_theme_font_size_override("font_size", 12)
		animal_grid.add_child(label)
		# Use a dummy button to hold the spot (buttons are cleared on refresh)
		var dummy := Button.new()
		dummy.flat = true
		dummy.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dummy.text = "  No animals on the map yet"
		dummy.disabled = true
		animal_grid.add_child(dummy)
		_animal_buttons.append(dummy)
		return

	var seen_names: Dictionary = {}  # "name" -> true, to show one button per unique name
	for a in all_animals:
		if not is_instance_valid(a):
			continue
		var name_str: String = str(a.animal_name)
		var type_str: String = str(a.animal_type)
		if name_str.is_empty() or name_str == "Animal":
			continue

		# Only one button per unique name — spawning creates another with same name,
		# so deduping by name keeps the list clean.
		if seen_names.has(name_str):
			continue
		seen_names[name_str] = true

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(130, 28)
		btn.text = name_str
		btn.tooltip_text = "Spawn a copy of this " + type_str.capitalize()

		# Snapshot all visual properties so the button works even if the
		# source animal dies or changes later.
		var template: Dictionary = {
			"animal_type": type_str,
			"animal_name": name_str,
			"body_color": a.body_color,
			"accent_color": a.accent_color,
			"secondary_color": a.secondary_color,
			"spot_color": a.spot_color,
			"behavior": a.behavior,
			"move_speed": a.move_speed,
			"_body_shape": a._body_shape,
			"_pattern": a._pattern,
			"max_health": a.max_health,
		}
		btn.pressed.connect(_spawn_animal_from_template.bind(template))
		animal_grid.add_child(btn)
		_animal_buttons.append(btn)


## Gets a spawn position near the player (30-50px in a random direction)
func _get_spawn_position() -> Vector2:
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return Vector2.ZERO
	var angle := randf_range(0.0, TAU)
	var dist := randf_range(30.0, 50.0)
	return player.global_position + Vector2(cos(angle), sin(angle)) * dist


func _spawn_enemy(scene_path: String) -> void:
	var gdscript := load(scene_path) as GDScript
	if not gdscript:
		_show_feedback("Failed to load: " + scene_path.get_file())
		return

	var enemy: Enemy = gdscript.new()
	if not enemy:
		_show_feedback("Failed to create enemy!")
		return

	var spawner := get_tree().get_first_node_in_group("enemy_spawner") as EnemySpawner
	var pos := _get_spawn_position()

	if NetworkManager.is_network_active():
		if not multiplayer.is_server():
			# Client: ask the host to spawn so every peer gets a copy.
			if spawner:
				spawner.rpc_id(1, "_server_request_creative_spawn_enemy", scene_path, pos.x, pos.y)
				_show_feedback("Requested " + enemy.display_name + " spawn!")
			else:
				_show_feedback("No enemy spawner found!")
			return
		if spawner:
			spawner.spawn_creative_enemy(enemy, pos)
			_show_feedback("Spawned " + enemy.display_name + "!")
		else:
			enemy.queue_free()
			_show_feedback("No enemy spawner found!")
		return

	# Single player
	enemy.global_position = pos
	var world := get_tree().current_scene
	if world:
		world.add_child(enemy)
		_show_feedback("Spawned " + enemy.display_name + "!")
	else:
		enemy.queue_free()
		_show_feedback("No world to spawn into!")


func _spawn_boss(scene_path: String) -> void:
	var BossScene = load(scene_path) as PackedScene
	if not BossScene:
		_show_feedback("Failed to load boss scene: " + scene_path.get_file())
		return

	var enemy: Enemy = BossScene.instantiate()
	if not enemy:
		_show_feedback("Failed to create boss!")
		return

	var spawner := get_tree().get_first_node_in_group("enemy_spawner") as EnemySpawner
	var pos := _get_spawn_position()

	if NetworkManager.is_network_active():
		if not multiplayer.is_server():
			# Client: ask the host to spawn so every peer gets a copy.
			if spawner:
				spawner.rpc_id(1, "_server_request_creative_spawn_boss", scene_path, pos.x, pos.y)
				_show_feedback("Requested " + enemy.display_name + " summon!")
			else:
				_show_feedback("No enemy spawner found!")
			return
		if spawner:
			# Only trigger the dramatic boss entrance effects if the boss was
			# actually added to the tree. A rejected boss (e.g. inside a building)
			# is queue_free()d and never enters the tree, so calling
			# _summon_spawn_effect() on it crashes get_tree().
			if spawner.spawn_creative_boss(enemy, scene_path, pos):
				if enemy.has_method("_summon_spawn_effect"):
					enemy._summon_spawn_effect()
				_show_feedback("Spawned " + enemy.display_name + "!")
			else:
				_show_feedback("Can't summon a boss here!")
		else:
			enemy.queue_free()
			_show_feedback("No enemy spawner found!")
		return

	# Single player
	enemy.global_position = pos
	var world := get_tree().current_scene
	if world:
		world.add_child(enemy)
		# Trigger dramatic boss entrance effects
		if enemy.has_method("_summon_spawn_effect"):
			enemy._summon_spawn_effect()
		_show_feedback("Spawned " + enemy.display_name + "!")
	else:
		enemy.queue_free()
		_show_feedback("No world to spawn into!")


## Spawns an animal that is an exact visual copy of a living map animal.
## The template dictionary is built by _refresh_animal_buttons() from the
## source animal's exported/property values.
func _on_pirate_raid_pressed() -> void:
	# Find the pirate raid system in the world
	var world := get_tree().get_first_node_in_group("world")
	if not world:
		ToastNotification.show_toast("☠ No world found!", ToastNotification.ToastType.ERROR, 2.0)
		return
	var raid = world.pirate_raid
	if not raid:
		ToastNotification.show_toast("☠ No pirate raid system found!", ToastNotification.ToastType.ERROR, 2.0)
		return
	if raid.is_raid_active():
		ToastNotification.show_toast("☠ A raid is already active!", ToastNotification.ToastType.WARNING, 2.0)
		return
	raid.trigger_raid()


func _on_blood_moon_pressed() -> void:
	# Find the blood moon event system in the world
	var world := get_tree().get_first_node_in_group("world")
	if not world:
		ToastNotification.show_toast("🌕 No world found!", ToastNotification.ToastType.ERROR, 2.0)
		return
	var bm = world.blood_moon_event
	if not bm:
		ToastNotification.show_toast("🌕 No blood moon system found!", ToastNotification.ToastType.ERROR, 2.0)
		return
	if bm.is_active:
		ToastNotification.show_toast("🌕 Blood moon is already active!", ToastNotification.ToastType.WARNING, 2.0)
		return
	# Force-trigger the blood moon
	bm.trigger_blood_moon()


func _spawn_animal_from_template(template: Dictionary) -> void:
	var animal := ANIMAL_SCENE.instantiate()
	if not animal:
		_show_feedback("Failed to create animal!")
		return

	animal.global_position = _get_spawn_position()

	# Apply all properties from the template
	animal.animal_type = template.get("animal_type", "chicken")
	animal.animal_name = template.get("animal_name", "Animal")
	animal.body_color = template.get("body_color", Color.WHITE)
	animal.accent_color = template.get("accent_color", Color.ORANGE_RED)
	animal.secondary_color = template.get("secondary_color", Color(0.9, 0.9, 0.9))
	animal.spot_color = template.get("spot_color", Color(0.4, 0.3, 0.2))
	animal.behavior = template.get("behavior", 0)
	animal.move_speed = template.get("move_speed", 30.0)
	animal.set("_body_shape", template.get("_body_shape", 0))
	animal.set("_pattern", template.get("_pattern", 0))

	animal.current_health = animal.max_health

	var world := get_tree().current_scene
	if not world:
		animal.queue_free()
		_show_feedback("No world to spawn into!")
		return

	world.add_child(animal)

	# Re-generate the procedural sprite using the copied visual properties
	animal._generate_procedural_sprite()
	animal.interaction_prompt = "Pet " + animal.animal_name

	# Update the name label to show immediately
	if animal.label:
		animal.label.text = animal.animal_name

	_show_feedback("Spawned " + animal.animal_name + "!")


# --------------------------------------------------------------------------
# Open / Close
# --------------------------------------------------------------------------

func toggle() -> void:
	if not GameManager or not GameManager.is_creative():
		return
	if _is_open:
		close()
	else:
		open()


func open() -> void:
	_is_open = true
	AudioManager.play(AudioManager.Sound.MENU_OPEN)
	dim.visible = true
	panel.visible = true

	# Refresh time display
	_update_pause_button()
	if GameManager:
		hour_slider.value = GameManager.get_hour()
		instant_growth_toggle.button_pressed = GameManager.creative_instant_growth

	# Show items tab by default
	_show_tab(0)

	# Refresh item list
	_build_item_list()


func close() -> void:
	_is_open = false
	AudioManager.play(AudioManager.Sound.MENU_CLOSE)
	dim.visible = false
	panel.visible = false


func is_open() -> bool:
	return _is_open


## Spawn item at the given index in the filtered list (keyboard shortcut)
func spawn_item_by_index(idx: int) -> void:
	if not _is_open:
		return
	if idx < 0 or idx >= _filtered_items.size():
		return
	_on_item_pressed(_filtered_items[idx])


# --------------------------------------------------------------------------
# Expeditions tab — travel to expedition islands for free in creative mode
# --------------------------------------------------------------------------

## Island type data for display, matching ExpeditionUI.ISLAND_INFO
const EXPEDITION_ISLAND_INFO: Array = [
	{ "type": 0, "name": "Plain", "desc": "A familiar grassy island with gentle hills", "color": Color(0.45, 0.72, 0.32) },
	{ "type": 1, "name": "Snowland", "desc": "A frosty snow-covered island", "color": Color(0.75, 0.80, 0.88) },
	{ "type": 2, "name": "Ice Cream Land", "desc": "A sweet candy-filled island", "color": Color(0.95, 0.75, 0.85) },
	{ "type": 3, "name": "Desert", "desc": "A scorching desert island", "color": Color(0.80, 0.70, 0.40) },
	{ "type": 4, "name": "Volcanic", "desc": "A fiery volcanic island", "color": Color(0.50, 0.30, 0.25) },
	{ "type": 5, "name": "Ethereal", "desc": "A mystical ethereal island", "color": Color(0.60, 0.40, 0.75) },
]

func _build_expeditions_tab() -> void:
	# Cache world reference for travel methods
	_world = get_tree().get_first_node_in_group("world")
	print("CreativePanel: _build_expeditions_tab world=", _world)

	# Clear existing content
	for child in expedition_list.get_children():
		child.queue_free()

	# Random Expedition button
	var random_btn := Button.new()
	random_btn.text = "🎲 Random Expedition"
	random_btn.custom_minimum_size = Vector2(0, 36)
	random_btn.size_flags_horizontal = Control.SIZE_FILL
	random_btn.add_theme_color_override("font_color", Color(0.4, 0.9, 0.7))
	random_btn.pressed.connect(_on_creative_random_expedition)
	expedition_list.add_child(random_btn)

	expedition_list.add_child(HSeparator.new())

	# Specific island type buttons
	var subtitle := Label.new()
	subtitle.text = "Choose Destination:"
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	subtitle.add_theme_font_size_override("font_size", 11)
	expedition_list.add_child(subtitle)

	for info in EXPEDITION_ISLAND_INFO:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_FILL
		row.add_theme_constant_override("separation", 8)

		# Color swatch
		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(24, 24)
		swatch.size = Vector2(24, 24)
		swatch.color = info["color"]
		row.add_child(swatch)

		# Name + description
		var vbox := VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.add_theme_constant_override("separation", 1)

		var name_label := Label.new()
		name_label.text = info["name"]
		name_label.add_theme_font_size_override("font_size", 12)
		name_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7))
		vbox.add_child(name_label)

		var desc_label := Label.new()
		desc_label.text = info["desc"]
		desc_label.add_theme_font_size_override("font_size", 9)
		desc_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.55, 0.8))
		vbox.add_child(desc_label)

		row.add_child(vbox)

		# Travel button — use lambda to match ExpeditionUI pattern exactly
		var travel_btn := Button.new()
		travel_btn.text = "Travel"
		travel_btn.custom_minimum_size = Vector2(80, 32)
		travel_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		travel_btn.pressed.connect(_on_creative_travel_to_island.bind(info["type"]))
		row.add_child(travel_btn)

		expedition_list.add_child(row)

	# Return from island button (shown if currently on an expedition)
	if _world and _world.get("_current_island") != null:
		expedition_list.add_child(HSeparator.new())
		var return_btn := Button.new()
		return_btn.text = "🚢 Return from Expedition"
		return_btn.custom_minimum_size = Vector2(0, 36)
		return_btn.size_flags_horizontal = Control.SIZE_FILL
		return_btn.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
		return_btn.pressed.connect(_on_creative_return_from_island)
		expedition_list.add_child(return_btn)


func _on_creative_random_expedition() -> void:
	print("CreativePanel: _on_creative_random_expedition called, _world=", _world)
	if not _world or not _world.has_method("travel_to_island"):
		push_error("CreativePanel: Could not find world with travel_to_island()")
		return
	AudioManager.play(AudioManager.Sound.BOAT_TRAVEL)
	close()
	_world.travel_to_island()


func _on_creative_travel_to_island(type_val: int) -> void:
	print("CreativePanel: _on_creative_travel_to_island(", type_val, ") called, _world=", _world)
	if not _world or not _world.has_method("travel_to_island_with_type"):
		push_error("CreativePanel: Could not find world with travel_to_island_with_type()")
		return
	AudioManager.play(AudioManager.Sound.BOAT_TRAVEL)
	close()
	_world.travel_to_island_with_type(type_val)


func _on_creative_return_from_island() -> void:
	print("CreativePanel: _on_creative_return_from_island called, _world=", _world)
	if not _world or not _world.has_method("return_from_island"):
		push_error("CreativePanel: Could not find world with return_from_island()")
		return
	AudioManager.play(AudioManager.Sound.BOAT_TRAVEL)
	close()
	_world.return_from_island()
