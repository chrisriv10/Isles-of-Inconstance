extends CropLayer
class_name FruitBodyLayer

enum BodyType { CIRCLE, OVAL, DIAMOND, STAR, MUSHROOM_CAP, BELL, CARROT, CORN_COB, TOMATO, PUMPKIN, INCONSTANT_FRUIT }

@export var body_type: BodyType = BodyType.CIRCLE
@export var size: int = 6
@export var width_ratio: float = 1.0 # For oval shapes

func render(image: Image, center_x: int, center_y: int) -> void:
	match body_type:
		BodyType.CIRCLE:
			_draw_circle(image, center_x, center_y, center_x, center_y)
		BodyType.OVAL:
			_draw_oval(image, center_x, center_y, center_x, center_y)
		BodyType.DIAMOND:
			_draw_diamond(image, center_x, center_y, center_x, center_y)
		BodyType.STAR:
			_draw_star(image, center_x, center_y, center_x, center_y)
		BodyType.MUSHROOM_CAP:
			_draw_mushroom_cap(image, center_x, center_y, center_x, center_y)
		BodyType.BELL:
			_draw_bell(image, center_x, center_y, center_x, center_y)
		BodyType.CARROT:
			_draw_carrot(image, center_x, center_y, center_x, center_y)
		BodyType.CORN_COB:
			_draw_corn_cob(image, center_x, center_y, center_x, center_y)
		BodyType.TOMATO:
			_draw_tomato(image, center_x, center_y, center_x, center_y)
		BodyType.PUMPKIN:
			_draw_pumpkin(image, center_x, center_y, center_x, center_y)
		BodyType.INCONSTANT_FRUIT:
			_draw_inconstant_fruit(image, center_x, center_y, center_x, center_y)

func _draw_circle(image: Image, x: int, y: int, _center_x: int, _center_y: int) -> void:
	var radius := size / 2
	PixelArtUtils.draw_circle(image, x, y, radius, color)

func _draw_oval(image: Image, x: int, y: int, _center_x: int, _center_y: int) -> void:
	var radius_x := int(float(size) / 2.0 * width_ratio)
	var radius_y := size / 2
	PixelArtUtils.draw_ellipse(image, x, y, radius_x, radius_y, color)

func _draw_diamond(image: Image, x: int, y: int, center_x: int, center_y: int) -> void:
	var half_size := size / 2
	var points: Array[Vector2i] = [
		Vector2i(x, y - half_size),
		Vector2i(x + half_size, y),
		Vector2i(x, y + half_size),
		Vector2i(x - half_size, y)
	]
	for i in range(points.size()):
		var p1: Vector2i = points[i]
		var p2: Vector2i = points[(i + 1) % points.size()]
		PixelArtUtils.draw_line(image, p1.x, p1.y, p2.x, p2.y, color)
	
	# Fill
	for py in range(y - half_size, y + half_size + 1):
		for px in range(x - half_size, x + half_size + 1):
			var dx: int = abs(px - x)
			var dy: int = abs(py - y)
			if dx + dy <= half_size:
				var transformed := apply_transforms(px, py, center_x, center_y)
				PixelArtUtils.set_pixel(image, transformed.x, transformed.y, color)

func _draw_star(image: Image, x: int, y: int, _center_x: int, _center_y: int) -> void:
	var half_size := size / 2
	var points: Array[Vector2i] = []
	for i in range(5):
		var angle := deg_to_rad(float(i) * 72.0 - 90.0)
		points.append(Vector2i(
			x + int(cos(angle) * half_size),
			y + int(sin(angle) * half_size)
		))
	
	# Draw star outline
	for i in range(points.size()):
		var p1: Vector2i = points[i]
		var p2: Vector2i = points[(i + 2) % points.size()]
		PixelArtUtils.draw_line(image, p1.x, p1.y, p2.x, p2.y, color)
	
	# Fill center
	PixelArtUtils.draw_circle(image, x, y, half_size / 2, color)

func _draw_mushroom_cap(image: Image, x: int, y: int, center_x: int, center_y: int) -> void:
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
				var transformed := apply_transforms(px, py, center_x, center_y)
				PixelArtUtils.set_pixel(image, transformed.x, transformed.y, color)

func _draw_bell(image: Image, x: int, y: int, center_x: int, center_y: int) -> void:
	var half_size := size / 2
	var bell_width := half_size
	var bell_height := half_size + 2
	
	for py in range(y - bell_height, y + 1):
		var progress := float(py - (y - bell_height)) / float(bell_height)
		var width_at_y: float = bell_width * sin(progress * PI)
		for px in range(x - int(width_at_y), x + int(width_at_y) + 1):
			var transformed := apply_transforms(px, py, center_x, center_y)
			PixelArtUtils.set_pixel(image, transformed.x, transformed.y, color)

# --- Recognizable crop shapes ---

func _draw_carrot(image: Image, x: int, y: int, center_x: int, center_y: int) -> void:
	# Tapered cone (narrow at bottom, wider at top) with horizontal belly lines
	var half_size := size / 2
	var top_y: int = y - half_size - 1
	var bottom_y: int = y + half_size
	var max_width := half_size + 1
	for py in range(top_y, bottom_y + 1):
		var progress := float(py - top_y) / float(max(bottom_y - top_y, 1))
		var row_width := int(max_width * (1.0 - progress * 0.7))  # narrows toward bottom
		var belly := int(2.0 * sin(progress * PI * 3.0))  # subtle horizontal ridges
		if abs(belly) > 0 and bool(py % 2 == 1):
			row_width = maxi(row_width - 1, 1)
		for px in range(x - row_width, x + row_width + 1):
			var transformed := apply_transforms(px, py, center_x, center_y)
			PixelArtUtils.set_pixel(image, transformed.x, transformed.y, color)

func _draw_corn_cob(image: Image, x: int, y: int, center_x: int, center_y: int) -> void:
	# Elongated oval (taller than wide) with horizontal kernel rows
	var half_size := size / 2
	var cob_width := half_size
	var cob_height := half_size + 2
	var top_y := y - cob_height
	var bottom_y := y + cob_height
	for py in range(top_y, bottom_y + 1):
		var progress := float(py - top_y) / float(max(bottom_y - top_y, 1))
		var row_width := int(float(cob_width) * sin(progress * PI))
		for px in range(x - row_width, x + row_width + 1):
			var transformed := apply_transforms(px, py, center_x, center_y)
			PixelArtUtils.set_pixel(image, transformed.x, transformed.y, color)
		# Kernel dots across each row
		if py % 2 == 0:
			for kx in [x - row_width + 2, x, x + row_width - 2]:
				if abs(kx - x) <= row_width - 1:
					var kernel := apply_transforms(kx, py, center_x, center_y)
					PixelArtUtils.set_pixel(image, kernel.x, kernel.y, Color(1.0, 0.9, 0.3))

func _draw_tomato(image: Image, x: int, y: int, center_x: int, center_y: int) -> void:
	# Slightly flattened circle with a small top indent
	var half_size := size / 2
	var radius_y := half_size
	var radius_x := half_size + 1  # slightly wider than tall
	for py in range(y - radius_y, y + radius_y + 1):
		var rel_y := float(py - y) / float(radius_y)
		# Top indent: flatten the top part slightly
		var indent := 0.0
		if rel_y < -0.3:
			indent = 2.0 * (abs(rel_y) - 0.3) / 0.7
		var row_width := int(float(radius_x) * sqrt(1.0 - rel_y * rel_y) - indent)
		for px in range(x - row_width, x + row_width + 1):
			var transformed := apply_transforms(px, py, center_x, center_y)
			PixelArtUtils.set_pixel(image, transformed.x, transformed.y, color)

func _draw_inconstant_fruit(image: Image, x: int, y: int, center_x: int, center_y: int) -> void:
	# A swirling vortex fruit — wide base with spiral pattern and glowing core
	var half_size := size / 2
	var radius := half_size + 1
	# Draw the round fruit body
	for py in range(y - radius, y + radius + 1):
		var rel_y := float(py - y) / float(radius)
		var row_width := int(float(radius) * sqrt(1.0 - rel_y * rel_y))
		for px in range(x - row_width, x + row_width + 1):
			var angle := atan2(float(py - y), float(px - x))
			var dist := sqrt(float((px - x) * (px - x) + (py - y) * (py - y)))
			# Spiral swirl pattern: darker arcs spiral outward
			var swirl := sin(dist * 1.5 - angle * 3.0)
			var swirl_color := color
			if swirl > 0.3:
				swirl_color = Color(
					clampf(color.r * 1.4, 0, 1),
					clampf(color.g * 0.8, 0, 1),
					clampf(color.b * 1.6, 0, 1)
				)
			elif swirl < -0.3:
				swirl_color = Color(
					clampf(color.r * 0.6, 0, 1),
					clampf(color.g * 1.3, 0, 1),
					clampf(color.b * 0.4, 0, 1)
				)
			var transformed := apply_transforms(px, py, center_x, center_y)
			PixelArtUtils.set_pixel(image, transformed.x, transformed.y, swirl_color)
	# Glowing core
	PixelArtUtils.draw_circle(image, x, y, maxi(radius / 3, 1), Color(1.0, 0.95, 0.8, 0.9))


func _draw_pumpkin(image: Image, x: int, y: int, center_x: int, center_y: int) -> void:
	# Wide oblong with vertical segment lines
	var half_size := size / 2
	var radius_y := half_size
	var radius_x := half_size + 2
	for py in range(y - radius_y, y + radius_y + 1):
		var rel_y := float(py - y) / float(radius_y)
		var row_width := int(float(radius_x) * sqrt(1.0 - rel_y * rel_y))
		for px in range(x - row_width, x + row_width + 1):
			var transformed := apply_transforms(px, py, center_x, center_y)
			PixelArtUtils.set_pixel(image, transformed.x, transformed.y, color)
		# Vertical crease lines at 1/3 and -1/3 of row width
		var crease_a := x - row_width / 3
		var crease_b := x + row_width / 3
		if py % 2 == 0:
			var c1 := apply_transforms(crease_a, py, center_x, center_y)
			PixelArtUtils.set_pixel(image, c1.x, c1.y, Color(0.8, 0.5, 0.1))
			var c2 := apply_transforms(crease_b, py, center_x, center_y)
			PixelArtUtils.set_pixel(image, c2.x, c2.y, Color(0.8, 0.5, 0.1))
