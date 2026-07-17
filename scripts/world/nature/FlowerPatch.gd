extends Interactable
class_name FlowerPatch

## Decorative flower patch. Can be harvested for petals/sellable flowers.
## Multiple variants with different colors and shapes.

@export var flower_variant: int = 0  # 0=simple, 1=daisy, 2=tulip, 3=rose
@export var flower_color: Color = Color(1.0, 0.3, 0.5)
@export var flower_count: int = 3

func _ready() -> void:
	interaction_prompt = "Pick Flowers"
	flower_variant = randi() % 4
	flower_color = _random_flower_color()
	flower_count = randi_range(2, 5)
	_generate_sprite()

func _random_flower_color() -> Color:
	var colors := [
		Color(1.0, 0.3, 0.5),  # pink
		Color(1.0, 0.1, 0.1),  # red
		Color(1.0, 0.8, 0.1),  # yellow
		Color(0.9, 0.5, 1.0),  # purple
		Color(1.0, 0.5, 0.0),  # orange
		Color(1.0, 1.0, 1.0),  # white
		Color(0.5, 0.3, 1.0),  # violet
		Color(1.0, 0.6, 0.8),  # light pink
	]
	return colors[randi() % colors.size()]

func _generate_sprite() -> void:
	var sprite_node: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
	if not sprite_node:
		return
	
	var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	
	# Draw stem
	var stem_color := Color(0.2, 0.5, 0.1)
	for y in range(6, 11):
		img.set_pixel(6, y, stem_color)
		img.set_pixel(5, y, stem_color)
	
	# Draw flower head based on variant
	match flower_variant:
		0: _draw_simple_flower(img, 5, 4, flower_color)
		1: _draw_daisy(img, 5, 4, flower_color)
		2: _draw_tulip(img, 5, 4, flower_color)
		3: _draw_rose(img, 5, 4, flower_color)
	
	var tex := ImageTexture.create_from_image(img)
	sprite_node.texture = tex

func _draw_simple_flower(img: Image, cx: int, cy: int, color: Color) -> void:
	# 5 petals
	var petal_offsets := [Vector2i(0, -2), Vector2i(2, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-2, -1)]
	for offset in petal_offsets:
		img.set_pixel(cx + offset.x, cy + offset.y, color)
	img.set_pixel(cx, cy, Color(1.0, 0.9, 0.1))  # center

func _draw_daisy(img: Image, cx: int, cy: int, color: Color) -> void:
	for angle in range(0, 360, 45):
		var rad := deg_to_rad(angle)
		var px := cx + roundi(cos(rad) * 2)
		var py := cy + roundi(sin(rad) * 2)
		img.set_pixel(px, py, color)
	img.set_pixel(cx, cy, Color(1.0, 0.9, 0.1))

func _draw_tulip(img: Image, cx: int, cy: int, color: Color) -> void:
	# U-shape
	for x in range(-2, 3):
		for y in range(-2, 1):
			if abs(x) + abs(y) < 3 and y <= 0:
				img.set_pixel(cx + x, cy + y, color)

func _draw_rose(img: Image, cx: int, cy: int, color: Color) -> void:
	# Layered circles
	for r in range(3, 0, -1):
		var layer_color := color
		layer_color = layer_color.darkened((3 - r) * 0.15)
		for x in range(-r, r + 1):
			for y in range(-r, r + 1):
				if x * x + y * y <= r * r:
					img.set_pixel(cx + x, cy + y, layer_color)

func interact(interactor: Node) -> void:
	if not can_interact():
		return
	
	var leftover := InventoryManager.add_item("flower", flower_count)
	var gathered := flower_count - leftover
	if gathered > 0:
		EffectSpawner.spawn_particles(global_position, flower_color, 8, 10.0)
		ToastNotification.show_toast("Picked %d flowers!" % gathered, ToastNotification.ToastType.SUCCESS, 1.5)
		AudioManager.play(AudioManager.Sound.GATHER)
	
	_used = true
	queue_free()
