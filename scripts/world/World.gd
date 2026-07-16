extends Node2D

## Owns the tile-based world: procedural generation, tile lookups, and
## simple farming actions (tilling). Keeps generation logic delegated to
## WorldGenerator so this script only deals with the scene tree.

const TILE_SIZE: int = 16
const RESOURCE_NODE_SCENE: PackedScene = preload("res://scenes/objects/ResourceNode.tscn")
const CROP_SCENE: PackedScene = preload("res://scenes/world/Crop.tscn")
const SHOP_STAND_SCENE: PackedScene = preload("res://scenes/objects/ShopStand.tscn")
const TREE_SCENE: PackedScene = preload("res://scenes/objects/Tree.tscn")

@export var world_width: int = 60
@export var world_height: int = 60
@export var world_seed: int = 0
@export var object_count: int = 12

@onready var ground_layer: TileMapLayer = $GroundLayer
@onready var objects_root: Node2D = $Objects

var _tile_grid: Array = []
var _generator: WorldGenerator
var _soil_data: Dictionary = {}
var _crop_nodes: Dictionary = {}

func _ready() -> void:
	GameManager.day_changed.connect(_on_day_changed)
	generate_world()
	_setup_water_collision()

func generate_world() -> void:
	_clear_world()
	_generator = WorldGenerator.create(world_width, world_height, world_seed)
	_tile_grid = _generator.generate_tile_grid()
	_paint_ground()
	_scatter_objects()
	_scatter_trees()
	_spawn_shop_stand()

func generate_world_with_seed(new_seed: int) -> void:
	world_seed = new_seed
	generate_world()

func _clear_world() -> void:
	ground_layer.clear()
	for child in objects_root.get_children():
		child.queue_free()
	_soil_data.clear()
	_crop_nodes.clear()

func _paint_ground() -> void:
	for y in range(world_height):
		for x in range(world_width):
			var tile_id: String = _tile_grid[y][x]
			var tile_type: TileTypeData = DataManager.get_tile_type(tile_id)
			if tile_type:
				ground_layer.set_cell(Vector2i(x, y), 0, tile_type.atlas_coords)

func _scatter_objects() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + 1
	var positions: Array = _generator.pick_object_positions(_tile_grid, object_count, rng)
	for pos in positions:
		var obj := RESOURCE_NODE_SCENE.instantiate()
		objects_root.add_child(obj)
		obj.global_position = cell_to_world(pos)

# ---------------------------------------------------------------------------
# Coordinate helpers
# ---------------------------------------------------------------------------

func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE_SIZE + TILE_SIZE / 2.0, cell.y * TILE_SIZE + TILE_SIZE / 2.0)

func world_to_cell(world_pos: Vector2) -> Vector2i:
	return Vector2i(floori(world_pos.x / TILE_SIZE), floori(world_pos.y / TILE_SIZE))

# ---------------------------------------------------------------------------
# Farming actions
# ---------------------------------------------------------------------------

func till_tile(world_pos: Vector2) -> bool:
	var cells := UpgradeManager.get_tool_area_cells(world_to_cell(world_pos))
	var tilled_any := false
	for cell in cells:
		if _till_cell(cell):
			tilled_any = true
	return tilled_any

func _till_cell(cell: Vector2i) -> bool:
	if not _is_in_bounds(cell):
		return false
	var tile_id: String = _tile_grid[cell.y][cell.x]
	var tile_type: TileTypeData = DataManager.get_tile_type(tile_id)
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
	
	return true

func water_tile(world_pos: Vector2) -> bool:
	var cells := UpgradeManager.get_tool_area_cells(world_to_cell(world_pos))
	var watered_any := false
	for cell in cells:
		if _water_cell(cell):
			watered_any = true
	return watered_any

func _water_cell(cell: Vector2i) -> bool:
	if not _soil_data.has(cell) or not _soil_data[cell].is_tilled or _soil_data[cell].is_watered:
		return false
	_soil_data[cell].is_watered = true
	var watered_type: TileTypeData = DataManager.get_tile_type("watered_tilled")
	ground_layer.set_cell(cell, 0, watered_type.atlas_coords)
	
	# Effects
	EffectSpawner.spawn_water_droplets(cell_to_world(cell))
	AudioManager.play(AudioManager.Sound.WATER)
	
	return true

func plant_seed(world_pos: Vector2, crop_id: String) -> bool:
	var cell := world_to_cell(world_pos)
	if not _soil_data.has(cell) or not _soil_data[cell].is_tilled or _soil_data[cell].crop_id != "":
		return false

	var crop_data := DataManager.get_crop(crop_id)
	if not crop_data or crop_data.seed_item_id == "":
		return false
	if not InventoryManager.remove_item(crop_data.seed_item_id, 1):
		return false
	
	_soil_data[cell].crop_id = crop_id
	_soil_data[cell].days_grown = 0
	
	var crop: Crop = CROP_SCENE.instantiate()
	objects_root.add_child(crop)
	crop.global_position = cell_to_world(cell)
	crop.setup(crop_id, 0)
	crop.mutated.connect(_on_crop_mutated.bind(cell))
	_crop_nodes[cell] = crop
	
	# Effects
	AudioManager.play(AudioManager.Sound.PLANT)
	
	return true

func harvest_crop(world_pos: Vector2) -> bool:
	var cell := world_to_cell(world_pos)
	if not _crop_nodes.has(cell):
		return false
	var crop: Crop = _crop_nodes[cell]
	if not crop.is_mature():
		return false
	
	var crop_data := DataManager.get_crop(crop.crop_id)
	if not crop_data:
		return false

	if not InventoryManager.can_fit(crop_data.yield_item_id, crop_data.yield_amount):
		return false  # inventory full - leave the crop growing rather than losing the harvest

	InventoryManager.add_item(crop_data.yield_item_id, crop_data.yield_amount)
	DataManager.mark_discovered(crop_data.id)
	
	# Effects
	var harvest_color := crop_data.modulate_color
	if crop.genetics:
		harvest_color = crop.genetics.to_color()
	EffectSpawner.spawn_harvest_effect(crop.global_position, crop_data.display_name, harvest_color)
	AudioManager.play(AudioManager.Sound.HARVEST)
	
	# Camera punch toward player (disabled - requires Camera2D with punch method)
	# var camera := get_viewport().get_camera_2d()
	# if camera and camera.has_method("punch"):
	
	if crop_data.regrows:
		crop.harvest()
		_soil_data[cell].days_grown = crop_data.regrow_days
	else:
		crop.queue_free()
		_crop_nodes.erase(cell)
		_soil_data[cell].crop_id = ""
		_soil_data[cell].days_grown = 0
	return true

## Keeps SoilData in sync when a Crop mutates into a new crop id mid-growth,
## and forwards a notification for the UI to display.
@warning_ignore("unused_parameter")
func _on_crop_mutated(crop: Crop, old_crop_id: String, new_crop_id: String, mutation_name: String, cell: Vector2i) -> void:
	if _soil_data.has(cell):
		_soil_data[cell].crop_id = new_crop_id

	var old_crop_data := DataManager.get_crop(old_crop_id)
	var new_crop_data := DataManager.get_crop(new_crop_id)
	var old_name := old_crop_data.display_name if old_crop_data else old_crop_id
	var new_name := new_crop_data.display_name if new_crop_data else new_crop_id
	GameManager.crop_mutated.emit(old_name, new_name, mutation_name)

func _on_day_changed(_day: int) -> void:
	for cell in _soil_data.keys():
		var soil: SoilData = _soil_data[cell]
		if soil.crop_id != "":
			var crop_data := DataManager.get_crop(soil.crop_id)
			if crop_data and (not crop_data.requires_water or soil.is_watered):
				soil.days_grown += 1
				if _crop_nodes.has(cell):
					_crop_nodes[cell].grow()
		
		# Soil dries out every day
		soil.is_watered = false
		var tilled_type: TileTypeData = DataManager.get_tile_type("tilled")
		ground_layer.set_cell(cell, 0, tilled_type.atlas_coords)

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

	# Apply full-tile collision to all non-walkable tile types.
	var non_walkable_coords := [Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0)]
	for coords in non_walkable_coords:
		var tile_data: TileData = source.get_tile_data(coords, 0)
		if tile_data:
			if tile_data.get_collision_polygons_count(0) == 0:
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

	for y in range(world_height):
		for x in range(world_width):
			var tile_id: String = _tile_grid[y][x]
			if tile_id != "trees":
				continue
			# Place a tree on ~60% of trees tiles for a natural look
			if rng.randf() > 0.6:
				continue

			var cell := Vector2i(x, y)
			# Skip if there's already something here
			var blocked := false
			for child in objects_root.get_children():
				if child.global_position.distance_squared_to(cell_to_world(cell)) < 100.0:
					blocked = true
					break
			if blocked:
				continue

			var tree: Area2D = TREE_SCENE.instantiate()
			objects_root.add_child(tree)
			tree.global_position = cell_to_world(cell)


func _is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < world_width and cell.y < world_height


# ---------------------------------------------------------------------------
# Shop Stand spawning
# ---------------------------------------------------------------------------

## Places the NPC shop stand at a random walkable position near-ish the
## centre so the player almost always finds it within the first minute.
func _spawn_shop_stand() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + 7777

	# Pick a walkable cell within the inner ~60% of the island
	var centre_x := world_width / 2
	var centre_y := world_height / 2
	var radius := mini(world_width, world_height) / 5

	for attempt in 100:
		var cell := Vector2i(
			centre_x + rng.randi_range(-radius, radius),
			centre_y + rng.randi_range(-radius, radius)
		)
		if not _is_in_bounds(cell):
			continue

		var tile_id: String = _tile_grid[cell.y][cell.x] if cell.y < _tile_grid.size() and cell.x < _tile_grid[cell.y].size() else "water"
		var tile_type: TileTypeData = DataManager.get_tile_type(tile_id)
		if tile_type and tile_type.walkable and tile_type.tillable:
			# Make sure no resource node is already here
			var blocked := false
			for child in objects_root.get_children():
				if child.global_position.distance_squared_to(cell_to_world(cell)) < 64.0:
					blocked = true
					break
			if blocked:
				continue

			var stand: Area2D = SHOP_STAND_SCENE.instantiate()
			objects_root.add_child(stand)
			stand.global_position = cell_to_world(cell)
			return

	# Fallback: place at centre
	var fallback := SHOP_STAND_SCENE.instantiate()
	objects_root.add_child(fallback)
	fallback.global_position = cell_to_world(Vector2i(centre_x, centre_y))
