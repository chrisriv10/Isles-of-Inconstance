extends CropLayer
class_name LeavesLayer

enum LeafType { SIMPLE, POINTED, ROUNDED, FERN, VINE_LEAVES }

@export var leaf_type: LeafType = LeafType.SIMPLE
@export var leaf_count: int = 4
@export var leaf_size: int = 4
@export var spread_angle: float = 360.0

func render(image: Image, center_x: int, center_y: int) -> void:
	for i in range(leaf_count):
		var angle := float(i) / float(leaf_count) * spread_angle
		var rad := deg_to_rad(angle)
		var dir_x := cos(rad)
		var dir_y := sin(rad)
		
		var leaf_center_x := center_x + int(dir_x * leaf_size)
		var leaf_center_y := center_y + int(dir_y * leaf_size)
		
		match leaf_type:
			LeafType.SIMPLE:
				_draw_simple_leaf(image, leaf_center_x, leaf_center_y, angle)
			LeafType.POINTED:
				_draw_pointed_leaf(image, leaf_center_x, leaf_center_y, angle)
			LeafType.ROUNDED:
				_draw_rounded_leaf(image, leaf_center_x, leaf_center_y, angle)
			LeafType.FERN:
				_draw_fern_leaf(image, leaf_center_x, leaf_center_y, angle)
			LeafType.VINE_LEAVES:
				_draw_vine_leaves(image, leaf_center_x, leaf_center_y, angle)

func _draw_simple_leaf(image: Image, x: int, y: int, angle: float) -> void:
	var half_size := leaf_size / 2
	for dy in range(-half_size, half_size + 1):
		for dx in range(-half_size, half_size + 1):
			var dist := sqrt(float(dx * dx + dy * dy))
			if dist <= half_size:
				var draw_x := x + dx
				var draw_y := y + dy
				var transformed := apply_transforms(draw_x, draw_y)
				PixelArtUtils.set_pixel(image, transformed.x, transformed.y, color)

func _draw_pointed_leaf(image: Image, x: int, y: int, angle: float) -> void:
	var half_size := leaf_size / 2
	for dy in range(-half_size, half_size + 1):
		var width_at_y := half_size - abs(dy) / 2
		for dx in range(-int(width_at_y), int(width_at_y) + 1):
			var draw_x := x + dx
			var draw_y := y + dy
			var transformed := apply_transforms(draw_x, draw_y)
			PixelArtUtils.set_pixel(image, transformed.x, transformed.y, color)

func _draw_rounded_leaf(image: Image, x: int, y: int, angle: float) -> void:
	var radius := leaf_size / 2
	PixelArtUtils.draw_circle(image, x, y, radius, color)

func _draw_fern_leaf(image: Image, x: int, y: int, angle: float) -> void:
	var length := leaf_size
	for i in range(length):
		var progress := float(i) / float(length)
		var branch_x := x + int(progress * length / 2)
		var branch_y := y - i
		var transformed := apply_transforms(branch_x, branch_y)
		PixelArtUtils.set_pixel(image, transformed.x, transformed.y, color)
		
		# Add small side branches
		if i % 2 == 0 and i > 0:
			var side_x := branch_x + 1
			var side_y := branch_y
			transformed = apply_transforms(side_x, side_y)
			PixelArtUtils.set_pixel(image, transformed.x, transformed.y, color)

func _draw_vine_leaves(image: Image, x: int, y: int, angle: float) -> void:
	var half_size := leaf_size / 2
	# Draw small pairs of leaves
	for offset in [-1, 1]:
		var leaf_x := x + offset * 2
		var leaf_y := y
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var draw_x := leaf_x + dx
				var draw_y := leaf_y + dy
				var transformed := apply_transforms(draw_x, draw_y)
				PixelArtUtils.set_pixel(image, transformed.x, transformed.y, color)
