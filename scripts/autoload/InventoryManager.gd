extends Node

## Autoload singleton. Central home for everything the player is carrying:
## seeds, harvested crops, and gathered resources. All three are just
## ItemData ids under the hood (see DataManager) - "seeds/crops/resources"
## is a UI-level grouping (see ItemData.category), not a structural one, so
## new item types automatically fit in without touching this script.
##
## Slots are stack-based, Stardew-style: a fixed number of slots, each
## holding up to `ItemData.stack_size` of a single item id. Capacity is
## raised by the "Storage Satchel" upgrade (see UpgradeManager).

signal changed()
signal capacity_changed(new_capacity: int)

const BASE_CAPACITY: int = 24
const CAPACITY_PER_UPGRADE_LEVEL: int = 6

# Array of null or {"item_id": String, "count": int} dictionaries.
var slots: Array = []
var capacity: int = BASE_CAPACITY

func _ready() -> void:
	slots.resize(capacity)

func set_capacity(new_capacity: int) -> void:
	capacity = maxi(new_capacity, get_used_slot_count())
	if slots.size() < capacity:
		var to_add := capacity - slots.size()
		for i in range(to_add):
			slots.append(null)
	capacity_changed.emit(capacity)
	changed.emit()

## Attempts to add `amount` of `item_id`, topping up existing stacks before
## using empty slots. Returns how much did NOT fit (0 means it all fit).
## Optional `tint` color is stored with the slot so the UI can show tinted icons.
## Items with different tints do NOT stack together.
func add_item(item_id: String, amount: int = 1, tint: Color = Color.WHITE) -> int:
	if item_id == "" or amount <= 0:
		return 0

	var item: ItemData = DataManager.get_item(item_id)
	var stack_size: int = item.stack_size if item else 99

	# Tool items: enforce one-of-a-kind - refuse to add if player already owns one
	if stack_size == 1 and item and item.category == "tool":
		for slot in slots:
			if slot != null and slot["item_id"] == item_id:
				return amount  # already have it, don't add more
		# Limit to 1 per call for tools (prevent filling multiple slots)
		amount = 1

	var remaining := amount

	# First pass: top up existing stacks with the SAME tint
	for i in range(slots.size()):
		if remaining <= 0:
			break
		var slot = slots[i]
		if slot != null and slot["item_id"] == item_id and slot["count"] < stack_size:
			# Only stack if tints match (or both are white/no tint)
			var slot_tint: Color = slot.get("tint", Color.WHITE)
			if _colors_equal_approx(slot_tint, tint):
				var room: int = stack_size - slot["count"]
				var added: int = mini(room, remaining)
				slot["count"] += added
				remaining -= added

	# Second pass: empty slots
	for i in range(slots.size()):
		if remaining <= 0:
			break
		if slots[i] == null:
			var added: int = mini(stack_size, remaining)
			var entry: Dictionary = {"item_id": item_id, "count": added}
			if tint != Color.WHITE:
				entry["tint"] = tint
			slots[i] = entry
			remaining -= added

	if remaining < amount:
		changed.emit()
		# Track that the player has discovered this item (for Collections UI)
		DataManager.mark_item_discovered(item_id)
	return remaining

## Cheap check for "would add_item(item_id, amount) fit entirely?" without
## mutating anything - used to gate actions like harvesting.
func can_fit(item_id: String, amount: int) -> bool:
	if amount <= 0:
		return true
	var item: ItemData = DataManager.get_item(item_id)
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

## Returns {item_id: count} for every non-empty stack, merged across slots.
## Handy for UI that just wants "what do I have" without caring about slot
## layout.
func get_all_counts() -> Dictionary:
	var totals: Dictionary = {}
	for slot in slots:
		if slot != null:
			totals[slot["item_id"]] = totals.get(slot["item_id"], 0) + slot["count"]
	return totals

## Same as get_all_counts() but filtered to items of a given ItemData
## category ("seed", "crop", "resource", ...).
func get_counts_by_category(category: String) -> Dictionary:
	var totals := get_all_counts()
	var filtered: Dictionary = {}
	for item_id in totals.keys():
		var item: ItemData = DataManager.get_item(item_id)
		if item and item.category == category:
			filtered[item_id] = totals[item_id]
	return filtered

## Get all items as {item_id: count} dictionary (for save/load)
func get_all_items() -> Dictionary:
	return get_all_counts()

## Sort inventory by category order: tool, weapon, armor, seed, crop, food, meal, resource, pet_egg, misc
func sort_inventory() -> void:
	var priority: Dictionary = {
		"tool": 0, "weapon": 1, "armor": 2, "seed": 3, "crop": 4,
		"food": 5, "meal": 6, "resource": 7, "pet_egg": 8, "misc": 9
	}
	# Collect all non-null slots
	var items: Array[Dictionary] = []
	for slot in slots:
		if slot != null:
			items.append(slot.duplicate())
	# Sort by category priority, then item_id
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var item_a: ItemData = DataManager.get_item(a["item_id"])
		var item_b: ItemData = DataManager.get_item(b["item_id"])
		var cat_a: int = priority.get(item_a.category if item_a else "misc", 9)
		var cat_b: int = priority.get(item_b.category if item_b else "misc", 9)
		if cat_a != cat_b:
			return cat_a < cat_b
		return a["item_id"] < b["item_id"]
	)
	# Clear and re-fill slots
	for i in range(slots.size()):
		slots[i] = null
	var idx: int = 0
	for entry in items:
		if idx < slots.size():
			slots[idx] = entry
			idx += 1
	changed.emit()

## Compare two colors approximately (for tint matching in stacking).
func _colors_equal_approx(a: Color, b: Color) -> bool:
	return abs(a.r - b.r) < 0.01 and abs(a.g - b.g) < 0.01 and abs(a.b - b.b) < 0.01

## Clear all inventory slots (for save/load)
func clear() -> void:
	for i in range(slots.size()):
		slots[i] = null
	changed.emit()
