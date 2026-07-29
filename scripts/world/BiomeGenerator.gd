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
@export var biome_scale: float = 0.008


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
	return hash(str(world_seed) + ":" + tag)


## Returns normalized [0,1] elevation at a tile coordinate.
func sample_elevation(tile_x: int, tile_y: int) -> float:
	return (elevation_noise.get_noise_2d(tile_x, tile_y) + 1.0) * 0.5


## Returns normalized [0,1] moisture at a tile coordinate.
func sample_moisture(tile_x: int, tile_y: int) -> float:
	return (moisture_noise.get_noise_2d(tile_x, tile_y) + 1.0) * 0.5


## Resolves the winning BiomeDefinition for a single tile.
## If is_land is false, returns null (caller handles water tiles).
## For land tiles, uses closest-center among all biomes so every biome
## has a chance to appear regardless of elevation/moisture distribution.
func get_biome_at(tile_x: int, tile_y: int, is_land: bool = true) -> BiomeDefinition:
	if not is_land:
		return null
	var elevation := sample_elevation(tile_x, tile_y)
	var moisture := sample_moisture(tile_x, tile_y)
	var result := _classify(elevation, moisture, true)
	return result


func _classify(elevation: float, moisture: float, force_all: bool = false) -> BiomeDefinition:
	if force_all:
		# Use closest-center across ALL biomes so every biome always gets
		# some tiles regardless of the elevation/moisture distribution.
		var closest: BiomeDefinition = _biomes[0]
		var closest_dist := INF
		for biome in _biomes:
			var d := biome.distance_to(elevation, moisture)
			if d < closest_dist:
				closest_dist = d
				closest = biome
		return closest
	
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


## Post-processes a biome map to remove single-tile noise speckles and
## enforce a minimum patch size (MIN_CLUSTER). Any contiguous biome cluster
## smaller than MIN_CLUSTER tiles gets converted to the dominant biome
## among its neighbouring cells.
func smooth_biome_map(map: Array, width: int, height: int) -> void:
	const MIN_CLUSTER: int = 2  # any patch smaller than this gets absorbed (was 4)

	# 1) Flood-fill to find all contiguous clusters
	var visited: Array = []
	visited.resize(height)
	for y in range(height):
		visited[y] = []
		visited[y].resize(width)
		for x in range(width):
			visited[y][x] = false

	var clusters: Array[Dictionary] = []  # each: {type, cells:Array[Vector2i]}

	for y in range(height):
		for x in range(width):
			if visited[y][x]:
				continue
			var biome_type := map[y][x] as int
			if biome_type < 0:
				visited[y][x] = true
				continue  # water, skip

			# BFS flood-fill
			var stack: Array[Vector2i] = [Vector2i(x, y)]
			var cluster_cells: Array[Vector2i] = []
			while not stack.is_empty():
				var c: Vector2i = stack.pop_back()
				if c.x < 0 or c.x >= width or c.y < 0 or c.y >= height:
					continue
				if visited[c.y][c.x]:
					continue
				if map[c.y][c.x] != biome_type:
					continue
				visited[c.y][c.x] = true
				cluster_cells.append(c)
				stack.append(Vector2i(c.x + 1, c.y))
				stack.append(Vector2i(c.x - 1, c.y))
				stack.append(Vector2i(c.x, c.y + 1))
				stack.append(Vector2i(c.x, c.y - 1))

			if cluster_cells.size() > 0:
				clusters.append({"type": biome_type, "cells": cluster_cells})

	# 2) Merge clusters smaller than MIN_CLUSTER into the most common
	#    biome among their edge neighbours
	for cluster in clusters:
		if cluster["cells"].size() >= MIN_CLUSTER:
			continue
		var small_type: int = cluster["type"]
		var neighbour_votes: Dictionary = {}
		for cell in (cluster["cells"] as Array[Vector2i]):
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nc: Vector2i = cell + d
				if nc.x < 0 or nc.x >= width or nc.y < 0 or nc.y >= height:
					continue
				var nt: int = map[nc.y][nc.x]
				if nt >= 0 and nt != small_type:
					neighbour_votes[nt] = neighbour_votes.get(nt, 0) + 1

		if neighbour_votes.is_empty():
			continue

		# Pick the most common neighbour type
		var best_neighbour: int = -1
		var best_count: int = 0
		for nt in neighbour_votes:
			if neighbour_votes[nt] > best_count:
				best_count = neighbour_votes[nt]
				best_neighbour = nt

		if best_neighbour >= 0:
			for cell in (cluster["cells"] as Array[Vector2i]):
				map[cell.y][cell.x] = best_neighbour


## Ensures every registered biome gets at least a minimum number of tiles.
## After smoothing, rare biomes may have been completely eliminated. This
## post-process finds any biome with fewer than MIN_TILES tiles and grows a
## compact contiguous patch from its best seed cell.
func guarantee_biomes(map: Array, width: int, height: int) -> void:
	const MIN_TILES: int = 16  # each biome should have at least this many tiles

	# Count current tiles per biome index
	var counts: Dictionary = {}
	for y in range(height):
		for x in range(width):
			var idx: int = map[y][x]
			if idx >= 0:
				counts[idx] = counts.get(idx, 0) + 1

	# Find which biomes are underrepresented
	var underrep: Array[Dictionary] = []
	for i in _biomes.size():
		var cnt: int = counts.get(i, 0)
		if cnt < MIN_TILES:
			underrep.append({"idx": i, "count": cnt})

	if underrep.is_empty():
		return  # all good

	# Sort so the most-starved biome (fewest tiles) processes first, preventing
	# a less-starved biome from sniping the best seed location.
	underrep.sort_custom(func(a, b): return a.count < b.count)

	# For each underrepresented biome: find its best seed cell, then BFS out
	for entry in underrep:
		var bi: int = entry.idx
		# Find the single best seed cell for this biome
		var best_cell: Vector2i = Vector2i(-1, -1)
		var best_dist := INF
		for y in range(height):
			for x in range(width):
				if map[y][x] < 0:
					continue  # water — can't convert
				var elev: float = sample_elevation(x, y)
				var moist: float = sample_moisture(x, y)
				var d := _biomes[bi].distance_to(elev, moist)
				if d < best_dist:
					best_dist = d
					best_cell = Vector2i(x, y)

		if best_cell.x < 0:
			continue  # no valid land cell found (shouldn't happen)

		# Convert the seed cell
		map[best_cell.y][best_cell.x] = bi
		var placed: int = 1

		# BFS outward from seed to grow a compact contiguous patch.
		var dirs: Array[Vector2i] = [
			Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
		]
		var queue: Array[Vector2i] = [best_cell]
		while placed < MIN_TILES and not queue.is_empty():
			var current: Vector2i = queue.pop_front()
			for d in dirs:
				if placed >= MIN_TILES:
					break
				var nc: Vector2i = current + d
				if nc.x < 0 or nc.x >= width or nc.y < 0 or nc.y >= height:
					continue
				if map[nc.y][nc.x] >= 0 and map[nc.y][nc.x] != bi:
					map[nc.y][nc.x] = bi
					placed += 1
					queue.append(nc)

		# If BFS ran out before reaching MIN_TILES, scan all land tiles by
		# distance-to-center and convert the closest ones that aren't already
		# this biome. This handles biomes with very narrow bands that have few
		# contiguous neighbours.
		if placed < MIN_TILES:
			var candidates: Array[Dictionary] = []
			for y in range(height):
				for x in range(width):
					if map[y][x] >= 0 and map[y][x] != bi:
						var elev: float = sample_elevation(x, y)
						var moist: float = sample_moisture(x, y)
						var d := _biomes[bi].distance_to(elev, moist)
						candidates.append({"cell": Vector2i(x, y), "dist": d})
			candidates.sort_custom(func(a, b): return a.dist < b.dist)
			for cand in candidates:
				if placed >= MIN_TILES:
					break
				var nc: Vector2i = cand.cell
				if map[nc.y][nc.x] >= 0 and map[nc.y][nc.x] != bi:
					map[nc.y][nc.x] = bi
					placed += 1

	# Final re-check: biomes processed first may have had tiles stolen by later
	# biomes. Run guarantee once more only for biomes still below MIN_TILES.
	var final_counts: Dictionary = {}
	for y in range(height):
		for x in range(width):
			var idx: int = map[y][x]
			if idx >= 0:
				final_counts[idx] = final_counts.get(idx, 0) + 1
	for i in _biomes.size():
		if final_counts.get(i, 0) < MIN_TILES:
			# Steal one tile from the largest biome to fix the count
			var richest_biome: int = 0
			var richest_count: int = 0
			for j in _biomes.size():
				var c: int = final_counts.get(j, 0)
				if c > richest_count and j != i:
					richest_count = c
					richest_biome = j
			if richest_biome >= 0 and richest_count > 0:
				for y in range(height):
					var done: bool = false
					for x in range(width):
						if map[y][x] == richest_biome:
							map[y][x] = i
							final_counts[i] = final_counts.get(i, 0) + 1
							final_counts[richest_biome] -= 1
							if final_counts[i] >= MIN_TILES:
								done = true
								break
					if done:
						break


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


## Returns the internal biome list (same object references used by get_biome_at).
func get_biomes() -> Array[BiomeDefinition]:
	return _biomes


## Returns the BiomeDefinition for a given BiomeType.Type enum value.
func get_biome_by_type(biome_type: int) -> BiomeDefinition:
	for biome in _biomes:
		if biome.type == biome_type:
			return biome
	return null


## Convenience: height contribution for a tile, factoring in the winning
## biome's roughness/offset so terrain visibly differs between biomes
## (mountains spike, swamps stay low and flat, forests roll gently).
func get_terrain_height(tile_x: int, tile_y: int) -> float:
	var elevation := sample_elevation(tile_x, tile_y)
	var biome := get_biome_at(tile_x, tile_y)
	return clampf(elevation * biome.terrain_roughness + biome.elevation_offset, 0.0, 1.0)
