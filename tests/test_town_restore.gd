extends Node
## Unit test for TownManager.deserialize — validates that loading a save with
## pre-restored ruin statuses re-emits ruin_status_changed so RuinStructure
## sprites refresh from the loaded state (single-player + host load path).

var _fails: Array[String] = []
var _passes: Array[String] = []
var _idx := 0

func _check(cond: bool, msg: String) -> void:
	_idx += 1
	if cond:
		_passes.append(msg)
		print("  PASS[%d] %s" % [_idx, msg])
	else:
		_fails.append(msg)
		print("  FAIL[%d] %s" % [_idx, msg])


func test_deserialize_reemits_ruin_status_changed() -> void:
	print("-- test_deserialize_reemits_ruin_status_changed --")
	var tm := TownManager.new()
	# Build ruin state as world-generation would (all at RUBBLE).
	var defs := TownManager.get_builtin_ruin_defs()
	var positions: Dictionary = {}
	for d: TownManager.RuinDef in defs:
		positions[d.id] = d.grid_cell
	tm.initialize(positions)

	# Track which ruins the signal re-emits for.
	var emitted: Dictionary = {}
	tm.ruin_status_changed.connect(func(rid: String, status: int) -> void:
		emitted[rid] = status)

	# Simulate a save where bakery is RESTORED and cottage_1 is RUBBLE.
	var save := {
		"town_level": 1,
		"reputation": 25,
		"ruins": {
			"bakery": {"status": TownManager.RuinStatus.RESTORED, "contributed": {"wood": 8, "stone": 5, "wooden_planks": 3, "gold_ingot": 1}},
			"cottage_1": {"status": TownManager.RuinStatus.RUBBLE, "contributed": {}},
		},
		"residents": {},
	}
	tm.deserialize(save)

	_check(emitted.has("bakery"), "ruin_status_changed re-emitted for bakery")
	_check(emitted.get("bakery", -1) == TownManager.RuinStatus.RESTORED, "bakery re-emitted as RESTORED")
	_check(emitted.has("cottage_1"), "ruin_status_changed re-emitted for cottage_1")
	_check(emitted.get("cottage_1", -1) == TownManager.RuinStatus.RUBBLE, "cottage_1 re-emitted as RUBBLE")
	_check(tm.get_ruin_status("bakery") == TownManager.RuinStatus.RESTORED, "ruins dict status updated to RESTORED")


func test_deserialize_empty_noop() -> void:
	print("-- test_deserialize_empty_noop --")
	var tm := TownManager.new()
	var fired := false
	tm.ruin_status_changed.connect(func(_rid: String, _status: int) -> void:
		fired = true)
	tm.deserialize({})
	_check(not fired, "empty save does not emit signals")


func run_all() -> void:
	test_deserialize_reemits_ruin_status_changed()
	test_deserialize_empty_noop()
	print("== RESULT: %d passed, %d failed ==" % [_passes.size(), _fails.size()])
	if _fails.is_empty():
		print("TEST-PASS")
	else:
		print("TEST-FAIL")
		for f in _fails:
			print("  FAILED: " + f)


func _init() -> void:
	run_all()