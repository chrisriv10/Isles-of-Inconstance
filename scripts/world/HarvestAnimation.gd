class_name HarvestAnimation
extends RefCounted

## Creates satisfying harvest effects: particles, floating text, camera shake,
## item pop animations, and sparkle bursts. Called by World when harvesting.

static func play_harvest_effect(crop_position: Vector2, crop_name: String, crop_color: Color, quality: int = 1) -> void:
	# Star particles burst
	var star_count := 5 + quality * 3
	for i in range(star_count):
		var angle := randf() * TAU
		var dist := randf_range(8.0, 24.0)
		var target := crop_position + Vector2(cos(angle), sin(angle)) * dist
		var star_color := _get_quality_color(quality, crop_color)
		EffectSpawner.spawn_particles(target, star_color, 3, 8.0)
	
	# Floating text showing item name (quality stars already appended by caller)
	EffectSpawner.spawn_floating_text("+%s!" % crop_name, crop_position, _get_quality_color(quality, crop_color))
	
	# Harvest ring effect
	EffectSpawner.spawn_sparkle(crop_position, crop_color)
	
	# Camera shake
	var camera := _get_camera()
	if camera and camera.has_method("shake"):
		camera.shake(3.0, 0.15)

static func _get_quality_color(quality: int, base: Color) -> Color:
	match quality:
		1: return Color(0.85, 0.85, 0.9)  # SILVER
		2: return Color(1.0, 0.85, 0.3)   # GOLD
		3: return Color(0.7, 0.5, 1.0)    # IRIDIUM (purple)
		_: return base  # NORMAL

static func _get_camera() -> Node:
	var player := _get_player()
	if player:
		return player.get_node_or_null("CameraController")
	return null

static func _get_player() -> Node:
	var main_loop: SceneTree = Engine.get_main_loop()
	if not main_loop:
		return null
	var root := main_loop.root
	if not root:
		return null
	var tree := root.get_tree()
	if not tree:
		return null
	return tree.get_first_node_in_group("player")

## Creates a yield pop animation showing multiple items flying out
static func play_yield_pop(position: Vector2, count: int, color: Color) -> void:
	for i in range(mini(count, 5)):
		var delay := i * 0.05
		var target := position + Vector2(randf_range(-12, 12), randf_range(-16, -4))
		# Use a timer to stagger the pops
		var tree: SceneTree = (Engine.get_main_loop() and Engine.get_main_loop().root and Engine.get_main_loop().root.get_tree() or null)
		if tree:
			tree.create_timer(delay).timeout.connect(func():
				EffectSpawner.spawn_particles(target, color, 2, 6.0)
			)
