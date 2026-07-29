extends Node2D
class_name OreDeposit

## A mineable ore deposit inside a mine room. Players use the pickaxe
## (left-click) to mine it. Mining now uses a progress-bar (hold-to-mine)
## system like chopping trees — better pickaxes make the bar fill faster.
##
## Flow:
##   1. Player with pickaxe left-clicks near the deposit
##   2. Player._try_use_tool_at_pos() → hotbar → _use_hotbar_item()
##     → _mine_ore_at(target_pos)
##   3. Player._mine_ore_at() finds the closest OreDeposit and calls
##      deposit.start_mining(player, pickaxe_id)
##   4. A progress bar appears above the deposit and fills over time.
##      If the player walks away, mining cancels (no ore lost).
##   5. When the bar fills, one hit worth of ore is dropped. If the
##      deposit still has remaining hits, the bar resets for another hit.

## What ore type this deposit yields. Must match a DataManager item_id.
@export var ore_type: String = "copper_ore"
## How many hits before this deposit is fully depleted.
@export var max_hits: int = 5
## How many ore items drop per hit (min).
@export var min_per_hit: int = 1
## How many ore items drop per hit (max).
@export var max_per_hit: int = 3
## Optional: chance (0.0–1.0) to drop a bonus gem/extra item on last hit.
@export var bonus_chance: float = 0.0
## The bonus item id to drop on last hit if bonus_chance succeeds.
@export var bonus_item: String = ""

## Base time (seconds) to mine one hit with a basic pickaxe.
## Better pickaxe tiers reduce this via PICKAXE_SPEED_MULTIPLIERS.
@export var base_gather_time: float = 1.5

## How long (seconds) the deposit stays hidden and depleted before
## regenerating with fresh ore. Set to 0 to disable regeneration
## (permanent depletion — original behavior).
@export var regeneration_time: float = 60.0

## How quickly the pickaxe tier mines relative to base_gather_time.
## Higher tier = lower multiplier = faster mining.
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

var remaining_hits: int = 5

# Mining-progress state (progress-bar style, one miner at a time)
var _is_mining: bool = false
var _mining_progress: float = 0.0
var _gather_time: float = 1.5  # computed from base * pickaxe multiplier
var _miner_ref: Node = null  # the player who started mining

# Regeneration state
var _is_regenerating: bool = false
var _regen_timer: SceneTreeTimer = null

# Reference to the collision body for toggling
var _collision_body: StaticBody2D = null

# Progress bar nodes (created in _ready)
var _progress_bg: ColorRect = null
var _progress_fill: ColorRect = null

## Max distance-squared the player can wander before mining cancels.
const MINE_RANGE_SQ: float = 900.0  # ~30px — same ballpark as ORE_MINE_RANGE

@onready var sprite: Sprite2D = $Sprite2D

# Texture lookup by ore type — 32×32 sprites for better visibility
const ORE_TEXTURES: Dictionary = {
	"copper_ore": preload("res://assets/generated/copper_ore_deposit_2_frame_0.png"),
	"coal": preload("res://assets/generated/coal_deposit_2_frame_0.png"),
	"gold_ore": preload("res://assets/generated/gold_ore_deposit_2_frame_0.png"),
	"iron_ore": preload("res://assets/generated/iron_ore_deposit_2_frame_0.png"),
	"stone": preload("res://assets/generated/stone_ore_deposit_frame_0.png"),
	"silver_ore": preload("res://assets/generated/silver_ore_deposit_2_frame_0.png"),
	"diamond_ore": preload("res://assets/generated/diamond_ore_deposit_2_frame_0.png"),
	"ruby_ore": preload("res://assets/generated/ruby_ore_deposit_2_frame_0.png"),
	"obsidian_ore": preload("res://assets/generated/obsidian_ore_deposit_2_frame_0.png"),
}


func _ready() -> void:
	remaining_hits = max_hits
	add_to_group("ore_deposits")
	# Set texture based on ore type
	if ORE_TEXTURES.has(ore_type) and sprite:
		sprite.texture = ORE_TEXTURES[ore_type]
	_setup_progress_bar()
	_setup_collision()


## Create the small progress-bar above the ore deposit, hidden until mining starts.
func _setup_progress_bar() -> void:
	_progress_bg = ColorRect.new()
	_progress_bg.name = "MineProgressBG"
	_progress_bg.size = Vector2(28, 4)
	_progress_bg.position = Vector2(-14, -28)  # Above the deposit sprite
	_progress_bg.color = Color(0.1, 0.1, 0.1, 0.6)
	_progress_bg.visible = false
	add_child(_progress_bg)

	_progress_fill = ColorRect.new()
	_progress_fill.name = "MineProgressFill"
	_progress_fill.size = Vector2(0, 4)
	_progress_fill.position = Vector2(-14, -28)
	_progress_fill.color = Color(0.3, 0.5, 0.9, 0.9)  # Blue-ish for mining
	_progress_fill.visible = false
	add_child(_progress_fill)


## Add a StaticBody2D collision shape so the player can't walk through ore.
## Uses the same collision layer 1 as interior walls (player collides with
## layer 1 when inside a mine interior).
func _setup_collision() -> void:
	var body := StaticBody2D.new()
	body.name = "OreCollision"
	body.collision_layer = 1  # interior wall / mine obstacle layer
	
	var shape := CollisionShape2D.new()
	shape.name = "OreShape"
	var rect := RectangleShape2D.new()
	# Slightly smaller than the sprite for a fair collision feel
	var tex_size: Vector2 = sprite.texture.get_size() if sprite and sprite.texture else Vector2(32, 32)
	rect.size = Vector2(maxf(tex_size.x - 6, 16), maxf(tex_size.y - 6, 16))
	shape.shape = rect
	body.add_child(shape)
	
	add_child(body)
	_collision_body = body


## Check whether the deposit can start a new mining session.
## Returns false if already being mined, fully depleted, or regenerating.
func can_start_mining() -> bool:
	if _is_mining:
		return false
	if _is_regenerating:
		return false
	if remaining_hits <= 0:
		return false
	return true


func _process(delta: float) -> void:
	if not _is_mining:
		return

	# Cancel if the player walked away or the reference is gone
	if not _is_miner_in_range():
		_cancel_mining()
		return

	_mining_progress += delta
	var ratio: float = minf(_mining_progress / _gather_time, 1.0)
	_progress_fill.size.x = ratio * 28.0

	if _mining_progress >= _gather_time:
		_complete_hit()


## Check whether the player who started mining is still nearby.
func _is_miner_in_range() -> bool:
	if not _miner_ref or not is_instance_valid(_miner_ref):
		return false
	var dist_sq: float = global_position.distance_squared_to(_miner_ref.global_position)
	return dist_sq < MINE_RANGE_SQ


## Start the mining progress bar. Called by Player after finding this deposit.
## Returns true if mining started, false if busy/depleted.
func start_mining(player: Node, pickaxe_id: String) -> bool:
	if not can_start_mining():
		return false

	_is_mining = true
	_mining_progress = 0.0
	_miner_ref = player

	# Compute gather time from pickaxe speed multiplier
	var mult: float = PICKAXE_SPEED_MULTIPLIERS.get(pickaxe_id, 1.0)
	_gather_time = base_gather_time * mult

	# Show the progress bar
	_progress_bg.visible = true
	_progress_fill.visible = true
	_progress_fill.size.x = 0.0

	return true


## Reset mining state — deposit can be mined again from scratch.
## The deposit is available to be mined again (unless fully depleted).
func _cancel_mining() -> void:
	_is_mining = false
	_mining_progress = 0.0
	_miner_ref = null
	_progress_bg.visible = false
	_progress_fill.visible = false
	_progress_fill.size.x = 0.0


## Called when the progress bar fills completely — drop one hit worth of ore.
func _complete_hit() -> void:
	_is_mining = false
	_progress_bg.visible = false
	_progress_fill.visible = false

	if remaining_hits <= 0:
		return

	remaining_hits -= 1

	var amount := randi_range(min_per_hit, max_per_hit)
	InventoryManager.add_item(ore_type, amount)

	# Floating text for ore collected
	var ore_name := get_ore_display_name()
	EffectSpawner.spawn_floating_text("+%d %s" % [amount, ore_name], global_position, Color(0.7, 0.7, 0.7))

	# Award mining XP
	LevelManager.add_xp_source("mine_ore")

	# Notify ObjectiveManager about ore collection
	var om_ore := get_tree().get_first_node_in_group("objective_manager")
	if om_ore and om_ore.has_method("on_ore_collected"):
		om_ore.on_ore_collected(amount)

	# Visual feedback — flash and update depletion
	if sprite:
		_update_depletion_visual()
		var tween := create_tween()
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.03)
		tween.tween_property(sprite, "modulate", Color(1.5, 1.5, 1.5), 0.04)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.03)

	# Tick mining combo on the player
	if _miner_ref and is_instance_valid(_miner_ref) and _miner_ref.has_method(&"_on_ore_deposit_mined"):
		_miner_ref._on_ore_deposit_mined(ore_type, amount, ore_name)

	# Sound and particles
	AudioManager.play(AudioManager.Sound.PICKAXE_HIT)
	EffectSpawner.spawn_dirt_puff(global_position)

	# Bonus drop on last hit
	if remaining_hits <= 0:
		if bonus_chance > 0.0 and bonus_item != "":
			if randf() < bonus_chance:
				InventoryManager.add_item(bonus_item, 1)
				# Show floating text for bonus
				EffectSpawner.spawn_floating_text("+1 " + bonus_item, global_position, Color.GOLD)

		# Bonus XP for fully depleting a deposit
		LevelManager.add_xp_source("mine_ore_final")

		# Start regeneration (disappear, then come back later)
		_start_regeneration()

	# Reset for next hit if deposit still has ore
	_mining_progress = 0.0
	_miner_ref = null


## Adjust the sprite's appearance based on how depleted the deposit is.
## The sprite gets progressively darker and slightly smaller, giving a
## visual cue that the ore is running out.
func _update_depletion_visual() -> void:
	var ratio: float = get_depletion_ratio()
	# Scale down slightly as it depletes (1.0 → 0.85)
	var scale_val := 1.0 - ratio * 0.15
	sprite.scale = Vector2(scale_val, scale_val)
	# Darken sprite slightly as it depletes
	var brightness: float = 1.0 - ratio * 0.25
	sprite.self_modulate = Color(brightness, brightness, brightness)


## Enter regeneration state: hide the deposit, disable collision, and
## start a timer. When the timer fires, the deposit reappears with fresh ore.
func _start_regeneration() -> void:
	_is_regenerating = true

	# Hide the sprite
	if sprite:
		sprite.visible = false

	# Hide any lingering progress bar
	_progress_bg.visible = false
	_progress_fill.visible = false

	# Disable collision so the player can walk through
	if _collision_body:
		_collision_body.collision_layer = 0

	# Start the regeneration timer
	if regeneration_time > 0.0:
		_regen_timer = get_tree().create_timer(regeneration_time)
		_regen_timer.timeout.connect(_on_regenerated)
	else:
		# regeneration_time == 0 means permanent depletion (original behavior)
		queue_free()


## Called when the regeneration timer expires — restore the deposit to full.
func _on_regenerated() -> void:
	if not _is_regenerating:
		return

	# Reset ore count
	remaining_hits = max_hits

	# Show the sprite and restore its visuals
	if sprite:
		sprite.visible = true
		sprite.scale = Vector2(1.0, 1.0)
		sprite.self_modulate = Color.WHITE
		sprite.modulate = Color.WHITE

	# Re-enable collision
	if _collision_body:
		_collision_body.collision_layer = 1

	# Clear regeneration state
	_is_regenerating = false
	_regen_timer = null


## Returns the ore_type's display name for UI purposes.
func get_ore_display_name() -> String:
	var item: ItemData = DataManager.get_item(ore_type)
	return item.display_name if item else ore_type


## Returns how depleted this deposit looks (0.0 = full, 1.0 = empty).
func get_depletion_ratio() -> float:
	if max_hits <= 0:
		return 0.0
	return 1.0 - (float(remaining_hits) / float(max_hits))
