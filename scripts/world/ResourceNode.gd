extends Interactable
class_name ResourceNode

## A gatherable world object (rock outcrop, etc.) - interacting with it adds
## a resource item to the player's inventory, then the node disappears.
## World scatters these across the map, which is what gives exploration a
## concrete reward: wander further out, find more nodes, gather more
## resources to sell or (eventually) spend on upgrades.

@export var item_id: String = "stone"
@export var min_amount: int = 1
@export var max_amount: int = 3

func interact(interactor: Node) -> void:
	if not can_interact():
		return
	var amount := randi_range(min_amount, max_amount)
	var leftover := InventoryManager.add_item(item_id, amount)
	var gathered := amount - leftover
	if gathered <= 0:
		return  # inventory was full - leave the node so the player can come back
	super.interact(interactor)
	queue_free()
