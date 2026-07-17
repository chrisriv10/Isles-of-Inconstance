extends CropLayer
class_name StemLayer

enum StemType { STRAIGHT, CURVED, VINE, MUSHROOM_STALK }

@export var stem_type: StemType = StemType.STRAIGHT
@export var height: int = 8
@export var width: int = 2
@export var curve_amount: int = 0

func render(image: Image, center_x: int, center_y: int) -> void:
	var start_y := center_y + height / 2
	var end_y := center_y - height / 2
	
	match stem_type:
		StemType.STRAIGHT:
			_draw_straight_stem(image, center_x, start_y, end_y, center_x, center_y)
		StemType.CURVED:
			_draw_curved_stem(image, center_x, start_y, end_y, center_x, center_y)
		StemType.VINE:
			_draw_vine_stem(image, center_x, start_y, end_y, center_x, center_y)
		StemType.MUSHROOM_STALK:
			_draw_mushroom_stalk(image, center_x, start_y, end_y, center_x, center_y)

func _draw_straight_stem(image: Image, x: int, start_y: int, end_y: int, center_x: int, center_y: int) -> void:
	var half_width := width / 2
	for y in range(end_y, start_y + 1):
		for dx in range(-half_width, half_width + 1):
			var draw_x: int = x + dx
			var draw_y: int = y
			var transformed := apply_transforms(draw_x, draw_y, center_x, center_y)
			PixelArtUtils.set_pixel(image, transformed.x, transformed.y, color)

func _draw_curved_stem(image: Image, x: int, start_y: int, end_y: int, center_x: int, center_y: int) -> void:
	var half_width := width / 2
	for y in range(end_y, start_y + 1):
		var progress := float(y - end_y) / float(max(start_y - end_y, 1))
		var curve_offset := int(curve_amount * sin(progress * PI))
		for dx in range(-half_width, half_width + 1):
			var draw_x: int = x + dx + curve_offset
			var draw_y: int = y
			var transformed := apply_transforms(draw_x, draw_y, center_x, center_y)
			PixelArtUtils.set_pixel(image, transformed.x, transformed.y, color)

func _draw_vine_stem(image: Image, x: int, start_y: int, end_y: int, center_x: int, center_y: int) -> void:
	var half_width: int = max(width / 2, 1)
	for y in range(end_y, start_y + 1):
		var progress := float(y - end_y) / float(max(start_y - end_y, 1))
		var wave_offset := int(2.0 * sin(progress * PI * 4))
		for dx in range(-half_width, half_width + 1):
			var draw_x: int = x + dx + wave_offset
			var draw_y: int = y
			var transformed := apply_transforms(draw_x, draw_y, center_x, center_y)
			PixelArtUtils.set_pixel(image, transformed.x, transformed.y, color)
		
		# Add small tendrils
		if y % 4 == 0:
			var tendril_x: int = x + wave_offset + half_width + 1
			var tendril_y: int = y
			var transformed := apply_transforms(tendril_x, tendril_y, center_x, center_y)
			PixelArtUtils.set_pixel(image, transformed.x, transformed.y, color)

func _draw_mushroom_stalk(image: Image, x: int, start_y: int, end_y: int, center_x: int, center_y: int) -> void:
	var half_width := width / 2
	for y in range(end_y, start_y + 1):
		var progress: float = float(y - end_y) / float(max(start_y - end_y, 1))
		# Taper at top and bottom
		var taper: float = 1.0 - abs(progress - 0.5) * 0.5
		var current_width: int = int(float(half_width) * taper)
		for dx in range(-current_width, current_width + 1):
			var draw_x: int = x + dx
			var draw_y: int = y
			var transformed := apply_transforms(draw_x, draw_y, center_x, center_y)
			PixelArtUtils.set_pixel(image, transformed.x, transformed.y, color)
