extends CharacterBody2D
class_name StoneGolem

## Larger stone golem creature found in deeper mine levels (depth 2+).
## Slow but tough, deals heavy damage. Has a ground slam attack area-of-effect.
##
## Same pattern as CaveCrawler — CharacterBody2D, "enemies" group,
## direct combat without abstract base classes.

## Health points
var max_health: int = 35
var current_health: int = 35

## Movement speed (pixels/sec)
var speed: float = 25.0

## Damage dealt to player on contact
var damage: int = 14

## Attack cooldown (seconds) — golems are slow attackers
var attack_cooldown: float = 2.0

## Chase/aggro range
var chase_range: float = 180.0

## Attack range
var attack_range: float = 22.0

## Ground slam range (AOE around the golem)
var slam_range: float = 40.0

## Chance to use ground slam instead of bite on each attack
var slam_chance: float = 0.3

## XP granted on kill
var experience_value: int = 15

var _attack_timer: float = 0.0
var _player_ref: Node2D = null
# Where this enemy first spawned — the point it walks back to when there is
# no standing player left to fight (mirrors overworld Enemy.gd).
var _spawn_position: Vector2 = Vector2.ZERO
var _hp_mult: float = 1.0

# Multiplayer sync (host-authoritative, same pattern as overworld Enemy.gd —
# every peer generates the same deterministic mine room, so each has a local
# copy; the host owns health/damage/death and broadcasts, clients are mirrors).
var enemy_id: int = -1
var _is_remote: bool = false
var _sync_timer: float = 0.0
const SYNC_INTERVAL: float = 0.15

# Health bar nodes
var _health_bar_bg: ColorRect = null
var _health_bar_fill: ColorRect = null
var _name_label: Label = null

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("enemies")
	_spawn_position = global_position
	current_health = max_health
	_ensure_health_bar()
	_update_health_bar()
	# Find the nearest player (remote copies included, same as overworld Enemy.gd)
	_player_ref = _find_nearest_player()


func set_hp_multiplier(mult: float) -> void:
	_hp_mult = mult
	max_health = roundi(max_health * _hp_mult)
	current_health = max_health


## Picks the closest standing (not-downed) player node from the "player"
## group, or null. In multiplayer every peer has its own local player plus
## remote copies, so the enemy targets the nearest LIVING player and skips
## downed ones (they're waiting for a revive, not fighting).
##
## Mine enemies only fight players who are actually INSIDE this peer's mine
## room. This matters in multiplayer when the host stays on the surface while
## a client explores the mine: without the room filter the host's enemy would
## lock onto the host's own far-away player (outside chase_range) and just
## idle forever, so the client's copy never moves. Restricting to in-room
## players makes the enemy watch the room and immediately chase the client's
## remote copy once it is inside (fixes "enemies appear but do not move").
func _find_nearest_player() -> Node2D:
	var best: Node2D = null
	var best_dist_sq: float = INF
	for p in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(p) or not (p is Node2D):
			continue
		if "_is_downed" in p and p._is_downed:
			continue
		var p_node: Node2D = p as Node2D
		if not _player_in_my_room(p_node):
			continue
		var d_sq: float = global_position.distance_squared_to(p_node.global_position)
		if d_sq < best_dist_sq:
			best_dist_sq = d_sq
			best = p_node
	return best


## True when `player` is inside this enemy's mine room (the parent MineRoom).
## A mine is a self-contained cave placed at a void coordinate; anyone outside
## it (overworld, other interiors, the host sitting at home) is not a valid
## target for this room's enemies.
func _player_in_my_room(player: Node2D) -> bool:
	var room := get_parent()
	if not room:
		return true  # Unknown room — fall back to old closest-player behavior.
	var gen: RefCounted = room.get("generator") as RefCounted
	if gen == null:
		return true
	var w: int = gen.get("grid_width") if "grid_width" in gen else 64
	var h: int = gen.get("grid_height") if "grid_height" in gen else 48
	var origin: Vector2 = room.global_position
	var pw: float = w * 16.0
	var ph: float = h * 16.0
	return player.global_position.x >= origin.x and player.global_position.x <= origin.x + pw \
		and player.global_position.y >= origin.y and player.global_position.y <= origin.y + ph


## Re-picks the nearest player each frame with hysteresis so the enemy does
## not oscillate between two players who are roughly equidistant.
func _refresh_target_player() -> void:
	var nearest: Node2D = _find_nearest_player()
	if not is_instance_valid(_player_ref):
		_player_ref = nearest
		return
	if nearest == null:
		# Everyone is downed — drop the target so we don't camp a downed player.
		if "_is_downed" in _player_ref and _player_ref._is_downed:
			_player_ref = null
		return
	# Current target went down — immediately re-target a standing player.
	if "_is_downed" in _player_ref and _player_ref._is_downed:
		_player_ref = nearest
		return
	# Current target is no longer inside this room (e.g. a remote copy that
	# left, or a stale target) — drop it for a valid in-room player so the
	# enemy doesn't stay frozen chasing a phantom out-of-room copy.
	if not _player_in_my_room(_player_ref):
		if nearest:
			_player_ref = nearest
		return
	var current_dist: float = global_position.distance_to(_player_ref.global_position)
	var nearest_dist: float = global_position.distance_to(nearest.global_position)
	if current_dist - nearest_dist > 40.0:
		_player_ref = nearest


## Called by the host when a client enters the mine: point this enemy at that
## client's remote player RNOW so it starts chasing immediately instead of
## waiting for the client's position to sync within chase_range (which made
## remote copies look frozen for the first second or two).
func retarget_to_player(player: Node2D) -> void:
	if _is_remote:
		return
	if is_instance_valid(player):
		_player_ref = player


func _ensure_health_bar() -> void:
	if _health_bar_bg != null:
		return
	var bar_w := 18.0
	var bar_h := 4.0
	
	var bg := ColorRect.new()
	bg.name = "HealthBarBG"
	bg.size = Vector2(bar_w, bar_h)
	bg.position = Vector2(-bar_w / 2.0, -24)
	bg.color = Color(0.1, 0.1, 0.1, 0.6)
	add_child(bg)
	_health_bar_bg = bg

	var fill := ColorRect.new()
	fill.name = "HealthBarFill"
	fill.size = Vector2(bar_w, bar_h)
	fill.position = Vector2(-bar_w / 2.0, -24)
	fill.color = Color(0.9, 0.15, 0.15, 0.85)
	add_child(fill)
	_health_bar_fill = fill

	# Name label
	var label := Label.new()
	label.name = "EnemyNameLabel"
	label.text = "Stone Golem"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	label.position = Vector2(-50, -36)
	label.size = Vector2(100, 14)
	add_child(label)
	_name_label = label


func _update_health_bar() -> void:
	_ensure_health_bar()
	var ratio := float(current_health) / float(max_health)
	_health_bar_fill.size.x = ratio * 18.0
	if ratio > 0.5:
		_health_bar_fill.color = Color(0.9, 0.15, 0.15, 0.85)
	else:
		_health_bar_fill.color = Color(0.6, 0.05, 0.05, 0.85)


func _physics_process(delta: float) -> void:
	if current_health <= 0:
		return
	if not is_inside_tree():
		return
	if NetworkManager.is_network_active() and _is_remote:
		return
	
	_attack_timer -= delta
	
	# Try to find player if we lost reference
	if not _player_ref or not is_instance_valid(_player_ref):
		_player_ref = _find_nearest_player()
		if not _player_ref or not is_instance_valid(_player_ref):
			_back_to_spawn(delta)
			return

	_refresh_target_player()
	if not is_instance_valid(_player_ref):
		_back_to_spawn(delta)
		return
	
	var dist := global_position.distance_to(_player_ref.global_position)
	
	if dist <= attack_range:
		velocity = Vector2.ZERO
		if _attack_timer <= 0.0:
			_attack_timer = attack_cooldown
			if randf() < slam_chance:
				_ground_slam()
			else:
				_melee_attack()
			# Push back so the enemy doesn't sit on the player
			var push_dir := (global_position - _player_ref.global_position).normalized()
			if push_dir != Vector2.ZERO:
				global_position += push_dir * 8.0
	elif dist <= chase_range:
		# Chase — stop slightly before reaching the player to avoid overlap
		var stop_dist := attack_range * 0.85
		if dist <= stop_dist:
			velocity = Vector2.ZERO
		else:
			var dir := (_player_ref.global_position - global_position).normalized()
			velocity = dir * speed
	else:
		velocity = Vector2.ZERO
	
	move_and_slide()
	
	if velocity.x < -1.0:
		sprite.flip_h = true
	elif velocity.x > 1.0:
		sprite.flip_h = false

	# Host: periodically broadcast position/health to remote peers
	if NetworkManager.is_network_active() and multiplayer.is_server():
		_sync_timer += delta
		if _sync_timer >= SYNC_INTERVAL:
			_sync_timer = 0.0
			for pid in _mine_sync_peers():
				rpc_id(pid, "_sync_mine_enemy_state", enemy_id, global_position, current_health)


func _melee_attack() -> void:
	_damage_target(damage)
	EffectSpawner.spawn_dirt_puff(global_position)
	AudioManager.play(AudioManager.Sound.HIT)


func _ground_slam() -> void:
	# Screen shake and aoe damage
	if _player_ref and is_instance_valid(_player_ref):
		var dist := global_position.distance_to(_player_ref.global_position)
		if dist <= slam_range:
			# Partial damage at range
			var aoe_damage := roundi(damage * 0.7)
			_damage_target(aoe_damage)
	
	# Visual: screen shake
	var camera := get_viewport().get_camera_2d()
	if camera and camera.has_method("shake"):
		camera.shake(6.0, 0.3)
	
	# Particles
	EffectSpawner.spawn_dirt_puff(global_position)
	AudioManager.play(AudioManager.Sound.HIT)


## No standing (non-downed) player left to fight — walk back to the spawn
## point and idle there instead of camping a downed teammate. Mirrors the
## overworld Enemy behavior; does its own move_and_slide + position-sync so
## remote copies keep following the walk-back.
func _back_to_spawn(delta: float) -> void:
	velocity = Vector2.ZERO
	if global_position.distance_to(_spawn_position) > 8.0:
		velocity = (_spawn_position - global_position).normalized() * speed
	move_and_slide()
	if velocity.x < -1.0:
		sprite.flip_h = true
	elif velocity.x > 1.0:
		sprite.flip_h = false
	# Host: broadcast position so remote copies mirror the walk-back.
	if NetworkManager.is_network_active() and multiplayer.is_server():
		_sync_timer += delta
		if _sync_timer >= SYNC_INTERVAL:
			_sync_timer = 0.0
			for pid in _mine_sync_peers():
				rpc_id(pid, "_sync_mine_enemy_state", enemy_id, global_position, current_health)


## Applies damage to the current target player, routing it over the network
## to that player's peer when the enemy's AI runs on another peer.
func _damage_target(amount: int) -> void:
	if not is_instance_valid(_player_ref):
		return
	if NetworkManager.is_network_active():
		var target_peer: int = _player_ref.get_multiplayer_authority()
		if target_peer != multiplayer.get_unique_id():
			GameManager.rpc_id(target_peer, "_receive_remote_enemy_damage", amount)
		else:
			GameManager.take_damage(amount)
	else:
		GameManager.take_damage(amount)


func take_damage(amount: int, _source: Node2D = null, _is_critical: bool = false) -> void:
	if current_health <= 0:
		return

	# Client-side remote copy — forward attack to host for authoritative processing
	if NetworkManager.is_network_active() and _is_remote:
		rpc_id(1, "_server_receive_mine_enemy_attack", enemy_id, amount, _is_critical)
		return

	current_health -= amount
	_update_health_bar()
	
	# Flash red like Minecraft
	sprite.modulate = Color(1.5, 0.2, 0.2, 1.0)  # Instant red tint
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.15)
	tw.set_ease(Tween.EASE_OUT)

	# Damage number for the local attacker (clients get theirs via broadcast)
	EffectSpawner.spawn_damage_number(amount, global_position + Vector2(0, -12), _is_critical)

	if current_health <= 0:
		_die()
	else:
		if _source:
			var kb_dir := (global_position - _source.global_position).normalized()
			velocity = kb_dir * 60.0

	# Host: broadcast damage update to all clients with a built mine room
	if NetworkManager.is_network_active() and multiplayer.is_server():
		for pid in _mine_sync_peers():
			rpc_id(pid, "_sync_mine_enemy_damage", enemy_id, current_health, amount, _is_critical, global_position, max_health)


## Mine-room peers that can receive node-path RPCs from this enemy copy.
## The host is authoritative and drives locally, so it is never included.
func _mine_sync_peers() -> Array[int]:
	var room := get_parent()
	if room and room.has_method("get_sync_peer_ids"):
		return room.get_sync_peer_ids()
	return []


## Host → all clients: sync position and health for a remote copy.
@rpc("unreliable", "authority", "call_local")
func _sync_mine_enemy_state(eid: int, pos: Vector2, hp: int) -> void:
	if not _is_remote or enemy_id != eid:
		return
	global_position = pos
	current_health = hp
	_update_health_bar()


## Host → all clients: broadcast damage result so remote copies show effects.
@rpc("authority", "call_local")
func _sync_mine_enemy_damage(eid: int, hp: int, dmg: int, crit: bool, pos: Vector2, mhp: int) -> void:
	if not _is_remote or enemy_id != eid:
		return
	current_health = hp
	max_health = mhp
	_update_health_bar()
	EffectSpawner.spawn_damage_number(dmg, pos, crit)


## Host → all clients: signal that this enemy has died.
@rpc("authority", "call_local")
func _sync_mine_enemy_died(eid: int, pos: Vector2) -> void:
	if not _is_remote or enemy_id != eid:
		return
	global_position = pos
	_remote_die()


## Client → host: forward a melee/ranged attack on a remote copy.
@rpc("any_peer", "reliable")
func _server_receive_mine_enemy_attack(eid: int, amount: int, crit: bool) -> void:
	if not multiplayer.is_server():
		return
	if _is_remote or enemy_id != eid:
		return
	# Validation mirroring overworld enemies: the attacker must be the
	# sending peer's own player node and within melee range, so an off-map
	# client can't land arbitrary damage on shared mine enemies.
	var attacker: Node2D = null
	var sender: int = multiplayer.get_remote_sender_id()
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and p.get_multiplayer_authority() == sender:
			attacker = p as Node2D
			break
	if attacker == null:
		return
	if global_position.distance_to(attacker.global_position) > 100.0:
		return
	take_damage(amount, attacker, crit)


## Public death trigger — called by CreativePanel kill-all and other external systems.
func die() -> void:
	_die()


func _die() -> void:
	velocity = Vector2.ZERO

	# Only the host rolls loot and grants XP (authoritative). Remote copies
	# receive the death sync and just fade out locally.
	if NetworkManager.is_network_active() and _is_remote:
		_remote_die()
		return

	_drop_loot()

	if experience_value > 0:
		LevelManager.add_xp_source("hit_enemy")
	
	EffectSpawner.spawn_dirt_puff(global_position)
	AudioManager.play(AudioManager.Sound.ENEMY_DIE)
	remove_from_group("enemies")
	
	# Host: broadcast death to clients with a built mine room (loot is
	# instanced per peer, so no list)
	if NetworkManager.is_network_active() and multiplayer.is_server():
		for pid in _mine_sync_peers():
			rpc_id(pid, "_sync_mine_enemy_died", enemy_id, global_position)
	
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.TRANSPARENT, 0.5)
	tween.tween_callback(queue_free)


## Remote-copy death visuals (called locally when the host confirms a kill).
func _remote_die() -> void:
	velocity = Vector2.ZERO
	remove_from_group("enemies")
	EffectSpawner.spawn_dirt_puff(global_position)
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.TRANSPARENT, 0.5)
	tween.tween_callback(queue_free)


func _get_loot_table() -> Array[Dictionary]:
	return [
		{"item_id": "stone", "count": 3, "chance": 0.7},
		{"item_id": "copper_ore", "count": 1, "chance": 0.3},
		{"item_id": "iron_ore", "count": 1, "chance": 0.2},
	]


## Host: roll loot for the killer's peer plus every connected peer
## (instanced drops, same behavior as overworld Enemy._drop_loot_instanced).
func _drop_loot() -> void:
	var loot := _get_loot_table()
	if not NetworkManager.is_network_active():
		for entry in loot:
			if randf() < entry["chance"]:
				InventoryManager.add_item(entry["item_id"], entry["count"])
		return
	if not multiplayer.is_server():
		return
	# Host rolls its own loot locally, then instances drops for every peer
	# whose mine room is built (only they can receive the node-path RPC).
	for entry in loot:
		if randf() < entry["chance"]:
			InventoryManager.add_item(entry["item_id"], entry["count"])
	for peer_id in _mine_sync_peers():
		_roll_loot_for_peer(peer_id, loot)


func _roll_loot_for_peer(peer_id: int, loot: Array) -> void:
	for entry in loot:
		if randf() < entry["chance"]:
			if peer_id == multiplayer.get_unique_id():
				InventoryManager.add_item(entry["item_id"], entry["count"])
			else:
				rpc_id(peer_id, "_receive_loot_drop", entry["item_id"], entry["count"])


@rpc("authority", "reliable")
func _receive_loot_drop(item_id: String, count: int) -> void:
	InventoryManager.add_item(item_id, count)