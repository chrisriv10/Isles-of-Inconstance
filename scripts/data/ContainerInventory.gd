extends RefCounted
class_name ContainerInventory

## Instance-based inventory container for chests, crates, etc.
## Mirrors InventoryManager's slot logic so each chest gets its own storage.

signal changed()

## Maximum number of slots this container holds.
var capacity: int = 18

## Array of null or {"item_id": String, "count": int} dictionaries.
var slots: Array = []


func _init(p_capacity: int = 18) -> void:
	capacity = maxi(p_capacity, 1)
	slots.resize(capacity)


## Attempts to add `amount` of `item_id`, topping up existing stacks first,
## then filling empty slots. Returns the count that did NOT fit (0 = all fit).
func add_item(item_id: String, amount: int = 1) -> int:
	if item_id == "" or amount <= 0:
		return 0

	var item := DataManager.get_item(item_id)
	var stack_size: int = item.stack_size if item else 99
	var remaining := amount

	# Top up existing stacks
	for i in range(slots.size()):
		if remaining <= 0:
			break
		var slot = slots[i]
		if slot != null and slot["item_id"] == item_id and slot["count"] < stack_size:
			var room: int = stack_size - slot["count"]
			var added: int = mini(room, remaining)
			slot["count"] += added
			remaining -= added

	# Fill empty slots
	for i in range(slots.size()):
		if remaining <= 0:
			break
		if slots[i] == null:
			var added: int = mini(stack_size, remaining)
			slots[i] = {"item_id": item_id, "count": added}
			remaining -= added

	if remaining < amount:
		changed.emit()
	return remaining


## Returns true if `add_item(item_id, amount)` would fully fit.
func can_fit(item_id: String, amount: int) -> bool:
	if amount <= 0:
		return true
	var item := DataManager.get_item(item_id)
	var stack_size: int = item.stack_size if item else 99
	var free := 0
	for slot in slots:
		if slot == null:
			free += stack_size
		elif slot["item_id"] == item_id:
			free += stack_size - slot["count"]
		if free >= amount:
			return true
	return free >= amount


## Removes `amount` of `item_id`. Returns false if insufficient quantity.
func remove_item(item_id: String, amount: int = 1) -> bool:
	if amount <= 0:
		return true
	if not has_item(item_id, amount):
		return false
	var remaining := amount
	for i in range(slots.size()):
		if remaining <= 0:
			break
		var slot = slots[i]
		if slot != null and slot["item_id"] == item_id:
			var taken: int = mini(slot["count"], remaining)
			slot["count"] -= taken
			remaining -= taken
			if slot["count"] <= 0:
				slots[i] = null
	changed.emit()
	return true


func get_count(item_id: String) -> int:
	var total := 0
	for slot in slots:
		if slot != null and slot["item_id"] == item_id:
			total += slot["count"]
	return total


func has_item(item_id: String, amount: int = 1) -> bool:
	return get_count(item_id) >= amount


func get_used_slot_count() -> int:
	var used := 0
	for slot in slots:
		if slot != null:
			used += 1
	return used


## Returns {item_id: count} merged across all slots.
func get_all_counts() -> Dictionary:
	var totals: Dictionary = {}
	for slot in slots:
		if slot != null:
			totals[slot["item_id"]] = totals.get(slot["item_id"], 0) + slot["count"]
	return totals


## Empties all slots.
func clear() -> void:
	for i in range(slots.size()):
		slots[i] = null
	changed.emit()
