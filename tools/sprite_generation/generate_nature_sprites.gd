extends SceneTree

## DEPRECATED — All nature sprites are now AI-generated via Ziva's generate_pixel_art.
## See res://assets/generated/{biome}_{type}_01.png for the current sprites.
## This script is kept for reference only and will NOT overwrite existing sprites.

func _init() -> void:
	print("DEPRECATED: Nature sprites are now AI-generated.")
	print("Existing sprites in res://assets/generated/ are from AI generation.")
	print("Skipping procedural generation to avoid overwriting AI sprites.")
	quit()

func fill_circle(img: Image, cx: int, cy: int, r: int, color: Color) -> void:
	for x in range(-r, r + 1):
		for y in range(-r, r + 1):
			if x*x + y*y <= r*r:
				var px = cx + x
				var py = cy + y
				if px >= 0 and px < img.get_width() and py >= 0 and py < img.get_height():
					img.set_pixel(px, py, color)

func fill_rect(img: Image, cx: float, cy: float, w: float, h: float, color: Color) -> void:
	var half_w = int(w / 2.0)
	var half_h = int(h / 2.0)
	for x in range(int(cx) - half_w, int(cx) + half_w + 1):
		for y in range(int(cy) - half_h, int(cy) + half_h + 1):
			if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
				img.set_pixel(x, y, color)

func draw_bush(img: Image, cx: int, cy: int, bush_color: Color, berry_color: Color, rng: RandomNumberGenerator) -> void:
	fill_circle(img, cx, cy, 5, bush_color)
	fill_circle(img, cx-3, cy+2, 4, bush_color.darkened(0.1))
	fill_circle(img, cx+3, cy+1, 4, bush_color.darkened(0.1))
	fill_circle(img, cx, cy-3, 3, bush_color.lightened(0.15))
	# Berries
	for i in range(4):
		var bx = cx - 2 + rng.randi() % 5
		var by = cy - 2 + rng.randi() % 5
		img.set_pixel(bx, by, berry_color)
		img.set_pixel(bx+1, by, berry_color)
		img.set_pixel(bx, by+1, berry_color)
		img.set_pixel(bx+1, by+1, berry_color)

func draw_flower(img: Image, cx: int, cy: int, stem_color: Color, petal_color: Color, center_color: Color) -> void:
	# Stem
	for y in range(4):
		img.set_pixel(cx, cy + y, stem_color)
		img.set_pixel(cx-1, cy + y, stem_color)
	# Petals
	for angle in range(0, 360, 45):
		var rad = deg_to_rad(float(angle))
		var px = cx + int(cos(rad) * 2.5)
		var py = cy - 2 + int(sin(rad) * 2.5)
		if px >= 0 and px < img.get_width() and py >= 0 and py < img.get_height():
			img.set_pixel(px, py, petal_color)
	# Center
	img.set_pixel(cx, cy - 2, center_color)

func draw_mushroom(img: Image, cx: int, cy: int, stem_color: Color, cap_color: Color, spot_color: Color) -> void:
	# Stem
	for y in range(4):
		img.set_pixel(cx, cy + y, stem_color)
		img.set_pixel(cx+1, cy + y, stem_color)
	# Cap
	for x in range(-4, 5):
		for y in range(-3, 1):
			if x*x + y*y <= 9 and y <= 0:
				var px = cx + 1 + x
				var py = cy - 1 + y
				if px >= 0 and px < img.get_width() and py >= 0 and py < img.get_height():
					img.set_pixel(px, py, cap_color)
	# Spots
	for i in range(3):
		var sx = cx - 1 + (i % 3)
		var sy = cy - 3
		if sx >= 0 and sx < img.get_width() and sy >= 0 and sy < img.get_height():
			img.set_pixel(sx, sy, spot_color)

# === SNOWLAND NATURE ===
func generate_snowland(rng: RandomNumberGenerator) -> void:
	# Snowland bush - frosty blue-green
	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0,0,0,0))
	draw_bush(img, 8, 10, Color(0.2, 0.55, 0.5), Color(0.5, 0.7, 1.0), rng)
	img.save_png("res://assets/generated/snowland_bush_01.png")
	print("snowland_bush_01 done")
	
	# Snowland flower - white/blue
	img = Image.create(12, 12, false, Image.FORMAT_RGBA8)
	img.fill(Color(0,0,0,0))
	draw_flower(img, 6, 8, Color(0.3, 0.5, 0.6), Color(0.8, 0.9, 1.0), Color(0.6, 0.8, 1.0))
	img.save_png("res://assets/generated/snowland_flower_01.png")
	print("snowland_flower_01 done")
	
	# Snowland mushroom - white with blue spots
	img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0,0,0,0))
	draw_mushroom(img, 6, 10, Color(0.8, 0.85, 0.9), Color(0.6, 0.7, 0.9), Color(0.3, 0.5, 0.8))
	img.save_png("res://assets/generated/snowland_mushroom_01.png")
	print("snowland_mushroom_01 done")

# === ICE CREAM NATURE ===
func generate_icecream(rng: RandomNumberGenerator) -> void:
	# Ice cream bush - pink/pastel
	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0,0,0,0))
	draw_bush(img, 8, 10, Color(0.8, 0.4, 0.6), Color(0.2, 0.8, 0.6), rng)
	img.save_png("res://assets/generated/icecream_bush_01.png")
	print("icecream_bush_01 done")
	
	# Ice cream flower - pastel rainbow
	img = Image.create(12, 12, false, Image.FORMAT_RGBA8)
	img.fill(Color(0,0,0,0))
	draw_flower(img, 6, 8, Color(0.3, 0.7, 0.3), Color(1.0, 0.7, 0.9), Color(1.0, 0.9, 0.2))
	img.save_png("res://assets/generated/icecream_flower_01.png")
	print("icecream_flower_01 done")
	
	# Ice cream mushroom - candy colored
	img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0,0,0,0))
	draw_mushroom(img, 6, 10, Color(0.9, 0.8, 0.7), Color(0.9, 0.3, 0.5), Color(1.0, 0.9, 0.3))
	img.save_png("res://assets/generated/icecream_mushroom_01.png")
	print("icecream_mushroom_01 done")

# === DESERT NATURE ===
func generate_desert(rng: RandomNumberGenerator) -> void:
	# Desert bush - tan/brown
	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0,0,0,0))
	draw_bush(img, 8, 10, Color(0.55, 0.4, 0.2), Color(0.8, 0.3, 0.1), rng)
	img.save_png("res://assets/generated/desert_bush_01.png")
	print("desert_bush_01 done")
	
	# Desert flower - bright yellow
	img = Image.create(12, 12, false, Image.FORMAT_RGBA8)
	img.fill(Color(0,0,0,0))
	draw_flower(img, 6, 8, Color(0.4, 0.5, 0.2), Color(1.0, 0.8, 0.1), Color(0.9, 0.5, 0.0))
	img.save_png("res://assets/generated/desert_flower_01.png")
	print("desert_flower_01 done")
	
	# Desert mushroom - dried brown
	img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0,0,0,0))
	draw_mushroom(img, 6, 10, Color(0.7, 0.6, 0.4), Color(0.5, 0.35, 0.15), Color(0.3, 0.2, 0.1))
	img.save_png("res://assets/generated/desert_mushroom_01.png")
	print("desert_mushroom_01 done")

# === VOLCANIC NATURE ===
func generate_volcanic(rng: RandomNumberGenerator) -> void:
	# Volcanic bush - dark red/charred
	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0,0,0,0))
	draw_bush(img, 8, 10, Color(0.2, 0.12, 0.08), Color(0.9, 0.3, 0.05), rng)
	img.save_png("res://assets/generated/volcanic_bush_01.png")
	print("volcanic_bush_01 done")
	
	# Volcanic flower - lava orange
	img = Image.create(12, 12, false, Image.FORMAT_RGBA8)
	img.fill(Color(0,0,0,0))
	draw_flower(img, 6, 8, Color(0.2, 0.15, 0.1), Color(1.0, 0.5, 0.0), Color(1.0, 0.8, 0.2))
	img.save_png("res://assets/generated/volcanic_flower_01.png")
	print("volcanic_flower_01 done")
	
	# Volcanic mushroom - dark with glow
	img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0,0,0,0))
	draw_mushroom(img, 6, 10, Color(0.3, 0.2, 0.15), Color(0.6, 0.1, 0.02), Color(1.0, 0.5, 0.0))
	img.save_png("res://assets/generated/volcanic_mushroom_01.png")
	print("volcanic_mushroom_01 done")

# === ETHEREAL NATURE ===
func generate_ethereal(rng: RandomNumberGenerator) -> void:
	# Ethereal bush - purple glow
	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0,0,0,0))
	draw_bush(img, 8, 10, Color(0.3, 0.1, 0.4), Color(0.6, 0.3, 1.0), rng)
	img.save_png("res://assets/generated/ethereal_bush_01.png")
	print("ethereal_bush_01 done")
	
	# Ethereal flower - cyan/purple
	img = Image.create(12, 12, false, Image.FORMAT_RGBA8)
	img.fill(Color(0,0,0,0))
	draw_flower(img, 6, 8, Color(0.2, 0.1, 0.4), Color(0.4, 0.3, 1.0), Color(0.8, 0.5, 1.0))
	img.save_png("res://assets/generated/ethereal_flower_01.png")
	print("ethereal_flower_01 done")
	
	# Ethereal mushroom - glowing
	img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0,0,0,0))
	draw_mushroom(img, 6, 10, Color(0.5, 0.3, 0.6), Color(0.4, 0.2, 0.8), Color(0.8, 0.6, 1.0))
	img.save_png("res://assets/generated/ethereal_mushroom_01.png")
	print("ethereal_mushroom_01 done")
