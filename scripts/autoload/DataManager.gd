extends Node

## Autoload singleton. Central registry for all static game data
## (items, crops, tile types). Other systems look up definitions here
## instead of holding their own copies, which keeps data consistent and
## makes it trivial to add new content later.

var items: Dictionary = {}       # id -> ItemData
var crops: Dictionary = {}       # id -> CropData
var tile_types: Dictionary = {}  # id -> TileTypeData

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
	fertile_soil.atlas_coords = Vector2i(6, 0)
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
	trees.atlas_coords = Vector2i(4, 0)
	trees.walkable = false
	trees.tillable = false
	trees.noise_min = 0.4
	trees.noise_max = 0.8
	register_tile_type(trees)

	var rocks := TileTypeData.new()
	rocks.id = "rocks"
	rocks.atlas_coords = Vector2i(5, 0)
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

func _register_default_items() -> void:
	var seed_item := ItemData.new()
	seed_item.id = "basic_seed"
	seed_item.display_name = "Basic Seed"
	seed_item.stack_size = 99
	seed_item.sell_price = 2
	register_item(seed_item)

	var crop_yield := ItemData.new()
	crop_yield.id = "basic_crop"
	crop_yield.display_name = "Basic Crop"
	crop_yield.stack_size = 99
	crop_yield.sell_price = 10
	register_item(crop_yield)

func _register_default_crops() -> void:
	var crop := CropData.new()
	crop.id = "basic_crop"
	crop.display_name = "Basic Crop"
	crop.days_to_grow = 4
	crop.yield_item_id = "basic_crop"
	crop.yield_amount = 1
	var sheet := load("res://assets/sprites/crop_stages.png")
	if sheet:
		# Split the 64x16 sheet into 4 16x16 stage textures.
		for i in range(4):
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(i * 16, 0, 16, 16)
			crop.growth_stage_textures.append(atlas)
	register_crop(crop)
