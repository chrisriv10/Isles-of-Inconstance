extends Node2D

## Owns the tile-based world: procedural generation, tile lookups, and
## simple farming actions (tilling). Keeps generation logic delegated to
## WorldGenerator so this script only deals with the scene tree.

const TILE_SIZE: int = 16
const RESOURCE_NODE_SCENE: PackedScene = preload("res://scenes/objects/ResourceNode.tscn")
const CROP_SCENE: PackedScene = preload("res://scenes/world/Crop.tscn")
const SHOP_BUILDING_SCENE: PackedScene = preload("res://scenes/objects/ShopBuilding.tscn")
const BOAT_SCENE: PackedScene = preload("res://scenes/objects/Boat.tscn")
const TRAVEL_BOAT_SCENE: PackedScene = preload("res://scenes/objects/TravelBoat.tscn")
const DOCK_SCENE: PackedScene = preload("res://scenes/objects/Dock.tscn")
const TREE_SCENE: PackedScene = preload("res://scenes/objects/Tree.tscn")
const FRUIT_TREE_SCENE: PackedScene = preload("res://scenes/objects/FruitTree.tscn")
const ANIMAL_SCENE: PackedScene = preload("res://scenes/world/Animal.tscn")
const EXPEDITION_ISLAND_SCENE: PackedScene = preload("res://scenes/world/ExpeditionIsland.tscn")
# MineRoom is instantiated via MineRoom.new()

## Nature scenes
const BUSH_SCENE: PackedScene = preload("res://scenes/objects/Bush.tscn")
const FLOWER_SCENE: PackedScene = preload("res://scenes/objects/FlowerPatch.tscn")
const MUSHROOM_SCENE: PackedScene = preload("res://scenes/objects/MushroomPatch.tscn")
const LOG_STUMP_SCENE_PATH: String = "res://scripts/world/nature/LogStump.gd"

@export var world_width: int = 100
@export var world_height: int = 100
@export var world_seed: int = 0
@export var object_count: int = 12
@export var iron_ore_count: int = 12

@onready var ground_layer: TileMapLayer = $GroundLayer
@onready var objects_root: Node2D = $Objects
@onready var tool_preview: ToolPreview = $ToolPreview

# Monotonic counter for naming worldgen/runtime-spawned animals. Host and
# client generate identical worlds from the same seed, so the worldgen
# portion of these names always matches; runtime spawns carry their name in
# the RPC payload (see register_animal_name / _broadcast_animal_spawn).
var _next_animal_index: int = 0

var _tile_grid: Array = []
var _dock_cell: Vector2i = Vector2i(-1, -1)  # set during _spawn_boat
var _biome_grid: Array = []  # parallel to _tile_grid, stores biome index into _biome_list (or -1 for water)
var _biome_list: Array[BiomeDefinition] = []  # ordered list of all biomes, populated at generation time
var _generator: WorldGenerator
var _soil_data: Dictionary = {}
var _crop_nodes: Dictionary = {}
var _sprinklers: Dictionary = {}  # cell -> {"active": true, "placed_day": int}
var _removed_cell_objects: Dictionary = {}  # cell -> true: freed world objects (trees, rocks, flowers) for late-joiner snapshots
var _scarecrow_cells: Array[Vector2i] = []  # cells with scarecrows
var _compost_bin_cells: Array[Vector2i] = []  # cells with compost bins
var _greenhouse_cells: Array[Vector2i] = []  # cells with greenhouses

# New system references
var building_system: BuildingSystem = null
var cooking_system: CookingSystem = null
var enemy_spawner: EnemySpawner = null
var hybrid_system: HybridCropSystem = null
var crop_trait_generator: CropTraitGenerator = null
var biome_generator: BiomeGenerator = null
var pirate_raid: PirateRaidEvent = null
var blood_moon_event: BloodMoonEvent = null
var visitor_manager: VisitorManager = null
var _animal_respawn_timer: Timer = null
var _visitor_time_timer: Timer = null

# Mine system
var mine_entrances: Array[Node2D] = []
var current_mine_room: MineRoom = null
var _mine_exit_cooldown: bool = false
var _player_near_mine_entrance: bool = false
var _player_mine_entrance_node: Node2D = null
# Host-coordinated shared-mine session. The mine is deterministic per peer,
# so every peer renders an identical room; the host only decides WHICH room
# (entrance + depth) is "the shared mine" so late joiners end up together.
# Sessions exist even when the host's own player is not inside.
var _mine_session_active: bool = false
var _mine_session_entrance: int = 1
var _mine_session_depth: int = 1
var _mine_session_members: Dictionary = {}  # peer_id -> true
# Peers that have ACKed their local mine room is fully built. The host only
# broadcasts enemy state/damage/death/respawn/loot to these peers, because
# node-path RPCs fail on peers that do not have the MineRoom/MineEnemy_N copy.
var _mine_session_room_ready: Dictionary = {}  # peer_id -> true
# Player's overworld position before entering mine (used to return on exit)

const MINE_ENTRANCE_TEX: Texture2D = preload("res://assets/generated/mine_entrance_frame_0.png")

# Tracked positions for UI/map markers
var _shop_position: Vector2 = Vector2.ZERO
var _shop_cell: Vector2i = Vector2i(-1, -1)
var _boat_position: Vector2 = Vector2.ZERO
var _dock_position: Vector2 = Vector2.ZERO

# Cells occupied by iron ore — checked by tree scattering to prevent overlap
var _ore_cells: Dictionary = {}

# Cells occupied by nature objects (bushes, flowers, mushrooms, stumps) —
# checked by tree scattering to prevent overlap.
var _nature_cells: Dictionary = {}

## Building interior sessions (host-authoritative, keyed by building cell).
## Each building cell that has players inside gets a session with a deterministic
## seed so all peers generate identical interior layouts.
var _building_sessions: Dictionary = {}  # "cell_x,cell_y" -> { "seed": int, "type": int, "members": {peer_id: true} }
var _peer_building: Dictionary = {}  # peer_id -> "cell_x,cell_y" the peer is currently inside

# Build mode state
var build_mode_active: bool = false
var build_item_id: String = ""
var build_type: int = BuildingSystem.BuildingType.NONE

## Maps craftable building items to their BuildingSystem type
const BUILD_ITEM_TO_TYPE: Dictionary = {
	"fence_material": BuildingSystem.BuildingType.FENCE,
	"stone_fence_material": BuildingSystem.BuildingType.STONE_FENCE,
	"campfire_kit": BuildingSystem.BuildingType.CAMPFIRE,

	# Additional buildings
	"small_home_kit": BuildingSystem.BuildingType.SMALL_HOME,
	"medium_home_kit": BuildingSystem.BuildingType.MEDIUM_HOME,
	"large_home_kit": BuildingSystem.BuildingType.LARGE_HOME,
	"barn_kit": BuildingSystem.BuildingType.BARN,
	"storage_shed_kit": BuildingSystem.BuildingType.STORAGE_SHED,
	"gate_kit": BuildingSystem.BuildingType.GATE,
	"garden_bed_kit": BuildingSystem.BuildingType.GARDEN_BED,
	"windmill_kit": BuildingSystem.BuildingType.WINDMILL,
	"greenhouse_kit": BuildingSystem.BuildingType.GREENHOUSE,
	"decorative_statue_kit": BuildingSystem.BuildingType.DECORATIVE_STATUE,
	"decorative_fountain_kit": BuildingSystem.BuildingType.DECORATIVE_FOUNTAIN,
	"decorative_bench_kit": BuildingSystem.BuildingType.DECORATIVE_BENCH,
	"decorative_lantern_kit": BuildingSystem.BuildingType.DECORATIVE_LANTERN,
	"decorative_sign_kit": BuildingSystem.BuildingType.DECORATIVE_SIGN,
	"silo_kit": BuildingSystem.BuildingType.SILO,
	"well_kit": BuildingSystem.BuildingType.WELL,
	"hotel_kit": BuildingSystem.BuildingType.HOTEL,
	"scarecrow_kit": BuildingSystem.BuildingType.SCARECROW,
	"compost_bin_kit": BuildingSystem.BuildingType.COMPOST_BIN,
}

## Reverse mapping: BuildingSystem BuildingType -> item ID (for pickup).
const TYPE_TO_BUILD_ITEM: Dictionary = {
	BuildingSystem.BuildingType.FENCE: "fence_material",
	BuildingSystem.BuildingType.STONE_FENCE: "stone_fence_material",
	BuildingSystem.BuildingType.CAMPFIRE: "campfire_kit",
	BuildingSystem.BuildingType.SMALL_HOME: "small_home_kit",
	BuildingSystem.BuildingType.MEDIUM_HOME: "medium_home_kit",
	BuildingSystem.BuildingType.LARGE_HOME: "large_home_kit",
	BuildingSystem.BuildingType.BARN: "barn_kit",
	BuildingSystem.BuildingType.STORAGE_SHED: "storage_shed_kit",
	BuildingSystem.BuildingType.GATE: "gate_kit",
	BuildingSystem.BuildingType.GARDEN_BED: "garden_bed_kit",
	BuildingSystem.BuildingType.WINDMILL: "windmill_kit",
	BuildingSystem.BuildingType.GREENHOUSE: "greenhouse_kit",
	BuildingSystem.BuildingType.DECORATIVE_STATUE: "decorative_statue_kit",
	BuildingSystem.BuildingType.DECORATIVE_FOUNTAIN: "decorative_fountain_kit",
	BuildingSystem.BuildingType.DECORATIVE_BENCH: "decorative_bench_kit",
	BuildingSystem.BuildingType.DECORATIVE_LANTERN: "decorative_lantern_kit",
	BuildingSystem.BuildingType.DECORATIVE_SIGN: "decorative_sign_kit",
	BuildingSystem.BuildingType.SILO: "silo_kit",
	BuildingSystem.BuildingType.WELL: "well_kit",
	BuildingSystem.BuildingType.HOTEL: "hotel_kit",
	BuildingSystem.BuildingType.SCARECROW: "scarecrow_kit",
	BuildingSystem.BuildingType.COMPOST_BIN: "compost_bin_kit",
}

func _init() -> void:
	building_system = BuildingSystem.new()
	cooking_system = CookingSystem.new()
	crop_trait_generator = CropTraitGenerator.new(0)
	enemy_spawner = EnemySpawner.new()
	pirate_raid = PirateRaidEvent.new()
	blood_moon_event = BloodMoonEvent.new()
	visitor_manager = VisitorManager.new()

func _ready() -> void:
	add_to_group("world")
	GameManager.day_changed.connect(_on_day_changed)
	UpgradeManager.upgrade_purchased.connect(_on_upgrade_purchased)
	generate_world()
	_setup_water_collision()
	if enemy_spawner and not enemy_spawner.is_inside_tree():
		add_child(enemy_spawner)
	
	# Add pirate raid event to scene tree
	if pirate_raid and not pirate_raid.is_inside_tree():
		add_child(pirate_raid)
	
	# Add blood moon event to scene tree
	if blood_moon_event and not blood_moon_event.is_inside_tree():
		add_child(blood_moon_event)
		# Track blood moon survival against objectives
		var om := get_tree().get_first_node_in_group("objective_manager")
		if om and om.has_method("on_blood_moon_survived"):
			if not blood_moon_event.blood_moon_ended.is_connected(om.on_blood_moon_survived):
				blood_moon_event.blood_moon_ended.connect(om.on_blood_moon_survived)
	
	# Add visitor manager to scene tree
	if visitor_manager and not visitor_manager.is_inside_tree():
		add_child(visitor_manager)
	
	# Start visitor time-check timer (fires every 10 real seconds ≈ 20 game minutes)
	_visitor_time_timer = Timer.new()
	_visitor_time_timer.name = "VisitorTimeCheck"
	_visitor_time_timer.wait_time = 10.0
	_visitor_time_timer.one_shot = false
	_visitor_time_timer.timeout.connect(_check_visitor_time)
	add_child(_visitor_time_timer)
	_visitor_time_timer.start()
	
	# Start animal respawn timer (fires every 60 seconds, checks and respawns animals)
	_animal_respawn_timer = Timer.new()
	_animal_respawn_timer.name = "AnimalRespawnTimer"
	_animal_respawn_timer.wait_time = 60.0
	_animal_respawn_timer.one_shot = false
	_animal_respawn_timer.timeout.connect(_on_animal_respawn_timer)
	add_child(_animal_respawn_timer)
	_animal_respawn_timer.start()

func generate_world() -> void:
	_clear_world()
	_next_animal_index = 0
	_generator = WorldGenerator.create(world_width, world_height, world_seed)
	_tile_grid = _generator.generate_tile_grid()
	# Generate procedural crops from world seed so host + clients match
	DataManager.generate_procedural_crops(world_seed)
	# Initialize biome generator BEFORE painting ground, scattering, etc.
	biome_generator = BiomeGenerator.new(world_seed)
	_paint_ground()
	# Place buildings FIRST so they aren't blocked by scattered objects
	_scatter_buildings()
	_spawn_boat()
	_spawn_chest()
	_spawn_shop_stand()
	
	# Place the ruined town district BEFORE any object scattering so the town
	# area fills with path tiles AND sets the town_rect meta. Trees, nature
	# objects, biome resources (stones/berry bushes/flowers) and iron ore all
	# consult town_rect to keep the town plaza clear of natural spawns.
	_spawn_ruined_town()
	
	_scatter_objects()
	_scatter_nature_objects()
	_scatter_trees()
	_scatter_animals()
	_scatter_mine_entrances()
	
	# Initialize season system if not already
	if GameManager.season_system == null:
		GameManager.season_system = SeasonSystem.new(world_seed)
	
	# Initialize hybrid system
	hybrid_system = HybridCropSystem.new(world_seed)
	
	# Sync crop trait generator with current world seed
	if crop_trait_generator:
		crop_trait_generator.world_seed = world_seed

func generate_world_with_seed(new_seed: int) -> void:
	world_seed = new_seed
	generate_world()

func _clear_world() -> void:
	ground_layer.clear()
	# Free synchronously instead of queue_free(): world regen happens twice per
	# peer (scene _ready + seed handshake), and deferred removal would leave the
	# first batch alive when the second batch is added, forcing Godot to
	# auto-rename duplicates to per-peer @Area2D@NNN names that never match
	# across hosts/clients (breaking path-based RPC routing).
	for child in objects_root.get_children():
		child.free()
	# Clear placed buildings so a fresh world gets fresh buildings
	if building_system:
		building_system.placed_buildings.clear()
	_soil_data.clear()
	_crop_nodes.clear()
	_sprinklers.clear()
	_removed_cell_objects.clear()
	_biome_grid.clear()
	_biome_list.clear()
	# Clear node-reference arrays (nodes were freed above)
	mine_entrances.clear()
	# Force-clean any stale mine state (room, camera limits, inside_interior flag)
	# This is essential when the player exited to menu or died while inside a mine
	# and then starts a new game — without this, the camera stays clamped to the
	# mine void area and the player appears to spawn "in the mine."
	emergency_exit_mine()
	# If the player is inside a building, restore them to the overworld too.
	# A regenerating world would otherwise strand them at the (now empty) void
	# with a stale current_interior reference — the "blue abyss" trap.
	if current_interior:
		_on_exit_interior()
	# Disconnect town lantern signal to avoid dangling connections
	if GameManager.phase_changed.is_connected(_update_town_lanterns):
		GameManager.phase_changed.disconnect(_update_town_lanterns)

func _paint_ground() -> void:
	# Use the biome generator's own biome list for index-based lookup.
	# Must use the same object references as get_biome_at() — don't call
	# BiomeLibrary.get_all_biomes() here because it creates new instances.
	if biome_generator:
		_biome_list = biome_generator.get_biomes()
	else:
		_biome_list = []
	# Initialize biome grid parallel to tile grid
	_biome_grid = []
	_biome_grid.resize(world_height)
	
	for y in range(world_height):
		var bg_row: Array = []
		bg_row.resize(world_width)
		_biome_grid[y] = bg_row
		for x in range(world_width):
			var cell := Vector2i(x, y)
			var tile_id: String = _tile_grid[y][x]
			var biome: BiomeDefinition = null
			var biome_index: int = -1
			
			# Only override land tiles with biome-based terrain
			if tile_id != "water" and not tile_id.begins_with("edge"):
				if biome_generator:
					biome = biome_generator.get_biome_at(x, y)
				if biome and biome.ground_tile_id != "":
					tile_id = biome.ground_tile_id
					_tile_grid[y][x] = tile_id
					biome_index = _biome_list.find(biome)
					_biome_grid[y][x] = biome_index if biome_index >= 0 else 0
				else:
					_biome_grid[y][x] = 0  # default to first biome (Plains)
			else:
				_biome_grid[y][x] = -1  # water
			
			# Resolve biome base ID (e.g. "cherry_grove") to a specific quadrant variant.
			var resolved_id: String = tile_id
			var quad_ids: Array = _biome_tile_variants(tile_id)
			if quad_ids.size() == 4:
				var qi: int = (x % 2) + (y % 2) * 2
				resolved_id = quad_ids[qi]
			
			var tile_type: TileTypeData = DataManager.get_tile_type(resolved_id)
			if tile_type:
				ground_layer.set_cell(cell, tile_type.source_id, tile_type.atlas_coords)
	
	# Post-process: smooth biome grid to remove single-tile noise patches
	if biome_generator:
		biome_generator.smooth_biome_map(_biome_grid, world_width, world_height)
		# Ensure every biome has at least some tiles (rare biomes may get absorbed)
		biome_generator.guarantee_biomes(_biome_grid, world_width, world_height)
		
		# Re-apply ground tiles from smoothed biomes
		for y in range(world_height):
			for x in range(world_width):
				var cell := Vector2i(x, y)
				var tile_id: String = _tile_grid[y][x]
				if tile_id == "water" or tile_id.begins_with("edge"):
					continue
				var biome_idx: int = _biome_grid[y][x]
				if biome_idx >= 0 and biome_idx < _biome_list.size():
					var biome := _biome_list[biome_idx]
					if biome and biome.ground_tile_id != "":
						var resolved_id: String = biome.ground_tile_id
						var quad_ids: Array = _biome_tile_variants(resolved_id)
						if quad_ids.size() == 4:
							var qi: int = (x % 2) + (y % 2) * 2
							resolved_id = quad_ids[qi]
						var tile_type: TileTypeData = DataManager.get_tile_type(resolved_id)
						if tile_type:
							_tile_grid[y][x] = resolved_id
							ground_layer.set_cell(cell, tile_type.source_id, tile_type.atlas_coords)

	# Post-process: add beach sand and coastline edge tiles around the island
	_add_beach_and_edge_tiles()


## Returns an array of 4 TileTypeData IDs for biomes that use 16x16 quadrant
## variants from a 32x32 source tile. The quadrants are placed in a 2x2
## pattern (Q0_0=top-left, Q1_0=top-right, Q0_1=bottom-left, Q1_1=bottom-right)
## matching the original layout so seams are seamless.
## For biomes without variants, returns an array containing just the base ID.
func _biome_tile_variants(base_id: String) -> Array:
	match base_id:
		"cherry_grove":
			return ["cherry_grove_0", "cherry_grove_1", "cherry_grove_2", "cherry_grove_3"]
		"savanna":
			return ["savanna_0", "savanna_1", "savanna_2", "savanna_3"]
		"pine_forest":
			return ["pine_forest_0", "pine_forest_1", "pine_forest_2", "pine_forest_3"]
		"autumn_forest":
			return ["autumn_forest_0", "autumn_forest_1", "autumn_forest_2", "autumn_forest_3"]
		"flower_fields":
			return ["flower_fields_0", "flower_fields_1", "flower_fields_2", "flower_fields_3"]
		"jungle":
			return ["jungle_0", "jungle_1", "jungle_2", "jungle_3"]
		"wetlands":
			return ["wetlands_0", "wetlands_1", "wetlands_2", "wetlands_3"]
		_:
			return [base_id]

## Post-processes the tile grid to add beach sand and coastline edge tiles.
## Beach: walkable tiles adjacent to water get replaced with sand.
## Edge: water tiles adjacent to land get replaced with direction-specific
## cliff-edge tiles (N/S/W/E + corners) so the coastline looks varied.
func _add_beach_and_edge_tiles() -> void:
	for y in range(world_height):
		for x in range(world_width):
			var cell := Vector2i(x, y)
			var tile_id: String = _tile_grid[y][x]
			
			# Water cell with land neighbours → directional edge tile
			if tile_id == "water" and _has_land_neighbor(cell):
				var edge_id: String = _get_edge_direction(cell)
				if edge_id != "":
					_tile_grid[y][x] = edge_id
					var edge_type: TileTypeData = DataManager.get_tile_type(edge_id)
					if edge_type:
						ground_layer.set_cell(cell, 0, edge_type.atlas_coords)
			
			# Land cell with a water neighbour → beach sand
			elif tile_id != "water" and not tile_id.begins_with("edge") and tile_id != "tilled" \
				and tile_id != "watered_tilled" and _has_water_neighbor(cell):
				_tile_grid[y][x] = "sand"
				var sand_type: TileTypeData = DataManager.get_tile_type("sand")
				if sand_type:
					ground_layer.set_cell(cell, 0, sand_type.atlas_coords)

## Determines which directional edge tile to use for a water cell that
## has land neighbours. Checks cardinal directions first, then corners.
## Returns an edge tile id like "edge_n", "edge_ne", etc., or "" if none.
func _get_edge_direction(cell: Vector2i) -> String:
	var north: bool = _is_neighbor_land(cell, 0, -1)  # land above
	var south: bool = _is_neighbor_land(cell, 0, 1)   # land below
	var west: bool = _is_neighbor_land(cell, -1, 0)    # land left
	var east: bool = _is_neighbor_land(cell, 1, 0)     # land right
	
	# Cardinal directions
	if south and not west and not east and not north:
		return "edge_n"   # land is south → north-facing cliff
	if north and not west and not east and not south:
		return "edge_s"   # land is north → south-facing cliff
	if east and not north and not south and not west:
		return "edge_w"   # land is east → west-facing cliff
	if west and not north and not south and not east:
		return "edge_e"   # land is west → east-facing cliff
	
	# Corners (two adjacent directions)
	if south and east and not west and not north:
		return "edge_nw"  # land is SE → NW corner
	if south and west and not east and not north:
		return "edge_ne"  # land is SW → NE corner
	if north and east and not west and not south:
		return "edge_sw"  # land is NE → SW corner
	if north and west and not east and not south:
		return "edge_se"  # land is NW → SE corner
	
	# Fallback for complex cases (3+ land neighbours): pick first cardinal
	if north: return "edge_s"
	if south: return "edge_n"
	if west: return "edge_e"
	if east: return "edge_w"
	
	return ""

## Returns true if the neighbour at offset (dx, dy) from cell is land.
## Checks dynamically against TileTypeData: any walkable or tillable tile is land.
func _is_neighbor_land(cell: Vector2i, dx: int, dy: int) -> bool:
	var nc := Vector2i(cell.x + dx, cell.y + dy)
	if not _is_in_bounds(nc):
		return false
	var nid: String = _tile_grid[nc.y][nc.x]
	# Water and edge tiles are not land; everything else is land
	if nid == "water" or nid.begins_with("edge"):
		return false
	return true

## Returns true if any neighbour of the given cell is land.
## Picks positions for iron ore, strongly preferring mountain/stone tiles.
func _pick_mountain_favored_positions(count: int, rng: RandomNumberGenerator, is_blocked: Callable = func(_c): return false) -> Array:
	var positions: Array = []
	var attempts: int = 0
	while positions.size() < count and attempts < count * 50:
		attempts += 1
		var x := rng.randi_range(0, world_width - 1)
		var y := rng.randi_range(0, world_height - 1)
		var cell := Vector2i(x, y)
		# Skip cells blocked by buildings, dock footprint, or other objects
		if is_blocked.call(cell):
			continue
		var tile_id: String = _tile_grid[y][x]
		var biome_idx: int = _biome_grid[y][x] if y < _biome_grid.size() and x < _biome_grid[y].size() else -1
		var biome_type_int: int = _biome_index_to_type(biome_idx) if biome_idx >= 0 else -1
		var tile_type: TileTypeData = DataManager.get_tile_type(tile_id)
		if tile_type == null:
			var variants: Array = _biome_tile_variants(tile_id)
			if variants.size() > 0 and variants[0] is String:
				tile_type = DataManager.get_tile_type(variants[0])
		if not tile_type or not tile_type.walkable or tile_id == "water" or tile_id == "path":
			continue
		# Strongly prefer mountain/stone tiles (4x weight), allow any walkable as fallback
		if tile_id == "stone" or tile_id == "cobblestone_path" or biome_type_int == BiomeType.Type.MOUNTAIN:
			positions.append(cell)
		elif attempts > count * 30:
			# Fallback: any walkable after enough attempts
			positions.append(cell)
	return positions

func _has_land_neighbor(cell: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			if _is_neighbor_land(cell, dx, dy):
				return true
	return false

## Returns true if any neighbour of the given cell is water.
func _has_water_neighbor(cell: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var nc := Vector2i(cell.x + dx, cell.y + dy)
			if not _is_in_bounds(nc):
				return true  # out of bounds acts like water
			var nid: String = _tile_grid[nc.y][nc.x]
			if nid == "water" or nid.begins_with("edge"):
				return true
	return false

## Public wrapper: checks if any neighbor of the given cell is water or edge.
func has_water_neighbor(cell: Vector2i) -> bool:
	return _has_water_neighbor(cell)

## Returns the BiomeDefinition (display_name, etc.) at a tile coordinate, or null for water/edge.
func get_biome_definition_at(cell_x: int, cell_y: int) -> BiomeDefinition:
	if not _is_in_bounds(Vector2i(cell_x, cell_y)):
		return null
	# Check the biome grid - if -1 it's water
	if cell_y < _biome_grid.size() and cell_x < _biome_grid[cell_y].size() and _biome_grid[cell_y][cell_x] < 0:
		return null
	if biome_generator:
		return biome_generator.get_biome_at(cell_x, cell_y)
	return null

## Returns the biome index at a given tile coordinate, or -1 for water/edge.
func get_biome_at(cell_x: int, cell_y: int) -> int:
	if not _is_in_bounds(Vector2i(cell_x, cell_y)):
		return -1
	if _biome_grid.is_empty() or cell_y >= _biome_grid.size() or cell_x >= _biome_grid[cell_y].size():
		return -1
	return _biome_grid[cell_y][cell_x]

## Converts a biome index (from _biome_grid) to its BiomeType.Type enum value.
## This is needed because _biome_grid stores a list index, not the type enum.
func _biome_index_to_type(biome_idx: int) -> int:
	if biome_idx >= 0 and biome_idx < _biome_list.size():
		return _biome_list[biome_idx].type
	return -1

## Returns the biome definition at a given world position.
func get_biome_at_pos(world_pos: Vector2) -> BiomeDefinition:
	var cell := world_to_cell(world_pos)
	if not _is_in_bounds(cell):
		return null
	if biome_generator:
		return biome_generator.get_biome_at(cell.x, cell.y)
	return null

## Public helper so Animal.gd can check if a world position is walkable
## (not water or edge). Returns true if the cell at the given position is
## safe for an animal to walk on.
func is_cell_walkable(world_pos: Vector2) -> bool:
	var cell := world_to_cell(world_pos)
	if not _is_in_bounds(cell):
		return false
	var tile_id: String = _tile_grid[cell.y][cell.x]
	var tile_type: TileTypeData = DataManager.get_tile_type(tile_id)
	if tile_type == null:
		var variants: Array = _biome_tile_variants(tile_id)
		if variants.size() > 0 and variants[0] is String:
			tile_type = DataManager.get_tile_type(variants[0])
	return tile_type != null and tile_type.walkable

## Returns true if the given cell contains a fence or gate (blocks animal movement).
func is_fence_at_cell(cell: Vector2i) -> bool:
	if not building_system:
		return false
	var fence_types: Array = [BuildingSystem.BuildingType.FENCE, BuildingSystem.BuildingType.STONE_FENCE, BuildingSystem.BuildingType.GATE]
	return building_system.is_building_type_at(cell, fence_types)


## Returns true if there's a fence or gate within `range_cells` of the given position.
func is_position_near_fence(world_pos: Vector2, range_cells: int) -> bool:
	if not building_system:
		return false
	var cell := world_to_cell(world_pos)
	var fence_types: Array = [BuildingSystem.BuildingType.FENCE, BuildingSystem.BuildingType.STONE_FENCE, BuildingSystem.BuildingType.GATE]
	return building_system.is_near_building_type(cell, fence_types, range_cells)


func _scatter_objects() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + 1
	
	# Count land cells per biome display_name so we can compute correct
	# spawn densities for each biome (instead of using the entire world size).
	var biome_cell_counts: Dictionary = {}  # display_name -> int
	var biome_refs: Dictionary = {}         # display_name -> BiomeDefinition
	if biome_generator:
		for y in range(world_height):
			for x in range(world_width):
				var tile_id: String = _tile_grid[y][x]
				if tile_id == "water" or tile_id.begins_with("edge") or tile_id == "path" or tile_id == "sand":
					continue
				var biome := biome_generator.get_biome_at(x, y)
				if not biome or biome.resources.is_empty():
					continue
				var name_key: String = biome.display_name
				biome_cell_counts[name_key] = biome_cell_counts.get(name_key, 0) + 1
				biome_refs[name_key] = biome
	
	# Spawn resources for each biome with its per-cell count
	var spawner := ResourceSpawner.new()
	# Callable that checks if a cell is occupied by a building or the dock.
	# Also used for iron ore placement (via _pick_mountain_favored_positions),
	# so the town exclusion below protects BOTH biome resources and ores.
	var is_building_blocked := func(cell: Vector2i) -> bool:
		# Never place resources or ore on the town plaza or its buildings —
		# the backdrop sprite and ruin structures own that area.
		var town_rect: Rect2i = get_meta("town_rect", Rect2i())
		if town_rect.size.x > 0 and town_rect.has_point(cell):
			return true
		# Block resources on the dock's entire visual footprint (~30×14 cells)
		if _dock_cell != Vector2i(-1, -1):
			var dock_local := cell - _dock_cell
			if dock_local.y >= -3 and dock_local.y <= 11 and dock_local.x >= -10 and dock_local.x <= 25:
				return true
		# Block resources on the shop stand footprint (5x3 tiles)
		if _shop_cell != Vector2i(-1, -1):
			var shop_local := cell - _shop_cell
			if abs(shop_local.x) <= 2 and abs(shop_local.y) <= 1:
				return true
		if not building_system:
			return false
		for b in building_system.placed_buildings:
			var b_cell: Vector2i = b.get("cell", Vector2i(0, 0))
			var b_w: int = b.get("width", 1)
			var b_h: int = b.get("height", 1)
			if cell.x >= b_cell.x and cell.x < b_cell.x + b_w and cell.y >= b_cell.y and cell.y < b_cell.y + b_h:
				return true
		return false

	for name_key: String in biome_cell_counts:
		var biome: BiomeDefinition = biome_refs[name_key]
		var cell_count: int = biome_cell_counts[name_key]
		spawner.spawn_biome_resources(
			biome, cell_count,
			_tile_grid, world_width, world_height,
			rng, objects_root, cell_to_world,
			is_building_blocked
		)
	
	# Also scatter iron ore nodes (global, but favors mountain/stone biomes)
	var iron_rng := RandomNumberGenerator.new()
	iron_rng.seed = world_seed + 100
	var iron_positions: Array = _pick_mountain_favored_positions(iron_ore_count, iron_rng, is_building_blocked)
	# Track iron ore cells so trees and other objects avoid them
	_ore_cells.clear()
	for i in range(iron_positions.size()):
		var pos: Vector2 = iron_positions[i]
		_ore_cells[pos] = true
		var ore := RESOURCE_NODE_SCENE.instantiate()
		ore.name = "Ore_%d" % i
		ore.item_id = "iron_ore"
		ore.interaction_prompt = "Mine Iron Ore"
		ore.required_tool = Player.Tool.PICKAXE
		ore.min_amount = 1
		ore.max_amount = 2
		objects_root.add_child(ore)
		ore.global_position = cell_to_world(pos)

# ---------------------------------------------------------------------------
# Coordinate helpers
# ---------------------------------------------------------------------------

func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE_SIZE + TILE_SIZE / 2.0, cell.y * TILE_SIZE + TILE_SIZE / 2.0)

## Returns true if a fully-grown (mature) crop exists at the given world position.
## Used so the player can left-click a ready crop to harvest it directly.
func has_mature_crop(world_pos: Vector2) -> bool:
	var cell := world_to_cell(world_pos)
	if not _crop_nodes.has(cell):
		return false
	var crop: Crop = _crop_nodes[cell]
	return crop != null and crop.is_mature()

func world_to_cell(world_pos: Vector2) -> Vector2i:
	return Vector2i(floori(world_pos.x / TILE_SIZE), floori(world_pos.y / TILE_SIZE))

# ---------------------------------------------------------------------------
# Tool targeting preview (pulsing blue outline)
# ---------------------------------------------------------------------------

## Show a preview of which tiles the player's current tool would affect.
## Calls through so the Player can request a preview for hoe (multi-cell)
## or seeds (single cell). Pass null/empty world_pos to clear.
func show_tool_preview(target_world_pos: Vector2) -> void:
	var cell := world_to_cell(target_world_pos)
	if not _is_in_bounds(cell):
		_clear_tool_preview()
		return
	var cells: Array[Vector2i] = UpgradeManager.get_tool_area_cells(cell)
	# Filter to only show cells that are valid for the action
	var valid: Array[Vector2i] = []
	for c in cells:
		if _is_in_bounds(c):
			valid.append(c)
	if valid.is_empty():
		_clear_tool_preview()
	else:
		tool_preview.show_cells(valid)

## Show preview for a single-cell action (planting seeds).
## If build mode is active, shows the full building footprint instead.
func show_single_cell_preview(target_world_pos: Vector2) -> void:
	var cell := world_to_cell(target_world_pos)
	if not _is_in_bounds(cell):
		_clear_tool_preview()
		return

	# Build mode: show the full building footprint so the player can see
	# exactly where a multi-tile structure (fountain 2x2, house 3x3, etc.)
	# will be placed, not just a misleading 1-tile outline.
	if build_mode_active and build_type != BuildingSystem.BuildingType.NONE:
		var data: Dictionary = BuildingSystem.BUILDING_DATA.get(build_type, {})
		var w: int = data.get("width", 1)
		var h: int = data.get("height", 1)
		var cells: Array[Vector2i] = []
		for dx in range(w):
			for dy in range(h):
				cells.append(Vector2i(cell.x + dx, cell.y + dy))
		tool_preview.show_cells(cells)
		return

	tool_preview.show_cells([cell])

func clear_tool_preview() -> void:
	tool_preview.hide_preview()

func _clear_tool_preview() -> void:
	clear_tool_preview()

# ---------------------------------------------------------------------------
# Farming actions
# ---------------------------------------------------------------------------

## Maps a biome type to a season preference tag used by SeasonSystem.
## Crops planted in a biome that aligns with the current season get
## a growth bonus (1.25x); biome/season mismatches give a penalty (0.75x).
func _biome_to_season_tag(biome_type: int) -> String:
	match biome_type:
		BiomeType.Type.PLAINS, BiomeType.Type.MEADOW:
			return "spring"
		BiomeType.Type.FOREST, BiomeType.Type.SWAMP:
			return "warm"
		BiomeType.Type.MOUNTAIN:
			return "cool"
		BiomeType.Type.BEACH:
			return "summer"
		_:
			return "all"  # neutral

func till_tile(world_pos: Vector2) -> bool:
	var cells := UpgradeManager.get_tool_area_cells(world_to_cell(world_pos))
	var tilled_any := false
	for cell in cells:
		if _till_cell(cell):
			tilled_any = true
	if tilled_any:
		_show_first_action_hint("first_till",
			"Tilled! Select seeds in your hotbar (keys 3-0), then left-click the tilled soil to plant.")
	return tilled_any

func _till_cell(cell: Vector2i, simulate: bool = false) -> bool:
	if not _is_in_bounds(cell):
		return false
	var tile_id: String = _tile_grid[cell.y][cell.x]
	# Resolve biome base IDs (e.g. "cherry_grove") to a registered quadrant variant
	var tile_type: TileTypeData = DataManager.get_tile_type(tile_id)
	if tile_type == null:
		var variants: Array = _biome_tile_variants(tile_id)
		if variants.size() > 0 and variants[0] is String:
			tile_type = DataManager.get_tile_type(variants[0])
	if tile_type == null or not tile_type.tillable:
		return false
	if _soil_data.has(cell) and _soil_data[cell].is_tilled:
		return false
	
	_tile_grid[cell.y][cell.x] = "tilled"
	
	var soil := SoilData.new()
	soil.is_tilled = true
	_soil_data[cell] = soil
	
	var tilled_type: TileTypeData = DataManager.get_tile_type("tilled")
	ground_layer.set_cell(cell, 0, tilled_type.atlas_coords)
	
	# Effects
	EffectSpawner.spawn_dirt_puff(cell_to_world(cell))
	AudioManager.play(AudioManager.Sound.TILL)

	# Only the player who performed the action gets credit (XP/objectives).
	# Simulated runs (remote sync) replicate the tile state but grant nothing.
	var til_mgr := get_tree().get_first_node_in_group("objective_manager")
	if not simulate and til_mgr and til_mgr.has_method("on_tile_tilled"):
		til_mgr.on_tile_tilled()
	if not simulate:
		LevelManager.add_xp_source("till")
	
	# Sync to remote peers
	if NetworkManager.is_network_active():
		rpc("_sync_till_cell", cell)
	
	return true

func water_tile(world_pos: Vector2) -> bool:
	var cells := UpgradeManager.get_tool_area_cells(world_to_cell(world_pos))
	var watered_any := false
	for cell in cells:
		if _water_cell(cell):
			watered_any = true
	if watered_any:
		var wtr_mgr := get_tree().get_first_node_in_group("objective_manager")
		if wtr_mgr and wtr_mgr.has_method("on_tile_watered"):
			wtr_mgr.on_tile_watered()
		LevelManager.add_xp_source("water")
		_show_first_action_hint("first_water",
			"Watered! Crops grow over time — press [E] or left-click to harvest when ready.")
	return watered_any

func _water_cell(cell: Vector2i) -> bool:
	if not _soil_data.has(cell) or not _soil_data[cell].is_tilled or _soil_data[cell].is_watered:
		return false
	_soil_data[cell].is_watered = true
	
	# Watering improves soil quality slightly
	if _soil_data[cell].soil_quality:
		_soil_data[cell].soil_quality.improve(1)
		# Cap at good quality from watering alone
		if _soil_data[cell].soil_quality.current_level > SoilQuality.QualityLevel.GOOD:
			_soil_data[cell].soil_quality.current_level = SoilQuality.QualityLevel.GOOD
	
	var watered_type: TileTypeData = DataManager.get_tile_type("watered_tilled")
	ground_layer.set_cell(cell, 0, watered_type.atlas_coords)
	
	# Effects
	EffectSpawner.spawn_water_droplets(cell_to_world(cell))
	AudioManager.play(AudioManager.Sound.WATER)
	
	# Sync to remote peers
	if NetworkManager.is_network_active():
		rpc("_sync_water_cell", cell)
	
	return true

## Checks if the player has any seeds in inventory.
func _has_any_seed() -> bool:
	var inv: Node = InventoryManager
	if not inv:
		return false
	for slot in inv.slots:
		if slot is Dictionary and not slot.is_empty():
			var item: ItemData = DataManager.get_item(slot.get("item_id", ""))
			if item and item.category == "seed":
				return true
	return false

## Finds the most appropriate seed to plant from inventory.
## Returns [crop_id, seed_item_id] or empty Array if none found.
func _find_seed_to_plant() -> Array:
	var inv: Node = InventoryManager
	if not inv:
		return []
	var best_crop_id: String = ""
	var best_count: int = 0
	for slot in inv.slots:
		if slot is Dictionary and not slot.is_empty():
			var item: ItemData = DataManager.get_item(slot.get("item_id", ""))
			if item and item.category == "seed":
				var count: int = slot.get("count", 0)
				# Prefer seeds the player has most of (they committed to this crop)
				if count > best_count:
					best_count = count
					# Find the crop that produces this seed
					for c_id: String in DataManager.crops:
						var c: CropData = DataManager.get_crop(c_id)
						if c and c.seed_item_id == slot["item_id"]:
							best_crop_id = c.id
							break
	if best_crop_id != "":
		return [best_crop_id, DataManager.get_crop(best_crop_id).seed_item_id if DataManager.get_crop(best_crop_id) else ""]
	return []

func plant_seed(world_pos: Vector2, crop_id: String) -> bool:
	# Use tool area for mass planting — seeds consume from inventory per tile
	var cells := UpgradeManager.get_tool_area_cells(world_to_cell(world_pos))
	var planted_any := false
	for cell in cells:
		if _plant_seed_cell(cell, crop_id):
			planted_any = true
	if planted_any:
		var plnt_mgr := get_tree().get_first_node_in_group("objective_manager")
		if plnt_mgr and plnt_mgr.has_method("on_crop_planted"):
			plnt_mgr.on_crop_planted()
		LevelManager.add_xp_source("plant")
		# Count how many were actually planted for the toast
		var count := 0
		for c in cells:
			if _soil_data.has(c) and _soil_data[c].crop_id == crop_id and _soil_data[c].days_grown == 0 and _crop_nodes.has(c):
				count += 1
		if count > 1:
			var crop_data_display: CropData = DataManager.get_crop(crop_id)
			var name_str: String = crop_data_display.display_name if crop_data_display else crop_id
			ToastNotification.show_toast("Planted %d %s seeds!" % [count, name_str], ToastNotification.ToastType.SUCCESS, 2.0)
		_show_first_action_hint("first_plant",
			"Planted! Press [2] for the Watering Can, then left-click or [F] to water it.")
	return planted_any

## Plant a single seed cell. Returns true if planted. `simulate` marks
## remote-sync runs, which replicate state but must NOT consume the remote
## player's inventory or grant any rewards.
func _plant_seed_cell(cell: Vector2i, crop_id: String, simulate: bool = false) -> bool:
	if not _soil_data.has(cell) or not _soil_data[cell].is_tilled or _soil_data[cell].crop_id != "":
		return false

	var crop_data: CropData = DataManager.get_crop(crop_id)
	if not crop_data or crop_data.seed_item_id == "":
		return false
	if not simulate and not InventoryManager.has_item(crop_data.seed_item_id, 1):
		return false

	if not simulate:
		InventoryManager.remove_item(crop_data.seed_item_id, 1)
		GameManager.total_seeds_planted += 1
	
	# Apply biome-specific traits if the trait generator and biome generator are available
	var effective_crop_id := crop_id
	var biome_trait_tags_to_set: Array = []
	if crop_trait_generator and biome_generator:
		var biome: BiomeDefinition = biome_generator.get_biome_at(cell.x, cell.y)
		if biome:
			# Set season preference based on biome type — this feeds into
			# SeasonSystem.get_growth_multiplier() so crops planted in
			# season-aligned biomes grow faster (1.25x) and out-of-season
			# biomes grow slower (0.75x).
			_soil_data[cell].season_tag = _biome_to_season_tag(biome.type)
			if biome.crop_trait_tags.size() > 0:
				biome_trait_tags_to_set = biome.crop_trait_tags.duplicate()
				var modified = crop_trait_generator.apply_biome_traits(crop_data, biome, cell.x, cell.y)
				if modified:
					effective_crop_id = crop_id  # keep same base id
	
	_soil_data[cell].crop_id = effective_crop_id
	_soil_data[cell].days_grown = 0
	
	# Crop rotation bonus: planting a different crop on previously-used soil
	# improves soil quality and gives a one-time growth boost.
	var prev_crop: String = _soil_data[cell].previous_crop_id
	if prev_crop != "" and prev_crop != effective_crop_id:
		# Different crop family — rotation bonus!
		if _soil_data[cell].soil_quality:
			_soil_data[cell].soil_quality.improve(1)
		# Give an extra growth day as a rotation bonus
		_soil_data[cell].days_grown = 1
		_soil_data[cell].previous_crop_id = ""  # Reset so bonus only applies once per rotation
		if not simulate:
			ToastNotification.show_toast("Crop rotation! Soil quality +1", ToastNotification.ToastType.SUCCESS, 1.5)
	
	# Season feedback on planting
	if not simulate and GameManager.season_system and _soil_data[cell].season_tag != "":
		var season_desc: String = GameManager.season_system.get_season_description(_soil_data[cell].season_tag)
		ToastNotification.show_toast(season_desc, ToastNotification.ToastType.INFO, 3.0)
	
	var crop: Crop = CROP_SCENE.instantiate()
	objects_root.add_child(crop)
	crop.global_position = cell_to_world(cell)
	crop.setup(effective_crop_id, 0)
	if not biome_trait_tags_to_set.is_empty():
		crop.set_meta("biome_trait_tags", biome_trait_tags_to_set)
	# Greenhouse bonus: +5% mutation chance for crops grown inside
	if _is_near_greenhouse(cell):
		crop.set_meta("greenhouse_mutation_bonus", 0.05)
	crop.mutated.connect(_on_crop_mutated.bind(cell))
	_crop_nodes[cell] = crop
	
	# Creative mode: instantly grow crop to maturity
	if GameManager.is_creative() and GameManager.creative_instant_growth:
		var crop_data_ref: CropData = DataManager.get_crop(effective_crop_id)
		if crop_data_ref:
			var max_loops := 200
			while not crop.is_mature() and max_loops > 0:
				crop.grow()
				max_loops -= 1
			_soil_data[cell].days_grown = crop.days_grown
	
	# Effects
	AudioManager.play(AudioManager.Sound.PLANT)
	
	# Sync to remote peers, carrying the crop's genetics so every peer builds
	# the SAME plant (no per-peer unseeded RNG roll → no farm divergence).
	if NetworkManager.is_network_active():
		var gen: Dictionary = {}
		if _crop_nodes.has(cell) and _crop_nodes[cell] and _crop_nodes[cell].genetics:
			gen = _crop_nodes[cell].genetics.serialize()
		rpc("_sync_plant_cell", cell, effective_crop_id, gen)
	
	return true

func harvest_crop(world_pos: Vector2) -> bool:
	var cell := world_to_cell(world_pos)
	if not _crop_nodes.has(cell):
		return false
	var crop: Crop = _crop_nodes[cell]
	if not crop.is_mature():
		return false
	
	var crop_data: CropData = DataManager.get_crop(crop.crop_id)
	if not crop_data:
		return false

	if not InventoryManager.can_fit(crop_data.yield_item_id, crop_data.yield_amount):
		return false  # inventory full - leave the crop growing rather than losing the harvest
	
	var soil: SoilData = _soil_data.get(cell)
	
	# Calculate quality tier
	var quality_tier := CropQuality.QualityTier.NORMAL
	if soil:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(str(world_seed) + ":quality:" + str(cell.x) + "," + str(cell.y))
		var watered_every_day := soil.unwatered_days == 0
		var season_favorable := true
		if GameManager.season_system:
			season_favorable = GameManager.season_system.is_season_favorable(soil.season_tag)
		
		var soil_level := SoilQuality.QualityLevel.AVERAGE
		if soil.soil_quality:
			soil_level = soil.soil_quality.current_level
		
		quality_tier = CropQuality.calculate_quality(
			soil_level,
			soil.fertilizer and soil.fertilizer.is_active(),
			watered_every_day,
			season_favorable,
			soil.days_grown,
			crop_data.days_to_grow,
			rng
		)
		# Track best quality tier for stats
		if quality_tier > GameManager.best_quality_tier:
			GameManager.best_quality_tier = quality_tier
	
	# Calculate yield with quality multiplier + farmer level perk
	var base_yield: int = crop_data.yield_amount
	var quality_mult := CropQuality.get_price_multiplier(quality_tier)
	var level_mult := LevelManager.get_harvest_multiplier()
	var effective_yield := maxi(1, roundi(base_yield * quality_mult * level_mult))
	
	# Apply soil yield boost
	if soil:
		effective_yield = maxi(1, roundi(effective_yield * soil.get_effective_yield_boost()))
	
	# Apply season yield bonus (in-season = 1.25x yield)
	if soil and GameManager.season_system:
		var season_yield_mult := GameManager.season_system.get_yield_multiplier(soil.season_tag)
		effective_yield = maxi(1, roundi(effective_yield * season_yield_mult))
	
	# Giant crop chance (1% with fertile soil)
	var is_giant := false
	if soil and soil.soil_quality and soil.soil_quality.current_level >= SoilQuality.QualityLevel.RICH:
		if randf() < 0.01:
			is_giant = true
			effective_yield *= 3
			soil.is_giant_crop = true
	
	# Add the yield items
	InventoryManager.add_item(crop_data.yield_item_id, clamp(effective_yield, 1, 99))
	DataManager.mark_discovered(crop_data.id)
	
	# Also drop 1-2 seeds back so the farming loop is self-sustaining
	var seed_to_drop: int = 1 if randi() % 3 == 0 else 2  # 2/3 chance of 2 seeds
	# Higher quality = more seeds
	if quality_tier >= CropQuality.QualityTier.GOLD:
		seed_to_drop += 1
	if crop_data.seed_item_id != "":
		InventoryManager.add_item(crop_data.seed_item_id, min(seed_to_drop, 5))
	
	# Rare drop chance (5% base + pet loot bonus)
	var rare_loot_bonus: float = 0.0
	var pet_mgr_loot: Node = PetManager
	if pet_mgr_loot and pet_mgr_loot.has_method("get_loot_bonus"):
		rare_loot_bonus = pet_mgr_loot.get_loot_bonus()
	if randf() < 0.03 + rare_loot_bonus:
		var all_crops: Array = DataManager.crops.values()
		if not all_crops.is_empty():
			var rare_crop: CropData = all_crops[randi() % all_crops.size()]
			if rare_crop and rare_crop.seed_item_id != "":
				InventoryManager.add_item(rare_crop.seed_item_id, 1)
				ToastNotification.show_toast("Found rare %s seed!" % rare_crop.display_name, ToastNotification.ToastType.SUCCESS, 3.0)
	
	# Ultra-rare Inconstant Fruit drop from harvesting (0.1%)
	if randf() < 0.001 + rare_loot_bonus * 0.01:
		var inconstant_fruits: Array[ItemData] = InconstantFruitSystem.get_wild_findable_fruits()
		if not inconstant_fruits.is_empty():
			var chosen: ItemData = inconstant_fruits[randi() % inconstant_fruits.size()]
			if InventoryManager.can_fit(chosen.id, 1):
				InventoryManager.add_item(chosen.id, 1)
				ToastNotification.show_toast("[color=#FFD700]✦ Legendary Harvest! ✦[/color]\nA %s emerges from the crops!" % chosen.display_name, ToastNotification.ToastType.SUCCESS, 5.0)
				AudioManager.play(AudioManager.Sound.LEVEL_UP)
				EffectSpawner.spawn_sparkle(crop.global_position, Color(1.0, 0.8, 0.3))
	
	# Effects
	var harvest_color: Color = crop_data.modulate_color
	if crop.genetics:
		harvest_color = crop.genetics.to_color()
	
	# Enhanced harvest animation
	var quality_suffix := CropQuality.get_tier_suffix(quality_tier)
	HarvestAnimation.play_harvest_effect(crop.global_position, crop_data.display_name + quality_suffix, harvest_color, quality_tier)
	AudioManager.play(AudioManager.Sound.HARVEST)
	
	_show_first_action_hint("first_harvest",
		"Harvested! Sell crops at the Boat (east coast) or eat them. Press [O] for objectives!")
	
	# Track farming stats
	GameManager.total_crops_harvested += 1
	if is_giant:
		GameManager.total_giant_crops_harvested += 1
	
	# Giant crop notification
	if is_giant:
		ToastNotification.show_toast("Giant %s harvested! ★★★" % crop_data.display_name, ToastNotification.ToastType.SUCCESS, 4.0)
	
	# Quality notification for silver+
	if quality_tier >= CropQuality.QualityTier.SILVER:
		var tier_name := CropQuality.get_tier_name(quality_tier)
		ToastNotification.show_toast("%s quality %s!" % [tier_name, crop_data.display_name], ToastNotification.ToastType.SUCCESS, 2.5)
	
	# Save crop for rotation tracking before removing/changing it
	if soil:
		soil.previous_crop_id = crop_data.id
	
	if crop_data.regrows:
		crop.harvest()
		_soil_data[cell].days_grown = crop_data.regrow_days
		_sync_harvest_if_active(cell, 1)
	else:
		# Sprout chance: 30% base. Higher with quality soil/fertilizer.
		var sprout_chance := 0.3
		if soil and soil.soil_quality:
			if soil.soil_quality.current_level >= SoilQuality.QualityLevel.RICH:
				sprout_chance = 0.55
			elif soil.soil_quality.current_level >= SoilQuality.QualityLevel.GOOD:
				sprout_chance = 0.45
		if soil and soil.fertilizer and soil.fertilizer.is_active():
			sprout_chance += 0.1
		if soil and soil.is_composted:
			sprout_chance += 0.05
		
		# Deterministic sprout chance (seeded by world_seed + cell + day)
		var rng_sprout := RandomNumberGenerator.new()
		rng_sprout.seed = hash(str(world_seed) + ":sprout_chance:" + str(cell.x) + "," + str(cell.y) + ":" + str(GameManager.current_day))
		if rng_sprout.randi() % 100 < sprout_chance * 100:
			# Sprout remains — regrows in 2-3 days
			crop.reset_to_sprout()
			_soil_data[cell].days_grown = 0
			_soil_data[cell].crop_id = crop_data.id
			# RNG mutation chance on sprout regrow (10% if composted/fertilized)
			if soil and (soil.fertilizer or soil.is_composted):
				var rng_mut := RandomNumberGenerator.new()
				rng_mut.seed = hash(str(world_seed) + ":sprout_mut:" + str(cell.x) + "," + str(cell.y) + ":" + str(GameManager.current_day))
				if rng_mut.randi() % 100 < 10:
					_trigger_sprout_mutation(cell, crop_data)
			_sync_harvest_if_active(cell, 2)
		else:
			crop.queue_free()
			_crop_nodes.erase(cell)
			_soil_data[cell].crop_id = ""
			_soil_data[cell].days_grown = 0
			_sync_harvest_if_active(cell, 0)
	
	# Compost bin passive effect: 40% chance to generate compost from crop waste
	if _is_near_compost_bin(cell):
		var compost_chance := 0.4
		# Higher quality crops produce quality compost
		if quality_tier >= CropQuality.QualityTier.GOLD:
			if randf() < compost_chance and InventoryManager.can_fit("quality_compost", 1):
				InventoryManager.add_item("quality_compost", 1)
				GameManager.total_compost_produced += 1
				ToastNotification.show_toast("Compost Bin turned waste into Quality Compost!", ToastNotification.ToastType.SUCCESS, 2.0)
		elif randf() < compost_chance and InventoryManager.can_fit("compost", 1):
			InventoryManager.add_item("compost", 1)
			GameManager.total_compost_produced += 1
			ToastNotification.show_toast("Compost Bin turned waste into Compost!", ToastNotification.ToastType.SUCCESS, 2.0)
	
	var hvst_mgr := get_tree().get_first_node_in_group("objective_manager")
	if hvst_mgr and hvst_mgr.has_method("on_crop_harvested"):
		hvst_mgr.on_crop_harvested()
	# XP for harvest: base + bonus per quality tier above Normal
	var quality_bonus := quality_tier * LevelManager.XP_REWARDS["harvest_quality"]
	LevelManager.add_xp(LevelManager.XP_REWARDS["harvest"] + quality_bonus, "harvest")
	
	return true

func _trigger_sprout_mutation(cell: Vector2i, crop_data) -> void:
	# 10% chance for a random mutation on sprout regrow
	if not crop_data or not _crop_nodes.has(cell):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(world_seed) + ":sprout:" + str(cell.x) + "," + str(cell.y) + ":" + str(GameManager.current_day))
	# Pick a random mutation from available ones
	var all_crops: Array = DataManager.crops.values()
	if all_crops.is_empty():
		return
	var rare_crop = all_crops[rng.randi() % all_crops.size()]
	if rare_crop and rare_crop.seed_item_id != "":
		_crop_nodes[cell].crop_id = rare_crop.id
		_soil_data[cell].crop_id = rare_crop.id
		ToastNotification.show_toast("Sprout mutated into %s!" % rare_crop.display_name, ToastNotification.ToastType.SUCCESS, 3.0)

## Keeps SoilData in sync when a Crop mutates into a new crop id mid-growth,
## and forwards a notification for the UI to display.
func _on_crop_mutated(_crop: Crop, old_crop_id: String, new_crop_id: String, mutation_name: String, cell: Vector2i) -> void:
	GameManager.total_mutations_occurred += 1
	if _soil_data.has(cell):
		_soil_data[cell].crop_id = new_crop_id

	var old_crop_data: CropData = DataManager.get_crop(old_crop_id)
	var new_crop_data: CropData = DataManager.get_crop(new_crop_id)
	var old_name: String = old_crop_data.display_name if old_crop_data else old_crop_id
	var new_name: String = new_crop_data.display_name if new_crop_data else new_crop_id
	GameManager.crop_mutated.emit(old_name, new_name, mutation_name)
	LevelManager.add_xp_source("mutation")

	# Track mutation objective
	var om := get_tree().get_first_node_in_group("objective_manager")
	if om and om.has_method("on_crop_mutated"):
		om.on_crop_mutated()

## Apply compost to a tilled tile with a growing crop. Boosts growth by 1
## day immediately (composted crops grow 2 days on the next day change).
## Returns true if compost was used.
func apply_compost(world_pos: Vector2) -> bool:
	var cell := world_to_cell(world_pos)
	if not _soil_data.has(cell) or not _soil_data[cell].is_tilled:
		return false
	var soil: SoilData = _soil_data[cell]
	if soil.crop_id == "":
		return false
	
	# Check for different fertilizer types
	var fertilizer_type := FertilizerSystem.FertilizerType.NONE
	var fertilizer_duration := 3
	var fertilizer_item := ""
	
	if InventoryManager.has_item("super_fertilizer", 1):
		fertilizer_type = FertilizerSystem.FertilizerType.SUPER_FERTILIZER
		fertilizer_duration = 10
		fertilizer_item = "super_fertilizer"
	elif InventoryManager.has_item("rich_fertilizer", 1):
		fertilizer_type = FertilizerSystem.FertilizerType.RICH_FERTILIZER
		fertilizer_duration = 7
		fertilizer_item = "rich_fertilizer"
	elif InventoryManager.has_item("yield_enhancer", 1):
		fertilizer_type = FertilizerSystem.FertilizerType.YIELD_ENHANCER
		fertilizer_duration = 6
		fertilizer_item = "yield_enhancer"
	elif InventoryManager.has_item("growth_booster", 1):
		fertilizer_type = FertilizerSystem.FertilizerType.GROWTH_BOOSTER
		fertilizer_duration = 4
		fertilizer_item = "growth_booster"
	elif InventoryManager.has_item("quality_compost", 1):
		fertilizer_type = FertilizerSystem.FertilizerType.QUALITY_COMPOST
		fertilizer_duration = 5
		fertilizer_item = "quality_compost"
	elif InventoryManager.has_item("compost", 1):
		fertilizer_type = FertilizerSystem.FertilizerType.BASIC_COMPOST
		fertilizer_duration = 3
		fertilizer_item = "compost"
	else:
		ToastNotification.show_toast("No compost or fertilizer available!", ToastNotification.ToastType.WARNING, 2.0)
		return false
	
	InventoryManager.remove_item(fertilizer_item, 1)
	
	if fertilizer_type == FertilizerSystem.FertilizerType.BASIC_COMPOST:
		soil.is_composted = true
	
	soil.apply_fertilizer(fertilizer_type, fertilizer_duration)
	
	# Immediate visual feedback
	var fert_color := soil.fertilizer.get_color() if soil.fertilizer else Color(0.3, 0.7, 0.3)
	if _crop_nodes.has(cell):
		_crop_nodes[cell].modulate = fert_color
	
	EffectSpawner.spawn_particles(cell_to_world(cell), fert_color, 8, 14.0)
	var fert_name := soil.fertilizer.get_name() if soil.fertilizer else "Compost"
	ToastNotification.show_toast("%s applied! Growth & soil boosted." % fert_name, ToastNotification.ToastType.SUCCESS, 2.0)
	AudioManager.play(AudioManager.Sound.PLANT)
	
	# Sync to all peers (acting peer broadcasts, like _sync_till_cell)
	if NetworkManager.is_network_active():
		rpc("_sync_apply_compost", cell, int(fertilizer_type), fertilizer_duration)
	
	return true


## Received by all peers: apply compost/fertilizer to soil.
@rpc("any_peer", "call_local")
func _sync_apply_compost(cell: Vector2i, fertilizer_type: int, duration: int) -> void:
	if not _soil_data.has(cell) or not _soil_data[cell].is_tilled:
		return
	var soil: SoilData = _soil_data[cell]
	if soil.crop_id == "":
		return
	
	if fertilizer_type == int(FertilizerSystem.FertilizerType.BASIC_COMPOST):
		soil.is_composted = true
	
	soil.apply_fertilizer(fertilizer_type as FertilizerSystem.FertilizerType, duration)
	
	# Visual feedback
	var fert_color := soil.fertilizer.get_color() if soil.fertilizer else Color(0.3, 0.7, 0.3)
	if _crop_nodes.has(cell):
		_crop_nodes[cell].modulate = fert_color

# ---------------------------------------------------------------------------
# Sprinkler system
# ---------------------------------------------------------------------------

## Place a sprinkler on a tilled tile. Auto-waters adjacent tiles each morning.
## Returns true if placed successfully.
## Returns the water radius for a given sprinkler tier.
func _get_sprinkler_radius(tier: int) -> int:
	match tier:
		0: return 1  # Basic 3×3 (radius 1)
		1: return 2  # Quality 5×5 (radius 2)
		2: return 3  # Iridium 7×7 (radius 3)
		_: return 1

## Returns the tier level for a sprinkler item id.
func _sprinkler_item_to_tier(item_id: String) -> int:
	match item_id:
		"sprinkler": return 0
		"quality_sprinkler": return 1
		"iridium_sprinkler": return 2
		_: return -1

func place_sprinkler(world_pos: Vector2) -> bool:
	var cell := world_to_cell(world_pos)
	if not _is_in_bounds(cell):
		return false
	# Must be on tilled soil
	if not _soil_data.has(cell) or not _soil_data[cell].is_tilled:
		ToastNotification.show_toast("Place sprinklers on tilled soil!", ToastNotification.ToastType.WARNING, 2.0)
		return false
	# Must not already have a sprinkler
	if _sprinklers.has(cell):
		ToastNotification.show_toast("Sprinkler already here!", ToastNotification.ToastType.WARNING, 2.0)
		return false
	
	# Check for sprinkler items in priority order (best first)
	var tier: int = -1
	var item_id: String = ""
	for check_id in ["iridium_sprinkler", "quality_sprinkler", "sprinkler"]:
		if InventoryManager.has_item(check_id, 1):
			tier = _sprinkler_item_to_tier(check_id)
			item_id = check_id
			break
	if tier < 0 or not InventoryManager.remove_item(item_id, 1):
		return false
	
	_sprinklers[cell] = {"active": true, "placed_day": GameManager.current_day, "tier": tier}
	
	# Sync to all peers (acting peer broadcasts, like _sync_till_cell)
	if NetworkManager.is_network_active():
		rpc("_sync_place_sprinkler", cell, tier)
	
	# Visual feedback based on tier
	var color: Color
	var toast_msg: String
	match tier:
		0:
			color = Color(0.3, 0.6, 1.0)
			toast_msg = "Sprinkler placed! Waters 3×3 area each dawn."
		1:
			color = Color(0.2, 0.8, 1.0)
			toast_msg = "Quality Sprinkler placed! Waters 5×5 area each dawn."
		2:
			color = Color(0.6, 0.3, 1.0)
			toast_msg = "Iridium Sprinkler placed! Waters 7×7 area with fertilizer each dawn."
	
	EffectSpawner.spawn_particles(cell_to_world(cell), color, 6, 10.0)
	AudioManager.play(AudioManager.Sound.PLANT)
	ToastNotification.show_toast(toast_msg, ToastNotification.ToastType.SUCCESS, 2.5)
	var spr_mgr := get_tree().get_first_node_in_group("objective_manager")
	if spr_mgr and spr_mgr.has_method("on_sprinkler_placed"):
		spr_mgr.on_sprinkler_placed()
	return true


## Received by all peers: place sprinkler.
@rpc("any_peer", "call_local")
func _sync_place_sprinkler(cell: Vector2i, tier: int) -> void:
	if not _is_in_bounds(cell):
		return
	if not _soil_data.has(cell) or not _soil_data[cell].is_tilled:
		return
	if _sprinklers.has(cell):
		return
	
	_sprinklers[cell] = {"active": true, "placed_day": GameManager.current_day, "tier": tier}

# ---------------------------------------------------------------------------
# Scythe — mass harvest all mature crops in tool area
# ---------------------------------------------------------------------------

## Harvests all mature crops in the tool's area range at once.
func scythe_harvest(world_pos: Vector2) -> bool:
	var cell := world_to_cell(world_pos)
	if not _is_in_bounds(cell):
		return false
	var cells := UpgradeManager.get_tool_area_cells(cell)
	var harvested_any := false
	var delay := 0.0
	for c in cells:
		if _crop_nodes.has(c):
			var crop: Crop = _crop_nodes[c]
			if crop.is_mature():
				# Stagger effects slightly for visual satisfaction
				if delay > 0.0:
					get_tree().create_timer(delay).timeout.connect(_spawn_harvest_particles.bind(crop.global_position))
				harvest_crop(cell_to_world(c))
				harvested_any = true
				delay += 0.05
	if harvested_any:
		AudioManager.play(AudioManager.Sound.HARVEST)
	return harvested_any

func _spawn_harvest_particles(pos: Vector2) -> void:
	EffectSpawner.spawn_particles(pos, Color(1.0, 0.9, 0.4), 3, 8.0)

func _on_day_changed(_day: int) -> void:
	# World farm/soil/crop growth is HOST-AUTHORITATIVE: only the host (or
	# single-player) recomputes it. Clients apply the host's daily farm delta
	# (_apply_farm_delta) instead of running divergent RNG-driven growth,
	# mutation and disease. Per-player day effects (wallet interest, own buffs)
	# are handled by the client's own day_changed emission in
	# GameManager._receive_time_state.
	if NetworkManager.is_network_active() and not multiplayer.is_server():
		return
	# Grouped notification counters
	var newly_mature_count: int = 0
	var first_mature_name: String = ""
	
	# Sprinklers auto-water adjacent tiles before crop growth
	for cell in _sprinklers.keys():
		var s_data: Dictionary = _sprinklers[cell]
		var tier: int = s_data.get("tier", 0)
		var radius: int = _get_sprinkler_radius(tier)
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				if dx == 0 and dy == 0:
					continue
				var adj := Vector2i(cell.x + dx, cell.y + dy)
				if _soil_data.has(adj) and _soil_data[adj].is_tilled:
					_soil_data[adj].is_watered = true
					# Iridium sprinklers apply a mild fertilizer effect
					if tier >= 2:
						if _soil_data[adj].fertilizer == null or not _soil_data[adj].fertilizer.is_active():
							_soil_data[adj].apply_fertilizer(FertilizerSystem.FertilizerType.QUALITY_COMPOST, 1)
	
	for cell in _soil_data.keys():
		var soil: SoilData = _soil_data[cell]
		
		# Capture watering state BEFORE advance_daily() clears it, so
		# yesterday's watering fuels today's growth.
		var was_watered: bool = soil.is_watered
		
		# Advance daily soil systems (clears is_watered, decays fertilizer, etc.)
		soil.advance_daily()
		
		# Greenhouse prevents soil degradation — counteract any loss
		if _is_near_greenhouse(cell) and soil.soil_quality and soil.crop_id != "":
			if soil.soil_quality.current_level < SoilQuality.QualityLevel.GOOD:
				soil.soil_quality.improve(1)
		
		if soil.crop_id != "":
			var crop_data: CropData = DataManager.get_crop(soil.crop_id)
			if crop_data and (not crop_data.requires_water or was_watered):
				# Crop got water (or doesn't need it) — grows normally
				soil.unwatered_days = 0
				
				# Calculate growth based on soil quality, fertilizer, season, compost, pet
				var growth_boost := soil.get_effective_growth_boost()
				# Pet growth bonus multiplies growth
				var pet_growth_bonus: float = 0.0
				var pet_mgr_grow: Node = PetManager
				if pet_mgr_grow and pet_mgr_grow.has_method("get_growth_bonus"):
					pet_growth_bonus = pet_mgr_grow.get_growth_bonus()
				if pet_growth_bonus > 0.0:
					growth_boost *= (1.0 + pet_growth_bonus)
				
				# Season effect — greenhouse overrides with always-favorable
				if GameManager.season_system:
					var season_mult: float
					if _is_near_greenhouse(cell):
						# Greenhouse: always favorable season (1.25x)
						season_mult = GameManager.season_system.get_growth_multiplier(soil.season_tag)
						if season_mult < 1.0:
							season_mult = 1.25
					else:
						season_mult = GameManager.season_system.get_growth_multiplier(soil.season_tag)
					growth_boost *= season_mult
				
				# Apply growth (rounded, minimum 1)
				var growth_days := maxi(1, roundi(growth_boost))
				
				# Growth buff from meals multiplies growth speed
				var growth_buff_str: float = BuffManager.get_strength("growth") if BuffManager else 0.0
				if growth_buff_str > 0.0:
					growth_days = maxi(1, roundi(growth_days / growth_buff_str))
				soil.days_grown += growth_days
				
				if _crop_nodes.has(cell):
					var crop_node: Crop = _crop_nodes[cell] as Crop
					for g in range(growth_days):
						var was_mature: bool = crop_node.is_mature() if crop_node else false
						if crop_node:
							crop_node.grow()
						# Count newly mature crops for grouped notification
						if crop_node and not was_mature and crop_node.is_mature():
							newly_mature_count += 1
							if first_mature_name == "":
								var cd_name: CropData = DataManager.get_crop(soil.crop_id)
								if cd_name:
									first_mature_name = cd_name.display_name
					
					# Check for disease
					if not soil.disease.is_infected():
						var disease_chance := 0.02  # 2% base chance per day
						# Poor soil = more disease
						if soil.soil_quality and soil.soil_quality.current_level <= SoilQuality.QualityLevel.POOR:
							disease_chance = 0.08
						# Rich soil = less disease
						elif soil.soil_quality and soil.soil_quality.current_level >= SoilQuality.QualityLevel.RICH:
							disease_chance = 0.005
						
						# Scarecrow reduces disease chance by 50% within 5×5 area
						if disease_chance > 0.0 and _is_near_scarecrow(cell):
							disease_chance *= 0.5
						# Greenhouse halves disease chance too
						if disease_chance > 0.0 and _is_near_greenhouse(cell):
							disease_chance *= 0.5
						
						var resistance_tags: Array = []
						if crop_node and crop_node.has_meta("biome_trait_tags"):
							resistance_tags = crop_node.get_meta("biome_trait_tags")
						
						if soil.disease.try_infect(disease_chance, resistance_tags):
							ToastNotification.show_toast("%s has %s!" % [crop_data.display_name, soil.disease.get_disease_name()], ToastNotification.ToastType.WARNING, 3.0)
					
					# Show disease visual
					if soil.disease.is_infected():
						var dc := soil.disease.get_disease_color()
						_crop_nodes[cell].modulate = dc
					
					# Check for hybrid crop opportunity (adjacent different crops)
					if _check_hybrid_opportunity(cell, soil):
						pass
		
			elif crop_data and crop_data.requires_water:
				# Crop needs water but wasn't watered — track stress
				soil.unwatered_days += 1
				if _crop_nodes.has(cell):
					if soil.unwatered_days >= 3:
						# Crop dies after 3 days without water
						_crop_nodes[cell].queue_free()
						_crop_nodes.erase(cell)
						soil.crop_id = ""
						soil.days_grown = 0
						soil.unwatered_days = 0
						EffectSpawner.spawn_particles(cell_to_world(cell), Color(0.6, 0.3, 0.1), 4, 8.0)
						ToastNotification.show_toast("Crop wilted from thirst!", ToastNotification.ToastType.WARNING, 3.0)
					else:
						# Show wilted visual (brownish tint)
						_crop_nodes[cell].modulate = Color(0.7, 0.6, 0.4)
		
		# Update tile appearance based on watered/dry state and soil quality
		if soil.is_tilled and soil.crop_id == "":
			var tilled_type: TileTypeData = DataManager.get_tile_type("tilled")
			ground_layer.set_cell(cell, 0, tilled_type.atlas_coords)
			# Tint based on soil quality
			_apply_soil_quality_tint(cell, soil)
		elif soil.is_tilled and soil.is_watered:
			var watered_type: TileTypeData = DataManager.get_tile_type("watered_tilled")
			ground_layer.set_cell(cell, 0, watered_type.atlas_coords)
			_apply_soil_quality_tint(cell, soil)
		
		# Revert empty tilled soil to original ground after 2 days without a crop
		if soil.is_tilled and soil.crop_id == "" and soil.days_since_harvest >= 2:
			# Find original ground tile type for this cell
			var orig_tile: String = _tile_grid[cell.y][cell.x] if cell.y < _tile_grid.size() and cell.x < _tile_grid[cell.y].size() else "grass"
			# If current tile is still tilled, revert it
			var current_id: String = _tile_grid[cell.y][cell.x] if cell.y < _tile_grid.size() and cell.x < _tile_grid[cell.y].size() else "grass"
			if current_id in ["tilled", "watered_tilled"]:
				# Restore original biome-appropriate tile
				var restore_tile: String = orig_tile
				if orig_tile in ["tilled", "watered_tilled"]:
					restore_tile = "grass"
				_tile_grid[cell.y][cell.x] = restore_tile
				var restore_type: TileTypeData = DataManager.get_tile_type(restore_tile)
				if restore_type:
					ground_layer.set_cell(cell, 0, restore_type.atlas_coords)
				# Remove from soil data
				_soil_data.erase(cell)
	
	# Grouped notifications for newly mature crops
	if newly_mature_count > 0:
		if newly_mature_count == 1 and first_mature_name != "":
			ToastNotification.show_toast("%s ready to harvest!" % first_mature_name, ToastNotification.ToastType.SUCCESS, 4.0)
		elif newly_mature_count == 2 and first_mature_name != "":
			ToastNotification.show_toast("%s +1 more ready to harvest!" % first_mature_name, ToastNotification.ToastType.SUCCESS, 4.0)
		else:
			ToastNotification.show_toast("%d crops ready to harvest!" % newly_mature_count, ToastNotification.ToastType.SUCCESS, 4.0)
	
	# Advance pirate raid event once per day (not per soil cell)
	if pirate_raid and pirate_raid.is_inside_tree():
		pirate_raid.advance_day(_day)
	
	# Advance visitor manager once per day
	if visitor_manager and visitor_manager.is_inside_tree():
		visitor_manager.advance_day(_day)

	# Host: after computing today's farm growth, broadcast the resulting soil +
	# crop state so clients converge without recomputing growth/mutation/disease
	# themselves (which would diverge from the host RNG + per-peer bonuses).
	_broadcast_farm_delta()


## Applies a color tint to a tilled soil tile based on its soil quality level.
## Higher quality → richer/brighter tint, lower quality → duller/browner tint.
func _apply_soil_quality_tint(cell: Vector2i, soil: SoilData) -> void:
	if not ground_layer or not soil or not soil.soil_quality:
		return
	var level: int = soil.soil_quality.current_level
	var tint: Color
	match level:
		SoilQuality.QualityLevel.DEPLETED:
			tint = Color(0.6, 0.5, 0.4)
		SoilQuality.QualityLevel.POOR:
			tint = Color(0.7, 0.6, 0.5)
		SoilQuality.QualityLevel.AVERAGE:
			tint = Color(0.85, 0.8, 0.7)
		SoilQuality.QualityLevel.GOOD:
			tint = Color(0.7, 0.85, 0.65)
		SoilQuality.QualityLevel.RICH:
			tint = Color(0.5, 0.8, 0.5)
		SoilQuality.QualityLevel.FERTILE:
			tint = Color(0.4, 0.9, 0.4)
		_:
			tint = Color.WHITE
	# TileMapLayer.set_cell doesn't accept a modulate parameter, so we use
	# get_cell_tile_data to apply the tint. This returns the live TileData object.
	if ground_layer.has_method("get_cell_tile_data"):
		var td: TileData = ground_layer.get_cell_tile_data(cell)
		if td:
			td.modulate = tint

## Called periodically (every ~10 real seconds ≈ ~20 game minutes) to check
## visitor ship arrival/departure time windows.
func _check_visitor_time() -> void:
	if not visitor_manager or not visitor_manager.is_inside_tree():
		return
	var hour: int = GameManager.get_hour()
	visitor_manager.check_time(hour)


## Check if two different crops are adjacent and can hybridize
func _check_hybrid_opportunity(cell: Vector2i, soil: SoilData) -> bool:
	if not hybrid_system or soil.crop_id == "":
		return false
	
	var crop_data: CropData = DataManager.get_crop(soil.crop_id)
	if not crop_data or not _crop_nodes.has(cell):
		return false
	var crop_node: Crop = _crop_nodes[cell]
	if not crop_node.is_mature():
		return false
	
	# Check adjacent cells for a different mature crop
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var nc := Vector2i(cell.x + dx, cell.y + dy)
			if not _soil_data.has(nc):
				continue
			var neighbor_soil: SoilData = _soil_data[nc]
			if neighbor_soil.crop_id == "" or neighbor_soil.crop_id == soil.crop_id:
				continue
			if not _crop_nodes.has(nc):
				continue
			var neighbor_crop: Crop = _crop_nodes[nc]
			if not neighbor_crop.is_mature():
				continue
			
			# Try to create hybrid
			var hybrid := hybrid_system.try_hybridize(soil.crop_id, neighbor_soil.crop_id, cell.x, cell.y)
			if hybrid:
				ToastNotification.show_toast("New hybrid discovered: %s!" % hybrid.display_name, ToastNotification.ToastType.SUCCESS, 5.0)
				# Track hybrid objective
				var om := get_tree().get_first_node_in_group("objective_manager")
				if om and om.has_method("on_hybrid_crop_created"):
					om.on_hybrid_crop_created()
				# Give the player a hybrid seed
				InventoryManager.add_item(hybrid.seed_item_id, 1)
				return true
	
	return false

# ---------------------------------------------------------------------------
# Upgrade visual feedback
# ---------------------------------------------------------------------------

func _on_upgrade_purchased(upgrade: UpgradeManager.Upgrade, new_level: int) -> void:
	var name_str := UpgradeManager.get_upgrade_name(upgrade)
	ToastNotification.show_toast("%s upgraded to level %d!" % [name_str, new_level], ToastNotification.ToastType.SUCCESS, 4.0)
	# Spawn celebratory particles at player position
	var player := get_tree().get_first_node_in_group("player")
	if player:
		EffectSpawner.spawn_particles(player.global_position, Color(1.0, 0.9, 0.2), 12, 15.0)

# ---------------------------------------------------------------------------
# Terrain collision
# ---------------------------------------------------------------------------

## Adds collision shapes to non-walkable tiles in the TileSet so the player
## (CharacterBody2D with collision_mask layer 1) cannot walk into water,
## trees, or rocks.
func _setup_water_collision() -> void:
	var tileset: TileSet = ground_layer.tile_set
	if not tileset:
		return

	# Ensure the TileSet has at least one physics layer.
	while tileset.get_physics_layers_count() < 1:
		tileset.add_physics_layer()

	var source: TileSetAtlasSource = tileset.get_source(0)
	if not source:
		return

	# Apply full-tile collision to non-walkable tile types EXCEPT water.
	# Water tile (3,0) gets NO collision — _is_water_cell (Player.gd) handles
	# water blocking via input clamping instead. This allows dock-area tiles
	# to stay as water visually (no sand under the dock sprite's transparent
	# padding) while the player can still walk on them via _tile_grid checks.
	# Trees (7,0), rocks (8,0), and edge tiles (13-20) keep physics collision.
	var non_walkable_coords: Array[Vector2i] = [
		Vector2i(7, 0), Vector2i(8, 0),
	]
	for i in range(13, 21):  # edge tiles at positions 13-20
		non_walkable_coords.append(Vector2i(i, 0))
	for coords in non_walkable_coords:
		var tile_data: TileData = source.get_tile_data(coords, 0)
		if tile_data and tile_data.get_collision_polygons_count(0) == 0:
			var polygon := PackedVector2Array([
				Vector2(0, 0),
				Vector2(16, 0),
				Vector2(16, 16),
				Vector2(0, 16),
			])
			tile_data.add_collision_polygon(0)
			tile_data.set_collision_polygon_points(0, 0, polygon)

	# Enable collision on the TileMapLayer.
	ground_layer.collision_enabled = true

	# Tell the TileSet's physics layer which collision layer to use.
	# Layer 1 matches the Player's collision_mask (default).
	tileset.set_physics_layer_collision_layer(0, 1)

## Places tree objects across the "trees" tile regions so the forest
## areas have 3D-looking tree sprites instead of flat tile textures.
func _scatter_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + 3333
	var fruit_tree_scene: PackedScene = FRUIT_TREE_SCENE

	# Biomes sorted by tree density: forest biomes get lots, others a few.
	# Use BiomeType.Type enum values (not indices) for comparison.
	var dense_type_set: Array = [
		BiomeType.Type.FOREST, BiomeType.Type.SWAMP,
	]
	var moderate_type_set: Array = [
		BiomeType.Type.PLAINS, BiomeType.Type.MEADOW,
	]
	var sparse_type_set: Array = [
		BiomeType.Type.MOUNTAIN, BiomeType.Type.BEACH,
	]

	# Target tree counts per biome tier (per 100x100 world)
	var dense_target := 180     # ~18% of tiles in dense biomes
	var moderate_target := 60   # ~6% in moderate biomes
	var sparse_target := 15     # ~1.5% in sparse biomes

	var biomes_placed: Dictionary = {}  # biome_index -> count placed
	var tree_idx := 0

	# First pass: count cells per biome INDEX so we know how many trees each gets
	var biome_cell_counts: Dictionary = {}  # biome_index -> cell count
	for y in range(world_height):
		for x in range(world_width):
			var biome_idx: int = -1
			if y < _biome_grid.size() and x < _biome_grid[y].size():
				biome_idx = _biome_grid[y][x]
			if biome_idx < 0:
				continue
			var tile_id: String = _tile_grid[y][x]
			var tile_type: TileTypeData = DataManager.get_tile_type(tile_id)
			if not tile_type or not tile_type.walkable:
				continue
			if tile_id == "water" or tile_id.begins_with("edge") or tile_id == "sand" or tile_id == "path":
				continue
			# Don't place trees on the dock visual footprint
			if _dock_cell != Vector2i(-1, -1):
				var dl := Vector2i(x, y) - _dock_cell
				if dl.y >= -3 and dl.y <= 11 and dl.x >= -10 and dl.x <= 25:
					continue
			biome_cell_counts[biome_idx] = biome_cell_counts.get(biome_idx, 0) + 1

	# Calculate max per biome index
	var max_per_biome: Dictionary = {}  # biome_index -> max trees
	var land_total := 0
	for c in biome_cell_counts.values():
		land_total += c as int

	for bt in biome_cell_counts:
		var count: int = biome_cell_counts[bt] as int
		var target: int = 0
		var biome_type_enum: int = _biome_index_to_type(bt)
		if dense_type_set.has(biome_type_enum):
			target = dense_target
		elif moderate_type_set.has(biome_type_enum):
			target = moderate_target
		elif sparse_type_set.has(biome_type_enum):
			target = sparse_target
		else:
			target = 20  # default modest
		# Scale target by this biome's share of the total land area
		if land_total > 0:
			target = maxi(2, roundi(target * float(count) / float(land_total) * 3.0))
		max_per_biome[bt] = target

	# Track which cells already have a tree placed (prevents same-cell overlap).
	var occupied_cells: Dictionary = {}  # Vector2i -> true. Also includes building footprint cells.

	# Pre-populate with all building footprint cells so trees never spawn on buildings.
	if building_system:
		for b in building_system.placed_buildings:
			var b_cell: Vector2i = b.get("cell", Vector2i(0, 0))
			var b_w: int = b.get("width", 1)
			var b_h: int = b.get("height", 1)
			var b_rot: int = b.get("rotation", 0)
			for bx in range(b_w):
				for by in range(b_h):
					# Apply the same rotation logic as BuildingSystem._rotate_coords
					var fc: Vector2i
					match b_rot:
						1:
							fc = Vector2i(b_h - 1 - by, bx)
						2:
							fc = Vector2i(b_w - 1 - bx, b_h - 1 - by)
						3:
							fc = Vector2i(by, b_w - 1 - bx)
						_:
							fc = Vector2i(bx, by)
					occupied_cells[b_cell + fc] = true

	# Also block the shop stand footprint (5x3 tiles centered on its cell)
	# so trees and nature never spawn on top of the merchant.
	if _shop_cell != Vector2i(-1, -1):
		for sx in range(-2, 3):
			for sy in range(-1, 2):
				occupied_cells[_shop_cell + Vector2i(sx, sy)] = true

	# Block all nature object cells (bushes, flowers, mushrooms, stumps)
	# so trees don't overlap with nature and vice versa.
	for nature_cell in _nature_cells:
		occupied_cells[nature_cell] = true

	# Block cells that already have biome resource objects (stones, berry
	# bushes, flowers from _scatter_objects) so trees don't overlap with them.
	for child in objects_root.get_children():
		var child_cell: Vector2i = Vector2i(
			floori(child.global_position.x / TILE_SIZE),
			floori(child.global_position.y / TILE_SIZE)
		)
		occupied_cells[child_cell] = true

	# Walking the grid once, check each cell and optionally place a tree
	for y in range(world_height):
		for x in range(world_width):
			var cell := Vector2i(x, y)

			# Skip cells occupied by trees, nature, buildings, or iron ore
			if occupied_cells.has(cell) or _ore_cells.has(cell):
				continue

			var tile_id: String = _tile_grid[y][x]
			var tile_type := DataManager.get_tile_type(tile_id)
			if not tile_type or not tile_type.walkable:
				continue
			if tile_id == "water" or tile_id.begins_with("edge") or tile_id == "sand" or tile_id == "path":
				continue

			# Skip town area — the backdrop sprite shows the buildings/streets
			var town_rect: Rect2i = get_meta("town_rect", Rect2i())
			if town_rect.size.x > 0 and town_rect.has_point(cell):
				continue

			# Check biome index
			var biome_idx: int = -1
			if y < _biome_grid.size() and x < _biome_grid[y].size():
				biome_idx = _biome_grid[y][x]
			if biome_idx < 0:
				continue

			# Check if this biome already has enough trees
			var current: int = biomes_placed.get(biome_idx, 0) as int
			var max_allowed: int = max_per_biome.get(biome_idx, 0) as int
			if current >= max_allowed:
				continue

			# Determine spawn chance for this biome tier
			var biome_type_enum: int = _biome_index_to_type(biome_idx)
			var skip_chance: float
			if dense_type_set.has(biome_type_enum):
				skip_chance = 0.75
			elif moderate_type_set.has(biome_type_enum):
				skip_chance = 0.88
			elif sparse_type_set.has(biome_type_enum):
				skip_chance = 0.96
			else:
				skip_chance = 0.92

			if rng.randf() < skip_chance:
				continue

			# Mark this cell as occupied so no other tree goes here
			occupied_cells[cell] = true

			# Count this placement
			biomes_placed[biome_idx] = biomes_placed.get(biome_idx, 0) + 1

			# Detect Cherry Grove: only cherry trees spawn here (100%, no other trees)
			var is_cherry_grove: bool = false
			if biome_idx >= 0 and biome_idx < _biome_list.size():
				var biome_def: BiomeDefinition = _biome_list[biome_idx]
				if biome_def.display_name == "Cherry Grove":
					is_cherry_grove = true

			if is_cherry_grove:
				var tree: TreeObject = TREE_SCENE.instantiate()
				tree.name = "Tree_%d" % tree_idx
				tree_idx += 1
				tree.set_cherry()
				tree.sprite_seed = world_seed + tree_idx
				objects_root.add_child(tree)
				tree.global_position = cell_to_world(cell)
				# Cherry trees are NOT rotated — a rotated 16×16 collision shape's
				# corners stick past the tile boundary and catch on the player's
				# rectangle collision shape at tile gaps, blocking movement.
				var scale_var: float = rng.randf_range(0.85, 1.15)
				tree.scale = Vector2(scale_var, scale_var)
				continue

			# Forest-type biomes: 25% chance of fruit tree
			var is_fruit_tree: bool = false
			if biome_type_enum == BiomeType.Type.FOREST and rng.randf() < 0.25:
				is_fruit_tree = true

			if is_fruit_tree:
				var fruit_tree: Area2D = fruit_tree_scene.instantiate()
				fruit_tree.name = "FruitTree_%d" % tree_idx
				tree_idx += 1
				fruit_tree.fruit_item_id = "berry"
				objects_root.add_child(fruit_tree)
				fruit_tree.global_position = cell_to_world(cell)
			else:
				var tree: Area2D = TREE_SCENE.instantiate()
				tree.name = "Tree_%d" % tree_idx
				tree_idx += 1
				tree.sprite_seed = world_seed + tree_idx
				objects_root.add_child(tree)
				tree.global_position = cell_to_world(cell)
				tree.rotation = rng.randf_range(-0.15, 0.15)
				var scale_var: float = rng.randf_range(0.85, 1.15)
				tree.scale = Vector2(scale_var, scale_var)


func _is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < world_width and cell.y < world_height

## Returns true if the given cell is within 2 tiles of any scarecrow.
## Scarecrows protect a 5×5 area (radius 2) from disease.
func _is_near_scarecrow(cell: Vector2i) -> bool:
	for s_cell in _scarecrow_cells:
		if abs(cell.x - s_cell.x) <= 2 and abs(cell.y - s_cell.y) <= 2:
			return true
	return false

## Returns true if the given cell is within 2 tiles of a greenhouse footprint.
## Greenhouses provide season override, disease resistance, and growth bonuses.
func _is_near_greenhouse(cell: Vector2i) -> bool:
	for gh_cell in _greenhouse_cells:
		if abs(cell.x - gh_cell.x) <= 2 and abs(cell.y - gh_cell.y) <= 2:
			return true
	return false

## Returns true if the given cell is within 2 tiles of any compost bin.
## Compost bins convert crop waste into compost.
func _is_near_compost_bin(cell: Vector2i) -> bool:
	for c_cell in _compost_bin_cells:
		if abs(cell.x - c_cell.x) <= 2 and abs(cell.y - c_cell.y) <= 2:
			return true
	return false


# ---------------------------------------------------------------------------
# Shop Stand spawning
# ---------------------------------------------------------------------------

## Places the NPC shop stand at the center of the dock.
func _spawn_shop_stand() -> void:
	var stand: Area2D = SHOP_BUILDING_SCENE.instantiate()
	objects_root.add_child(stand)
	stand.global_position = _dock_position
	_shop_position = stand.global_position
	var dock_cell := Vector2i(_dock_cell.x + 12, _dock_cell.y + 7)
	_shop_cell = dock_cell


## Places a storage chest near the player's starting area.
func _spawn_chest() -> void:
	var centre_x := world_width / 2
	var centre_y := world_height / 2
	
	# Place chest right next to the shop stand
	var chest := Chest.new()
	chest.name = "StarterChest"
	objects_root.add_child(chest)
	chest.global_position = cell_to_world(Vector2i(centre_x + 2, centre_y + 1))
	
	# Floating label above the chest, matching the mine-entrance label style
	var label := Label.new()
	label.name = "StarterChestLabel"
	label.text = "Starter Chest"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.size = Vector2(120, 20)
	label.position = Vector2(-60, -34)
	label.z_index = 5
	chest.add_child(label)


## Places the Boat at the southernmost point of the island. Scans from the
## bottom of the map upward for a wide enough stretch of land (≥26 tiles)
## with water below, flattens the harbor, marks the dock area walkable,
## and places the dock + merchant boat. The dock sits flush against the
## coastline — player walks directly from shore onto visible dock wood.
func _spawn_boat() -> void:
	const HARBOR_W := 24  # dock sprite tile width
	const HARBOR_DEPTH := 14  # tiles below coastline (covers dock sprite + boat)

	# ── Step 1: Find a wide enough southern harbor ─────────────
	_dock_cell = Vector2i.ZERO
	var found := false

	# Scan Y from the very bottom of the grid upward
	for y in range(world_height - 2, 0, -1):
		# Find contiguous land runs at this Y
		var runs: Array[Dictionary] = []
		var start_x := -1
		for x in range(world_width):
			var tid: String = _tile_grid[y][x]
			var is_land := tid != "water" and not tid.begins_with("edge") and not tid.is_empty()
			if is_land and start_x == -1:
				start_x = x
			elif not is_land and start_x != -1:
				runs.append({"s": start_x, "e": x - 1, "w": x - start_x})
				start_x = -1
		if start_x != -1:
			runs.append({"s": start_x, "e": world_width - 1, "w": world_width - start_x})

		# Check the widest run first (longest contiguous land)
		runs.sort_custom(func(a, b): return a.w > b.w)
		for run in runs:
			if run.w < 24:
				continue  # run too narrow for the dock
			var cx: int = run.s + run.w / 2
			# Check water below for the full dock visual width
			var all_clear := true
			for check_x in range(cx - 12, cx + 13):
				var below := Vector2i(check_x, y + 1)
				if not _is_in_bounds(below):
					all_clear = false
					break
				var bt: String = _tile_grid[below.y][below.x]
				if bt != "water" and not bt.begins_with("edge"):
					all_clear = false
					break
			if all_clear:
				_dock_cell = Vector2i(cx, y)
				found = true
				break
		if found:
			break

	# Fallback: any southern land with water below (unlikely with circular island)
	if not found:
		for y in range(world_height - 2, 0, -1):
			for x in range(world_width):
				var tid: String = _tile_grid[y][x]
				if tid == "water" or tid.begins_with("edge") or tid.is_empty():
					continue
				var below := Vector2i(x, y + 1)
				if not _is_in_bounds(below):
					continue
				var bt: String = _tile_grid[below.y][below.x]
				if bt == "water" or bt.begins_with("edge"):
					_dock_cell = Vector2i(x, y)
					found = true
					break
			if found:
				break

	if not found:
		push_error("Cannot place dock: no suitable southern coastline found")
		return

	# ── Step 2: Flatten the harbor area ────────────────────────
	# Dock area tiles (dy=0..9, dx=-9..5) are marked "path". The dock
	# is placed with visible artwork flush against the coastline, so the
	# top row of dock tiles shows wood directly at the shore. Everything
	# else within the harbor is restored to "water".
	var hw := HARBOR_W / 2

	for dy in range(0, HARBOR_DEPTH + 1):
		for dx in range(-hw, hw + 1):
			var nx := _dock_cell.x + dx
			var ny := _dock_cell.y + dy
			if ny < 0 or ny >= _tile_grid.size() or nx < 0 or nx >= _tile_grid[ny].size():
				continue

			# Dock walkable area: within the visible artwork bounds.
			# Dock walkable area: 5 tiles south from the coast, left edge
			# restricted by 1 tile from the previous -9..5 boundary.
			var is_dock_sprite := dy >= 0 and dy <= 5 and dx >= -8 and dx <= 7
			if is_dock_sprite:
				_tile_grid[ny][nx] = "path"
			else:
				_tile_grid[ny][nx] = "water"

	# ── Step 2b: Extend path corridor north of coastline ───────
	# Pirates (collision_mask bit 0 for TileMap layer 1) can be blocked
	# by edge tile physics at the coastline. Setting the land row directly
	# north of the dock (dy=-1) to "path" in the _tile_grid ensures the
	# enemy's water-avoidance check passes, letting them walk off the dock
	# onto the island. The visual tile keeps its original land/beach look;
	# no collision is added since biome tiles (source 1+) never get them.
	# Only the dock-width corridor (dx=-8..7) is marked; adjacent cells
	# retain their original walkable IDs so the player's grid check
	# (is_water_tile) does not falsely flag them.
	for dx in range(-8, 8):
		var nx := _dock_cell.x + dx
		var ny := _dock_cell.y - 1
		if ny >= 0 and ny < _tile_grid.size() and nx >= 0 and nx < _tile_grid[ny].size():
			_tile_grid[ny][nx] = "path"

	# ── Step 3: Paint water tiles under the dock ────────────────
	# Edge tiles at the coastline have physics collision that blocks
	# move_and_slide. Painting water (3,0) replaces those collision
	# shapes with tiles that have no physics, while looking normal.
	# The grid-based dock-area path check (Player._is_water_cell
	# Step A) still allows walking here.
	# The dock sprite is 384px wide (24 cells), so we paint water under
	# the full sprite width (dx=0..23) plus a margin, and 14 rows deep
	# (dy=0..13) to cover the full visible artwork.
	for dy in range(0, 14):
		for dx in range(0, 24):
			var nx := _dock_cell.x + dx
			var ny := _dock_cell.y + dy
			if ny >= 0 and ny < _tile_grid.size() and nx >= 0 and nx < _tile_grid[ny].size():
				ground_layer.set_cell(Vector2i(nx, ny), 0, Vector2i(3, 0))

	# ── Step 5: Place the dock structure ──────────────────────
	var dock: Dock = DOCK_SCENE.instantiate()
	objects_root.add_child(dock)
	# Offset 54 raises the dock so it overlaps with the coastline island,
	# visually embedding the top edge of the dock into the shore.
	dock.global_position = cell_to_world(_dock_cell) + Vector2(0, 54)
	_dock_position = dock.global_position

	# ── Step 6: Place the merchant boat at Berth 3 (right side) ───
	var boat: Area2D = BOAT_SCENE.instantiate()
	objects_root.add_child(boat)
	boat.global_position = _dock_position + Dock.BERTH_POSITIONS[3]
	_boat_position = boat.global_position

	# ── Step 7: Place the expedition travel boat (Captain Briggs) at Berth 0 (left side) ────
	var travel_boat: Area2D = TRAVEL_BOAT_SCENE.instantiate()
	objects_root.add_child(travel_boat)
	travel_boat.global_position = _dock_position + Dock.BERTH_POSITIONS[0]


## Returns true if the cell is within the dock's walkable area
## (dy=-1..5, dx=-8..7, 16×7 tiles), matching the grid "path" area.
## Includes dy=-1 (the extra row north of the coastline) so pirates
## can walk off the dock onto the island without hitting edge collision.
func is_cell_in_dock_area(cell: Vector2i) -> bool:
	if _dock_cell == Vector2i(-1, -1):
		return false
	var local := cell - _dock_cell
	return local.y >= -1 and local.y <= 5 and local.x >= -8 and local.x <= 7


## Returns true if the cell was flattened to "path" (e.g. the dock area).
## Used by Player._is_water_cell to allow walking on tiles that visually
## display as water but are walkable in the game grid (like the dock platform).
func is_dock_path_tile(cell: Vector2i) -> bool:
	if cell.y < 0 or cell.y >= _tile_grid.size():
		return false
	var row: Array = _tile_grid[cell.y]
	if cell.x < 0 or cell.x >= row.size():
		return false
	return row[cell.x] == "path"

## Returns true if the authoritative _tile_grid considers this cell water.
## This catches cells where the TileMapLayer shows a biome tile (source 1+)
## but the grid was force-set to "water" during harbor flattening. Without
## this, Player._is_water_cell would see sid != 0 and incorrectly treat the
## cell as walkable.
func is_water_tile(cell: Vector2i) -> bool:
	if cell.y < 0 or cell.y >= _tile_grid.size():
		return false
	var row: Array = _tile_grid[cell.y]
	if cell.x < 0 or cell.x >= row.size():
		return false
	return row[cell.x] == "water"


## Determine which direction points inward (toward center) from an edge cell.
## Returns a Vector2i direction pointing one step toward the island interior.
func _get_inward_direction(cell: Vector2i) -> Vector2i:
	var cx := world_width / 2
	var cy := world_height / 2
	var dir := Vector2i(signi(cx - cell.x), signi(cy - cell.y))
	if dir.x != 0 and dir.y != 0:
		# Diagonal edge — prefer the stronger axis
		if abs(cx - cell.x) > abs(cy - cell.y):
			dir.y = 0
		else:
			dir.x = 0
	return dir



## Spawns procedurally named animals with varied behaviours across
## walkable tiles of the island.
## Spawns exactly 2 of each type so the player can easily breed them.
func _scatter_animals() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = world_seed + 10000
	var animal_types: Array[String] = ["chicken", "cow", "rabbit", "deer", "goat", "pig", "sheep", "squirrel", "frog", "turtle"]
	var animal_count: int = animal_types.size() * 2
	# Keep animals out of the town area — the backdrop sprite owns the plaza.
	var town_rect: Rect2i = get_meta("town_rect", Rect2i())
	var is_town_cell := func(cell: Vector2i) -> bool:
		return town_rect.size.x > 0 and town_rect.has_point(cell)
	var positions: Array = _generator.pick_object_positions(_tile_grid, animal_count, rng, is_town_cell)
	
	# Shuffle so type-to-position distribution varies per world seed
	var shuffled_types: Array[String] = animal_types.duplicate()
	_shuffle_array_with_rng(shuffled_types, rng)
	
	for i in range(min(positions.size(), animal_count)):
		var p_type: String = shuffled_types[i / 2]
		var animal: Animal = ANIMAL_SCENE.instantiate()
		register_animal_name(animal)
		objects_root.add_child(animal)
		animal.setup(p_type, cell_to_world(positions[i]))
		_broadcast_animal_spawn(animal)


## Helper: collect an animal's visual and gameplay state into a dictionary
## and broadcast it so remote clients create a matching copy.
func _broadcast_animal_spawn(animal: Animal) -> void:
	if not NetworkManager.is_network_active() or not multiplayer.is_server():
		return
	var data: Dictionary = animal.get_network_data()
	rpc("_sync_spawn_animal", data)


## Assigns a deterministic, unique node name to a newly spawned animal so
## that per-node RPCs (e.g. _sync_animal_pos) resolve to the same path on
## host and clients. Must be called before add_child(). Runtime spawns are
## broadcast to clients with this name via get_network_data().
func register_animal_name(animal: Node) -> void:
	animal.name = "Animal_%d" % _next_animal_index
	_next_animal_index += 1


## Host → all clients: spawn an animal on remote copies.
@rpc("authority", "call_local")
func _sync_spawn_animal(data: Dictionary) -> void:
	if multiplayer.is_server():
		return  # Host already has the real animal
	if not objects_root or not is_instance_valid(objects_root):
		return  # World not ready yet
	var animal: Animal = ANIMAL_SCENE.instantiate()
	var node_name: String = data.get("node_name", "")
	if node_name != "":
		animal.name = node_name
	objects_root.add_child(animal)
	animal.setup_from_network(data)


## ── Animal RPC relay ──────────────────────────────────────────────────────
## Per-node animal RPCs (e.g. _sync_animal_pos) used to route to the animal
## node path, which doesn't exist on a joining peer until its world regen +
## snapshot apply finish — the engine then floods "Node not found" errors.
## Instead, host animals broadcast through World (which always exists) and
## the receiver looks the animal up by its animal_id; missing animals are
## silently skipped (the snapshot backfill recreates them moments later).

## Host → all clients: relay an unreliable animal RPC (position).
@rpc("authority", "unreliable")
func _relay_animal_rpc_unreliable(method: String, args: Array) -> void:
	_apply_animal_relay(method, args)


## Host → all clients: relay a reliable animal RPC (tamed/damage/died).
@rpc("authority", "reliable")
func _relay_animal_rpc_reliable(method: String, args: Array) -> void:
	_apply_animal_relay(method, args)


## Routes a relayed animal RPC to the local animal matching the id (args[0]).
## Runs only on clients (host animals apply their state locally already).
func _apply_animal_relay(method: String, args: Array) -> void:
	if multiplayer.is_server():
		return  # Host's real animals handled their own state already
	if args.is_empty() or not (args[0] is int):
		return
	var aid: int = args[0]
	for a in get_tree().get_nodes_in_group("animals"):
		if is_instance_valid(a) and "animal_id" in a and a.animal_id == aid:
			a.callv(method, args)
			return


## Host → killer client: deliver an animal's kill drop to that player's own
## inventory. Animal drops are routed to the killer only (via this targeted
## RPC) instead of being broadcast to and duplicated across every peer.
@rpc("authority", "reliable")
func _receive_animal_loot(item_id: String, count: int) -> void:
	if count <= 0 or item_id.is_empty():
		return
	InventoryManager.add_item(item_id, count)


## Host → all clients: the final boss (Inconstant Soul) was defeated, so this
## peer's game is complete too. The boss _die() only runs on the host's
## authority copy, so without this broadcast clients would never see the win.
@rpc("authority", "reliable")
func _receive_game_completed() -> void:
	if multiplayer.is_server():
		return
	GameManager.complete_game()


## Look up a live animal by its stable animal_id. Used by the World-routed
## client→host handlers below so they never depend on matching Animal_N node
## names across peers (those names drift apart after per-peer worldgen/respawn).
func _find_animal_by_id(aid: int) -> Animal:
	for a in get_tree().get_nodes_in_group("animals"):
		if is_instance_valid(a) and a is Animal and a.animal_id == aid:
			return a as Animal
	return null


## Client → host: a client fed an animal. Routed through World's stable node
## path instead of the Animal node (whose per-peer names can drift and flood
## "Node not found"). Delegates to the existing host-side tame handler.
@rpc("any_peer", "reliable")
func _server_tame_animal(aid: int) -> void:
	if not multiplayer.is_server():
		return
	var animal := _find_animal_by_id(aid)
	if animal:
		animal._request_animal_tamed(aid)


## Client → host: a client fed an animal. The host's authoritative copy must
## also enter love mode (plus tamed) and run _try_breed so breeding works when
## a non-host player feeds — otherwise only the client's local copy enters love
## mode and the host (which actually spawns babies) never sees a mate in love
## mode, so no baby is ever born from a client-initiated feeding.
@rpc("any_peer", "reliable")
func _server_feed_animal(aid: int) -> void:
	if not multiplayer.is_server():
		return
	var animal := _find_animal_by_id(aid)
	if animal:
		animal._request_feed_from_client(aid)


## Client → host: forward a melee/ranged attack on a remote copy. Routed
## through World's stable path; the old Animal-node rpc_id flooded "Node
## not found" whenever host/client animal names drifted apart.
@rpc("any_peer", "reliable")
func _server_receive_animal_attack(aid: int, amount: int, crit: bool) -> void:
	if not multiplayer.is_server():
		return
	var animal := _find_animal_by_id(aid)
	if animal:
		animal._server_receive_animal_attack(aid, amount, crit)


## ── Enemy RPC relay ──────────────────────────────────────────────────────
## Per-node enemy RPCs (e.g. _sync_enemy_state) used to route to the enemy
## node path, which doesn't exist on a joining peer until its world regen +
## spawn broadcasts finish — the engine then floods "Node not found" errors.
## Instead, host enemies broadcast through World (which always exists) and
## the receiver looks the enemy up by its enemy_id; missing enemies are
## silently skipped (the late-joiner pull recreates them moments later).

## Host → all clients: relay an unreliable enemy RPC (position).
@rpc("authority", "unreliable")
func _relay_enemy_rpc_unreliable(method: String, args: Array) -> void:
	_apply_enemy_relay(method, args)


## Host → all clients: relay a reliable enemy RPC (damage/died).
@rpc("authority", "reliable")
func _relay_enemy_rpc_reliable(method: String, args: Array) -> void:
	_apply_enemy_relay(method, args)


## Routes a relayed enemy RPC to the local enemy matching the id (args[0]).
## Runs only on clients (host enemies apply their state locally already).
func _apply_enemy_relay(method: String, args: Array) -> void:
	if multiplayer.is_server():
		return  # Host's real enemies handled their own state already
	if args.is_empty() or not (args[0] is int):
		return
	var eid: int = args[0]
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and "enemy_id" in e and e.enemy_id == eid:
			e.callv(method, args)
			return


## Look up a live enemy by its stable enemy_id. Used by the World-routed
## client→host handler below so it never depends on matching Enemy_N node
## names across peers (those names drift apart after per-peer worldgen/respawn).
func _find_enemy_by_id(eid: int) -> Enemy:
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e is Enemy and e.enemy_id == eid:
			return e as Enemy
	return null


## Client → host: forward a melee/ranged attack on a remote copy. Routed
## through World's stable path; the old Enemy-node rpc_id flooded "Node
## not found" whenever host/client enemy names drifted apart.
@rpc("any_peer", "reliable")
func _server_receive_enemy_attack(eid: int, amount: int, crit: bool, ranged: bool = false) -> void:
	if not multiplayer.is_server():
		return
	var enemy := _find_enemy_by_id(eid)
	if enemy:
		enemy._server_receive_enemy_attack(eid, amount, crit, ranged)


## Spawns a couple of starter animals on walkable land near the player's
## starting position so they encounter animals immediately without having
## to search the entire island. Spawns 2 of the same type (chickens) so
## the player can try breeding right away.
func spawn_starter_animals_near(world_pos: Vector2) -> void:
	# Dedupe: only stock starter animals on a fresh world. If this peer
	# already has any animals (second seed handshake, or the same session
	# joined more than once), spawning again would create duplicate
	# Animal_20/21-style names and break per-node RPC routing.
	if not get_tree().get_nodes_in_group("animals").is_empty():
		return
	var spawn_cell := world_to_cell(world_pos)
	var starter_type := "chicken"
	var placed := 0
	# Scan a 6-cell radius around the spawn for walkable land cells
	for dy in range(-6, 7):
		for dx in range(-6, 7):
			if placed >= 2:
				return
			var cell := Vector2i(spawn_cell.x + dx, spawn_cell.y + dy)
			if cell.y < 0 or cell.y >= _tile_grid.size() or cell.x < 0 or cell.x >= _tile_grid[cell.y].size():
				continue
			var tile_id: String = _tile_grid[cell.y][cell.x]
			if tile_id == "water" or tile_id.begins_with("edge") or tile_id.is_empty():
				continue
			var animal: Animal = ANIMAL_SCENE.instantiate()
			register_animal_name(animal)
			objects_root.add_child(animal)
			animal.setup(starter_type, cell_to_world(cell))
			_broadcast_animal_spawn(animal)
			placed += 1

## Periodic animal respawn check. Fires every ~60 seconds.
## Prefers spawning animals of types that are missing a breeding partner,
## so the player can eventually breed all species.
func _on_animal_respawn_timer() -> void:
	# Don't respawn if paused or in creative panel mode
	if GameManager.creative_time_paused:
		return
	# Clients receive respawned animals via _sync_spawn_animal; never
	# respawn locally on a client (would desync animal counts and names).
	if NetworkManager.is_network_active() and not multiplayer.is_server():
		return
	var animals := get_tree().get_nodes_in_group("animals")
	var type_counts: Dictionary = {}  # "chicken" -> 2
	for a in animals:
		if is_instance_valid(a) and a is Animal:
			type_counts[a.animal_type] = type_counts.get(a.animal_type, 0) + 1
	
	# Find types that need more for breeding (< 2 members)
	var all_animal_types: Array[String] = ["chicken", "cow", "rabbit", "deer", "goat", "pig", "sheep", "squirrel", "frog", "turtle"]
	var need_pair: Array[String] = []  # types with 0 members (highest priority)
	var need_one: Array[String] = []   # types with 1 member
	for t in all_animal_types:
		var count: int = type_counts.get(t, 0)
		if count == 0:
			need_pair.append(t)
		elif count == 1:
			need_one.append(t)
	
	# Only respawn if there's a type missing a breeding partner
	if need_pair.is_empty() and need_one.is_empty():
		return
	
	# Need a player reference for spawn location
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	# Spawn 1-2 animals, prioritizing types that are completely missing
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var spawn_count: int = clampi(2, 1, need_pair.size() + need_one.size())
	
	for _i in range(spawn_count):
		# Pick a type that needs a partner — prefer missing types first
		var p_type: String
		if not need_pair.is_empty():
			p_type = need_pair.pop_at(rng.randi() % need_pair.size())
		elif not need_one.is_empty():
			p_type = need_one.pop_at(rng.randi() % need_one.size())
		else:
			break  # All types have partners, skip
		
		# Find a random walkable position near the player (not on water)
		for attempt in range(5):
			var pos_offset: Vector2 = Vector2(rng.randf_range(-200.0, 200.0), rng.randf_range(-200.0, 200.0))
			var spawn_pos: Vector2 = player.global_position + pos_offset
			var cell := world_to_cell(spawn_pos)
			if not _is_in_bounds(cell):
				continue
			var tile_id: String = _tile_grid[cell.y][cell.x] if cell.y < _tile_grid.size() and cell.x < _tile_grid[cell.y].size() else ""
			if tile_id == "water" or tile_id.begins_with("edge") or tile_id.is_empty():
				continue
			
			var animal: Animal = ANIMAL_SCENE.instantiate()
			register_animal_name(animal)
			objects_root.add_child(animal)
			animal.setup(p_type, spawn_pos)
			_broadcast_animal_spawn(animal)
			break


## Scatter 2-3 mine entrances on mountain/snow biome tiles across the world.
## Pre-collects all eligible cells first for reliable placement.
func _scatter_mine_entrances() -> void:
	if not objects_root:
		return
	
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + 55555
	var entrance_count: int = rng.randi_range(2, 3)
	
	# Collect ALL eligible cells first (stone or snow tiles, not in town, not occupied by buildings)
	var town_rect: Rect2i = get_meta("town_rect", Rect2i())
	var eligible_cells: Array[Vector2i] = []
	for y in range(5, world_height - 5):
		for x in range(5, world_width - 5):
			var cell := Vector2i(x, y)
			if town_rect.size.x > 0 and town_rect.has_point(cell):
				continue
			var tile_id: String = _tile_grid[y][x]
			if tile_id == "stone" or tile_id == "snow" or tile_id == "cobblestone_path":
				if building_system and building_system.is_occupied(cell):
					continue
				eligible_cells.append(cell)
	
	if eligible_cells.is_empty():
		push_warning("No eligible mine entrance cells found (need stone, snow, or cobblestone_path tiles)")
		return
	
	# Pick entrance positions with minimum spacing between them
	const MIN_ENTRANCE_SPACING: int = 10  # cells (160px) between entrances
	var picked_cells: Array[Vector2i] = []
	# Deterministic Fisher-Yates shuffle using the seeded RNG so host and
	# clients generate the same entrance positions.
	for i in range(eligible_cells.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Vector2i = eligible_cells[i]
		eligible_cells[i] = eligible_cells[j]
		eligible_cells[j] = tmp
	
	for cell in eligible_cells:
		if picked_cells.size() >= entrance_count:
			break
		# Check distance from all already-picked cells
		var too_close := false
		for other in picked_cells:
			if abs(cell.x - other.x) < MIN_ENTRANCE_SPACING and abs(cell.y - other.y) < MIN_ENTRANCE_SPACING:
				too_close = true
				break
		if not too_close:
			picked_cells.append(cell)
	
	for entrance_idx in range(picked_cells.size()):
		var cell: Vector2i = picked_cells[entrance_idx]
		var cx := cell.x
		var cy := cell.y
		
		# Position in world coordinates (center of tile)
		var world_pos := Vector2(cx * TILE_SIZE + TILE_SIZE / 2, cy * TILE_SIZE + TILE_SIZE / 2)
		
		# Create entrance node: Sprite2D + Area2D trigger
		var entrance := Node2D.new()
		entrance.name = "MineEntrance_%d" % entrance_idx
		entrance.position = world_pos
		entrance.z_index = 1
		entrance.set_meta("entrance_index", entrance_idx)
		
		var sprite := Sprite2D.new()
		sprite.texture = MINE_ENTRANCE_TEX
		sprite.z_index = 2
		entrance.add_child(sprite)
		
		var label := Label.new()
		label.text = "Mine"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_color_override("font_shadow_color", Color.BLACK)
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
		label.position = Vector2(-20, -40)
		label.z_index = 5
		entrance.add_child(label)
		
		# Interaction area — detect player proximity on body_entered (no auto-trigger)
		var area := Area2D.new()
		area.name = "MineEntranceArea"
		area.collision_mask = 2  # detect player (layer 2)
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(32, 24)
		shape.shape = rect
		area.add_child(shape)
		area.body_entered.connect(_on_mine_entrance_near.bind(entrance))
		area.body_exited.connect(_on_mine_entrance_left)
		entrance.add_child(area)
		
		# Entrance marker on ground
		var ground_sprite := Sprite2D.new()
		ground_sprite.texture = MINE_ENTRANCE_TEX
		ground_sprite.z_index = 0
		ground_sprite.modulate = Color(0.3, 0.25, 0.2, 0.5)  # shadow
		ground_sprite.position = Vector2(0, 4)
		entrance.add_child(ground_sprite)
		
		# Static collision body — prevents player from walking through the mine entrance
		var wall_body := StaticBody2D.new()
		wall_body.name = "MineEntranceBlocker"
		wall_body.collision_layer = 8  # building exterior wall layer (matches player collision_mask)
		var wall_shape := CollisionShape2D.new()
		var wall_rect := RectangleShape2D.new()
		wall_rect.size = Vector2(20, 20)
		wall_shape.shape = wall_rect
		wall_body.add_child(wall_shape)
		entrance.add_child(wall_body)
		
		objects_root.add_child(entrance)
		mine_entrances.append(entrance)


## Places starter buildings near the player spawn area so the world
## feels more inhabited. Uses BuildingSystem.place_building() which
## handles collision checks and visual node creation.
func _scatter_buildings() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + 33333
	
	# Player spawns near the right coastline, so place
	# buildings in a cluster to the left/west of the spawn point.
	var spawn_cell := Vector2i(world_width - 30, world_height / 2)
	var buildings_to_place: Array[Dictionary] = [
		{"type": BuildingSystem.BuildingType.SMALL_HOME, "offset": Vector2i(-5, -2), "rot": 0},
		{"type": BuildingSystem.BuildingType.CAMPFIRE, "offset": Vector2i(-2, 3), "rot": 0},
		{"type": BuildingSystem.BuildingType.STORAGE_SHED, "offset": Vector2i(-2, -5), "rot": 0},
		{"type": BuildingSystem.BuildingType.DECORATIVE_BENCH, "offset": Vector2i(-4, 3), "rot": 0},
	]
	# Shuffle offsets a bit with the rng so placement varies per seed but
	# stays identical between host and clients (deterministic Fisher-Yates).
	for _bi in range(buildings_to_place.size() - 1, 0, -1):
		var _bj: int = rng.randi_range(0, _bi)
		var _btmp: Dictionary = buildings_to_place[_bi]
		buildings_to_place[_bi] = buildings_to_place[_bj]
		buildings_to_place[_bj] = _btmp
	
	for entry in buildings_to_place:
		var cell: Vector2i = spawn_cell + (entry["offset"] as Vector2i)
		var b_type: int = entry["type"] as int
		if _is_in_bounds(cell):
			var result: Dictionary = building_system.can_place(
				b_type, cell, entry["rot"] as int, _tile_grid, world_width, world_height
			)
			if result.get("valid", false):
				building_system.place_building(b_type, cell, entry["rot"] as int, self, false)
			else:
				# Fallback: scan for a nearby walkable tile
				var found := false
				for radius in range(1, 5):
					for dx in range(-radius, radius + 1):
						for dy in range(-radius, radius + 1):
							var try_cell: Vector2i = spawn_cell + (entry["offset"] as Vector2i) + Vector2i(dx, dy)
							if _is_in_bounds(try_cell):
								var try_result: Dictionary = building_system.can_place(
									b_type, try_cell, entry["rot"] as int, _tile_grid, world_width, world_height
								)
								if try_result.get("valid", false):
									building_system.place_building(b_type, try_cell, entry["rot"] as int, self, false)
									found = true
									break
						if found:
							break
					if found:
						break

## Scatters nature objects (bushes, flowers, mushrooms, stumps) across the
## world to make the environment feel more alive and varied.
func _scatter_nature_objects() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + 22222
	
	# Reset nature cells tracker so trees can avoid these positions
	_nature_cells.clear()
	
	var bush_count := rng.randi_range(6, 12)
	var flower_count := rng.randi_range(8, 16)
	var mushroom_count := rng.randi_range(4, 8)
	var stump_count := rng.randi_range(8, 14)
	
	# Scatter on grass/dirt/fertile tiles only
	_scatter_nature_type(bush_count, "Bush", rng)
	_scatter_nature_type(flower_count, "FlowerPatch", rng)
	_scatter_nature_type(mushroom_count, "MushroomPatch", rng)
	_scatter_nature_type(stump_count, "LogStump", rng)

func _scatter_nature_type(count: int, type_name: String, rng: RandomNumberGenerator) -> void:
	var attempts := 0
	var placed := 0
	while placed < count and attempts < count * 30:
		attempts += 1
		var x := rng.randi_range(2, world_width - 3)
		var y := rng.randi_range(2, world_height - 3)
		var cell := Vector2i(x, y)
		
		if not _is_in_bounds(cell):
			continue
		
		var tile_id: String = _tile_grid[y][x]
		var tile_type: TileTypeData = DataManager.get_tile_type(tile_id)
		if not tile_type or not tile_type.walkable:
			continue
		if tile_id == "path" or tile_id == "sand":
			continue
		# Don't place nature objects on the dock visual footprint
		if _dock_cell != Vector2i(-1, -1):
			var dl := cell - _dock_cell
			if dl.y >= -3 and dl.y <= 11 and dl.x >= -10 and dl.x <= 25:
				continue
		
		# Don't place nature objects on the shop footprint (5x3 tiles)
		if _shop_cell != Vector2i(-1, -1):
			var sl := cell - _shop_cell
			if abs(sl.x) <= 2 and abs(sl.y) <= 1:
				continue
		
		# Skip town area — the backdrop sprite shows the buildings/streets
		var town_rect: Rect2i = get_meta("town_rect", Rect2i())
		if town_rect.size.x > 0 and town_rect.has_point(cell):
			continue
		
		# Check not blocked by existing object (trees, buildings, etc.)
		# Use 256.0 (1 tile radius) to prevent overlap with tree foliage.
		var blocked := false
		var w_pos := cell_to_world(cell)
		for child in objects_root.get_children():
			if child.global_position.distance_squared_to(w_pos) < 256.0:
				blocked = true
				break
		if blocked:
			continue
		
		var node: Area2D = null
		match type_name:
			"Bush":
				node = BUSH_SCENE.instantiate()
				node.name = "Bush_%d_%d" % [x, y]
				# Use AI sprites with random color tinting
				node.texture_override_pool = [
					"res://assets/generated/plain_bush_01.png",
					"res://assets/generated/plain_bush_02.png",
					"res://assets/generated/plain_bush_03.png",
				]
			"FlowerPatch":
				node = FLOWER_SCENE.instantiate()
				node.name = "Flower_%d_%d" % [x, y]
				# Use AI sprites with random color tinting (flower_color already random)
				node.texture_override_pool = [
					"res://assets/generated/plain_flower_01.png",
					"res://assets/generated/plain_flower_02.png",
					"res://assets/generated/plain_flower_03.png",
				]
			"MushroomPatch":
				node = MUSHROOM_SCENE.instantiate()
				node.name = "Mushroom_%d_%d" % [x, y]
				# Use AI sprites with random color tinting (cap_color already random)
				node.texture_override_pool = [
					"res://assets/generated/plain_mushroom_01.png",
					"res://assets/generated/plain_mushroom_02.png",
					"res://assets/generated/plain_mushroom_03.png",
				]
			"LogStump":
				var script := load(LOG_STUMP_SCENE_PATH) as GDScript
				if script:
					node = Area2D.new()
					node.set_script(script)
					node.name = "Stump_%d_%d" % [x, y]
		
		if node:
			# Only add Sprite2D manually for LogStump (which is still Area2D.new()+set_script)
			# Bush/FlowerPatch/MushroomPatch come from scenes that already have a Sprite2D child
			if not node.has_node("Sprite2D"):
				var sprite := Sprite2D.new()
				sprite.name = "Sprite2D"
				node.add_child(sprite)
			objects_root.add_child(node)
			node.global_position = w_pos
			_nature_cells[cell] = true
			placed += 1

# ---------------------------------------------------------------------------
# Build Mode (player-facing building placement)
# ---------------------------------------------------------------------------

## Attempts to enter build mode. Returns true if a building item is available.
func enter_build_mode() -> bool:
	if build_mode_active:
		return true

	# Prefer the building kit in the player's currently selected hotbar slot,
	# so having "decorative_fountain_kit" selected actually places a fountain
	# even when other kits (e.g. decorative_statue_kit) are also in inventory.
	var hotbar_item_id := _get_selected_hotbar_item_id()
	if not hotbar_item_id.is_empty() and BUILD_ITEM_TO_TYPE.has(hotbar_item_id):
		build_item_id = hotbar_item_id
		build_type = BUILD_ITEM_TO_TYPE[hotbar_item_id]
		build_mode_active = true
		ToastNotification.show_toast("Build mode [V]: point at a tile and press [E] to place", ToastNotification.ToastType.INFO, 3.5)
		_show_hud_hint("Build mode active — move cursor and press E to place")
		return true

	# Fallback: scan inventory for any placeable building material
	for item_id: String in BUILD_ITEM_TO_TYPE:
		if InventoryManager.has_item(item_id, 1):
			build_item_id = item_id
			build_type = BUILD_ITEM_TO_TYPE[item_id]
			build_mode_active = true
			ToastNotification.show_toast("Build mode [V]: point at a tile and press [E] to place", ToastNotification.ToastType.INFO, 3.5)
			_show_hud_hint("Build mode active — move cursor and press E to place")
			return true
	
	# No materials — give unmistakable persistent feedback so the player can't miss it
	ToastNotification.show_toast("⚠ No building materials! Craft fence or campfire from the Crafting menu [C] first", ToastNotification.ToastType.ERROR, 5.0)
	var _fence_name := DataManager.get_item("fence_material").display_name if DataManager.get_item("fence_material") else "Fence Material"
	var _stone_name := DataManager.get_item("stone_fence_material").display_name if DataManager.get_item("stone_fence_material") else "Stone Fence Material"
	var _campfire_name := DataManager.get_item("campfire_kit").display_name if DataManager.get_item("campfire_kit") else "Campfire Kit"
	_show_hud_hint("Need %s, %s, or %s — press C to craft then V to build" % [_fence_name, _stone_name, _campfire_name])
	return false


## Returns the item ID (e.g. "decorative_fountain_kit") in the player's
## currently selected hotbar slot, or "" if the slot is empty / not a hotbar slot.
func _get_selected_hotbar_item_id() -> String:
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return ""
	var tool_val: int = player.active_tool
	# Map Player.Tool enum values to inventory slot indices
	# HOTBAR_0=3 → inv 0, HOTBAR_1=4 → inv 1, … HOTBAR_3=6 → inv 3
	# HOTBAR_4=12 → inv 4, HOTBAR_5=13 → inv 5, … HOTBAR_7=15 → inv 7
	var slot_idx: int = -1
	if tool_val >= 3 and tool_val <= 6:         # HOTBAR_0 … HOTBAR_3
		slot_idx = tool_val - 3
	elif tool_val >= 12 and tool_val <= 15:     # HOTBAR_4 … HOTBAR_7
		slot_idx = tool_val - 12 + 4

	if slot_idx < 0 or slot_idx >= InventoryManager.slots.size():
		return ""
	var slot_data = InventoryManager.slots[slot_idx]
	return slot_data.get("item_id", "") if slot_data is Dictionary else ""

## Exits build mode and clears the preview.
func exit_build_mode() -> void:
	build_mode_active = false
	build_item_id = ""
	build_type = BuildingSystem.BuildingType.NONE
	_clear_tool_preview()

## Shows a persistent tutorial-style hint on the HUD (auto-hides after 5s).
func _show_hud_hint(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_tutorial_hint"):
		hud.show_tutorial_hint(text)

## Shows a moment-of-action hint only the first time the given action happens
## per session (delegates to HUD.show_first_action_hint).
func _show_first_action_hint(action_id: String, text: String, duration: float = 5.0) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_first_action_hint"):
		hud.show_first_action_hint(action_id, text, duration)

## Toggles build mode on/off. Returns the new state.
func toggle_build_mode() -> bool:
	if build_mode_active:
		exit_build_mode()
		return false
	return enter_build_mode()

## Places the current building at the given tile cell.
## Returns true and refunds inventory on success.
func try_place_building(cell: Vector2i) -> bool:
	if not build_mode_active or build_type == BuildingSystem.BuildingType.NONE:
		return false

	if not _is_in_bounds(cell):
		ToastNotification.show_toast("Out of bounds!", ToastNotification.ToastType.ERROR)
		return false
	if build_item_id.is_empty() or not InventoryManager.has_item(build_item_id, 1):
		exit_build_mode()
		ToastNotification.show_toast("Out of building materials!", ToastNotification.ToastType.ERROR)
		return false

	var result: Dictionary = building_system.can_place(build_type, cell, 0, _tile_grid, world_width, world_height)
	if not result.get("valid", false):
		ToastNotification.show_toast(result.get("reason", "Cannot place here!"), ToastNotification.ToastType.ERROR)
		return false

	building_system.place_building(build_type, cell, 0, self)
	InventoryManager.remove_item(build_item_id, 1)

	# Register special building types
	_register_special_building(build_type, cell)

	var data: Dictionary = BuildingSystem.BUILDING_DATA.get(build_type, {})
	var name_str: String = data.get("name", "Building")

	# Check if we should stay in build mode (fences can be placed multiple times)
	var keep_mode: bool = BuildingSystem.keeps_build_mode(build_type) and InventoryManager.has_item(build_item_id, 1)

	if keep_mode:
		var remaining: int = InventoryManager.get_count(build_item_id)
		ToastNotification.show_toast("Placed %s! (%d remaining - press V to exit build mode)" % [name_str, remaining], ToastNotification.ToastType.SUCCESS, 2.5)
	else:
		ToastNotification.show_toast("Placed %s!" % name_str, ToastNotification.ToastType.SUCCESS)

	AudioManager.play(AudioManager.Sound.BUILD)
	LevelManager.add_xp_source("build")

	# Grab the placed type BEFORE exit_build_mode() resets build_type to
	# BuildingType.NONE — otherwise the sync RPC below sends 0 (NONE) and the
	# host's _sync_place_building() no-ops (BUILDING_DATA.has(0) is false), so a
	# non-keep-mode building (barn, home, silo, well…) placed by a client never
	# appears on other peers.
	var placed_type: int = build_type
	if not keep_mode:
		exit_build_mode()

	_show_first_action_hint("first_build",
		"Built! Walk to the door and press [E] to enter.")

	# Sync to remote peers
	if NetworkManager.is_network_active():
		rpc("_sync_place_building", placed_type, cell)

	return true

## Picks up a placed building at the given cell, refunding the kit item.
## Only works while build mode is active. Returns true on success.
func try_pickup_building(cell: Vector2i) -> bool:
	if not build_mode_active:
		return false
	if not _is_in_bounds(cell):
		return false

	var building_data: Dictionary = building_system.get_building_at(cell)
	if building_data.is_empty():
		ToastNotification.show_toast("No building here!", ToastNotification.ToastType.ERROR)
		return false

	var b_type: int = building_data.get("type", -1)
	if b_type < 0:
		return false

	var item_id: String = TYPE_TO_BUILD_ITEM.get(b_type, "")
	if item_id.is_empty():
		ToastNotification.show_toast("Can't pick this up!", ToastNotification.ToastType.ERROR)
		return false

	# Clean up special tracking arrays
	# Clean up special tracking arrays
	_unregister_special_building(b_type, cell)

	# Remove the building node and data
	building_system.remove_building(cell, self)

	# Refund the item to the player's inventory
	InventoryManager.add_item(item_id, 1)

	var data: Dictionary = BuildingSystem.BUILDING_DATA.get(b_type, {})
	var name_str: String = data.get("name", "Building")
	ToastNotification.show_toast("Picked up %s!" % name_str, ToastNotification.ToastType.SUCCESS)
	AudioManager.play(AudioManager.Sound.PICKUP_ITEM)
	LevelManager.add_xp_source("build")

	# Sync to remote peers
	if NetworkManager.is_network_active():
		rpc("_sync_remove_building", cell, b_type)

	return true

# ---------------------------------------------------------------------------
# System accessors for save/load and other systems
# ---------------------------------------------------------------------------

## Returns the BuildingSystem reference for save/load and building interaction
func get_building_system() -> BuildingSystem:
	return building_system

## Returns the CookingSystem reference for cooking UI
func get_cooking_system() -> CookingSystem:
	return cooking_system

## Set the cooking system from save data
func set_cooking_system(cs: CookingSystem) -> void:
	cooking_system = cs

## Returns whether build mode is currently active.
func get_build_mode_state() -> bool:
	return build_mode_active

# Current interior scene the player is inside (null if outside)
var current_interior: BuildingInterior = null
var _hint_interior_shown: bool = false
var _exit_cooldown: bool = false  # prevents re-entering briefly after exit

## Enter a building interior. Called when the player walks into a building.
var _outside_player_pos: Vector2 = Vector2.ZERO  # where to return the player on exit
var _previous_player_z: int = 0  # z_index to restore on exit

# Void location for interior rendering — far from world tiles so nothing shows through
const INTERIOR_VOID := Vector2(10000, 10000)
const INTERIOR_SCALE := 1.0
# The co-op mine lives at its own void region so it can never overlap the
# expedition island or building interiors (which share INTERIOR_VOID).
# Without this, a player sailing to an island while a teammate is downed in
# the mine sees the downed teammate's copy inside the island.
const MINE_VOID := INTERIOR_VOID + Vector2(20000, 0)

func enter_building(interior: BuildingInterior) -> void:
	if current_interior:
		return  # already inside
	if _exit_cooldown:
		return  # just exited, brief cooldown
	# Gate on the player's ACTUAL state, not current_mine_room. The host keeps a
	# session-only mine room when a client is inside while the host stays on the
	# surface; that room existing must NOT block the host from entering buildings.
	if GameManager.inside_mine or _mine_exit_cooldown:
		return  # don't enter building from inside a mine
	
	current_interior = interior
	GameManager.inside_interior = true
	GameManager.inside_building = true
	# Broadcast a unique building key so remote peers can hide anyone who is in a
	# DIFFERENT interior (all building interiors share INTERIOR_VOID). Town-ruin
	# interiors carry a ruin_id key; regular buildings fall back to their cell.
	GameManager.current_building_key = interior.get_building_key()
	AudioManager.play_music(AudioManager.Sound.INTERIOR_MUSIC)
	AudioManager.play(AudioManager.Sound.DOOR_OPEN)
	# Show interior tutorial hint once
	if not _hint_interior_shown:
		_hint_interior_shown = true
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_interior_hint"):
			hud.show_interior_hint()
	
	# Despawn non-boss enemies so they don't try to pathfind to the void
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy and is_instance_valid(enemy) and not enemy.is_in_group("bosses"):
			enemy.queue_free()
	
	# Defer the scene tree changes to avoid "flushing queries" error
	# (called from Area2D.body_entered physics callback)
	call_deferred("_deferred_setup_interior", interior)

	# Player setup (non-deferred — position/velocity changes are safe)
	# Only move THIS peer's local player; remote copies on this peer stay put
	# and will be updated via position RPCs from their owning peers.
	for player in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(player) or not _is_local_player(player):
			continue
		_outside_player_pos = player.global_position
		if player is CharacterBody2D:
			player.velocity = Vector2.ZERO
		# Player renders above room floor
		_previous_player_z = player.z_index
		player.z_index = 2
		# Place player in the center of the room (NOT at the exit door to avoid instant exit)
		player.global_position = INTERIOR_VOID + Vector2(40, 36) * INTERIOR_SCALE
		player.visible = true
		player.set_process(true)
		player.set_physics_process(true)
		break

	# Fade transition (safe to call anytime)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("fade_to_black"):
		hud.fade_to_black(0.3)
	
	# Broadcast updated stats so remote peers see inside_interior=true immediately
	GameManager._try_broadcast_player_stats()

func _deferred_setup_interior(interior: BuildingInterior) -> void:
	if not is_instance_valid(interior):
		# The interior was freed between entry and setup (e.g. the world
		# regenerated). Pull the local player back out of the void so they
		# aren't stranded in the blue abyss with no room to stand on.
		_on_exit_interior()
		return
	interior.position = INTERIOR_VOID
	interior.scale = Vector2(INTERIOR_SCALE, INTERIOR_SCALE)
	add_child(interior)
	interior.exited_interior.connect(_on_exit_interior)

func _on_exit_interior() -> void:
	current_interior = null
	GameManager.inside_interior = false
	GameManager.inside_building = false
	GameManager.current_building_key = ""
	AudioManager.resume_ambient_music()
	AudioManager.play(AudioManager.Sound.DOOR_CLOSE)
	# Brief cooldown so the player doesn't immediately re-enter the building
	_exit_cooldown = true
	get_tree().create_timer(0.5).timeout.connect(func(): _exit_cooldown = false)
	
	# Fade transition
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("fade_to_black"):
		hud.fade_to_black(0.3)
	
	# Move ONLY the local player back outside
	for player in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(player) or not _is_local_player(player):
			continue
		if _outside_player_pos != Vector2.ZERO:
			player.global_position = _outside_player_pos
		if player is CharacterBody2D:
			player.velocity = Vector2.ZERO
		player.z_index = _previous_player_z
		player.visible = true
		player.set_process(true)
		player.set_physics_process(true)
		break
	
	# Broadcast updated stats so remote peers see inside_interior=false immediately
	GameManager._try_broadcast_player_stats()


# ── Mine System ──

var _mine_outside_pos: Vector2 = Vector2.ZERO
var _mine_prev_z: int = 0
var _mine_current_depth: int = 0  # tracks current depth while in mine

# ── Expedition Island ──
var _current_island: ExpeditionIsland = null
var _island_outside_pos: Vector2 = Vector2.ZERO
var _island_prev_z: int = 0
var _island_exit_cooldown: bool = false  # brief cooldown after returning

## Removed island object ids, keyed by island seed -> { obj_id: true }. Tracked
## on the always-present World node (not the transient island, which only exists
## while a peer is on-island) so every peer accumulates removals regardless of
## its current presence, enabling backfill to a late joiner on island entry.
## Mirrors _removed_cell_objects for the main world.
var _island_removed: Dictionary = {}

# Host-side shared-island sessions. Keyed by island type so that multiple
# players can be on DIFFERENT island types at the same time; every player
# traveling to the same type joins the same generated island (same seed).
var _island_sessions: Dictionary = {}  # island_type -> { "seed": int, "members": {peer_id: true} }
var _island_peer_type: Dictionary = {}  # peer_id -> island_type the peer is currently on

## Host's hidden authoritative island copy, built when a client enters an island
## session while the host player stays home. Mirrors _server_build_mine_room so
## the host's resident island animals exist and can drive combat/HP for the
## client's remote mirrors (otherwise _find_animal_by_id finds nothing and
## attack/tame/feed silently no-op). Only one proxy is kept at a time; it is
## freed when the session empties or when the host player enters an island itself.
var _host_island_proxy: ExpeditionIsland = null
var _host_island_proxy_seed: int = 0

## Called when the player walks into proximity of a mine entrance area.
## Marks the entrance as nearby for E-press interaction.
func _on_mine_entrance_near(body: Node, entrance_node: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	# Gate on the player's ACTUAL state, not current_mine_room. The host keeps a
	# session-only room when a client is inside the mine while the host stays on
	# the surface; current_mine_room being set must NOT block the host from
	# approaching/entering other mines (or buildings).
	if GameManager.inside_mine:
		return
	if _mine_exit_cooldown:
		return
	if GameManager.inside_interior:
		return
	_player_near_mine_entrance = true
	_player_mine_entrance_node = entrance_node


## Called when the player leaves a mine entrance area.
func _on_mine_entrance_left(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	_player_near_mine_entrance = false
	_player_mine_entrance_node = null


## Check if the player CAN enter a mine (used by hold-to-interact).
## Returns true if the player is near a valid mine entrance.
func can_enter_mine() -> bool:
	if not _player_near_mine_entrance or not _player_mine_entrance_node:
		return false
	# Gate on the player's actual state (see _on_mine_entrance_near note).
	if GameManager.inside_mine:
		return false
	if _mine_exit_cooldown:
		return false
	if GameManager.inside_interior:
		return false
	return true

## Called when the player presses E near a mine entrance in the overworld.
## Returns true if the player was near an entrance and entered the mine.
## In multiplayer, only the host processes this and broadcasts the mine creation.
func try_enter_mine() -> bool:
	if not _player_near_mine_entrance or not _player_mine_entrance_node:
		return false
	# Gate on the player's actual state (see _on_mine_entrance_near note).
	if GameManager.inside_mine:
		return false
	if _mine_exit_cooldown:
		return false
	if GameManager.inside_interior:
		return false
	
	var entrance_node: Node2D = _player_mine_entrance_node
	
	# Determine which entrance index this is — each entrance spawns
	# the player at a different chamber in the underground.
	var entrance_index: int = entrance_node.get_meta("entrance_index", 0)
	
	# Determine mine depth based on entrance position
	var depth: int = 1
	var cx := int(entrance_node.position.x / TILE_SIZE)
	var cy := int(entrance_node.position.y / TILE_SIZE)
	var center_x := world_width / 2
	var center_y := world_height / 2
	var dist_from_center := sqrt(pow(cx - center_x, 2) + pow(cy - center_y, 2))
	if dist_from_center < 15.0:
		depth = 3
	elif dist_from_center < 25.0:
		depth = 2
	
	# In multiplayer, clients request entry via RPC; the host coordinates
	# which shared room (entrance + depth) everyone joins.
	if NetworkManager.is_network_active() and not multiplayer.is_server():
		rpc_id(1, "_server_try_enter_mine", entrance_index, depth)
		return true
	
	return _server_try_enter_mine(entrance_index, depth)


## True when `player` is this peer's own copy. Without a network peer (single
## player) every node is local, so these checks never touch the network API.
func _is_local_player(player: Node) -> bool:
	if not NetworkManager.is_network_active():
		return true
	return player.get_multiplayer_authority() == multiplayer.get_unique_id()


## This peer's multiplayer id. Returns 1 (the default authority) when no
## network peer is assigned, so single-player never errors on the peer API.
func _self_id() -> int:
	if not NetworkManager.is_network_active():
		return 1
	return multiplayer.get_unique_id()


## The peer id of the caller of the current RPC. When called directly (host
## pressing E) or in single-player, this resolves to the local peer.
func _sender_id() -> int:
	if not NetworkManager.is_network_active():
		return 1
	var sender: int = multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = multiplayer.get_unique_id()
	return sender


## Host: decide the shared mine room for the requesting peer and tell only
## that peer to enter it. Each peer renders its own deterministic copy, so
## the host's own player is NOT moved when a client enters.
## When called directly (host pressing E), sender defaults to the host.
## Returns true if the caller's own player was moved into the mine.
@rpc("any_peer", "reliable")
func _server_try_enter_mine(entrance_index: int, depth: int) -> bool:
	if not multiplayer.is_server():
		return false
	var sender: int = _sender_id()
	
	var target_e: int = entrance_index
	var target_d: int = depth
	if _mine_session_active:
		# Someone is already inside — join the same shared room so
		# co-op players end up together.
		target_e = _mine_session_entrance
		target_d = _mine_session_depth
	else:
		_mine_session_active = true
		_mine_session_entrance = entrance_index
		_mine_session_depth = depth
	_mine_session_members[sender] = true
	
	if sender == _self_id():
		return _do_enter_mine(target_e, target_d)
	# A client is entering while the host stays on the surface: build the
	# host's deterministic copy of the shared room so the host's enemy AI
	# exists and can drive combat for everyone inside the mine.
	if current_mine_room == null and not GameManager.inside_mine:
		_server_build_mine_room(target_e, target_d)
		# Point the host's mine enemies at the entering client's remote copy
		# right away. Otherwise they wait for the client's position to sync
		# within chase_range before engaging, so the client's remote copies
		# appear frozen for the first second or two. The build is deferred, so
		# defer this until the room (and its enemies) actually exist.
		call_deferred("_retarget_mine_enemies_to_client", sender)
	rpc_id(sender, "_receive_enter_mine", target_e, target_d)
	return true


## Client-side receiver: run the same local mine entry so this client's own
## player is transported into its local copy of the shared room.
@rpc("authority", "reliable")
func _receive_enter_mine(entrance_index: int, depth: int) -> void:
	_do_enter_mine(entrance_index, depth)


## Host: after a client enters the mine, aim every enemy in the host's
## authoritative mine room at that client's remote player copy so they start
## moving/attacking immediately instead of idling until the client's position
## syncs within chase_range. Fixes "client's mine enemies appear but do not move".
func _retarget_mine_enemies_to_client(client_peer: int) -> void:
	if not current_mine_room or not is_instance_valid(current_mine_room):
		return
	# Find the client's remote player copy on this host.
	var target: Node2D = null
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and (p is Node2D) \
				and p.get_multiplayer_authority() == client_peer:
			target = p as Node2D
			break
	if not target:
		return
	for child in current_mine_room.get_children():
		if is_instance_valid(child) and child.has_method("retarget_to_player"):
			child.retarget_to_player(target)


## Host: after the host's own player leaves the mine while clients remain
## inside, point every enemy in the authoritative room at an in-room client's
## remote copy so the AI keeps fighting them. Without this the enemies keep a
## stale reference to the (now gone) host player and idle until their target
## refreshes — which Player 2 sees as "enemies standing still".
func _retarget_mine_enemies_to_remaining_clients() -> void:
	if not current_mine_room or not is_instance_valid(current_mine_room):
		return
	var ready: Array[int] = get_mine_ready_peer_ids()
	if ready.is_empty():
		return
	for pid in ready:
		var target: Node2D = null
		for p in get_tree().get_nodes_in_group("player"):
			if is_instance_valid(p) and (p is Node2D) \
					and p.get_multiplayer_authority() == pid:
				target = p as Node2D
				break
		if target:
			for child in current_mine_room.get_children():
				if is_instance_valid(child) and child.has_method("retarget_to_player"):
					child.retarget_to_player(target)
			return


## Internal: actually create the mine room so THIS peer's player enters.
## The room is generated deterministically, so each peer's copy matches.
## Only the local player is moved (remote players enter on their own peers).
## Returns true if the mine was created.
func _do_enter_mine(entrance_index: int, depth: int) -> bool:
	if _mine_exit_cooldown:
		return false
	if GameManager.inside_interior:
		return false
	# If a room already exists AND this peer's local player is already inside
	# it, there is nothing to do. But a room may exist while the local player is
	# NOT inside: the host pre-builds its deterministic copy when a client enters
	# the mine without the host (so the host's enemy AI can drive combat). In that
	# case the host's own player entering must still be moved into the existing
	# room rather than being blocked. (Regression: the old `if current_mine_room:
	# return false` left the host stranded on the surface forever once it had
	# pre-built a room for a client.)
	if current_mine_room and GameManager.inside_mine:
		return false
	
	AudioManager.play_music(AudioManager.Sound.CAVE_MUSIC)
	AudioManager.play(AudioManager.Sound.CAVE_AMBIENCE)
	
	# Create mine room with generator (skip if one already exists — e.g. the
	# host pre-built it for a client; we just move our own player into it).
	var world_seed_val: int = world_seed if world_seed > 0 else 0
	var mine_generator: MineGenerator = null
	var mine: MineRoom = null
	if current_mine_room == null:
		mine_generator = MineGenerator.create(world_seed_val + depth * 7777, 64, 48)
		mine = MineRoom.new()
		mine.name = "MineRoom"
		mine.depth_level = depth
		mine.entrance_index = entrance_index
		mine.generator = mine_generator
		current_mine_room = mine
		_mine_current_depth = depth
	
	# Notify ObjectiveManager — mine entry and depth reached
	var om_mine := get_tree().get_first_node_in_group("objective_manager")
	if om_mine:
		if om_mine.has_method("on_enter_mine"):
			om_mine.on_enter_mine(depth)
		if om_mine.has_method("on_reach_mine_depth"):
			om_mine.on_reach_mine_depth(depth)
	
	_show_first_action_hint("first_mine",
		"Mine! Deeper floors have better ores but tougher enemies.")
	
	GameManager.inside_interior = true
	GameManager.inside_mine = true
	
	# Despawn non-boss enemies
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy and is_instance_valid(enemy) and not enemy.is_in_group("bosses"):
			enemy.queue_free()
	
	# Move ONLY the local player to the void position (matching the interior
	# pattern). Remote copies on this peer stay put — their own peers move them.
	var local_player: Node = null
	for player in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(player) and _is_local_player(player):
			local_player = player
			break
	# Resolve the generator for the room we are entering — the freshly created
	# one, or the existing pre-built room's generator when the host enters a
	# room it already created for a client.
	var gen: MineGenerator = current_mine_room.generator if current_mine_room else mine_generator
	if local_player:
		# Save this peer's own local player's outside position so we can
		# return it to the surface on exit.
		_mine_outside_pos = local_player.global_position
		if local_player is CharacterBody2D:
			local_player.velocity = Vector2.ZERO
		local_player.z_index = 2
		var spawn_pos := gen.get_spawn_position(entrance_index)
		local_player.global_position = MINE_VOID + spawn_pos
		local_player.visible = true
		local_player.set_process(true)
		local_player.set_physics_process(true)
		local_player.show_dialogue("in here... I should explore deeper and find valuable ores.", 4.0)
	
	# Add the mine room at the void position (deferred so the room builds after
	# this frame). Skip when the room already exists (host entering a room it
	# pre-built for a client) — it is already set up.
	if mine:
		call_deferred("_deferred_setup_mine_room", mine)
	
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("fade_to_black"):
		hud.fade_to_black(0.3)
	
	# Clear proximity since player is no longer near entrance
	_player_near_mine_entrance = false
	_player_mine_entrance_node = null
	
	# Set camera limits to the mine bounds so the gray viewport background
	# is not visible when the player is near the edge of the map.
	_set_mine_camera_limits(gen.grid_width, gen.grid_height)
	
	return true


## Host: create the deterministic shared mine room WITHOUT moving the host's
## player (the host stays on the surface). The room's enemy subtree exists so
## the host can run enemy AI and the damage/health/death/loot broadcasts for
## clients who are inside the mine. Torn down when the session empties.
func _server_build_mine_room(entrance_index: int, depth: int) -> void:
	if current_mine_room:
		return
	var world_seed_val: int = world_seed if world_seed > 0 else 0
	var mine_generator := MineGenerator.create(world_seed_val + depth * 7777, 64, 48)
	var mine := MineRoom.new()
	mine.name = "MineRoom"
	mine.depth_level = depth
	mine.entrance_index = entrance_index
	mine.generator = mine_generator
	current_mine_room = mine
	_mine_current_depth = depth
	call_deferred("_deferred_setup_mine_room", mine)


func _set_mine_camera_limits(grid_w: int, grid_h: int) -> void:
	## Clamp the player camera to the mine's pixel bounds so the gray
	## viewport background is hidden behind the mine's own dark background.
	var player := get_tree().get_first_node_in_group("player")
	if not player or not is_instance_valid(player):
		return
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if not cam:
		return
	if not _is_local_player(player):
		# Only clamp the local player's camera (remote copies have disabled cameras).
		for p in get_tree().get_nodes_in_group("player"):
			if is_instance_valid(p) and _is_local_player(p):
				player = p
				cam = (player.get_node_or_null("Camera2D") as Camera2D)
				break
		if not cam:
			return
	var pixel_w := grid_w * 16
	var pixel_h := grid_h * 16
	cam.limit_left = int(MINE_VOID.x)
	cam.limit_top = int(MINE_VOID.y)
	cam.limit_right = int(MINE_VOID.x + pixel_w)
	cam.limit_bottom = int(MINE_VOID.y + pixel_h)


func _clear_mine_camera_limits() -> void:
	## Remove camera limits when leaving the mine so the overworld camera
	## can scroll freely again.
	var player := get_tree().get_first_node_in_group("player")
	if not player or not is_instance_valid(player):
		return
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if not cam:
		return
	if not _is_local_player(player):
		for p in get_tree().get_nodes_in_group("player"):
			if is_instance_valid(p) and _is_local_player(p):
				player = p
				cam = (player.get_node_or_null("Camera2D") as Camera2D)
				break
		if not cam:
			return
	cam.limit_left = -10000000
	cam.limit_top = -10000000
	cam.limit_right = 10000000
	cam.limit_bottom = 10000000


func _deferred_setup_mine_room(mine: MineRoom) -> void:
	if not is_instance_valid(mine):
		return
	mine.position = MINE_VOID
	mine.scale = Vector2(1.0, 1.0)
	# Ensure a stable node name so node-path enemy RPCs (World/MineRoom/MineEnemy_N)
	# resolve identically on every peer. If the name is ever left empty (or the
	# room is added while a same-named sibling still exists), Godot auto-names it
	# `@Node2D@<instance_id>`, which DIFFERS per peer and silently breaks every
	# mine-enemy RPC broadcast (the "Node not found / Failed to get path" flood).
	mine.name = "MineRoom"
	# On a descent/re-entry the previous room was queue_free()d, but queued
	# deletions flush AFTER deferred calls — so the stale "MineRoom" sibling is
	# still a child of World right now. If we only queue_free() it and then
	# add_child(mine), Godot collides on the duplicate name and auto-renames the
	# fresh room to `@Node2D@<id>`, which DIFFERS per peer and silently breaks
	# every mine-enemy node-path RPC (the "Node not found / Failed to get path"
	# flood). Remove the stale sibling from the tree synchronously so the fresh
	# room reliably keeps the stable name. Safely ignores a missing sibling.
	var existing := get_node_or_null("MineRoom")
	if existing and existing != mine:
		remove_child(existing)
		existing.queue_free()
	add_child(mine)
	mine.exited.connect(_on_exit_mine)
	mine.descended.connect(_on_mine_descended)

	# Once the room (and its enemy subtree) is built on this peer, tell the
	# host so it can start node-path RPCs to us. The host's own copy is the
	# authority and is never sent broadcasts, so it only acks when a client.
	if NetworkManager.is_network_active() and not multiplayer.is_server():
		rpc_id(1, "_notify_mine_room_ready")
		# Pull the host's current ore-depletion snapshot so deposits this peer
		# never saw being mined don't look full (and its swings aren't rejected).
		rpc_id(1, "_server_request_mine_deposit_state")

	# Push fresh stats now that we are inside the mine: remote copies rely on
	# inside_interior/inside_mine flags to stay visible and show their health
	# bar (stats otherwise only broadcast on damage/heal/hunger events).
	GameManager._try_broadcast_player_stats()


## Client → host: this peer's local mine room is fully built. The host then
## includes the sender in enemy state/damage/death/respawn/loot broadcasts.
@rpc("any_peer", "reliable")
func _notify_mine_room_ready() -> void:
	if not multiplayer.is_server():
		return
	_mine_session_room_ready[_sender_id()] = true


## Client → host: this peer just built its local mine room and wants the
## host's current ore-depletion for every deposit, so deposits that were
## mined (or regenerating) before it built its copy match exactly.
## The serialized snapshot (deposits + enemy HP) can exceed a single EOS
## reliable packet (~1170 bytes) on a large floor, so it is streamed in
## byte-chunks exactly like the world-state / farm-delta snapshots.
@rpc("any_peer", "reliable")
func _server_request_mine_deposit_state() -> void:
	if not multiplayer.is_server():
		return
	var sender: int = _sender_id()
	if not current_mine_room or not is_instance_valid(current_mine_room):
		return
	var entries: Array = []
	for child in current_mine_room.get_children():
		if child is OreDeposit and is_instance_valid(child):
			entries.append({
				"d": child.deposit_id,
				"h": child.remaining_hits,
				"g": child.get("_is_regenerating") == true,
			})
	# Backfill the full live mine-enemy snapshot so a late joiner matches the
	# host's current mine: not just HP (so already-damaged enemies aren't
	# unkillable full-HP blockers) but also TYPE and POSITION. The host's mine
	# evolves over time — enemies get respawned with NEW enemy_ids past the
	# client's deterministic initial set, and originals die. A pure HP backfill
	# matched by id can't create those respawned enemies, so the late joiner
	# would never see them. Each entry carries the type key (so a missing enemy
	# can be re-created client-side) and position (so living enemies sit where
	# the host has them, not at their stale spawn cell).
	var enemy_entries: Array = []
	for child in current_mine_room.get_children():
		if is_instance_valid(child) and (child is CaveCrawler or child is StoneGolem or child is CaveBat):
			var t: int = MineRoom.MINE_ENEMY_BAT
			if child is CaveCrawler:
				t = MineRoom.MINE_ENEMY_CRAWLER
			elif child is StoneGolem:
				t = MineRoom.MINE_ENEMY_GOLEM
			enemy_entries.append({
				"d": child.enemy_id,
				"t": t,
				"p": child.global_position,
				"h": child.current_health,
				"m": child.max_health,
			})
	var payload := var_to_bytes({"entries": entries, "enemy_entries": enemy_entries})
	var total: int = ceili(float(payload.size()) / float(WORLD_SYNC_CHUNK_BYTES))
	for i in range(total):
		var start: int = i * WORLD_SYNC_CHUNK_BYTES
		var end: int = mini(start + WORLD_SYNC_CHUNK_BYTES, payload.size())
		rpc_id(sender, "_receive_mine_deposit_state_chunk", i, total, payload.slice(start, end))


## Client: collect one mine-deposit-state chunk, then apply the whole snapshot
## once every piece has arrived. Reliable RPCs preserve order, so reassembly is
## safe (mirrors _receive_world_state_snapshot_chunk).
@rpc("authority", "reliable")
func _receive_mine_deposit_state_chunk(chunk_index: int, total_chunks: int, chunk: PackedByteArray) -> void:
	if multiplayer.is_server():
		return
	if chunk_index == 0:
		_pending_mine_state_chunks = []
		_pending_mine_state_chunks_total = total_chunks
	if _pending_mine_state_chunks.size() != chunk_index or total_chunks != _pending_mine_state_chunks_total:
		_pending_mine_state_chunks = []  # out-of-order/interleaved transfer — discard
		return
	_pending_mine_state_chunks.append(chunk)
	if _pending_mine_state_chunks.size() < _pending_mine_state_chunks_total:
		return
	var payload := PackedByteArray()
	for c in _pending_mine_state_chunks:
		payload.append_array(c)
	_pending_mine_state_chunks = []
	var data: Variant = bytes_to_var(payload)
	if not (data is Dictionary):
		return
	_receive_mine_deposit_state(data.get("entries", []), data.get("enemy_entries", []))


## Host → client: apply the host's ore-depletion snapshot to the matching
## deposits in the local room (matched by deterministic deposit_id), and
## reconcile the full live mine-enemy set so a late joiner matches the host's
## current mine (not just HP of the deterministic initial set — also the
## respawned enemies the client never generated, and removal of host-dead ones).
@rpc("authority", "reliable")
func _receive_mine_deposit_state(entries: Array, enemy_entries: Array = []) -> void:
	if not current_mine_room or not is_instance_valid(current_mine_room):
		return
	if current_mine_room.has_method("reconcile_enemies_from_host"):
		current_mine_room.reconcile_enemies_from_host(enemy_entries)
	for entry in entries:
		var did: int = int(entry.get("d", -1))
		if did < 0:
			continue
		for child in current_mine_room.get_children():
			if child is OreDeposit and is_instance_valid(child) and child.deposit_id == did:
				child.remaining_hits = int(entry.get("h", child.remaining_hits))
				if child.remaining_hits <= 0:
					# Mirror the host's depleted/regenerating state (hides sprite,
					# disables collision, starts the same regen timer or frees it).
					if child.has_method("_start_regeneration_host"):
						child._start_regeneration_host()
				elif child.has_method("_update_depletion_visual"):
					child._update_depletion_visual()
				break


## Peers whose local mine room is built and ready to receive node-path RPCs.
## Excludes the host's own id (the host is authoritative and drives locally).
func get_mine_ready_peer_ids() -> Array[int]:
	var ids: Array[int] = []
	var self_id: int = _self_id()
	# Only send to peers that are still connected. A peer whose "ready" entry was
	# left behind (e.g. a hard disconnect that skipped the cleanup handler) would
	# otherwise make mine enemies flood "Attempt to call RPC with unknown peer ID"
	# every sync tick. get_peers() is authoritative on the host.
	var connected: Array = []
	if NetworkManager.is_network_active():
		connected = multiplayer.get_peers()
	for pid in _mine_session_room_ready:
		if pid != self_id:
			if not NetworkManager.is_network_active() or connected.has(pid):
				ids.append(pid)
	ids.sort()
	return ids


## Force-exit the mine. Cleans up all mine state without requiring
## the exit ladder interaction. Used when the player dies or exits
## to menu while inside the mine.
## Does NOT move the player — the caller handles positioning.
func emergency_exit_mine() -> void:
	# A client tearing down its local mine room (death / emergency exit) must
	# tell the host to drop it from the shared-mine session, or the host keeps
	# sending node-path enemy RPCs to a peer whose MineEnemy nodes no longer
	# exist -> the "Node not found: MineRoom/MineEnemy_N" flood. Idempotent, and
	# skipped on the host itself (it is the server and tracks its own session).
	if NetworkManager.is_network_active() and not multiplayer.is_server():
		rpc_id(1, "_server_leave_mine_session")
	if current_mine_room and is_instance_valid(current_mine_room):
		current_mine_room.queue_free()
	current_mine_room = null
	_mine_current_depth = 0
	_mine_outside_pos = Vector2.ZERO
	_mine_prev_z = 0
	_mine_exit_cooldown = false
	GameManager.inside_interior = false
	GameManager.inside_mine = false
	AudioManager.resume_ambient_music()
	_clear_mine_camera_limits()
	
	var local_player: Node = null
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and _is_local_player(p):
			local_player = p
			break
	if local_player:
		if local_player is CharacterBody2D:
			local_player.velocity = Vector2.ZERO
		local_player.z_index = 1  # match the player's outdoor layer (above buildings)
		local_player.visible = true
		local_player.set_process(true)
		local_player.set_physics_process(true)


## Tear down the local expedition island without the normal exit flow (used when
## leaving to the main menu). Mirrors _do_exit_island's cleanup so no stale
## island node lingers: a stale island that stays in the "expedition_island"
## group makes _get_expedition_island() return it after a multiplayer REJOIN,
## and once the player is put back at the overworld spawn it computes the
## player's cell relative to the island origin (way out of bounds) and
## is_water_tile() returns true for every cell -> all movement is blocked.
func emergency_exit_island() -> void:
	var outside_pos: Vector2 = _island_outside_pos
	if _current_island and is_instance_valid(_current_island):
		_current_island.queue_free()
	_current_island = null
	_island_outside_pos = Vector2.ZERO
	GameManager.inside_interior = false
	GameManager.inside_island_seed = 0
	GameManager.near_campfire = false
	AudioManager.resume_ambient_music()

	var local_player: Node = null
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and _is_local_player(p):
			local_player = p
			break
	if local_player:
		if local_player is CharacterBody2D:
			local_player.velocity = Vector2.ZERO
		# Restore the overworld position recorded when the island was entered
		# so the player isn't left at the island void (which would be read as
		# water by the overworld walkability check).
		if outside_pos != Vector2.ZERO:
			local_player.global_position = outside_pos
		local_player.z_index = 1
		local_player.visible = true
		local_player.set_process(true)
		local_player.set_physics_process(true)


## Host: remove a peer from the shared-mine session when they disconnect.
## The disconnected peer's own copy is cleaned up on their side.
func mine_peer_disconnected(peer_id: int) -> void:
	_mine_session_members.erase(peer_id)
	_mine_session_room_ready.erase(peer_id)
	if not _mine_has_clients():
		_mine_session_active = false
		_mine_session_entrance = 1
		_mine_session_depth = 1
		if current_mine_room and not GameManager.inside_mine:
			current_mine_room.queue_free()
			current_mine_room = null
			_mine_current_depth = 0


## True when any client is still inside the shared mine. The host's
## authoritative MineRoom drives enemy AI for everyone inside, so it must be
## retained as long as a client is in the mine — even after the host's own
## player leaves. A client is "in the mine" if it is a session member or has a
## built/ready room (_mine_session_members can be stale/empty in edge cases, so
## the ready set is checked too).
func _mine_has_clients() -> bool:
	return not _mine_session_members.is_empty() or not _mine_session_room_ready.is_empty()


func _on_exit_mine() -> void:
	if not current_mine_room:
		return
	
	# In multiplayer, the host coordinates the shared session; clients
	# request their own exit (only the requesting peer leaves).
	if NetworkManager.is_network_active() and not multiplayer.is_server():
		rpc_id(1, "_server_exit_mine")
		return
	
	_server_exit_mine()


## Host: remove the requesting peer from the shared-mine session and tell
## ONLY that peer to exit. When called directly (host's own exit), sender
## defaults to the host. Single-player runs this locally too.
@rpc("any_peer", "reliable")
func _server_exit_mine() -> void:
	if not multiplayer.is_server():
		return
	var sender: int = _sender_id()
	
	_mine_session_members.erase(sender)
	_mine_session_room_ready.erase(sender)
	if not _mine_has_clients():
		_mine_session_active = false
		_mine_session_entrance = 1
		_mine_session_depth = 1
		# The host may hold a session-only room (built when a client entered
		# without the host). Tear it down now that nobody is inside.
		if current_mine_room and not GameManager.inside_mine:
			current_mine_room.queue_free()
			current_mine_room = null
			_mine_current_depth = 0
	
	if sender == _self_id():
		_do_exit_mine()
	else:
		rpc_id(sender, "_receive_exit_mine")


## Client-side receiver: run the same local mine exit so this client's own
## player is returned to the overworld.
@rpc("authority", "reliable")
func _receive_exit_mine() -> void:
	_do_exit_mine()


## Client -> host: this peer left the mine (e.g. died/respawned) and its local
## MineRoom/MineEnemy nodes are being freed. Remove it from the shared-mine
## session so the host stops sending node-path enemy RPCs to a peer whose
## MineRoom copy no longer exists (which would otherwise flood the console with
## "Node not found: MineRoom/MineEnemy_N" errors). Unlike _server_exit_mine, it
## does NOT move the player -- the caller already handled local cleanup.
@rpc("any_peer", "reliable")
func _server_leave_mine_session() -> void:
	if not multiplayer.is_server():
		return
	var sender: int = _sender_id()
	_mine_session_members.erase(sender)
	_mine_session_room_ready.erase(sender)
	if not _mine_has_clients():
		_mine_session_active = false
		_mine_session_entrance = 1
		_mine_session_depth = 1
		# Tear down a host-only session room now that nobody is left inside.
		if current_mine_room and not GameManager.inside_mine:
			current_mine_room.queue_free()
			current_mine_room = null
			_mine_current_depth = 0


## Internal: actually exit the mine for THIS peer (called locally or via RPC).
## Only the local player is moved back out.
func _do_exit_mine() -> void:
	if not current_mine_room:
		return
	
	_mine_exit_cooldown = true
	get_tree().create_timer(0.5).timeout.connect(func(): _mine_exit_cooldown = false)
	
	# Destroy the mine room (it's procedurally generated each time) — but ONLY
	# if this peer is the last one out. On the host the room is authoritative
	# for any clients still inside, so it must persist while the session is
	# active. (_mine_session_members is host-tracked; on a client it's always
	# empty, so a client still frees its own local room copy.)
	if not _mine_has_clients():
		current_mine_room.queue_free()
		current_mine_room = null
		_mine_current_depth = 0
	else:
		# A client is still in the mine and the host just left: aim every enemy
		# in the host's authoritative room at the remaining in-room clients so
		# they keep moving/attacking (instead of idling once the host's own
		# player is out of the room and the enemies' old target goes stale).
		_retarget_mine_enemies_to_remaining_clients()
	GameManager.inside_interior = false
	GameManager.inside_mine = false
	AudioManager.resume_ambient_music()

	# Fresh stats so remote copies flip back to the overworld visibility.
	GameManager._try_broadcast_player_stats()
	
	# Clear camera limits so the overworld camera scrolls freely
	_clear_mine_camera_limits()
	
	# Fade transition
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("fade_to_black"):
		hud.fade_to_black(0.3)
	
	# Move ONLY the local player back outside
	for player in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(player):
			continue
		if not _is_local_player(player):
			continue
		if _mine_outside_pos != Vector2.ZERO:
			player.global_position = _mine_outside_pos
		if player is CharacterBody2D:
			player.velocity = Vector2.ZERO
		player.z_index = _mine_prev_z
		player.visible = true
		player.set_process(true)
		player.set_physics_process(true)
		break


## Called when the player walks into the descent shaft in a mine room.
## Destroys the current room and creates a new deeper one.
## In multiplayer the host decides the shared depth, then mirrors so
## every member of the shared mine descends together (stays co-op).
func _on_mine_descended(new_depth: int) -> void:
	if NetworkManager.is_network_active() and not multiplayer.is_server():
		rpc_id(1, "_server_try_descend", new_depth)
		return
	if _mine_session_active:
		_mine_session_depth = new_depth
		_mine_session_entrance = 0
	_do_mine_descended(new_depth)
	if NetworkManager.is_network_active() and multiplayer.is_server():
		rpc("_receive_mine_descended", new_depth)


## Client-only: mirror the host's descent onto this peer's local mine room.
@rpc("authority", "reliable")
func _receive_mine_descended(new_depth: int) -> void:
	_do_mine_descended(new_depth)


## Host-only: a client wants to descend; update the shared session and mirror.
@rpc("any_peer", "reliable")
func _server_try_descend(new_depth: int) -> void:
	if not multiplayer.is_server():
		return
	if _mine_session_active:
		_mine_session_depth = new_depth
		_mine_session_entrance = 0
	_do_mine_descended(new_depth)
	if NetworkManager.is_network_active() and multiplayer.is_server():
		rpc("_receive_mine_descended", new_depth)


## Internal: actually rebuild a deeper local mine room.
func _do_mine_descended(new_depth: int) -> void:
	if not current_mine_room:
		return
	
	AudioManager.play(AudioManager.Sound.CAVE_AMBIENCE)
	
	# Store the player's relative position in the current room
	var player := get_tree().get_first_node_in_group("player")
	var relative_pos := Vector2.ZERO
	if player:
		if not _is_local_player(player):
			# Prefer the local player so per-peer descent teleports the right copy.
			for p in get_tree().get_nodes_in_group("player"):
				if is_instance_valid(p) and _is_local_player(p):
					player = p
					break
		relative_pos = player.global_position - current_mine_room.global_position
		if player is CharacterBody2D:
			player.velocity = Vector2.ZERO
	
	# Destroy the current room
	current_mine_room.queue_free()
	current_mine_room = null
	
	# Generate new deeper room
	var world_seed_val: int = world_seed if world_seed > 0 else 0
	var mine_generator := MineGenerator.create(world_seed_val + new_depth * 7777, 64, 48)
	var mine := MineRoom.new()
	mine.depth_level = new_depth
	mine.entrance_index = 0  # reset entrance for deeper levels
	mine.generator = mine_generator
	mine.name = "MineRoom"
	current_mine_room = mine
	
	_mine_current_depth = new_depth
	
	# Notify ObjectiveManager about depth reached
	var om_mine := get_tree().get_first_node_in_group("objective_manager")
	if om_mine and om_mine.has_method("on_reach_mine_depth"):
		om_mine.on_reach_mine_depth(new_depth)
	
	# Rebuild effects that only apply to THIS peer's own player actually being
	# inside the mine. The host keeps a session-only room copy when a client is
	# inside while the host stays on the surface; its player must not be moved,
	# and its camera must NOT be clamped to the distant mine void (otherwise the
	# host's camera snaps to the mine on a client's descent, the host "sees" the
	# mine while their own character is off-screen at the surface — appearing
	# 'teleported, frozen and invisible').
	if GameManager.inside_mine:
		if player:
			var spawn_pos := mine_generator.get_spawn_position(0)
			player.global_position = MINE_VOID + spawn_pos
			player.visible = true
			player.set_process(true)
			player.set_physics_process(true)
		# Re-apply camera limits for the new deeper room
		_set_mine_camera_limits(64, 48)
		# Fade transition
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("fade_to_black"):
			hud.fade_to_black(0.3)
	
	# Add new room at void position
	call_deferred("_deferred_setup_mine_room", mine)

	# The old room is freed now, so client copies of it are stale. Drop every
	# ready-ack; clients re-ack once their rebuilt room is ready again.
	if NetworkManager.is_network_active() and multiplayer.is_server():
		_mine_session_room_ready.clear()


# ── Expedition Island System ──
# Travel from main world to a fresh procedurally generated island.
# The island has no buildings, is different every time.

## Travel to a fresh expedition island. Called by TravelBoat after fee is paid.
## Generates a brand new island with a random seed, moves the player there,
## and stores their overworld position so they can return.
# ── First-time dialogue lines per expedition island type ────────────
const EXPEDITION_FIRST_LINES: Dictionary = {
	ExpeditionIsland.IslandType.PLAIN: "A familiar grassy island, but with a whole new set of secrets to uncover. Let's explore!",
	ExpeditionIsland.IslandType.SNOWLAND: "A frozen wilderness... I wonder what can survive in conditions like these.",
	ExpeditionIsland.IslandType.ICE_CREAM_LAND: "The ground is ice cream! I'd better not get too hungry exploring here...",
	ExpeditionIsland.IslandType.DESERT: "The heat is intense! I'll need to watch my step in this scorching desert.",
	ExpeditionIsland.IslandType.VOLCANIC: "Lava rivers and ash clouds... this place is dangerously alive. I shouldn't stay too long.",
	ExpeditionIsland.IslandType.ETHEREAL: "This place hums with strange energy... I feel like I'm walking through another world.",
}

func travel_to_island() -> void:
	if _current_island:
		return  # already on an island
	if _island_exit_cooldown:
		return
	if current_mine_room:
		return  # can't sail from the mines
	if current_interior:
		return  # can't sail from inside a building

	# In multiplayer the host decides the shared island; clients forward
	# their request so everyone ends up on a consistent island.
	if NetworkManager.is_network_active() and not multiplayer.is_server():
		rpc_id(1, "_server_try_enter_island", -1)
		return
	_server_try_enter_island(-1)


## Travel to an expedition island of a specific type. Called by ExpeditionUI
## when the player picks a specific island type (more expensive option).
func travel_to_island_with_type(island_type: int) -> void:
	if _current_island:
		return  # already on an island
	if _island_exit_cooldown:
		return
	if current_mine_room:
		return  # can't sail from the mines
	if current_interior:
		return  # can't sail from inside a building

	# In multiplayer the host decides the shared island; clients forward
	# their request so everyone ends up on a consistent island.
	if NetworkManager.is_network_active() and not multiplayer.is_server():
		rpc_id(1, "_server_try_enter_island", island_type)
		return
	_server_try_enter_island(island_type)


## Host: decide the shared island for the requesting peer and tell only that
## peer to enter it. Players traveling to the SAME island type share one island
## (same seed); players traveling to a DIFFERENT type get a separate island.
## type_hint of -1 means "random" — the host rolls a type and applies the same
## rule (joining an existing island of that type if one is active).
## Each peer renders its own deterministic copy, so the host's own player is
## NOT moved when a client enters. Single-player runs this locally too.
## Returns true if the caller's own player was moved onto the island.
@rpc("any_peer", "reliable")
func _server_try_enter_island(type_hint: int) -> bool:
	if not multiplayer.is_server():
		return false
	var sender: int = _sender_id()

	var target_type: int = type_hint
	if target_type < 0:
		target_type = randi() % ExpeditionIsland.IslandType.size()

	var seed: int
	if _island_sessions.has(target_type):
		# Someone is already on this island type — join the same island.
		seed = _island_sessions[target_type]["seed"]
		_island_sessions[target_type]["members"][sender] = true
	else:
		seed = randi()
		_island_sessions[target_type] = { "seed": seed, "members": { sender: true } }
	_island_peer_type[sender] = target_type

	if sender == _self_id():
		return _do_enter_island(seed, target_type)
	# A client is entering while the host player stays off-island: build the
	# host's deterministic copy so the host's authoritative island animals exist
	# and can drive combat/HP for the client's remote mirrors. Skipped when the
	# host is already on its own island (_current_island already holds animals).
	if _current_island == null:
		_server_build_island(seed, target_type)
	rpc_id(sender, "_receive_enter_island", seed, target_type)
	return true


## Client-side receiver: run the same local island entry so this client's own
## player is transported into its local copy of the shared island.
@rpc("authority", "reliable")
func _receive_enter_island(seed: int, island_type: int) -> void:
	_do_enter_island(seed, island_type)


## Host: build a hidden deterministic copy of an island session so the host's
## authoritative island animals exist even when the host player stays home. A
## client on that island has remote-mirror animals that forward attack/tame/feed
## to the host via World; without this proxy the host has no matching animal to
## receive them (_find_animal_by_id finds nothing), so HP/status silently no-op.
## Mirrors _server_build_mine_room. Placed at INTERIOR_VOID (so position
## broadcasts line up with clients' copies) but the host player is never moved
## into it, so it stays invisible to the host's own view.
func _server_build_island(seed_val: int, island_type: int) -> void:
	if _host_island_proxy and is_instance_valid(_host_island_proxy):
		return
	var proxy: ExpeditionIsland = EXPEDITION_ISLAND_SCENE.instantiate()
	add_child(proxy)
	proxy.position = INTERIOR_VOID
	proxy.generate_with_seed(seed_val, island_type)
	_host_island_proxy = proxy
	_host_island_proxy_seed = seed_val


func _free_host_island_proxy() -> void:
	if _host_island_proxy and is_instance_valid(_host_island_proxy):
		_host_island_proxy.queue_free()
	_host_island_proxy = null
	_host_island_proxy_seed = 0


## Internal: actually create the island (deterministic from seed + type) so
## THIS peer's player enters. Only the local player is moved (remote players
## enter on their own peers). Returns true if the island was created.
func _do_enter_island(seed: int, island_type: int) -> bool:
	# The host player entering an island must not overlap a hidden proxy built
	# for a client's separate session (both would sit at INTERIOR_VOID). Drop the
	# proxy first; the client's remote mirrors then degrade gracefully.
	_free_host_island_proxy()
	if _current_island:
		return false
	if _island_exit_cooldown:
		return false
	if current_mine_room:
		return false
	if current_interior:
		return false

	AudioManager.play(AudioManager.Sound.BOAT_TRAVEL)

	# Despawn non-boss enemies so they don't break
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy and is_instance_valid(enemy) and not enemy.is_in_group("bosses"):
			enemy.queue_free()

	# Generate the island from the shared seed (identical on every peer)
	var island: ExpeditionIsland = EXPEDITION_ISLAND_SCENE.instantiate()
	# Add to tree FIRST so child nodes (animals) get @onready vars initialized
	add_child(island)
	island.position = INTERIOR_VOID
	_current_island = island
	island.generate_with_seed(seed, island_type)

	# A client that just built its island copy wants the objects other members
	# of this island session already removed, so it matches the host's gathered
	# (depleted) state instead of a pristine island. Host skips (it's authority).
	if NetworkManager.is_network_active() and not multiplayer.is_server():
		rpc_id(1, "_server_request_island_removals", seed)

	# Move ONLY the local player (remote copies on this peer stay put — their
	# own peers move them).
	var player: Node = null
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and _is_local_player(p):
			player = p
			break
	if player:
		_island_outside_pos = player.global_position
		if player is CharacterBody2D:
			player.velocity = Vector2.ZERO
		_island_prev_z = player.z_index
		player.z_index = 2
		GameManager.inside_interior = true
		GameManager.inside_island_seed = seed
		GameManager.near_campfire = false
		# Push fresh stats so remote peers know we're on this island (the seed
		# drives whether they render us as a shared visible teammate).
		GameManager._try_broadcast_player_stats()

	# Move player to island center (island is 50x50 tiles)
	if player:
		var spawn_cell := Vector2i(25, 25)
		var spawn_pos := Vector2(spawn_cell.x * TILE_SIZE + TILE_SIZE / 2.0, spawn_cell.y * TILE_SIZE + TILE_SIZE / 2.0)
		player.global_position = INTERIOR_VOID + spawn_pos
		player.visible = true
		player.set_process(true)
		player.set_physics_process(true)

	# Fade transition
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("fade_to_black"):
		hud.fade_to_black(0.3)

	var island_name: String = island.get_island_name() if island.has_method("get_island_name") else "a new island"
	ToastNotification.show_toast("Set sail for " + island_name + "!", ToastNotification.ToastType.SUCCESS, 3.0)
	
	# First-time expedition dialogue — unique line per island type
	var line: String = EXPEDITION_FIRST_LINES.get(island_type, "Whoa... a whole new island to explore! I wonder what treasures await...")
	GameManager.try_show_dialogue(
		GameManager.DIALOGUE_FIRST_EXPEDITION,
		line,
		4.0
	)

	# Track expedition visited objective
	var om := get_tree().get_first_node_in_group("objective_manager")
	if om and om.has_method("on_expedition_visited"):
		om.on_expedition_visited(island_type)

	return true


# ── Island removal backfill for late joiners ─────────────────────────────

## Acting peer records an island-object removal on the World and broadcasts it
## to all peers, so it is tracked even on peers not currently on the island.
## Also removes the object from any local island already built with that seed.
func notify_island_removal(seed: int, obj_id: int) -> void:
	if not NetworkManager.is_network_active():
		return
	if not _island_removed.has(seed):
		_island_removed[seed] = {}
	_island_removed[seed][obj_id] = true
	rpc("_sync_island_removal", seed, obj_id)


## Every peer records the removal and removes the object from its local island
## if that island is built with the same seed (so peers on-island free it too).
## any_peer so the acting client can broadcast its own removal.
@rpc("any_peer", "call_local", "reliable")
func _sync_island_removal(seed: int, obj_id: int) -> void:
	if not _island_removed.has(seed):
		_island_removed[seed] = {}
	_island_removed[seed][obj_id] = true
	if _island_has_seed(seed):
		_current_island._sync_island_object_removed(obj_id)


## Client → host: this peer just built its island copy and wants any objects
## already removed by other members of the same island session.
@rpc("any_peer", "reliable")
func _server_request_island_removals(seed: int) -> void:
	if not multiplayer.is_server():
		return
	var sender: int = _sender_id()
	if sender == 0:
		sender = multiplayer.get_unique_id()
	var ids: Array = []
	for obj_id: Variant in _island_removed.get(seed, {}):
		ids.append(int(obj_id))
	# Also backfill the live animal states from the authority island so a late
	# joiner's fresh deterministic copies match the host's damaged/tamed/kept
	# animals (removals alone only cover static gathered objects, not HP/status).
	var animal_states: Array = []
	var island := _get_authority_island_by_seed(seed)
	if island:
		for a in get_tree().get_nodes_in_group("animals"):
			if is_instance_valid(a) and a is Animal and a.animal_id != 0 \
					and island.is_ancestor_of(a):
				animal_states.append({
					"id": a.animal_id,
					"hp": a.current_health,
					"mhp": a.max_health,
					"tamed": a._tamed,
				})
	# A gathered island session can have many removed objects plus many animals,
	# which overflows a single EOS reliable packet. Stream it in byte-chunks
	# exactly like the world-state snapshot.
	var payload := var_to_bytes({ "seed": seed, "ids": ids, "animal_states": animal_states })
	var total: int = ceili(float(payload.size()) / float(WORLD_SYNC_CHUNK_BYTES))
	for i in range(total):
		var start: int = i * WORLD_SYNC_CHUNK_BYTES
		var end: int = mini(start + WORLD_SYNC_CHUNK_BYTES, payload.size())
		rpc_id(sender, "_receive_island_removals_chunk", i, total, payload.slice(start, end))


## Client: collect one chunk of the host's island-removals payload, then apply
## it once every piece has arrived (mirrors the world-state chunk reassembly).
@rpc("authority", "reliable")
func _receive_island_removals_chunk(chunk_index: int, total_chunks: int, chunk: PackedByteArray) -> void:
	if multiplayer.is_server():
		return
	if chunk_index == 0:
		_pending_island_rem_chunks = []
		_pending_island_rem_chunks_total = total_chunks
	if _pending_island_rem_chunks.size() != chunk_index or total_chunks != _pending_island_rem_chunks_total:
		_pending_island_rem_chunks = []  # out-of-order/interleaved — discard
		return
	_pending_island_rem_chunks.append(chunk)
	if _pending_island_rem_chunks.size() < _pending_island_rem_chunks_total:
		return
	var payload := PackedByteArray()
	for c in _pending_island_rem_chunks:
		payload.append_array(c)
	_pending_island_rem_chunks = []
	var data: Variant = bytes_to_var(payload)
	if not (data is Dictionary):
		return
	var seed: int = int(data.get("seed", 0))
	var ids: Array = data.get("ids", [])
	var animal_states: Array = data.get("animal_states", [])
	_apply_island_removals(seed, ids, animal_states)


## Applies the already-removed objects plus live animal states to this peer so
## it matches the host's gathered/damaged island state (removals recorded
## regardless of island presence are still applied when the seed matches, and
## matching-copy animals adopt the host's HP/tamed status).
func _apply_island_removals(seed: int, ids: Array, animal_states: Array) -> void:
	if not _island_removed.has(seed):
		_island_removed[seed] = {}
	for obj_id: Variant in ids:
		var oid: int = int(obj_id)
		_island_removed[seed][oid] = true
		if _island_has_seed(seed):
			_current_island._sync_island_object_removed(oid)
	# Match backfilled animal states against this peer's freshly-built copies.
	for state: Variant in animal_states:
		var st: Dictionary = state
		var aid: int = int(st.get("id", 0))
		if aid == 0:
			continue
		for a in get_tree().get_nodes_in_group("animals"):
			if is_instance_valid(a) and a is Animal and a.animal_id == aid:
				if st.has("hp"):
					a.current_health = int(st["hp"])
				if st.has("mhp"):
					a.max_health = int(st["mhp"])
				if st.get("tamed", false):
					a.set("_tamed", true)
				if a.has_method("_update_health_bar"):
					a._update_health_bar()
				break


## True if this peer currently has a local island built with the given seed.
func _island_has_seed(seed: int) -> bool:
	if not is_instance_valid(_current_island):
		return false
	return int(_current_island.get("_island_seed")) == seed


## Return the host's authoritative island instance for a given session seed:
## the host player's own _current_island if it matches, else the hidden host
## proxy built for an off-island client session (or null if neither exists).
## Used to backfill live animal state to late-joining clients.
func _get_authority_island_by_seed(seed: int) -> Node:
	if _host_island_proxy and is_instance_valid(_host_island_proxy) \
			and int(_host_island_proxy.get("_island_seed")) == seed:
		return _host_island_proxy
	if _current_island and is_instance_valid(_current_island) \
			and int(_current_island.get("_island_seed")) == seed:
		return _current_island
	return null


## Return from the expedition island back to the main world.
## Called by ReturnBoat when the player interacts with it.
func return_from_island() -> void:
	if not _current_island:
		return
	if _island_exit_cooldown:
		return

	# In multiplayer the host coordinates the shared session; clients request
	# their own exit (only the requesting peer leaves).
	if NetworkManager.is_network_active() and not multiplayer.is_server():
		rpc_id(1, "_server_exit_island")
		return
	_server_exit_island()


## Host: remove the requesting peer from its island session and tell ONLY that
## peer to exit. When called directly (host's own exit), sender defaults to
## the host. Single-player runs this locally too.
@rpc("any_peer", "reliable")
func _server_exit_island() -> void:
	if not multiplayer.is_server():
		return
	var sender: int = _sender_id()

	var isl_type: int = _island_peer_type.get(sender, -1)
	_island_peer_type.erase(sender)
	if isl_type >= 0 and _island_sessions.has(isl_type):
		_island_sessions[isl_type]["members"].erase(sender)
		if _island_sessions[isl_type]["members"].is_empty():
			# No one is on this island type anymore — its seed will rotate on
			# the next entry, so drop its cached removal list to avoid growth.
			var emptied_seed: int = int(_island_sessions[isl_type].get("seed", -1))
			_island_removed.erase(emptied_seed)
			_island_sessions.erase(isl_type)
			# No one is left on the session the host proxy was authoritative for —
			# free it so its animals stop broadcasting and the slot is reusable.
			if _host_island_proxy_seed == emptied_seed:
				_free_host_island_proxy()

	if sender == _self_id():
		_do_exit_island()
	else:
		rpc_id(sender, "_receive_exit_island")


## Client-side receiver: run the same local exit so this client's own player
## leaves its local copy of the island.
@rpc("authority", "reliable")
func _receive_exit_island() -> void:
	_do_exit_island()


## Internal: tear down this peer's local island and restore the player.
func _do_exit_island() -> void:
	_island_exit_cooldown = true
	get_tree().create_timer(0.5).timeout.connect(func(): _island_exit_cooldown = false)

	AudioManager.play(AudioManager.Sound.BOAT_TRAVEL)

	# Destroy the island
	_current_island.queue_free()
	_current_island = null
	GameManager.inside_interior = false
	GameManager.inside_island_seed = 0
	# Tell peers we've left the island so they stop rendering us here.
	GameManager._try_broadcast_player_stats()

	# Move the local player back to the overworld
	var player: Node = null
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and _is_local_player(p):
			player = p
			break
	if player:
		if _island_outside_pos != Vector2.ZERO:
			player.global_position = _island_outside_pos
		if player is CharacterBody2D:
			player.velocity = Vector2.ZERO
		player.z_index = _island_prev_z
		player.visible = true
		player.set_process(true)
		player.set_physics_process(true)

	# Fade transition
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("fade_to_black"):
		hud.fade_to_black(0.3)

	ToastNotification.show_toast("Back at the main island!", ToastNotification.ToastType.SUCCESS, 2.0)


## ── Building Interior Sync ──
## In multiplayer, building interiors are shared sessions keyed by building cell.
## The host manages a session per building cell with a deterministic seed so
## all peers generate identical interior layouts. Multiple peers can be inside
## the same building simultaneously and see each other.

## Host: a peer wants to enter a building. The host checks/creates a session
## for that building cell, assigns a deterministic seed, and tells the requesting
## peer to enter its local copy. Returns true if the caller's own player
## was moved into the interior.
@rpc("any_peer", "reliable")
func _server_try_enter_building(building_type: int, building_cell_x: int, building_cell_y: int) -> bool:
	if not multiplayer.is_server():
		return false
	var sender: int = _sender_id()
	var cell_key: String = "%d,%d" % [building_cell_x, building_cell_y]
	
	# Get or create session for this building cell
	var session: Dictionary
	if _building_sessions.has(cell_key):
		session = _building_sessions[cell_key]
		# Verify the building type matches (should always be true)
		if session["type"] != building_type:
			return false
	else:
		# Create new session with deterministic seed based on world seed + cell
		var seed: int = hash(str(world_seed) + ":building:" + cell_key)
		session = { "seed": seed, "type": building_type, "members": {} }
		_building_sessions[cell_key] = session
	
	# Add sender to session members
	session["members"][sender] = true
	_peer_building[sender] = cell_key
	
	if sender == _self_id():
		# Host's own entry — run the local logic directly
		var interior := BuildingInterior.new()
		interior.setup(building_type, Vector2i(building_cell_x, building_cell_y), session["seed"])
		enter_building(interior)
		return true
	
	# Client requested entry — tell that client to run local entry with the session seed
	rpc_id(sender, "_receive_enter_building", building_type, building_cell_x, building_cell_y, session["seed"])
	return true


## Client-side receiver: run the local building entry so this peer's player
## is transported into its local copy of the interior (deterministic from seed).
@rpc("authority", "reliable")
func _receive_enter_building(building_type: int, building_cell_x: int, building_cell_y: int, interior_seed: int) -> void:
	var interior := BuildingInterior.new()
	interior.setup(building_type, Vector2i(building_cell_x, building_cell_y), interior_seed)
	enter_building(interior)


## Host: a peer wants to exit the building. Remove them from the session.
## If the session becomes empty, clean it up.
## NOTE: town-ruin interiors (restaurant, tavern, blacksmith, ...) enter via
## the local RuinStructure.enter_building path and never register a session, so
## _peer_building may be empty here — the exit must still be completed or the
## peer stays stranded in the freed interior void (the "sky abyss").
@rpc("any_peer", "reliable")
func _server_exit_building() -> void:
	if not multiplayer.is_server():
		return
	var sender: int = _sender_id()
	var cell_key: String = _peer_building.get(sender, "")
	if cell_key != "":
		var session: Dictionary = _building_sessions.get(cell_key, {})
		if session:
			session["members"].erase(sender)
			if session["members"].is_empty():
				_building_sessions.erase(cell_key)
		_peer_building.erase(sender)
	
	if sender == _self_id():
		# Only run the local exit when this peer is actually inside — a stray
		# call while outside must not yank the host to a stale _outside_player_pos.
		if current_interior:
			_on_exit_interior()
	else:
		rpc_id(sender, "_receive_exit_building")


## Client-side receiver: run the local exit so this peer's player returns
## to the overworld.
@rpc("authority", "reliable")
func _receive_exit_building() -> void:
	_on_exit_interior()


## Host → all clients: play the boss defeat cutscene on every peer so the whole
## lobby sees the cinematic, not just the host that landed the kill. Called by
## GameManager.trigger_boss_defeat_cutscene() on the authority after a boss dies.
@rpc("authority", "reliable")
func _receive_boss_defeat_cutscene(boss_index: int) -> void:
	if multiplayer.is_server():
		return  # host already played it in trigger_boss_defeat_cutscene
	BossDefeatCutscene.play(boss_index)


## Host: remove a peer from interior session when they disconnect.
func building_peer_disconnected(peer_id: int) -> void:
	var cell_key: String = _peer_building.get(peer_id, "")
	if cell_key == "":
		return
	var session: Dictionary = _building_sessions.get(cell_key, {})
	if session:
		session["members"].erase(peer_id)
		if session["members"].is_empty():
			_building_sessions.erase(cell_key)
	_peer_building.erase(peer_id)


## Host: remove a peer from its shared-island session when they disconnect.
## An abrupt disconnect skips the normal _server_exit_island RPC, so the dead
## peer would otherwise stay in _island_sessions[type]["members"] and
## _island_peer_type forever — pinning that island type's seed so later
## players join a stale, depleted island instead of a fresh one.
func island_peer_disconnected(peer_id: int) -> void:
	var isl_type: int = _island_peer_type.get(peer_id, -1)
	_island_peer_type.erase(peer_id)
	if isl_type >= 0 and _island_sessions.has(isl_type):
		_island_sessions[isl_type]["members"].erase(peer_id)
		if _island_sessions[isl_type]["members"].is_empty():
			# No one is on this island type anymore — its seed will rotate on
			# the next entry, so drop its cached removal list to avoid growth.
			var emptied_seed: int = int(_island_sessions[isl_type].get("seed", -1))
			_island_removed.erase(emptied_seed)
			_island_sessions.erase(isl_type)
			# Free the host's authoritative proxy for this session if it held one.
			if _host_island_proxy_seed == emptied_seed:
				_free_host_island_proxy()


# ── Ruined town ──

func _spawn_ruined_town() -> void:
	# Remove any existing TownManager from a previous session (exiting
	# to menu only hides the game — the old node persists in the tree).
	var existing := get_node_or_null("TownManager")
	if existing:
		remove_child(existing)
		existing.queue_free()

	# Create a fresh TownManager for this world
	var town_manager := TownManager.new()
	town_manager.name = "TownManager"
	add_child(town_manager)
	
	# Use the validate-and-find approach for ALL seeds so the town
	# never spills off the island. If the region finder fails for seed 0,
	# fall back to the known-good (30, 27) position if it's valid.
	var origin_x: int
	var origin_y: int
	
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + 88888
	var town_region := _find_town_region(rng)
	
	if town_region.is_empty():
		# Fallback: check if the old fixed position is valid
		if _is_town_eligible_cell(Vector2i(30, 27)):
			origin_x = 30
			origin_y = 27
		else:
			push_warning("Could not find suitable town region — skipping ruined town placement.")
			return
	else:
		origin_x = town_region["x"]
		origin_y = town_region["y"]
	
	# Get ruin definitions and assign their grid positions
	var defs: Array = TownManager.get_builtin_ruin_defs()
	var ruin_positions: Dictionary = {}
	
	# Compact village layout: 5-tile horizontal (80px), 6-tile vertical (96px).
	# Buildings nearly touch (4px overlap for 96px ↔ 72px) for a dense town square.
	# Extra buildings go south of the plaza out of the way.
	# All values are in whole tile units (1 = 16px).
	var layout_offsets: Dictionary = {
		# ── Top Row (y=5): Bakery, Tavern, Library ──
		"bakery": Vector2i(-1, 5),
		"tavern": Vector2i(4, 5),
		"library": Vector2i(9, 5),
		# ── Middle Row (y=11): Blacksmith, Well, Workbench ──
		"blacksmith": Vector2i(-1, 11),
		"well": Vector2i(4, 11),
		"workbench": Vector2i(9, 11),
		# ── Bottom Row ──
		"general_store": Vector2i(-1, 16),
		"restaurant": Vector2i(9, 16),
		# ── Edge buildings ──
		"gate": Vector2i(-6, 5),
		"cottage_1": Vector2i(-6, 16),
		"stable": Vector2i(14, 5),
		"stall_1": Vector2i(-6, 11),
		"stall_2": Vector2i(14, 16),
		"shed": Vector2i(14, 11),
	}
	
	for def in defs:
		if not (def is TownManager.RuinDef):
			continue
		var offset: Vector2i = layout_offsets.get(def.id, Vector2i(0, 0))
		var cell: Vector2i = Vector2i(origin_x + offset.x, origin_y + offset.y)
		
		ruin_positions[def.id] = cell
		
		# Spawn ruin structure scene
		_spawn_ruin_at(cell, def)
	
	# Draw path tiles (main street + connections) across the town layout
	_add_town_paths(origin_x, origin_y, layout_offsets)

	# (Town lantern scattering removed — sprites overlapped with buildings after restoration)

	# Initialize the TownManager with ruin positions so it has fresh
	# RuinState entries (all at RUBBLE) for this new world.
	town_manager.initialize(ruin_positions)

	# Mark town region so trees/nature objects don't spawn on the plaza.
	# The plaza sprite (612×408 at 0.7 scale = 428×286 px ≈ 26.8×17.9 tiles)
	# is centered at (origin_x + 4, origin_y + 11), extending from about
	# (origin_x - 10) to (origin_x + 18) in tile x and from about
	# (origin_y + 2) to (origin_y + 20) in tile y.
	# The building layout spans x offset -6..+14 and y offset +5..+16.
	# This rect is padded so the backdrop sprite and all buildings are fully
	# protected from tree/nature overlap. The north/south padding is kept
	# tight (1 tile above the plaza, 0 below) so nature isn't excluded too
	# aggressively above/below the town.
	var town_left := origin_x - 10
	var town_top := origin_y + 1
	var town_right := origin_x + 18
	var town_bottom := origin_y + 20
	set_meta("town_rect", Rect2i(town_left, town_top, town_right - town_left + 1, town_bottom - town_top + 1))
	
	# Connect to restoration signals
	town_manager.building_restored.connect(_on_town_building_restored.bind(town_manager, origin_x, origin_y))
	town_manager.all_ruins_restored.connect(_show_town_lanterns)
	town_manager.rep_threshold_reached.connect(_on_rep_threshold_reached)
	
	# Spawn a town entry detector — use tighter bounds that only cover
	# the building layout itself, not the generously padded tree-exclusion zone.
	# Buildings span x offset -6..+14, y offset +5..+16 in the layout grid.
	var entry_left := origin_x - 3
	var entry_top := origin_y
	var entry_right := origin_x + 15
	var entry_bottom := origin_y + 18
	_spawn_town_entry_detector(entry_left, entry_top, entry_right, entry_bottom)

func _find_town_region(rng: RandomNumberGenerator) -> Dictionary:
	# Scan the west side of the island (x < 40) for a flat area of
	# walkable grassland tiles large enough for the spread-out town (17x21)
	var attempts := 0
	while attempts < 50:
		attempts += 1
		# Bias toward the northwest quadrant of the island
		var cx: int = rng.randi_range(8, 35)
		var cy: int = rng.randi_range(10, 40)
		
		# Check that the 24x30 region is all walkable grassland
		var valid := true
		for dy in range(0, 30):
			for dx in range(0, 24):
				var check_cell := Vector2i(cx + dx, cy + dy)
				if not _is_town_eligible_cell(check_cell):
					valid = false
					break
			if not valid:
				break
		
		if valid:
			# Check distance from mines (avoid stone/snow biomes nearby)
			var too_close_to_mines := false
			for check_y in range(cy - 5, cy + 35):
				for check_x in range(cx - 5, cx + 29):
					var mc := Vector2i(check_x, check_y)
					if _is_in_bounds(mc):
						var tid: String = _tile_grid[mc.y][mc.x]
						if tid == "stone" or tid == "snow" or tid == "cobblestone_path":
							too_close_to_mines = true
							break
				if too_close_to_mines:
					break
			
			if not too_close_to_mines:
				return {"x": cx, "y": cy}
	
	# Fallback: any decent grassland patch on the west side
	for y in range(10, 50):
		for x in range(8, 38):
			if _is_town_eligible_cell(Vector2i(x, y)):
				return {"x": x, "y": y}
	
	return {}

func _is_town_eligible_cell(cell: Vector2i) -> bool:
	if not _is_in_bounds(cell):
		return false
	var tile_id: String = _tile_grid[cell.y][cell.x]
	if tile_id == "water" or tile_id.begins_with("edge") or tile_id.is_empty():
		return false
	if tile_id == "stone" or tile_id == "snow" or tile_id == "cobblestone_path":
		return false
	var tile_type: TileTypeData = DataManager.get_tile_type(tile_id)
	if not tile_type or not tile_type.walkable:
		return false
	# Avoid dock area — roughly bottom 10 rows
	if cell.y > world_height - 10:
		return false
	return true

func _on_town_building_restored(_ruin_id: String, _building_name: String, town_manager: TownManager, origin_x: int, origin_y: int) -> void:
	# When a building is restored, check if ALL are now done
	if _are_all_town_buildings_restored(town_manager):
		_swap_plaza_to_restored()
		_add_town_fence_border(origin_x, origin_y)

func _are_all_town_buildings_restored(town_manager: TownManager) -> bool:
	for rid: String in town_manager.ruins:
		var state: TownManager.RuinState = town_manager.ruins[rid]
		if state.status < TownManager.RuinStatus.RESTORED:
			return false
	return true

func _swap_plaza_to_restored() -> void:
	# All buildings restored — swap the plaza ground to the clean version.
	# Use the meta stored in _add_town_paths rather than searching by node name,
	# which is more reliable (the meta is set alongside the sprite creation).
	if not has_meta("town_plaza_sprite"):
		push_error("town_plaza_sprite meta not found — town paths may not have been generated yet!")
		return
	var plaza := get_meta("town_plaza_sprite") as Sprite2D
	if not plaza:
		push_error("town_plaza_sprite meta is not a valid Sprite2D!")
		return
	plaza.texture = preload("res://assets/generated/restored.png")
	# restored.png is 1536x1024 while unrestored.png is 612x408 at scale 0.7
	# Compute scale so restored covers the same world area (428x286)
	plaza.scale = Vector2(428.4 / 1536.0, 285.6 / 1024.0)


func _add_town_fence_border(origin_x: int, origin_y: int) -> void:
	## When all town buildings are restored, add a decorative stone fence
	## perimeter around the town to mark the completed restoration.
	## Uses the building system's stone fence with auto-connections.

	# Building footprint relative to origin: x=-6..14, y=5..16
	# Fence goes 3 tiles outside: x=-9..17, y=2..19
	# Gate entrance gap on left wall, entrance gap at bottom-center.
	const FENCE: int = BuildingSystem.BuildingType.STONE_FENCE

	var fence_cells: Array[Vector2i] = []

	# Top horizontal wall: y = origin_y + 2
	for x in range(origin_x - 9, origin_x + 18):
		fence_cells.append(Vector2i(x, origin_y + 2))

	# Bottom horizontal wall: y = origin_y + 19
	# Leave a 3-tile gap in the middle for the player to walk through.
	var bottom_y := origin_y + 19
	for x in range(origin_x - 9, origin_x + 18):
		# Skip the middle 3 tiles to create a bottom entrance
		if x >= origin_x + 3 and x <= origin_x + 5:
			continue
		fence_cells.append(Vector2i(x, bottom_y))

	# Left wall: x = origin_x - 9  (with a 3-tile gap for the gate entrance)
	for y in range(origin_y + 5, origin_y + 20):  # starts below the gate area
		fence_cells.append(Vector2i(origin_x - 9, y))
	# The gate entrance gap (y=origin_y+2..origin_y+4) is left open
	# so the player can walk in from the gate at (-6, 5).

	# Right wall: x = origin_x + 17
	for y in range(origin_y + 2, origin_y + 20):
		fence_cells.append(Vector2i(origin_x + 17, y))

	# Place all fences via the synced RPC so every peer (not just the one that
	# triggered the restore) sees the boundary. call_local applies it on the
	# host too; _sync_place_building triggers no objective hook (decorative),
	# and the same skip guard runs on the server before each is sent.
	for cell in fence_cells:
		if not _is_in_bounds(cell):
			continue
		# Skip cells that already have a building (ruins or other)
		var existing := building_system.get_building_at(cell)
		if not existing.is_empty():
			continue
		rpc("_sync_place_building", FENCE, cell)

	# Show a toast to let the player know
	ToastNotification.show_toast("🏰 Town fully restored! Stone fence perimeter added.", ToastNotification.ToastType.SUCCESS, 4.0)


func _add_town_paths(origin_x: int, origin_y: int, _layout_offsets: Dictionary) -> void:
	# Cobblestone plaza centered on the middle of the grid.
	var cx := (origin_x + 4) * 16 + 8
	var cy := (origin_y + 11) * 16 + 8
	var plaza_sprite := Sprite2D.new()
	plaza_sprite.name = "TownPlaza"
	plaza_sprite.texture = preload("res://assets/generated/unrestored.png")
	plaza_sprite.centered = true
	plaza_sprite.position = Vector2(cx, cy)
	plaza_sprite.scale = Vector2(0.7, 0.7)
	plaza_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	plaza_sprite.z_index = 0
	objects_root.add_child(plaza_sprite)
	
	# Store refs for restoration swap.
	set_meta("town_plaza_sprite", plaza_sprite)
	set_meta("town_plaza_px", cx)
	set_meta("town_plaza_py", cy)
	set_meta("town_origin_x", origin_x)
	set_meta("town_origin_y", origin_y)
	set_meta("town_well_cx", cx)
	set_meta("town_well_cy", cy)


func _scatter_town_lanterns(_origin_x: int, _origin_y: int, _rng: RandomNumberGenerator) -> void:
	## NOTE: Disabled — individual lantern sprites overlapped with building
	## sprites after restoration. Only the ambient glow remains for night lighting.
	pass


func _update_town_lanterns(_phase: int = -1) -> void:
	## Toggle the ambient town glow based on the current day/night phase.
	## Glow turns on during dusk and night, off during dawn and day.
	var phase: int = GameManager.get_season_phase()
	var lights_on: bool = phase in [DayNightCycle.Phase.DUSK, DayNightCycle.Phase.NIGHT]
	var glow := objects_root.get_node_or_null("TownAmbientGlow") as PointLight2D
	if glow:
		glow.visible = lights_on


func _on_rep_threshold_reached(threshold_name: String, threshold_value: int) -> void:
	## Called when a reputation threshold is crossed for the first time.
	var toast_messages := {
		"settlement": "🏘️ Settlement — Bank interest doubled!",
		"village": "🏡 Village — Boat sell prices +10%!",
		"town": "🏙️ Town — Boat sell prices +15%!",
		"thriving": "⭐ Thriving — Boat sell prices +20%!",
	}
	var msg: String = toast_messages.get(threshold_name, "Reputation threshold reached!")
	ToastNotification.show_toast(msg, ToastNotification.ToastType.SUCCESS, 4.0)

	# Apply gameplay bonuses
	match threshold_name:
		"settlement":
			GameManager.rep_bank_interest_doubled = true
		"village":
			GameManager.rep_sell_price_mult = 1.10
		"town":
			GameManager.rep_sell_price_mult = 1.15
		"thriving":
			GameManager.rep_sell_price_mult = 1.20

func _show_town_lanterns() -> void:
	## Called when all town ruins are fully restored (all_ruins_restored signal).
	## Adds a large ambient glow that covers the entire restored town at night
	## and connects to the day/night cycle so it toggles on at dusk/night.
	
	# Connect to day/night cycle so the ambient glow turns on at night
	if GameManager.phase_changed.is_connected(_update_town_lanterns):
		GameManager.phase_changed.disconnect(_update_town_lanterns)
	GameManager.phase_changed.connect(_update_town_lanterns)
	
	# Add a large ambient glow that covers the entire restored town at night.
	# Positioned at the town plaza center (stored as meta during path creation).
	var glow_name := "TownAmbientGlow"
	if not objects_root.has_node(glow_name):
		var glow := PointLight2D.new()
		glow.name = glow_name
		glow.energy = 0.55
		glow.texture_scale = 3.0
		glow.color = Color(1.0, 0.88, 0.6, 0.35)
		glow.range_item_cull_mask = 1
		glow.shadow_enabled = false
		glow.texture = LightUtils.make_light_texture(256)
		# Center on the town plaza
		var px: int = get_meta("town_plaza_px", 0)
		var py: int = get_meta("town_plaza_py", 0)
		glow.global_position = Vector2(px, py)
		glow.z_index = -1  # below everything to act as ambient backlight
		# Start dark; phase_changed toggles it on at night
		glow.visible = false
		objects_root.add_child(glow)

	_update_town_lanterns()


func _ensure_cobblestone_source() -> int:
	## Add a cobblestone path texture to the ground tileset as a new atlas source.
	## Returns the source_id to use for path tiles. Only adds once.
	const SOURCE_ID := 99
	var tileset := ground_layer.tile_set as TileSet
	if not tileset:
		return 0
	if tileset.has_source(SOURCE_ID):
		return SOURCE_ID
	var atlas := TileSetAtlasSource.new()
	atlas.texture = load("res://assets/generated/cobblestone_path_v2.png")
	atlas.texture_region_size = Vector2i(16, 16)
	atlas.create_tile(Vector2i(0, 0))
	var ret := tileset.add_source(atlas, SOURCE_ID)
	if ret >= 0:
		return ret
	return 0

func _spawn_ruin_at(cell: Vector2i, def: TownManager.RuinDef) -> void:
	# Create the ruin structure scene
	var ruin := preload("res://scenes/world/town/RuinStructure.tscn").instantiate() as RuinStructure
	if not ruin:
		push_error("Failed to instantiate RuinStructure!")
		return
	
	var world_pos := cell_to_world(cell)
	ruin.global_position = world_pos
	ruin.name = "Ruin_%s" % String(def.id)
	ruin.initialize(def.id, def)
	
	# RuinStructure handles its own visuals — shows a unique ruin sprite
	# for rubble state, foundation when cleared, and the restored building
	# sprite when fully rebuilt — all on top of the worn plaza ground.
	objects_root.add_child(ruin)

# ── Array helpers ──

## Fisher-Yates shuffle using a seeded RNG so the result is deterministic.
func _shuffle_array_with_rng(array: Array, rng: RandomNumberGenerator) -> void:
	for i in range(array.size() - 1, 0, -1):
		var j: int = rng.randi() % (i + 1)
		var temp = array[i]
		array[i] = array[j]
		array[j] = temp

# ── Map marker getters ──

func get_shop_position() -> Vector2:
	return _shop_position

## Returns true if a world position falls inside the dock shop's solid blocker
## (96x48 rect centered on the shop). Visitor NPCs spawn and wander on the dock,
## and the shop blocker sits in the middle of the dock walkway, so without this
## check NPCs would spawn inside/beside the blocker and get permanently stuck
## (simple wall-slide movement can't free them).
func is_position_in_shop_blocker(world_pos: Vector2) -> bool:
	if _shop_position == Vector2.ZERO:
		return false
	var d := world_pos - _shop_position
	return absf(d.x) <= 48.0 and absf(d.y) <= 24.0

func get_boat_position() -> Vector2:
	return _boat_position

func get_dock_position() -> Vector2:
	return _dock_position


## The cell every player should spawn at on the overworld: 35 cells from the
## right edge (6 inland from the coastline), centered vertically. Single
## source of truth so host, clients, remote copies, and respawns agree.
func get_default_spawn_cell() -> Vector2i:
	return Vector2i(world_width - 35, world_height / 2)


func get_default_spawn_position() -> Vector2:
	return cell_to_world(get_default_spawn_cell())

## Returns an array of world positions for all mine entrances.
## Returns the current MineRoom node if the player is in a mine, or null.
func get_current_mine_room():
	return current_mine_room


func get_mine_entrance_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for entrance in mine_entrances:
		positions.append(entrance.global_position)
	return positions


## Returns an array of world positions along the island's coastline where
## enemies (pirates) can spawn. Scans the _tile_grid for land cells that
## border water, filters to beach-accessible tiles, and returns up to
## `max_positions` random choices. Each position is the center of a cell.
## Skips cells within 10 tiles of the dock to avoid stacking on dock-area spawns.
func get_coastline_spawn_positions(max_positions: int = 6, rng: RandomNumberGenerator = null) -> Array[Vector2]:
	if _tile_grid.is_empty():
		return []
	if rng == null:
		rng = RandomNumberGenerator.new()
	
	# Collect all coastline cells: land tiles with at least one water neighbor
	var coastline: Array[Vector2i] = []
	for y in range(1, world_height - 1):
		for x in range(1, world_width - 1):
			var tid: String = _tile_grid[y][x]
			if tid == "water" or tid.begins_with("edge") or tid.is_empty() or tid == "path":
				continue
			# Skip cells near the dock — those are handled by the dock-area spawn
			if _dock_cell != Vector2i(-1, -1):
				var dock_local := Vector2i(x, y) - _dock_cell
				if abs(dock_local.x) < 10 and dock_local.y >= -3 and dock_local.y <= 15:
					continue
			# Check four neighbors for water
			var neighbors := [
				Vector2i(x - 1, y),
				Vector2i(x + 1, y),
				Vector2i(x, y - 1),
				Vector2i(x, y + 1),
			]
			for nb in neighbors:
				if _is_in_bounds(nb):
					var nt: String = _tile_grid[nb.y][nb.x]
					if nt == "water" or nt.begins_with("edge"):
						coastline.append(Vector2i(x, y))
						break
	
	if coastline.is_empty():
		return []
	
	# Shuffle and pick up to max_positions
	rng.shuffle(coastline)
	var count := mini(max_positions, coastline.size())
	var result: Array[Vector2] = []
	for i in range(count):
		result.append(cell_to_world(coastline[i]))
	return result

## Spawn an invisible Area2D covering the town area. When the player first
## enters it (on foot from the main world), show the first-time town dialogue.
func _spawn_town_entry_detector(left: int, top: int, right: int, bottom: int) -> void:
	# Remove any existing detector
	var existing := get_node_or_null("TownEntryDetector")
	if existing:
		existing.queue_free()
	
	var area := Area2D.new()
	area.name = "TownEntryDetector"
	area.collision_layer = 0
	area.collision_mask = 2  # detect player (player is on layer 2)
	
	var shape := RectangleShape2D.new()
	var tile_size_px: float = TILE_SIZE
	var pixel_w: float = (right - left + 1) * tile_size_px
	var pixel_h: float = (bottom - top + 1) * tile_size_px
	shape.size = Vector2(pixel_w, pixel_h)
	
	var col_shape := CollisionShape2D.new()
	col_shape.shape = shape
	area.add_child(col_shape)
	
	var center_x: float = (left + right) / 2.0 * tile_size_px + tile_size_px / 2.0
	var center_y: float = (top + bottom) / 2.0 * tile_size_px + tile_size_px / 2.0
	area.position = Vector2(center_x, center_y)
	
	# One-shot detection: show dialogue then remove self
	area.body_entered.connect(func(body: Node):
		if not body.is_in_group("player"):
			return
		if GameManager.inside_interior:
			return
		var shown := GameManager.try_show_dialogue(
			GameManager.DIALOGUE_FIRST_TOWN,
			"What happened here...? This town is in ruins. I should restore it!",
			4.5
		)
		if shown:
			area.queue_free()
	)
	
	add_child(area)


## Returns the dock node (Dock) if one was placed, or null.
## External code can use Dock.BERTH_POSITIONS relative to dock position.
func get_dock() -> Dock:
	if not is_inside_tree():
		return null
	for child in objects_root.get_children():
		if child is Dock:
			return child
	return null

func get_biome_generator():
	return biome_generator

func get_enemy_spawner():
	return enemy_spawner


# ── Multiplayer ────────────────────────────────────────────────────────

## Called by an interactable object before it removes itself (e.g. tree
## chopped, rock mined). Broadcasts the cell to all clients so they can
## remove the matching node on their end. The acting peer (host OR client)
## broadcasts — each peer mutates its own copy of the world.
func notify_cell_object_removed(world_pos: Vector2) -> void:
	if not NetworkManager.is_network_active():
		return
	var cell := world_to_cell(world_pos)
	_removed_cell_objects[cell] = true
	rpc("_sync_remove_cell_object", cell)


## Received by all peers to remove a world object at the given cell.
@rpc("any_peer", "call_local")
func _sync_remove_cell_object(cell: Vector2i) -> void:
	_removed_cell_objects[cell] = true
	_remove_object_at_cell(cell)


## Only harvestable/mineable nature objects may be removed through the live
## removal RPC and the late-joiner snapshot. Buildings, animals, crops and
## other persistent content are excluded so a malicious peer can't delete
## arbitrary world state via _sync_remove_cell_object.
func _is_removable_world_object(node: Node) -> bool:
	return node is ResourceNode or node is TreeObject or node is FruitTree \
		or node is OreDeposit or node is Bush or node is FlowerPatch \
		or node is LogStump or node is MushroomPatch

## Removes any harvestable/mineable nature-object node sitting at the given
## cell (trees, rocks/flower stumps, flowers, bushes, mushroom patches, ore).
## Used by both the live removal RPC and the late-joiner world-state snapshot.
func _remove_object_at_cell(cell: Vector2i) -> void:
	for child in objects_root.get_children():
		if child is Node2D and is_instance_valid(child):
			var child_cell := world_to_cell(child.global_position)
			if child_cell == cell and _is_removable_world_object(child):
				child.queue_free()
				return


## Called by a Bush node after successful harvest. Broadcasts the cell
## to all clients so they can mark the matching bush as harvested.
func notify_bush_harvested(world_pos: Vector2) -> void:
	if not NetworkManager.is_network_active():
		return
	var cell := world_to_cell(world_pos)
	rpc("_sync_bush_harvested", cell)


## Received by all peers to mark a bush as harvested at the given cell.
@rpc("any_peer", "call_local")
func _sync_bush_harvested(cell: Vector2i) -> void:
	for child in objects_root.get_children():
		if child is Bush and is_instance_valid(child):
			var child_cell := world_to_cell(child.global_position)
			if child_cell == cell:
				child.set_harvested()
				return


## Sync helpers — called by host after successful farming actions.
func _sync_harvest_if_active(cell: Vector2i, action: int) -> void:
	if NetworkManager.is_network_active():
		rpc("_sync_harvest_cell", cell, action)


@rpc("any_peer", "call_local")
func _sync_till_cell(cell: Vector2i) -> void:
	_till_cell(cell, true)


@rpc("any_peer", "call_local")
func _sync_water_cell(cell: Vector2i) -> void:
	_water_cell(cell)


@rpc("any_peer", "call_local")
func _sync_plant_cell(cell: Vector2i, crop_id: String, genetics_dict: Dictionary = {}) -> void:
	if _soil_data.has(cell) and _soil_data[cell].is_tilled and _soil_data[cell].crop_id == "":
		_plant_seed_cell(cell, crop_id, true)
		# Match the planting peer's genetics exactly (not an unseeded re-roll).
		if not genetics_dict.is_empty() and _crop_nodes.has(cell) and _crop_nodes[cell].genetics:
			_crop_nodes[cell].genetics = CropGenetics.deserialize(genetics_dict)


## action: 0 = removed, 1 = regrow, 2 = sprout
@rpc("any_peer", "call_local")
func _sync_harvest_cell(cell: Vector2i, action: int) -> void:
	if not _crop_nodes.has(cell):
		return
	var crop: Crop = _crop_nodes[cell]
	match action:
		0:
			crop.queue_free()
			_crop_nodes.erase(cell)
			if _soil_data.has(cell):
				_soil_data[cell].crop_id = ""
		1:
			crop.harvest()
			var crop_data: CropData = DataManager.get_crop(crop.crop_id)
			if crop_data:
				_soil_data[cell].days_grown = crop_data.regrow_days
		2:
			crop.reset_to_sprout()
			_soil_data[cell].days_grown = 0


## Registers a special building type in its tracking array.
func _register_special_building(b_type: int, cell: Vector2i) -> void:
	if b_type == BuildingSystem.BuildingType.GREENHOUSE:
		var gh_data: Dictionary = BuildingSystem.BUILDING_DATA.get(BuildingSystem.BuildingType.GREENHOUSE, {})
		var gh_w: int = gh_data.get("width", 6)
		var gh_h: int = gh_data.get("height", 4)
		for dx in range(gh_w):
			for dy in range(gh_h):
				var gh_cell := cell + Vector2i(dx, dy)
				if not gh_cell in _greenhouse_cells:
					_greenhouse_cells.append(gh_cell)
	elif b_type == BuildingSystem.BuildingType.SCARECROW:
		if not cell in _scarecrow_cells:
			_scarecrow_cells.append(cell)
	elif b_type == BuildingSystem.BuildingType.COMPOST_BIN:
		if not cell in _compost_bin_cells:
			_compost_bin_cells.append(cell)


## Unregisters a special building type from its tracking array.
func _unregister_special_building(b_type: int, cell: Vector2i) -> void:
	if b_type == BuildingSystem.BuildingType.GREENHOUSE:
		var gh_data: Dictionary = BuildingSystem.BUILDING_DATA.get(BuildingSystem.BuildingType.GREENHOUSE, {})
		var gh_w: int = gh_data.get("width", 6)
		var gh_h: int = gh_data.get("height", 4)
		for dx in range(gh_w):
			for dy in range(gh_h):
				var gh_cell := cell + Vector2i(dx, dy)
				var idx: int = _greenhouse_cells.find(gh_cell)
				if idx >= 0:
					_greenhouse_cells.remove_at(idx)
	elif b_type == BuildingSystem.BuildingType.SCARECROW:
		var idx: int = _scarecrow_cells.find(cell)
		if idx >= 0:
			_scarecrow_cells.remove_at(idx)
	elif b_type == BuildingSystem.BuildingType.COMPOST_BIN:
		var idx: int = _compost_bin_cells.find(cell)
		if idx >= 0:
			_compost_bin_cells.remove_at(idx)


## Received by clients to place a building at the given cell.
@rpc("any_peer", "call_local")
func _sync_place_building(b_type: int, cell: Vector2i) -> void:
	# Idempotency guard: the actor's try_place_building() already places
	# locally (and fires the objective), and this RPC is call_local — so the
	# sender would otherwise double-place. Remote peers have nothing at this
	# cell yet and place normally. Same-type check keeps a legit replacement
	# (different building type at the same origin) from being skipped.
	var existing := building_system.get_building_at(cell)
	if not existing.is_empty() and int(existing.get("type", -1)) == b_type:
		return
	building_system.place_building(b_type, cell, 0, self, false)
	_register_special_building(b_type, cell)


## Received by clients to remove a building at the given cell.
@rpc("any_peer", "call_local")
func _sync_remove_building(cell: Vector2i, b_type: int) -> void:
	building_system.remove_building(cell, self)
	_unregister_special_building(b_type, cell)


# ── Late-joiner world-state sync ──────────────────────────────────────────

## Called by a client right after it regenerates its world, asking the host to
## send a snapshot of the world's mutable state: removed resources, harvested
## bushes, placed buildings, sprinklers and chest inventories. Without this a
## late joiner sees a pristine world that diverges from the host's.

## EOS P2P reliable packets cap at ~1170 bytes total, and a fully-built
## world-state snapshot (removed cells + buildings + soil + crops + animals +
## chests) can far exceed that, so it must be streamed in byte-chunks (same
## pattern as TownManager._broadcast_state). Reliable RPCs preserve order, so
## the client reassembles the snapshot in arrival order.
const WORLD_SYNC_CHUNK_BYTES: int = 800
var _pending_world_chunks: Array = []
var _pending_world_chunks_total: int = 0

# Day-rollover farm delta reassembly (mirrors the world-state chunking above).
var _pending_farm_delta_chunks: Array = []
var _pending_farm_delta_chunks_total: int = 0

# Island-removals reassembly (same chunked pattern — a well-gathered island
# session can carry many removed object ids plus animal states that overflow a
# single EOS reliable packet).
var _pending_island_rem_chunks: Array = []
var _pending_island_rem_chunks_total: int = 0

# Mine-deposit/enemy-HP snapshot reassembly (a large mine floor's deposit +
# enemy roster can overflow a single EOS reliable packet).
var _pending_mine_state_chunks: Array = []
var _pending_mine_state_chunks_total: int = 0

@rpc("any_peer", "reliable")
func _server_request_world_state() -> void:
	if not multiplayer.is_server():
		return
	var removed: Array = []
	for cell in _removed_cell_objects.keys():
		removed.append([cell.x, cell.y])
	var harvested_bushes: Array = []
	for child in objects_root.get_children():
		if child is Bush and is_instance_valid(child) and child.get("_harvested"):
			var bc := world_to_cell(child.global_position)
			harvested_bushes.append([bc.x, bc.y])
	var build_snapshot: Array = []
	if building_system:
		for b in building_system.placed_buildings:
			var b_cell: Vector2i = b.get("cell", Vector2i.ZERO)
			build_snapshot.append({"t": b.get("type", 0), "x": b_cell.x, "y": b_cell.y, "r": b.get("rotation", 0)})
	var sprinkler_snapshot: Array = []
	for cell in _sprinklers.keys():
		var s_data: Dictionary = _sprinklers[cell]
		sprinkler_snapshot.append({"x": cell.x, "y": cell.y, "t": s_data.get("tier", 0), "d": s_data.get("placed_day", 0)})
	# Full farm snapshot: every tilled/watered/planted soil cell (via
	# SoilData.serialize) so a late joiner sees the real farm, not a pristine
	# plot. Only tilled cells are sent (crops only grow there).
	var soil_snapshot: Array = []
	for cell in _soil_data:
		var sd: SoilData = _soil_data[cell]
		if sd is SoilData and sd.is_tilled:
			soil_snapshot.append([cell.x, cell.y, sd.serialize()])
	# Recreate the live Crop nodes (visuals + genetics) for planted cells so
	# a late joiner can see and harvest crops that were already growing.
	var crop_snapshot: Array = []
	for cell in _crop_nodes:
		var crop: Crop = _crop_nodes[cell]
		if is_instance_valid(crop) and crop.crop_id != "":
			crop_snapshot.append({
				"x": cell.x, "y": cell.y, "id": crop.crop_id,
				"days": crop.days_grown,
				"g": crop.genetics.serialize() if crop.genetics else {},
			})
	# Live farm-animal roster already on the shared world (chickens, cows,
	# respawned animals, etc.) so a late joiner matches the host's population.
	var animal_snapshot: Array = []
	for a in get_tree().get_nodes_in_group("animals"):
		if is_instance_valid(a) and a is Animal:
			animal_snapshot.append(a.get_network_data())
	var sender: int = multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = multiplayer.get_unique_id()
	# Building-integrated storage (Silo/Windmill/Shed) lives in
	# GameManager.chest_inventories (keyed by cell), so it rides along in the
	# chest snapshot. Send chest_versions too so the joiner's P1 write-version
	# table matches the host from the start (no stale-write edge on first open).
	var snapshot: Dictionary = {
		"removed": removed,
		"bushes": harvested_bushes,
		"buildings": build_snapshot,
		"sprinklers": sprinkler_snapshot,
		"chests": GameManager.chest_inventories.duplicate(true),
		"soil": soil_snapshot,
		"crops": crop_snapshot,
		"animals": animal_snapshot,
		"chest_versions": GameManager.chest_versions.duplicate(true),
	}
	_send_world_state_chunks(sender, snapshot)


## Host: stream a serialized world-state snapshot to one peer, split into
## sub-1170-byte chunks (mirrors TownManager._send_state_chunks).
func _send_world_state_chunks(sender: int, data: Dictionary) -> void:
	var payload := var_to_bytes(data)
	var total: int = ceili(float(payload.size()) / float(WORLD_SYNC_CHUNK_BYTES))
	for i in range(total):
		var start: int = i * WORLD_SYNC_CHUNK_BYTES
		var end: int = mini(start + WORLD_SYNC_CHUNK_BYTES, payload.size())
		rpc_id(sender, "_receive_world_state_snapshot_chunk", i, total, payload.slice(start, end))


## Client: collect one chunk of the host's world-state snapshot, then apply the
## whole snapshot once all pieces have arrived.
@rpc("authority", "reliable")
func _receive_world_state_snapshot_chunk(chunk_index: int, total_chunks: int, chunk: PackedByteArray) -> void:
	if multiplayer.is_server():
		return
	if chunk_index == 0:
		_pending_world_chunks = []
		_pending_world_chunks_total = total_chunks
	if _pending_world_chunks.size() != chunk_index or total_chunks != _pending_world_chunks_total:
		_pending_world_chunks = []  # out-of-order/interleaved transfer — discard
		return
	_pending_world_chunks.append(chunk)
	if _pending_world_chunks.size() < _pending_world_chunks_total:
		return
	var payload := PackedByteArray()
	for c in _pending_world_chunks:
		payload.append_array(c)
	_pending_world_chunks = []
	var data: Variant = bytes_to_var(payload)
	if data is Dictionary:
		_apply_world_state_snapshot(data)


## Applies the host's world-state snapshot on a late-joining client.
## soil/crops/animals carry the full farm so the joiner matches the host's
## shared world rather than a pristine copy.
func _apply_world_state_snapshot(data: Dictionary) -> void:
	var removed: Array = data.get("removed", [])
	var harvested_bushes: Array = data.get("bushes", [])
	var buildings: Array = data.get("buildings", [])
	var sprinklers: Array = data.get("sprinklers", [])
	var chests: Dictionary = data.get("chests", {})
	var soil: Array = data.get("soil", [])
	var crops: Array = data.get("crops", [])
	var animals: Array = data.get("animals", [])
	var chest_versions: Dictionary = data.get("chest_versions", {})
	for entry in removed:
		_remove_object_at_cell(Vector2i(int(entry[0]), int(entry[1])))
	for entry in harvested_bushes:
		var cell := Vector2i(int(entry[0]), int(entry[1]))
		for child in objects_root.get_children():
			if child is Bush and is_instance_valid(child):
				if world_to_cell(child.global_position) == cell:
					child.set_harvested()
					break
	for entry in buildings:
		_sync_place_building(int(entry.get("t", 0)), Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0))))
	for entry in sprinklers:
		var cell := Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0)))
		if _is_in_bounds(cell) and not _sprinklers.has(cell):
			_sprinklers[cell] = {"active": true, "placed_day": int(entry.get("d", GameManager.current_day)), "tier": int(entry.get("t", 0))}
	if not chests.is_empty():
		GameManager.chest_inventories.clear()
		for key in chests.keys():
			GameManager.chest_inventories[key] = chests.get(key)
	if not chest_versions.is_empty():
		GameManager.chest_versions.clear()
		for key in chest_versions.keys():
			GameManager.chest_versions[key] = chest_versions.get(key)

	# Recreate the farm's soil state (tilting, watering, planted crop ids).
	for entry in soil:
		var cell := Vector2i(int(entry[0]), int(entry[1]))
		if _is_in_bounds(cell):
			_soil_data[cell] = SoilData.deserialize(entry[2])

	# Recreate the live Crop nodes (visuals + genetics) for planted cells so
	# this joiner can see and harvest crops already growing on the host.
	for entry in crops:
		var crop_cell := Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0)))
		if not _soil_data.has(crop_cell) or _crop_nodes.has(crop_cell):
			continue
		var crop: Crop = CROP_SCENE.instantiate()
		objects_root.add_child(crop)
		crop.global_position = cell_to_world(crop_cell)
		var g: Variant = entry.get("g", {})
		if g is Dictionary and not (g as Dictionary).is_empty():
			crop.setup(str(entry.get("id", "")), int(entry.get("days", 0)), CropGenetics.deserialize(g))
		else:
			crop.setup(str(entry.get("id", "")), int(entry.get("days", 0)))
		crop.mutated.connect(_on_crop_mutated.bind(crop_cell))
		_crop_nodes[crop_cell] = crop

	# This client may have spawned its own starter animals during world gen
	# before this snapshot arrived. The host is authoritative for the shared
	# farm population, so drop any local ones, then recreate the host's roster.
	if not animals.is_empty():
		for existing in get_tree().get_nodes_in_group("animals"):
			if is_instance_valid(existing):
				existing.queue_free()
		for entry in animals:
			if not (entry is Dictionary):
				continue
			var animal_data: Dictionary = entry
			var animal: Animal = ANIMAL_SCENE.instantiate()
			var node_name: String = str(animal_data.get("node_name", ""))
			if node_name != "":
				animal.name = node_name
			objects_root.add_child(animal)
			animal.setup_from_network(animal_data)


# ── Daily farm delta sync (host-authoritative growth) ───────────────────
#
# During day rollover the HOST recomputes the whole farm once (in
# _on_day_changed) using THE host's RNG + pet/buff bonuses, then serializes
# the resulting soil + crop state and broadcasts it. Clients apply this delta
# verbatim instead of recomputing growth/mutation/disease, so every peer's
# farm stays identical (no divergence from per-peer RNG / bonuses).

## Host: serialize the full farm (soil + live crops) into a compact delta.
func _build_farm_delta() -> Dictionary:
	var soil_delta: Array = []
	for cell in _soil_data:
		var sd: SoilData = _soil_data[cell] as SoilData
		if sd:
			soil_delta.append([cell.x, cell.y, sd.serialize()])
	var crop_delta: Array = []
	for cell in _crop_nodes:
		var crop: Crop = _crop_nodes[cell] as Crop
		if crop and is_instance_valid(crop):
			crop_delta.append({
				"x": cell.x, "y": cell.y,
				"id": crop.crop_id, "days": crop.days_grown,
				"g": crop.genetics.serialize() if crop.genetics else {},
			})
	return {"soil": soil_delta, "crops": crop_delta}


## Host: broadcast today's farm delta to all clients after day rollover.
## The serialized farm can exceed a single EOS packet (a large farm overflowing
## the 1170-byte reliable limit throws ERR_UNAVAILABLE), so it is split into
## sub-800-byte chunks exactly like the world-state snapshot.
func _broadcast_farm_delta() -> void:
	if not NetworkManager.is_network_active() or not multiplayer.is_server():
		return
	var delta := _build_farm_delta()
	var payload := var_to_bytes(delta)
	var total: int = ceili(float(payload.size()) / float(WORLD_SYNC_CHUNK_BYTES))
	for i in range(total):
		var start: int = i * WORLD_SYNC_CHUNK_BYTES
		var end: int = mini(start + WORLD_SYNC_CHUNK_BYTES, payload.size())
		rpc("_receive_farm_delta_chunk", i, total, payload.slice(start, end))


## Client: collect one farm-delta chunk, then apply the whole delta once all
## pieces have arrived. Reliable RPCs preserve order, so reassembly is safe.
@rpc("authority", "reliable")
func _receive_farm_delta_chunk(chunk_index: int, total_chunks: int, chunk: PackedByteArray) -> void:
	if multiplayer.is_server():
		return
	if chunk_index == 0:
		_pending_farm_delta_chunks = []
		_pending_farm_delta_chunks_total = total_chunks
	if _pending_farm_delta_chunks.size() != chunk_index or total_chunks != _pending_farm_delta_chunks_total:
		_pending_farm_delta_chunks = []  # out-of-order/interleaved transfer — discard
		return
	_pending_farm_delta_chunks.append(chunk)
	if _pending_farm_delta_chunks.size() < _pending_farm_delta_chunks_total:
		return
	var payload := PackedByteArray()
	for c in _pending_farm_delta_chunks:
		payload.append_array(c)
	_pending_farm_delta_chunks = []
	var data: Variant = bytes_to_var(payload)
	if not (data is Dictionary):
		return
	_apply_farm_delta(data.get("soil", []), data.get("crops", []))


## Applies the host's host-computed farm state WITHOUT recomputing
## growth/mutation/disease (avoids divergence from per-peer RNG + bonuses).
## This is the day-rollover counterpart to the late-joiner snapshot.
func _apply_farm_delta(soil_delta: Array = [], crop_delta: Array = []) -> void:
	if multiplayer.is_server():
		return
	# Build the set of cells the host still farms, and apply its soil state.
	var host_cells: Dictionary = {}
	for entry in soil_delta:
		var cell := Vector2i(int(entry[0]), int(entry[1]))
		if _is_in_bounds(cell) and entry.size() >= 3:
			_soil_data[cell] = SoilData.deserialize(entry[2])
			host_cells[cell] = true
	# Track which cells the host currently has crops on, and rebuild the local
	# crop nodes from the delta so growth / mutation / death apply cleanly.
	var host_crop_cells: Dictionary = {}
	for entry in crop_delta:
		var cc := Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0)))
		host_crop_cells[cc] = true
		if _crop_nodes.has(cc):
			_crop_nodes[cc].queue_free()
			_crop_nodes.erase(cc)
		if _soil_data.has(cc) and _soil_data[cc].crop_id != "":
			var crop: Crop = CROP_SCENE.instantiate()
			objects_root.add_child(crop)
			crop.global_position = cell_to_world(cc)
			var g: Variant = entry.get("g", {})
			if g is Dictionary and not (g as Dictionary).is_empty():
				crop.setup(str(entry.get("id", "")), int(entry.get("days", 0)), CropGenetics.deserialize(g))
			else:
				crop.setup(str(entry.get("id", "")), int(entry.get("days", 0)))
			crop.mutated.connect(_on_crop_mutated.bind(cc))
			_crop_nodes[cc] = crop
	# Drop local crop nodes the host no longer has: either the crop died on the
	# host (soil remains, crop_id cleared) or the whole plot was reverted.
	for cell in _crop_nodes.keys():
		var keep: bool = host_crop_cells.has(cell) and _soil_data.has(cell) \
				and _soil_data[cell].crop_id != ""
		if not keep:
			_crop_nodes[cell].queue_free()
			_crop_nodes.erase(cell)
	# Remove local soil the host reverted to grass, and restore the ground tile
	# visual (mirrors the host's revert in _on_day_changed so a guest's plot
	# doesn't stay a ghost of tilled dirt after the host regrew it).
	for cell in _soil_data.keys():
		if not host_cells.has(cell):
			_soil_data.erase(cell)
			if cell.y < _tile_grid.size() and cell.x < _tile_grid[cell.y].size():
				var tile_id: String = _tile_grid[cell.y][cell.x]
				if tile_id in ["tilled", "watered_tilled"]:
					_tile_grid[cell.y][cell.x] = "grass"
					var gtype: TileTypeData = DataManager.get_tile_type("grass")
					if gtype:
						ground_layer.set_cell(cell, 0, gtype.atlas_coords)


# ── Visitor ship sync ───────────────────────────────────────────────────

## Called by VisitorManager on the host after NPCs disembark.
## Broadcasts the NPC roster and the ship's berth offset to all clients.
func notify_visitor_arrived(roster: Array, berth: Vector2) -> void:
	if NetworkManager.is_network_active() and multiplayer.is_server():
		rpc("_sync_spawn_visitor_ship", roster, berth.x, berth.y)


## Called by VisitorManager on the host when the ship departs.
func notify_visitor_departed() -> void:
	if NetworkManager.is_network_active() and multiplayer.is_server():
		rpc("_sync_depart_visitor_ship")


## Client → host: a freshly joined client asks for the current visitor ship
## state. The one-shot arrival broadcast is easy to miss (the client joined
## after the ship arrived, or its dock wasn't ready at broadcast time), so
## clients pull a snapshot once their world is up. Missing ships/NPCs are
## then re-spawned via _sync_spawn_visitor_ship, which is idempotent.
@rpc("any_peer", "reliable")
func _server_request_visitor_state() -> void:
	if not multiplayer.is_server():
		return
	var vm := get_tree().get_first_node_in_group("visitor_manager")
	if vm and vm.has_method("current_ship_snapshot"):
		var snap: Dictionary = vm.current_ship_snapshot()
		if not snap.is_empty():
			notify_visitor_arrived(snap.get("roster", []), snap.get("berth", Vector2.ZERO))


var _visitor_sync_attempts: int = 0

## Re-ask the host for the visitor snapshot after a short delay. Used when a
## client received the state before its world/dock was ready to place it.
func _retry_visitor_sync() -> void:
	_visitor_sync_attempts += 1
	if _visitor_sync_attempts > 10 or not NetworkManager.is_network_active() or multiplayer.is_server():
		return
	get_tree().create_timer(1.5).timeout.connect(func() -> void:
		if is_inside_tree():
			rpc_id(1, "_server_request_visitor_state")
	)


## Received by clients to spawn a visitor ship with matching NPCs.
@rpc("authority", "call_local")
func _sync_spawn_visitor_ship(roster: Array, berth_x: float = 0.0, berth_y: float = 60.0) -> void:
	if multiplayer.is_server():
		return
	const SHIP_SCENE := preload("res://scenes/world/visitors/VisitorShip.tscn")
	const NPC_SCENE := preload("res://scenes/world/visitors/VisitorNPC.tscn")
	# Idempotent: this runs for the original broadcast AND for late-join pulls,
	# so clear any prior ship/NPCs first instead of stacking duplicates.
	for old_ship in get_tree().get_nodes_in_group("visitor_ships"):
		if is_instance_valid(old_ship):
			old_ship.queue_free()
	for old_npc in get_tree().get_nodes_in_group("visitor_npcs"):
		if is_instance_valid(old_npc):
			old_npc.queue_free()
	var dock_pos: Vector2 = get_dock_position()
	var dock_node: Dock = get_dock()
	if dock_pos == Vector2.ZERO or not dock_node:
		# World/dock not ready yet (the pull raced with worldgen): re-ask the
		# host shortly instead of silently dropping the boat forever.
		_retry_visitor_sync()
		return
	var ship: VisitorShip = SHIP_SCENE.instantiate() as VisitorShip
	ship.dock_position = dock_pos
	ship.berth_offset = Vector2(berth_x, berth_y)
	ship.global_position = dock_pos + ship.berth_offset
	ship.is_docked = true
	# Store dock_node reference for NPC spawn position
	var world_root: Node = get_tree().current_scene
	if world_root:
		world_root.add_child(ship)
	# Spawn NPCs on the dock walkway (same placement as the host's
	# _deploy_npcs). Ship-relative offsets would land over water, where
	# walkability blocks all movement and NPCs stay glued next to the ship.
	for i in range(roster.size()):
		var entry: Dictionary = roster[i]
		var ntype: int = entry.get("type", 0)
		var npc := NPC_SCENE.instantiate() as VisitorNPC
		npc.npc_type = ntype
		npc._synced_index = i
		npc._is_remote = true
		var spawn_pos: Vector2 = VisitorShip.dock_spawn_position(dock_pos, i, self)
		npc.home_position = spawn_pos
		npc.dock_position = dock_pos
		npc.global_position = spawn_pos
		world_root.add_child(npc)
		# Override RNG-chosen values with synced ones
		npc._npc_display_name = entry.get("name", VisitorNPC.get_npc_name(ntype))
		npc._npc_texture_variant = entry.get("tex", 0)
		if is_instance_valid(npc.label):
			npc.label.text = npc._npc_display_name
		var tex_pool: Array[String] = VisitorNPC.get_npc_texture_paths(ntype)
		if tex_pool.size() > npc._npc_texture_variant:
			var tex_path: String = tex_pool[npc._npc_texture_variant]
			if ResourceLoader.exists(tex_path):
				npc.sprite.texture = load(tex_path)
		npc.start_wandering()
	_visitor_sync_attempts = 0


## Received by clients to remove the visitor ship and all NPCs.
@rpc("authority", "call_local")
func _sync_depart_visitor_ship() -> void:
	if multiplayer.is_server():
		return
	# Remove all visitor NPCs
	for npc in get_tree().get_nodes_in_group("visitor_npcs"):
		if is_instance_valid(npc):
			npc.queue_free()
	# Remove the ship
	var ships: Array[Node] = get_tree().get_nodes_in_group("visitor_ships")
	for ship in ships:
		if is_instance_valid(ship):
			ship.queue_free()


## Host: notify clients that a visitor ship's berth offset changed
## (e.g. displaced by the pirate ship during a raid).
func notify_visitor_berth_changed(offset: Vector2) -> void:
	if NetworkManager.is_network_active() and multiplayer.is_server():
		rpc("_sync_visitor_berth", offset.x, offset.y)


## Client: apply a host-dictated berth offset to all visitor ships.
@rpc("authority", "call_local")
func _sync_visitor_berth(ox: float, oy: float) -> void:
	if multiplayer.is_server():
		return
	for ship in get_tree().get_nodes_in_group("visitor_ships"):
		if is_instance_valid(ship) and ship.has_method("set_berth_offset"):
			ship.set_berth_offset(Vector2(ox, oy))


## Host: tell clients to walk their roaming NPCs to the hotel at night.
func notify_visitor_hotel_direct(hotel_pos: Vector2) -> void:
	if NetworkManager.is_network_active() and multiplayer.is_server():
		rpc("_sync_visitor_hotel_direct", hotel_pos.x, hotel_pos.y)


## Client: walk all visitor NPCs to the hotel like the host does.
@rpc("authority", "call_local")
func _sync_visitor_hotel_direct(px: float, py: float) -> void:
	if multiplayer.is_server():
		return
	var hotel_pos := Vector2(px, py)
	for npc in get_tree().get_nodes_in_group("visitor_npcs"):
		if is_instance_valid(npc) and npc.has_method("go_to_hotel"):
			npc.go_to_hotel(hotel_pos)


## Host: tell clients to recall their NPCs to the dock walkway before departure.
func notify_visitor_recall() -> void:
	if NetworkManager.is_network_active() and multiplayer.is_server():
		rpc("_sync_visitor_recall")


## Client: recall visitor NPCs to the dock walkway like the host does.
@rpc("authority", "call_local")
func _sync_visitor_recall() -> void:
	if multiplayer.is_server():
		return
	var dock_pos: Vector2 = get_dock_position()
	for npc in get_tree().get_nodes_in_group("visitor_npcs"):
		if is_instance_valid(npc) and npc.has_method("return_to_ship"):
			var walkway_target: Vector2 = dock_pos + Vector2(randf_range(32.0, 96.0), randf_range(-32.0, 8.0))
			npc.call_deferred("return_to_ship", walkway_target)


# ── NPC position sync (host-authoritative) ───────────────────────────────

## Host: relay a town resident's authoritative position to all clients.
func relay_resident_pos(npc_id: String, x: float, y: float) -> void:
	if NetworkManager.is_network_active() and multiplayer.is_server():
		rpc("_sync_resident_pos", npc_id, x, y)


## Client: mirror a town resident's host position.
@rpc("unreliable", "authority")
func _sync_resident_pos(npc_id: String, x: float, y: float) -> void:
	if multiplayer.is_server():
		return
	for r in get_tree().get_nodes_in_group("town_residents"):
		if r is TownResidentNPC and r.npc_id == npc_id:
			r.apply_remote_position(Vector2(x, y))
			break


## Host: relay a visitor NPC's authoritative position to all clients.
func relay_visitor_pos(index: int, x: float, y: float) -> void:
	if NetworkManager.is_network_active() and multiplayer.is_server():
		rpc("_sync_visitor_pos", index, x, y)


## Client: mirror a visitor NPC's host position.
@rpc("unreliable", "authority")
func _sync_visitor_pos(index: int, x: float, y: float) -> void:
	if multiplayer.is_server():
		return
	for v in get_tree().get_nodes_in_group("visitor_npcs"):
		if v is VisitorNPC and v._synced_index == index:
			v.apply_remote_position(Vector2(x, y))
			break


## Host: relay an interior wander NPC's authoritative position to all clients.
## Keyed by the owning building's cell ("cell_x,cell_y") plus the NPC's stable
## in-room origin. The cell key is essential: a client in a DIFFERENT building
## of the same layout has NPCs with identical origins, so matching by origin
## alone would cross-apply another building's positions onto them.
func relay_interior_wander_pos(cell_key: String, x: float, y: float, ox: float, oy: float) -> void:
	if NetworkManager.is_network_active() and multiplayer.is_server():
		rpc("_sync_interior_wander_pos", cell_key, x, y, ox, oy)


## Client: mirror an interior wander NPC's host position.
@rpc("unreliable", "authority")
func _sync_interior_wander_pos(cell_key: String, x: float, y: float, ox: float, oy: float) -> void:
	if multiplayer.is_server():
		return
	for w in get_tree().get_nodes_in_group("interior_wander_npcs"):
		# Same building session AND same in-room origin (multiple wander NPCs
		# can share a cell — e.g. hotel guests — so origin disambiguates).
		if w is InteriorWanderNPC and w._cell_key == cell_key \
				and w._origin.distance_to(Vector2(ox, oy)) < 1.0:
			w.apply_remote_position(Vector2(x, y))
			break


## Host: broadcast a hotel's guest count so clients' hotel interiors match.
func notify_hotel_guests(hotel_pos: Vector2, count: int) -> void:
	if NetworkManager.is_network_active() and multiplayer.is_server():
		rpc("_sync_hotel_guests", hotel_pos.x, hotel_pos.y, count)


## Client: apply a host-broadcast hotel guest count.
@rpc("authority", "call_local")
func _sync_hotel_guests(px: float, py: float, count: int) -> void:
	if multiplayer.is_server():
		return
	var hotel_pos := Vector2(px, py)
	for hotel in get_tree().get_nodes_in_group("hotel_buildings"):
		if is_instance_valid(hotel) and hotel is Hotel:
			if hotel.get_hotel_position().distance_to(hotel_pos) < 8.0:
				hotel.apply_synced_guest_count(count)
				return


# ── Resident recruitment sync ────────────────────────────────────────────

## Client → host: ask the server to convert a visitor NPC (by roster index)
## into a permanent resident. The host performs the conversion and broadcasts
## the result so every peer ends up with the same resident.
func request_convert_resident(role_name: String, home_ruin_id: String, home_cell: Vector2i, vtype: int, synced_index: int) -> void:
	rpc_id(1, "_server_convert_resident", role_name, home_ruin_id, home_cell.x, home_cell.y, vtype, synced_index)


## Host: broadcast a completed resident conversion to all clients.
func broadcast_convert_resident(npc_id: String, resident_name: String, role_name: String, home_ruin_id: String, home_cell: Vector2i, vtype: int, synced_index: int) -> void:
	if NetworkManager.is_network_active() and multiplayer.is_server():
		rpc("_sync_convert_resident", npc_id, resident_name, role_name, home_ruin_id, home_cell.x, home_cell.y, vtype, synced_index)


## Server: perform a resident conversion requested by any peer.
@rpc("any_peer", "reliable")
func _server_convert_resident(role_name: String, home_ruin_id: String, cell_x: int, cell_y: int, vtype: int, synced_index: int) -> void:
	if not multiplayer.is_server():
		return
	# Ignore requests for NPCs that were already converted (or don't exist).
	if not _free_visitor_by_synced_index(synced_index):
		return
	var npc_id: String = "resident_%s_%d" % [home_ruin_id, Time.get_unix_time_from_system()]
	# Re-style the resident's name to their new role so the name matches the
	# dialogue/services of the building they moved into.
	var resident_name: String = VisitorNPC.get_resident_name(role_name, VisitorNPC.get_random_npc_name(vtype))
	VisitorNPC.spawn_resident_from(self, npc_id, resident_name, role_name, home_ruin_id, Vector2i(cell_x, cell_y), vtype)
	_register_converted_resident(npc_id, resident_name, role_name, home_ruin_id, vtype)
	rpc("_sync_convert_resident", npc_id, resident_name, role_name, home_ruin_id, cell_x, cell_y, vtype, synced_index)


## Client: apply a host-broadcast resident conversion.
@rpc("authority", "reliable")
func _sync_convert_resident(npc_id: String, resident_name: String, role_name: String, home_ruin_id: String, cell_x: int, cell_y: int, vtype: int, synced_index: int) -> void:
	if multiplayer.is_server():
		return
	if not _free_visitor_by_synced_index(synced_index):
		return
	VisitorNPC.spawn_resident_from(self, npc_id, resident_name, role_name, home_ruin_id, Vector2i(cell_x, cell_y), vtype)
	_register_converted_resident(npc_id, resident_name, role_name, home_ruin_id, vtype)


## Register a converted resident in the local TownManager registry.
func _register_converted_resident(npc_id: String, resident_name: String, role_name: String, home_ruin_id: String, vtype: int) -> void:
	var town_mgr := get_tree().get_first_node_in_group("town_manager") as TownManager
	if town_mgr:
		town_mgr.add_resident(npc_id, resident_name, role_name, home_ruin_id, vtype)


## Remove the local visitor NPC copy matching a roster index after conversion.
## Returns false when no matching NPC exists (request is stale/duplicate).
func _free_visitor_by_synced_index(synced_index: int) -> bool:
	if synced_index < 0:
		return false
	for npc in get_tree().get_nodes_in_group("visitor_npcs"):
		if is_instance_valid(npc) and npc.get("_synced_index") == synced_index:
			npc.queue_free()
			return true
	return false
