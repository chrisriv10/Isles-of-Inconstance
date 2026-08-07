extends Enemy
class_name HollowStag

## Boss #2 of the Spirit Harvest: a ghostly stag with antlers of golden light.
## Summoned by using a Golden Hay Bale. Very fast, charges, phases, and
## barrages ghostly projectiles. Attacks: Phantom Charge (enhanced dash with
## afterimages), Ethereal Barrage (3 ghost projectiles), Spectral Howl
## (area fear pushback), and Teleport Strike (phase + charge behind player).

const CHARGE_SPEED_MULT: float = 2.5
const CHARGE_DURATION: float = 0.6
const PHASE_INTERVAL: float = 5.0

var _charge_timer: float = 0.0
var _is_charging: bool = false
var _phase_timer: float = 0.0
var _is_phased: bool = false
var _charge_dir: Vector2 = Vector2.ZERO
var _barrage_cooldown: float = 0.0
var _howl_cooldown: float = 0.0
var _afterimage_timer: float = 0.0


func _init() -> void:
	display_name = "Hollow Stag"


func _ready() -> void:
	super()
	max_health = 180
	speed = 80.0
	damage = 18
	attack_cooldown = 1.2
	chase_range = 300.0
	attack_range = 25.0
	current_health = max_health
	display_name = "Hollow Stag"
	add_to_group("bosses")
	AudioManager.play_music(AudioManager.Sound.BOSS_MUSIC, 1.0)
	_load_sprite()


func _summon_spawn_effect() -> void:
	_trigger_screen_flash(Color(1.0, 0.85, 0.3, 0.2), 1.0)
	_trigger_screen_shake(5.0, 0.35)
	EffectSpawner.spawn_particles(global_position, Color(1.0, 0.85, 0.3), 30, 40.0)
	EffectSpawner.spawn_particles(global_position, Color(0.7, 0.7, 1.0), 20, 35.0)
	AudioManager.play(AudioManager.Sound.BOSS_ROAR)
	GameManager.broadcast_toast("⚔ The Hollow Stag materializes from the ether!", ToastNotification.ToastType.ERROR, 3.0)
	GameManager.broadcast_toast("💀 A Spirit Harvest boss has appeared!", ToastNotification.ToastType.WARNING, 4.0)
	# First-time boss encounter dialogue
	GameManager.try_show_dialogue(
		GameManager.DIALOGUE_FIRST_BOSS_ENCOUNTER + "_hollow_stag",
		"A ghostly stag! It moves so fast... I need to watch for its charges!",
		3.0
	)


func _load_sprite() -> void:
	if not sprite:
		return
	var tex := load("res://assets/generated/hollow_stag_boss_frame_0_frame_0.png")
	if not tex:
		tex = load("res://assets/sprites/player.png")
	sprite.texture = tex
	sprite.centered = true


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if NetworkManager.is_network_active() and _is_remote:
		return
	
	_phase_timer += delta
	_barrage_cooldown = maxf(_barrage_cooldown - delta, 0.0)
	_howl_cooldown = maxf(_howl_cooldown - delta, 0.0)
	
	if _is_phased:
		_handle_phased_state(delta)
		return
	
	if _is_charging:
		_handle_charge_state(delta)
		return
	
	# Phase out periodically
	if _phase_timer >= PHASE_INTERVAL and not _is_phased and state != State.DEAD:
		_phase_timer = 0.0
		_start_phase()
		return
	
	# Range attacks while not in charge state
	if player_ref and state != State.IDLE:
		var dist := global_position.distance_to(player_ref.global_position)
		# Ethereal Barrage — fire at medium range
		if _barrage_cooldown <= 0.0 and dist < 140.0 and dist > 50.0 and _attack_timer <= 0.0:
			_barrage_cooldown = 4.0
			_ethereal_barrage()
			_attack_timer = 0.8
			return
		# Spectral Howl — close range area pushback
		if _howl_cooldown <= 0.0 and dist < 60.0:
			_howl_cooldown = 7.0
			_spectral_howl()
			return
	
	# Start charge when entering melee attack range
	if state == State.ATTACK and not _is_charging and _attack_timer <= 0.0 and player_ref:
		_is_charging = true
		_charge_timer = CHARGE_DURATION
		_charge_dir = Enemy._safe_normalize(player_ref.global_position - global_position)
		speed = speed * CHARGE_SPEED_MULT
		_attack_timer = attack_cooldown
	
	super(delta)


func _handle_charge_state(delta: float) -> void:
	_charge_timer -= delta
	# Afterimage trail
	_afterimage_timer += delta
	if _afterimage_timer >= 0.06:
		_afterimage_timer = 0.0
		EffectSpawner.spawn_particles(global_position, Color(1.0, 0.85, 0.3, 0.3), 2, 4.0)
	
	if _charge_timer <= 0.0:
		_is_charging = false
		speed = 80.0
		return
	
	if not player_ref:
		_is_charging = false
		return
	
	velocity = _charge_dir * speed * CHARGE_SPEED_MULT
	move_and_slide()
	if global_position.distance_to(player_ref.global_position) < attack_range:
		_damage_target(damage)
		_trigger_screen_shake(4.0, 0.15)
		EffectSpawner.spawn_particles(player_ref.global_position, Color(1.0, 0.8, 0.2), 8, 12.0)
		EffectSpawner.spawn_floating_text("Gore!", player_ref.global_position, Color(1.0, 0.85, 0.3))
		_broadcast_boss_effect(BossEffect.BURST, player_ref.global_position,
			Color(1.0, 0.8, 0.2), Color.TRANSPARENT, Color.TRANSPARENT)
		_broadcast_boss_effect(BossEffect.FLOATING_TEXT, player_ref.global_position,
			Color(1.0, 0.85, 0.3), Color.TRANSPARENT, Color.TRANSPARENT,
			"Gore!")
		_is_charging = false
		speed = 80.0


func _handle_phased_state(delta: float) -> void:
	_phase_timer += delta
	if _phase_timer >= 1.0 and player_ref:
		_is_phased = false
		var behind_dir := -Enemy._safe_normalize(global_position - player_ref.global_position)
		if behind_dir == Vector2.ZERO:
			behind_dir = Vector2.UP
		global_position = player_ref.global_position + behind_dir * 30.0
		sprite.modulate = Color(0.85, 0.85, 1.0, 0.8)
		_trigger_screen_shake(3.0, 0.1)
		EffectSpawner.spawn_particles(global_position, Color(1.0, 0.85, 0.3), 8, 14.0)
		EffectSpawner.spawn_floating_text("Surprise!", player_ref.global_position, Color(0.85, 0.85, 1.0))
		# Mirror the teleport burst on clients.
		_broadcast_boss_effect(BossEffect.BURST, global_position,
			Color(1.0, 0.85, 0.3), Color.TRANSPARENT, Color.TRANSPARENT)
		_broadcast_boss_effect(BossEffect.FLOATING_TEXT, player_ref.global_position,
			Color(0.85, 0.85, 1.0), Color.TRANSPARENT, Color.TRANSPARENT,
			"Surprise!")
		# Immediate charge after teleport
		_is_charging = true
		_charge_timer = 0.4
		_charge_dir = behind_dir
		speed = speed * CHARGE_SPEED_MULT
		_phase_timer = 0.0


func _start_phase() -> void:
	_is_phased = true
	_phase_timer = 0.0
	sprite.modulate = Color(0.85, 0.85, 1.0, 0.1)
	velocity = Vector2.ZERO
	EffectSpawner.spawn_particles(global_position, Color(1.0, 0.85, 0.3), 10, 16.0)
	EffectSpawner.spawn_particles(global_position, Color(0.7, 0.7, 1.0), 6, 12.0)
	ToastNotification.show_toast("💨 Hollow Stag fades into the shadows!", ToastNotification.ToastType.WARNING, 1.5)
	_broadcast_boss_effect(BossEffect.BURST, global_position,
		Color(1.0, 0.85, 0.3), Color(0.7, 0.7, 1.0), Color.TRANSPARENT)


## Ethereal Barrage — fires 3 ghostly projectiles in an arc toward the player.
func _ethereal_barrage() -> void:
	if not player_ref:
		return
	var base_dir := Enemy._safe_normalize(player_ref.global_position - global_position)
	for i in range(3):
		var spread := (i - 1.0) * 0.25
		var shot_dir := Vector2(
			base_dir.x * cos(spread) - base_dir.y * sin(spread),
			base_dir.x * sin(spread) + base_dir.y * cos(spread)
		)
		for j in range(4):
			var trail_pos := global_position + shot_dir * (15.0 + j * 15.0) + Vector2(randf_range(-4.0, 4.0), randf_range(-4.0, 4.0))
			EffectSpawner.spawn_particles(trail_pos, Color(0.85, 0.85, 1.0, 0.6), 2, 4.0)
			EffectSpawner.spawn_particles(trail_pos, Color(1.0, 0.85, 0.3, 0.4), 1, 3.0)
	# Damage check near player
	if global_position.distance_to(player_ref.global_position) < 130.0:
		_damage_target(7)
		EffectSpawner.spawn_floating_text("Ghost Barrage!", player_ref.global_position, Color(0.85, 0.85, 1.0))
		_broadcast_boss_effect(BossEffect.FLOATING_TEXT, player_ref.global_position,
			Color(0.85, 0.85, 1.0), Color.TRANSPARENT, Color.TRANSPARENT,
			"Ghost Barrage!")
	_broadcast_boss_effect(BossEffect.BURST, player_ref.global_position,
		Color(0.85, 0.85, 1.0), Color(1.0, 0.85, 0.3), Color.TRANSPARENT)
	AudioManager.play(AudioManager.Sound.HIT)
	_trigger_screen_shake(2.0, 0.1)


## Spectral Howl — area fear effect pushing the player back with ghostly energy.
func _spectral_howl() -> void:
	if not player_ref:
		return
	_trigger_screen_shake(5.0, 0.25)
	_trigger_screen_flash(Color(0.85, 0.85, 1.0, 0.15), 0.5)
	# Expanding ring of ghostly particles
	for ring in range(4):
		var r := 10.0 + ring * 10.0
		for angle_i in range(8):
			var a := (angle_i / 8.0) * TAU
			var p := global_position + Vector2(cos(a), sin(a)) * r
			EffectSpawner.spawn_particles(p, Color(0.7, 0.7, 1.0, 0.5), 2, 4.0)
	# Push player away
	if global_position.distance_to(player_ref.global_position) < 70.0:
		_damage_target(6)
		# Visual-only push effect (no physics knockback)
		_trigger_screen_shake(6.0, 0.3)
		EffectSpawner.spawn_floating_text("Spectral Howl!", player_ref.global_position, Color(0.7, 0.7, 1.0))
		_broadcast_boss_effect(BossEffect.FLOATING_TEXT, player_ref.global_position,
			Color(0.7, 0.7, 1.0), Color.TRANSPARENT, Color.TRANSPARENT,
			"Spectral Howl!")
	_broadcast_boss_effect(BossEffect.BURST, global_position,
		Color(0.7, 0.7, 1.0), Color.TRANSPARENT, Color.TRANSPARENT)
	_broadcast_boss_effect(BossEffect.FLASH, global_position,
		Color(0.85, 0.85, 1.0, 0.15), Color.TRANSPARENT, Color.TRANSPARENT,
		"", 0.0, 0.5)
	AudioManager.play(AudioManager.Sound.BOSS_ROAR)


func _die() -> void:
	_grant_loot_to_killer("stags_essence", 1)
	_queue_loot("stags_essence", 1)
	_grant_loot_to_killer("mythril_ingot", 1)
	_queue_loot("mythril_ingot", 1)
	var mgr := get_tree().get_first_node_in_group("objective_manager")
	if mgr and mgr.has_method("on_boss_defeated"):
		mgr.on_boss_defeated()
	_trigger_screen_flash(Color(1.0, 0.85, 0.3, 0.3), 1.0)
	_trigger_screen_shake(7.0, 0.5)
	EffectSpawner.spawn_particles(global_position, Color(1.0, 0.85, 0.3), 30, 40.0)
	EffectSpawner.spawn_particles(global_position, Color(0.7, 0.7, 1.0), 20, 32.0)
	EffectSpawner.spawn_particles(global_position, Color(1.0, 1.0, 1.0), 15, 28.0)
	AudioManager.play(AudioManager.Sound.BOSS_DIE)
	# Mirror the death explosion on clients' remote copies.
	_broadcast_enemy_rpc("_sync_boss_death", [enemy_id, Color(1.0, 0.85, 0.3), Color(0.7, 0.7, 1.0), Color(1.0, 1.0, 1.0)], true)
	ToastNotification.show_toast("The Hollow Stag fades into pure light!", ToastNotification.ToastType.SUCCESS, 3.0)
	ToastNotification.show_toast("💀 " + display_name + " defeated! +500 XP", ToastNotification.ToastType.SUCCESS, 4.0)
	
	# --- Boss defeat cutscene (synced across peers) ---
	GameManager.trigger_boss_defeat_cutscene(1)
	await GameManager.get_tree().create_timer(0.1).timeout
	# Defeat dialogue
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("show_dialogue"):
		player.show_dialogue("The Stag's essence is mine. Two down, two to go...", 3.5)
	
	super()


func _get_loot_table() -> Array[Dictionary]:
	return []
