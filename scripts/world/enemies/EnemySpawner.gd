extends Node
class_name EnemySpawner

## Spawns enemies at night when the game is in SURVIVAL mode, or in CREATIVE
## mode if the "Enable Enemy Spawning" setting is toggled on in the Creative Panel.
## Enemies spawn outside the player's view radius and despawn at dawn.
## 5 enemy types with varied weights based on player progression.

const SPAWN_INTERVAL: float = 6.0  # seconds between spawn waves (normal) — Harder mode
const SPAWN_INTERVAL_BLOOD_MOON: float = 3.0  # seconds between spawn waves during blood moon
const SPAWN_RADIUS_MIN: float = 200.0
const SPAWN_RADIUS_MAX: float = 350.0
const MAX_ENEMIES: int = 16
const MAX_ENEMIES_BLOOD_MOON: int = 24

var _spawn_timer: float = 0.0
var _is_night: bool = false
var _is_foggy: bool = false
var _player_ref: CharacterBody2D = null


## Picks the closest valid player node from the "player" group, or null.
## Anchored on the previous spawn focus (or the origin on the first call)
## so spawn waves keep serving the nearest active player.
func _find_nearest_player() -> CharacterBody2D:
	var anchor: Vector2 = Vector2.ZERO
	if is_instance_valid(_player_ref):
		anchor = _player_ref.global_position
	var best: CharacterBody2D = null
	var best_dist_sq: float = INF
	for p in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(p) or not (p is CharacterBody2D):
			continue
		var p_body := p as CharacterBody2D
		var d_sq: float = p_body.global_position.distance_squared_to(anchor)
		if d_sq < best_dist_sq:
			best_dist_sq = d_sq
			best = p_body
	return best
var _weather_system: WeatherSystem = null

# Multiplayer
var _next_enemy_id: int = 1


func _ready() -> void:
	add_to_group("enemy_spawner")
	GameManager.phase_changed.connect(_on_phase_changed)
	GameManager.game_mode_changed.connect(_on_game_mode_changed)
	_player_ref = _find_nearest_player()
	
	# Find the weather system
	_weather_system = get_tree().root.find_child("WeatherSystem", true, false)
	if not _weather_system:
		var gm := get_tree().root.find_child("GameManager", true, false)
		if gm and "weather_system" in gm:
			_weather_system = gm.weather_system as WeatherSystem
	if _weather_system:
		_weather_system.weather_changed.connect(_on_weather_updated)
		_is_foggy = _weather_system.is_foggy()


func _on_weather_updated(weather: WeatherSystem.WeatherType) -> void:
	var was_foggy: bool = _is_foggy
	_is_foggy = (weather == WeatherSystem.WeatherType.FOG)
	
	# When fog lifts, Caspers dissipate back into the mist
	if was_foggy and not _is_foggy:
		_despawn_all_caspers()


func _process(delta: float) -> void:
	# Multiplayer: only host spawns enemies
	if NetworkManager.is_network_active() and not multiplayer.is_server():
		return
	
	if GameManager.inside_interior:
		return
	# Allow spawning during foggy weather even in the daytime
	if not _is_night and not _is_foggy:
		return
	if not GameManager.is_survival() and not GameManager.creative_enemy_spawning:
		return
	if not _player_ref or not is_instance_valid(_player_ref):
		_player_ref = _find_nearest_player()
		return
	
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		# During blood moon, spawns happen much more frequently
		var is_blood_moon := GameManager.day_night and GameManager.day_night.blood_moon_active
		var interval_mult := GameManager.get_spawn_interval_mult()
		_spawn_timer = (SPAWN_INTERVAL_BLOOD_MOON if is_blood_moon else SPAWN_INTERVAL) * interval_mult
		_try_spawn_wave()


func _on_phase_changed(phase: int) -> void:
	_is_night = (phase == DayNightCycle.Phase.NIGHT)
	if _is_night:
		_spawn_timer = 2.0  # First spawn shortly after nightfall
	elif _is_foggy:
		# Keep Caspers alive during foggy days — the mist sustains them
		_spawn_timer = 2.0
	else:
		_despawn_all()


func _on_game_mode_changed(_mode: int) -> void:
	# If switched to peaceful mid-game, clear enemies
	# But keep them alive in creative if the enemy-spawning toggle is on
	if not GameManager.is_survival() and not GameManager.creative_enemy_spawning:
		_despawn_all()


func _try_spawn_wave() -> void:
	# In multiplayer, spawn around whichever player is closest so night
	# combat reaches every player, not just the host.
	_player_ref = _find_nearest_player()
	var is_blood_moon := GameManager.day_night and GameManager.day_night.blood_moon_active
	var max_enemy_mult := GameManager.get_max_enemy_mult()
	var max_enemies := roundi((MAX_ENEMIES_BLOOD_MOON if is_blood_moon else MAX_ENEMIES) * max_enemy_mult)
	
	var current_count := get_tree().get_nodes_in_group("enemies").size()
	if current_count >= max_enemies:
		return
	
	# Blood moon: 3-4 enemies per wave; normal: 1-2 (scaled by difficulty)
	var count := roundi(((randi() % 2 + 3) if is_blood_moon else (randi() % 2 + 1)) * max_enemy_mult)
	for i in range(count):
		if get_tree().get_nodes_in_group("enemies").size() >= max_enemies:
			return
		_spawn_enemy()


func _spawn_enemy() -> void:
	if not _player_ref:
		return
	
	# Pick a random position in a ring around the player, retrying up to 10
	# times to avoid spawning on water tiles.
	var world := get_tree().get_first_node_in_group("world")
	var spawn_pos: Vector2
	var found_land := false
	for attempt in 10:
		var angle := randf_range(0.0, TAU)
		var dist := randf_range(SPAWN_RADIUS_MIN, SPAWN_RADIUS_MAX)
		var pos := _player_ref.global_position + Vector2(cos(angle), sin(angle)) * dist
		if world and world.has_method("world_to_cell") and world.has_method("is_water_tile"):
			var cell: Vector2i = world.world_to_cell(pos)
			if world.is_water_tile(cell):
				continue  # try another spot
		spawn_pos = pos
		found_land = true
		break
	
	if not found_land:
		return  # give up, try next wave
	
	var enemy: Enemy
	
	# In foggy weather, only Caspers (GhostEnemy) emerge from the mist
	if _is_foggy:
		enemy = GhostEnemy.new()
	else:
		# Randomly pick enemy type from 5 varieties with weighted chances
		# Ghosts (30%), Sporelings (25%), Cinder Imps (20%), Shadow Hounds (15%), Frost Wisps (10%)
		var roll := randf()
		if roll < 0.30:
			enemy = GhostEnemy.new()
		elif roll < 0.55:
			enemy = SporelingEnemy.new()
		elif roll < 0.75:
			enemy = CinderImp.new()
		elif roll < 0.90:
			enemy = ShadowHound.new()
		else:
			enemy = FrostWisp.new()
	
	enemy.global_position = spawn_pos
	enemy.enemy_id = _next_enemy_id
	enemy.name = "Enemy_%d" % _next_enemy_id
	_next_enemy_id += 1
	
	add_child(enemy)
	# Apply difficulty scaling synchronously so the broadcast below sends the
	# already-scaled HP to clients (the _ready() deferred call no-ops via the
	# _stats_scaled guard).
	enemy.apply_difficulty_scaling()
	
	# Broadcast spawn to remote clients
	if NetworkManager.is_network_active() and multiplayer.is_server():
		var type_name: String = enemy.get_script().get_global_name()
		rpc("_receive_spawn_enemy", type_name, spawn_pos.x, spawn_pos.y,
			enemy.enemy_id, enemy.current_health, enemy.max_health)


## Spawn an enemy at a specific position for the pirate raid event.
func spawn_enemy_at(pos: Vector2, _type: String = "pirate") -> Enemy:
	if GameManager.inside_interior:
		return null
	var enemy := GhostEnemy.new()  # Use GhostEnemy as base for pirate raiders
	enemy.global_position = pos
	enemy.set_meta("is_pirate", true)
	enemy.enemy_id = _next_enemy_id
	enemy.name = "Enemy_%d" % _next_enemy_id
	_next_enemy_id += 1
	add_child(enemy)  # GhostEnemy._ready() fires here, sets ghost defaults (including display_name = "Casper")
	enemy.set_display_name("Pirate Raider")  # Must be set AFTER _ready() to override GhostEnemy's default
	# Immediately override GhostEnemy._ready() defaults with pirate stats
	enemy.max_health = 100
	enemy.current_health = 100
	enemy.speed = 70.0
	enemy.damage = 8
	enemy.add_to_group("enemies")
	enemy.apply_difficulty_scaling()
	
	# Override the ghost sprite with a distinct pirate raider sprite
	_apply_pirate_sprite(enemy)
	
	return enemy


## Host: spawn a creative-panel enemy (already instantiated by the panel) with
## full network sync — proper id/name so RPC routing matches on every peer, and
## a spawn broadcast so clients create a remote copy under the same node path.
func spawn_creative_enemy(enemy: Enemy, pos: Vector2) -> void:
	if GameManager.inside_interior:
		enemy.queue_free()
		return
	enemy.global_position = pos
	enemy.enemy_id = _next_enemy_id
	enemy.name = "Enemy_%d" % _next_enemy_id
	_next_enemy_id += 1
	add_child(enemy)
	if NetworkManager.is_network_active() and multiplayer.is_server():
		# Scale synchronously so the broadcast sends final HP (same as night spawns)
		enemy.apply_difficulty_scaling()
		var type_name: String = enemy.get_script().get_global_name()
		rpc("_receive_spawn_enemy", type_name, pos.x, pos.y,
			enemy.enemy_id, enemy.current_health, enemy.max_health)


## Host: spawn a creative-panel boss (instantiated from a .tscn by the panel)
## with full network sync. scene_path is the .tscn the client will re-instantiate.
func spawn_creative_boss(enemy: Enemy, scene_path: String, pos: Vector2) -> void:
	if GameManager.inside_interior:
		enemy.queue_free()
		return
	enemy.global_position = pos
	enemy.enemy_id = _next_enemy_id
	enemy.name = "Enemy_%d" % _next_enemy_id
	_next_enemy_id += 1
	add_child(enemy)
	if NetworkManager.is_network_active() and multiplayer.is_server():
		enemy.apply_difficulty_scaling()
		rpc("_receive_spawn_boss", scene_path, pos.x, pos.y,
			enemy.enemy_id, enemy.current_health, enemy.max_health)


## Client: request the host to spawn a creative-panel enemy at a position.
## The host broadcasts the spawn so every peer (including the requester) gets a copy.
@rpc("any_peer", "reliable")
func _server_request_creative_spawn_enemy(scene_path: String, pos_x: float, pos_y: float) -> void:
	if not NetworkManager.is_network_active() or not multiplayer.is_server():
		return
	var gdscript := load(scene_path) as GDScript
	if not gdscript:
		return
	var enemy: Enemy = gdscript.new()
	if not enemy:
		return
	spawn_creative_enemy(enemy, Vector2(pos_x, pos_y))


## Client: request the host to spawn a creative-panel boss at a position.
@rpc("any_peer", "reliable")
func _server_request_creative_spawn_boss(scene_path: String, pos_x: float, pos_y: float) -> void:
	if not NetworkManager.is_network_active() or not multiplayer.is_server():
		return
	var boss_scene := load(scene_path) as PackedScene
	if not boss_scene:
		return
	var enemy: Enemy = boss_scene.instantiate()
	if not enemy:
		return
	spawn_creative_boss(enemy, scene_path, Vector2(pos_x, pos_y))


## Client: create a remote copy of a creative-panel boss spawn.
@rpc("authority", "reliable")
func _receive_spawn_boss(scene_path: String, pos_x: float, pos_y: float, eid: int, hp: int, max_hp: int) -> void:
	if multiplayer.is_server():
		return
	var boss_scene := load(scene_path) as PackedScene
	if not boss_scene:
		return
	var enemy: Enemy = boss_scene.instantiate()
	enemy.enemy_id = eid
	enemy.name = "Enemy_%d" % eid
	enemy._is_remote = true
	enemy.global_position = Vector2(pos_x, pos_y)
	add_child(enemy)
	enemy.max_health = max_hp
	enemy.current_health = hp
	enemy._update_health_bar()


## Replace the ghost sprite on a pirate raider enemy with the pirate raider sprite
## and remove the ghostly glow (PointLight2D) so pirates look like human raiders.
func _apply_pirate_sprite(enemy: GhostEnemy) -> void:
	if not is_instance_valid(enemy) or not enemy.sprite:
		return
	# Load the pirate raider sprite texture
	var pirate_tex := load("res://assets/generated/pirate_raider_large_frame_0.png")
	if pirate_tex:
		enemy.sprite.texture = pirate_tex
	# Scale to match the player's visual size (player: 48x48 @ 0.5 = 24x24, pirate: 32x32 @ 0.75 = 24x24)
	enemy.sprite.scale = Vector2(0.75, 0.75)
	# Opaque, solid colors — no translucent ghost look
	enemy.sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	# Remove the ghostly PointLight2D (first child added after Sprite2D and CollisionShape2D)
	for child in enemy.get_children():
		if child is PointLight2D:
			child.queue_free()
			break
	# Pirates collide with terrain like normal enemies (not phase-through like ghosts)
	enemy.collision_mask = 3  # collide with world (layer 1) AND player (layer 2)


func _despawn_all() -> void:
	# Multiplayer: only host manages despawning
	if NetworkManager.is_network_active() and not multiplayer.is_server():
		return
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy and is_instance_valid(enemy):
			# Don't despawn bosses or pirates — they persist until killed
			if enemy.is_in_group("bosses") or enemy.has_meta("is_pirate"):
				continue
			# During fog, keep Caspers alive (fog transition handles them separately)
			if _is_foggy and enemy is GhostEnemy:
				continue
			_notify_despawn(enemy)
			enemy.queue_free()


## Despawns only GhostEnemy (Casper) enemies — called when fog lifts.
func _despawn_all_caspers() -> void:
	# Multiplayer: only host manages despawning
	if NetworkManager.is_network_active() and not multiplayer.is_server():
		return
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy and is_instance_valid(enemy) and enemy is GhostEnemy:
			if enemy.has_meta("is_pirate"):
				continue
			_notify_despawn(enemy)
			enemy.queue_free()


## Client: receive a spawn broadcast from the host and create a remote copy.
@rpc("authority", "reliable")
func _receive_spawn_enemy(type_name: String, pos_x: float, pos_y: float, eid: int, hp: int, max_hp: int) -> void:
	if multiplayer.is_server():
		return
	var enemy: Enemy
	match type_name:
		"GhostEnemy":
			enemy = GhostEnemy.new()
		"SporelingEnemy":
			enemy = SporelingEnemy.new()
		"CinderImp":
			enemy = CinderImp.new()
		"ShadowHound":
			enemy = ShadowHound.new()
		"FrostWisp":
			enemy = FrostWisp.new()
		_:
			return
	
	enemy.enemy_id = eid
	enemy.name = "Enemy_%d" % eid
	enemy._is_remote = true
	enemy.global_position = Vector2(pos_x, pos_y)
	add_child(enemy)
	enemy.current_health = hp
	enemy.max_health = max_hp
	enemy._update_health_bar()


## Host: broadcast a pirate raider spawn so clients create a matching remote copy.
func broadcast_pirate_spawn(enemy: Enemy) -> void:
	if NetworkManager.is_network_active() and multiplayer.is_server() and enemy.enemy_id > 0:
		rpc("_receive_spawn_pirate", enemy.global_position.x, enemy.global_position.y,
			enemy.enemy_id, enemy.current_health, enemy.max_health)


## Host: broadcast a sporeling minion spawn so clients create a matching remote copy.
func broadcast_sporeling_spawn(pos_x: float, pos_y: float) -> void:
	if NetworkManager.is_network_active() and multiplayer.is_server():
		var eid: int = _next_enemy_id
		_next_enemy_id += 1
		rpc("_receive_spawn_sporeling", pos_x, pos_y, eid, 25, 25)  # Sporeling base HP = 25


## Client: create a remote sporeling minion copy.
@rpc("authority", "reliable")
func _receive_spawn_sporeling(pos_x: float, pos_y: float, eid: int, hp: int, max_hp: int) -> void:
	if multiplayer.is_server():
		return
	var enemy := SporelingEnemy.new()
	enemy.global_position = Vector2(pos_x, pos_y)
	enemy.enemy_id = eid
	enemy.name = "Enemy_%d" % eid
	enemy._is_remote = true
	add_child(enemy)
	enemy.max_health = max_hp
	enemy.current_health = hp
	enemy._update_health_bar()


## Client: create a remote pirate raider copy (pirate visuals + stats).
@rpc("authority", "reliable")
func _receive_spawn_pirate(pos_x: float, pos_y: float, eid: int, hp: int, max_hp: int) -> void:
	if multiplayer.is_server():
		return
	var enemy := GhostEnemy.new()
	enemy.global_position = Vector2(pos_x, pos_y)
	enemy.set_meta("is_pirate", true)
	enemy.enemy_id = eid
	enemy.name = "Enemy_%d" % eid
	enemy._is_remote = true
	add_child(enemy)
	enemy.set_display_name("Pirate Raider")
	enemy.max_health = max_hp
	enemy.current_health = hp
	enemy.speed = 70.0
	enemy.damage = 8
	_apply_pirate_sprite(enemy)
	enemy._update_health_bar()


## Host: tell clients to remove a remote copy during despawn events.
func _notify_despawn(enemy: Node2D) -> void:
	if enemy is Enemy and NetworkManager.is_network_active() and multiplayer.is_server() and enemy.enemy_id > 0:
		rpc("_receive_despawn_enemy", enemy.enemy_id)


## Client: remove a remote copy that the host has despawned.
@rpc("authority", "reliable")
func _receive_despawn_enemy(eid: int) -> void:
	if multiplayer.is_server():
		return
	var enemy := get_node_or_null("Enemy_%d" % eid) as Enemy
	if enemy:
		enemy.queue_free()


# ── Late-joiner enemy-state sync ──────────────────────────────────────────

## Join-time pull: a freshly connected client asks the host for every enemy
## currently alive (night mobs, raid pirates, sporeling minions, bosses) so it
## can spawn matching remote copies. Spawn broadcasts that happened before the
## client was ready never reach it, leaving it blind to (but lootable by) mobs.
@rpc("any_peer", "reliable")
func _server_request_enemy_state() -> void:
	if not multiplayer.is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = multiplayer.get_unique_id()
	var entries: Array = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is Enemy and is_instance_valid(enemy):
			entries.append({
				"s": enemy.get_script().get_global_name(),
				"x": enemy.global_position.x,
				"y": enemy.global_position.y,
				"i": enemy.enemy_id,
				"hp": enemy.current_health,
				"mx": enemy.max_health,
				"p": enemy.scene_file_path,
				"pir": enemy.has_meta("is_pirate"),
			})
	rpc_id(sender, "_receive_enemy_state_snapshot", entries)


## Client: receive the host's alive-enemy snapshot and recreate each remote
## copy through the same per-type helpers the live spawn broadcasts use, so
## ids, node names and RPC routing match on every peer.
@rpc("authority", "reliable")
func _receive_enemy_state_snapshot(entries: Array) -> void:
	if multiplayer.is_server():
		return
	for entry in entries:
		var eid: int = int(entry.get("i", 0))
		if eid <= 0:
			continue
		if get_node_or_null("Enemy_%d" % eid):
			continue
		var pos := Vector2(float(entry.get("x", 0.0)), float(entry.get("y", 0.0)))
		var hp: int = int(entry.get("hp", 1))
		var mx: int = int(entry.get("mx", hp))
		if entry.get("pir", false):
			_receive_spawn_pirate(pos.x, pos.y, eid, hp, mx)
		elif String(entry.get("p", "")).length() > 0:
			_receive_spawn_boss(String(entry.get("p", "")), pos.x, pos.y, eid, hp, mx)
		else:
			_receive_spawn_enemy(String(entry.get("s", "")), pos.x, pos.y, eid, hp, mx)
