extends CropLayer
class_name SpecialEffectsLayer

enum EffectType { GLOW, SPARKLE, SHADOW, OUTLINE, NONE }

@export var effect_type: EffectType = EffectType.NONE
@export var effect_color: Color = Color.WHITE
@export var intensity: float = 0.5
@export var radius: int = 2

func render(image: Image, center_x: int, center_y: int) -> void:
	if effect_type == EffectType.NONE:
		return
	
	match effect_type:
		EffectType.GLOW:
			_apply_glow(image, center_x, center_y)
		EffectType.SPARKLE:
			_apply_sparkle(image, center_x, center_y)
		EffectType.SHADOW:
			_apply_shadow(image, center_x, center_y)
		EffectType.OUTLINE:
			_apply_outline(image, center_x, center_y)

func _apply_glow(image: Image, center_x: int, center_y: int) -> void:
	var width := image.get_width()
	var height := image.get_height()
	var glow_image := PixelArtUtils.create_empty_image(width, height)
	
	for y in range(height):
		for x in range(width):
			var pixel := PixelArtUtils.get_pixel(image, x, y)
			if pixel.a > 0.1:
				# Add glow around pixel
				for dy in range(-radius, radius + 1):
					for dx in range(-radius, radius + 1):
						var dist := sqrt(float(dx * dx + dy * dy))
						if dist <= radius and dist > 0:
							var glow_intensity := intensity * (1.0 - dist / float(radius))
							var glow_color := Color(
								effect_color.r,
								effect_color.g,
								effect_color.b,
								glow_intensity * 0.5
							)
							var gx := x + dx
							var gy := y + dy
							if gx >= 0 and gx < width and gy >= 0 and gy < height:
								PixelArtUtils.blend_pixels(glow_image, gx, gy, glow_color)
	
	# Blend glow back to original
	for y in range(height):
		for x in range(width):
			var original := PixelArtUtils.get_pixel(image, x, y)
			var glow := PixelArtUtils.get_pixel(glow_image, x, y)
			if glow.a > 0.1:
				PixelArtUtils.blend_pixels(image, x, y, glow)

func _apply_sparkle(image: Image, center_x: int, center_y: int) -> void:
	var width := image.get_width()
	var height := image.get_height()
	
	for y in range(height):
		for x in range(width):
			var pixel := PixelArtUtils.get_pixel(image, x, y)
			if pixel.a > 0.1:
				# Random sparkle
				var noise := float((x * 17 + y * 23) % 100) / 100.0
				if noise < intensity:
					var sparkle_color := Color(1.0, 1.0, 1.0, intensity)
					PixelArtUtils.blend_pixels(image, x, y, sparkle_color)

func _apply_shadow(image: Image, center_x: int, center_y: int) -> void:
	var width := image.get_width()
	var height := image.get_height()
	var shadow_image := PixelArtUtils.create_empty_image(width, height)
	
	for y in range(height):
		for x in range(width):
			var pixel := PixelArtUtils.get_pixel(image, x, y)
			if pixel.a > 0.1:
				# Add shadow offset
				var sx := x + 1
				var sy := y + 1
				if sx < width and sy < height:
					var shadow_color := Color(0.0, 0.0, 0.0, intensity * 0.3)
					PixelArtUtils.blend_pixels(shadow_image, sx, sy, shadow_color)
	
	# Blend shadow back to original
	for y in range(height):
		for x in range(width):
			var original := PixelArtUtils.get_pixel(image, x, y)
			var shadow := PixelArtUtils.get_pixel(shadow_image, x, y)
			if shadow.a > 0.1:
				PixelArtUtils.blend_pixels(image, x, y, shadow)

func _apply_outline(image: Image, center_x: int, center_y: int) -> void:
	PixelArtUtils.add_outline(image, effect_color, 1)
