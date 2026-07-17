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

signal crop_discovered(crop_id: String)

func _ready() -> void:
	_register_default_tile_types()
	_register_default_items()
	_register_default_crops()

# ---------------------------------------------------------------------------
# Registration
# ---------------------------------------------------------------------------

func register_item(item: ItemData) -> void:
	items[item.id] = item

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
	return discovered_crop_ids.keys()

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
	tool_kit.display_name = "Tool Upgrade Kit"
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

func _register_default_crops() -> void:
	## Uses ProceduralCropGenerator to generate more unique crops each session.
	## The RNG is seeded from OS time so every launch is different.
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	
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
