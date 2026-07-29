class_name MineGenerator
extends RefCounted

## Procedural underground mine generator.
## Uses two noise fields to create a natural-looking cave system with
## chambers connected by tunnels. Output is a grid of tile ids plus
## metadata (entrance positions, ore zones, enemy zones).

## Tile types used in the underground map
const TILE_WALL: String = "mine_wall"        # Impassable rock
const TILE_FLOOR: String = "mine_floor"      # Walkable cave floor
const TILE_DEEPER: String = "mine_deeper"    # Deeper/richer floor (better ores)
const TILE_WATER: String = "mine_water"      # Underground pool (hazard)

## Grid dimensions in tiles (each tile = 16 world pixels)
var grid_width: int
var grid_height: int

## The generated tile grid: grid[y][x] = tile_id string
var grid: Array

## Entrance positions in pixel coordinates (relative to the mine origin)
var entrance_positions: Array[Vector2] = []

## Chamber centers in pixel coordinates
var chamber_centers: Array[Vector2] = []

## World seed used for deterministic generation
var _seed: int

## Noise instances
var _cave_noise: FastNoiseLite
var _detail_noise: FastNoiseLite

## Radius from center for entrance offset when placing player
const ENTRANCE_SPAWN_OFFSET: float = 16.0


static func create(p_seed: int, p_width: int = 64, p_height: int = 48) -> MineGenerator:
	var gen := MineGenerator.new()
	gen._seed = p_seed
	gen.grid_width = p_width
	gen.grid_height = p_height
	gen.grid = []
	gen.entrance_positions = []
	gen.chamber_centers = []
	
	# Cave noise — determines open/closed cells
	gen._cave_noise = FastNoiseLite.new()
	gen._cave_noise.seed = p_seed
	gen._cave_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	gen._cave_noise.frequency = 0.12
	gen._cave_noise.fractal_octaves = 3
	
	# Detail noise — determines ore richness within floor cells
	gen._detail_noise = FastNoiseLite.new()
	gen._detail_noise.seed = p_seed + 1000
	gen._detail_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	gen._detail_noise.frequency = 0.06
	
	gen._generate()
	return gen


## Returns the number of entrance points
func get_entrance_count() -> int:
	return entrance_positions.size()


## Get the spawn position (pixel coords) for a given entrance index
func get_spawn_position(entrance_index: int) -> Vector2:
	if entrance_index < 0 or entrance_index >= entrance_positions.size():
		return Vector2(64, 64)
	return entrance_positions[entrance_index]


## Pixel width of the entire generated map
func get_pixel_width() -> int:
	return grid_width * 16


## Pixel height of the entire generated map
func get_pixel_height() -> int:
	return grid_height * 16


# ── Internal generation ──


func _generate() -> void:
	_step1_clear()
	_step2_cellular_carve()
	_step3_place_entrances()
	_step4_mark_deeper_zones()
	_step5_place_water()
	_step6_ensure_exit_reachable()


## Step 1: Fill the grid with an initial noise-based pattern.
func _step1_clear() -> void:
	grid.clear()
	for y in range(grid_height):
		var row: Array = []
		row.resize(grid_width)
		for x in range(grid_width):
			var n: float = _cave_noise.get_noise_2d(x, y)
			# Wider border: outer 3 cells are always wall
			if x < 3 or x >= grid_width - 3 or y < 3 or y >= grid_height - 3:
				row[x] = TILE_WALL
			elif n > -0.1:
				row[x] = TILE_FLOOR
			else:
				row[x] = TILE_WALL
		grid.append(row)


## Step 2: Run 2 iterations of cellular automata (smooth/carve).
## A cell becomes floor if it has >= 4 floor neighbours (out of 8).
## This produces natural-looking connected chambers with wider passages.
func _step2_cellular_carve() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed + 2000
	
	for iteration in range(2):
		var new_grid: Array = []
		for y in range(grid_height):
			var new_row: Array = []
			new_row.resize(grid_width)
			for x in range(grid_width):
				if x < 2 or x >= grid_width - 2 or y < 2 or y >= grid_height - 2:
					new_row[x] = TILE_WALL
					continue
				var floor_count := 0
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						if dx == 0 and dy == 0:
							continue
						var ny := y + dy
						var nx := x + dx
						if ny >= 0 and ny < grid_height and nx >= 0 and nx < grid_width:
							if grid[ny][nx] != TILE_WALL:
								floor_count += 1
				var current: String = grid[y][x]
				if current != TILE_WALL:
					# Floor survives with >= 3 floor neighbours; dies if < 2
					new_row[x] = TILE_FLOOR if floor_count >= 2 else TILE_WALL
				else:
					# Wall becomes floor with >= 5 floor neighbours (carving)
					new_row[x] = TILE_FLOOR if floor_count >= 5 else TILE_WALL
			new_grid.append(new_row)
		grid = new_grid
	
	# Identify chambers (connected floor regions) and ensure at least 3
	# usable chambers exist. If not, do extra carving passes.
	_ensure_minimum_chambers()


## Ensure the map has enough open space. Tags chamber centers.
func _ensure_minimum_chambers() -> void:
	# Flood-fill to find connected floor regions
	var visited: Dictionary = {}  # "x,y" -> chamber_id
	var chambers: Array[Array] = []  # chamber_id -> Array of Vector2i cells
	
	for y in range(grid_height):
		for x in range(grid_width):
			var key: String = "%d,%d" % [x, y]
			if visited.has(key):
				continue
			if grid[y][x] == TILE_WALL:
				visited[key] = -1
				continue
			
			# Flood fill from this cell
			var stack: Array[Vector2i] = [Vector2i(x, y)]
			var chamber_cells: Array[Vector2i] = []
			while not stack.is_empty():
				var cell: Vector2i = stack.pop_back()
				var ck: String = "%d,%d" % [cell.x, cell.y]
				if visited.has(ck):
					continue
				if grid[cell.y][cell.x] == TILE_WALL:
					continue
				visited[ck] = chambers.size()
				chamber_cells.append(cell)
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						if dx == 0 and dy == 0:
							continue
						var ny := cell.y + dy
						var nx := cell.x + dx
						if ny >= 0 and ny < grid_height and nx >= 0 and nx < grid_width:
							stack.append(Vector2i(nx, ny))
			
			if chamber_cells.size() >= 12:
				chambers.append(chamber_cells)
	
	# If we have fewer than 3 decent chambers, manually carve a path
	if chambers.size() < 3:
		_manual_carve_paths()
		return
	
	# Compute chamber centers (average of all cells in chamber)
	chamber_centers.clear()
	for chamber_cells in chambers:
		var sum_x: int = 0
		var sum_y: int = 0
		for c in chamber_cells:
			sum_x += c.x
			sum_y += c.y
		var center := Vector2(
			(sum_x / float(chamber_cells.size())) * 16 + 8,
			(sum_y / float(chamber_cells.size())) * 16 + 8
		)
		chamber_centers.append(center)
	
	# Connect chambers with tunnels if they're not already connected
	_connect_chambers(chambers)


## Carve tunnels between disconnected chambers
func _connect_chambers(chambers: Array[Array]) -> void:
	if chambers.size() < 2:
		return
	
	# Sort chambers by position (top-left first for deterministic behaviour)
	var centers: Array[Vector2i] = []
	for ch in chambers:
		var sum_x := 0
		var sum_y := 0
		for c in ch:
			sum_x += c.x
			sum_y += c.y
		centers.append(Vector2i(sum_x / ch.size(), sum_y / ch.size()))
	
	# Connect each chamber to the next nearest one (minimum spanning tree-ish)
	var connected: Array[int] = [0]
	while connected.size() < chambers.size():
		var best_dist := INF
		var best_from := -1
		var best_to := -1
		for ci in connected:
			for cj in range(chambers.size()):
				if connected.has(cj):
					continue
				var d := centers[ci].distance_squared_to(centers[cj])
				if d < best_dist:
					best_dist = d
					best_from = ci
					best_to = cj
		if best_to >= 0:
			_carve_tunnel(centers[best_from], centers[best_to])
			connected.append(best_to)


## Carve a 3-tile-wide tunnel between two points using an L-shaped path
func _carve_tunnel(from: Vector2i, to: Vector2i) -> void:
	var cx := from.x
	var cy := from.y
	
	# First go horizontally, then vertically
	while cx != to.x:
		_set_floor(cx, cy)
		_set_floor(cx + 1, cy)
		_set_floor(cx + 2, cy)
		cx += 1 if to.x > cx else -1
	while cy != to.y:
		_set_floor(cx, cy)
		_set_floor(cx + 1, cy)
		_set_floor(cx + 2, cy)
		cy += 1 if to.y > cy else -1
	_set_floor(cx, cy)
	_set_floor(cx + 1, cy)
	_set_floor(cx + 2, cy)


## Set a cell to floor if within bounds
func _set_floor(x: int, y: int) -> void:
	if x >= 0 and x < grid_width and y >= 0 and y < grid_height:
		grid[y][x] = TILE_FLOOR


## Manual carving fallback if cellular automata didn't produce enough chambers
func _manual_carve_paths() -> void:
	# Carve a few guaranteed open areas in different quadrants
	var centers_to_carve: Array[Vector2i] = [
		Vector2i(grid_width / 4, grid_height / 3),
		Vector2i(grid_width / 2, grid_height / 2),
		Vector2i(3 * grid_width / 4, 2 * grid_height / 3),
	]
	
	for c in centers_to_carve:
		_carve_circular_chamber(c.x, c.y, 6)
	
	# Connect them
	_carve_tunnel(centers_to_carve[0], centers_to_carve[1])
	_carve_tunnel(centers_to_carve[1], centers_to_carve[2])
	
	# Re-detect chambers after carving
	chamber_centers.clear()
	for c in centers_to_carve:
		chamber_centers.append(Vector2(c.x * 16 + 8, c.y * 16 + 8))


## Carve a circular chamber centered at (cx, cy) with given radius in tiles
func _carve_circular_chamber(cx: int, cy: int, radius: int) -> void:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dy * dy <= radius * radius:
				_set_floor(cx + dx, cy + dy)


## Step 3: Place entrance markers at 3 different chambers.
func _step3_place_entrances() -> void:
	entrance_positions.clear()
	
	if chamber_centers.is_empty():
		# Fallback: use hardcoded positions
		entrance_positions = [
			Vector2(64, 64),
			Vector2(grid_width * 16 - 64, 64),
			Vector2(grid_width * 8, grid_height * 16 - 64),
		]
		return
	
	# Pick up to 3 chambers as entrance locations, preferring edge chambers
	var entrances_needed := mini(3, chamber_centers.size())
	var center_of_map := Vector2(grid_width * 8, grid_height * 8)
	
	# Sort chambers by distance from center (edge chambers first)
	var with_distance: Array[Dictionary] = []
	for i in range(chamber_centers.size()):
		var dist := chamber_centers[i].distance_squared_to(center_of_map)
		with_distance.append({"idx": i, "dist": dist})
	with_distance.sort_custom(func(a, b): return a.dist > b.dist)  # furthest first
	
	for i in range(entrances_needed):
		if i < with_distance.size():
			var idx: int = with_distance[i]["idx"]
			entrance_positions.append(chamber_centers[idx])
	
	# If we still don't have 3, pad
	while entrance_positions.size() < 3:
		entrance_positions.append(Vector2(64 + entrance_positions.size() * 80, 64))


## Step 4: Mark some floor cells as "deeper" (richer ore zones)
## in a ring around chamber centers
func _step4_mark_deeper_zones() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed + 3000
	
	for y in range(grid_height):
		for x in range(grid_width):
			if grid[y][x] != TILE_FLOOR:
				continue
			# Use detail noise to mark richer zones
			var n: float = _detail_noise.get_noise_2d(x, y)
			if n > 0.3 and rng.randf() < 0.35:
				grid[y][x] = TILE_DEEPER


## Step 5: Place small water pools in low-lying areas
func _step5_place_water() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed + 4000
	
	for y in range(grid_height):
		for x in range(grid_width):
			if grid[y][x] != TILE_FLOOR:
				continue
			var n: float = _cave_noise.get_noise_2d(x + 1000, y + 1000)
			if n < -0.5 and rng.randf() < 0.2:
				# Check neighbours — water pools need surrounding floor
				var floor_neighbours := 0
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						if dx == 0 and dy == 0:
							continue
						var ny := y + dy
						var nx := x + dx
						if ny >= 0 and ny < grid_height and nx >= 0 and nx < grid_width:
							if grid[ny][nx] != TILE_WALL:
								floor_neighbours += 1
				if floor_neighbours >= 6:
					grid[y][x] = TILE_WATER


## Check if a world-pixel position is walkable (not wall)
func is_position_walkable(px: float, py: float) -> bool:
	var tx := int(px) / 16
	var ty := int(py) / 16
	if tx < 0 or tx >= grid_width or ty < 0 or ty >= grid_height:
		return false
	return grid[ty][tx] != TILE_WALL


## Get the tile ID at a pixel position
func get_tile_at(px: float, py: float) -> String:
	var tx := int(px) / 16
	var ty := int(py) / 16
	if tx < 0 or tx >= grid_width or ty < 0 or ty >= grid_height:
		return TILE_WALL
	return grid[ty][tx]


## Get ore config for a tile type and depth level
static func get_ore_for_tile(tile_id: String, depth: int) -> Array[Dictionary]:
	var base_configs: Array[Dictionary] = MineRoom.get_ore_config_for_depth(depth)
	
	if tile_id == TILE_DEEPER:
		# Richer deposits in deeper zones: more ores, higher bonus chance
		var buffed: Array[Dictionary] = []
		for cfg in base_configs:
			var c := cfg.duplicate()
			c["count"] = c["count"] + 2
			c["bonus_chance"] = minf(1.0, c["bonus_chance"] + 0.1)
			buffed.append(c)
		return buffed
	else:
		return base_configs


## Return the four cardinal neighbors of a tile position.
static func _neighbors(c: Vector2i) -> Array[Vector2i]:
	return [
		Vector2i(c.x, c.y - 1),
		Vector2i(c.x, c.y + 1),
		Vector2i(c.x - 1, c.y),
		Vector2i(c.x + 1, c.y),
	]


## Step 6: Ensure the player can reach the exit chamber from the entrance.
## If the exit cell isn't reachable via 4-directional movement, carve a
## direct L-shaped tunnel to guarantee a path.
func _step6_ensure_exit_reachable() -> void:
	if entrance_positions.is_empty():
		return

	var start_tile := Vector2i(
		int(entrance_positions[0].x) / 16,
		int(entrance_positions[0].y) / 16
	)

	# Find exit chamber (same logic as MineRoom._generate_exit_area)
	var center_map := Vector2(grid_width / 2.0, grid_height / 2.0)
	var exit_center: Vector2 = center_map
	var best_dist := INF
	for ch in chamber_centers:
		var d := ch.distance_squared_to(center_map * 16.0)
		if d < best_dist:
			best_dist = d
			exit_center = ch
	var exit_tile := Vector2i(int(exit_center.x) / 16, int(exit_center.y) / 16)

	# 4-directional BFS from start to exit cell
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [start_tile]
	visited["%d,%d" % [start_tile.x, start_tile.y]] = true
	var found := false
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if c == exit_tile:
			found = true
			break
		for neighbor in _neighbors(c):
			var key := "%d,%d" % [neighbor.x, neighbor.y]
			if visited.has(key):
				continue
			if neighbor.x < 0 or neighbor.x >= grid_width or neighbor.y < 0 or neighbor.y >= grid_height:
				continue
			if grid[neighbor.y][neighbor.x] == TILE_WALL:
				continue
			visited[key] = true
			queue.append(neighbor)

	if not found:
		# Carve a direct L-shaped 3-wide tunnel from entrance to exit
		_carve_tunnel(start_tile, exit_tile)
