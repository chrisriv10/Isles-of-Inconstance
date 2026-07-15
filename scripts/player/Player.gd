extends CharacterBody2D

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

var facing_direction: Vector2 = Vector2.DOWN
var active_tool: Tool = Tool.HOE
var selected_seed_crop_id: String = ""

var _tool_cooldown_remaining: float = 0.0

func _ready() -> void:
	call_deferred("_emit_initial_tool")

func _emit_initial_tool() -> void:
	_update_tool_ui()

func _physics_process(delta: float) -> void:
	if _tool_cooldown_remaining > 0.0:
		_tool_cooldown_remaining -= delta

	var input_direction := _get_input_direction()
	velocity = input_direction * speed
	move_and_slide()

	if input_direction != Vector2.ZERO:
		facing_direction = input_direction
		facing_changed.emit(facing_direction)
		_update_interactor_position()

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

## Called by the Shop/Inventory UI when the player picks a seed to plant -
## covers any seed they own, not just the 3 starter crops. Immediately
## switches the active tool to the "Selected Seed" slot so it's ready to use.
func select_seed(crop_id: String) -> void:
	selected_seed_crop_id = crop_id
	_set_tool(Tool.SEED_SLOT_SELECTED)

func _set_tool(tool: Tool) -> void:
	active_tool = tool
	_update_tool_ui()

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
		interactor.position = facing_direction * 10.0

func _try_interact() -> void:
	if interactor and interactor.has_method("interact_with_nearest"):
		var interacted: bool = interactor.interact_with_nearest()
		if not interacted:
			var world := get_tree().get_first_node_in_group("world")
			if world and world.has_method("harvest_crop"):
				var target_pos: Vector2 = global_position + facing_direction * 16.0
				world.harvest_crop(target_pos)

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
		_tool_cooldown_remaining = base_tool_cooldown * UpgradeManager.get_farming_speed_multiplier()
