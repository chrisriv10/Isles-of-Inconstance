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

# Multiplayer position replication (host-authoritative, via World relay).
## Whether this is a client-side copy that mirrors the host's position.
var _is_remote: bool = false
## Seconds between host broadcasts of this NPC's position to clients.
const POS_SYNC_INTERVAL: float = 0.25
var _pos_sync_timer: float = 0.0
## The World node used to relay positions (cached in _ready).
var _world: Node = null


func _ready() -> void:
	var parent := get_parent()
	if parent is Node2D:
		_origin = parent.position
	# Find the Sprite2D child of the parent (the NPC sprite)
	for child in get_parent().get_children():
		if child is Sprite2D:
			_sprite = child
			break
	add_to_group("interior_wander_npcs")
	_world = get_tree().get_first_node_in_group("world")
	_pick_new_target()


func _process(delta: float) -> void:
	# Host-authoritative position relay: host nodes broadcast so every player in
	# the same shared building interior sees this NPC in the same spot; remote
	# copies apply via World relay. Local in-room position is used because the
	# interior base (INTERIOR_VOID) is identical on every peer.
	if not _is_remote and NetworkManager.is_network_active() and multiplayer.is_server() \
			and _world and _world.has_method("relay_interior_wander_pos"):
		_pos_sync_timer -= delta
		if _pos_sync_timer <= 0.0:
			_pos_sync_timer = POS_SYNC_INTERVAL
			var p := get_parent()
			if p is Node2D:
				_world.relay_interior_wander_pos(p.position.x, p.position.y, _origin.x, _origin.y)

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


## Mirror the host's authoritative position (called by World._sync_interior_wander_pos).
func apply_remote_position(pos: Vector2) -> void:
	if not _is_remote:
		return
	if get_parent() is Node2D:
		get_parent().position = pos
