class_name WorldGenerator
extends RefCounted

## Pure procedural-generation logic, kept separate from World.gd so it can be
## unit tested, reused (e.g. for a minimap or a new biome), or swapped out
## entirely without touching scene/node code.

var noise: FastNoiseLite
var width: int
var height: int

static func create(p_width: int, p_height: int, p_seed: int = 0) -> WorldGenerator:
	var generator := WorldGenerator.new()
	generator.width = p_width
	generator.height = p_height
	generator.noise = FastNoiseLite.new()
	generator.noise.seed = p_seed
	generator.noise.noise_type = FastNoiseLite.TYPE_PERLIN
	generator.noise.frequency = 0.08
	return generator

func _init(p_width: int = 0, p_height: int = 0, p_seed: int = 0) -> void:
	width = p_width
	height = p_height
	if p_width > 0 and p_height > 0:
		noise = FastNoiseLite.new()
		noise.seed = p_seed
		noise.noise_type = FastNoiseLite.TYPE_PERLIN
		noise.frequency = 0.08

## Returns a 2D array (Array of Array) of TileTypeData ids, one per cell,
## chosen by feeding noise values through the tile types registered in
## DataManager. Applies an island-falloff mask so the world has a ragged,
## organic shape surrounded by water.
func generate_tile_grid() -> Array:
	var tile_types: Array = DataManager.get_all_tile_types()
	var grid: Array = []
	grid.resize(height)

	# Pre-compute the island mask using a separate noise field at a
	# lower frequency so coastlines are ragged but not micro-pixelated.
	var island_noise := FastNoiseLite.new()
	island_noise.seed = noise.seed + 9999
	island_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	island_noise.frequency = 0.03

	for y in range(height):
		var row: Array = []
		row.resize(width)
		for x in range(width):
			if _is_island_cell(x, y, island_noise):
				var n: float = noise.get_noise_2d(x, y)
				row[x] = _pick_tile_type_id(n, tile_types)
			else:
				row[x] = "water"
		grid[y] = row
	return grid

## Returns true if the cell (x, y) should be land rather than water.
## Combines a distance-based falloff from centre with Perlin noise
## perturbation so the coastline is ragged and natural-looking.
func _is_island_cell(x: int, y: int, island_noise: FastNoiseLite) -> bool:
	# Normalise coords so that (0,0) is the centre and
	# (-1,-1) .. (1,1) spans the whole grid.
	var nx := (x / float(width)) * 2.0 - 1.0
	var ny := (y / float(height)) * 2.0 - 1.0

	# Base distance from centre (0 = centre, 1 ≈ corner).
	var dist := sqrt(nx * nx + ny * ny)

	# Perturb the falloff with noise so the coastline varies
	# organically instead of being a perfect circle.
	var perturb := island_noise.get_noise_2d(x, y) * 0.25

	# Stretch the island slightly along the 45° diagonal for
	# a more organic overall shape (less perfectly round).
	var stretch_nx := nx * 0.85 + ny * 0.15
	var stretch_ny := ny * 0.85 + nx * 0.15
	var stretch_dist := sqrt(stretch_nx * stretch_nx + stretch_ny * stretch_ny)
	dist = lerpf(dist, stretch_dist, 0.25)

	# Scale island radius so the island occupies roughly 55% of the grid,
	# leaving a generous water buffer around the edge (no gray void).
	var island_radius := 0.58
	var modified_dist := dist + perturb

	return modified_dist < island_radius

func _pick_tile_type_id(noise_value: float, tile_types: Array) -> String:
	for tile_type in tile_types:
		if noise_value >= tile_type.noise_min and noise_value <= tile_type.noise_max:
			return tile_type.id
	# Fallback: closest match by distance to range.
	var best_id := "grass"
	var best_dist := INF
	for tile_type in tile_types:
		var mid: float = (tile_type.noise_min + tile_type.noise_max) * 0.5
		var dist: float = abs(noise_value - mid)
		if dist < best_dist:
			best_dist = dist
			best_id = tile_type.id
	return best_id

## Returns a list of grid positions suitable for scattering interactable
## objects (e.g. rocks), avoiding non-walkable tiles.
func pick_object_positions(grid: Array, count: int, rng: RandomNumberGenerator) -> Array:
	var positions: Array = []
	var attempts: int = 0
	while positions.size() < count and attempts < count * 20:
		attempts += 1
		var x := rng.randi_range(0, width - 1)
		var y := rng.randi_range(0, height - 1)
		var tile_id: String = grid[y][x]
		var tile_type: TileTypeData = DataManager.get_tile_type(tile_id)
		if tile_type and tile_type.walkable and tile_type.id != "water":
			positions.append(Vector2i(x, y))
	return positions
