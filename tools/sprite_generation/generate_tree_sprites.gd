extends SceneTree

func _init() -> void:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	# === SNOWLAND ===
	snowland_tree_01(rng)
	snowland_tree_02(rng)
	snowland_tree_03(rng)
	icecream_tree_01(rng)
	icecream_tree_02(rng)
	icecream_tree_03(rng)
	desert_tree_01(rng)
	desert_tree_02(rng)
	desert_tree_03(rng)
	volcanic_tree_01(rng)
	volcanic_tree_02(rng)
	volcanic_tree_03(rng)
	ethereal_tree_01(rng)
	ethereal_tree_02(rng)
	ethereal_tree_03(rng)
	print("ALL 15 TREE SPRITES GENERATED!")
	quit()

func fill_rect(img: Image, cx: float, cy: float, w: float, h: float, color: Color) -> void:
	var half_w = int(w / 2.0)
	var half_h = int(h / 2.0)
	for x in range(cx - half_w, cx + half_w + 1):
		for y in range(cy - half_h, cy + half_h + 1):
			if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
				img.set_pixel(x, y, color)

func fill_circle(img: Image, cx: int, cy: int, r: int, color: Color) -> void:
	for x in range(-r, r + 1):
		for y in range(-r, r + 1):
			if x*x + y*y <= r*r:
				var px = cx + x
				var py = cy + y
				if px >= 0 and px < img.get_width() and py >= 0 and py < img.get_height():
					img.set_pixel(px, py, color)

func draw_pine_tier(img: Image, cx: int, base_y: int, w: int, h: int, color: Color) -> void:
	for y in range(h):
		var row_w = int(float(y) / float(h) * float(w) / 2.0) + 1
		for x in range(-row_w, row_w + 1):
			var px = cx + x
			var py = base_y - y
			if px >= 0 and px < img.get_width() and py >= 0 and py < img.get_height():
				img.set_pixel(px, py, color)

func snowland_tree_01(rng: RandomNumberGenerator) -> void:
	var img = Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0,0,0,0))
	fill_rect(img, 16, 42, 5, 8, Color(0.45, 0.3, 0.18))
	draw_pine_tier(img, 16, 36, 22, 10, Color(0.35, 0.6, 0.5))
	draw_pine_tier(img, 16, 26, 18, 10, Color(0.4, 0.65, 0.55))
	draw_pine_tier(img, 16, 16, 14, 10, Color(0.45, 0.7, 0.6))
	fill_circle(img, 16, 12, 4, Color(0.9, 0.95, 1.0))
	for i in range(25):
		var sx = 6 + rng.randi() % 20
		var sy = 14 + rng.randi() % 24
		if rng.randf() > 0.5:
			img.set_pixel(sx, sy, Color(0.9, 0.95, 1.0, 0.7))
	img.save_png("res://assets/generated/snowland_tree_01.png")
	print("snowland_tree_01 done")

func snowland_tree_02(rng: RandomNumberGenerator) -> void:
	var img = Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0,0,0,0))
	fill_rect(img, 16, 44, 5, 6, Color(0.35, 0.25, 0.2))
	fill_rect(img, 12, 36, 7, 3, Color(0.35, 0.25, 0.2))
	fill_rect(img, 20, 30, 7, 3, Color(0.35, 0.25, 0.2))
	fill_rect(img, 16, 24, 3, 6, Color(0.35, 0.25, 0.2))
	for i in range(20):
		var bx = 6 + rng.randi() % 20
		var by = 16 + rng.randi() % 22
		fill_circle(img, bx, by, 2, Color(0.6, 0.8, 1.0, 0.7))
	for i in range(6):
		var ix = 6 + rng.randi() % 20
		var iy = 28 + rng.randi() % 12
		img.set_pixel(ix, iy, Color(0.4, 0.7, 0.9))
		img.set_pixel(ix+1, iy+1, Color(0.4, 0.7, 0.9))
	img.save_png("res://assets/generated/snowland_tree_02.png")
	print("snowland_tree_02 done")

func snowland_tree_03(rng: RandomNumberGenerator) -> void:
	var img = Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0,0,0,0))
	fill_rect(img, 16, 44, 4, 10, Color(0.2, 0.45, 0.75))
	var ice_blue = Color(0.35, 0.65, 0.95)
	for y in range(12):
		var sx = 16 - y/3
		img.set_pixel(sx, 32 - y, ice_blue)
	for y in range(12):
		var sx = 16 + y/3
		img.set_pixel(sx, 32 - y, ice_blue)
	for y in range(20):
		img.set_pixel(16, 22 - y, ice_blue)
	fill_circle(img, 16, 18, 6, Color(0.5, 0.75, 1.0, 0.3))
	fill_circle(img, 16, 14, 4, Color(0.65, 0.85, 1.0))
	img.save_png("res://assets/generated/snowland_tree_03.png")
	print("snowland_tree_03 done")

func icecream_tree_01(rng: RandomNumberGenerator) -> void:
	var img = Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0,0,0,0))
	for y in range(10):
		fill_rect(img, 16, 44 - y, 5, 1, Color(1.0, 0.2, 0.3) if y % 2 == 0 else Color(1.0, 1.0, 1.0))
	fill_circle(img, 16, 22, 13, Color(1.0, 0.45, 0.65))
	fill_circle(img, 16, 18, 9, Color(1.0, 0.65, 0.85))
	fill_circle(img, 12, 26, 7, Color(1.0, 0.55, 0.75))
	fill_circle(img, 20, 26, 7, Color(1.0, 0.55, 0.75))
	fill_circle(img, 16, 13, 5, Color(1.0, 0.7, 0.9))
	img.save_png("res://assets/generated/icecream_tree_01.png")
	print("icecream_tree_01 done")

func icecream_tree_02(rng: RandomNumberGenerator) -> void:
	var img = Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0,0,0,0))
	fill_rect(img, 16, 46, 4, 12, Color(0.45, 0.28, 0.1))
	fill_circle(img, 16, 18, 14, Color(0.25, 0.75, 0.25))
	fill_circle(img, 16, 18, 10, Color(1.0, 0.45, 0.55))
	fill_circle(img, 16, 18, 5, Color(0.25, 0.75, 0.25))
	for a in range(0, 360, 30):
		var rad = deg_to_rad(float(a))
		var sx = 16 + int(cos(rad) * 8)
		var sy = 18 + int(sin(rad) * 8)
		fill_circle(img, sx, sy, 3, Color(1.0, 0.9, 0.4))
	img.save_png("res://assets/generated/icecream_tree_02.png")
	print("icecream_tree_02 done")

func icecream_tree_03(rng: RandomNumberGenerator) -> void:
	var img = Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0,0,0,0))
	fill_rect(img, 16, 46, 5, 10, Color(0.38, 0.18, 0.05))
	for y in range(14):
		var r = int(sqrt(196 - y*y))
		for x in range(-r, r + 1):
			var px = 16 + x
			var py = 26 + y
			if px >= 0 and px < 32 and py >= 0 and py < 48:
				img.set_pixel(px, py, Color(0.75, 0.18, 0.55))
	for y in range(8):
		var r = int(sqrt(64 - y*y))
		for x in range(-r, r + 1):
			var px = 16 + x
			var py = 18 + y
			if px >= 0 and px < 32 and py >= 0 and py < 48:
				img.set_pixel(px, py, Color(0.18, 0.65, 0.38))
	for i in range(15):
		var sx = 6 + rng.randi() % 20
		var sy = 14 + rng.randi() % 18
		img.set_pixel(sx, sy, Color(1.0, 1.0, 1.0, 0.7))
	img.save_png("res://assets/generated/icecream_tree_03.png")
	print("icecream_tree_03 done")

func desert_tree_01(rng: RandomNumberGenerator) -> void:
	var img = Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0,0,0,0))
	fill_rect(img, 16, 44, 5, 8, Color(0.45, 0.3, 0.13))
	fill_rect(img, 14, 38, 4, 6, Color(0.45, 0.3, 0.13))
	fill_rect(img, 15, 32, 4, 6, Color(0.45, 0.3, 0.13))
	fill_rect(img, 9, 34, 5, 3, Color(0.35, 0.22, 0.1))
	fill_rect(img, 21, 30, 5, 3, Color(0.35, 0.22, 0.1))
	fill_rect(img, 14, 26, 3, 5, Color(0.35, 0.22, 0.1))
	for i in range(5):
		var lx = 8 + rng.randi() % 18
		var ly = 22 + rng.randi() % 14
		img.set_pixel(lx, ly, Color(0.5, 0.38, 0.1))
	img.save_png("res://assets/generated/desert_tree_01.png")
	print("desert_tree_01 done")

func desert_tree_02(rng: RandomNumberGenerator) -> void:
	var img = Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0,0,0,0))
	fill_rect(img, 16, 44, 7, 12, Color(0.25, 0.5, 0.18))
	fill_rect(img, 8, 34, 7, 5, Color(0.25, 0.5, 0.18))
	fill_rect(img, 24, 30, 7, 5, Color(0.25, 0.5, 0.18))
	fill_rect(img, 4, 32, 4, 4, Color(0.25, 0.5, 0.18))
	fill_rect(img, 28, 28, 4, 4, Color(0.25, 0.5, 0.18))
	for i in range(12):
		var sx = 6 + rng.randi() % 20
		var sy = 22 + rng.randi() % 20
		img.set_pixel(sx, sy, Color(0.15, 0.65, 0.15))
	fill_circle(img, 16, 18, 2, Color(1.0, 0.8, 0.15))
	img.set_pixel(16, 17, Color(1.0, 0.9, 0.4))
	img.save_png("res://assets/generated/desert_tree_02.png")
	print("desert_tree_02 done")

func desert_tree_03(rng: RandomNumberGenerator) -> void:
	var img = Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0,0,0,0))
	fill_rect(img, 16, 44, 7, 8, Color(0.5, 0.38, 0.18))
	fill_rect(img, 8, 38, 7, 4, Color(0.5, 0.38, 0.18))
	fill_rect(img, 24, 38, 7, 4, Color(0.5, 0.38, 0.18))
	fill_rect(img, 5, 34, 4, 4, Color(0.35, 0.25, 0.12))
	fill_rect(img, 26, 34, 4, 4, Color(0.35, 0.25, 0.12))
	for a in range(0, 360, 45):
		var rad = deg_to_rad(float(a))
		var tx = 16 + int(cos(rad) * 9)
		var ty = 36 + int(sin(rad) * 5)
		if tx >= 0 and tx < 32 and ty >= 0 and ty < 48:
			img.set_pixel(tx, ty, Color(0.35, 0.25, 0.12))
	img.save_png("res://assets/generated/desert_tree_03.png")
	print("desert_tree_03 done")

func volcanic_tree_01(rng: RandomNumberGenerator) -> void:
	var img = Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0,0,0,0))
	fill_rect(img, 16, 44, 5, 10, Color(0.08, 0.06, 0.04))
	fill_rect(img, 14, 36, 4, 6, Color(0.08, 0.06, 0.04))
	fill_rect(img, 8, 34, 5, 3, Color(0.08, 0.06, 0.04))
	fill_rect(img, 22, 32, 5, 3, Color(0.08, 0.06, 0.04))
	fill_rect(img, 5, 30, 4, 2, Color(0.08, 0.06, 0.04))
	fill_rect(img, 23, 26, 4, 2, Color(0.08, 0.06, 0.04))
	for i in range(8):
		var ex = 12 + rng.randi() % 8
		var ey = 28 + rng.randi() % 14
		img.set_pixel(ex, ey, Color(0.8, 0.15, 0.02))
		img.set_pixel(ex+1, ey, Color(1.0, 0.35, 0.05))
	fill_circle(img, 5, 30, 2, Color(1.0, 0.35, 0.05))
	fill_circle(img, 25, 26, 2, Color(1.0, 0.35, 0.05))
	img.save_png("res://assets/generated/volcanic_tree_01.png")
	print("volcanic_tree_01 done")

func volcanic_tree_02(rng: RandomNumberGenerator) -> void:
	var img = Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0,0,0,0))
	fill_rect(img, 16, 44, 8, 10, Color(0.12, 0.08, 0.04))
	for i in range(5):
		var lx = 14 + rng.randi() % 4
		var ly = 40 - i * 3
		img.set_pixel(lx, ly, Color(1.0, 0.45, 0.0))
		img.set_pixel(lx, ly-1, Color(1.0, 0.75, 0.15))
	fill_rect(img, 10, 34, 5, 4, Color(0.12, 0.08, 0.04))
	fill_rect(img, 22, 34, 5, 4, Color(0.12, 0.08, 0.04))
	fill_rect(img, 6, 30, 4, 4, Color(0.12, 0.08, 0.04))
	fill_rect(img, 24, 28, 4, 4, Color(0.12, 0.08, 0.04))
	for i in range(5):
		var lx = 6 + rng.randi() % 22
		var ly = 26 + rng.randi() % 16
		img.set_pixel(lx, ly, Color(1.0, 0.45, 0.0))
		img.set_pixel(lx, ly+1, Color(1.0, 0.75, 0.15))
	img.save_png("res://assets/generated/volcanic_tree_02.png")
	print("volcanic_tree_02 done")

func volcanic_tree_03(rng: RandomNumberGenerator) -> void:
	var img = Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0,0,0,0))
	fill_rect(img, 16, 44, 6, 8, Color(0.25, 0.22, 0.2))
	fill_rect(img, 18, 36, 5, 8, Color(0.25, 0.22, 0.2))
	fill_rect(img, 16, 26, 4, 10, Color(0.25, 0.22, 0.2))
	fill_rect(img, 10, 34, 5, 3, Color(0.35, 0.32, 0.3))
	fill_rect(img, 22, 30, 5, 3, Color(0.35, 0.32, 0.3))
	for i in range(8):
		var ex = 6 + rng.randi() % 22
		var ey = 12 + rng.randi() % 28
		img.set_pixel(ex, ey, Color(0.85, 0.25, 0.02))
	img.save_png("res://assets/generated/volcanic_tree_03.png")
	print("volcanic_tree_03 done")

func ethereal_tree_01(rng: RandomNumberGenerator) -> void:
	var img = Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0,0,0,0))
	for y in range(10):
		var c = Color(0.28, 0.08, 0.38) if y % 2 == 0 else Color(0.55, 0.18, 0.75)
		fill_rect(img, 16, 44 - y, 5, 1, c)
	fill_circle(img, 16, 22, 12, Color(0.45, 0.18, 0.65, 0.45))
	fill_circle(img, 16, 22, 8, Color(0.65, 0.28, 0.85, 0.55))
	fill_circle(img, 16, 22, 5, Color(0.75, 0.38, 0.95))
	for i in range(8):
		var gx = 8 + rng.randi() % 16
		var gy = 12 + rng.randi() % 16
		fill_circle(img, gx, gy, 1, Color(1.0, 0.55, 1.0, 0.75))
	img.save_png("res://assets/generated/ethereal_tree_01.png")
	print("ethereal_tree_01 done")

func ethereal_tree_02(rng: RandomNumberGenerator) -> void:
	var img = Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0,0,0,0))
	fill_rect(img, 16, 44, 4, 10, Color(0.08, 0.08, 0.38))
	fill_circle(img, 16, 22, 14, Color(0.08, 0.08, 0.45, 0.35))
	fill_circle(img, 16, 22, 10, Color(0.18, 0.18, 0.65, 0.45))
	fill_circle(img, 16, 22, 6, Color(0.18, 0.28, 0.75))
	for i in range(12):
		var sx = 6 + rng.randi() % 20
		var sy = 12 + rng.randi() % 20
		img.set_pixel(sx, sy, Color(1.0, 1.0, 0.75))
		if rng.randf() > 0.6:
			img.set_pixel(sx+1, sy, Color(1.0, 1.0, 0.75))
			img.set_pixel(sx-1, sy, Color(1.0, 1.0, 0.75))
			img.set_pixel(sx, sy+1, Color(1.0, 1.0, 0.75))
			img.set_pixel(sx, sy-1, Color(1.0, 1.0, 0.75))
	img.save_png("res://assets/generated/ethereal_tree_02.png")
	print("ethereal_tree_02 done")

func ethereal_tree_03(rng: RandomNumberGenerator) -> void:
	var img = Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0,0,0,0))
	fill_rect(img, 16, 44, 4, 10, Color(0.0, 0.25, 0.35))
	for y in range(18):
		var half_w = int(abs(8.0 - float(y) * 0.8))
		for x in range(-half_w, half_w + 1):
			var px = 16 + x
			var py = 26 + y - 8
			if px >= 0 and px < 32 and py >= 0 and py < 48:
				var bright = 0.5 + 0.5 * (1.0 - abs(float(y) - 8.0) / 8.0)
				img.set_pixel(px, py, Color(0.0, 0.45 * bright, 0.55 * bright))
	fill_circle(img, 16, 22, 4, Color(0.25, 0.95, 0.95))
	for i in range(10):
		var sx = 8 + rng.randi() % 16
		var sy = 14 + rng.randi() % 16
		img.set_pixel(sx, sy, Color(1.0, 1.0, 1.0, 0.85))
	img.save_png("res://assets/generated/ethereal_tree_03.png")
	print("ethereal_tree_03 done")
