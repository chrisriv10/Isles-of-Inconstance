extends CharacterBody2D
class_name Enemy

## Base class for all night enemies. Handles movement, health, damage,
## loot drops, and proximity detection. Subclasses override _get_loot_table()
## and configure their own sprite/animation.

signal died(pos: Vector2)
signal health_ratio_changed(ratio: float)

enum State { IDLE, CHASE, ATTACK, STUNNED, DEAD }

## Global multiplier applied to all enemy loot drop chances.
## 1.0 = original rates; 0.5 = half as frequent; 0.25 = quarter as frequent.
const DROP_RATE_MULTIPLIER: float = 0.35  # Harder mode — less loot from enemies

@export var max_health: int = 20
@export var speed: float = 40.0
@export var damage: int = 10
@export var attack_cooldown: float = 1.5
@export var chase_range: float = 180.0
@export var attack_range: float = 20.0
@export var experience_value: int = 0
@export var display_name: String = "Sporeling"

var current_health: int
var state: int = State.IDLE
var player_ref: CharacterBody2D = null
## Tracker for enemy loot drops. Populated on the host, broadcast in death sync.
var _pending_loot_drops: Array[Dictionary] = []


var _attack_timer: float = 0.0
var _enrage_warning_shown: bool = false
## Grace period (seconds) after spawn during which the enemy won't chase.
## Prevents enemies from instantly rushing the player on spawn.
var _spawn_grace_time: float = 0.8
var _spawned_at: float = 0.0
# NOTE: _move_target was removed as dead code — never read or assigned

## Hitstun state — briefly pauses enemy AI after taking damage.
var _stun_timer: Timer
var _previous_state: int = State.IDLE

# Multiplayer sync
const SYNC_INTERVAL: float = 0.1  # seconds between position broadcasts (host only)
var enemy_id: int = 0
var _is_remote: bool = false
var _sync_timer: float = 0.0

# Health bar nodes
var _health_bar_bg: ColorRect = null
var _health_bar_fill: ColorRect = null
var _name_label: Label = null

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D


func _ensure_health_bar() -> void:
	if _health_bar_bg != null:
		return
	var is_boss := is_in_group("bosses")
	var bar_w := 36.0 if is_boss else 18.0
	var bar_h := 6.0 if is_boss else 4.0
	
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
	fill.color = Color(0.9, 0.15, 0.15, 0.85) if not is_boss else Color(0.9, 0.6, 0.15, 0.9)
	add_child(fill)
	_health_bar_fill = fill

	# Name label
	var label := Label.new()
	label.name = "EnemyNameLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10 if is_boss else 8)
	label.add_theme_color_override("font_color", Color(0.95, 0.8, 0.3) if is_boss else Color(1, 1, 1, 0.85))
	label.position = Vector2(-50, -36)
	label.size = Vector2(100, 14)
	add_child(label)
	_name_label = label

func _update_health_bar() -> void:
	_ensure_health_bar()
	var ratio := float(current_health) / float(max_health)
	var is_boss := is_in_group("bosses")
	var bar_w := 36.0 if is_boss else 18.0
	_health_bar_fill.size.x = ratio * bar_w
	# Color: red when healthy, darker red when low
	if ratio > 0.5:
		_health_bar_fill.color = Color(0.9, 0.15, 0.15, 0.85)
	else:
		_health_bar_fill.color = Color(0.6, 0.05, 0.05, 0.85)
	if _name_label:
		_name_label.text = display_name
	health_ratio_changed.emit(ratio)


## Updates the enemy's display name and refreshes its name label.
## Needed because _ready() renders the label from the base class default;
## subclasses/variants that rename after _ready() must use this to keep
## the on-screen label in sync.
func set_display_name(new_name: String) -> void:
	display_name = new_name
	if _name_label:
		_name_label.text = new_name


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 1   # collide with world (TileMapLayer on layer 1)
	collision_mask = 3    # collide with world (layer 1) AND player (layer 2)
	# Scale boss stats based on player level to keep them challenging
	if is_in_group("bosses"):
		_apply_boss_scaling()
	current_health = max_health
	player_ref = get_tree().get_first_node_in_group("player")
	_spawned_at = Time.get_ticks_msec() / 1000.0
	_update_health_bar()
	
	# Set up hitstun timer
	_stun_timer = Timer.new()
	_stun_timer.one_shot = true
	_stun_timer.timeout.connect(_on_stun_ended)
	add_child(_stun_timer)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	
	# Remote copy — skip AI, position is synced by host
	if NetworkManager.is_network_active() and _is_remote:
		return
	
	_attack_timer = max(0.0, _attack_timer - delta)
	
	if not is_instance_valid(player_ref):
		player_ref = get_tree().get_first_node_in_group("player")
		if not is_instance_valid(player_ref):
			velocity = Vector2.ZERO
			return
	
	# Always update state — even from ATTACK — so enemies resume chasing
	# when the player moves out of attack range.
	_update_state()
	
	match state:
		State.IDLE:
			velocity = Vector2.ZERO
		State.CHASE:
			_chase_player(delta)
		State.ATTACK:
			velocity = Vector2.ZERO
			if _attack_timer <= 0.0:
				_attack_player()
		State.STUNNED:
			velocity = Vector2.ZERO
			# Timer handles state transition back to previous state
	
	# Sanitize velocity — NaN/INF values propagate through move_and_slide and
	# corrupt global_position, causing camera jitter / pseudo-crashes.
	if not is_finite(velocity.x) or not is_finite(velocity.y):
		velocity = Vector2.ZERO
	move_and_slide()
	
	# Host: periodically broadcast position/state to remote peers
	if NetworkManager.is_network_active() and multiplayer.is_server():
		_sync_timer += delta
		if _sync_timer >= SYNC_INTERVAL:
			_sync_timer = 0.0
			rpc("_sync_enemy_state", enemy_id, global_position, current_health, state)


func _update_state() -> void:
	if state == State.STUNNED or state == State.DEAD:
		return  # Don't override hitstun or death with chase/attack
	if not player_ref:
		state = State.IDLE
		return
	
	# During the spawn grace period, enemies are idle/alert but don't chase.
	# This gives the player a moment to react when enemies appear.
	if Time.get_ticks_msec() / 1000.0 - _spawned_at < _spawn_grace_time:
		state = State.IDLE
		return
	
	var dist := global_position.distance_to(player_ref.global_position)
	
	if dist <= attack_range:
		state = State.ATTACK
	elif dist <= chase_range:
		state = State.CHASE
	else:
		state = State.IDLE


func _chase_player(_delta: float) -> void:
	if not player_ref:
		return
	var dist := global_position.distance_to(player_ref.global_position)
	var diff := player_ref.global_position - global_position
	var dir := _safe_normalize(diff)
	# Keep a safe buffer from the player so enemies don't stack on top
	var stop_dist := attack_range * 0.85
	if dist <= stop_dist:
		velocity = Vector2.ZERO
		
	else:
		# Check if moving towards player would cross water — if so, pathfind around it
		var next_pos := global_position + dir * speed * _delta
		if _is_water_position(next_pos):
			# Try perpendicular movement to go around water
			var perp_dir := Vector2(dir.y, dir.x)
			var perp_pos := global_position + perp_dir * speed * _delta
			if not _is_water_position(perp_pos):
				velocity = perp_dir * speed
			else:
				var neg_perp_pos := global_position - perp_dir * speed * _delta
				if not _is_water_position(neg_perp_pos):
					velocity = -perp_dir * speed
				else:
					# Both sides blocked — stop and wait
					velocity = Vector2.ZERO
		else:
			velocity = dir * speed
	
	# Flip sprite to face player
	if sprite:
		sprite.flip_h = dir.x < 0

func _is_water_position(pos: Vector2) -> bool:
	var world := get_tree().get_first_node_in_group("world")
	if not world:
		return false
	if world.has_method("is_cell_walkable"):
		return not world.is_cell_walkable(pos)
	return false


## Trigger screen shake on the player's camera.
func _trigger_screen_shake(strength: float = 4.0, duration: float = 0.2) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_node("Camera2D"):
		var cam: CameraController = player.get_node("Camera2D") as CameraController
		if cam:
			cam.shake(strength, duration)


## Trigger a full-screen flash overlay on the HUD.
func _trigger_screen_flash(color: Color = Color(1.0, 1.0, 1.0, 0.3), duration: float = 0.8) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if not hud:
		return
	var flash := ColorRect.new()
	flash.color = color
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(flash)
	var tween := create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, duration)
	tween.tween_callback(flash.queue_free)


## Called when the hitstun timer ends — returns to the previous state.
func _on_stun_ended() -> void:
	if state == State.STUNNED:
		state = _previous_state


## Scales boss HP and damage based on player level so they remain challenging.
## Bosses gain +10% HP and +5% damage per player level above 1.
func _apply_boss_scaling() -> void:
	var level: int = 1
	var lm := Engine.get_singleton("LevelManager")
	if lm and lm.has_method("get_level"):
		level = max(1, lm.get_level())
	var hp_mult: float = 1.0 + (level - 1) * 0.10
	var dmg_mult: float = 1.0 + (level - 1) * 0.05
	max_health = max(10, roundi(max_health * hp_mult))
	damage = max(1, roundi(damage * dmg_mult))


func _attack_player() -> void:
	if not player_ref:
		return
	_attack_timer = attack_cooldown
	var dist := global_position.distance_to(player_ref.global_position)
	if dist <= attack_range + 10.0:
		if NetworkManager.is_network_active():
			var target_peer: int = player_ref.get_multiplayer_authority()
			if target_peer != multiplayer.get_unique_id():
				rpc_id(target_peer, "_receive_remote_enemy_damage", damage)
			else:
				GameManager.take_damage(damage)
		else:
			GameManager.take_damage(damage)
		EffectSpawner.spawn_particles(player_ref.global_position, Color(1.0, 0.2, 0.2), 4, 8.0)
		AudioManager.play(AudioManager.Sound.HIT)
		var push_dir := _safe_normalize(global_position - player_ref.global_position)
		if push_dir != Vector2.ZERO:
			global_position += push_dir * 8.0


func take_damage(amount: int, _source: Node2D = null, is_critical: bool = false) -> void:
	if state == State.DEAD:
		return
	
	# Client-side remote copy — forward attack to host for authoritative processing
	if NetworkManager.is_network_active() and _is_remote:
		rpc_id(1, "_server_receive_enemy_attack", enemy_id, amount, is_critical)
		return
	
	current_health -= amount
	_update_health_bar()
	EffectSpawner.spawn_particles(global_position, Color(1.0, 1.0, 0.3), 3, 6.0)
	
	# Combat feedback — enhanced damage numbers with crit support
	var is_boss := is_in_group("bosses")
	var dmg_color: Color
	var dmg_pos: Vector2
	
	if is_boss:
		dmg_pos = global_position + Vector2(0, -20)
		if is_critical:
			dmg_color = Color(1.0, 0.3, 0.0)
		else:
			dmg_color = Color(1.0, 0.6, 0.1)
	else:
		dmg_pos = global_position + Vector2(0, -12)
		if is_critical:
			dmg_color = Color(1.0, 0.4, 0.0)
		else:
			dmg_color = Color(1.0, 0.9, 0.2)
	
	EffectSpawner.spawn_damage_number(amount, dmg_pos, is_critical)
	
	# Extra particles on crit
	if is_critical:
		EffectSpawner.spawn_particles(global_position, Color(1.0, 0.4, 0.0), 6, 10.0)
		EffectSpawner.screen_shake(4.0, 0.15)
	
	# Check for low-HP enrage warning on bosses
	if is_boss and current_health > 0 and not _enrage_warning_shown:
		var hp_ratio := float(current_health) / float(max_health)
		if hp_ratio <= 0.25:
			_enrage_warning_shown = true
			ToastNotification.show_toast("⚠ " + display_name + " is ENRAGED!", ToastNotification.ToastType.ERROR, 3.0)
			EffectSpawner.spawn_particles(global_position, Color(1.0, 0.2, 0.0), 16, 20.0)
			_trigger_screen_shake(8.0, 0.3)
	
	if current_health <= 0:
		_die()
	else:
		# Enter hitstun — briefly pause AI
		if state != State.STUNNED:
			_previous_state = state
			state = State.STUNNED
			_stun_timer.wait_time = 0.2
			_stun_timer.start()
		
		# Flash red like Minecraft
		if sprite:
			sprite.modulate = Color(1.5, 0.2, 0.2, 1.0)  # Instant red tint
			var hit_tween := create_tween()
			hit_tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)
			hit_tween.set_ease(Tween.EASE_OUT)
	
	# Host: broadcast damage update to all clients
	if NetworkManager.is_network_active() and multiplayer.is_server():
		rpc("_sync_enemy_damage", enemy_id, current_health, amount, is_critical, global_position, max_health)


## Public death trigger — called by CreativePanel kill-all and other external systems.
func die() -> void:
	_die()


func _die() -> void:
	state = State.DEAD
	velocity = Vector2.ZERO
	collision.set_deferred("disabled", true)
	
	# Drop loot (populates _pending_loot_drops for broadcast)
	_drop_loot()
	
	# Host: broadcast death and loot to all clients
	if NetworkManager.is_network_active() and multiplayer.is_server():
		rpc("_sync_enemy_died", enemy_id, _pending_loot_drops)
	_pending_loot_drops.clear()
	
	var is_boss := is_in_group("bosses")
	if is_boss:
		AudioManager.play(AudioManager.Sound.BOSS_DIE)
		LevelManager.add_xp_source("kill_boss")
		EffectSpawner.spawn_xp_notification(500, global_position + Vector2(0, -16))
		ToastNotification.show_toast("💀 " + display_name + " defeated!", ToastNotification.ToastType.SUCCESS, 4.0)
		# Screen shake-like effect: tint the world briefly
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("_on_boss_defeated"):
			hud._on_boss_defeated()
	else:
		LevelManager.add_xp_source("kill_enemy")
		# Death particles — reduced counts to avoid frame-freezing on AOE multi-death
		EffectSpawner.spawn_particles(global_position, Color(1.0, 1.0, 0.3), 4, 12.0)
		EffectSpawner.spawn_particles(global_position, Color(1.0, 0.5, 0.1), 2, 8.0)
		EffectSpawner.screen_shake(3.0, 0.1)
		# Floating XP text at the enemy's position
		EffectSpawner.spawn_xp_notification(experience_value, global_position + Vector2(0, -16))
		# Play death audio (throttled: skip if the same sound is already playing)
		AudioManager.play(AudioManager.Sound.ENEMY_DIE)
	
	# Track enemy slain objective
	var ene_mgr := get_tree().get_first_node_in_group("objective_manager")
	if ene_mgr and ene_mgr.has_method("on_enemy_slain"):
		ene_mgr.on_enemy_slain()
	
	# Track quest kill progress — report the class name for quest matching
	var quest_mgr := get_tree().get_first_node_in_group("quest_manager")
	if quest_mgr and quest_mgr.has_method("report_kill"):
		# Use the class_name if available (SporelingEnemy, ShadowHound, etc.)
		var script_name: String = get_script().get_global_name() if get_script() else ""
		if script_name.is_empty():
			script_name = display_name.replace(" ", "")
		quest_mgr.report_kill(script_name)
	
	# Visual death effect — reduced counts for non-boss to prevent freeze on AOE multi-death
	EffectSpawner.spawn_particles(global_position, Color(0.5, 0.0, 0.5) if not is_boss else Color(1.0, 0.85, 0.3), 6 if not is_boss else 24, 12.0 if not is_boss else 30.0)
	if is_boss:
		EffectSpawner.spawn_particles(global_position, Color(1.0, 0.2, 0.2), 16, 24.0)
	
	# Fade out and remove (slower for bosses)
	var fade_time := 1.0 if is_boss else 0.5
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, fade_time)
	tween.tween_callback(func():
		died.emit(global_position)
		queue_free()
	)


## Override in subclasses to return a list of {item_id, count, chance} dictionaries.
func _get_loot_table() -> Array[Dictionary]:
	return []

## Override in boss subclasses to play a dramatic boss-specific spawn effect.
func _summon_spawn_effect() -> void:
	# Default: basic particle burst + screen shake
	EffectSpawner.spawn_particles(global_position, Color(0.8, 0.3, 0.9), 15, 20.0)
	EffectSpawner.spawn_floating_text("A creature appears!", global_position, Color(1.0, 0.6, 0.2))
	AudioManager.play(AudioManager.Sound.BOSS_ROAR)
	if has_method("_trigger_screen_shake"):
		_trigger_screen_shake(6.0, 0.4)


func _drop_loot() -> void:
	var loot := _get_loot_table()
	var loot_bonus: float = 0.0
	if Engine.has_singleton("PetManager"):
		var pet_mgr: Node = Engine.get_singleton("PetManager")
		if pet_mgr and pet_mgr.has_method("get_loot_bonus"):
			loot_bonus = pet_mgr.get_loot_bonus()
	for entry in loot:
		if randf() <= (entry.get("chance", 1.0) + loot_bonus) * DROP_RATE_MULTIPLIER:
			var count: int = entry.get("count", 1)
			InventoryManager.add_item(entry["item_id"], count)
			_queue_loot(entry["item_id"], count)
	
	# Ultra-rare Inconstant Fruit drop from any enemy (0.05% base + tiny pet bonus)
	if randf() < 0.0005 + loot_bonus * 0.001:
		_try_drop_inconstant_fruit()


func _queue_loot(item_id: String, count: int = 1) -> void:
	if NetworkManager.is_network_active():
		_pending_loot_drops.append({"item_id": item_id, "count": count})


# ── Multiplayer RPC ──────────────────────────────────────────────────────

## Host → all clients: sync position, health, and state for a remote copy.
@rpc("unreliable", "authority", "call_local")
func _sync_enemy_state(eid: int, pos: Vector2, hp: int, st: int) -> void:
	if not _is_remote or enemy_id != eid:
		return
	global_position = pos
	current_health = hp
	state = st
	_update_health_bar()


## Host → all clients: broadcast damage result so remote copies show effects.
@rpc("authority", "call_local")
func _sync_enemy_damage(eid: int, hp: int, dmg: int, crit: bool, pos: Vector2, mhp: int) -> void:
	if not _is_remote or enemy_id != eid:
		return
	current_health = hp
	max_health = mhp
	_update_health_bar()
	EffectSpawner.spawn_damage_number(dmg, pos, crit)
	if crit:
		EffectSpawner.spawn_particles(pos, Color(1.0, 0.4, 0.0), 6, 10.0)


## Host → all clients: signal that this enemy has died and distribute loot.
@rpc("authority", "call_local")
func _sync_enemy_died(eid: int, loot: Array[Dictionary] = []) -> void:
	if not _is_remote or enemy_id != eid:
		return
	state = State.DEAD
	died.emit(global_position)
	# Add loot to the receiving client's inventory
	for drop in loot:
		var item_id: String = drop.get("item_id", "")
		var count: int = drop.get("count", 1)
		if not item_id.is_empty():
			InventoryManager.add_item(item_id, count)
	queue_free()


## Client → host: forward a melee/ranged attack on a remote copy.
@rpc("any_peer", "reliable")
func _server_receive_enemy_attack(eid: int, amount: int, crit: bool) -> void:
	if not multiplayer.is_server():
		return
	if _is_remote or enemy_id != eid:
		return
	# Basic validation — attacker must be nearby
	var attacker := get_tree().get_first_node_in_group("player")
	if not attacker:
		return
	if global_position.distance_to(attacker.global_position) > 100.0:
		return
	take_damage(amount, attacker, crit)


## Safely normalize a Vector2, returning Vector2.ZERO if the vector is zero or contains NaN/INF.
static func _safe_normalize(v: Vector2) -> Vector2:
	if v == Vector2.ZERO or not is_finite(v.x) or not is_finite(v.y):
		return Vector2.ZERO
	return v.normalized()


## Ultra-rare chance (0.05%) for any enemy to drop an Inconstant Fruit.
func _try_drop_inconstant_fruit() -> void:
	var available_fruits: Array[ItemData] = InconstantFruitSystem.get_wild_findable_fruits()
	if available_fruits.is_empty():
		return
	var fruit: ItemData = available_fruits[randi() % available_fruits.size()]
	if InventoryManager.can_fit(fruit.id, 1):
		InventoryManager.add_item(fruit.id, 1)
		_queue_loot(fruit.id, 1)
		ToastNotification.show_toast("[color=#FFD700][b]✦ Legendary Drop! ✦[/b][/color]\nA [color=#BB66FF]%s[/color] falls from the slain foe!" % fruit.display_name, ToastNotification.ToastType.SUCCESS, 5.0)
		AudioManager.play(AudioManager.Sound.LEVEL_UP)
		EffectSpawner.spawn_sparkle(global_position, Color(1.0, 0.8, 0.3))
