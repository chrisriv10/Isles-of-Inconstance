extends CharacterBody2D
class_name Pet

## A companion animal that follows the player around and attacks nearby enemies.
## The pet maintains a comfortable distance from the player (doesn't stick directly
## to them) and automatically engages hostile enemies within detection range.
## Uses pre-generated animated spritesheets with idle and walk cycles.

enum PetState { FOLLOW, ATTACK, RETURN }

var pet_id: String = ""
var player_ref: Node2D = null

var _pet_data: Dictionary = {}
var _velocity := Vector2.ZERO
var _state: int = PetState.FOLLOW
var _attack_cooldown: float = 0.0
var _idle_shift_timer: float = 0.0
var _idle_shift_target: Vector2 = Vector2.ZERO
var _is_remote: bool = false

## Follow distance: pet maintains this range from the player.
## Increased from 16 to 42 so the pet doesn't feel like it's stuck to you.
const FOLLOW_BUFFER: float = 42.0
## Stop distance: how close before the pet stops moving.
## Increased from 6 to 18 for a more natural "comfort zone".
const STOP_DIST: float = 18.0
## Minimum distance: pet won't get closer than this (prevents overlapping).
const MIN_DIST: float = 30.0
## Detection range for enemies.
const DETECT_RANGE: float = 120.0
const ATTACK_RANGE: float = 24.0
const ATTACK_COOLDOWN: float = 1.5
## Pet base scale — reduced for more compact pets.
const PET_SCALE_BASE: float = 0.7

# ── Pet dialogue ──
const PET_DIALOGUE_COOLDOWN: float = 20.0

const GINGERBREAD_PET_LINES: Array[String] = [
	"Run run as fast as I can!",
	"Fresh from the oven!",
	"Don't eat me, I'm your pal!",
	"Crumbly but cuddly!",
	"Icing on top!",
	"Not just a snack!",
	"Watch me go!",
	"Sweet as can be!",
	"Hey, you're pretty cool!",
	"Thanks for taking me along!",
	"You're my favorite baker!",
	"Let's go on an adventure!",
]
const SANDWICH_PET_LINES: Array[String] = [
	"Two wafers and lots of cream!",
	"Chilly companion at your side!",
	"Stay cool!",
	"Sweet and frozen solid!",
	"Vanilla and chocolate power!",
	"Brain freeze incoming!",
	"Snap, crackle, chill!",
	"I'm melting for adventure!",
	"You're the coolest friend I know!",
	"I've got your back, buddy!",
	"Together we're unbeatable!",
	"Let's chill out together!",
]

var _pet_dialogue_bubble: Node2D = null
var _pet_dialogue_label: Label = null
var _last_pet_dialogue_time: float = -999.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var label: Label = $Label
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func setup(id: String, player: Node2D) -> bool:
	pet_id = id
	player_ref = player
	_pet_data = {}
	# PetManager is an autoload singleton — reference it directly rather than via
	# get_node("/root/..."). The tree-relative path fails when a remote pet is
	# configured before it has been added to the scene tree (an absolute
	# get_node from outside the tree errors and returns null), which left
	# _pet_data empty and logged a bogus "unknown pet id".
	_pet_data = PetManager.get_pet_data(id)
	PetManager.pet_name_changed.connect(_on_pet_name_changed)
	if _pet_data.is_empty():
		push_error("Pet: unknown pet id '%s'" % id)
		queue_free()
		return false
	
	name = "Pet_" + id
	# Apply scale reduction for a more compact pet
	scale = Vector2(PET_SCALE_BASE, PET_SCALE_BASE)
	_setup_animation()
	_setup_pet_dialogue()
	_update_name_label()
	label.show()
	z_index = 10
	return true


func _update_name_label() -> void:
	if PetManager.has_method("get_pet_display_name"):
		label.text = PetManager.get_pet_display_name(pet_id)
	else:
		label.text = _pet_data.get("name", pet_id)


func _on_pet_name_changed(changed_id: String, _display_name: String) -> void:
	if changed_id == pet_id:
		_update_name_label()


func _physics_process(delta: float) -> void:
	if not player_ref or not is_instance_valid(player_ref):
		return
	if _pet_data.is_empty():
		return
	if _is_remote:
		# Remote pet: sit at follow offset relative to player, no AI
		var offset: Vector2 = _pet_data.get("offset", Vector2(-22, 8))
		position = offset
		sprite.play("idle")
		return
	
	_attack_cooldown = max(0.0, _attack_cooldown - delta)
	_update_state()
	
	match _state:
		PetState.FOLLOW:
			_follow_player(delta)
			_try_show_pet_dialogue()
		PetState.ATTACK:
			_attack_enemy(delta)
		PetState.RETURN:
			_return_to_player(delta)


func _update_state() -> void:
	var nearest := _find_nearest_enemy()
	
	if nearest != null:
		_state = PetState.ATTACK
	elif _state == PetState.ATTACK and nearest == null:
		_state = PetState.RETURN
	elif _state == PetState.RETURN:
		var dist := global_position.distance_to(player_ref.global_position)
		if dist <= FOLLOW_BUFFER + STOP_DIST:
			_state = PetState.FOLLOW


func _find_nearest_enemy() -> Node2D:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var nearest_dist: float = DETECT_RANGE
	for e in enemies:
		if not is_instance_valid(e):
			continue
		if not e.has_method("take_damage"):
			continue
		var dist := global_position.distance_to(e.global_position)
		if dist <= DETECT_RANGE and dist < nearest_dist:
			nearest = e
			nearest_dist = dist
	return nearest


func _follow_player(delta: float) -> void:
	var player_facing := Vector2.RIGHT
	if is_instance_valid(player_ref) and "facing_direction" in player_ref:
		player_facing = player_ref.facing_direction
	
	# Compute a follow offset behind and to the side of the player,
	# so the pet trails naturally rather than sitting on top of the player.
	var follow_offset: Vector2 = _pet_data.get("offset", Vector2(-22, 8))
	if player_facing.x < 0:
		follow_offset.x = abs(follow_offset.x)
	elif player_facing.x > 0:
		follow_offset.x = -abs(follow_offset.x)
	follow_offset += player_facing * -8.0  # trail slightly behind
	
	var target_pos := player_ref.global_position + follow_offset
	var dist := global_position.distance_to(target_pos)
	
	if dist > FOLLOW_BUFFER + STOP_DIST:
		# Far away — rush toward the player
		var dir := (player_ref.global_position - global_position).normalized()
		var spd: float = _pet_data.get("speed", 150.0) * 1.3
		_velocity = _velocity.move_toward(dir * spd, spd * delta * 6.0)
		velocity = _velocity
		move_and_slide()
		_velocity = velocity
		_update_facing()
		if sprite.sprite_frames and sprite.animation != "walk":
			sprite.play("walk")
	elif dist > STOP_DIST:
		# Comfortable follow range — approach the target offset naturally
		var dir := (target_pos - global_position).normalized()
		var spd: float = _pet_data.get("speed", 150.0)
		# Speed up when farther, slow down when closer
		var speed_factor := clampf(dist / FOLLOW_BUFFER, 0.3, 1.0)
		_velocity = _velocity.move_toward(dir * spd * speed_factor, spd * delta * 4.0)
		velocity = _velocity
		move_and_slide()
		_velocity = velocity
		_update_facing()
		if sprite.sprite_frames and sprite.animation != "walk":
			sprite.play("walk")
	elif dist < MIN_DIST:
		# Too close — back off slightly
		var away_dir := (global_position - target_pos).normalized()
		_velocity = _velocity.move_toward(away_dir * 30.0, 60.0 * delta)
		velocity = _velocity
		move_and_slide()
		_velocity = velocity
		_update_facing()
		if sprite.sprite_frames and sprite.animation != "walk":
			sprite.play("walk")
	else:
		# In the comfort zone — idle with occasional small shifts
		_idle_shift_timer -= delta
		if _idle_shift_timer <= 0.0:
			# Every 2-4 seconds, pick a random tiny offset to shuffle to
			_idle_shift_timer = randf_range(2.0, 4.0)
			_idle_shift_target = player_ref.global_position + follow_offset + Vector2(
				randf_range(-12.0, 12.0),
				randf_range(-8.0, 8.0)
			)
		
		var shift_dist := global_position.distance_to(_idle_shift_target)
		if shift_dist > 6.0:
			var shift_dir := (_idle_shift_target - global_position).normalized()
			_velocity = _velocity.move_toward(shift_dir * 25.0, 40.0 * delta)
			velocity = _velocity
			move_and_slide()
			_velocity = velocity
			_update_facing()
			if sprite.sprite_frames and sprite.animation != "walk":
				sprite.play("walk")
		else:
			_velocity = _velocity.move_toward(Vector2.ZERO, 200.0 * delta)
			if _velocity.length() < 5.0:
				_velocity = Vector2.ZERO
				if sprite.sprite_frames and sprite.animation != "idle":
					sprite.play("idle")
			else:
				velocity = _velocity
				move_and_slide()
				_update_facing()


func _attack_enemy(_delta: float) -> void:
	var target := _find_nearest_enemy()
	if target == null:
		_state = PetState.RETURN
		return
	
	var dist := global_position.distance_to(target.global_position)
	var spd: float = _pet_data.get("speed", 150.0) * 1.3
	
	if dist > ATTACK_RANGE:
		var dir := (target.global_position - global_position).normalized()
		_velocity = _velocity.move_toward(dir * spd, spd * _delta * 8.0)
		velocity = _velocity
		move_and_slide()
		_velocity = velocity
		_update_facing()
		if sprite.sprite_frames and sprite.animation != "walk":
			sprite.play("walk")
	else:
		_velocity = Vector2.ZERO
		if _attack_cooldown <= 0.0 and target.has_method("take_damage"):
			_attack_cooldown = ATTACK_COOLDOWN
			var dmg: int = _pet_data.get("combat_damage", 2)
			target.take_damage(dmg, self)
			if PetManager and PetManager.has_method("award_xp"):
				PetManager.award_xp(1)
			if sprite.sprite_frames:
				sprite.play("walk")
			EffectSpawner.spawn_particles(target.global_position, Color(1.0, 0.8, 0.2), 3, 6.0)
		if sprite.sprite_frames and sprite.animation != "idle":
			sprite.play("idle")


func _return_to_player(delta: float) -> void:
	var target_pos := player_ref.global_position + Vector2(0, -10)
	var dist := global_position.distance_to(target_pos)
	
	if dist > STOP_DIST:
		var dir := (target_pos - global_position).normalized()
		var spd: float = _pet_data.get("speed", 150.0)
		_velocity = _velocity.move_toward(dir * spd, spd * delta * 8.0)
		velocity = _velocity
		move_and_slide()
		_velocity = velocity
		_update_facing()
		if sprite.sprite_frames and sprite.animation != "walk":
			sprite.play("walk")
	else:
		_velocity = Vector2.ZERO
		if sprite.sprite_frames and sprite.animation != "idle":
			sprite.play("idle")


func _update_facing() -> void:
	if _velocity.x < -5:
		sprite.scale.x = -abs(sprite.scale.x)
	elif _velocity.x > 5:
		sprite.scale.x = abs(sprite.scale.x)


# ---------------------------------------------------------------------------
# Pet dialogue (only for ice_cream_sandwich and gingerbread_man)
# ---------------------------------------------------------------------------

func _has_pet_dialogue() -> bool:
	return pet_id in ["ice_cream_sandwich", "gingerbread_man"]


func _get_pet_dialogue_line() -> String:
	match pet_id:
		"gingerbread_man":
			return GINGERBREAD_PET_LINES[randi() % GINGERBREAD_PET_LINES.size()]
		"ice_cream_sandwich":
			return SANDWICH_PET_LINES[randi() % SANDWICH_PET_LINES.size()]
	return "..."


func _setup_pet_dialogue() -> void:
	if not _has_pet_dialogue():
		return
	if _pet_dialogue_bubble != null:
		return
	_pet_dialogue_bubble = Node2D.new()
	_pet_dialogue_bubble.name = "PetDialogueBubble"
	_pet_dialogue_bubble.position = Vector2(0, -28)
	_pet_dialogue_bubble.visible = false

	_pet_dialogue_label = Label.new()
	_pet_dialogue_label.name = "PetDialogueLabel"
	_pet_dialogue_label.size = Vector2(72, 16)
	_pet_dialogue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pet_dialogue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_pet_dialogue_label.add_theme_font_size_override("font_size", 6)
	_pet_dialogue_label.add_theme_color_override("font_color", Color.WHITE)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.15, 0.85)
	sb.border_color = Color(1.0, 0.7, 0.3, 0.9)
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = 5
	sb.corner_radius_top_right = 5
	sb.corner_radius_bottom_left = 5
	sb.corner_radius_bottom_right = 5
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	_pet_dialogue_label.add_theme_stylebox_override("normal", sb)

	_pet_dialogue_bubble.add_child(_pet_dialogue_label)
	add_child(_pet_dialogue_bubble)


func _try_show_pet_dialogue() -> void:
	if not _has_pet_dialogue() or _pet_dialogue_bubble == null:
		return
	var now := Time.get_unix_time_from_system()
	if now - _last_pet_dialogue_time < PET_DIALOGUE_COOLDOWN:
		return
	if randf() > 0.35:
		return
	_last_pet_dialogue_time = now
	_pet_dialogue_label.text = _get_pet_dialogue_line()
	_pet_dialogue_bubble.visible = true
	# Auto-hide after 3 seconds
	get_tree().create_timer(3.0).timeout.connect(func():
		if is_instance_valid(_pet_dialogue_bubble):
			_pet_dialogue_bubble.visible = false
	)




# ---------------------------------------------------------------------------
# Animation setup
# ---------------------------------------------------------------------------

func _setup_animation() -> void:
	# The ice_cream_sandwich pet uses v4 spritesheets (properly animated)
	var walk_path: String
	var idle_path: String
	if pet_id == "ice_cream_sandwich":
		walk_path = "res://assets/generated/pet_ice_cream_sandwich_walk_v4.png"
		idle_path = "res://assets/generated/pet_ice_cream_sandwich_idle_v4.png"
	elif pet_id == "gingerbread_man":
		walk_path = "res://assets/generated/pet_gingerbread_man_walk_v4.png"
		idle_path = "res://assets/generated/pet_gingerbread_man_idle_v4.png"
	else:
		walk_path = "res://assets/generated/pet_%s_walk.png" % pet_id
		idle_path = "res://assets/generated/pet_%s_idle.png" % pet_id
	var walk_tex: Texture2D = load(walk_path) if ResourceLoader.exists(walk_path) else null
	var idle_tex: Texture2D = load(idle_path) if ResourceLoader.exists(idle_path) else null
	if not walk_tex or not idle_tex:
		push_error("Pet: missing animation for '%s'" % pet_id)
		return
	
	var frames := SpriteFrames.new()
	frames.add_animation("idle")
	frames.add_animation("walk")
	for i in range(8):
		var idle_frame := AtlasTexture.new()
		idle_frame.atlas = idle_tex
		idle_frame.region = Rect2((i % 4) * 48, floori(i / 4) * 48, 48, 48)
		frames.add_frame("idle", idle_frame)
		var walk_frame := AtlasTexture.new()
		walk_frame.atlas = walk_tex
		walk_frame.region = Rect2((i % 4) * 48, floori(i / 4) * 48, 48, 48)
		frames.add_frame("walk", walk_frame)
	frames.set_animation_speed("idle", 4.0)
	frames.set_animation_speed("walk", 8.0)
	frames.set_animation_loop("idle", true)
	frames.set_animation_loop("walk", true)
	sprite.sprite_frames = frames
	sprite.play("idle")

# ---------------------------------------------------------------------------
# Legacy stubs (unused — kept for compatibility)
# ---------------------------------------------------------------------------
func _set_px(_img: Image, _x: int, _y: int, _c: Color) -> void:
	pass
func _draw_ellipse(_img: Image, _cx: int, _cy: int, _rx: int, _ry: int, _c: Color) -> void:
	pass
func _draw_rect(_img: Image, _x1: int, _y1: int, _x2: int, _y2: int, _c: Color) -> void:
	pass
func _draw_cat(_img: Image) -> void:
	pass
func _draw_dog(_img: Image) -> void:
	pass
func _draw_fox(_img: Image) -> void:
	pass
func _draw_bird(_img: Image) -> void:
	pass
func _draw_turtle(_img: Image) -> void:
	pass
func _draw_rabbit(_img: Image) -> void:
	pass
func _draw_triangle(_img: Image, _x1: int, _y1: int, _x2: int, _y2: int, _x3: int, _y3: int, _c: Color) -> void:
	pass
func _draw_line_h(_img: Image, _y: int, _x1: int, _x2: int, _c: Color) -> void:
	pass
func _draw_line_v(_img: Image, _x: int, _y1: int, _y2: int, _c: Color) -> void:
	pass