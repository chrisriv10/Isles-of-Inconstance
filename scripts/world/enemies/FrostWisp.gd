extends Enemy
class_name FrostWisp

## A floating icy spirit that hovers above the ground. Fires slow-moving
## homing projectiles that chill the player. Drops frost crystals.

const PROJECTILE_SPEED: float = 70.0
const SHOOT_COOLDOWN: float = 2.5
const HOVER_AMPLITUDE: float = 6.0
const HOVER_SPEED: float = 2.0

var _shoot_timer: float = 0.0
var _hover_offset: float = 0.0
var _base_y: float = 0.0


func _init() -> void:
	var s := Sprite2D.new(); s.name = "Sprite2D"; add_child(s)
	var c := CollisionShape2D.new(); c.name = "CollisionShape2D"; add_child(c)
	c.shape = CircleShape2D.new()
	c.shape.radius = 8.0
	display_name = "Frost Wisp"


func _ready() -> void:
	super()
	max_health = 75
	speed = 30.0
	damage = 8
	attack_cooldown = 0.8
	chase_range = 240.0
	attack_range = 18.0
	current_health = max_health
	display_name = "Frost Wisp"

	_base_y = global_position.y

	_load_wisp_sprite()

	# Cold glow
	var point_light := PointLight2D.new()
	point_light.energy = 0.5
	point_light.texture_scale = 2.5
	point_light.color = Color(0.4, 0.6, 1.0, 0.5)
	point_light.texture = LightUtils.make_light_texture(64)
	add_child(point_light)


func _load_wisp_sprite() -> void:
	if not sprite:
		return
	sprite.texture = load("res://assets/generated/ghost_enemy_frame_0.png")
	sprite.scale = Vector2(0.6, 0.6)
	sprite.modulate = Color(0.55, 0.7, 1.0, 0.85)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	_shoot_timer = maxf(_shoot_timer - delta, 0.0)

	# Hovering bob
	_hover_offset += delta * HOVER_SPEED
	var hover_y := sin(_hover_offset) * HOVER_AMPLITUDE
	global_position.y = _base_y + hover_y

	if not player_ref:
		return

	var dist := global_position.distance_to(player_ref.global_position)

	# Shoot projectiles from range
	if dist < chase_range and _shoot_timer <= 0.0 and state != State.IDLE:
		_shoot_timer = SHOOT_COOLDOWN
		_shoot_projectile()

	# Keep distance — wisps prefer mid-range
	if dist < attack_range * 2.0 and state == State.CHASE:
		var flee_dir := Enemy._safe_normalize(global_position - player_ref.global_position)
		velocity = flee_dir * speed * 0.7
		move_and_slide()
		return

	super(delta)


func _shoot_projectile() -> void:
	if not player_ref or not is_instance_valid(player_ref):
		return

	var dir := Enemy._safe_normalize(player_ref.global_position - global_position)
	var proj := _create_ice_bolt()
	proj.global_position = global_position + dir * 14.0
	proj.linear_velocity = dir * PROJECTILE_SPEED
	get_parent().add_child(proj)

	EffectSpawner.spawn_particles(global_position, Color(0.5, 0.7, 1.0), 3, 5.0)


func _create_ice_bolt() -> RigidBody2D:
	var body := RigidBody2D.new()
	body.gravity_scale = 0.0
	body.contact_monitor = true
	body.max_contacts_reported = 1

	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = 4.0
	body.add_child(shape)

	var sprite2d := Sprite2D.new()
	var ib_img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	ib_img.fill(Color.TRANSPARENT)
	for iy in range(8):
		for ix in range(8):
			var id := sqrt((ix - 3.5) * (ix - 3.5) + (iy - 3.5) * (iy - 3.5))
			if id < 3.5:
				var alpha := clampf(1.0 - id / 4.0, 0.4, 0.9)
				ib_img.set_pixel(ix, iy, Color(0.5, 0.7, 1.0, alpha))
			# Bright center
			if id < 2.0:
				var alpha2 := clampf(1.0 - id / 2.0, 0.5, 1.0)
				ib_img.set_pixel(ix, iy, Color(0.8, 0.9, 1.0, alpha2))
	sprite2d.texture = ImageTexture.create_from_image(ib_img)
	body.add_child(sprite2d)

	body.body_entered.connect(_on_ice_bolt_hit.bind(body))
	return body


func _on_ice_bolt_hit(_body: Node, bolt: RigidBody2D) -> void:
	if not is_instance_valid(bolt):
		return
	if _body == player_ref:
		GameManager.take_damage(damage)
		EffectSpawner.spawn_particles(bolt.global_position, Color(0.5, 0.8, 1.0), 5, 7.0)
	bolt.queue_free()


func _get_loot_table() -> Array[Dictionary]:
	return [
		{"item_id": "frost_crystal", "count": randi() % 2 + 1, "chance": 0.7},
		{"item_id": "ectoplasm", "count": 1, "chance": 0.2},
	]
