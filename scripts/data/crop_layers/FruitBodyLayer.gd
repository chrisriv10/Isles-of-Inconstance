extends CropLayer
class_name FruitBodyLayer

enum BodyType { CIRCLE, OVAL, DIAMOND, STAR, MUSHROOM_CAP, BELL }

@export var body_type: BodyType = BodyType.CIRCLE
@export var size: int = 6
@export var width_ratio: float = 1.0 # For oval shapes

func render(image: Image, center_x: int, center_y: int) -> void:
	match body_type:
		BodyType.CIRCLE:
			_draw_circle(image, center_x, center_y)
		BodyType.OVAL:
			_draw_oval(image, center_x, center_y)
		BodyType.DIAMOND:
			_draw_diamond(image, center_x, center_y)
		BodyType.STAR:
			_draw_star(image, center_x, center_y)
		BodyType.MUSHROOM_CAP:
			_draw_mushroom_cap(image, center_x, center_y)
		BodyType.BELL:
			_draw_bell(image, center_x, center_y)

func _draw_circle(image: Image, x: int, y: int) -> void:
	var radius := size / 2
	PixelArtUtils.draw_circle(image, x, y, radius, color)

func _draw_oval(image: Image, x: int, y: int) -> void:
	var radius_x := int(float(size) / 2.0 * width_ratio)
	var radius_y := size / 2
	PixelArtUtils.draw_ellipse(image, x, y, radius_x, radius_y, color)

func _draw_diamond(image: Image, x: int, y: int) -> void:
	var half_size := size / 2
	var points := [
		Vector2i(x, y - half_size),
		Vector2i(x + half_size, y),
		Vector2i(x, y + half_size),
		Vector2i(x - half_size, y)
	]
	for i in range(points.size()):
		var p1 := points[i]
		var p2 := points[(i + 1) % points.size()]
		PixelArtUtils.draw_line(image, p1.x, p1.y, p2.x, p2.y, color)
	
	# Fill
	for py in range(y - half_size, y + half_size + 1):
		for px in range(x - half_size, x + half_size + 1):
			var dx := abs(px - x)
			var dy := abs(py - y)
			if dx + dy <= half_size:
				var transformed := apply_transforms(px, py)
				PixelArtUtils.set_pixel(image, transformed.x, transformed.y, color)

func _draw_star(image: Image, x: int, y: int) -> void:
	var half_size := size / 2
	var points := []
	for i in range(5):
		var angle := deg_to_rad(float(i) * 72.0 - 90.0)
		points.append(Vector2i(
			x + int(cos(angle) * half_size),
			y + int(sin(angle) * half_size)
		))
	
	# Draw star outline
	for i in range(points.size()):
		var p1 := points[i]
		var p2 := points[(i + 2) % points.size()]
		PixelArtUtils.draw_line(image, p1.x, p1.y, p2.x, p2.y, color)
	
	# Fill center
	PixelArtUtils.draw_circle(image, x, y, half_size / 2, color)

func _draw_mushroom_cap(image: Image, x: int, y: int) -> void:
	var half_size := size / 2
	var cap_width := half_size + 2
	var cap_height := half_size
	
	# Draw semicircle cap
	for py in range(y - cap_height, y + 1):
		for px in range(x - cap_width, x + cap_width + 1):
			var rel_y := float(py - (y - cap_height / 2))
			var rel_x := float(px - x)
			var dist := sqrt(rel_x * rel_x + rel_y * rel_y)
			if dist <= cap_width and py <= y:
				var transformed := apply_transforms(px, py)
				PixelArtUtils.set_pixel(image, transformed.x, transformed.y, color)

func _draw_bell(image: Image, x: int, y: int) -> void:
	var half_size := size / 2
	var bell_width := half_size
	var bell_height := half_size + 2
	
	for py in range(y - bell_height, y + 1):
		var progress := float(py - (y - bell_height)) / float(bell_height)
		var width_at_y := bell_width * sin(progress * PI)
		for px in range(x - int(width_at_y), x + int(width_at_y) + 1):
			var transformed := apply_transforms(px, py)
			PixelArtUtils.set_pixel(image, transformed.x, transformed.y, color)
