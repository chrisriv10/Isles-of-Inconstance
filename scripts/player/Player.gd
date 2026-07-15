extends CharacterBody2D

## Handles player input and movement only. Interaction detection lives in
## PlayerInteractor.gd, and world manipulation (tilling, etc.) lives in
## World.gd - Player just asks those systems to act.

signal facing_changed(direction: Vector2)

@export var speed: float = 90.0

@onready var interactor: Area2D = $Interactor
@onready var sprite: Sprite2D = $Sprite2D

var facing_direction: Vector2 = Vector2.DOWN

func _physics_process(_delta: float) -> void:
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
	if event.is_action_pressed("till"):
		_try_till()

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
		interactor.interact_with_nearest()

func _try_till() -> void:
	var world := get_tree().get_first_node_in_group("world")
	if world and world.has_method("till_tile"):
		var target_pos: Vector2 = global_position + facing_direction * 16.0
		world.till_tile(target_pos)
