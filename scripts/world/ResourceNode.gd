extends Interactable
class_name ResourceNode

## A gatherable world object (rock outcrop, wildflowers, wood, etc.) -
## interacting with it adds a resource item to the player's inventory,
## then the node disappears.
## World scatters these across the map, which is what gives exploration a
## concrete reward: wander further out, find more nodes, gather more
## resources to sell or (eventually) spend on upgrades.
##
## Gathering now takes time (like Minecraft): press E to start, stand
## still nearby while a progress bar fills. Walk away to cancel.

@export var item_id: String = "stone"
@export var min_amount: int = 1
@export var max_amount: int = 2

## How many seconds the player must stand still nearby to gather this node.
@export var gather_time: float = 1.5

## How quickly each pickaxe tier mines relative to gather_time.
## Higher tier = lower multiplier = faster gathering.
## Keyed by pickaxe item_id. Basic pickaxe_tool is 1.0 (no reduction).
const PICKAXE_SPEED_MULTIPLIERS: Dictionary = {
	"pickaxe_tool": 1.0,
	"copper_pickaxe": 0.80,
	"iron_pickaxe": 0.63,
	"gold_pickaxe": 0.48,
	"diamond_pickaxe": 0.35,
	"mythril_pickaxe": 0.22,
	"magma_pickaxe": 0.22,
}

## Optional override texture; if unset, one is generated from item_id.
@export var override_texture: Texture2D = null

# Gather-progress state
var _is_gathering: bool = false
var _gather_progress: float = 0.0
var _gatherer_ref: Node = null
var _current_gather_time: float = 1.5

# Progress bar nodes (created in _ready)
var _progress_bg: ColorRect = null
var _progress_fill: ColorRect = null

## Max distance-squared the player can wander before gathering cancels.
const GATHER_RANGE_SQ: float = 600.0  # ~24px

## Pre-made textures for specific resource items, replacing procedural generation.
const CUSTOM_TEXTURES: Dictionary = {
	"iron_ore": preload("res://assets/generated/iron_ore_deposit_frame_0_frame_0.png"),
	"stone": preload("res://assets/generated/stone_deposit_frame_0.png"),
	"clay": preload("res://assets/generated/icon_stone_frame_0.png"),
	"ice_crystal": preload("res://assets/generated/icon_ice_crystal_frame_0.png"),
	"coal": preload("res://assets/generated/coal_deposit_frame_0.png"),
	"diamond_ore": preload("res://assets/generated/diamond_ore_deposit_2_frame_0.png"),
	"gold_ore": preload("res://assets/generated/gold_ore_deposit_frame_0.png"),
	"silver_ore": preload("res://assets/generated/silver_ore_deposit_2_frame_0.png"),
	"obsidian_ore": preload("res://assets/generated/obsidian_ore_deposit_2_frame_0.png"),
	"ruby_ore": preload("res://assets/generated/ruby_ore_deposit_2_frame_0.png"),
	"sugar_crystal": preload("res://assets/generated/sugar_crystal_deposit_frame_0.png"),
	"gumdrop": preload("res://assets/generated/gumdrop_deposit_frame_0.png"),
	"chocolate_chunk": preload("res://assets/generated/chocolate_chunk_deposit_frame_0.png"),
	"cactus_fruit": preload("res://assets/generated/cactus_fruit_deposit_frame_0.png"),
	"sulfur_crystal": preload("res://assets/generated/sulfur_crystal_deposit_frame_0.png"),
	"ember_dust": preload("res://assets/generated/ember_dust_deposit_frame_0.png"),
	"moon_shard": preload("res://assets/generated/moon_shard_deposit_frame_0.png"),
	"starlight_dust": preload("res://assets/generated/starlight_dust_deposit_frame_0.png"),
}


func _ready() -> void:
	if override_texture:
		_set_sprite_texture(override_texture)
	elif CUSTOM_TEXTURES.has(item_id):
		_set_sprite_texture(CUSTOM_TEXTURES[item_id])
	else:
		_generate_sprite_for_item()
	_setup_progress_bar()


## Create the small progress-bar above the node, hidden until gathering starts.
func _setup_progress_bar() -> void:
	_progress_bg = ColorRect.new()
	_progress_bg.name = "GatherProgressBG"
	_progress_bg.size = Vector2(20, 3)
	_progress_bg.position = Vector2(-10, -18)
	_progress_bg.color = Color(0.1, 0.1, 0.1, 0.6)
	_progress_bg.visible = false
	add_child(_progress_bg)

	_progress_fill = ColorRect.new()
	_progress_fill.name = "GatherProgressFill"
	_progress_fill.size = Vector2(0, 3)
	_progress_fill.position = Vector2(-10, -18)
	_progress_fill.color = Color(0.3, 0.8, 0.3, 0.9)
	_progress_fill.visible = false
	add_child(_progress_fill)


## Block re-interaction while we're in the middle of gathering.
func can_interact() -> bool:
	if _is_gathering:
		return false
	return not (single_use and _used)


func _process(delta: float) -> void:
	if not _is_gathering:
		return

	# Cancel if the player walked away or the reference is gone
	if not _is_gatherer_in_range():
		_cancel_gathering()
		return

	_gather_progress += delta
	var ratio: float = minf(_gather_progress / _current_gather_time, 1.0)
	_progress_fill.size.x = ratio * 20.0

	if _gather_progress >= _current_gather_time:
		_complete_gathering()


## Check whether the player who started gathering is still nearby.
func _is_gatherer_in_range() -> bool:
	if not _gatherer_ref or not is_instance_valid(_gatherer_ref):
		return false
	var dist_sq: float = global_position.distance_squared_to(_gatherer_ref.global_position)
	return dist_sq < GATHER_RANGE_SQ


## Reset progress — node is available to be gathered again.
func _cancel_gathering() -> void:
	_is_gathering = false
	_gather_progress = 0.0
	_gatherer_ref = null
	_progress_bg.visible = false
	_progress_fill.visible = false
	_progress_fill.size.x = 0.0
	_used = false  # allow another attempt


## Called when the progress bar fills completely — actually give the items.
func _complete_gathering() -> void:
	_is_gathering = false
	_progress_bg.visible = false
	_progress_fill.visible = false

	# ── Original gather logic ──
	var amount := randi_range(min_amount, max_amount)
	# Pet gather bonus multiplies yield
	var gather_bonus: float = PetManager.get_gather_bonus()
	if gather_bonus > 0.0:
		amount = maxi(1, roundi(amount * (1.0 + gather_bonus)))
	var leftover := InventoryManager.add_item(item_id, amount)
	var gathered := amount - leftover
	if gathered <= 0:
		# Inventory was full — reset so the player can try again
		_used = false
		return

	# Effects
	EffectSpawner.spawn_particles(global_position, Color(0.7, 0.7, 0.7), 6, 12.0)
	var item_data: ItemData = DataManager.get_item(item_id)
	var item_name := item_data.display_name if item_data else item_id
	EffectSpawner.spawn_floating_text("+%d %s" % [gathered, item_name], global_position, Color.WHITE)
	AudioManager.play(AudioManager.Sound.GATHER)
	LevelManager.add_xp_source("gather")

	# Track foraging objectives
	var om := get_tree().get_first_node_in_group("objective_manager")
	if om and om.has_method("on_gather_wild"):
		om.on_gather_wild(item_id, gathered)

	super.interact(_gatherer_ref)
	# Route removal through the parent expedition island when present so shared
	# islands replicate gather/remove to all peers; otherwise fall back to the
	# main-world removal broadcast.
	var parent := get_parent()
	if parent != null and parent.get_parent() != null and parent.get_parent().has_method("notify_island_object_removed"):
		parent.get_parent().notify_island_object_removed(int(get_meta("island_obj_id", -1)))
		queue_free()
		return
	var world: Node = get_tree().get_first_node_in_group("world")
	if world and world.has_method("notify_cell_object_removed"):
		world.notify_cell_object_removed(global_position)
	queue_free()


func interact(interactor: Node) -> void:
	if not can_interact():
		return
	if not _check_tool_requirement(interactor):
		EffectSpawner.spawn_floating_text("Need a pickaxe!", global_position, Color.ORANGE_RED)
		return

	# Detect pickaxe tier and apply speed multiplier
	var player: Player = Interactable._resolve_player(interactor)
	var pickaxe_id: String = player.get_active_hotbar_item_id() if player else ""
	if pickaxe_id.is_empty() or not PICKAXE_SPEED_MULTIPLIERS.has(pickaxe_id):
		pickaxe_id = "pickaxe_tool"
	_current_gather_time = gather_time * PICKAXE_SPEED_MULTIPLIERS[pickaxe_id]

	# Start the timed gather process instead of collecting instantly
	_is_gathering = true
	_gather_progress = 0.0
	_gatherer_ref = interactor
	_used = true  # prevent double-interaction while gathering

	# Show the progress bar
	_progress_bg.visible = true
	_progress_fill.visible = true
	_progress_fill.size.x = 0.0


## Apply a texture to the Sprite2D child.
func _set_sprite_texture(tex: Texture2D) -> void:
	for child in get_children():
		if child is Sprite2D:
			child.texture = tex
			return
	# No Sprite2D child found — create one
	var sprite := Sprite2D.new()
	sprite.texture = tex
	add_child(sprite)
	sprite.owner = self


## Generate a simple coloured placeholder sprite based on item type.
## Draws distinct shapes so resource nodes are visually distinguishable.
func _generate_sprite_for_item() -> void:
	var color := _get_color_for_item(item_id)
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	
	match item_id:
		"stone", "iron_ore":
			_draw_diamond(img, color)
		"wood":
			_draw_log(img, color)
		"flower":
			_draw_flower(img, color)
		"berry":
			_draw_berry(img, color)
		"mushroom":
			_draw_mushroom_cap(img, color)
		"ectoplasm":
			_draw_wobble_circle(img, color)
		"spore_sac":
			_draw_diamond(img, color)
		"ghostly_essence":
			_draw_wobble_circle(img, color)
		_:
			_draw_circle(img, color)
	
	# Small highlight near top-left for depth
	_draw_highlight(img)
	
	var tex := ImageTexture.create_from_image(img)
	_set_sprite_texture(tex)


## Solid circle
static func _draw_circle(img: Image, color: Color) -> void:
	for y in range(16):
		for x in range(16):
			var dx := float(x) - 7.5
			var dy := float(y) - 7.5
			var dist := sqrt(dx * dx + dy * dy)
			if dist <= 6.5:
				var shade := 1.0 - (dist / 6.5) * 0.3
				img.set_pixel(x, y, Color(
					color.r * shade, color.g * shade, color.b * shade, 1.0
				))


## Diamond shape (stone, ores)
static func _draw_diamond(img: Image, color: Color) -> void:
	for y in range(16):
		for x in range(16):
			var dx := absf(float(x) - 7.5)
			var dy := absf(float(y) - 7.5)
			if dx + dy <= 7.0:
				var depth := (dx + dy) / 7.0
				var shade := 1.0 - depth * 0.35
				img.set_pixel(x, y, Color(
					color.r * shade, color.g * shade, color.b * shade, 1.0
				))


## Horizontal log shape (wood)
static func _draw_log(img: Image, color: Color) -> void:
	for y in range(16):
		for x in range(16):
			var dx := absf(float(x) - 7.5)
			var dy := absf(float(y) - 7.5)
			# Horizontal-oval: wider than tall
			var normalized := (dx * dx) / (5.5 * 5.5) + (dy * dy) / (3.5 * 3.5)
			if normalized <= 1.0:
				var shade := 1.0 - clampf(normalized, 0.0, 1.0) * 0.3
				img.set_pixel(x, y, Color(
					color.r * shade, color.g * shade, color.b * shade, 1.0
				))
	# Add three ring lines for wood grain
	for ring_y in [5, 7, 9]:
		for ring_x in range(4, 12):
			var dx := absf(float(ring_x) - 7.5)
			var dy := absf(float(ring_y) - 7.5)
			var normalized := (dx * dx) / (5.5 * 5.5) + (dy * dy) / (3.5 * 3.5)
			if normalized <= 0.98 and normalized >= 0.7:
				var p := img.get_pixel(ring_x, ring_y)
				if p.a > 0:
					img.set_pixel(ring_x, ring_y, Color(
						minf(1.0, p.r + 0.15), minf(1.0, p.g + 0.15),
						minf(1.0, p.b + 0.15), 1.0
					))


## Small flower with 5 petals, a yellow center, and a green stem.
static func _draw_flower(img: Image, color: Color) -> void:
	var center_x := 7.5
	var center_y := 7.0
	var stem_color := Color(0.25, 0.6, 0.15)
	var center_color := Color(1.0, 0.85, 0.15)
	
	# 5 petals arranged in a circle around center
	var petal_radius := 3.5
	var petal_count := 5
	for p in range(petal_count):
		var angle := float(p) / float(petal_count) * TAU - PI / 2.0
		var cx := center_x + cos(angle) * 3.0
		var cy := center_y + sin(angle) * 3.0
		for y in range(16):
			for x in range(16):
				var dx := float(x) - cx
				var dy := float(y) - cy
				if dx * dx + dy * dy <= petal_radius * petal_radius:
					var dist := sqrt(dx * dx + dy * dy)
					var shade := 1.0 - (dist / petal_radius) * 0.35
					var existing := img.get_pixel(x, y)
					if existing.a > 0:
						# Blend petals together
						var blend := shade * 0.5
						img.set_pixel(x, y, Color(
							minf(1.0, color.r * shade + existing.r * (1.0 - blend)),
							minf(1.0, color.g * shade + existing.g * (1.0 - blend)),
							minf(1.0, color.b * shade + existing.b * (1.0 - blend)),
							1.0
						))
					else:
						img.set_pixel(x, y, Color(
							color.r * shade, color.g * shade, color.b * shade, 1.0
						))
	
	# Yellow center
	for y in range(16):
		for x in range(16):
			var dx := float(x) - center_x
			var dy := float(y) - center_y
			if dx * dx + dy * dy <= 2.5 * 2.5:
				var dist := sqrt(dx * dx + dy * dy)
				var shade := 1.0 - (dist / 2.5) * 0.25
				img.set_pixel(x, y, Color(
					center_color.r * shade, center_color.g * shade, center_color.b * shade, 1.0
				))
	
	# Green stem
	for sy in range(10, 15):
		for sx in range(7, 9):
			var shade := 1.0 - (float(sy - 10) / 5.0) * 0.3
			img.set_pixel(sx, sy, Color(
				stem_color.r * shade, stem_color.g * shade, stem_color.b * shade, 1.0
			))
	
	# Two small leaves on stem
	img.set_pixel(5, 10, Color(0.3, 0.65, 0.15))
	img.set_pixel(6, 10, Color(0.3, 0.65, 0.15))
	img.set_pixel(4, 11, Color(0.3, 0.65, 0.15))
	img.set_pixel(5, 11, Color(0.3, 0.65, 0.15))
	img.set_pixel(10, 12, Color(0.3, 0.65, 0.15))
	img.set_pixel(11, 12, Color(0.3, 0.65, 0.15))
	img.set_pixel(10, 13, Color(0.3, 0.65, 0.15))


## Small cluster of berries (several small circles grouped together).
static func _draw_berry(img: Image, color: Color) -> void:
	# Berry cluster positions — 6 small berries forming a bunch
	var berry_positions: Array[Vector2] = [
		Vector2(5.0, 6.0),  # top-left
		Vector2(9.0, 5.5),  # top-right
		Vector2(7.0, 8.0),  # center
		Vector2(4.0, 9.0),  # bottom-left
		Vector2(9.5, 8.5),  # bottom-right
		Vector2(6.5, 10.0), # bottom-center
	]
	for berry_pos in berry_positions:
		var bx := berry_pos.x
		var by := berry_pos.y
		for y in range(16):
			for x in range(16):
				var dx := float(x) - bx
				var dy := float(y) - by
				var dist_sq := dx * dx + dy * dy
				if dist_sq <= 3.0 * 3.0:
					var dist := sqrt(dist_sq)
					var shade := 1.0 - (dist / 3.0) * 0.3
					var existing := img.get_pixel(x, y)
					if existing.a > 0:
						# Blend overlapping berries darker
						img.set_pixel(x, y, Color(
							color.r * shade * 0.85, color.g * shade * 0.85, color.b * shade * 0.85, 1.0
						))
					else:
						img.set_pixel(x, y, Color(
							color.r * shade, color.g * shade, color.b * shade, 1.0
						))
					# Tiny highlight on top edge of each berry
					var rel_y := dy
					if rel_y < -1.8 and dist > 0.5 and dist < 2.5:
						var hl_alpha := 1.0 - absf(dy + 2.0) * 0.5
						img.set_pixel(x, y, Color(
							minf(1.0, existing.r + 0.25 * hl_alpha),
							minf(1.0, existing.g + 0.25 * hl_alpha),
							minf(1.0, existing.b + 0.25 * hl_alpha),
							1.0
						))
	
	# Small green top stem/leaf on the cluster
	var stem_color := Color(0.25, 0.55, 0.15)
	for sx in range(6, 9):
		for sy in range(2, 5):
			var dx := float(sx) - 7.5
			var dy := float(sy) - 3.0
			if dx * dx + dy * dy <= 2.5 * 2.5:
				var shade := 1.0 - sqrt(dx * dx + dy * dy) / 2.5 * 0.3
				img.set_pixel(sx, sy, Color(
					stem_color.r * shade, stem_color.g * shade, stem_color.b * shade, 1.0
				))


## Rounded mushroom-cap shape
static func _draw_mushroom_cap(img: Image, color: Color) -> void:
	for y in range(16):
		for x in range(16):
			var dx := float(x) - 7.5
			var dy := float(y) - 7.5
			var dist := sqrt(dx * dx + dy * dy)
			# Dome: upper half wider, lower half narrower
			var top_half := dy <= 0
			var radius := 5.5 if top_half else 4.0
			if dist <= radius:
				var shade := 1.0 - (dist / radius) * 0.3
				img.set_pixel(x, y, Color(
					color.r * shade, color.g * shade, color.b * shade, 1.0
				))
	# Stem rectangle below cap
	for sy in range(8, 13):
		for sx in range(6, 10):
			var stem_color := Color(0.85, 0.78, 0.65)
			var shade := 1.0 - (float(sy - 8) / 5.0) * 0.2
			img.set_pixel(sx, sy, Color(
				stem_color.r * shade, stem_color.g * shade, stem_color.b * shade, 1.0
			))


## Squiggly / ghostly circle (ectoplasm, ghostly essence)
static func _draw_wobble_circle(img: Image, color: Color) -> void:
	for y in range(16):
		for x in range(16):
			var dx := float(x) - 7.5
			var dy := float(y) - 7.5
			var angle := atan2(dy, dx)
			var wobble := sin(angle * 4.0) * 0.8
			var radius := 5.5 + wobble
			var dist := sqrt(dx * dx + dy * dy)
			if dist <= radius:
				var shade := 1.0 - (dist / (radius + 0.1)) * 0.25
				img.set_pixel(x, y, Color(
					color.r * shade, color.g * shade, color.b * shade, 0.85
				))


## Small highlight spot near top-left
static func _draw_highlight(img: Image) -> void:
	for ox in range(-1, 2):
		for oy in range(-1, 2):
			var px := 5 + ox
			var py := 4 + oy
			if px >= 0 and px < 16 and py >= 0 and py < 16:
				var existing := img.get_pixel(px, py)
				if existing.a > 0:
					img.set_pixel(px, py, Color(
						minf(1.0, existing.r + 0.3),
						minf(1.0, existing.g + 0.3),
						minf(1.0, existing.b + 0.3),
						existing.a
					))


static func _get_color_for_item(item: String) -> Color:
	match item:
		"flower":           return Color(0.95, 0.4, 0.6)      # pink
		"wood":             return Color(0.55, 0.35, 0.15)    # brown
		"berry":            return Color(0.85, 0.15, 0.15)    # red
		"mushroom":         return Color(0.75, 0.6, 0.4)      # tan
		"iron_ore":         return Color(0.6, 0.55, 0.7)      # purple-gray
		"stone":            return Color(0.5, 0.5, 0.5)       # gray
		"ectoplasm":        return Color(0.3, 0.8, 0.6)       # teal
		"spore_sac":        return Color(0.5, 0.7, 0.3)       # olive
		"ghostly_essence":  return Color(0.6, 0.5, 0.9)       # lavender
		_:                  return Color(0.5, 0.5, 0.5)       # gray fallback
