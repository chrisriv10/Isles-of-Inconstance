class_name BiomeLibrary
extends RefCounted

## Central registry of every biome in the game. Mirrors the pattern used by
## SpritePieceLibrary for crop sprites: static factory functions build
## Resource instances on demand, and callers duplicate() before mutating.
##
## To add a new biome:
##   1. Add a Type to BiomeType.gd
##   2. Write a _create_my_biome() below
##   3. Register it in get_all_biomes()

static func get_all_biomes() -> Array[BiomeDefinition]:
	return [
		_create_plains(),
		_create_forest(),
		_create_swamp(),
		_create_mountain(),
	]


static func get_biome(type: BiomeType.Type) -> BiomeDefinition:
	for biome in get_all_biomes():
		if biome.type == type:
			return biome
	return _create_plains()


# --- Plains (default/fallback biome) -----------------------------------

static func _create_plains() -> BiomeDefinition:
	var biome := BiomeDefinition.new()
	biome.type = BiomeType.Type.PLAINS
	biome.display_name = "Plains"
	biome.ground_tile_id = "grass"
	biome.elevation_range = Vector2(0.35, 0.65)
	biome.moisture_range = Vector2(0.25, 0.6)
	biome.terrain_roughness = 0.4
	biome.elevation_offset = 0.0
	biome.movement_speed_multiplier = 1.0
	biome.resource_density = 1.5
	biome.crop_trait_tags = ["hardy"]
	biome.crop_growth_multiplier = 1.0
	biome.crop_yield_multiplier = 1.0
	biome.crop_color_tint = Color.WHITE
	biome.unique_crop_chance = 0.02
	biome.resources = [_wildflowers()]
	return biome


# --- Forest --------------------------------------------------------------

static func _create_forest() -> BiomeDefinition:
	var biome := BiomeDefinition.new()
	biome.type = BiomeType.Type.FOREST
	biome.display_name = "Forest"
	biome.ground_tile_id = "forest_floor"
	biome.detail_tile_id = "underbrush"
	biome.elevation_range = Vector2(0.35, 0.7)
	biome.moisture_range = Vector2(0.45, 0.75)
	biome.terrain_roughness = 0.7
	biome.elevation_offset = 0.05
	biome.movement_speed_multiplier = 0.9
	biome.resource_density = 6.0
	biome.crop_trait_tags = ["shade_grown", "woodland"]
	biome.crop_growth_multiplier = 1.1
	biome.crop_yield_multiplier = 1.0
	biome.crop_color_tint = Color(0.75, 0.95, 0.7)
	biome.unique_crop_chance = 0.1
	biome.resources = [
		_forest_tree(),
		_forest_berries(),
		_forest_mushrooms(),
	]
	return biome


static func _forest_tree() -> ResourceSpawnEntry:
	var entry := ResourceSpawnEntry.new()
	entry.resource_id = "forest_tree"
	entry.display_name = "Tree"
	entry.weight = 5.0
	entry.min_spacing = 2
	entry.clusters = true
	entry.cluster_size_range = Vector2i(3, 8)
	entry.scene_path = "res://scenes/world/resources/tree.tscn"
	entry.harvestable = true
	return entry


static func _forest_berries() -> ResourceSpawnEntry:
	var entry := ResourceSpawnEntry.new()
	entry.resource_id = "forest_berries"
	entry.display_name = "Berry Bush"
	entry.weight = 3.0
	entry.min_spacing = 1
	entry.clusters = true
	entry.cluster_size_range = Vector2i(2, 4)
	entry.scene_path = "res://scenes/world/resources/berry_bush.tscn"
	entry.harvestable = true
	return entry


static func _forest_mushrooms() -> ResourceSpawnEntry:
	var entry := ResourceSpawnEntry.new()
	entry.resource_id = "forest_mushrooms"
	entry.display_name = "Mushroom Patch"
	entry.weight = 2.0
	entry.min_spacing = 1
	entry.clusters = true
	entry.cluster_size_range = Vector2i(2, 5)
	entry.scene_path = "res://scenes/world/resources/mushroom_patch.tscn"
	entry.harvestable = true
	return entry


# --- Swamp ---------------------------------------------------------------

static func _create_swamp() -> BiomeDefinition:
	var biome := BiomeDefinition.new()
	biome.type = BiomeType.Type.SWAMP
	biome.display_name = "Swamp"
	biome.ground_tile_id = "bog"
	biome.detail_tile_id = "murky_water"
	biome.elevation_range = Vector2(0.1, 0.4)
	biome.moisture_range = Vector2(0.7, 1.0)
	biome.terrain_roughness = 0.25
	biome.elevation_offset = -0.1
	biome.movement_speed_multiplier = 0.7
	biome.resource_density = 4.0
	biome.crop_trait_tags = ["waterlogged", "rare_bloom"]
	biome.crop_growth_multiplier = 0.85
	biome.crop_yield_multiplier = 1.3
	biome.crop_color_tint = Color(0.55, 0.75, 0.5)
	biome.unique_crop_chance = 0.25
	biome.resources = [
		_swamp_rare_plants(),
		_swamp_unique_crops(),
	]
	return biome


static func _swamp_rare_plants() -> ResourceSpawnEntry:
	var entry := ResourceSpawnEntry.new()
	entry.resource_id = "swamp_rare_plant"
	entry.display_name = "Rare Plant"
	entry.weight = 2.0
	entry.min_spacing = 2
	entry.clusters = false
	entry.scene_path = "res://scenes/world/resources/rare_plant.tscn"
	entry.harvestable = true
	return entry


static func _swamp_unique_crops() -> ResourceSpawnEntry:
	var entry := ResourceSpawnEntry.new()
	entry.resource_id = "swamp_unique_crop"
	entry.display_name = "Wild Bog Crop"
	entry.weight = 1.0
	entry.min_spacing = 3
	entry.clusters = false
	entry.scene_path = "res://scenes/world/resources/wild_bog_crop.tscn"
	entry.harvestable = true
	return entry


# --- Mountain --------------------------------------------------------------

static func _create_mountain() -> BiomeDefinition:
	var biome := BiomeDefinition.new()
	biome.type = BiomeType.Type.MOUNTAIN
	biome.display_name = "Mountain"
	biome.ground_tile_id = "stone"
	biome.detail_tile_id = "snow_patch"
	biome.elevation_range = Vector2(0.75, 1.0)
	biome.moisture_range = Vector2(0.0, 0.4)
	biome.terrain_roughness = 1.4
	biome.elevation_offset = 0.2
	biome.movement_speed_multiplier = 0.75
	biome.resource_density = 3.0
	biome.crop_trait_tags = ["crystalline", "high_altitude"]
	biome.crop_growth_multiplier = 1.25
	biome.crop_yield_multiplier = 0.9
	biome.crop_color_tint = Color(0.75, 0.85, 1.0)
	biome.unique_crop_chance = 0.15
	biome.resources = [
		_mountain_crystals(),
		_mountain_special_seeds(),
	]
	return biome


static func _mountain_crystals() -> ResourceSpawnEntry:
	var entry := ResourceSpawnEntry.new()
	entry.resource_id = "mountain_crystal"
	entry.display_name = "Crystal Deposit"
	entry.weight = 2.5
	entry.min_spacing = 2
	entry.clusters = true
	entry.cluster_size_range = Vector2i(1, 3)
	entry.scene_path = "res://scenes/world/resources/crystal_deposit.tscn"
	entry.harvestable = true
	return entry


static func _mountain_special_seeds() -> ResourceSpawnEntry:
	var entry := ResourceSpawnEntry.new()
	entry.resource_id = "mountain_special_seeds"
	entry.display_name = "Special Seed Cache"
	entry.weight = 1.5
	entry.min_spacing = 3
	entry.clusters = false
	entry.scene_path = "res://scenes/world/resources/special_seed_cache.tscn"
	entry.harvestable = true
	return entry


static func _wildflowers() -> ResourceSpawnEntry:
	var entry := ResourceSpawnEntry.new()
	entry.resource_id = "plains_wildflowers"
	entry.display_name = "Wildflowers"
	entry.weight = 1.0
	entry.min_spacing = 1
	entry.clusters = false
	entry.scene_path = "res://scenes/world/resources/wildflowers.tscn"
	entry.harvestable = true
	return entry
