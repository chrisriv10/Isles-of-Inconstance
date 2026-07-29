## InteriorWanderNPC — attached to interior NPC sprites so they walk around
## inside the building instead of standing still. The NPC moves between
## random waypoints within a small radius of their spawn position,
## with occasional pauses.
extends Node
class_name InteriorWanderNPC

## Movement speed in px/sec
var wander_speed: float = 12.0

## Max distance from origin to wander
var wander_radius: float = 24.0

## Pause time between wander cycles (seconds)
var pause_min: float = 2.0
var pause_max: float = 6.0

## Origin position (where the NPC was placed in the interior)
var _origin: Vector2 = Vector2.ZERO

## Current target waypoint
var _target: Vector2 = Vector2.ZERO

## Whether the NPC is currently moving or paused
var _moving: bool = false

## Pause timer
var _pause_timer: float = 0.0

## The Sprite2D to flip based on movement direction
var _sprite: Sprite2D = null


func _ready() -> void:
	var parent := get_parent()
	if parent is Node2D:
		_origin = parent.position
	# Find the Sprite2D child of the parent (the NPC sprite)
	for child in get_parent().get_children():
		if child is Sprite2D:
			_sprite = child
			break
	_pick_new_target()


func _process(delta: float) -> void:
	if _moving:
		var dir: Vector2 = (_target - get_parent().position).normalized()
		var dist_sq: float = get_parent().position.distance_squared_to(_target)
		if dist_sq > 4.0:
			var step: Vector2 = dir * wander_speed * delta
			get_parent().position += step
			if _sprite:
				_sprite.flip_h = dir.x < -0.1
		else:
			# Arrived — pause
			_moving = false
			_pause_timer = pause_min + randf() * (pause_max - pause_min)
			if _sprite:
				_sprite.flip_h = false
	else:
		_pause_timer -= delta
		if _pause_timer <= 0.0:
			_pick_new_target()
			_moving = true


func _pick_new_target() -> void:
	_target = _origin + Vector2(
		randf_range(-wander_radius, wander_radius),
		randf_range(-wander_radius, wander_radius)
	)
