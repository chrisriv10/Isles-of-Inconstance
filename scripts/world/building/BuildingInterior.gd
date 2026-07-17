extends Node2D
class_name BuildingInterior

## Creates a building interior scene dynamically when the player enters a
## building. Furnishings, lighting, and stations are generated based on
## building type.

enum InteriorType { SMALL_HOME, MEDIUM_HOME, LARGE_HOME, BARN, WORKSHOP, GREENHOUSE }

var interior_type: int
var building_cell: Vector2i

# Room dimensions (set by _generate_interior)
var _room_width: int = 0
var _room_height: int = 0

# References to furniture nodes
var crafting_station: Area2D = null
var cooking_station: Area2D = null
var storage_chest: Area2D = null
var _chest_inventory: ContainerInventory = null
var bed: Area2D = null

signal exited_interior()

# Preloaded pixel art textures for furniture
const FURNITURE_BED := preload("res://assets/generated/furniture_bed_frame_0.png")
const FURNITURE_CRAFTING := preload("res://assets/generated/furniture_crafting_frame_0.png")
const FURNITURE_CHEST := preload("res://assets/generated/furniture_chest_frame_0.png")
const FURNITURE_COOKING := preload("res://assets/generated/furniture_cooking_frame_0.png")
const FURNITURE_TABLE := preload("res://assets/generated/furniture_table_frame_0.png")
const INTERACTABLE_SCRIPT := preload("res://scripts/world/Interactable.gd")

func setup(type: int, cell: Vector2i) -> void:
	interior_type = type
	building_cell = cell
	_generate_interior()

func _generate_interior() -> void:
	match interior_type:
		InteriorType.SMALL_HOME:
			_generate_small_home()
		InteriorType.MEDIUM_HOME:
			_generate_medium_home()
		InteriorType.LARGE_HOME:
			_generate_large_home()
		InteriorType.BARN:
			_generate_barn()
		InteriorType.WORKSHOP:
			_generate_workshop()
		InteriorType.GREENHOUSE:
			_generate_greenhouse()
	# Add invisible collision walls around the room perimeter
	if _room_width > 0 and _room_height > 0:
		_add_room_walls(_room_width, _room_height)

func _create_floor(width: int, height: int) -> void:
	var floor_sprite := Sprite2D.new()
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.3, 0.25, 0.2))
	
	# Wooden floor pattern
	for y in range(0, height, 4):
		for x in range(0, width, 16):
			var plank_color := Color(0.35, 0.28, 0.22)
			if (x / 16 + y / 4) % 2 == 0:
				plank_color = Color(0.3, 0.24, 0.19)
			for py in range(y, min(y + 4, height)):
				for px in range(x, min(x + 16, width)):
					img.set_pixel(px, py, plank_color)
	
	floor_sprite.texture = ImageTexture.create_from_image(img)
	floor_sprite.position = Vector2(width / 2, height / 2)
	floor_sprite.z_index = 1
	add_child(floor_sprite)

func _create_wall_sprite(width: int, height: int, color: Color) -> void:
	# Full-void background — covers the viewport so no world/void shows through
	var bg := ColorRect.new()
	bg.color = color
	# Large enough to cover viewport at 4× zoom after scaling (1600 local pixels at 3× = 4800 world pixels)
	bg.size = Vector2(1600, 1200)
	bg.position = Vector2(-800, -600)
	bg.z_index = -2
	add_child(bg)

func _add_room_walls(width: int, height: int) -> void:
	# Add invisible StaticBody2D walls around the room perimeter
	# so the player can't walk through the walls.
	var wall_thickness := 8
	
	# Helper to create a wall segment
	var add_wall := func(x: float, y: float, w: float, h: float) -> void:
		var wall := StaticBody2D.new()
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(w, h)
		shape.shape = rect
		wall.add_child(shape)
		wall.position = Vector2(x, y)
		add_child(wall)
	
	# Left wall
	add_wall.call(-wall_thickness / 2.0, height / 2.0, wall_thickness, height)
	# Right wall
	add_wall.call(width + wall_thickness / 2.0, height / 2.0, wall_thickness, height)
	# Top wall
	add_wall.call(width / 2.0, -wall_thickness / 2.0, width, wall_thickness)
	# Bottom wall
	add_wall.call(width / 2.0, height + wall_thickness / 2.0, width, wall_thickness)

func _add_exit_door(pos: Vector2 = Vector2(32, 80)) -> void:
	# Door collision area
	var door_area := Area2D.new()
	door_area.collision_mask = 2
	var door_shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(20, 28)
	door_shape.shape = rect
	door_area.add_child(door_shape)
	door_area.position = pos
	door_area.body_entered.connect(_on_exit_entered)
	add_child(door_area)
	
	# Draw a proper door sprite (20x28)
	var door_sprite := Sprite2D.new()
	var door_img := Image.create(20, 28, false, Image.FORMAT_RGBA8)
	door_img.fill(Color(0.0, 0.0, 0.0, 0.0))  # transparent
	
	# Door frame (darker wood border)
	var frame_color := Color(0.35, 0.2, 0.08)
	for y in range(28):
		for x in [0, 1, 18, 19]:
			door_img.set_pixel(x, y, frame_color)
	# Top/bottom frame
	for x in range(20):
		for y in [0, 1, 26, 27]:
			door_img.set_pixel(x, y, frame_color)
	
	# Door panel (lighter wood)
	var panel_color := Color(0.5, 0.32, 0.15)
	for y in range(2, 26):
		for x in range(2, 18):
			door_img.set_pixel(x, y, panel_color)
	# Vertical plank lines
	var line_color := Color(0.42, 0.27, 0.12)
	for x in [4, 7, 10, 13, 16]:
		for y in range(2, 26):
			door_img.set_pixel(x, y, line_color)
	# Horizontal plank lines
	for y in [6, 12, 18, 22]:
		for x in range(2, 18):
			door_img.set_pixel(x, y, line_color)
	
	# Door knob (small circle)
	var knob_color := Color(0.8, 0.7, 0.3)
	door_img.set_pixel(15, 15, knob_color)
	door_img.set_pixel(15, 14, knob_color)
	door_img.set_pixel(15, 16, knob_color)
	
	# Yellow glow / arrow above the door
	var arrow_color := Color(1.0, 0.9, 0.3)
	for y_offset in range(4):
		var bx := 8 - y_offset
		var ex := 11 + y_offset
		for x in range(bx, ex + 1):
			door_img.set_pixel(x, -y_offset - 2 + 28, Color(arrow_color.r, arrow_color.g, arrow_color.b, 0.6 + 0.4 * (1.0 - y_offset / 4.0)))
	# Top point of arrow
	door_img.set_pixel(9, -4 + 28, arrow_color)
	door_img.set_pixel(10, -4 + 28, arrow_color)
	
	door_sprite.texture = ImageTexture.create_from_image(door_img)
	door_sprite.position = pos
	door_sprite.z_index = 2
	add_child(door_sprite)
	# Note: no text label — the door sprite is self-explanatory

func _on_exit_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_exit_interior()

func _exit_interior() -> void:
	exited_interior.emit()
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_exit_interior()
		get_viewport().set_input_as_handled()

func _add_decorative(pos: Vector2, color: Color, width: int, height: int) -> void:
	# Simple non-interactive decorative sprite (just visual, no interaction)
	var sprite := Sprite2D.new()
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	img.fill(color)
	# Dark border
	var border := Color(color.r * 0.5, color.g * 0.5, color.b * 0.5, 1.0)
	for x in range(width):
		img.set_pixel(x, 0, border)
		img.set_pixel(x, height - 1, border)
	for y in range(height):
		img.set_pixel(0, y, border)
		img.set_pixel(width - 1, y, border)
	sprite.texture = ImageTexture.create_from_image(img)
	sprite.position = pos
	sprite.z_index = 2
	add_child(sprite)

func _add_interactable_furniture(pos: Vector2, texture: Texture2D, prompt: String, width: int, height: int) -> Interactable:
	# Creates a furniture piece as an Interactable Area2D so the PlayerInteractor
	# detects it and the HUD shows the interaction prompt at the bottom of the screen.
	var interactable := Interactable.new()
	# Set on collision layer 3 (bit 2 = value 4) so PlayerInteractor (mask=4) detects it
	interactable.collision_layer = 4
	interactable.interaction_prompt = prompt
	
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, height)
	shape.shape = rect
	interactable.add_child(shape)
	interactable.position = pos
	
	# Pixel art sprite above the floor (z=1)
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.z_index = 2
	interactable.add_child(sprite)
	
	add_child(interactable)
	return interactable

func _add_bed(pos: Vector2) -> Interactable:
	var bed_area := _add_interactable_furniture(pos, FURNITURE_BED, "Sleep", 32, 24)
	bed_area.interacted.connect(_on_bed_interacted)
	bed = bed_area
	return bed_area

func _on_bed_interacted(_interactor: Node) -> void:
	GameManager.current_minute_of_day = 6 * 60  # Wake at 6 AM
	GameManager.time_changed.emit(GameManager.get_hour(), GameManager.get_minute())
	ToastNotification.show_toast("Good morning! Slept through the night.", ToastNotification.ToastType.SUCCESS, 3.0)
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.flash_screen(Color.BLACK, 0.5)

func _add_crafting_station(pos: Vector2) -> Interactable:
	var station := _add_interactable_furniture(pos, FURNITURE_CRAFTING, "Craft", 28, 20)
	station.interacted.connect(_on_crafting_interacted)
	crafting_station = station
	return station

func _on_crafting_interacted(_interactor: Node) -> void:
	var crafting_ui: Node = get_tree().get_first_node_in_group("crafting_ui")
	if crafting_ui:
		crafting_ui.open()

func _add_cooking_station(pos: Vector2) -> Interactable:
	var station := _add_interactable_furniture(pos, FURNITURE_COOKING, "Cook", 24, 20)
	station.interacted.connect(_on_cooking_interacted)
	cooking_station = station
	return station

func _on_cooking_interacted(_interactor: Node) -> void:
	var cooking_ui: Node = get_tree().get_first_node_in_group("cooking_ui")
	if cooking_ui and cooking_ui.has_method("open"):
		cooking_ui.open()
	else:
		ToastNotification.show_toast("Cooking station!", ToastNotification.ToastType.INFO, 2.0)

func _add_storage_chest(pos: Vector2) -> Interactable:
	var chest := _add_interactable_furniture(pos, FURNITURE_CHEST, "Open Storage", 20, 16)
	chest.interacted.connect(_on_storage_interacted)
	storage_chest = chest
	# Give each chest its own inventory container (18 slots)
	_chest_inventory = ContainerInventory.new(18)
	return chest

func _on_storage_interacted(_interactor: Node) -> void:
	var chest_ui: CanvasLayer = get_tree().get_first_node_in_group("chest_storage_ui") as CanvasLayer
	if chest_ui and _chest_inventory:
		chest_ui.open_for(_chest_inventory, "Storage Chest")

func _add_table(pos: Vector2) -> Interactable:
	return _add_interactable_furniture(pos, FURNITURE_TABLE, "Examine", 24, 16)

func _add_baseboards(room_w: int, room_h: int) -> void:
	# Thin decorative strips along the walls to give depth
	var img := Image.create(room_w, room_h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	var board_color := Color(0.25, 0.18, 0.12)
	for x in range(room_w):
		img.set_pixel(x, 3, board_color)
		img.set_pixel(x, 4, board_color)
		img.set_pixel(x, room_h - 4, board_color)
		img.set_pixel(x, room_h - 5, board_color)
	for y in range(room_h):
		img.set_pixel(3, y, board_color)
		img.set_pixel(4, y, board_color)
		img.set_pixel(room_w - 4, y, board_color)
		img.set_pixel(room_w - 5, y, board_color)
	var sprite := Sprite2D.new()
	sprite.texture = ImageTexture.create_from_image(img)
	sprite.position = Vector2(room_w / 2.0, room_h / 2.0)
	sprite.z_index = 1  # same as floor
	add_child(sprite)

func _add_rug(pos: Vector2, w: int, h: int, color: Color) -> void:
	var sprite := Sprite2D.new()
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(color)
	# Border in darker shade
	var border := Color(color.r * 0.6, color.g * 0.6, color.b * 0.6)
	for x in range(w):
		img.set_pixel(x, 0, border)
		img.set_pixel(x, h - 1, border)
	for y in range(h):
		img.set_pixel(0, y, border)
		img.set_pixel(w - 1, y, border)
	# Simple diamond pattern in the center
	var cx := w / 2
	var cy := h / 2
	var pattern_color := Color(color.r * 1.3, color.g * 1.3, color.b * 1.3, 0.7)
	for d in range(1, min(w, h) / 4):
		for dx in range(-d, d + 1):
			img.set_pixel(cx + dx, cy - d, pattern_color)
			img.set_pixel(cx + dx, cy + d, pattern_color)
		for dy in range(-d, d + 1):
			img.set_pixel(cx - d, cy + dy, pattern_color)
			img.set_pixel(cx + d, cy + dy, pattern_color)
	sprite.texture = ImageTexture.create_from_image(img)
	sprite.position = pos
	sprite.z_index = 1  # sits on floor, under furniture
	add_child(sprite)

func _add_wall_art(pos: Vector2, w: int, h: int, frame_color: Color, paint_color: Color) -> void:
	var sprite := Sprite2D.new()
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(paint_color)
	# Frame (thick border)
	for x in range(w):
		for y in [0, 1, h - 2, h - 1]:
			img.set_pixel(x, y, frame_color)
	for y in range(h):
		for x in [0, 1, w - 2, w - 1]:
			img.set_pixel(x, y, frame_color)
	# Simple landscape: green ground, blue sky
	var mid_y := h * 2 / 3
	for y in range(mid_y, h):
		for x in range(3, w - 3):
			img.set_pixel(x, y, Color(0.2, 0.5, 0.15))
	for y in range(3, mid_y):
		for x in range(3, w - 3):
			img.set_pixel(x, y, Color(0.3, 0.5, 0.8))
	# Sun
	var sun_cx := w - 8
	var sun_cy := 6
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			if dx * dx + dy * dy <= 9:
				img.set_pixel(sun_cx + dx, sun_cy + dy, Color(1.0, 0.9, 0.3))
	sprite.texture = ImageTexture.create_from_image(img)
	sprite.position = pos
	sprite.z_index = 2
	add_child(sprite)

func _add_window(pos: Vector2, w: int, h: int) -> void:
	var sprite := Sprite2D.new()
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	# Frame
	var frame := Color(0.55, 0.35, 0.18)
	for x in range(w):
		for y in [0, 1, h - 2, h - 1]:
			img.set_pixel(x, y, frame)
	for y in range(h):
		for x in [0, 1, w - 2, w - 1]:
			img.set_pixel(x, y, frame)
	# Cross panes
	for x in [w / 2 - 1, w / 2, w / 2 + 1]:
		for y in range(2, h - 2):
			img.set_pixel(x, y, frame)
	for y in [h / 2 - 1, h / 2, h / 2 + 1]:
		for x in range(2, w - 2):
			img.set_pixel(x, y, frame)
	# Glass (light blue with some glow)
	for y in range(2, h - 2):
		for x in range(2, w - 2):
			# Fill transparent pixels with semi-transparent blue glass
			if img.get_pixel(x, y).a < 0.01:
				img.set_pixel(x, y, Color(0.4, 0.6, 0.9, 0.35))
	sprite.texture = ImageTexture.create_from_image(img)
	sprite.position = pos
	sprite.z_index = 2
	add_child(sprite)

func _add_room_divider_wall(x: int, wall_color: Color) -> void:
	# Wall segments with collision that act as room dividers.
	# Top and bottom segments have a wide open gap between them
	# so the player can pass through. The gap is tall enough (36px)
	# to comfortably fit the player's collision box.
	var wall_w := 4
	var top_h := 24     # y=0  to y=24
	var gap_top := 24   # gap starts here
	var gap_h := 36     # y=24 to y=60 — 36px clear passage
	var bot_h := 60     # y=60 to y=120
	var edge := Color(wall_color.r * 0.7, wall_color.g * 0.7, wall_color.b * 0.7)
	
	# ── Top segment sprite (above gap) ──
	var top_sprite := Sprite2D.new()
	var top_img := Image.create(wall_w, top_h, false, Image.FORMAT_RGBA8)
	top_img.fill(wall_color)
	for y in range(top_h):
		top_img.set_pixel(0, y, edge)
	top_sprite.texture = ImageTexture.create_from_image(top_img)
	top_sprite.position = Vector2(x, top_h / 2.0)
	top_sprite.z_index = 2
	add_child(top_sprite)
	
	# ── Top segment collision ──
	var top_body := StaticBody2D.new()
	var top_shape := CollisionShape2D.new()
	var top_rect := RectangleShape2D.new()
	top_rect.size = Vector2(wall_w, top_h)
	top_shape.shape = top_rect
	top_body.add_child(top_shape)
	top_body.position = Vector2(x, top_h / 2.0)
	add_child(top_body)
	
	# ── Bottom segment sprite (below gap) ──
	var bot_sprite := Sprite2D.new()
	var bot_img := Image.create(wall_w, bot_h, false, Image.FORMAT_RGBA8)
	bot_img.fill(wall_color)
	for y in range(bot_h):
		bot_img.set_pixel(0, y, edge)
	bot_sprite.texture = ImageTexture.create_from_image(bot_img)
	bot_sprite.position = Vector2(x, gap_top + gap_h + bot_h / 2.0)
	bot_sprite.z_index = 2
	add_child(bot_sprite)
	
	# ── Bottom segment collision ──
	var bot_body := StaticBody2D.new()
	var bot_shape := CollisionShape2D.new()
	var bot_rect := RectangleShape2D.new()
	bot_rect.size = Vector2(wall_w, bot_h)
	bot_shape.shape = bot_rect
	bot_body.add_child(bot_shape)
	bot_body.position = Vector2(x, gap_top + gap_h + bot_h / 2.0)
	add_child(bot_body)

func _generate_small_home() -> void:
	_room_width = 160
	_room_height = 120
	_create_wall_sprite(_room_width, _room_height, Color(0.25, 0.2, 0.15))
	_create_floor(_room_width, _room_height)
	_add_baseboards(_room_width, _room_height)
	
	# ── Room divider wall segments (short, with wide open gap) ──
	var wall_color := Color(0.27, 0.2, 0.14)
	_add_room_divider_wall(50, wall_color)   # Kitchen ↔ Living Room
	_add_room_divider_wall(110, wall_color)  # Living Room ↔ Bedroom
	
	# ── EXIT DOOR (bottom-center — front door) ──
	_add_exit_door(Vector2(78, 95))
	
	# ══════════════════════════════════════════════
	#  🍳  KITCHEN  (left zone, x: 5–48)
	# ══════════════════════════════════════════════
	_add_cooking_station(Vector2(30, 28))   # Stove / fire pit
	_add_crafting_station(Vector2(30, 68))  # Prep table / workbench
	
	# ══════════════════════════════════════════════
	#  🛋️  LIVING ROOM  (center zone, x: 52–108)
	# ══════════════════════════════════════════════
	_add_table(Vector2(80, 44))              # Coffee/dining table
	_add_rug(Vector2(80, 65), 40, 24, Color(0.5, 0.15, 0.15))  # Red rug under table
	
	# ══════════════════════════════════════════════
	#  🛏️  BEDROOM  (right zone, x: 112–155)
	# ══════════════════════════════════════════════
	_add_bed(Vector2(135, 28))               # Bed in top-right
	_add_storage_chest(Vector2(135, 75))     # Chest at foot of bed

func _generate_medium_home() -> void:
	_room_width = 200
	_room_height = 144
	_create_wall_sprite(_room_width, _room_height, Color(0.28, 0.22, 0.16))
	_create_floor(_room_width, _room_height)
	_add_exit_door()
	
	_add_bed(Vector2(160, 50))
	_add_crafting_station(Vector2(40, 50))
	_add_storage_chest(Vector2(160, 100))
	_add_cooking_station(Vector2(40, 100))
	_add_table(Vector2(100, 75))
	_add_decorative(Vector2(100, 40), Color(0.6, 0.55, 0.4), 24, 16)  # Shelf

func _generate_large_home() -> void:
	_room_width = 280
	_room_height = 176
	_create_wall_sprite(_room_width, _room_height, Color(0.3, 0.25, 0.18))
	_create_floor(_room_width, _room_height)
	_add_exit_door()
	
	_add_bed(Vector2(240, 60))
	_add_crafting_station(Vector2(50, 50))
	_add_storage_chest(Vector2(240, 120))
	_add_cooking_station(Vector2(50, 120))
	_add_table(Vector2(140, 85))
	_add_decorative(Vector2(140, 40), Color(0.6, 0.5, 0.35), 36, 22)  # Bookshelf
	_add_decorative(Vector2(50, 85), Color(0.4, 0.35, 0.25), 28, 24)  # Armchair

func _generate_barn() -> void:
	_room_width = 200
	_room_height = 120
	_create_wall_sprite(_room_width, _room_height, Color(0.35, 0.25, 0.15))
	_create_floor(_room_width, _room_height)
	_add_exit_door()
	_add_storage_chest(Vector2(160, 80))
	_add_decorative(Vector2(45, 80), Color(0.4, 0.3, 0.2), 36, 28)  # Hay Bales
	_add_decorative(Vector2(100, 50), Color(0.5, 0.35, 0.25), 40, 28)  # Trough

func _generate_workshop() -> void:
	_room_width = 200
	_room_height = 144
	_create_wall_sprite(_room_width, _room_height, Color(0.22, 0.2, 0.18))
	_create_floor(_room_width, _room_height)
	_add_exit_door()
	_add_crafting_station(Vector2(40, 40))
	_add_crafting_station(Vector2(140, 40))  # Second station
	_add_storage_chest(Vector2(140, 100))
	_add_decorative(Vector2(25, 55), Color(0.4, 0.35, 0.3), 16, 20)  # Tool Rack

func _generate_greenhouse() -> void:
	_room_width = 200
	_room_height = 120
	_create_wall_sprite(_room_width, _room_height, Color(0.2, 0.35, 0.2))
	_create_floor(_room_width, _room_height)
	_add_exit_door()
	_add_decorative(Vector2(45, 55), Color(0.2, 0.5, 0.2), 36, 24)  # Plant Bed
	_add_decorative(Vector2(100, 55), Color(0.2, 0.5, 0.2), 36, 24)  # Plant Bed
	_add_decorative(Vector2(155, 55), Color(0.2, 0.5, 0.2), 36, 24)  # Plant Bed
