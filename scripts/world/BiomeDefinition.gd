class_name BiomeDefinition
extends Resource

## Full description of one biome: what terrain it generates, what resources
## spawn in it, and how it warps crops planted within its borders.
## Instances are produced by BiomeLibrary.gd and selected at generation
## time by BiomeGenerator.gd based on seeded elevation/moisture noise.

@export var type: BiomeType.Type = BiomeType.Type.PLAINS
@export var display_name: String = "Plains"

# --- Terrain ---------------------------------------------------------

## Tile id used by the ground tilemap layer for this biome's base terrain.
@export var ground_tile_id: String = "grass"
## Secondary/detail tile id (e.g. mud in swamps, rock in mountains).
@export var detail_tile_id: String = ""

## Normalized [0,1] elevation band this biome is allowed to occupy.
@export var elevation_range: Vector2 = Vector2(0.0, 1.0)
## Normalized [0,1] moisture band this biome is allowed to occupy.
@export var moisture_range: Vector2 = Vector2(0.0, 1.0)

## Multiplies the raw height-noise sample before it's baked into the
## heightmap, giving each biome a distinct silhouette (mountains spike,
## swamps stay low and flat, forests roll gently).
@export var terrain_roughness: float = 1.0
## Flat offset applied after roughness, so e.g. swamps sit visibly lower
## and mountains sit visibly higher than plains.
@export var elevation_offset: float = 0.0

## Multiplies player movement speed while standing in this biome
## (e.g. swamps slow you down, plains are neutral).
@export var movement_speed_multiplier: float = 1.0

# --- Resource spawning -------------------------------------------------

@export var resources: Array[ResourceSpawnEntry] = []
## Target resource nodes per 100 tiles; scaled by each entry's own weight.
@export var resource_density: float = 4.0

# --- Crop traits ---------------------------------------------------------

## Trait tags granted to any crop planted while standing in this biome.
## Consumed by CropTraitGenerator.gd to flavor CropData instances.
@export var crop_trait_tags: Array[String] = []
## Growth-time multiplier for crops planted in this biome (< 1 = faster).
@export var crop_growth_multiplier: float = 1.0
## Harvest-yield multiplier for crops grown in this biome.
@export var crop_yield_multiplier: float = 1.0
## Procedural sprite tint blended into crops generated for this biome.
@export var crop_color_tint: Color = Color.WHITE
## Chance [0,1] that a crop planted here rolls a biome-exclusive unique
## variant instead of its normal form.
@export var unique_crop_chance: float = 0.0


func matches_elevation_moisture(elevation: float, moisture: float) -> bool:
	return elevation >= elevation_range.x and elevation <= elevation_range.y \
		and moisture >= moisture_range.x and moisture <= moisture_range.y


## Distance from the center of this biome's elevation/moisture band, used
## by BiomeGenerator to pick the *best* biome when several ranges overlap.
func distance_to(elevation: float, moisture: float) -> float:
	var elev_center := (elevation_range.x + elevation_range.y) * 0.5
	var moist_center := (moisture_range.x + moisture_range.y) * 0.5
	return Vector2(elevation - elev_center, moisture - moist_center).length()
