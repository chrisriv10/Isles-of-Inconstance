extends Interactable
class_name Animal

## Procedurally generated animal that draws its own pixel-art sprite,
## picks a random species name, and wanders around with varied behaviour.
## Extends Interactable (Area2D) so the PlayerInteractor can detect it.

# ---------------------------------------------------------------------------
# Behaviour types
# ---------------------------------------------------------------------------
enum Behavior { WANDER, GRAZE, IDLE, SKITTISH }

# ---------------------------------------------------------------------------
# Species name generators
# ---------------------------------------------------------------------------
const SPECIES_PREFIX := [
	"Glimmer", "Shadow", "Cinder", "Dew", "Frost", "Ember", "Mist",
	"Storm", "Sun", "Moon", "Star", "Thorn", "Briar", "Ash", "Flint",
	"Dusk", "Dawn", "Crystal", "Copper", "Silver", "Golden", "Ivy",
	"Fern", "Moss", "Heather", "Honey", "Maple", "Thistle", "Clover",
]

const SPECIES_SUFFIX_FOWL := [
	"beak", "plume", "wing", "crest", "feather", "talon", "claw",
	"strider", "dancer", "chirp", "flutter", "peck",
]

const SPECIES_SUFFIX_BOVINE := [
	"hoof", "mane", "hide", "horn", "snout", "muzzle", "flank",
	"strider", "trotter", "stomp", "bellow",
]

const SPECIES_SUFFIX_RABBIT := [
	"hop", "burrow", "whisker", "paw", "bounce", "scamper", "ear",
	"fluff", "twitch",
]

const SPECIES_SUFFIX_DEER := [
	"antler", "leap", "glade", "wood", "buck", "snout", "strider",
	"prowl", "dapple",
]

const WANDER_SPEED_MIN: float = 15.0
const WANDER_SPEED_MAX: float = 40.0
const GRAZE_SPEED: float = 8.0
const SKITTISH_SPEED: float = 60.0

# ---------------------------------------------------------------------------
# Exports
# ---------------------------------------------------------------------------
@export var animal_name: String = "Animal"
@export var animal_type: String = "chicken"
@export var behavior: Behavior = Behavior.WANDER
@export var move_speed: float = 30.0
@export var body_color: Color = Color.WHITE
@export var accent_color: Color = Color.ORANGE_RED
@export var secondary_color: Color = Color(0.9, 0.9, 0.9)
@export var spot_color: Color = Color(0.4, 0.3, 0.2)

# ---------------------------------------------------------------------------
# Nodes
# ---------------------------------------------------------------------------
@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $Label
@onready var wander_timer: Timer = $WanderTimer

var _target_pos: Vector2 = Vector2.ZERO
var _home_pos: Vector2 = Vector2.ZERO
var _move_radius: float = 48.0
var _rest_time: float = 0.0
var _idle_phase: float = 0.0
var _body_shape: int = 0
var _pattern: int = 0
var _world_ref: Node = null
var _player_ref: Node2D = null

# ---------------------------------------------------------------------------
# Initialisation
# ---------------------------------------------------------------------------

func setup(p_type: String, p_home: Vector2) -> void:
	animal_type = p_type
	_home_pos = p_home
	global_position = p_home
	_generate_species_name()
	_generate_behavior()
	_generate_colors_and_pattern()
	_generate_procedural_sprite()
	_pick_new_target()
	wander_timer.start()

## Generates a fantasy species name, e.g. "Cinderplume Fowl" or
## "Frosthoof Bovine".  Each animal type has its own suffix pool so
## the names feel like they belong to that kind of creature.
func _generate_species_name() -> void:
	var prefix: String = SPECIES_PREFIX[randi() % SPECIES_PREFIX.size()]
	var suffix_pool: Array
	match animal_type:
		"chicken", "bird":
			suffix_pool = SPECIES_SUFFIX_FOWL
		"cow":
			suffix_pool = SPECIES_SUFFIX_BOVINE
		"rabbit":
			suffix_pool = SPECIES_SUFFIX_RABBIT
		"deer":
			suffix_pool = SPECIES_SUFFIX_DEER
		_:
			suffix_pool = SPECIES_SUFFIX_FOWL

	var suffix: String = suffix_pool[randi() % suffix_pool.size()]
	var type_label: String = _species_type_label()
	animal_name = prefix + suffix + " " + type_label
	if label:
		label.text = animal_name

func _species_type_label() -> String:
	match animal_type:
		"chicken", "bird":
			return ["Fowl", "Bird", "Flyer"][randi() % 3]
		"cow":
			return ["Bovine", "Herder", "Grazer"][randi() % 3]
		"rabbit":
			return ["Burrower", "Hopper", "Lagomorph"][randi() % 3]
		"deer":
			return ["Deer", "Strider", "Grazer"][randi() % 3]
		_:
			return "Critter"

func _generate_behavior() -> void:
	var roll: float = randf()
	if roll < 0.35:
		behavior = Behavior.WANDER
		move_speed = randf_range(WANDER_SPEED_MIN, WANDER_SPEED_MAX)
	elif roll < 0.55:
		behavior = Behavior.GRAZE
		move_speed = GRAZE_SPEED
	elif roll < 0.75:
		behavior = Behavior.IDLE
		move_speed = 0.0
	else:
		behavior = Behavior.SKITTISH
		move_speed = SKITTISH_SPEED

## Picks a colour palette, body shape (round/tall/wide/slender),
## and pattern (solid/spotted/striped/patchy) for this animal.
func _generate_colors_and_pattern() -> void:
	_body_shape = randi() % 4      # 0=round, 1=tall, 2=wide, 3=slender
	_pattern = randi() % 4         # 0=solid, 1=spotted, 2=striped, 3=patchy

	match animal_type:
		"chicken", "bird":
			var hue: float = randf_range(0.0, 0.12)
			var sat: float = randf_range(0.1, 0.7)
			var val: float = randf_range(0.6, 1.0)
			body_color = Color.from_hsv(hue, sat, val)
			accent_color = Color.from_hsv(randf_range(0.0, 0.1), randf_range(0.8, 1.0), randf_range(0.7, 1.0))
			secondary_color = Color.from_hsv(hue, sat * 0.5, val * 0.8)
			spot_color = Color.from_hsv(hue, sat, val * 0.5)
		"cow":
			var shade: float = randf_range(0.6, 1.0)
			body_color = Color(shade, shade, shade)
			accent_color = Color.from_hsv(randf_range(0.0, 0.1), randf_range(0.4, 0.8), randf_range(0.5, 0.8))
			secondary_color = Color(shade * 0.85, shade * 0.85, shade * 0.85)
			spot_color = Color.from_hsv(randf(), randf_range(0.3, 0.8), randf_range(0.3, 0.6))
		"rabbit":
			var hue: float = randf_range(0.0, 0.15)
			var sat: float = randf_range(0.1, 0.4)
			var val: float = randf_range(0.5, 0.9)
			body_color = Color.from_hsv(hue, sat, val)
			accent_color = Color(1.0, 1.0, 1.0)
			secondary_color = Color.from_hsv(hue, sat * 0.5, val * 0.8)
			spot_color = Color.from_hsv(0.0, 0.0, val * 0.4)
		"deer":
			var hue: float = randf_range(0.05, 0.12)
			var sat: float = randf_range(0.3, 0.7)
			var val: float = randf_range(0.5, 0.85)
			body_color = Color.from_hsv(hue, sat, val)
			accent_color = Color.from_hsv(0.0, 0.0, val * 0.6)
			secondary_color = Color.from_hsv(hue, sat * 0.5, val * 1.1)
			spot_color = Color.from_hsv(0.0, 0.0, val * 0.4)
		_:
			body_color = Color(0.8, 0.8, 0.8)
			accent_color = Color(0.6, 0.6, 0.6)

## Draws animal pixel-art entirely in code into an Image, then assigns
## it as a texture on the Sprite2D node.
func _generate_procedural_sprite() -> void:
	var w: int = 24
	var h: int = 20
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))  # transparent background

	match animal_type:
		"chicken", "bird":
			_draw_bird_body(img, w, h)
		"cow":
			_draw_quadruped_body(img, w, h)
		"rabbit":
			_draw_rabbit_body(img, w, h)
		"deer":
			_draw_quadruped_body(img, w, h)
		_:
			_draw_bird_body(img, w, h)

	var tex := ImageTexture.create_from_image(img)
	sprite.texture = tex

# ---------------------------------------------------------------------------
# Pixel-art drawing helpers
# ---------------------------------------------------------------------------

func _set_px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
		img.set_pixel(x, y, c)

func _draw_ellipse(img: Image, cx: int, cy: int, rx: int, ry: int, c: Color) -> void:
	for dy in range(-ry, ry + 1):
		for dx in range(-rx, rx + 1):
			if dx * dx * ry * ry + dy * dy * rx * rx <= rx * rx * ry * ry:
				_set_px(img, cx + dx, cy + dy, c)

func _draw_rect_solid(img: Image, x1: int, y1: int, x2: int, y2: int, c: Color) -> void:
	for y in range(y1, y2 + 1):
		for x in range(x1, x2 + 1):
			_set_px(img, x, y, c)

func _draw_line_h(img: Image, y: int, x1: int, x2: int, c: Color) -> void:
	for x in range(x1, x2 + 1):
		_set_px(img, x, y, c)

func _draw_line_v(img: Image, x: int, y1: int, y2: int, c: Color) -> void:
	for y in range(y1, y2 + 1):
		_set_px(img, x, y, c)

func _draw_triangle(img: Image, x1: int, y1: int, x2: int, y2: int, x3: int, y3: int, c: Color) -> void:
	# Simple filled triangle using scanlines
	var min_y: int = mini(y1, mini(y2, y3))
	var max_y: int = maxi(y1, maxi(y2, y3))
	for y in range(min_y, max_y + 1):
		var x_vals: Array[int] = []
		# helper: edge intersection
		var _add_edge := func(ax: int, ay: int, bx: int, by: int):
			if ay == by:
				return
			if (y >= mini(ay, by) and y < maxi(ay, by)) or (y == maxi(ay, by) and y == mini(ay, by)):
				var t: float = (y - ay) / float(by - ay)
				x_vals.append(int(ax + (bx - ax) * t))
		_add_edge.call(x1, y1, x2, y2)
		_add_edge.call(x2, y2, x3, y3)
		_add_edge.call(x3, y3, x1, y1)
		if x_vals.size() >= 2:
			x_vals.sort()
			_draw_line_h(img, y, x_vals[0], x_vals[x_vals.size() - 1], c)

# --- Bird (chicken-like) body ---
func _draw_bird_body(img: Image, w: int, h: int) -> void:
	var cx: int = w / 2
	var body_top: int = 6
	var body_bottom: int = 15
	var body_left: int = 5
	var body_right: int = 18

	# Body oval
	_draw_ellipse(img, cx, 10, 7, 5, body_color)

	# Apply pattern on body area
	match _pattern:
		1: _apply_spots(img, body_left, body_top, body_right, body_bottom, spot_color, 5)
		2: _apply_stripes(img, body_left, body_top, body_right, body_bottom, spot_color, 3)
		3: _apply_patches(img, body_left, body_top, body_right, body_bottom, secondary_color, spot_color, 4)

	# Head
	_draw_ellipse(img, cx + 5, 6, 3, 3, body_color)

	# Eye
	_set_px(img, cx + 6, 6, Color(0.0, 0.0, 0.0))
	_set_px(img, cx + 6, 5, Color(1.0, 1.0, 1.0))

	# Beak
	_draw_triangle(img, cx + 8, 6, cx + 11, 5, cx + 11, 7, accent_color)

	# Comb (on top of head)
	var comb_color: Color = Color.from_hsv(0.02, 0.9, 0.8)
	_set_px(img, cx + 4, 3, comb_color)
	_set_px(img, cx + 5, 2, comb_color)
	_set_px(img, cx + 6, 3, comb_color)

	# Tail feathers
	_draw_ellipse(img, cx - 7, 10, 3, 2, secondary_color)

	# Fill a solid attachment block so legs connect seamlessly to body
	_draw_rect_solid(img, cx - 3, body_bottom - 2, cx + 3, body_bottom - 1, body_color)

	# Legs (2px wide, start inside body so they connect solidly)
	# Spaced with a 3px gap so legs don't touch
	_draw_rect_solid(img, cx - 3, body_bottom - 2, cx - 2, h - 2, accent_color)
	_draw_rect_solid(img, cx + 2, body_bottom - 2, cx + 3, h - 2, accent_color)

	# Feet (separate, not bridging the gap)
	_draw_line_h(img, h - 1, cx - 4, cx - 2, accent_color)
	_draw_line_h(img, h - 1, cx + 2, cx + 4, accent_color)

# --- Quadruped (cow/deer-like) body ---
func _draw_quadruped_body(img: Image, w: int, h: int) -> void:
	var cx: int = w / 2
	var body_top: int = 6
	var body_bottom: int = 13
	var body_left: int = 4
	var body_right: int = 19

	# Body rectangle (torso)
	_draw_round_rect(img, body_left, body_top, body_right, body_bottom, body_color)

	# Apply pattern
	match _pattern:
		1: _apply_spots(img, body_left, body_top, body_right, body_bottom, spot_color, 6)
		2: _apply_stripes(img, body_left, body_top, body_right, body_bottom, spot_color, 4)
		3: _apply_patches(img, body_left, body_top, body_right, body_bottom, secondary_color, spot_color, 3)

	# Head (offset to right side)
	var head_cx: int = cx + 7
	var head_cy: int = body_top - 2
	_draw_ellipse(img, head_cx, head_cy, 3, 3, body_color)

	# Eyes
	_set_px(img, head_cx + 1, head_cy - 1, Color(0.0, 0.0, 0.0))
	_set_px(img, head_cx + 2, head_cy, Color(1.0, 1.0, 1.0))

	# Snout
	if animal_type == "cow":
		_draw_ellipse(img, head_cx + 4, head_cy + 1, 2, 1, accent_color)
	else: # deer
		_draw_ellipse(img, head_cx + 4, head_cy, 1, 1, accent_color)

	# Ears
	_draw_ellipse(img, head_cx - 1, head_cy - 4, 1, 2, secondary_color)

	# Horns (deer) or tiny horn nubs (cow)
	if animal_type == "deer":
		_draw_line_v(img, head_cx, 0, head_cy - 4, accent_color)
		_draw_line_v(img, head_cx + 1, 1, head_cy - 4, accent_color)
	else:
		_set_px(img, head_cx, head_cy - 4, accent_color)
		_set_px(img, head_cx + 1, head_cy - 4, accent_color)

	# Fill leg attachment zone so legs connect to body solidly
	_draw_rect_solid(img, body_left, body_bottom, body_right, body_bottom, body_color)

	# Legs (2px wide each, starting at body_bottom)
	# Spaced so paired legs have a 2px gap between them
	_draw_rect_solid(img, body_left + 1, body_bottom, body_left + 2, h - 2, secondary_color)
	_draw_rect_solid(img, body_left + 5, body_bottom, body_left + 6, h - 2, secondary_color)
	_draw_rect_solid(img, body_right - 6, body_bottom, body_right - 5, h - 2, secondary_color)
	_draw_rect_solid(img, body_right - 2, body_bottom, body_right - 1, h - 2, secondary_color)

	# Hooves (separate under each leg, not bridging the gap)
	_draw_rect_solid(img, body_left + 1, h - 2, body_left + 2, h - 1, Color(0.2, 0.2, 0.2))
	_draw_rect_solid(img, body_left + 5, h - 2, body_left + 6, h - 1, Color(0.2, 0.2, 0.2))
	_draw_rect_solid(img, body_right - 6, h - 2, body_right - 5, h - 1, Color(0.2, 0.2, 0.2))
	_draw_rect_solid(img, body_right - 2, h - 2, body_right - 1, h - 1, Color(0.2, 0.2, 0.2))

	# Tail (small)
	var tail_x: int = body_left - 1
	var tail_y: int = body_top + 2
	_set_px(img, tail_x, tail_y, secondary_color)
	_set_px(img, tail_x - 1, tail_y, secondary_color)

# --- Rabbit body ---
func _draw_rabbit_body(img: Image, w: int, h: int) -> void:
	var cx: int = w / 2
	var body_top: int = 8
	var body_bottom: int = 14
	var body_left: int = 7
	var body_right: int = 16

	# Body (round ball)
	_draw_ellipse(img, cx, 12, 5, 4, body_color)

	# Apply pattern
	match _pattern:
		1: _apply_spots(img, body_left, body_top, body_right, body_bottom, spot_color, 3)
		2: _apply_stripes(img, body_left, body_top, body_right, body_bottom, spot_color, 2)
		3: _apply_patches(img, body_left, body_top, body_right, body_bottom, secondary_color, spot_color, 2)

	# Head
	_draw_ellipse(img, cx + 4, 7, 3, 3, body_color)

	# Eye
	_set_px(img, cx + 5, 7, Color(0.0, 0.0, 0.0))
	_set_px(img, cx + 5, 6, Color(1.0, 1.0, 1.0))

	# Nose
	_set_px(img, cx + 7, 7, accent_color)

	# Ears (long pointing up)
	_draw_line_v(img, cx + 3, 1, 5, secondary_color)
	_draw_line_v(img, cx + 5, 1, 5, secondary_color)
	_draw_line_v(img, cx + 3, 1, 1, Color(0.9, 0.7, 0.7))
	_draw_line_v(img, cx + 5, 1, 1, Color(0.9, 0.7, 0.7))

	# Fill a solid attachment zone at the bottom of the body
	_draw_rect_solid(img, cx - 3, body_bottom, cx + 3, body_bottom, body_color)

	# Legs (2px wide solid blocks, attached at body_bottom)
	# Spaced with a 3px gap so legs don't touch
	_draw_rect_solid(img, cx - 3, body_bottom, cx - 2, h - 2, secondary_color)
	_draw_rect_solid(img, cx + 2, body_bottom, cx + 3, h - 2, secondary_color)

	# Tail (tiny ball)
	_set_px(img, cx - 6, 11, Color(1.0, 1.0, 1.0))
	_set_px(img, cx - 6, 12, Color(1.0, 1.0, 1.0))

func _draw_round_rect(img: Image, x1: int, y1: int, x2: int, y2: int, c: Color) -> void:
	_draw_rect_solid(img, x1, y1, x2, y2, c)
	# Round the corners slightly
	_set_px(img, x1, y1, c)
	_set_px(img, x2, y1, c)
	_set_px(img, x1, y2, c)
	_set_px(img, x2, y2, c)

# --- Pattern helpers ---
func _apply_spots(img: Image, x1: int, y1: int, x2: int, y2: int, c: Color, count: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.set_seed(randi())
	for i in range(count):
		var sx: int = rng.randi_range(x1 + 1, x2 - 1)
		var sy: int = rng.randi_range(y1 + 1, y2 - 1)
		var r: int = rng.randi_range(1, 2)
		_draw_ellipse(img, sx, sy, r, r, c)

func _apply_stripes(img: Image, x1: int, y1: int, x2: int, y2: int, c: Color, count: int) -> void:
	var step: float = (x2 - x1) / float(count + 1)
	for i in range(1, count + 1):
		var sx: int = x1 + int(i * step)
		_draw_line_v(img, sx, y1, y2, c)

func _apply_patches(img: Image, x1: int, y1: int, x2: int, y2: int, c1: Color, c2: Color, count: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.set_seed(randi())
	for i in range(count):
		var sx: int = rng.randi_range(x1, x2 - 2)
		var sy: int = rng.randi_range(y1, y2 - 2)
		var pw: int = rng.randi_range(2, 4)
		var ph: int = rng.randi_range(1, 2)
		var patch_color: Color = c1 if i % 2 == 0 else c2
		_draw_rect_solid(img, sx, sy, sx + pw, sy + ph, patch_color)

# ---------------------------------------------------------------------------
# Behaviour loop
# ---------------------------------------------------------------------------

func _ready() -> void:
	_move_radius = randf_range(32.0, 80.0)
	add_to_group("animals")
	interaction_prompt = "Pet " + animal_name
	_world_ref = get_tree().get_first_node_in_group("world")
	_player_ref = get_tree().get_first_node_in_group("player") as Node2D

func _process(delta: float) -> void:
	_idle_phase += delta * 2.0
	var dist: float = global_position.distance_to(_target_pos)
	var is_moving: bool = false

	match behavior:
		Behavior.IDLE:
			is_moving = false

		Behavior.SKITTISH:
			var player: Node2D = _get_nearest_player()
			if player and global_position.distance_to(player.global_position) < 56.0:
				var flee_dir: Vector2 = (global_position - player.global_position).normalized()
				var flee_pos: Vector2 = global_position + flee_dir * move_speed * delta
				if _is_walkable_position(flee_pos):
					global_position = flee_pos
					sprite.flip_h = flee_dir.x > 0
					is_moving = true
				else:
					# Hit water boundary — pick a new target away from the player
					_pick_new_target()
			elif dist > 3.0:
				_walk_toward(delta)
				is_moving = true

		Behavior.GRAZE:
			if _rest_time > 0.0:
				_rest_time -= delta
			elif dist > 3.0:
				_walk_toward(delta)
				is_moving = true
				if randf() < 0.005:
					_rest_time = randf_range(1.0, 3.0)

		_:  # WANDER
			if dist > 3.0:
				_walk_toward(delta)
				is_moving = true

	# Gentle idle bob when stationary
	if not is_moving:
		sprite.position.y = sin(_idle_phase) * 1.5

func _walk_toward(delta: float) -> void:
	var dir: Vector2 = (_target_pos - global_position).normalized()
	var new_pos: Vector2 = global_position + dir * move_speed * delta
	# Don't walk into water - if the next position is non-walkable, stop and pick a new target
	if _is_walkable_position(new_pos):
		global_position = new_pos
		if abs(dir.x) > 0.2:
			sprite.flip_h = dir.x < 0
	else:
		_pick_new_target()

func _pick_new_target() -> void:
	# Try up to 20 times to find a walkable target (not in water)
	for _attempt in 20:
		var candidate := _home_pos + Vector2(
			randf_range(-_move_radius, _move_radius),
			randf_range(-_move_radius, _move_radius)
		)
		if _is_walkable_position(candidate):
			_target_pos = candidate
			return
	# Fallback: go home (which should always be walkable)
	_target_pos = _home_pos

## Returns true if the given world position is on a walkable tile
## (not water, edge, or out of bounds).
func _is_walkable_position(pos: Vector2) -> bool:
	if not _world_ref or not _world_ref.has_method("is_cell_walkable"):
		return true  # can't check, assume walkable
	return _world_ref.is_cell_walkable(pos)

func _on_wander_timer_timeout() -> void:
	if behavior == Behavior.IDLE:
		return
	_pick_new_target()

func _get_nearest_player() -> Node2D:
	if not _player_ref:
		# Player may not have been ready when this animal's _ready() ran
		_player_ref = get_tree().get_first_node_in_group("player") as Node2D
	return _player_ref

# ---------------------------------------------------------------------------
# Interaction
# ---------------------------------------------------------------------------

func interact(interactor: Node) -> void:
	super(interactor)
	ToastNotification.show_toast(animal_name + " looks at you curiously!")
