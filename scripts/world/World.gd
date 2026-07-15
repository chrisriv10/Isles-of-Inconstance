extends Node2D

## Owns the tile-based world: procedural generation, tile lookups, and
## simple farming actions (tilling). Keeps generation logic delegated to
## WorldGenerator so this script only deals with the scene tree.

const TILE_SIZE: int = 16
const OBJECT_SCENE: PackedScene = preload("res://scenes/objects/Interactable.tscn")

@export var world_width: int = 40
@export var world_height: int = 40
@export var world_seed: int = 0
@export var object_count: int = 12

@onready var ground_layer: TileMapLayer = $GroundLayer
@onready var objects_root: Node2D = $Objects

var _tile_grid: Array = []
var _generator: WorldGenerator

func _ready() -> void:
	generate_world()

func generate_world() -> void:
	_clear_world()
	_generator = WorldGenerator.new(world_width, world_height, world_seed)
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
		var obj := OBJECT_SCENE.instantiate()
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
# Farming actions - simple prototype implementation, safe to extend later
# (e.g. plant_crop, water_tile, harvest_tile).
# ---------------------------------------------------------------------------

func till_tile(world_pos: Vector2) -> bool:
	var cell := world_to_cell(world_pos)
	if not _is_in_bounds(cell):
		return false
	var tile_id: String = _tile_grid[cell.y][cell.x]
	var tile_type: TileTypeData = DataManager.get_tile_type(tile_id)
	if tile_type == null or not tile_type.tillable:
		return false
	_tile_grid[cell.y][cell.x] = "tilled"
	var tilled_type: TileTypeData = DataManager.get_tile_type("tilled")
	ground_layer.set_cell(cell, 0, tilled_type.atlas_coords)
	return true

func _is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < world_width and cell.y < world_height
