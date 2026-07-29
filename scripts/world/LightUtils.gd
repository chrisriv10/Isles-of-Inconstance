class_name LightUtils
extends RefCounted

## Utility for creating PointLight2D textures.
## PointLight2D requires a texture to emit visible light — the default is null,
## so lights are invisible without calling make_light_texture().

## Create a soft circular gradient texture for use as a PointLight2D texture.
## Uses an Image with pixel-level alpha clipping outside the inscribed circle
## so the light is a perfect circle, not a square with gradient corners.
static func make_light_texture(size: int = 128) -> Texture2D:
	var half := size / 2.0
	var radius := half - 1.0
	var inner_radius := radius * 0.35
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			var dx := x - half + 0.5
			var dy := y - half + 0.5
			var dist := sqrt(dx * dx + dy * dy)
			var a: float
			if dist >= radius:
				a = 0.0
			elif dist <= inner_radius:
				a = 1.0
			else:
				var t := (dist - inner_radius) / (radius - inner_radius)
				a = 1.0 - t * t  # smooth quadratic falloff
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(img)