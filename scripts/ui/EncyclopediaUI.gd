extends CanvasLayer
class_name EncyclopediaUI

## Interactive encyclopedia / world guide. Auto-updates as player discovers
## new content. Opened via H key.

signal closed()

@onready var dim: ColorRect = $Dim if has_node("Dim") else null
@onready var panel: PanelContainer = $Panel if has_node("Panel") else null
@onready var tabs: TabContainer = $Panel/VBox/TabContainer if has_node("Panel/VBox/TabContainer") else null
@onready var title_label: Label = $Panel/VBox/TitleBar/TitleLabel if has_node("Panel/VBox/TitleBar/TitleLabel") else null

var is_open: bool = false

# Cache of all sections to avoid re-building unnecessarily
var _needs_refresh: bool = true

## Tabs locked behind library research. Synced with LibraryResearch on open.
var _locked_tabs: Array[String] = []

## Default locked tabs before any research is done.
const DEFAULT_LOCKED_TABS: Array[String] = ["animals", "biomes", "buildings"]

func _ready() -> void:
	if panel:
		panel.visible = false
	if dim:
		dim.visible = false
	
	# open_encyclopedia action is now defined in project.godot (bound to H key)
	
	# Auto-refresh when new content is discovered
	DataManager.crop_discovered.connect(_on_new_discovery)
	UpgradeManager.upgrade_purchased.connect(_on_upgrade_purchased)

func _on_upgrade_purchased(_upgrade: int, _new_level: int) -> void:
	_needs_refresh = true
	if is_open:
		refresh()

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
	AudioManager.play(AudioManager.Sound.MENU_OPEN)
	_sync_locked_tabs()
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

## Sync locked tab state with LibraryResearch. Falls back to defaults if
## the library system node isn't available yet.
func _sync_locked_tabs() -> void:
	# Creative mode fully unlocks all encyclopedia tabs.
	if GameManager and GameManager.is_creative():
		_locked_tabs = []
		return
	var lib := get_tree().get_first_node_in_group("library_system") as LibraryResearch
	if lib and lib.has_method("get_locked_tabs"):
		_locked_tabs = lib.get_locked_tabs()
	else:
		_locked_tabs = DEFAULT_LOCKED_TABS.duplicate()

## Called by LibraryResearch when the player pays gold to unlock a tab.
## Removes the tab from the locked set and refreshes so it becomes visible.
func unlock_tab(tab_name: String) -> void:
	_locked_tabs.erase(tab_name)
	_needs_refresh = true
	if is_open:
		refresh()

func _on_close_pressed() -> void:
	close()

func refresh() -> void:
	if not panel or not tabs:
		return
	
	_clear_tabs()
	_needs_refresh = false
	title_label.text = "Encyclopedia — World Guide"

func _clear_tabs() -> void:
	if not tabs:
		return
	for child in tabs.get_children():
		child.queue_free()
	_build_all_tabs()

func _build_all_tabs() -> void:
	_build_crops_tab()
	_build_crafting_tab()
	_build_alchemy_tab()
	_build_cooking_tab()
	_build_animals_tab()
	_build_pets_tab()
	_build_biomes_tab()
	_build_buildings_tab()
	_build_farming_tab()
	_build_town_tab()
	_build_bosses_tab()

## Show a placeholder tab with a lock icon and instructions for locked tabs.
func _build_locked_tab_placeholder(tab_title: String) -> void:
	var vbox := _make_scroll_container(tab_title)
	_add_hint(vbox, "🔒 This section is locked. Visit the Library in the Ruined Town and pay gold to unlock it.")
	_add_entry(vbox, tab_title, "Locked — Research Required",
		"This encyclopedia section can be unlocked by researching at the Library.\n"
		+ "Cost: $50 per section.\n"
		+ "Find the Library in the Ruined Town and speak with the scholar.",
		null, Color(0.5, 0.5, 0.5))

func _make_scroll_container(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	var vbox := VBoxContainer.new()
	vbox.name = title + "Content"
	vbox.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_FILL
	scroll.add_child(vbox)
	tabs.add_child(scroll)
	tabs.set_tab_title(tabs.get_tab_count() - 1, title)
	return vbox

# ── Color helpers ──

## Standard rarity color mapping.
const RARITY_COLORS: Dictionary = {
	"Common": Color(0.8, 0.8, 0.8),
	"Uncommon": Color(0.6, 0.9, 0.5),
	"Rare": Color(0.4, 0.6, 1.0),
	"Epic": Color(0.7, 0.4, 1.0),
	"Legendary": Color(1.0, 0.7, 0.2),
}

## Category accent colors for entry title backgrounds/accent.
func _category_color(category: String) -> Color:
	match category.to_lower():
		"crop", "seed": return Color(1.0, 0.7, 0.3)
		"food", "meal": return Color(0.9, 0.9, 0.4)
		"tool": return Color(0.6, 0.6, 1.0)
		"armor": return Color(0.7, 0.5, 0.9)
		"resource": return Color(0.6, 0.7, 0.9)
		"combat": return Color(1.0, 0.4, 0.4)
		"magic", "alchemy": return Color(0.7, 0.3, 0.9)
		"animal", "pet": return Color(0.6, 0.9, 0.7)
		"building": return Color(0.8, 0.65, 0.35)
		_: return Color(1.0, 0.85, 0.4)

## Wrap text in a color-tagged short label (returns a Label).
func _make_colored_label(text: String, color: Color, font_size: int = 10) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", font_size)
	return lbl

## Build a small colored badge label (like a pill/tag).
func _make_badge(text: String, bg_color: Color, text_color: Color = Color.WHITE, font_size: int = 9) -> PanelContainer:
	var badge := PanelContainer.new()
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_top", 1)
	margin.add_theme_constant_override("margin_bottom", 1)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", text_color)
	lbl.add_theme_font_size_override("font_size", font_size)
	margin.add_child(lbl)
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	badge.add_theme_stylebox_override("panel", style)
	badge.add_child(margin)
	return badge

# ── Add entry (horizontal card with optional icon) ──

## Creates a card-style entry in the encyclopedia. Optional icon appears on
## the left side (48×48). Title/subtitle/details fill the remaining space
## on the right, eliminating the previously empty right side.
func _add_entry(container: VBoxContainer, entry_name: String, subtitle: String, details: String, icon: Texture2D = null, accent_color: Color = Color(1.0, 0.85, 0.4)) -> void:
	var frame := PanelContainer.new()
	frame.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_FILL
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_FILL
	hbox.size_flags_vertical = Control.SIZE_FILL
	hbox.add_theme_constant_override("separation", 8)
	
	# ── Icon column (left) ──
	if icon != null:
		var icon_bg := PanelContainer.new()
		icon_bg.custom_minimum_size = Vector2(52, 52)
		icon_bg.size_flags_horizontal = 0
		icon_bg.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var icon_bg_style := StyleBoxFlat.new()
		icon_bg_style.bg_color = Color(0.15, 0.12, 0.06, 0.8)
		icon_bg_style.corner_radius_top_left = 6
		icon_bg_style.corner_radius_top_right = 6
		icon_bg_style.corner_radius_bottom_left = 6
		icon_bg_style.corner_radius_bottom_right = 6
		icon_bg_style.border_width_left = 1
		icon_bg_style.border_width_top = 1
		icon_bg_style.border_width_right = 1
		icon_bg_style.border_width_bottom = 1
		icon_bg_style.border_color = Color(0.5, 0.4, 0.15, 0.6)
		icon_bg.add_theme_stylebox_override("panel", icon_bg_style)
		
		var tex := TextureRect.new()
		tex.texture = icon
		tex.custom_minimum_size = Vector2(48, 48)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.size_flags_horizontal = 0
		tex.size_flags_vertical = 0
		icon_bg.add_child(tex)
		hbox.add_child(icon_bg)
	
	# ── Text column (right, fills remaining space) ──
	var text_column := VBoxContainer.new()
	text_column.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_FILL
	text_column.add_theme_constant_override("separation", 2)
	
	# Title row: title + optional badges
	var title_row := HBoxContainer.new()
	title_row.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_FILL
	
	var title_lbl := Label.new()
	title_lbl.text = entry_name
	title_lbl.add_theme_font_size_override("font_size", 13)
	title_lbl.add_theme_color_override("font_color", accent_color)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_FILL
	title_row.add_child(title_lbl)
	
	text_column.add_child(title_row)
	
	if subtitle != "":
		var sub_lbl := Label.new()
		sub_lbl.text = subtitle
		sub_lbl.add_theme_font_size_override("font_size", 11)
		sub_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		sub_lbl.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_FILL
		text_column.add_child(sub_lbl)
	
	if details != "":
		var det_lbl := Label.new()
		det_lbl.text = details
		det_lbl.add_theme_font_size_override("font_size", 10)
		det_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		det_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		det_lbl.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_FILL
		det_lbl.max_lines_visible = 6
		text_column.add_child(det_lbl)
	
	hbox.add_child(text_column)
	frame.add_child(hbox)
	container.add_child(frame)

func _add_hint(container: VBoxContainer, text: String, icon: Texture2D = null) -> void:
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_FILL
	hbox.add_theme_constant_override("separation", 6)
	if icon != null:
		var tex := TextureRect.new()
		tex.texture = icon
		tex.custom_minimum_size = Vector2(20, 20)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.size_flags_horizontal = 0
		hbox.add_child(tex)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 0.8))
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_FILL
	hbox.add_child(lbl)
	container.add_child(hbox)

## Returns a colored rarity label string with a color-tag bullet symbol.
func _rarity_label(rarity: String) -> String:
	match rarity.to_lower():
		"common": return "[Common]"
		"uncommon": return "[Uncommon]"
		"rare": return "[Rare]"
		"epic": return "[Epic]"
		"legendary": return "[Legendary]"
	return "[%s]" % rarity

# --- Section Builders ---

func _build_crops_tab() -> void:
	var vbox := _make_scroll_container("Crops")
	var discovered: Array[CropData] = DataManager.get_discovered_crops()
	
	_add_hint(vbox, "Crops are procedurally generated with unique names, colors, and traits! Plant seeds to discover new varieties.")
	
	if discovered.is_empty():
		_add_hint(vbox, "Harvest your first crop to unlock the crop guide.")
		return
	
	for crop in discovered:
		var item: ItemData = DataManager.get_item(crop.yield_item_id)
		var price := item.sell_price if item else 0
		var seed_item: ItemData = DataManager.get_item(crop.seed_item_id)
		var seed_name := seed_item.display_name if seed_item else crop.seed_item_id
		var crop_icon: Texture2D = item.icon if item else null
		var rarity_color: Color = RARITY_COLORS.get(crop.rarity, Color(0.8, 0.8, 0.8))
		var rarity_badge: String = _rarity_label(crop.rarity)
		_add_entry(vbox, "%s %s" % [rarity_badge, crop.display_name], "Seed: %s" % seed_name,
			"Growth: %d days | Yield: %d | Sell: $%d | Replant: %s" % [crop.days_to_grow, crop.yield_amount, price, "Yes" if crop.yield_item_id != "" else "No"],
			crop_icon, rarity_color)

func _build_crafting_tab() -> void:
	var vbox := _make_scroll_container("Crafting")
	
	var crafting_ui := get_tree().get_first_node_in_group("crafting_ui")
	if not crafting_ui or not crafting_ui.has_method("get_recipes"):
		_add_hint(vbox, "Press [C] to open the crafting menu. Craft tools, building materials, and more!")
		return
	
	var recipes = crafting_ui.get_recipes()
	if recipes.is_empty():
		_add_hint(vbox, "No recipes available yet. Collect materials to unlock crafting recipes.")
		return
	
	for recipe in recipes:
		var result_icon: Texture2D = _lookup_item_icon(recipe.result_item_id)
		_add_entry(vbox, recipe.recipe_name, "→ %s x%d" % [recipe.result_display_name, recipe.result_amount],
			"Ingredients: " + recipe.get_ingredient_summary(),
			result_icon, Color(0.7, 0.85, 1.0))

func _lookup_item_icon(item_id: String) -> Texture2D:
	if item_id.is_empty():
		return null
	var item: ItemData = DataManager.get_item(item_id)
	if item and item.icon:
		return item.icon
	return null

## Try to load an animal's frame_0 sprite from assets/generated/.
func _lookup_animal_sprite(animal_id: String) -> Texture2D:
	var path: String = "res://assets/generated/animal_%s_frame_0.png" % animal_id
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

func _build_alchemy_tab() -> void:
	var vbox := _make_scroll_container("Alchemy")
	_add_hint(vbox, "Brew potions at the crafting table! Switch to the ⚗ Alchemy tab. Ingredients include monster drops, ores, gems, and foraged goods.")
	
	# Potion reference data (used as fallback and for display)
	var potions := [
		["Health Tonic", "+30 HP", "3 berry + 2 mushroom + 1 stone", Color(0.4, 1.0, 0.4)],
		["Health Potion", "+60 HP", "5 berry + 3 mushroom + 2 coal", Color(0.3, 0.9, 0.3)],
		["Greater Health Potion", "+120 HP", "2 gold_nugget + 3 soulberry + 3 coal", Color(0.2, 0.8, 0.2)],
		["Speed Tonic", "+20% speed (5m)", "2 vine + 2 feather + 1 coal", Color(0.4, 0.8, 1.0)],
		["Swift Elixir", "+30% speed (10m)", "3 golden_wheat + 3 feather + 2 spore_sac", Color(0.3, 0.7, 1.0)],
		["Iron Skin Potion", "+25% defense (5m)", "3 iron_ore + 5 stone + 2 coal", Color(0.7, 0.7, 0.7)],
		["Stone Skin Elixir", "+40% defense (10m)", "2 obsidian_shard + 2 shadow_hide + 3 silver_ore", Color(0.5, 0.5, 0.6)],
		["Luck Draught", "+30% luck (5m)", "1 ancient_coin + 2 gold_nugget + 2 spore_sac", Color(1.0, 0.9, 0.3)],
		["Elixir of Vigor", "+50 HP +20% speed (5m)", "2 cinder_shard + 2 egg + 2 gold_nugget", Color(1.0, 0.6, 0.2)],
		["Mana Infusion", "+50 energy", "2 ectoplasm + 1 ghostly_essence + 2 frost_crystal", Color(0.6, 0.3, 1.0)],
	]
	
	var crafting_ui := get_tree().get_first_node_in_group("crafting_ui")
	if crafting_ui and crafting_ui.has_method("get_alchemy_recipes"):
		var alchemy_recipes = crafting_ui.get_alchemy_recipes()
		if not alchemy_recipes.is_empty():
			for recipe in alchemy_recipes:
				var icon: Texture2D = _lookup_item_icon(recipe.result_item_id)
				_add_entry(vbox, recipe.recipe_name, "→ %s x%d" % [recipe.result_display_name, recipe.result_amount],
					"Ingredients: " + recipe.get_ingredient_summary(),
					icon, Color(0.7, 0.3, 0.9))
			return
	
	for p in potions:
		var potion_color: Color = p[3] as Color
		# Try to find first ingredient icon for visual interest
		var first_ing: String = p[2].split(" ")[-1].strip_edges() if p[2] != "" else ""
		var icon: Texture2D = _lookup_item_icon(first_ing) if first_ing.length() > 0 else null
		_add_entry(vbox, p[0], p[1], "Ingredients: " + p[2], icon, potion_color)


func _build_cooking_tab() -> void:
	var vbox := _make_scroll_container("Cooking")
	_add_hint(vbox, "Cook meals at a Campfire or Kitchen! Combine ingredients to create buff-granting meals. Cooking recipes are discovered through experimentation.")
	
	var world := get_tree().get_first_node_in_group("world")
	if not world or not world.has_method("get_cooking_system"):
		_add_hint(vbox, "Build a campfire or kitchen to start cooking!")
		return
	
	var cs = world.get_cooking_system()
	if not cs:
		_add_hint(vbox, "Cooking system not available.")
		return
	
	var all_recipes: Array = cs.get_all_recipes()
	if all_recipes.is_empty():
		_add_hint(vbox, "No cooking recipes defined in the game data.")
		return
	
	var known: Array = cs.get_known_recipes()
	var known_set: Dictionary = {}
	for r in known:
		known_set[r] = true
	
	for recipe_id in all_recipes:
		var meal = cs.get_meal(recipe_id)
		if meal:
			var ing_str := ""
			for ing_id in meal.ingredients:
				if ing_id == "crop":
					ing_str += "Any crop x%d " % meal.ingredients[ing_id]
				else:
					ing_str += "%s x%d " % [ing_id, meal.ingredients[ing_id]]
			var discovered_label: String = "" if known_set.has(recipe_id) else " [Undiscovered]"
			var buff_str := "none" if meal.buff_type == "none" else "%s (%.1f hrs)" % [meal.buff_type, meal.buff_duration]
			# Get the first ingredient's icon for visual reference
			var first_ing_id: String = ""
			for ing_id in meal.ingredients:
				if ing_id != "crop":
					first_ing_id = ing_id
					break
			var meal_icon: Texture2D = _lookup_item_icon(first_ing_id) if not first_ing_id.is_empty() else null
			# Fallback: use the meal item's own icon
			if meal_icon == null:
				meal_icon = _lookup_item_icon(recipe_id)
			var buff_color: Color = Color(0.9, 0.7, 0.3) if meal.buff_type != "none" else Color(0.6, 0.6, 0.6)
			_add_entry(vbox, meal.display_name + discovered_label, meal.description,
				"Ingredients: %s\n[Buff: %s]" % [ing_str, buff_str],
				meal_icon, buff_color)

func _build_animals_tab() -> void:
	if "animals" in _locked_tabs:
		_build_locked_tab_placeholder("Animals")
		return
	var vbox := _make_scroll_container("Animals")
	
	# Animals are procedurally generated from the world seed with unique
	# species names and visual traits. The actual species roaming your
	# island are generated at world creation.
	_add_hint(vbox, "Animals have unique generated names (e.g. 'Frosthoof Bovine') and vary in color, pattern, and behavior. Each animal type has favorite foods for breeding. Animals can be petted daily for drops (fur, eggs, milk, wool, feathers, etc.). Killing animals yields meat and hide. Animals respawn over time if none are nearby.")
	
	# Fish added via the fishing system
	_add_entry(vbox, "🐟 Fishing", "Requires: Fishing Rod (crafted at workbench)",
		"Cast line by pressing [E] near water while holding the Fishing Rod. Wait for a bite, then press [E] again to reel it in!\nCommon: Raw Fish, Carp, Perch\nUncommon: Salmon, Trout\nRare: Tuna, Swordfish\nVery Rare: Golden Fish, Moonfish",
		null, Color(0.4, 0.7, 1.0))
	
	# Dynamically pull animal types from Animal.gd love foods / behavior
	var animal_types_list := [
		{"id": "chicken", "name": "Fowl (Chicken/Bird)", "food": "Berry, Mushroom, Nut", "interaction_drops": "Feather, Egg (daily)", "behavior": "Wander & Graze"},
		{"id": "cow", "name": "Bovine (Cow)", "food": "Berry, Flower, Mushroom", "interaction_drops": "Milk (daily), Leather (one-time)", "behavior": "Graze & Wander"},
		{"id": "rabbit", "name": "Burrower (Rabbit)", "food": "Berry, Mushroom", "interaction_drops": "None (shy)", "behavior": "Skittish"},
		{"id": "deer", "name": "Strider (Deer)", "food": "Berry, Flower, Mushroom", "interaction_drops": "Antlers (one-time)", "behavior": "Skittish & Wander"},
		{"id": "goat", "name": "Caprine (Goat)", "food": "Berry, Flower, Mushroom", "interaction_drops": "Milk (daily), Wool (every 2 days)", "behavior": "Wander & Graze"},
		{"id": "pig", "name": "Porcine (Pig)", "food": "Mushroom, Nut, Truffle", "interaction_drops": "Truffle (every 2 days)", "behavior": "Wander & Root"},
		{"id": "sheep", "name": "Ovine (Sheep)", "food": "Berry, Flower", "interaction_drops": "Wool (daily)", "behavior": "Graze & Idle"},
		{"id": "squirrel", "name": "Sciurid (Squirrel)", "food": "Nut, Berry", "interaction_drops": "Nut", "behavior": "Skittish"},
		{"id": "frog", "name": "Anuran (Frog)", "food": "Mushroom, Berry", "interaction_drops": "None (curious)", "behavior": "Idle & Leap"},
		{"id": "turtle", "name": "Testudine (Turtle)", "food": "Mushroom, Flower", "interaction_drops": "Shell (one-time)", "behavior": "Idle & Slow Wander"},
		# --- Expedition Island Types ---
		{"id": "snow_fox", "name": "Snow Fox (Snowland)", "food": "Berry, Ice Crystal", "interaction_drops": "Polar Bear Hide, Snow Flower (daily)", "behavior": "Curious & Fleet"},
		{"id": "polar_bear", "name": "Polar Bear (Snowland)", "food": "Fish, Berry", "interaction_drops": "Polar Bear Hide (one-time), Snow Flower (daily)", "behavior": "Solitary & Strong"},
		{"id": "snow_owl", "name": "Snow Owl (Snowland)", "food": "Berry, Mushroom", "interaction_drops": "Feather, Snow Flower (daily)", "behavior": "Nocturnal & Watchful"},
		{"id": "gummy_bear", "name": "Gummy Bear (Ice Cream Land)", "food": "Gumdrop, Sugar Crystal", "interaction_drops": "Gumdrop (daily)", "behavior": "Bouncy & Friendly"},
		{"id": "marshmallow_puff", "name": "Marshmallow Puff (Ice Cream Land)", "food": "Sugar Crystal, Chocolate Chunk", "interaction_drops": "Sugar Crystal (daily)", "behavior": "Floaty & Sweet"},
		{"id": "licorice_worm", "name": "Licorice Worm (Ice Cream Land)", "food": "Chocolate Chunk, Gumdrop", "interaction_drops": "Chocolate Chunk (daily)", "behavior": "Wiggly & Burrowing"},
		{"id": "gingerbread_man", "name": "Gingerbread Man (Ice Cream Land)", "food": "Sugar Crystal, Gumdrop", "interaction_drops": "Sugar Crystal (daily)", "behavior": "Sprightly & Sweet-toothed"},
		{"id": "sand_lizard", "name": "Sand Lizard (Desert)", "food": "Cactus Fruit, Mushroom", "interaction_drops": "Desert Scales (one-time)", "behavior": "Basking & Swift"},
		{"id": "desert_scorpion", "name": "Desert Scorpion (Desert)", "food": "Cactus Fruit, Berry", "interaction_drops": "Scorpion Stinger (one-time)", "behavior": "Skittish & Poisonous"},
		{"id": "meerkat", "name": "Meerkat (Desert)", "food": "Cactus Fruit, Nut", "interaction_drops": "Golden Scarab (daily)", "behavior": "Social & Alert"},
		{"id": "ember_crawler", "name": "Ember Crawler (Volcanic)", "food": "Ember Dust, Sulfur Crystal", "interaction_drops": "Ember Dust (daily), Magma Core (one-time)", "behavior": "Glowing & Slow"},
		{"id": "ash_moth", "name": "Ash Moth (Volcanic)", "food": "Sulfur Crystal, Ember Dust", "interaction_drops": "Sulfur Crystal (daily)", "behavior": "Fluttering & Heat-seeking"},
		{"id": "magma_slug", "name": "Magma Slug (Volcanic)", "food": "Ember Dust, Coal", "interaction_drops": "Magma Core (daily)", "behavior": "Slow & Molten"},
		{"id": "spirit_fox", "name": "Spirit Fox (Ethereal)", "food": "Moon Shard, Starlight Dust", "interaction_drops": "Starlight Dust (daily)", "behavior": "Ethereal & Glowing"},
		{"id": "glow_jelly", "name": "Glow Jelly (Ethereal)", "food": "Starlight Dust, Moon Shard", "interaction_drops": "Moon Shard (daily)", "behavior": "Floating & Luminous"},
		{"id": "lunar_moth", "name": "Lunar Moth (Ethereal)", "food": "Starlight Dust, Berry", "interaction_drops": "Starlight Dust (daily)", "behavior": "Night-dwelling & Graceful"},
	]
	
	for a in animal_types_list:
		var habitat := _get_animal_habitat(a.id)
		var animal_icon: Texture2D = _lookup_animal_sprite(a.id)
		# Fallback to a related item icon if no animal sprite exists
		if animal_icon == null:
			var fallback_ids: Dictionary = {
				"cow": "milk", "pig": "truffle", "sheep": "wool", "turtle": "shell"
			}
			animal_icon = _lookup_item_icon(fallback_ids.get(a.id, ""))
		_add_entry(vbox, a.name, "Habitat: %s" % habitat,
			"Interaction Drops: %s\nFavorite Foods: %s\nBehavior: %s" % [a.interaction_drops, a.food, a.behavior],
			animal_icon, Color(0.6, 0.9, 0.7))

## Returns a habitat string for a given animal type, based on world biome generation.
## Falls back to sensible defaults if world isn't available.
func _get_animal_habitat(animal_type: String) -> String:
	var world := get_tree().get_first_node_in_group("world")
	if not world:
		match animal_type:
			"chicken": return "Grasslands, Forests"
			"cow": return "Plains, Meadows"
			"rabbit": return "Forests, Meadows"
			"deer": return "Forests, Mountains"
			"goat": return "Mountains, Hills"
			"pig": return "Forests, Farms"
			"sheep": return "Meadows"
			"squirrel": return "Forests"
			"frog": return "Swamps, Ponds"
			"turtle": return "Beaches, Ponds"
		return "Various"
	
	# Query biome generator for which biomes this animal appears in
	if world.has_method("get_biome_generator"):
		var bg = world.get_biome_generator()
		if bg and bg.has_method("get_animal_habitat"):
			return bg.get_animal_habitat(animal_type)
	
	return "Various"

func _build_pets_tab() -> void:
	var vbox := _make_scroll_container("Pets")
	_add_hint(vbox, "Companion pets follow you and grant passive bonuses. You can only have one pet active at a time. Press [b]P[/b] to open the pet management panel.")
	
	var pets := PetManager.get_all_pet_data()
	if pets.is_empty():
		_add_hint(vbox, "No pet data available.")
		return
	
	for pid in pets:
		var pet: Dictionary = pets[pid]
		var bonus_string: String = _pet_bonus_desc(pet.get("bonus_type", ""), pet.get("bonus_val", 0.0))
		var owned_text: String = " [Owned]" if PetManager.has_pet(pid) else ""
		var pet_color: Color = Color(0.6, 0.9, 0.4) if PetManager.has_pet(pid) else Color(0.8, 0.8, 0.8)
		# Try to load a pet sprite
		var pet_icon: Texture2D = _lookup_animal_sprite(pid)
		_add_entry(vbox, pet.get("name", pid) + owned_text, bonus_string,
			pet.get("desc", ""), pet_icon, pet_color)

func _pet_bonus_desc(bonus_type: String, bonus_val: float) -> String:
	match bonus_type:
		"combat":
			return "+%.0f combat damage" % bonus_val
		"loot":
			return "+%.0f%% rare loot chance" % (bonus_val * 100.0)
		"gather":
			return "+%.0f%% gather yield" % (bonus_val * 100.0)
		"scout":
			return "Reveals the world map"
		"defense":
			return "+%.0f defense" % bonus_val
		"growth":
			return "+%.0f%% crop growth speed" % (bonus_val * 100.0)
		_:
			return bonus_type

func _build_biomes_tab() -> void:
	if "biomes" in _locked_tabs:
		_build_locked_tab_placeholder("Biomes")
		return
	var vbox := _make_scroll_container("Biomes")
	
	var world := get_tree().get_first_node_in_group("world")
	if not world or not world.biome_generator:
		_add_hint(vbox, "Explore the world to discover biomes! Each biome affects crop growth, movement speed, and resource availability.")
		return
	
	var biomes = BiomeLibrary.get_all_biomes()
	for biome in biomes:
		var traits_str: String = ", ".join(biome.crop_trait_tags) if biome.crop_trait_tags.size() > 0 else "None"
		# Try to find a tile texture for the biome ground
		var biome_icon: Texture2D = null
		var tile_path: String = "res://assets/sprites/" + biome.ground_tile_id + ".png"
		if ResourceLoader.exists(tile_path):
			biome_icon = load(tile_path) as Texture2D
		var biome_accents: Dictionary = {
			"grasslands": Color(0.4, 0.8, 0.3),
			"forest": Color(0.3, 0.6, 0.2),
			"desert": Color(0.9, 0.75, 0.4),
			"beach": Color(0.9, 0.85, 0.5),
			"water": Color(0.3, 0.5, 0.9),
			"mountains": Color(0.6, 0.6, 0.65),
			"swamp": Color(0.4, 0.5, 0.3),
			"tundra": Color(0.7, 0.75, 0.8),
			"volcanic": Color(0.6, 0.2, 0.1),
		}
		var b_color: Color = Color(0.6, 0.8, 0.5)
		for key in biome_accents:
			if biome.display_name.to_lower().contains(key):
				b_color = biome_accents[key]
				break
		_add_entry(vbox, biome.display_name, "Terrain: %s" % biome.ground_tile_id,
			"Movement: %.0f%% | Growth: %.0f%% | Yield: %.0f%%\nCrop Traits: %s | Unique Crop Chance: %.0f%%" % [
				biome.movement_speed_multiplier * 100.0, biome.crop_growth_multiplier * 100.0,
				biome.crop_yield_multiplier * 100.0, traits_str, biome.unique_crop_chance * 100.0],
			biome_icon, b_color)
	
	# --- Expedition Island Types ---
	_add_hint(vbox, "\n⛵ Expedition Islands (Captain Briggs):")
	var expedition_biomes := [
		{"name": "🏝️ Plain Island", "sub": "Grassy Meadow / Forest Grove / Flower Field",
			"resources": "Iron Ore, Stone, Clay",
			"animals": "Chicken, Rabbit, Deer, Goat, Squirrel, Frog",
			"desc": "The default island — familiar and fertile. Good for gathering basic resources."},
		{"name": "❄️ Snowland", "sub": "Snowy Forest / Frozen Lake / Glacial Peak",
			"resources": "Ice Crystal, Diamond, Coal",
			"animals": "Snow Fox, Polar Bear, Snow Owl",
			"desc": "A frigid expanse covered in snow. Harvest ice crystals and mine diamonds."},
		{"name": "🍦 Ice Cream Land", "sub": "Strawberry Swirl / Vanilla Frosting / Chocolate Sprinkles",
			"resources": "Sugar Crystal, Gumdrop, Chocolate Chunk",
			"animals": "Gummy Bear, Marshmallow Puff, Licorice Worm",
			"desc": "A sweet confectionary paradise! Everything is made of candy and ice cream."},
		{"name": "🏜️ Desert Island", "sub": "Sand Dunes / Rocky Badlands / Oasis Pool",
			"resources": "Gold, Silver, Cactus Fruit",
			"animals": "Sand Lizard, Desert Scorpion, Meerkat",
			"desc": "A scorching arid wasteland. Riches await beneath the sand."},
		{"name": "🌋 Volcanic Island", "sub": "Lava Fields / Ash Plains / Obsidian Cliffs",
			"resources": "Sulfur Crystal, Obsidian, Ruby, Ember Dust",
			"animals": "Ember Crawler, Ash Moth, Magma Slug",
			"desc": "A fiery land of molten rock. Danger and rare minerals go hand in hand."},
		{"name": "✨ Ethereal Island", "sub": "Crystal Grove / Starfall Meadow / Misty Fen",
			"resources": "Moon Shard, Starlight Dust, Gold",
			"animals": "Spirit Fox, Glow Jelly, Lunar Moth",
			"desc": "A mystical realm between worlds. Magical resources glow in the twilight."},
	]
	var expedition_colors := [
		Color(0.5, 0.85, 0.4),  # Plain - green
		Color(0.6, 0.8, 1.0),   # Snowland - ice blue
		Color(1.0, 0.7, 0.9),   # Ice Cream Land - pink
		Color(1.0, 0.8, 0.4),   # Desert - gold
		Color(1.0, 0.4, 0.3),   # Volcanic - red
		Color(0.7, 0.4, 1.0),   # Ethereal - purple
	]
	for idx in range(expedition_biomes.size()):
		var eb = expedition_biomes[idx]
		var ecolor: Color = expedition_colors[idx] if idx < expedition_colors.size() else Color(0.8, 0.8, 0.8)
		_add_entry(vbox, eb.name, "Sub-biomes: " + eb.sub,
			"Resources: %s\nAnimals: %s\n%s" % [eb.resources, eb.animals, eb.desc],
			null, ecolor)
	_add_hint(vbox, "Captain Briggs at the dock charges $100 for a random expedition. You never know which island you'll get!")

func _build_buildings_tab() -> void:
	if "buildings" in _locked_tabs:
		_build_locked_tab_placeholder("Buildings")
		return
	var vbox := _make_scroll_container("Buildings")
	
	var building_types := BuildingSystem.BUILDING_DATA
	if building_types.is_empty():
		_add_hint(vbox, "Building system not available yet.")
		return
	
	# Mapping of building display names to correct item IDs when the simple
	# name-to-kit-id conversion doesn't match the registered item.
	const BUILDING_ITEM_OVERRIDES: Dictionary = {
		"Town Hall": "wooden_planks",
		"Monument Statue": "decorative_statue_kit",
		"Fountain": "decorative_fountain_kit",
		"Bench": "decorative_bench_kit",
		"Lantern": "decorative_lantern_kit",
		"Sign": "decorative_sign_kit",
		"Fence": "fence_material",
		"Stone Fence": "stone_fence_material",
	}
	
	for type_key in building_types:
		var data: Dictionary = building_types[type_key]
		var ing_str := ""
		for item_id in data.ingredients:
			var item: ItemData = DataManager.get_item(item_id)
			var item_name: String = item.display_name if item else item_id
			ing_str += "%s x%d " % [item_name, data.ingredients[item_id]]
		var size_str := "%dx%d" % [data.get("width", 1), data.get("height", 1)]
		var has_interior := "Has interior" if data.get("has_interior", false) else "Exterior only"
		# Try override first, then fall back to name-based kit ID
		var bld_name: String = data.get("name", "")
		var bld_icon: Texture2D = null
		if BUILDING_ITEM_OVERRIDES.has(bld_name):
			bld_icon = _lookup_item_icon(BUILDING_ITEM_OVERRIDES[bld_name])
		else:
			var kit_name: String = bld_name.to_lower().replace(" ", "_") + "_kit"
			bld_icon = _lookup_item_icon(kit_name)
		_add_entry(vbox, data.name, data.description, "Size: %s | %s\nMaterials: %s" % [size_str, has_interior, ing_str],
			bld_icon, Color(0.8, 0.65, 0.35))

func _build_farming_tab() -> void:
	var vbox := _make_scroll_container("Farming")
	
	# ── Stats Journal section ──
	var stat_text := "Seeds Planted: %d\n" % GameManager.total_seeds_planted
	stat_text += "Crops Harvested: %d\n" % GameManager.total_crops_harvested
	stat_text += "Giant Crops: %d\n" % GameManager.total_giant_crops_harvested
	stat_text += "Mutations: %d\n" % GameManager.total_mutations_occurred
	stat_text += "Compost Produced: %d" % GameManager.total_compost_produced
	
	var tier_names := ["Normal", "Silver", "Gold", "Iridium"]
	var best_name: String = tier_names[clampi(GameManager.best_quality_tier, 0, tier_names.size() - 1)]
	stat_text += "\nBest Quality: %s" % best_name
	_add_entry(vbox, "Farming Stats Journal", "Lifetime farming records", stat_text,
		null, Color(0.4, 0.9, 0.4))
	_add_hint(vbox, "These stats track your entire farming journey across all seasons.")
	
	_add_hint(vbox, "Press [G] to open the Farming Overview panel. It shows all planted crops, their growth progress, water status, and alerts for disease/mutations.")
	_add_hint(vbox, "Till soil with the Hoe [1], water with the Watering Can [2], and plant seeds from your inventory.")
	
	var soil_icon: Texture2D = _lookup_item_icon("compost")
	var water_icon: Texture2D = _lookup_item_icon("milk")
	
	# Crop planting guide
	_add_entry(vbox, "Farming Basics", "",
		"Hoe [1]: Till soil by clicking on dirt/grass\n"
		+ "Watering Can [2]: Water tilled soil (crops need daily water!)\n"
		+ "Seeds: Hold in hotbar and click tilled soil to plant\n"
		+ "Harvest: Click mature crops with empty hand\n"
		+ "Press [G] anytime to check your farm status",
		soil_icon, Color(0.7, 0.6, 0.3))
	
	# Growth factors
	_add_entry(vbox, "Growth Factors", "",
		"Water: Crops grow only if watered daily (soil dries overnight)\n"
		+ "Compost: Speeds up growth (craft at workbench)\n"
		+ "Fertilizer: Boosts yield quality\n"
		+ "Soil Quality: Tilling and composting improves soil over time\n"
		+ "Season: 1.25x speed AND yield in-season; 0.75x out-of-season\n"
		+ "Crop Rotation: Different crop on same tile = +1 soil quality\n"
		+ "Sprinklers: Auto-water 3x3 area (craft with iron + stone)",
		water_icon, Color(0.4, 0.7, 1.0))
	
	# Buildings
	_add_entry(vbox, "Farming Buildings", "",
		"Scarecrow (Wood+Vine): -50% disease in 5x5 area\n"
		+ "Compost Bin (Wood+Planks): 40% compost from crop waste\n"
		+ "Greenhouse (Planks+Glass+Vine): Season override, halved disease",
		null, Color(0.6, 0.5, 0.3))
	
	# Mutations
	_add_entry(vbox, "Crop Mutations", "",
		"Crops can mutate into special variants while growing!\n"
		+ "Mutations are random; luck buffs increase the chance\n"
		+ "Mutated crops have unique names, colors, and traits\n"
		+ "Their seeds inherit the mutation for replanting",
		null, Color(0.9, 0.4, 0.9))
	
	# Fruit Trees
	_add_entry(vbox, "Fruit Trees", "",
		"Found in Forest biomes (15% of trees bear fruit)\n"
		+ "Interact with bare hands to harvest berries\n"
		+ "Fruit trees regrow their fruit after a few days\n"
		+ "Berries can be eaten raw or used in cooking",
		null, Color(0.9, 0.6, 0.2))
	
	# Cooking
	var crop_icon: Texture2D = _lookup_item_icon("minecraft_wheat")
	_add_entry(vbox, "Cooking with Farm Produce", "",
		"Cook meals at a Campfire [craft V] or Kitchen [build]\n"
		+ "Press [K] near a fire to open cooking menu\n"
		+ "Meals grant buffs: energy, health, speed, luck, growth\n"
		+ "Boss drops create super-powered meals:\n"
		+ "Warden's Brew - massive health | Stag's Elixir - super speed\n"
		+ "Wyrm's Nectar - great luck | Heart of Life - ultimate restore",
		crop_icon, Color(0.9, 0.7, 0.3))

# --- Town Tab ---
func _build_town_tab() -> void:
	var vbox := _make_scroll_container("Town")
	
	var town_icon: Texture2D = _lookup_item_icon("stone")
	_add_entry(vbox, "The Ruined Town", "A forgotten settlement on the west side of the island",
		"The town was destroyed long ago. Rubble and crumbling foundations are all that remain.\n"
		+ "Restore the town to unlock shops, NPCs, and services!\n"
		+ "Press [N] to open the Town Overview panel and track progress.",
		town_icon, Color(0.9, 0.7, 0.4))
	
	var ruins_icon: Texture2D = _lookup_item_icon("stone")
	_add_entry(vbox, "Ruins", "11 ruined structures to discover and restore",
		"Approach a ruin and press [E] to clear rubble\n"
		+ "Cleared ruins can be repaired with materials\n"
		+ "Press [R] near a cleared ruin to open the repair panel\n"
		+ "Each ruin needs specific materials (wood, stone, planks, gold)\n"
		+ "Once complete, the building is fully restored!",
		ruins_icon, Color(0.7, 0.5, 0.3))
	
	var buildings_icon: Texture2D = _lookup_item_icon("small_home_kit")
	_add_entry(vbox, "Restored Buildings", "Each restored building provides a unique service",
		"Cottage x2 — Houses for new residents\n"
		+ "Bakery — Timing mini-game to bake bread and pastries\n"
		+ "Restaurant — Sell crops for better prices, discover recipes\n"
		+ "Tavern — Resident gathering spot\n"
		+ "Blacksmith — Tool upgrades and metal working\n"
		+ "General Store — Shopping and trading hub\n"
		+ "Library — Pay gold to research crop mutations and lore\n"
		+ "Stable — Mount and animal transport\n"
		+ "Well — Restored watering source\n"
		+ "Gate — Town entrance",
		buildings_icon, Color(0.8, 0.65, 0.35))
	
	var residents_icon: Texture2D = _lookup_item_icon("feather")
	_add_entry(vbox, "Residents & Recruitment", "NPCs that live in your town",
		"Visitors arrive by ship each day at the docks\n"
		+ "When a building is restored, a vacancy opens\n"
		+ "If a visitor is still on the island at dusk, they may stay permanently\n"
		+ "Each resident runs the service for their building\n"
		+ "Residents have daily schedules (home, work, wander, sleep)\n"
		+ "Talk to residents to access their specialty services",
		residents_icon, Color(0.6, 0.85, 0.6))
	
	var rep_icon: Texture2D = _lookup_item_icon("gold_nugget")
	_add_entry(vbox, "Town Level & Reputation", "Your town grows as you restore buildings",
		"Town levels:\n"
		+ "Level 1 — Clearing: First building restored\n"
		+ "Level 2 — Settlement: 3+ buildings restored\n"
		+ "Level 3 — Village: 5+ buildings restored\n"
		+ "Level 4 — Town: 7+ buildings restored\n"
		+ "Level 5 — Thriving: All 9+ buildings restored\n\n"
		+ "Reputation: +50 per building restored. Build trust with the town!",
		rep_icon, Color(0.9, 0.8, 0.3))
	
	var bakery_icon: Texture2D = _lookup_item_icon("bread")
	_add_entry(vbox, "Bakery Mini-Game", "Bake goods for gold and buffs",
		"Talk to the baker in the restored Bakery to start a baking session.\n"
		+ "Press [Space] at the right moment to flip items\n"
		+ "Timing determines quality: Burnt, Normal, Silver, Gold, Iridium\n"
		+ "Higher quality = more gold and better buffs\n"
		+ "Iridium quality items provide powerful temporary buffs!",
		bakery_icon, Color(0.9, 0.7, 0.3))
	
	var restaurant_icon: Texture2D = _lookup_item_icon("berry")
	_add_entry(vbox, "Restaurant", "Sell crops at premium prices",
		"Talk to the chef in the restored Restaurant to sell surplus crops.\n"
		+ "Base prices are 15% higher than normal market rates\n"
		+ "Silver quality crops get an additional bonus\n"
		+ "Iridium quality crops sell for up to 75% more!\n"
		+ "Unlock special recipes by selling certain crop combinations\n"
		+ "Each day may feature a 'daily special' crop for extra bonuses",
		restaurant_icon, Color(0.8, 0.5, 0.3))
	
	var library_icon: Texture2D = _lookup_item_icon("ancient_coin")
	_add_entry(vbox, "Library Research", "Unlock secrets through research",
		"Talk to the scholar in the restored Library to research topics.\n"
		+ "Pay gold to unlock new encyclopedia entries\n"
		+ "Research grants permanent bonuses\n"
		+ "Unlock crop mutation knowledge\n"
		+ "Reveal hidden areas on the world map\n"
		+ "Research costs increase with every discovery",
		library_icon, Color(0.5, 0.5, 0.9))

# --- Bosses Tab ---

func _build_bosses_tab() -> void:
	var vbox := _make_scroll_container("Bosses")
	_add_hint(vbox, "Bosses are powerful spirits summoned by using special bait items from your hotbar. Each requires specific crops grown on your farm. Bosses must be defeated in order!")
	
	var warden_icon: Texture2D = _lookup_item_icon("wardens_core")
	_add_entry(vbox, "Root Warden", "Spirit Harvest I — First Boss",
		"Summon with: Soulberry Pie (craft from 3 soulberries)\n"
		+ "Drops: Warden's Core\n"
		+ "Used for: Warden's Brew recipe + Heart of Life Elixir",
		warden_icon, Color(0.4, 0.8, 0.3))
	
	var stag_icon: Texture2D = _lookup_item_icon("stags_essence")
	_add_entry(vbox, "Hollow Stag", "Spirit Harvest II — Second Boss",
		"Summon with: Golden Hay Bale (craft from 3 golden wheat)\n"
		+ "Drops: Stag's Essence\n"
		+ "Used for: Stag's Elixir recipe + Heart of Life Elixir",
		stag_icon, Color(0.6, 0.8, 1.0))
	
	var wyrm_icon: Texture2D = _lookup_item_icon("wyrms_petal")
	_add_entry(vbox, "Blooming Wyrm", "Spirit Harvest III — Third Boss",
		"Summon with: Nectar Brew (craft from 2 nectar blooms + 1 berry)\n"
		+ "Drops: Wyrm's Petal\n"
		+ "Used for: Wyrm's Nectar recipe + Heart of Life Elixir",
		wyrm_icon, Color(0.9, 0.4, 0.6))
	
	var soul_icon: Texture2D = _lookup_item_icon("soul_of_inconstance")
	_add_entry(vbox, "Inconstant Soul", "Spirit Harvest IV — Final Boss",
		"Summon with: Essence of Inconstance (craft from Warden's Core + Stag's Essence + Wyrm's Petal)\n"
		+ "Drops: Soul of Inconstance\n"
		+ "Defeating this boss completes the game!",
		soul_icon, Color(0.8, 0.3, 1.0))
