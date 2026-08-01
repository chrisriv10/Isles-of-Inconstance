class_name PirateRaidEvent
extends Node

## Pirate Raid Event for Isles of Inconstance.
## Periodically triggers a raid event where pirates spawn near the player.
## The player must survive the raid. Waves get harder. Rewards on survival.

signal raid_started(wave_count: int)
signal raid_wave_spawned(wave: int, total_waves: int)
signal raid_ended(victory: bool)

enum RaidState {
	INACTIVE,
	WARNING,
	ACTIVE,
	COOLDOWN,
}

var state: RaidState = RaidState.INACTIVE
var current_wave: int = 0
var max_waves: int = 3
var enemies_per_wave: int = 3
var _cooldown_days: int = 5
var _days_until_next_raid: int = 3
var _rng: RandomNumberGenerator
var _player_ref: Node2D = null
var _world_ref: Node = null
var _dock_position: Vector2 = Vector2.ZERO
var _pirate_ship_sprite: Sprite2D = null

# ── Randomized pirate raid dialogue ──
const PIRATE_TAUNTS_WAVE_START: Array[String] = [
	"Arr! The landlubber thinks they can fight us!",
	"Har har! We'll take yer gold and yer ship!",
	"Avast! Prepare to be boarded!",
	"Yer crops be ours now, farm boy!",
	"All hands on deck! Raid ashore!",
	"Ye picked the wrong island to settle, matey!",
	"Surrender and we'll go easy on ye!",
	"Cut 'em down, lads!",
	"Treasure and plunder for everyone!",
	"This here island's ours now!",
]
const PIRATE_TAUNTS_WAVE_END: Array[String] = [
	"Argh! We'll be back!",
	"Ye got lucky this time!",
	"The Flying Dutchman sends 'is regards!",
	"Mark my words — we'll return with a bigger crew!",
	"Blast! Retreat!",
	"Yarr... ye fight well for a dirt-digger.",
	"This isn't over, greenhorn!",
	"Curse ye and yer farm tools!",
	"We'll have yer head next time!",
	"Back to the ship! Run!",
]
const PIRATE_TAUNTS_DURING: Array[String] = [
	"Get 'em, boys!",
	"Stand and fight, coward!",
	"Yer gold'll make a fine prize!",
	"Skewer the farmer!",
	"Not so tough now, are ye?",
	"To the victor go the spoils!",
	"We've got 'em surrounded!",
	"One more down!",
	"Parry this, farmhand!",
	"Who's next?",
	"Yer cuts ain't got no power against me blunderbuss!",
	"I'll make a fine coat from yer leather!",
	"Hoist the colors! Death to all who resist!",
	"Take that, ye scallywag!",
	"Arr, I can smell yer fear!",
	"Don't let 'em escape!",
]
const PIRATE_TAUNTS_BOSS_DEFEATED: Array[String] = [
	"Who's the captain NOW?!",
	"Bury 'em at sea... oh wait, we're on land!",
	"That's what ye get for messing with a farmer!",
	"Back to Davey Jones's Locker with ye!",
]

func _init() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.randomize()


# ── Pirate dialogue helpers ──

## Pick a random line from a dialogue pool.
func _pick_random_taunt(pool: Array[String]) -> String:
	return pool[_rng.randi() % pool.size()]


## Spawn a styled dialogue bubble at the given world position.
## Creates a Node2D with a Label child that has a dark background with
## orange border and proper spacing, matching the boat's NPC dialogue bubble style.
func _spawn_dialogue_bubble(text: String, position: Vector2, duration: float = 4.0, follow_target: Node = null) -> void:
	var parent: Node = get_tree().current_scene
	if not parent:
		return
	
	var container := Node2D.new()
	container.z_index = 105
	
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
	label.add_theme_constant_override("outline_size", 1)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Style the background like the boat's dialogue bubble
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.88)
	style.border_color = Color(1.0, 0.6, 0.1, 0.7)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	label.add_theme_stylebox_override("normal", style)
	
	container.add_child(label)
	
	# Add to scene tree BEFORE sizing
	parent.add_child(container)
	
	# Size and center the bubble
	var label_size: Vector2 = label.get_minimum_size()
	var bubble_w: float = max(label_size.x + 12.0, 40.0)
	var bubble_h: float = max(label_size.y + 6.0, 22.0)
	label.size = Vector2(bubble_w, bubble_h)
	container.position = position - Vector2(bubble_w / 2.0, bubble_h / 2.0)
	
	# If we have a follow_target, keep the bubble positioned above it as it moves
	if follow_target and follow_target.has_method("get_global_position"):
		# Extract the vertical offset from the passed position (e.g. Vector2(0, -32))
		var vert_offset: Vector2 = position - follow_target.global_position
		var follow_script := load("res://scripts/world/dialogue_bubble_follow.gd")
		container.set_script(follow_script)
		container.follow(follow_target, vert_offset, Vector2(bubble_w, bubble_h))
	
	# Fade in, hold, fade out
	container.modulate.a = 0.0
	var tween := container.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(container, "modulate:a", 1.0, 0.2)
	tween.tween_interval(duration)
	tween.tween_property(container, "modulate:a", 0.0, 0.3)
	tween.tween_callback(container.queue_free)


## Show a pirate taunt as a styled dialogue bubble above the pirate ship sprite.
## Replaces the old toast-style notification with a proper speech bubble.
func _show_pirate_dialogue_above_ship(text: String) -> void:
	if not _pirate_ship_sprite or not _pirate_ship_sprite.is_inside_tree():
		return
	_spawn_dialogue_bubble(text, _pirate_ship_sprite.global_position + Vector2(0, -48), 5.0, _pirate_ship_sprite)


## Show a pirate taunt as a dialogue bubble above a specific pirate enemy.
func _show_pirate_dialogue_above_pirate(enemy: Node, text: String) -> void:
	if not is_instance_valid(enemy):
		return
	_spawn_dialogue_bubble(text, enemy.global_position + Vector2(0, -32), 3.5, enemy)


## Start a timer that periodically shows a random pirate taunt during battle.
func _start_taunt_timer() -> void:
	if has_node("PirateTauntTimer"):
		return
	var timer := Timer.new()
	timer.name = "PirateTauntTimer"
	timer.wait_time = 10.0 + _rng.randf() * 8.0  # 10-18 seconds between taunts
	timer.one_shot = true
	timer.timeout.connect(_on_taunt_timer_timeout)
	add_child(timer)
	timer.start()


func _on_taunt_timer_timeout() -> void:
	if state != RaidState.ACTIVE:
		return
	if _rng.randf() < 0.4:  # 40% chance to taunt each tick
		# Pick a random alive pirate to speak, fall back to ship
		var pirates := get_tree().get_nodes_in_group("enemies")
		var alive_pirates: Array[Node] = []
		for p: Node in pirates:
			if p.has_meta("is_pirate") and is_instance_valid(p):
				alive_pirates.append(p)
		if not alive_pirates.is_empty():
			var target: Node = alive_pirates[_rng.randi() % alive_pirates.size()]
			_show_pirate_dialogue_above_pirate(target, _pick_random_taunt(PIRATE_TAUNTS_DURING))
		else:
			_show_pirate_dialogue_above_ship(_pick_random_taunt(PIRATE_TAUNTS_DURING))
	# Restart the timer with a random interval
	var timer := get_node_or_null("PirateTauntTimer") as Timer
	if timer:
		timer.wait_time = 10.0 + _rng.randf() * 8.0
		timer.start()
	else:
		_start_taunt_timer()


func _stop_taunt_timer() -> void:
	var timer := get_node_or_null("PirateTauntTimer") as Timer
	if timer:
		timer.stop()
		timer.queue_free()


## Called when a new day starts. Checks if raid should trigger.
func advance_day(_day: int) -> void:
	match state:
		RaidState.COOLDOWN:
			_cooldown_days -= 1
			if _cooldown_days <= 0:
				_days_until_next_raid = _rng.randi_range(2, 5)
				state = RaidState.INACTIVE
		RaidState.INACTIVE:
			_days_until_next_raid -= 1
			if _days_until_next_raid <= 0 and _rng.randf() < 0.4:  # 40% chance when timer hits zero
				_start_raid()

func _start_raid() -> void:
	state = RaidState.WARNING
	_world_ref = get_tree().get_first_node_in_group("world")
	_player_ref = get_tree().get_first_node_in_group("player")
	if not _player_ref or not _world_ref:
		state = RaidState.COOLDOWN
		_cooldown_days = 2
		return
	
	# Get dock position for pirate ship spawn
	if _world_ref.has_method("get_dock_position"):
		_dock_position = _world_ref.get_dock_position()
	else:
		_dock_position = _player_ref.global_position + Vector2(200, 0)  # fallback
	
	# Spawn the pirate ship sprite at the dock
	_spawn_pirate_ship()
	
	current_wave = 0
	max_waves = 2 + _rng.randi() % 3  # 2-4 waves
	enemies_per_wave = 2 + (_rng.randi() % 3)  # 2-4 per wave
	
	ToastNotification.show_toast("🏴‍☠️ PIRATES SPOTTED! Prepare for battle!", ToastNotification.ToastType.WARNING, 5.0)
	raid_started.emit(max_waves)
	
	# Show a random pirate taunt via floating text above the ship
	_show_pirate_dialogue_above_ship(_pick_random_taunt(PIRATE_TAUNTS_WAVE_START))
	
	# Brief warning before first wave
	get_tree().create_timer(3.0).timeout.connect(_spawn_wave)

func _spawn_pirate_ship() -> void:
	if not _world_ref or not is_inside_tree():
		return
	# Create a pirate ship sprite at Berth 1 (center berth of the large dock)
	_pirate_ship_sprite = Sprite2D.new()
	_pirate_ship_sprite.name = "PirateShip"
	var ship_tex := load("res://assets/generated/pirate_ship_v3_frame_0.png")
	if ship_tex:
		_pirate_ship_sprite.texture = ship_tex
	# Use Berth 1 from Dock constants (center berth for pirate ship)
	var berth_pos: Vector2 = _dock_position + Dock.BERTH_POSITIONS[1]
	_pirate_ship_sprite.position = berth_pos
	_pirate_ship_sprite.z_index = 10
	_world_ref.add_child(_pirate_ship_sprite)
	# Add a subtle bob animation
	var btw := _pirate_ship_sprite.create_tween()
	btw.set_loops()
	btw.tween_property(_pirate_ship_sprite, "position:y", berth_pos.y + 4, 1.5)
	btw.tween_property(_pirate_ship_sprite, "position:y", berth_pos.y, 1.5)


func _remove_pirate_ship() -> void:
	if _pirate_ship_sprite and _pirate_ship_sprite.is_inside_tree():
		# Quick fade-out
		var tween := _pirate_ship_sprite.create_tween()
		tween.tween_property(_pirate_ship_sprite, "modulate:a", 0.0, 0.5)
		tween.tween_callback(_pirate_ship_sprite.queue_free)
	_pirate_ship_sprite = null


func _spawn_wave() -> void:
	if state != RaidState.WARNING and state != RaidState.ACTIVE:
		return
	
	state = RaidState.ACTIVE
	current_wave += 1
	
	ToastNotification.show_toast("Wave %d/%d of pirates incoming!" % [current_wave, max_waves], ToastNotification.ToastType.WARNING, 4.0)
	raid_wave_spawned.emit(current_wave, max_waves)
	
	# Show a pirate taunt — first wave gets a bold opener, later waves get mid-raid jeers
	if current_wave == 1:
		_show_pirate_dialogue_above_ship(_pick_random_taunt(PIRATE_TAUNTS_WAVE_START))
		# Start periodic taunts during the active raid
		_start_taunt_timer()
	else:
		_show_pirate_dialogue_above_ship(_pick_random_taunt(PIRATE_TAUNTS_DURING))
	
	# Spawn enemies from the dock area, marching onto the island to hunt
	# the player. Stagger spawns with a small delay so pirates appear to
	# run off the ship one by one.
	for i in range(enemies_per_wave):
		if not _player_ref or not _world_ref:
			break
		
		# Stagger spawns so pirates disembark in sequence (0.3s apart)
		var stagger_delay := i * 0.3
		get_tree().create_timer(stagger_delay).timeout.connect(
			func():
				if not _world_ref or not is_inside_tree():
					return
				_spawn_single_pirate()
		)
	
	# Start checking if all pirates in this wave are dead before progressing
	# This ensures waves only advance after all enemies from the current wave are cleared
	var check_timer := Timer.new()
	check_timer.name = "WaveCheckTimer"
	check_timer.wait_time = 1.0  # Check every second
	check_timer.one_shot = false
	check_timer.timeout.connect(_check_wave_completion)
	add_child(check_timer)
	check_timer.start()


## Spawn a single pirate at the dock area. Pirates appear on the beach
## just north of the dock (where the gangplank touches shore) and then
## chase the player — either south onto the dock or north into the island.
## The x-range keeps them within the dock's walkable corridor so they can
## step off the dock area onto the island without hitting water.
func _spawn_single_pirate() -> void:
	if not _world_ref or not _player_ref or not is_inside_tree():
		return
	
	var spawn_pos: Vector2
	
	# Dock-area spawn: on the beach north of the dock, within the
	# dock's walkable x-corridor so pirates step onto the path tiles
	# instead of hitting water and getting stuck.
	# Extends further north (-200) to find walkable beach/land tiles
	# beyond the coastline, giving pirates room to path onto the island.
	var found_walkable := false
	for _attempt in range(12):
		var offset := Vector2(
			_rng.randf_range(-120.0, 80.0),
			_rng.randf_range(-200.0, -30.0)
		)
		spawn_pos = _dock_position + offset
		var cell := Vector2i(int(spawn_pos.x / 16), int(spawn_pos.y / 16))
		
		# Check bounds
		if _world_ref.has_method("_is_in_bounds"):
			var world_w: int = _world_ref.world_width if "world_width" in _world_ref else 60
			var world_h: int = _world_ref.world_height if "world_height" in _world_ref else 60
			if cell.x < 1 or cell.x >= world_w - 1 or cell.y < 1 or cell.y >= world_h - 1:
				continue
		
		if _world_ref.has_method("is_cell_walkable") and _world_ref.is_cell_walkable(spawn_pos):
			found_walkable = true
			break
	
	if not found_walkable:
		return
	
	# Spawn the pirate
	var pirate := _spawn_pirate_enemy(spawn_pos)
	
	# Give each pirate a random personal taunt above their head on spawn
	if pirate:
		_show_pirate_dialogue_above_pirate(pirate, _pick_random_taunt(PIRATE_TAUNTS_DURING))
	
	# Dust puff effect to show the pirate jumping onto the beach
	EffectSpawner.spawn_particles(spawn_pos, Color(0.6, 0.5, 0.3), 4, 8.0)


## Checks if all pirates from the current wave have been defeated.
## Only progresses to the next wave (or raid victory) once none remain.
func _check_wave_completion() -> void:
	if not is_inside_tree() or state != RaidState.ACTIVE:
		return
	
	var enemies := get_tree().get_nodes_in_group("enemies")
	var pirates_alive := 0
	for e: Node in enemies:
		if e.has_meta("is_pirate"):
			pirates_alive += 1
	
	if pirates_alive <= 0:
		# Clean up the wave check timer
		if has_node("WaveCheckTimer"):
			get_node("WaveCheckTimer").queue_free()
		
		# Brief dramatic pause before next wave
		if current_wave >= max_waves:
			# All waves done — trigger raid victory check
			var timer := Timer.new()
			timer.name = "RaidCheckTimer"
			timer.wait_time = 1.5
			timer.one_shot = true
			timer.timeout.connect(_on_raid_victory)
			add_child(timer)
			timer.start()
		else:
			# Schedule next wave after a dramatic 1.5s delay
			get_tree().create_timer(1.5).timeout.connect(_spawn_wave)


func _spawn_pirate_enemy(pos: Vector2) -> Enemy:
	if not _world_ref:
		return null
	# Use the EnemySpawner to create a pirate variant
	if _world_ref.has_method("get_enemy_spawner"):
		var spawner = _world_ref.get_enemy_spawner()
		if spawner and spawner.has_method("spawn_enemy_at"):
			return spawner.spawn_enemy_at(pos, "pirate")
		return null
	
	# Fallback: create enemy from GhostEnemy script (has proper collision shapes)
	var EnemyScript := load("res://scripts/world/enemies/GhostEnemy.gd") as GDScript
	if EnemyScript:
		var enemy: CharacterBody2D = CharacterBody2D.new()
		enemy.set_script(EnemyScript)
		enemy.set_meta("is_pirate", true)
		_world_ref.add_child(enemy)
		enemy.global_position = pos
		enemy.add_to_group("enemies")
		# Override GhostEnemy defaults after _ready() runs
		enemy.max_health = 40
		enemy.current_health = 40
		enemy.damage = 8
		enemy.speed = 70.0
		enemy.set_display_name("Pirate Raider")
		# Replace ghost sprite with pirate raider sprite
		# (enemy.sprite is available after _ready() via @onready var sprite: Sprite2D = $Sprite2D)
		if enemy.sprite:
			var pirate_tex := load("res://assets/generated/pirate_raider_large_frame_0.png")
			if pirate_tex:
				enemy.sprite.texture = pirate_tex
			enemy.sprite.scale = Vector2(0.75, 0.75)  # Match player visual size (24x24)
			enemy.sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
			# Remove ghostly PointLight2D
			for child in enemy.get_children():
				if child is PointLight2D:
					child.queue_free()
					break
		# Pirates collide with terrain like normal enemies
		enemy.collision_mask = 3
		return enemy
	return null

func _on_raid_victory() -> void:
	state = RaidState.COOLDOWN
	_cooldown_days = 4 + _rng.randi() % 3  # 4-6 day cooldown
	
	# One last taunt from the fleeing pirates
	_show_pirate_dialogue_above_ship(_pick_random_taunt(PIRATE_TAUNTS_WAVE_END))
	
	# Stop periodic taunts
	_stop_taunt_timer()
	
	# Remove the pirate ship
	_remove_pirate_ship()
	
	ToastNotification.show_toast("🏆 RAID DEFEATED! Pirates routed!", ToastNotification.ToastType.SUCCESS, 5.0)
	
	# Reward: gold + pirate-themed loot
	GameManager.add_money(50 + _rng.randi() % 100)
	InventoryManager.add_item("cutlass", 1)
	InventoryManager.add_item("cannonball", 3 + _rng.randi() % 5)
	if _rng.randf() > 0.6:
		InventoryManager.add_item("treasure_map", 1)
	if _rng.randf() > 0.85:
		InventoryManager.add_item("ancient_coin", 1)
	
	# Track objective completion
	var obj_mgr := get_tree().get_first_node_in_group("objective_manager")
	if obj_mgr and obj_mgr.has_method("on_pirate_raid_survived"):
		obj_mgr.on_pirate_raid_survived()
	
	raid_ended.emit(true)

func serialize() -> Dictionary:
	return {
		"state": int(state),
		"cooldown_days": _cooldown_days,
		"days_until_next_raid": _days_until_next_raid,
		"current_wave": current_wave,
		"max_waves": max_waves,
		"enemies_per_wave": enemies_per_wave,
	}

func deserialize(data: Dictionary) -> void:
	if data.has("state"):
		state = data["state"] as int
		# If we load with an active raid state, reset to cooldown
		# (the ship would be gone, so don't leave it stuck)
		if state == RaidState.ACTIVE or state == RaidState.WARNING:
			state = RaidState.COOLDOWN
	if data.has("cooldown_days"):
		_cooldown_days = data["cooldown_days"] as int
	if data.has("days_until_next_raid"):
		_days_until_next_raid = data["days_until_next_raid"] as int
	if data.has("current_wave"):
		current_wave = data["current_wave"] as int
	if data.has("max_waves"):
		max_waves = data["max_waves"] as int
	if data.has("enemies_per_wave"):
		enemies_per_wave = data["enemies_per_wave"] as int


## Public method to force-trigger a raid (used by Creative Panel)
func trigger_raid() -> void:
	if state == RaidState.INACTIVE or state == RaidState.COOLDOWN:
		_start_raid()

func is_raid_active() -> bool:
	return state == RaidState.ACTIVE or state == RaidState.WARNING

func get_status_string() -> String:
	match state:
		RaidState.INACTIVE:
			return "Next raid in %d days" % _days_until_next_raid
		RaidState.WARNING:
			return "🏴‍☠️ RAID INCOMING!"
		RaidState.ACTIVE:
			return "🏴‍☠️ Wave %d/%d" % [current_wave, max_waves]
		RaidState.COOLDOWN:
			return "Recovering... (%d days)" % _cooldown_days
	return ""
