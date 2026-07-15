class_name BiomeGenerator
extends RefCounted

## Turns a world seed into a deterministic biome map.
##
## Two independent noise fields (elevation, moisture) are sampled per tile.
## Every BiomeDefinition in BiomeLibrary claims a band of that
## elevation/moisture space; whichever biome's band best matches the
## sampled point wins that tile. Because both noise fields are seeded
## directly from the world seed, the exact same seed always reproduces
## the exact same biome layout.

var world_seed: int
var elevation_noise: FastNoiseLite
var moisture_noise: FastNoiseLite
var _biomes: Array[BiomeDefinition]

## How many world tiles one noise "cell" covers - lower is more
## fragmented/patchy biomes, higher is broad continuous regions.
@export var biome_scale: float = 0.015


func _init(seed_value: int) -> void:
	world_seed = seed_value
	_biomes = BiomeLibrary.get_all_biomes()

	elevation_noise = FastNoiseLite.new()
	elevation_noise.seed = _derive_seed("elevation")
	elevation_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	elevation_noise.fractal_octaves = 4
	elevation_noise.frequency = biome_scale

	moisture_noise = FastNoiseLite.new()
	moisture_noise.seed = _derive_seed("moisture")
	moisture_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	moisture_noise.fractal_octaves = 3
	# Slightly different frequency than elevation so the two fields don't
	# stay perfectly correlated, giving more varied biome borders.
	moisture_noise.frequency = biome_scale * 1.3


## Deterministically derives a sub-seed from the world seed + a string tag,
## so elevation and moisture noise never accidentally share a seed.
func _derive_seed(tag: String) -> int:
	return int(hash(str(world_seed) + ":" + tag))


## Returns normalized [0,1] elevation at a tile coordinate.
func sample_elevation(tile_x: int, tile_y: int) -> float:
	return (elevation_noise.get_noise_2d(tile_x, tile_y) + 1.0) * 0.5


## Returns normalized [0,1] moisture at a tile coordinate.
func sample_moisture(tile_x: int, tile_y: int) -> float:
	return (moisture_noise.get_noise_2d(tile_x, tile_y) + 1.0) * 0.5


## Resolves the winning BiomeDefinition for a single tile.
func get_biome_at(tile_x: int, tile_y: int) -> BiomeDefinition:
	var elevation := sample_elevation(tile_x, tile_y)
	var moisture := sample_moisture(tile_x, tile_y)
	return _classify(elevation, moisture)


func _classify(elevation: float, moisture: float) -> BiomeDefinition:
	var candidates: Array[BiomeDefinition] = []
	for biome in _biomes:
		if biome.matches_elevation_moisture(elevation, moisture):
			candidates.append(biome)

	if candidates.is_empty():
		# No exact band match (can happen near the extreme corners of the
		# elevation/moisture space) - fall back to whichever biome's band
		# center is closest, so every tile still resolves to something.
		var closest: BiomeDefinition = _biomes[0]
		var closest_dist := INF
		for biome in _biomes:
			var d := biome.distance_to(elevation, moisture)
			if d < closest_dist:
				closest_dist = d
				closest = biome
		return closest

	if candidates.size() == 1:
		return candidates[0]

	# Multiple bands overlap this point - pick whichever band center is
	# nearest, so borders between biomes resolve consistently rather than
	# always favoring registration order.
	var best: BiomeDefinition = candidates[0]
	var best_dist := best.distance_to(elevation, moisture)
	for biome in candidates:
		var d := biome.distance_to(elevation, moisture)
		if d < best_dist:
			best_dist = d
			best = biome
	return best


## Generates a full width x height grid of BiomeType.Type values, anchored
## at world tile (origin_x, origin_y). Useful for chunk-based streaming -
## call once per chunk with that chunk's origin.
func generate_biome_map(origin_x: int, origin_y: int, width: int, height: int) -> Array:
	var map := []
	map.resize(height)
	for y in range(height):
		var row := []
		row.resize(width)
		for x in range(width):
			row[x] = get_biome_at(origin_x + x, origin_y + y).type
		map[y] = row
	return map


## Convenience: height contribution for a tile, factoring in the winning
## biome's roughness/offset so terrain visibly differs between biomes
## (mountains spike, swamps stay low and flat, forests roll gently).
func get_terrain_height(tile_x: int, tile_y: int) -> float:
	var elevation := sample_elevation(tile_x, tile_y)
	var biome := get_biome_at(tile_x, tile_y)
	return clampf(elevation * biome.terrain_roughness + biome.elevation_offset, 0.0, 1.0)
