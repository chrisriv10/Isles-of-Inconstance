extends Enemy
class_name BloomingWyrm

## Boss #3 of the Spirit Harvest: a segmented worm with flower petals.
## Summoned by using a Nectar Brew. Burrows, spits poison pools, and uses
## Petal Storm (vortex AOE) and Vine Lash (ground eruption).
## At low HP enters ENRAGED state with faster attacks.

const POISON_DAMAGE: int = 4
const POISON_TICK_INTERVAL: float = 1.5
const BURROW_COOLDOWN: float = 6.0
const POOL_DURATION: float = 8.0

const ENRAGE_HP: float = 0.25

var _burrow_cooldown: float = 0.0
var _is_burrowed: bool = false
var _poison_pools: Array[Dictionary] = []
var _pool_timer: float = 0.0
var _petal_storm_cooldown: float = 0.0
var _vine_lash_cooldown: float = 0.0
var _is_enraged: bool = false


func _init() -> void:
	display_name = "Blooming Wyrm"


func _ready() -> void:
	super()
	max_health = 220
	speed = 40.0
	damage = 12
	attack_cooldown = 1.5
	chase_range = 280.0
	attack_range = 22.0
	current_health = max_health
	display_name = "Blooming Wyrm"
	add_to_group("bosses")
	AudioManager.play_music(AudioManager.Sound.BOSS_MUSIC, 1.0)
	_load_sprite()


func _summon_spawn_effect() -> void:
	_trigger_screen_flash(Color(0.85, 0.3, 0.55, 0.2), 1.0)
	_trigger_screen_shake(5.0, 0.4)
	EffectSpawner.spawn_particles(global_position, Color(0.85, 0.3, 0.55), 30, 40.0)
	EffectSpawner.spawn_particles(global_position, Color(0.3, 0.9, 0.2), 20, 30.0)
	AudioManager.play(AudioManager.Sound.BOSS_ROAR)
	GameManager.broadcast_toast("⚔ The Blooming Wyrm bursts from the ground!", ToastNotification.ToastType.ERROR, 3.0)
	GameManager.broadcast_toast("💀 A Spirit Harvest boss has appeared!", ToastNotification.ToastType.WARNING, 4.0)
	# First-time boss encounter dialogue
	GameManager.try_show_dialogue(
		GameManager.DIALOGUE_FIRST_BOSS_ENCOUNTER + "_blooming_wyrm",
		"A serpent of flowers and vines! Its petals look deadly...",
		3.0
	)


func _load_sprite() -> void:
	if not sprite:
		return
	var tex := load("res://assets/generated/blooming_wyrm_boss_frame_0.png")
	if not tex:
		tex = load("res://assets/sprites/player.png")
	sprite.texture = tex
	sprite.centered = true


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if NetworkManager.is_network_active() and _is_remote:
		return
	
	_burrow_cooldown = maxf(_burrow_cooldown - delta, 0.0)
	_pool_timer += delta
	_petal_storm_cooldown = maxf(_petal_storm_cooldown - delta, 0.0)
	_vine_lash_cooldown = maxf(_vine_lash_cooldown - delta, 0.0)
	
	# Enrage at 25% HP
	var hp_ratio := float(current_health) / float(max_health)
	if not _is_enraged and hp_ratio <= ENRAGE_HP:
		_is_enraged = true
		_enter_enrage()
	
	if _is_burrowed:
		_handle_burrowed(delta)
		return
	
	# Special attacks while not burrowed
	if player_ref and state != State.IDLE:
		var dist := global_position.distance_to(player_ref.global_position)
		
		# Petal Storm — vortex attack at medium range
		if _petal_storm_cooldown <= 0.0 and dist < 100.0 and dist > 30.0:
			_petal_storm_cooldown = 8.0
			_petal_storm()
			return
		
		# Vine Lash — ground eruption under player
		if _vine_lash_cooldown <= 0.0 and dist < 120.0:
			_vine_lash_cooldown = 6.0
			_vine_lash()
			return
	
	# Poison pool (periodic)
	if _pool_timer >= 3.0 and _attack_timer <= 0.0 and player_ref and state != State.IDLE:
		_pool_timer = 0.0
		_spit_poison_pool()
	
	_tick_poison_pools(delta)
	
	# Burrow when hurt or periodically
	if _burrow_cooldown <= 0.0 and not _is_burrowed and state == State.CHASE and player_ref:
		if randf() < 0.02 or hp_ratio < 0.3:
			_start_burrow()
	
	super(delta)


func _handle_burrowed(delta: float) -> void:
	velocity = Vector2.ZERO
	sprite.modulate.a -= delta * 2.0
	_burrow_cooldown -= delta
	if _burrow_cooldown <= 0.0:
		_emerge()


func _enter_enrage() -> void:
	_trigger_screen_flash(Color(0.85, 0.3, 0.55, 0.35), 1.0)
	_trigger_screen_shake(7.0, 0.4)
	attack_cooldown = 0.8  # Faster attacks!
	speed = 55.0
	EffectSpawner.spawn_particles(global_position, Color(0.85, 0.3, 0.55), 25, 30.0)
	EffectSpawner.spawn_particles(global_position, Color(1.0, 0.2, 0.2), 15, 25.0)
	ToastNotification.show_toast("🔥 Blooming Wyrm enters ENRAGED state!", ToastNotification.ToastType.ERROR, 3.0)
	# Flashing sprite to indicate enrage
	var tween := create_tween().set_loops()
	tween.tween_property(sprite, "modulate", Color(1.0, 0.4, 0.6), 0.15)
	tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0), 0.15)


## Petal Storm — creates a vortex of scattering petals around a target point.
## Multiple waves of damage.
func _petal_storm() -> void:
	if not player_ref:
		return
	_trigger_screen_shake(4.0, 0.3)
	var center := player_ref.global_position
	for wave in range(3 if not _is_enraged else 5):
		var radius := 10.0 + wave * 8.0
		for angle_i in range(6):
			var a := (angle_i / 6.0) * TAU + wave * 0.5
			var pos := center + Vector2(cos(a), sin(a)) * radius
			EffectSpawner.spawn_particles(pos, Color(0.85, 0.3, 0.55, 0.7), 3, 5.0)
			EffectSpawner.spawn_particles(pos, Color(0.3, 0.9, 0.2, 0.5), 2, 4.0)
		# Damage if standing near center
		if global_position.distance_to(player_ref.global_position) < 50.0:
			_damage_target(4 if not _is_enraged else 6)
	AudioManager.play(AudioManager.Sound.HIT)
	EffectSpawner.spawn_floating_text("Petal Storm!", center, Color(0.85, 0.3, 0.55))


## Vine Lash — vines burst from the ground at the player's position.
func _vine_lash() -> void:
	if not player_ref:
		return
	_trigger_screen_shake(5.0, 0.2)
	var target := player_ref.global_position
	# Three eruptions in quick succession
	for i in range(3):
		var offset := Vector2(randf_range(-15.0, 15.0), randf_range(-15.0, 15.0))
		var pos := target + offset
		EffectSpawner.spawn_particles(pos, Color(0.6, 0.4, 0.2), 6, 7.0)
		EffectSpawner.spawn_particles(pos, Color(0.3, 0.9, 0.2), 4, 6.0)
	# Damage check
	if global_position.distance_to(player_ref.global_position) < 50.0:
		var dmg := 5 if not _is_enraged else 8
		_damage_target(dmg)
		EffectSpawner.spawn_floating_text("Vine Lash!", player_ref.global_position, Color(0.3, 0.9, 0.2))
	AudioManager.play(AudioManager.Sound.HIT)


func _spit_poison_pool() -> void:
	if not player_ref:
		return
	_attack_timer = 2.0
	var pool_pos := player_ref.global_position + Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0))
	_poison_pools.append({"pos": pool_pos, "timer": POOL_DURATION, "interval": 0.0})
	EffectSpawner.spawn_particles(pool_pos, Color(0.5, 0.9, 0.2), 5, 8.0)
	AudioManager.play(AudioManager.Sound.HIT)
	EffectSpawner.spawn_floating_text("Poison Pool!", pool_pos, Color(0.3, 0.8, 0.2))


func _tick_poison_pools(delta: float) -> void:
	if not player_ref:
		return
	var to_remove: Array[int] = []
	for i in range(_poison_pools.size()):
		var pool = _poison_pools[i]
		pool.timer -= delta
		pool.interval -= delta
		if pool.timer <= 0.0:
			to_remove.append(i)
			continue
		if pool.interval <= 0.0:
			pool.interval = POISON_TICK_INTERVAL
			if player_ref.global_position.distance_to(pool.pos) < 16.0:
				_damage_target(POISON_DAMAGE)
				EffectSpawner.spawn_particles(pool.pos, Color(0.3, 0.9, 0.2), 3, 5.0)
		if randi() % 10 == 0:
			EffectSpawner.spawn_particles(pool.pos, Color(0.3, 0.8, 0.2), 1, 3.0)
	for idx in to_remove:
		_poison_pools.remove_at(idx)


func _start_burrow() -> void:
	_is_burrowed = true
	_burrow_cooldown = 2.5
	EffectSpawner.spawn_particles(global_position, Color(0.6, 0.4, 0.2), 12, 14.0)
	EffectSpawner.spawn_particles(global_position, Color(0.85, 0.3, 0.55), 6, 10.0)
	ToastNotification.show_toast("🐛 Blooming Wyrm burrows underground!", ToastNotification.ToastType.WARNING, 1.5)
	_trigger_screen_shake(3.0, 0.2)


func _emerge() -> void:
	if not player_ref:
		_is_burrowed = false
		return
	var angle := randf_range(0.0, TAU)
	var dist := randf_range(20.0, 50.0)
	global_position = player_ref.global_position + Vector2(cos(angle), sin(angle)) * dist
	_is_burrowed = false
	sprite.modulate.a = 1.0
	_burrow_cooldown = BURROW_COOLDOWN
	_trigger_screen_shake(5.0, 0.25)
	EffectSpawner.spawn_particles(global_position, Color(0.85, 0.3, 0.55), 14, 18.0)
	EffectSpawner.spawn_particles(global_position, Color(0.6, 0.4, 0.2), 10, 16.0)
	AudioManager.play(AudioManager.Sound.BOSS_ROAR)
	ToastNotification.show_toast("🌺 Blooming Wyrm erupts from below!", ToastNotification.ToastType.WARNING, 1.5)


func take_damage(amount: int, _source: Node2D = null, _is_critical: bool = false) -> void:
	if _is_burrowed:
		return
	super(amount)


func _die() -> void:
	_grant_loot_to_killer("wyrms_petal", 1)
	_queue_loot("wyrms_petal", 1)
	_grant_loot_to_killer("everbloom_seed", 1)
	_queue_loot("everbloom_seed", 1)
	var mgr := get_tree().get_first_node_in_group("objective_manager")
	if mgr and mgr.has_method("on_boss_defeated"):
		mgr.on_boss_defeated()
	_trigger_screen_flash(Color(0.85, 0.3, 0.55, 0.3), 1.2)
	_trigger_screen_shake(8.0, 0.5)
	EffectSpawner.spawn_particles(global_position, Color(0.85, 0.3, 0.55), 30, 40.0)
	EffectSpawner.spawn_particles(global_position, Color(0.3, 0.9, 0.2), 20, 32.0)
	EffectSpawner.spawn_particles(global_position, Color(1.0, 0.8, 0.6), 15, 28.0)
	AudioManager.play(AudioManager.Sound.BOSS_DIE)
	ToastNotification.show_toast("The Blooming Wyrm wilts away!", ToastNotification.ToastType.SUCCESS, 3.0)
	ToastNotification.show_toast("💀 " + display_name + " defeated! +500 XP", ToastNotification.ToastType.SUCCESS, 4.0)
	
	# --- Boss defeat cutscene (synced across peers) ---
	GameManager.trigger_boss_defeat_cutscene(2)
	await GameManager.get_tree().create_timer(0.1).timeout
	# Defeat dialogue
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("show_dialogue"):
		player.show_dialogue("The Wyrm wilts... just one more spirit left.", 3.5)
	
	super()


func _get_loot_table() -> Array[Dictionary]:
	return []
