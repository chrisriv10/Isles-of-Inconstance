extends CharacterBody2D
class_name CaveCrawler

## Small underground cave centipede-like creature. Weak, fast, attacks by
## biting. Found in early mine levels (depth 1-2).
##
## Uses the same Enemy base pattern but extends CharacterBody2D directly
## for a simpler AI (no abstract base complexity). Registers in the
## "enemies" group so the player can damage it.

## Health points
var max_health: int = 12
var current_health: int = 12

## Movement speed (pixels/sec)
var speed: float = 50.0

## Damage dealt to player on contact
var damage: int = 6

## Attack cooldown (seconds)
var attack_cooldown: float = 1.2

## Chase/aggro range
var chase_range: float = 160.0

## Attack range
var attack_range: float = 18.0

## XP granted on kill
var experience_value: int = 5

var _attack_timer: float = 0.0
var _player_ref: Node2D = null
var _hp_mult: float = 1.0

# Health bar nodes
var _health_bar_bg: ColorRect = null
var _health_bar_fill: ColorRect = null
var _name_label: Label = null

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("enemies")
	current_health = max_health
	_ensure_health_bar()
	_update_health_bar()
	# Find player
	_player_ref = get_tree().get_first_node_in_group("player")


func set_hp_multiplier(mult: float) -> void:
	_hp_mult = mult
	max_health = roundi(max_health * _hp_mult)
	current_health = max_health


func _ensure_health_bar() -> void:
	if _health_bar_bg != null:
		return
	var bar_w := 18.0
	var bar_h := 4.0
	
	var bg := ColorRect.new()
	bg.name = "HealthBarBG"
	bg.size = Vector2(bar_w, bar_h)
	bg.position = Vector2(-bar_w / 2.0, -24)
	bg.color = Color(0.1, 0.1, 0.1, 0.6)
	add_child(bg)
	_health_bar_bg = bg

	var fill := ColorRect.new()
	fill.name = "HealthBarFill"
	fill.size = Vector2(bar_w, bar_h)
	fill.position = Vector2(-bar_w / 2.0, -24)
	fill.color = Color(0.9, 0.15, 0.15, 0.85)
	add_child(fill)
	_health_bar_fill = fill

	# Name label
	var label := Label.new()
	label.name = "EnemyNameLabel"
	label.text = "Cave Crawler"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	label.position = Vector2(-50, -36)
	label.size = Vector2(100, 14)
	add_child(label)
	_name_label = label


func _update_health_bar() -> void:
	_ensure_health_bar()
	var ratio := float(current_health) / float(max_health)
	_health_bar_fill.size.x = ratio * 18.0
	if ratio > 0.5:
		_health_bar_fill.color = Color(0.9, 0.15, 0.15, 0.85)
	else:
		_health_bar_fill.color = Color(0.6, 0.05, 0.05, 0.85)


func _physics_process(delta: float) -> void:
	if current_health <= 0:
		return
	if not is_inside_tree():
		return
	
	_attack_timer -= delta
	
	# Try to find player if we lost reference
	if not _player_ref or not is_instance_valid(_player_ref):
		_player_ref = get_tree().get_first_node_in_group("player")
		return
	
	var dist := global_position.distance_to(_player_ref.global_position)
	
	if dist <= attack_range:
		# Attack
		velocity = Vector2.ZERO
		if _attack_timer <= 0.0:
			_attack_timer = attack_cooldown
			GameManager.take_damage(damage)
			EffectSpawner.spawn_dirt_puff(global_position)
			# Push back so the enemy doesn't sit on the player
			var push_dir := (global_position - _player_ref.global_position).normalized()
			if push_dir != Vector2.ZERO:
				global_position += push_dir * 8.0
	elif dist <= chase_range:
		# Chase — stop slightly before reaching the player to avoid overlap
		var stop_dist := attack_range * 0.85
		if dist <= stop_dist:
			velocity = Vector2.ZERO
		else:
			var dir := (_player_ref.global_position - global_position).normalized()
			velocity = dir * speed
	else:
		velocity = Vector2.ZERO
	
	move_and_slide()
	
	# Flip sprite based on direction
	if velocity.x < -1.0:
		sprite.flip_h = true
	elif velocity.x > 1.0:
		sprite.flip_h = false


func take_damage(amount: int, _source: Node2D = null, _is_critical: bool = false) -> void:
	if current_health <= 0:
		return
	
	current_health -= amount
	_update_health_bar()
	
	# Flash red like Minecraft
	sprite.modulate = Color(1.5, 0.2, 0.2, 1.0)  # Instant red tint
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.15)
	tw.set_ease(Tween.EASE_OUT)
	
	if current_health <= 0:
		_die()
	else:
		# Brief knockback
		if _source:
			var kb_dir := (global_position - _source.global_position).normalized()
			velocity = kb_dir * 80.0


## Public death trigger — called by CreativePanel kill-all and other external systems.
func die() -> void:
	_die()


func _die() -> void:
	velocity = Vector2.ZERO
	# Drop loot
	var loot_table := _get_loot_table()
	for entry in loot_table:
		if randf() < entry["chance"]:
			InventoryManager.add_item(entry["item_id"], entry["count"])
	
	# XP
	if experience_value > 0:
		LevelManager.add_xp_source("hit_enemy")
	
	# Effects
	EffectSpawner.spawn_dirt_puff(global_position)
	AudioManager.play(AudioManager.Sound.ENEMY_DIE)
	
	# Remove from group so we can't be double-killed
	remove_from_group("enemies")
	
	# Fade out
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.TRANSPARENT, 0.3)
	tween.tween_callback(queue_free)


func _get_loot_table() -> Array[Dictionary]:
	return [
		{"item_id": "spore_sac", "count": 1, "chance": 0.4},
		{"item_id": "stone", "count": 1, "chance": 0.3},
	]
