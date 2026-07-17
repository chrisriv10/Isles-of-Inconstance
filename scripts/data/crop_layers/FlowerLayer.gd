extends CropLayer
class_name FlowerLayer

enum FlowerType { SIMPLE, DAISY, TULIP, ROSE, SPIKES }

@export var flower_type: FlowerType = FlowerType.SIMPLE
@export var petal_count: int = 6
@export var petal_size: int = 3
@export var center_color: Color = Color.YELLOW

func render(image: Image, center_x: int, center_y: int) -> void:
	match flower_type:
		FlowerType.SIMPLE:
			_draw_simple_flower(image, center_x, center_y, center_x, center_y)
		FlowerType.DAISY:
			_draw_daisy(image, center_x, center_y, center_x, center_y)
		FlowerType.TULIP:
			_draw_tulip(image, center_x, center_y, center_x, center_y)
		FlowerType.ROSE:
			_draw_rose(image, center_x, center_y, center_x, center_y)
		FlowerType.SPIKES:
			_draw_spikes(image, center_x, center_y, center_x, center_y)

func _draw_simple_flower(image: Image, x: int, y: int, center_x: int, center_y: int) -> void:
	# Draw petals
	for i in range(petal_count):
		var angle := deg_to_rad(float(i) * 360.0 / float(petal_count))
		var petal_x := x + int(cos(angle) * petal_size)
		var petal_y := y + int(sin(angle) * petal_size)
		PixelArtUtils.draw_circle(image, petal_x, petal_y, petal_size / 2, color)
	
	# Draw center
	PixelArtUtils.draw_circle(image, x, y, petal_size / 3, center_color)

func _draw_daisy(image: Image, x: int, y: int, center_x: int, center_y: int) -> void:
	# Draw long petals
	for i in range(petal_count):
		var angle := deg_to_rad(float(i) * 360.0 / float(petal_count))
		var start_x := x + int(cos(angle) * (petal_size / 2))
		var start_y := y + int(sin(angle) * (petal_size / 2))
		var end_x := x + int(cos(angle) * petal_size * 1.5)
		var end_y := y + int(sin(angle) * petal_size * 1.5)
		PixelArtUtils.draw_line(image, start_x, start_y, end_x, end_y, color)
	
	# Draw center
	PixelArtUtils.draw_circle(image, x, y, petal_size / 2, center_color)

func _draw_tulip(image: Image, x: int, y: int, center_x: int, center_y: int) -> void:
	var half_size := petal_size / 2
	
	# Draw cup-shaped petals
	for i in range(3):
		var offset_x: int = (i - 1) * half_size
		for py in range(-half_size, half_size + 1):
			var width_at_y: float = half_size - abs(py) / 2
			for px in range(-int(width_at_y), int(width_at_y) + 1):
				var draw_x: int = x + offset_x + px
				var draw_y: int = y + py - half_size
				var transformed := apply_transforms(draw_x, draw_y, center_x, center_y)
				PixelArtUtils.set_pixel(image, transformed.x, transformed.y, color)

func _draw_rose(image: Image, x: int, y: int, center_x: int, center_y: int) -> void:
	var layers := 3
	for layer in range(layers):
		var layer_size := petal_size - layer
		var layer_color := PixelArtUtils.shade_color(color, 1.0 - float(layer) * 0.2)
		for i in range(petal_count):
			var angle := deg_to_rad(float(i) * 360.0 / float(petal_count) + layer * 20.0)
			var petal_x := x + int(cos(angle) * layer_size / 2)
			var petal_y := y + int(sin(angle) * layer_size / 2)
			PixelArtUtils.draw_circle(image, petal_x, petal_y, layer_size / 3, layer_color)

func _draw_spikes(image: Image, x: int, y: int, center_x: int, center_y: int) -> void:
	for i in range(petal_count):
		var angle := deg_to_rad(float(i) * 360.0 / float(petal_count))
		var start_x := x + int(cos(angle) * 2)
		var start_y := y + int(sin(angle) * 2)
		var end_x := x + int(cos(angle) * petal_size)
		var end_y := y + int(sin(angle) * petal_size)
		PixelArtUtils.draw_line(image, start_x, start_y, end_x, end_y, color)
