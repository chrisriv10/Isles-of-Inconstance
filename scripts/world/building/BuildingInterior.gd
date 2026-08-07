extends Node2D
class_name BuildingInterior

## Creates a building interior scene dynamically when the player enters a
## building. Furnishings, lighting, and stations are generated based on
## building type.

enum InteriorType { SMALL_HOME, MEDIUM_HOME, LARGE_HOME, BARN, TOWN_HALL, GREENHOUSE, HOTEL, BAKERY, RESTAURANT, TAVERN, BLACKSMITH, GENERAL_STORE, LIBRARY, STABLE, BANK }

var interior_type: int
var building_cell: Vector2i

# Unique stable identifier for THIS interior, used for multiplayer remote-player
# visibility. Regular buildings use the cell key "x,y"; town ruins use their
# ruin_id (their building_cell is always Vector2i.ZERO, so it can't distinguish
# two different ruins). Empty for any interior type that doesn't set one.
var building_key: String = ""

# Room dimensions (set by _generate_interior)
var _room_width: int = 0
var _room_height: int = 0

# References to furniture nodes
var crafting_station: Area2D = null
var cooking_station: Area2D = null
var storage_chest: Area2D = null

# UI Style constants
var LIGHT_WOOD: StyleBoxTexture
var DARK_WOOD: StyleBoxTexture
var DARK_WOOD_BORDER: StyleBoxTexture
var DARK_SLOT: StyleBoxFlat

func _ready() -> void:
	LIGHT_WOOD = preload("res://resources/ui/wood_panel.tres")
	DARK_WOOD = preload("res://resources/ui/dark_wood_panel.tres")
	DARK_WOOD_BORDER = preload("res://resources/ui/dark_wood_border.tres")
	DARK_SLOT = _make_dark_slot()

static func _make_dark_slot() -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.12, 0.12, 0.12, 0.85)
	s.border_color = Color(0.25, 0.25, 0.25, 1.0)
	s.set_border_width_all(2)
	s.set_corner_radius_all(4)
	return s
var _chest_inventory: ContainerInventory = null
var bed: Area2D = null

## Resident info set from BuildingSystem or RuinStructure when entering
## a home interior that belongs to a recruited NPC.
var _resident_name: String = ""
var _resident_visitor_type: int = -1
var _resident_npc_id: String = ""

signal exited_interior()

## True when `player` is this peer's own copy. Without a network peer (single
## player) every node is local, so these checks never touch the network API.
func _is_local_player(player: Node) -> bool:
	if not NetworkManager.is_network_active():
		return true
	return player.get_multiplayer_authority() == multiplayer.get_unique_id()


# Preloaded pixel art textures for furniture
const FURNITURE_BED := preload("res://assets/generated/furniture_bed_frame_0.png")
const FURNITURE_CRAFTING := preload("res://assets/generated/furniture_crafting_frame_0.png")
const FURNITURE_CHEST := preload("res://assets/generated/furniture_chest_frame_0.png")
const FURNITURE_COOKING := preload("res://assets/generated/furniture_kitchen_frame_0.png")
const FURNITURE_TABLE := preload("res://assets/generated/furniture_table_frame_0.png")
const FURNITURE_BOOKSHELF := preload("res://assets/generated/furniture_bookshelf_frame_0.png")
const FURNITURE_ARMCHAIR := preload("res://assets/generated/furniture_armchair_frame_0.png")
const FURNITURE_POTTED_PLANT := preload("res://assets/generated/furniture_potted_plant_frame_0.png")
const FURNITURE_CANDLE_TABLE := preload("res://assets/generated/furniture_candle_table_frame_0.png")
const BARN_CHICKEN_COOP := preload("res://assets/generated/furniture_chicken_coop_frame_0.png")
const BARN_COW_STALL := preload("res://assets/generated/furniture_cow_stall_frame_0.png")
const BARN_SHEEP_PEN := preload("res://assets/generated/furniture_sheep_pen_frame_0.png")
const BARN_TROUGH := preload("res://assets/generated/furniture_trough_frame_0.png")

# Greenhouse furniture sprites
const GREENHOUSE_PLANT_BED := preload("res://assets/generated/greenhouse_plant_bed_frame_0.png")
const GREENHOUSE_WATER_BARREL := preload("res://assets/generated/greenhouse_water_barrel_frame_0.png")
const GREENHOUSE_SEED_RACK := preload("res://assets/generated/greenhouse_seed_rack_frame_0.png")
const GREENHOUSE_POTTING_TABLE := preload("res://assets/generated/greenhouse_potting_table_frame_0.png")
# NOTE: INTERACTABLE_SCRIPT was removed — Interactable is used via class_name Interactable.new()

# ── Hotel-specific sprite textures (pre-made pixel art) ──
const HOTEL_WALL_BG := preload("res://assets/generated/hotel_wall_bg.png")
const HOTEL_FLOOR_TILE := preload("res://assets/generated/hotel_floor_tile.png")
const HOTEL_BASEBOARD := preload("res://assets/generated/hotel_baseboard.png")
const HOTEL_RUG_LARGE := preload("res://assets/generated/hotel_rug_large.png")
const HOTEL_RUG_SMALL := preload("res://assets/generated/hotel_rug_small.png")
const HOTEL_FIREPLACE := preload("res://assets/generated/hotel_fireplace.png")
const HOTEL_WINDOW := preload("res://assets/generated/hotel_window.png")
const HOTEL_WALL_ART := preload("res://assets/generated/hotel_wall_art.png")
const HOTEL_DOOR := preload("res://assets/generated/hotel_door.png")
const HOTEL_FRONT_DESK := preload("res://assets/generated/hotel_front_desk.png")
const HOTEL_BED_SPRITE := preload("res://assets/generated/hotel_bed.png")
const HOTEL_ARMCHAIR := preload("res://assets/generated/hotel_armchair.png")
const HOTEL_POTTED_PLANT := preload("res://assets/generated/hotel_potted_plant.png")
const HOTEL_NIGHTSTAND := preload("res://assets/generated/hotel_nightstand.png")
const HOTEL_WALL_SCONCE := preload("res://assets/generated/hotel_wall_sconce.png")
const HOTEL_CHANDELIER := preload("res://assets/generated/hotel_chandelier.png")
const HOTEL_STAIRS := preload("res://assets/generated/hotel_stairs.png")
const HOTEL_LOBBY_TABLE := preload("res://assets/generated/hotel_lobby_table.png")

# NPC textures for hotel guest sprites
const NPC_EXPLORER := preload("res://assets/generated/npc_explorer_frame_0.png")
const NPC_FISHER := preload("res://assets/generated/npc_fisher_frame_0.png")
const NPC_VENDOR := preload("res://assets/generated/npc_vendor_frame_0.png")
const NPC_SIGHTSEER := preload("res://assets/generated/npc_sightseer_frame_0.png")

# Guest NPC appearances for hotel rooms
const GUEST_APPEARANCES: Array[Texture2D] = [NPC_EXPLORER, NPC_FISHER, NPC_VENDOR, NPC_SIGHTSEER]

# Reference to the Hotel.gd income logic on the parent building (set for hotel interiors)
var _hotel_ref: Hotel = null

# Dynamic guest NPC sprites — spawned/cleared when hotel guests register/depart
var _guest_sprites: Array[Node] = []

# Whether the hotel currently has active registered guests
var _guests_active: bool = false

# Seeded RNG for deterministic interior generation (multiplayer sync)
var _rng: RandomNumberGenerator = null

## Positions where guest NPCs appear in the hotel interior.
const _HOTEL_GUEST_SPOTS: Array[Vector2] = [
	Vector2(68, 48),   # Guest Room 1 - beside nightstand
	Vector2(168, 48),  # Guest Room 2 - beside nightstand
	Vector2(268, 48),  # Guest Room 3 - beside nightstand
	Vector2(105, 132), # Lobby - near armchair 1
	Vector2(231, 132), # Lobby - near armchair 2
]

## Set the Hotel reference so the front desk can collect earnings.
func set_hotel_reference(hotel: Hotel) -> void:
	_hotel_ref = hotel
	# Listen for guest count changes to spawn/clear NPC sprites
	if hotel and not hotel.guests_changed.is_connected(_on_hotel_guests_changed):
		hotel.guests_changed.connect(_on_hotel_guests_changed)
		# If hotel already has guests, spawn them once the interior is in the
		# tree. set_hotel_reference() is called from RuinStructure BEFORE the
		# interior is added to the world, and _add_hotel_guest reads
		# multiplayer.is_server() — which is null while the node is outside the
		# tree, crashing 'Cannot call method is_server on a null value'.
		if hotel.has_guests and hotel.guest_count > 0:
			if is_inside_tree():
				_on_hotel_guests_changed(hotel.guest_count)
			else:
				tree_entered.connect(_on_hotel_guests_changed.bind(hotel.guest_count), CONNECT_ONE_SHOT)
	
	# Listen for time changes so guest NPCs appear at night and hide during day
	if not GameManager.time_changed.is_connected(_on_time_changed):
		GameManager.time_changed.connect(_on_time_changed)
		# Initial check for current time
		var gm: GameManager = GameManager
		_on_time_changed(gm.get_hour(), gm.get_minute())

# ── Barn animal stall definitions ──
# Each stall: name, sprite, product_item_id, product_amount, product_name
const BARN_STALLS: Array[Dictionary] = [
	{"id": "chickens", "name": "Chickens", "sprite": BARN_CHICKEN_COOP, "product": "egg", "amount": 1, "product_name": "Eggs"},
	{"id": "cows",     "name": "Cows",     "sprite": BARN_COW_STALL,   "product": "milk", "amount": 1, "product_name": "Milk"},
	{"id": "sheep",    "name": "Sheep",    "sprite": BARN_SHEEP_PEN,  "product": "wool", "amount": 1, "product_name": "Wool"},
]

func setup(type: int, cell: Vector2i, seed: int = 0) -> void:
	# Initialize seeded RNG for deterministic generation (multiplayer sync)
	_rng = RandomNumberGenerator.new()
	_rng.seed = seed
	
	# Map building type to interior type — BuildingType enum values may not
	# match InteriorType enum values for types added later (e.g. HOTEL).
	# Types 0-5 match 1:1 (SMALL_HOME..GREENHOUSE), but HOTEL is handled explicitly.
	interior_type = _map_building_to_interior(type)
	building_cell = cell
	_generate_interior()

## Unique stable identifier for THIS interior used for multiplayer remote-player
## visibility. Town ruins set building_key to their ruin_id; regular buildings
## fall back to the cell key.
func get_building_key() -> String:
	if not building_key.is_empty():
		return building_key
	return "%d,%d" % [building_cell.x, building_cell.y]

## Map a BuildingSystem.BuildingType value to the matching InteriorType.
## Types 0-5 match directly; HOTEL (21) maps to InteriorType.HOTEL (6);
## WORKSHOP (11) maps to InteriorType.TOWN_HALL (4); GREENHOUSE (13)
## maps to InteriorType.GREENHOUSE (5).
func _map_building_to_interior(b_type: int) -> int:
	match b_type:
		11:  # BuildingType.WORKSHOP
			return InteriorType.TOWN_HALL
		13:  # BuildingType.GREENHOUSE
			return InteriorType.GREENHOUSE
		21:  # BuildingType.HOTEL
			return InteriorType.HOTEL
		_:  # Types 0-3 match directly with InteriorType
			return b_type

## Set the resident info so a recruited NPC appears inside this interior.
## Called by BuildingSystem._on_enter_interior and RuinStructure._open_interior.
## NOTE: set_resident_info is called AFTER setup() (which runs the room
## generator), so spawning the resident must happen here — the generator's
## own calls were no-ops because _resident_visitor_type was still -1.
func set_resident_info(name: String, visitor_type: int, npc_id: String = "") -> void:
	_resident_name = name
	_resident_visitor_type = visitor_type
	_resident_npc_id = npc_id
	# Wait until the interior is in the tree before spawning the resident so
	# _spawn_resident_npc can find the resident's world node: it then skips
	# spawning when the resident is out wandering (no duplicate outside+inside)
	# and copies the resident's real sprite so the interior copy matches.
	if is_inside_tree():
		_spawn_resident_npc()
	else:
		tree_entered.connect(_spawn_resident_npc, CONNECT_ONE_SHOT)

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
		InteriorType.TOWN_HALL:
			_generate_town_hall()
		InteriorType.GREENHOUSE:
			_generate_greenhouse()
		InteriorType.HOTEL:
			_generate_hotel()
		InteriorType.BAKERY:
			_generate_bakery()
		InteriorType.RESTAURANT:
			_generate_restaurant()
		InteriorType.TAVERN:
			_generate_tavern()
		InteriorType.BLACKSMITH:
			_generate_blacksmith()
		InteriorType.GENERAL_STORE:
			_generate_general_store()
		InteriorType.LIBRARY:
			_generate_library()
		InteriorType.STABLE:
			_generate_stable()
		InteriorType.BANK:
			_generate_bank()
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

func _create_greenhouse_floor(width: int, height: int) -> void:
	var floor_sprite := Sprite2D.new()
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.25, 0.22, 0.18))

	# Stone tile pattern
	for y in range(0, height, 8):
		for x in range(0, width, 8):
			var tile_color: Color
			if ((x / 8) + (y / 8)) % 2 == 0:
				tile_color = Color(0.3, 0.27, 0.22)
			else:
				tile_color = Color(0.26, 0.23, 0.19)
			# Slight variation per tile
			var variation: float = 0.95 + 0.1 * ((x + y) % 5) / 5.0
			tile_color = Color(
				tile_color.r * variation,
				tile_color.g * variation,
				tile_color.b * variation
			)
			for py in range(y, min(y + 8, height)):
				for px in range(x, min(x + 8, width)):
					# Grout lines at edges
					if px == x or py == y:
						img.set_pixel(px, py, Color(0.2, 0.18, 0.15))
					else:
						img.set_pixel(px, py, tile_color)

	floor_sprite.texture = ImageTexture.create_from_image(img)
	floor_sprite.position = Vector2(width / 2, height / 2)
	floor_sprite.z_index = 1
	add_child(floor_sprite)

func _create_wall_sprite(_width: int, _height: int, color: Color) -> void:
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
	if body.is_in_group("player") and _is_local_player(body):
		_exit_interior()


func _exit_interior() -> void:
	_save_chest_contents()
	
	# Multiplayer: route exit through World RPC so all peers exit together.
	# Do NOT emit the local signal in multiplayer (would cause double-exit).
	if NetworkManager.is_network_active():
		var world := get_tree().root.find_child("World", true, false)
		if world and world.has_method("_server_exit_building"):
			# _server_exit_building is 'any_peer' (no call_local): as the host,
			# call it directly (rpc_id(1,...) on self would error); as a client,
			# forward to the host (peer 1).
			if world.get_multiplayer().is_server():
				world.call("_server_exit_building")
			else:
				world.rpc_id(1, "_server_exit_building")
			queue_free()
			return
	
	# Single player: use the local signal path
	exited_interior.emit()
	queue_free()

## Persist chest inventory to GameManager so it survives interior destruction.
func _save_chest_contents() -> void:
	if _chest_inventory:
		var key: String = "%d,%d" % [building_cell.x, building_cell.y]
		# Deep-copy the slots array (RefCounted objects don't auto-serialize)
		var slots_copy: Array = []
		for slot in _chest_inventory.slots:
			if slot is Dictionary:
				slots_copy.append({"item_id": slot["item_id"], "count": slot["count"]})
			else:
				slots_copy.append(null)
		GameManager.chest_inventories[key] = slots_copy

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
	# Host-authoritative: on a client this forwards the sleep to the host, which
	# sets 06:00 and broadcasts it to every peer. Directly mutating the
	# per-peer autoload here desynced time for the sleeping player.
	GameManager.request_sleep()
	ToastNotification.show_toast("Good morning! Slept through the night.", ToastNotification.ToastType.SUCCESS, 3.0)
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud:
		if hud.has_method("show_first_action_hint"):
			hud.show_first_action_hint("first_sleep", "Slept! Time skipped to 6 AM.")
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
	# Restore previously saved contents, if any
	_load_chest_contents()
	return chest

## Load saved chest inventory from GameManager cache (if any).
func _load_chest_contents() -> void:
	if not _chest_inventory:
		return
	var key: String = "%d,%d" % [building_cell.x, building_cell.y]
	if GameManager.chest_inventories.has(key):
		var saved_slots: Array = GameManager.chest_inventories[key]
		for i in range(min(saved_slots.size(), _chest_inventory.slots.size())):
			_chest_inventory.slots[i] = saved_slots[i]

func _on_storage_interacted(_interactor: Node) -> void:
	var chest_ui: CanvasLayer = get_tree().get_first_node_in_group("chest_storage_ui") as CanvasLayer
	if chest_ui and _chest_inventory:
		var chest_key: String = "%d,%d" % [building_cell.x, building_cell.y]
		chest_ui.open_for(_chest_inventory, "Storage Chest", Callable(), chest_key)

func _add_table(pos: Vector2) -> Interactable:
	var table := _add_interactable_furniture(pos, FURNITURE_TABLE, "Examine", 24, 16)
	table.interacted.connect(_on_table_interacted)
	return table

## Random helpful tips shown when examining furniture. Keeps the "Examine"
## prompt meaningful instead of being a dead interaction.
const TABLE_TIPS: Array[String] = [
	"Tip: Water your crops every day — they grow faster when hydrated.",
	"Tip: Crops can mutate into rare variants. Keep an eye out for odd colors!",
	"Tip: Cooking meals restores more hunger than raw ingredients.",
	"Tip: Talk to the Shopkeeper to buy seeds and sell your harvest.",
	"Tip: Build a storage shed to keep your overflow items safe.",
	"Tip: Higher quality crops sell for more. Use compost to boost quality!",
	"Tip: Don't forget to eat — your hunger drains over time.",
	"Tip: You can craft tools and furniture at a crafting station.",
	"Tip: Sleep in a bed to skip the night and restore energy.",
	"Tip: Enemies come out at night. Be prepared before dark!",
	"Tip: Plant crops in rows for easier watering and harvesting.",
	"Tip: Save your coins for tool upgrades — they make farming much faster.",
]

func _on_table_interacted(_interactor: Node) -> void:
	var tip: String = TABLE_TIPS.pick_random()
	ToastNotification.show_toast(tip, ToastNotification.ToastType.INFO, 4.0)

func _add_armchair(pos: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = FURNITURE_ARMCHAIR
	sprite.z_index = 2
	sprite.position = pos
	add_child(sprite)

func _add_bookshelf(pos: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = FURNITURE_BOOKSHELF
	sprite.z_index = 2
	sprite.position = pos
	add_child(sprite)

func _add_potted_plant(pos: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = FURNITURE_POTTED_PLANT
	sprite.z_index = 2
	sprite.position = pos
	add_child(sprite)

func _add_candle_table(pos: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = FURNITURE_CANDLE_TABLE
	sprite.z_index = 2
	sprite.position = pos
	add_child(sprite)

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

func _add_fireplace(pos: Vector2) -> void:
	var sprite := Sprite2D.new()
	var img := Image.create(28, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	# Stone chimney body (grey stone)
	var stone_color := Color(0.35, 0.3, 0.25)
	for y in range(4, 32):
		for x in range(4, 24):
			# Stone variation
			var variation: float = 0.9 + 0.2 * ((x + y * 3) % 5) / 5.0
			var c := Color(stone_color.r * variation, stone_color.g * variation, stone_color.b * variation)
			img.set_pixel(x, y, c)
	# Mortar lines between stones
	var mortar := Color(0.25, 0.2, 0.15)
	for y in range(6, 30, 6):
		for x in range(4, 24):
			img.set_pixel(x, y, mortar)
	for x in range(6, 24, 8):
		for y in range(4, 32):
			img.set_pixel(x, y, mortar)
	# Fireplace opening (dark arch)
	for y in range(14, 30):
		for x in range(8, 20):
			var rel_x := x - 14
			var rel_y := y - 14
			var in_arch := float(rel_x * rel_x + rel_y * rel_y * 0.5) < 36.0
			if in_arch and y >= 14:
				img.set_pixel(x, y, Color(0.05, 0.03, 0.02))
	# Warm fire glow inside
	for var_y in range(20, 28):
		for var_x in range(10, 18):
			if img.get_pixel(var_x, var_y) == Color(0.05, 0.03, 0.02):
				var dist: float = float(abs(var_x - 14) + abs(var_y - 24))
				if dist < 6:
					var alpha: float = 0.5 - dist * 0.07
					if alpha > 0.0:
						img.set_pixel(var_x, var_y, Color(1.0, 0.6 + 0.3 * ((var_x + var_y) % 3) * 0.1, 0.1, alpha))
	# Mantel (wooden shelf above opening)
	var mantel_color := Color(0.45, 0.22, 0.08)
	for x in range(6, 22):
		img.set_pixel(x, 12, mantel_color)
		img.set_pixel(x, 13, mantel_color)
	# Warm glow sprite behind fireplace (soft orange aura)
	var glow_sprite := Sprite2D.new()
	var glow_img := Image.create(40, 36, false, Image.FORMAT_RGBA8)
	glow_img.fill(Color(0.0, 0.0, 0.0, 0.0))
	for var_y in range(36):
		for var_x in range(40):
			var dist := sqrt(pow(var_x - 20, 2) + pow(var_y - 22, 2))
			if dist < 20:
				var alpha: float = 0.12 * (1.0 - dist / 20.0)
				if alpha > 0.01:
					glow_img.set_pixel(var_x, var_y, Color(1.0, 0.5, 0.1, alpha))
	glow_sprite.texture = ImageTexture.create_from_image(glow_img)
	glow_sprite.position = pos
	glow_sprite.z_index = 1  # behind fireplace
	add_child(glow_sprite)
	
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
	
	# Spawn resident NPC if one is assigned to this building
	_spawn_resident_npc()

func _generate_medium_home() -> void:
	_room_width = 200
	_room_height = 144
	_create_wall_sprite(_room_width, _room_height, Color(0.28, 0.22, 0.16))
	_create_floor(_room_width, _room_height)
	_add_baseboards(_room_width, _room_height)
	_add_exit_door()
	
	# ── Bedroom nook (right side) ──
	_add_bed(Vector2(168, 42))
	_add_candle_table(Vector2(168, 72))   # Nightstand beside bed
	_add_storage_chest(Vector2(168, 108))
	
	# ── Living area (center) ──
	_add_rug(Vector2(100, 80), 48, 28, Color(0.5, 0.15, 0.15))  # Red rug
	_add_table(Vector2(100, 80))          # Coffee table on rug
	_add_armchair(Vector2(72, 110))       # Armchair by the rug
	_add_wall_art(Vector2(100, 24), 28, 20, Color(0.45, 0.3, 0.15), Color(0.2, 0.4, 0.6))  # Painting
	
	# ── Kitchen / workshop (left side) ──
	_add_cooking_station(Vector2(36, 42))
	_add_crafting_station(Vector2(56, 110))
	
	# ── Decorations ──
	_add_potted_plant(Vector2(190, 30))   # Plant by the window
	_add_decorative(Vector2(100, 136), Color(0.6, 0.55, 0.4), 32, 12)  # Shelf below painting
	
	# Spawn resident NPC if one is assigned to this building
	_spawn_resident_npc()

func _generate_large_home() -> void:
	_room_width = 280
	_room_height = 176
	_create_wall_sprite(_room_width, _room_height, Color(0.3, 0.25, 0.18))
	_create_floor(_room_width, _room_height)
	_add_baseboards(_room_width, _room_height)
	_add_exit_door()
	
	# ── Master bedroom (far right) ──
	_add_bed(Vector2(252, 52))
	_add_candle_table(Vector2(252, 80))       # Nightstand
	_add_wall_art(Vector2(252, 28), 20, 16, Color(0.5, 0.35, 0.15), Color(0.6, 0.2, 0.15))  # Small painting
	_add_storage_chest(Vector2(252, 140))
	
	# ── Grand living room (center) ──
	_add_rug(Vector2(145, 90), 64, 36, Color(0.4, 0.1, 0.1))  # Large red rug
	_add_table(Vector2(145, 90))          # Dining table on rug
	_add_armchair(Vector2(105, 118))      # Armchair left of table
	_add_armchair(Vector2(185, 118))      # Armchair right of table
	_add_wall_art(Vector2(145, 28), 40, 28, Color(0.5, 0.3, 0.1), Color(0.2, 0.3, 0.7))  # Large landscape painting
	
	# ── Kitchen / crafting (left side) ──
	_add_cooking_station(Vector2(40, 55))
	_add_crafting_station(Vector2(40, 108))
	_add_decorative(Vector2(40, 28), Color(0.6, 0.5, 0.35), 32, 16)  # Shelf above cooking
	
	# ── Decorations ──
	_add_bookshelf(Vector2(185, 40))      # Bookshelf in living room
	_add_potted_plant(Vector2(105, 40))   # Plant near window
	_add_potted_plant(Vector2(260, 110))  # Plant in bedroom corner
	_add_window(Vector2(145, 165), 36, 20)  # Window near door
	
	# Spawn resident NPC if one is assigned to this building
	_spawn_resident_npc()

func _generate_barn() -> void:
	_room_width = 200
	_room_height = 120
	_create_wall_sprite(_room_width, _room_height, Color(0.35, 0.25, 0.15))
	_create_floor(_room_width, _room_height)
	_add_exit_door()
	
	# ══════════════════════════════════════════════
	#  🐔  ANIMAL STALLS (left side)
	# ══════════════════════════════════════════════
	var stall_start_x := 50
	var stall_spacing := 55
	for i in range(BARN_STALLS.size()):
		var stall: Dictionary = BARN_STALLS[i]
		var sx: int = stall_start_x + i * stall_spacing
		_add_animal_stall(Vector2(sx, 50), stall)
	
	# ══════════════════════════════════════════════
	#  🪤  FEEDING TROUGH (center)
	# ══════════════════════════════════════════════
	_add_feed_trough(Vector2(100, 90))
	
	# ══════════════════════════════════════════════
	#  📦  STORAGE (right side)
	# ══════════════════════════════════════════════
	_add_storage_chest(Vector2(166, 55))
	
	# ── Decorations ──
	_add_decorative(Vector2(160, 98), Color(0.4, 0.3, 0.2), 28, 20)  # Hay bales

func _generate_town_hall() -> void:
	_room_width = 320
	_room_height = 220
	_create_wall_sprite(_room_width, _room_height, Color(0.25, 0.22, 0.28))  # Slightly dignified purple-grey
	_create_floor(_room_width, _room_height)
	_add_baseboards(_room_width, _room_height)
	_add_exit_door(Vector2(40, 80))
	
	# ══════════════════════════════════════════════
	#  📋  RECRUITMENT DESK (left side — recruit visitors!)
	# ══════════════════════════════════════════════
	_add_recruitment_desk(Vector2(60, 56))
	
	# ══════════════════════════════════════════════
	#  🪪  ID STATION (bottom-left — town identity)
	# ══════════════════════════════════════════════
	_add_table(Vector2(60, 130))
	_add_armchair(Vector2(60, 150))
	_add_candle_table(Vector2(60, 110))  # Lamp for reading documents
	
	# ══════════════════════════════════════════════
	#  🏛️  MAYOR'S DESK (right side — ceremonial)
	# ══════════════════════════════════════════════
	_add_table(Vector2(240, 56))
	_add_armchair(Vector2(240, 76))
	_add_bookshelf(Vector2(280, 48))
	_add_bookshelf(Vector2(280, 96))
	_add_decorative(Vector2(240, 32), Color(0.55, 0.5, 0.3), 24, 12)  # Shelf behind desk
	
	# (Notice board / painting removed per user request)
	
	# ══════════════════════════════════════════════
	#  🪑  WAITING AREA (center)
	# ══════════════════════════════════════════════
	_add_armchair(Vector2(150, 100))
	_add_armchair(Vector2(180, 100))
	_add_candle_table(Vector2(165, 88))  # Table between chairs
	
	# (Storage chest removed per user request)
	
	# ══════════════════════════════════════════════
	#  🪴  DECORATIVE FURNISHINGS
	# ══════════════════════════════════════════════
	_add_potted_plant(Vector2(48, 186))
	_add_potted_plant(Vector2(272, 186))
	_add_potted_plant(Vector2(160, 200))
	
	# ══════════════════════════════════════════════
	#  🏛️  WINDOWS
	# ══════════════════════════════════════════════
	_add_window(Vector2(100, 10), 32, 16)
	_add_window(Vector2(180, 10), 32, 16)
	_add_window(Vector2(260, 10), 32, 16)

	# ══════════════════════════════════════════════
	#  🧵  FORMAL RUG (center of room)
	# ══════════════════════════════════════════════
	_add_rug(Vector2(100, 96), 120, 48, Color(0.45, 0.15, 0.2))  # Grand red carpet

func _generate_greenhouse() -> void:
	_room_width = 400
	_room_height = 280
	_create_wall_sprite(_room_width, _room_height, Color(0.2, 0.35, 0.2))
	_create_greenhouse_floor(_room_width, _room_height)
	_add_exit_door(Vector2(40, 80))
	
	# ══════════════════════════════════════════════
	#  🌱  PLANT BEDS (8 beds in 3 rows — spacious layout)
	# ══════════════════════════════════════════════
	# Top row (3 beds)
	_add_greenhouse_plant_bed(Vector2(80, 55))
	_add_greenhouse_plant_bed(Vector2(180, 55))
	_add_greenhouse_plant_bed(Vector2(280, 55))
	# Middle row (3 beds, staggered)
	_add_greenhouse_plant_bed(Vector2(130, 95))
	_add_greenhouse_plant_bed(Vector2(230, 95))
	_add_greenhouse_plant_bed(Vector2(330, 95))
	# Bottom row (2 beds, staggered)
	_add_greenhouse_plant_bed(Vector2(80, 135))
	_add_greenhouse_plant_bed(Vector2(280, 135))
	
	# ══════════════════════════════════════════════
	#  🪴  POTTING TABLES (interactive — gardening tips)
	# ══════════════════════════════════════════════
	_add_greenhouse_potting_table(Vector2(350, 165))
	_add_greenhouse_potting_table(Vector2(350, 215))
	
	# ══════════════════════════════════════════════
	#  🔨  CRAFTING STATION — craft seeds, garden tools, compost
	# ══════════════════════════════════════════════
	_add_crafting_station(Vector2(50, 170))
	
	# ══════════════════════════════════════════════
	#  🌰  SEED RACKS (decorative, along right wall)
	# ══════════════════════════════════════════════
	_add_greenhouse_seed_rack(Vector2(370, 52))
	_add_greenhouse_seed_rack(Vector2(370, 92))
	
	# ══════════════════════════════════════════════
	#  🛢️  WATER BARRELS (functional — waters all crops)
	# ══════════════════════════════════════════════
	_add_greenhouse_water_barrel(Vector2(60, 26))
	_add_greenhouse_water_barrel(Vector2(340, 26))
	
	# ══════════════════════════════════════════════
	#  ♻️  COMPOST BIN (functional interaction)
	# ══════════════════════════════════════════════
	_add_greenhouse_compost_bin(Vector2(150, 230))
	
	# ══════════════════════════════════════════════
	#  📦  STORAGE CHEST (bottom-right)
	# ══════════════════════════════════════════════
	_add_storage_chest(Vector2(350, 250))
	
	# ══════════════════════════════════════════════
	#  🪑  TABLE with gardening tips (center-bottom)
	# ══════════════════════════════════════════════
	_add_table(Vector2(250, 220))
	
	# ══════════════════════════════════════════════
	#  🌿  DECORATIVE POTTED PLANTS (aisle accents)
	# ══════════════════════════════════════════════
	_add_decorative(Vector2(180, 175), Color(0.2, 0.5, 0.15), 12, 14)
	_add_decorative(Vector2(320, 175), Color(0.25, 0.55, 0.2), 10, 12)
	_add_decorative(Vector2(50, 250), Color(0.3, 0.6, 0.2), 10, 12)
	
	# ══════════════════════════════════════════════
	#  🏛️  WINDOWS (glass panels along top wall)
	# ══════════════════════════════════════════════
	_add_window(Vector2(100, 12), 40, 16)
	_add_window(Vector2(200, 12), 40, 16)
	_add_window(Vector2(300, 12), 40, 16)


# ── Greenhouse furniture helpers ──

func _add_greenhouse_plant_bed(pos: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = GREENHOUSE_PLANT_BED
	sprite.z_index = 2
	sprite.position = pos
	add_child(sprite)

func _add_greenhouse_potting_table(pos: Vector2) -> void:
	var interactable := Interactable.new()
	interactable.collision_layer = 4
	interactable.interaction_prompt = "Manage crops"
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(24, 16)
	shape.shape = rect
	interactable.add_child(shape)
	var sprite := Sprite2D.new()
	sprite.texture = GREENHOUSE_POTTING_TABLE
	sprite.z_index = 2
	interactable.add_child(sprite)
	interactable.position = pos
	interactable.interacted.connect(func(_i: Node) -> void:
		var farming_ui: CanvasLayer = get_tree().get_first_node_in_group("farming_ui") as CanvasLayer
		if farming_ui and farming_ui.has_method("open"):
			farming_ui.open()
		else:
			ToastNotification.show_toast("The potting table is ready. Check your crops!", ToastNotification.ToastType.INFO, 3.0)
	)
	add_child(interactable)

func _add_greenhouse_seed_rack(pos: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = GREENHOUSE_SEED_RACK
	sprite.z_index = 2
	sprite.position = pos
	add_child(sprite)

func _add_greenhouse_water_barrel(pos: Vector2) -> Interactable:
	var interactable := Interactable.new()
	interactable.collision_layer = 4
	interactable.interaction_prompt = "Water crops"
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(24, 20)
	shape.shape = rect
	interactable.add_child(shape)
	interactable.position = pos
	var sprite := Sprite2D.new()
	sprite.texture = GREENHOUSE_WATER_BARREL
	sprite.z_index = 2
	interactable.add_child(sprite)
	interactable.interacted.connect(func(_i: Node) -> void:
		ToastNotification.show_toast("The water barrel is full and ready. Use your watering can on the fields outside!", ToastNotification.ToastType.INFO, 3.0)
	)
	add_child(interactable)
	return interactable

func _add_greenhouse_compost_bin(pos: Vector2) -> void:
	# Interactive compost bin — shows gardening tips and can consume
	# organic items to produce compost.
	var interactable := Interactable.new()
	interactable.collision_layer = 4
	interactable.interaction_prompt = "Use Compost Bin"
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(24, 16)
	shape.shape = rect
	interactable.add_child(shape)
	interactable.position = pos
	
	# Visual: brown wooden bin with dark filling
	var sprite := Sprite2D.new()
	var img := Image.create(24, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	# Bin walls (wooden slats)
	var wood_color := Color(0.4, 0.25, 0.12)
	for y in range(2, 14):
		for x in range(2, 22):
			img.set_pixel(x, y, wood_color)
	# Dark compost inside
	var compost_color := Color(0.22, 0.15, 0.08)
	for y in range(4, 12):
		for x in range(4, 20):
			img.set_pixel(x, y, compost_color)
	# Slat lines
	var slat_line := Color(0.35, 0.2, 0.1)
	for x in [5, 10, 15, 20]:
		for y in range(2, 14):
			img.set_pixel(x, y, slat_line)
	# Top rim
	var rim_color := Color(0.5, 0.32, 0.15)
	for x in range(1, 23):
		img.set_pixel(x, 1, rim_color)
		img.set_pixel(x, 2, rim_color)
	sprite.texture = ImageTexture.create_from_image(img)
	sprite.z_index = 2
	interactable.add_child(sprite)
	
	interactable.interacted.connect(func(_i: Node) -> void:
		# Consume organic items to produce compost
		var organic_items: Array[String] = ["crop", "berry", "mushroom", "flower", "nut", "fiber", "weed"]
		var consumed: int = 0
		for item_id: String in organic_items:
			var count: int = InventoryManager.get_count(item_id)
			if count > 0:
				var to_consume: int = mini(count, 5)
				InventoryManager.remove_item(item_id, to_consume)
				consumed += to_consume
				if consumed >= 5:
					break
		if consumed >= 5:
			InventoryManager.add_item("compost", 1)
			ToastNotification.show_toast("Compost produced! Rich soil for your crops.", ToastNotification.ToastType.SUCCESS, 3.0)
		elif consumed > 0:
			ToastNotification.show_toast("Need 5 organic items for compost. Only got %d — keep gathering!" % [consumed], ToastNotification.ToastType.INFO, 3.0)
		else:
			ToastNotification.show_toast("No organic items to compost. Gather crops, berries, mushrooms, or weeds!", ToastNotification.ToastType.INFO, 3.0)
	)
	add_child(interactable)


# ── Barn animal farming helpers ──

func _get_barn_stall_key() -> String:
	return "%d,%d" % [building_cell.x, building_cell.y]

func _get_stall_data(stall_id: String) -> int:
	var key: String = _get_barn_stall_key()
	var barn_data: Dictionary = GameManager.barn_stall_data.get(key, {})
	return barn_data.get(stall_id, -1)

func _set_stall_collected(stall_id: String) -> void:
	var key: String = _get_barn_stall_key()
	if not GameManager.barn_stall_data.has(key):
		GameManager.barn_stall_data[key] = {}
	GameManager.barn_stall_data[key][stall_id] = GameManager.current_day

func _add_animal_stall(pos: Vector2, stall: Dictionary) -> void:
	# Visual sprite
	var sprite := Sprite2D.new()
	sprite.texture = stall["sprite"]
	sprite.z_index = 2
	sprite.position = pos
	add_child(sprite)
	
	# Label showing stall name
	var label := Label.new()
	label.text = stall["name"]
	label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	label.add_theme_font_size_override("font_size", 10)
	label.position = pos + Vector2(-16, -20)
	add_child(label)
	
	# Interactive area
	var interactable := Interactable.new()
	interactable.collision_layer = 4
	interactable.interaction_prompt = "Collect " + stall["product_name"]
	
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(36, 28)
	shape.shape = rect
	interactable.add_child(shape)
	interactable.position = pos + Vector2(0, 4)
	
	var stall_id: String = stall["id"]
	interactable.interacted.connect(func(_i):
		var last_day: int = _get_stall_data(stall_id)
		if last_day >= GameManager.current_day:
			ToastNotification.show_toast(stall["name"] + " — Check back tomorrow!", ToastNotification.ToastType.INFO, 2.5)
			return
		# Give product
		if InventoryManager.add_item(stall["product"], stall["amount"]) == 0:
			_set_stall_collected(stall_id)
			EffectSpawner.spawn_floating_text("+%d %s" % [stall["amount"], stall["product_name"]], interactable.global_position, Color(0.9, 0.85, 0.7))
			ToastNotification.show_toast("Collected " + stall["product_name"] + " from " + stall["name"] + "!", ToastNotification.ToastType.SUCCESS, 2.5)
			# Visual feedback — brief flash
			sprite.modulate = Color(1.0, 1.0, 0.8)
			var tween := create_tween()
			tween.tween_property(sprite, "modulate", Color.WHITE, 0.3)
		else:
			ToastNotification.show_toast("Inventory full!", ToastNotification.ToastType.ERROR, 2.0)
	)
	
	add_child(interactable)

func _add_feed_trough(pos: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = BARN_TROUGH
	sprite.z_index = 2
	sprite.position = pos
	add_child(sprite)
	
	# Label
	var label := Label.new()
	label.text = "Feed Trough"
	label.add_theme_color_override("font_color", Color(0.8, 0.75, 0.6))
	label.add_theme_font_size_override("font_size", 9)
	label.position = pos + Vector2(-18, -12)
	add_child(label)
	
	# Interactive area — player can deposit wheat/berries to feed animals
	var interactable := Interactable.new()
	interactable.collision_layer = 4
	interactable.interaction_prompt = "Deposit feed"
	
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(32, 14)
	shape.shape = rect
	interactable.add_child(shape)
	interactable.position = pos
	
	interactable.interacted.connect(func(_i):
		# Accepts: berry, mushroom, nut, flower as feed
		var feed_items := ["berry", "mushroom", "nut", "flower"]
		var deposited := false
		for feed in feed_items:
			if InventoryManager.has_item(feed, 1):
				InventoryManager.remove_item(feed, 1)
				deposited = true
				ToastNotification.show_toast("Fed the animals! They look happy.", ToastNotification.ToastType.SUCCESS, 2.5)
				# Visual feedback
				sprite.modulate = Color(0.9, 1.0, 0.8)
				var tween := create_tween()
				tween.tween_property(sprite, "modulate", Color.WHITE, 0.5)
				break
		if not deposited:
			ToastNotification.show_toast("Need feed (berries, mushrooms, nuts, or flowers)", ToastNotification.ToastType.INFO, 3.0)
	)
	
	add_child(interactable)


# ──────────────────────────────────────────────
#  🏨  HOTEL INTERIOR — lobby + 3 guest rooms
# ──────────────────────────────────────────────

func _generate_hotel() -> void:
	_room_width = 336
	_room_height = 192
	
	# Full-void background — covers the whole viewport so the sky layer
	# doesn't show through around the room edges (same as every other interior).
	_create_wall_sprite(_room_width, _room_height, Color(0.18, 0.13, 0.1))
	
	# ═══════════════════════════════════════════════════
	#  🖼️  WALL BACKGROUND (pre-made pixel art)
	# ═══════════════════════════════════════════════════
	var bg := Sprite2D.new()
	bg.texture = HOTEL_WALL_BG
	bg.position = Vector2(_room_width / 2.0, _room_height / 2.0)
	bg.z_index = -2
	add_child(bg)
	
	# ═══════════════════════════════════════════════════
	#  🌳  FLOOR (tiled from pre-made floor tile PNG)
	# ═══════════════════════════════════════════════════
	var floor_sprite := Sprite2D.new()
	# Tile the floor tile texture across the room's floor area
	var tile_size := Vector2i(16, 16)
	var tiles_x := ceilf(_room_width / float(tile_size.x))
	var tiles_y := ceilf(_room_height / float(tile_size.y))
	var floor_img := Image.create(tiles_x * tile_size.x, tiles_y * tile_size.y, false, Image.FORMAT_RGBA8)
	for ty in range(tiles_y):
		for tx in range(tiles_x):
			floor_img.blit_rect(HOTEL_FLOOR_TILE.get_image(), Rect2i(0, 0, tile_size.x, tile_size.y), Vector2i(tx * tile_size.x, ty * tile_size.y))
	floor_sprite.texture = ImageTexture.create_from_image(floor_img)
	floor_sprite.position = Vector2(_room_width / 2.0, _room_height / 2.0)
	floor_sprite.z_index = 0
	add_child(floor_sprite)
	
	# ═══════════════════════════════════════════════════
	#  🚪  EXIT DOOR (bottom-center)
	# ═══════════════════════════════════════════════════
	_add_exit_door(Vector2(168, 186))
	# Overlay with a detailed pre-made door sprite
	var door_overlay := Sprite2D.new()
	door_overlay.texture = HOTEL_DOOR
	door_overlay.position = Vector2(168, 186)
	door_overlay.z_index = 3
	add_child(door_overlay)
	
	# ═══════════════════════════════════════════════════
	#  ROOM DIVIDER — horizontal wall across middle
	# ═══════════════════════════════════════════════════
	var wall_color := Color(0.3, 0.22, 0.15)
	var wall_thickness := 4
	var wall_sprite := Sprite2D.new()
	var wall_img := Image.create(_room_width, wall_thickness, false, Image.FORMAT_RGBA8)
	wall_img.fill(wall_color)
	for x in range(_room_width):
		wall_img.set_pixel(x, 0, Color(wall_color.r * 0.7, wall_color.g * 0.7, wall_color.b * 0.7))
	var gap_start := 148
	var gap_end := 188
	for x in range(gap_start, gap_end):
		for y in range(wall_thickness):
			wall_img.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
	wall_sprite.texture = ImageTexture.create_from_image(wall_img)
	wall_sprite.position = Vector2(_room_width / 2.0, 68.0)
	wall_sprite.z_index = 2
	add_child(wall_sprite)
	
	# Collision wall segments
	var add_wall_segment := func(x: float, y: float, w: float, h: float) -> void:
		var wall := StaticBody2D.new()
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(w, h)
		shape.shape = rect
		wall.add_child(shape)
		wall.position = Vector2(x, y)
		add_child(wall)
	
	add_wall_segment.call(gap_start / 2.0, 68.0, float(gap_start), float(wall_thickness))
	add_wall_segment.call(float(gap_end + (_room_width - gap_end) / 2.0), 68.0, float(_room_width - gap_end), float(wall_thickness))
	
	# ═══════════════════════════════════════════════════
	#  🧱  VERTICAL ROOM DIVIDERS between guest rooms
	#  Each has a doorway gap so the player can walk in.
	# ═══════════════════════════════════════════════════
	var room_wall_thick := 8
	var room_ceil_y := 8
	var room_floor_y := 68
	var room_height := room_floor_y - room_ceil_y  # 60
	# Door gap: y range where the wall opening is
	var door_top := 30
	var door_bot := 56
	var door_height := door_bot - door_top  # 26
	
	# Helper to add a vertical wall with a door gap (visual + collision)
	var add_vert_divider := func(center_x: int) -> void:
		var half := room_wall_thick / 2
		# Build the wall image with a door cutout
		var img := Image.create(room_wall_thick, room_height, false, Image.FORMAT_RGBA8)
		img.fill(wall_color)
		# Highlight stripe on the left edge
		for y in range(room_height):
			img.set_pixel(0, y, Color(wall_color.r * 0.7, wall_color.g * 0.7, wall_color.b * 0.7))
		# Darker stripe on the right edge for depth
		for y in range(room_height):
			img.set_pixel(room_wall_thick - 1, y, Color(wall_color.r * 0.5, wall_color.g * 0.5, wall_color.b * 0.5))
		# Punch out the doorway (transparent)
		for dy in range(door_height):
			for dx in range(room_wall_thick):
				img.set_pixel(dx, door_top - room_ceil_y + dy, Color(0.0, 0.0, 0.0, 0.0))
		# Add subtle door frame: darker pixels at the edges of the door opening
		var door_local_y := door_top - room_ceil_y  # 22
		for dx in range(room_wall_thick):
			# Top edge of door
			if door_local_y - 1 >= 0:
				img.set_pixel(dx, door_local_y - 1, Color(0.2, 0.14, 0.08))
			# Bottom edge of door
			if door_local_y + door_height < room_height:
				img.set_pixel(dx, door_local_y + door_height, Color(0.2, 0.14, 0.08))
		# Left/right pillars of the door frame (slightly darker)
		img.set_pixel(0, door_local_y, Color(0.2, 0.14, 0.08))
		img.set_pixel(0, door_local_y + door_height - 1, Color(0.2, 0.14, 0.08))
		img.set_pixel(room_wall_thick - 1, door_local_y, Color(0.2, 0.14, 0.08))
		img.set_pixel(room_wall_thick - 1, door_local_y + door_height - 1, Color(0.2, 0.14, 0.08))
		
		var sprite := Sprite2D.new()
		sprite.texture = ImageTexture.create_from_image(img)
		sprite.position = Vector2(center_x, (room_ceil_y + room_floor_y) / 2.0)
		sprite.z_index = 2
		add_child(sprite)
		
		# Collision: two segments — above the door and below the door
		var top_seg_h := door_top - room_ceil_y  # 22
		var bot_seg_top := door_bot
		var bot_seg_h := room_floor_y - door_bot  # 12
		if top_seg_h > 0:
			add_wall_segment.call(float(center_x), room_ceil_y + top_seg_h / 2.0, float(room_wall_thick), float(top_seg_h))
		if bot_seg_h > 0:
			add_wall_segment.call(float(center_x), bot_seg_top + bot_seg_h / 2.0, float(room_wall_thick), float(bot_seg_h))
	
	# Left divider between Room 1 and center hallway
	add_vert_divider.call(144)
	# Right divider between center hallway and Room 3
	add_vert_divider.call(192)
	
	# ═══════════════════════════════════════════════════
	#  💡  DECORATIVE LIGHTING
	# ═══════════════════════════════════════════════════
	# Wall sconces flanking the room divider gap
	_add_sprite(HOTEL_WALL_SCONCE, Vector2(130, 70), 3)
	_add_sprite(HOTEL_WALL_SCONCE, Vector2(206, 70), 3)
	# Chandelier in the lobby
	_add_sprite(HOTEL_CHANDELIER, Vector2(168, 90), 4)
	
	# ═══════════════════════════════════════════════════
	#  🛏️  GUEST ROOM 1 (left, x: 8–140, y: 8–64)
	# ═══════════════════════════════════════════════════
	_add_hotel_bed(Vector2(68, 22))
	_add_sprite(HOTEL_NIGHTSTAND, Vector2(68, 48), 2)
	_add_sprite(HOTEL_RUG_SMALL, Vector2(68, 34), 1)
	_add_sprite(HOTEL_WALL_SCONCE, Vector2(12, 16), 3)
	
	# ═══════════════════════════════════════════════════
	#  🛏️  GUEST ROOM 2 (center, x: 148–188 hall)
	# ═══════════════════════════════════════════════════
	_add_hotel_bed(Vector2(168, 22))
	_add_sprite(HOTEL_NIGHTSTAND, Vector2(168, 48), 2)
	_add_sprite(HOTEL_RUG_SMALL, Vector2(168, 34), 1)
	
	# ═══════════════════════════════════════════════════
	#  🛏️  GUEST ROOM 3 (right, x: 196–328, y: 8–64)
	# ═══════════════════════════════════════════════════
	_add_hotel_bed(Vector2(268, 22))
	_add_sprite(HOTEL_NIGHTSTAND, Vector2(268, 48), 2)
	_add_sprite(HOTEL_RUG_SMALL, Vector2(268, 34), 1)
	_add_sprite(HOTEL_WALL_SCONCE, Vector2(324, 16), 3)
	
	# ═══════════════════════════════════════════════════
	#  🔥  COZY FIREPLACE on left lobby wall
	# ═══════════════════════════════════════════════════
	_add_sprite(HOTEL_FIREPLACE, Vector2(24, 126), 2)
	
	# ═══════════════════════════════════════════════════
	#  🪜  DECORATIVE STAIRCASE (lobby left)
	# ═══════════════════════════════════════════════════
	_add_sprite(HOTEL_STAIRS, Vector2(36, 144), 2)
	
	# ═══════════════════════════════════════════════════
	#  🛋️  LOBBY (bottom section, y: 76–188)
	# ═══════════════════════════════════════════════════
	
	# Large ornate rug in center lobby
	_add_sprite(HOTEL_RUG_LARGE, Vector2(168, 130), 1)
	
	# Two armchairs flanking the rug, facing inward
	_add_sprite(HOTEL_ARMCHAIR, Vector2(105, 120), 2)
	_add_sprite(HOTEL_ARMCHAIR, Vector2(231, 120), 2)
	
	# Coffee table between armchairs
	_add_sprite(HOTEL_LOBBY_TABLE, Vector2(168, 116), 2)
	
	# Wall art (scenic painting) on the divider wall above the lobby
	_add_sprite(HOTEL_WALL_ART, Vector2(168, 82), 3)
	
	# Front desk at bottom center — interactable that collects hotel earnings
	_add_hotel_front_desk(Vector2(168, 170))
	
	# Potted plants flanking the front desk
	_add_sprite(HOTEL_POTTED_PLANT, Vector2(135, 170), 2)
	_add_sprite(HOTEL_POTTED_PLANT, Vector2(201, 170), 2)
	
	# Potted plants flanking the exit door
	_add_sprite(HOTEL_POTTED_PLANT, Vector2(148, 186), 2)
	_add_sprite(HOTEL_POTTED_PLANT, Vector2(188, 186), 2)


## Helper: add a decorative pre-made sprite at a position with a given z_index.
func _add_sprite(tex: Texture2D, pos: Vector2, z: int) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.position = pos
	sprite.z_index = z
	add_child(sprite)

## Add a hotel-specific bed as an Interactable (press E to Sleep).
func _add_hotel_bed(pos: Vector2) -> Interactable:
	var bed := Interactable.new()
	bed.collision_layer = 4
	bed.interaction_prompt = "Sleep"
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(32, 24)
	shape.shape = rect
	bed.add_child(shape)
	bed.position = pos
	var sprite := Sprite2D.new()
	sprite.texture = HOTEL_BED_SPRITE
	sprite.z_index = 2
	bed.add_child(sprite)
	bed.interacted.connect(_on_bed_interacted)
	add_child(bed)
	self.bed = bed
	return bed

## Create the hotel front desk — an Interactable that collects coins from Hotel.gd.
func _add_hotel_front_desk(pos: Vector2) -> void:
	var desk := Interactable.new()
	desk.collision_layer = 4
	desk.interaction_prompt = "Check-in Desk"
	
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(32, 16)
	shape.shape = rect
	desk.add_child(shape)
	
	# Use pre-made pixel art desk sprite
	var desk_sprite := Sprite2D.new()
	desk_sprite.texture = HOTEL_FRONT_DESK
	desk_sprite.z_index = 2
	desk.add_child(desk_sprite)
	
	desk.position = pos
	
	# Label
	var label := Label.new()
	label.text = "Front Desk"
	label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	label.add_theme_font_size_override("font_size", 9)
	label.position = Vector2(-20, -14)
	desk.add_child(label)
	
	desk.interacted.connect(func(_interactor: Node) -> void:
		if _hotel_ref and _hotel_ref.is_inside_tree():
			if _hotel_ref.try_collect():
				pass  # Toast and effects handled by Hotel.gd
			else:
				var display: String = _hotel_ref.get_earnings_display()
				ToastNotification.show_toast("Hotel — " + display, ToastNotification.ToastType.INFO, 2.5)
		else:
			ToastNotification.show_toast("The desk is unattended...", ToastNotification.ToastType.INFO, 2.0)
	)
	
	add_child(desk)


## Place a guest NPC sprite in a hotel room.
## appearance_index selects which texture from GUEST_APPEARANCES to use.
func _add_hotel_guest(pos: Vector2, appearance_index: int, guest_name: String) -> void:
	var guest := Sprite2D.new()
	var tex: Texture2D = GUEST_APPEARANCES[appearance_index % GUEST_APPEARANCES.size()]
	if tex:
		guest.texture = tex
	guest.position = pos
	guest.z_index = 2
	add_child(guest)
	
	# Name label above guest
	var label := Label.new()
	label.text = guest_name
	label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	label.add_theme_font_size_override("font_size", 8)
	label.position = Vector2(-12, -18)
	guest.add_child(label)
	
	# Add wander behavior so hotel guests move around instead of standing still
	var wander := InteriorWanderNPC.new()
	wander._is_remote = NetworkManager.is_network_active() and not multiplayer.is_server()
	wander._cell_key = "%d,%d" % [building_cell.x, building_cell.y]
	guest.add_child(wander)
	
	# Talk interaction — pressing E shows a greeting bubble
	var guest_ref: Sprite2D = guest
	var talk_lines: Array[String] = [
		"Lovely inn, isn't it?",
		"I'm just resting before exploring more of the island!",
		"The sea air here is wonderful.",
		"I've heard great things about this island's sights.",
		"The beds here are heavenly!",
		"Have you seen the sunset from the dock?",
	]
	var interact := Interactable.new()
	interact.name = "Talk"
	interact.collision_layer = 4
	interact.interaction_prompt = "Talk to " + guest_name
	var ishape := CollisionShape2D.new()
	var irect := RectangleShape2D.new()
	irect.size = Vector2(16, 20)
	ishape.shape = irect
	interact.add_child(ishape)
	interact.interacted.connect(func(_i: Node) -> void:
		if is_instance_valid(guest_ref):
			_spawn_npc_dialogue(guest_ref.global_position, talk_lines[randi() % talk_lines.size()])
	)
	guest.add_child(interact)
	
	# Sparse ambient chatter — only while the player is inside the hotel
	var chatter := Timer.new()
	chatter.name = "GuestChatter"
	chatter.wait_time = 20.0 + randf() * 25.0
	chatter.autostart = true
	chatter.timeout.connect(func() -> void:
		if not is_inside_tree() or not GameManager.inside_interior or not is_instance_valid(guest_ref):
			return
		_spawn_npc_dialogue(guest_ref.global_position, talk_lines[randi() % talk_lines.size()], 2.5)
	)
	guest.add_child(chatter)
	
	_guest_sprites.append(guest)


## Called when Hotel.gd emits guests_changed signal.
## Spawns NPC sprites in guest rooms when visitors check in,
## and clears them when they depart.
func _on_hotel_guests_changed(count: int) -> void:
	_guests_active = count > 0
	
	# Clear existing guest sprites
	for g in _guest_sprites:
		if is_instance_valid(g):
			g.queue_free()
	_guest_sprites.clear()
	
	if count <= 0:
		return
	
	# Spawn guest NPCs, one per available spot, cycling appearances.
	# Use the full display-name pools from VisitorNPC so hotel guests
	# get titles too ("Mara the Explorer"), matching the island visitors.
	var guest_name_pools: Array[Array] = [
		VisitorNPC.get_npc_names(VisitorNPC.VisitorType.EXPLORER),
		VisitorNPC.get_npc_names(VisitorNPC.VisitorType.FISHER),
		VisitorNPC.get_npc_names(VisitorNPC.VisitorType.VENDOR),
		VisitorNPC.get_npc_names(VisitorNPC.VisitorType.SIGHTSEER),
	]
	for i in range(mini(count, _HOTEL_GUEST_SPOTS.size())):
		var pos: Vector2 = _HOTEL_GUEST_SPOTS[i]
		var appearance_idx: int = i % GUEST_APPEARANCES.size()
		var name_pool: Array = guest_name_pools[appearance_idx % guest_name_pools.size()]
		var name_str: String = name_pool[randi() % name_pool.size()]
		_add_hotel_guest(pos, appearance_idx, name_str)
	
	# Apply day/night visibility immediately
	var gm: GameManager = GameManager
	if gm:
		_update_guest_visibility(gm.get_hour())


## Called when GameManager.time_changed fires.
## Hotel guests are staying inside the building — they're always visible
## while registered (the visitor NPCs are "checking in" to the hotel rooms).
func _on_time_changed(hour: int, _minute: int) -> void:
	_update_guest_visibility(hour)

func _update_guest_visibility(hour: int) -> void:
	if _guest_sprites.is_empty():
		return
	# Guests are staying in the hotel interior — always visible while
	# registered (the real visitor NPCs are outside on the island).
	# No day/night hiding needed since this is the hotel interior view.
	for g in _guest_sprites:
		if is_instance_valid(g):
			g.visible = true


# ═══════════════════════════════════════════════════════════════════════
#  🏪  TOWN BUILDING INTERIORS
# ═══════════════════════════════════════════════════════════════════════
# Specialized interiors for restored town ruin buildings.
# Each has themed pixel-art sprites and unique interactions.
# ═══════════════════════════════════════════════════════════════════════

# ── Shared helper: place an NPC character sprite in an interior ──
## Spawn a styled dialogue bubble at the given world position above an NPC.
## Uses a dark semi-transparent background with warm text, matching
## the game's other dialogue bubble styling.
func _spawn_npc_dialogue(pos: Vector2, text: String, duration: float = 3.5) -> void:
	var parent: Node = get_tree().current_scene
	if not parent:
		return
	
	var container := Node2D.new()
	container.z_index = 105
	
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 6)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
	label.add_theme_constant_override("outline_size", 1)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	# Compact fixed size matching island NPC dialogue bubbles (72x16),
	# so long lines wrap instead of producing a screen-filling bubble.
	label.custom_minimum_size = Vector2(72, 16)
	label.size = Vector2(72, 16)
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.88)
	style.border_color = Color(1.0, 0.6, 0.1, 0.7)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	label.add_theme_stylebox_override("normal", style)
	
	container.add_child(label)
	parent.add_child(container)
	
	# Center above the NPC, high enough to clear the 24px-tall sprite
	# (its top edge sits ~12px above the origin).
	container.position = pos - Vector2(36, 30)
	
	# Fade in, hold, fade out
	container.modulate.a = 0.0
	var tween := container.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(container, "modulate:a", 1.0, 0.2)
	tween.tween_interval(duration)
	tween.tween_property(container, "modulate:a", 0.0, 0.3)
	tween.tween_callback(container.queue_free)


func _add_interior_npc(pos: Vector2, texture_res: Texture2D, name_str: String, tint: Color = Color.WHITE, scale_mult: float = 1.0, dialogue_lines: Array[String] = []) -> Interactable:
	## Creates an interactive NPC with a sprite, name label, and optional dialogue.
	## The NPC is an Interactable — walk up and press E to chat.
	var interactable := Interactable.new()
	interactable.collision_layer = 4
	interactable.interaction_prompt = "Talk to %s" % [name_str]
	interactable.position = pos
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(20, 20)
	shape.shape = rect
	interactable.add_child(shape)
	
	var npc := Sprite2D.new()
	npc.texture = texture_res
	npc.z_index = 3
	npc.modulate = tint
	npc.scale = Vector2(scale_mult, scale_mult)
	interactable.add_child(npc)
	var label := Label.new()
	label.text = name_str
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
	label.add_theme_font_size_override("font_size", 9)
	label.position = Vector2(-16, -22)
	npc.add_child(label)
	
	if dialogue_lines.is_empty():
		dialogue_lines = ["Hello there!", "Lovely day, isn't it?"]
	
	interactable.interacted.connect(func(_interactor: Node) -> void:
		var line: String = dialogue_lines[randi() % dialogue_lines.size()]
		_spawn_npc_dialogue(interactable.global_position + Vector2(0, -16), line, 3.5)
	)
	
	add_child(interactable)
	return interactable


## Map a VisitorNPC.VisitorType to the correct interior NPC texture.
## Uses the same preloaded textures used for hotel/tavern NPCs.
func _get_npc_texture_for_visitor_type(vtype: int) -> Texture2D:
	match vtype:
		0:  # Explorer
			return NPC_EXPLORER
		1:  # Fisher
			return NPC_FISHER
		2:  # Shopper
			return NPC_VENDOR
		3:  # Sightseer
			return NPC_SIGHTSEER
		4:  # Vendor
			return NPC_VENDOR
		5:  # Artist
			return NPC_EXPLORER
		6:  # Forager
			return NPC_EXPLORER
		_:
			return NPC_EXPLORER


## Spawn a resident NPC sprite with wander behavior inside this interior.
## Only does something if _resident_visitor_type >= 0 (a resident is assigned).
func _spawn_resident_npc() -> void:
	if _resident_visitor_type < 0:
		return  # No resident assigned to this building
	
	# Don't show the resident inside if they're currently outside wandering/tending.
	# Find their TownResidentNPC node in the world to check schedule.
	if not _is_resident_currently_inside():
		return
	
	var tex: Texture2D = _get_npc_texture_for_visitor_type(_resident_visitor_type)
	var tint: Color = Color.WHITE
	# Match the resident's own random sprite variant + role tint so the interior
	# NPC looks like the same person you see outside (not a different texture).
	var resident_node := _find_resident_node()
	if resident_node and resident_node.has_node("Sprite2D"):
		var resident_sprite := resident_node.get_node("Sprite2D") as Sprite2D
		if resident_sprite and resident_sprite.texture:
			tex = resident_sprite.texture
			tint = resident_sprite.modulate
	
	# Create the NPC sprite
	var npc := Sprite2D.new()
	npc.texture = tex
	npc.modulate = tint
	npc.z_index = 3
	npc.position = Vector2(_room_width * 0.5, _room_height * 0.5)
	add_child(npc)
	
	# Name label above the NPC
	var label := Label.new()
	label.text = _resident_name
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
	label.add_theme_font_size_override("font_size", 9)
	label.position = Vector2(-20, -22)
	npc.add_child(label)
	
	# Add InteriorWanderNPC so the resident moves around inside the room
	var wander := InteriorWanderNPC.new()
	wander._is_remote = NetworkManager.is_network_active() and not multiplayer.is_server()
	wander._cell_key = "%d,%d" % [building_cell.x, building_cell.y]
	npc.add_child(wander)
	
	# Talk interaction — pressing E opens the same quest dialogue panel as
	# talking to the resident outside, so residents are interactable inside
	# their own home. Mirrors the hotel guest "Talk" pattern.
	var npc_sprite: Sprite2D = npc
	var interact := Interactable.new()
	interact.name = "Talk"
	interact.collision_layer = 4
	interact.interaction_prompt = "Talk to " + _resident_name
	var ishape := CollisionShape2D.new()
	var irect := RectangleShape2D.new()
	irect.size = Vector2(16, 22)
	ishape.shape = irect
	interact.add_child(ishape)
	interact.interacted.connect(func(_i: Node) -> void:
		if not is_instance_valid(npc_sprite):
			return
		# Open the resident's quest dialogue. force=true skips the physical
		# in-range check (this sprite lives in the interior void, so the
		# resident's world Area2D can never see the player here).
		var rn := _find_resident_node()
		if rn:
			rn.open_quest_dialogue(true)
		else:
			_spawn_npc_dialogue(npc_sprite.global_position, "Hello, neighbor!", 2.5)
	)
	npc.add_child(interact)


## Find the recruited resident NPC in the world by its unique id.
func _find_resident_node() -> TownResidentNPC:
	if _resident_npc_id.is_empty():
		return null
	if not is_inside_tree():
		return null
	for n in get_tree().get_nodes_in_group("town_residents"):
		if n is TownResidentNPC and n.npc_id == _resident_npc_id:
			return n as TownResidentNPC
	return null


## Check whether this resident is currently inside their building (vs outside
## wandering, at their post, or heading home). Returns true if the resident
## should appear in the interior view.
func _is_resident_currently_inside() -> bool:
	# Unique-id lookup first (names can collide between same-type residents).
	var resident_node := _find_resident_node()
	if resident_node:
		return resident_node.is_inside_building()
	if _resident_name.is_empty():
		return false
	if not is_inside_tree():
		return true  # Can't reach the world tree — spawn anyway as fallback
	# Name fallback for residents assigned before npc ids were propagated.
	for n in get_tree().get_nodes_in_group("town_residents"):
		if n is TownResidentNPC and n.npc_name == _resident_name:
			return n.is_inside_building()
	# No matching NPC found — spawn anyway as fallback
	return true


# ── Shared helper: small decorative item sprite ──
func _add_town_decorative(pos: Vector2, color: Color, w: int, h: int) -> void:
	var sprite := Sprite2D.new()
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(color)
	var border := Color(color.r * 0.5, color.g * 0.5, color.b * 0.5)
	for x in range(w):
		img.set_pixel(x, 0, border)
		img.set_pixel(x, h - 1, border)
	for y in range(h):
		img.set_pixel(0, y, border)
		img.set_pixel(w - 1, y, border)
	sprite.texture = ImageTexture.create_from_image(img)
	sprite.position = pos
	sprite.z_index = 2
	add_child(sprite)


# ═══════════════════════════════════════════════════════════════════════
#  🥖  BAKERY INTERIOR
# ═══════════════════════════════════════════════════════════════════════

func _add_bakery_oven(pos: Vector2) -> Interactable:
	var interactable := Interactable.new()
	interactable.collision_layer = 4
	interactable.interaction_prompt = "Bake"
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(36, 28)
	shape.shape = rect
	interactable.add_child(shape)
	interactable.position = pos
	var sprite := Sprite2D.new()
	sprite.texture = preload("res://assets/generated/interior_bakery_oven_frame_0.png")
	sprite.z_index = 2
	interactable.add_child(sprite)
	interactable.interacted.connect(func(_i: Node) -> void:
		_start_bakery_minigame()
	)
	add_child(interactable)
	# Add a floating "Bake" text label above the oven
	var bake_label := Label.new()
	bake_label.text = "Bake"
	bake_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bake_label.add_theme_font_size_override("font_size", 8)
	bake_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7, 0.85))
	bake_label.position = Vector2(-16, -24)
	bake_label.size = Vector2(32, 12)
	bake_label.z_index = 10
	bake_label.mouse_filter = Control.MOUSE_FILTER_PASS
	interactable.add_child(bake_label)
	return interactable

func _add_bakery_counter(pos: Vector2) -> Interactable:
	var interactable := Interactable.new()
	interactable.collision_layer = 4
	interactable.interaction_prompt = "Sell baked goods"
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(36, 18)
	shape.shape = rect
	interactable.add_child(shape)
	interactable.position = pos
	var sprite := Sprite2D.new()
	sprite.texture = preload("res://assets/generated/interior_bakery_counter_frame_0.png")
	sprite.z_index = 2
	interactable.add_child(sprite)
	interactable.interacted.connect(func(_i: Node) -> void:
		_open_bakery_sell_ui()
	)
	add_child(interactable)
	return interactable

func _start_bakery_minigame() -> void:
	## Show a payment choice popup, then launch the minigame.
	## Player can pay with $10 coins OR 1 dough + 1 wood.
	_show_bake_cost_choice()

## Show a small popup letting the player choose how to pay for baking.
func _show_bake_cost_choice() -> void:
	var has_dough: bool = InventoryManager.get_count("dough") >= 1
	var has_wood: bool = InventoryManager.get_count("wood") >= 1
	var has_coins: bool = GameManager.money >= 10
	var has_ingredients: bool = has_dough and has_wood
	
	if not has_coins and not has_ingredients:
		var msg: String = "Can't afford to bake! Need $10 coins, or 1 Dough + 1 Wood."
		ToastNotification.show_toast(msg, ToastNotification.ToastType.ERROR, 3.0)
		return
	
	var popup := CanvasLayer.new()
	popup.layer = 10
	popup.name = "BakeCostPopup"
	add_child(popup)
	
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.anchors_preset = Control.PRESET_FULL_RECT
	dim.mouse_filter = Control.MOUSE_FILTER_PASS
	popup.add_child(dim)
	
	var panel_style := LIGHT_WOOD
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", panel_style)
	panel.position = Vector2(160, 150)
	panel.size = Vector2(180, 140)
	popup.add_child(panel)
	
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	layout.position = Vector2(10, 10)
	panel.add_child(layout)
	
	var title := Label.new()
	title.text = "How to pay for baking?"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	layout.add_child(title)
	
	var close_popup := func() -> void:
		if is_instance_valid(popup):
			popup.queue_free()
	
	var launch := func(pay_with_coins: bool) -> void:
		close_popup.call()
		if pay_with_coins:
			GameManager.add_money(-10)
		else:
			InventoryManager.remove_item("dough", 1)
			InventoryManager.remove_item("wood", 1)
		_launch_bakery_minigame()
	
	var gold_btn := Button.new()
	gold_btn.text = "Pay $10 coins" if has_coins else "Pay $10 coins [need more]"
	gold_btn.disabled = not has_coins
	gold_btn.add_theme_font_size_override("font_size", 11)
	gold_btn.pressed.connect(func() -> void: launch.call(true))
	layout.add_child(gold_btn)
	
	var ingredients_btn := Button.new()
	ingredients_btn.text = "Use 1 Dough + 1 Wood" if has_ingredients else "Use 1 Dough + 1 Wood [need more]"
	ingredients_btn.disabled = not has_ingredients
	ingredients_btn.add_theme_font_size_override("font_size", 11)
	ingredients_btn.pressed.connect(func() -> void: launch.call(false))
	layout.add_child(ingredients_btn)
	
	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel [Esc]"
	cancel_btn.add_theme_font_size_override("font_size", 10)
	cancel_btn.pressed.connect(close_popup)
	layout.add_child(cancel_btn)
	
	# Esc to close
	var input_catcher := Control.new()
	input_catcher.mouse_filter = Control.MOUSE_FILTER_PASS
	input_catcher.anchors_preset = Control.PRESET_FULL_RECT
	input_catcher.focus_mode = Control.FOCUS_ALL
	popup.add_child(input_catcher)
	input_catcher.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE:
				close_popup.call()
				get_viewport().set_input_as_handled()
	)

## Launch the actual baking minigame (cost already paid).
func _launch_bakery_minigame() -> void:
	var minigame_scene := preload("res://scenes/ui/BakeryMiniGame.tscn")
	var minigame: BakeryMiniGame = minigame_scene.instantiate()
	var hud: CanvasLayer = get_tree().get_first_node_in_group("hud") as CanvasLayer
	if not hud:
		minigame.queue_free()
		return
	hud.add_child(minigame)
	
	minigame.start_minigame()
	
	minigame.baking_completed.connect(func(quality: int) -> void:
		# Map quality to a baked good item
		var result_item: String
		var quality_name: String = BakeryMiniGame.QUALITY_NAMES.get(quality, "Mystery")
		match quality:
			BakeryMiniGame.Quality.BURNT:
				result_item = "bread"
				ToastNotification.show_toast("Burnt! The baker sighs...", ToastNotification.ToastType.INFO, 2.5)
			BakeryMiniGame.Quality.NORMAL:
				result_item = "fresh_bread"
				ToastNotification.show_toast("Fresh bread! A simple, warm loaf.", ToastNotification.ToastType.SUCCESS, 2.5)
			BakeryMiniGame.Quality.SILVER:
				result_item = "buttered_bread"
				ToastNotification.show_toast("Silver-quality buttered bread! Delicious!", ToastNotification.ToastType.SUCCESS, 2.5)
			BakeryMiniGame.Quality.GOLD:
				result_item = "cinnamon_toast"
				ToastNotification.show_toast("Gold-quality cinnamon toast! Perfect bake!", ToastNotification.ToastType.SUCCESS, 2.5)
			BakeryMiniGame.Quality.IRIDIUM:
				result_item = "chocolate_croissant"
				ToastNotification.show_toast("Iridium-quality chocolate croissant! A masterpiece!", ToastNotification.ToastType.SUCCESS, 2.5)
			_:
				result_item = "bread"
		
		# Tag the item's description with the quality it was baked at
		var item_data := DataManager.get_item(result_item)
		if item_data:
			# Remove any previous quality tag to avoid stacking
			var base_desc: String = item_data.description
			# Handle BBCode color format: [color=#RRGGBB]Name[/color] desc...
			if base_desc.begins_with("[color="):
				var close_tag_idx: int = base_desc.find("[/color]")
				if close_tag_idx >= 0:
					base_desc = base_desc.substr(close_tag_idx + 8).strip_edges()
			# Handle old plain bracket format: [Name] desc...
			elif base_desc.begins_with("["):
				var idx: int = base_desc.find("] ")
				if idx > 0:
					base_desc = base_desc.substr(idx + 2)
			var quality_color: Color = BakeryMiniGame.QUALITY_COLORS.get(quality, Color.WHITE)
			item_data.description = "[color=#%s]%s[/color] %s" % [quality_color.to_html(false), quality_name, base_desc]
		
		if InventoryManager.add_item(result_item, 1) == 0:
			var name_str: String = item_data.display_name if item_data else result_item
			ToastNotification.show_toast("You baked %s!" % [name_str], ToastNotification.ToastType.SUCCESS, 2.5)
		else:
			ToastNotification.show_toast("Inventory full — baked goods lost!", ToastNotification.ToastType.ERROR, 2.0)
		
		# Notify objective manager about the bake (for Master Baker objective)
		var obj_mgr := get_tree().get_first_node_in_group("objective_manager")
		if obj_mgr and obj_mgr.has_method("on_bake_completed"):
			obj_mgr.on_bake_completed(quality)
		
		# Clean up after a short delay
		if is_instance_valid(minigame):
			minigame.queue_free()
	)

## Open a sell-popup that lists each baked good the player has and lets
## them choose which to sell at the premium bakery price (1.3x).
func _open_bakery_sell_ui() -> void:
	var baked_items: Array[String] = ["fresh_bread", "buttered_bread", "cinnamon_toast", "fruit_tart_bake", "chocolate_croissant", "bread", "croissant", "dough"]
	
	var available: Array[Dictionary] = []
	for item_id: String in baked_items:
		var count: int = InventoryManager.get_count(item_id)
		if count <= 0:
			continue
		var item_data := DataManager.get_item(item_id)
		if not item_data:
			continue
		var premium_price: int = ceilf(item_data.sell_price * 1.3)
		available.append({"id": item_id, "name": item_data.display_name, "count": count, "price": premium_price})
	
	if available.is_empty():
		ToastNotification.show_toast("No baked goods to sell. Try the oven!", ToastNotification.ToastType.INFO, 2.5)
		return
	
	_show_sell_choice_popup("Sell Baked Goods", available, func(item_id: String, count: int) -> int:
		var item_data := DataManager.get_item(item_id)
		if not item_data:
			return 0
		var premium_price: int = ceilf(item_data.sell_price * 1.3)
		InventoryManager.remove_item(item_id, count)
		GameManager.add_money(premium_price * count)
		return premium_price * count
	)

func _add_bakery_shelves(pos: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = preload("res://assets/generated/interior_bakery_shelves_frame_0.png")
	sprite.position = pos
	sprite.z_index = 2
	add_child(sprite)

func _add_bakery_table(pos: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = preload("res://assets/generated/interior_bakery_table_frame_0.png")
	sprite.position = pos
	sprite.z_index = 2
	add_child(sprite)

func _generate_bakery() -> void:
	_room_width = 240
	_room_height = 144
	_create_wall_sprite(_room_width, _room_height, Color(0.28, 0.22, 0.15))
	_create_floor(_room_width, _room_height)
	_add_baseboards(_room_width, _room_height)
	_add_exit_door(Vector2(118, 130))

	# 🍞 Oven (left wall)
	_add_bakery_oven(Vector2(32, 50))
	# 🧑‍🍳 Baker NPC behind the counter
	_add_interior_npc(Vector2(190, 50), NPC_VENDOR, "Baker Bertie", Color(0.95, 0.9, 0.8), 1.0, [
		"Fresh bread just came out of the oven!",
		"Try my famous sourdough — it's got a secret ingredient.",
		"A pinch of cinnamon makes all the difference!",
		"Nothing beats the smell of baking in the morning.",
	])
	# 🍞 Prep table (center-left)
	_add_bakery_table(Vector2(72, 80))
	# 🍞 Ingredient shelves (top wall)
	_add_bakery_shelves(Vector2(120, 30))
	# 🍞 Bread counter (right side)
	_add_bakery_counter(Vector2(190, 70))
	# 🪑 Decor: small stool
	_add_town_decorative(Vector2(200, 108), Color(0.4, 0.25, 0.14), 12, 8)
	# 🪟 Window
	_add_window(Vector2(72, 12), 32, 16)
	_add_window(Vector2(190, 12), 32, 16)


# ═══════════════════════════════════════════════════════════════════════
#  🍽️  RESTAURANT INTERIOR
# ═══════════════════════════════════════════════════════════════════════

func _add_restaurant_stove(pos: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = preload("res://assets/generated/interior_restaurant_stove_frame_0.png")
	sprite.position = pos
	sprite.z_index = 2
	add_child(sprite)

func _add_restaurant_table(pos: Vector2) -> void:
	## Purely decorative dining table (no interaction — use the counter to sell crops).
	var sprite := Sprite2D.new()
	sprite.texture = preload("res://assets/generated/interior_restaurant_table_frame_0.png")
	sprite.position = pos
	sprite.z_index = 2
	add_child(sprite)

## Show a choice popup for selling crops/meals at the restaurant.
func _sell_crops_at_restaurant() -> void:
	var restaurant: RestaurantSystem = get_tree().get_first_node_in_group("restaurant_system") as RestaurantSystem
	if not restaurant:
		ToastNotification.show_toast("The chef isn't here right now...", ToastNotification.ToastType.INFO, 2.5)
		return
	
	# Collect eligible items
	var available: Array[Dictionary] = []
	for item_id: String in InventoryManager.get_all_counts().keys():
		var item_data := DataManager.get_item(item_id)
		# If the id isn't a registered item, it may still be a crop (whose
		# yield item is registered here) — resolve a friendly name regardless.
		if not item_data:
			var crop_for_id: CropData = restaurant.get_crop_for_yield(item_id)
			if crop_for_id:
				available.append({"id": item_id, "name": crop_for_id.display_name, "count": InventoryManager.get_count(item_id), "price": restaurant.calculate_price(item_id, InventoryManager.get_count(item_id), 0)})
			continue
		if item_data.category != "crop" and item_data.category != "meal":
			continue
		var count: int = InventoryManager.get_count(item_id)
		if count <= 0:
			continue
		var price: int = restaurant.calculate_price(item_id, count, 0)
		available.append({"id": item_id, "name": item_data.display_name, "count": count, "price": price})
	
	if available.is_empty():
		ToastNotification.show_toast("No crops or meals to sell. Bring produce from your farm!", ToastNotification.ToastType.INFO, 3.0)
		return
	
	# Show daily special
	var special := restaurant.get_daily_special()
	var special_name: String = special.get("name", "?")
	ToastNotification.show_toast("Today's special: %s — 2x price!" % [special_name], ToastNotification.ToastType.INFO, 4.0)
	
	_show_sell_choice_popup("Sell at Restaurant", available, func(item_id: String, count: int) -> int:
		return restaurant.sell_crops(item_id, count, 0)
	)

## Show a generic sell-choice popup.
## title: title text shown at the top
## items: Array[{"id","name","count","price"}]
## sell_callback(item_id, count) -> gold_earned
func _show_sell_choice_popup(title: String, items: Array, sell_callback: Callable) -> void:
	var popup := CanvasLayer.new()
	popup.layer = 10
	popup.name = "SellChoicePopup"
	add_child(popup)
	
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.anchors_preset = Control.PRESET_FULL_RECT
	dim.mouse_filter = Control.MOUSE_FILTER_PASS
	popup.add_child(dim)
	
	var panel_style := LIGHT_WOOD
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", panel_style)
	panel.position = Vector2(120, 100)
	panel.size = Vector2(280, 240)
	popup.add_child(panel)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.custom_minimum_size = Vector2(260, 200)
	panel.add_child(margin)
	
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 6)
	margin.add_child(layout)
	
	# Title row
	var title_row := HBoxContainer.new()
	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title_label)
	var coins_label := Label.new()
	coins_label.text = "$%d" % GameManager.money
	coins_label.add_theme_font_size_override("font_size", 14)
	coins_label.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
	title_row.add_child(coins_label)
	layout.add_child(title_row)
	
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)
	
	var item_list := VBoxContainer.new()
	item_list.add_theme_constant_override("separation", 4)
	scroll.add_child(item_list)
	
	var close_popup := func() -> void:
		if is_instance_valid(popup):
			popup.queue_free()
	
	for entry: Dictionary in items:
		var row := HBoxContainer.new()
		var name_label := Label.new()
		name_label.text = "%s x%d" % [entry["name"], entry["count"]]
		name_label.add_theme_font_size_override("font_size", 12)
		name_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7))
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		
		var price_label := Label.new()
		price_label.text = "$%d" % entry["price"]
		price_label.add_theme_font_size_override("font_size", 11)
		price_label.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
		row.add_child(price_label)
		
		var sell_btn := Button.new()
		sell_btn.text = "Sell All"
		sell_btn.add_theme_font_size_override("font_size", 10)
		var item_id: String = entry["id"]
		var item_name: String = entry["name"]
		var item_count: int = entry["count"]
		var item_price: int = entry["price"]
		sell_btn.pressed.connect(func() -> void:
			var earned: int = sell_callback.call(item_id, item_count)
			if earned > 0:
				ToastNotification.show_toast("Sold %d %s for $%d!" % [item_count, item_name, earned], ToastNotification.ToastType.SUCCESS, 3.0)
			close_popup.call()
		)
		row.add_child(sell_btn)
		item_list.add_child(row)
	
	var close_btn := Button.new()
	close_btn.text = "Close [Esc]"
	close_btn.add_theme_font_size_override("font_size", 10)
	close_btn.pressed.connect(close_popup)
	layout.add_child(close_btn)
	
	var input_catcher := Control.new()
	input_catcher.mouse_filter = Control.MOUSE_FILTER_PASS
	input_catcher.anchors_preset = Control.PRESET_FULL_RECT
	input_catcher.focus_mode = Control.FOCUS_ALL
	popup.add_child(input_catcher)
	input_catcher.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE:
				close_popup.call()
				get_viewport().set_input_as_handled()
	)

func _add_restaurant_counter(pos: Vector2) -> Interactable:
	## Creates the serving counter as an interactable that sells crops.
	## A cashier NPC stands behind it.
	var interactable := Interactable.new()
	interactable.collision_layer = 4
	interactable.interaction_prompt = "Sell crops"
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40, 20)
	shape.shape = rect
	interactable.add_child(shape)
	interactable.position = pos
	
	var sprite := Sprite2D.new()
	sprite.texture = preload("res://assets/generated/interior_restaurant_counter_frame_0.png")
	sprite.z_index = 2
	interactable.add_child(sprite)
	
	interactable.interacted.connect(func(_i: Node) -> void:
		_sell_crops_at_restaurant()
	)
	add_child(interactable)
	return interactable

func _generate_restaurant() -> void:
	_room_width = 224
	_room_height = 156
	_create_wall_sprite(_room_width, _room_height, Color(0.26, 0.2, 0.14))
	_create_floor(_room_width, _room_height)
	_add_baseboards(_room_width, _room_height)
	_add_exit_door(Vector2(110, 142))

	# 🔥 Kitchen stove (left wall)
	_add_restaurant_stove(Vector2(32, 60))
	# 👨‍🍳 Chef NPC near the stove
	_add_interior_npc(Vector2(32, 36), preload("res://assets/generated/chefmarco.png"), "Chef Marco", Color(0.95, 0.85, 0.75), 1.0, [
		"Tonight's special is going to be spectacular!",
		"The secret to a great sauce is patience and fresh herbs.",
		"I could use some fresh ingredients from the garden.",
		"A good meal brings the whole town together.",
	])
	# 🧑‍🍳 Serving counter (center-left) — sell crops here
	_add_restaurant_counter(Vector2(80, 100))
	# 🧑‍💼 Cashier NPC behind the counter
	_add_interior_npc(Vector2(80, 84), NPC_VENDOR, "Cashier", Color(0.85, 0.75, 0.65), 1.0, [
		"Welcome! Bring your fresh crops here to sell.",
		"Today's special is looking good on the menu.",
		"Got any farm-fresh produce? I'll give you a fair price.",
		"The chef always picks the best ingredients right here.",
	])
	# 🍽️ Dining table 1 (center)
	_add_restaurant_table(Vector2(140, 60))
	# 🍽️ Dining table 2 (right)
	_add_restaurant_table(Vector2(140, 116))
	# 🪟 Windows on top wall
	_add_window(Vector2(112, 12), 36, 16)
	# (Painting removed per user request)
	# 🌿 Potted plant
	_add_potted_plant(Vector2(208, 120))


# ═══════════════════════════════════════════════════════════════════════
#  🍺  TAVERN INTERIOR
# ═══════════════════════════════════════════════════════════════════════

# NPC merchant texture (unique to interior use)
const NPC_MERCHANT := preload("res://assets/generated/teller.png")

const TAVERN_DRINK_COST: int = 10

func _add_tavern_bar(pos: Vector2) -> Interactable:
	var interactable := Interactable.new()
	interactable.collision_layer = 4
	interactable.interaction_prompt = "Order a drink (%d Coins)" % TAVERN_DRINK_COST
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(48, 16)
	shape.shape = rect
	interactable.add_child(shape)
	interactable.position = pos
	var sprite := Sprite2D.new()
	sprite.texture = preload("res://assets/generated/interior_tavern_bar_frame_0.png")
	sprite.z_index = 2
	interactable.add_child(sprite)
	interactable.interacted.connect(func(_i: Node) -> void:
		if not GameManager.spend_money(TAVERN_DRINK_COST):
			ToastNotification.show_toast("Not enough coins! A drink costs %d Coins." % TAVERN_DRINK_COST, ToastNotification.ToastType.ERROR, 3.0)
			return
		# Restore hunger
		GameManager.change_hunger(15)
		# Apply a speed buff
		BuffManager.apply_potion_effect("speed", 0.5, 20.0, "Tavern Ale")
		ToastNotification.show_toast("A hearty ale warms you from within! +15 Hunger + Speed!", ToastNotification.ToastType.SUCCESS, 3.0)
	)
	add_child(interactable)
	return interactable

func _add_tavern_table(pos: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = preload("res://assets/generated/interior_tavern_table_frame_0.png")
	sprite.position = pos
	sprite.z_index = 2
	add_child(sprite)

func _add_tavern_kegs(pos: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = preload("res://assets/generated/interior_tavern_kegs_frame_0.png")
	sprite.position = pos
	sprite.z_index = 2
	add_child(sprite)

func _add_tavern_npc(pos: Vector2, name_str: String) -> Interactable:
	# Bartender NPC sprite behind the bar — now interactive with dialogue
	var interactable := Interactable.new()
	interactable.collision_layer = 4
	interactable.interaction_prompt = "Talk to %s" % [name_str]
	interactable.position = pos
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(20, 20)
	shape.shape = rect
	interactable.add_child(shape)
	
	var npc := Sprite2D.new()
	npc.texture = NPC_VENDOR
	npc.z_index = 2
	interactable.add_child(npc)
	var label := Label.new()
	label.text = name_str
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
	label.add_theme_font_size_override("font_size", 9)
	label.position = Vector2(-16, -22)
	npc.add_child(label)
	
	var dialogue_lines: Array[String] = [
		"Welcome to the tavern! What'll it be?",
		"Ale's fresh from the keg, straight from the mainland.",
		"The best stories are told over a pint.",
		"Hard day farming? I've got just the cure.",
	]
	interactable.interacted.connect(func(_interactor: Node) -> void:
		var line: String = dialogue_lines[randi() % dialogue_lines.size()]
		_spawn_npc_dialogue(interactable.global_position + Vector2(0, -16), line, 3.5)
	)
	
	add_child(interactable)
	return interactable

func _generate_tavern() -> void:
	_room_width = 256
	_room_height = 168
	_create_wall_sprite(_room_width, _room_height, Color(0.22, 0.18, 0.12))
	_create_floor(_room_width, _room_height)
	_add_baseboards(_room_width, _room_height)
	_add_exit_door(Vector2(126, 154))

	# 🔥 Fireplace (left wall)
	_add_fireplace(Vector2(32, 60))
	# 🪜 Kegs (top-left)
	_add_tavern_kegs(Vector2(48, 32))
	# 🍺 Bar counter (right wall)
	_add_tavern_bar(Vector2(224, 100))
	# 🧑‍🍳 Bartender NPC behind bar
	_add_tavern_npc(Vector2(224, 84), "Hilda")
	# 🪑 Table 1 (center-top)
	_add_tavern_table(Vector2(100, 60))
	# 🪑 Table 2 (center-bottom)
	_add_tavern_table(Vector2(100, 116))
	# 🪑 Table 3 (near bar)
	_add_tavern_table(Vector2(162, 108))
	# (Painting removed per user request)
	# 🪟 Windows
	_add_window(Vector2(100, 14), 32, 16)
	_add_window(Vector2(162, 14), 32, 16)
	# 🏮 Wall sconces (warm light)
	_add_town_decorative(Vector2(8, 32), Color(0.8, 0.6, 0.15), 4, 6)
	_add_town_decorative(Vector2(248, 32), Color(0.8, 0.6, 0.15), 4, 6)


# ═══════════════════════════════════════════════════════════════════════
#  🔨  BLACKSMITH INTERIOR
# ═══════════════════════════════════════════════════════════════════════

func _add_blacksmith_forge(pos: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = preload("res://assets/generated/interior_blacksmith_forge_frame_0.png")
	sprite.position = pos
	sprite.z_index = 2
	add_child(sprite)

func _add_blacksmith_anvil(pos: Vector2) -> Interactable:
	var interactable := Interactable.new()
	interactable.collision_layer = 4
	interactable.interaction_prompt = "Smith at anvil"
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(24, 16)
	shape.shape = rect
	interactable.add_child(shape)
	interactable.position = pos
	var sprite := Sprite2D.new()
	sprite.texture = preload("res://assets/generated/interior_blacksmith_anvil_frame_0.png")
	sprite.z_index = 2
	interactable.add_child(sprite)
	interactable.interacted.connect(func(_i: Node) -> void:
		var crafting_ui: Node = get_tree().get_first_node_in_group("crafting_ui")
		if crafting_ui:
			crafting_ui.open()
	)
	add_child(interactable)
	return interactable

func _add_blacksmith_rack(pos: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = preload("res://assets/generated/interior_blacksmith_rack_frame_0.png")
	sprite.position = pos
	sprite.z_index = 2
	add_child(sprite)

func _add_blacksmith_coal_bin(pos: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = preload("res://assets/generated/interior_blacksmith_coal_bin_frame_0.png")
	sprite.position = pos
	sprite.z_index = 2
	add_child(sprite)

func _generate_blacksmith() -> void:
	_room_width = 240
	_room_height = 156
	_create_wall_sprite(_room_width, _room_height, Color(0.2, 0.18, 0.16))
	# Stone floor (darker, industrial feel)
	var floor_sprite := Sprite2D.new()
	var floor_img := Image.create(_room_width, _room_height, false, Image.FORMAT_RGBA8)
	floor_img.fill(Color(0.22, 0.2, 0.18))
	for y in range(0, _room_height, 8):
		for x in range(0, _room_width, 8):
			var tile_color: Color
			if ((x / 8) + (y / 8)) % 2 == 0:
				tile_color = Color(0.26, 0.24, 0.2)
			else:
				tile_color = Color(0.22, 0.2, 0.17)
			var v: float = 0.95 + 0.1 * ((x + y) % 5) / 5.0
			tile_color = Color(tile_color.r * v, tile_color.g * v, tile_color.b * v)
			for py in range(y, min(y + 8, _room_height)):
				for px in range(x, min(x + 8, _room_width)):
					if px == x or py == y:
						floor_img.set_pixel(px, py, Color(0.17, 0.15, 0.12))
					else:
						floor_img.set_pixel(px, py, tile_color)
	floor_sprite.texture = ImageTexture.create_from_image(floor_img)
	floor_sprite.position = Vector2(_room_width / 2, _room_height / 2)
	floor_sprite.z_index = 1
	add_child(floor_sprite)
	_add_exit_door(Vector2(118, 142))

	# 🔥 Forge (left side)
	_add_blacksmith_forge(Vector2(40, 60))
	# 🔨 Blacksmith NPC near the forge
	_add_interior_npc(Vector2(58, 60), NPC_EXPLORER, "Smith Ironhand", Color(0.8, 0.75, 0.7), 1.0, [
		"Hard work keeps the rust away!",
		"Need a tool sharpened? I'm your dwarf.",
		"These anvils don't swing themselves, you know!",
		"Nothing a good forge can't fix.",
	])
	# 🔨 Anvil (center) — interactive
	_add_blacksmith_anvil(Vector2(130, 70))
	# 🗡️ Weapon racks (right wall)
	_add_blacksmith_rack(Vector2(224, 44))
	_add_blacksmith_rack(Vector2(224, 88))
	# 🪣 Coal bin (bottom-left)
	_add_blacksmith_coal_bin(Vector2(36, 126))
	# 📦 Storage chest
	_add_storage_chest(Vector2(196, 130))
	# 🪟 Windows
	_add_window(Vector2(100, 14), 32, 16)
	_add_window(Vector2(170, 14), 32, 16)


# ═══════════════════════════════════════════════════════════════════════
#  🏪  GENERAL STORE INTERIOR
# ═══════════════════════════════════════════════════════════════════════

func _add_store_shelf(pos: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = preload("res://assets/generated/interior_store_shelf_frame_0.png")
	sprite.position = pos
	sprite.z_index = 2
	add_child(sprite)

func _add_store_counter(pos: Vector2) -> Interactable:
	var interactable := Interactable.new()
	interactable.collision_layer = 4
	interactable.interaction_prompt = "Browse goods"
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(32, 14)
	shape.shape = rect
	interactable.add_child(shape)
	interactable.position = pos
	var sprite := Sprite2D.new()
	sprite.texture = preload("res://assets/generated/interior_store_counter_frame_0.png")
	sprite.z_index = 2
	interactable.add_child(sprite)
	interactable.interacted.connect(func(_i: Node) -> void:
		var tips := [
			"Well-stocked shelves! The shopkeep keeps everything organized.",
			"Seeds, tools, fabrics — this store has it all!",
			"The shopkeep greets you warmly. 'Take your time browsing!'",
		]
		ToastNotification.show_toast(tips.pick_random(), ToastNotification.ToastType.INFO, 3.0)
	)
	add_child(interactable)
	return interactable

func _add_store_crate(pos: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = preload("res://assets/generated/interior_store_crate_frame_0.png")
	sprite.position = pos
	sprite.z_index = 2
	add_child(sprite)

func _add_store_display(pos: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = preload("res://assets/generated/interior_store_display_frame_0.png")
	sprite.position = pos
	sprite.z_index = 2
	add_child(sprite)

func _generate_general_store() -> void:
	_room_width = 208
	_room_height = 144
	_create_wall_sprite(_room_width, _room_height, Color(0.26, 0.22, 0.16))
	_create_floor(_room_width, _room_height)
	_add_baseboards(_room_width, _room_height)
	_add_exit_door(Vector2(102, 130))

	# 🏪 Shop counter (left side)
	_add_store_counter(Vector2(40, 70))
	# 🧑‍💼 Shopkeep NPC behind counter
	_add_interior_npc(Vector2(40, 50), NPC_VENDOR, "Merchant Mina", Color(0.9, 0.85, 0.75), 1.0, [
		"Always happy to help a customer!",
		"New stock just arrived from the mainland.",
		"Let me know if you need anything at all!",
		"I've got the best prices this side of the Isles.",
	])
	# 📦 Crates (bottom-left)
	_add_store_crate(Vector2(40, 120))
	_add_store_crate(Vector2(60, 120))
	# 🪜 Shelves (top wall)
	_add_store_shelf(Vector2(70, 32))
	_add_store_shelf(Vector2(140, 32))
	# 🧵 Display table (right side)
	_add_store_display(Vector2(160, 90))
	# 📦 Storage chest
	_add_storage_chest(Vector2(180, 126))
	# 🪟 Window
	_add_window(Vector2(110, 12), 32, 16)
	# 🌿 Potted plant
	_add_potted_plant(Vector2(190, 36))


# ═══════════════════════════════════════════════════════════════════════
#  📚  LIBRARY INTERIOR
# ═══════════════════════════════════════════════════════════════════════

var _bookshelf_tex_cache: Texture2D = null

func _add_library_bookshelf(pos: Vector2) -> void:
	if _bookshelf_tex_cache == null:
		_bookshelf_tex_cache = load("res://assets/generated/interior_library_bookshelf_frame_0.png")
	var sprite := Sprite2D.new()
	sprite.texture = _bookshelf_tex_cache
	sprite.position = pos
	sprite.z_index = 2
	add_child(sprite)

func _add_library_reading_table(pos: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = preload("res://assets/generated/interior_library_reading_table_frame_0.png")
	sprite.position = pos
	sprite.z_index = 2
	add_child(sprite)

func _add_library_study_desk(pos: Vector2) -> Interactable:
	var interactable := Interactable.new()
	interactable.collision_layer = 4
	interactable.interaction_prompt = "Research at desk"
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(32, 16)
	shape.shape = rect
	interactable.add_child(shape)
	interactable.position = pos
	var sprite := Sprite2D.new()
	sprite.texture = preload("res://assets/generated/interior_library_study_desk_frame_0.png")
	sprite.z_index = 2
	interactable.add_child(sprite)
	interactable.interacted.connect(func(_i: Node) -> void:
		var lib: Node = get_tree().get_first_node_in_group("library_system")
		if lib and lib.has_method("open_ui"):
			lib.open_ui()
		else:
			ToastNotification.show_toast("The research desk is ready. Come back when the library is fully operational!", ToastNotification.ToastType.INFO, 3.0)
	)
	add_child(interactable)
	return interactable

func _generate_library() -> void:
	_room_width = 240
	_room_height = 168
	_create_wall_sprite(_room_width, _room_height, Color(0.24, 0.2, 0.14))
	_create_floor(_room_width, _room_height)
	_add_baseboards(_room_width, _room_height)
	_add_exit_door(Vector2(118, 154))

	# 📚 Tall bookshelves (left and right walls)
	_add_library_bookshelf(Vector2(16, 60))
	_add_library_bookshelf(Vector2(16, 108))
	_add_library_bookshelf(Vector2(224, 60))
	_add_library_bookshelf(Vector2(224, 108))
	# 🎓 Scholar NPC at reading table
	_add_interior_npc(Vector2(80, 40), NPC_SIGHTSEER, "Scholar Sage", Color(0.85, 0.8, 0.9), 1.0, [
		"Knowledge is the truest treasure of all.",
		"These tomes hold the secrets of the Isles.",
		"Have you read about the ancient islanders? Fascinating stuff.",
		"The library is open to all who seek wisdom.",
	])
	# 🪑 Reading table 1 (center-left)
	_add_library_reading_table(Vector2(80, 60))
	# 🪑 Reading table 2 (center-right)
	_add_library_reading_table(Vector2(160, 60))
	# 📖 Study desk (center-bottom) — interactive
	_add_library_study_desk(Vector2(120, 120))
	# 🖼️ Wall art (landscape painting)
	_add_wall_art(Vector2(120, 28), 36, 22, Color(0.45, 0.3, 0.12), Color(0.2, 0.4, 0.6))
	# 🪟 Windows (top wall)
	_add_window(Vector2(72, 14), 28, 16)
	_add_window(Vector2(168, 14), 28, 16)
	


# ═══════════════════════════════════════════════════════════════════════
#  🐴  STABLE INTERIOR
# ═══════════════════════════════════════════════════════════════════════

func _add_stable_stall(pos: Vector2, stall_name: String) -> Interactable:
	var interactable := Interactable.new()
	interactable.collision_layer = 4
	interactable.interaction_prompt = "Tend to " + stall_name
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40, 28)
	shape.shape = rect
	interactable.add_child(shape)
	interactable.position = pos
	var sprite := Sprite2D.new()
	sprite.texture = preload("res://assets/generated/interior_stable_stall_frame_0.png")
	# Name label
	var label := Label.new()
	label.text = stall_name
	label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	label.add_theme_font_size_override("font_size", 8)
	label.position = Vector2(-14, -16)
	sprite.add_child(label)
	sprite.z_index = 2
	interactable.add_child(sprite)
	interactable.interacted.connect(func(_i: Node) -> void:
		var collected := InventoryManager.add_item("fiber", 2)
		if collected:
			EffectSpawner.spawn_floating_text("+2 Fiber", interactable.global_position, Color(0.8, 0.75, 0.4))
			ToastNotification.show_toast("Gathered fresh hay from the " + stall_name + " stall!", ToastNotification.ToastType.SUCCESS, 2.0)
		else:
			ToastNotification.show_toast("Inventory full!", ToastNotification.ToastType.ERROR, 2.0)
	)
	add_child(interactable)
	return interactable

func _add_stable_hay(pos: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = preload("res://assets/generated/interior_stable_hay_frame_0.png")
	sprite.position = pos
	sprite.z_index = 2
	add_child(sprite)

func _add_stable_tack_wall(pos: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = preload("res://assets/generated/interior_stable_tack_wall_frame_0.png")
	sprite.position = pos
	sprite.z_index = 2
	add_child(sprite)

func _add_stable_trough(pos: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = preload("res://assets/generated/interior_stable_trough_frame_0.png")
	sprite.position = pos
	sprite.z_index = 2
	add_child(sprite)

func _generate_stable() -> void:
	_room_width = 224
	_room_height = 128
	_create_wall_sprite(_room_width, _room_height, Color(0.25, 0.2, 0.14))
	_create_floor(_room_width, _room_height)
	_add_exit_door(Vector2(110, 114))

	# 🐴 Horse stall 1 (left)
	_add_stable_stall(Vector2(48, 40), "Thunder")
	# 🐴 Horse stall 2 (right)
	_add_stable_stall(Vector2(176, 40), "Luna")
	# 🧑‍🌾 Stablehand NPC near stalls
	_add_interior_npc(Vector2(112, 92), NPC_FISHER, "Stablehand Sam", Color(0.75, 0.7, 0.6), 1.0, [
		"The horses are well-fed and happy today!",
		"Luna's been restless — I think she misses the open fields.",
		"A good brush-down keeps 'em content.",
		"Hay, water, and a gentle hand — that's all they need.",
	])
	# 💧 Water trough (center)
	_add_stable_trough(Vector2(112, 72))
	# 🌾 Hay bales (bottom area)
	_add_stable_hay(Vector2(48, 104))
	_add_stable_hay(Vector2(80, 104))
	_add_stable_hay(Vector2(144, 104))
	_add_stable_hay(Vector2(176, 104))
	# 🪜 Tack wall (top wall)
	_add_stable_tack_wall(Vector2(112, 16))
	# 🪟 Windows
	_add_window(Vector2(72, 12), 28, 14)
	_add_window(Vector2(152, 12), 28, 14)

# ─────────────────────────────────────────────────────────────────────────────
#  🏦  BANK INTERIOR — teller counter, vault, desks
# ─────────────────────────────────────────────────────────────────────────────
func _add_recruitment_desk(pos: Vector2) -> Interactable:
	## Recruitment desk — lets player see current visitors and recruit them directly.
	var interactable := Interactable.new()
	interactable.collision_layer = 4
	interactable.interaction_prompt = "Recruit a town resident"
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(36, 16)
	shape.shape = rect
	interactable.add_child(shape)
	interactable.position = pos
	# Desk sprite
	var sprite := Sprite2D.new()
	sprite.texture = preload("res://assets/generated/interior_bakery_table_frame_0.png")
	sprite.z_index = 2
	interactable.add_child(sprite)
	# Sign label
	var sign_label := Label.new()
	sign_label.text = "📋 VISITOR REGISTRY"
	sign_label.add_theme_color_override("font_color", Color(0.85, 0.7, 0.3))
	sign_label.add_theme_font_size_override("font_size", 8)
	sign_label.position = Vector2(-28, -20)
	interactable.add_child(sign_label)
	
	interactable.interacted.connect(func(_i: Node) -> void:
		_open_recruitment_dialog()
	)
	add_child(interactable)
	return interactable

func _open_recruitment_dialog() -> void:
	## Shows a dialog listing current visitors and allowing the player to recruit one.
	var visitor_mgr := get_tree().get_first_node_in_group("visitor_manager") as Node
	if not visitor_mgr or not visitor_mgr.has_method("get_active_ship"):
		ToastNotification.show_toast("No visitors in town right now. Wait for a ship to arrive!", ToastNotification.ToastType.INFO, 3.0)
		return
	
	var ship = visitor_mgr.get_active_ship()
	if not ship or not ship.has_method("get_visitor_npcs"):
		ToastNotification.show_toast("No visitors in town right now. Wait for a ship to arrive!", ToastNotification.ToastType.INFO, 3.0)
		return
	
	var visitors: Array = ship.get_visitor_npcs()
	if visitors.is_empty():
		ToastNotification.show_toast("All visitors have already left for the day!", ToastNotification.ToastType.INFO, 3.0)
		return
	
	# Check if there are vacancies
	var town_mgr := get_tree().get_first_node_in_group("town_manager") as TownManager
	if not town_mgr or town_mgr.get_vacancy_count() <= 0:
		ToastNotification.show_toast("No vacant buildings to move into! Restore more ruins first.", ToastNotification.ToastType.INFO, 3.0)
		return
	
	# ── Build dialog UI ──
	var hud: CanvasLayer = get_tree().get_first_node_in_group("hud") as CanvasLayer
	if not hud:
		return
	
	# Dim background
	var dim := ColorRect.new()
	dim.name = "RecruitDim"
	dim.color = Color(0, 0, 0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_close_recruitment_dialog(hud)
	)
	hud.add_child(dim)
	
	# Panel
	var panel := PanelContainer.new()
	panel.name = "RecruitPanel"
	panel.custom_minimum_size = Vector2(320, 260)
	panel.position = Vector2(
		hud.get_viewport().get_visible_rect().size.x / 2.0 - 160,
		hud.get_viewport().get_visible_rect().size.y / 2.0 - 130
	)
	var style := LIGHT_WOOD
	panel.add_theme_stylebox_override("panel", style)
	hud.add_child(panel)
	
	# VBox content
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(vbox)
	
	# Title
	var title := Label.new()
	title.text = "  📋  Welcome to Tidehaven!"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.85, 0.7, 0.25))
	vbox.add_child(title)
	
	var subtitle := Label.new()
	subtitle.text = "Choose a visitor to invite as a permanent resident:"
	subtitle.add_theme_font_size_override("font_size", 10)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.65, 0.55))
	vbox.add_child(subtitle)
	
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer)
	
	# ── Vacancy info ──
	var vacancy_count: int = town_mgr.get_vacancy_count()
	var vacant_ruins: Array[String] = town_mgr.get_vacant_ruins()
	
	var info := Label.new()
	info.text = "Available homes: %d" % [vacancy_count]
	info.add_theme_font_size_override("font_size", 9)
	info.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
	vbox.add_child(info)
	
	# ── Scroll container for visitor list ──
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 120)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	
	var visitor_list := VBoxContainer.new()
	visitor_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(visitor_list)
	
	# Add a button for each visitor
	for visitor in visitors:
		if not is_instance_valid(visitor):
			continue
		var vtype = visitor.get("npc_type") if "npc_type" in visitor else 0
		var vname = VisitorNPC.get_npc_name(vtype) if visitor.has_method("get_npc_name") else "Visitor"
		
		# Determine the best building match
		var preferred_id: String = town_mgr.get_preferred_vacancy(vtype)
		var preferred_name: String = ""
		if not preferred_id.is_empty():
			var def_data = town_mgr.get_ruin_def(preferred_id)
			if def_data:
				preferred_name = def_data.building_name
		
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 28)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var name_label := Label.new()
		name_label.text = vname
		name_label.custom_minimum_size = Vector2(140, 0)
		name_label.add_theme_font_size_override("font_size", 10)
		row.add_child(name_label)
		
		var role_label := Label.new()
		role_label.text = "→ " + preferred_name if not preferred_name.is_empty() else ""
		role_label.add_theme_color_override("font_color", Color(0.6, 0.75, 0.6))
		role_label.add_theme_font_size_override("font_size", 8)
		role_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(role_label)
		
		var recruit_btn := Button.new()
		recruit_btn.text = "Recruit"
		recruit_btn.custom_minimum_size = Vector2(70, 0)
		if preferred_id.is_empty():
			recruit_btn.disabled = true
			recruit_btn.text = "No home"
		else:
			recruit_btn.pressed.connect(_recruit_selected_visitor.bind(visitor, preferred_id, vname, hud))
		row.add_child(recruit_btn)
		
		visitor_list.add_child(row)
	
	# ── Close button ──
	var close_spacer := Control.new()
	close_spacer.custom_minimum_size = Vector2(0, 6)
	vbox.add_child(close_spacer)
	
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(func():
		_close_recruitment_dialog(hud)
	)
	vbox.add_child(close_btn)
	
	# Tween in
	panel.modulate = Color(1, 1, 1, 0)
	panel.scale = Vector2(0.85, 0.85)
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(panel, "modulate", Color(1, 1, 1, 1), 0.25)
	tween.parallel().tween_property(panel, "scale", Vector2(1, 1), 0.25)

func _recruit_selected_visitor(visitor: Node, ruin_id: String, visitor_name: String, hud: CanvasLayer) -> void:
	## Recruit the selected visitor as a permanent resident.
	if not is_instance_valid(visitor) or not visitor.has_method("convert_to_resident"):
		ToastNotification.show_toast("That visitor is no longer available.", ToastNotification.ToastType.INFO, 2.0)
		_close_recruitment_dialog(hud)
		return
	
	var town_mgr := get_tree().get_first_node_in_group("town_manager") as TownManager
	if not town_mgr:
		return
	
	var def: TownManager.RuinDef = town_mgr.get_ruin_def(ruin_id)
	if not def or town_mgr.get_ruin_status(ruin_id) != TownManager.RuinStatus.RESTORED:
		ToastNotification.show_toast("That building is no longer available!", ToastNotification.ToastType.ERROR, 2.0)
		_close_recruitment_dialog(hud)
		return
	
	# Create the resident
	var vtype = visitor.get("npc_type") if "npc_type" in visitor else 0
	vtype = vtype if vtype is int else 0
	var npc_id: String = "resident_%s_%d" % [ruin_id, Time.get_unix_time_from_system()]
	# Re-style the name to the resident's new role so the name matches the
	# dialogue/services of the building they moved into.
	var visitor_display: String = visitor_name
	if "_npc_display_name" in visitor:
		var vdisp: String = str(visitor.get("_npc_display_name"))
		if not vdisp.is_empty():
			visitor_display = vdisp
	var resident_name: String = VisitorNPC.get_resident_name(def.npc_role, visitor_display)
	
	visitor.convert_to_resident(npc_id, def.npc_role, ruin_id, def.grid_cell, resident_name)
	town_mgr.add_resident(npc_id, resident_name, def.npc_role, ruin_id, vtype)
	
	ToastNotification.show_toast("%s has moved into %s!" % [resident_name, def.building_name], ToastNotification.ToastType.SUCCESS, 4.0)
	_close_recruitment_dialog(hud)

func _close_recruitment_dialog(hud: CanvasLayer) -> void:
	if not is_instance_valid(hud):
		return
	var dim := hud.get_node_or_null("RecruitDim")
	if dim:
		dim.queue_free()
	var panel := hud.get_node_or_null("RecruitPanel")
	if panel:
		var tween := create_tween()
		tween.set_ease(Tween.EASE_IN)
		tween.set_trans(Tween.TRANS_BACK)
		tween.tween_property(panel, "scale", Vector2(0.85, 0.85), 0.15)
		tween.parallel().tween_property(panel, "modulate", Color(1, 1, 1, 0), 0.15)
		tween.tween_callback(panel.queue_free)

func _add_bank_teller(pos: Vector2) -> Interactable:
	var interactable := Interactable.new()
	interactable.collision_layer = 4
	interactable.interaction_prompt = "Use bank teller"
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40, 20)
	shape.shape = rect
	interactable.add_child(shape)
	interactable.position = pos
	# Decorative counter sprite (use store counter — generic wooden counter)
	var counter_sprite := Sprite2D.new()
	counter_sprite.texture = preload("res://assets/generated/interior_store_counter_frame_0.png")
	counter_sprite.z_index = 2
	interactable.add_child(counter_sprite)
	# Gold scales decoration (small gold squares)
	var scale_left := ColorRect.new()
	scale_left.color = Color(0.85, 0.7, 0.2)
	scale_left.size = Vector2(6, 5)
	scale_left.position = Vector2(-14, -8)
	scale_left.z_index = 3
	scale_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	interactable.add_child(scale_left)
	var scale_right := ColorRect.new()
	scale_right.color = Color(0.85, 0.7, 0.2)
	scale_right.size = Vector2(6, 5)
	scale_right.position = Vector2(8, -8)
	scale_right.z_index = 3
	scale_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	interactable.add_child(scale_right)
	
	interactable.interacted.connect(func(_i: Node) -> void:
		_open_bank_dialog(interactable)
	)
	add_child(interactable)
	return interactable

func _open_bank_dialog(anchor: Node) -> void:
	## Opens a simple bank deposit/withdraw dialog as a popup on the HUD.
	var hud: CanvasLayer = get_tree().get_first_node_in_group("hud") as CanvasLayer
	if not hud:
		return
	
	# ── Dim background ──
	var dim := ColorRect.new()
	dim.name = "BankDim"
	dim.color = Color(0, 0, 0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_close_bank_dialog(hud)
	)
	hud.add_child(dim)
	
	# ── Dialog panel ──
	var panel := PanelContainer.new()
	panel.name = "BankPanel"
	panel.custom_minimum_size = Vector2(280, 220)
	panel.position = Vector2(
		hud.get_viewport().get_visible_rect().size.x / 2.0 - 140,
		hud.get_viewport().get_visible_rect().size.y / 2.0 - 110
	)
	# Style
	var style := LIGHT_WOOD
	panel.add_theme_stylebox_override("panel", style)
	hud.add_child(panel)
	
	# ── VBox content ──
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(vbox)
	
	# Title
	var title := Label.new()
	title.text = "  🏦  Tidehaven Bank"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.85, 0.7, 0.25))
	vbox.add_child(title)
	
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	vbox.add_child(spacer)
	
	# Balance display
	var balance_row := HBoxContainer.new()
	var bal_label := Label.new()
	bal_label.text = "Bank Balance:"
	bal_label.add_theme_font_size_override("font_size", 14)
	bal_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	balance_row.add_child(bal_label)
	var bal_value := Label.new()
	bal_value.name = "BalValue"
	bal_value.text = "$%d" % GameManager.bank_balance
	bal_value.add_theme_font_size_override("font_size", 14)
	bal_value.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	bal_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bal_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	balance_row.add_child(bal_value)
	vbox.add_child(balance_row)
	
	# Wallet display
	var wallet_row := HBoxContainer.new()
	var wal_label := Label.new()
	wal_label.text = "On Hand:"
	wal_label.add_theme_font_size_override("font_size", 14)
	wal_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	wallet_row.add_child(wal_label)
	var wal_value := Label.new()
	wal_value.name = "WalValue"
	wal_value.text = "$%d" % GameManager.money
	wal_value.add_theme_font_size_override("font_size", 14)
	wal_value.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	wal_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wal_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	wallet_row.add_child(wal_value)
	vbox.add_child(wallet_row)
	
	# Interest info
	var interest_label := Label.new()
	interest_label.text = "Daily interest: 0.5%"
	interest_label.add_theme_font_size_override("font_size", 10)
	interest_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.5))
	vbox.add_child(interest_label)
	
	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 12)
	vbox.add_child(spacer2)
	
	# ── Amount input (SpinBox) ──
	var amount_hbox := HBoxContainer.new()
	amount_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	var amount_label := Label.new()
	amount_label.text = "Amount:"
	amount_label.add_theme_font_size_override("font_size", 12)
	amount_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	amount_hbox.add_child(amount_label)
	var amount_spin := SpinBox.new()
	amount_spin.name = "AmountSpin"
	amount_spin.custom_minimum_size = Vector2(120, 0)
	amount_spin.min_value = 1
	amount_spin.max_value = 999999
	amount_spin.value = 10
	amount_spin.step = 1
	amount_spin.rounded = true
	amount_spin.prefix = "$"
	amount_hbox.add_child(amount_spin)
	vbox.add_child(amount_hbox)
	
	var spacer3 := Control.new()
	spacer3.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer3)
	
	# ── Buttons ──
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var deposit_btn := Button.new()
	deposit_btn.text = "Deposit"
	deposit_btn.custom_minimum_size = Vector2(90, 32)
	btn_row.add_child(deposit_btn)
	
	var withdraw_btn := Button.new()
	withdraw_btn.text = "Withdraw"
	withdraw_btn.custom_minimum_size = Vector2(90, 32)
	btn_row.add_child(withdraw_btn)
	
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(90, 32)
	btn_row.add_child(close_btn)
	
	vbox.add_child(btn_row)
	
	# ── Message label ──
	var msg_label := Label.new()
	msg_label.name = "MsgLabel"
	msg_label.add_theme_font_size_override("font_size", 11)
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(msg_label)
	
	# ── Helper to refresh ──
	var set_balance := func():
		bal_value.text = "$%d" % GameManager.bank_balance
		wal_value.text = "$%d" % GameManager.money
	
	# Connection helpers
	var update_msg := func(text: String, good: bool):
		msg_label.text = text
		msg_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4) if good else Color(1.0, 0.4, 0.3))
	
	deposit_btn.pressed.connect(func():
		var amt: int = int(amount_spin.value)
		if GameManager.deposit_money(amt):
			update_msg.call("Deposited $%d!" % [amt], true)
			set_balance.call()
			amount_spin.value = min(amount_spin.value, GameManager.money)
		else:
			update_msg.call("You don't have that much money.", false)
	)
	
	withdraw_btn.pressed.connect(func():
		var amt: int = int(amount_spin.value)
		if GameManager.withdraw_money(amt):
			update_msg.call("Withdrew $%d!" % [amt], true)
			set_balance.call()
			amount_spin.value = min(amount_spin.value, GameManager.bank_balance)
		else:
			update_msg.call("Not enough in the bank.", false)
	)
	
	close_btn.pressed.connect(func():
		_close_bank_dialog(hud)
	)
	
	# Tween in
	panel.modulate = Color(1, 1, 1, 0)
	panel.scale = Vector2(0.85, 0.85)
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(panel, "modulate", Color(1, 1, 1, 1), 0.25)
	tween.parallel().tween_property(panel, "scale", Vector2(1, 1), 0.25)

func _close_bank_dialog(hud: CanvasLayer) -> void:
	if not is_instance_valid(hud):
		return
	var dim := hud.get_node_or_null("BankDim")
	if dim:
		dim.queue_free()
	var panel := hud.get_node_or_null("BankPanel")
	if panel:
		var tween := create_tween()
		tween.set_ease(Tween.EASE_IN)
		tween.set_trans(Tween.TRANS_BACK)
		tween.tween_property(panel, "scale", Vector2(0.85, 0.85), 0.15)
		tween.parallel().tween_property(panel, "modulate", Color(1, 1, 1, 0), 0.15)
		tween.tween_callback(panel.queue_free)

func _generate_bank() -> void:
	_room_width = 240
	_room_height = 168
	_create_wall_sprite(_room_width, _room_height, Color(0.22, 0.2, 0.18))
	_create_floor(_room_width, _room_height)
	_add_baseboards(_room_width, _room_height)
	_add_exit_door(Vector2(48, 150))

	# 🪟 Windows along the front wall
	_add_window(Vector2(96, 12), 48, 14)
	_add_window(Vector2(192, 12), 48, 14)

	# 🏦 Teller counter (interactive — deposit/withdraw)
	_add_bank_teller(Vector2(64, 62))
	# 🧑‍💼 Bank teller NPC behind the counter
	_add_interior_npc(Vector2(48, 46), preload("res://assets/generated/teller.png"), "Teller Tom", Color(0.85, 0.82, 0.75), 1.0, [
		"Safe and sound — that's the Tidehaven Bank way!",
		"Interest accrues daily. Your coins are working for you!",
		"Need to make a deposit or withdrawal? I'm your man.",
		"We keep your coins safer than a dragon's hoard.",
	])

	# 🪑 Customer waiting area
	_add_armchair(Vector2(48, 112))
	_add_armchair(Vector2(80, 112))
	_add_table(Vector2(192, 56))

	# Potted plant (right side)
	_add_potted_plant(Vector2(150, 100))

	# 💰 Vault area (top-right corner)
	_add_storage_chest(Vector2(208, 32))
	_add_decorative(Vector2(184, 28), Color(0.55, 0.5, 0.35), 12, 10)  # Vault shelf
	# Gold bars in the vault
	_add_decorative(Vector2(188, 32), Color(0.85, 0.7, 0.15), 4, 3)
	_add_decorative(Vector2(194, 32), Color(0.8, 0.65, 0.1), 4, 3)

	# (Painting removed per user request)
