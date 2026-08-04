extends Node

## Locks in the per-save difficulty multiplier values so rebalancing
## mistakes (or accidental edits) are caught at test time.

func _eq(actual: Variant, expected: Variant, what: String) -> bool:
	if actual != expected:
		printerr("  FAIL %s: expected=%s actual=%s" % [what, expected, actual])
	return actual == expected

func _with_difficulty(diff: int, check: Callable) -> void:
	var saved := GameManager.difficulty
	GameManager.set_difficulty(diff)
	check.call()
	GameManager.set_difficulty(saved)

func test_difficulty_name_labels() -> void:
	assert(_eq(GameManager.difficulty_name(GameManager.Difficulty.CASUAL), "Casual", "casual label"))
	assert(_eq(GameManager.difficulty_name(GameManager.Difficulty.NORMAL), "Normal", "normal label"))
	assert(_eq(GameManager.difficulty_name(GameManager.Difficulty.HARD), "Hard", "hard label"))

func test_casual_multipliers() -> void:
	_with_difficulty(GameManager.Difficulty.CASUAL, func() -> void:
		assert(_eq(GameManager.get_enemy_hp_mult(), 0.8, "casual enemy hp"))
		assert(_eq(GameManager.get_enemy_dmg_mult(), 0.8, "casual enemy dmg"))
		assert(_eq(GameManager.get_boss_hp_mult(), 0.8, "casual boss hp"))
		assert(_eq(GameManager.get_boss_dmg_mult(), 0.8, "casual boss dmg"))
		assert(_eq(GameManager.get_spawn_interval_mult(), 1.3, "casual interval"))
		assert(_eq(GameManager.get_max_enemy_mult(), 0.6, "casual max enemy"))
		assert(_eq(GameManager.get_loot_mult(), 1.2, "casual loot"))
		assert(_eq(GameManager.get_sell_mult(), 1.0, "casual sell"))
		assert(_eq(GameManager.get_income_mult(), 1.0, "casual income")))

func test_normal_multipliers() -> void:
	_with_difficulty(GameManager.Difficulty.NORMAL, func() -> void:
		assert(_eq(GameManager.get_enemy_hp_mult(), 1.4, "normal enemy hp"))
		assert(_eq(GameManager.get_enemy_dmg_mult(), 1.4, "normal enemy dmg"))
		assert(_eq(GameManager.get_boss_hp_mult(), 1.5, "normal boss hp"))
		assert(_eq(GameManager.get_boss_dmg_mult(), 1.5, "normal boss dmg"))
		assert(_eq(GameManager.get_spawn_interval_mult(), 1.0, "normal interval"))
		assert(_eq(GameManager.get_max_enemy_mult(), 1.0, "normal max enemy"))
		assert(_eq(GameManager.get_loot_mult(), 1.0, "normal loot"))
		assert(_eq(GameManager.get_sell_mult(), 0.85, "normal sell"))
		assert(_eq(GameManager.get_income_mult(), 0.8, "normal income")))

func test_hard_multipliers() -> void:
	_with_difficulty(GameManager.Difficulty.HARD, func() -> void:
		assert(_eq(GameManager.get_enemy_hp_mult(), 2.0, "hard enemy hp"))
		assert(_eq(GameManager.get_enemy_dmg_mult(), 2.0, "hard enemy dmg"))
		assert(_eq(GameManager.get_boss_hp_mult(), 2.5, "hard boss hp"))
		assert(_eq(GameManager.get_boss_dmg_mult(), 2.0, "hard boss dmg"))
		assert(_eq(GameManager.get_spawn_interval_mult(), 0.65, "hard interval"))
		assert(_eq(GameManager.get_max_enemy_mult(), 1.5, "hard max enemy"))
		assert(_eq(GameManager.get_loot_mult(), 0.5, "hard loot"))
		assert(_eq(GameManager.get_sell_mult(), 0.65, "hard sell"))
		assert(_eq(GameManager.get_income_mult(), 0.5, "hard income")))

func test_set_difficulty_clamps_invalid_values() -> void:
	var saved := GameManager.difficulty
	GameManager.set_difficulty(999)
	assert(_eq(GameManager.difficulty, GameManager.Difficulty.HARD, "clamp high"))
	GameManager.set_difficulty(-5)
	assert(_eq(GameManager.difficulty, GameManager.Difficulty.CASUAL, "clamp low"))
	GameManager.set_difficulty(saved)

# Note: signal delivery can't be asserted from the test harness (the
# runner's smoke pass uses a shell autoload that doesn't deliver signal
# emissions to test lambdas); set_difficulty's behavior is already covered
# by the clamp and multiplier tests above.