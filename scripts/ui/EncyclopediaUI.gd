extends CanvasLayer
class_name EncyclopediaUI

## Interactive encyclopedia / world guide. Auto-updates as player discovers
## new content. Opened via Shift+I hotkey or a button.

signal closed()

@onready var dim: ColorRect = $Dim if has_node("Dim") else null
@onready var panel: PanelContainer = $Panel if has_node("Panel") else null
@onready var tabs: TabContainer = $Panel/VBox/TabContainer if has_node("Panel/VBox/TabContainer") else null
@onready var title_label: Label = $Panel/VBox/TitleBar/TitleLabel if has_node("Panel/VBox/TitleBar/TitleLabel") else null

var is_open: bool = false

# Cache of all sections to avoid re-building unnecessarily
var _needs_refresh: bool = true

func _ready() -> void:
	if panel:
		panel.visible = false
	if dim:
		dim.visible = false
	
	# open_encyclopedia action is now defined in project.godot (bound to H key)
	
	# Auto-refresh when new content is discovered
	DataManager.crop_discovered.connect(_on_new_discovery)
	if UpgradeManager.upgrade_purchased.is_connected(_on_new_discovery):
		pass
	UpgradeManager.upgrade_purchased.connect(_on_new_discovery)

func _on_new_discovery(_unused = null) -> void:
	_needs_refresh = true
	if is_open:
		refresh()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_encyclopedia"):
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
	if dim:
		dim.visible = true
	if panel:
		panel.visible = true
	if _needs_refresh:
		refresh()
		_needs_refresh = false

func close() -> void:
	is_open = false
	if dim:
		dim.visible = false
	if panel:
		panel.visible = false
	_needs_refresh = true
	closed.emit()

func _on_close_pressed() -> void:
	close()

func refresh() -> void:
	if not panel or not tabs:
		return
	
	_clear_tabs()
	_needs_refresh = false

func _clear_tabs() -> void:
	if not tabs:
		return
	for child in tabs.get_children():
		child.queue_free()
	_build_all_tabs()

func _build_all_tabs() -> void:
	_build_crops_tab()
	_build_crafting_tab()
	_build_cooking_tab()
	_build_animals_tab()
	_build_biomes_tab()
	_build_buildings_tab()

func _make_scroll_container(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	var vbox := VBoxContainer.new()
	vbox.name = title + "Content"
	scroll.add_child(vbox)
	tabs.add_child(scroll)
	tabs.set_tab_title(tabs.get_tab_count() - 1, title)
	return vbox

func _add_entry(container: VBoxContainer, name: String, subtitle: String, details: String) -> void:
	var frame := PanelContainer.new()
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 3)
	margin.add_theme_constant_override("margin_bottom", 3)
	
	var vbox := VBoxContainer.new()
	
	var title_lbl := Label.new()
	title_lbl.text = name
	title_lbl.add_theme_font_size_override("font_size", 13)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	vbox.add_child(title_lbl)
	
	if subtitle != "":
		var sub_lbl := Label.new()
		sub_lbl.text = subtitle
		sub_lbl.add_theme_font_size_override("font_size", 11)
		sub_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		vbox.add_child(sub_lbl)
	
	if details != "":
		var det_lbl := Label.new()
		det_lbl.text = details
		det_lbl.add_theme_font_size_override("font_size", 10)
		det_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		det_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		vbox.add_child(det_lbl)
	
	margin.add_child(vbox)
	frame.add_child(margin)
	container.add_child(frame)

func _add_hint(container: VBoxContainer, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 0.8))
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	container.add_child(lbl)

# --- Section Builders ---

func _build_crops_tab() -> void:
	var vbox := _make_scroll_container("Crops")
	var discovered := DataManager.get_discovered_crops()
	
	if discovered.is_empty():
		_add_hint(vbox, "Harvest your first crop to unlock the crop guide.")
		return
	
	for crop in discovered:
		var item := DataManager.get_item(crop.yield_item_id)
		var price := item.sell_price if item else 0
		var season_info := ""
		if GameManager.season_system:
			season_info = "\nSeason: Adaptable"
		_add_entry(vbox, crop.display_name, "Rarity: %s" % crop.rarity,
			"Growth: %d days | Yield: %d | Sell: $%d%s" % [crop.days_to_grow, crop.yield_amount, price, season_info])

func _build_crafting_tab() -> void:
	var vbox := _make_scroll_container("Crafting")
	
	var crafting_ui := get_tree().get_first_node_in_group("crafting_ui")
	if not crafting_ui or not crafting_ui.has_method("get_recipes"):
		_add_hint(vbox, "Press [C] to view crafting recipes.")
		return
	
	var recipes = crafting_ui.get_recipes()
	if recipes.is_empty():
		_add_hint(vbox, "No recipes available yet.")
		return
	
	for recipe in recipes:
		_add_entry(vbox, recipe.recipe_name, "→ %s x%d" % [recipe.result_display_name, recipe.result_amount],
			"Ingredients: " + recipe.get_ingredient_summary())

func _build_cooking_tab() -> void:
	var vbox := _make_scroll_container("Cooking")
	var world := get_tree().get_first_node_in_group("world")
	if not world or not world.has_method("get_cooking_system"):
		_add_hint(vbox, "Build a campfire or kitchen to start cooking!")
		return
	
	var cs = world.get_cooking_system()
	if not cs:
		_add_hint(vbox, "Cooking system not available.")
		return
	
	var known: Array = cs.get_known_recipes()
	if known.is_empty():
		_add_hint(vbox, "No recipes discovered yet. Experiment with ingredients at a fire!")
		return
	
	for recipe_id in known:
		var meal = cs.get_meal(recipe_id)
		if meal:
			var ing_str := ""
			for ing_id in meal.ingredients:
				if ing_id == "crop":
					ing_str += "Any crop x%d " % meal.ingredients[ing_id]
				else:
					ing_str += "%s x%d " % [ing_id, meal.ingredients[ing_id]]
			_add_entry(vbox, meal.display_name, meal.description,
				"Ingredients: %s\nBuff: %s (%.1f hrs)" % [ing_str, meal.buff_type, meal.buff_duration])

func _build_animals_tab() -> void:
	var vbox := _make_scroll_container("Animals")
	
	var species := [
		{"name": "Fowl (Chickens/Birds)", "habitat": "Grasslands, Forests", "drops": "Feathers, Eggs", "behavior": "Wander, Graze"},
		{"name": "Bovine (Cows)", "habitat": "Plains, Meadows", "drops": "Milk, Leather", "behavior": "Graze, Wander"},
		{"name": "Burrower (Rabbits)", "habitat": "Forests, Meadows", "drops": "Fur", "behavior": "Skittish, Idle"},
		{"name": "Strider (Deer)", "habitat": "Forests, Mountains", "drops": "Venison, Antlers", "behavior": "Skittish, Wander"},
		{"name": "Caprine (Goats)", "habitat": "Mountains, Hills", "drops": "Milk, Wool", "behavior": "Wander, Graze"},
		{"name": "Ovine (Sheep)", "habitat": "Meadows", "drops": "Wool", "behavior": "Graze, Idle"},
		{"name": "Porcine (Pigs)", "habitat": "Forests, Farms", "drops": "Truffles", "behavior": "Wander, Graze"},
		{"name": "Sciurid (Squirrels)", "habitat": "Forests", "drops": "Nuts", "behavior": "Skittish"},
		{"name": "Anuran (Frogs)", "habitat": "Swamps, Ponds", "drops": "None", "behavior": "Idle, Jump"},
		{"name": "Testudine (Turtles)", "habitat": "Beaches, Ponds", "drops": "Shell", "behavior": "Idle, Slow Wander"},
	]
	
	for s in species:
		_add_entry(vbox, s.name, "Habitat: %s" % s.habitat,
			"Drops: %s\nBehavior: %s" % [s.drops, s.behavior])

func _build_biomes_tab() -> void:
	var vbox := _make_scroll_container("Biomes")
	
	var world := get_tree().get_first_node_in_group("world")
	if not world or not world.biome_generator:
		_add_hint(vbox, "Biome data not available yet. Explore the world to discover biomes!")
		return
	
	var biomes = BiomeLibrary.get_all_biomes()
	for biome in biomes:
		_add_entry(vbox, biome.display_name, "Terrain: %s" % biome.ground_tile_id,
			"Speed: %.1fx | Growth: %.1fx | Yield: %.1fx\nTraits: %s" % [
				biome.movement_speed_multiplier, biome.crop_growth_multiplier,
				biome.crop_yield_multiplier, ", ".join(biome.crop_trait_tags)])

func _build_buildings_tab() -> void:
	var vbox := _make_scroll_container("Buildings")
	
	var world := get_tree().get_first_node_in_group("world")
	if not world or not world.has_method("get_building_system"):
		_add_hint(vbox, "Building system not available yet. Place a building to unlock this guide!")
		return
	
	var building_types := BuildingSystem.BUILDING_DATA
	for type_key in building_types:
		var data: Dictionary = building_types[type_key]
		var ing_str := ""
		for item_id in data.ingredients:
			var item := DataManager.get_item(item_id)
			var item_name: String = item.display_name if item else item_id
			ing_str += "%s x%d " % [item_name, data.ingredients[item_id]]
		_add_entry(vbox, data.name, data.description, "Materials: %s" % ing_str)
