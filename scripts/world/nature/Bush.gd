extends Interactable
class_name Bush

## A harvestable bush that gives berries or leaves.
## Comes in different sizes and berry colors.
## Hold E to harvest — a progress bar fills above the bush.

@export var bush_variant: int = 0  # 0=small, 1=medium, 2=large
@export var berry_color: Color = Color(0.8, 0.2, 0.2)
@export var berry_count: int = 2
## If set (to a res:// path), use this pre-made texture instead of procedural generation.
## Set this BEFORE _ready() (e.g. before add_child from an island generator).
@export var texture_override_path: String = ""
## If set, picks a random sprite from this pool and applies a random color tint.
## Takes priority over texture_override_path. Set BEFORE _ready().
@export var texture_override_pool: Array = []
@export var regrow_days: int = 3

## How many seconds the player must stand still nearby to harvest.
@export var harvest_time: float = 0.5

var _harvested: bool = false
var _days_since_harvest: int = 0

# Hold-to-harvest state
var _is_harvesting: bool = false
var _harvest_progress: float = 0.0
var _harvester_ref: Node = null

# Progress bar nodes (created in _ready)
var _progress_bg: ColorRect = null
var _progress_fill: ColorRect = null

## Max distance-squared the player can wander before harvesting cancels.
const HARVEST_RANGE_SQ: float = 600.0  # ~24px

func _ready() -> void:
	interaction_prompt = "Harvest"
	
	# Initialize seeded RNG for deterministic multiplayer visuals
	var world := get_tree().get_first_node_in_group("world")
	var rng := RandomNumberGenerator.new()
	if world and world.has_method("world_to_cell"):
		var cell := world.world_to_cell(global_position)
		rng.seed = hash(str(world.world_seed) + ":bush:" + str(cell.x) + "," + str(cell.y))
	else:
		rng.randomize()
	
	bush_variant = rng.randi() % 3
	berry_color = _random_berry_color_seeded(rng)
	berry_count = rng.randi_range(1, 4)
	_generate_sprite()
	_setup_progress_bar()
	# Connect to day tracking so bushes can regrow after harvest
	if GameManager.day_changed.is_connected(_on_day_passed):
		pass
	GameManager.day_changed.connect(_on_day_passed)


## Create the small progress bar above the bush, hidden until harvesting starts.
func _setup_progress_bar() -> void:
	_progress_bg = ColorRect.new()
	_progress_bg.name = "HarvestProgressBG"
	_progress_bg.size = Vector2(20, 3)
	_progress_bg.position = Vector2(-10, -20)  # Above the bush sprite
	_progress_bg.color = Color(0.1, 0.1, 0.1, 0.6)
	_progress_bg.visible = false
	add_child(_progress_bg)

	_progress_fill = ColorRect.new()
	_progress_fill.name = "HarvestProgressFill"
	_progress_fill.size = Vector2(0, 3)
	_progress_fill.position = Vector2(-10, -20)
	_progress_fill.color = Color(0.3, 0.8, 0.3, 0.9)
	_progress_fill.visible = false
	add_child(_progress_fill)


func can_interact() -> bool:
	return not (_harvested or _is_harvesting)


func _process(delta: float) -> void:
	if not _is_harvesting:
		return

	# Cancel if the player walked away or the reference is gone
	if not _is_harvester_in_range():
		_cancel_harvesting()
		return

	_harvest_progress += delta
	var ratio: float = minf(_harvest_progress / harvest_time, 1.0)
	_progress_fill.size.x = ratio * 20.0

	if _harvest_progress >= harvest_time:
		_complete_harvesting()


func _is_harvester_in_range() -> bool:
	if not _harvester_ref or not is_instance_valid(_harvester_ref):
		return false
	var dist_sq: float = global_position.distance_squared_to(_harvester_ref.global_position)
	return dist_sq < HARVEST_RANGE_SQ


func _cancel_harvesting() -> void:
	_is_harvesting = false
	_harvest_progress = 0.0
	_harvester_ref = null
	_progress_bg.visible = false
	_progress_fill.visible = false
	_progress_fill.size.x = 0.0

func _random_berry_color() -> Color:
	var colors := [
		Color(0.8, 0.2, 0.2),  # red
		Color(0.2, 0.4, 0.8),  # blue
		Color(0.8, 0.2, 0.8),  # purple
		Color(0.2, 0.6, 0.2),  # green
		Color(1.0, 0.7, 0.1),  # orange
		Color(0.1, 0.1, 0.1),  # black
	]
	return colors[randi() % colors.size()]


func _random_berry_color_seeded(rng: RandomNumberGenerator) -> Color:
	var colors := [
		Color(0.8, 0.2, 0.2),  # red
		Color(0.2, 0.4, 0.8),  # blue
		Color(0.8, 0.2, 0.8),  # purple
		Color(0.2, 0.6, 0.2),  # green
		Color(1.0, 0.7, 0.1),  # orange
		Color(0.1, 0.1, 0.1),  # black
	]
	return colors[rng.randi() % colors.size()]


func _generate_sprite() -> void:
	var sprite_node: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
	if not sprite_node:
		return
	
	# Initialize seeded RNG for deterministic multiplayer visuals
	var world := get_tree().get_first_node_in_group("world")
	var rng := RandomNumberGenerator.new()
	if world and world.has_method("world_to_cell"):
		var cell := world.world_to_cell(global_position)
		rng.seed = hash(str(world.world_seed) + ":bush:" + str(cell.x) + "," + str(cell.y))
	else:
		rng.randomize()
	
	# Use texture override pool if provided — picks random + applies tint
	if not texture_override_pool.is_empty():
		var path: String = texture_override_pool[rng.randi() % texture_override_pool.size()]
		if ResourceLoader.exists(path):
			sprite_node.texture = load(path)
			# Apply a random color tint to the foliage part
			var tint_variants: Array[Color] = [
				Color(1.0, 1.0, 1.0),           # no tint
				Color(0.85, 1.0, 0.85),          # lighter green
				Color(0.9, 0.95, 0.75),          # yellow-green
				Color(0.8, 0.9, 1.0),            # blue-tinted
				Color(1.0, 0.85, 0.95),          # pink-tinted
				Color(0.95, 0.9, 0.8),           # warm tone
			]
			sprite_node.modulate = tint_variants[rng.randi() % tint_variants.size()]
		return
	
	# Use texture override if provided
	if not texture_override_path.is_empty() and ResourceLoader.exists(texture_override_path):
		sprite_node.texture = load(texture_override_path)
		return
	
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	
	# Draw bush body (green)
	var bush_color := Color(0.2, 0.6, 0.15)
	if bush_variant == 0:
		_draw_bush_small(img, bush_color)
	elif bush_variant == 1:
		_draw_bush_medium(img, bush_color)
	else:
		_draw_bush_large(img, bush_color)
	
	# Draw berries
	_draw_berries(img, berry_color)
	
	var tex := ImageTexture.create_from_image(img)
	sprite_node.texture = tex

func _draw_bush_small(img: Image, color: Color) -> void:
	for y in range(6, 12):
		for x in range(5, 11):
			var dx: int = abs(x - 8)
			var dy: int = abs(y - 9)
			if dx + dy < 4:
				img.set_pixel(x, y, color)

func _draw_bush_medium(img: Image, color: Color) -> void:
	for y in range(4, 13):
		for x in range(3, 13):
			var dx: int = abs(x - 8)
			var dy: int = abs(y - 8)
			if dx + dy < 6:
				img.set_pixel(x, y, color)

func _draw_bush_large(img: Image, color: Color) -> void:
	for y in range(3, 14):
		for x in range(2, 14):
			var dx: int = abs(x - 8)
			var dy: int = abs(y - 8)
			if dx + dy < 7:
				img.set_pixel(x, y, color)

func _draw_berries(img: Image, color: Color) -> void:
	var berry_positions: Array[Vector2i] = []
	match bush_variant:
		0: berry_positions = [Vector2i(7, 8), Vector2i(9, 9)]
		1: berry_positions = [Vector2i(6, 7), Vector2i(10, 8), Vector2i(8, 10)]
		2: berry_positions = [Vector2i(5, 6), Vector2i(7, 5), Vector2i(9, 6), Vector2i(11, 8), Vector2i(6, 10)]
	
	for pos in berry_positions:
		img.set_pixel(pos.x, pos.y, color)
		img.set_pixel(pos.x + 1, pos.y, color)
		img.set_pixel(pos.x, pos.y + 1, color)
		img.set_pixel(pos.x + 1, pos.y + 1, color)

## Convert a berry Color to a human-readable color name.
static func get_berry_color_name(color: Color) -> String:
	var names := {
		Color(0.8, 0.2, 0.2): "Red",
		Color(0.2, 0.4, 0.8): "Blue",
		Color(0.8, 0.2, 0.8): "Purple",
		Color(0.2, 0.6, 0.2): "Green",
		Color(1.0, 0.7, 0.1): "Orange",
		Color(0.1, 0.1, 0.1): "Black",
	}
	return names.get(color, "Berry")


func interact(interactor: Node) -> void:
	if not can_interact() or _harvested:
		return
	
	# Start hold-to-harvest progress bar
	_is_harvesting = true
	_harvest_progress = 0.0
	_harvester_ref = interactor
	_progress_bg.visible = true
	_progress_fill.visible = true
	_progress_fill.size.x = 0.0


## Called when the progress bar fills — actually give the berries.
func _complete_harvesting() -> void:
	_is_harvesting = false
	_progress_bg.visible = false
	_progress_fill.visible = false
	
	var level_bonus: int = 0
	if _harvester_ref and is_instance_valid(_harvester_ref) and _harvester_ref.is_in_group("player"):
		level_bonus = floori(LevelManager.get_level() / 10.0)
	var total_harvest := berry_count + level_bonus
	var leftover := InventoryManager.add_item("berry", total_harvest, berry_color)
	var gathered := total_harvest - leftover
	if gathered <= 0:
		EffectSpawner.spawn_floating_text("Inventory full!", global_position, Color.YELLOW)
		return
	var color_name := Bush.get_berry_color_name(berry_color)
	EffectSpawner.spawn_dirt_puff(global_position)
	EffectSpawner.spawn_floating_text("+%d %s Berries" % [gathered, color_name], global_position, Color(0.8, 0.2, 0.2))
	ToastNotification.show_toast("Harvested %d %s berries from bush!" % [gathered, color_name], ToastNotification.ToastType.SUCCESS, 1.5)
	AudioManager.play(AudioManager.Sound.GATHER)
	LevelManager.add_xp_source("gather")
	
	# Track foraging objectives
	var om := get_tree().get_first_node_in_group("objective_manager")
	if om and om.has_method("on_berry_gathered"):
		om.on_berry_gathered()
	if om and om.has_method("on_gather_wild"):
		om.on_gather_wild("berry", gathered)
	
	_harvested = true
	# Reduce sprite size to show harvested
	var sprite_node: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
	if sprite_node:
		sprite_node.modulate = Color(0.5, 0.5, 0.3)
	interaction_prompt = "Regrowing..."
	
	# Notify remote peers so they see the bush as harvested
	if NetworkManager.is_network_active():
		var world = get_tree().current_scene
		if world and world.has_method("notify_bush_harvested"):
			world.notify_bush_harvested(global_position)


## Called remotely by World.gd to mark this bush as harvested without
## running the gameplay/inventory logic.
func set_harvested() -> void:
	_harvested = true
	_is_harvesting = false
	_progress_bg.visible = false
	_progress_fill.visible = false
	var sprite_node: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
	if sprite_node:
		sprite_node.modulate = Color(0.5, 0.5, 0.3)
	interaction_prompt = "Regrowing..."

func _on_day_passed(_day: int) -> void:
	if _harvested:
		_days_since_harvest += 1
		if _days_since_harvest >= regrow_days:
			_harvested = false
			_days_since_harvest = 0
			var sprite_node: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
			if sprite_node:
				sprite_node.modulate = Color.WHITE
			interaction_prompt = "Harvest"
