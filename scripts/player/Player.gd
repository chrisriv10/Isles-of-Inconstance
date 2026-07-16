extends CharacterBody2D
class_name Player

## Handles player input and movement only. Interaction detection lives in
## PlayerInteractor.gd, and world manipulation (tilling, etc.) lives in
## World.gd - Player just asks those systems to act.

signal facing_changed(direction: Vector2)
signal active_tool_changed(tool_name: String)

## Tools: 0=None, 1=Hoe, 2=WateringCan, 3-5=Seed slots driven by
## DataManager.procedural_crops, 6=whichever seed the player last picked
## from the Shop/Inventory ("Selected Seed") - this is how purchased rare
## or mutated seeds actually get planted, since the 3 fixed slots only
## ever cover the original starter crops.
enum Tool { NONE, HOE, WATERING_CAN, SEED_SLOT_1, SEED_SLOT_2, SEED_SLOT_3, SEED_SLOT_SELECTED }

@export var speed: float = 90.0
@export var base_tool_cooldown: float = 0.35

@onready var interactor: Area2D = $Interactor
@onready var sprite: Sprite2D = $Sprite2D
@onready var held_item: Sprite2D = $Sprite2D/HeldItem
@onready var _world: Node2D = get_parent().get_node("World") if get_parent().has_node("World") else null

var facing_direction: Vector2 = Vector2.DOWN
var active_tool: Tool = Tool.HOE
var selected_seed_crop_id: String = ""

# Textures for items held in the player's hand
const TEX_HOE: Texture2D = preload("res://assets/generated/hand_hoe_frame_0.png")
const TEX_WATERING_CAN: Texture2D = preload("res://assets/generated/hand_watering_can_frame_0.png")
const TEX_SEED: Texture2D = preload("res://assets/generated/icon_seed_default_frame_0.png")

var _tool_cooldown_remaining: float = 0.0
var _walk_tween: Tween
var _tool_swing_tween: Tween
var _bob_phase: float = 0.0

func _ready() -> void:
	add_to_group("player")
	call_deferred("_emit_initial_tool")

func _emit_initial_tool() -> void:
	_update_tool_ui()
	_update_held_item()

func _physics_process(delta: float) -> void:
	if _tool_cooldown_remaining > 0.0:
		_tool_cooldown_remaining -= delta

	var input_direction := _get_input_direction()
	# Block movement into non-walkable tiles (water, etc.)
	# The tile collision handles most of this, but we check here too so the
	# player can't "walk a little" into water before the collision pushes them back.
	input_direction = _clamp_to_walkable(input_direction)
	velocity = input_direction * speed
	move_and_slide()

	if input_direction != Vector2.ZERO:
		facing_direction = input_direction
		facing_changed.emit(facing_direction)
		_update_interactor_position()
		_update_sprite_facing()
		_walk_bob(delta)
	else:
		_reset_walk_bob()
	
	_update_tool_preview()

## Prevents the player from moving into non-walkable tiles (e.g. water).
## Checks the tile one step ahead in each axis and zeroes out movement
## toward any blocked tile. This works alongside tile collision to prevent
## the player from visually "walking a little" into water.
func _clamp_to_walkable(direction: Vector2) -> Vector2:
	if direction == Vector2.ZERO or not _world:
		return direction
	var world: Node = _world
	var w_pos: Vector2 = global_position
	var cell_size: float = 16.0
	
	# Try horizontal movement first
	if direction.x != 0.0:
		var next_x: float = w_pos.x + direction.x * cell_size * 0.6
		var cell_x: Vector2i = Vector2i(floori(next_x / cell_size), floori(w_pos.y / cell_size))
		if _is_water_cell(world, cell_x):
			direction.x = 0.0
	
	# Try vertical movement
	if direction.y != 0.0:
		var next_y: float = w_pos.y + direction.y * cell_size * 0.6
		var cell_y: Vector2i = Vector2i(floori(w_pos.x / cell_size), floori(next_y / cell_size))
		if _is_water_cell(world, cell_y):
			direction.y = 0.0
	
	return direction

## Checks if a given cell position contains a water tile (atlas_coords.x == 3).
func _is_water_cell(world: Node, cell: Vector2i) -> bool:
	var layer: TileMapLayer = world.get_node("GroundLayer") if world.has_node("GroundLayer") else null
	if not layer:
		return false
	var atlas: Vector2i = layer.get_cell_atlas_coords(cell)
	# Water tile is at atlas coordinate (3, 0). Edge tiles are at (13-20, 0).
	return (atlas.x == 3 and atlas.y == 0) or (atlas.x >= 13 and atlas.x <= 20 and atlas.y == 0)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_try_interact()
	if event.is_action_pressed("till") or (event is InputEventKey and event.pressed and event.keycode == KEY_SPACE):
		_try_use_tool()

	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1: _set_tool(Tool.HOE)
			KEY_2: _set_tool(Tool.WATERING_CAN)
			KEY_3: _set_tool(Tool.SEED_SLOT_1)
			KEY_4: _set_tool(Tool.SEED_SLOT_2)
			KEY_5: _set_tool(Tool.SEED_SLOT_3)
			KEY_6: _set_tool(Tool.SEED_SLOT_SELECTED)

## Public setter so external UI (hotbar, etc.) can switch the active tool.
func set_tool(tool: Tool) -> void:
	_set_tool(tool)

## Called by the Shop/Inventory UI when the player picks a seed to plant -
## covers any seed they own, not just the 3 starter crops. Immediately
## switches the active tool to the "Selected Seed" slot so it's ready to use.
func select_seed(crop_id: String) -> void:
	selected_seed_crop_id = crop_id
	_set_tool(Tool.SEED_SLOT_SELECTED)

func _set_tool(tool: Tool) -> void:
	active_tool = tool
	_update_tool_ui()
	_update_tool_preview()
	_update_held_item()

func _update_tool_ui() -> void:
	var tool_name := "None"
	match active_tool:
		Tool.HOE:
			tool_name = "Hoe"
		Tool.WATERING_CAN:
			tool_name = "Watering Can"
		Tool.SEED_SLOT_1, Tool.SEED_SLOT_2, Tool.SEED_SLOT_3, Tool.SEED_SLOT_SELECTED:
			var crop := _get_crop_for_active_slot()
			if crop:
				var owned := InventoryManager.get_count(crop.seed_item_id)
				tool_name = "%s Seeds (x%d)" % [crop.display_name, owned]
			else:
				tool_name = "Empty Slot"
	active_tool_changed.emit(tool_name)

func _get_crop_for_active_slot() -> CropData:
	if active_tool == Tool.SEED_SLOT_SELECTED:
		return DataManager.get_crop(selected_seed_crop_id) if selected_seed_crop_id != "" else null
	var slot_index := _tool_to_slot_index(active_tool)
	if slot_index < 0:
		return null
	var proc_crops := DataManager.get_procedural_crops()
	if slot_index < proc_crops.size():
		return proc_crops[slot_index]
	return null

func _tool_to_slot_index(tool: Tool) -> int:
	match tool:
		Tool.SEED_SLOT_1: return 0
		Tool.SEED_SLOT_2: return 1
		Tool.SEED_SLOT_3: return 2
	return -1

func _get_input_direction() -> Vector2:
	var dir := Vector2.ZERO
	dir.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	dir.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	return dir.normalized()

func _update_interactor_position() -> void:
	if interactor:
		interactor.position = facing_direction * 14.0

func _try_interact() -> void:
	if interactor and interactor.has_method("interact_with_nearest"):
		var interacted: bool = interactor.interact_with_nearest()
		if not interacted:
			var world := get_tree().get_first_node_in_group("world")
			if not world:
				return
			var target_pos: Vector2 = global_position + facing_direction * 16.0
			
			# If holding compost (tool is any seed slot with compost in inventory),
			# try compost on the tile first
			if InventoryManager.has_item("compost", 1):
				if world.has_method("apply_compost") and world.apply_compost(target_pos):
					return
			
			# Otherwise try to harvest
			if world.has_method("harvest_crop"):
				world.harvest_crop(target_pos)

## Updates the blue pulsing tile preview based on the player's current tool
## and facing direction. Shows multi-cell area for hoe/watering can,
## single cell for seeds (only if seeds are actually available).
func _update_tool_preview() -> void:
	var world := get_tree().get_first_node_in_group("world")
	if not world:
		return
	var target_pos: Vector2 = global_position + facing_direction * 16.0
	
	match active_tool:
		Tool.HOE, Tool.WATERING_CAN:
			if world.has_method("show_tool_preview"):
				world.show_tool_preview(target_pos)
		Tool.SEED_SLOT_1, Tool.SEED_SLOT_2, Tool.SEED_SLOT_3, Tool.SEED_SLOT_SELECTED:
			# Only show the preview if this slot actually has seeds to plant
			var crop := _get_crop_for_active_slot()
			if crop != null and InventoryManager.get_count(crop.seed_item_id) > 0:
				if world.has_method("show_single_cell_preview"):
					world.show_single_cell_preview(target_pos)
			else:
				if world.has_method("clear_tool_preview"):
					world.clear_tool_preview()
		_:
			if world.has_method("clear_tool_preview"):
				world.clear_tool_preview()

func _try_use_tool() -> void:
	if _tool_cooldown_remaining > 0.0:
		return

	var world := get_tree().get_first_node_in_group("world")
	if not world:
		return

	var target_pos: Vector2 = global_position + facing_direction * 16.0
	var used := false

	match active_tool:
		Tool.HOE:
			if world.has_method("till_tile"):
				used = world.till_tile(target_pos)
		Tool.WATERING_CAN:
			if world.has_method("water_tile"):
				used = world.water_tile(target_pos)
		Tool.SEED_SLOT_1, Tool.SEED_SLOT_2, Tool.SEED_SLOT_3, Tool.SEED_SLOT_SELECTED:
			var crop := _get_crop_for_active_slot()
			if crop and world.has_method("plant_seed"):
				used = world.plant_seed(target_pos, crop.id)
				if used:
					_update_tool_ui()  # refresh the remaining seed count

	if used:
		_play_tool_swing()
		_tool_cooldown_remaining = base_tool_cooldown * UpgradeManager.get_farming_speed_multiplier()

func _update_sprite_facing() -> void:
	if facing_direction.x < 0:
		sprite.flip_h = true
		held_item.flip_h = true
	elif facing_direction.x > 0:
		sprite.flip_h = false
		held_item.flip_h = false
	_update_held_item_position()

## Updates the held item sprite based on the active tool.
## Shows the tool/seed icon in the player's hand, or hides it when nothing is equipped.
func _update_held_item() -> void:
	match active_tool:
		Tool.NONE:
			held_item.visible = false
		Tool.HOE:
			held_item.texture = TEX_HOE
			held_item.visible = true
		Tool.WATERING_CAN:
			held_item.texture = TEX_WATERING_CAN
			held_item.visible = true
		Tool.SEED_SLOT_1, Tool.SEED_SLOT_2, Tool.SEED_SLOT_3, Tool.SEED_SLOT_SELECTED:
			var crop := _get_crop_for_active_slot()
			if crop != null and InventoryManager.get_count(crop.seed_item_id) > 0:
				held_item.texture = TEX_SEED
				held_item.visible = true
			else:
				held_item.visible = false
		_:
			held_item.visible = false
	_update_held_item_position()

## Adjusts the held item position based on which direction the player is facing.
## HeldItem is a child of Sprite2D, so positions are in Sprite2D-local space.
## The sprite is centered at (0,0), and the right hand is at pixel (15,17) = (3,5).
## When facing LEFT, sprite.flip_h mirrors the texture: the right hand (pixel 15)
## renders at (12-15, 5) = (-3, 5) — so the tool goes there, not at the left hand's
## original pixel, because the flipped right hand is the visible holding hand.
func _update_held_item_position() -> void:
	match facing_direction:
		Vector2.LEFT:
			held_item.position = Vector2(-3, 5)
		Vector2.RIGHT:
			held_item.position = Vector2(3, 5)
		Vector2.UP:
			held_item.position = Vector2(4, 0)
		Vector2.DOWN:
			held_item.position = Vector2(3, 5)
		_:
			held_item.position = Vector2(3, 5)

func _walk_bob(delta: float) -> void:
	_bob_phase += delta * 10.0
	var bob_offset := sin(_bob_phase) * 2.0
	sprite.position.y = bob_offset

func _reset_walk_bob() -> void:
	if _walk_tween and _walk_tween.is_valid():
		_walk_tween.kill()
	
	_walk_tween = create_tween()
	_walk_tween.set_ease(Tween.EASE_OUT)
	_walk_tween.tween_property(sprite, "position:y", 0.0, 0.2)
	_bob_phase = 0.0

func _play_tool_swing() -> void:
	if _tool_swing_tween and _tool_swing_tween.is_valid():
		_tool_swing_tween.kill()
	
	var swing_direction := facing_direction
	var rotation_amount := 15.0 if swing_direction.x != 0 else 10.0
	
	# Rotate sprite slightly in swing direction
	var target_rotation := rotation_amount if swing_direction.x > 0 or swing_direction.y > 0 else -rotation_amount
	
	_tool_swing_tween = create_tween()
	_tool_swing_tween.set_parallel(true)
	_tool_swing_tween.set_ease(Tween.EASE_OUT)
	_tool_swing_tween.set_trans(Tween.TRANS_QUART)
	
	_tool_swing_tween.tween_property(sprite, "rotation_degrees", target_rotation, 0.1)
	_tool_swing_tween.tween_property(sprite, "scale", Vector2(1.1, 0.9), 0.1)
	_tool_swing_tween.tween_interval(0.05)
	_tool_swing_tween.tween_property(sprite, "rotation_degrees", 0.0, 0.1)
	_tool_swing_tween.tween_property(sprite, "scale", Vector2.ONE, 0.1)
