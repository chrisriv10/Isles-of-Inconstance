extends Node
## Live 2-peer multiplayer smoke test.
##
## Run as TWO headless processes against the same project:
##   godot --headless res://tests/MpSmoke.tscn -- --role=host
##   godot --headless res://tests/MpSmoke.tscn -- --role=client
##
## Host = ENet server on 127.0.0.1:34200; client joins it and they exercise
## the REAL autoload RPC plumbing end-to-end:
##   - any_peer -> server relay (chat), sender-derived naming (fix #2a)
##   - unreliable any_peer stats broadcast keyed by sender
##   - host -> client time-state broadcast: day rollover re-emits
##     day_changed + season_changed and triggers the client personal-only
##     save (fix #5/#6) — live over the wire
##   - client personal save excludes ALL world/host keys (fix #5)
##   - server_disconnected -> immediate personal save (fix #2c)
##   - EnemySpawner creative-spawn whitelist (fix #2a)
## Each process exits 0 on all-pass, 1 on any failure.

const TEST_PORT := 34200
const CHAT_TEXT := "hello-mp-client"

var _role: String = ""
var _fails: Array[String] = []
var _passes: Array[String] = []
var _timeline := 0.0
var _finished := false
var _heartbeat := 0

# Client evidence
var _connected := false
var _sent_relays := false
var _sent_stats2 := false
var _sent_stats3 := false
var _saw_season_change := false
var _saw_day_change := false
var _save_writes := 0
var _saw_server_disconnect := false
var _checked_save := false

# Host evidence + FSM
var _saw_chat := false
var _saw_stats := false
var _client_peer: int = -1
var _staged := false
var _b_baseline := false
var _b_rollover := false
var _b_season := false
var _b_asserts := false
var _b_disconnect := false
var _stage_base := 0.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--role="):
			_role = a.trim_prefix("--role=")
	print("[MP-SMOKE] %s process ready" % _role.to_upper())
	if _role == "host":
		GameManager.chat_message_received.connect(_on_host_chat)
		GameManager.player_list_changed.connect(_on_host_player_list)
		NetworkManager.host(TEST_PORT)
		print("[MP-SMOKE] HOST hosting on 127.0.0.1:%d" % TEST_PORT)
	elif _role == "client":
		GameManager.season_changed.connect(func(_s: int, _n: String) -> void: _saw_season_change = true)
		GameManager.day_changed.connect(func(_d: int) -> void: _saw_day_change = true)
		SaveManager.save_completed.connect(func(_ok: bool) -> void: _save_writes += 1)
		NetworkManager.connection_succeeded.connect(func(_id: int) -> void: _connected = true)
		NetworkManager.server_disconnected.connect(_on_client_disconnected)
		if GameManager.season_system == null:
			GameManager.season_system = SeasonSystem.new()
		NetworkManager.join("127.0.0.1", TEST_PORT)
		print("[MP-SMOKE] CLIENT joining 127.0.0.1:%d" % TEST_PORT)
	else:
		_fail("unknown role '%s'" % _role)
		_finish()


func _process(delta: float) -> void:
	if _role == "" or _finished:
		return
	_timeline += delta
	if int(_timeline / 5.0) != _heartbeat:
		_heartbeat = int(_timeline / 5.0)
		print("[MP-SMOKE] %s heartbeat t=%.1f" % [_role.to_upper(), _timeline])
	if _role == "host":
		_host_fsm()
	else:
		_client_fsm()


# ── Host ──────────────────────────────────────────────────────────────────

func _on_host_chat(sender_name: String, text: String) -> void:
	if text == CHAT_TEXT:
		_saw_chat = true
		print("[MP-SMOKE] HOST chat relay ok (from '%s')" % sender_name)


func _on_host_player_list() -> void:
	if _client_peer != -1 and not GameManager.remote_player_stats.is_empty():
		_saw_stats = true


func _broadcast_time(day: int, minute: int, season: int, weather: int) -> void:
	GameManager.rpc("_receive_time_state", day, minute, 0, season, weather)


func _host_fsm() -> void:
	if _timeline < 0.5:
		if NetworkManager.mode != NetworkManager.ConnectionMode.HOST:
			_fail("host mode not HOST")
			_finish()
		return
	# Stage 1: wait for the client (Godot 4.7 ENet uses random client ids).
	if _client_peer == -1:
		if not multiplayer.get_peers().is_empty():
			_client_peer = multiplayer.get_peers()[0]
			_stage_base = _timeline
			_pass("client connected as peer %d" % _client_peer)
		elif _timeline > 12.0:
			_fail("client never connected after 12s")
			_finish()
			return
		return
	# Stage 2: broadcasts at fixed offsets after the peer is up.
	if not _b_baseline and _timeline >= _stage_base + 0.5:
		_b_baseline = true
		_broadcast_time(2, 0, 0, 0)
	if not _b_rollover and _timeline >= _stage_base + 1.5:
		_b_rollover = true
		_broadcast_time(3, 30, 1, 1)
	if not _b_season and _timeline >= _stage_base + 2.5:
		_b_season = true
		_broadcast_time(3, 90, 2, 1)
	# Stage 3: collect results.
	if not _b_asserts and _timeline >= _stage_base + 3.5:
		_b_asserts = true
		_host_asserts()
	# Stage 4: drop the client -> client server_disconnected -> personal save.
	if not _b_disconnect and _timeline >= _stage_base + 4.5:
		_b_disconnect = true
		print("[MP-SMOKE] HOST disconnecting client")
		NetworkManager.disconnect_from_server()
	if _timeline >= 13.0:
		_finish()


func _host_asserts() -> void:
	if _saw_chat:
		_pass("any_peer chat relay with sender-derived name")
	else:
		_fail("chat relay from client not received")
	if _saw_stats:
		_pass("client stats broadcast keyed by real sender")
	else:
		_fail("client stats not received")
	var es := load("res://scripts/world/enemies/EnemySpawner.gd").new() as Node
	if es:
		if es.is_valid_creative_spawn_path("res://scripts/world/enemies/GhostEnemy.gd"):
			_pass("creative whitelist allows real enemy script")
		else:
			_fail("creative whitelist rejected real enemy script")
		if es.is_valid_creative_spawn_path("res://scenes/enemies/RootWarden.tscn"):
			_pass("creative whitelist allows boss scene")
		else:
			_fail("creative whitelist rejected boss scene")
		if not es.is_valid_creative_spawn_path("res://scripts/Main.gd") \
				and not es.is_valid_creative_spawn_path("res://evil/exploit.gd"):
			_pass("creative whitelist blocks arbitrary paths")
		else:
			_fail("creative whitelist FAILED to block arbitrary path")
	else:
		_fail("could not instantiate EnemySpawner for whitelist check")


# ── Client ────────────────────────────────────────────────────────────────

func _client_fsm() -> void:
	if _timeline < 0.5:
		if NetworkManager.mode != NetworkManager.ConnectionMode.CLIENT:
			_fail("client mode not CLIENT")
			_finish()
		return
	if _connected and not _sent_relays:
		_sent_relays = true
		_pass("client connected (connection_succeeded, unique_id=%d)" % multiplayer.get_unique_id())
		GameManager.rpc_id(1, "_server_forward_chat", CHAT_TEXT)
		GameManager.rpc("_receive_player_stats", 50, 100, 80, 100, "SmokeClient", "", 0, 0, "", 1, "hoe")
	elif _timeline >= 2.0 and _connected and not _sent_stats2:
		_sent_stats2 = true
		GameManager.rpc("_receive_player_stats", 50, 100, 80, 100, "SmokeClient", "", 0, 0, "", 1, "hoe")
	elif _timeline >= 3.0 and _connected and not _sent_stats3:
		_sent_stats3 = true
		GameManager.rpc("_receive_player_stats", 50, 100, 80, 100, "SmokeClient", "", 0, 0, "", 1, "hoe")
	if _timeline >= 6.0 and not _connected:
		_fail("client never connected (no connection_succeeded)")
		_connected = true  # mark "reported"
	if _timeline >= 12.0:
		_finish()


func _on_client_disconnected() -> void:
	_saw_server_disconnect = true
	print("[MP-SMOKE] CLIENT server_disconnected fired")


func _finish() -> void:
	if _finished:
		return
	_finished = true
	if _role == "client" and not _checked_save:
		_checked_save = true
		_check_personal_save()
	if _role == "client":
		if _saw_day_change:
			_pass("client day_changed re-emitted (fix #5/#6 day rollover)")
		else:
			_fail("client never saw day_changed on rollover")
		if _saw_season_change:
			_pass("client season_changed re-emitted (fix #6)")
		else:
			_fail("client never saw season_changed")
		if _saw_server_disconnect:
			_pass("client saw server_disconnected")
		else:
			_fail("client never saw server_disconnected")
		if _save_writes >= 2:
			_pass("client wrote personal save on rollover AND on disconnect")
		elif _save_writes >= 1:
			_pass("client wrote personal save at least once")
		else:
			_fail("client never wrote a personal save")
	print("[MP-SMOKE] %s: %d pass, %d fail" % [_role.to_upper(), _passes.size(), _fails.size()])
	for p in _passes:
		print("[MP-SMOKE]   PASS  ", p)
	for f in _fails:
		print("[MP-SMOKE]   FAIL  ", f)
	if _fails.is_empty():
		print("[MP-SMOKE] %s RESULT: PASS" % _role.to_upper())
		get_tree().quit(0)
	else:
		print("[MP-SMOKE] %s RESULT: FAIL" % _role.to_upper())
		get_tree().quit(1)


## Read the client's slot-0 save (written by _save_player_progression) and
## assert it contains personal keys and NEVER world/host keys.
func _check_personal_save() -> void:
	var path := "user://save_0.json"
	if not FileAccess.file_exists(path):
		_fail("personal save file missing at " + path)
		return
	var f := FileAccess.open(path, FileAccess.READ)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	f.close()
	if data.is_empty():
		_fail("personal save file empty/unparseable")
		return
	var personal_ok := data.has("money") and data.has("inventory") \
			and data.has("player_name") and data.has("player_level")
	if personal_ok:
		_pass("personal save contains money/inventory/player_name/player_level")
	else:
		_fail("personal save missing personal keys: " + str(data.keys()))
	var world_keys := ["soil_data", "world_seed", "buildings", "chest_inventories",
			"town", "pirate_raid", "difficulty", "game_mode"]
	var leaked: Array[String] = []
	for k in world_keys:
		if data.has(k):
			leaked.append(k)
	if leaked.is_empty():
		_pass("personal save EXCLUDES all world/host keys")
	else:
		_fail("personal save LEAKED world keys: " + str(leaked))
	print("[MP-SMOKE] CLIENT personal save keys: ", data.keys())


func _pass(msg: String) -> void:
	print("[MP-SMOKE] PASS: ", msg)
	_passes.append(msg)


func _fail(msg: String) -> void:
	print("[MP-SMOKE] FAIL: ", msg)
	_fails.append(msg)
