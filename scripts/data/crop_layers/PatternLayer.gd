extends CropLayer
class_name PatternLayer

enum PatternType { DOTS, STRIPES, CHECKER, SPOTS, SPIRAL, NONE }

@export var pattern_type: PatternType = PatternType.NONE
@export var pattern_color: Color = Color.WHITE
@export var pattern_scale: int = 2
@export var density: float = 0.5

func render(image: Image, center_x: int, center_y: int) -> void:
	if pattern_type == PatternType.NONE:
		return
	
	var width := image.get_width()
	var height := image.get_height()
	
	for y in range(height):
		for x in range(width):
			var pixel := PixelArtUtils.get_pixel(image, x, y)
			if pixel.a > 0.1:
				if _should_draw_pattern(x, y):
					var transformed := apply_transforms(x, y)
					PixelArtUtils.blend_pixels(image, transformed.x, transformed.y, pattern_color)

func _should_draw_pattern(x: int, y: int) -> bool:
	match pattern_type:
		PatternType.DOTS:
			return (x % pattern_scale == 0) and (y % pattern_scale == 0)
		PatternType.STRIPES:
			return (x + y) % pattern_scale == 0
		PatternType.CHECKER:
			return ((x / pattern_scale) + (y / pattern_scale)) % 2 == 0
		PatternType.SPOTS:
			var noise := float((x * 7 + y * 13) % 100) / 100.0
			return noise < density
		PatternType.SPIRAL:
			var dx := x - offset_x
			var dy := y - offset_y
			var dist := sqrt(float(dx * dx + dy * dy))
			var angle := atan2(float(dy), float(dx))
			var spiral := (dist / pattern_scale + angle / PI) % 1.0
			return spiral < density
		_:
			return false
