extends Node

## Validates the COMBAT and LUCK upgrades: enum wiring, names, descriptions,
## and the (1.6x) cost curve. Upgrade levels are snapshotted and restored.

func _eq(actual: Variant, expected: Variant, what: String) -> bool:
	if actual != expected:
		printerr("  FAIL %s: expected=%s actual=%s" % [what, expected, actual])
	return actual == expected

var _saved_levels: Dictionary = {}

func _snapshot() -> void:
	_saved_levels = UpgradeManager.levels.duplicate()

func _restore() -> void:
	UpgradeManager.levels = _saved_levels.duplicate()

func test_combat_and_luck_enum_values() -> void:
	# COMBAT=4 and LUCK=5 were appended so existing saves stay compatible.
	assert(_eq(int(UpgradeManager.Upgrade.COMBAT), 4, "COMBAT enum value"))
	assert(_eq(int(UpgradeManager.Upgrade.LUCK), 5, "LUCK enum value"))

func test_combat_name_and_description() -> void:
	assert(_eq(UpgradeManager.get_upgrade_name(UpgradeManager.Upgrade.COMBAT), "Combat Training", "COMBAT name"))
	assert(not UpgradeManager.get_description(UpgradeManager.Upgrade.COMBAT).is_empty(), "COMBAT desc empty")

func test_luck_name_and_description() -> void:
	assert(_eq(UpgradeManager.get_upgrade_name(UpgradeManager.Upgrade.LUCK), "Mystic Luck", "LUCK name"))
	assert(not UpgradeManager.get_description(UpgradeManager.Upgrade.LUCK).is_empty(), "LUCK desc empty")

func test_base_costs() -> void:
	_snapshot()
	UpgradeManager.levels[UpgradeManager.Upgrade.COMBAT] = 0
	UpgradeManager.levels[UpgradeManager.Upgrade.LUCK] = 0
	assert(_eq(UpgradeManager.get_cost(UpgradeManager.Upgrade.COMBAT), 600, "COMBAT base cost"))
	assert(_eq(UpgradeManager.get_cost(UpgradeManager.Upgrade.LUCK), 800, "LUCK base cost"))
	_restore()

func test_cost_increases_with_level() -> void:
	_snapshot()
	UpgradeManager.levels[UpgradeManager.Upgrade.COMBAT] = 0
	var base := UpgradeManager.get_cost(UpgradeManager.Upgrade.COMBAT)
	UpgradeManager.levels[UpgradeManager.Upgrade.COMBAT] = 1
	var lvl1 := UpgradeManager.get_cost(UpgradeManager.Upgrade.COMBAT)
	UpgradeManager.levels[UpgradeManager.Upgrade.COMBAT] = 2
	var lvl2 := UpgradeManager.get_cost(UpgradeManager.Upgrade.COMBAT)
	assert(lvl1 > base, "cost grows from lvl0")
	assert(lvl2 > lvl1, "cost grows from lvl1")
	assert(_eq(lvl1, roundi(600 * 1.6), "lvl1 cost 960"))
	assert(_eq(lvl2, roundi(600 * 1.6 * 1.6), "lvl2 cost 1536"))
	_restore()

func test_all_upgrades_have_valid_data() -> void:
	_snapshot()
	for u in UpgradeManager.Upgrade.values():
		assert(UpgradeManager.get_cost(u) > 0, "zero cost for upgrade %d" % u)
		assert(not UpgradeManager.get_upgrade_name(u).is_empty(), "empty name for upgrade %d" % u)
		assert(not UpgradeManager.get_description(u).is_empty(), "empty desc for upgrade %d" % u)
	_restore()