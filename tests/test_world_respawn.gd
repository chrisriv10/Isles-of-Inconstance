extends Node
## Verifies the timed world-object respawn system:
##  1) Removing a tree records a recipe + day_removed.
##  2) _process_respawns respawns it once the respawn days elapse.
##  3) A cell with a planted crop is NOT respawned onto.
## Uses a minimal World instance (autoloads are available in the test runner).

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


func test_respawn_records_and_elapses() -> void:
	print("-- test_respawn_records_and_elapses --")
	var world := Node2D.new()
	world.set_script(load("res://scripts/world/World.gd"))
	var objects_root := Node2D.new()
	objects_root.name = "ObjectsRoot"
	world.add_child(objects_root)
	world.objects_root = objects_root
	# Give the world a minimal tile grid so cell math works.
	world.world_width = 20
	world.world_height = 20
	var grid: Array = []
	for y in range(20):
		var row: Array = []
		for _x in range(20):
			row.append("grass")
		grid.append(row)
	world._tile_grid = grid

	# Attach a tree scene at cell (5, 5).
	var tree_scene: PackedScene = preload("res://scenes/objects/Tree.tscn")
	var tree := tree_scene.instantiate()
	tree.name = "Tree_test"
	tree.sprite_seed = 123
	objects_root.add_child(tree)
	tree.global_position = world.cell_to_world(Vector2i(5, 5))

	# Remove it via the same path a chopped tree uses.
	world.notify_cell_object_removed(tree.global_position)
	_check(world._removed_cell_objects.size() == 1,
		"removed tree is recorded in _removed_cell_objects")
	if world._removed_cell_objects.size() == 1:
		var entry: Dictionary = world._removed_cell_objects[Vector2i(5, 5)]
		_check(entry.get("day_removed", -1) == GameManager.current_day,
			"day_removed recorded")
		var recipe: Dictionary = entry.get("recipe", {})
		_check(str(recipe.get("type", "")) == "tree", "tree recipe captured")
		_check(int(recipe.get("sprite_seed", -1)) == 123, "tree sprite_seed captured")

	# Not yet enough days elapsed -> no respawn.
	GameManager.current_day += 1
	world._process_respawns()
	_check(world._removed_cell_objects.size() == 1,
		"tree NOT respawned before respawn days elapse")

	# Elapse past the respawn window -> respawn happens.
	GameManager.current_day += world.get_script().get_script_constant_map().get("WORLD_OBJECT_RESPAWN_DAYS", 3) + 1
	world._process_respawns()
	_check(world._removed_cell_objects.is_empty(),
		"tree respawned after respawn days elapse")
	var found := 0
	for child in objects_root.get_children():
		if world._is_removable_world_object(child):
			found += 1
	_check(found == 1, "a removable object is present again at the cell")

	world.queue_free()


func test_respawn_skips_crop_cell() -> void:
	print("-- test_respawn_skips_crop_cell --")
	var world := Node2D.new()
	world.set_script(load("res://scripts/world/World.gd"))
	var objects_root := Node2D.new()
	objects_root.name = "ObjectsRoot"
	world.add_child(objects_root)
	world.objects_root = objects_root
	world.world_width = 20
	world.world_height = 20
	var grid: Array = []
	for y in range(20):
		var row: Array = []
		for _x in range(20):
			row.append("grass")
		grid.append(row)
	world._tile_grid = grid

	# Place a removable object at (3, 3) and remove it.
	var bush_scene: PackedScene = preload("res://scenes/objects/Bush.tscn")
	var bush := bush_scene.instantiate()
	bush.name = "Bush_test"
	objects_root.add_child(bush)
	bush.global_position = world.cell_to_world(Vector2i(3, 3))
	world.notify_cell_object_removed(bush.global_position)
	_check(world._removed_cell_objects.size() == 1, "bush removed and recorded")

	# Simulate a crop planted on that same cell.
	world._crop_nodes[Vector2i(3, 3)] = Node.new()

	# Elapse past respawn window.
	GameManager.current_day += world.get_script().get_script_constant_map().get("WORLD_OBJECT_RESPAWN_DAYS", 3) + 1
	world._process_respawns()
	_check(not world._removed_cell_objects.is_empty(),
		"object NOT respawned onto a crop cell (stays removed, retries later)")

	world.queue_free()


func run_all() -> void:
	test_respawn_records_and_elapses()
	test_respawn_skips_crop_cell()
	print("== RESULT: %d passed, %d failed ==" % [_passes.size(), _fails.size()])
	if _fails.is_empty():
		print("TEST-PASS")
	else:
		print("TEST-FAIL")
		for f in _fails:
			print("  FAILED: " + f)


func _init() -> void:
	run_all()