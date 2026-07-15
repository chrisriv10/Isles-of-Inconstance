class_name WorldGenerator
extends RefCounted

## Entry point for the biome-aware procedural world system. Wraps
## BiomeGenerator (terrain/biome layout), ResourceSpawner (trees, berries,
## mushrooms, rare plants, crystals, etc.), and CropTraitGenerator (unique
## per-biome crop variants) behind a single seed.
##
## var world := WorldGenerator.new(world_seed)
## var chunk := world.generate_chunk(chunk_x * CHUNK_SIZE, chunk_y * CHUNK_SIZE, CHUNK_SIZE, CHUNK_SIZE)
## # chunk.biome_map[y][x]      -> BiomeType.Type
## # chunk.resources            -> Array of {resource_id, tile, scene_path}

var world_seed: int
var biome_generator: BiomeGenerator
var resource_spawner: ResourceSpawner
var crop_trait_generator: CropTraitGenerator


func _init(seed_value: int) -> void:
	world_seed = seed_value
	biome_generator = BiomeGenerator.new(seed_value)
	resource_spawner = ResourceSpawner.new(biome_generator)
	crop_trait_generator = CropTraitGenerator.new(seed_value)


## Generates everything needed to build one chunk of the world: the biome
## map, per-tile terrain height, and resource spawn list. Deterministic -
## calling this twice with the same arguments always returns identical data.
func generate_chunk(origin_x: int, origin_y: int, width: int, height: int) -> WorldChunk:
	var chunk := WorldChunk.new()
	chunk.origin = Vector2i(origin_x, origin_y)
	chunk.size = Vector2i(width, height)
	chunk.biome_map = biome_generator.generate_biome_map(origin_x, origin_y, width, height)
	chunk.height_map = _generate_height_map(origin_x, origin_y, width, height)
	chunk.resources = resource_spawner.spawn_resources_for_chunk(origin_x, origin_y, width, height)
	return chunk


func _generate_height_map(origin_x: int, origin_y: int, width: int, height: int) -> Array:
	var map := []
	map.resize(height)
	for y in range(height):
		var row := []
		row.resize(width)
		for x in range(width):
			row[x] = biome_generator.get_terrain_height(origin_x + x, origin_y + y)
		map[y] = row
	return map


func get_biome_at(tile_x: int, tile_y: int) -> BiomeDefinition:
	return biome_generator.get_biome_at(tile_x, tile_y)


## Plants a crop at (tile_x, tile_y), returning a CropData duplicate
## flavored with that tile's biome traits (growth/yield multipliers,
## biome-exclusive trait tags, and a chance at a unique named variant).
func plant_crop(base_crop, tile_x: int, tile_y: int):
	var biome := get_biome_at(tile_x, tile_y)
	return crop_trait_generator.apply_biome_traits(base_crop, biome, tile_x, tile_y)


## Convenience for UI/debug: human-readable biome name at a tile.
func get_biome_name_at(tile_x: int, tile_y: int) -> String:
	return get_biome_at(tile_x, tile_y).display_name
