extends Enemy
class_name InconstantSoul

## Final boss of the Spirit Harvest. A swirling soul entity with tendrils that
## cycles through three phases, each with unique attacks. Requires Essence
## of Inconstance to summon. Each phase has 3 unique abilities.

enum HeartPhase { ROOT, STAG, WYRM }

const PHASE_HEALTH_1: float = 0.66
const PHASE_HEALTH_2: float = 0.33

# ROOT phase cooldowns
var _pulse_cooldown: float = 0.0
var _tendril_cooldown: float = 0.0
var _drain_cooldown: float = 0.0

# STAG phase cooldowns
var _sunburst_cooldown: float = 0.0
var _lance_cooldown: float = 0.0
var _shield_cooldown: float = 0.0
var _shield_active: bool = false
var _shield_timer: float = 0.0

# WYRM phase cooldowns
var _orb_cooldown: float = 0.0
var _fissure_cooldown: float = 0.0
var _tendril_eruption_cooldown: float = 0.0

# Shared
var _current_phase: int = HeartPhase.ROOT
var _phase_particles_timer: float = 0.0


func _init() -> void:
	display_name = "Inconstant Soul"


func _ready() -> void:
	super()
	max_health = 300
	speed = 55.0
	damage = 20
	attack_cooldown = 1.2
	chase_range = 350.0
	attack_range = 28.0
	current_health = max_health
	display_name = "Inconstant Soul"
	add_to_group("bosses")
	_load_sprite()


func _summon_spawn_effect() -> void:
	_trigger_screen_flash(Color(0.8, 0.15, 0.15, 0.4), 1.5)
	_trigger_screen_shake(10.0, 0.6)
	EffectSpawner.spawn_particles(global_position, Color(0.8, 0.15, 0.15), 40, 50.0)
	EffectSpawner.spawn_particles(global_position, Color(0.5, 0.15, 0.7), 30, 45.0)
	EffectSpawner.spawn_particles(global_position, Color(0.85, 0.7, 0.2), 20, 40.0)
	AudioManager.play(AudioManager.Sound.BOSS_ROAR)
	ToastNotification.show_toast("⚔ THE INCONSTANT SOUL AWAKENS!", ToastNotification.ToastType.ERROR, 4.0)
	ToastNotification.show_toast("💀 The final boss of the Spirit Harvest has appeared!", ToastNotification.ToastType.ERROR, 4.5)
	# First-time boss encounter dialogue
	GameManager.try_show_dialogue(
		GameManager.DIALOGUE_FIRST_BOSS_ENCOUNTER + "_inconstant_soul",
		"This is it... the Inconstant Soul! All four spirits in one! I need to give it everything I've got!",
		4.0
	)


func _load_sprite() -> void:
	if not sprite:
		return
	var tex := load("res://assets/generated/inconstant_soul_boss_3_frame_0.png")
	if not tex:
		tex = load("res://assets/sprites/player.png")
	sprite.texture = tex
	sprite.centered = true
	# The sprite is 128x128 — scale down to ~45px wide (~35%) for a huge, imposing presence.
	# Root Warden uses 25% (32px) — Inconstant Soul is 40% larger, visually dominant.
	sprite.scale = Vector2(0.35, 0.35)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if NetworkManager.is_network_active() and _is_remote:
		return
	
	var hp_ratio := float(current_health) / float(max_health)
	if hp_ratio <= PHASE_HEALTH_2:
		_set_phase(HeartPhase.WYRM)
	elif hp_ratio <= PHASE_HEALTH_1:
		_set_phase(HeartPhase.STAG)
	else:
		_set_phase(HeartPhase.ROOT)
	
	match _current_phase:
		HeartPhase.ROOT:
			_do_root_phase(delta)
		HeartPhase.STAG:
			_do_stag_phase(delta)
		HeartPhase.WYRM:
			_do_wyrm_phase(delta)
	
	_phase_particles_timer += delta
	if _phase_particles_timer >= 2.0:
		_phase_particles_timer = 0.0
		var colors := [Color(0.5, 0.15, 0.7), Color(0.85, 0.7, 0.2), Color(0.8, 0.3, 0.55)]
		EffectSpawner.spawn_particles(global_position, colors[randi() % 3], 3, 8.0)
	
	super(delta)


func _set_phase(phase: int) -> void:
	if _current_phase == phase:
		return
	_current_phase = phase
	_trigger_screen_flash(Color(1.0, 1.0, 1.0, 0.3), 0.8)
	_trigger_screen_shake(6.0, 0.3)
	var phase_colors: Dictionary = {
		HeartPhase.ROOT: Color(0.5, 0.15, 0.7),
		HeartPhase.STAG: Color(0.85, 0.7, 0.2),
		HeartPhase.WYRM: Color(0.85, 0.3, 0.55),
	}
	var color: Color = phase_colors.get(phase, Color.WHITE)
	EffectSpawner.spawn_particles(global_position, color, 20, 24.0)
	EffectSpawner.spawn_particles(global_position, Color(1.0, 1.0, 1.0), 12, 20.0)
	AudioManager.play(AudioManager.Sound.BOSS_ROAR)
	match phase:
		HeartPhase.ROOT:
			ToastNotification.show_toast("🔄 Phase Shift: Root of Inconstance!", ToastNotification.ToastType.WARNING, 2.5)
		HeartPhase.STAG:
			ToastNotification.show_toast("🔄 Phase Shift: Stag of Inconstance!", ToastNotification.ToastType.WARNING, 2.5)
		HeartPhase.WYRM:
			ToastNotification.show_toast("🔄 Phase Shift: Wyrm of Inconstance!", ToastNotification.ToastType.WARNING, 2.5)


# ─── ROOT PHASE: Tendrils, Pulses, and Life Drain ──────────────────────

func _do_root_phase(delta: float) -> void:
	_pulse_cooldown = maxf(_pulse_cooldown - delta, 0.0)
	_tendril_cooldown = maxf(_tendril_cooldown - delta, 0.0)
	_drain_cooldown = maxf(_drain_cooldown - delta, 0.0)
	
	if not player_ref or state == State.IDLE:
		return
	
	var dist := global_position.distance_to(player_ref.global_position)
	
	# Heart Pulse: expanding ring of purple energy
	if _pulse_cooldown <= 0.0 and dist < 80.0:
		_pulse_cooldown = 4.0
		_heart_pulse()
		return
	
	# Tendril Sweep: tendrils arc across in front of boss
	if _tendril_cooldown <= 0.0 and dist < 70.0:
		_tendril_cooldown = 5.0
		_tendril_sweep()
		return
	
	# Soul Drain: purple tendrils shoot out, damage + heal boss
	if _drain_cooldown <= 0.0 and dist < 100.0:
		_drain_cooldown = 7.0
		_soul_drain()
		return


## Heart Pulse — expanding ring of purple energy that damages in a radius.
func _heart_pulse() -> void:
	if not player_ref:
		return
	_trigger_screen_shake(4.0, 0.2)
	# Three expanding rings
	for ring in range(3):
		var r := 15.0 + ring * 12.0
		for angle_i in range(8):
			var a := (angle_i / 8.0) * TAU
			var p := global_position + Vector2(cos(a), sin(a)) * r
			EffectSpawner.spawn_particles(p, Color(0.5, 0.15, 0.7, 0.6), 3, 5.0)
	if global_position.distance_to(player_ref.global_position) < 60.0:
		GameManager.take_damage(8)
		EffectSpawner.spawn_floating_text("Heart Pulse!", player_ref.global_position, Color(0.5, 0.15, 0.7))
	AudioManager.play(AudioManager.Sound.HIT)


## Tendril Sweep — three tendrils sweep in an arc in front of the boss.
func _tendril_sweep() -> void:
	if not player_ref:
		return
	var dir := Enemy._safe_normalize(player_ref.global_position - global_position)
	_trigger_screen_shake(3.0, 0.15)
	for t in range(3):
		var sweep := (t - 1.0) * 0.3
		for i in range(4):
			var d := 10.0 + i * 10.0
			var sweep_dir := Vector2(
				dir.x * cos(sweep) - dir.y * sin(sweep),
				dir.x * sin(sweep) + dir.y * cos(sweep)
			)
			var p := global_position + sweep_dir * d
			EffectSpawner.spawn_particles(p, Color(0.5, 0.15, 0.7), 4, 5.0)
			EffectSpawner.spawn_particles(p, Color(0.3, 0.15, 0.05), 2, 4.0)
	if global_position.distance_to(player_ref.global_position) < 65.0:
		GameManager.take_damage(7)
		EffectSpawner.spawn_floating_text("Tendril Sweep!", player_ref.global_position, Color(0.5, 0.15, 0.7))
	AudioManager.play(AudioManager.Sound.HIT)


## Soul Drain — purple tendrils drain life from the player, healing the boss.
func _soul_drain() -> void:
	if not player_ref:
		return
	_trigger_screen_shake(4.0, 0.3)
	# Line of particles from boss toward player
	var dir := Enemy._safe_normalize(player_ref.global_position - global_position)
	for i in range(6):
		var p := global_position + dir * (10.0 + i * 8.0) + Vector2(randf_range(-5.0, 5.0), randf_range(-5.0, 5.0))
		EffectSpawner.spawn_particles(p, Color(0.5, 0.15, 0.7, 0.8), 4, 5.0)
		EffectSpawner.spawn_particles(p, Color(0.8, 0.15, 0.15, 0.6), 2, 4.0)
	# Damage player + heal boss
	if global_position.distance_to(player_ref.global_position) < 80.0:
		GameManager.take_damage(9)
		current_health = mini(current_health + 5, max_health)
		_update_health_bar()
		EffectSpawner.spawn_particles(global_position, Color(0.5, 0.15, 0.7), 8, 10.0)
		EffectSpawner.spawn_floating_text("Soul Drain!", player_ref.global_position, Color(0.8, 0.15, 0.15))
	AudioManager.play(AudioManager.Sound.HIT)


# ─── STAG PHASE: Light Beams, Shields, and Radiant Bursts ─────────────

func _do_stag_phase(delta: float) -> void:
	_sunburst_cooldown = maxf(_sunburst_cooldown - delta, 0.0)
	_lance_cooldown = maxf(_lance_cooldown - delta, 0.0)
	_shield_cooldown = maxf(_shield_cooldown - delta, 0.0)
	
	if not player_ref or state == State.IDLE:
		return
	
	# Radiant Shield — temporary invulnerability
	if _shield_cooldown <= 0.0 and not _shield_active and state == State.ATTACK:
		_shield_cooldown = 10.0
		_radiant_shield()
		return
	
	if _shield_active:
		_shield_timer -= delta
		_trigger_screen_flash(Color(0.85, 0.7, 0.2, 0.1), 0.1)
		if _shield_timer <= 0.0:
			_shield_active = false
			_shield_explode()
		return
	
	var dist := global_position.distance_to(player_ref.global_position)
	
	# Sunburst — emit radial burst of golden light
	if _sunburst_cooldown <= 0.0 and dist < 70.0:
		_sunburst_cooldown = 5.0
		_sunburst()
		return
	
	# Light Lances — three beams of light in succession
	if _lance_cooldown <= 0.0 and dist < 120.0:
		_lance_cooldown = 4.0
		_light_lances()
		return


## Sunburst — emits a burst of golden light in all directions.
func _sunburst() -> void:
	if not player_ref:
		return
	_trigger_screen_shake(5.0, 0.2)
	for ring in range(4):
		var r := 10.0 + ring * 8.0
		for angle_i in range(6):
			var a := (angle_i / 6.0) * TAU + ring * 0.5
			var p := global_position + Vector2(cos(a), sin(a)) * r
			EffectSpawner.spawn_particles(p, Color(1.0, 0.85, 0.3, 0.7), 3, 5.0)
			EffectSpawner.spawn_particles(p, Color(1.0, 1.0, 1.0, 0.4), 2, 4.0)
	if global_position.distance_to(player_ref.global_position) < 55.0:
		GameManager.take_damage(8)
		EffectSpawner.spawn_floating_text("Sunburst!", player_ref.global_position, Color(1.0, 0.85, 0.3))
	AudioManager.play(AudioManager.Sound.HIT)


## Light Lances — three beams of light fire toward the player.
func _light_lances() -> void:
	if not player_ref:
		return
	var base_dir := Enemy._safe_normalize(player_ref.global_position - global_position)
	for i in range(3):
		var spread := (i - 1.0) * 0.3
		var shot_dir := Vector2(
			base_dir.x * cos(spread) - base_dir.y * sin(spread),
			base_dir.x * sin(spread) + base_dir.y * cos(spread)
		)
		for j in range(5):
			var p := global_position + shot_dir * (10.0 + j * 10.0) + Vector2(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0))
			EffectSpawner.spawn_particles(p, Color(1.0, 0.85, 0.3, 0.8), 2, 5.0)
			EffectSpawner.spawn_particles(p, Color(1.0, 1.0, 1.0, 0.5), 1, 3.0)
	if global_position.distance_to(player_ref.global_position) < 110.0:
		GameManager.take_damage(7)
		EffectSpawner.spawn_floating_text("Light Lance!", player_ref.global_position, Color(1.0, 0.85, 0.3))
	AudioManager.play(AudioManager.Sound.HIT)
	_trigger_screen_shake(2.0, 0.1)


## Radiant Shield — brief invulnerability + damaging light pulse.
func _radiant_shield() -> void:
	_shield_active = true
	_shield_timer = 2.0
	_trigger_screen_flash(Color(1.0, 0.85, 0.3, 0.2), 0.5)
	EffectSpawner.spawn_particles(global_position, Color(1.0, 0.85, 0.3), 15, 20.0)
	ToastNotification.show_toast("🛡️ Inconstant Soul becomes invulnerable!", ToastNotification.ToastType.WARNING, 1.5)


func _shield_explode() -> void:
	if player_ref:
		_trigger_screen_shake(5.0, 0.3)
		for ring in range(5):
			var r := 10.0 + ring * 10.0
			for angle_i in range(8):
				var a := (angle_i / 8.0) * TAU
				var p := global_position + Vector2(cos(a), sin(a)) * r
				EffectSpawner.spawn_particles(p, Color(1.0, 0.85, 0.3), 3, 5.0)
				EffectSpawner.spawn_particles(p, Color(1.0, 1.0, 1.0), 2, 4.0)
		if global_position.distance_to(player_ref.global_position) < 70.0:
			GameManager.take_damage(10)
			EffectSpawner.spawn_floating_text("Shield Burst!", player_ref.global_position, Color(1.0, 0.85, 0.3))
		AudioManager.play(AudioManager.Sound.HIT)


func take_damage(amount: int, _source: Node2D = null, _is_critical: bool = false) -> void:
	if _shield_active:
		return  # Immune during shield
	super(amount)


# ─── WYRM PHASE: Chaos Orbs, Ground Fissure, Tendril Eruption ─────────

func _do_wyrm_phase(delta: float) -> void:
	_orb_cooldown = maxf(_orb_cooldown - delta, 0.0)
	_fissure_cooldown = maxf(_fissure_cooldown - delta, 0.0)
	_tendril_eruption_cooldown = maxf(_tendril_eruption_cooldown - delta, 0.0)
	
	if not player_ref or state == State.IDLE:
		return
	
	var dist := global_position.distance_to(player_ref.global_position)
	
	# Chaos Orbs — 3 orbs orbit the boss and strike out
	if _orb_cooldown <= 0.0:
		_orb_cooldown = 6.0
		_chaos_orbs()
		return
	
	# Ground Fissure — cracks in the ground toward the player
	if _fissure_cooldown <= 0.0 and dist < 110.0:
		_fissure_cooldown = 5.0
		_ground_fissure()
		return
	
	# Tendril Eruption — multiple tendrils burst around boss
	if _tendril_eruption_cooldown <= 0.0 and dist < 60.0:
		_tendril_eruption_cooldown = 7.0
		_tendril_eruption()
		return


## Chaos Orbs — 3 slow-moving orbs orbit the boss and strike at player.
func _chaos_orbs() -> void:
	if not player_ref:
		return
	_trigger_screen_shake(4.0, 0.3)
	var dir := Enemy._safe_normalize(player_ref.global_position - global_position)
	for i in range(3):
		var spread := (i - 1.0) * 0.4
		var shot_dir := Vector2(
			dir.x * cos(spread) - dir.y * sin(spread),
			dir.x * sin(spread) + dir.y * cos(spread)
		)
		for j in range(4):
			var p := global_position + shot_dir * (12.0 + j * 10.0) + Vector2(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0))
			EffectSpawner.spawn_particles(p, Color(0.85, 0.3, 0.55, 0.8), 4, 6.0)
			EffectSpawner.spawn_particles(p, Color(0.8, 0.15, 0.15, 0.5), 2, 5.0)
	if global_position.distance_to(player_ref.global_position) < 90.0:
		var dmg := 6
		GameManager.take_damage(dmg)
		EffectSpawner.spawn_floating_text("Chaos Orb!", player_ref.global_position, Color(0.85, 0.3, 0.55))
	AudioManager.play(AudioManager.Sound.HIT)


## Ground Fissure — cracks in the ground erupt toward the player in a line.
func _ground_fissure() -> void:
	if not player_ref:
		return
	_trigger_screen_shake(6.0, 0.25)
	var dir := Enemy._safe_normalize(player_ref.global_position - global_position)
	for i in range(5):
		var p := global_position + dir * (10.0 + i * 12.0) + Vector2(randf_range(-8.0, 8.0), randf_range(-8.0, 8.0))
		EffectSpawner.spawn_particles(p, Color(0.6, 0.4, 0.2), 6, 7.0)
		EffectSpawner.spawn_particles(p, Color(0.85, 0.3, 0.55, 0.5), 3, 5.0)
	if global_position.distance_to(player_ref.global_position) < 80.0:
		var dmg := 8
		GameManager.take_damage(dmg)
		EffectSpawner.spawn_floating_text("Ground Fissure!", player_ref.global_position, Color(0.6, 0.4, 0.2))
	AudioManager.play(AudioManager.Sound.HIT)


## Tendril Eruption — tendrils burst from the ground around the boss.
func _tendril_eruption() -> void:
	_trigger_screen_shake(5.0, 0.2)
	for angle_i in range(8):
		var a := (angle_i / 8.0) * TAU
		for dist_i in range(2):
			var r := 15.0 + dist_i * 12.0
			var p := global_position + Vector2(cos(a), sin(a)) * r
			EffectSpawner.spawn_particles(p, Color(0.5, 0.15, 0.7), 4, 6.0)
			EffectSpawner.spawn_particles(p, Color(0.3, 0.15, 0.05), 2, 5.0)
	# Damage if close
	if player_ref and global_position.distance_to(player_ref.global_position) < 50.0:
		var dmg := 7
		GameManager.take_damage(dmg)
		EffectSpawner.spawn_floating_text("Tendril Eruption!", player_ref.global_position, Color(0.5, 0.15, 0.7))
	AudioManager.play(AudioManager.Sound.HIT)


# ─── DEATH: Ender Dragon Style Cinematic ──────────────────────────────

func _die() -> void:
	# Stop all movement and become invulnerable during death sequence
	state = State.DEAD
	velocity = Vector2.ZERO
	
	# ── Phase 0: Initial explosion ──
	_trigger_screen_flash(Color(1.0, 1.0, 1.0, 0.6), 2.0)
	_trigger_screen_shake(12.0, 1.5)
	EffectSpawner.spawn_particles(global_position, Color(0.8, 0.15, 0.15), 50, 60.0)
	AudioManager.play(AudioManager.Sound.BOSS_DIE)
	
	# ── Phase 1: Expanding purple shockwave ring ──
	await get_tree().create_timer(0.4).timeout
	_trigger_screen_shake(10.0, 1.0)
	for ring in range(5):
		var r := 15.0 + ring * 12.0
		for angle_i in range(12):
			var a := (angle_i / 12.0) * TAU + ring * 0.3
			var p := global_position + Vector2(cos(a), sin(a)) * r
			EffectSpawner.spawn_particles(p, Color(0.5, 0.15, 0.7, 0.8), 4, 8.0)
	
	# ── Phase 2: Expanding gold shockwave ──
	await get_tree().create_timer(0.4).timeout
	_trigger_screen_shake(9.0, 1.0)
	_trigger_screen_flash(Color(0.85, 0.7, 0.2, 0.4), 1.0)
	for ring in range(6):
		var r := 20.0 + ring * 14.0
		for angle_i in range(14):
			var a := (angle_i / 14.0) * TAU - ring * 0.2
			var p := global_position + Vector2(cos(a), sin(a)) * r
			EffectSpawner.spawn_particles(p, Color(1.0, 0.85, 0.3, 0.8), 4, 8.0)
			EffectSpawner.spawn_particles(p, Color(1.0, 1.0, 1.0, 0.5), 2, 6.0)
	
	# ── Phase 3: Ascending white light pillar ──
	await get_tree().create_timer(0.4).timeout
	_trigger_screen_flash(Color(1.0, 1.0, 1.0, 0.5), 1.5)
	# Ascending pillar of light particles
	for i in range(15):
		var p := global_position + Vector2(randf_range(-10.0, 10.0), -i * 6.0)
		EffectSpawner.spawn_particles(p, Color(1.0, 1.0, 1.0, 0.9), 5, 10.0)
		EffectSpawner.spawn_particles(p, Color(1.0, 0.85, 0.3, 0.6), 3, 8.0)
	
	# ── Phase 4: Expanding white light rings (like Ender Dragon XP) ──
	await get_tree().create_timer(0.3).timeout
	_trigger_screen_shake(8.0, 1.5)
	for wave in range(4):
		for ring in range(8):
			var r := 15.0 + ring * 10.0 + wave * 5.0
			for angle_i in range(10):
				var a := (angle_i / 10.0) * TAU + wave * 0.5
				var p := global_position + Vector2(cos(a), sin(a)) * r
				EffectSpawner.spawn_particles(p, Color(1.0, 1.0, 1.0, 0.8), 3, 7.0)
				EffectSpawner.spawn_particles(p, Color(1.0, 0.85, 0.3, 0.5), 2, 5.0)
		await get_tree().create_timer(0.15).timeout
		_trigger_screen_shake(6.0, 0.5)
	
	# ── Phase 5: Golden rain from above ──
	for i in range(20):
		var rain_pos := global_position + Vector2(randf_range(-60.0, 60.0), -30.0 - randf_range(0.0, 20.0))
		EffectSpawner.spawn_particles(rain_pos, Color(1.0, 0.85, 0.3, 0.7), 3, 6.0)
		EffectSpawner.spawn_particles(rain_pos, Color(1.0, 1.0, 1.0, 0.4), 2, 4.0)
	
	# ── Phase 6: Final white-out then fade ──
	await get_tree().create_timer(0.3).timeout
	_trigger_screen_flash(Color(1.0, 1.0, 1.0, 0.8), 3.0)
	_trigger_screen_shake(5.0, 0.5)
	
	# ── Loot & completion ──
	InventoryManager.add_item("soul_of_inconstance", 1)
	_queue_loot("soul_of_inconstance", 1)
	
	var mgr := get_tree().get_first_node_in_group("objective_manager")
	if mgr and mgr.has_method("on_boss_defeated"):
		mgr.on_boss_defeated()
	
	GameManager.complete_game()
	
	ToastNotification.show_toast("💀 " + display_name + " defeated! +1000 XP", ToastNotification.ToastType.SUCCESS, 5.0)
	await get_tree().create_timer(0.5).timeout
	ToastNotification.show_toast("The Inconstant Soul shatters into pure light!", ToastNotification.ToastType.SUCCESS, 4.0)
	await get_tree().create_timer(1.0).timeout
	ToastNotification.show_toast("✨ You have conquered the Isles of Inconstance!", ToastNotification.ToastType.SUCCESS, 6.0)
	
	# --- Final boss defeat cutscene (longest!) ---
	var cutscene := BossDefeatCutscene.play(3)
	await cutscene.finished
	# Final defeat dialogue
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("show_dialogue"):
		player.show_dialogue("It's over... the Isles are free. I did it.", 4.0)
	
	super()


func _get_loot_table() -> Array[Dictionary]:
	return []
