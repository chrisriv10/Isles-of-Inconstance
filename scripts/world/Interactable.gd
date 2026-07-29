extends Area2D
class_name Interactable

## Generic base for anything in the world the player can interact with
## (resource nodes, crops, doors, NPCs...). Attach this script directly for
## simple objects, or extend it (extends "res://scripts/world/Interactable.gd")
## for behaviour that needs its own state.

@export var interaction_prompt: String = "Interact"
@export var single_use: bool = false
## If set to a Player.Tool value (e.g. Player.Tool.AXE), the player must
## have that tool active to interact with this object.
@export var required_tool: int = -1

signal interacted(interactor: Node)

var _used: bool = false

func can_interact() -> bool:
	return not (single_use and _used)

## Check if the interacting player has the required tool active.
## Called at the start of interact() before anything else.
## Supports both legacy direct-tool values and hotbar items via
## Player.has_tool_active().
func _check_tool_requirement(interactor: Node) -> bool:
	if required_tool < 0:
		return true
	var player: Player = interactor as Player if interactor is Player else _resolve_player(interactor)
	if not player:
		return false
	return player.has_tool_active(required_tool)

## Walk up the parent chain or fall back to the player group.
static func _resolve_player(from: Node) -> Player:
	if not from:
		return null
	var p := from
	while p:
		if p is Player:
			return p
		p = p.get_parent()
	return from.get_tree().get_first_node_in_group("player") if from.get_tree() else null

## Called by whoever performs the interaction (usually PlayerInteractor).
## Override this in subclasses to add custom behaviour, calling
## super.interact(interactor) last if you still want the signal emitted.
func interact(interactor: Node) -> void:
	if not can_interact():
		return
	if not _check_tool_requirement(interactor):
		return
	_used = true
	interacted.emit(interactor)
