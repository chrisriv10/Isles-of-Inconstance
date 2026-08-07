extends Node

## Autoload singleton. Central registry for all static game data
## (items, crops, tile types). Other systems look up definitions here
## instead of holding their own copies, which keeps data consistent and
## makes it trivial to add new content later.

var items: Dictionary = {}       # id -> ItemData
var crops: Dictionary = {}       # id -> CropData
var tile_types: Dictionary = {}  # id -> TileTypeData

# The 3 crops generated for the current session, in slot order.
var procedural_crops: Array[CropData] = []

# Crop ids the player has actually grown & harvested at least once. Gates
# what shows up as purchasable in the Shop - see UpgradeManager's rare seed
# unlock tier and Shop.gd. Mutations only enter here once discovered, which
# is what makes finding one in the field feel worth chasing.
var discovered_crop_ids: Dictionary = {}

# Item IDs the player has ever obtained at least once. Drives the Collections
# UI — undiscovered items show as locked placeholders.
var discovered_item_ids: Dictionary = {}

signal crop_discovered(crop_id: String)
signal item_discovered(item_id: String)

func _ready() -> void:
	_register_default_tile_types()
	_register_default_items()
	# Procedural crops are generated when world seed is known (generate_world)
	# _register_default_crops() removed from here

# ---------------------------------------------------------------------------
# Registration
# ---------------------------------------------------------------------------

func register_item(item: ItemData) -> void:
	items[item.id] = item
	# Auto-assign a fallback icon if the item doesn't have one yet.
	# This ensures every item — even those created at runtime (mutations,
	# hybrids, etc.) — always has at least a colored-square icon.
	if item.icon == null:
		item.icon = make_item_icon(item.category, item.id, item.display_name)

func register_crop(crop: CropData) -> void:
	crops[crop.id] = crop

func register_tile_type(tile_type: TileTypeData) -> void:
	tile_types[tile_type.id] = tile_type

# ---------------------------------------------------------------------------
# Lookup
# ---------------------------------------------------------------------------

func get_item(id: String) -> ItemData:
	return items.get(id, null)

func get_crop(id: String) -> CropData:
	return crops.get(id, null)

func get_tile_type(id: String) -> TileTypeData:
	return tile_types.get(id, null)

## Resolve a friendly display name for any id (item or crop).
## Falls back to the item registry, then the crop registry, then a
## prettified version of the raw id (e.g. "violet_turnup" -> "Violet Turnup").
func get_display_name(id: String) -> String:
	if id == "":
		return ""
	var item: ItemData = items.get(id, null)
	if item and not item.display_name.is_empty():
		return item.display_name
	var crop: CropData = crops.get(id, null)
	if crop and not crop.display_name.is_empty():
		return crop.display_name
	return id.replace("_", " ").capitalize()

func get_all_tile_types() -> Array:
	return tile_types.values()

func get_procedural_crops() -> Array[CropData]:
	return procedural_crops

## Marks a crop as discovered (grown + harvested at least once). Returns
## true only the first time - useful for triggering a "New crop discovered!"
## style notification.
func mark_discovered(crop_id: String) -> bool:
	if crop_id == "" or discovered_crop_ids.has(crop_id):
		return false
	discovered_crop_ids[crop_id] = true
	crop_discovered.emit(crop_id)
	return true

func is_discovered(crop_id: String) -> bool:
	return discovered_crop_ids.has(crop_id)

func get_discovered_crops() -> Array[CropData]:
	var result: Array[CropData] = []
	for id in discovered_crop_ids.keys():
		var crop := get_crop(id)
		if crop:
			result.append(crop)
	return result

## Get all discovered crop IDs as array (for save/load)
func get_discovered_crop_ids() -> Array[String]:
	var result: Array[String] = []
	result.assign(discovered_crop_ids.keys())
	return result

# ---------------------------------------------------------------------------
# Item discovery (collections)
# ---------------------------------------------------------------------------

## Marks an item as discovered (obtained at least once). Returns true only
## the first time — useful for triggering a "New item discovered!"
## notification.
func mark_item_discovered(item_id: String) -> bool:
	if item_id == "" or discovered_item_ids.has(item_id):
		return false
	discovered_item_ids[item_id] = true
	item_discovered.emit(item_id)
	return true

func is_item_discovered(item_id: String) -> bool:
	return discovered_item_ids.has(item_id)

## Get all discovered item IDs as array (for save/load)
func get_discovered_item_ids() -> Array[String]:
	var result: Array[String] = []
	result.assign(discovered_item_ids.keys())
	return result

# ---------------------------------------------------------------------------
# Default placeholder content.
# Replace these with .tres resources loaded from disk as the project grows -
# this function is the only place that needs to change.
# ---------------------------------------------------------------------------

func _register_default_tile_types() -> void:
	var water := TileTypeData.new()
	water.id = "water"
	water.atlas_coords = Vector2i(3, 0)
	water.walkable = false
	water.tillable = false
	water.noise_min = -1.0
	water.noise_max = -0.6
	register_tile_type(water)

	var fertile_soil := TileTypeData.new()
	fertile_soil.id = "fertile_soil"
	fertile_soil.atlas_coords = Vector2i(9, 0)
	fertile_soil.walkable = true
	fertile_soil.tillable = true
	fertile_soil.noise_min = -0.6
	fertile_soil.noise_max = -0.4
	register_tile_type(fertile_soil)

	var dirt := TileTypeData.new()
	dirt.id = "dirt"
	dirt.atlas_coords = Vector2i(1, 0)
	dirt.walkable = true
	dirt.tillable = true
	dirt.noise_min = -0.4
	dirt.noise_max = -0.2
	register_tile_type(dirt)

	var grass := TileTypeData.new()
	grass.id = "grass"
	grass.atlas_coords = Vector2i(0, 0)
	grass.walkable = true
	grass.tillable = true
	grass.noise_min = -0.2
	grass.noise_max = 0.4
	register_tile_type(grass)

	var trees := TileTypeData.new()
	trees.id = "trees"
	trees.atlas_coords = Vector2i(7, 0)
	trees.walkable = false
	trees.tillable = false
	trees.noise_min = 0.4
	trees.noise_max = 0.8
	register_tile_type(trees)

	var rocks := TileTypeData.new()
	rocks.id = "rocks"
	rocks.atlas_coords = Vector2i(8, 0)
	rocks.walkable = false
	rocks.tillable = false
	rocks.noise_min = 0.8
	rocks.noise_max = 1.0
	register_tile_type(rocks)

	var tilled := TileTypeData.new()
	tilled.id = "tilled"
	tilled.atlas_coords = Vector2i(2, 0)
	tilled.walkable = true
	tilled.tillable = false
	# Tilled soil doesn't spawn naturally, so it has no noise range.
	register_tile_type(tilled)

	var watered_tilled := TileTypeData.new()
	watered_tilled.id = "watered_tilled"
	watered_tilled.atlas_coords = Vector2i(10, 0)
	watered_tilled.walkable = true
	watered_tilled.tillable = false
	register_tile_type(watered_tilled)

	var sand := TileTypeData.new()
	sand.id = "sand"
	sand.atlas_coords = Vector2i(11, 0)
	sand.walkable = true
	sand.tillable = false
	sand.noise_min = -0.65
	sand.noise_max = -0.55
	register_tile_type(sand)

	# Biome ground tiles — added to support biome-based terrain painting
	var forest_floor_tile := TileTypeData.new()
	forest_floor_tile.id = "forest_floor"
	forest_floor_tile.atlas_coords = Vector2i(0, 1)
	forest_floor_tile.walkable = true
	forest_floor_tile.tillable = true
	register_tile_type(forest_floor_tile)

	var bog_tile := TileTypeData.new()
	bog_tile.id = "bog"
	bog_tile.atlas_coords = Vector2i(1, 1)
	bog_tile.walkable = true
	bog_tile.tillable = false
	register_tile_type(bog_tile)

	var stone_tile := TileTypeData.new()
	stone_tile.id = "stone"
	stone_tile.atlas_coords = Vector2i(2, 1)
	stone_tile.walkable = true
	stone_tile.tillable = false
	register_tile_type(stone_tile)

	var cobblestone_tile := TileTypeData.new()
	cobblestone_tile.id = "cobblestone_path"
	cobblestone_tile.atlas_coords = Vector2i(0, 0)
	cobblestone_tile.source_id = 14
	cobblestone_tile.walkable = true
	cobblestone_tile.tillable = false
	register_tile_type(cobblestone_tile)

	var snow_tile := TileTypeData.new()
	snow_tile.id = "snow"
	snow_tile.atlas_coords = Vector2i(0, 0)
	snow_tile.source_id = 2
	snow_tile.walkable = true
	snow_tile.tillable = false
	register_tile_type(snow_tile)

	# Biome-specific ground tiles — each is a 16x16 quadrant from a 32x32 biome texture.
	# 4 quadrants per biome provide visual variety when placed randomly.
	var biome_quad_tiles := [
		{ "id": "cherry_grove_0", "coords": Vector2i(0, 0), "source": 1 },
		{ "id": "cherry_grove_1", "coords": Vector2i(1, 0), "source": 1 },
		{ "id": "cherry_grove_2", "coords": Vector2i(2, 0), "source": 1 },
		{ "id": "cherry_grove_3", "coords": Vector2i(3, 0), "source": 1 },
		{ "id": "savanna_0", "coords": Vector2i(4, 2) },
		{ "id": "savanna_1", "coords": Vector2i(5, 2) },
		{ "id": "savanna_2", "coords": Vector2i(6, 2) },
		{ "id": "savanna_3", "coords": Vector2i(7, 2) },
		{ "id": "pine_forest_0", "coords": Vector2i(8, 2) },
		{ "id": "pine_forest_1", "coords": Vector2i(9, 2) },
		{ "id": "pine_forest_2", "coords": Vector2i(10, 2) },
		{ "id": "pine_forest_3", "coords": Vector2i(11, 2) },
		{ "id": "autumn_forest_0", "coords": Vector2i(12, 2) },
		{ "id": "autumn_forest_1", "coords": Vector2i(13, 2) },
		{ "id": "autumn_forest_2", "coords": Vector2i(14, 2) },
		{ "id": "autumn_forest_3", "coords": Vector2i(15, 2) },
		{ "id": "flower_fields_0", "coords": Vector2i(16, 2) },
		{ "id": "flower_fields_1", "coords": Vector2i(17, 2) },
		{ "id": "flower_fields_2", "coords": Vector2i(18, 2) },
		{ "id": "flower_fields_3", "coords": Vector2i(19, 2) },
		{ "id": "jungle_0", "coords": Vector2i(20, 2) },
		{ "id": "jungle_1", "coords": Vector2i(0, 3) },
		{ "id": "jungle_2", "coords": Vector2i(1, 3) },
		{ "id": "jungle_3", "coords": Vector2i(2, 3) },
		{ "id": "wetlands_0", "coords": Vector2i(3, 3) },
		{ "id": "wetlands_1", "coords": Vector2i(4, 3) },
		{ "id": "wetlands_2", "coords": Vector2i(5, 3) },
		{ "id": "wetlands_3", "coords": Vector2i(6, 3) },
	]
	for t in biome_quad_tiles:
		var bt := TileTypeData.new()
		bt.id = t.id
		bt.atlas_coords = t.coords
		bt.source_id = t.get("source", 0)
		bt.walkable = true
		bt.tillable = true
		register_tile_type(bt)

	# ── Ice Cream Land tiles ──
	var ice_cream_tiles := [
		{ "id": "ice_cream_strawberry", "coords": Vector2i(0, 0), "source": 3 },
		{ "id": "ice_cream_vanilla", "coords": Vector2i(1, 0), "source": 3 },
		{ "id": "ice_cream_chocolate", "coords": Vector2i(2, 0), "source": 3 },
		{ "id": "ice_cream_swirl", "coords": Vector2i(3, 0), "source": 3 },
	]
	for t in ice_cream_tiles:
		var bt := TileTypeData.new()
		bt.id = t.id
		bt.atlas_coords = t.coords
		bt.source_id = t.get("source", 0)
		bt.walkable = true
		bt.tillable = false
		register_tile_type(bt)

	# ── Desert tiles ──
	var desert_tiles := [
		{ "id": "desert_sand", "coords": Vector2i(0, 0), "source": 4 },
		{ "id": "desert_rock", "coords": Vector2i(1, 0), "source": 4 },
		{ "id": "desert_tan", "coords": Vector2i(2, 0), "source": 4 },
		{ "id": "desert_gold", "coords": Vector2i(3, 0), "source": 4 },
	]
	for t in desert_tiles:
		var bt := TileTypeData.new()
		bt.id = t.id
		bt.atlas_coords = t.coords
		bt.source_id = t.get("source", 0)
		bt.walkable = true
		bt.tillable = false
		register_tile_type(bt)

	# ── Volcanic tiles ──
	# Order matches new atlas: ash(0), magma(1), obsidian(2), basalt(3)
	var volcanic_tiles := [
		{ "id": "volcanic_ash", "coords": Vector2i(0, 0), "source": 5 },
		{ "id": "volcanic_magma", "coords": Vector2i(1, 0), "source": 5 },
		{ "id": "volcanic_obsidian", "coords": Vector2i(2, 0), "source": 5 },
		{ "id": "volcanic_basalt", "coords": Vector2i(3, 0), "source": 5 },
	]
	for t in volcanic_tiles:
		var bt := TileTypeData.new()
		bt.id = t.id
		bt.atlas_coords = t.coords
		bt.source_id = t.get("source", 0)
		bt.walkable = true
		bt.tillable = false
		register_tile_type(bt)

	# ── Ethereal tiles ──
	var ethereal_tiles := [
		{ "id": "ethereal_purple", "coords": Vector2i(0, 0), "source": 6 },
		{ "id": "ethereal_blue", "coords": Vector2i(1, 0), "source": 6 },
		{ "id": "ethereal_cyan", "coords": Vector2i(2, 0), "source": 6 },
		{ "id": "ethereal_mist", "coords": Vector2i(3, 0), "source": 6 },
	]
	for t in ethereal_tiles:
		var bt := TileTypeData.new()
		bt.id = t.id
		bt.atlas_coords = t.coords
		bt.source_id = t.get("source", 0)
		bt.walkable = true
		bt.tillable = false
		register_tile_type(bt)

	# ── Snowland variant tiles ──
	var snowland_variants := [
		{ "id": "snow_ice", "coords": Vector2i(0, 0), "source": 7 },
		{ "id": "snow_white", "coords": Vector2i(1, 0), "source": 7 },
		{ "id": "snow_bright", "coords": Vector2i(2, 0), "source": 7 },
		{ "id": "snow_slush", "coords": Vector2i(3, 0), "source": 7 },
	]
	for t in snowland_variants:
		var bt := TileTypeData.new()
		bt.id = t.id
		bt.atlas_coords = t.coords
		bt.source_id = t.get("source", 0)
		bt.walkable = true
		bt.tillable = false
		register_tile_type(bt)

	# "Path" tile type — used for dock area / flattened walkable zones on the beach.
	# Uses the sand atlas coords so it renders like flattened sandy terrain.
	var path_tile := TileTypeData.new()
	path_tile.id = "path"
	path_tile.atlas_coords = Vector2i(11, 0)
	path_tile.walkable = true
	path_tile.tillable = false
	register_tile_type(path_tile)

	# Directional edge tiles. Placed around the coastline to show cliff
	# drop-offs between land and water. Each variant faces a different
	# direction, and the _add_beach_and_edge_tiles() method selects the
	# correct one based on which adjacent cells are water.
	var edge_data := [
		{ "id": "edge_n", "coords": Vector2i(13, 0) },
		{ "id": "edge_s", "coords": Vector2i(14, 0) },
		{ "id": "edge_w", "coords": Vector2i(15, 0) },
		{ "id": "edge_e", "coords": Vector2i(16, 0) },
		{ "id": "edge_nw", "coords": Vector2i(17, 0) },
		{ "id": "edge_ne", "coords": Vector2i(18, 0) },
		{ "id": "edge_sw", "coords": Vector2i(19, 0) },
		{ "id": "edge_se", "coords": Vector2i(20, 0) },
	]
	for e in edge_data:
		var edge_tile := TileTypeData.new()
		edge_tile.id = e.id
		edge_tile.atlas_coords = e.coords
		edge_tile.walkable = false
		edge_tile.tillable = false
		# Edge tiles are not placed naturally by noise; they're added in post-processing.
		register_tile_type(edge_tile)

func _register_default_items() -> void:
	var wood := ItemData.new()
	wood.id = "wood"
	wood.display_name = "Wood"
	wood.category = "resource"
	wood.stack_size = 99
	wood.sell_price = 3
	wood.buy_price = 0
	wood.description = "Sturdy timber from the island's trees. Useful for crafting."
	register_item(wood)

	var stone := ItemData.new()
	stone.id = "stone"
	stone.display_name = "Stone"
	stone.category = "resource"
	stone.stack_size = 99
	stone.sell_price = 2
	stone.buy_price = 0
	stone.description = "A chunk of rock, gathered from outcrops around the island. Sells for a little, useful in bulk."
	register_item(stone)

	# Crafting materials
	var tool_kit := ItemData.new()
	tool_kit.id = "tool_upgrade_kit"
	tool_kit.display_name = "Blacksmith Component Kit"
	tool_kit.category = "misc"
	tool_kit.stack_size = 10
	tool_kit.sell_price = 50
	tool_kit.description = "Upgrades your farming tools. Crafted from stone."
	register_item(tool_kit)

	var compost := ItemData.new()
	compost.id = "compost"
	compost.display_name = "Compost"
	compost.category = "misc"
	compost.stack_size = 20
	compost.sell_price = 10
	compost.description = "Nutrient-rich compost. Speeds crop growth when applied to tilled soil."
	register_item(compost)

	var wooden_planks := ItemData.new()
	wooden_planks.id = "wooden_planks"
	wooden_planks.display_name = "Wooden Planks"
	wooden_planks.category = "resource"
	wooden_planks.stack_size = 99
	wooden_planks.sell_price = 5
	wooden_planks.description = "Sturdy wooden planks, useful for building and crafting."
	register_item(wooden_planks)
	
	# New farming items
	var quality_compost := ItemData.new()
	quality_compost.id = "quality_compost"
	quality_compost.display_name = "Quality Compost"
	quality_compost.category = "misc"
	quality_compost.stack_size = 20
	quality_compost.sell_price = 25
	quality_compost.description = "Premium compost that greatly improves soil quality."
	register_item(quality_compost)
	
	var growth_booster := ItemData.new()
	growth_booster.id = "growth_booster"
	growth_booster.display_name = "Growth Booster"
	growth_booster.category = "misc"
	growth_booster.stack_size = 20
	growth_booster.sell_price = 35
	growth_booster.description = "A potent fertilizer that accelerates crop growth."
	register_item(growth_booster)
	
	var yield_enhancer := ItemData.new()
	yield_enhancer.id = "yield_enhancer"
	yield_enhancer.display_name = "Yield Enhancer"
	yield_enhancer.category = "misc"
	yield_enhancer.stack_size = 20
	yield_enhancer.sell_price = 40
	yield_enhancer.description = "Increases crop yield at harvest time."
	register_item(yield_enhancer)
	
	var rich_fertilizer := ItemData.new()
	rich_fertilizer.id = "rich_fertilizer"
	rich_fertilizer.display_name = "Rich Fertilizer"
	rich_fertilizer.category = "misc"
	rich_fertilizer.stack_size = 20
	rich_fertilizer.sell_price = 60
	rich_fertilizer.description = "A rich blend that boosts growth, yield, and soil quality."
	register_item(rich_fertilizer)
	
	var super_fertilizer := ItemData.new()
	super_fertilizer.id = "super_fertilizer"
	super_fertilizer.display_name = "Super Fertilizer"
	super_fertilizer.category = "misc"
	super_fertilizer.stack_size = 10
	super_fertilizer.sell_price = 120
	super_fertilizer.description = "The ultimate fertilizer - greatly boosts everything!"
	register_item(super_fertilizer)

	# Nature harvest items
	var berry_item := ItemData.new()
	berry_item.id = "berry"
	berry_item.display_name = "Berry"
	berry_item.category = "food"
	berry_item.stack_size = 99
	berry_item.sell_price = 4
	berry_item.buy_price = 0
	berry_item.description = "A handful of wild berries. Can be eaten or cooked."
	register_item(berry_item)

	var flower_item := ItemData.new()
	flower_item.id = "flower"
	flower_item.display_name = "Flower"
	flower_item.category = "resource"
	flower_item.stack_size = 99
	flower_item.sell_price = 6
	flower_item.buy_price = 0
	flower_item.description = "A freshly picked wildflower. Nice for decoration."
	register_item(flower_item)

	var mushroom_item := ItemData.new()
	mushroom_item.id = "mushroom"
	mushroom_item.display_name = "Mushroom"
	mushroom_item.category = "food"
	mushroom_item.stack_size = 99
	mushroom_item.sell_price = 5
	mushroom_item.buy_price = 0
	mushroom_item.description = "A wild mushroom. Edible and useful for cooking."
	register_item(mushroom_item)

	var ice_cream_cone_item := ItemData.new()
	ice_cream_cone_item.id = "ice_cream_cone"
	ice_cream_cone_item.display_name = "Ice Cream Cone"
	ice_cream_cone_item.category = "food"
	ice_cream_cone_item.stack_size = 99
	ice_cream_cone_item.sell_price = 8
	ice_cream_cone_item.buy_price = 0
	ice_cream_cone_item.description = "A delicious chocolate ice cream cone harvested from an ice cream tree. Melts fast — eat quick!"
	register_item(ice_cream_cone_item)

	# Metal crafting items
	var iron_ore_item := ItemData.new()
	iron_ore_item.id = "iron_ore"
	iron_ore_item.display_name = "Iron Ore"
	iron_ore_item.category = "resource"
	iron_ore_item.stack_size = 99
	iron_ore_item.sell_price = 5
	iron_ore_item.buy_price = 0
	iron_ore_item.description = "Raw iron ore. Smelt it into ingots for advanced crafting."
	register_item(iron_ore_item)

	var iron_ingot := ItemData.new()
	iron_ingot.id = "iron_ingot"
	iron_ingot.display_name = "Iron Ingot"
	iron_ingot.category = "resource"
	iron_ingot.stack_size = 99
	iron_ingot.sell_price = 8
	iron_ingot.buy_price = 0
	iron_ingot.description = "A smelted iron ingot. Used for advanced crafting."
	register_item(iron_ingot)

	# ── Mining ores (mine rooms) ──
	var copper_ore_item := ItemData.new()
	copper_ore_item.id = "copper_ore"
	copper_ore_item.display_name = "Copper Ore"
	copper_ore_item.category = "resource"
	copper_ore_item.stack_size = 99
	copper_ore_item.sell_price = 4
	copper_ore_item.buy_price = 0
	copper_ore_item.description = "Raw copper ore. Smelt it into ingots for crafting."
	register_item(copper_ore_item)

	var coal_item := ItemData.new()
	coal_item.id = "coal"
	coal_item.display_name = "Coal"
	coal_item.category = "resource"
	coal_item.stack_size = 99
	coal_item.sell_price = 3
	coal_item.buy_price = 0
	coal_item.description = "A chunk of coal. Used as fuel for smelting ores."
	register_item(coal_item)

	var gold_ore_item := ItemData.new()
	gold_ore_item.id = "gold_ore"
	gold_ore_item.display_name = "Gold Ore"
	gold_ore_item.category = "resource"
	gold_ore_item.stack_size = 99
	gold_ore_item.sell_price = 15
	gold_ore_item.buy_price = 0
	gold_ore_item.description = "Raw gold ore. Smelt into gleaming ingots."
	register_item(gold_ore_item)

	var diamond_ore_item := ItemData.new()
	diamond_ore_item.id = "diamond_ore"
	diamond_ore_item.display_name = "Diamond Ore"
	diamond_ore_item.category = "resource"
	diamond_ore_item.stack_size = 99
	diamond_ore_item.sell_price = 40
	diamond_ore_item.buy_price = 0
	diamond_ore_item.description = "Rough diamond ore. Cut and polish into sparkling gems."
	register_item(diamond_ore_item)

	var ruby_ore_item := ItemData.new()
	ruby_ore_item.id = "ruby_ore"
	ruby_ore_item.display_name = "Ruby Ore"
	ruby_ore_item.category = "resource"
	ruby_ore_item.stack_size = 99
	ruby_ore_item.sell_price = 35
	ruby_ore_item.buy_price = 0
	ruby_ore_item.description = "Raw ruby ore. Extract and cut into brilliant red gems."
	register_item(ruby_ore_item)

	var silver_ore_item := ItemData.new()
	silver_ore_item.id = "silver_ore"
	silver_ore_item.display_name = "Silver Ore"
	silver_ore_item.category = "resource"
	silver_ore_item.stack_size = 99
	silver_ore_item.sell_price = 20
	silver_ore_item.buy_price = 0
	silver_ore_item.description = "Raw silver ore. Smelt into gleaming ingots."
	register_item(silver_ore_item)

	var obsidian_ore_item := ItemData.new()
	obsidian_ore_item.id = "obsidian_ore"
	obsidian_ore_item.display_name = "Obsidian Ore"
	obsidian_ore_item.category = "resource"
	obsidian_ore_item.stack_size = 99
	obsidian_ore_item.sell_price = 30
	obsidian_ore_item.buy_price = 0
	obsidian_ore_item.description = "Volcanic obsidian shards. Extremely hard and dark."
	register_item(obsidian_ore_item)

	# ── Smelted ingots ──
	var copper_ingot_item := ItemData.new()
	copper_ingot_item.id = "copper_ingot"
	copper_ingot_item.display_name = "Copper Ingot"
	copper_ingot_item.category = "resource"
	copper_ingot_item.stack_size = 99
	copper_ingot_item.sell_price = 7
	copper_ingot_item.buy_price = 0
	copper_ingot_item.description = "A smelted copper ingot. Used for basic metal crafting."
	register_item(copper_ingot_item)

	var steel_ingot_item := ItemData.new()
	steel_ingot_item.id = "steel_ingot"
	steel_ingot_item.display_name = "Steel Ingot"
	steel_ingot_item.category = "resource"
	steel_ingot_item.stack_size = 99
	steel_ingot_item.sell_price = 15
	steel_ingot_item.buy_price = 0
	steel_ingot_item.description = "A strong steel ingot. Used for advanced tools and weapons."
	register_item(steel_ingot_item)

	var gold_ingot_item := ItemData.new()
	gold_ingot_item.id = "gold_ingot"
	gold_ingot_item.display_name = "Gold Ingot"
	gold_ingot_item.category = "resource"
	gold_ingot_item.stack_size = 99
	gold_ingot_item.sell_price = 30
	gold_ingot_item.buy_price = 0
	gold_ingot_item.description = "A gleaming gold ingot. Highly valuable for trading."
	register_item(gold_ingot_item)

	var silver_ingot_item := ItemData.new()
	silver_ingot_item.id = "silver_ingot"
	silver_ingot_item.display_name = "Silver Ingot"
	silver_ingot_item.category = "resource"
	silver_ingot_item.stack_size = 99
	silver_ingot_item.sell_price = 22
	silver_ingot_item.buy_price = 0
	silver_ingot_item.description = "A polished silver ingot. Used for elegant metalworking."
	register_item(silver_ingot_item)

	var mythril_ingot_item := ItemData.new()
	mythril_ingot_item.id = "mythril_ingot"
	mythril_ingot_item.display_name = "Mythril Ingot"
	mythril_ingot_item.category = "resource"
	mythril_ingot_item.stack_size = 99
	mythril_ingot_item.sell_price = 50
	mythril_ingot_item.buy_price = 0
	mythril_ingot_item.description = "A shimmering mythril ingot. Light as air, strong as steel."
	register_item(mythril_ingot_item)

	var diamond_gem_item := ItemData.new()
	diamond_gem_item.id = "diamond_gem"
	diamond_gem_item.display_name = "Diamond"
	diamond_gem_item.category = "resource"
	diamond_gem_item.stack_size = 99
	diamond_gem_item.sell_price = 60
	diamond_gem_item.buy_price = 0
	diamond_gem_item.description = "A cut and polished diamond. Hardest material known."
	register_item(diamond_gem_item)

	var ruby_gem_item := ItemData.new()
	ruby_gem_item.id = "ruby_gem"
	ruby_gem_item.display_name = "Ruby"
	ruby_gem_item.category = "resource"
	ruby_gem_item.stack_size = 99
	ruby_gem_item.sell_price = 50
	ruby_gem_item.buy_price = 0
	ruby_gem_item.description = "A brilliant cut ruby. Deep red and highly sought after."
	register_item(ruby_gem_item)

	var obsidian_shard_item := ItemData.new()
	obsidian_shard_item.id = "obsidian_shard"
	obsidian_shard_item.display_name = "Obsidian Shard"
	obsidian_shard_item.category = "resource"
	obsidian_shard_item.stack_size = 99
	obsidian_shard_item.sell_price = 40
	obsidian_shard_item.buy_price = 0
	obsidian_shard_item.description = "A sharp obsidian shard. Volcanic glass with a razor edge."
	register_item(obsidian_shard_item)

	# Misc crafting items (used by recipes / starter chest)
	var vine_item := ItemData.new()
	vine_item.id = "vine"
	vine_item.display_name = "Vine"
	vine_item.category = "resource"
	vine_item.stack_size = 99
	vine_item.sell_price = 2
	vine_item.buy_price = 0
	vine_item.description = "A sturdy vine. Useful for binding things together."
	register_item(vine_item)

	var gold_nugget_item := ItemData.new()
	gold_nugget_item.id = "gold_nugget"
	gold_nugget_item.display_name = "Gold Nugget"
	gold_nugget_item.category = "misc"
	gold_nugget_item.stack_size = 99
	gold_nugget_item.sell_price = 50
	gold_nugget_item.buy_price = 0
	gold_nugget_item.description = "A shiny gold nugget. Highly valuable!"
	register_item(gold_nugget_item)

	var torch_item := ItemData.new()
	torch_item.id = "torch"
	torch_item.display_name = "Torch"
	torch_item.category = "tool"
	torch_item.stack_size = 20
	torch_item.sell_price = 5
	torch_item.buy_price = 0
	torch_item.is_light_source = true
	torch_item.description = "A simple torch. Provides light in dark places."
	register_item(torch_item)

	# Enemy drop items
	var ectoplasm_item := ItemData.new()
	ectoplasm_item.id = "ectoplasm"
	ectoplasm_item.display_name = "Ectoplasm"
	ectoplasm_item.category = "misc"
	ectoplasm_item.stack_size = 99
	ectoplasm_item.sell_price = 15
	ectoplasm_item.buy_price = 0
	ectoplasm_item.description = "Ghostly residue from a slain spirit. Valuable to collectors."
	register_item(ectoplasm_item)

	var spore_sac_item := ItemData.new()
	spore_sac_item.id = "spore_sac"
	spore_sac_item.display_name = "Spore Sac"
	spore_sac_item.category = "misc"
	spore_sac_item.stack_size = 99
	spore_sac_item.sell_price = 10
	spore_sac_item.buy_price = 0
	spore_sac_item.description = "A pulsating sac from a sporeling. Useful for alchemy."
	register_item(spore_sac_item)

	var ghostly_essence_item := ItemData.new()
	ghostly_essence_item.id = "ghostly_essence"
	ghostly_essence_item.display_name = "Ghostly Essence"
	ghostly_essence_item.category = "misc"
	ghostly_essence_item.stack_size = 20
	ghostly_essence_item.sell_price = 40
	ghostly_essence_item.buy_price = 0
	ghostly_essence_item.description = "Rare essence from a powerful ghost. Can empower tools."
	register_item(ghostly_essence_item)

	var cinder_shard_item := ItemData.new()
	cinder_shard_item.id = "cinder_shard"
	cinder_shard_item.display_name = "Cinder Shard"
	cinder_shard_item.category = "misc"
	cinder_shard_item.stack_size = 99
	cinder_shard_item.sell_price = 12
	cinder_shard_item.buy_price = 0
	cinder_shard_item.description = "A warm shard from a cinder imp. Glows faintly."
	register_item(cinder_shard_item)

	var shadow_hide_item := ItemData.new()
	shadow_hide_item.id = "shadow_hide"
	shadow_hide_item.display_name = "Shadow Hide"
	shadow_hide_item.category = "misc"
	shadow_hide_item.stack_size = 99
	shadow_hide_item.sell_price = 18
	shadow_hide_item.buy_price = 0
	shadow_hide_item.description = "Supple dark leather from a shadow hound. Resists the night."
	register_item(shadow_hide_item)

	var frost_crystal_item := ItemData.new()
	frost_crystal_item.id = "frost_crystal"
	frost_crystal_item.display_name = "Frost Crystal"
	frost_crystal_item.category = "misc"
	frost_crystal_item.stack_size = 30
	frost_crystal_item.sell_price = 20
	frost_crystal_item.buy_price = 0
	frost_crystal_item.description = "A cold-burning crystal from a frost wisp. Chills the hand that holds it."
	register_item(frost_crystal_item)

	# Sprinkler items (3 tiers)
	var sprinkler_item := ItemData.new()
	sprinkler_item.id = "sprinkler"
	sprinkler_item.display_name = "Sprinkler"
	sprinkler_item.category = "misc"
	sprinkler_item.stack_size = 20
	sprinkler_item.sell_price = 25
	sprinkler_item.buy_price = 0
	sprinkler_item.description = "Automatically waters adjacent tilled tiles each morning. (3×3 area)"
	register_item(sprinkler_item)
	
	var quality_sprinkler_item := ItemData.new()
	quality_sprinkler_item.id = "quality_sprinkler"
	quality_sprinkler_item.display_name = "Quality Sprinkler"
	quality_sprinkler_item.category = "misc"
	quality_sprinkler_item.stack_size = 10
	quality_sprinkler_item.sell_price = 50
	quality_sprinkler_item.buy_price = 0
	quality_sprinkler_item.description = "Waters a 5×5 area around it each morning."
	register_item(quality_sprinkler_item)
	
	var iridium_sprinkler_item := ItemData.new()
	iridium_sprinkler_item.id = "iridium_sprinkler"
	iridium_sprinkler_item.display_name = "Iridium Sprinkler"
	iridium_sprinkler_item.category = "misc"
	iridium_sprinkler_item.stack_size = 5
	iridium_sprinkler_item.sell_price = 120
	iridium_sprinkler_item.buy_price = 0
	iridium_sprinkler_item.description = "Waters a 7×7 area and applies a mild fertilizer effect each morning."
	register_item(iridium_sprinkler_item)

	# Tool items (craftable, must be in inventory to equip)
	var axe_item := ItemData.new()
	axe_item.id = "axe_tool"
	axe_item.display_name = "Axe"
	axe_item.category = "tool"
	axe_item.stack_size = 1
	axe_item.sell_price = 10
	axe_item.buy_price = 0
	axe_item.description = "A sturdy axe for chopping trees."
	register_item(axe_item)

	# ── Tiered axes (faster chopping) ──
	var tier_axes := [
		{"id": "copper_axe", "name": "Copper Axe", "sell": 25, "desc": "A copper-reinforced axe. Chops slightly faster."},
		{"id": "iron_axe", "name": "Iron Axe", "sell": 45, "desc": "A sturdy iron axe. Chops faster and yields more wood."},
		{"id": "gold_axe", "name": "Gold Axe", "sell": 80, "desc": "A gleaming gold axe. Chops efficiently and yields extra wood."},
		{"id": "diamond_axe", "name": "Diamond Axe", "sell": 150, "desc": "A diamond-tipped axe. Extremely fast and yields more wood."},
		{"id": "mythril_axe", "name": "Mythril Axe", "sell": 250, "desc": "A legendary mythril axe. The ultimate woodcutting tool."},
		{"id": "magma_axe", "name": "Magma Axe", "sell": 250, "desc": "A fiery magma axe forged from volcano steel. Blazing fast!"},
	]
	for ta in tier_axes:
		var tier_item := ItemData.new()
		tier_item.id = ta.id
		tier_item.display_name = ta.name
		tier_item.category = "tool"
		tier_item.stack_size = 1
		tier_item.sell_price = ta.sell
		tier_item.buy_price = 0
		tier_item.description = ta.desc
		register_item(tier_item)

	var scythe_item := ItemData.new()
	scythe_item.id = "scythe_tool"
	scythe_item.display_name = "Scythe"
	scythe_item.category = "tool"
	scythe_item.stack_size = 1
	scythe_item.sell_price = 8
	scythe_item.buy_price = 0
	scythe_item.description = "A curved scythe for harvesting crops."
	register_item(scythe_item)

	var pickaxe_item := ItemData.new()
	pickaxe_item.id = "pickaxe_tool"
	pickaxe_item.display_name = "Pickaxe"
	pickaxe_item.category = "tool"
	pickaxe_item.stack_size = 1
	pickaxe_item.sell_price = 12
	pickaxe_item.buy_price = 0
	pickaxe_item.description = "A pickaxe for mining ore deposits."
	register_item(pickaxe_item)

	# ── Tiered pickaxes (improved mining) ──
	var tier_pickaxes := [
		{"id": "copper_pickaxe", "name": "Copper Pickaxe", "sell": 25, "desc": "A copper-reinforced pickaxe. Mines slightly faster."},
		{"id": "iron_pickaxe", "name": "Iron Pickaxe", "sell": 45, "desc": "A sturdy iron pickaxe. Mines faster and yields more ore."},
		{"id": "gold_pickaxe", "name": "Gold Pickaxe", "sell": 80, "desc": "A gleaming gold pickaxe. Mines efficiently and can extract rare gems."},
		{"id": "diamond_pickaxe", "name": "Diamond Pickaxe", "sell": 150, "desc": "A diamond-tipped pickaxe. Extremely fast and finds rare minerals."},
		{"id": "mythril_pickaxe", "name": "Mythril Pickaxe", "sell": 250, "desc": "A legendary mythril pickaxe. The ultimate mining tool."},
	]
	for tp in tier_pickaxes:
		var tier_item := ItemData.new()
		tier_item.id = tp.id
		tier_item.display_name = tp.name
		tier_item.category = "tool"
		tier_item.stack_size = 1
		tier_item.sell_price = tp.sell
		tier_item.buy_price = 0
		tier_item.description = tp.desc
		register_item(tier_item)

	var sword_item := ItemData.new()
	sword_item.id = "sword_tool"
	sword_item.display_name = "Sword"
	sword_item.category = "tool"
	sword_item.stack_size = 1
	sword_item.sell_price = 15
	sword_item.buy_price = 0
	sword_item.description = "A basic sword for defending yourself against enemies."
	register_item(sword_item)

	# ── Tiered swords (improved combat) ──
	var tier_swords := [
		{"id": "copper_sword", "name": "Copper Sword", "sell": 30, "desc": "A copper-reinforced sword. Slightly more powerful."},
		{"id": "iron_sword", "name": "Iron Sword", "sell": 55, "desc": "A sturdy iron sword. Deals solid damage."},
		{"id": "gold_sword", "name": "Gold Sword", "sell": 100, "desc": "A gleaming gold sword. Strikes with precision."},
		{"id": "diamond_sword", "name": "Diamond Sword", "sell": 180, "desc": "A diamond-edged sword. Razor sharp and deadly."},
		{"id": "mythril_sword", "name": "Mythril Sword", "sell": 300, "desc": "A legendary mythril sword. The ultimate blade."},
	]
	for ts in tier_swords:
		var tier_item := ItemData.new()
		tier_item.id = ts.id
		tier_item.display_name = ts.name
		tier_item.category = "tool"
		tier_item.stack_size = 1
		tier_item.sell_price = ts.sell
		tier_item.buy_price = 0
		tier_item.description = ts.desc
		register_item(tier_item)

	var lantern_item := ItemData.new()
	lantern_item.id = "lantern"
	lantern_item.display_name = "Lantern"
	lantern_item.category = "tool"
	lantern_item.stack_size = 1
	lantern_item.sell_price = 25
	lantern_item.buy_price = 0
	lantern_item.is_light_source = true
	lantern_item.description = "A warm lantern that repels ghosts. Hold it to light your way."
	register_item(lantern_item)

	var fishing_rod_item := ItemData.new()
	fishing_rod_item.id = "fishing_rod"
	fishing_rod_item.display_name = "Fishing Rod"
	fishing_rod_item.category = "tool"
	fishing_rod_item.stack_size = 1
	fishing_rod_item.sell_price = 15
	fishing_rod_item.buy_price = 0
	fishing_rod_item.description = "Used to fish in waters near the island coast. Press [E] near water to cast."
	register_item(fishing_rod_item)

	# ── Bow & Arrow (ranged combat) ──
	var bow_item := ItemData.new()
	bow_item.id = "bow"
	bow_item.display_name = "Bow"
	bow_item.category = "tool"
	bow_item.stack_size = 1
	bow_item.sell_price = 20
	bow_item.buy_price = 0
	bow_item.description = "A wooden hunting bow. Equip it, then left-click to fire an arrow at your target. Requires arrows as ammo."
	register_item(bow_item)

	var arrow_item := ItemData.new()
	arrow_item.id = "arrow"
	arrow_item.display_name = "Arrow"
	arrow_item.category = "resource"
	arrow_item.stack_size = 50
	arrow_item.sell_price = 2
	arrow_item.buy_price = 0
	arrow_item.description = "Fletched wooden arrows for the bow."
	register_item(arrow_item)

	# ── Pirate-themed items ──
	var cutlass_item := ItemData.new()
	cutlass_item.id = "cutlass"
	cutlass_item.display_name = "Cutlass"
	cutlass_item.category = "tool"
	cutlass_item.stack_size = 1
	cutlass_item.sell_price = 35
	cutlass_item.buy_price = 0
	cutlass_item.description = "A curved pirate saber. Quick and deadly."
	register_item(cutlass_item)

	var treasure_map_item := ItemData.new()
	treasure_map_item.id = "treasure_map"
	treasure_map_item.display_name = "Treasure Map"
	treasure_map_item.category = "misc"
	treasure_map_item.stack_size = 5
	treasure_map_item.sell_price = 60
	treasure_map_item.buy_price = 0
	treasure_map_item.description = "A faded map marked with an X. Perhaps it leads to buried riches..."
	register_item(treasure_map_item)

	var cannonball_item := ItemData.new()
	cannonball_item.id = "cannonball"
	cannonball_item.display_name = "Cannonball"
	cannonball_item.category = "resource"
	cannonball_item.stack_size = 30
	cannonball_item.sell_price = 8
	cannonball_item.buy_price = 0
	cannonball_item.description = "A heavy iron cannonball. Could be sold or smelted."
	register_item(cannonball_item)

	var ancient_coin_item := ItemData.new()
	ancient_coin_item.id = "ancient_coin"
	ancient_coin_item.display_name = "Ancient Coin"
	ancient_coin_item.category = "misc"
	ancient_coin_item.stack_size = 30
	ancient_coin_item.sell_price = 100
	ancient_coin_item.buy_price = 0
	ancient_coin_item.description = "A gold coin from a forgotten era. Extremely valuable!"
	register_item(ancient_coin_item)

	# ── Pet Egg items (buyable from shop, usable from inventory to unlock pets) ──
	_add_pet_egg("cat_egg", "Cat Egg", "A warm egg with a feline scent. Use it to unlock the Cat pet!")
	_add_pet_egg("dog_egg", "Dog Egg", "A sturdy egg that thumps like a heartbeat. Use to unlock the Dog pet!")
	_add_pet_egg("fox_egg", "Fox Egg", "A clever-looking egg with a reddish tint. Use to unlock the Fox pet!")
	_add_pet_egg("bird_egg", "Bird Egg", "A light blue egg that seems to chirp. Use to unlock the Bird pet!")
	_add_pet_egg("turtle_egg", "Turtle Egg", "A hard-shelled egg that feels ancient. Use to unlock the Turtle pet!")
	_add_pet_egg("rabbit_egg", "Rabbit Egg", "A springy egg that bounces when dropped. Use to unlock the Rabbit pet!")
	_add_pet_egg("ice_cream_sandwich_egg", "Ice Cream Sandwich Egg", "A chilly egg that smells like vanilla and chocolate. Use to unlock the Ice Cream Sandwich pet!")
	_add_pet_egg("gingerbread_man_egg", "Gingerbread Man Egg", "A warm egg decorated with icing snowflakes. Use to unlock the Gingerbread Man pet!")

	# ── Armor items ──
	var leather_helmet_item := ItemData.new()
	leather_helmet_item.id = "leather_helmet"
	leather_helmet_item.display_name = "Leather Helmet"
	leather_helmet_item.category = "armor"
	leather_helmet_item.stack_size = 1
	leather_helmet_item.sell_price = 8
	leather_helmet_item.buy_price = 0
	leather_helmet_item.description = "A tough leather cap. Provides basic head protection."
	register_item(leather_helmet_item)

	var leather_chestplate_item := ItemData.new()
	leather_chestplate_item.id = "leather_chestplate"
	leather_chestplate_item.display_name = "Leather Tunic"
	leather_chestplate_item.category = "armor"
	leather_chestplate_item.stack_size = 1
	leather_chestplate_item.sell_price = 12
	leather_chestplate_item.buy_price = 0
	leather_chestplate_item.description = "A sturdy leather tunic. Protects your torso."
	register_item(leather_chestplate_item)

	var leather_leggings_item := ItemData.new()
	leather_leggings_item.id = "leather_leggings"
	leather_leggings_item.display_name = "Leather Pants"
	leather_leggings_item.category = "armor"
	leather_leggings_item.stack_size = 1
	leather_leggings_item.sell_price = 10
	leather_leggings_item.buy_price = 0
	leather_leggings_item.description = "Sturdy leather pants. Offers basic leg protection."
	register_item(leather_leggings_item)

	var leather_boots_item := ItemData.new()
	leather_boots_item.id = "leather_boots"
	leather_boots_item.display_name = "Leather Boots"
	leather_boots_item.category = "armor"
	leather_boots_item.stack_size = 1
	leather_boots_item.sell_price = 8
	leather_boots_item.buy_price = 0
	leather_boots_item.description = "Tough leather boots. Keep your feet safe."
	register_item(leather_boots_item)

	var iron_helmet_item := ItemData.new()
	iron_helmet_item.id = "iron_helmet"
	iron_helmet_item.display_name = "Iron Helmet"
	iron_helmet_item.category = "armor"
	iron_helmet_item.stack_size = 1
	iron_helmet_item.sell_price = 20
	iron_helmet_item.buy_price = 0
	iron_helmet_item.description = "A forged iron helmet with a visor. Strong head protection."
	register_item(iron_helmet_item)

	var iron_chestplate_item := ItemData.new()
	iron_chestplate_item.id = "iron_chestplate"
	iron_chestplate_item.display_name = "Iron Chestplate"
	iron_chestplate_item.category = "armor"
	iron_chestplate_item.stack_size = 1
	iron_chestplate_item.sell_price = 30
	iron_chestplate_item.buy_price = 0
	iron_chestplate_item.description = "A heavy iron breastplate with shoulder guards. Excellent protection."
	register_item(iron_chestplate_item)

	var iron_leggings_item := ItemData.new()
	iron_leggings_item.id = "iron_leggings"
	iron_leggings_item.display_name = "Iron Leggings"
	iron_leggings_item.category = "armor"
	iron_leggings_item.stack_size = 1
	iron_leggings_item.sell_price = 25
	iron_leggings_item.buy_price = 0
	iron_leggings_item.description = "Iron leg guards. Protects your lower body."
	register_item(iron_leggings_item)

	var iron_boots_item := ItemData.new()
	iron_boots_item.id = "iron_boots"
	iron_boots_item.display_name = "Iron Boots"
	iron_boots_item.category = "armor"
	iron_boots_item.stack_size = 1
	iron_boots_item.sell_price = 20
	iron_boots_item.buy_price = 0
	iron_boots_item.description = "Sturdy iron boots. Protects your feet."
	register_item(iron_boots_item)

	# ── Copper armor ──
	var copper_helmet_item := ItemData.new()
	copper_helmet_item.id = "copper_helmet"
	copper_helmet_item.display_name = "Copper Helmet"
	copper_helmet_item.category = "armor"
	copper_helmet_item.stack_size = 1
	copper_helmet_item.sell_price = 15
	copper_helmet_item.buy_price = 0
	copper_helmet_item.description = "A basic copper helmet. Light but decent protection."
	register_item(copper_helmet_item)

	var copper_chestplate_item := ItemData.new()
	copper_chestplate_item.id = "copper_chestplate"
	copper_chestplate_item.display_name = "Copper Chestplate"
	copper_chestplate_item.category = "armor"
	copper_chestplate_item.stack_size = 1
	copper_chestplate_item.sell_price = 22
	copper_chestplate_item.buy_price = 0
	copper_chestplate_item.description = "A copper breastplate. Good basic torso protection."
	register_item(copper_chestplate_item)

	var copper_leggings_item := ItemData.new()
	copper_leggings_item.id = "copper_leggings"
	copper_leggings_item.display_name = "Copper Leggings"
	copper_leggings_item.category = "armor"
	copper_leggings_item.stack_size = 1
	copper_leggings_item.sell_price = 18
	copper_leggings_item.buy_price = 0
	copper_leggings_item.description = "Copper leg guards. Basic lower body protection."
	register_item(copper_leggings_item)

	var copper_boots_item := ItemData.new()
	copper_boots_item.id = "copper_boots"
	copper_boots_item.display_name = "Copper Boots"
	copper_boots_item.category = "armor"
	copper_boots_item.stack_size = 1
	copper_boots_item.sell_price = 14
	copper_boots_item.buy_price = 0
	copper_boots_item.description = "Copper boots. Light and easy to move in."
	register_item(copper_boots_item)

	# ── Silver armor ──
	var silver_helmet_item := ItemData.new()
	silver_helmet_item.id = "silver_helmet"
	silver_helmet_item.display_name = "Silver Helmet"
	silver_helmet_item.category = "armor"
	silver_helmet_item.stack_size = 1
	silver_helmet_item.sell_price = 25
	silver_helmet_item.buy_price = 0
	silver_helmet_item.description = "A polished silver helmet. Elegant and protective."
	register_item(silver_helmet_item)

	var silver_chestplate_item := ItemData.new()
	silver_chestplate_item.id = "silver_chestplate"
	silver_chestplate_item.display_name = "Silver Chestplate"
	silver_chestplate_item.category = "armor"
	silver_chestplate_item.stack_size = 1
	silver_chestplate_item.sell_price = 38
	silver_chestplate_item.buy_price = 0
	silver_chestplate_item.description = "A shining silver chestplate. Excellent craftsmanship."
	register_item(silver_chestplate_item)

	var silver_leggings_item := ItemData.new()
	silver_leggings_item.id = "silver_leggings"
	silver_leggings_item.display_name = "Silver Leggings"
	silver_leggings_item.category = "armor"
	silver_leggings_item.stack_size = 1
	silver_leggings_item.sell_price = 30
	silver_leggings_item.buy_price = 0
	silver_leggings_item.description = "Silver leg guards. Shiny and strong."
	register_item(silver_leggings_item)

	var silver_boots_item := ItemData.new()
	silver_boots_item.id = "silver_boots"
	silver_boots_item.display_name = "Silver Boots"
	silver_boots_item.category = "armor"
	silver_boots_item.stack_size = 1
	silver_boots_item.sell_price = 24
	silver_boots_item.buy_price = 0
	silver_boots_item.description = "Silver boots that gleam as you walk. Decent protection."
	register_item(silver_boots_item)

	# ── Gold armor ──
	var gold_helmet_item := ItemData.new()
	gold_helmet_item.id = "gold_helmet"
	gold_helmet_item.display_name = "Gold Helmet"
	gold_helmet_item.category = "armor"
	gold_helmet_item.stack_size = 1
	gold_helmet_item.sell_price = 40
	gold_helmet_item.buy_price = 0
	gold_helmet_item.description = "A gleaming gold helmet. Status and protection combined."
	register_item(gold_helmet_item)

	var gold_chestplate_item := ItemData.new()
	gold_chestplate_item.id = "gold_chestplate"
	gold_chestplate_item.display_name = "Gold Chestplate"
	gold_chestplate_item.category = "armor"
	gold_chestplate_item.stack_size = 1
	gold_chestplate_item.sell_price = 60
	gold_chestplate_item.buy_price = 0
	gold_chestplate_item.description = "A brilliant gold chestplate. Shines with wealth and power."
	register_item(gold_chestplate_item)

	var gold_leggings_item := ItemData.new()
	gold_leggings_item.id = "gold_leggings"
	gold_leggings_item.display_name = "Gold Leggings"
	gold_leggings_item.category = "armor"
	gold_leggings_item.stack_size = 1
	gold_leggings_item.sell_price = 50
	gold_leggings_item.buy_price = 0
	gold_leggings_item.description = "Gold-plated leg guards. Heavy but impressive."
	register_item(gold_leggings_item)

	var gold_boots_item := ItemData.new()
	gold_boots_item.id = "gold_boots"
	gold_boots_item.display_name = "Gold Boots"
	gold_boots_item.category = "armor"
	gold_boots_item.stack_size = 1
	gold_boots_item.sell_price = 38
	gold_boots_item.buy_price = 0
	gold_boots_item.description = "Gold-trimmed boots. Walk like royalty."
	register_item(gold_boots_item)

	# ── Steel armor ──
	var steel_helmet_item := ItemData.new()
	steel_helmet_item.id = "steel_helmet"
	steel_helmet_item.display_name = "Steel Helmet"
	steel_helmet_item.category = "armor"
	steel_helmet_item.stack_size = 1
	steel_helmet_item.sell_price = 35
	steel_helmet_item.buy_price = 0
	steel_helmet_item.description = "A durable steel helmet. Superior head protection."
	register_item(steel_helmet_item)

	var steel_chestplate_item := ItemData.new()
	steel_chestplate_item.id = "steel_chestplate"
	steel_chestplate_item.display_name = "Steel Chestplate"
	steel_chestplate_item.category = "armor"
	steel_chestplate_item.stack_size = 1
	steel_chestplate_item.sell_price = 50
	steel_chestplate_item.buy_price = 0
	steel_chestplate_item.description = "A strong steel breastplate. Excellent torso protection."
	register_item(steel_chestplate_item)

	var steel_leggings_item := ItemData.new()
	steel_leggings_item.id = "steel_leggings"
	steel_leggings_item.display_name = "Steel Leggings"
	steel_leggings_item.category = "armor"
	steel_leggings_item.stack_size = 1
	steel_leggings_item.sell_price = 40
	steel_leggings_item.buy_price = 0
	steel_leggings_item.description = "Steel leg guards. Superior lower body protection."
	register_item(steel_leggings_item)

	var steel_boots_item := ItemData.new()
	steel_boots_item.id = "steel_boots"
	steel_boots_item.display_name = "Steel Boots"
	steel_boots_item.category = "armor"
	steel_boots_item.stack_size = 1
	steel_boots_item.sell_price = 35
	steel_boots_item.buy_price = 0
	steel_boots_item.description = "Reinforced steel boots. Sturdy foot protection."
	register_item(steel_boots_item)

	# ── Mythril armor ──
	var mythril_helmet_item := ItemData.new()
	mythril_helmet_item.id = "mythril_helmet"
	mythril_helmet_item.display_name = "Mythril Helmet"
	mythril_helmet_item.category = "armor"
	mythril_helmet_item.stack_size = 1
	mythril_helmet_item.sell_price = 60
	mythril_helmet_item.buy_price = 0
	mythril_helmet_item.description = "A shimmering mythril helmet. Light yet incredibly strong."
	register_item(mythril_helmet_item)

	var mythril_chestplate_item := ItemData.new()
	mythril_chestplate_item.id = "mythril_chestplate"
	mythril_chestplate_item.display_name = "Mythril Chestplate"
	mythril_chestplate_item.category = "armor"
	mythril_chestplate_item.stack_size = 1
	mythril_chestplate_item.sell_price = 85
	mythril_chestplate_item.buy_price = 0
	mythril_chestplate_item.description = "A mythril breastplate that gleams with magical light."
	register_item(mythril_chestplate_item)

	var mythril_leggings_item := ItemData.new()
	mythril_leggings_item.id = "mythril_leggings"
	mythril_leggings_item.display_name = "Mythril Leggings"
	mythril_leggings_item.category = "armor"
	mythril_leggings_item.stack_size = 1
	mythril_leggings_item.sell_price = 70
	mythril_leggings_item.buy_price = 0
	mythril_leggings_item.description = "Mythril leg guards that move like silk."
	register_item(mythril_leggings_item)

	var mythril_boots_item := ItemData.new()
	mythril_boots_item.id = "mythril_boots"
	mythril_boots_item.display_name = "Mythril Boots"
	mythril_boots_item.category = "armor"
	mythril_boots_item.stack_size = 1
	mythril_boots_item.sell_price = 55
	mythril_boots_item.buy_price = 0
	mythril_boots_item.description = "Lightweight mythril boots. Incredible mobility."
	register_item(mythril_boots_item)

	# ── Diamond armor ──
	var diamond_helmet_item := ItemData.new()
	diamond_helmet_item.id = "diamond_helmet"
	diamond_helmet_item.display_name = "Diamond Helmet"
	diamond_helmet_item.category = "armor"
	diamond_helmet_item.stack_size = 1
	diamond_helmet_item.sell_price = 80
	diamond_helmet_item.buy_price = 0
	diamond_helmet_item.description = "A diamond-encrusted helmet. Supremely tough."
	register_item(diamond_helmet_item)

	var diamond_chestplate_item := ItemData.new()
	diamond_chestplate_item.id = "diamond_chestplate"
	diamond_chestplate_item.display_name = "Diamond Chestplate"
	diamond_chestplate_item.category = "armor"
	diamond_chestplate_item.stack_size = 1
	diamond_chestplate_item.sell_price = 120
	diamond_chestplate_item.buy_price = 0
	diamond_chestplate_item.description = "A brilliant diamond chestplate. The hardest armor known."
	register_item(diamond_chestplate_item)

	var diamond_leggings_item := ItemData.new()
	diamond_leggings_item.id = "diamond_leggings"
	diamond_leggings_item.display_name = "Diamond Leggings"
	diamond_leggings_item.category = "armor"
	diamond_leggings_item.stack_size = 1
	diamond_leggings_item.sell_price = 95
	diamond_leggings_item.buy_price = 0
	diamond_leggings_item.description = "Diamond-studded leg guards. Unmatched protection."
	register_item(diamond_leggings_item)

	var diamond_boots_item := ItemData.new()
	diamond_boots_item.id = "diamond_boots"
	diamond_boots_item.display_name = "Diamond Boots"
	diamond_boots_item.category = "armor"
	diamond_boots_item.stack_size = 1
	diamond_boots_item.sell_price = 75
	diamond_boots_item.buy_price = 0
	diamond_boots_item.description = "Diamond-capped boots. Nearly indestructible."
	register_item(diamond_boots_item)

	# ── Ruby armor ──
	var ruby_helmet_item := ItemData.new()
	ruby_helmet_item.id = "ruby_helmet"
	ruby_helmet_item.display_name = "Ruby Helmet"
	ruby_helmet_item.category = "armor"
	ruby_helmet_item.stack_size = 1
	ruby_helmet_item.sell_price = 70
	ruby_helmet_item.buy_price = 0
	ruby_helmet_item.description = "A ruby-studded helmet. Radiates protective energy."
	register_item(ruby_helmet_item)

	var ruby_chestplate_item := ItemData.new()
	ruby_chestplate_item.id = "ruby_chestplate"
	ruby_chestplate_item.display_name = "Ruby Chestplate"
	ruby_chestplate_item.category = "armor"
	ruby_chestplate_item.stack_size = 1
	ruby_chestplate_item.sell_price = 100
	ruby_chestplate_item.buy_price = 0
	ruby_chestplate_item.description = "A fiery ruby chestplate. Channels crimson power."
	register_item(ruby_chestplate_item)

	var ruby_leggings_item := ItemData.new()
	ruby_leggings_item.id = "ruby_leggings"
	ruby_leggings_item.display_name = "Ruby Leggings"
	ruby_leggings_item.category = "armor"
	ruby_leggings_item.stack_size = 1
	ruby_leggings_item.sell_price = 85
	ruby_leggings_item.buy_price = 0
	ruby_leggings_item.description = "Ruby-adorned leg guards. Elegant and strong."
	register_item(ruby_leggings_item)

	var ruby_boots_item := ItemData.new()
	ruby_boots_item.id = "ruby_boots"
	ruby_boots_item.display_name = "Ruby Boots"
	ruby_boots_item.category = "armor"
	ruby_boots_item.stack_size = 1
	ruby_boots_item.sell_price = 65
	ruby_boots_item.buy_price = 0
	ruby_boots_item.description = "Ruby-infused boots. Step with confidence."
	register_item(ruby_boots_item)

	# ── Obsidian armor ──
	var obsidian_helmet_item := ItemData.new()
	obsidian_helmet_item.id = "obsidian_helmet"
	obsidian_helmet_item.display_name = "Obsidian Helmet"
	obsidian_helmet_item.category = "armor"
	obsidian_helmet_item.stack_size = 1
	obsidian_helmet_item.sell_price = 55
	obsidian_helmet_item.buy_price = 0
	obsidian_helmet_item.description = "An obsidian helmet. Dark and menacing."
	register_item(obsidian_helmet_item)

	var obsidian_chestplate_item := ItemData.new()
	obsidian_chestplate_item.id = "obsidian_chestplate"
	obsidian_chestplate_item.display_name = "Obsidian Chestplate"
	obsidian_chestplate_item.category = "armor"
	obsidian_chestplate_item.stack_size = 1
	obsidian_chestplate_item.sell_price = 75
	obsidian_chestplate_item.buy_price = 0
	obsidian_chestplate_item.description = "A heavy obsidian chestplate. Volcanic strength protects you."
	register_item(obsidian_chestplate_item)

	var obsidian_leggings_item := ItemData.new()
	obsidian_leggings_item.id = "obsidian_leggings"
	obsidian_leggings_item.display_name = "Obsidian Leggings"
	obsidian_leggings_item.category = "armor"
	obsidian_leggings_item.stack_size = 1
	obsidian_leggings_item.sell_price = 60
	obsidian_leggings_item.buy_price = 0
	obsidian_leggings_item.description = "Obsidian-infused leg guards. Dark and sturdy."
	register_item(obsidian_leggings_item)

	var obsidian_boots_item := ItemData.new()
	obsidian_boots_item.id = "obsidian_boots"
	obsidian_boots_item.display_name = "Obsidian Boots"
	obsidian_boots_item.category = "armor"
	obsidian_boots_item.stack_size = 1
	obsidian_boots_item.sell_price = 50
	obsidian_boots_item.buy_price = 0
	obsidian_boots_item.description = "Obsidian-hardened boots. Grounded and solid."
	register_item(obsidian_boots_item)

	# ── Gingerbread armor ──
	var gingerbread_helmet_item := ItemData.new()
	gingerbread_helmet_item.id = "gingerbread_helmet"
	gingerbread_helmet_item.display_name = "Gingerbread Helmet"
	gingerbread_helmet_item.category = "armor"
	gingerbread_helmet_item.stack_size = 1
	gingerbread_helmet_item.sell_price = 25
	gingerbread_helmet_item.buy_price = 0
	gingerbread_helmet_item.description = "A crunchy gingerbread helmet with a green gumdrop on top. Wearing the full set makes you invincible — but you can't deal damage either!"
	register_item(gingerbread_helmet_item)

	var gingerbread_chestplate_item := ItemData.new()
	gingerbread_chestplate_item.id = "gingerbread_chestplate"
	gingerbread_chestplate_item.display_name = "Gingerbread Chestplate"
	gingerbread_chestplate_item.category = "armor"
	gingerbread_chestplate_item.stack_size = 1
	gingerbread_chestplate_item.sell_price = 40
	gingerbread_chestplate_item.buy_price = 0
	gingerbread_chestplate_item.description = "A crispy gingerbread chestplate with white icing zigzag and gumdrop buttons. Wearing the full set makes you invincible — but you can't deal damage either!"
	register_item(gingerbread_chestplate_item)

	var gingerbread_leggings_item := ItemData.new()
	gingerbread_leggings_item.id = "gingerbread_leggings"
	gingerbread_leggings_item.display_name = "Gingerbread Leggings"
	gingerbread_leggings_item.category = "armor"
	gingerbread_leggings_item.stack_size = 1
	gingerbread_leggings_item.sell_price = 30
	gingerbread_leggings_item.buy_price = 0
	gingerbread_leggings_item.description = "Gingerbread leg guards with white icing trim. Wearing the full set makes you invincible — but you can't deal damage either!"
	register_item(gingerbread_leggings_item)

	var gingerbread_boots_item := ItemData.new()
	gingerbread_boots_item.id = "gingerbread_boots"
	gingerbread_boots_item.display_name = "Gingerbread Boots"
	gingerbread_boots_item.category = "armor"
	gingerbread_boots_item.stack_size = 1
	gingerbread_boots_item.sell_price = 20
	gingerbread_boots_item.buy_price = 0
	gingerbread_boots_item.description = "Crunchy gingerbread boots with icing trim. Wearing the full set makes you invincible — but you can't deal damage either!"
	register_item(gingerbread_boots_item)

	# Building material items
	var fence_item := ItemData.new()
	fence_item.id = "fence_material"
	fence_item.display_name = "Fence Material"
	fence_item.category = "resource"
	fence_item.stack_size = 99
	fence_item.sell_price = 2
	fence_item.buy_price = 0
	fence_item.description = "Wooden fence sections ready for assembly."
	register_item(fence_item)

	var stone_fence_item := ItemData.new()
	stone_fence_item.id = "stone_fence_material"
	stone_fence_item.display_name = "Stone Fence Material"
	stone_fence_item.category = "resource"
	stone_fence_item.stack_size = 99
	stone_fence_item.sell_price = 3
	stone_fence_item.buy_price = 0
	stone_fence_item.description = "Sturdy stone fence blocks."
	register_item(stone_fence_item)

	var campfire_kit_item := ItemData.new()
	campfire_kit_item.id = "campfire_kit"
	campfire_kit_item.display_name = "Campfire Kit"
	campfire_kit_item.category = "misc"
	campfire_kit_item.stack_size = 10
	campfire_kit_item.sell_price = 15
	campfire_kit_item.buy_price = 0
	campfire_kit_item.description = "A portable campfire kit for cooking outdoors."
	register_item(campfire_kit_item)

	# --- Additional building kits ---
	# Each kit is consumed on placement and grants one building of that type.
	var building_kits := [
		{"id": "small_home_kit", "name": "Small Home Kit", "cat": "misc", "stack": 5, "sell": 50, "buy": 0, "desc": "Materials for a cozy small home."},
		{"id": "medium_home_kit", "name": "Medium Home Kit", "cat": "misc", "stack": 5, "sell": 100, "buy": 0, "desc": "Materials for a comfortable medium home."},
		{"id": "large_home_kit", "name": "Large Home Kit", "cat": "misc", "stack": 5, "sell": 200, "buy": 0, "desc": "Materials for a grand large home."},
		{"id": "barn_kit", "name": "Barn Kit", "cat": "misc", "stack": 5, "sell": 60, "buy": 0, "desc": "Materials for a sturdy barn."},
		{"id": "storage_shed_kit", "name": "Storage Shed Kit", "cat": "misc", "stack": 5, "sell": 30, "buy": 0, "desc": "Materials for a storage shed."},
		{"id": "gate_kit", "name": "Gate Kit", "cat": "misc", "stack": 20, "sell": 8, "buy": 0, "desc": "Materials for a wooden gate."},
		{"id": "garden_bed_kit", "name": "Garden Bed Kit", "cat": "misc", "stack": 10, "sell": 15, "buy": 0, "desc": "Materials for a raised garden bed."},
		{"id": "windmill_kit", "name": "Windmill Kit", "cat": "misc", "stack": 5, "sell": 150, "buy": 0, "desc": "Materials for a grain windmill."},
		{"id": "greenhouse_kit", "name": "Greenhouse Kit", "cat": "misc", "stack": 5, "sell": 120, "buy": 0, "desc": "Materials for a spacious glass greenhouse."},
		{"id": "decorative_statue_kit", "name": "Monument Statue Kit", "cat": "misc", "stack": 5, "sell": 200, "buy": 0, "desc": "Materials for an impressive stone monument statue."},
		{"id": "decorative_fountain_kit", "name": "Fountain Kit", "cat": "misc", "stack": 10, "sell": 60, "buy": 0, "desc": "Materials for a decorative fountain."},
		{"id": "decorative_bench_kit", "name": "Bench Kit", "cat": "misc", "stack": 10, "sell": 10, "buy": 0, "desc": "Materials for a wooden bench."},
		{"id": "decorative_lantern_kit", "name": "Lantern Kit", "cat": "misc", "stack": 10, "sell": 12, "buy": 0, "desc": "A placeable lantern that glows at night."},
		{"id": "decorative_sign_kit", "name": "Sign Kit", "cat": "misc", "stack": 10, "sell": 6, "buy": 0, "desc": "Materials for a wooden signpost."},
		{"id": "silo_kit", "name": "Silo Kit", "cat": "misc", "stack": 5, "sell": 100, "buy": 0, "desc": "Materials for a tall stone silo with 36 slots of crop-only storage."},
		{"id": "well_kit", "name": "Well Kit", "cat": "misc", "stack": 5, "sell": 30, "buy": 0, "desc": "Materials for a fresh water well."},
		{"id": "hotel_kit", "name": "Hotel Kit", "cat": "misc", "stack": 5, "sell": 120, "buy": 0, "desc": "Materials to build a cozy inn for visiting travelers. Earns coins from guests."},
		{"id": "scarecrow_kit", "name": "Scarecrow Kit", "cat": "misc", "stack": 10, "sell": 15, "buy": 0, "desc": "A scarecrow that protects crops from disease in a 5×5 area."},
		{"id": "compost_bin_kit", "name": "Compost Bin Kit", "cat": "misc", "stack": 5, "sell": 20, "buy": 0, "desc": "A compost bin that turns excess crops into compost."},
	]
	for bk in building_kits:
		var kit := ItemData.new()
		kit.id = bk.id
		kit.display_name = bk.name
		kit.category = bk.cat
		kit.stack_size = bk.stack
		kit.sell_price = bk.sell
		kit.buy_price = bk.buy
		kit.description = bk.desc
		# Use the building's sprite as the inventory icon, scaled down
		if bk.id == "compost_bin_kit":
			var building_tex: Texture2D = load("res://assets/generated/building_compost_bin_frame_0.png")
			if building_tex:
				var img: Image = building_tex.get_image()
				img.resize(16, 16, Image.INTERPOLATE_NEAREST)
				kit.icon = ImageTexture.create_from_image(img)
		register_item(kit)

	# Animal product items
	var animal_items := [
		{"id": "feather", "name": "Feather", "category": "resource", "price": 2, "desc": "A soft feather from a fowl."},
		{"id": "egg", "name": "Egg", "category": "food", "price": 5, "desc": "A fresh egg. Can be eaten or used in cooking."},
		{"id": "milk", "name": "Milk", "category": "food", "price": 8, "desc": "Fresh milk from a bovine. Nutritious and versatile."},
		{"id": "leather", "name": "Leather", "category": "resource", "price": 12, "desc": "Tough hide, good for crafting."},
		{"id": "fur", "name": "Fur", "category": "resource", "price": 6, "desc": "Soft animal fur."},
		{"id": "chicken_meat", "name": "Chicken Meat", "category": "food", "price": 8, "desc": "Tender poultry meat from a chicken."},
		{"id": "venison", "name": "Venison", "category": "food", "price": 14, "desc": "Lean meat from a deer."},
		{"id": "antlers", "name": "Antlers", "category": "resource", "price": 18, "desc": "A set of deer antlers. Valuable for decoration."},
		{"id": "wool", "name": "Wool", "category": "resource", "price": 8, "desc": "Sheared wool from a sheep."},
		{"id": "truffle", "name": "Truffle", "category": "food", "price": 25, "desc": "A rare and aromatic truffle foraged by pigs."},
		{"id": "nut", "name": "Nut", "category": "food", "price": 3, "desc": "A foraged nut. Small but snackable."},
		{"id": "shell", "name": "Shell", "category": "resource", "price": 8, "desc": "A sturdy turtle shell."},
	]
	for ai in animal_items:
		var animal_item := ItemData.new()
		animal_item.id = ai.id
		animal_item.display_name = ai.name
		animal_item.category = ai.category
		animal_item.stack_size = 99
		animal_item.sell_price = ai.price
		animal_item.buy_price = 0
		animal_item.description = ai.desc
		register_item(animal_item)

	# Fish items
	var fish_items := [
		{"id": "raw_fish", "name": "Raw Fish", "category": "food", "price": 8, "desc": "A common raw fish. Cook it for a hearty meal."},
		{"id": "carp", "name": "Carp", "category": "food", "price": 12, "desc": "A freshwater carp. Makes a fine stew."},
		{"id": "perch", "name": "Perch", "category": "food", "price": 10, "desc": "A tasty perch. Great grilled."},
		{"id": "salmon", "name": "Salmon", "category": "food", "price": 20, "desc": "A prized salmon. Rich and flavorful."},
		{"id": "trout", "name": "Trout", "category": "food", "price": 22, "desc": "A spotted trout. Delicate meat."},
		{"id": "tuna", "name": "Tuna", "category": "food", "price": 40, "desc": "A large tuna. Excellent for cooking."},
		{"id": "swordfish", "name": "Swordfish", "category": "food", "price": 55, "desc": "A mighty swordfish. A true catch."},
		{"id": "golden_fish", "name": "Golden Fish", "category": "food", "price": 100, "desc": "A shimmering golden fish of great value."},
		{"id": "moonfish", "name": "Moonfish", "category": "food", "price": 80, "desc": "A pale fish that glows with moonlight. Very rare."},
	]
	for fi in fish_items:
		var fish_item := ItemData.new()
		fish_item.id = fi.id
		fish_item.display_name = fi.name
		fish_item.category = fi.category
		fish_item.stack_size = 20
		fish_item.sell_price = fi.price
		fish_item.buy_price = 0
		fish_item.description = fi.desc
		register_item(fish_item)

	# Meal/cooking items
	var meal_ids := [
		{"id": "grilled_vegetables", "name": "Grilled Vegetables", "desc": "A healthy mix of grilled garden vegetables.", "price": 15, "category": "meal"},
		{"id": "vegetable_soup", "name": "Vegetable Soup", "desc": "A warm and hearty vegetable soup.", "price": 25, "category": "meal"},
		{"id": "garden_salad", "name": "Garden Salad", "desc": "Fresh garden greens with a light dressing.", "price": 12, "category": "meal"},
		{"id": "roasted_roots", "name": "Roasted Roots", "desc": "Slow-roasted root vegetables.", "price": 20, "category": "meal"},
		{"id": "fruit_compote", "name": "Fruit Compote", "desc": "Sweet stewed fruits.", "price": 18, "category": "meal"},
		{"id": "berry_juice", "name": "Berry Juice", "desc": "Refreshing juice from wild berries.", "price": 10, "category": "meal"},
		{"id": "hearty_stew", "name": "Hearty Stew", "desc": "A filling stew with meat and vegetables.", "price": 45, "category": "meal"},
		{"id": "growth_tea", "name": "Growth Tea", "desc": "A herbal tea that helps crops grow faster.", "price": 30, "category": "meal"},
		{"id": "lucky_salad", "name": "Lucky Salad", "desc": "A salad said to bring good fortune.", "price": 35, "category": "meal"},
		{"id": "farmers_breakfast", "name": "Farmer's Breakfast", "desc": "A hearty breakfast to start the day.", "price": 30, "category": "meal"},
		{"id": "golden_soup", "name": "Golden Soup", "desc": "A luxurious soup with rare ingredients.", "price": 60, "category": "meal"},
		{"id": "herbal_tea", "name": "Herbal Tea", "desc": "Soothing tea made from aromatic herbs.", "price": 15, "category": "meal"},
		{"id": "stuffed_vegetables", "name": "Stuffed Vegetables", "desc": "Vegetables stuffed with seasoned grains.", "price": 35, "category": "meal"},
		{"id": "candied_fruit", "name": "Candied Fruit", "desc": "Fruit preserved in sweet syrup.", "price": 22, "category": "meal"},
		{"id": "mushroom_stew", "name": "Mushroom Stew", "desc": "Earthy mushroom stew.", "price": 28, "category": "meal"},
		# --- Baking meals ---
		{"id": "fresh_bread", "name": "Fresh Bread", "desc": "A warm crusty loaf. Simple and satisfying.", "price": 4, "category": "meal"},
		{"id": "buttered_bread", "name": "Buttered Bread", "desc": "Warm bread slathered in creamy butter.", "price": 8, "category": "meal"},
		{"id": "cinnamon_toast", "name": "Cinnamon Toast", "desc": "Toasted bread sprinkled with cinnamon and sugar.", "price": 10, "category": "meal"},
		{"id": "fruit_tart_bake", "name": "Fruit Tart", "desc": "A golden pastry filled with fresh glazed fruit.", "price": 12, "category": "meal"},
		{"id": "chocolate_croissant", "name": "Chocolate Croissant", "desc": "A flaky croissant filled with rich chocolate.", "price": 14, "category": "meal"},
	]
	for m in meal_ids:
		var meal_item := ItemData.new()
		meal_item.id = m.id
		meal_item.display_name = m.name
		meal_item.category = m.category
		meal_item.stack_size = 20
		meal_item.sell_price = m.price
		meal_item.buy_price = 0
		meal_item.description = m.desc
		register_item(meal_item)
	
	# --- Spirit Harvest: Boss crops ---
	var boss_crop_items := [
		{"id": "soulberry_seed", "name": "Soulberry Seed", "cat": "seed", "price": 15, "desc": "Plant on tilled soil to grow soulberries — a mystical purple crop."},
		{"id": "soulberry", "name": "Soulberry", "cat": "crop", "price": 20, "desc": "A glowing purple berry pulsing with arcane energy."},
		{"id": "golden_wheat_seed", "name": "Golden Wheat Seed", "cat": "seed", "price": 15, "desc": "Plant on tilled soil to grow golden wheat — radiant and resilient."},
		{"id": "golden_wheat", "name": "Golden Wheat", "cat": "crop", "price": 20, "desc": "A radiant golden stalk of wheat, warm to the touch."},
		{"id": "nectar_bloom_seed", "name": "Nectar Bloom Seed", "cat": "seed", "price": 15, "desc": "Plant on tilled soil to grow nectar blooms — fragrant and vibrant."},
		{"id": "nectar_bloom", "name": "Nectar Bloom", "cat": "crop", "price": 20, "desc": "A vibrant pink flower dripping with sweet nectar."},
	]
	for bi in boss_crop_items:
		var bc_item := ItemData.new()
		bc_item.id = bi.id
		bc_item.display_name = bi.name
		bc_item.category = bi.cat
		bc_item.stack_size = 99
		bc_item.sell_price = bi.price
		bc_item.buy_price = 0
		bc_item.description = bi.desc
		register_item(bc_item)
	
	# --- Spirit Harvest: Bait items ---
	var bait_items := [
		{"id": "soulberry_pie", "name": "Soulberry Pie", "price": 0, "desc": "★ Summons the Root Warden. Equip on your hotbar and press SPACE/click to use."},
		{"id": "golden_hay_bale", "name": "Golden Hay Bale", "price": 0, "desc": "★ Summons the Hollow Stag. Equip on your hotbar and press SPACE/click to use."},
		{"id": "nectar_brew", "name": "Nectar Brew", "price": 0, "desc": "★ Summons the Blooming Wyrm. Equip on your hotbar and press SPACE/click to use."},
		{"id": "essence_of_inconstance", "name": "Essence of Inconstance", "price": 0, "desc": "★ Summons the Inconstant Soul. Equip on your hotbar and press SPACE/click to use."},
	]
	for bait in bait_items:
		var bait_item := ItemData.new()
		bait_item.id = bait.id
		bait_item.display_name = bait.name
		bait_item.category = "misc"
		bait_item.stack_size = 10
		bait_item.sell_price = bait.price
		bait_item.buy_price = 0
		bait_item.description = bait.desc
		register_item(bait_item)
	
	# --- Spirit Harvest: Boss drops ---
	var boss_drops := [
		{"id": "wardens_core", "name": "Warden's Core", "price": 0, "desc": "The pulsing core of the Root Warden. Glows with purple energy."},
		{"id": "stags_essence", "name": "Stag's Essence", "price": 0, "desc": "The ethereal essence of the Hollow Stag. Warm golden light swirls within."},
		{"id": "wyrms_petal", "name": "Wyrm's Petal", "price": 0, "desc": "A shimmering petal from the Blooming Wyrm. Still warm from its breath."},
		{"id": "soul_of_inconstance", "name": "Soul of Inconstance", "price": 0, "desc": "The purified soul of the final spirit. The Isles feel calmer already."},
	]
	for bd in boss_drops:
		var drop_item := ItemData.new()
		drop_item.id = bd.id
		drop_item.display_name = bd.name
		drop_item.category = "misc"
		drop_item.stack_size = 10
		drop_item.sell_price = bd.price
		drop_item.buy_price = 0
		drop_item.description = bd.desc
		register_item(drop_item)
	
	# --- Spirit Harvest: Boss rewards (permanent items) ---
	var boss_rewards := [
		{"id": "evergrowth_seed", "name": "Evergrowth Seed", "cat": "seed", "price": 0, "desc": "A legendary seed that regrows every day after harvest. Endless berries forever!"},
		{"id": "evergrowth_berry", "name": "Evergrowth Berry", "cat": "food", "price": 5, "desc": "A sweet berry from the legendary Evergrowth plant. It grows back the next day!"},
		{"id": "mythril_ingot", "name": "Mythril Ingot", "price": 0, "desc": "A shimmering ingot of mythril. Carrying it makes your strikes hit harder (+10 damage)."},
		{"id": "everbloom_seed", "name": "Everbloom Seed", "cat": "seed", "price": 0, "desc": "A luminous seed that grows into an everbloom — a flower that glows softly at night."},
		{"id": "everbloom_flower", "name": "Everbloom Flower", "cat": "crop", "price": 0, "desc": "A beautiful flower that emits a gentle glow. Perfect for decoration."},
	]
	for br in boss_rewards:
		var reward_item := ItemData.new()
		reward_item.id = br.id
		reward_item.display_name = br.name
		reward_item.category = br.get("cat", "misc")
		reward_item.stack_size = 99
		reward_item.sell_price = br.price
		reward_item.buy_price = 0
		reward_item.description = br.desc
		register_item(reward_item)
	
	# ── Alchemy: Potions (brewed at the crafting table) ──
	var potions := [
		{"id": "health_tonic", "name": "Health Tonic", "sell": 25, "desc": "Restores 30 HP. A mild healing brew."},
		{"id": "health_potion", "name": "Health Potion", "sell": 50, "desc": "Restores 60 HP. Essential for deep mine expeditions."},
		{"id": "greater_health_potion", "name": "Greater Health Potion", "sell": 120, "desc": "Restores 120 HP. A potent crimson elixir."},
		{"id": "speed_tonic", "name": "Speed Tonic", "sell": 30, "desc": "Grants +20% movement speed for 5 minutes."},
		{"id": "swift_elixir", "name": "Swift Elixir", "sell": 60, "desc": "Grants +30% movement speed for 10 minutes."},
		{"id": "iron_skin_potion", "name": "Iron Skin Potion", "sell": 40, "desc": "Grants +25% defense for 5 minutes."},
		{"id": "stone_skin_elixir", "name": "Stone Skin Elixir", "sell": 80, "desc": "Grants +40% defense for 10 minutes. Brewed with obsidian."},
		{"id": "luck_draught", "name": "Luck Draught", "sell": 75, "desc": "Grants +30% luck for 5 minutes. A gambler's favorite."},
		{"id": "elixir_of_vigor", "name": "Elixir of Vigor", "sell": 65, "desc": "Restores 50 HP and grants +20% speed for 5 minutes."},
		{"id": "mana_infusion", "name": "Mana Infusion", "sell": 55, "desc": "Restores 50 energy instantly. Brewed from ghostly essences."},
	]
	for p in potions:
		var pot := ItemData.new()
		pot.id = p.id
		pot.display_name = p.name
		pot.category = "potion"
		pot.stack_size = 10
		pot.sell_price = p.sell
		pot.buy_price = 0
		pot.description = p.desc
		register_item(pot)

	# ── Island Biome Items (Snowland) ──
	var ice_crystal_item := ItemData.new()
	ice_crystal_item.id = "ice_crystal"
	ice_crystal_item.display_name = "Ice Crystal"
	ice_crystal_item.category = "resource"
	ice_crystal_item.stack_size = 99
	ice_crystal_item.sell_price = 8
	ice_crystal_item.buy_price = 0
	ice_crystal_item.description = "A pristine frozen crystal from the snowy wilds."
	register_item(ice_crystal_item)

	var snow_flower_item := ItemData.new()
	snow_flower_item.id = "snow_flower"
	snow_flower_item.display_name = "Snow Flower"
	snow_flower_item.category = "resource"
	snow_flower_item.stack_size = 99
	snow_flower_item.sell_price = 6
	snow_flower_item.buy_price = 0
	snow_flower_item.description = "A delicate flower that blooms only in ice."
	register_item(snow_flower_item)

	var polar_bear_hide_item := ItemData.new()
	polar_bear_hide_item.id = "polar_bear_hide"
	polar_bear_hide_item.display_name = "Polar Bear Hide"
	polar_bear_hide_item.category = "misc"
	polar_bear_hide_item.stack_size = 20
	polar_bear_hide_item.sell_price = 15
	polar_bear_hide_item.buy_price = 0
	polar_bear_hide_item.description = "Thick warm hide from a polar bear."
	register_item(polar_bear_hide_item)

	# ── Ice Cream Land Items ──
	var gumdrop_item := ItemData.new()
	gumdrop_item.id = "gumdrop"
	gumdrop_item.display_name = "Gumdrop"
	gumdrop_item.category = "food"
	gumdrop_item.stack_size = 99
	gumdrop_item.sell_price = 6
	gumdrop_item.buy_price = 0
	gumdrop_item.description = "A chewy, fruity gumdrop. Sweet and delightful!"
	register_item(gumdrop_item)

	var chocolate_chunk_item := ItemData.new()
	chocolate_chunk_item.id = "chocolate_chunk"
	chocolate_chunk_item.display_name = "Chocolate Chunk"
	chocolate_chunk_item.category = "food"
	chocolate_chunk_item.stack_size = 99
	chocolate_chunk_item.sell_price = 8
	chocolate_chunk_item.buy_price = 0
	chocolate_chunk_item.description = "A rich piece of chocolate from a chocolatey island."
	register_item(chocolate_chunk_item)

	var sugar_crystal_item := ItemData.new()
	sugar_crystal_item.id = "sugar_crystal"
	sugar_crystal_item.display_name = "Sugar Crystal"
	sugar_crystal_item.category = "resource"
	sugar_crystal_item.stack_size = 99
	sugar_crystal_item.sell_price = 5
	sugar_crystal_item.buy_price = 0
	sugar_crystal_item.description = "Sparkly sugar crystals. Sweet as can be."
	register_item(sugar_crystal_item)

	var ice_cream_sandwich_item := ItemData.new()
	ice_cream_sandwich_item.id = "ice_cream_sandwich"
	ice_cream_sandwich_item.display_name = "Ice Cream Sandwich"
	ice_cream_sandwich_item.category = "food"
	ice_cream_sandwich_item.stack_size = 20
	ice_cream_sandwich_item.sell_price = 15
	ice_cream_sandwich_item.buy_price = 50
	var ics_tex: Texture2D = load("res://assets/icon_ice_cream_sandwich.png")
	if ics_tex.get_size().x > 16 or ics_tex.get_size().y > 16:
		var ics_img: Image = ics_tex.get_image()
		ics_img.resize(16, 16, Image.INTERPOLATE_NEAREST)
		ics_tex = ImageTexture.create_from_image(ics_img)
	ice_cream_sandwich_item.icon = ics_tex
	ice_cream_sandwich_item.description = "A delicious frozen treat with creamy filling between chocolate wafers. Restores hunger!"
	register_item(ice_cream_sandwich_item)

	# ── Desert Items ──
	var cactus_fruit_item := ItemData.new()
	cactus_fruit_item.id = "cactus_fruit"
	cactus_fruit_item.display_name = "Cactus Fruit"
	cactus_fruit_item.category = "food"
	cactus_fruit_item.stack_size = 99
	cactus_fruit_item.sell_price = 6
	cactus_fruit_item.buy_price = 0
	cactus_fruit_item.description = "A sweet, juicy fruit from a desert cactus."
	register_item(cactus_fruit_item)

	var golden_scarab_item := ItemData.new()
	golden_scarab_item.id = "golden_scarab"
	golden_scarab_item.display_name = "Golden Scarab"
	golden_scarab_item.category = "misc"
	golden_scarab_item.stack_size = 10
	golden_scarab_item.sell_price = 35
	golden_scarab_item.buy_price = 0
	golden_scarab_item.description = "A rare golden beetle from the desert sands."
	register_item(golden_scarab_item)

	var scorpion_stinger_item := ItemData.new()
	scorpion_stinger_item.id = "scorpion_stinger"
	scorpion_stinger_item.display_name = "Scorpion Stinger"
	scorpion_stinger_item.category = "misc"
	scorpion_stinger_item.stack_size = 20
	scorpion_stinger_item.sell_price = 10
	scorpion_stinger_item.buy_price = 0
	scorpion_stinger_item.description = "A sharp venomous stinger from a desert scorpion."
	register_item(scorpion_stinger_item)

	# ── Volcanic Items ──
	var sulfur_crystal_item := ItemData.new()
	sulfur_crystal_item.id = "sulfur_crystal"
	sulfur_crystal_item.display_name = "Sulfur Crystal"
	sulfur_crystal_item.category = "resource"
	sulfur_crystal_item.stack_size = 99
	sulfur_crystal_item.sell_price = 10
	sulfur_crystal_item.buy_price = 0
	sulfur_crystal_item.description = "A stinky yellow crystal from volcanic vents."
	register_item(sulfur_crystal_item)

	var ember_dust_item := ItemData.new()
	ember_dust_item.id = "ember_dust"
	ember_dust_item.display_name = "Ember Dust"
	ember_dust_item.category = "misc"
	ember_dust_item.stack_size = 20
	ember_dust_item.sell_price = 8
	ember_dust_item.buy_price = 0
	ember_dust_item.description = "Glowing ember fragments from a volcanic island."
	register_item(ember_dust_item)

	var magma_core_item := ItemData.new()
	magma_core_item.id = "magma_core"
	magma_core_item.display_name = "Magma Core"
	magma_core_item.category = "resource"
	magma_core_item.stack_size = 20
	magma_core_item.sell_price = 20
	magma_core_item.buy_price = 0
	magma_core_item.description = "The molten heart of a volcano. Radiates intense heat."
	register_item(magma_core_item)

	# ── Ethereal Items ──
	var moon_shard_item := ItemData.new()
	moon_shard_item.id = "moon_shard"
	moon_shard_item.display_name = "Moon Shard"
	moon_shard_item.category = "resource"
	moon_shard_item.stack_size = 99
	moon_shard_item.sell_price = 15
	moon_shard_item.buy_price = 0
	moon_shard_item.description = "A fragment of crystallized moonlight."
	register_item(moon_shard_item)

	var starlight_dust_item := ItemData.new()
	starlight_dust_item.id = "starlight_dust"
	starlight_dust_item.display_name = "Starlight Dust"
	starlight_dust_item.category = "misc"
	starlight_dust_item.stack_size = 20
	starlight_dust_item.sell_price = 12
	starlight_dust_item.buy_price = 0
	starlight_dust_item.description = "Sparkling cosmic dust from an ethereal realm."
	register_item(starlight_dust_item)

	var ethereal_essence_item := ItemData.new()
	ethereal_essence_item.id = "ethereal_essence"
	ethereal_essence_item.display_name = "Ethereal Essence"
	ethereal_essence_item.category = "misc"
	ethereal_essence_item.stack_size = 10
	ethereal_essence_item.sell_price = 25
	ethereal_essence_item.buy_price = 0
	ethereal_essence_item.description = "Concentrated spirit energy from the twilight realm."
	register_item(ethereal_essence_item)

	# ── Crafted Island Items ──
	var frozen_delight_item := ItemData.new()
	frozen_delight_item.id = "frozen_delight"
	frozen_delight_item.display_name = "Frozen Delight"
	frozen_delight_item.category = "meal"
	frozen_delight_item.stack_size = 20
	frozen_delight_item.sell_price = 20
	frozen_delight_item.buy_price = 0
	frozen_delight_item.description = "A chilly treat made from ice crystals and berries."
	register_item(frozen_delight_item)

	var chocolate_fondue_item := ItemData.new()
	chocolate_fondue_item.id = "chocolate_fondue"
	chocolate_fondue_item.display_name = "Chocolate Fondue"
	chocolate_fondue_item.category = "meal"
	chocolate_fondue_item.stack_size = 20
	chocolate_fondue_item.sell_price = 18
	chocolate_fondue_item.buy_price = 0
	chocolate_fondue_item.description = "Rich melted chocolate with fresh berries."
	register_item(chocolate_fondue_item)

	var candied_cactus_item := ItemData.new()
	candied_cactus_item.id = "candied_cactus"
	candied_cactus_item.display_name = "Candied Cactus"
	candied_cactus_item.category = "meal"
	candied_cactus_item.stack_size = 20
	candied_cactus_item.sell_price = 16
	candied_cactus_item.buy_price = 0
	candied_cactus_item.description = "Cactus fruit coated in sugar. Surprisingly delicious!"
	register_item(candied_cactus_item)

	var magma_steel_item := ItemData.new()
	magma_steel_item.id = "magma_steel"
	magma_steel_item.display_name = "Magma Steel"
	magma_steel_item.category = "resource"
	magma_steel_item.stack_size = 20
	magma_steel_item.sell_price = 35
	magma_steel_item.buy_price = 0
	magma_steel_item.description = "Volcanic steel infused with magma cores. Incredibly strong."
	register_item(magma_steel_item)

	var starlight_amulet_item := ItemData.new()
	starlight_amulet_item.id = "starlight_amulet"
	starlight_amulet_item.display_name = "Starlight Amulet"
	starlight_amulet_item.category = "misc"
	starlight_amulet_item.stack_size = 1
	starlight_amulet_item.sell_price = 80
	starlight_amulet_item.buy_price = 0
	starlight_amulet_item.description = "A shimmering amulet infused with moonlight."
	register_item(starlight_amulet_item)

	var ice_ward_item := ItemData.new()
	ice_ward_item.id = "ice_ward"
	ice_ward_item.display_name = "Ice Ward"
	ice_ward_item.category = "misc"
	ice_ward_item.stack_size = 10
	ice_ward_item.sell_price = 30
	ice_ward_item.buy_price = 0
	ice_ward_item.description = "A protective ward carved from ice crystal."
	register_item(ice_ward_item)

	var sugar_sculpture_item := ItemData.new()
	sugar_sculpture_item.id = "sugar_sculpture"
	sugar_sculpture_item.display_name = "Sugar Sculpture"
	sugar_sculpture_item.category = "meal"
	sugar_sculpture_item.stack_size = 10
	sugar_sculpture_item.sell_price = 80
	sugar_sculpture_item.buy_price = 0
	sugar_sculpture_item.description = "A delicate sculpture made of pure sugar crystal."
	register_item(sugar_sculpture_item)

	var ember_lantern_item := ItemData.new()
	ember_lantern_item.id = "ember_lantern"
	ember_lantern_item.display_name = "Ember Lantern"
	ember_lantern_item.category = "misc"
	ember_lantern_item.stack_size = 10
	ember_lantern_item.sell_price = 35
	ember_lantern_item.buy_price = 0
	ember_lantern_item.is_light_source = true
	ember_lantern_item.description = "A warm lantern that glows with captured embers."
	register_item(ember_lantern_item)

	# ── New Crafted Items ──
	var shell_necklace_item := ItemData.new()
	shell_necklace_item.id = "shell_necklace"
	shell_necklace_item.display_name = "Shell Necklace"
	shell_necklace_item.category = "misc"
	shell_necklace_item.stack_size = 1
	shell_necklace_item.sell_price = 45
	shell_necklace_item.buy_price = 0
	shell_necklace_item.description = "A simple necklace of polished shells. Brings good luck."
	register_item(shell_necklace_item)

	var antler_bow_item := ItemData.new()
	antler_bow_item.id = "antler_bow"
	antler_bow_item.display_name = "Antler Bow"
	antler_bow_item.category = "weapon"
	antler_bow_item.stack_size = 1
	antler_bow_item.sell_price = 120
	antler_bow_item.buy_price = 0
	antler_bow_item.description = "A mighty bow reinforced with antlers. Fires faster arrows."
	register_item(antler_bow_item)

	var flower_extract_item := ItemData.new()
	flower_extract_item.id = "flower_extract"
	flower_extract_item.display_name = "Flower Extract"
	flower_extract_item.category = "potion"
	flower_extract_item.stack_size = 20
	flower_extract_item.sell_price = 12
	flower_extract_item.buy_price = 0
	flower_extract_item.description = "A fragrant extract distilled from wildflowers. Restores health."
	register_item(flower_extract_item)

	var ancient_compass_item := ItemData.new()
	ancient_compass_item.id = "ancient_compass"
	ancient_compass_item.display_name = "Ancient Compass"
	ancient_compass_item.category = "misc"
	ancient_compass_item.stack_size = 1
	ancient_compass_item.sell_price = 200
	ancient_compass_item.buy_price = 0
	ancient_compass_item.description = "A mysterious compass that points toward buried treasure."
	register_item(ancient_compass_item)

	var magma_pickaxe_item := ItemData.new()
	magma_pickaxe_item.id = "magma_pickaxe"
	magma_pickaxe_item.display_name = "Magma Pickaxe"
	magma_pickaxe_item.category = "tool"
	magma_pickaxe_item.stack_size = 1
	magma_pickaxe_item.sell_price = 250
	magma_pickaxe_item.buy_price = 0
	magma_pickaxe_item.description = "A legendary pickaxe forged from magma steel. Auto-smelts ores!"
	register_item(magma_pickaxe_item)

	# ── Island Potions ──
	var frost_resist_tonic_item := ItemData.new()
	frost_resist_tonic_item.id = "frost_resist_tonic"
	frost_resist_tonic_item.display_name = "Frost Resist Tonic"
	frost_resist_tonic_item.category = "potion"
	frost_resist_tonic_item.stack_size = 10
	frost_resist_tonic_item.sell_price = 30
	frost_resist_tonic_item.buy_price = 0
	frost_resist_tonic_item.description = "Protects against the bitter cold."
	register_item(frost_resist_tonic_item)

	var sweet_elixir_item := ItemData.new()
	sweet_elixir_item.id = "sweet_elixir"
	sweet_elixir_item.display_name = "Sweet Elixir"
	sweet_elixir_item.category = "potion"
	sweet_elixir_item.stack_size = 10
	sweet_elixir_item.sell_price = 25
	sweet_elixir_item.buy_price = 0
	sweet_elixir_item.description = "A sugary potion that restores health."
	register_item(sweet_elixir_item)

	var desert_salve_item := ItemData.new()
	desert_salve_item.id = "desert_salve"
	desert_salve_item.display_name = "Desert Salve"
	desert_salve_item.category = "potion"
	desert_salve_item.stack_size = 10
	desert_salve_item.sell_price = 28
	desert_salve_item.buy_price = 0
	desert_salve_item.description = "Cools and soothes, perfect for the scorching heat."
	register_item(desert_salve_item)

	var magma_burst_item := ItemData.new()
	magma_burst_item.id = "magma_burst"
	magma_burst_item.display_name = "Magma Burst"
	magma_burst_item.category = "potion"
	magma_burst_item.stack_size = 10
	magma_burst_item.sell_price = 40
	magma_burst_item.buy_price = 0
	magma_burst_item.description = "A volatile orb that explodes on impact."
	register_item(magma_burst_item)

	var ethereal_infusion_item := ItemData.new()
	ethereal_infusion_item.id = "ethereal_infusion"
	ethereal_infusion_item.display_name = "Ethereal Infusion"
	ethereal_infusion_item.category = "potion"
	ethereal_infusion_item.stack_size = 10
	ethereal_infusion_item.sell_price = 50
	ethereal_infusion_item.buy_price = 0
	ethereal_infusion_item.description = "Infuses the drinker with ethereal energy."
	register_item(ethereal_infusion_item)

	var polar_balm_item := ItemData.new()
	polar_balm_item.id = "polar_balm"
	polar_balm_item.display_name = "Polar Balm"
	polar_balm_item.category = "potion"
	polar_balm_item.stack_size = 10
	polar_balm_item.sell_price = 32
	polar_balm_item.buy_price = 0
	polar_balm_item.description = "Thick warming balm made from polar bear hide and snow flowers."
	register_item(polar_balm_item)

	var cosmic_dust_item := ItemData.new()
	cosmic_dust_item.id = "cosmic_dust"
	cosmic_dust_item.display_name = "Cosmic Dust"
	cosmic_dust_item.category = "potion"
	cosmic_dust_item.stack_size = 10
	cosmic_dust_item.sell_price = 60
	cosmic_dust_item.buy_price = 0
	cosmic_dust_item.description = "Ultra-rare alchemical dust from beyond the stars."
	register_item(cosmic_dust_item)

	# ── Bakery Items (baked at the Bakery mini-game) ──
	var bread_item := ItemData.new()
	bread_item.id = "bread"
	bread_item.display_name = "Bread"
	bread_item.category = "food"
	bread_item.stack_size = 20
	bread_item.sell_price = 3
	bread_item.buy_price = 0
	bread_item.description = "A warm crusty loaf of freshly baked bread. A perfect snack."
	register_item(bread_item)

	var baguette_item := ItemData.new()
	baguette_item.id = "baguette"
	baguette_item.display_name = "Baguette"
	baguette_item.category = "food"
	baguette_item.stack_size = 20
	baguette_item.sell_price = 25
	baguette_item.buy_price = 0
	baguette_item.description = "A long golden French baguette with a crispy crust."
	register_item(baguette_item)

	var croissant_item := ItemData.new()
	croissant_item.id = "croissant"
	croissant_item.display_name = "Croissant"
	croissant_item.category = "food"
	croissant_item.stack_size = 20
	croissant_item.sell_price = 20
	croissant_item.buy_price = 0
	croissant_item.description = "A flaky buttery crescent pastry. Melts in your mouth!"
	register_item(croissant_item)

	var cinnamon_roll_item := ItemData.new()
	cinnamon_roll_item.id = "cinnamon_roll"
	cinnamon_roll_item.display_name = "Cinnamon Roll"
	cinnamon_roll_item.category = "food"
	cinnamon_roll_item.stack_size = 20
	cinnamon_roll_item.sell_price = 22
	cinnamon_roll_item.buy_price = 0
	cinnamon_roll_item.description = "A sweet cinnamon-swirl roll topped with creamy icing."
	register_item(cinnamon_roll_item)

	var fruit_tart_item := ItemData.new()
	fruit_tart_item.id = "fruit_tart"
	fruit_tart_item.display_name = "Fruit Tart"
	fruit_tart_item.category = "food"
	fruit_tart_item.stack_size = 20
	fruit_tart_item.sell_price = 28
	fruit_tart_item.buy_price = 0
	fruit_tart_item.description = "A golden pastry shell filled with fresh glazed fruit."
	register_item(fruit_tart_item)

	var dough_item := ItemData.new()
	dough_item.id = "dough"
	dough_item.display_name = "Bread Dough"
	dough_item.category = "food"
	dough_item.stack_size = 99
	dough_item.sell_price = 5
	dough_item.buy_price = 0
	dough_item.description = "Freshly kneaded bread dough ready for the oven."
	register_item(dough_item)

	# ── Special: Minecraft Wheat (classic blocky wheat from another world) ──
	var mc_wheat_item := ItemData.new()
	mc_wheat_item.id = "minecraft_wheat"
	mc_wheat_item.display_name = "Minecraft Wheat"
	mc_wheat_item.category = "crop"
	mc_wheat_item.stack_size = 64
	mc_wheat_item.sell_price = 8
	mc_wheat_item.buy_price = 0
	mc_wheat_item.description = "A classic blocky wheat. Reminds you of home."
	mc_wheat_item.icon = load("res://assets/generated/wheat.png")
	register_item(mc_wheat_item)

	var mc_seed_item := ItemData.new()
	mc_seed_item.id = "minecraft_wheat_seeds"
	mc_seed_item.display_name = "Minecraft Seeds"
	mc_seed_item.category = "seed"
	mc_seed_item.stack_size = 64
	mc_seed_item.sell_price = 2
	mc_seed_item.buy_price = 10
	mc_seed_item.description = "Seeds from another world. Plant on tilled soil to grow Minecraft Wheat."
	mc_seed_item.icon = load("res://assets/generated/minecraft_wheat_seeds.png")
	register_item(mc_seed_item)

	var fiber_item := ItemData.new()
	fiber_item.id = "fiber"
	fiber_item.display_name = "Fiber"
	fiber_item.category = "resource"
	fiber_item.stack_size = 99
	fiber_item.sell_price = 2
	fiber_item.buy_price = 0
	fiber_item.description = "Sturdy plant fiber. Useful for crafting ropes and textiles."
	register_item(fiber_item)

	# Assign procedural icons to all items that lack one
	_assign_missing_item_icons()

# ---------------------------------------------------------------------------
# Item icon generation (procedural, no external files needed)
# ---------------------------------------------------------------------------

## Generate a 16×16 icon for any item.
## - Standard items (resource, food, meal, tool, misc) → clean category-themed icons.
## - Procedural items (seed, crop) → fully unique per item_id with varied shapes/patterns.
## - If a pre-generated PNG exists at res://assets/generated/icon_{item_id}_frame_0.png,
##   that is loaded instead (allows hand-authored replacements).
static func make_item_icon(category: String, item_id: String, _display_name: String) -> Texture2D:
	# Check for pre-generated asset first
	var pregen_path: String = "res://assets/generated/icon_" + item_id + "_frame_0.png"
	if ResourceLoader.exists(pregen_path):
		var tex: Texture2D = load(pregen_path)
		var size: Vector2 = tex.get_size()
		# Resize pre-generated PNGs to 16×16 so all icons display at the same size
		if size.x > 16 or size.y > 16:
			var img: Image = tex.get_image()
			img.resize(16, 16, Image.INTERPOLATE_NEAREST)
			tex = ImageTexture.create_from_image(img)
		return tex
	
	# Potions without a pre-gen icon get a tinted potion bottle
	if category == "potion":
		return _make_potion_icon(item_id)
	
	var base_color := _item_color_for(category, item_id)
	
	# Seeds and crops get fully unique procedural icons
	if category in ["seed", "crop"]:
		return _make_procedural_icon(base_color, item_id)
	
	# Standard items get a clean category-themed shape (or item-specific when available)
	return _make_standard_icon(base_color, category, item_id)


## Pre-generated potion bottle base icon (32×32).
const POTION_BOTTLE_BASE := preload("res://assets/generated/potion_bottle_frame_0.png")

## Generate a tinted potion bottle icon for potions without a pre-gen PNG.
static func _make_potion_icon(item_id: String) -> Texture2D:
	var tint: Color
	match item_id:
		"health_tonic":            tint = Color(0.9, 0.3, 0.3)     # pale red
		"health_potion":           tint = Color(0.85, 0.15, 0.15) # red
		"greater_health_potion":   tint = Color(0.75, 0.05, 0.05) # crimson
		"speed_tonic":             tint = Color(0.4, 0.85, 0.3)   # light green
		"swift_elixir":            tint = Color(0.2, 0.75, 0.15)  # bright green
		"iron_skin_potion":        tint = Color(0.55, 0.55, 0.6)  # gray/iron
		"stone_skin_elixir":       tint = Color(0.45, 0.4, 0.45)  # dark gray
		"luck_draught":            tint = Color(0.9, 0.75, 0.15)  # gold
		"elixir_of_vigor":         tint = Color(0.9, 0.55, 0.15)  # orange
		"mana_infusion":           tint = Color(0.3, 0.5, 0.95)   # blue
		"flower_extract":          tint = Color(0.85, 0.4, 0.7)   # pink
		_:
			tint = Color(0.7, 0.7, 0.7)  # fallback gray

	var img: Image = POTION_BOTTLE_BASE.get_image()
	img.resize(16, 16, Image.INTERPOLATE_NEAREST)
	for y in range(16):
		for x in range(16):
			var p: Color = img.get_pixel(x, y)
			if p.a > 0.0:
				img.set_pixel(x, y, Color(
					p.r * tint.r,
					p.g * tint.g,
					p.b * tint.b,
					p.a
				))
	return ImageTexture.create_from_image(img)


## Generates a 16×16 icon for standard items (non-seed/non-crop).
## Uses item-specific shapes for known items (venison → meat, wood → log, etc.)
## and falls back to category-themed simple shapes for everything else.
static func _make_standard_icon(color: Color, category: String, item_id: String) -> Texture2D:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	
	match item_id:
		"chicken_meat":
			_draw_meat(img, color)
		"venison":
			_draw_meat(img, color)
		"wood":
			_draw_log(img, color)
		"stone":
			_draw_rock(img, color)
		"egg":
			_draw_egg(img, color)
		"berry":
			_draw_berries(img, color)
		"milk":
			_draw_milk(img, color)
		"feather":
			_draw_feather(img, Color(0.85, 0.8, 0.7))
		"leather":
			_draw_leather(img, Color(0.6, 0.4, 0.2))
		"fur":
			_draw_fur(img, Color(0.65, 0.5, 0.3))
		"wool":
			_draw_wool(img, Color(0.85, 0.8, 0.7))
		"iron_ore":
			_draw_iron_ore(img, Color(0.55, 0.5, 0.65))
		"iron_ingot":
			_draw_iron_ingot(img, Color(0.6, 0.6, 0.65))
		"flower":
			_draw_flower(img, Color(0.9, 0.4, 0.6))
		"mushroom":
			_draw_mushroom(img, Color(0.7, 0.55, 0.35))
		"antlers":
			_draw_antlers(img, Color(0.5, 0.4, 0.25))
		"shell":
			_draw_shell(img, Color(0.3, 0.65, 0.3))
		"nut":
			_draw_nut(img, Color(0.55, 0.4, 0.2))
		"truffle":
			_draw_truffle(img, Color(0.35, 0.2, 0.1))
		"wooden_planks":
			_draw_planks(img, Color(0.6, 0.45, 0.2))
		"fence_material":
			_draw_fence_log(img, Color(0.5, 0.35, 0.15))
		"stone_fence_material":
			_draw_rock(img, Color(0.5, 0.45, 0.4))
		"ice_crystal":
			_draw_ice_crystal(img, Color(0.5, 0.7, 0.95))
		"snow_flower":
			_draw_snow_flower(img, Color(0.75, 0.85, 1.0))
		"gumdrop":
			_draw_gumdrop(img, Color(0.9, 0.3, 0.4))
		"chocolate_chunk":
			_draw_chocolate_chunk(img, Color(0.4, 0.25, 0.15))
		"sugar_crystal":
			_draw_ice_crystal(img, Color(0.95, 0.85, 0.7))
		"cactus_fruit":
			_draw_cactus_fruit(img, Color(0.8, 0.3, 0.35))
		"golden_scarab":
			_draw_scarab(img, Color(0.85, 0.7, 0.15))
		"scorpion_stinger":
			_draw_scorpion_stinger(img, Color(0.5, 0.2, 0.15))
		"sulfur_crystal":
			_draw_ice_crystal(img, Color(0.85, 0.8, 0.2))
		"ember_dust":
			_draw_ember_dust(img, Color(0.9, 0.4, 0.1))
		"magma_core":
			_draw_magma_core(img, Color(0.85, 0.2, 0.1))
		"moon_shard":
			_draw_ice_crystal(img, Color(0.6, 0.65, 0.95))
		"starlight_dust":
			_draw_starlight_dust(img, Color(0.8, 0.75, 0.95))
		"ethereal_essence":
			_draw_ethereal_essence(img, Color(0.55, 0.4, 0.85))
		# --- Pickaxes (base + tiers) ---
		"pickaxe_tool":
			_draw_pickaxe(img, _item_color_for("tool", item_id))
		"copper_pickaxe":
			_draw_pickaxe(img, _item_color_for("tool", item_id))
		"iron_pickaxe":
			_draw_pickaxe(img, _item_color_for("tool", item_id))
		"gold_pickaxe":
			_draw_pickaxe(img, _item_color_for("tool", item_id))
		"diamond_pickaxe":
			_draw_pickaxe(img, _item_color_for("tool", item_id))
		"mythril_pickaxe":
			_draw_pickaxe(img, _item_color_for("tool", item_id))
		"magma_pickaxe":
			_draw_pickaxe(img, _item_color_for("tool", item_id))
		# --- Spirit Harvest items ---
		"soulberry":
			_draw_soulberry(img)
		"soulberry_seed":
			_draw_soulberry_seed(img)
		"golden_wheat":
			_draw_golden_wheat(img)
		"golden_wheat_seed":
			_draw_golden_wheat_seed(img)
		"nectar_bloom":
			_draw_nectar_bloom(img)
		"nectar_bloom_seed":
			_draw_nectar_bloom_seed(img)
		"soulberry_pie":
			_draw_soulberry_pie(img)
		"golden_hay_bale":
			_draw_golden_hay_bale(img)
		"nectar_brew":
			_draw_nectar_brew(img)
		"essence_of_inconstance":
			_draw_essence_of_inconstance(img)
		"wardens_core":
			_draw_wardens_core(img)
		"stags_essence":
			_draw_stags_essence(img)
		"wyrms_petal":
			_draw_wyrms_petal(img)
		"soul_of_inconstance":
			_draw_soul_of_inconstance(img)
		"evergrowth_seed":
			_draw_evergrowth_seed(img)
		"everbloom_seed":
			_draw_everbloom_seed(img)
		"everbloom_flower":
			_draw_everbloom_flower(img)
		"mythril_ingot":
			_draw_mythril_ingot(img)
		"herbal_tea":
			_draw_herbal_tea(img, color)
		"growth_tea":
			_draw_herbal_tea(img, color)
		"evergrowth_berry":
			_draw_evergrowth_berry(img)
		"windmill_kit":
			_draw_icon_windmill(img, _item_color_for("misc", "windmill_kit"))
		"well_kit":
			_draw_icon_well(img, _item_color_for("misc", "well_kit"))
		# --- Bakery items ---
		"bread":
			_draw_bread(img, Color(0.85, 0.6, 0.3))
		"baguette":
			_draw_baguette(img, Color(0.8, 0.55, 0.25))
		"croissant":
			_draw_croissant(img, Color(0.82, 0.58, 0.28))
		"cinnamon_roll":
			_draw_cinnamon_roll(img, Color(0.7, 0.4, 0.2))
		"fruit_tart":
			_draw_fruit_tart(img, Color(0.8, 0.55, 0.25))
		"dough":
			_draw_dough(img, Color(0.9, 0.8, 0.65))
		# --- Baked meal items ---
		"fresh_bread":
			_draw_bread(img, Color(0.85, 0.6, 0.3))
		"buttered_bread":
			_draw_bread(img, Color(0.9, 0.7, 0.5))
		"cinnamon_toast":
			_draw_cinnamon_roll(img, Color(0.8, 0.55, 0.3))
		"fruit_tart_bake":
			_draw_fruit_tart(img, Color(0.8, 0.55, 0.25))
		"chocolate_croissant":
			_draw_croissant(img, Color(0.55, 0.3, 0.15))
		_:
			# Everything else gets a category-themed simple shape
			_draw_category_shape(img, color, category)
	
	return ImageTexture.create_from_image(img)


# ---------------------------------------------------------------------------
# Item-specific icon drawing helpers
# ---------------------------------------------------------------------------

## Venison — irregular meat cut with white marbling streaks
static func _draw_meat(img: Image, color: Color) -> void:
	for y in range(16):
		for x in range(16):
			var px := float(x) - 7.5
			var py := float(y) - 7.5
			# Irregular oval: vary radius by angle
			var ang := atan2(py, px)
			var r := 5.5 + 1.5 * absf(sin(ang * 1.3 + 0.7))
			if px*px + py*py <= r * r:
				# Base meat colour
				var shade := 1.0
				var dist := sqrt(px*px + py*py)
				if dist > 3.0:
					shade = 1.0 - (dist - 3.0) / 4.0 * 0.2
				# Marbling (white streaks)
				var marb := sin(px * 2.3 + py * 1.7) * cos(py * 2.1 - px * 1.3)
				if marb > 0.6:
					img.set_pixel(x, y, Color(0.95, 0.9, 0.85, 1.0))
				elif marb < -0.7:
					# Darker meat areas
					img.set_pixel(x, y, Color(color.r * shade * 0.85, color.g * shade * 0.7, color.b * shade * 0.6, 1.0))
				else:
					img.set_pixel(x, y, Color(color.r * shade, color.g * shade * 0.85, color.b * shade * 0.7, 1.0))
	# Edge darkening
	for y in range(16):
		for x in range(16):
			var px := float(x) - 7.5
			var py := float(y) - 7.5
			var ang := atan2(py, px)
			var r := 5.5 + 1.5 * absf(sin(ang * 1.3 + 0.7))
			var dist := sqrt(px*px + py*py)
			if dist > r - 1.0 and dist <= r:
				var p := img.get_pixel(x, y)
				if p.a > 0:
					img.set_pixel(x, y, Color(p.r * 0.6, p.g * 0.5, p.b * 0.45, 1.0))

## Wood — log cross-section with rings
static func _draw_log(img: Image, color: Color) -> void:
	for y in range(16):
		for x in range(16):
			var px := float(x) - 7.5
			var py := float(y) - 7.5
			var dist := sqrt(px*px + py*py)
			if dist <= 6.5:
				var ring := int(dist * 1.8) % 3
				var shade := 1.0
				if ring == 0:
					shade = 0.7  # darker ring
				var p := Color(color.r * shade, color.g * shade, color.b * shade * 0.9, 1.0)
				# Slight grain variation
				var grain := sin(px * 4.0 + py * 3.0) * 0.05
				img.set_pixel(x, y, Color(
					clampf(p.r + grain, 0, 1),
					clampf(p.g + grain, 0, 1),
					clampf(p.b + grain * 0.5, 0, 1), 1.0))

## Stone — irregular gray polygon with speckles
static func _draw_rock(img: Image, color: Color) -> void:
	for y in range(16):
		for x in range(16):
			var px := float(x) - 7.5
			var py := float(y) - 7.5
			var ang := atan2(py, px)
			# Irregular rock shape
			var rock_r := 5.5 + 1.2 * sin(ang * 3.0 + 0.5) + 0.8 * sin(ang * 5.0 + 2.0)
			if sqrt(px*px + py*py) <= rock_r:
				var noise := sin(x * 7.0 + y * 5.0) * 0.08
				img.set_pixel(x, y, Color(
					clampf(color.r + noise, 0, 1),
					clampf(color.g + noise, 0, 1),
					clampf(color.b + noise, 0, 1), 1.0))

## Egg — oval with yolk highlight
static func _draw_egg(img: Image, color: Color) -> void:
	for y in range(16):
		for x in range(16):
			var px := float(x) - 7.5
			var py := float(y) - 7.5
			# Egg shape (wider at bottom)
			var eg := (px*px) / 9.0 + ((py+0.5)*(py+0.5)) / 11.0
			if eg <= 1.0:
				img.set_pixel(x, y, Color(
					color.r + 0.05, color.g + 0.05, color.b + 0.05, 1.0))
			# Yolk shadow
			if (px-1.5)*(px-1.5) + (py+1.0)*(py+1.0) <= 4.0:
				img.set_pixel(x, y, Color(0.9, 0.7, 0.2, 1.0))

## Berries — cluster of small circles
static func _draw_berries(img: Image, color: Color) -> void:
	var berry_positions: Array[Vector2] = [Vector2(6,5), Vector2(9,6), Vector2(5,8), Vector2(8,9)]
	for bp: Vector2 in berry_positions:
		for y in range(16):
			for x in range(16):
				var dx: float = float(x) - bp.x
				var dy: float = float(y) - bp.y
				if dx*dx + dy*dy <= 3.5:
					var shade: float = 1.0
					if dx*dx + dy*dy > 2.0:
						shade = 0.75
					img.set_pixel(x, y, Color(color.r * shade, color.g * shade, color.b * shade, 1.0))
		# Tiny highlight on each berry
		for dy2 in range(-1, 2):
			for dx2 in range(-1, 2):
				var hx: int = int(bp.x) - 1 + dx2
				var hy: int = int(bp.y) - 1 + dy2
				if hx >= 0 and hx < 16 and hy >= 0 and hy < 16:
					var p := img.get_pixel(hx, hy)
					if p.a > 0:
						img.set_pixel(hx, hy, Color(minf(p.r+0.3,1), minf(p.g+0.3,1), minf(p.b+0.3,1), 1))

## Milk — white circle with wave detail
static func _draw_milk(img: Image, color: Color) -> void:
	for y in range(16):
		for x in range(16):
			var px := float(x) - 7.5
			var py := float(y) - 7.5
			if px*px + py*py <= 42.0:
				var wave := sin(px * 0.8 + py * 1.2) * 0.03
				img.set_pixel(x, y, Color(
					clampf(color.r + wave, 0, 1),
					clampf(color.g + wave, 0, 1),
					clampf(color.b + wave + 0.02, 0, 1), 1.0))

## Feather — elongated feather shape
static func _draw_feather(img: Image, color: Color) -> void:
	for y in range(16):
		for x in range(16):
			var px := float(x) - 7.5
			var py := float(y) - 7.5
			var t := py / 8.0
			var fw := 2.0 + 4.0 * (1.0 - absf(t))
			if absf(px) <= fw and absf(t) <= 1.0:
				var shade := 1.0 - absf(t) * 0.15
				# Quill line
				if absf(px) <= 0.5:
					shade = 0.6
				img.set_pixel(x, y, Color(
					color.r * shade, color.g * shade, color.b * shade, 1.0))

## Leather — tanned hide with texture
static func _draw_leather(img: Image, color: Color) -> void:
	for y in range(16):
		for x in range(16):
			var px := float(x) - 7.5
			var py := float(y) - 7.5
			if absf(px) <= 6.0 and absf(py) <= 6.0:
				var tex := sin(x * 3.0 + y * 5.0) * 0.06 + cos(x * 7.0 - y * 4.0) * 0.04
				img.set_pixel(x, y, Color(
					clampf(color.r + tex, 0, 1),
					clampf(color.g + tex * 0.8, 0, 1),
					clampf(color.b + tex * 0.5, 0, 1), 1.0))

## Fur — furry rectangle with noise
static func _draw_fur(img: Image, color: Color) -> void:
	for y in range(16):
		for x in range(16):
			var px := float(x) - 7.5
			var py := float(y) - 7.5
			if absf(px) <= 6.0 and absf(py) <= 6.0:
				var tex := sin(x * 2.0 + y * 3.0) * 0.1 + cos(x * 5.0 - y * 7.0) * 0.06
				img.set_pixel(x, y, Color(
					clampf(color.r + tex, 0, 1),
					clampf(color.g + tex * 1.1, 0, 1),
					clampf(color.b + tex * 0.9, 0, 1), 1.0))
	# Fuzzy edge tufts
	for ang_i in range(8):
		var ang := ang_i * PI / 4.0
		var tx := 7.5 + cos(ang) * 6.5
		var ty := 7.5 + sin(ang) * 6.5
		var ix := int(tx)
		var iy := int(ty)
		if ix >= 0 and ix < 16 and iy >= 0 and iy < 16:
			img.set_pixel(ix, iy, Color(color.r * 0.8, color.g * 0.8, color.b * 0.8, 0.7))

## Wool — fluffy cloud-like shape
static func _draw_wool(img: Image, color: Color) -> void:
	for y in range(16):
		for x in range(16):
			var px := float(x) - 7.5
			var py := float(y) - 7.5
			var d := sqrt(px*px + py*py)
			# Bumpy cloud-like shape
			var bump_r := 5.5 + 1.5 * sin(atan2(py, px) * 3.0 + 1.2) * 0.5
			if d <= bump_r:
				var shade := 1.0 - d / 8.0 * 0.15
				img.set_pixel(x, y, Color(
					color.r * shade, color.g * shade, color.b * shade, 1.0))

## Iron ore — dark irregular with shiny specks
static func _draw_iron_ore(img: Image, _color: Color) -> void:
	var dark := Color(0.35, 0.3, 0.4, 1.0)
	for y in range(16):
		for x in range(16):
			var px := float(x) - 7.5
			var py := float(y) - 7.5
			var ang := atan2(py, px)
			var rock_r := 5.0 + 1.8 * sin(ang * 2.7 + 0.8)
			if sqrt(px*px + py*py) <= rock_r:
				var p := dark
				# Shiny specks (ore bits)
				if sin(x * 11.0 + y * 7.0) > 0.85:
					p = Color(0.7, 0.65, 0.8, 1.0)
				img.set_pixel(x, y, p)

## Iron ingot — silver bar
static func _draw_iron_ingot(img: Image, color: Color) -> void:
	for y in range(16):
		for x in range(16):
			var px := float(x) - 7.5
			var py := float(y) - 7.5
			# Slightly tapered bar shape
			var half_w := 5.0 - absf(py) * 0.2
			if absf(px) <= half_w and absf(py) <= 6.0:
				var shade := 1.0
				# Metallic sheen
				if int(x + y) % 4 == 0:
					shade = 0.8
				img.set_pixel(x, y, Color(
					color.r * shade, color.g * shade, color.b * shade, 1.0))

## Pickaxe — diagonal handle with curved/claw head
static func _draw_pickaxe(img: Image, color: Color) -> void:
	# Handle color (darker, wood-ish tint derived from main color)
	var handle_color := Color(
		color.r * 0.5 + 0.15,
		color.g * 0.4 + 0.1,
		color.b * 0.3 + 0.05,
		1.0
	)
	
	for y in range(16):
		for x in range(16):
			var px := float(x) - 7.5
			var py := float(y) - 7.5
			
			# Calculate distance from diagonal line (handle axis)
			# Handle goes from bottom-left to center-right
			var d_handle := absf(px - py - 1.0) / sqrt(2.0)
			
			# Progress along handle
			var hx: float = (px + py + 1.0) / sqrt(2.0)
			var on_handle := d_handle <= 1.4 and hx >= -4.5 and hx <= 5.0
			
			# Pick head - curved claw shape
			# Center of arc at roughly (2.5, -1.5) relative to center
			var acx := px - 2.5
			var acy := py + 1.5
			var arc_dist := sqrt(acx * acx + acy * acy)
			var arc_ang := atan2(acy, acx)
			
			# Outer arc (back of the pick head)
			var on_outer_arc := arc_dist >= 3.5 and arc_dist <= 5.0 and arc_ang >= -2.4 and arc_ang <= 0.3
			
			# Inner arc (front/hollow of the head)
			var on_inner_arc := arc_dist >= 1.5 and arc_dist <= 3.0 and arc_ang >= -2.2 and arc_ang <= 0.0
			
			# Tip at the left end
			var tx := px + 5.0
			var ty := py - 1.0
			var tip_dist := sqrt(tx * tx + ty * ty)
			var on_tip := tip_dist <= 1.7 and tx <= 1.5
			
			# Bottom connector (lower curve joining head to handle)
			var bx := px - 0.5
			var by := py + 5.0
			var b_dist := sqrt(bx * bx + by * by)
			var on_bottom := b_dist >= 1.0 and b_dist <= 3.2 and arc_ang >= -1.8 and arc_ang <= 0.8
			
			# Solid fill between inner and outer arc (north-west of handle connection)
			var in_fill := false
			var fill_cx := px - 1.5
			var fill_cy := py + 1.0
			var fill_dist := sqrt(fill_cx * fill_cx + fill_cy * fill_cy)
			if fill_dist <= 5.5 and fill_dist >= 3.2 and arc_ang >= -2.4 and arc_ang <= -0.1:
				in_fill = true
			# Additional fill area connecting head to handle
			if px >= -1.0 and px <= 2.0 and py >= 1.0 and py <= 4.0:
				# Fill the connection region (between handle and head)
				var conn_dist := sqrt((px - 0.0) * (px - 0.0) + (py - 1.5) * (py - 1.5))
				if conn_dist <= 4.0 and not on_handle:
					# Check not in the hollow
					if not (on_inner_arc and arc_dist <= 2.5):
						in_fill = true
			
			if on_handle:
				var shade := 1.0
				if d_handle > 1.0:
					shade = 0.75
				img.set_pixel(x, y, Color(
					handle_color.r * shade,
					handle_color.g * shade,
					handle_color.b * shade, 1.0))
			
			elif on_outer_arc or on_tip or on_bottom:
				var shade := 1.0
				if on_outer_arc and arc_dist > 4.5:
					shade = 0.7
				elif on_tip:
					shade = 1.15
				elif on_bottom:
					shade = 0.8
				var speckle := sin(x * 5.3 + y * 7.1) * 0.06
				img.set_pixel(x, y, Color(
					clampf(color.r * shade + speckle, 0, 1),
					clampf(color.g * shade + speckle, 0, 1),
					clampf(color.b * shade + speckle, 0, 1), 1.0))
			
			elif in_fill:
				var speckle := sin(x * 5.3 + y * 7.1) * 0.05
				img.set_pixel(x, y, Color(
					clampf(color.r * 0.85 + speckle, 0, 1),
					clampf(color.g * 0.85 + speckle, 0, 1),
					clampf(color.b * 0.85 + speckle, 0, 1), 1.0))


## Flower — simple four-petal shape
static func _draw_flower(img: Image, color: Color) -> void:
	var center := Vector2(7.5, 7.5)
	for y in range(16):
		for x in range(16):
			var px := float(x) - center.x
			var py := float(y) - center.y
			var ang := atan2(py, px)
			var d := sqrt(px*px + py*py)
			# Petal shape: four lobes
			var petal_r := 2.5 + 3.5 * absf(cos(ang * 2.0))  # 4 petals
			if d <= petal_r and d > 0.5:
				var shade := 1.0 - d / 7.0 * 0.3
				img.set_pixel(x, y, Color(
					color.r * shade, color.g * shade, color.b * shade, 1.0))
	# Center dot
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var cx := 7 + dx
			var cy := 7 + dy
			if cx >= 0 and cx < 16 and cy >= 0 and cy < 16:
				img.set_pixel(cx, cy, Color(0.9, 0.8, 0.2, 1.0))

## Mushroom — cap on stem
static func _draw_mushroom(img: Image, color: Color) -> void:
	for y in range(16):
		for x in range(16):
			var px := float(x) - 7.5
			var py := float(y) - 7.5
			# Cap (dome shape, top half)
			if py <= 1.0 and px*px + (py+1.0)*(py+1.0) <= 16.0:
				img.set_pixel(x, y, Color(color.r * 0.9, color.g * 0.85, color.b * 0.8, 1.0))
			# Stem (rectangle, bottom half)
			if py > 1.0 and absf(px) <= 2.0 and py <= 6.0:
				var shade := 1.0 - (py - 1.0) / 5.0 * 0.2
				img.set_pixel(x, y, Color(0.8 * shade, 0.7 * shade, 0.6 * shade, 1.0))

## Antlers — branched shape (bone-colored)
static func _draw_antlers(img: Image, color: Color) -> void:
	for y in range(16):
		for x in range(16):
			var px := float(x) - 7.5
			var py := float(y) - 7.5
			# Main branch (diagonal)
			if absf(px - py * 0.7) <= 1.0 and py <= 5.0 and py >= -5.0:
				img.set_pixel(x, y, Color(color.r, color.g, color.b, 1.0))
			# Side branch 1
			if absf(px - 3.0 - py * 0.5) <= 0.8 and py <= 3.0 and py >= -2.0:
				img.set_pixel(x, y, Color(color.r * 0.9, color.g * 0.9, color.b * 0.9, 1.0))
			# Side branch 2 (point tines)
			if absf(px + 1.0 - py * 0.3) <= 0.6 and py <= 1.0 and py >= -4.0:
				img.set_pixel(x, y, Color(color.r * 0.95, color.g * 0.95, color.b * 0.95, 1.0))

## Shell — green turtle shell dome with scute pattern
static func _draw_shell(img: Image, color: Color) -> void:
	var c_mid := Color(color.r, color.g, color.b, 1.0)                       # main
	var c_light := Color(color.r * 1.2, color.g * 1.2, color.b * 1.2, 1.0) # highlight
	var c_line := Color(color.r * 0.5, color.g * 0.5, color.b * 0.5, 1.0)   # scute lines
	var c_rim := Color(color.r * 0.85, color.g * 0.85, color.b * 0.85, 1.0) # rim

	for y in range(16):
		for x in range(16):
			var px := float(x) - 7.5
			var py := float(y) - 7.5
			var d := sqrt(px*px + py*py)

			# Outer shell — domed oval (slightly wider than tall)
			var in_shell := (px*px) / 25.0 + (py*py) / 20.0 <= 1.0

			if not in_shell:
				continue

			# Flat bottom edge (turtle shell is flat on the bottom)
			var in_bottom_rim := py > 3.0 and absf(px) <= 4.0

			# Rim band — lighter ring around edge
			var in_rim := d >= 3.8 and in_shell

			# Center hex scute pattern — a central hexagon with lines
			var in_center := absf(px) <= 2.5 and py >= -4.0 and py <= 2.0
			var in_center_hex := absf(px) * 1.2 + absf(py + 1.0) * 0.8 <= 4.0

			# Left scute (reserved for future scute shading)
			var _in_left_scute := px < -2.0 and px >= -5.0 and absf(py + 0.5) <= 2.5

			# Right scute (reserved for future scute shading)
			var _in_right_scute := px > 2.0 and px <= 5.0 and absf(py + 0.5) <= 2.5

			# Scute dividing lines — thin darker lines between plates
			var is_scute_line := false
			if in_center_hex and in_center:
				# Border of center hex
				if absf(px) >= 2.0 or absf(py + 1.0) >= 2.8:
					if absf(px) * 1.2 + absf(py + 1.0) * 0.8 >= 3.5:
						is_scute_line = true

			# Vertical center line
			if absf(px) <= 0.8 and py >= -4.0 and py <= 3.0:
				is_scute_line = true

			# Horizontal dividing line across middle
			if absf(py + 0.5) <= 0.6 and absf(px) <= 5.5:
				is_scute_line = true

			# Diagonal scute lines for side plates
			var in_left_diag := px < -1.0 and absf(py - px * 0.4 + 0.5) <= 0.6 and py >= -3.0 and py <= 2.0
			var in_right_diag := px > 1.0 and absf(py + px * 0.4 + 0.5) <= 0.6 and py >= -3.0 and py <= 2.0
			if in_left_diag or in_right_diag:
				is_scute_line = true

			# Top highlight
			var is_highlight := py <= -3.5 and absf(px) <= 1.5 and d >= 3.0

			# Determine pixel color
			if is_scute_line:
				img.set_pixel(x, y, c_line)
			elif in_bottom_rim:
				img.set_pixel(x, y, c_rim)
			elif in_rim:
				img.set_pixel(x, y, c_rim)
			elif is_highlight:
				img.set_pixel(x, y, c_light)
			elif in_center_hex:
				img.set_pixel(x, y, c_mid)
			else:
				# Edge gradient — darker toward rim
				var edge_dist := minf(d / 4.5, 1.0)
				var edge_color := Color(
					c_mid.r * (0.7 + 0.3 * edge_dist),
					c_mid.g * (0.7 + 0.3 * edge_dist),
					c_mid.b * (0.7 + 0.3 * edge_dist),
					1.0
				)
				img.set_pixel(x, y, edge_color)

## Nut — small oval with darker line
static func _draw_nut(img: Image, color: Color) -> void:
	for y in range(16):
		for x in range(16):
			var px := float(x) - 7.5
			var py := float(y) - 7.5
			# Slightly elongated oval
			var el := (px*px) / 8.0 + (py*py) / 10.0
			if el <= 1.0:
				var shade := 1.0
				# Center line (nut cleft)
				if absf(px) <= 0.5:
					shade = 0.5
				img.set_pixel(x, y, Color(
					color.r * shade, color.g * shade * 0.9, color.b * shade * 0.8, 1.0))

## Truffle — dark lumpy shape
static func _draw_truffle(img: Image, color: Color) -> void:
	for y in range(16):
		for x in range(16):
			var px := float(x) - 7.5
			var py := float(y) - 7.5
			var d := sqrt(px*px + py*py)
			# Lumpy shape
			var lump_r := 4.5 + sin(px * 1.5 + py * 1.2) * 1.0
			if d <= lump_r:
				var tex := sin(x * 8.0 + y * 6.0) * 0.05
				img.set_pixel(x, y, Color(
					clampf(color.r + tex, 0, 1),
					clampf(color.g + tex, 0, 1),
					clampf(color.b + tex, 0, 1), 1.0))

## Wooden planks — rectangle with grain lines
static func _draw_planks(img: Image, color: Color) -> void:
	for y in range(16):
		for x in range(16):
			var px := float(x) - 7.5
			var py := float(y) - 7.5
			if absf(px) <= 6.0 and absf(py) <= 6.0:
				var shade := 1.0
				# Plank line
				if absf(py) <= 0.5:
					shade = 0.7
				# Grain
				var grain := sin(px * 2.0 + py * 0.5) * 0.06
				img.set_pixel(x, y, Color(
					clampf(color.r * shade + grain, 0, 1),
					clampf(color.g * shade + grain * 0.5, 0, 1),
					clampf(color.b * shade, 0, 1), 1.0))

## Fence log — horizontal log with rings
static func _draw_fence_log(img: Image, color: Color) -> void:
	_draw_log(img, color)
	# Cross it with a vertical bar
	for y in range(2, 14):
		for x in range(2, 4):
			var p := img.get_pixel(x, y)
			if p.a > 0:
				img.set_pixel(x, y, Color(
					color.r * 0.7, color.g * 0.7, color.b * 0.65, 1.0))

## Fallback: category-themed simple shape
static func _draw_category_shape(img: Image, color: Color, category: String) -> void:
	var shape_max: float
	match category:
		"tool":          shape_max = 7.0
		"food", "meal":  shape_max = 6.5
		"resource":      shape_max = 6.0
		_:               shape_max = 6.5
	
	for y in range(16):
		for x in range(16):
			var px := float(x) - 7.5
			var py := float(y) - 7.5
			var inside := false
			match category:
				"tool":     inside = (absf(px) + absf(py)) <= shape_max
				"food", "meal":    inside = (px*px + py*py) <= shape_max * shape_max
				"resource": inside = absf(px) <= shape_max and absf(py) <= shape_max
			if not inside:
				continue
			var shade := 1.0
			var dist := sqrt(px*px + py*py)
			if dist > shape_max * 0.5:
				shade = 1.0 - (dist - shape_max * 0.5) / (shape_max * 0.5) * 0.25
			if absf(px) >= shape_max - 1.0 or absf(py) >= shape_max - 1.0:
				shade *= 0.55
			img.set_pixel(x, y, Color(color.r * shade, color.g * shade, color.b * shade, 1.0))
	# Small highlight
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var hx := 5 + dx
			var hy := 4 + dy
			if hx >= 0 and hx < 16 and hy >= 0 and hy < 16:
				var p := img.get_pixel(hx, hy)
				if p.a > 0:
					img.set_pixel(hx, hy, Color(
						minf(p.r + 0.25, 1.0), minf(p.g + 0.25, 1.0), minf(p.b + 0.25, 1.0), p.a))


# ---------------------------------------------------------------------------
# Spirit Harvest item icon helpers
# ---------------------------------------------------------------------------

static func _draw_soulberry(img: Image) -> void:
	# Glowing purple berry
	for y in range(16):
		for x in range(16):
			var px := float(x) - 7.5
			var py := float(y) - 7.5
			if px*px + py*py <= 16.0:
				img.set_pixel(x, y, Color(0.55, 0.2, 0.7, 1.0))
			# Outer glow
			if px*px + py*py <= 25.0 and px*px + py*py > 16.0:
				var alpha := 1.0 - ((px*px + py*py) - 16.0) / 9.0
				img.set_pixel(x, y, Color(0.65, 0.3, 0.8, alpha * 0.4))
			# Highlight
			if (px-1.5)*(px-1.5) + (py-1.5)*(py-1.5) <= 2.0:
				img.set_pixel(x, y, Color(0.8, 0.5, 0.9, 1.0))

static func _draw_soulberry_seed(img: Image) -> void:
	# Small purple teardrop seed
	for y in range(16):
		for x in range(16):
			var px := float(x) - 7.5
			var py := float(y) - 7.5
			# Teardrop shape
			var d := px*px + (py+1.5)*(py+1.5)
			var r := 3.5 - py * 0.3
			if d <= r * r and py <= 4.0 and py >= -4.0:
				img.set_pixel(x, y, Color(0.5, 0.2, 0.65, 1.0))
			# Tiny glow
			if d <= 6.0 and d > 3.0:
				img.set_pixel(x, y, Color(0.6, 0.3, 0.75, 0.5))

static func _draw_golden_wheat(img: Image) -> void:
	# Golden wheat stalk
	for y in range(16):
		for x in range(16):
			var px := float(x) - 7.5
			var py := float(y) - 7.5
			# Stalk
			if absf(px) <= 0.5 and py >= 1.0 and py <= 6.0:
				img.set_pixel(x, y, Color(0.7, 0.6, 0.2, 1.0))
			# Head (oval of grains)
			var gx := px * 1.2
			var gy := (py - 2.0) * 1.5
			if gx*gx + gy*gy <= 9.0:
				var shade := 1.0
				if absf(px) > 2.0:
					shade = 0.85
				img.set_pixel(x, y, Color(0.9 * shade, 0.75 * shade, 0.2 * shade, 1.0))
			# Glow at top
			if (px*px + (py-3.0)*(py-3.0)) <= 4.0:
				img.set_pixel(x, y, Color(1.0, 0.9, 0.5, 0.6))

static func _draw_golden_wheat_seed(img: Image) -> void:
	# Small golden grain
	for y in range(16):
		for x in range(16):
			var px := float(x) - 7.5
			var py := float(y) - 7.5
			var el := (px*px) / 3.0 + (py*py) / 5.0
			if el <= 1.0:
				img.set_pixel(x, y, Color(0.85, 0.7, 0.25, 1.0))
			if el <= 2.0 and el > 1.0:
				img.set_pixel(x, y, Color(0.9, 0.8, 0.4, 0.4))

static func _draw_nectar_bloom(img: Image) -> void:
	# Pink flower with nectar drop
	for y in range(16):
		for x in range(16):
			var px := float(x) - 7.5
			var py := float(y) - 7.5
			var ang := atan2(py, px)
			var d := sqrt(px*px + py*py)
			# 5 petals
			var petal_r := 2.0 + 3.5 * absf(cos(ang * 2.5))
			if d <= petal_r and d > 1.0:
				var shade := 1.0 - d / 7.0 * 0.25
				img.set_pixel(x, y, Color(0.85 * shade, 0.3 * shade, 0.6 * shade, 1.0))
			# Center
			if d <= 1.5:
				img.set_pixel(x, y, Color(0.95, 0.7, 0.2, 1.0))
			# Nectar drop
			if px > 1.0 and py > 1.0 and (px-2.0)*(px-2.0) + (py-2.0)*(py-2.0) <= 1.5:
				img.set_pixel(x, y, Color(0.9, 0.5, 0.2, 1.0))

static func _draw_nectar_bloom_seed(img: Image) -> void:
	# Small pink teardrop seed
	for y in range(16):
		for x in range(16):
			var px := float(x) - 7.5
			var py := float(y) - 7.5
			var d := px*px + (py+1.0)*(py+1.0)
			if d <= 5.0 and absf(py) <= 4.0 and py >= -3.0:
				img.set_pixel(x, y, Color(0.75, 0.25, 0.5, 1.0))

static func _draw_soulberry_pie(img: Image) -> void:
	# Pie with purple filling
	for y in range(16):
		for x in range(16):
			var px := float(x) - 7.5
			var py := float(y) - 7.5
			var d := sqrt(px*px + py*py)
			# Pie crust (ring)
			if d <= 6.5 and d >= 4.0:
				img.set_pixel(x, y, Color(0.7, 0.5, 0.25, 1.0))
			# Purple filling (center)
			if d <= 4.0:
				img.set_pixel(x, y, Color(0.5, 0.15, 0.65, 1.0))
			# Glow dots (soulberries)
			if (px-1.5)*(px-1.5) + (py-1.0)*(py-1.0) <= 1.5:
				img.set_pixel(x, y, Color(0.8, 0.4, 0.9, 1.0))
			if (px+1.5)*(px+1.5) + (py+1.0)*(py+1.0) <= 1.5:
				img.set_pixel(x, y, Color(0.8, 0.4, 0.9, 1.0))

static func _draw_golden_hay_bale(img: Image) -> void:
	# Rectangular bale with binding
	for y in range(16):
		for x in range(16):
			var px := float(x) - 7.5
			var py := float(y) - 7.5
			if absf(px) <= 6.0 and absf(py) <= 5.0:
				var tex := sin(x * 3.0 + y * 2.0) * 0.06
				img.set_pixel(x, y, Color(
					clampf(0.85 + tex, 0, 1),
					clampf(0.7 + tex, 0, 1),
					clampf(0.2 + tex * 0.5, 0, 1), 1.0))
			# Binding lines
			if absf(px) <= 6.0 and absf(py) <= 5.0 and (absf(px-3.0) <= 0.5 or absf(px+3.0) <= 0.5):
				img.set_pixel(x, y, Color(0.5, 0.35, 0.15, 1.0))
			# Golden glow
			if absf(px) <= 3.0 and absf(py) <= 3.0:
				var p := img.get_pixel(x, y)
				img.set_pixel(x, y, Color(minf(p.r + 0.15, 1), minf(p.g + 0.1, 1), p.b, p.a))

static func _draw_nectar_brew(img: Image) -> void:
	# Bottle with pink liquid
	for y in range(16):
		for x in range(16):
			var px := float(x) - 7.5
			var py := float(y) - 7.5
			# Bottle shape
			var bottle_w := 4.0 - absf(py) * 0.2
			if absf(px) <= bottle_w and py <= 6.0 and py >= -6.0:
				# Bottle glass (transparent)
				if py >= -4.0:
					img.set_pixel(x, y, Color(0.4, 0.2, 0.3, 0.6))
				# Pink liquid (bottom)
				if py >= 0.0 and py <= 5.0:
					img.set_pixel(x, y, Color(0.8, 0.3, 0.5, 0.8))
				# Bottle neck
				if py < -4.0 and absf(px) <= 1.5:
					img.set_pixel(x, y, Color(0.5, 0.3, 0.2, 0.7))
			# Cork
			if py <= -5.5 and absf(px) <= 1.5:
				img.set_pixel(x, y, Color(0.6, 0.45, 0.25, 1.0))

static func _draw_essence_of_inconstance(img: Image) -> void:
	# Swirling orb blending purple, gold, and pink
	for y in range(16):
		for x in range(16):
			var px := float(x) - 7.5
			var py := float(y) - 7.5
			var d := sqrt(px*px + py*py)
			if d <= 6.0:
				var ang := atan2(py, px)
				var swirl := sin(ang * 3.0 + d * 1.5) * 0.5 + 0.5
				var col := Color()
				if swirl < 0.33:
					col = Color(0.5, 0.15, 0.7)  # purple
				elif swirl < 0.66:
					col = Color(0.85, 0.7, 0.2)  # gold
				else:
					col = Color(0.8, 0.3, 0.5)  # pink
				var alpha := 1.0 - d / 7.0
				img.set_pixel(x, y, Color(col.r, col.g, col.b, alpha))
			# Outer glow
			if d <= 7.5 and d > 6.0:
				var alpha := (7.5 - d) * 0.4
				img.set_pixel(x, y, Color(0.6, 0.3, 0.6, alpha))

static func _draw_wardens_core(img: Image) -> void:
	# Pulsing purple orb with energy lines
	for y in range(16):
		for x in range(16):
			var px := float(x) - 7.5
			var py := float(y) - 7.5
			var d := sqrt(px*px + py*py)
			if d <= 5.5:
				img.set_pixel(x, y, Color(0.5, 0.15, 0.7, 1.0))
			# Energy lines
			var ang := atan2(py, px)
			for i in range(4):
				var line_ang := float(i) * PI / 2.0
				if absf(ang - line_ang) < 0.2 and d <= 7.0 and d > 5.0:
					img.set_pixel(x, y, Color(0.7, 0.3, 0.85, 0.7))
			if d <= 2.0:
				img.set_pixel(x, y, Color(0.85, 0.5, 0.95, 1.0))

static func _draw_stags_essence(img: Image) -> void:
	# Golden glowing wisp
	for y in range(16):
		for x in range(16):
			var px := float(x) - 7.5
			var py := float(y) - 7.5
			var d := sqrt(px*px + py*py)
			if d <= 4.0:
				img.set_pixel(x, y, Color(0.9, 0.75, 0.25, 1.0))
			if d <= 6.0 and d > 4.0:
				var alpha := (6.0 - d) / 2.0 * 0.6
				img.set_pixel(x, y, Color(0.95, 0.85, 0.4, alpha))
			# Sparkle (antler shape)
			if absf(px) <= 0.5 and py <= -3.0 and py >= -6.0:
				img.set_pixel(x, y, Color(1.0, 0.9, 0.5, (py + 6.0) / 3.0))
			if absf(px - py * 0.5) <= 0.5 and py <= -3.0 and py >= -5.0:
				img.set_pixel(x+1, y, Color(1.0, 0.9, 0.5, (py + 5.0) / 2.0))

static func _draw_wyrms_petal(img: Image) -> void:
	# Shimmering pink petal
	for y in range(16):
		for x in range(16):
			var px := float(x) - 7.5
			var py := float(y) - 7.5
			# Petal shape (pointed oval)
			var el := (px*px) / 7.0 + (py*py) / 9.0
			if el <= 1.0:
				var shade := 1.0
				if absf(px) > 2.0:
					shade = 0.85
				img.set_pixel(x, y, Color(0.8 * shade, 0.3 * shade, 0.55 * shade, 1.0))
			# Vein lines
			if el <= 0.9 and absf(px) <= 0.5:
				img.set_pixel(x, y, Color(0.9, 0.5, 0.65, 0.8))
			# Shimmer highlight
			if el <= 1.0 and sin(x * 5.0 + y * 3.0) > 0.8:
				var p := img.get_pixel(x, y)
				img.set_pixel(x, y, Color(minf(p.r + 0.2, 1), minf(p.g + 0.15, 1), minf(p.b + 0.15, 1), p.a))

static func _draw_soul_of_inconstance(img: Image) -> void:
	# Ethereal soul orb with swirling purple/gold/pink energy
	for y in range(16):
		for x in range(16):
			var px := float(x) - 7.5
			var py := float(y) - 7.5
			var d := sqrt(px*px + py*py)
			# Circular soul orb
			if d <= 6.5:
				var ang := atan2(py, px)
				var swirl := sin(ang * 3.0 + d * 0.8) * 0.5 + 0.5
				var col: Color
				if swirl < 0.33:
					col = Color(0.5, 0.15, 0.7)  # purple
				elif swirl < 0.66:
					col = Color(0.85, 0.7, 0.2)  # gold
				else:
					col = Color(0.8, 0.3, 0.55)  # pink
				# Fade toward edges
				var alpha := 1.0 - (d / 7.0) * 0.4
				img.set_pixel(x, y, Color(col.r, col.g, col.b, alpha))
			# Outer glow
			if d <= 7.5 and d > 6.5:
				var alpha := (7.5 - d) * 0.3
				img.set_pixel(x, y, Color(1.0, 0.9, 0.7, alpha))
			# Bright core
			if d <= 2.0:
				var core_alpha := 1.0 - d / 2.0
				img.set_pixel(x, y, Color(1.0, 0.95, 0.85, core_alpha))

static func _draw_evergrowth_seed(img: Image) -> void:
	# Legendary gold-infused seed with green glow
	for y in range(16):
		for x in range(16):
			var px := float(x) - 7.5
			var py := float(y) - 7.5
			var d := px*px + (py+1.0)*(py+1.0)
			if d <= 6.0 and absf(py) <= 5.0 and py >= -4.0:
				img.set_pixel(x, y, Color(0.7, 0.6, 0.2, 1.0))
			# Green glow aura
			if d <= 10.0 and d > 6.0:
				var alpha := (10.0 - d) / 4.0 * 0.5
				img.set_pixel(x, y, Color(0.2, 0.8, 0.3, alpha))
			# Center dot
			if d <= 1.5:
				img.set_pixel(x, y, Color(0.2, 0.9, 0.4, 1.0))

static func _draw_everbloom_seed(img: Image) -> void:
	# Luminous pink-green seed
	for y in range(16):
		for x in range(16):
			var px := float(x) - 7.5
			var py := float(y) - 7.5
			var d := px*px + (py+1.0)*(py+1.0)
			if d <= 6.0 and absf(py) <= 5.0 and py >= -4.0:
				img.set_pixel(x, y, Color(0.75, 0.3, 0.55, 1.0))
			# Soft glow
			if d <= 12.0 and d > 6.0:
				var alpha := (12.0 - d) / 6.0 * 0.3
				img.set_pixel(x, y, Color(0.9, 0.5, 0.7, alpha))

static func _draw_everbloom_flower(img: Image) -> void:
	# Glowing decorative flower
	for y in range(16):
		for x in range(16):
			var px := float(x) - 7.5
			var py := float(y) - 7.5
			var ang := atan2(py, px)
			var d := sqrt(px*px + py*py)
			var petal_r := 2.0 + 4.0 * absf(cos(ang * 2.5))
			if d <= petal_r and d > 1.0:
				var shade := 1.0 - d / 7.0 * 0.2
				img.set_pixel(x, y, Color(0.85 * shade, 0.35 * shade, 0.65 * shade, 1.0))
			if d <= 1.5:
				img.set_pixel(x, y, Color(0.95, 0.75, 0.2, 1.0))
			# Glow aura
			if d <= 8.0 and d > petal_r:
				var alpha := (8.0 - d) / 8.0 * 0.25
				img.set_pixel(x, y, Color(0.9, 0.6, 0.8, alpha))

static func _draw_mythril_ingot(img: Image) -> void:
	# Shimmering silver-blue bar
	for y in range(16):
		for x in range(16):
			var px := float(x) - 7.5
			var py := float(y) - 7.5
			var half_w := 5.0 - absf(py) * 0.15
			if absf(px) <= half_w and absf(py) <= 6.0:
				var shade := 1.0
				if int(x + y) % 3 == 0:
					shade = 0.85
				img.set_pixel(x, y, Color(
					0.5 * shade, 0.55 * shade, 0.7 * shade, 1.0))
			# Blue shimmer
			if absf(px) <= half_w and absf(py) <= 6.0 and sin(x * 4.0 + y * 2.0) > 0.85:
				var p := img.get_pixel(x, y)
				img.set_pixel(x, y, Color(minf(p.r + 0.2, 1), minf(p.g + 0.2, 1), minf(p.b + 0.3, 1), p.a))

static func _draw_evergrowth_berry(img: Image) -> void:
	# Legendary infinite berry
	for y in range(16):
		for x in range(16):
			var px := float(x) - 7.5
			var py := float(y) - 7.5
			var d := px*px + py*py
			if d <= 16.0:
				img.set_pixel(x, y, Color(0.2, 0.75, 0.35, 1.0))
			# Gold highlight
			if d <= 4.0:
				img.set_pixel(x, y, Color(0.85, 0.7, 0.2, 1.0))
			# Infini-symbol hint (two tiny dots)
			if (px-3.0)*(px-3.0) + (py-3.0)*(py-3.0) <= 1.0:
				img.set_pixel(x, y, Color(0.9, 0.8, 0.3, 0.8))
			if (px+3.0)*(px+3.0) + (py+3.0)*(py+3.0) <= 1.0:
				img.set_pixel(x, y, Color(0.9, 0.8, 0.3, 0.8))


## Herbal Tea — a steaming teacup with green liquid and a small herb leaf
static func _draw_herbal_tea(img: Image, color: Color) -> void:
	var tea_color := color
	var tea_light := Color(minf(color.r * 1.3, 1.0), minf(color.g * 1.3, 1.0), minf(color.b * 1.2, 1.0))
	var _tea_dark := Color(color.r * 0.6, color.g * 0.6, color.b * 0.6)
	var cup_color := Color(0.8, 0.75, 0.7)
	var cup_light := Color(0.9, 0.85, 0.8)
	var cup_dark := Color(0.6, 0.55, 0.5)
	var steam_color := Color(0.85, 0.85, 0.85, 0.6)
	var leaf_color := Color(0.2, 0.55, 0.2)

	for y in range(16):
		for x in range(16):
			var px := float(x) - 7.5
			var py := float(y) - 7.5

			# Cup body — trapezoid (wider at top, narrower at bottom)
			var top_width := 5.0
			var bottom_width := 4.0
			var cup_top := -3.0
			var cup_bottom := 4.0
			var t := (py - cup_top) / (cup_bottom - cup_top)
			var half_w := lerpf(top_width, bottom_width, t)
			var in_cup := py >= cup_top and py <= cup_bottom and absf(px) <= half_w

			# Handle — small C-shape on the right side
			var in_handle := false
			var hx := px - half_w - 0.5
			var hy := py + 1.0  # center handle at y=-1
			if hx >= 0 and hx <= 2.0 and hy >= -2.0 and hy <= 2.0:
				var hd := sqrt(hx*hx + hy*hy)
				if hd >= 1.0 and hd <= 2.5:
					in_handle = true

			if not in_cup and not in_handle:
				continue

			# Determine pixel
			if in_handle:
				img.set_pixel(x, y, cup_light)
				continue

			# Cup wall thickness
			var wall_thick := 1.0
			var is_wall := absf(px) >= half_w - wall_thick or py >= cup_bottom - wall_thick

			# Rim
			var is_rim := py >= cup_top - 0.5 and py <= cup_top and absf(px) <= half_w + 0.2

			if is_rim:
				img.set_pixel(x, y, cup_light)
			elif is_wall:
				# Cup wall with slight shading
				if py >= cup_bottom - 0.8:
					img.set_pixel(x, y, cup_dark)
				elif absf(px) >= half_w - 0.5:
					img.set_pixel(x, y, cup_light)
				else:
					img.set_pixel(x, y, cup_color)
			else:
				# Tea liquid — green herbal tea
				if absf(px) <= half_w - 1.0 and py > cup_top and py < cup_bottom - 0.5:
					# Tea surface highlight
					if py <= cup_top + 0.8:
						img.set_pixel(x, y, tea_light)
					else:
						var depth := (py - cup_top) / (cup_bottom - cup_top)
						var darken := 1.0 - depth * 0.2
						img.set_pixel(x, y, Color(tea_color.r * darken, tea_color.g * darken, tea_color.b * darken, 1.0))

	# Draw a small herb leaf floating on the tea surface
	var leaf_pixels := [
		[5, 10], [6, 9], [6, 10], [7, 9], [7, 10], [8, 10]
	]
	for lp in leaf_pixels:
		img.set_pixel(lp[0], lp[1], leaf_color)

	# Steam wisps rising above the cup
	var steam_pixels := [
		# Left steam wisp
		[6, 3], [5, 2], [6, 1],
		# Right steam wisp
		[9, 3], [10, 2], [9, 1],
	]
	for sp in steam_pixels:
		var p := img.get_pixel(sp[0], sp[1])
		if p.a <= 0:
			img.set_pixel(sp[0], sp[1], steam_color)


## 16×16 icon for a windmill — tapered cream tower, dark cone roof, and cross blades.
static func _draw_icon_windmill(img: Image, color: Color) -> void:
	var roof := Color(0.35, 0.25, 0.2)
	var blades := Color(0.5, 0.35, 0.2)
	# Tapered tower body (wider at base, narrower at top)
	for y in range(6, 14):
		var half_w: int = 2 if y < 9 else 3
		for x in range(8 - half_w, 8 + half_w + 1):
			img.set_pixel(x, y, color)
	# Cone roof
	for y in range(4, 6):
		var half_w: int = 0 if y == 4 else 2
		for x in range(8 - half_w, 8 + half_w + 1):
			img.set_pixel(x, y, roof)
	# Blade cross on top
	for dx in range(-3, 4):
		img.set_pixel(8 + dx, 3, blades)        # horizontal blade
		img.set_pixel(8, 3 + dx, blades)         # vertical blade
	# Center hub
	img.set_pixel(8, 2, blades)
	img.set_pixel(8, 3, Color(0.6, 0.5, 0.35))
	# Base line
	for x in range(5, 12):
		img.set_pixel(x, 14, roof)


## 16×16 icon for a well — stone pillars, crossbeam, and peaked roof.
static func _draw_icon_well(img: Image, color: Color) -> void:
	var roof := Color(0.35, 0.25, 0.2)
	var rope := Color(0.4, 0.3, 0.2)
	# Stone pillars (left and right)
	for y in range(5, 13):
		img.set_pixel(4, y, color)
		img.set_pixel(5, y, color)
		img.set_pixel(10, y, color)
		img.set_pixel(11, y, color)
	# Stone ring (horizontal bands between pillars)
	for x in range(5, 11):
		img.set_pixel(x, 7, color)
		img.set_pixel(x, 11, color)
	# Dark center (the well hole)
	for y in range(8, 11):
		for x in range(6, 10):
			img.set_pixel(x, y, Color(0.2, 0.2, 0.2))
	# Crossbeam on top
	for x in range(4, 12):
		img.set_pixel(x, 4, roof)
	# Peaked roof
	img.set_pixel(6, 2, roof)
	img.set_pixel(7, 2, roof)
	img.set_pixel(8, 2, roof)
	img.set_pixel(9, 2, roof)
	for x in range(5, 10):
		img.set_pixel(x, 3, roof)
	img.set_pixel(7, 1, roof)
	img.set_pixel(8, 1, roof)
	# Rope/bucket hint
	img.set_pixel(7, 5, rope)
	img.set_pixel(8, 5, rope)
	img.set_pixel(7, 6, rope)
	img.set_pixel(8, 6, rope)


## Fully unique procedural icon for procedurally-generated items (crops, hybrids).
## Uses the item_id hash to deterministically pick shape, pattern, symbol and border.
static func _make_procedural_icon(base_color: Color, item_id: String) -> Texture2D:
	var seed_val := hash(item_id)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val & 0x7FFFFFFF
	
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	
	var shape: int = rng.randi() % 6
	var pattern: int = rng.randi() % 6
	var symbol: int = rng.randi() % 6
	var border: int = rng.randi() % 3
	
	var accent := Color(
		clampf(base_color.r * 1.3, 0, 1),
		clampf(base_color.g * 0.7, 0, 1),
		clampf(base_color.b * 1.5, 0, 1),
		1.0
	)
	
	for y in range(16):
		for x in range(16):
			var inside: bool = false
			var px := float(x) - 7.5
			var py := float(y) - 7.5
			match shape:
				0:  inside = (px*px + py*py) <= 42.0
				1:  inside = (absf(px) + absf(py)) <= 7.0
				2:
					var hx: float = absf(px)
					var hy: float = absf(py)
					inside = (hy * 1.732 + hx * 0.5) <= 7.0 and hy <= 6.0
				3:
					var ddx: float = absf(px)
					var ddy: float = absf(py)
					var cor1: float = maxf(ddx - 4.0, ddy - 4.0)
					var corner: float = maxf(cor1, 0.0)
					inside = (ddx <= 6.5 and ddy <= 6.5) or (corner * corner * 0.8 <= 4.0)
				4:
					var rel_y: float = py + 6.0
					inside = rel_y >= 0 and rel_y <= 12.0 and absf(px) * (12.0 - rel_y) / 12.0 <= 6.5
				5:
					var rad: float = sqrt(px*px + py*py)
					var angle: float = atan2(py, px)
					var star_r: float = 6.5 * (0.7 + 0.3 * sin(angle * 4.0 + 1.5))
					inside = rad <= star_r
			
			if not inside:
				continue
			
			var col: Color
			match pattern:
				0:  col = base_color
				1:  col = base_color if (y % 3) != 0 else accent
				2:  col = base_color if (x % 3) != 0 else accent
				3:
					var check_x: int = (x / 2) % 2
					var check_y: int = (y / 2) % 2
					col = base_color if (check_x + check_y) % 2 == 0 else accent
				4:
					var ring_rad := sqrt(px*px + py*py)
					col = base_color if int(ring_rad) % 2 == 0 else Color(
						minf(base_color.r * 1.15, 1), minf(base_color.g * 1.15, 1), minf(base_color.b * 1.15, 1), 1 )
				5:
					var ang: int = int(atan2(py, px) * 4.0 / PI)
					col = base_color if absi(ang) % 2 == 0 else accent
			
			if border == 1 and (absf(px) > 5.5 or absf(py) > 5.5):
				col = Color(0.1, 0.1, 0.1, 1.0)
			elif border == 2 and (absf(px) > 4.5 or absf(py) > 4.5):
				col = Color(0.15, 0.15, 0.12, 1.0)
			
			img.set_pixel(x, y, col)
	
	# Center symbol
	var cx: int = 7
	var cy: int = 7
	match symbol:
		1:
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					img.set_pixel(cx+dx, cy+dy, Color(1, 1, 1, 0.9))
		2:
			for i in range(-2, 3):
				if cx+i >= 0 and cx+i < 16: img.set_pixel(cx+i, cy+i, Color(1, 1, 1, 0.85))
				if cx-i >= 0 and cx-i < 16: img.set_pixel(cx-i, cy+i, Color(1, 1, 1, 0.85))
		3:
			for i in range(-2, 3):
				if cx+i >= 0 and cx+i < 16: img.set_pixel(cx+i, cy, Color(1, 1, 1, 0.85))
				if cy+i >= 0 and cy+i < 16: img.set_pixel(cx, cy+i, Color(1, 1, 1, 0.85))
		4:
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					if dx == 0 and dy == 0: continue
					if cx+dx < 0 or cx+dx >= 16 or cy+dy < 0 or cy+dy >= 16: continue
					if sqrt(float(dx*dx + dy*dy)) <= 2.0 and sqrt(float(dx*dx + dy*dy)) > 0.5:
						img.set_pixel(cx+dx, cy+dy, Color(1, 1, 1, 0.8))
		5:
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					if absi(dx) + absi(dy) <= 2 and (dx != 0 or dy != 0):
						if cx+dx >= 0 and cx+dx < 16 and cy+dy >= 0 and cy+dy < 16:
							img.set_pixel(cx+dx, cy+dy, Color(1, 1, 1, 0.85))
	
	return ImageTexture.create_from_image(img)


# ── Island Biome Icon Drawers ──

static func _draw_ice_crystal(img: Image, color: Color) -> void:
	# Diamond / crystal shape — 6-sided gem
	for y in range(16):
		for x in range(16):
			var px := float(x) - 7.5
			var py := float(y) - 7.5
			# Hexagonal crystal
			var hex_r := 5.5 - absf(py) * 0.25
			if absf(px) <= hex_r and absf(py) <= 5.5:
				var shade := 1.0 - absf(py) / 6.0 * 0.2
				# Facet highlight
				if px > 0:
					shade *= 1.15
				img.set_pixel(x, y, Color(
					clampf(color.r * shade, 0, 1),
					clampf(color.g * shade, 0, 1),
					clampf(color.b * shade, 0, 1), 1.0))
	# Sparkle dots
	for i in range(3):
		var sx := 7 + int(cos(i * 2.1) * 3.5)
		var sy := 7 + int(sin(i * 2.1) * 3.5)
		if sx >= 0 and sx < 16 and sy >= 0 and sy < 16:
			img.set_pixel(sx, sy, Color(1, 1, 1, 0.8))


static func _draw_snow_flower(img: Image, color: Color) -> void:
	# 6-petal snowflake/flower
	var cx: int = 7
	var cy: int = 7
	for ang_i in range(6):
		var ang := ang_i * PI / 3.0
		for r in range(1, 5):
			var sx := cx + int(cos(ang) * r)
			var sy := cy + int(sin(ang) * r)
			if sx >= 0 and sx < 16 and sy >= 0 and sy < 16:
				img.set_pixel(sx, sy, color)
	# Center dot
	img.set_pixel(cx, cy, Color(color.r * 1.2, color.g * 1.2, color.b * 1.2, 1))


static func _draw_gumdrop(img: Image, color: Color) -> void:
	# Dome shape (flat bottom, rounded top)
	for y in range(16):
		for x in range(16):
			var px := float(x) - 7.5
			var py := float(y) - 7.5
			# Dome: wider at bottom, rounded at top
			var half_w := 5.5 - (py + 5.5) * (py + 5.5) / 12.0
			if absf(px) <= half_w and py >= -5.5 and py <= 5.5:
				var shade := 1.0 - (py + 5.5) / 12.0 * 0.3
				img.set_pixel(x, y, Color(color.r * shade, color.g * shade, color.b * shade, 1))
	# Highlight on top
	for x in range(-2, 3):
		for y in range(-2, 1):
			var sx := 7 + x
			var sy := 4 + y
			if sx >= 0 and sx < 16 and sy >= 0 and sy < 16:
				var p := img.get_pixel(sx, sy)
				if p.a > 0:
					img.set_pixel(sx, sy, Color(minf(p.r + 0.3, 1), minf(p.g + 0.3, 1), minf(p.b + 0.3, 1), 1))


static func _draw_chocolate_chunk(img: Image, color: Color) -> void:
	# Irregular square with rounded edges
	for y in range(16):
		for x in range(16):
			var px := float(x) - 7.5
			var py := float(y) - 7.5
			# Jagged square
			var jag := 0.5 * sin(px * 0.8 + py * 0.6)
			if absf(px) <= 5.0 + jag and absf(py) <= 5.0 + jag:
				var shade := 1.0
				# Slightly lighter on one side (3D effect)
				if px > 1:
					shade = 0.85
				if px < -2:
					shade = 1.1
				img.set_pixel(x, y, Color(
					clampf(color.r * shade, 0, 1),
					clampf(color.g * shade, 0, 1),
					clampf(color.b * shade, 0, 1), 1))


static func _draw_cactus_fruit(img: Image, color: Color) -> void:
	# Oval fruit shape
	for y in range(16):
		for x in range(16):
			var px := float(x) - 7.5
			var py := float(y) - 7.5
			# Slightly pointed oval
			var r := 5.0 + 1.5 * cos(atan2(py, px) * 2.0)
			if sqrt(px*px + py*py) <= r:
				var shade := 1.0
				if px < 0:
					shade = 0.8
				img.set_pixel(x, y, Color(
					color.r * shade, color.g * shade * 0.85, color.b * shade, 1))
	# Tiny seeds
	img.set_pixel(6, 7, Color(0.9, 0.8, 0.3, 0.8))
	img.set_pixel(8, 8, Color(0.9, 0.8, 0.3, 0.8))
	img.set_pixel(7, 9, Color(0.9, 0.8, 0.3, 0.8))


static func _draw_scarab(img: Image, color: Color) -> void:
	# Oval beetle body
	for y in range(16):
		for x in range(16):
			var px := float(x) - 7.5
			var py := float(y) - 7.5
			# Oval body
			if (px*px) / 20.0 + (py*py) / 14.0 <= 1.0:
				var shade := 1.0
				if py < -2:
					shade = 0.7  # head darker
				# Shell shine (center line)
				if absf(px) < 1.5:
					shade = minf(shade + 0.15, 1.0)
				img.set_pixel(x, y, Color(
					clampf(color.r * shade, 0, 1),
					clampf(color.g * shade, 0, 1),
					clampf(color.b * shade, 0, 1), 1))
	# Legs (tiny lines)
	for side_val in [-1, 1]:
		for leg in range(3):
			var lx: int = 7 + side_val * (4 + leg)
			var ly := 7 + (leg - 1) * 2
			if lx >= 0 and lx < 16 and ly >= 0 and ly < 16:
				img.set_pixel(lx, ly, Color(0.6, 0.5, 0.15, 0.9))


static func _draw_scorpion_stinger(img: Image, color: Color) -> void:
	# Curved stinger shape
	for y in range(16):
		for x in range(16):
			var px := float(x) - 7.5
			var py := float(y) - 7.5
			# Curved line: arc from bottom-left to top-right with a point
			var dx := px - 1.0
			var dy := py + 1.0
			var dist_to_curve := absf(sqrt(dx*dx + dy*dy) - 5.0)
			if dist_to_curve < 1.5 and dy > -4 and dy < 6 and dx > -6 and dx < 4:
				var shade := 1.0
				if dist_to_curve < 0.5:
					shade = 0.6  # darker center of stinger
				img.set_pixel(x, y, Color(
					color.r * shade, color.g * shade, color.b * shade, 1))
	# Tip (sharp point)
	img.set_pixel(11, 3, Color(0.9, 0.6, 0.5, 1))
	img.set_pixel(12, 3, Color(0.9, 0.6, 0.5, 1))


static func _draw_ember_dust(img: Image, color: Color) -> void:
	# Small glowing particles
	var positions := [Vector2(4,4), Vector2(10,5), Vector2(6,10), Vector2(11,10), Vector2(8,7)]
	for pos in positions:
		var px := int(pos.x)
		var py := int(pos.y)
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var sx := px + dx
				var sy := py + dy
				if sx >= 0 and sx < 16 and sy >= 0 and sy < 16:
					var d := sqrt(float(dx*dx + dy*dy))
					if d <= 1.0:
						var brightness := 1.0 - d * 0.3
						img.set_pixel(sx, sy, Color(
							minf(color.r * brightness + 0.2, 1),
							color.g * brightness * 0.6,
							color.b * brightness * 0.2, 1))


static func _draw_magma_core(img: Image, color: Color) -> void:
	# Glowing sphere with cracks
	for y in range(16):
		for x in range(16):
			var px := float(x) - 7.5
			var py := float(y) - 7.5
			var dist := sqrt(px*px + py*py)
			if dist <= 6.0:
				var shade := 1.0 - dist / 7.0
				# Cracks (dark lines)
				var crack := sin(px * 1.3 + py * 2.1) * cos(py * 1.7 - px * 0.9)
				if crack > 0.7 and dist > 2.0:
					shade *= 0.5
				img.set_pixel(x, y, Color(
					clampf(color.r * shade + 0.15, 0, 1),
					clampf(color.g * shade * 0.3, 0, 1),
					clampf(color.b * shade * 0.1, 0, 1), 1))
	# Glow center
	for y in range(-1, 2):
		for x in range(-1, 2):
			var sx := 7 + x
			var sy := 7 + y
			if sx >= 0 and sx < 16 and sy >= 0 and sy < 16:
				img.set_pixel(sx, sy, Color(1, 0.8, 0.3, 1))


static func _draw_starlight_dust(img: Image, color: Color) -> void:
	# Tiny star shapes
	var stars := [Vector2(3,3), Vector2(11,4), Vector2(5,10), Vector2(10,10), Vector2(8,3), Vector2(4,7)]
	for star in stars:
		var sx := int(star.x)
		var sy := int(star.y)
		# 4-point star
		img.set_pixel(sx, sy, color)
		if sx-1 >= 0: img.set_pixel(sx-1, sy, color)
		if sx+1 < 16: img.set_pixel(sx+1, sy, color)
		if sy-1 >= 0: img.set_pixel(sx, sy-1, color)
		if sy+1 < 16: img.set_pixel(sx, sy+1, color)
		# Tiny brighter center
		img.set_pixel(sx, sy, Color(minf(color.r + 0.3, 1), minf(color.g + 0.3, 1), minf(color.b + 0.4, 1), 1))


static func _draw_ethereal_essence(img: Image, color: Color) -> void:
	# Wispy cloud/glow shape
	for y in range(16):
		for x in range(16):
			var px := float(x) - 7.5
			var py := float(y) - 7.5
			var dist := sqrt(px*px + py*py)
			# Irregular wispy blob
			var wobble := 4.5 + 1.8 * sin(px * 0.7 + py * 0.5) * cos(py * 0.9 - px * 0.6)
			if dist <= wobble:
				var alpha := 1.0 - dist / wobble * 0.4
				img.set_pixel(x, y, Color(
					color.r, color.g, color.b, alpha))
	# Bright center core
	for y in range(-1, 2):
		for x in range(-1, 2):
			var sx := 7 + x
			var sy := 7 + y
			if sx >= 0 and sx < 16 and sy >= 0 and sy < 16:
				img.set_pixel(sx, sy, Color(minf(color.r + 0.3, 1), minf(color.g + 0.3, 1), minf(color.b + 0.4, 1), 1))


static func _item_color_for(category: String, item_id: String) -> Color:
	match item_id:
		"wood":              return Color(0.55, 0.35, 0.15)   # brown
		"stone":             return Color(0.55, 0.5, 0.45)    # gray
		"tool_upgrade_kit":  return Color(0.8, 0.65, 0.2)     # gold
		"compost":           return Color(0.4, 0.25, 0.1)     # dark brown
		"wooden_planks":     return Color(0.6, 0.45, 0.2)     # light brown
		"quality_compost":   return Color(0.3, 0.5, 0.2)      # green-brown
		"growth_booster":    return Color(0.2, 0.7, 0.35)     # green
		"yield_enhancer":    return Color(0.85, 0.7, 0.15)    # yellow
		"rich_fertilizer":   return Color(0.55, 0.25, 0.1)    # dark orange
		"super_fertilizer":  return Color(0.7, 0.15, 0.7)     # purple
		"berry":             return Color(0.85, 0.15, 0.15)   # red
		"flower":            return Color(0.9, 0.4, 0.6)      # pink
		"mushroom":          return Color(0.7, 0.55, 0.35)    # tan
		"iron_ore":          return Color(0.55, 0.5, 0.65)    # purple-gray
		"iron_ingot":        return Color(0.6, 0.6, 0.65)     # silver
		"copper_ore":        return Color(0.7, 0.4, 0.2)      # orange-brown
		"coal":              return Color(0.15, 0.15, 0.15)   # black
		"gold_ore":          return Color(0.85, 0.65, 0.1)    # gold
		"copper_ingot":      return Color(0.75, 0.45, 0.25)   # copper
		"steel_ingot":       return Color(0.5, 0.55, 0.6)     # blue-gray steel
		"gold_ingot":        return Color(0.9, 0.7, 0.15)     # bright gold
		"ectoplasm":         return Color(0.3, 0.75, 0.6)     # teal
		"spore_sac":         return Color(0.5, 0.65, 0.3)     # olive
		"ghostly_essence":   return Color(0.55, 0.5, 0.85)    # lavender
		"cinder_shard":      return Color(0.9, 0.35, 0.1)     # fiery orange
		"shadow_hide":       return Color(0.2, 0.15, 0.25)    # deep purple-black
		"frost_crystal":     return Color(0.5, 0.7, 0.95)     # ice blue
		"axe_tool":          return Color(0.5, 0.35, 0.15)    # brown
		"copper_axe":        return Color(0.8, 0.5, 0.25)    # copper orange
		"iron_axe":          return Color(0.55, 0.55, 0.62)  # iron silver
		"gold_axe":          return Color(0.9, 0.75, 0.15)   # gold
		"diamond_axe":       return Color(0.6, 0.85, 1.0)    # diamond ice blue
		"mythril_axe":       return Color(0.5, 0.8, 0.65)    # mythril teal
		"magma_axe":         return Color(0.9, 0.35, 0.1)    # magma red-orange
		"scythe_tool":       return Color(0.65, 0.55, 0.35)  # tan
		"pickaxe_tool":      return Color(0.55, 0.5, 0.45)   # gray
		"copper_pickaxe":    return Color(0.8, 0.5, 0.25)    # copper orange
		"iron_pickaxe":      return Color(0.55, 0.55, 0.62)  # iron silver
		"gold_pickaxe":      return Color(0.9, 0.75, 0.15)   # gold
		"diamond_pickaxe":   return Color(0.6, 0.85, 1.0)    # diamond ice blue
		"mythril_pickaxe":   return Color(0.5, 0.8, 0.65)    # mythril teal
		"magma_pickaxe":     return Color(0.9, 0.35, 0.1)    # magma red-orange
		"sword_tool":        return Color(0.6, 0.6, 0.7)     # silver
		"copper_sword":      return Color(0.8, 0.5, 0.25)    # copper orange
		"iron_sword":        return Color(0.55, 0.55, 0.62)  # iron silver
		"gold_sword":        return Color(0.9, 0.75, 0.15)   # gold
		"diamond_sword":     return Color(0.6, 0.85, 1.0)    # diamond ice blue
		"mythril_sword":     return Color(0.5, 0.8, 0.65)    # mythril teal
		"sprinkler":         return Color(0.4, 0.55, 0.7)     # blue-gray
		"quality_sprinkler": return Color(0.2, 0.6, 0.8)      # brighter blue
		"iridium_sprinkler": return Color(0.6, 0.3, 0.9)      # purple iridium
		"fishing_rod":       return Color(0.55, 0.35, 0.2)    # brown/wood
		"torch":             return Color(0.85, 0.5, 0.15)    # orange
		"vine":              return Color(0.35, 0.6, 0.2)     # green
		"gold_nugget":       return Color(0.9, 0.75, 0.1)     # gold
		"fence_material":    return Color(0.5, 0.35, 0.15)    # brown
		"stone_fence_material": return Color(0.5, 0.45, 0.4)  # dark gray
		"campfire_kit":      return Color(0.85, 0.5, 0.15)    # orange
		"small_home_kit":    return Color(0.6, 0.4, 0.25)     # warm brown
		"medium_home_kit":   return Color(0.55, 0.35, 0.2)    # darker brown
		"large_home_kit":    return Color(0.5, 0.3, 0.15)     # deep brown
		"barn_kit":          return Color(0.7, 0.2, 0.15)     # barn red
		"storage_shed_kit":  return Color(0.5, 0.5, 0.4)      # weathered gray
		"gate_kit":          return Color(0.55, 0.4, 0.25)    # fence brown
		"garden_bed_kit":    return Color(0.3, 0.5, 0.2)      # plant green
		"windmill_kit":      return Color(0.7, 0.65, 0.55)    # windmill cream
		"greenhouse_kit":    return Color(0.35, 0.6, 0.4)     # glass green
		"decorative_statue_kit": return Color(0.55, 0.5, 0.45) # stone gray
		"decorative_fountain_kit": return Color(0.5, 0.55, 0.6) # water blue-gray
		"decorative_bench_kit": return Color(0.55, 0.4, 0.25)  # wood brown
		"decorative_lantern_kit": return Color(0.8, 0.6, 0.2)  # lantern gold
		"decorative_sign_kit": return Color(0.5, 0.4, 0.25)    # sign brown
		"silo_kit":          return Color(0.5, 0.5, 0.45)     # silo gray
		"well_kit":          return Color(0.45, 0.5, 0.55)    # stone blue
		"hotel_kit":         return Color(0.7, 0.35, 0.2)     # red roof
		"scarecrow_kit":     return Color(0.8, 0.6, 0.1)      # straw yellow
		"compost_bin_kit":   return Color(0.4, 0.3, 0.15)     # compost brown
		"feather":           return Color(0.85, 0.8, 0.7)     # cream
		"egg":               return Color(0.9, 0.85, 0.75)    # eggshell
		"milk":              return Color(0.92, 0.9, 0.85)    # white
		"leather":           return Color(0.6, 0.4, 0.2)      # tan
		"fur":               return Color(0.65, 0.5, 0.3)     # brown-tan
		"chicken_meat":      return Color(0.85, 0.7, 0.55)    # pale poultry
		"venison":           return Color(0.7, 0.25, 0.15)    # dark red
		"antlers":           return Color(0.5, 0.4, 0.25)     # bone
		"wool":              return Color(0.85, 0.8, 0.7)     # off-white
		"truffle":           return Color(0.35, 0.2, 0.1)     # dark brown
		"nut":               return Color(0.55, 0.4, 0.2)     # nut brown
		"shell":             return Color(0.7, 0.6, 0.45)     # shell beige
		"grilled_vegetables": return Color(0.7, 0.4, 0.15)    # roasted
		"vegetable_soup":    return Color(0.6, 0.5, 0.2)      # broth
		"garden_salad":      return Color(0.3, 0.6, 0.25)     # green
		"roasted_roots":     return Color(0.65, 0.35, 0.15)   # root brown
		"fruit_compote":     return Color(0.7, 0.2, 0.25)     # fruit red
		"berry_juice":       return Color(0.75, 0.15, 0.25)   # berry red
		"hearty_stew":       return Color(0.55, 0.3, 0.15)    # stew brown
		"growth_tea":        return Color(0.3, 0.6, 0.3)      # tea green
		"lucky_salad":       return Color(0.4, 0.7, 0.3)      # bright green
		"farmers_breakfast": return Color(0.8, 0.65, 0.3)     # egg yellow
		"golden_soup":       return Color(0.85, 0.65, 0.15)   # golden
		"herbal_tea":        return Color(0.4, 0.55, 0.2)     # herb green
		"stuffed_vegetables":return Color(0.5, 0.6, 0.25)     # stuffed green
		"candied_fruit":     return Color(0.8, 0.2, 0.35)     # candy pink
		"mushroom_stew":     return Color(0.5, 0.35, 0.2)     # mushroom brown
		"cutlass":           return Color(0.6, 0.6, 0.65)    # silver
		"treasure_map":      return Color(0.7, 0.6, 0.3)     # parchment
		"cannonball":        return Color(0.3, 0.3, 0.3)     # dark gray
		"ancient_coin":      return Color(0.85, 0.75, 0.2)   # gold
		"cat_egg":           return Color(0.9, 0.5, 0.2)     # orange
		"dog_egg":           return Color(0.7, 0.45, 0.3)    # brown
		"fox_egg":           return Color(0.85, 0.4, 0.1)    # red
		"bird_egg":          return Color(0.3, 0.6, 0.9)     # sky blue
		"turtle_egg":        return Color(0.3, 0.7, 0.3)     # green
		"rabbit_egg":        return Color(0.85, 0.75, 0.65)  # cream
		"silver_ore":        return Color(0.7, 0.7, 0.8)    # silver-gray
		"silver_ingot":      return Color(0.75, 0.75, 0.85) # bright silver
		"diamond_ore":       return Color(0.5, 0.7, 0.9)    # light blue
		"diamond_gem":       return Color(0.6, 0.85, 1.0)   # ice blue
		"ruby_ore":          return Color(0.7, 0.2, 0.2)    # dark red
		"ruby_gem":          return Color(0.85, 0.15, 0.15) # bright red
		"obsidian_ore":      return Color(0.25, 0.15, 0.3)  # dark purple
		"obsidian_shard":    return Color(0.15, 0.1, 0.2)   # very dark purple-black
		"ice_crystal":       return Color(0.5, 0.7, 0.95)    # ice blue
		"snow_flower":       return Color(0.75, 0.85, 1.0)   # pale blue-white
		"polar_bear_hide":   return Color(0.85, 0.8, 0.75)   # off-white
		"gumdrop":           return Color(0.9, 0.3, 0.4)     # candy pink
		"chocolate_chunk":   return Color(0.4, 0.25, 0.15)   # dark brown
		"sugar_crystal":     return Color(0.95, 0.85, 0.7)   # cream-white
		"cactus_fruit":      return Color(0.8, 0.3, 0.35)    # cactus red
		"golden_scarab":     return Color(0.85, 0.7, 0.15)   # gold
		"scorpion_stinger":  return Color(0.5, 0.2, 0.15)    # dark red-brown
		"sulfur_crystal":    return Color(0.85, 0.8, 0.2)    # sulfur yellow
		"ember_dust":        return Color(0.9, 0.4, 0.1)     # fiery orange
		"magma_core":        return Color(0.85, 0.2, 0.1)    # magma red
		"moon_shard":        return Color(0.6, 0.65, 0.95)   # moon blue
		"starlight_dust":    return Color(0.8, 0.75, 0.95)   # lavender
		"ethereal_essence":  return Color(0.55, 0.4, 0.85)   # spirit purple
		"frozen_delight":    return Color(0.6, 0.8, 0.9)     # icy blue
		"chocolate_fondue":  return Color(0.5, 0.3, 0.15)    # fondue brown
		"candied_cactus":    return Color(0.75, 0.35, 0.3)   # cactus candy
		"magma_steel":       return Color(0.7, 0.2, 0.15)    # volcanic red steel
		"starlight_amulet":  return Color(0.7, 0.7, 0.9)     # starlight silver
		"ice_ward":          return Color(0.5, 0.7, 0.95)    # ice blue
		"sugar_sculpture":   return Color(0.9, 0.85, 0.75)   # cream
		"ember_lantern":     return Color(0.85, 0.55, 0.15)  # lantern orange
		"frost_resist_tonic":return Color(0.55, 0.75, 0.95)  # tonic blue
		"sweet_elixir":      return Color(0.9, 0.4, 0.5)     # elixir pink
		"desert_salve":      return Color(0.7, 0.6, 0.3)     # salve tan
		"magma_burst":       return Color(0.85, 0.3, 0.1)    # burst red
		"ethereal_infusion": return Color(0.6, 0.5, 0.9)     # infusion purple
		"polar_balm":        return Color(0.75, 0.8, 0.85)   # balm white-blue
		"cosmic_dust":       return Color(0.55, 0.35, 0.85)  # cosmic purple
		"bread":             return Color(0.85, 0.6, 0.3)   # bread golden brown
		"baguette":          return Color(0.8, 0.55, 0.25)  # baguette brown
		"croissant":         return Color(0.82, 0.58, 0.28) # croissant golden
		"cinnamon_roll":     return Color(0.7, 0.4, 0.2)    # cinnamon brown
		"fruit_tart":        return Color(0.8, 0.55, 0.25)  # tart golden
		"dough":             return Color(0.9, 0.8, 0.65)   # dough pale beige
	
	# Fallback by category
	match category:
		"seed":   return Color(0.3, 0.5, 0.2)      # green
		"crop":   return Color(0.8, 0.5, 0.15)     # orange
		"food", "meal": return Color(0.8, 0.3, 0.2) # red
		"resource": return Color(0.5, 0.45, 0.35)   # gray-brown
		"pet_egg": return Color(0.8, 0.5, 0.7)      # pink
		_:        return Color(0.4, 0.4, 0.5)      # blue-gray


# ── Bakery item icon drawing ────────────────────────────────────────────

## Bread loaf — rounded top with scoring marks
static func _draw_bread(img: Image, color: Color) -> void:
	for y in range(16):
		for x in range(16):
			var px := float(x) - 7.5
			var py := float(y) - 7.5
			# Rounded bread shape (wider at bottom)
			var top := 1.0 - (py + 4.0) * 0.12
			if top < 0.0: top = 0.0
			var w := 5.5 + top * 2.0
			if absf(px) <= w and py >= -4.0 and py <= 6.0:
				var shade := 1.0 - (py + 4.0) / 10.0 * 0.15
				if absf(px) > w - 0.5:
					shade *= 0.7
				# Scoring line on top
				if absf(px) <= 1.0 and py <= -2.0:
					shade *= 0.6
				img.set_pixel(x, y, Color(color.r * shade, color.g * shade * 0.9, color.b * shade * 0.7, 1.0))
	# Crust highlight
	for y in range(16):
		for x in range(16):
			var px := float(x) - 7.5
			var py := float(y) - 7.5
			if absf(px) <= 4.5 and py >= -4.0 and py <= -3.0:
				var p := img.get_pixel(x, y)
				if p.a > 0:
					img.set_pixel(x, y, Color(minf(p.r + 0.12, 1), minf(p.g + 0.08, 1), minf(p.b + 0.05, 1), 1.0))

## Baguette — long narrow loaf with diagonal cuts
static func _draw_baguette(img: Image, color: Color) -> void:
	for y in range(16):
		for x in range(16):
			var px := float(x) - 7.5
			var py := float(y) - 7.5
			# Long narrow shape
			var bx := absf(px)
			var top := 3.0 - py * 0.15
			if top < 2.0: top = 2.0
			if bx <= top and py >= -5.0 and py <= 6.0:
				var shade := 1.0 - (py + 5.0) / 11.0 * 0.12
				# Diagonal cuts
				var cut_x := px * 0.8 + py * 0.6
				if absf(int(cut_x * 1.5) - cut_x * 1.5) < 0.3 and py < 2.0:
					shade *= 0.55
				img.set_pixel(x, y, Color(color.r * shade, color.g * shade * 0.9, color.b * shade * 0.7, 1.0))

## Croissant — crescent-shaped flaky pastry
static func _draw_croissant(img: Image, color: Color) -> void:
	for y in range(16):
		for x in range(16):
			var px := float(x) - 7.5
			var py := float(y) - 7.0
			# Crescent curve
			var angle := atan2(py, px)
			var cres_r := 4.5 + 1.5 * sin(angle * 2.0 + 1.5)
			var dist := sqrt(px*px + py*py)
			var inner_r := 2.5 + 1.0 * sin(angle * 2.0 + 1.5)
			if dist <= cres_r and dist >= inner_r:
				var shade := 1.0 - (dist - inner_r) / (cres_r - inner_r) * 0.15
				# Flaky texture
				var flake := sin(px * 4.0 + py * 3.5) * 0.04
				img.set_pixel(x, y, Color(
					clampf(color.r * shade + flake, 0, 1),
					clampf(color.g * shade * 0.9 + flake, 0, 1),
					clampf(color.b * shade * 0.7, 0, 1), 1.0))

## Cinnamon Roll — swirled spiral with white icing
static func _draw_cinnamon_roll(img: Image, color: Color) -> void:
	# Swirl base
	for y in range(16):
		for x in range(16):
			var px := float(x) - 7.5
			var py := float(y) - 7.5
			var dist := sqrt(px*px + py*py)
			if dist <= 6.0:
				var angle := atan2(py, px)
				# Spiral lines
				var spiral := sin(angle * 4.0 + dist * 2.0)
				var shade := 0.6 + 0.3 * spiral * 0.5
				if dist > 5.0:
					shade *= 0.7
				img.set_pixel(x, y, Color(color.r * shade, color.g * shade, color.b * shade * 0.8, 1.0))
	# White icing drizzle on top
	for y in range(16):
		for x in range(16):
			var px := float(x) - 7.5
			var py := float(y) - 7.5
			var dist := sqrt(px*px + py*py)
			if dist <= 4.5 and dist > 1.0:
				var icing := sin(px * 2.5 + py * 1.8) * cos(py * 2.2 - px * 1.5)
				if icing > 0.6:
					img.set_pixel(x, y, Color(0.95, 0.92, 0.85, 0.9))

## Fruit Tart — pastry shell with colorful fruit topping
static func _draw_fruit_tart(img: Image, color: Color) -> void:
	# Tart shell (rounded edge)
	for y in range(16):
		for x in range(16):
			var px := float(x) - 7.5
			var py := float(y) - 7.5
			var dist := sqrt(px*px + py*py)
			var ang := atan2(py, px)
			var tart_r := 6.0 + 0.5 * sin(ang * 6.0 + 1.0)
			if dist <= tart_r and dist >= 2.0:
				var shade := 1.0
				if dist > tart_r - 1.0:
					shade = 0.75  # crust edge
				elif dist < 3.0:
					shade = 0.85  # inner fill
				img.set_pixel(x, y, Color(color.r * shade, color.g * shade * 0.9, color.b * shade * 0.7, 1.0))
	# Fruit topping (colorful dots)
	var fruit_colors: Array[Color] = [Color(0.9, 0.2, 0.2), Color(0.9, 0.7, 0.1), Color(0.2, 0.6, 0.3)]
	var fruit_positions: Array[Vector2] = [Vector2(5,5), Vector2(9,4), Vector2(7,8), Vector2(4,7), Vector2(10,7), Vector2(7,3)]
	for i in range(fruit_positions.size()):
		var fp := fruit_positions[i]
		var fc := fruit_colors[i % fruit_colors.size()]
		for y in range(16):
			for x in range(16):
				var dx := float(x) - fp.x
				var dy := float(y) - fp.y
				if dx*dx + dy*dy <= 2.5:
					img.set_pixel(x, y, fc)
	# Glaze shine
	for y in range(16):
		for x in range(16):
			var px := float(x) - 7.5
			var py := float(y) - 7.5
			if px*px + py*py <= 20.0:
				var p := img.get_pixel(x, y)
				if p.a > 0 and p.r > 0.6 and p.g > 0.5:
					var glaze := sin(px * 1.5 + py * 1.2) * 0.06
					img.set_pixel(x, y, Color(
						clampf(p.r + glaze, 0, 1), clampf(p.g + glaze, 0, 1), clampf(p.b + glaze, 0, 1), 1.0))

## Dough — soft rounded ball of raw dough
static func _draw_dough(img: Image, color: Color) -> void:
	for y in range(16):
		for x in range(16):
			var px := float(x) - 7.5
			var py := float(y) - 7.0
			var dist := sqrt(px*px + py*py)
			# Soft round ball
			if dist <= 5.5:
				var shade := 1.0 - dist / 6.0 * 0.1
				# Subtle fold lines
				var fold := sin(px * 3.0 + py * 2.0) * 0.03
				# Highlight on top
				if dist < 2.0 and py < 0:
					shade += 0.15
				img.set_pixel(x, y, Color(
					clampf(color.r * shade + fold, 0, 1),
					clampf(color.g * shade + fold * 0.8, 0, 1),
					clampf(color.b * shade + fold * 0.5, 0, 1), 1.0))

## Called at the end of _register_default_items() — assigns procedural
## icons to every registered item that doesn't have one yet.
func _assign_missing_item_icons() -> void:
	for id in items:
		var item := items[id] as ItemData
		if item.icon != null:
			continue  # already has an icon (e.g. procedural crop seed)
		item.icon = make_item_icon(item.category, item.id, item.display_name)


## Helper: register a pet egg item that can be used from inventory to unlock a pet.
func _add_pet_egg(id: String, display_name: String, desc: String) -> void:
	var egg := ItemData.new()
	egg.id = id
	egg.display_name = display_name
	egg.category = "pet_egg"
	egg.stack_size = 1
	egg.sell_price = 25
	egg.buy_price = 500
	egg.description = desc
	register_item(egg)


func generate_procedural_crops(seed: int) -> void:
	## Uses ProceduralCropGenerator to generate crops deterministically from world seed.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed + 99999  # unique offset for crop generation
	
	# Generate more initial crops (increased from 3)
	var generator := ProceduralCropGenerator.new()
	var base_crops := generator.generate_batch(5, rng)
	
	# Generate additional crops using the expanded generator
	var expanded_gen := ExpandedCropGenerator.new(rng)
	var existing_names := {}
	for c in base_crops:
		existing_names[c.display_name] = true
	var expanded_crops := expanded_gen.generate_batch(5, existing_names)
	
	procedural_crops.assign(base_crops + expanded_crops)

	# The starter crops are always available in the shop from the very
	# start - there'd be no way to earn the money to unlock them otherwise.
	for crop in procedural_crops:
		mark_discovered(crop.id)
	
	# ── Special: Minecraft Wheat ──
	# A classic blocky wheat crop, like from another world.
	var mc_wheat := CropData.new()
	mc_wheat.id = "minecraft_wheat"
	mc_wheat.display_name = "Minecraft Wheat"
	mc_wheat.seed_item_id = "minecraft_wheat_seeds"
	mc_wheat.yield_item_id = "minecraft_wheat"
	mc_wheat.yield_amount = 2
	mc_wheat.days_to_grow = 4
	mc_wheat.requires_water = true
	mc_wheat.rarity = "Common"
	mc_wheat.size_trait = "medium"
	mc_wheat.modulate_color = Color(0.85, 0.7, 0.15)  # Warm wheat gold
	mc_wheat.growth_stage_textures = CropSpriteUtils.generate_crop_textures(
		"Minecraft Wheat", Color(0.85, 0.7, 0.15), hash("minecraft_wheat_crop"), "Stalk"
	)
	register_crop(mc_wheat)
	mark_discovered(mc_wheat.id)
	
	# Generate Inconstant Fruits (legendary one-of-a-kind consumables)
	_generate_inconstant_fruits(rng)

	# Assign icons to any items that were created during crop generation
	# (yield items, mutation seed items) which weren't covered by the
	# earlier _assign_missing_item_icons() call in _register_default_items().
	_assign_missing_item_icons()


## Generates 3 unique Inconstant Fruits and registers them as buyable items.
## Sets the buy_price to an astronomical 10,000 coins so only the most
## dedicated players can afford one.
func _generate_inconstant_fruits(rng: RandomNumberGenerator) -> void:
	var system := InconstantFruitSystem.new()
	var fruits: Array[ItemData] = system.generate_fruits(rng.seed, 3)
	for fruit in fruits:
		if fruit.get_meta("is_soul_fruit", false):
			continue  # Soul Fruit is never buyable/sellable
		fruit.buy_price = 10000  # High price — 10K coins
		fruit.sell_price = 50000  # Can still sell for a fortune
