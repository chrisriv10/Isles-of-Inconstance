class_name ResourceSpawner
extends RefCounted

## Places resource nodes (trees, berries, mushrooms, rare plants, crystals,
## etc.) across the world according to each tile's biome. All placement is
## driven by a RandomNumberGenerator reseeded per-chunk from the world seed
## plus chunk coordinates, so a given world seed always spawns the exact
## same resources in the exact same places.

var biome_generator: BiomeGenerator
var world_seed: int

const RESULT_RESOURCE_ID := "resource_id"
const RESULT_TILE := "tile"
const RESULT_SCENE_PATH := "scene_path"


func _init(generator: BiomeGenerator) -> void:
	biome_generator = generator
	world_seed = generator.world_seed


## Returns an Array of Dictionaries describing every resource to spawn in
## the chunk anchored at (origin_x, origin_y) with the given tile
## dimensions. Each dict has: resource_id, tile (Vector2i), scene_path.
func spawn_resources_for_chunk(origin_x: int, origin_y: int, width: int, height: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = _chunk_seed(origin_x, origin_y)

	var results: Array = []
	var occupied: Dictionary = {}

	# Group tiles by biome so each biome's resource table only rolls once
	# per candidate tile, weighted by that biome's own resource_density.
	for y in range(height):
		for x in range(width):
			var tile_x := origin_x + x
			var tile_y := origin_y + y
			var biome := biome_generator.get_biome_at(tile_x, tile_y)
			if biome.resources.is_empty():
				continue

			var roll := rng.randf() * 100.0
			if roll > biome.resource_density:
				continue

			var entry := _pick_weighted_entry(biome.resources, rng)
			if entry == null:
				continue

			var key := Vector2i(tile_x, tile_y)
			if _too_close(key, entry.resource_id, entry.min_spacing, occupied):
				continue

			occupied[key] = entry.resource_id
			results.append({
				RESULT_RESOURCE_ID: entry.resource_id,
				RESULT_TILE: key,
				RESULT_SCENE_PATH: entry.scene_path,
			})

			if entry.clusters:
				_spawn_cluster(entry, key, rng, occupied, results)

	return results


func _spawn_cluster(entry: ResourceSpawnEntry, center: Vector2i, rng: RandomNumberGenerator,
		occupied: Dictionary, results: Array) -> void:
	var cluster_count := rng.randi_range(entry.cluster_size_range.x, entry.cluster_size_range.y)
	for i in range(cluster_count):
		var offset := Vector2i(rng.randi_range(-2, 2), rng.randi_range(-2, 2))
		var tile := center + offset
		if tile == center:
			continue
		if _too_close(tile, entry.resource_id, entry.min_spacing, occupied):
			continue
		occupied[tile] = entry.resource_id
		results.append({
			RESULT_RESOURCE_ID: entry.resource_id,
			RESULT_TILE: tile,
			RESULT_SCENE_PATH: entry.scene_path,
		})


func _pick_weighted_entry(entries: Array[ResourceSpawnEntry],
		rng: RandomNumberGenerator) -> ResourceSpawnEntry:
	var total_weight := 0.0
	for entry in entries:
		total_weight += entry.weight
	if total_weight <= 0.0:
		return null

	var roll := rng.randf() * total_weight
	var cursor := 0.0
	for entry in entries:
		cursor += entry.weight
		if roll <= cursor:
			return entry
	return entries[entries.size() - 1]


func _too_close(tile: Vector2i, resource_id: String, min_spacing: int,
		occupied: Dictionary) -> bool:
	if min_spacing <= 0:
		return false
	for other_tile in occupied.keys():
		if occupied[other_tile] != resource_id:
			continue
		if tile.distance_to(other_tile) < min_spacing:
			return true
	return false


## Deterministic per-chunk seed derived from the world seed and chunk
## origin, so re-visiting the same chunk always regenerates identical
## resource placement without needing to persist it.
func _chunk_seed(origin_x: int, origin_y: int) -> int:
	return hash(str(world_seed) + ":resources:" + str(origin_x) + "," + str(origin_y))
