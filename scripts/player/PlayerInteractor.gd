extends Area2D

## Tracks which Interactable objects are currently in range of the player
## and exposes a single entry point (interact_with_nearest) for Player.gd to
## call. Also surfaces the current prompt text so the UI can display it.

signal interactable_in_range(interactable: Interactable)
signal interactable_out_of_range()

var _nearby: Array[Interactable] = []

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

func _on_area_entered(area: Area2D) -> void:
	if area is Interactable and area.can_interact():
		_nearby.append(area)
		interactable_in_range.emit(get_nearest())

func _on_area_exited(area: Area2D) -> void:
	if area in _nearby:
		_nearby.erase(area)
	if _nearby.is_empty():
		interactable_out_of_range.emit()
	else:
		interactable_in_range.emit(get_nearest())

func get_nearest() -> Interactable:
	if _nearby.is_empty():
		return null
	var nearest: Interactable = _nearby[0]
	var nearest_dist := global_position.distance_squared_to(nearest.global_position)
	for candidate in _nearby:
		var dist := global_position.distance_squared_to(candidate.global_position)
		if dist < nearest_dist:
			nearest = candidate
			nearest_dist = dist
	return nearest

func get_nearest_interactable() -> Interactable:
	return get_nearest()

## Returns true if the nearest interactable has no tool requirement,
## or if the player has the required tool equipped.
## This lets Player.gd decide whether to eat instead of attempting
## a blocked interaction (e.g. pressing E near a tree without an axe).
func can_player_use_nearest(player: Player) -> bool:
	var target := get_nearest()
	if not target:
		return false
	# No tool requirement → always usable
	if target.required_tool < 0:
		return true
	# Check if player has the required tool
	return player.has_tool_active(target.required_tool)

func interact_with_nearest() -> bool:
	var target := get_nearest()
	if target and target.can_interact():
		target.interact(get_owner())
		if target.single_use:
			_nearby.erase(target)
			interactable_out_of_range.emit()
		return true
	return false
