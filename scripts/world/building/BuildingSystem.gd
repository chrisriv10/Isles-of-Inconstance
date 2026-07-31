class_name BuildingSystem
extends RefCounted

## Complete building placement system. Players can craft and place structures
## into the world. Supports placement preview, collision validation, rotation,
## removal, relocation, and save/load.

enum BuildingType {
	NONE = -1,
	SMALL_HOME = 0,
	MEDIUM_HOME = 1,
	LARGE_HOME = 2,
	BARN = 3,
	STORAGE_SHED = 4,
	FENCE = 5,
	STONE_FENCE = 6,
	GATE = 7,
	GARDEN_BED = 8,
	# BRIDGE = 9 — removed
	CAMPFIRE = 10,
	WORKSHOP = 11,
	WINDMILL = 12,
	GREENHOUSE = 13,
	DECORATIVE_STATUE = 14,
	DECORATIVE_FOUNTAIN = 15,
	DECORATIVE_BENCH = 16,
	DECORATIVE_LANTERN = 17,
	DECORATIVE_SIGN = 18,
	SILO = 19,
	WELL = 20,
	HOTEL = 21,
	SCARECROW = 22,
	COMPOST_BIN = 23,
}

## Pre-made textures for all buildings — use these instead of procedural drawing.
## Each texture is sized to the building's footprint in tiles (width*16 × height*16).
## Generated as pixel art matching the game's top-down style.
const PREMADE_TEXTURES: Dictionary = {
	BuildingType.SMALL_HOME: preload("res://assets/generated/building_small_home_frame_0.png"),
	BuildingType.MEDIUM_HOME: preload("res://assets/generated/building_medium_home_frame_0.png"),
	BuildingType.LARGE_HOME: preload("res://assets/generated/building_large_home_frame_0.png"),
	BuildingType.BARN: preload("res://assets/generated/building_barn_frame_0.png"),
	BuildingType.STORAGE_SHED: preload("res://assets/generated/building_storage_shed_frame_0.png"),
	BuildingType.FENCE: preload("res://assets/generated/building_fence_frame_0.png"),
	BuildingType.STONE_FENCE: preload("res://assets/generated/building_stone_fence_frame_0.png"),
	BuildingType.GATE: preload("res://assets/generated/building_gate_frame_0.png"),
	BuildingType.GARDEN_BED: preload("res://assets/generated/building_garden_bed_frame_0.png"),
	BuildingType.CAMPFIRE: preload("res://assets/generated/building_campfire_frame_0.png"),
	BuildingType.WORKSHOP: preload("res://assets/generated/building_workshop_frame_0.png"),
	BuildingType.WINDMILL: preload("res://assets/generated/building_windmill_frame_0.png"),
	BuildingType.GREENHOUSE: preload("res://assets/generated/building_greenhouse_frame_0.png"),
	BuildingType.DECORATIVE_STATUE: preload("res://assets/generated/building_statue_frame_0.png"),
	BuildingType.DECORATIVE_FOUNTAIN: preload("res://assets/generated/building_fountain_frame_0.png"),
	BuildingType.DECORATIVE_BENCH: preload("res://assets/generated/building_bench_frame_0.png"),
	BuildingType.DECORATIVE_LANTERN: preload("res://assets/generated/building_decorative_lantern_frame_0.png"),
	BuildingType.DECORATIVE_SIGN: preload("res://assets/generated/building_sign_frame_0.png"),
	BuildingType.SILO: preload("res://assets/generated/building_silo_frame_0.png"),
	BuildingType.WELL: preload("res://assets/generated/building_well_frame_0.png"),
	BuildingType.HOTEL: preload("res://assets/generated/building_hotel_frame_0.png"),
	BuildingType.SCARECROW: preload("res://assets/generated/building_scarecrow_frame_0.png"),
	BuildingType.COMPOST_BIN: preload("res://assets/generated/building_compost_bin_frame_0.png"),
}

const BUILDING_DATA: Dictionary = {
	BuildingType.SMALL_HOME: {
		"name": "Small Home",
		"width": 4, "height": 4,
		"has_interior": true,
		"interior_scene": "res://scenes/buildings/small_home_interior.tscn",
		"ingredients": {"wood": 20, "stone": 10},
		"description": "A cozy small home to shelter from the elements."
	},
	BuildingType.MEDIUM_HOME: {
		"name": "Medium Home",
		"width": 5, "height": 4,
		"has_interior": true,
		"interior_scene": "res://scenes/buildings/medium_home_interior.tscn",
		"ingredients": {"wood": 40, "stone": 20, "wooden_planks": 15},
		"description": "A comfortable home with room for furnishings."
	},
	BuildingType.LARGE_HOME: {
		"name": "Large Home",
		"width": 6, "height": 5,
		"has_interior": true,
		"interior_scene": "res://scenes/buildings/large_home_interior.tscn",
		"ingredients": {"wood": 80, "stone": 40, "wooden_planks": 30},
		"description": "A grand home with plenty of space for crafting and storage."
	},
	BuildingType.BARN: {
		"name": "Barn",
		"width": 4, "height": 3,
		"has_interior": true,
		"interior_scene": "res://scenes/buildings/barn_interior.tscn",
		"ingredients": {"wood": 30, "stone": 15},
		"description": "A sturdy barn for storage and animals."
	},
	BuildingType.STORAGE_SHED: {
		"name": "Storage Shed",
		"width": 2, "height": 2,
		"has_interior": false,
		"ingredients": {"wood": 15, "stone": 5},
		"description": "Extra storage space for your belongings."
	},
	BuildingType.FENCE: {
		"name": "Fence",
		"width": 1, "height": 1,
		"has_interior": false,
		"is_fence": true,
		"keep_build_mode": true,
		"ingredients": {"wood": 2},
		"description": "A simple wooden fence to mark boundaries."
	},
	BuildingType.STONE_FENCE: {
		"name": "Stone Fence",
		"width": 1, "height": 1,
		"has_interior": false,
		"is_fence": true,
		"keep_build_mode": true,
		"ingredients": {"stone": 3},
		"description": "A sturdy stone fence."
	},
	BuildingType.GATE: {
		"name": "Gate",
		"width": 1, "height": 1,
		"has_interior": false,
		"is_fence": true,
		"keep_build_mode": true,
		"ingredients": {"wood": 5, "stone": 2},
		"description": "A wooden gate for fence openings."
	},
	BuildingType.GARDEN_BED: {
		"name": "Garden Bed",
		"width": 2, "height": 1,
		"has_interior": false,
		"ingredients": {"wood": 8, "wooden_planks": 4},
		"description": "A vibrant raised garden bed with rich soil for growing crops."
	},
	BuildingType.CAMPFIRE: {
		"name": "Campfire",
		"width": 1, "height": 1,
		"has_interior": false,
		"ingredients": {"wood": 5, "stone": 3},
		"description": "A cozy campfire for cooking and light."
	},
	BuildingType.WORKSHOP: {
		"name": "Town Hall",
		"width": 4, "height": 3,
		"has_interior": true,
		"interior_scene": "res://scenes/buildings/town_hall_interior.tscn",
		"ingredients": {"wood": 50, "stone": 30, "wooden_planks": 25},
		"description": "The town's administrative heart — manage visitors, recruitment, and governance."
	},
	BuildingType.WINDMILL: {
		"name": "Windmill",
		"width": 3, "height": 5,
		"has_interior": false,
		"ingredients": {"wood": 50, "stone": 30, "wooden_planks": 20},
		"description": "A windmill for processing grain."
	},
	BuildingType.GREENHOUSE: {
		"name": "Greenhouse",
		"width": 6, "height": 4,
		"has_interior": true,
		"interior_scene": "res://scenes/buildings/greenhouse_interior.tscn",
		"ingredients": {"wood": 60, "stone": 30, "wooden_planks": 40},
		"description": "An expansive glass greenhouse with abundant space for year-round growing."
	},
	BuildingType.DECORATIVE_STATUE: {
		"name": "Monument Statue",
		"width": 3, "height": 3,
		"has_interior": false,
		"ingredients": {"stone": 80},
		"description": "An impressive stone monument with a heroic statue."
	},
	BuildingType.DECORATIVE_FOUNTAIN: {
		"name": "Fountain",
		"width": 2, "height": 2,
		"has_interior": false,
		"ingredients": {"stone": 30},
		"description": "A decorative fountain."
	},
	BuildingType.DECORATIVE_BENCH: {
		"name": "Bench",
		"width": 1, "height": 1,
		"has_interior": false,
		"ingredients": {"wood": 5},
		"description": "A simple wooden bench to rest on."
	},
	BuildingType.DECORATIVE_LANTERN: {
		"name": "Lantern",
		"width": 1, "height": 1,
		"has_interior": false,
		"ingredients": {"stone": 3, "wood": 2},
		"description": "A lantern that glows at night."
	},
	BuildingType.DECORATIVE_SIGN: {
		"name": "Sign",
		"width": 1, "height": 1,
		"has_interior": false,
		"ingredients": {"wood": 3},
		"description": "A wooden signpost."
	},
	BuildingType.SILO: {
		"name": "Silo",
		"width": 3, "height": 4,
		"has_interior": false,
		"ingredients": {"stone": 40, "wood": 20, "wooden_planks": 15},
		"description": "A tall stone silo with 36 slots of crop-only bulk storage."
	},
	BuildingType.WELL: {
		"name": "Well",
		"width": 2, "height": 2,
		"has_interior": false,
		"ingredients": {"stone": 15},
		"description": "A well providing fresh water."
	},
	BuildingType.HOTEL: {
		"name": "Hotel",
		"width": 8, "height": 7,
		"has_interior": true,
		"interior_scene": "",
		"ingredients": {"wood": 60, "stone": 30, "wooden_planks": 20, "gold_nugget": 5},
		"description": "A grand two-story hotel with a comfortable lobby and private guest rooms. Earns gold from visitor NPCs."
	},
	BuildingType.SCARECROW: {
		"name": "Scarecrow",
		"width": 1, "height": 1,
		"has_interior": false,
		"ingredients": {"wood": 8, "fiber": 5},
		"description": "Scares away pests! Reduces crop disease within a 5×5 area."
	},
	BuildingType.COMPOST_BIN: {
		"name": "Compost Bin",
		"width": 1, "height": 1,
		"has_interior": false,
		"ingredients": {"wood": 10, "wooden_planks": 6},
		"description": "Turns excess crops into compost over time."
	},
}

## Returns true if the given building type is a fence-type building (connects to neighbors).
static func is_fence_type(building_type: int) -> bool:
	return BUILDING_DATA.get(building_type, {}).get("is_fence", false)

## Returns true if the given building type should keep build mode active after placement.
static func keeps_build_mode(building_type: int) -> bool:
	return BUILDING_DATA.get(building_type, {}).get("keep_build_mode", false)

# Buildings placed in the world
var placed_buildings: Array = []

signal building_placed(building_type: int, cell: Vector2i, rotation: int)
signal building_removed(building_type: int, cell: Vector2i)

## Rotates a coordinate offset based on the rotation value (0=0°, 1=90°, 2=180°, 3=270°)
func _rotate_coords(x: int, y: int, w: int, h: int, rotation: int) -> Vector2i:
	match rotation:
		1:  # 90°
			return Vector2i(h - 1 - y, x)
		2:  # 180°
			return Vector2i(w - 1 - x, h - 1 - y)
		3:  # 270°
			return Vector2i(y, w - 1 - x)
		_:  # 0° (default)
			return Vector2i(x, y)

func can_place(building_type: int, cell: Vector2i, rotation: int, tile_grid: Array, world_width: int, world_height: int) -> Dictionary:
	if not BUILDING_DATA.has(building_type):
		return {"valid": false, "reason": "Unknown building type"}
	var data: Dictionary = BUILDING_DATA[building_type]
	var w: int = data.get("width", 1)
	var h: int = data.get("height", 1)
	
	# Check bounds
	for x in range(w):
		for y in range(h):
			var rotated: Vector2i = _rotate_coords(x, y, w, h, rotation)
			var check_cell: Vector2i = cell + rotated
			if check_cell.x < 0 or check_cell.x >= world_width or check_cell.y < 0 or check_cell.y >= world_height:
				return {"valid": false, "reason": "Out of bounds"}
			
			# Check tile is walkable
			if tile_grid and check_cell.y < tile_grid.size() and check_cell.x < tile_grid[check_cell.y].size():
				var tile_id: String = tile_grid[check_cell.y][check_cell.x]
				var tile_type: TileTypeData = DataManager.get_tile_type(tile_id)
				# Biome variant tiles like "cherry_grove_0" are registered; but some tile IDs
				# used in the grid (e.g., "path") may not be in DataManager — treat unknown as
				# non-walkable so we don't crash, but allow "path" explicitly for building placement.
				if tile_id == "path":
					pass  # path is buildable
				elif tile_type == null:
					return {"valid": false, "reason": "Unknown tile: " + tile_id}
				elif not tile_type.walkable and tile_id != "tilled" and tile_id != "watered_tilled":
					return {"valid": false, "reason": "Cannot place on " + tile_id}
			
			# Check no other building here (full footprint check)
			for b in placed_buildings:
				var b_cell: Vector2i = b.get("cell", Vector2i(0, 0))
				var b_w: int = b.get("width", 1)
				var b_h: int = b.get("height", 1)
				var b_rot: int = b.get("rotation", 0)
				var found_overlap := false
				for bx in range(b_w):
					for by in range(b_h):
						var b_rotated: Vector2i = _rotate_coords(bx, by, b_w, b_h, b_rot)
						if b_cell + b_rotated == check_cell:
							found_overlap = true
							break
					if found_overlap:
						break
				if found_overlap:
					return {"valid": false, "reason": "Occupied by " + b.get("name", "Building")}
	
	return {"valid": true}

func place_building(building_type: int, cell: Vector2i, rotation: int, world_ref: Node, trigger_objective: bool = true) -> bool:
	if not BUILDING_DATA.has(building_type):
		return false
	var data: Dictionary = BUILDING_DATA[building_type]
	
	var building_data: Dictionary = {
		"type": building_type,
		"name": data.get("name", "Building"),
		"cell": cell,
		"rotation": rotation,
		"width": data.get("width", 1),
		"height": data.get("height", 1),
		"has_interior": data.get("has_interior", false),
		"interior_scene": data.get("interior_scene", ""),
	}
	
	placed_buildings.append(building_data)
	building_placed.emit(building_type, cell, rotation)
	
	# Notify ObjectiveManager (only for player-placed buildings)
	if trigger_objective:
		var obj_mgr_b: Node = world_ref.get_tree().get_first_node_in_group("objective_manager") if world_ref and world_ref.get_tree() else null
		if obj_mgr_b and obj_mgr_b.has_method("on_building_placed"):
			obj_mgr_b.on_building_placed()
	
	# Create visual node
	_create_building_node(building_data, world_ref)
	
	# Update fence connections for this cell and all neighbors
	if data.get("is_fence", false):
		FenceConnectionManager.update_neighbor_fences(cell, self, world_ref)
	
	return true

func remove_building(cell: Vector2i, world_ref: Node) -> bool:
	var was_fence: bool = false
	for i in range(placed_buildings.size()):
		var b = placed_buildings[i]
		if b.cell == cell:
			was_fence = BUILDING_DATA.get(b.type, {}).get("is_fence", false)
			building_removed.emit(b.type, cell)
			placed_buildings.remove_at(i)
			
			# Remove visual node
			var node_name := "Building_%d_%d" % [cell.x, cell.y]
			var obj_root: Node = world_ref.get_node_or_null("Objects")
			if obj_root:
				var node: Node = obj_root.get_node_or_null(node_name)
				if node:
					node.queue_free()
			
			# Update neighbor fence visuals if a fence was removed
			if was_fence:
				FenceConnectionManager.update_neighbor_fences(cell, self, world_ref)
			return true
	return false

func _create_building_node(building_data: Dictionary, world_ref: Node) -> void:
	var obj_root: Node = world_ref.get_node_or_null("Objects")
	if not obj_root:
		return
	
	# Extract values with explicit types (cell may be string from JSON)
	var b_cell: Vector2i = _parse_cell(building_data.get("cell", Vector2i(0, 0)))
	var b_width: int = building_data.get("width", 1)
	var b_height: int = building_data.get("height", 1)
	var b_has_interior: bool = building_data.get("has_interior", false)
	var b_type: int = building_data.get("type", 0)
	var b_interior_scene: String = building_data.get("interior_scene", "")
	
	var node := Node2D.new()
	node.name = "Building_%d_%d" % [b_cell.x, b_cell.y]
	obj_root.add_child(node)
	
	var cell_size: int = 16
	var pos := Vector2(
		b_cell.x * cell_size + b_width * cell_size / 2.0,
		b_cell.y * cell_size + b_height * cell_size / 2.0
	)
	node.global_position = pos
	
	# Fence buildings: use connection-aware sprites via FenceConnectionManager
	var is_fence_building: bool = BUILDING_DATA.get(b_type, {}).get("is_fence", false)
	
	# Draw building sprite — prefer pre-made texture when available
	var sprite := Sprite2D.new()
	node.add_child(sprite)
	
	# Declare tex here so it's in scope for the entire function body below
	var tex: Texture2D = PREMADE_TEXTURES.get(b_type) if not is_fence_building else null
	if is_fence_building:
		# Fence sprite is managed by FenceConnectionManager — apply atlas texture
		FenceConnectionManager.update_fence_sprite(sprite, b_cell, b_type, placed_buildings)
	else:
		# Fallback: try runtime load if preload was null at compile time (e.g. newly added textures)
		if not tex:
			if ResourceLoader.exists("res://assets/generated/building_windmill_frame_0.png") and b_type == BuildingType.WINDMILL:
				tex = load("res://assets/generated/building_windmill_frame_0.png")
			elif ResourceLoader.exists("res://assets/generated/building_well_frame_0.png") and b_type == BuildingType.WELL:
				tex = load("res://assets/generated/building_well_frame_0.png")
			elif ResourceLoader.exists("res://assets/generated/building_silo_frame_0.png") and b_type == BuildingType.SILO:
				tex = load("res://assets/generated/building_silo_frame_0.png")
			elif ResourceLoader.exists("res://assets/generated/building_scarecrow_frame_0.png") and b_type == BuildingType.SCARECROW:
				tex = load("res://assets/generated/building_scarecrow_frame_0.png")
			elif ResourceLoader.exists("res://assets/generated/building_compost_bin_frame_0.png") and b_type == BuildingType.COMPOST_BIN:
				tex = load("res://assets/generated/building_compost_bin_frame_0.png")
		if tex:
			sprite.texture = tex
		else:
			var img_size: int = b_width * cell_size
			var img := Image.create(img_size, b_height * cell_size, false, Image.FORMAT_RGBA8)
			img.fill(Color(0.0, 0.0, 0.0, 0.0))
			_draw_building_sprite(img, building_data, img_size)
			sprite.texture = ImageTexture.create_from_image(img)
	
	# Building size in pixels (for collision shapes)
	var area_size := Vector2(b_width * cell_size, b_height * cell_size)
	
	# ── Physics blocker: prevents player from walking through the building ──
	# Interior buildings get a blocker sized to match visible sprite content (not
	# the full tile footprint), shrunk slightly inside the visible edges so the
	# player can walk right up to the building wall without feeling invisible
	# padding. Fences (wood, stone) block the player, but gates do not — the
	# player should be able to walk through gates as intended openings.
	var should_add_blocker: bool = b_has_interior or \
		b_type == BuildingType.FENCE or b_type == BuildingType.STONE_FENCE
	if should_add_blocker:
		var blocker := StaticBody2D.new()
		blocker.name = "BuildingCollision"
		var block_shape := CollisionShape2D.new()
		block_shape.shape = RectangleShape2D.new()
		
		if b_has_interior:
			var blocker_tex := tex if tex else sprite.texture
			var blocker_size := area_size
			if blocker_tex:
				var content_bounds: Rect2 = _get_texture_content_bounds(blocker_tex)
				if content_bounds.size.x > 0 and content_bounds.size.y > 0:
					# Shrink well inside the visible sprite edge so the player can
					# get right up to the building for easy interaction.
					blocker_size = content_bounds.size - Vector2(8.0, 8.0)
					# Clamp: at least 12×12, at most the tile footprint
					blocker_size.x = clampf(blocker_size.x, 12.0, area_size.x)
					blocker_size.y = clampf(blocker_size.y, 12.0, area_size.y)
			block_shape.shape.size = blocker_size
		else:
			# Fence: 1×1 tile — use the full tile as a solid blocker
			block_shape.shape.size = Vector2(16.0, 16.0)
		
		blocker.add_child(block_shape)
		blocker.collision_layer = 8  # Building collision layer (player collides with this outside)
		blocker.collision_mask = 0
		node.add_child(blocker)
	
	# ── Interactable entry: press E to enter / interact ──
	if b_has_interior:
		# Interior buildings: press E to enter
		var entry_interactable := Interactable.new()
		entry_interactable.name = "BuildingEntry"
		entry_interactable.collision_layer = 4
		entry_interactable.interaction_prompt = "Enter"
		var entry_shape := CollisionShape2D.new()
		entry_shape.shape = RectangleShape2D.new()
		entry_shape.shape.size = area_size
		entry_interactable.add_child(entry_shape)
		# Position at (0,0) so the entry rectangle (size = full building footprint)
		# covers the entire building, letting the player interact from any side.
		entry_interactable.position = Vector2.ZERO
		entry_interactable.interacted.connect(_on_enter_interior.bind(b_type, b_cell, world_ref, node))
		node.add_child(entry_interactable)
	else:
		# Non-interior buildings that already have their own Interactable children
		# (STORAGE_SHED, DECORATIVE_BENCH, SILO) need no extra Interactable here.
		# For CAMPFIRE, add a proximity Area2D so the K hotkey cooking works.
		# Uses a 3×3 tile area (48×48 px) centered on the campfire so the
		# player can stand on any adjacent tile and press K to cook.
		if b_type == BuildingType.CAMPFIRE:
			var campfire_prox := Area2D.new()
			campfire_prox.name = "CampfireProximity"
			campfire_prox.collision_layer = 0
			campfire_prox.collision_mask = 2
			var prox_shape := CollisionShape2D.new()
			prox_shape.shape = RectangleShape2D.new()
			prox_shape.shape.size = Vector2(cell_size * 3, cell_size * 3)
			campfire_prox.add_child(prox_shape)
			campfire_prox.position = Vector2.ZERO
			campfire_prox.scale = Vector2(1, 1)
			campfire_prox.body_entered.connect(func(b: Node) -> void:
				if b.is_in_group("player"):
					GameManager.near_campfire = true
			)
			campfire_prox.body_exited.connect(func(b: Node) -> void:
				if b.is_in_group("player"):
					GameManager.near_campfire = false
			)
			node.add_child(campfire_prox)
	
	# For STORAGE_SHED, add an Interactable with a container inventory
	if b_type == BuildingType.STORAGE_SHED:
		_setup_shed_storage(node, building_data, b_width, b_height)
	
	# For DECORATIVE_BENCH, add an Interactable for sitting
	if b_type == BuildingType.DECORATIVE_BENCH:
		_setup_bench_interaction(node)
	
	# For HOTEL, add a Hotel node for visitor income management
	if b_type == BuildingType.HOTEL:
		_setup_hotel(node)
	
	# For SILO, add a Silo node for crop storage
	if b_type == BuildingType.SILO:
		_setup_silo(node)
	
	# For WINDMILL, add a Windmill node for storage
	if b_type == BuildingType.WINDMILL:
		_setup_windmill(node, building_data, b_width, b_height)
	
	# ── Light emission for campfire ──
	if b_type == BuildingType.CAMPFIRE:
		var light_node := PointLight2D.new()
		light_node.name = "BuildingLight"
		light_node.energy = 1.5
		light_node.texture_scale = 1.2
		light_node.color = Color(1.0, 0.5, 0.1, 0.9)
		light_node.range_item_cull_mask = 1
		light_node.shadow_enabled = false
		light_node.texture = LightUtils.make_light_texture(64)
		node.add_child(light_node)

## Scans a texture to find the bounding box of non-transparent content.
## Returns a Rect2 with the content area, or an empty Rect2 if all transparent.
## Used to size collision blockers to the visible sprite, not the padded texture.
func _get_texture_content_bounds(tex: Texture2D) -> Rect2:
	if not tex:
		return Rect2()
	var img: Image = tex.get_image()
	if not img:
		return Rect2()
	var w: int = tex.get_width()
	var h: int = tex.get_height()
	var min_x: int = w
	var max_x: int = 0
	var min_y: int = h
	var max_y: int = 0
	
	for x in range(w):
		for y in range(h):
			if img.get_pixel(x, y).a > 0.02:
				if x < min_x: min_x = x
				if x > max_x: max_x = x
				if y < min_y: min_y = y
				if y > max_y: max_y = y
	
	if min_x >= w or max_x <= 0 or min_y >= h or max_y <= 0:
		return Rect2()  # empty or fully transparent
	
	return Rect2(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)

## Called when the player presses E near an interior building.
## Creates the interior dynamically and enters it.
func _on_enter_interior(interactor: Node, b_type: int, b_cell: Vector2i, world_ref: Node, building_node: Node) -> void:
	var b_data: Dictionary = BUILDING_DATA.get(b_type, {})
	if not b_data.get("has_interior", false):
		return
	# Prevent entering a building while sitting on a bench (sitting sets
	# velocity to zero and skips movement, so the player would be stuck).
	if "is_sitting" in interactor and interactor.is_sitting:
		ToastNotification.show_toast("Stand up from the bench first.", ToastNotification.ToastType.WARNING, 1.5)
		return
	var interior := BuildingInterior.new()
	if interior and world_ref.has_method("enter_building"):
		interior.setup(b_type, b_cell)
		# For hotels, pass the Hotel reference so the front desk can collect gold
		if b_type == BuildingType.HOTEL:
			var hotel := _find_hotel_on_building(building_node)
			if hotel:
				interior.set_hotel_reference(hotel)
		# Find and pass resident info so the NPC appears in the interior
		var resident_data := _find_resident_for_building(b_cell, building_node)
		if not resident_data.is_empty():
			interior.set_resident_info(resident_data.name, resident_data.visitor_type)
		world_ref.enter_building(interior)

## Called when the player presses E near a decorative building.
func _on_examine_building_interacted(_interactor: Node, b_name: String) -> void:
	ToastNotification.show_toast(b_name, ToastNotification.ToastType.INFO, 2.0)

## Set up an Interactable with ContainerInventory for a STORAGE_SHED
func _setup_shed_storage(parent_node: Node, building_data: Dictionary, width: int, height: int) -> void:
	var interactable := Area2D.new()
	interactable.name = "ShedStorage"
	interactable.set_script(preload("res://scripts/world/Interactable.gd"))
	interactable.collision_layer = 4
	interactable.monitoring = true
	interactable.monitorable = true
	interactable.interaction_prompt = "Open Storage Shed"

	var shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = Vector2(width * 16, height * 16)
	shape.shape = rect_shape
	interactable.add_child(shape)
	parent_node.add_child(interactable)

	# Create container and restore from save data if available
	var container := ContainerInventory.new(18)
	var saved_slots: Array = building_data.get("container_slots", [])
	if saved_slots.size() > 0:
		container.slots = saved_slots.duplicate(true)

	# Link container slots to building_data so serialize() captures changes
	building_data["container_slots"] = container.slots

	interactable.set_meta("container_inventory", container)
	var cell: Vector2i = building_data.get("cell", Vector2i())
	interactable.set_meta("chest_key", "%d,%d" % [cell.x, cell.y])
	interactable.interacted.connect(_on_shed_interacted.bind(interactable))


## Set up an Interactable for bench sitting.
func _setup_bench_interaction(parent_node: Node) -> void:
	var interactable := Area2D.new()
	interactable.name = "BenchSit"
	interactable.set_script(preload("res://scripts/world/Interactable.gd"))
	
	# CRITICAL: Must match PlayerInteractor.collision_mask = 4 (layer 3).
	# Without this, the PlayerInteractor never detects the BenchSit area.
	interactable.collision_layer = 4
	interactable.monitoring = true
	interactable.monitorable = true
	
	# Show a clear prompt in the HUD instead of generic "[E] Interact"
	interactable.interaction_prompt = "Sit on the bench"
	
	# Generous detection rectangle — wider than the bench tile (16px) so the
	# player can easily trigger it from either side.
	var rect_shape := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(40, 24)
	rect_shape.shape = shape
	interactable.add_child(rect_shape)
	parent_node.add_child(interactable)
	interactable.interacted.connect(_on_bench_interacted.bind(interactable))

## Set up a Hotel building with a Hotel script child for visitor income.
func _setup_hotel(parent_node: Node) -> void:
	var hotel := Hotel.new()
	hotel.name = "HotelLogic"
	parent_node.add_child(hotel)

## Set up a Windmill building with a Windmill script child for storage.
func _setup_windmill(parent_node: Node, building_data: Dictionary, width: int, height: int) -> void:
	var windmill := Windmill.new()
	windmill.name = "WindmillLogic"
	windmill.setup(building_data, width, height)
	parent_node.add_child(windmill)

## Set up a Silo building with a Silo script child for crop storage.
func _setup_silo(parent_node: Node) -> void:
	var silo := Silo.new()
	silo.name = "SiloLogic"
	parent_node.add_child(silo)


## Find the Hotel child on the given building node.
func _find_hotel_on_building(building_node: Node) -> Hotel:
	if not building_node:
		return null
	for child in building_node.get_children():
		if child is Hotel:
			return child
	return null


## Find a recruited resident whose home position matches the given building cell.
## Returns a dict {name, visitor_type} or an empty dict if none found.
func _find_resident_for_building(b_cell: Vector2i, tree_node: Node) -> Dictionary:
	if not tree_node or not tree_node.is_inside_tree():
		return {}
	var search_pos := Vector2(b_cell.x * 16 + 8, b_cell.y * 16 + 8)
	var residents: Array[Node] = tree_node.get_tree().get_nodes_in_group("town_residents")
	for r in residents:
		if r is TownResidentNPC:
			if r.global_position.distance_squared_to(search_pos) < 64.0:
				return {"name": r.npc_name, "visitor_type": r.visitor_type}
	return {}


## Handler: player sits on or stands up from a bench.
func _on_bench_interacted(interactor: Node, interactable: Area2D) -> void:
	var player: Player = interactor as Player if interactor is Player else Interactable._resolve_player(interactor)
	if not player:
		return
	if not ("is_sitting" in player):
		return
	if player.is_sitting:
		# Stand up — restore movement and visibility
		player.is_sitting = false
		player.visible = true
		player.sprite.play("idle")
		player._update_held_item()
		ToastNotification.show_toast("You stand up.", ToastNotification.ToastType.INFO, 1.5)
	else:
		# Sit down — teleport player to the bench. Keep the player visible but
		# switch to idle animation and hide the held item so they appear seated.
		player.is_sitting = true
		player.global_position = interactable.global_position
		player.visible = true
		player.sprite.play("idle")
		player.held_item.visible = false
		ToastNotification.show_toast("Sitting on the bench. Press [E] to stand up.", ToastNotification.ToastType.INFO, 2.5)

## Handler: opens the ChestStorageUI when player interacts with a shed
func _on_shed_interacted(_interactor: Node, interactable: Area2D) -> void:
	var tree := interactable.get_tree()
	if not tree:
		return
	var chest_ui: Node = tree.get_first_node_in_group("chest_storage_ui")
	var container: ContainerInventory = interactable.get_meta("container_inventory", null)
	if chest_ui and chest_ui.has_method("open_for") and container:
		var chest_key: String = interactable.get_meta("chest_key", "")
		chest_ui.open_for(container, "Storage Shed", Callable(), chest_key)


func _draw_building_sprite(img: Image, data: Dictionary, _img_size: int) -> void:
	var d_width: int = data.get("width", 1)
	var d_height: int = data.get("height", 1)
	var d_type: int = data.get("type", 0)
	var w: int = d_width * 16
	var h: int = d_height * 16
	
	match d_type:
		BuildingType.SMALL_HOME, BuildingType.MEDIUM_HOME, BuildingType.LARGE_HOME:
			_draw_house(img, w, h, data)
		BuildingType.BARN:
			_draw_barn(img, w, h)
		BuildingType.STORAGE_SHED:
			_draw_shed(img, w, h)
		BuildingType.FENCE:
			_draw_fence(img, w, h)
		BuildingType.STONE_FENCE:
			_draw_stone_fence(img, w, h)
		BuildingType.CAMPFIRE:
			_draw_campfire(img, w, h)
		BuildingType.GREENHOUSE:
			_draw_greenhouse(img, w, h)
		BuildingType.WINDMILL:
			_draw_windmill(img, w, h)
		BuildingType.SILO:
			_draw_silo(img, w, h)
		BuildingType.SCARECROW:
			_draw_scarecrow(img, w, h)
		_:
			_draw_default_building(img, w, h)

func _draw_house(img: Image, w: int, h: int, _data: Dictionary) -> void:
	var wall_color := Color(0.6, 0.4, 0.25)
	var roof_color := Color(0.5, 0.2, 0.1)
	var window_color := Color(0.6, 0.75, 0.9)
	
	# Walls
	for y in range(h / 3, h):
		for x in range(1, w - 1):
			img.set_pixel(x, y, wall_color)
			if x == 1 or x == w - 2:
				img.set_pixel(x, y, wall_color.darkened(0.2))
	
	# Roof (triangle)
	for y in range(0, h / 3):
		var roof_width := int((float(y) / float(h / 3)) * (w / 2))
		for x in range(w / 2 - roof_width, w / 2 + roof_width + 1):
			img.set_pixel(x, y, roof_color)
	
	# Door
	var door_x := w / 2
	var door_y := h - 4
	img.set_pixel(door_x, door_y, window_color)
	img.set_pixel(door_x + 1, door_y, window_color)
	
	# Windows
	if w > 24:
		img.set_pixel(4, h - 5, window_color)
		img.set_pixel(w - 5, h - 5, window_color)

func _draw_barn(img: Image, w: int, h: int) -> void:
	var wall_color := Color(0.7, 0.2, 0.1)
	var roof_color := Color(0.3, 0.2, 0.15)
	
	for y in range(h / 3, h):
		for x in range(w):
			img.set_pixel(x, y, wall_color)
	
	for y in range(0, h / 3):
		var roof_width := int((float(y) / float(h / 3)) * (w / 2 + 2))
		for x in range(w / 2 - roof_width, w / 2 + roof_width + 1):
			img.set_pixel(x, y, roof_color)

func _draw_shed(img: Image, w: int, h: int) -> void:
	var wall_color := Color(0.55, 0.4, 0.2)
	var roof_color := Color(0.4, 0.3, 0.15)
	
	for y in range(h / 3, h):
		for x in range(w):
			img.set_pixel(x, y, wall_color)
	
	for y in range(0, h / 3 + 1):
		for x in range(w):
			if y == 0 or x == 0 or x == w - 1:
				img.set_pixel(x, y, roof_color)
	
	# Door
	img.set_pixel(w / 2, h - 2, Color(0.4, 0.25, 0.1))

func _draw_fence(img: Image, w: int, h: int) -> void:
	var fence_color := Color(0.6, 0.4, 0.2)
	for y in range(h):
		if y == 2 or y == 5:
			for x in range(w):
				img.set_pixel(x, y, fence_color)
	for x in [0, w - 1]:
		for y in range(h):
			if y < 6:
				img.set_pixel(x, y, fence_color)

func _draw_stone_fence(img: Image, w: int, h: int) -> void:
	var stone_color := Color(0.5, 0.45, 0.4)
	for y in range(h - 4, h):
		for x in range(w):
			if randi() % 3 != 0:
				img.set_pixel(x, y, stone_color)
	# Top caps
	for x in range(0, w, 3):
		img.set_pixel(x, h - 5, stone_color)

func _draw_campfire(img: Image, w: int, h: int) -> void:
	var stone_color := Color(0.4, 0.35, 0.3)
	var fire_color := Color(1.0, 0.6, 0.1)
	var glow_color := Color(1.0, 0.8, 0.2)
	
	# Stones (circle)
	for x in range(-3, 4):
		for y in range(-3, 4):
			if x * x + y * y <= 10 and x * x + y * y >= 5:
				var px := w / 2 + x
				var py := h / 2 + y
				if px >= 0 and px < w and py >= 0 and py < h:
					img.set_pixel(px, py, stone_color)
	
	# Fire
	img.set_pixel(w / 2, h / 2 - 1, fire_color)
	img.set_pixel(w / 2 - 1, h / 2, fire_color)
	img.set_pixel(w / 2 + 1, h / 2, fire_color)
	img.set_pixel(w / 2, h / 2, glow_color)

func _draw_greenhouse(img: Image, w: int, h: int) -> void:
	var frame_color := Color(0.6, 0.5, 0.3)
	var glass_color := Color(0.7, 0.85, 0.9, 0.5)
	var base_color := Color(0.4, 0.35, 0.3)
	var plant_color := Color(0.2, 0.6, 0.2)
	
	# Stone base (bottom 6 rows)
	for y in range(h - 6, h):
		for x in range(w):
			img.set_pixel(x, y, base_color)
			if x == 0 or x == w - 1 or y == h - 6 or y == h - 1:
				img.set_pixel(x, y, Color(0.35, 0.3, 0.25))
			if x % 8 == 0 or x % 8 == 1:
				img.set_pixel(x, y, Color(0.38, 0.33, 0.28))
	
	# Glass walls
	var wall_top: int = max(0, h / 4)
	for y in range(wall_top, h - 6):
		for x in range(w):
			img.set_pixel(x, y, glass_color)
			if x == 0 or x == w - 1 or y == wall_top or y == h - 7:
				img.set_pixel(x, y, frame_color)
			if x % 8 == 0 or x % 8 == 1:
				img.set_pixel(x, y, frame_color)
			if y % 8 == 0 or y % 8 == 1:
				img.set_pixel(x, y, Color(0.55, 0.45, 0.25))
			if x % 16 == 8 and y % 12 == 4:
				img.set_pixel(x, y, plant_color)
				img.set_pixel(x, y + 1, plant_color)
				img.set_pixel(x, y - 1, plant_color)
	
	# Glass roof (peaked)
	for y in range(0, wall_top):
		var half_width := int(w / 2)
		var roof_left := half_width - y * 2
		var roof_right := half_width + y * 2 + 1
		for x in range(max(0, roof_left), min(w, roof_right)):
			img.set_pixel(x, y, glass_color)
			if x == roof_left or x == roof_right - 1:
				img.set_pixel(x, y, frame_color)
		if y % 3 == 2:
			for x in range(max(0, roof_left), min(w, roof_right)):
				if x % 6 < 2:
					img.set_pixel(x, y, frame_color)

func _draw_windmill(img: Image, w: int, h: int) -> void:
	var body_color := Color(0.7, 0.65, 0.6)
	var roof_color := Color(0.3, 0.25, 0.2)
	
	# Body (tapered tower)
	for y in range(h / 3, h):
		var taper := int((float(y - h / 3) / float(h * 2 / 3)) * (w / 4))
		for x in range(taper, w - taper):
			img.set_pixel(x, y, body_color)
	
	# Roof (cone)
	for y in range(0, h / 3):
		var r := int(lerpf(w / 2, 2, float(y) / float(h / 3)))
		for x in range(w / 2 - r, w / 2 + r + 1):
			img.set_pixel(x, y, roof_color)
	
	# Blades (cross shape) — larger for bigger canvas
	var blade_color := Color(0.5, 0.4, 0.3)
	var blade_len := h / 4
	for i in range(-blade_len + 2, blade_len - 2):
		img.set_pixel(w / 2 + i, h / 3, blade_color)
		img.set_pixel(w / 2, h / 3 + i, blade_color)
	# Blade hub
	img.set_pixel(w / 2, h / 3, Color(0.35, 0.25, 0.2))
	img.set_pixel(w / 2 - 1, h / 3 - 1, Color(0.35, 0.25, 0.2))
	img.set_pixel(w / 2 + 1, h / 3 + 1, Color(0.35, 0.25, 0.2))
	img.set_pixel(w / 2 - 1, h / 3 + 1, Color(0.35, 0.25, 0.2))
	img.set_pixel(w / 2 + 1, h / 3 - 1, Color(0.35, 0.25, 0.2))
	# Small window openings on tower body
	if w >= 8:
		var win_x := w / 2
		var win_y := h * 2 / 3
		img.set_pixel(win_x, win_y, Color(0.2, 0.15, 0.1))
		img.set_pixel(win_x, win_y - 1, Color(0.2, 0.15, 0.1))

func _draw_silo(img: Image, w: int, h: int) -> void:
	# Tall cylindrical stone silo with conical roof
	var wall_color := Color(0.5, 0.45, 0.4)
	var dark_color := Color(0.35, 0.3, 0.27)
	var roof_color := Color(0.3, 0.25, 0.2)
	var door_color := Color(0.45, 0.3, 0.15)
	
	# Conical stone roof (top ~1/4)
	var roof_height: int = max(1, h / 4)
	for y in range(roof_height):
		var center_x: int = w / 2
		var half_width: int = max(1, int(lerpf(w / 2 + 1, 3, float(y) / float(roof_height))))
		var left: int = center_x - half_width
		var right: int = center_x + half_width
		for x in range(max(0, left), min(w, right + 1)):
			img.set_pixel(x, y, roof_color)
			# Edge highlight for depth
			if x == left or x == right:
				img.set_pixel(x, y, dark_color)
		# Horizontal stone band every 2 rows
		if y % 2 == 0 and y < roof_height - 1:
			for x in range(max(0, left), min(w, right + 1)):
				img.set_pixel(x, y, roof_color.darkened(0.15))
	# Capstone accent at roof peak
	if w >= 5:
		img.set_pixel(w / 2, 0, dark_color)
		img.set_pixel(w / 2, 1, dark_color.lightened(0.15))
	
	# Stone body (vertical cylinder)
	var body_top: int = roof_height
	for y in range(body_top, h):
		# Slight taper to simulate cylinder perspective
		var taper: int = int(lerpf(0, 1, float(y - body_top) / float(h - body_top)))
		var left: int = taper
		var right: int = w - 1 - taper
		for x in range(left, right + 1):
			img.set_pixel(x, y, wall_color)
		# Dark edges for cylinder illusion
		for edge_x in [left, right]:
			img.set_pixel(edge_x, y, dark_color)
			img.set_pixel(edge_x + 1, y, wall_color.darkened(0.1))
		# Horizontal band lines every 4 rows (masonry courses)
		if (y - body_top) % 4 == 0 and y > body_top:
			for x in range(left, right + 1):
				img.set_pixel(x, y, wall_color.darkened(0.12))
		# Subtle vertical mortar lines occasionally
		if (y + left) % 6 == 0 and left + 3 < right:
			img.set_pixel(left + 3, y, dark_color)
		if (y + right) % 7 == 0 and right - 3 > left:
			img.set_pixel(right - 3, y, dark_color)
	
	# Large wooden door at bottom center — scales with building
	var door_w: int = maxi(2, w / 8)
	var door_h: int = maxi(2, h / 8)
	var door_x: int = w / 2 - door_w / 2
	var door_y: int = h - door_h - 1
	for dy in range(door_h + 1):
		for dx in range(door_w):
			img.set_pixel(door_x + dx, door_y + dy, door_color)
		# Door frame sides
		img.set_pixel(door_x - 1, door_y + dy, dark_color)
		img.set_pixel(door_x + door_w, door_y + dy, dark_color)
	# Door frame top
	for dx in range(-1, door_w + 1):
		img.set_pixel(door_x + dx, door_y - 1, dark_color)


func _draw_scarecrow(img: Image, w: int, h: int) -> void:
	var post_color := Color(0.5, 0.3, 0.15)
	var hat_color := Color(0.8, 0.7, 0.1)
	var shirt_color := Color(0.7, 0.2, 0.15)
	var arm_color := Color(0.55, 0.35, 0.15)
	# Post (vertical stick)
	for y in range(4, h):
		img.set_pixel(w / 2, y, post_color)
	# Cross arm
	for x in range(1, w - 1):
		img.set_pixel(x, h / 2 - 1, arm_color)
	# Body (red shirt)
	for y in range(h / 2 + 1, h - 2):
		for x in range(w / 2 - 2, w / 2 + 3):
			if randf() > 0.2:
				img.set_pixel(x, y, shirt_color)
	# Straw hat
	for x in range(w / 2 - 3, w / 2 + 4):
		if x >= 0 and x < w:
			img.set_pixel(x, h / 2 - 3, hat_color)
			img.set_pixel(x, h / 2 - 2, hat_color.darkened(0.2))
	# Head
	img.set_pixel(w / 2, h / 2, Color(0.9, 0.75, 0.5))

func _draw_default_building(img: Image, w: int, h: int) -> void:
	var color := Color(0.6, 0.5, 0.4)
	for y in range(h):
		for x in range(w):
			if x == 0 or x == w - 1 or y == 0 or y == h - 1:
				img.set_pixel(x, y, color)

## Returns the building data at a specific cell, or null if no building occupies that cell.
func get_building_at(cell: Vector2i) -> Dictionary:
	for b in placed_buildings:
		var b_cell: Vector2i = _parse_cell(b.get("cell", Vector2i(0, 0)))
		var b_w: int = b.get("width", 1)
		var b_h: int = b.get("height", 1)
		if cell.x >= b_cell.x and cell.x < b_cell.x + b_w and cell.y >= b_cell.y and cell.y < b_cell.y + b_h:
			return b
	return {}

## Returns true if any building occupies the given cell.
func is_occupied(cell: Vector2i) -> bool:
	return not get_building_at(cell).is_empty()

## Returns true if a building matching one of the given types occupies the cell.
func is_building_type_at(cell: Vector2i, types: Array) -> bool:
	var b := get_building_at(cell)
	if b.is_empty():
		return false
	return types.has(b.get("type", -1))


## Checks if any building of the given types exists within `range_cells` of the cell.
func is_near_building_type(cell: Vector2i, types: Array, range_cells: int) -> bool:
	for b in placed_buildings:
		var b_cell: Vector2i = _parse_cell(b.get("cell", Vector2i(0, 0)))
		var b_w: int = b.get("width", 1)
		var b_h: int = b.get("height", 1)
		if not types.has(b.get("type", -1)):
			continue
		# Check if cell is within range_cells of the building's bounding box
		var nearest_x := clampi(cell.x, b_cell.x, b_cell.x + b_w - 1)
		var nearest_y := clampi(cell.y, b_cell.y, b_cell.y + b_h - 1)
		var dx := absi(cell.x - nearest_x)
		var dy := absi(cell.y - nearest_y)
		if dx <= range_cells and dy <= range_cells:
			return true
	return false


## Serialize all placed buildings for save/load
func serialize() -> Dictionary:
	return {
		"placed_buildings": placed_buildings.duplicate(true)
	}

## Helper: parse a Vector2i from a string like "(42, 18)" or return as-is
func _parse_cell(value) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Vector2:
		return Vector2i(value)
	if value is String:
		var s: String = value.strip_edges().trim_prefix("(").trim_suffix(")")
		var parts: PackedStringArray = s.split(",")
		if parts.size() >= 2:
			return Vector2i(int(parts[0].strip_edges()), int(parts[1].strip_edges()))
	return Vector2i(0, 0)

## Deserialize buildings from save data
func deserialize(data: Dictionary, world_ref: Node) -> void:
	placed_buildings.clear()
	var buildings_data: Array = data.get("placed_buildings", [])
	var fence_cells: Array[Vector2i] = []
	for b in buildings_data:
		if b is Dictionary:
			var bld_dict: Dictionary = b as Dictionary
			# Convert "cell" from serialized string back to Vector2i
			if bld_dict.has("cell"):
				bld_dict["cell"] = _parse_cell(bld_dict["cell"])
			placed_buildings.append(bld_dict)
			_create_building_node(bld_dict, world_ref)
			if BUILDING_DATA.get(bld_dict.get("type", -1), {}).get("is_fence", false):
				fence_cells.append(bld_dict["cell"] as Vector2i)
	# Refresh all fence visuals so connections are correct after loading
	for cell: Vector2i in fence_cells:
		FenceConnectionManager.update_neighbor_fences(cell, self, world_ref)

## Check if player has a home (for sleeping/saving)
func has_home() -> bool:
	for b in placed_buildings:
		if b is Dictionary:
			var home_types: Array = [BuildingType.SMALL_HOME, BuildingType.MEDIUM_HOME, BuildingType.LARGE_HOME]
			if home_types.has(b.get("type", 0)):
				return true
	return false
