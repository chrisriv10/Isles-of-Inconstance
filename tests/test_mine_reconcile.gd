extends Node
## Unit test for MineRoom.reconcile_enemies_from_host — validates that a late
## joiner's mine-enemy set matches the host's snapshot:
##   - shared enemies get HP/position updated
##   - host-only (respawned) enemies are created client-side
##   - client-only (host-dead) enemies are removed

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


func _enemy_count(room: Node) -> int:
	var n := 0
	for c in room.get_children():
		if c is CaveCrawler or c is StoneGolem or c is CaveBat:
			if is_instance_valid(c):
				n += 1
	return n


func test_reconcile_creates_host_only_enemies() -> void:
	print("-- test_reconcile_creates_host_only_enemies --")
	var room := MineRoom.new()
	room.name = "MineRoom"
	var crawler := CaveCrawler.new() as Node2D
	crawler.enemy_id = 0
	crawler.name = "MineEnemy_0"
	crawler.current_health = 100
	crawler.max_health = 100
	room.add_child(crawler)
	# Host snapshot: crawler id 0 (wounded) + a respawned golem id 7 the client lacks.
	var snapshot := [
		{"d": 0, "t": MineRoom.MINE_ENEMY_CRAWLER, "p": Vector2(150, 200), "h": 40, "m": 100},
		{"d": 7, "t": MineRoom.MINE_ENEMY_GOLEM, "p": Vector2(300, 400), "h": 80, "m": 120},
	]
	room.reconcile_enemies_from_host(snapshot)
	_check(room.get_node_or_null("MineEnemy_7") != null, "respawned enemy id 7 created")
	_check(room.get_node_or_null("MineEnemy_7") is StoneGolem, "created enemy is a StoneGolem (type honored)")
	_check(room.get_node_or_null("MineEnemy_7").position == Vector2(300, 400), "created enemy placed at host position")
	_check(room.get_node_or_null("MineEnemy_7").current_health == 80, "created enemy HP synced")
	_check(room.get_node_or_null("MineEnemy_0").current_health == 40, "shared enemy HP updated to host value")
	_check(room.get_node_or_null("MineEnemy_0").position == Vector2(150, 200), "shared enemy repositioned to host")
	_check(_enemy_count(room) == 2, "room holds exactly the 2 host enemies")


func test_reconcile_removes_host_dead_enemies() -> void:
	print("-- test_reconcile_removes_host_dead_enemies --")
	var room := MineRoom.new()
	room.name = "MineRoom"
	var a := CaveCrawler.new() as Node2D
	a.enemy_id = 0
	a.name = "MineEnemy_0"
	room.add_child(a)
	var b := CaveBat.new() as Node2D
	b.enemy_id = 1
	b.name = "MineEnemy_1"
	room.add_child(b)
	# Host only lists id 1 (id 0 died host-side).
	var snapshot := [{"d": 1, "t": MineRoom.MINE_ENEMY_BAT, "p": Vector2(10, 20), "h": 50, "m": 50}]
	room.reconcile_enemies_from_host(snapshot)
	_check(room.get_node_or_null("MineEnemy_0") != null, "host-dead enemy 0 is queued for removal (still present until freed)")
	_check(room.get_node_or_null("MineEnemy_1") != null, "surviving enemy 1 kept")


func test_reconcile_empty_noop() -> void:
	print("-- test_reconcile_empty_noop --")
	var room := MineRoom.new()
	var a := CaveCrawler.new() as Node2D
	a.enemy_id = 0
	a.name = "MineEnemy_0"
	room.add_child(a)
	room.reconcile_enemies_from_host([])
	_check(room.get_node_or_null("MineEnemy_0") != null, "empty snapshot is a no-op (no removal)")


func run_all() -> void:
	test_reconcile_creates_host_only_enemies()
	test_reconcile_removes_host_dead_enemies()
	test_reconcile_empty_noop()
	print("== RESULT: %d passed, %d failed ==" % [_passes.size(), _fails.size()])
	if _fails.is_empty():
		print("TEST-PASS")
	else:
		print("TEST-FAIL")
		for f in _fails:
			print("  FAILED: " + f)


func _init() -> void:
	run_all()