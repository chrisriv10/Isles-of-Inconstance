extends Node
class_name EffectSpawner

## Lightweight particle and floating text effect spawner.
## Attach to the World node or use as a singleton for global effects.

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

## Spawn floating text that rises and fades
static func spawn_floating_text(text: String, position: Vector2, color: Color = Color.WHITE) -> void:
	var parent: Node = Engine.get_main_loop().current_scene
	if not parent:
		return
	
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", ThemeDB.fallback_font)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", color)
	label.position = position - Vector2(20, 0)
	label.z_index = 100
	parent.add_child(label)
	
	var tween := label.create_tween()
	tween.set_parallel(false)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position", position + Vector2(0, -32), 0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.3)
	tween.tween_callback(label.queue_free)

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
