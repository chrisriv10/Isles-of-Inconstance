extends Enemy
class_name GhostEnemy

## A translucent ghost that phases through obstacles and chases the player
## at night. Drops ectoplasm on death. Ghosts always share the same name
## since their sprite is not procedurally generated.

func _init() -> void:
	# Create child nodes so Enemy's @onready vars resolve correctly
	var s := Sprite2D.new(); s.name = "Sprite2D"; add_child(s)
	var c := CollisionShape2D.new(); c.name = "CollisionShape2D"; add_child(c)
	c.shape = CircleShape2D.new()
	c.shape.radius = 5.0
	# Set name at construction so Enemy._ready() sees it
	display_name = "Casper"


func _ready() -> void:
	super()
	max_health = 80
	speed = 45.0
	damage = 12
	attack_cooldown = 1.8
	chase_range = 200.0
	attack_range = 22.0
	current_health = max_health
	display_name = "Casper"
	# Ghosts don't collide with terrain - only collide with player
	collision_mask = 2
	
	# Load ghost sprite
	_load_ghost_sprite()
	
	# Warm ghostly glow
	var point_light := PointLight2D.new()
	point_light.energy = 0.6
	point_light.texture_scale = 3.0
	point_light.color = Color(1.0, 0.85, 0.4, 0.5)
	point_light.texture = LightUtils.make_light_texture(64)
	add_child(point_light)


## Loads the generated ghost sprite.
func _load_ghost_sprite() -> void:
	if not sprite:
		return
	sprite.texture = load("res://assets/generated/ghost_enemy_yellow_frame_0.png")
	sprite.scale = Vector2(0.6, 0.6)
	sprite.modulate = Color(1.0, 0.9, 0.5, 0.8)


## Checks if the player is holding a lantern within range.
func _is_lantern_nearby() -> bool:
	if not player_ref:
		return false
	var dist := global_position.distance_to(player_ref.global_position)
	if dist > 120.0:
		return false
	# Check if player has lantern active in hotbar
	if player_ref.has_method("_get_hotbar_slot_data"):
		var sd = player_ref._get_hotbar_slot_data()
		if not sd.is_empty() and sd.get("item_id", "") == "lantern":
			return true
	return false

func _physics_process(delta: float) -> void:
	# Lantern repulsion: flee from player if they hold a lantern nearby
	if _is_lantern_nearby() and state != State.DEAD:
		state = State.IDLE
		var flee_diff := global_position - player_ref.global_position
		var flee_dir := Enemy._safe_normalize(flee_diff) if not flee_diff.is_zero_approx() else Vector2.ZERO
		velocity = flee_dir * speed * 2.0  # Double speed fleeing
		move_and_slide()
		# Translucent flicker when fleeing
		sprite.modulate = Color(1, 1, 1, 0.4 + sin(Time.get_ticks_msec() * 0.02) * 0.3)
		return
	
	super(delta)
	# Ghosts don't collide with terrain - already handled via collision_mask = 2


func _get_loot_table() -> Array[Dictionary]:
	return [
		{"item_id": "ectoplasm", "count": randi() % 2 + 1, "chance": 0.8},
		{"item_id": "ghostly_essence", "count": 1, "chance": 0.1},
	]
