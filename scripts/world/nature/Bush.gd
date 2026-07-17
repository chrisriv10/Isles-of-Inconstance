extends Interactable
class_name Bush

## A harvestable bush that gives berries or leaves.
## Comes in different sizes and berry colors.

@export var bush_variant: int = 0  # 0=small, 1=medium, 2=large
@export var berry_color: Color = Color(0.8, 0.2, 0.2)
@export var berry_count: int = 2
@export var regrow_days: int = 3

var _harvested: bool = false
var _days_since_harvest: int = 0

func _ready() -> void:
	interaction_prompt = "Harvest"
	bush_variant = randi() % 3
	berry_color = _random_berry_color()
	berry_count = randi_range(1, 4)
	_generate_sprite()
	# Connect to day tracking so bushes can regrow after harvest
	if GameManager.day_changed.is_connected(_on_day_passed):
		pass
	GameManager.day_changed.connect(_on_day_passed)

func _random_berry_color() -> Color:
	var colors := [
		Color(0.8, 0.2, 0.2),  # red
		Color(0.2, 0.4, 0.8),  # blue
		Color(0.8, 0.2, 0.8),  # purple
		Color(0.2, 0.6, 0.2),  # green
		Color(1.0, 0.7, 0.1),  # orange
		Color(0.1, 0.1, 0.1),  # black
	]
	return colors[randi() % colors.size()]

func _generate_sprite() -> void:
	var sprite_node: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
	if not sprite_node:
		return
	
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	
	# Draw bush body (green)
	var bush_color := Color(0.2, 0.6, 0.15)
	if bush_variant == 0:
		_draw_bush_small(img, bush_color)
	elif bush_variant == 1:
		_draw_bush_medium(img, bush_color)
	else:
		_draw_bush_large(img, bush_color)
	
	# Draw berries
	_draw_berries(img, berry_color)
	
	var tex := ImageTexture.create_from_image(img)
	sprite_node.texture = tex

func _draw_bush_small(img: Image, color: Color) -> void:
	for y in range(6, 12):
		for x in range(5, 11):
			var dx: int = abs(x - 8)
			var dy: int = abs(y - 9)
			if dx + dy < 4:
				img.set_pixel(x, y, color)

func _draw_bush_medium(img: Image, color: Color) -> void:
	for y in range(4, 13):
		for x in range(3, 13):
			var dx: int = abs(x - 8)
			var dy: int = abs(y - 8)
			if dx + dy < 6:
				img.set_pixel(x, y, color)

func _draw_bush_large(img: Image, color: Color) -> void:
	for y in range(3, 14):
		for x in range(2, 14):
			var dx: int = abs(x - 8)
			var dy: int = abs(y - 8)
			if dx + dy < 7:
				img.set_pixel(x, y, color)

func _draw_berries(img: Image, color: Color) -> void:
	var berry_positions: Array[Vector2i] = []
	match bush_variant:
		0: berry_positions = [Vector2i(7, 8), Vector2i(9, 9)]
		1: berry_positions = [Vector2i(6, 7), Vector2i(10, 8), Vector2i(8, 10)]
		2: berry_positions = [Vector2i(5, 6), Vector2i(7, 5), Vector2i(9, 6), Vector2i(11, 8), Vector2i(6, 10)]
	
	for pos in berry_positions:
		img.set_pixel(pos.x, pos.y, color)
		img.set_pixel(pos.x + 1, pos.y, color)
		img.set_pixel(pos.x, pos.y + 1, color)
		img.set_pixel(pos.x + 1, pos.y + 1, color)

func interact(interactor: Node) -> void:
	if not can_interact() or _harvested:
		return
	
	InventoryManager.add_item("berry", berry_count)
	EffectSpawner.spawn_dirt_puff(global_position)
	ToastNotification.show_toast("Harvested %d berries from bush!" % berry_count, ToastNotification.ToastType.SUCCESS, 1.5)
	AudioManager.play(AudioManager.Sound.GATHER)
	
	_harvested = true
	# Reduce sprite size to show harvested
	var sprite_node: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
	if sprite_node:
		sprite_node.modulate = Color(0.5, 0.5, 0.3)
	interaction_prompt = "Regrowing..."

func _on_day_passed(_day: int) -> void:
	if _harvested:
		_days_since_harvest += 1
		if _days_since_harvest >= regrow_days:
			_harvested = false
			_days_since_harvest = 0
			var sprite_node: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
			if sprite_node:
				sprite_node.modulate = Color.WHITE
			interaction_prompt = "Harvest"
