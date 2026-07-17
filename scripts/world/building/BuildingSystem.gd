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
	BRIDGE = 9,
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
}

## Pre-made textures for key buildings — use these instead of procedural drawing
const PREMADE_TEXTURES: Dictionary = {
	BuildingType.SMALL_HOME: preload("res://assets/generated/building_small_home_frame_0.png"),
	BuildingType.CAMPFIRE: preload("res://assets/generated/building_campfire_frame_0.png"),
	BuildingType.STORAGE_SHED: preload("res://assets/generated/building_storage_shed_frame_0.png"),
	BuildingType.DECORATIVE_BENCH: preload("res://assets/generated/building_bench_frame_0.png"),
}

const BUILDING_DATA: Dictionary = {
	BuildingType.SMALL_HOME: {
		"name": "Small Home",
		"width": 3, "height": 3,
		"has_interior": true,
		"interior_scene": "res://scenes/buildings/small_home_interior.tscn",
		"ingredients": {"wood": 20, "stone": 10},
		"description": "A cozy small home to shelter from the elements."
	},
	BuildingType.MEDIUM_HOME: {
		"name": "Medium Home",
		"width": 4, "height": 3,
		"has_interior": true,
		"interior_scene": "res://scenes/buildings/medium_home_interior.tscn",
		"ingredients": {"wood": 40, "stone": 20, "wooden_planks": 15},
		"description": "A comfortable home with room for furnishings."
	},
	BuildingType.LARGE_HOME: {
		"name": "Large Home",
		"width": 5, "height": 4,
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
		"ingredients": {"wood": 2},
		"description": "A simple wooden fence to mark boundaries."
	},
	BuildingType.STONE_FENCE: {
		"name": "Stone Fence",
		"width": 1, "height": 1,
		"has_interior": false,
		"ingredients": {"stone": 3},
		"description": "A sturdy stone fence."
	},
	BuildingType.GATE: {
		"name": "Gate",
		"width": 1, "height": 1,
		"has_interior": false,
		"ingredients": {"wood": 5, "stone": 2},
		"description": "A wooden gate for fence openings."
	},
	BuildingType.GARDEN_BED: {
		"name": "Garden Bed",
		"width": 2, "height": 1,
		"has_interior": false,
		"ingredients": {"wood": 8, "wooden_planks": 4},
		"description": "A raised garden bed for growing crops."
	},
	BuildingType.BRIDGE: {
		"name": "Bridge",
		"width": 1, "height": 3,
		"has_interior": false,
		"ingredients": {"wood": 15, "stone": 10},
		"description": "A small bridge to cross water."
	},
	BuildingType.CAMPFIRE: {
		"name": "Campfire",
		"width": 1, "height": 1,
		"has_interior": false,
		"ingredients": {"wood": 5, "stone": 3},
		"description": "A cozy campfire for cooking and light."
	},
	BuildingType.WORKSHOP: {
		"name": "Workshop",
		"width": 3, "height": 2,
		"has_interior": true,
		"interior_scene": "res://scenes/buildings/workshop_interior.tscn",
		"ingredients": {"wood": 35, "stone": 20, "wooden_planks": 15},
		"description": "A workshop with crafting stations."
	},
	BuildingType.WINDMILL: {
		"name": "Windmill",
		"width": 2, "height": 2,
		"has_interior": false,
		"ingredients": {"wood": 50, "stone": 30, "wooden_planks": 20},
		"description": "A windmill for processing grain."
	},
	BuildingType.GREENHOUSE: {
		"name": "Greenhouse",
		"width": 3, "height": 2,
		"has_interior": true,
		"interior_scene": "res://scenes/buildings/greenhouse_interior.tscn",
		"ingredients": {"wood": 25, "stone": 10, "wooden_planks": 20},
		"description": "A glass greenhouse for year-round growing."
	},
	BuildingType.DECORATIVE_STATUE: {
		"name": "Decorative Statue",
		"width": 1, "height": 1,
		"has_interior": false,
		"ingredients": {"stone": 20},
		"description": "A beautiful stone statue."
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
		"width": 2, "height": 2,
		"has_interior": false,
		"ingredients": {"stone": 25, "wood": 10},
		"description": "A silo for bulk crop storage."
	},
	BuildingType.WELL: {
		"name": "Well",
		"width": 1, "height": 1,
		"has_interior": false,
		"ingredients": {"stone": 15},
		"description": "A well providing fresh water."
	},
}

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
				if not tile_type or (not tile_type.walkable and tile_id != "tilled" and tile_id != "watered_tilled"):
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

func place_building(building_type: int, cell: Vector2i, rotation: int, world_ref: Node) -> bool:
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
	
	# Create visual node
	_create_building_node(building_data, world_ref)
	
	return true

func remove_building(cell: Vector2i, world_ref: Node) -> bool:
	for i in range(placed_buildings.size()):
		var b = placed_buildings[i]
		if b.cell == cell:
			building_removed.emit(b.type, cell)
			placed_buildings.remove_at(i)
			
			# Remove visual node
			var node_name := "Building_%d_%d" % [cell.x, cell.y]
			var obj_root: Node = world_ref.get_node_or_null("Objects")
			if obj_root:
				var node: Node = obj_root.get_node_or_null(node_name)
				if node:
					node.queue_free()
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
	
	# Draw building sprite — prefer pre-made texture when available
	var sprite := Sprite2D.new()
	node.add_child(sprite)
	
	var tex: Texture2D = PREMADE_TEXTURES.get(b_type)
	if tex:
		sprite.texture = tex
	else:
		var img_size: int = b_width * cell_size
		var img := Image.create(img_size, b_height * cell_size, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.0, 0.0, 0.0, 0.0))
		_draw_building_sprite(img, building_data, img_size)
		sprite.texture = ImageTexture.create_from_image(img)
	
	# Always add an Area2D so the player can interact
	var area_size := Vector2(b_width * cell_size, b_height * cell_size)
	var area := Area2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = area_size
	shape.shape = rect
	area.add_child(shape)
	node.add_child(area)
	area.monitorable = true
	area.monitoring = true
	# Detect player (on collision_layer 2)
	area.collision_mask = 2
	
	area.set_meta("building_type", b_type)
	area.set_meta("building_cell", b_cell)
	area.set_meta("is_building", true)
	
	if b_has_interior:
		# Store interior data and connect interior entry
		area.set_meta("interior_scene", b_interior_scene)
		area.body_entered.connect(_on_body_entered_building.bind(area, world_ref))
	else:
		# Non-interior buildings show a prompt via area_entered
		area.body_entered.connect(_on_body_entered_non_interior.bind(area))

func _on_body_entered_building(body: Node, area: Area2D, world_ref: Node) -> void:
	if body.is_in_group("player"):
		var b_type: int = area.get_meta("building_type", 0)
		var b_cell: Vector2i = area.get_meta("building_cell", Vector2i(0, 0))
		if b_type >= 0 and b_type <= BuildingType.WELL:
			var b_data: Dictionary = BUILDING_DATA.get(b_type, {})
			if b_data.get("has_interior", false):
				# Generate interior dynamically using BuildingInterior class
				var interior := BuildingInterior.new()
				if interior and world_ref.has_method("enter_building"):
					interior.setup(b_type, b_cell)
					world_ref.enter_building(interior)

func _on_body_entered_non_interior(body: Node, area: Area2D) -> void:
	if not body.is_in_group("player"):
		return
	var b_type: int = area.get_meta("building_type", 0)
	var b_name: String = BUILDING_DATA.get(b_type, {}).get("name", "Building")
	match b_type:
		BuildingType.CAMPFIRE:
			ToastNotification.show_toast("Campfire — gather ingredients and cook!", ToastNotification.ToastType.INFO, 2.5)
		BuildingType.STORAGE_SHED:
			ToastNotification.show_toast("Storage Shed — press I to view inventory", ToastNotification.ToastType.INFO, 2.5)
		BuildingType.DECORATIVE_BENCH:
			ToastNotification.show_toast("A quiet spot to rest.", ToastNotification.ToastType.INFO, 2.5)
		_:
			ToastNotification.show_toast(b_name, ToastNotification.ToastType.INFO, 2.0)

func _draw_building_sprite(img: Image, data: Dictionary, img_size: int) -> void:
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
		_:
			_draw_default_building(img, w, h)

func _draw_house(img: Image, w: int, h: int, data: Dictionary) -> void:
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
	
	for y in range(h / 3, h):
		for x in range(w):
			img.set_pixel(x, y, glass_color)
			if x == 0 or x == w - 1 or y == h / 3 or y == h - 1:
				img.set_pixel(x, y, frame_color)
			if x % 6 == 0 or x % 6 == 1:
				img.set_pixel(x, y, frame_color)
	
	# Glass roof
	for y in range(0, h / 3):
		for x in range(y, w - y):
			img.set_pixel(x, y, glass_color)
			if x == y or x == w - y - 1:
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
	
	# Blades (cross shape)
	var blade_color := Color(0.5, 0.4, 0.3)
	for i in range(-h / 4 + 2, h / 4 - 2):
		img.set_pixel(w / 2 + i, h / 3, blade_color)
		img.set_pixel(w / 2, h / 3 + i, blade_color)

func _draw_default_building(img: Image, w: int, h: int) -> void:
	var color := Color(0.6, 0.5, 0.4)
	for y in range(h):
		for x in range(w):
			if x == 0 or x == w - 1 or y == 0 or y == h - 1:
				img.set_pixel(x, y, color)

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
	for b in buildings_data:
		if b is Dictionary:
			var bld_dict: Dictionary = b as Dictionary
			# Convert "cell" from serialized string back to Vector2i
			if bld_dict.has("cell"):
				bld_dict["cell"] = _parse_cell(bld_dict["cell"])
			placed_buildings.append(bld_dict)
			_create_building_node(bld_dict, world_ref)

## Check if player has a home (for sleeping/saving)
func has_home() -> bool:
	for b in placed_buildings:
		if b is Dictionary:
			var home_types: Array = [BuildingType.SMALL_HOME, BuildingType.MEDIUM_HOME, BuildingType.LARGE_HOME]
			if home_types.has(b.get("type", 0)):
				return true
	return false
