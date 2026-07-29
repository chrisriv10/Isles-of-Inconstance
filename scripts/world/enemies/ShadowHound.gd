extends Enemy
class_name ShadowHound

## A fast, low-to-the-ground shadow beast that hunts in bursts. Has a lunge
## attack that closes distance quickly. Drops shadow hide.

const LUNGE_SPEED_MULT: float = 3.0
const LUNGE_DURATION: float = 0.3
const LUNGE_COOLDOWN: float = 3.0
const LUNGE_RANGE: float = 80.0  # How far away it'll lunge from

var _lunge_timer: float = 0.0
var _is_lunging: bool = false
var _lunge_remaining: float = 0.0
var _lunge_dir: Vector2 = Vector2.ZERO
var _circle_angle: float = 0.0


func _init() -> void:
	var s := Sprite2D.new(); s.name = "Sprite2D"; add_child(s)
	var c := CollisionShape2D.new(); c.name = "CollisionShape2D"; add_child(c)
	c.shape = CircleShape2D.new()
	c.shape.radius = 8.0
	display_name = "Shadow Hound"


func _ready() -> void:
	super()
	max_health = 80
	speed = 60.0
	damage = 14
	attack_cooldown = 1.0
	chase_range = 250.0
	attack_range = 20.0
	current_health = max_health
	display_name = "Shadow Hound"

	_load_hound_sprite()


func _load_hound_sprite() -> void:
	if not sprite:
		return
	sprite.texture = load("res://assets/generated/shadow_hound_enemy_frame_0.png")
	sprite.modulate = Color(0.5, 0.3, 0.6, 0.95)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	_lunge_timer = maxf(_lunge_timer - delta, 0.0)

	if not player_ref:
		return

	# Handle active lunge
	if _is_lunging:
		_lunge_remaining -= delta
		velocity = _lunge_dir * speed * LUNGE_SPEED_MULT
		move_and_slide()
		# Check if reached player
		if global_position.distance_to(player_ref.global_position) < attack_range:
			if _attack_timer <= 0.0:
				_attack_player()
			_is_lunging = false
			_lunge_timer = LUNGE_COOLDOWN
		if _lunge_remaining <= 0.0:
			_is_lunging = false
			_lunge_timer = LUNGE_COOLDOWN
		return

	# Circle the player when close but not attacking
	var dist := global_position.distance_to(player_ref.global_position)
	if dist < LUNGE_RANGE * 0.8 and state == State.CHASE and _lunge_timer <= 0.0:
		# Lunge!
		_is_lunging = true
		_lunge_remaining = LUNGE_DURATION
		_lunge_dir = Enemy._safe_normalize(player_ref.global_position - global_position)
		EffectSpawner.spawn_particles(global_position, Color(0.5, 0.2, 0.6), 4, 6.0)
		return

	# When circling (within lunge range but cooldown active), strafe around player
	if dist < LUNGE_RANGE and state == State.CHASE:
		_circle_angle += delta * 1.5
		# Move perpendicular to player direction to circle
		var to_player := Enemy._safe_normalize(player_ref.global_position - global_position)
		var perp := Vector2(-to_player.y, to_player.x)
		velocity = (perp * 0.7 + to_player * 0.3) * speed * 0.8
		move_and_slide()
		if sprite:
			sprite.flip_h = to_player.x < 0
		return

	# Normal chase (far away)
	super(delta)


func _die() -> void:
	# Dramatic shadow fade
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 1.0)
	EffectSpawner.spawn_particles(global_position, Color(0.2, 0.1, 0.3), 8, 12.0)
	super()


func _get_loot_table() -> Array[Dictionary]:
	return [
		{"item_id": "shadow_hide", "count": randi() % 2 + 1, "chance": 0.75},
		{"item_id": "ectoplasm", "count": 1, "chance": 0.15},
	]
