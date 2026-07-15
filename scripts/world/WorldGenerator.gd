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
## DataManager. Keeping the tile catalogue in DataManager means new biomes
## or tile types can be added without changing this function.
func generate_tile_grid() -> Array:
	var tile_types: Array = DataManager.get_all_tile_types()
	var grid: Array = []
	grid.resize(height)
	for y in range(height):
		var row: Array = []
		row.resize(width)
		for x in range(width):
			var n: float = noise.get_noise_2d(x, y)
			row[x] = _pick_tile_type_id(n, tile_types)
		grid[y] = row
	return grid

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
