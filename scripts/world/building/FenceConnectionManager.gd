class_name FenceConnectionManager
extends RefCounted

## Manages fence connections and generates connection-aware sprites.
## Fences auto-connect to adjacent fences of any type (wood, stone, gate).
## Uses a 4-bit connection mask: N=1, S=2, E=4, W=8.
## Connection variants are stored in 64×64 atlas textures (4×4 grid of 16×16 tiles).

# Cached atlas textures (generated once on first use)
static var _wood_fence_atlas: Texture2D = null
static var _stone_fence_atlas: Texture2D = null
static var _gate_atlas: Texture2D = null

# Connection bitmask constants
const MASK_N: int = 1
const MASK_S: int = 2
const MASK_E: int = 4
const MASK_W: int = 8

## Returns true if the given building type is a fence type (connects to neighbors).
static func is_fence_type(building_type: int) -> bool:
	return BuildingSystem.BUILDING_DATA.get(building_type, {}).get("is_fence", false)

## Compute the connection bitmask for a cell by checking adjacent fence buildings.
static func compute_mask(cell: Vector2i, placed_buildings: Array) -> int:
	var mask: int = 0
	for b: Variant in placed_buildings:
		if not (b is Dictionary):
			continue
		if not is_fence_type(b.get("type", -1)):
			continue
		var b_cell: Vector2i = _parse_cell(b.get("cell", Vector2i(-1, -1)))
		if b_cell == cell + Vector2i.UP:
			mask |= MASK_N
		elif b_cell == cell + Vector2i.DOWN:
			mask |= MASK_S
		elif b_cell == cell + Vector2i.RIGHT:
			mask |= MASK_E
		elif b_cell == cell + Vector2i.LEFT:
			mask |= MASK_W
	return mask

## Get or generate the atlas texture for a fence building type.
static func get_atlas(building_type: int) -> Texture2D:
	match building_type:
		BuildingSystem.BuildingType.FENCE:
			if not _wood_fence_atlas:
				_wood_fence_atlas = _generate_atlas("wood")
			return _wood_fence_atlas
		BuildingSystem.BuildingType.STONE_FENCE:
			if not _stone_fence_atlas:
				_stone_fence_atlas = _generate_atlas("stone")
			return _stone_fence_atlas
		BuildingSystem.BuildingType.GATE:
			if not _gate_atlas:
				_gate_atlas = _generate_atlas("gate")
			return _gate_atlas
	return null

## Get the region rect in the 4x4 atlas for a given connection mask.
static func get_region_rect(mask: int) -> Rect2:
	var x: int = (mask % 4) * 16
	var y: int = (mask / 4) * 16
	return Rect2(x, y, 16, 16)

## Update a fence sprite to show the correct connection visual.
static func update_fence_sprite(sprite: Sprite2D, cell: Vector2i, building_type: int, placed_buildings: Array) -> void:
	var atlas: Texture2D = get_atlas(building_type)
	if not atlas:
		return
	var mask: int = compute_mask(cell, placed_buildings)
	sprite.texture = atlas
	sprite.region_enabled = true
	sprite.region_rect = get_region_rect(mask)
	sprite.hframes = 1
	sprite.vframes = 1

## After placing or removing a fence, update the affected cell and all neighbors.
static func update_neighbor_fences(cell: Vector2i, building_system: BuildingSystem, world_ref: Node) -> void:
	var neighbors: Array[Vector2i] = [
		cell + Vector2i.UP,
		cell + Vector2i.DOWN,
		cell + Vector2i.LEFT,
		cell + Vector2i.RIGHT,
		cell,  # Include the cell itself
	]
	for n_cell: Vector2i in neighbors:
		_update_fence_node(n_cell, building_system, world_ref)

## Update the visual of a single fence node if it exists at the given cell.
static func _update_fence_node(cell: Vector2i, building_system: BuildingSystem, world_ref: Node) -> void:
	var b: Dictionary = building_system.get_building_at(cell)
	if b.is_empty():
		return
	var b_type: int = b.get("type", -1)
	if not is_fence_type(b_type):
		return
	var node_name: String = "Building_%d_%d" % [cell.x, cell.y]
	var obj_root: Node = world_ref.get_node_or_null("Objects")
	if not obj_root:
		return
	var node: Node = obj_root.get_node_or_null(node_name)
	if not node:
		return
	# Find the Sprite2D child (named "Sprite2D" by default)
	var sprite: Sprite2D = node.get_node_or_null("Sprite2D")
	if not sprite:
		# Fallback: find any Sprite2D child
		for child in node.get_children():
			if child is Sprite2D:
				sprite = child
				break
	if not sprite:
		return
	update_fence_sprite(sprite, cell, b_type, building_system.placed_buildings)

# ---------------------------------------------------------------------------
# Atlas generation — procedural pixel art for 16 fence connection variants
# ---------------------------------------------------------------------------

## Generate a 64×64 atlas image for the given fence type.
static func _generate_atlas(fence_type: String) -> Texture2D:
	var atlas := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	atlas.fill(Color(0, 0, 0, 0))
	
	for mask in range(16):
		var cell_x: int = (mask % 4) * 16
		var cell_y: int = (mask / 4) * 16
		var cell_img := _draw_fence_cell(mask, fence_type)
		# Blit the cell into the atlas
		for y in range(16):
			for x in range(16):
				var px := cell_img.get_pixel(x, y)
				if px.a > 0.0:
					atlas.set_pixel(cell_x + x, cell_y + y, px)
	
	var tex := ImageTexture.create_from_image(atlas)
	return tex

## Draw a single 16×16 fence cell for a given mask and fence type.
static func _draw_fence_cell(mask: int, fence_type: String) -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	
	match fence_type:
		"wood":
			_draw_wood_fence(img, mask)
		"stone":
			_draw_stone_fence(img, mask)
		"gate":
			_draw_gate(img, mask)
	
	return img

# ---------------------------------------------------------------------------
# Wood fence drawing
# ---------------------------------------------------------------------------

static func _draw_wood_fence(img: Image, mask: int) -> void:
	var post_color := Color(0.5, 0.35, 0.15)
	var rail_color := Color(0.6, 0.4, 0.2)
	var highlight_color := Color(0.7, 0.5, 0.25)
	var dark_color := Color(0.35, 0.25, 0.1)
	
	var n: bool = bool(mask & MASK_N)
	var s: bool = bool(mask & MASK_S)
	var e: bool = bool(mask & MASK_E)
	var w: bool = bool(mask & MASK_W)
	
	# Center post (3 px wide, 6 px tall, centered)
	_fill_rect(img, 6, 6, 3, 6, post_color)
	# Post highlight (left edge)
	_vline(img, 6, 6, 11, highlight_color)
	# Post shadow (right edge)
	_vline(img, 8, 6, 11, dark_color)
	# Post top cap
	_hline(img, 6, 8, 5, highlight_color)
	# Post bottom
	_hline(img, 6, 8, 12, dark_color)
	
	var count: int = int(n) + int(s) + int(e) + int(w)
	
	# ---- North rail ----
	if n:
		_vline(img, 6, 0, 5, rail_color)
		_vline(img, 7, 0, 5, rail_color)
		# End post at top edge
		_hline(img, 6, 8, 1, post_color)
		_hline(img, 6, 8, 0, post_color)
		_hline(img, 6, 8, 0, highlight_color)
	elif count > 0 and (e or w):
		_hline(img, 6, 8, 4, dark_color)
	
	# ---- South rail ----
	if s:
		_vline(img, 6, 12, 15, rail_color)
		_vline(img, 7, 12, 15, rail_color)
		# End post at bottom edge
		_hline(img, 6, 8, 14, post_color)
		_hline(img, 6, 8, 15, post_color)
		_hline(img, 6, 8, 15, highlight_color)
	elif count > 0 and (e or w):
		_hline(img, 6, 8, 13, dark_color)
	
	# ---- East rail ----
	if e:
		_hline(img, 9, 15, 6, rail_color)
		_hline(img, 9, 15, 7, rail_color)
		_vline(img, 14, 6, 8, post_color)
		_vline(img, 15, 6, 8, dark_color)
		_hline(img, 14, 15, 5, highlight_color)
	elif count > 0 and (n or s):
		_hline(img, 9, 15, 6, post_color.darkened(0.2))
		_hline(img, 9, 15, 7, post_color.darkened(0.2))
		_vline(img, 14, 6, 8, post_color)
		_vline(img, 15, 6, 8, dark_color)
	
	# ---- West rail ----
	if w:
		_hline(img, 0, 5, 6, rail_color)
		_hline(img, 0, 5, 7, rail_color)
		_vline(img, 1, 6, 8, post_color)
		_vline(img, 0, 6, 8, dark_color)
		_hline(img, 0, 1, 5, highlight_color)
	elif count > 0 and (n or s):
		_hline(img, 0, 5, 6, post_color.darkened(0.2))
		_hline(img, 0, 5, 7, post_color.darkened(0.2))
		_vline(img, 1, 6, 8, post_color)
		_vline(img, 0, 6, 8, dark_color)
	
	# Standalone post: small top ornament
	if count == 0:
		_hline(img, 6, 8, 4, highlight_color)
		_hline(img, 7, 7, 3, highlight_color)


# ---------------------------------------------------------------------------
# Stone fence drawing
# ---------------------------------------------------------------------------

static func _draw_stone_fence(img: Image, mask: int) -> void:
	var stone_color := Color(0.5, 0.45, 0.4)
	var dark_color := Color(0.35, 0.3, 0.27)
	var light_color := Color(0.6, 0.55, 0.5)
	
	var n: bool = bool(mask & MASK_N)
	var s: bool = bool(mask & MASK_S)
	var e: bool = bool(mask & MASK_E)
	var w: bool = bool(mask & MASK_W)
	
	# Center pillar (6x8)
	_fill_rect(img, 5, 5, 6, 8, stone_color)
	# Left shadow
	_vline(img, 5, 5, 12, dark_color)
	# Right highlight
	_vline(img, 10, 5, 12, light_color)
	# Pillar top
	_fill_rect(img, 4, 4, 8, 1, stone_color)
	_fill_rect(img, 4, 4, 1, 1, dark_color)
	_fill_rect(img, 11, 4, 1, 1, light_color)
	
	# Horizontal stone bands across pillar
	_hline(img, 5, 10, 6, dark_color)
	_hline(img, 5, 10, 10, dark_color)
	
	var count: int = int(n) + int(s) + int(e) + int(w)
	
	# ---- North wall ----
	if n:
		_fill_rect(img, 6, 0, 4, 5, stone_color)
		_vline(img, 6, 0, 4, dark_color)
		_vline(img, 9, 0, 4, light_color)
		_hline(img, 6, 9, 2, dark_color)
		_hline(img, 6, 9, 4, dark_color)
		_hline(img, 5, 10, 0, stone_color)
	elif count == 0:
		_hline(img, 5, 10, 3, stone_color)
	elif e or w:
		_hline(img, 5, 10, 3, stone_color)
	
	# ---- South wall ----
	if s:
		_fill_rect(img, 6, 13, 4, 3, stone_color)
		_vline(img, 6, 13, 15, dark_color)
		_vline(img, 9, 13, 15, light_color)
		_hline(img, 6, 9, 14, dark_color)
	
	# ---- East wall ----
	if e:
		_fill_rect(img, 11, 6, 5, 4, stone_color)
		_vline(img, 11, 6, 9, dark_color)
		_hline(img, 12, 15, 6, dark_color)
		_hline(img, 12, 15, 9, dark_color)
		_hline(img, 12, 15, 8, light_color)
		_vline(img, 14, 5, 10, dark_color)
		_vline(img, 15, 5, 10, stone_color)
	elif n or s:
		_fill_rect(img, 11, 6, 5, 4, stone_color.darkened(0.15))
		_vline(img, 11, 6, 9, dark_color)
		_hline(img, 12, 15, 6, dark_color)
		_hline(img, 12, 15, 9, dark_color)
		_vline(img, 14, 5, 10, dark_color)
		_vline(img, 15, 5, 10, stone_color)
	
	# ---- West wall ----
	if w:
		_fill_rect(img, 0, 6, 5, 4, stone_color)
		_vline(img, 5, 6, 9, light_color)
		_hline(img, 0, 4, 6, dark_color)
		_hline(img, 0, 4, 9, dark_color)
		_hline(img, 0, 4, 8, light_color)
		_vline(img, 0, 5, 10, dark_color)
		_vline(img, 1, 5, 10, stone_color)
	elif n or s:
		_fill_rect(img, 0, 6, 5, 4, stone_color.darkened(0.15))
		_vline(img, 5, 6, 9, light_color)
		_hline(img, 0, 4, 6, dark_color.darkened(0.2))
		_hline(img, 0, 4, 9, dark_color.darkened(0.2))
		_vline(img, 0, 5, 10, dark_color)
		_vline(img, 1, 5, 10, stone_color)


# ---------------------------------------------------------------------------
# Gate drawing
# ---------------------------------------------------------------------------

static func _draw_gate(img: Image, mask: int) -> void:
	var post_color := Color(0.55, 0.38, 0.18)
	var rail_color := Color(0.65, 0.45, 0.22)
	var dark_color := Color(0.4, 0.28, 0.12)
	var highlight_color := Color(0.75, 0.55, 0.3)
	
	var n: bool = bool(mask & MASK_N)
	var s: bool = bool(mask & MASK_S)
	var e: bool = bool(mask & MASK_E)
	var w: bool = bool(mask & MASK_W)
	
	# Two gate posts with an open gap between (for walking through)
	# Left post at x=2..4
	_fill_rect(img, 2, 4, 3, 8, post_color)
	_hline(img, 2, 4, 3, highlight_color)
	_hline(img, 2, 4, 12, dark_color)
	
	# Right post at x=10..12
	_fill_rect(img, 10, 4, 3, 8, post_color)
	_hline(img, 10, 12, 3, highlight_color)
	_hline(img, 10, 12, 12, dark_color)
	
	# Open gap between posts (x=5..9) is intentionally empty
	
	# Top rail connecting posts
	_hline(img, 5, 9, 5, rail_color)
	_hline(img, 5, 9, 5, dark_color)
	
	# Bottom rail connecting posts
	_hline(img, 5, 9, 10, rail_color)
	_hline(img, 5, 9, 10, dark_color)
	
	# Accent on the rails
	_hline(img, 5, 9, 6, highlight_color)
	
	# ---- North connection ----
	if n:
		_vline(img, 6, 0, 3, rail_color)
		_vline(img, 7, 0, 3, rail_color)
		_vline(img, 8, 0, 3, rail_color)
		_hline(img, 6, 8, 0, highlight_color)
	
	# ---- South connection ----
	if s:
		_vline(img, 6, 12, 15, rail_color)
		_vline(img, 7, 12, 15, rail_color)
		_vline(img, 8, 12, 15, rail_color)
		_hline(img, 6, 8, 15, highlight_color)
	
	# ---- East connection ----
	if e:
		_hline(img, 13, 15, 7, rail_color)
		_hline(img, 13, 15, 8, rail_color)
		_vline(img, 14, 5, 10, post_color)
		_vline(img, 15, 5, 10, post_color)
		_vline(img, 15, 5, 10, dark_color)
		_hline(img, 14, 15, 4, highlight_color)
	elif n or s:
		_vline(img, 14, 5, 10, post_color)
		_vline(img, 15, 5, 10, post_color)
		_hline(img, 14, 15, 4, highlight_color)
	
	# ---- West connection ----
	if w:
		_hline(img, 0, 1, 7, rail_color)
		_hline(img, 0, 1, 8, rail_color)
		_vline(img, 0, 5, 10, post_color)
		_vline(img, 1, 5, 10, post_color)
		_vline(img, 0, 5, 10, dark_color)
		_hline(img, 0, 1, 4, highlight_color)
	elif n or s:
		_vline(img, 0, 5, 10, post_color)
		_vline(img, 1, 5, 10, post_color)
		_hline(img, 0, 1, 4, highlight_color)


# ---------------------------------------------------------------------------
# Pixel drawing helpers
# ---------------------------------------------------------------------------

## Draw a horizontal line from x1 to x2 at row y.
static func _hline(im: Image, x1: int, x2: int, y: int, c: Color) -> void:
	var start: int = mini(x1, x2)
	var end: int = maxi(x1, x2)
	for x in range(start, end + 1):
		if x >= 0 and x < im.get_width() and y >= 0 and y < im.get_height():
			im.set_pixel(x, y, c)

## Draw a vertical line from y1 to y2 at column x.
static func _vline(im: Image, x: int, y1: int, y2: int, c: Color) -> void:
	var start: int = mini(y1, y2)
	var end: int = maxi(y1, y2)
	for y in range(start, end + 1):
		if x >= 0 and x < im.get_width() and y >= 0 and y < im.get_height():
			im.set_pixel(x, y, c)

## Fill a rectangle at (x, y) with given width and height.
static func _fill_rect(im: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for dy in range(h):
		for dx in range(w):
			var px: int = x + dx
			var py: int = y + dy
			if px >= 0 and px < im.get_width() and py >= 0 and py < im.get_height():
				im.set_pixel(px, py, c)


## Helper: parse Vector2i from building data (can be Vector2i, Vector2, or string)
static func _parse_cell(value) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Vector2:
		return Vector2i(value)
	if value is String:
		var s: String = value.strip_edges().trim_prefix("(").trim_suffix(")")
		var parts: PackedStringArray = s.split(",")
		if parts.size() >= 2:
			return Vector2i(int(parts[0].strip_edges()), int(parts[1].strip_edges()))
	return Vector2i(0, 0)
