extends CharacterBody2D
class_name CaveBat

## Small flying cave bat that swoops at the player.
## Found near water pools in the mines. It flies, so it can move
## over water tiles unlike ground enemies.
##
## Has a fast swooping attack pattern: circles at range, then
## dives at the player when close enough.

## Health points
var max_health: int = 8
var current_health: int = 8

## Movement speed (pixels/sec) — fast fliers
var speed: float = 70.0

## Damage dealt to player on contact
var damage: int = 4

## Attack cooldown (seconds)
var attack_cooldown: float = 0.8

## Chase/aggro range
var chase_range: float = 180.0

## Attack range
var attack_range: float = 16.0

## XP granted on kill
var experience_value: int = 3

## Swoop distance — bat flies above target then dives
var swoop_altitude: float = 20.0

var _attack_timer: float = 0.0
var _player_ref: Node2D = null
var _hp_mult: float = 1.0
var _swoop_offset: float = 0.0
var _swoop_direction: float = 1.0

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
	current_health = max_health
	_ensure_health_bar()
	_update_health_bar()
	# Find the nearest player (remote copies included, same as overworld Enemy.gd)
	_player_ref = _find_nearest_player()
	_swoop_direction = 1.0 if randf() > 0.5 else -1.0


func set_hp_multiplier(mult: float) -> void:
	_hp_mult = mult
	max_health = roundi(max_health * _hp_mult)
	current_health = max_health


## Picks the closest valid player node from the "player" group, or null.
## In multiplayer every peer has its own local player plus remote copies,
## so the enemy targets the nearest player instead of the first in the group.
func _find_nearest_player() -> Node2D:
	var best: Node2D = null
	var best_dist_sq: float = INF
	for p in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(p) or not (p is Node2D):
			continue
		var p_node: Node2D = p as Node2D
		var d_sq: float = global_position.distance_squared_to(p_node.global_position)
		if d_sq < best_dist_sq:
			best_dist_sq = d_sq
			best = p_node
	return best


## Re-picks the nearest player each frame with hysteresis so the enemy does
## not oscillate between two players who are roughly equidistant.
func _refresh_target_player() -> void:
	var nearest: Node2D = _find_nearest_player()
	if not is_instance_valid(_player_ref):
		_player_ref = nearest
		return
	if nearest == null:
		return
	var current_dist: float = global_position.distance_to(_player_ref.global_position)
	var nearest_dist: float = global_position.distance_to(nearest.global_position)
	if current_dist - nearest_dist > 40.0:
		_player_ref = nearest


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
	label.text = "Cave Bat"
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

	# Find player reference
	# Try to find player if we lost reference
	if not _player_ref or not is_instance_valid(_player_ref):
		_player_ref = _find_nearest_player()
		return

	_refresh_target_player()
	if not is_instance_valid(_player_ref):
		return

	var dist := global_position.distance_to(_player_ref.global_position)

	if dist <= attack_range:
		# Attack
		velocity = Vector2.ZERO
		if _attack_timer <= 0.0:
			_attack_timer = attack_cooldown
			_damage_target(damage)
			EffectSpawner.spawn_dirt_puff(global_position)
			# Push back so the bat doesn't sit on the player
			var push_dir := (global_position - _player_ref.global_position).normalized()
			if push_dir != Vector2.ZERO:
				global_position += push_dir * 10.0
	elif dist <= chase_range:
		# Swooping flight pattern: bat hovers with sine-wave vertical motion
		# while moving toward the player
		var dir := (_player_ref.global_position - global_position).normalized()

		# Add vertical swooping oscillation
		_swoop_offset += delta * 3.0
		var swoop_y := sin(_swoop_offset) * swoop_altitude

		# Move toward player with swoop
		velocity = dir * speed
		velocity.y += swoop_y * 0.3

		# Sometimes move in an arc to the side for more erratic movement
		if dist < 80.0:
			velocity.x += cos(_swoop_offset * 0.7) * 20.0
	else:
		# Idle circling around a point
		_swoop_offset += delta * 2.0
		velocity = Vector2(
			cos(_swoop_offset) * 30.0,
			sin(_swoop_offset * 0.5) * 15.0
		)

	move_and_slide()

	# Flip sprite based on horizontal direction
	if velocity.x < -5.0:
		sprite.flip_h = true
	elif velocity.x > 5.0:
		sprite.flip_h = false

	# Wing animation — subtle scale pulse
	var wing_pulse := 1.0 + sin(_swoop_offset * 4.0) * 0.05
	sprite.scale.y = wing_pulse

	# Host: periodically broadcast position/health to remote peers
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
			velocity = kb_dir * 80.0

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
	take_damage(amount, null, crit)


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
	tween.tween_property(self, "modulate", Color.TRANSPARENT, 0.3)
	tween.tween_callback(queue_free)


## Remote-copy death visuals (called locally when the host confirms a kill).
func _remote_die() -> void:
	velocity = Vector2.ZERO
	remove_from_group("enemies")
	EffectSpawner.spawn_dirt_puff(global_position)
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.TRANSPARENT, 0.3)
	tween.tween_callback(queue_free)


func _get_loot_table() -> Array[Dictionary]:
	return [
		{"item_id": "spore_sac", "count": 1, "chance": 0.3},
		{"item_id": "stone", "count": 1, "chance": 0.2},
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