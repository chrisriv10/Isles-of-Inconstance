extends Interactable
class_name LogStump

## A fallen log or stump that can be chopped for wood.
## Larger variants give more wood.

@export var stump_variant: int = 0  # 0=small stump, 1=large stump, 2=fallen log
@export var wood_amount: int = 2

func _ready() -> void:
	interaction_prompt = "Chop"
	stump_variant = randi() % 3
	wood_amount = randi_range(1, 4)
	_generate_sprite()

func _generate_sprite() -> void:
	var sprite_node: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
	if not sprite_node:
		return
	
	var img := Image.create(16, 14, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	
	var wood_color := Color(0.5, 0.35, 0.2)
	var ring_color := Color(0.4, 0.28, 0.15)
	
	match stump_variant:
		0: _draw_small_stump(img, wood_color, ring_color)
		1: _draw_large_stump(img, wood_color, ring_color)
		2: _draw_fallen_log(img, wood_color, ring_color)
	
	var tex := ImageTexture.create_from_image(img)
	sprite_node.texture = tex

func _draw_small_stump(img: Image, wood_c: Color, ring_c: Color) -> void:
	# Top oval
	for x in range(3, 11):
		for y in range(2, 7):
			var dx: int = abs(x - 7)
			var dy: int = abs(y - 4)
			if dx * dx * 3 + dy * dy * 3 <= 18:
				img.set_pixel(x, y, wood_c)
	
	# Rings
	img.set_pixel(7, 4, ring_c)
	for r in range(1, 4):
		for x in range(-r, r + 1):
			for y in range(-r, r + 1):
				if abs(x * x + y * y - r * r) <= 2:
					var px: int = 7 + x
					var py: int = 4 + y
					if px >= 0 and px < 16 and py >= 0 and py < 14:
						img.set_pixel(px, py, ring_c)

func _draw_large_stump(img: Image, wood_c: Color, ring_c: Color) -> void:
	for x in range(2, 13):
		for y in range(2, 9):
			var dx: int = abs(x - 7)
			var dy: int = abs(y - 5)
			if dx * dx * 2 + dy * dy * 3 <= 28:
				img.set_pixel(x, y, wood_c)
	
	img.set_pixel(7, 5, ring_c)
	for r in range(2, 5):
		for x in range(-r, r + 1):
			for y in range(-r, r + 1):
				if abs(x * x + y * y - r * r) <= 3:
					var px: int = 7 + x
					var py: int = 5 + y
					if px >= 0 and px < 16 and py >= 0 and py < 14:
						img.set_pixel(px, py, ring_c)

func _draw_fallen_log(img: Image, wood_c: Color, ring_c: Color) -> void:
	# Horizontal log
	for x in range(2, 14):
		for y in range(5, 10):
			var dy: int = abs(y - 7)
			if dy < 3:
				img.set_pixel(x, y, wood_c)
	
	# End rings
	for y in range(5, 10):
		var dy: int = abs(y - 7)
		if dy < 2:
			img.set_pixel(2, y, ring_c)
			img.set_pixel(13, y, ring_c)

func interact(interactor: Node) -> void:
	if not can_interact():
		return
	
	var leftover := InventoryManager.add_item("wood", wood_amount)
	var gathered := wood_amount - leftover
	if gathered > 0:
		EffectSpawner.spawn_dirt_puff(global_position)
		ToastNotification.show_toast("Got %d wood from stump!" % gathered, ToastNotification.ToastType.SUCCESS, 1.5)
		AudioManager.play(AudioManager.Sound.GATHER)
	
	_used = true
	queue_free()
