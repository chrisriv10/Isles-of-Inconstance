class_name WorldChunk
extends RefCounted

## Plain data container returned by WorldGenerator.generate_chunk().

var origin: Vector2i = Vector2i.ZERO
var size: Vector2i = Vector2i.ZERO

## 2D array indexed [y][x] of BiomeType.Type, relative to `origin`.
var biome_map: Array = []

## 2D array indexed [y][x] of normalized [0,1] terrain height, relative to `origin`.
var height_map: Array = []

## Flat list of resource spawn dictionaries:
## { "resource_id": String, "tile": Vector2i, "scene_path": String }
var resources: Array = []


func get_biome_type(local_x: int, local_y: int) -> int:
	return biome_map[local_y][local_x]


func get_height(local_x: int, local_y: int) -> float:
	return height_map[local_y][local_x]
