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
	if is_instance_valid(area) and area in _nearby:
		_nearby.erase(area)
	if _nearby.is_empty():
		interactable_out_of_range.emit()
	else:
		interactable_in_range.emit(get_nearest())

func get_nearest() -> Interactable:
	# Drop freed interactables — world regen and remote player cleanup free
	# them while they may still be tracked here.
	var valid: Array[Interactable] = []
	for tracked in _nearby:
		if is_instance_valid(tracked):
			valid.append(tracked)
	_nearby = valid
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

## Returns the nearest building-entry interactable in range (name "BuildingEntry"
## or prompt "Enter"), or null if none. Used by hold-left-click building entry so
## a player can enter even when a tree/bush cluttering the doorway is the nearest
## generic interactable.
func get_building_entry_in_range() -> Interactable:
	var valid: Array[Interactable] = []
	for tracked in _nearby:
		if is_instance_valid(tracked):
			valid.append(tracked)
	_nearby = valid
	var nearest: Interactable = null
	var nearest_dist := INF
	for candidate in _nearby:
		if candidate.name == "BuildingEntry" or candidate.interaction_prompt == "Enter":
			var dist := global_position.distance_squared_to(candidate.global_position)
			if dist < nearest_dist:
				nearest = candidate
				nearest_dist = dist
	return nearest

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
