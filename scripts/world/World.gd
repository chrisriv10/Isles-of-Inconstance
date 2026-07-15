extends Node2D

## Owns the tile-based world: procedural generation, tile lookups, and
## simple farming actions (tilling). Keeps generation logic delegated to
## WorldGenerator so this script only deals with the scene tree.

const TILE_SIZE: int = 16
const RESOURCE_NODE_SCENE: PackedScene = preload("res://scenes/objects/ResourceNode.tscn")
const CROP_SCENE: PackedScene = preload("res://scenes/world/Crop.tscn")

@export var world_width: int = 40
@export var world_height: int = 40
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

func generate_world() -> void:
	_clear_world()
	_generator = WorldGenerator.create(world_width, world_height, world_seed)
	_tile_grid = _generator.generate_tile_grid()
	_paint_ground()
	_scatter_objects()

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

func _is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < world_width and cell.y < world_height
