extends Node

## Verifies Enemy.apply_difficulty_scaling(): correct multipliers per
## difficulty, boss uses the boss multipliers, idempotency, and the remote
## guard. Uses bare Enemy.new() nodes (never added to a tree) and frees
## them at the end of each test.

func _eq(actual: Variant, expected: Variant, what: String) -> bool:
	if actual != expected:
		printerr("  FAIL %s: expected=%s actual=%s" % [what, expected, actual])
	return actual == expected

func _make_enemy(max_hp: int, dmg: int) -> Enemy:
	var e := Enemy.new()
	e.max_health = max_hp
	e.damage = dmg
	e.current_health = max_hp
	return e

func test_hard_enemy_scaling() -> void:
	var saved := GameManager.difficulty
	GameManager.set_difficulty(GameManager.Difficulty.HARD)
	var e := _make_enemy(100, 10)
	e.apply_difficulty_scaling()
	assert(_eq(e.max_health, 200, "hard hp 100*2.0"))
	assert(_eq(e.damage, 20, "hard dmg 10*2.0"))
	assert(_eq(e.current_health, e.max_health, "current==max"))
	e.free()
	GameManager.set_difficulty(saved)

func test_normal_enemy_scaling() -> void:
	var saved := GameManager.difficulty
	GameManager.set_difficulty(GameManager.Difficulty.NORMAL)
	var e := _make_enemy(100, 10)
	e.apply_difficulty_scaling()
	assert(_eq(e.max_health, 140, "normal hp 100*1.4"))
	assert(_eq(e.damage, 14, "normal dmg 10*1.4"))
	e.free()
	GameManager.set_difficulty(saved)

func test_casual_enemy_scaling() -> void:
	var saved := GameManager.difficulty
	GameManager.set_difficulty(GameManager.Difficulty.CASUAL)
	var e := _make_enemy(100, 10)
	e.apply_difficulty_scaling()
	assert(_eq(e.max_health, 80, "casual hp 100*0.8"))
	e.free()
	GameManager.set_difficulty(saved)

func test_scaling_is_idempotent() -> void:
	var saved := GameManager.difficulty
	GameManager.set_difficulty(GameManager.Difficulty.HARD)
	var e := _make_enemy(100, 10)
	e.apply_difficulty_scaling()
	e.apply_difficulty_scaling()
	assert(_eq(e.max_health, 200, "not doubled twice"))
	e.free()
	GameManager.set_difficulty(saved)

func test_boss_uses_boss_multiplier() -> void:
	var saved := GameManager.difficulty
	GameManager.set_difficulty(GameManager.Difficulty.HARD)
	var e := _make_enemy(100, 10)
	e.add_to_group("bosses")
	e.apply_difficulty_scaling()
	assert(_eq(e.max_health, 250, "boss hp 100*2.5"))
	assert(_eq(e.damage, 20, "boss dmg 10*2.0"))
	e.free()
	GameManager.set_difficulty(saved)

func test_remote_enemy_skips_scaling() -> void:
	var saved := GameManager.difficulty
	GameManager.set_difficulty(GameManager.Difficulty.HARD)
	var e := _make_enemy(100, 10)
	e._is_remote = true
	e.apply_difficulty_scaling()
	assert(_eq(e.max_health, 100, "remote untouched"))
	assert(_eq(e.damage, 10, "remote dmg untouched"))
	e.free()
	GameManager.set_difficulty(saved)

func test_drop_rate_constant_locked() -> void:
	# Guards the loot-difficulty tuning (0.35 = harder mode, less loot).
	assert(_eq(Enemy.DROP_RATE_MULTIPLIER, 0.35, "drop rate mult"))