extends Resource
class_name CropLayer

## Base class for all crop sprite layers

@export var layer_name: String = ""
@export var color: Color = Color.WHITE
@export var offset_x: int = 0
@export var offset_y: int = 0
@export var scale: float = 1.0
@export var rotation: float = 0.0 # In degrees

func render(image: Image, center_x: int, center_y: int) -> void:
	pass

func apply_transforms(x: int, y: int, center_x: int, center_y: int) -> Vector2i:
	var transformed := Vector2i(x, y)
	transformed.x += offset_x
	transformed.y += offset_y
	
	if rotation != 0.0:
		var rad := deg_to_rad(rotation)
		var cos_r := cos(rad)
		var sin_r := sin(rad)
		var rel_x := float(x - center_x)
		var rel_y := float(y - center_y)
		transformed.x = center_x + int(rel_x * cos_r - rel_y * sin_r)
		transformed.y = center_y + int(rel_x * sin_r + rel_y * cos_r)
	
	return transformed
