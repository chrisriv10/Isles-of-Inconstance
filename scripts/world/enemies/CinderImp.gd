extends Enemy
class_name CinderImp

## A small, quick fire creature that hurls fireballs from range and runs
## away when the player gets close. Drops cinder shards.

const FLEE_RANGE: float = 60.0
const FIREBALL_SPEED: float = 120.0
const FIREBALL_COOLDOWN: float = 2.0

var _fireball_timer: float = 0.0
var _fleeing: bool = false


func _init() -> void:
	var s := Sprite2D.new(); s.name = "Sprite2D"; add_child(s)
	var c := CollisionShape2D.new(); c.name = "CollisionShape2D"; add_child(c)
	c.shape = CircleShape2D.new()
	c.shape.radius = 7.0
	display_name = "Cinder Imp"


func _ready() -> void:
	super()
	max_health = 65
	speed = 55.0
	damage = 6       # Melee damage is low — the fireballs are the real threat
	attack_cooldown = 0.5
	chase_range = 220.0
	attack_range = 16.0
	current_health = max_health
	display_name = "Cinder Imp"

	_load_cinder_sprite()

	# Warm glow
	var point_light := PointLight2D.new()
	point_light.energy = 0.5
	point_light.texture_scale = 2.0
	point_light.color = Color(1.0, 0.4, 0.1, 0.6)
	point_light.texture = LightUtils.make_light_texture(64)
	add_child(point_light)


func _load_cinder_sprite() -> void:
	if not sprite:
		return
	sprite.texture = load("res://assets/generated/cinder_imp_enemy_frame_0.png")
	sprite.modulate = Color(1.0, 0.7, 0.3, 0.95)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if NetworkManager.is_network_active() and _is_remote:
		return

	_fireball_timer = maxf(_fireball_timer - delta, 0.0)

	if not player_ref:
		return

	var dist := global_position.distance_to(player_ref.global_position)

	# Run away when player is close (keep distance for ranged attacks)
	if dist < FLEE_RANGE and state != State.DEAD:
		_fleeing = true
		var flee_dir := Enemy._safe_normalize(global_position - player_ref.global_position)
		velocity = flee_dir * speed * 1.3
		move_and_slide()
		# Still shoot fireballs while fleeing
		if _fireball_timer <= 0.0:
			_fireball_timer = FIREBALL_COOLDOWN
			_fire_fireball()
		return
	else:
		_fleeing = false

	# Hurl fireballs from range
	if dist < chase_range and dist > attack_range:
		if _fireball_timer <= 0.0:
			_fireball_timer = FIREBALL_COOLDOWN
			_fire_fireball()

	super(delta)


func _fire_fireball() -> void:
	if not player_ref or not is_instance_valid(player_ref):
		return

	var dir := Enemy._safe_normalize(player_ref.global_position - global_position)
	var proj := _create_fireball()
	proj.global_position = global_position + dir * 12.0
	proj.linear_velocity = dir * FIREBALL_SPEED
	get_parent().add_child(proj)

	# Recoil push-back
	var push_dir := -dir * 6.0
	global_position += push_dir

	EffectSpawner.spawn_particles(global_position, Color(1.0, 0.5, 0.1), 3, 5.0)


func _create_fireball() -> RigidBody2D:
	var body := RigidBody2D.new()
	body.gravity_scale = 0.0
	body.contact_monitor = true
	body.max_contacts_reported = 1

	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = 4.0
	body.add_child(shape)

	var sprite2d := Sprite2D.new()
	var fb_img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	fb_img.fill(Color.TRANSPARENT)
	for fy in range(8):
		for fx in range(8):
			var fd := sqrt((fx - 3.5) * (fx - 3.5) + (fy - 3.5) * (fy - 3.5))
			if fd < 3.5:
				var alpha := clampf(1.0 - fd / 4.0, 0.5, 1.0)
				var bright := 1.0 - fd / 4.0
				fb_img.set_pixel(fx, fy, Color(1.0 * bright, 0.5 * bright, 0.05, alpha))
	sprite2d.texture = ImageTexture.create_from_image(fb_img)
	body.add_child(sprite2d)

	# Auto-destruct on contact
	body.body_entered.connect(_on_fireball_hit.bind(body))
	return body


func _on_fireball_hit(_body: Node, fireball: RigidBody2D) -> void:
	if not is_instance_valid(fireball):
		return
	# Damage player
	if _body == player_ref:
		GameManager.take_damage(damage + 3)
		EffectSpawner.spawn_particles(fireball.global_position, Color(1.0, 0.5, 0.0), 4, 6.0)
	fireball.queue_free()


func _get_loot_table() -> Array[Dictionary]:
	return [
		{"item_id": "cinder_shard", "count": randi() % 2 + 1, "chance": 0.8},
		{"item_id": "ghostly_essence", "count": 1, "chance": 0.05},
	]
