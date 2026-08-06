class_name ResourceSpawner
extends RefCounted

## Places biome-specific resource nodes across the world.
## Each biome defines its resource mix via ResourceSpawnEntry entries,
## and this spawner instantiates them respecting spacing/clustering rules.

## Monotonic per-worldgen instance counter so names never collide even when
## the same (resource_id, cell) pair is placed more than once. Keeps node
## paths deterministic across host and client.
var _name_index: int = 0

const RESOURCE_NODE_SCENE: PackedScene = preload("res://scenes/objects/ResourceNode.tscn")
const TREE_SCENE: PackedScene = preload("res://scenes/objects/Tree.tscn")

## Maps biome resource_id identifiers to actual inventory item_ids.
## Used when the custom scene doesn't exist and we fall back to the generic ResourceNode.
const RESOURCE_ITEM_MAP: Dictionary = {
	"plains_wildflowers":   "flower",
	"forest_tree":          "wood",
	"forest_berries":       "berry",
	"forest_mushrooms":     "mushroom",
	"swamp_rare_plant":     "flower",
	"swamp_unique_crop":    "mushroom",
	"mountain_crystal":     "iron_ore",
	"mountain_special_seeds": "flower",
}

## Maps resource_id to the Player.Tool enum value required to gather it.
## Resources not listed here have no tool requirement.
const RESOURCE_TOOL_MAP: Dictionary = {
	"mountain_crystal":     10,  # Player.Tool.PICKAXE
}

## Spawn resources for a biome region within a bounding box.
## Returns an array of spawned Node2D references so the caller can parent them.
## @param biome_cell_count: number of land cells belonging to this biome (used for density scaling).
func spawn_biome_resources(
	biome: BiomeDefinition,
	biome_cell_count: int,
	tile_grid: Array,
	world_width: int,
	world_height: int,
	rng: RandomNumberGenerator,
	objects_root: Node2D,
	cell_to_world_func: Callable,
	is_cell_blocked: Callable = Callable()
) -> Array:
	var spawned: Array = []
	if not biome or biome.resources.is_empty():
		return spawned

	# Calculate target spawn count based on density relative to this biome's area
	var total_tiles := biome_cell_count
	var target_count := maxi(1, roundi(total_tiles * biome.resource_density / 100.0))
	
	# Distribute target across resource entries based on weights
	var total_weight := 0.0
	for entry in biome.resources:
		total_weight += entry.weight
	
	if total_weight <= 0:
		return spawned
	
	var attempts := 0
	var placed := 0
	var used_positions: Dictionary = {}
	var spawn_map: Dictionary = {}  # entry_id -> Array of positions
	
	while placed < target_count and attempts < target_count * 30:
		attempts += 1
		
		# Pick a resource entry weighted by its weight
		var roll := rng.randf_range(0.0, total_weight)
		var cumulative := 0.0
		var selected_entry: ResourceSpawnEntry = null
		for entry in biome.resources:
			cumulative += entry.weight
			if roll <= cumulative:
				selected_entry = entry
				break
		if not selected_entry:
			continue
		
		# Pick a random walkable tile
		var x := rng.randi_range(0, world_width - 1)
		var y := rng.randi_range(0, world_height - 1)
		var cell := Vector2i(x, y)
		
		# Check tile is walkable
		if y >= tile_grid.size() or x >= tile_grid[y].size():
			continue
		var tile_id: String = tile_grid[y][x]
		if tile_id == "path":
			continue
		var tile_type: TileTypeData = DataManager.get_tile_type(tile_id)
		if not tile_type or not tile_type.walkable:
			continue
		
		# Check spacing
		var spacing_key := selected_entry.resource_id
		var min_dist_sq := selected_entry.min_spacing * selected_entry.min_spacing * 256.0
		var too_close := false
		if spawn_map.has(spacing_key):
			for existing_pos in spawn_map[spacing_key]:
				if existing_pos.distance_squared_to(cell) < min_dist_sq:
					too_close = true
					break
		if too_close:
			continue
		
		# Check not on an existing object (trees, bushes, etc.)
		# Use 256.0 (1 tile radius) to prevent overlapping with tree foliage.
		var blocked := false
		# Look at the current objects_root children
		for child in objects_root.get_children():
			var cpos: Vector2 = child.global_position
			var tpos: Vector2 = cell_to_world_func.call(cell)
			if cpos.distance_squared_to(tpos) < 256.0:
				blocked = true
				break
		# Also check the building-blocked callback if provided
		if not blocked and is_cell_blocked.is_valid():
			blocked = is_cell_blocked.call(cell)
		if blocked:
			continue
		
		# Place the resource
		_place_resource(selected_entry, cell, objects_root, cell_to_world_func)
		
		# Track position for spacing
		if not spawn_map.has(spacing_key):
			spawn_map[spacing_key] = []
		spawn_map[spacing_key].append(cell)
		placed += 1
		
		# Handle clustering
		if selected_entry.clusters:
			var cluster_size := rng.randi_range(selected_entry.cluster_size_range.x, selected_entry.cluster_size_range.y)
			for _c in range(cluster_size - 1):
				# Try nearby positions
				for _attempt in 10:
					var ox := x + rng.randi_range(-2, 2)
					var oy := y + rng.randi_range(-2, 2)
					var cluster_cell := Vector2i(ox, oy)
					if ox < 0 or ox >= world_width or oy < 0 or oy >= world_height:
						continue
					if oy >= tile_grid.size() or ox >= tile_grid[oy].size():
						continue
					var ctile_id: String = tile_grid[oy][ox]
					if ctile_id == "path":
						continue
					var ctile_type: TileTypeData = DataManager.get_tile_type(ctile_id)
					if not ctile_type or not ctile_type.walkable:
						continue
					if used_positions.has(cluster_cell):
						continue
					# Cluster children must respect the blocked callback too - a
					# cluster from a resource placed just outside the town rect
					# must not hop inside it.
					if is_cell_blocked.is_valid() and is_cell_blocked.call(cluster_cell):
						continue
					
					_place_resource(selected_entry, cluster_cell, objects_root, cell_to_world_func)
					spawn_map[spacing_key].append(cluster_cell)
					used_positions[cluster_cell] = true
					placed += 1
					break
	
	return spawned


func _place_resource(entry: ResourceSpawnEntry, cell: Vector2i, objects_root: Node2D, cell_to_world_func: Callable) -> void:
	# Try to use the specified scene path if it exists
	var scene_path := entry.scene_path
	if scene_path != "" and ResourceLoader.exists(scene_path):
		var scene := load(scene_path) as PackedScene
		if scene:
			var instance := scene.instantiate()
			instance.name = "%s_%d_%d_%d" % [entry.resource_id, cell.x, cell.y, _name_index]
			_name_index += 1
			objects_root.add_child(instance)
			instance.global_position = cell_to_world_func.call(cell)
			# Cherry trees spawned by the cherry grove biome get cherry blossom sprites
			if entry.resource_id == "cherry_tree" and instance.has_method("set_cherry"):
				instance.set_cherry()
			return
	
	# Fallback: use generic ResourceNode with a proper item id
	var node := RESOURCE_NODE_SCENE.instantiate()
	node.name = "%s_%d_%d_%d" % [entry.resource_id, cell.x, cell.y, _name_index]
	_name_index += 1
	node.item_id = RESOURCE_ITEM_MAP.get(entry.resource_id, entry.resource_id)
	node.interaction_prompt = "Take " + entry.display_name
	node.min_amount = 1
	node.max_amount = 3
	if RESOURCE_TOOL_MAP.has(entry.resource_id):
		node.required_tool = RESOURCE_TOOL_MAP[entry.resource_id]
	objects_root.add_child(node)
	node.global_position = cell_to_world_func.call(cell)
