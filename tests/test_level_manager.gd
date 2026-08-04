extends Node

## Locks the XP curve and verifies add_xp()/level-up behavior. Live player
## XP/level state is snapshotted and restored so the suite is side-effect free.

func _eq(actual: Variant, expected: Variant, what: String) -> bool:
	if actual != expected:
		printerr("  FAIL %s: expected=%s actual=%s" % [what, expected, actual])
	return actual == expected

var _saved_level: int = 0
var _saved_xp: int = 0

func _snapshot() -> void:
	_saved_level = LevelManager.player_level
	_saved_xp = LevelManager.current_xp

func _restore() -> void:
	LevelManager.player_level = _saved_level
	LevelManager.current_xp = _saved_xp

func test_xp_to_next_is_monotonic() -> void:
	var prev := 0
	for level in range(1, 30):
		var need := LevelManager.xp_to_next(level)
		assert(need > prev, "xp_to_next(%d) must exceed xp_to_next(%d)" % [level, level - 1])
		prev = need

func test_xp_to_next_exact_values() -> void:
	assert(_eq(LevelManager.xp_to_next(1), 60, "xp_to_next(1)"))
	assert(_eq(LevelManager.xp_to_next(2), 111, "xp_to_next(2)"))

func test_add_xp_increases_xp() -> void:
	_snapshot()
	LevelManager.player_level = 1
	LevelManager.current_xp = 0
	LevelManager.add_xp(5, "test")
	assert(_eq(LevelManager.get_xp(), 5, "xp after add"))
	assert(_eq(LevelManager.get_level(), 1, "no accidental level-up"))
	_restore()

func test_zero_or_negative_xp_is_ignored() -> void:
	_snapshot()
	LevelManager.player_level = 1
	LevelManager.current_xp = 10
	LevelManager.add_xp(0, "test")
	LevelManager.add_xp(-3, "test")
	assert(_eq(LevelManager.get_xp(), 10, "xp unchanged"))
	_restore()

func test_level_up_at_threshold() -> void:
	_snapshot()
	LevelManager.player_level = 1
	LevelManager.current_xp = 58
	LevelManager.add_xp(5, "test")  # 63 >= 60 -> level 2, 3 xp remaining
	assert(_eq(LevelManager.get_level(), 2, "level after threshold"))
	assert(_eq(LevelManager.get_xp(), 3, "remaining xp"))
	_restore()