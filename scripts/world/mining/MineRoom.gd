extends Node2D
class_name MineRoom

## A procedurally generated underground mine that the player enters
## through a mine entrance in the overworld.
##
## Uses MineGenerator to create a multi-chamber cave system with
## tunnels, ore deposits, enemies, and hazards.
##
## Supports multi-level descent (Stardew-style): find the shaft to
## descend deeper, or use the exit ladder to return to the surface.
##
## Uses the same void-position pattern as BuildingInterior.

## Mine depth level (1-6+). Higher = better ores and tougher enemies.
@export var depth_level: int = 1

## Maximum depth that allows descending further
const MAX_DESCENT_DEPTH: int = 6

## How often (seconds) the mine checks and respawns enemies.
const ENEMY_RESPAWN_INTERVAL: float = 40.0

## How close to the target count the respawn tries to replenish (fraction).
const RESPAWN_FILL_RATIO: float = 0.7

## Which entrance index to spawn at (0, 1, or 2).
## Set by World before _ready() to determine spawn location.
var entrance_index: int = 0

## Deterministic enemy id counter — both peers generate the room in the same
## order, so assigning ids here makes host broadcasts resolve to matching
## remote copies on clients (same pattern as overworld Enemy.enemy_id).
var _next_enemy_id: int = 0

## Reference to the MineGenerator for this underground instance
var generator: MineGenerator = null

## Exited signal — World connects to this to return the player
signal exited()

## Descended signal — emitted when player takes the shaft to go deeper
signal descended(new_depth: int)

## Ore deposit scene
const ORE_DEPOSIT_SCENE := preload("res://scenes/world/mine_objects/OreDeposit.tscn")

## Enemy scenes
const CAVE_CRAWLER_SCENE := preload("res://scenes/world/mine_objects/CaveCrawler.tscn")
const STONE_GOLEM_SCENE := preload("res://scenes/world/mine_objects/StoneGolem.tscn")
const CAVE_BAT_SCENE := preload("res://scenes/world/mine_objects/CaveBat.tscn")

## Enemy type keys used by the host-authoritative respawn broadcast
const MINE_ENEMY_CRAWLER: int = 0
const MINE_ENEMY_GOLEM: int = 1
const MINE_ENEMY_BAT: int = 2

## Preloaded textures
const ENTRANCE_LADDER := preload("res://assets/generated/mine_exit_ladder_frame_0.png")
const DESCENDING_SHAFT := preload("res://assets/generated/mine_exit_ladder_frame_0.png")  # reuse ladder for now

## Tile texture images (loaded at runtime for direct pixel access)
## Preloaded textures + get_image() (NOT Image.load_from_file, which can't read
## project-imported assets reliably and returns null → flat untextured tiles).
const CAVE_FLOOR_TEX := preload("res://assets/generated/cave_floor_tile.png")
const CAVE_WALL_TEX := preload("res://assets/generated/cave_wall_tile.png")
const CAVE_WATER_TEX := preload("res://assets/generated/water_base_48.png")
var _cave_floor_img: Image = null
var _cave_wall_img: Image = null
var _cave_water_img: Image = null

## Tile image colours for underground mine — dim but visible
const COLOR_FLOOR := Color(0.18, 0.16, 0.14)
const COLOR_DEEPER := Color(0.25, 0.20, 0.16)
const COLOR_WALL := Color(0.07, 0.06, 0.05)
const COLOR_WATER := Color(0.04, 0.06, 0.18)
const COLOR_WALL_EDGE := Color(0.12, 0.10, 0.08)

## Water shimmer animation speed
const WATER_SHIMMER_SPEED := 1.5

## How the generator maps to our world space
const TILE_PX: int = 16

## Container for collision wall segments
var _wall_body: StaticBody2D = null

## RNG for deterministic placement
var _rng: RandomNumberGenerator = null

## Ambient audio player
var _ambient_player: AudioStreamPlayer2D = null

## Dust particle emitter
var _dust_particles: GPUParticles2D = null

## Water shimmer timer
var _water_shimmer_time: float = 0.0

## Mine depth label (in-world HUD element)
var _depth_label: Label = null

## E-press proximity tracking for exit ladder
var _player_near_exit: bool = false

## E-press proximity tracking for descent shaft
var _player_near_shaft: bool = false

## Timer for periodic enemy respawn
var _enemy_respawn_timer: Timer = null

## Cached floor cells for respawn (populated during initial spawn)
var _respawn_floor_cells: Array[Vector2i] = []

## Ore configuration per depth level
## Depths 1-3: copper, coal, stone, iron, gold
## Depths 4-6: silver, diamond, ruby, obsidian with gems as bonuses
static func get_ore_config_for_depth(depth: int) -> Array[Dictionary]:
	match depth:
		1:
			return [
				{"type": "copper_ore", "max_hits": 4, "min": 1, "max": 3, "bonus_chance": 0.0, "bonus": "", "count": 5},
				{"type": "coal",       "max_hits": 3, "min": 1, "max": 2, "bonus_chance": 0.0, "bonus": "", "count": 4},
				{"type": "stone",      "max_hits": 2, "min": 1, "max": 2, "bonus_chance": 0.0, "bonus": "", "count": 6},
			]
		2:
			return [
				{"type": "iron_ore",   "max_hits": 5, "min": 1, "max": 3, "bonus_chance": 0.05, "bonus": "gold_nugget", "count": 5},
				{"type": "coal",       "max_hits": 4, "min": 2, "max": 3, "bonus_chance": 0.0,  "bonus": "", "count": 3},
				{"type": "copper_ore", "max_hits": 4, "min": 1, "max": 2, "bonus_chance": 0.0,  "bonus": "", "count": 3},
			]
		3:
			return [
				{"type": "gold_ore",   "max_hits": 6, "min": 1, "max": 2, "bonus_chance": 0.1, "bonus": "gold_nugget", "count": 4},
				{"type": "iron_ore",   "max_hits": 5, "min": 2, "max": 3, "bonus_chance": 0.05, "bonus": "gold_nugget", "count": 3},
				{"type": "coal",       "max_hits": 4, "min": 2, "max": 4, "bonus_chance": 0.0,  "bonus": "", "count": 2},
			]
		4:
			return [
				{"type": "silver_ore", "max_hits": 6, "min": 1, "max": 3, "bonus_chance": 0.08, "bonus": "gold_nugget", "count": 4},
				{"type": "gold_ore",   "max_hits": 5, "min": 2, "max": 3, "bonus_chance": 0.12, "bonus": "gold_nugget", "count": 3},
				{"type": "iron_ore",   "max_hits": 5, "min": 2, "max": 4, "bonus_chance": 0.05, "bonus": "gold_nugget", "count": 4},
				{"type": "coal",       "max_hits": 5, "min": 3, "max": 5, "bonus_chance": 0.0,  "bonus": "", "count": 2},
			]
		5:
			return [
				{"type": "diamond_ore", "max_hits": 7, "min": 1, "max": 2, "bonus_chance": 0.15, "bonus": "diamond_gem", "count": 3},
				{"type": "ruby_ore",    "max_hits": 7, "min": 1, "max": 2, "bonus_chance": 0.15, "bonus": "ruby_gem", "count": 3},
				{"type": "silver_ore",  "max_hits": 6, "min": 2, "max": 3, "bonus_chance": 0.1,  "bonus": "gold_nugget", "count": 3},
				{"type": "coal",       "max_hits": 5, "min": 3, "max": 5, "bonus_chance": 0.0,  "bonus": "", "count": 2},
			]
		_:
			return [
				{"type": "obsidian_ore", "max_hits": 8, "min": 1, "max": 2, "bonus_chance": 0.2, "bonus": "obsidian_shard", "count": 4},
				{"type": "diamond_ore",  "max_hits": 7, "min": 2, "max": 3, "bonus_chance": 0.2, "bonus": "diamond_gem", "count": 3},
				{"type": "ruby_ore",     "max_hits": 7, "min": 2, "max": 3, "bonus_chance": 0.2, "bonus": "ruby_gem", "count": 3},
				{"type": "silver_ore",   "max_hits": 6, "min": 2, "max": 4, "bonus_chance": 0.15, "bonus": "gold_nugget", "count": 3},
				{"type": "coal",         "max_hits": 6, "min": 3, "max": 6, "bonus_chance": 0.0,  "bonus": "", "count": 2},
			]

static func get_enemy_count(depth: int) -> int:
	if depth <= 1:
		return 3
	elif depth <= 2:
		return 5
	elif depth <= 3:
		return 7
	elif depth <= 4:
		return 9
	elif depth <= 5:
		return 11
	else:
		return 13

static func get_enemy_hp_multiplier(depth: int) -> float:
	return 1.0 + (depth - 1) * 0.3


func _ready() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = depth_level * 1000 + entrance_index
	
	# Load tile textures for rocky appearance
	_cave_floor_img = CAVE_FLOOR_TEX.get_image()
	_cave_wall_img = CAVE_WALL_TEX.get_image()
	_cave_water_img = CAVE_WATER_TEX.get_image()
	
	_generate_underground()
	_generate_exit_area()
	
	# Generate shaft to deeper levels (if not at max depth)
	if depth_level < MAX_DESCENT_DEPTH:
		_generate_descent_shaft()
	
	# Visual atmosphere
	_setup_ambient_lighting()
	_setup_dust_particles()
	_setup_mine_ambient_audio()
	_setup_depth_label()
	
	# Start enemy respawn timer (always active — mine is underground, day/night doesn't matter)
	_setup_enemy_respawn()


## Paint the entire underground from the generator's tile grid.
func _generate_underground() -> void:
	if generator == null or generator.grid.is_empty():
		# Fallback: generate a default generator
		generator = MineGenerator.create(abs(hash(str(depth_level))), 64, 48)
	
	var g_w := generator.grid_width
	var g_h := generator.grid_height
	var pixel_w := g_w * TILE_PX
	var pixel_h := g_h * TILE_PX
	
	# Background darkness
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.01, 0.02)
	bg.size = Vector2(pixel_w, pixel_h)
	bg.position = Vector2.ZERO
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	
	# Draw floor + wall tiles to a single image for performance
	var map_img := Image.create(pixel_w, pixel_h, false, Image.FORMAT_RGBA8)
	map_img.fill(Color(0.0, 0.0, 0.0, 0.0))  # transparent background
	
	# Water tiles get their own overlay so they can shimmer independently
	_water_overlay_img = Image.create(pixel_w, pixel_h, false, Image.FORMAT_RGBA8)
	_water_overlay_img.fill(Color(0.0, 0.0, 0.0, 0.0))
	
	for y in range(g_h):
		for x in range(g_w):
			var tile_id: String = generator.grid[y][x]
			var px := x * TILE_PX
			var py := y * TILE_PX
			
			match tile_id:
				MineGenerator.TILE_FLOOR:
					_draw_simple_tile(map_img, px, py, TILE_PX, COLOR_FLOOR)
				MineGenerator.TILE_DEEPER:
					_draw_simple_tile(map_img, px, py, TILE_PX, COLOR_DEEPER)
				MineGenerator.TILE_WALL:
					_draw_wall_tile(map_img, px, py, TILE_PX, x, y)
				MineGenerator.TILE_WATER:
					_draw_water_tile(_water_overlay_img, px, py, TILE_PX, x, y)
	
	var map_sprite := Sprite2D.new()
	map_sprite.texture = ImageTexture.create_from_image(map_img)
	map_sprite.centered = false
	map_sprite.position = Vector2.ZERO
	map_sprite.z_index = 1
	add_child(map_sprite)
	
	# Water shimmer overlay — sits on top of the shadow, refreshed periodically
	_water_overlay_sprite = Sprite2D.new()
	_water_overlay_sprite.texture = ImageTexture.create_from_image(_water_overlay_img)
	_water_overlay_sprite.centered = false
	_water_overlay_sprite.position = Vector2.ZERO
	_water_overlay_sprite.z_index = 4
	add_child(_water_overlay_sprite)
	
	# Build collision walls around all wall tiles
	_wall_body = StaticBody2D.new()
	_wall_body.z_index = 3
	add_child(_wall_body)
	
	for y in range(g_h):
		for x in range(g_w):
			if generator.grid[y][x] == MineGenerator.TILE_WALL:
				_add_wall_collision(x, y)
	
	# Place ore deposits on floor tiles
	_place_ores()
	
	# Spawn enemies on floor tiles
	_spawn_enemies()
	
	# Depth-based darkness overlay — deeper = darker
	var darkness_alpha: float = 0.08 + clampf(depth_level * 0.04, 0.0, 0.35)
	var shadow_img := Image.create(pixel_w, pixel_h, false, Image.FORMAT_RGBA8)
	shadow_img.fill(Color(0.0, 0.0, 0.0, darkness_alpha))
	var shadow_sprite := Sprite2D.new()
	shadow_sprite.texture = ImageTexture.create_from_image(shadow_img)
	shadow_sprite.centered = false
	shadow_sprite.position = Vector2.ZERO
	shadow_sprite.z_index = 2
	add_child(shadow_sprite)


## Draw a floor tile using the rocky cave floor texture with tinting
func _draw_simple_tile(img: Image, px: int, py: int, size: int, color: Color) -> void:
	if _cave_floor_img != null:
		# Use the rocky texture blended with the tile color
		for dy in range(size):
			for dx in range(size):
				var texel: Color = _cave_floor_img.get_pixel(dx % _cave_floor_img.get_width(), dy % _cave_floor_img.get_height())
				var blended := Color(
					color.r * (0.3 + 0.7 * texel.r),
					color.g * (0.3 + 0.7 * texel.g),
					color.b * (0.3 + 0.7 * texel.b),
					1.0
				)
				img.set_pixel(px + dx, py + dy, blended)
	else:
		# Fallback: flat color
		for dy in range(size):
			for dx in range(size):
				img.set_pixel(px + dx, py + dy, color)
	# Subtle edge highlight for depth
	var edge := Color(color.r * 1.12, color.g * 1.12, color.b * 1.12)
	for dx in range(size):
		img.set_pixel(px + dx, py, edge)
		img.set_pixel(px, py + dx, Color(color.r * 1.08, color.g * 1.08, color.b * 1.08))


## Draw a wall tile using the cave wall texture with tinting
func _draw_wall_tile(img: Image, px: int, py: int, size: int, gx: int, gy: int) -> void:
	if _cave_wall_img != null:
		# Use the rocky wall texture blended with wall color
		for dy in range(size):
			for dx in range(size):
				var texel: Color = _cave_wall_img.get_pixel(dx % _cave_wall_img.get_width(), dy % _cave_wall_img.get_height())
				var blended := Color(
					COLOR_WALL.r * (0.2 + 0.8 * texel.r),
					COLOR_WALL.g * (0.2 + 0.8 * texel.g),
					COLOR_WALL.b * (0.2 + 0.8 * texel.b),
					1.0
				)
				img.set_pixel(px + dx, py + dy, blended)
	else:
		# Fallback: flat color
		for dy in range(size):
			for dx in range(size):
				img.set_pixel(px + dx, py + dy, COLOR_WALL)
	# Add some small specular highlights on walls
	var rng_local := RandomNumberGenerator.new()
	rng_local.seed = gx * 1000 + gy
	for _i in range(4):
		var sx := rng_local.randi_range(2, size - 3)
		var sy := rng_local.randi_range(2, size - 3)
		var brightness := 0.08 + rng_local.randf() * 0.08
		img.set_pixel(px + sx, py + sy, Color(
			COLOR_WALL_EDGE.r + brightness,
			COLOR_WALL_EDGE.g + brightness,
			COLOR_WALL_EDGE.b + brightness
		))


## Draw a water tile using the water texture with tinting and a shimmer offset.
## shimmer_offset is derived from position + time so adjacent tiles don't pulse in unison.
func _draw_water_tile(img: Image, px: int, py: int, size: int, gx: int, gy: int) -> void:
	if _cave_water_img != null:
		var w: int = _cave_water_img.get_width()
		var h: int = _cave_water_img.get_height()
		var shimmer_val := sin(_water_shimmer_time * WATER_SHIMMER_SPEED + float(gx) * 0.7 + float(gy) * 1.3) * 0.08
		var bright := Color(1.0 + shimmer_val, 1.0 + shimmer_val, 1.0 + shimmer_val)
		for dy in range(size):
			for dx in range(size):
				var texel: Color = _cave_water_img.get_pixel(dx % w, dy % h)
				var blended := Color(
					COLOR_WATER.r * (0.2 + 0.8 * texel.r) * bright.r,
					COLOR_WATER.g * (0.2 + 0.8 * texel.g) * bright.g,
					COLOR_WATER.b * (0.2 + 0.8 * texel.b) * bright.b,
					1.0
				)
				img.set_pixel(px + dx, py + dy, blended)
	else:
		# Fallback: flat color
		for dy in range(size):
			for dx in range(size):
				img.set_pixel(px + dx, py + dy, COLOR_WATER)


## Fisher-Yates shuffle driven by the deterministic _rng so every peer
## generates identical mine rooms (enemies/ores land in the same cells).
func _shuffle_with_rng(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


## Add a collision rectangle for a wall tile
func _add_wall_collision(tx: int, ty: int) -> void:
	var px := tx * TILE_PX + TILE_PX / 2.0
	var py := ty * TILE_PX + TILE_PX / 2.0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(TILE_PX, TILE_PX)
	shape.shape = rect
	shape.position = Vector2(px, py)
	_wall_body.add_child(shape)


## Place ore deposits on walkable floor tiles
func _place_ores() -> void:
	var configs: Array[Dictionary] = get_ore_config_for_depth(depth_level)
	var g_w := generator.grid_width
	var g_h := generator.grid_height
	
	# Collect eligible floor cell positions
	var floor_cells: Array[Vector2i] = []
	for y in range(g_h):
		for x in range(g_w):
			var tid: String = generator.grid[y][x]
			if tid == MineGenerator.TILE_FLOOR or tid == MineGenerator.TILE_DEEPER:
				floor_cells.append(Vector2i(x, y))
	
	if floor_cells.is_empty():
		return
	
	_shuffle_with_rng(floor_cells)
	
	var cell_idx := 0
	for cfg in configs:
		var count: int = cfg["count"]
		# Deeper tiles get extra ores
		var cell: Vector2i = floor_cells[cell_idx % floor_cells.size()]
		for _i in range(count):
			if cell_idx >= floor_cells.size():
				cell_idx = 0
			cell = floor_cells[cell_idx % floor_cells.size()]
			cell_idx += 1
			
		var ore := ORE_DEPOSIT_SCENE.instantiate()
		ore.ore_type = cfg["type"]
		ore.max_hits = cfg["max_hits"]
		ore.min_per_hit = cfg["min"]
		ore.max_per_hit = cfg["max"]
		ore.bonus_chance = cfg["bonus_chance"]
		ore.bonus_item = cfg["bonus"]
		
		# Assign deterministic deposit_id for multiplayer sync (matching enemy pattern)
		ore.deposit_id = _next_enemy_id
		ore.name = "OreDeposit_%d" % _next_enemy_id
		_next_enemy_id += 1
		if NetworkManager.is_network_active() and not multiplayer.is_server():
			ore._is_remote = true
		
		# Slight random offset so deposits aren't perfectly grid-aligned
		var ox := 3.0 + _rng.randf() * 10.0
		var oy := 3.0 + _rng.randf() * 10.0
		ore.position = Vector2(cell.x * TILE_PX + ox, cell.y * TILE_PX + oy)
		add_child(ore)


## Assign deterministic ids and per-peer remote flag, then attach the enemy.
## Because generation order is identical on every peer, `_next_enemy_id` yields
## the same ids on both the host and clients. The explicit stable node name also
## keeps node-path RPC routing (World/MineRoom/MineEnemy_N) resolving to the
## matching copy on every peer — clients just render host-authoritative state.
func _add_mine_enemy(enemy: Node2D, cell: Vector2i) -> void:
	enemy.enemy_id = _next_enemy_id
	enemy.name = "MineEnemy_%d" % _next_enemy_id
	_next_enemy_id += 1
	enemy.z_index = 10
	enemy.position = Vector2(cell.x * TILE_PX + 8, cell.y * TILE_PX + 8)
	if enemy.has_method("set_hp_multiplier"):
		enemy.set_hp_multiplier(get_enemy_hp_multiplier(depth_level))
	if NetworkManager.is_network_active() and not multiplayer.is_server():
		enemy._is_remote = true
	add_child(enemy)


## Spawn enemies on floor tiles, preferring chambers
func _spawn_enemies() -> void:
	var spawn_count: int = get_enemy_count(depth_level)
	var g_w := generator.grid_width
	var g_h := generator.grid_height
	
	# Collect ground cells for ground enemies (cache for respawn too)
	var ground_cells: Array[Vector2i] = []
	_respawn_floor_cells.clear()
	# Collect water cells for bat spawns (bats fly over everything)
	var water_cells: Array[Vector2i] = []
	for y in range(g_h):
		for x in range(g_w):
			var tid: String = generator.grid[y][x]
			if tid == MineGenerator.TILE_FLOOR or tid == MineGenerator.TILE_DEEPER:
				ground_cells.append(Vector2i(x, y))
				_respawn_floor_cells.append(Vector2i(x, y))
			elif tid == MineGenerator.TILE_WATER:
				water_cells.append(Vector2i(x, y))
	
	var total_enemies := 0
	
	# Spawn ground enemies on floor cells
	if not ground_cells.is_empty():
		_shuffle_with_rng(ground_cells)
		var ground_count: int = maxi(1, spawn_count - (water_cells.size() / 2 if not water_cells.is_empty() else 0))
		# Ensure at least 60% are ground enemies
		ground_count = mini(ground_count, ground_cells.size())
		
		for i in range(ground_count):
			var cell: Vector2i = ground_cells[i % ground_cells.size()]
			var enemy: Node2D
			
			if depth_level <= 1 and _rng.randf() < 0.7:
				enemy = CAVE_CRAWLER_SCENE.instantiate()
			elif depth_level <= 2:
				# Depth 2: mix of crawlers and golems
				if _rng.randf() < 0.6:
					enemy = CAVE_CRAWLER_SCENE.instantiate()
				else:
					enemy = STONE_GOLEM_SCENE.instantiate()
			else:
				# Depth 3+: more golems, tougher
				if _rng.randf() < 0.4:
					enemy = CAVE_CRAWLER_SCENE.instantiate()
				else:
					enemy = STONE_GOLEM_SCENE.instantiate()
			
			_add_mine_enemy(enemy, cell)
			total_enemies += 1
	
	# Spawn bats near water
	if not water_cells.is_empty():
		_shuffle_with_rng(water_cells)
		var bat_count: int = maxi(1, mini(water_cells.size(), 3 + depth_level))
		
		for i in range(bat_count):
			var cell: Vector2i = water_cells[i % water_cells.size()]
			var bat := CAVE_BAT_SCENE.instantiate()
			_add_mine_enemy(bat, cell)
			total_enemies += 1
	
	# Fallback: if no enemies spawned at all, place some on ground
	if total_enemies == 0 and not ground_cells.is_empty():
		for i in range(mini(3, ground_cells.size())):
			var cell: Vector2i = ground_cells[i]
			var crawler := CAVE_CRAWLER_SCENE.instantiate()
			_add_mine_enemy(crawler, cell)


# ── Enemy Respawn (always active — underground, day/night doesn't matter) ──


## Create and start the periodic enemy respawn timer.
func _setup_enemy_respawn() -> void:
	# Host-authoritative respawn: only the server runs the timer and broadcasts
	# spawns so clients stay in lockstep. Clients just mirror host copies.
	if NetworkManager.is_network_active() and not multiplayer.is_server():
		return
	_enemy_respawn_timer = Timer.new()
	_enemy_respawn_timer.name = "EnemyRespawnTimer"
	_enemy_respawn_timer.wait_time = ENEMY_RESPAWN_INTERVAL
	_enemy_respawn_timer.one_shot = false
	_enemy_respawn_timer.timeout.connect(_on_enemy_respawn_timeout)
	add_child(_enemy_respawn_timer)
	_enemy_respawn_timer.start()


## Periodically checks enemy count and respawns if below the target for this depth.
## Runs on a timer so the mine always feels alive with enemies, regardless of day/night.
func _on_enemy_respawn_timeout() -> void:
	if not is_inside_tree():
		return
	
	# Count current mine enemies that are direct children of this room
	var current_enemies: int = 0
	for child in get_children():
		if child is CaveCrawler or child is StoneGolem or child is CaveBat:
			if is_instance_valid(child) and child.current_health > 0:
				current_enemies += 1
	
	var target_count: int = get_enemy_count(depth_level)
	# Allow some buffer — don't respawn if we're close to target
	if current_enemies >= roundi(target_count * 0.6):
		return
	
	# How many to spawn this wave
	var to_spawn: int = maxi(1, roundi((target_count - current_enemies) * RESPAWN_FILL_RATIO))
	
	if _respawn_floor_cells.is_empty():
		return
	
	# Shuffle for random selection each wave
	_shuffle_with_rng(_respawn_floor_cells)
	
	# Get player cell to avoid spawning on top of them
	var player := get_tree().get_first_node_in_group("player")
	var player_cell: Vector2i = Vector2i(-1, -1)
	if is_instance_valid(player) and player.get_parent() == self:
		player_cell = Vector2i(
			int(player.global_position.x / TILE_PX),
			int(player.global_position.y / TILE_PX)
		)
	
	var spawned: int = 0
	for cell in _respawn_floor_cells:
		if spawned >= to_spawn:
			break
		
		# Don't spawn too close to the player (3 tiles radius)
		if player_cell.x >= 0:
			if abs(cell.x - player_cell.x) < 3 and abs(cell.y - player_cell.y) < 3:
				continue
		
		var enemy: Node2D
		var type_key: int = 0
		if depth_level <= 1 and _rng.randf() < 0.7:
			enemy = CAVE_CRAWLER_SCENE.instantiate()
			type_key = MINE_ENEMY_CRAWLER
		elif depth_level <= 2:
			if _rng.randf() < 0.6:
				enemy = CAVE_CRAWLER_SCENE.instantiate()
				type_key = MINE_ENEMY_CRAWLER
			else:
				enemy = STONE_GOLEM_SCENE.instantiate()
				type_key = MINE_ENEMY_GOLEM
		else:
			# Depth 3+: more golems, tougher
			if _rng.randf() < 0.4:
				enemy = CAVE_CRAWLER_SCENE.instantiate()
				type_key = MINE_ENEMY_CRAWLER
			else:
				enemy = STONE_GOLEM_SCENE.instantiate()
				type_key = MINE_ENEMY_GOLEM
		
		_add_mine_enemy(enemy, cell)
		spawned += 1
		if NetworkManager.is_network_active() and multiplayer.is_server():
			for pid in get_sync_peer_ids():
				rpc_id(pid, "_receive_mine_respawn", enemy.enemy_id, type_key,
					Vector2(cell.x * TILE_PX + 8, cell.y * TILE_PX + 8),
					get_enemy_hp_multiplier(depth_level))


## Peers that have a fully built mine room and can receive node-path RPCs.
## The host is authoritative and is never included (it drives locally).
func get_sync_peer_ids() -> Array[int]:
	var world: Node = get_tree().get_first_node_in_group("world")
	if is_instance_valid(world) and world.has_method("get_mine_ready_peer_ids"):
		return world.get_mine_ready_peer_ids()
	return []


## Host-authoritative respawn mirror: clients instantiate a matching remote
## copy so node-path RPC routing keeps working for the new enemy.
@rpc("authority", "reliable")
func _receive_mine_respawn(enemy_id: int, type_key: int, pos: Vector2, hp_mult: float) -> void:
	if NetworkManager.is_network_active() and multiplayer.is_server():
		return
	var enemy: Node2D
	if type_key == MINE_ENEMY_CRAWLER:
		enemy = CAVE_CRAWLER_SCENE.instantiate()
	elif type_key == MINE_ENEMY_GOLEM:
		enemy = STONE_GOLEM_SCENE.instantiate()
	else:
		enemy = CAVE_BAT_SCENE.instantiate()
	enemy.enemy_id = enemy_id
	enemy.name = "MineEnemy_%d" % enemy_id
	enemy.z_index = 10
	enemy.position = pos
	if enemy.has_method("set_hp_multiplier"):
		enemy.set_hp_multiplier(hp_mult)
	enemy._is_remote = true
	add_child(enemy)


## Reconcile this peer's mine-enemy set against the host's authoritative snapshot
## (a late joiner). The deterministic generation only produces the INITIAL enemy
## set, but the host's mine evolves: originals get killed/damaged and NEW enemies
## respawn with enemy_ids past the client's initial range. So beside matching HP
## of shared enemies, we must (1) create any enemy the host has that we don't
## (the respawned ones), (2) move living enemies to the host's current position,
## and (3) remove ours that the host no longer has (they died host-side).
func reconcile_enemies_from_host(enemy_entries: Array) -> void:
	if enemy_entries.is_empty():
		return
	var host_ids: Dictionary = {}
	for e in enemy_entries:
		var eid: int = int(e.get("d", -1))
		if eid < 0:
			continue
		host_ids[eid] = true
		var h: int = int(e.get("h", 0))
		var m: int = int(e.get("m", 1))
		var pos: Vector2 = e.get("p", Vector2.ZERO)
		var child: Node = _find_enemy_by_id(eid)
		if child:
			# Shared enemy — sync HP/position so it matches the host.
			if m > 0:
				child.max_health = m
			child.current_health = maxi(0, h)
			if pos != Vector2.ZERO:
				child.position = pos
			if child.has_method("_update_health_bar"):
				child._update_health_bar()
		else:
			# Respawned enemy the client never generated — create a remote copy.
			var t: int = int(e.get("t", MINE_ENEMY_CRAWLER))
			var enemy: Node2D
			if t == MINE_ENEMY_GOLEM:
				enemy = STONE_GOLEM_SCENE.instantiate()
			elif t == MINE_ENEMY_BAT:
				enemy = CAVE_BAT_SCENE.instantiate()
			else:
				enemy = CAVE_CRAWLER_SCENE.instantiate()
			enemy.enemy_id = eid
			enemy.name = "MineEnemy_%d" % eid
			enemy.z_index = 10
			if pos != Vector2.ZERO:
				enemy.position = pos
			if m > 0:
				enemy.max_health = m
			enemy.current_health = maxi(0, h)
			enemy._is_remote = true
			add_child(enemy)
	# Remove this peer's enemies the host no longer lists (they died host-side).
	for child in get_children():
		if is_instance_valid(child) and "enemy_id" in child \
				and (child is CaveCrawler or child is StoneGolem or child is CaveBat):
			if not host_ids.has(int(child.enemy_id)):
				child.queue_free()


func _find_enemy_by_id(eid: int) -> Node:
	for child in get_children():
		if is_instance_valid(child) and "enemy_id" in child \
				and (child is CaveCrawler or child is StoneGolem or child is CaveBat) \
				and int(child.enemy_id) == eid:
			return child
	return null


## Generate the exit area in the central chamber
func _generate_exit_area() -> void:
	if generator == null or generator.chamber_centers.is_empty():
		return
	
	# Find the chamber closest to the map center for the exit
	var center_map := Vector2(
		generator.grid_width * TILE_PX / 2.0,
		generator.grid_height * TILE_PX / 2.0
	)
	var exit_pos: Vector2 = center_map
	var best_dist := INF
	for ch in generator.chamber_centers:
		var d := ch.distance_squared_to(center_map)
		if d < best_dist:
			best_dist = d
			exit_pos = ch
	
	# Exit Area2D — tracks proximity for E-press interaction
	var exit_area := Area2D.new()
	exit_area.name = "MineExit"
	exit_area.z_index = 5
	exit_area.collision_mask = 2
	
	var exit_shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(72, 40)
	exit_shape.shape = rect
	exit_area.add_child(exit_shape)
	exit_area.position = exit_pos + Vector2(0, -4)
	
	# Exit visual — large ladder sprite
	var ladder := Sprite2D.new()
	ladder.texture = ENTRANCE_LADDER
	ladder.scale = Vector2(0.7, 0.7)
	ladder.z_index = 15
	ladder.position = exit_pos + Vector2(0, -16)
	add_child(ladder)
	
	# Label above the exit ladder
	var label := Label.new()
	label.text = "Exit"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.position = exit_pos + Vector2(-16, -42)
	label.z_index = 25
	add_child(label)

	# Glow behind ladder for visibility
	var glow := Sprite2D.new()
	var glow_img := Image.create(48, 64, false, Image.FORMAT_RGBA8)
	glow_img.fill(Color(1.0, 1.0, 0.6, 0.08))
	glow.texture = ImageTexture.create_from_image(glow_img)
	glow.centered = true
	glow.position = exit_pos + Vector2(0, -16)
	glow.z_index = 14
	glow.modulate = Color(1.0, 1.0, 0.8, 0.15)
	add_child(glow)
	
	exit_area.body_entered.connect(_on_exit_near)
	exit_area.body_exited.connect(_on_exit_left)
	add_child(exit_area)


func _on_exit_near(body: Node) -> void:
	if body.is_in_group("player"):
		_player_near_exit = true


func _on_exit_left(body: Node) -> void:
	if body.is_in_group("player"):
		_player_near_exit = false


## Check if player can exit (no interaction, just proximity check).
func can_exit() -> bool:
	return _player_near_exit

## Called when player presses E near exit ladder. Returns true if exit triggered.
func try_exit() -> bool:
	if not _player_near_exit:
		return false
	exited.emit()
	_player_near_exit = false
	return true


# ── Visual Atmosphere ──


## Adds a dark gradient overlay so the mine feels deep and claustrophobic.
## Uses a ColorRect with a radial gradient mask that's darker toward the edges.
func _setup_ambient_lighting() -> void:
	var g_w := generator.grid_width
	var g_h := generator.grid_height
	var pixel_w := g_w * TILE_PX
	var pixel_h := g_h * TILE_PX
	
	# Create a darkness vignette overlay using a large ColorRect
	var darkness := ColorRect.new()
	darkness.color = Color(0.0, 0.0, 0.0, 0.25 + depth_level * 0.04)  # deeper = darker
	darkness.size = Vector2(pixel_w, pixel_h)
	darkness.position = Vector2.ZERO
	darkness.mouse_filter = Control.MOUSE_FILTER_IGNORE
	darkness.z_index = 20
	darkness.name = "AmbientDarkness"
	add_child(darkness)


## Creates faint dust particles that drift down in open chambers.
func _setup_dust_particles() -> void:
	var g_w := generator.grid_width
	var g_h := generator.grid_height
	var pixel_w := g_w * TILE_PX
	var pixel_h := g_h * TILE_PX
	
	var particles := GPUParticles2D.new()
	particles.name = "DustParticles"
	particles.z_index = 25
	particles.position = Vector2(pixel_w / 2.0, pixel_h / 2.0)
	particles.emitting = true
	particles.amount = 12
	particles.lifetime = 6.0
	particles.preprocess = 3.0  # start already spawned
	particles.explosiveness = 0.0
	particles.randomness = 0.3
	particles.one_shot = false
	
	# Process material for gentle downward drift
	var proc_mat := ParticleProcessMaterial.new()
	proc_mat.gravity = Vector3(0.0, 3.0, 0.0)  # very slow fall
	proc_mat.initial_velocity_min = 2.0
	proc_mat.initial_velocity_max = 6.0
	proc_mat.direction = Vector3(0.0, 1.0, 0.0)
	proc_mat.spread = 180.0
	proc_mat.scale_min = 0.8
	proc_mat.scale_max = 1.5
	proc_mat.color = Color(0.6, 0.55, 0.5, 0.2)
	proc_mat.angle_min = 0.0
	proc_mat.angle_max = 360.0
	proc_mat.angular_velocity_min = 0.0
	proc_mat.angular_velocity_max = 10.0
	particles.process_material = proc_mat
	
	# Use a simple white dot texture for particles
	var dot_img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	dot_img.fill(Color(1.0, 1.0, 1.0, 0.4))
	particles.texture = ImageTexture.create_from_image(dot_img)
	
	add_child(particles)
	_dust_particles = particles


## Adds a looping ambient audio player for underground atmosphere.
func _setup_mine_ambient_audio() -> void:
	var player := AudioStreamPlayer2D.new()
	player.name = "MineAmbientAudio"
	player.volume_db = -12.0  # quiet
	player.max_distance = 2000.0
	player.bus = &"Master"
	
	# Generate a simple low hum procedurally — or use a silent generator
	# that just creates atmospheric feel. For now, we rely on the built-in
	# game audio system. The player node exists for future ambient audio assets.
	player.stream = null  # no audio file yet, placeholder for future
	add_child(player)
	_ambient_player = player


## Shows the current mine depth as an in-world label near the exit.
func _setup_depth_label() -> void:
	if generator == null or generator.chamber_centers.is_empty():
		return
	
	_depth_label = Label.new()
	_depth_label.name = "DepthLabel"
	_depth_label.text = "⚒ Floor %d" % depth_level
	_depth_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_depth_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6, 0.5))
	_depth_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0))
	_depth_label.add_theme_constant_override("shadow_offset_x", 1)
	_depth_label.add_theme_constant_override("shadow_offset_y", 1)
	_depth_label.add_theme_font_size_override("font_size", 12)
	_depth_label.position = Vector2(8, 8)
	_depth_label.z_index = 30
	add_child(_depth_label)


# ── Stardew-Style Depth Descent ──


## Generate a descending shaft in a separate chamber from the exit ladder.
## Players use this to go deeper into the mine instead of leaving.
func _generate_descent_shaft() -> void:
	if generator == null or generator.chamber_centers.is_empty():
		return
	
	# Find a chamber that's NOT the exit chamber (different from center)
	var center_map := Vector2(
		generator.grid_width * TILE_PX / 2.0,
		generator.grid_height * TILE_PX / 2.0
	)
	var shaft_pos: Vector2 = center_map
	var best_dist := 0.0
	var found_other := false
	for ch in generator.chamber_centers:
		var d := ch.distance_squared_to(center_map)
		if d > best_dist:
			best_dist = d
			shaft_pos = ch
			found_other = true
	
	if not found_other:
		return
	
	# Shaft Area2D trigger — tracks proximity for E-press interaction
	var shaft_area := Area2D.new()
	shaft_area.name = "DescentShaft"
	shaft_area.z_index = 5
	shaft_area.collision_mask = 2
	
	var shaft_shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(72, 40)
	shaft_shape.shape = rect
	shaft_area.add_child(shaft_shape)
	shaft_area.position = shaft_pos + Vector2(0, -4)
	
	# Shaft visual — wooden support beams + dark hole
	var shaft_sprite := Sprite2D.new()
	shaft_sprite.texture = DESCENDING_SHAFT
	shaft_sprite.scale = Vector2(0.6, 0.6)
	shaft_sprite.z_index = 15
	shaft_sprite.position = shaft_pos + Vector2(0, -16)
	add_child(shaft_sprite)
	
	# Label above the shaft
	var label := Label.new()
	label.text = "Descend"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.position = shaft_pos + Vector2(-24, -42)
	label.z_index = 25
	add_child(label)

	# Glow around shaft
	var glow := Sprite2D.new()
	var glow_img := Image.create(48, 64, false, Image.FORMAT_RGBA8)
	glow_img.fill(Color(0.3, 0.2, 0.6, 0.06))
	glow.texture = ImageTexture.create_from_image(glow_img)
	glow.centered = true
	glow.position = shaft_pos + Vector2(0, -12)
	glow.z_index = 14
	glow.modulate = Color(0.6, 0.4, 1.0, 0.12)
	add_child(glow)
	
	# Purple hint particles rising from the shaft
	var hint_particles := GPUParticles2D.new()
	hint_particles.name = "ShaftParticles"
	hint_particles.z_index = 16
	hint_particles.position = shaft_pos + Vector2(0, 4)
	hint_particles.emitting = true
	hint_particles.amount = 4
	hint_particles.lifetime = 3.0
	hint_particles.one_shot = false
	
	var hint_mat := ParticleProcessMaterial.new()
	hint_mat.gravity = Vector3(0.0, -5.0, 0.0)
	hint_mat.initial_velocity_min = 2.0
	hint_mat.initial_velocity_max = 8.0
	hint_mat.direction = Vector3(0.0, -1.0, 0.0)
	hint_mat.spread = 30.0
	hint_mat.scale_min = 1.0
	hint_mat.scale_max = 2.0
	hint_mat.color = Color(0.5, 0.3, 1.0, 0.15)
	hint_particles.process_material = hint_mat
	add_child(hint_particles)
	
	shaft_area.body_entered.connect(_on_shaft_near)
	shaft_area.body_exited.connect(_on_shaft_left)
	add_child(shaft_area)


func _on_shaft_near(body: Node) -> void:
	if body.is_in_group("player"):
		_player_near_shaft = true


func _on_shaft_left(body: Node) -> void:
	if body.is_in_group("player"):
		_player_near_shaft = false


## Check if player can descend (no interaction, just proximity check).
func can_descend() -> bool:
	return _player_near_shaft

## Called when player presses E near descent shaft. Returns true if descend triggered.
func try_descend() -> bool:
	if not _player_near_shaft:
		return false
	var new_depth: int = clampi(depth_level + 1, 1, MAX_DESCENT_DEPTH)
	descended.emit(new_depth)
	_player_near_shaft = false
	return true


# ── Water Shimmer Animation ──

## How often (in seconds) to rebuild the water shimmer overlay.
const WATER_REBUILD_INTERVAL := 0.12

## If non-null, water tiles were drawn into this separate overlay image so
## it can be animated independently from the static floor/wall map.
var _water_overlay_sprite: Sprite2D = null
var _water_overlay_img: Image = null
var _water_rebuild_timer: float = 0.0


func _process(delta: float) -> void:
	_water_shimmer_time += delta
	if _water_overlay_sprite != null and _water_overlay_img != null:
		_water_rebuild_timer += delta
		if _water_rebuild_timer >= WATER_REBUILD_INTERVAL:
			_water_rebuild_timer = 0.0
			_redraw_water_overlay()


func _redraw_water_overlay() -> void:
	if _water_overlay_img == null or generator == null:
		return
	_water_overlay_img.fill(Color(0.0, 0.0, 0.0, 0.0))
	var g_w := generator.grid_width
	var g_h := generator.grid_height
	for y in range(g_h):
		for x in range(g_w):
			if generator.grid[y][x] == MineGenerator.TILE_WATER:
				_draw_water_tile(_water_overlay_img, x * TILE_PX, y * TILE_PX, TILE_PX, x, y)
	var tex := ImageTexture.create_from_image(_water_overlay_img)
	_water_overlay_sprite.texture = tex
