extends Interactable
class_name MushroomPatch

## A decorative/gatherable mushroom patch with multiple visual variants.

@export var mushroom_variant: int = 0
@export var cap_color: Color = Color(0.8, 0.2, 0.15)
@export var mushroom_count: int = 2
## If set (to a res:// path), use this pre-made texture instead of procedural generation.
## Set this BEFORE _ready() (e.g. before add_child from an island generator).
@export var texture_override_path: String = ""
## If set, picks a random sprite from this pool and applies a random color tint.
## Takes priority over texture_override_path. Set BEFORE _ready().
@export var texture_override_pool: Array = []

func _ready() -> void:
	interaction_prompt = "Gather Mushrooms"
	mushroom_variant = randi() % 4
	cap_color = _random_cap_color()
	mushroom_count = randi_range(2, 4)
	_generate_sprite()

func _random_cap_color() -> Color:
	var colors := [
		Color(0.8, 0.2, 0.15),  # red
		Color(0.9, 0.5, 0.1),   # orange
		Color(0.6, 0.4, 0.7),   # purple
		Color(0.2, 0.6, 0.8),   # blue
		Color(0.2, 0.7, 0.2),   # green
		Color(0.9, 0.7, 0.3),   # yellow
		Color(0.1, 0.1, 0.1),   # dark
		Color(0.9, 0.9, 0.9),   # white
	]
	return colors[randi() % colors.size()]

func _generate_sprite() -> void:
	var sprite_node: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
	if not sprite_node:
		return
	
	# Use texture override pool if provided — picks random + applies cap_color tint
	if not texture_override_pool.is_empty():
		var path: String = texture_override_pool[randi() % texture_override_pool.size()]
		if ResourceLoader.exists(path):
			sprite_node.texture = load(path)
			# Tint the sprite with the random cap color (subtle overlay)
			sprite_node.modulate = Color(
				cap_color.r * 0.5 + 0.5,
				cap_color.g * 0.5 + 0.5,
				cap_color.b * 0.5 + 0.5,
				1.0
			)
		return
	
	# Use texture override if provided
	if not texture_override_path.is_empty() and ResourceLoader.exists(texture_override_path):
		sprite_node.texture = load(texture_override_path)
		return
	
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	
	var stem_color := Color(0.9, 0.85, 0.75)
	
	match mushroom_variant:
		0: _draw_single_mushroom(img, 7, 10, cap_color, stem_color)
		1: 
			_draw_single_mushroom(img, 5, 10, cap_color, stem_color)
			_draw_single_mushroom(img, 9, 10, cap_color.darkened(0.2), stem_color)
		2:
			_draw_single_mushroom(img, 4, 10, cap_color, stem_color)
			_draw_single_mushroom(img, 7, 9, cap_color.lightened(0.1), stem_color)
			_draw_single_mushroom(img, 10, 10, cap_color.darkened(0.15), stem_color)
		3:
			_draw_tall_mushroom(img, 7, 10, cap_color, stem_color)
	
	var tex := ImageTexture.create_from_image(img)
	sprite_node.texture = tex

func _draw_single_mushroom(img: Image, cx: int, base_y: int, cap_c: Color, stem_c: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	# Stem
	for y in range(base_y, base_y + 3):
		if y >= 0 and y < h:
			if cx >= 0 and cx < w:
				img.set_pixel(cx, y, stem_c)
			if cx + 1 >= 0 and cx + 1 < w:
				img.set_pixel(cx + 1, y, stem_c)
	
	# Cap (dome shape)
	for x in range(-3, 4):
		for y in range(-3, 1):
			var px := cx + 1 + x
			var py := base_y - 1 + y
			if x * x + y * y <= 9 and y <= 0 and px >= 0 and px < w and py >= 0 and py < h:
				img.set_pixel(px, py, cap_c)
	
	# Spots on cap
	if randi() % 2 == 0:
		var spot_y1 := base_y - 3
		var spot_y2 := base_y - 2
		if cx >= 0 and cx < w and spot_y1 >= 0 and spot_y1 < h:
			img.set_pixel(cx, spot_y1, Color(1.0, 1.0, 1.0, 0.7))
		if cx + 2 >= 0 and cx + 2 < w and spot_y2 >= 0 and spot_y2 < h:
			img.set_pixel(cx + 2, spot_y2, Color(1.0, 1.0, 1.0, 0.6))

func _draw_tall_mushroom(img: Image, cx: int, base_y: int, cap_c: Color, stem_c: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for y in range(base_y, base_y + 5):
		if y >= 0 and y < h:
			if cx >= 0 and cx < w:
				img.set_pixel(cx, y, stem_c)
			if cx + 1 >= 0 and cx + 1 < w:
				img.set_pixel(cx + 1, y, stem_c)
	
	# Larger cap
	for x in range(-4, 5):
		for y in range(-4, 1):
			var px := cx + 1 + x
			var py := base_y - 2 + y
			if x * x + y * y <= 12 and y <= 0 and px >= 0 and px < w and py >= 0 and py < h:
				img.set_pixel(px, py, cap_c)

func interact(interactor: Node) -> void:
	if not can_interact():
		return
	
	var level_bonus: int = 0
	if interactor and interactor.is_in_group("player"):
		level_bonus = floori(LevelManager.get_level() / 10.0)
	var leftover := InventoryManager.add_item("mushroom", mushroom_count + level_bonus, cap_color)
	var gathered := mushroom_count - leftover
	if gathered > 0:
		EffectSpawner.spawn_particles(global_position, cap_color, 6, 8.0)
		EffectSpawner.spawn_floating_text("+%d Mushrooms!" % gathered, global_position, Color(0.8, 0.5, 0.15))
		AudioManager.play(AudioManager.Sound.GATHER)
		LevelManager.add_xp_source("gather")
		var om := get_tree().get_first_node_in_group("objective_manager")
		if om and om.has_method("on_gather_wild"):
			om.on_gather_wild("mushroom", gathered)
	
	_used = true
	queue_free()
