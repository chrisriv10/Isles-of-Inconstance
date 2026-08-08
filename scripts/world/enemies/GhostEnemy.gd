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


## Returns the nearest standing player holding a light source (lantern,
## torch, ember lantern) within range, or null. In multiplayer this checks
## ALL players in the "player" group (host's own player + remote copies), so
## any player's light repels the ghost — not just its current target.
func _find_nearest_light_holder() -> CharacterBody2D:
	var best: CharacterBody2D = null
	var best_dist_sq: float = INF
	for p in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(p) or not (p is CharacterBody2D):
			continue
		if "_is_downed" in p and p._is_downed:
			continue
		var d_sq: float = global_position.distance_squared_to(p.global_position)
		if d_sq > 120.0 * 120.0:
			continue
		if _player_holds_light(p):
			if d_sq < best_dist_sq:
				best_dist_sq = d_sq
				best = p as CharacterBody2D
	return best


## Determines whether a given player node is currently holding a light source.
## The host's own player reads its live hotbar; remote copies read the synced
## held_item_id (their local InventoryManager/active_tool are not replicated),
## which is broadcast ~3x/sec by GameManager.
func _player_holds_light(p: Node) -> bool:
	if p.is_multiplayer_authority():
		if p.has_method("_get_hotbar_slot_data"):
			var sd: Dictionary = p._get_hotbar_slot_data()
			if not sd.is_empty():
				var item: ItemData = DataManager.get_item(sd.get("item_id", ""))
				return item != null and item.is_light_source
		return false
	# Remote copy — use the synced held item id
	var authority: int = p.get_multiplayer_authority()
	var stats: Dictionary = GameManager.remote_player_stats.get(authority, {})
	var held_id: String = stats.get("held_item_id", "")
	if held_id.is_empty():
		return false
	var item: ItemData = DataManager.get_item(held_id)
	return item != null and item.is_light_source

func _physics_process(delta: float) -> void:
	# Remote copy — skip AI, position is synced by host
	if NetworkManager.is_network_active() and _is_remote:
		return
	
	# Lantern repulsion: flee from the nearest player holding a light source.
	# In multiplayer this checks ALL players, so any player's lantern repels.
	var light_holder: CharacterBody2D = _find_nearest_light_holder()
	if light_holder and state != State.DEAD:
		state = State.IDLE
		var flee_diff := global_position - light_holder.global_position
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
