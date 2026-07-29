extends CharacterBody2D
class_name StoneGolem

## Larger stone golem creature found in deeper mine levels (depth 2+).
## Slow but tough, deals heavy damage. Has a ground slam attack area-of-effect.
##
## Same pattern as CaveCrawler — CharacterBody2D, "enemies" group,
## direct combat without abstract base classes.

## Health points
var max_health: int = 35
var current_health: int = 35

## Movement speed (pixels/sec)
var speed: float = 25.0

## Damage dealt to player on contact
var damage: int = 14

## Attack cooldown (seconds) — golems are slow attackers
var attack_cooldown: float = 2.0

## Chase/aggro range
var chase_range: float = 180.0

## Attack range
var attack_range: float = 22.0

## Ground slam range (AOE around the golem)
var slam_range: float = 40.0

## Chance to use ground slam instead of bite on each attack
var slam_chance: float = 0.3

## XP granted on kill
var experience_value: int = 15

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
	label.text = "Stone Golem"
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
	
	if not _player_ref or not is_instance_valid(_player_ref):
		_player_ref = get_tree().get_first_node_in_group("player")
		return
	
	var dist := global_position.distance_to(_player_ref.global_position)
	
	if dist <= attack_range:
		velocity = Vector2.ZERO
		if _attack_timer <= 0.0:
			_attack_timer = attack_cooldown
			if randf() < slam_chance:
				_ground_slam()
			else:
				_melee_attack()
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
	
	if velocity.x < -1.0:
		sprite.flip_h = true
	elif velocity.x > 1.0:
		sprite.flip_h = false


func _melee_attack() -> void:
	GameManager.take_damage(damage)
	EffectSpawner.spawn_dirt_puff(global_position)
	AudioManager.play(AudioManager.Sound.HIT)


func _ground_slam() -> void:
	# Screen shake and aoe damage
	if _player_ref and is_instance_valid(_player_ref):
		var dist := global_position.distance_to(_player_ref.global_position)
		if dist <= slam_range:
			# Partial damage at range
			var aoe_damage := roundi(damage * 0.7)
			GameManager.take_damage(aoe_damage)
	
	# Visual: screen shake
	var camera := get_viewport().get_camera_2d()
	if camera and camera.has_method("shake"):
		camera.shake(6.0, 0.3)
	
	# Particles
	EffectSpawner.spawn_dirt_puff(global_position)
	AudioManager.play(AudioManager.Sound.HIT)


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
		if _source:
			var kb_dir := (global_position - _source.global_position).normalized()
			velocity = kb_dir * 60.0


## Public death trigger — called by CreativePanel kill-all and other external systems.
func die() -> void:
	_die()


func _die() -> void:
	velocity = Vector2.ZERO
	
	var loot_table := _get_loot_table()
	for entry in loot_table:
		if randf() < entry["chance"]:
			InventoryManager.add_item(entry["item_id"], entry["count"])
	
	if experience_value > 0:
		LevelManager.add_xp_source("hit_enemy")
	
	EffectSpawner.spawn_dirt_puff(global_position)
	AudioManager.play(AudioManager.Sound.ENEMY_DIE)
	remove_from_group("enemies")
	
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.TRANSPARENT, 0.5)
	tween.tween_callback(queue_free)


func _get_loot_table() -> Array[Dictionary]:
	return [
		{"item_id": "stone", "count": 3, "chance": 0.7},
		{"item_id": "copper_ore", "count": 1, "chance": 0.3},
		{"item_id": "iron_ore", "count": 1, "chance": 0.2},
	]