extends Node
class_name EffectSpawner

## Lightweight particle and floating text effect spawner.
## Attach to the World node or use as a singleton for global effects.

## Cached scene tree reference
static var _scene_tree: SceneTree = null

static func _get_scene_tree() -> SceneTree:
	if not _scene_tree or not is_instance_valid(_scene_tree):
		_scene_tree = Engine.get_main_loop() as SceneTree
	return _scene_tree

## Spawn a burst of colored particles at position
static func spawn_particles(position: Vector2, color: Color, count: int = 8, spread: float = 16.0) -> void:
	var parent: Node = Engine.get_main_loop().current_scene
	if not parent:
		return
	
	for i in range(count):
		var particle := ColorRect.new()
		particle.color = color
		particle.size = Vector2(3, 3)
		particle.position = position
		parent.add_child(particle)
		
		var angle := (float(i) / float(count)) * PI * 2.0
		var distance := randf_range(4.0, spread)
		var velocity := Vector2(cos(angle), sin(angle)) * distance
		
		var tween := particle.create_tween()
		tween.set_parallel(true)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(particle, "position", position + velocity, 0.4)
		tween.tween_property(particle, "modulate:a", 0.0, 0.4)
		tween.tween_callback(particle.queue_free)

## ========================================================================
## HEART SPRITE EFFECTS
## ========================================================================

## Cached heart texture (generated procedurally once, reused for all hearts).
static var _heart_texture: ImageTexture = null

## Generates a small pink pixel heart texture on first call, then caches it.
static func _get_heart_texture() -> ImageTexture:
	if _heart_texture:
		return _heart_texture
	
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))  # transparent
	
	var h: Color = Color(1.0, 0.2, 0.5)  # bright pink
	
	# Draw a 10x9 pixel heart centered at (3,3) in the 16x16 canvas
	# Row 0 (blank)
	# Row 1:   xx xx
	_set_px_heart(img, 4, 1, h); _set_px_heart(img, 5, 1, h)
	_set_px_heart(img, 8, 1, h); _set_px_heart(img, 9, 1, h)
	# Row 2:  xxxx xxxx
	for x in range(3, 11): _set_px_heart(img, x, 2, h)
	# Row 3:  xxxxxxxxxx
	for x in range(2, 12): _set_px_heart(img, x, 3, h)
	# Row 4:  xxxxxxxxxx
	for x in range(2, 12): _set_px_heart(img, x, 4, h)
	# Row 5:   xxxxxxxx
	for x in range(3, 11): _set_px_heart(img, x, 5, h)
	# Row 6:    xxxxxx
	for x in range(4, 10): _set_px_heart(img, x, 6, h)
	# Row 7:     xxxx
	for x in range(5, 9): _set_px_heart(img, x, 7, h)
	# Row 8:      xx
	_set_px_heart(img, 6, 8, h); _set_px_heart(img, 7, 8, h)
	
	_heart_texture = ImageTexture.create_from_image(img)
	return _heart_texture

static func _set_px_heart(img: Image, x: int, y: int, c: Color) -> void:
	img.set_pixel(x, y, c)

## Spawn heart sprites that float upward, pulse, and fade out.
## Creates animated heart shapes (using Sprite2D with the pixel heart texture).
static func spawn_hearts(position: Vector2, count: int = 5, spread: float = 12.0, float_height: float = -30.0) -> void:
	var parent: Node = Engine.get_main_loop().current_scene
	if not parent:
		return
	
	var tex: ImageTexture = _get_heart_texture()
	
	for i in range(count):
		var heart := Sprite2D.new()
		heart.texture = tex
		heart.z_index = 100
		heart.global_position = position + Vector2(randf_range(-spread * 0.5, spread * 0.5), 0)
		var heart_scale := randf_range(0.8, 1.3)
		heart.scale = Vector2(heart_scale, heart_scale)
		parent.add_child(heart)
		
		var tween := heart.create_tween()
		tween.set_parallel(true)
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_SINE)
		# Float upward
		var rise_offset := Vector2(0, float_height + randf_range(-8, 0))
		tween.tween_property(heart, "global_position", heart.global_position + rise_offset, 1.0 + randf_range(0, 0.5))
		# Pulse scale slightly bigger then fade
		var pulse_scale := heart_scale * 1.3
		tween.tween_property(heart, "scale", Vector2(pulse_scale, pulse_scale), 0.4)
		tween.chain()
		tween.tween_property(heart, "modulate:a", 0.0, 0.6)
		tween.tween_callback(heart.queue_free)

## ========================================================================
## Spawn floating text that rises and fades.
## The text stays visible for a readable duration before fading out.
static func spawn_floating_text(text: String, position: Vector2, color: Color = Color.WHITE) -> void:
	var parent: Node = Engine.get_main_loop().current_scene
	if not parent:
		return
	
	# Use Node2D + Label with font outline (no background ColorRect that
	# depends on get_minimum_size() before the label is in the scene tree).
	var container := Node2D.new()
	container.z_index = 100
	
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", ThemeDB.fallback_font)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.7))
	container.add_child(label)
	
	# Add to tree BEFORE positioning so label layout is resolved
	parent.add_child(container)
	
	# Position centered above target (no extra offset so it stays on screen)
	var label_size: Vector2 = label.get_minimum_size()
	container.position = position - Vector2(label_size.x / 2.0, label_size.y)
	
	var tween := container.create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	# Float up just a tiny bit and fade out slowly
	# Duration extended so the text persists longer for readability
	tween.tween_property(container, "position", container.position + Vector2(0, -8), 1.5)
	tween.tween_property(container, "modulate:a", 0.0, 2.5)
	tween.set_parallel(false)
	tween.tween_callback(container.queue_free)

## ========================================================================
## ENHANCED FLOATING TEXT METHODS
## ========================================================================

## Spawn a damage number that bounces up and fades.
## If is_critical is true, shows bigger orange text with screen shake.
static func spawn_damage_number(value: int, position: Vector2, is_critical: bool = false) -> void:
	var parent: Node = Engine.get_main_loop().current_scene
	if not parent:
		return
	
	var ft := FloatingText.new()
	ft.global_position = position
	parent.add_child(ft)
	ft.play_damage(value, is_critical)


## Spawn a resource collection notification: "+X ItemName" in the given color.
static func spawn_resource_notification(item_name: String, amount: int, position: Vector2, color: Color) -> void:
	var parent: Node = Engine.get_main_loop().current_scene
	if not parent:
		return
	
	var ft := FloatingText.new()
	ft.global_position = position
	parent.add_child(ft)
	ft.play_resource(item_name, amount, color)


## Spawn a gold collection notification.
static func spawn_collect_notification(amount: int, position: Vector2) -> void:
	var parent: Node = Engine.get_main_loop().current_scene
	if not parent:
		return
	
	var ft := FloatingText.new()
	ft.global_position = position
	parent.add_child(ft)
	ft.play_collect(amount)


## Spawn a combo streak notification.
static func spawn_combo_notification(streak: int, position: Vector2) -> void:
	var parent: Node = Engine.get_main_loop().current_scene
	if not parent:
		return
	
	var ft := FloatingText.new()
	ft.global_position = position
	parent.add_child(ft)
	ft.play_combo(streak)


## Spawn an XP notification floating text at a world position.
static func spawn_xp_notification(amount: int, position: Vector2) -> void:
	var parent: Node = Engine.get_main_loop().current_scene
	if not parent:
		return

	var ft := FloatingText.new()
	ft.global_position = position
	parent.add_child(ft)
	ft.play_xp(amount)


## Spawn player damage feedback.
static func spawn_player_damage(value: int, position: Vector2, blocked: int = 0) -> void:
	var parent: Node = Engine.get_main_loop().current_scene
	if not parent:
		return
	
	var ft := FloatingText.new()
	ft.global_position = position
	parent.add_child(ft)
	ft.play_player_damage(value, blocked)


## ========================================================================
## SCREEN SHAKE
## ========================================================================

## Trigger screen shake on the player's camera.
## strength = pixel offset magnitude, duration = seconds.
static func screen_shake(strength: float = 4.0, duration: float = 0.2) -> void:
	var tree := _get_scene_tree()
	if not tree:
		return
	var player: Node2D = tree.get_first_node_in_group("player")
	if not player:
		return
	var cam: Node = player.get_node_or_null("Camera2D")
	if not cam or not cam.has_method("shake"):
		return
	cam.shake(strength, duration)


## ========================================================================
## LEGACY EFFECTS
## ========================================================================

## Spawn a sparkle effect (for mutations/rare events)
static func spawn_sparkle(position: Vector2, color: Color = Color.GOLD) -> void:
	var parent: Node = Engine.get_main_loop().current_scene
	if not parent:
		return
	
	for i in range(12):
		var particle := ColorRect.new()
		particle.color = color
		particle.size = Vector2(4, 4)
		particle.position = position
		particle.z_index = 50
		parent.add_child(particle)
		
		var angle := randf() * PI * 2.0
		var distance := randf_range(8.0, 24.0)
		var velocity := Vector2(cos(angle), sin(angle)) * distance
		
		var tween := particle.create_tween()
		tween.set_parallel(true)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(particle, "position", position + velocity, 0.5)
		tween.tween_property(particle, "scale", Vector2.ZERO, 0.5)
		tween.tween_property(particle, "modulate:a", 0.0, 0.5)
		tween.tween_callback(particle.queue_free)

## Spawn dirt puff effect (for tilling)
static func spawn_dirt_puff(position: Vector2) -> void:
	var parent: Node = Engine.get_main_loop().current_scene
	if not parent:
		return
	
	for i in range(6):
		var particle := ColorRect.new()
		particle.color = Color(0.6, 0.5, 0.3)
		particle.size = Vector2(4, 4)
		particle.position = position + Vector2(randf_range(-4, 4), randf_range(-2, 2))
		particle.z_index = 5
		parent.add_child(particle)
		
		var tween := particle.create_tween()
		tween.set_parallel(true)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(particle, "position", particle.position + Vector2(0, -randf_range(4, 8)), 0.3)
		tween.tween_property(particle, "modulate:a", 0.0, 0.3)
		tween.tween_callback(particle.queue_free)

## Spawn water droplet effect (for watering)
static func spawn_water_droplets(position: Vector2) -> void:
	var parent: Node = Engine.get_main_loop().current_scene
	if not parent:
		return
	
	for i in range(5):
		var particle := ColorRect.new()
		particle.color = Color(0.5, 0.7, 1.0, 0.7)
		particle.size = Vector2(3, 3)
		particle.position = position + Vector2(randf_range(-6, 6), randf_range(-4, 4))
		particle.z_index = 5
		parent.add_child(particle)
		
		var tween := particle.create_tween()
		tween.set_parallel(true)
		tween.set_ease(Tween.EASE_IN)
		tween.tween_property(particle, "position", particle.position + Vector2(0, randf_range(8, 16)), 0.25)
		tween.tween_property(particle, "modulate:a", 0.0, 0.25)
		tween.tween_callback(particle.queue_free)

## Spawn harvest effect with item icon flying to UI
static func spawn_harvest_effect(position: Vector2, crop_name: String, color: Color) -> void:
	spawn_sparkle(position, color)
	spawn_floating_text("+1 " + crop_name, position, color)
