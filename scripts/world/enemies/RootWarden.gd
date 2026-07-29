extends Enemy
class_name RootWarden

## Boss #1 of the Spirit Harvest: a hulking mass of twisted roots with a
## glowing purple core. Summoned by using a Soulberry Pie in the hotbar.
## Attacks: Root Grasp (slow + damage), Earth Spike (line AOE),
## Vine Whip (ranged slash), AoE Slam (melee burst), Sporeling minions at 50% HP.

const MINION_SPAWN_HP: float = 0.5
const AOE_RANGE: float = 40.0
const AOE_DAMAGE: int = 8

var _has_spawned_minions: bool = false
var _aoe_cooldown: float = 0.0
var _root_grasp_cooldown: float = 0.0
var _vine_whip_cooldown: float = 0.0
var _earth_spike_cooldown: float = 0.0


func _init() -> void:
	display_name = "Root Warden"


func _ready() -> void:
	super()
	max_health = 200
	speed = 25.0
	damage = 15
	attack_cooldown = 1.8
	chase_range = 250.0
	attack_range = 30.0
	current_health = max_health
	display_name = "Root Warden"
	add_to_group("bosses")
	_load_sprite()


func _load_sprite() -> void:
	if not sprite:
		return
	var tex := load("res://assets/generated/root_warden_boss_frame_0.png")
	if not tex:
		tex = load("res://assets/sprites/player.png")
	sprite.texture = tex
	sprite.centered = true
	sprite.scale = Vector2(0.25, 0.25)


func _summon_spawn_effect() -> void:
	_trigger_screen_flash(Color(0.5, 0.0, 0.5, 0.25), 1.0)
	_trigger_screen_shake(6.0, 0.4)
	EffectSpawner.spawn_particles(global_position, Color(0.55, 0.2, 0.7), 30, 40.0)
	EffectSpawner.spawn_particles(global_position, Color(0.3, 0.15, 0.05), 20, 35.0)
	AudioManager.play(AudioManager.Sound.BOSS_ROAR)
	ToastNotification.show_toast("⚔ The Root Warden rises from the earth!", ToastNotification.ToastType.ERROR, 3.0)
	ToastNotification.show_toast("💀 A Spirit Harvest boss has appeared!", ToastNotification.ToastType.WARNING, 4.0)
	# First-time boss encounter dialogue
	GameManager.try_show_dialogue(
		GameManager.DIALOGUE_FIRST_BOSS_ENCOUNTER + "_root_warden",
		"That thing is HUGE! I need to watch its root attacks...",
		3.0
	)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	
	_aoe_cooldown = maxf(_aoe_cooldown - delta, 0.0)
	_root_grasp_cooldown = maxf(_root_grasp_cooldown - delta, 0.0)
	_vine_whip_cooldown = maxf(_vine_whip_cooldown - delta, 0.0)
	_earth_spike_cooldown = maxf(_earth_spike_cooldown - delta, 0.0)
	
	if not _has_spawned_minions and float(current_health) / float(max_health) <= MINION_SPAWN_HP:
		_has_spawned_minions = true
		_summon_minions()
	
	if player_ref and state != State.IDLE:
		var dist := global_position.distance_to(player_ref.global_position)
		if _root_grasp_cooldown <= 0.0 and dist < 100.0 and dist > 30.0:
			_root_grasp_cooldown = 5.0
			_root_grasp()
			return
		if _vine_whip_cooldown <= 0.0 and dist < 120.0 and dist > 40.0:
			_vine_whip_cooldown = 6.0
			_vine_whip()
			return
		if _earth_spike_cooldown <= 0.0 and dist > 30.0:
			_earth_spike_cooldown = 7.0
			_earth_spike()
			return
	
	if state == State.ATTACK and _aoe_cooldown <= 0.0 and player_ref:
		if global_position.distance_to(player_ref.global_position) <= AOE_RANGE:
			_aoe_cooldown = 4.0
			_aoe_slam()
	
	super(delta)


## Root Grasp — sends root tendrils toward the player, damaging and slowing.
func _root_grasp() -> void:
	if not player_ref:
		return
	var dir := Enemy._safe_normalize(player_ref.global_position - global_position)
	for i in range(6):
		var offset := Vector2(randf_range(-8.0, 8.0), randf_range(-8.0, 8.0))
		var spawn_pos := global_position + dir * (10.0 + i * 6.0) + offset
		EffectSpawner.spawn_particles(spawn_pos, Color(0.4, 0.2, 0.05), 3, 4.0)
	if global_position.distance_to(player_ref.global_position) < 90.0:
		GameManager.take_damage(5)
		EffectSpawner.spawn_floating_text("Roots Grab You!", player_ref.global_position, Color(0.6, 0.3, 0.1))
	AudioManager.play(AudioManager.Sound.HIT)
	_trigger_screen_shake(2.0, 0.1)


## Earth Spike — erupts spikes at the player's position.
func _earth_spike() -> void:
	if not player_ref:
		return
	_trigger_screen_shake(4.0, 0.2)
	var target := player_ref.global_position
	for i in range(3):
		var spike_pos := target + Vector2(randf_range(-12.0, 12.0), randf_range(-12.0, 12.0))
		EffectSpawner.spawn_particles(spike_pos, Color(0.5, 0.3, 0.1), 8, 6.0)
		EffectSpawner.spawn_particles(spike_pos, Color(0.55, 0.2, 0.7), 4, 5.0)
	if global_position.distance_to(player_ref.global_position) < 60.0:
		GameManager.take_damage(7)
		EffectSpawner.spawn_floating_text("Earth Spike!", player_ref.global_position, Color(0.8, 0.5, 0.1))
	AudioManager.play(AudioManager.Sound.HIT)


## Vine Whip — long-range sweeping vine slash.
func _vine_whip() -> void:
	if not player_ref:
		return
	var dir := Enemy._safe_normalize(player_ref.global_position - global_position)
	var perp := Vector2(-dir.y, dir.x)
	for i in range(5):
		var t := (i / 4.0) - 0.5
		var sweep_pos := global_position + dir * 40.0 + perp * t * 25.0
		EffectSpawner.spawn_particles(sweep_pos, Color(0.3, 0.6, 0.15), 4, 5.0)
		EffectSpawner.spawn_particles(sweep_pos, Color(0.55, 0.2, 0.7), 2, 4.0)
	if global_position.distance_to(player_ref.global_position) < 90.0:
		GameManager.take_damage(8)
		EffectSpawner.spawn_floating_text("Vine Whip!", player_ref.global_position, Color(0.3, 0.7, 0.2))
	AudioManager.play(AudioManager.Sound.HIT)
	_trigger_screen_shake(3.0, 0.1)


func _aoe_slam() -> void:
	if not player_ref:
		return
	EffectSpawner.spawn_particles(global_position, Color(0.5, 0.25, 0.1), 10, 14.0)
	AudioManager.play(AudioManager.Sound.HIT)
	_trigger_screen_shake(4.0, 0.15)
	if global_position.distance_to(player_ref.global_position) <= AOE_RANGE:
		GameManager.take_damage(AOE_DAMAGE)
		EffectSpawner.spawn_floating_text("Slam!", player_ref.global_position, Color(0.8, 0.4, 0.1))


func _summon_minions() -> void:
	_trigger_screen_shake(5.0, 0.3)
	EffectSpawner.spawn_particles(global_position, Color(0.5, 0.0, 0.5), 20, 24.0)
	EffectSpawner.spawn_particles(global_position, Color(0.3, 0.15, 0.05), 12, 20.0)
	AudioManager.play(AudioManager.Sound.BOSS_ROAR)
	ToastNotification.show_toast("🌱 The Root Warden summons Sporelings!", ToastNotification.ToastType.WARNING, 2.5)
	for i in range(2):
		var sporeling = load("res://scripts/world/enemies/SporelingEnemy.gd").new()
		var offset: Vector2 = Vector2(randf_range(-30.0, 30.0), randf_range(-30.0, 30.0))
		sporeling.global_position = global_position + offset
		get_parent().add_child(sporeling)


func _die() -> void:
	InventoryManager.add_item("wardens_core", 1)
	InventoryManager.add_item("evergrowth_seed", 1)
	var mgr := get_tree().get_first_node_in_group("objective_manager")
	if mgr and mgr.has_method("on_boss_defeated"):
		mgr.on_boss_defeated()
	_trigger_screen_flash(Color(0.55, 0.2, 0.7, 0.35), 1.2)
	_trigger_screen_shake(8.0, 0.5)
	EffectSpawner.spawn_particles(global_position, Color(0.55, 0.2, 0.7), 30, 40.0)
	EffectSpawner.spawn_particles(global_position, Color(0.5, 0.25, 0.1), 20, 35.0)
	EffectSpawner.spawn_particles(global_position, Color(0.2, 0.8, 0.2), 12, 25.0)
	AudioManager.play(AudioManager.Sound.BOSS_DIE)
	ToastNotification.show_toast("The Root Warden crumbles into dust!", ToastNotification.ToastType.SUCCESS, 3.0)
	ToastNotification.show_toast("💀 " + display_name + " defeated! +500 XP", ToastNotification.ToastType.SUCCESS, 4.0)
	
	# --- Boss defeat cutscene ---
	var cutscene := BossDefeatCutscene.play(0)
	await cutscene.finished
	# Defeat dialogue
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("show_dialogue"):
		player.show_dialogue("The Root Warden is down... but I feel like this is only the beginning.", 3.5)
	
	super()


func _get_loot_table() -> Array[Dictionary]:
	return []
