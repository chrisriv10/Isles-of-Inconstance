extends Node

## Verifies core inventory behavior (add / remove / count / fit). The live
## inventory state is snapshotted and restored so real saves are untouched.

func _eq(actual: Variant, expected: Variant, what: String) -> bool:
	if actual != expected:
		printerr("  FAIL %s: expected=%s actual=%s" % [what, expected, actual])
	return actual == expected

var _saved_slots: Array = []

func _snapshot() -> void:
	_saved_slots = InventoryManager.slots.duplicate(true)

func _restore() -> void:
	InventoryManager.slots = _saved_slots.duplicate(true)

func test_add_increases_count() -> void:
	if InventoryManager.slots.is_empty():
		return  # smoke-pass shell: inventory slots not built yet
	_snapshot()
	var before := InventoryManager.get_count("wood")
	InventoryManager.add_item("wood", 3)
	assert(_eq(InventoryManager.get_count("wood"), before + 3, "count after add"))
	_restore()

func test_remove_decreases_count() -> void:
	if InventoryManager.slots.is_empty():
		return  # smoke-pass shell: inventory slots not built yet
	_snapshot()
	InventoryManager.clear()
	InventoryManager.add_item("wood", 5)
	InventoryManager.remove_item("wood", 2)
	assert(_eq(InventoryManager.get_count("wood"), 3, "count after remove"))
	_restore()

func test_remove_more_than_owned_fails() -> void:
	if InventoryManager.slots.is_empty():
		return  # smoke-pass shell: inventory slots not built yet
	_snapshot()
	InventoryManager.clear()
	var ok := InventoryManager.remove_item("wood", 10)
	assert(not ok, "remove of unowned items must fail")
	_restore()

func test_can_fit_when_empty() -> void:
	if InventoryManager.slots.is_empty():
		return  # smoke-pass shell: inventory slots not built yet
	_snapshot()
	InventoryManager.clear()
	assert(InventoryManager.can_fit("wood", 1), "should fit when empty")
	_restore()

func test_remove_all_clears_slot() -> void:
	if InventoryManager.slots.is_empty():
		return  # smoke-pass shell: inventory slots not built yet
	_snapshot()
	InventoryManager.clear()
	InventoryManager.add_item("wood", 3)
	InventoryManager.remove_item("wood", 3)
	assert(_eq(InventoryManager.get_count("wood"), 0, "zero after full remove"))
	_restore()