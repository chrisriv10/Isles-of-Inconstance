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

	var watered_tilled := TileTypeData.new()
	watered_tilled.id = "watered_tilled"
	watered_tilled.atlas_coords = Vector2i(7, 0)
	watered_tilled.walkable = true
	watered_tilled.tillable = false
	register_tile_type(watered_tilled)

func _register_default_items() -> void:
	var stone := ItemData.new()
	stone.id = "stone"
	stone.display_name = "Stone"
	stone.category = "resource"
	stone.stack_size = 99
	stone.sell_price = 2
	stone.buy_price = 0
	stone.description = "A chunk of rock, gathered from outcrops around the island. Sells for a little, useful in bulk."
	register_item(stone)

func _register_default_crops() -> void:
	## Uses ProceduralCropGenerator to generate 3 unique crops each session.
	## The RNG is seeded from OS time so every launch is different.
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var generator := ProceduralCropGenerator.new()
	procedural_crops = generator.generate_batch(3, rng)

	# The starter crops are always available in the shop from the very
	# start - there'd be no way to earn the money to unlock them otherwise.
	for crop in procedural_crops:
		mark_discovered(crop.id)
