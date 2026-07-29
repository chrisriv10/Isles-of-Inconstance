extends Enemy
class_name SporelingEnemy

## A small fungal creature that patrols near its spawn point but chases
## the player when they get close. Slower but more numerous than ghosts.
## Drops spore sacs on death.

const WANDER_RANGE: float = 48.0

var _spawn_pos: Vector2
var _wander_target: Vector2
var _wander_timer: float = 0.0


func _init() -> void:
	# Create child nodes so Enemy's @onready vars resolve correctly
	var s := Sprite2D.new(); s.name = "Sprite2D"; add_child(s)
	var c := CollisionShape2D.new(); c.name = "CollisionShape2D"; add_child(c)
	c.shape = CircleShape2D.new()
	c.shape.radius = 8.0


func _ready() -> void:
	super()
	max_health = 55
	speed = 35.0
	damage = 8
	attack_cooldown = 1.2
	chase_range = 150.0
	attack_range = 18.0
	current_health = max_health
	
	_spawn_pos = global_position
	_pick_wander_target()
	
	# Load sporeling sprite
	_load_sporeling_sprite()


func _physics_process(delta: float) -> void:
	super(delta)
	
	# Wander when idle
	if state == State.IDLE:
		_wander_timer -= delta
		if _wander_timer <= 0.0:
			_pick_wander_target()
			_wander_timer = randf_range(2.0, 5.0)
		
		var wander_dir := (_wander_target - global_position)
		if wander_dir.length() > 4.0 and is_finite(wander_dir.length()):
			velocity = (wander_dir.normalized() if wander_dir != Vector2.ZERO else Vector2.ZERO) * speed * 0.5
		else:
			velocity = Vector2.ZERO
		
		if sprite:
			sprite.flip_h = wander_dir.x < 0


func _load_sporeling_sprite() -> void:
	if not sprite:
		return
	sprite.texture = load("res://assets/generated/sporeling_enemy_frame_0.png")
	sprite.modulate = Color(0.9, 0.35, 0.35, 1.0)

func _pick_wander_target() -> void:
	_wander_target = _spawn_pos + Vector2(
		randf_range(-WANDER_RANGE, WANDER_RANGE),
		randf_range(-WANDER_RANGE, WANDER_RANGE)
	)


func _get_loot_table() -> Array[Dictionary]:
	return [
		{"item_id": "spore_sac", "count": randi() % 2 + 1, "chance": 0.85},
	]
