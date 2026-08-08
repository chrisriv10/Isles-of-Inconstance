extends Node
## Verifies the two new single-player persistence formats survive a JSON
## save/load round-trip (the same serialization SaveManager writes via
## JSON.stringify and reads back in _apply_save_data).

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


func test_removed_objects_roundtrip() -> void:
	print("-- test_removed_objects_roundtrip --")
	# Removed island objects save as a list of [x, y] arrays.
	var removed: Array = [[10, 20], [-3, 4]]
	var removed_json := JSON.stringify(removed)
	var removed_parsed: Variant = JSON.parse_string(removed_json)
	_check(removed_parsed is Array, "removed_objects parses back to Array")
	if removed_parsed is Array:
		var arr: Array = removed_parsed
		_check(arr.size() == 2, "removed_objects keeps row count")
		var first: Array = arr[0]
		_check(first is Array and int(first[0]) == 10 and int(first[1]) == 20,
			"removed_objects cell [x,y] round-trips")
		_check(int(arr[1][0]) == -3 and int(arr[1][1]) == 4,
			"negative coordinates round-trip")


func test_animal_data_roundtrip() -> void:
	print("-- test_animal_data_roundtrip --")
	# get_network_data() dicts save the full animal state.
	var animal_data := {
		"node_name": "Animal_7",
		"aid": 7,
		"type": "chicken",
		"name": "Cluck",
		"behavior": 1,
		"speed": 30.0,
		"body_c": {"r": 1.0, "g": 1.0, "b": 1.0, "a": 1.0},
		"acc_c": {"r": 0.5, "g": 0.5, "b": 0.5, "a": 1.0},
		"sec_c": {"r": 0.0, "g": 0.0, "b": 0.0, "a": 1.0},
		"spot_c": {"r": 0.2, "g": 0.2, "b": 0.2, "a": 1.0},
		"shape": 0,
		"pattern": 0,
		"hx": 100.0,
		"hy": 200.0,
		"radius": 48.0,
		"fox": 0.0,
		"foy": 0.0,
		"baby": false,
		"tamed": true,
		"growth": 0.0,
		"hp": 20,
		"mhp": 20,
		"int_day": 3,
		"rare": false,
		"affection": 5.0,
	}
	var animals_json := JSON.stringify(animal_data)
	var animal_parsed: Variant = JSON.parse_string(animals_json)
	_check(animal_parsed is Dictionary, "animal dict parses back to Dictionary")
	if animal_parsed is Dictionary:
		var d: Dictionary = animal_parsed
		_check(str(d.get("node_name", "")) == "Animal_7", "animal node_name round-trips")
		_check(bool(d.get("tamed", false)) == true, "animal tamed round-trips")
		_check(float(d.get("hx", 0.0)) == 100.0, "animal home x round-trips")
		_check(int(d.get("aid", -1)) == 7, "animal aid round-trips")
		var body_c: Dictionary = d.get("body_c", {})
		_check(float(body_c.get("r", 0.0)) == 1.0, "animal color dict round-trips")


func run_all() -> void:
	test_removed_objects_roundtrip()
	test_animal_data_roundtrip()
	print("== RESULT: %d passed, %d failed ==" % [_passes.size(), _fails.size()])
	if _fails.is_empty():
		print("TEST-PASS")
	else:
		print("TEST-FAIL")
		for f in _fails:
			print("  FAILED: " + f)


func _init() -> void:
	run_all()