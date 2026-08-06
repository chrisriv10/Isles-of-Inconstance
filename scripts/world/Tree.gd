extends Interactable
class_name TreeObject

## A harvestable tree with pre-generated sprite variety.
## Randomly picks from hand-crafted pixel-art tree sprites
## so each tree looks unique without procedural generation overhead.
## Use set_cherry() before _ready() to make this tree use cherry sprites.
##
## Chopping takes time (like Minecraft): press E with an axe equipped,
## stand nearby while a progress bar fills. Walk away to cancel.

@export var min_wood: int = 1
@export var max_wood: int = 2

## Optional fruit item to yield alongside wood (e.g. "ice_cream_cone").
## Set to non-empty to give bonus items when chopped.
@export var fruit_item_id: String = ""
@export var min_fruit: int = 1
@export var max_fruit: int = 3

## How many seconds the player must stand still nearby to chop this tree.
## Base time before axe tier multiplier is applied.
@export var chop_time: float = 1.5

## How quickly each axe tier chops relative to chop_time.
## Higher tier = lower multiplier = faster chopping.
## Keyed by axe item_id. Basic axe_tool is 1.0 (no reduction).
const AXE_SPEED_MULTIPLIERS: Dictionary = {
	"axe_tool": 1.0,
	"copper_axe": 0.80,
	"iron_axe": 0.63,
	"gold_axe": 0.48,
	"diamond_axe": 0.35,
	"mythril_axe": 0.22,
	"magma_axe": 0.22,
}

# Pre-generated tree sprite paths — cherry sprites are excluded by default
const TREE_SPRITES: Array[String] = [
	"res://assets/generated/tree_01_frame_0.png",
	"res://assets/generated/tree_02_frame_0.png",
	"res://assets/generated/tree_round_green_frame_0.png",
	"res://assets/generated/tree_pine_dark_frame_0.png",
	"res://assets/generated/tree_umbrella_green_frame_0.png",
	"res://assets/generated/tree_oblong_olive_frame_0.png",
	"res://assets/generated/tree_autumn_orange_frame_0.png",
	"res://assets/generated/tree_twin_green_frame_0.png",
	"res://assets/generated/tree_vase_yellow_frame_0.png",
]

# Cherry blossom sprites — only used when _is_cherry is true
const CHERRY_SPRITES: Array[String] = [
	"res://assets/generated/tree_cherry_pink_frame_0.png",
]

## Override the default TREE_SPRITES with island-type-specific sprites.
## Set this before _ready() (e.g. from ExpeditionIsland before add_child).
var sprite_pool_override: Array[String] = []

var _is_cherry: bool = false

# Chopping-progress state
var _is_chopping: bool = false
var _chop_progress: float = 0.0
var _chopper_ref: Node = null

# Progress bar nodes (created in _ready)
var _progress_bg: ColorRect = null
var _progress_fill: ColorRect = null

# Actual chop time after axe tier multiplier is applied
var _current_chop_time: float = 1.5

# The axe item_id used when chopping started (for tier bonus in _complete_chopping)
var _current_axe_id: String = "axe_tool"

## Max distance-squared the player can wander before chopping cancels.
const CHOP_RANGE_SQ: float = 600.0  # ~24px

## Minimum time (seconds) between "Need an axe!" warning messages.
const AXE_WARNING_COOLDOWN: float = 1.5

var _last_axe_warning_time: float = 0.0


func _ready() -> void:
	interaction_prompt = "Chop"
	required_tool = Player.Tool.AXE
	_pick_random_sprite()
	_setup_progress_bar()


## Create the small progress-bar above the tree, hidden until chopping starts.
func _setup_progress_bar() -> void:
	_progress_bg = ColorRect.new()
	_progress_bg.name = "ChopProgressBG"
	_progress_bg.size = Vector2(28, 4)
	_progress_bg.position = Vector2(-14, -22)  # Above the tree sprite (lowered to match harvest-bar level)
	_progress_bg.color = Color(0.1, 0.1, 0.1, 0.6)
	_progress_bg.visible = false
	add_child(_progress_bg)

	_progress_fill = ColorRect.new()
	_progress_fill.name = "ChopProgressFill"
	_progress_fill.size = Vector2(0, 4)
	_progress_fill.position = Vector2(-14, -22)
	_progress_fill.color = Color(0.3, 0.8, 0.3, 0.9)
	_progress_fill.visible = false
	add_child(_progress_fill)


## Block re-interaction while we're in the middle of chopping.
func can_interact() -> bool:
	if _is_chopping:
		return false
	return not (single_use and _used)


func _process(delta: float) -> void:
	if not _is_chopping:
		return

	# Cancel if the player walked away or the reference is gone
	if not _is_chopper_in_range():
		_cancel_chopping()
		return

	_chop_progress += delta
	var ratio: float = minf(_chop_progress / _current_chop_time, 1.0)
	_progress_fill.size.x = ratio * 28.0

	if _chop_progress >= _current_chop_time:
		_complete_chopping()


## Check whether the player who started chopping is still nearby.
func _is_chopper_in_range() -> bool:
	if not _chopper_ref or not is_instance_valid(_chopper_ref):
		return false
	var dist_sq: float = global_position.distance_squared_to(_chopper_ref.global_position)
	return dist_sq < CHOP_RANGE_SQ


## Reset progress — tree is available to be chopped again.
func _cancel_chopping() -> void:
	_is_chopping = false
	_chop_progress = 0.0
	_chopper_ref = null
	_progress_bg.visible = false
	_progress_fill.visible = false
	_progress_fill.size.x = 0.0
	_used = false  # allow another attempt


## Called when the progress bar fills completely — actually give the wood.
func _complete_chopping() -> void:
	_is_chopping = false
	_progress_bg.visible = false
	_progress_fill.visible = false

	# Add tier bonus wood if using an upgraded axe
	var tier_bonus: int = 0
	if _chopper_ref and is_instance_valid(_chopper_ref):
		var pl: Player = _chopper_ref as Player
		if pl and pl.has_method(&"_get_axe_tier_bonus"):
			tier_bonus = pl._get_axe_tier_bonus(_current_axe_id)

	var amount := randi_range(min_wood, max_wood) + tier_bonus
	var remaining := InventoryManager.add_item("wood", amount)
	if remaining < amount:
		EffectSpawner.spawn_dirt_puff(global_position)
		EffectSpawner.spawn_resource_notification("Wood", amount, global_position, Color(0.6, 0.4, 0.2))
		AudioManager.play(AudioManager.Sound.GATHER)
		LevelManager.add_xp_source("gather")
	else:
		EffectSpawner.spawn_floating_text("Inventory full!", global_position, Color.YELLOW)
		_used = false
		return

	# If this tree has a fruit_item_id, give fruit too
	if not fruit_item_id.is_empty():
		var fruit_amt := randi_range(min_fruit, max_fruit)
		var added_fruit := InventoryManager.add_item(fruit_item_id, fruit_amt)
		if added_fruit > 0:
			var fruit_item_data: ItemData = DataManager.get_item(fruit_item_id)
			var fruit_name: String = fruit_item_data.display_name if fruit_item_data else fruit_item_id.replace("_", " ").capitalize()
			EffectSpawner.spawn_resource_notification(fruit_name, added_fruit, global_position + Vector2(0, 8), Color(1.0, 0.6, 0.8))
			AudioManager.play(AudioManager.Sound.GATHER)
			LevelManager.add_xp_source("gather")

	_used = true
	AudioManager.play(AudioManager.Sound.DESTROY)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property($Sprite2D, "modulate:a", 0.0, 0.3)
	tween.tween_callback(_notify_and_free)


func _notify_and_free() -> void:
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


## Mark this tree as a cherry tree so it uses cherry blossom sprites.
func set_cherry() -> void:
	_is_cherry = true


## Picks a random pre-generated tree sprite and assigns it to the Sprite2D child.
## Cherry trees pick from cherry-only sprites; all others exclude cherry sprites.
## If sprite_pool_override is set (non-empty), uses that instead of the default pool.
func _pick_random_sprite() -> void:
	var sprite_node: Sprite2D = $Sprite2D
	if not sprite_node:
		return
	
	var pool: Array[String]
	if _is_cherry:
		pool = CHERRY_SPRITES
	elif not sprite_pool_override.is_empty():
		pool = sprite_pool_override
	else:
		pool = TREE_SPRITES
	
	var path: String = pool[randi() % pool.size()]
	if ResourceLoader.exists(path):
		sprite_node.texture = load(path)
	# If the file doesn't exist, the sprite stays blank rather than crashing.


func interact(interactor: Node) -> void:
	if not can_interact():
		return
	if not _check_tool_requirement(interactor):
		var now: float = Time.get_ticks_msec() / 1000.0
		if now - _last_axe_warning_time >= AXE_WARNING_COOLDOWN:
			_last_axe_warning_time = now
			EffectSpawner.spawn_floating_text("Need an axe!", global_position, Color.ORANGE_RED)
		return

	# Detect axe tier and apply speed multiplier
	var player: Player = Interactable._resolve_player(interactor)
	var axe_id: String = player.get_active_hotbar_item_id() if player else ""
	if axe_id.is_empty() or not AXE_SPEED_MULTIPLIERS.has(axe_id):
		axe_id = "axe_tool"
	_current_chop_time = chop_time * AXE_SPEED_MULTIPLIERS[axe_id]
	_current_axe_id = axe_id

	# Start the timed chopping process instead of collecting instantly
	_is_chopping = true
	_chop_progress = 0.0
	_chopper_ref = interactor
	_used = true  # prevent double-interaction while chopping

	# Show the progress bar
	_progress_bg.visible = true
	_progress_fill.visible = true
	_progress_fill.size.x = 0.0
