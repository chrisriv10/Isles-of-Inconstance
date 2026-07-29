extends Node2D
class_name DialogueBubbleFollow

## Attached dynamically to dialogue bubble containers so they follow
## a target node (pirate enemy or ship) as it moves around the world.

var _target: WeakRef
var _target_offset: Vector2
var _bubble_size: Vector2


func _process(_delta: float) -> void:
	var t: Node = _target.get_ref()
	if not t or not is_instance_valid(t):
		return
	# Position bubble centered horizontally, above target vertically
	global_position = t.global_position + _target_offset - _bubble_size / 2.0


## Initialize the follower.
## `target` — the moving node to follow.
## `offset` — the upward offset from the target's origin (e.g. Vector2(0, -32)).
## `bubble_size` — the width/height of the bubble label for centering.
func follow(target: Node, offset: Vector2, bubble_size: Vector2) -> void:
	_target = weakref(target)
	_target_offset = offset
	_bubble_size = bubble_size
