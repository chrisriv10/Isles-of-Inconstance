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
		_create_dense_forest(),
		_create_swamp(),
		_create_mountain(),
		_create_rocky_hills(),
		_create_beach(),
		_create_meadow(),
		_create_flower_fields(),
		_create_pine_forest(),
		_create_cherry_grove(),
		_create_savanna(),
		_create_autumn_forest(),
		_create_snow_fields(),
		_create_wetlands(),
		_create_jungle(),
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
	biome.resource_density = 1.0
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
	biome.resource_density = 4.0
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
	entry.weight = 8.0
	entry.min_spacing = 1
	entry.clusters = true
	entry.cluster_size_range = Vector2i(4, 10)
	entry.scene_path = "res://scenes/objects/Tree.tscn"
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
	entry.scene_path = "res://scenes/objects/Bush.tscn"
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
	entry.scene_path = "res://scenes/objects/MushroomPatch.tscn"
	entry.harvestable = true
	return entry


# --- Swamp ---------------------------------------------------------------

static func _create_swamp() -> BiomeDefinition:
	var biome := BiomeDefinition.new()
	biome.type = BiomeType.Type.SWAMP
	biome.display_name = "Swamp"
	biome.ground_tile_id = "bog"
	biome.detail_tile_id = "murky_water"
	biome.elevation_range = Vector2(0.0, 0.35)
	biome.moisture_range = Vector2(0.4, 0.75)
	biome.terrain_roughness = 0.25
	biome.elevation_offset = -0.1
	biome.movement_speed_multiplier = 0.7
	biome.resource_density = 3.0
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
	entry.scene_path = "res://scenes/objects/FlowerPatch.tscn"
	entry.harvestable = true
	return entry


static func _swamp_unique_crops() -> ResourceSpawnEntry:
	var entry := ResourceSpawnEntry.new()
	entry.resource_id = "swamp_unique_crop"
	entry.display_name = "Wild Bog Crop"
	entry.weight = 1.0
	entry.min_spacing = 3
	entry.clusters = false
	entry.scene_path = "res://scenes/objects/MushroomPatch.tscn"
	entry.harvestable = true
	return entry


# --- Mountain --------------------------------------------------------------

static func _create_mountain() -> BiomeDefinition:
	var biome := BiomeDefinition.new()
	biome.type = BiomeType.Type.MOUNTAIN
	biome.display_name = "Mountain"
	biome.ground_tile_id = "cobblestone_path"
	biome.detail_tile_id = "snow_patch"
	biome.elevation_range = Vector2(0.72, 0.88)
	biome.moisture_range = Vector2(0.2, 0.45)
	biome.terrain_roughness = 1.4
	biome.elevation_offset = 0.2
	biome.movement_speed_multiplier = 0.75
	biome.resource_density = 2.5
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
	entry.scene_path = "res://scenes/objects/ResourceNode.tscn"
	entry.harvestable = true
	return entry


static func _mountain_special_seeds() -> ResourceSpawnEntry:
	var entry := ResourceSpawnEntry.new()
	entry.resource_id = "mountain_special_seeds"
	entry.display_name = "Special Seed Cache"
	entry.weight = 1.5
	entry.min_spacing = 3
	entry.clusters = false
	entry.scene_path = "res://scenes/objects/ResourceNode.tscn"
	entry.harvestable = true
	return entry


# --- Beach ---------------------------------------------------------------
## Sandy shoreline between water and land. Nutrient-poor but easy to traverse.

static func _create_beach() -> BiomeDefinition:
	var biome := BiomeDefinition.new()
	biome.type = BiomeType.Type.BEACH
	biome.display_name = "Beach"
	biome.ground_tile_id = "sand"
	biome.elevation_range = Vector2(0.25, 0.45)
	biome.moisture_range = Vector2(0.5, 0.85)
	biome.terrain_roughness = 0.2
	biome.elevation_offset = -0.05
	biome.movement_speed_multiplier = 1.0
	biome.resource_density = 0.5
	biome.crop_trait_tags = ["salty", "sand_dweller"]
	biome.crop_growth_multiplier = 0.9
	biome.crop_yield_multiplier = 1.0
	biome.crop_color_tint = Color(0.9, 0.85, 0.7)
	biome.unique_crop_chance = 0.05
	biome.resources = []
	return biome


# --- Meadow --------------------------------------------------------------
## Fertile, flower-filled grassland. Excellent for farming.

static func _create_meadow() -> BiomeDefinition:
	var biome := BiomeDefinition.new()
	biome.type = BiomeType.Type.MEADOW
	biome.display_name = "Meadow"
	biome.ground_tile_id = "fertile_soil"
	biome.elevation_range = Vector2(0.4, 0.6)
	biome.moisture_range = Vector2(0.3, 0.65)
	biome.terrain_roughness = 0.3
	biome.elevation_offset = 0.0
	biome.movement_speed_multiplier = 1.0
	biome.resource_density = 1.5
	biome.crop_trait_tags = ["rich", "blooming"]
	biome.crop_growth_multiplier = 1.15
	biome.crop_yield_multiplier = 1.2
	biome.crop_color_tint = Color(0.9, 1.0, 0.8)
	biome.unique_crop_chance = 0.08
	biome.resources = [_wildflowers()]
	return biome


static func _wildflowers() -> ResourceSpawnEntry:
	var entry := ResourceSpawnEntry.new()
	entry.resource_id = "plains_wildflowers"
	entry.display_name = "Wildflowers"
	entry.weight = 1.0
	entry.min_spacing = 1
	entry.clusters = false
	entry.scene_path = "res://scenes/objects/FlowerPatch.tscn"
	entry.harvestable = true
	return entry

# --- Dense Forest ---------------------------------------------------------
static func _create_dense_forest() -> BiomeDefinition:
	var biome := BiomeDefinition.new()
	biome.type = BiomeType.Type.FOREST
	biome.display_name = "Dense Forest"
	biome.ground_tile_id = "grass"
	biome.elevation_range = Vector2(0.35, 0.65)
	biome.moisture_range = Vector2(0.55, 0.85)
	biome.terrain_roughness = 0.8
	biome.elevation_offset = 0.08
	biome.movement_speed_multiplier = 0.7
	biome.resource_density = 5.0
	biome.crop_trait_tags = ["shade_grown", "woodland", "mossy"]
	biome.crop_growth_multiplier = 1.15
	biome.crop_yield_multiplier = 0.9
	biome.crop_color_tint = Color(0.4, 0.7, 0.4)
	biome.unique_crop_chance = 0.12
	biome.resources = [_forest_tree(), _forest_berries(), _forest_mushrooms()]
	return biome

# --- Rocky Hills ---------------------------------------------------------
static func _create_rocky_hills() -> BiomeDefinition:
	var biome := BiomeDefinition.new()
	biome.type = BiomeType.Type.MOUNTAIN
	biome.display_name = "Rocky Hills"
	biome.ground_tile_id = "dirt"
	biome.elevation_range = Vector2(0.55, 0.72)
	biome.moisture_range = Vector2(0.2, 0.45)
	biome.terrain_roughness = 1.0
	biome.elevation_offset = 0.1
	biome.movement_speed_multiplier = 0.85
	biome.resource_density = 2.0
	biome.crop_trait_tags = ["hardy", "rocky"]
	biome.crop_growth_multiplier = 1.1
	biome.crop_yield_multiplier = 0.85
	biome.crop_color_tint = Color(0.5, 0.55, 0.5)
	biome.unique_crop_chance = 0.08
	biome.resources = [_mountain_crystals(), _snow_rocks()]
	return biome

# --- Flower Fields -------------------------------------------------------
static func _create_flower_fields() -> BiomeDefinition:
	var biome := BiomeDefinition.new()
	biome.type = BiomeType.Type.MEADOW
	biome.display_name = "Flower Fields"
	biome.ground_tile_id = "flower_fields"
	biome.elevation_range = Vector2(0.3, 0.5)
	biome.moisture_range = Vector2(0.4, 0.6)
	biome.terrain_roughness = 0.2
	biome.elevation_offset = -0.02
	biome.movement_speed_multiplier = 1.0
	biome.resource_density = 1.5
	biome.crop_trait_tags = ["blooming", "fertile"]
	biome.crop_growth_multiplier = 0.9
	biome.crop_yield_multiplier = 1.25
	biome.crop_color_tint = Color(1.0, 0.8, 0.9)
	biome.unique_crop_chance = 0.1
	biome.resources = [_flower_field_flowers(), _forest_berries()]
	return biome


static func _flower_field_flowers() -> ResourceSpawnEntry:
	var entry := ResourceSpawnEntry.new()
	entry.resource_id = "flower_field_wildflowers"
	entry.display_name = "Petal Blooms"
	entry.weight = 4.0
	entry.min_spacing = 1
	entry.clusters = true
	entry.cluster_size_range = Vector2i(2, 6)
	entry.scene_path = "res://scenes/objects/FlowerPatch.tscn"
	entry.harvestable = true
	return entry

# --- Pine Forest ---------------------------------------------------------
static func _create_pine_forest() -> BiomeDefinition:
	var biome := BiomeDefinition.new()
	biome.type = BiomeType.Type.FOREST
	biome.display_name = "Pine Forest"
	biome.ground_tile_id = "pine_forest"
	biome.elevation_range = Vector2(0.45, 0.7)
	biome.moisture_range = Vector2(0.3, 0.55)
	biome.terrain_roughness = 0.6
	biome.elevation_offset = 0.1
	biome.movement_speed_multiplier = 0.85
	biome.resource_density = 3.5
	biome.crop_trait_tags = ["hardy", "pine"]
	biome.crop_growth_multiplier = 1.2
	biome.crop_yield_multiplier = 0.8
	biome.crop_color_tint = Color(0.2, 0.5, 0.2)
	biome.unique_crop_chance = 0.06
	biome.resources = [_pine_forest_trees(), _forest_berries(), _forest_mushrooms()]
	return biome


static func _pine_forest_trees() -> ResourceSpawnEntry:
	var entry := ResourceSpawnEntry.new()
	entry.resource_id = "pine_forest_tree"
	entry.display_name = "Pine Tree"
	entry.weight = 5.0
	entry.min_spacing = 2
	entry.clusters = true
	entry.cluster_size_range = Vector2i(3, 6)
	entry.scene_path = "res://scenes/objects/Tree.tscn"
	entry.harvestable = true
	return entry

# --- Cherry Grove ---------------------------------------------------------
static func _create_cherry_grove() -> BiomeDefinition:
	var biome := BiomeDefinition.new()
	biome.type = BiomeType.Type.FOREST
	biome.display_name = "Cherry Grove"
	biome.ground_tile_id = "cherry_grove"
	biome.elevation_range = Vector2(0.2, 0.4)
	biome.moisture_range = Vector2(0.3, 0.5)
	biome.terrain_roughness = 0.3
	biome.elevation_offset = 0.0
	biome.movement_speed_multiplier = 1.0
	biome.resource_density = 2.5
	biome.crop_trait_tags = ["blooming", "sweet"]
	biome.crop_growth_multiplier = 0.85
	biome.crop_yield_multiplier = 1.2
	biome.crop_color_tint = Color(1.0, 0.7, 0.8)
	biome.unique_crop_chance = 0.15
	biome.resources = [_cherry_trees(), _forest_berries()]
	return biome


static func _cherry_trees() -> ResourceSpawnEntry:
	var entry := ResourceSpawnEntry.new()
	entry.resource_id = "cherry_tree"
	entry.display_name = "Cherry Tree"
	entry.weight = 5.0
	entry.min_spacing = 2
	entry.clusters = true
	entry.cluster_size_range = Vector2i(3, 7)
	entry.scene_path = "res://scenes/objects/Tree.tscn"
	entry.harvestable = true
	return entry


# --- Savanna -------------------------------------------------------------
static func _create_savanna() -> BiomeDefinition:
	var biome := BiomeDefinition.new()
	biome.type = BiomeType.Type.PLAINS
	biome.display_name = "Savanna"
	biome.ground_tile_id = "savanna"
	biome.elevation_range = Vector2(0.35, 0.55)
	biome.moisture_range = Vector2(0.05, 0.25)
	biome.terrain_roughness = 0.35
	biome.elevation_offset = 0.02
	biome.movement_speed_multiplier = 1.1
	biome.resource_density = 1.0
	biome.crop_trait_tags = ["hardy", "drought_resistant"]
	biome.crop_growth_multiplier = 0.7
	biome.crop_yield_multiplier = 0.8
	biome.crop_color_tint = Color(0.8, 0.6, 0.3)
	biome.unique_crop_chance = 0.04
	biome.resources = [_savanna_grass_tufts(), _forest_berries()]
	return biome


static func _savanna_grass_tufts() -> ResourceSpawnEntry:
	var entry := ResourceSpawnEntry.new()
	entry.resource_id = "savanna_grass_tuft"
	entry.display_name = "Dry Grass"
	entry.weight = 4.0
	entry.min_spacing = 1
	entry.clusters = true
	entry.cluster_size_range = Vector2i(2, 5)
	entry.scene_path = "res://scenes/objects/FlowerPatch.tscn"
	entry.harvestable = false
	return entry


# --- Autumn Forest ---------------------------------------------------------
static func _create_autumn_forest() -> BiomeDefinition:
	var biome := BiomeDefinition.new()
	biome.type = BiomeType.Type.FOREST
	biome.display_name = "Autumn Forest"
	biome.ground_tile_id = "autumn_forest"
	biome.elevation_range = Vector2(0.35, 0.6)
	biome.moisture_range = Vector2(0.35, 0.6)
	biome.terrain_roughness = 0.5
	biome.elevation_offset = 0.03
	biome.movement_speed_multiplier = 0.9
	biome.resource_density = 3.0
	biome.crop_trait_tags = ["hardy", "autumn"]
	biome.crop_growth_multiplier = 1.0
	biome.crop_yield_multiplier = 1.1
	biome.crop_color_tint = Color(1.0, 0.6, 0.2)
	biome.unique_crop_chance = 0.08
	biome.resources = [_autumn_trees(), _forest_berries(), _forest_mushrooms()]
	return biome


static func _autumn_trees() -> ResourceSpawnEntry:
	var entry := ResourceSpawnEntry.new()
	entry.resource_id = "autumn_tree"
	entry.display_name = "Autumn Tree"
	entry.weight = 5.0
	entry.min_spacing = 2
	entry.clusters = true
	entry.cluster_size_range = Vector2i(3, 6)
	entry.scene_path = "res://scenes/objects/Tree.tscn"
	entry.harvestable = true
	return entry


# --- Snow Fields ---------------------------------------------------------
static func _create_snow_fields() -> BiomeDefinition:
	var biome := BiomeDefinition.new()
	biome.type = BiomeType.Type.MOUNTAIN
	biome.display_name = "Snow Fields"
	biome.ground_tile_id = "snow"
	biome.elevation_range = Vector2(0.7, 1.0)
	biome.moisture_range = Vector2(0.4, 0.7)
	biome.terrain_roughness = 0.6
	biome.elevation_offset = 0.3
	biome.movement_speed_multiplier = 0.6
	biome.resource_density = 1.0
	biome.crop_trait_tags = ["cold_resistant", "hardy"]
	biome.crop_growth_multiplier = 1.5
	biome.crop_yield_multiplier = 0.6
	biome.crop_color_tint = Color(0.8, 0.85, 1.0)
	biome.unique_crop_chance = 0.05
	biome.resources = [_snow_rocks(), _mountain_crystals()]
	return biome


static func _snow_rocks() -> ResourceSpawnEntry:
	var entry := ResourceSpawnEntry.new()
	entry.resource_id = "snow_rocks"
	entry.display_name = "Frozen Rock"
	entry.weight = 4.0
	entry.min_spacing = 1
	entry.clusters = false
	entry.scene_path = "res://scenes/objects/ResourceNode.tscn"
	entry.harvestable = true
	return entry


# --- Wetlands -------------------------------------------------------------
static func _create_wetlands() -> BiomeDefinition:
	var biome := BiomeDefinition.new()
	biome.type = BiomeType.Type.SWAMP
	biome.display_name = "Wetlands"
	biome.ground_tile_id = "wetlands"
	biome.elevation_range = Vector2(0.15, 0.35)
	biome.moisture_range = Vector2(0.6, 0.9)
	biome.terrain_roughness = 0.2
	biome.elevation_offset = -0.05
	biome.movement_speed_multiplier = 0.8
	biome.resource_density = 2.0
	biome.crop_trait_tags = ["waterlogged", "aquatic"]
	biome.crop_growth_multiplier = 0.9
	biome.crop_yield_multiplier = 1.1
	biome.crop_color_tint = Color(0.4, 0.6, 0.5)
	biome.unique_crop_chance = 0.12
	biome.resources = [_wetlands_plants(), _forest_mushrooms(), _swamp_rare_plants()]
	return biome


static func _wetlands_plants() -> ResourceSpawnEntry:
	var entry := ResourceSpawnEntry.new()
	entry.resource_id = "wetlands_plant"
	entry.display_name = "Marsh Plant"
	entry.weight = 4.0
	entry.min_spacing = 1
	entry.clusters = true
	entry.cluster_size_range = Vector2i(2, 5)
	entry.scene_path = "res://scenes/objects/FlowerPatch.tscn"
	entry.harvestable = true
	return entry


# --- Jungle -------------------------------------------------------------
static func _create_jungle() -> BiomeDefinition:
	var biome := BiomeDefinition.new()
	biome.type = BiomeType.Type.FOREST
	biome.display_name = "Jungle"
	biome.ground_tile_id = "jungle"
	biome.elevation_range = Vector2(0.2, 0.5)
	biome.moisture_range = Vector2(0.6, 1.0)
	biome.terrain_roughness = 0.9
	biome.elevation_offset = 0.0
	biome.movement_speed_multiplier = 0.6
	biome.resource_density = 5.0
	biome.crop_trait_tags = ["tropical", "exotic"]
	biome.crop_growth_multiplier = 0.8
	biome.crop_yield_multiplier = 1.4
	biome.crop_color_tint = Color(0.2, 0.8, 0.3)
	biome.unique_crop_chance = 0.2
	biome.resources = [_jungle_trees(), _forest_berries(), _swamp_rare_plants()]
	return biome


static func _jungle_trees() -> ResourceSpawnEntry:
	var entry := ResourceSpawnEntry.new()
	entry.resource_id = "jungle_tree"
	entry.display_name = "Jungle Tree"
	entry.weight = 6.0
	entry.min_spacing = 2
	entry.clusters = true
	entry.cluster_size_range = Vector2i(3, 7)
	entry.scene_path = "res://scenes/objects/Tree.tscn"
	entry.harvestable = true
	return entry
