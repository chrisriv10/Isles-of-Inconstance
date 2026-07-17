extends Area2D
class_name Interactable

## Generic base for anything in the world the player can interact with
## (resource nodes, crops, doors, NPCs...). Attach this script directly for
## simple objects, or extend it (extends "res://scripts/world/Interactable.gd")
## for behaviour that needs its own state.

@export var interaction_prompt: String = "Interact"
@export var single_use: bool = false

signal interacted(interactor: Node)

var _used: bool = false

func can_interact() -> bool:
	return not (single_use and _used)

## Called by whoever performs the interaction (usually PlayerInteractor).
## Override this in subclasses to add custom behaviour, calling
## super.interact(interactor) last if you still want the signal emitted.
func interact(interactor: Node) -> void:
	if not can_interact():
		return
	_used = true
	interacted.emit(interactor)
