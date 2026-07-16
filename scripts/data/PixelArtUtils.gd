extends Node
class_name PixelArtUtils

## Utility functions for procedural pixel art generation

static func create_empty_image(width: int, height: int) -> Image:
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	return image

static func set_pixel(image: Image, x: int, y: int, color: Color):
	if x >= 0 and x < image.get_width() and y >= 0 and y < image.get_height():
		image.set_pixel(x, y, color)

static func get_pixel(image: Image, x: int, y: int) -> Color:
	if x >= 0 and x < image.get_width() and y >= 0 and y < image.get_height():
		return image.get_pixel(x, y)
	return Color(0, 0, 0, 0)

static func draw_circle(image: Image, center_x: int, center_y: int, radius: int, color: Color):
	for y in range(center_y - radius, center_y + radius + 1):
		for x in range(center_x - radius, center_x + radius + 1):
			var dx := x - center_x
			var dy := y - center_y
			if dx * dx + dy * dy <= radius * radius:
				set_pixel(image, x, y, color)

static func draw_ellipse(image: Image, center_x: int, center_y: int, radius_x: int, radius_y: int, color: Color):
	for y in range(center_y - radius_y, center_y + radius_y + 1):
		for x in range(center_x - radius_x, center_x + radius_x + 1):
			var dx := float(x - center_x) / float(radius_x)
			var dy := float(y - center_y) / float(radius_y)
			if dx * dx + dy * dy <= 1.0:
				set_pixel(image, x, y, color)

static func draw_rect(image: Image, x: int, y: int, width: int, height: int, color: Color, filled: bool = true):
	if filled:
		for py in range(y, y + height):
			for px in range(x, x + width):
				set_pixel(image, px, py, color)
	else:
		for px in range(x, x + width):
			set_pixel(image, px, y, color)
			set_pixel(image, px, y + height - 1, color)
		for py in range(y, y + height):
			set_pixel(image, x, py, color)
			set_pixel(image, x + width - 1, py, color)

static func draw_line(image: Image, x0: int, y0: int, x1: int, y1: int, color: Color):
	var dx := absi(x1 - x0)
	var dy := -absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx + dy
	
	while true:
		set_pixel(image, x0, y0, color)
		if x0 == x1 and y0 == y1:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy

static func draw_triangle(image: Image, x0: int, y0: int, x1: int, y1: int, x2: int, y2: int, color: Color, filled: bool = true):
	if filled:
		# Scanline fill
		var min_y := mini(y0, mini(y1, y2))
		var max_y := maxi(y0, maxi(y1, y2))
		
		for y in range(min_y, max_y + 1):
			var intersections: Array = []
			
			for i in range(3):
				var ax: int
				var ay: int
				var bx: int
				var by: int
				match i:
					0:
						ax = x0
						ay = y0
						bx = x1
						by = y1
					1:
						ax = x1
						ay = y1
						bx = x2
						by = y2
					2:
						ax = x2
						ay = y2
						bx = x0
						by = y0
				
				if (ay <= y and by > y) or (by <= y and ay > y):
					var t := float(y - ay) / float(by - ay)
					var x := floori(float(ax) + t * float(bx - ax))
					intersections.append(x)
			
			intersections.sort()
			for i in range(0, intersections.size() - 1, 2):
				if i + 1 < intersections.size():
					for x in range(intersections[i], intersections[i + 1] + 1):
						set_pixel(image, x, y, color)
	else:
		draw_line(image, x0, y0, x1, y1, color)
		draw_line(image, x1, y1, x2, y2, color)
		draw_line(image, x2, y2, x0, y0, color)

static func blend_pixels(image: Image, x: int, y: int, color: Color):
	var existing := get_pixel(image, x, y)
	var alpha := color.a
	var blended := Color(
		existing.r * (1.0 - alpha) + color.r * alpha,
		existing.g * (1.0 - alpha) + color.g * alpha,
		existing.b * (1.0 - alpha) + color.b * alpha,
		minf(existing.a + alpha, 1.0)
	)
	set_pixel(image, x, y, blended)

static func add_outline(image: Image, color: Color, thickness: int = 1):
	var width := image.get_width()
	var height := image.get_height()
	var outline_image := create_empty_image(width, height)
	
	for y in range(height):
		for x in range(width):
			var pixel := get_pixel(image, x, y)
			if pixel.a > 0.1:
				# Check neighbors for outline
				var is_edge := false
				for dy in range(-thickness, thickness + 1):
					for dx in range(-thickness, thickness + 1):
						if dx == 0 and dy == 0:
							continue
						var neighbor := get_pixel(image, x + dx, y + dy)
						if neighbor.a <= 0.1:
							is_edge = true
							break
					if is_edge:
						break
				if is_edge:
					set_pixel(outline_image, x, y, color)
				else:
					set_pixel(outline_image, x, y, pixel)
	
	# Copy outline back to original
	for y in range(height):
		for x in range(width):
			image.set_pixel(x, y, outline_image.get_pixel(x, y))

static func shade_color(base_color: Color, factor: float) -> Color:
	return Color(
		clampf(base_color.r * factor, 0.0, 1.0),
		clampf(base_color.g * factor, 0.0, 1.0),
		clampf(base_color.b * factor, 0.0, 1.0),
		base_color.a
	)

static func image_to_texture(image: Image) -> ImageTexture:
	var texture := ImageTexture.new()
	texture.set_image(image)
	return texture
