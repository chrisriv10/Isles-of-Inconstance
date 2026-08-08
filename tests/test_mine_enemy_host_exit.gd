extends Node
## Reproduces "enemies stand still after the host leaves the mine while a client
## is still inside". The mine enemy AI is host-authoritative: it targets the
## nearest standing player inside its room. When the host player exits, the enemy
## must retarget to the remaining client player whose remote copy is still inside
## the room. If it fails to find that copy, it walks back to spawn and idles —
## which Player 2 sees as "enemies standing still".

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


func _make_player(name: String, pos: Vector2, authority: int) -> Node2D:
	var p := CharacterBody2D.new()
	p.name = name
	p.position = pos
	p.set_multiplayer_authority(authority)
	p.add_to_group("player")
	add_child(p)
	return p


func test_retargets_to_remaining_client_after_host_leaves() -> void:
	print("-- test_retargets_to_remaining_client_after_host_leaves --")
	var room := MineRoom.new()
	room.name = "MineRoom"
	room.position = Vector2(1000, 1000)  # simulate MINE_VOID-ish origin
	add_child(room)
	# Room needs a generator for _player_in_my_room bounds. Build a minimal
	# fake generator object with the fields the enemy reads.
	var gen := {&"grid_width": 64, &"grid_height": 48}
	room.set("generator", gen)

	var enemy := CaveCrawler.new()
	enemy.enemy_id = 0
	enemy.name = "MineEnemy_0"
	enemy._is_remote = false  # AI runs on this peer
	room.add_child(enemy)
	enemy.position = Vector2(1100, 1100)

	var host_player := _make_player("HostPlayer", Vector2(1150, 1100), 1)
	var client_player := _make_player("ClientPlayer", Vector2(1200, 1100), 2)

	# Let the enemy find the host player first.
	for i in range(5):
		enemy._physics_process(0.016)
	_check(is_instance_valid(enemy._player_ref) and enemy._player_ref == host_player \
		or enemy._player_ref == client_player, "enemy acquired a target")

	# Host leaves the mine: host player is moved out of the room bounds.
	host_player.global_position = Vector2(50, 50)

	# Over a few frames the enemy should re-target the client player still inside.
	var retargeted := false
	for i in range(10):
		enemy._physics_process(0.016)
		if is_instance_valid(enemy._player_ref) and enemy._player_ref == client_player:
			retargeted = true
			break
	_check(retargeted, "enemy retargeted to the client player still inside the room")

	# Cleanup to avoid leaks.
	host_player.queue_free()
	client_player.queue_free()
	room.queue_free()


func run_all() -> void:
	test_retargets_to_remaining_client_after_host_leaves()
	print("== RESULT: %d passed, %d failed ==" % [_passes.size(), _fails.size()])
	if _fails.is_empty():
		print("TEST-PASS")
	else:
		print("TEST-FAIL")
		for f in _fails:
			print("  FAILED: " + f)


func _init() -> void:
	run_all()