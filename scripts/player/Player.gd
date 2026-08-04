extends CharacterBody2D
class_name Player

## Handles player input and movement only. Interaction detection lives in
## PlayerInteractor.gd, and world manipulation (tilling, etc.) lives in
## World.gd - Player just asks those systems to act.

signal facing_changed(direction: Vector2)
signal active_tool_changed(tool_name: String)
## Emitted when hold-E eating starts.
signal eating_started(item_name: String)
## Emitted each frame while eating (0.0 to 1.0).
signal eating_progress(progress: float)
## Emitted when eating finishes.
signal eating_completed(item_name: String)
## Emitted when eating is cancelled.
signal eating_cancelled()

## Emitted when hold-E mine interaction starts (enter/exit/descend).
signal mine_interact_started(prompt_text: String)
## Emitted each frame while holding E near mine interactable (0.0 to 1.0).
signal mine_interact_progress(progress: float)
## Emitted when mine interaction completes.
signal mine_interact_completed()
## Emitted when mine interaction is cancelled.
signal mine_interact_cancelled()

## Emitted when hold-E rubble clearing starts.
signal rubble_clear_started(prompt_text: String)
## Emitted each frame while holding E near rubble (0.0 to 1.0).
signal rubble_clear_progress(progress: float)
## Emitted when rubble clearing completes.
signal rubble_clear_completed()
## Emitted when rubble clearing is cancelled.
signal rubble_clear_cancelled()

## Tools: 0=None, 1=Hoe, 2=WateringCan.
## 3-10 (HOTBAR_0..HOTBAR_7) are freely assignable slots that show whatever
## item is in the corresponding InventoryManager slot. Keys 3-0 select them.
## SPRINKLER=7..SWORD=11 keep their old numeric values so Interactable
## references (e.g. Player.Tool.AXE) still compile.
enum Tool {
	NONE,          # 0
	HOE,           # 1
	WATERING_CAN,  # 2
	HOTBAR_0,      # 3  — inventory slot 0
	HOTBAR_1,      # 4  — inventory slot 1
	HOTBAR_2,      # 5  — inventory slot 2
	HOTBAR_3,      # 6  — inventory slot 3
	SPRINKLER,     # 7  (legacy direct-tool, preserved value)
	SCYTHE,        # 8  (legacy direct-tool, preserved value)
	AXE,           # 9  (legacy direct-tool, preserved value)
	PICKAXE,       # 10 (legacy direct-tool, preserved value)
	SWORD,         # 11 (legacy direct-tool, preserved value)
	HOTBAR_4,      # 12 — inventory slot 4
	HOTBAR_5,      # 13 — inventory slot 5
	HOTBAR_6,      # 14 — inventory slot 6
	HOTBAR_7,      # 15 — inventory slot 7
}

@export var speed: float = 170.0
## Acceleration in px/s² — higher values = snappier response
@export var acceleration: float = 1200.0
## Friction in px/s² — higher values = quicker stops
@export var friction: float = 900.0
@export var base_tool_cooldown: float = 0.35

## Seconds of continuous movement before draining 1 hunger.
const MOVE_HUNGER_DRAIN_INTERVAL: float = 2.5

## Max enemies damaged per melee swing. Prevents one click from nuking a huge
## stacked pile of enemies into runaway knockback physics.
const MAX_MELEE_HITS_PER_SWING: int = 10

## Melee range in pixels from the player's feet. The cursor only picks the
## swing direction; the hit check stays near the player so a click on the far
## side of the screen whiffs (replaces the old "hit anything near the cursor").
const MELEE_RANGE: float = 44.0
## Field strength guard so a single swing still feels wide but not screen-wide.
const MELEE_ARC_COS: float = 0.6
## Minimum seconds between melee swings from hold-to-attack, applied even in
## creative mode (which zeroes the tool cooldown every frame). Without this,
## holding LMB in creative swings ~60 times/second and melts bosses instantly.
const MELEE_MIN_SWING_INTERVAL: float = 0.32
## Attack lunge: short dash in the swing direction to close distance.
const MELEE_LUNGE_SPEED: float = 240.0
const MELEE_LUNGE_TIME: float = 0.12
## Bow charge: seconds of hold to fully charge the shot (double damage).
const BOW_CHARGE_MAX_TIME: float = 0.7
const BOW_CHARGE_DAMAGE_MULT: float = 2.0

@onready var name_label: Label = $NameLabel
@onready var interactor: Area2D = $Interactor
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var held_item: Sprite2D = $AnimatedSprite2D/HeldItem
@onready var dialogue_bubble: Node2D = $DialogueBubble

# Remote player health bar (built in code, not in scene)
var _remote_hp_bar_bg: ColorRect = null
var _remote_hp_bar_fill: ColorRect = null
var _remote_nameplate: Label = null
var _remote_pet_node: Node2D = null
var _remote_last_armor_set: String = ""
# @onready var armor_chestplate — removed, armor uses full spritesheet swap

# Armor spritesheets — separate walk (192x96) and idle (192x96) matching the base
# player format: 4x2 grid of 48x48 frames, 8 frames per animation.
# Used to swap the entire character sprite when a full matching set is equipped.
var ARMOR_WALK_IRON: Texture2D
var ARMOR_IDLE_IRON: Texture2D
var ARMOR_WALK_LEATHER: Texture2D
var ARMOR_IDLE_LEATHER: Texture2D
var ARMOR_WALK_COPPER: Texture2D
var ARMOR_IDLE_COPPER: Texture2D
var ARMOR_WALK_SILVER: Texture2D
var ARMOR_IDLE_SILVER: Texture2D
var ARMOR_WALK_GOLD: Texture2D
var ARMOR_IDLE_GOLD: Texture2D
var ARMOR_WALK_STEEL: Texture2D
var ARMOR_IDLE_STEEL: Texture2D
var ARMOR_WALK_MYTHRIL: Texture2D
var ARMOR_IDLE_MYTHRIL: Texture2D
var ARMOR_WALK_DIAMOND: Texture2D
var ARMOR_IDLE_DIAMOND: Texture2D
var ARMOR_WALK_RUBY: Texture2D
var ARMOR_IDLE_RUBY: Texture2D
var ARMOR_WALK_OBSIDIAN: Texture2D
var ARMOR_IDLE_OBSIDIAN: Texture2D
var ARMOR_WALK_GINGERBREAD: Texture2D
var ARMOR_IDLE_GINGERBREAD: Texture2D
@onready var _world: Node2D = get_parent().get_node("World") if get_parent().has_node("World") else null
@onready var _ground_layer: TileMapLayer = _world.get_node("GroundLayer") if _world and _world.has_node("GroundLayer") else null

var facing_direction: Vector2 = Vector2.DOWN
var active_tool: Tool = Tool.HOE
var is_sitting: bool = false

## Hold-E eating state (Minecraft-style).
var _is_eating: bool = false
var _eat_progress: float = 0.0
var _eat_duration: float = 1.5  # seconds to eat/drink
var _eat_item_id: String = ""
var _eat_item: ItemData = null

## Hold-E mine interaction state (enter/exit/descend mine).
var _is_mine_interacting: bool = false
var _mine_interact_progress: float = 0.0
var _mine_interact_duration: float = 0.5  # short hold
var _mine_interact_prompt: String = ""

## Hold-E rubble clearing state.
var _is_clearing_rubble: bool = false
var _rubble_clear_progress: float = 0.0
var _rubble_clear_duration: float = 1.5  # seconds to hold
var _rubble_clear_prompt: String = ""
var _rubble_ruin_ref: RuinStructure = null

# Edge-detection for E (interact) when a LineEdit has focus — Godot's GUI
# consumes the event so _input() and _unhandled_input() never fire for it.
var _prev_e_pressed: bool = false

## Accumulator for movement-based hunger drain.
var _move_hunger_accumulator: float = 0.0

## Invincibility frames — prevents multi-hit damage.
var _is_invulnerable: bool = false
var _invulnerability_timer: Timer
var _invuln_blink_tween: Tween
var _gingerbread_sparkle_timer: Timer

# Downed state (multiplayer co-op)
var _is_downed: bool = false
var _revive_progress: float = 0.0
const REVIVE_HOLD_TIME: float = 3.0
var _revive_target: Player = null

## Base melee damage per tool (before upgrade scaling).
## Tools not listed get the default of 15.
## The upgrade bonus (+5 per TOOLS level) is added on top.
const TOOL_BASE_DAMAGE: Dictionary = {
	Tool.NONE: 0,
	Tool.HOE: 5,
	Tool.WATERING_CAN: 5,
	Tool.SPRINKLER: 5,
	Tool.SCYTHE: 5,
	Tool.AXE: 18,
	Tool.PICKAXE: 15,
	Tool.SWORD: 25,
}

# Textures for items held in the player's hand
const TEX_HOE: Texture2D = preload("res://assets/generated/hand_hoe_frame_0.png")
const TEX_WATERING_CAN: Texture2D = preload("res://assets/generated/hand_watering_can_frame_0.png")
const TEX_SEED: Texture2D = preload("res://assets/generated/icon_seed_default_frame_0.png")
const TEX_SPRINKLER: Texture2D = preload("res://assets/generated/icon_seed_default_frame_0.png")
const TEX_SCYTHE: Texture2D = preload("res://assets/generated/hand_scythe_frame_0.png")
const TEX_AXE: Texture2D = preload("res://assets/generated/hand_axe_frame_0.png")
const TEX_PICKAXE: Texture2D = preload("res://assets/generated/hand_pickaxe_frame_0.png")
const TEX_SWORD: Texture2D = preload("res://assets/generated/hand_sword_frame_0.png")
const TEX_LANTERN: Texture2D = preload("res://assets/generated/hand_lantern_frame_0.png")
const TEX_FISHING_ROD: Texture2D = preload("res://assets/generated/hand_fishing_rod_frame_0.png")
const TEX_BOW: Texture2D = preload("res://assets/generated/hand_bow_frame_0.png")

const TEX_CUTLASS: Texture2D = preload("res://assets/generated/hand_cutlass_frame_0.png")

# Boss scenes (must have Sprite2D + CollisionShape2D children)
const BOSS_ROOT_WARDEN: PackedScene = preload("res://scenes/enemies/RootWarden.tscn")
const BOSS_HOLLOW_STAG: PackedScene = preload("res://scenes/enemies/HollowStag.tscn")
const BOSS_BLOOMING_WYRM: PackedScene = preload("res://scenes/enemies/BloomingWyrm.tscn")
const BOSS_INCONSTANT_SOUL: PackedScene = preload("res://scenes/enemies/InconstantSoul.tscn")

const ARROW_SCENE: PackedScene = preload("res://scenes/player/Arrow.tscn")
const ARROW_SPEED: float = 350.0
const ORE_MINE_RANGE: float = 32.0  # max distance to detect an OreDeposit

## Critical hit system
## Base crit chance by tool type (0.0 - 1.0)
const CRIT_CHANCE: Dictionary = {
	Tool.SWORD: 0.08,
	Tool.AXE: 0.05,
	Tool.PICKAXE: 0.03,
	# Bow uses a separate check in _fire_bow()
}
const CRIT_MULTIPLIER: float = 1.8
const CRIT_BOW_CHANCE: float = 0.05

## Combo tracking: consecutive actions within a time window
const COMBO_TIMEOUT: float = 3.0  # seconds before combo resets
var _kill_combo: int = 0          # consecutive enemy kills
var _mine_combo: int = 0          # consecutive mining hits
var _last_combo_time: float = 0.0

var _tool_cooldown_remaining: float = 0.0
var _tool_swing_tween: Tween
var _last_swing_crit: bool = false

# Hold-to-attack / lunge / bow charge state
var _attack_held: bool = false
var _swing_gate_timer: float = 0.0
var _lunge_velocity: Vector2 = Vector2.ZERO
var _lunge_timer: float = 0.0
var _bow_charging: bool = false
var _bow_charge_start: float = 0.0

# Lantern light
var _lantern_light: PointLight2D = null
var _lantern_active: bool = false
var _lantern_texture: Texture2D = null


func _ready() -> void:
	add_to_group("player")
	# Draw the player above ground decorations and town building sprites
	# (buildings are z=1, NPCs are z=3, so the player sits in the same
	# "above buildings" layer). Interior/mine/island code overrides this
	# temporarily and restores it on exit.
	z_index = 1
	# Set player name from GameManager
	name_label.text = GameManager.player_name
	_ensure_build_mode_action()
	_setup_animation()
	call_deferred("_emit_initial_tool")
	# Listen for armor changes and swap spritesheet when full set equipped
	GameManager.armor_changed.connect(_update_armor_sheet)
	call_deferred("_update_armor_sheet")
	# Re-evaluate lantern light when day/night phases change
	GameManager.phase_changed.connect(_update_lantern)
	
	# Set up invulnerability timer for i-frames
	_invulnerability_timer = Timer.new()
	_invulnerability_timer.one_shot = true
	_invulnerability_timer.timeout.connect(_on_invulnerability_ended)
	add_child(_invulnerability_timer)
	
	# Timer for gingerbread armor sparkle effect
	_gingerbread_sparkle_timer = Timer.new()
	_gingerbread_sparkle_timer.wait_time = 1.5
	_gingerbread_sparkle_timer.timeout.connect(_on_gingerbread_sparkle_tick)
	add_child(_gingerbread_sparkle_timer)

	# Remote health bar (for non-authority copies shown to other players)
	if NetworkManager.is_network_active() and not is_multiplayer_authority():
		_ensure_remote_health_bar()


## Show a dialogue bubble above the player's head.
func show_dialogue(text: String, duration: float = 3.5) -> void:
	if dialogue_bubble and dialogue_bubble.has_method("show_text"):
		dialogue_bubble.show_text(text, duration)


func _ensure_build_mode_action() -> void:
	if not InputMap.has_action("open_build_mode"):
		print("WARNING: open_build_mode action missing from InputMap — adding at runtime")
		InputMap.add_action("open_build_mode")
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_V
		InputMap.action_add_event("open_build_mode", ev)

func _emit_initial_tool() -> void:
	_update_tool_ui()
	_update_held_item()
	_update_lantern()

## Builds SpriteFrames from the walk/idle spritesheets and assigns to AnimatedSprite2D.
func _setup_animation() -> void:
	var walk_tex: Texture2D = load("res://assets/generated/player_walk.png")
	var idle_tex: Texture2D = load("res://assets/generated/player_idle.png")
	var frames := SpriteFrames.new()
	frames.add_animation("idle")
	frames.add_animation("walk")
	for i in range(8):
		var idle_frame := AtlasTexture.new()
		idle_frame.atlas = idle_tex
		idle_frame.region = Rect2((i % 4) * 48, floori(i / 4) * 48, 48, 48)
		frames.add_frame("idle", idle_frame)
		var walk_frame := AtlasTexture.new()
		walk_frame.atlas = walk_tex
		walk_frame.region = Rect2((i % 4) * 48, floori(i / 4) * 48, 48, 48)
		frames.add_frame("walk", walk_frame)
	frames.set_animation_speed("idle", 6.0)
	frames.set_animation_speed("walk", 8.0)
	frames.set_animation_loop("idle", true)
	frames.set_animation_loop("walk", true)
	sprite.sprite_frames = frames
	sprite.play("idle")


func _ensure_remote_health_bar() -> void:
	if _remote_hp_bar_bg != null:
		return
	var bar_w := 24.0
	var bar_h := 4.0
	var bg := ColorRect.new()
	bg.name = "RemoteHPBarBG"
	bg.size = Vector2(bar_w, bar_h)
	bg.position = Vector2(-bar_w / 2.0, -28)
	bg.color = Color(0.1, 0.1, 0.1, 0.6)
	add_child(bg)
	_remote_hp_bar_bg = bg
	var fill := ColorRect.new()
	fill.name = "RemoteHPBarFill"
	fill.size = Vector2(bar_w, bar_h)
	fill.position = Vector2(-bar_w / 2.0, -28)
	fill.color = Color(0.3, 1.0, 0.3, 0.85)
	add_child(fill)
	_remote_hp_bar_fill = fill

	# Nameplate label (above health bar)
	var np := Label.new()
	np.name = "NameplateLabel"
	np.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	np.add_theme_font_size_override("font_size", 10)
	np.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	np.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	np.add_theme_constant_override("shadow_offset_x", 1)
	np.add_theme_constant_override("shadow_offset_y", 1)
	np.position = Vector2(0, -40)
	add_child(np)
	_remote_nameplate = np


func _update_remote_health_bar() -> void:
	if not NetworkManager.is_network_active():
		return
	if not is_instance_valid(_remote_hp_bar_fill):
		return
	var authority: int = get_multiplayer_authority()
	var stats: Dictionary = GameManager.remote_player_stats.get(authority, {})
	var hp: int = stats.get("health", -1)
	var max_hp: int = stats.get("max_health", 1)
	if hp < 0:
		_remote_hp_bar_fill.visible = false
		_remote_hp_bar_bg.visible = false
		return

	# Hide remote player when they're inside an interior (mine, expedition, building)
	var interior: bool = stats.get("inside_interior", false)
	if interior:
		visible = false
		if _remote_pet_node:
			_remote_pet_node.queue_free()
			_remote_pet_node = null
		return
	else:
		visible = true

_remote_hp_bar_fill.visible = true
	_remote_hp_bar_bg.visible = true
	# Hide original name_label for remote players, use _remote_nameplate instead
	if name_label:
		name_label.visible = false
	# Update nameplate
	if _remote_nameplate and is_instance_valid(_remote_nameplate):
		var remote_name: String = stats.get("name", "")
		if not remote_name.is_empty():
			_remote_nameplate.text = remote_name
			_remote_nameplate.visible = true
		else:
			_remote_nameplate.visible = false
	else:
		if _remote_nameplate and is_instance_valid(_remote_nameplate):
			_remote_nameplate.visible = false

	# Apply armor set visual on remote copy
	var armor_set: String = stats.get("armor_set", "")
	_apply_remote_armor(armor_set)
	var ratio := float(hp) / float(max_hp)
	var bar_w := 24.0
	_remote_hp_bar_fill.size.x = ratio * bar_w
	if ratio > 0.6:
		_remote_hp_bar_fill.color = Color(0.3, 1.0, 0.3, 0.85)
	elif ratio > 0.3:
		_remote_hp_bar_fill.color = Color(1.0, 0.8, 0.2, 0.85)
	else:
		_remote_hp_bar_fill.color = Color(1.0, 0.2, 0.2, 0.85)

	# Remote pet visual
	var active_pet_id: String = stats.get("pet_id", "")
	if active_pet_id.is_empty():
		if _remote_pet_node:
			_remote_pet_node.queue_free()
			_remote_pet_node = null
	else:
		if not _remote_pet_node or str(_remote_pet_node.get("pet_id") if _remote_pet_node else "") != active_pet_id:
			if _remote_pet_node:
				_remote_pet_node.queue_free()
			var pet_scene := preload("res://scenes/Pet.tscn")
			var pet: Node2D = pet_scene.instantiate()
			pet._is_remote = true
			if pet.has_method("setup"):
				pet.setup(active_pet_id, self)
			add_child(pet)
			_remote_pet_node = pet


func _apply_remote_armor(set_type: String) -> void:
	if _remote_last_armor_set == set_type:
		return
	_remote_last_armor_set = set_type

	if set_type.is_empty():
		_setup_animation()
		sprite.play("idle")
		return

	var walk_tex: Texture2D
	var idle_tex: Texture2D
	if set_type == "iron":
		if not ARMOR_WALK_IRON: ARMOR_WALK_IRON = load("res://assets/generated/player_walk_iron.png")
		if not ARMOR_IDLE_IRON: ARMOR_IDLE_IRON = load("res://assets/generated/player_idle_iron.png")
		walk_tex = ARMOR_WALK_IRON; idle_tex = ARMOR_IDLE_IRON
	elif set_type == "leather":
		if not ARMOR_WALK_LEATHER: ARMOR_WALK_LEATHER = load("res://assets/generated/player_walk_leather.png")
		if not ARMOR_IDLE_LEATHER: ARMOR_IDLE_LEATHER = load("res://assets/generated/player_idle_leather.png")
		walk_tex = ARMOR_WALK_LEATHER; idle_tex = ARMOR_IDLE_LEATHER
	elif set_type == "copper":
		if not ARMOR_WALK_COPPER: ARMOR_WALK_COPPER = load("res://assets/generated/player_walk_copper.png")
		if not ARMOR_IDLE_COPPER: ARMOR_IDLE_COPPER = load("res://assets/generated/player_idle_copper.png")
		walk_tex = ARMOR_WALK_COPPER; idle_tex = ARMOR_IDLE_COPPER
	elif set_type == "silver":
		if not ARMOR_WALK_SILVER: ARMOR_WALK_SILVER = load("res://assets/generated/player_walk_silver.png")
		if not ARMOR_IDLE_SILVER: ARMOR_IDLE_SILVER = load("res://assets/generated/player_idle_silver.png")
		walk_tex = ARMOR_WALK_SILVER; idle_tex = ARMOR_IDLE_SILVER
	elif set_type == "gold":
		if not ARMOR_WALK_GOLD: ARMOR_WALK_GOLD = load("res://assets/generated/player_walk_gold.png")
		if not ARMOR_IDLE_GOLD: ARMOR_IDLE_GOLD = load("res://assets/generated/player_idle_gold.png")
		walk_tex = ARMOR_WALK_GOLD; idle_tex = ARMOR_IDLE_GOLD
	elif set_type == "steel":
		if not ARMOR_WALK_STEEL: ARMOR_WALK_STEEL = load("res://assets/generated/player_walk_steel.png")
		if not ARMOR_IDLE_STEEL: ARMOR_IDLE_STEEL = load("res://assets/generated/player_idle_steel.png")
		walk_tex = ARMOR_WALK_STEEL; idle_tex = ARMOR_IDLE_STEEL
	elif set_type == "mythril":
		if not ARMOR_WALK_MYTHRIL: ARMOR_WALK_MYTHRIL = load("res://assets/generated/player_walk_mythril.png")
		if not ARMOR_IDLE_MYTHRIL: ARMOR_IDLE_MYTHRIL = load("res://assets/generated/player_idle_mythril.png")
		walk_tex = ARMOR_WALK_MYTHRIL; idle_tex = ARMOR_IDLE_MYTHRIL
	elif set_type == "diamond":
		if not ARMOR_WALK_DIAMOND: ARMOR_WALK_DIAMOND = load("res://assets/generated/player_walk_diamond.png")
		if not ARMOR_IDLE_DIAMOND: ARMOR_IDLE_DIAMOND = load("res://assets/generated/player_idle_diamond.png")
		walk_tex = ARMOR_WALK_DIAMOND; idle_tex = ARMOR_IDLE_DIAMOND
	elif set_type == "ruby":
		if not ARMOR_WALK_RUBY: ARMOR_WALK_RUBY = load("res://assets/generated/player_walk_ruby.png")
		if not ARMOR_IDLE_RUBY: ARMOR_IDLE_RUBY = load("res://assets/generated/player_idle_ruby.png")
		walk_tex = ARMOR_WALK_RUBY; idle_tex = ARMOR_IDLE_RUBY
	elif set_type == "obsidian":
		if not ARMOR_WALK_OBSIDIAN: ARMOR_WALK_OBSIDIAN = load("res://assets/generated/player_walk_obsidian.png")
		if not ARMOR_IDLE_OBSIDIAN: ARMOR_IDLE_OBSIDIAN = load("res://assets/generated/player_idle_obsidian.png")
		walk_tex = ARMOR_WALK_OBSIDIAN; idle_tex = ARMOR_IDLE_OBSIDIAN
	elif set_type == "gingerbread":
		if not ARMOR_WALK_GINGERBREAD: ARMOR_WALK_GINGERBREAD = load("res://assets/gingerbread_set/player_walk_gingerbread.png")
		walk_tex = ARMOR_WALK_GINGERBREAD; idle_tex = ARMOR_WALK_GINGERBREAD
	else:
		_setup_animation(); sprite.play("idle"); return

	if not walk_tex or not idle_tex:
		return
	var frame_size: int = 48
	var frames := SpriteFrames.new()
	frames.add_animation("idle")
	frames.add_animation("walk")
	var frame_start: int = 1 if set_type == "gingerbread" else 0
	for i in range(frame_start, 8):
		var idle_frame := AtlasTexture.new()
		idle_frame.atlas = idle_tex
		idle_frame.region = Rect2((i % 4) * frame_size, floori(i / 4) * frame_size, frame_size, frame_size)
		frames.add_frame("idle", idle_frame)
		var walk_frame := AtlasTexture.new()
		walk_frame.atlas = walk_tex
		walk_frame.region = Rect2((i % 4) * frame_size, floori(i / 4) * frame_size, frame_size, frame_size)
		frames.add_frame("walk", walk_frame)
	frames.set_animation_speed("idle", 6.0)
	frames.set_animation_speed("walk", 8.0)
	frames.set_animation_loop("idle", true)
	frames.set_animation_loop("walk", true)
	sprite.sprite_frames = frames
	sprite.play("idle")


func _process(_delta: float) -> void:
	if NetworkManager.is_network_active() and not is_multiplayer_authority():
		_update_remote_health_bar()


func _physics_process(delta: float) -> void:
	# Skip physics for remote players — they receive position via RPC
	if NetworkManager.is_network_active() and not is_multiplayer_authority():
		return
	# Sitting on a bench — disable all movement
	if is_sitting:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# Toggle collision: inside interiors, collide with walls (layer 1);
	# outside, no tilemap collision (walkability is grid-checked).
	# Inside interiors, collide with wall collision (layer 1).
	# Outside, collide with building exterior walls (layer 8).
	collision_mask = 1 if GameManager.inside_interior else 8

	if GameManager.is_creative():
		_tool_cooldown_remaining = 0.0
	elif _tool_cooldown_remaining > 0.0:
		_tool_cooldown_remaining -= delta

	# Hold-to-attack: while LMB is held (and cooldown allows) keep swinging a
	# melee weapon toward where the player aims. Farming tools stay click-per-
	# use so holding LMB doesn't repeatedly till/water. Bows charge on hold.
	# _swing_gate_timer enforces a minimum interval per swing that survives the
	# creative-mode cooldown zeroing, so holds can't dump damage every frame.
	_swing_gate_timer = maxf(_swing_gate_timer - delta, 0.0)
	if _attack_held and not _bow_charging and _swing_gate_timer <= 0.0 and _can_deal_melee_damage():
		_try_use_tool_at_pos(get_global_mouse_position())

	var input_direction := _get_input_direction()
	input_direction = _clamp_to_walkable(input_direction)
	var snapback_position: Vector2 = global_position
	if input_direction != Vector2.ZERO:
		# Apply biome speed multiplier
		# Apply biome speed multiplier + farmer level speed perk
		var current_speed: float = speed * _get_current_biome_speed_mult() * LevelManager.get_speed_multiplier()
		# Hunger speed penalty: at half hunger, speed is reduced; at zero, slowest.
		var hunger_ratio: float = float(GameManager.hunger) / float(GameManager.MAX_HUNGER)
		if hunger_ratio < 0.5:
			current_speed *= 0.5 + hunger_ratio  # e.g. 25% hunger = 75% speed, 0% = 50%
		velocity = velocity.move_toward(input_direction * current_speed, acceleration * delta)
	else:
		# Friction — gradual deceleration
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	# Attack lunge: for the brief MELEE_LUNGE_TIME after a swing, the player
	# carries an extra burst of speed toward the aim point so melee flows.
	if _lunge_timer > 0.0:
		_lunge_timer = maxf(0.0, _lunge_timer - delta)
		velocity += _lunge_velocity * (_lunge_timer / MELEE_LUNGE_TIME)

	move_and_slide()

	# Movement-based hunger drain — the more you move, the faster you hunger.
	if input_direction != Vector2.ZERO and not GameManager.is_creative():
		_move_hunger_accumulator += delta
		if _move_hunger_accumulator >= MOVE_HUNGER_DRAIN_INTERVAL:
			_move_hunger_accumulator = 0.0
			GameManager.change_hunger(-1)
	else:
		_move_hunger_accumulator = 0.0

	# Cancel eating or mine hold if player moves
	if (_is_eating or _is_mine_interacting or _is_clearing_rubble) and input_direction != Vector2.ZERO:
		if _is_eating:
			_cancel_eating()
		if _is_mine_interacting:
			_cancel_mine_interaction()
		if _is_clearing_rubble:
			_cancel_rubble_clear()
	
	# Cancel revive if player moves
	if _revive_target and input_direction != Vector2.ZERO:
		_cancel_revive()
	
	# Process revive hold (hold E to revive)
	if _revive_target:
		_process_revive(delta)
	
	# Update revive progress UI for downed player
	if _is_downed:
		_update_revive_progress(delta)

	# ── Post-move guard ──
	# On expedition island, snap back if standing on water or edge tile.
	var expedition_guard: Node = _get_expedition_island()
	if expedition_guard and expedition_guard.has_method("is_water_tile"):
		var island_origin: Vector2 = expedition_guard.global_position
		var local_cell: Vector2i = Vector2i(floori((global_position.x - island_origin.x) / 16.0), floori((global_position.y - island_origin.y) / 16.0))
		if expedition_guard.is_water_tile(local_cell.x, local_cell.y):
			global_position = snapback_position

	# Only the dock sprite walkable area (dy=0..5, dx=-8..5) is safe.
	# Tiles outside that area that display water are snapped back.
	# Interior movement is handled by physics collision instead.
	if _world and _ground_layer and not GameManager.inside_interior and not _get_expedition_island():
		var cur_cell: Vector2i = Vector2i(floori(global_position.x / 16.0), floori(global_position.y / 16.0))
		# Dock visible-artwork area is always walkable.
		var in_dock_area: bool = _world.has_method(&"is_cell_in_dock_area") and _world.is_cell_in_dock_area(cur_cell)
		if not in_dock_area:
			# Outside the approved area — snap back if the tile is truly water
			# (source-aware: biome tiles like cherry_grove_3 share water's atlas
			# coords (3,0) in source 1 but are walkable land, so they must not
			# trigger the snap-back).
			if _is_water_cell(_world, cur_cell):
				global_position = snapback_position

	if input_direction != Vector2.ZERO:
		facing_direction = input_direction
		facing_changed.emit(facing_direction)
		_update_interactor_position()
		_update_sprite_facing()
		if sprite.sprite_frames and sprite.animation != "walk":
			sprite.play("walk")
	else:
		if sprite.sprite_frames and sprite.animation != "idle":
			sprite.play("idle")
	
	_update_tool_preview()

	# ── Eating progress ──
	if _is_eating:
		_eat_progress += delta / _eat_duration
		eating_progress.emit(_eat_progress)
		if _eat_progress >= 1.0:
			_finish_eating()
	
	# ── Mine hold interaction progress ──
	if _is_mine_interacting:
		# Check if still near the interactable — cancel if player moved away
		if not can_mine_interact():
			_cancel_mine_interaction()
			return
		_mine_interact_progress += delta / _mine_interact_duration
		mine_interact_progress.emit(_mine_interact_progress)
		if _mine_interact_progress >= 1.0:
			_finish_mine_interaction()

	# ── Rubble clearing hold progress ──
	if _is_clearing_rubble:
		# Check if still near the ruin — cancel if player moved away
		if not can_clear_rubble():
			_cancel_rubble_clear()
			return
		_rubble_clear_progress += delta / _rubble_clear_duration
		rubble_clear_progress.emit(_rubble_clear_progress)
		if _rubble_clear_progress >= 1.0:
			_finish_rubble_clear()

	# ── E key fallback when LineEdit has focus ──
	# When a LineEdit (e.g. creative panel's SearchInput) has focus, the GUI
	# consumes keyboard events and _unhandled_input() never fires. Detect the
	# E key edge directly from Input state as a fallback.
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner is LineEdit or focus_owner is TextEdit:
		var e_pressed: bool = Input.is_key_pressed(KEY_E)
		if e_pressed and not _prev_e_pressed:
			_handle_interact_pressed()
		if not e_pressed and _prev_e_pressed:
			_handle_interact_released()
		_prev_e_pressed = e_pressed

	# Sync position to remote peers if multiplayer is active
	if NetworkManager.is_network_active():
		var is_moving: bool = velocity.length_squared() > 1.0
		rpc("_sync_remote_state", global_position, facing_direction.x, facing_direction.y, sprite.flip_h, is_moving, z_index)

## Prevents the player from moving into non-walkable tiles (e.g. water).
## Checks the tile one step ahead in each axis and zeroes out movement
## toward any blocked tile. This works alongside tile collision to prevent
## the player from visually "walking a little" into water.
## Interior movement is handled by physics collision, not grid checks.
## On expedition islands, checks against the island's local tile grid
## which manages walkability per-cell via ExpeditionIsland.is_water_tile().
func _clamp_to_walkable(direction: Vector2) -> Vector2:
	if direction == Vector2.ZERO or not _world:
		return direction

	# ── Expedition island: use island-local coordinate grid ──
	var expedition: Node = _get_expedition_island()
	if expedition:
		if expedition.has_method("is_water_tile"):
			var island_origin: Vector2 = expedition.global_position
			var cs: float = 16.0

			# Horizontal
			if direction.x != 0.0:
				var next_x: float = global_position.x + direction.x * cs * 0.6
				var cell_x: Vector2i = Vector2i(floori((next_x - island_origin.x) / cs), floori((global_position.y - island_origin.y) / cs))
				if expedition.is_water_tile(cell_x.x, cell_x.y):
					direction.x = 0.0

			# Vertical
			if direction.y != 0.0:
				var next_y: float = global_position.y + direction.y * cs * 0.6
				var cell_y: Vector2i = Vector2i(floori((global_position.x - island_origin.x) / cs), floori((next_y - island_origin.y) / cs))
				if expedition.is_water_tile(cell_y.x, cell_y.y):
					direction.y = 0.0
		return direction

	# Normal interior: skip grid check (physics collision handles it)
	if GameManager.inside_interior:
		return direction

	var world: Node = _world
	var w_pos: Vector2 = global_position
	var cell_size: float = 16.0

	# Try horizontal movement first
	if direction.x != 0.0:
		var next_x: float = w_pos.x + direction.x * cell_size * 0.6
		var cell_x: Vector2i = Vector2i(floori(next_x / cell_size), floori(w_pos.y / cell_size))
		if _is_water_cell(world, cell_x):
			direction.x = 0.0

	# Try vertical movement
	if direction.y != 0.0:
		var next_y: float = w_pos.y + direction.y * cell_size * 0.6
		var cell_y: Vector2i = Vector2i(floori(w_pos.x / cell_size), floori(next_y / cell_size))
		if _is_water_cell(world, cell_y):
			direction.y = 0.0

	return direction

## Returns the expedition island node if the player is currently on one,
## or null otherwise. Used by walkability guards to check island-local tiles.
func _get_expedition_island() -> Node:
	return get_tree().get_first_node_in_group("expedition_island")


## Checks if a given cell position contains a non-walkable tile that should
## block player movement. Only checks source 0 (main terrain tileset);
## biome tiles (source 1+) are always walkable even if their atlas coords
## happen to match non-walkable coords in other sources (e.g. cherry_grove_3
## in source 1 uses atlas (3,0) which overlaps with water's atlas (3,0) in
## source 0 — without checking source_id it would be misidentified as water).
func _is_water_cell(world_node: Node, cell: Vector2i) -> bool:
	# Dock area tiles are walkable ONLY if they're within the dock geometry
	# AND marked as "path" (not water). This prevents stray grid "path" values
	# outside the actual dock sprite / approach area from making water walkable.
	if world_node \
			and world_node.has_method(&"is_cell_in_dock_area") \
			and world_node.is_cell_in_dock_area(cell) \
			and world_node.has_method(&"is_dock_path_tile") \
			and world_node.is_dock_path_tile(cell):
		return false
	
	# Check the authoritative _tile_grid first (catches harbor water where
	# TileMap may show a biome tile over what the grid considers water).
	if world_node and world_node.has_method(&"is_water_tile"):
		if world_node.is_water_tile(cell):
			return true
	
	# Fallback: check the TileMap for water tiles, empty tiles, and terrain blockers.
	var layer: TileMapLayer = _ground_layer if _ground_layer else null
	if not layer:
		return false
	
	var sid: int = layer.get_cell_source_id(cell)
	var atlas: Vector2i = layer.get_cell_atlas_coords(cell)
	
	# Empty cells (no tile) — nothing to block on. Grid-level check above
	# handles _tile_grid water; if we're here, grid says walkable.
	if sid == -1 or atlas == Vector2i(-1, -1):
		return false
	
	# Water (3,0) only blocks from source 0. Biome tiles (source 1+) that
	# happen to display water-coordinate tiles are decorative — they were
	# hand-placed on a land cell and shouldn't block.
	if atlas.x == 3 and atlas.y == 0 and sid == 0:
		return true
	
	# Trees (7,0), rocks (8,0), and edge tiles (13-20, 0) only block if
	# they come from source 0 (the main terrain tileset). Biome tiles
	# (source 1+) at these coords are walkable land tiles.
	if sid != 0:
		return false
	return (atlas.x == 7 or atlas.x == 8) and atlas.y == 0 \
		or (atlas.x >= 13 and atlas.x <= 20 and atlas.y == 0)

func _unhandled_input(event: InputEvent) -> void:
	# Skip input for remote players
	if NetworkManager.is_network_active() and not is_multiplayer_authority():
		return
	# While sitting on a bench, only the interact key (E) works to stand up.
	# Stand up directly instead of going through the general interact system,
	# because a closer interactable (e.g. a tree) could intercept the action
	# and repeatedly show "Need an axe!" instead of letting the player stand.
	if is_sitting:
		if InputMap.has_action("interact") and event.is_action_pressed("interact"):
			# Don't try mine interactions while sitting — just stand up
			is_sitting = false
			sprite.play("idle")
			held_item.visible = true
			_update_held_item()
			ToastNotification.show_toast("You stand up.", ToastNotification.ToastType.INFO, 1.5)
		return

	# Build mode toggle (V key)
	if event.is_action_pressed("open_build_mode"):
		_toggle_build_mode()
		return
	
	# Mouse interaction: left-click uses tool (hold to keep attacking), right-click interacts.
	if event is InputEventMouseButton and not event.is_echo():
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					if _is_build_mode_active():
						_try_build_placement_at_pos(get_global_mouse_position())
					else:
						_attack_held = true
						if _is_active_bow():
							_start_bow_charge()
						else:
							_try_use_tool_at_pos(get_global_mouse_position())
				else:
					_attack_held = false
					if _bow_charging:
						_finish_bow_charge(get_global_mouse_position())
				get_viewport().set_input_as_handled()
				return
			MOUSE_BUTTON_RIGHT:
				if event.pressed:
					_try_interact_at_pos(get_global_mouse_position())
				get_viewport().set_input_as_handled()
				return
	
	if InputMap.has_action("interact"):
		if event.is_action_pressed("interact"):
			_handle_interact_pressed()
			return
		if event.is_action_released("interact"):
			_handle_interact_released()
	if event.is_action_pressed("till") or (event is InputEventKey and event.pressed and event.keycode == KEY_SPACE):
		_try_use_tool()

	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1: _set_tool(Tool.HOE)
			KEY_2: _set_tool(Tool.WATERING_CAN)
			# Keys 3-0 select the 8 freely assignable hotbar slots (inv slots 0-7)
			KEY_3: _set_tool(Tool.HOTBAR_0)
			KEY_4: _set_tool(Tool.HOTBAR_1)
			KEY_5: _set_tool(Tool.HOTBAR_2)
			KEY_6: _set_tool(Tool.HOTBAR_3)
			KEY_7: _set_tool(Tool.HOTBAR_4)
			KEY_8: _set_tool(Tool.HOTBAR_5)
			KEY_9: _set_tool(Tool.HOTBAR_6)
			KEY_0: _set_tool(Tool.HOTBAR_7)
			# R key handled in Main.gd (opens restoration panel for cleared ruins)

## Public setter so external UI (hotbar, etc.) can switch the active tool.
func set_tool(tool: Tool) -> void:
	_set_tool(tool)

## Used by Interactable to check if the player has the right tool equipped.
## Works with both legacy direct-tool values (AXE=9, etc.) and hotbar slots
## that contain the corresponding item.
func has_tool_active(tool_enum_value: int) -> bool:
	if active_tool == tool_enum_value:
		return true
	# If a hotbar slot is active, check whether it contains the matching item
	if active_tool >= Tool.HOTBAR_0 and active_tool <= Tool.HOTBAR_7:
		var slot_idx := _hotbar_tool_to_inv_slot(active_tool)
		var slot_data = InventoryManager.slots[slot_idx] if slot_idx >= 0 and slot_idx < InventoryManager.slots.size() else null
		if slot_data == null:
			return false
		match tool_enum_value:
			Tool.AXE:     return slot_data["item_id"] in ["axe_tool", "copper_axe", "iron_axe", "gold_axe", "diamond_axe", "mythril_axe", "magma_axe"]
			Tool.PICKAXE: return slot_data["item_id"] in ["pickaxe_tool", "copper_pickaxe", "iron_pickaxe", "gold_pickaxe", "diamond_pickaxe", "mythril_pickaxe", "magma_pickaxe"]
			Tool.SWORD:   return slot_data["item_id"] in ["sword_tool", "copper_sword", "iron_sword", "gold_sword", "diamond_sword", "mythril_sword"]
			Tool.SCYTHE:  return slot_data["item_id"] == "scythe_tool"
			Tool.SPRINKLER: return slot_data["item_id"] in ["sprinkler", "quality_sprinkler", "iridium_sprinkler"]
	return false

## Returns the item_id of the currently active hotbar slot, or "" if none.
func get_active_hotbar_item_id() -> String:
	if active_tool >= Tool.HOTBAR_0 and active_tool <= Tool.HOTBAR_7:
		var slot_idx := _hotbar_tool_to_inv_slot(active_tool)
		var slot_data = InventoryManager.slots[slot_idx] if slot_idx >= 0 and slot_idx < InventoryManager.slots.size() else null
		if slot_data:
			return slot_data.get("item_id", "")
	return ""


## Returns the slot data dict (or null) for a hotbar-slot tool value.
## Only meaningful for Tool.HOTBAR_0 through Tool.HOTBAR_7.
func _get_hotbar_slot_data() -> Dictionary:
	var slot_idx := _hotbar_tool_to_inv_slot(active_tool)
	if slot_idx < 0 or slot_idx >= InventoryManager.slots.size():
		return {}
	var sd = InventoryManager.slots[slot_idx]
	return sd if sd is Dictionary else {}

## Maps a Tool.HOTBAR_X enum value to an inventory slot index (0-7).
## The Tool enum has legacy tools between HOTBAR_3 (6) and HOTBAR_4 (12),
## so a simple subtraction doesn't work.
static func _hotbar_tool_to_inv_slot(tool_val: int) -> int:
	match tool_val:
		3: return 0   # HOTBAR_0
		4: return 1   # HOTBAR_1
		5: return 2   # HOTBAR_2
		6: return 3   # HOTBAR_3
		12: return 4  # HOTBAR_4
		13: return 5  # HOTBAR_5
		14: return 6  # HOTBAR_6
		15: return 7  # HOTBAR_7
	return -1

## Returns the count of items in the active hotbar slot (0 if empty or not a hotbar slot).
func _get_hotbar_item_count() -> int:
	var sd := _get_hotbar_slot_data()
	return sd.get("count", 0) if sd else 0

func _set_tool(tool: Tool) -> void:
	if _is_eating:
		_cancel_eating()
	active_tool = tool
	_update_tool_ui()
	_update_tool_preview()
	_update_held_item()
	_update_lantern()

func _update_tool_ui() -> void:
	var tool_name := "None"
	match active_tool:
		Tool.HOE:
			tool_name = "Hoe"
		Tool.WATERING_CAN:
			tool_name = "Watering Can"
		Tool.HOTBAR_0, Tool.HOTBAR_1, Tool.HOTBAR_2, Tool.HOTBAR_3, \
		Tool.HOTBAR_4, Tool.HOTBAR_5, Tool.HOTBAR_6, Tool.HOTBAR_7:
			var sd := _get_hotbar_slot_data()
			if sd.is_empty():
				tool_name = "Empty"
			else:
				var item: ItemData = DataManager.get_item(sd["item_id"])
				tool_name = item.display_name if item else sd["item_id"]
				if sd["count"] > 1:
					tool_name += " (x%d)" % sd["count"]
		Tool.SPRINKLER:
			tool_name = "Sprinkler"
		Tool.SCYTHE:
			tool_name = "Scythe"
		Tool.AXE:
			tool_name = "Axe"
		Tool.PICKAXE:
			tool_name = "Pickaxe"
		Tool.SWORD:
			tool_name = "Sword"
	active_tool_changed.emit(tool_name)

func _warn_no_tool(tool_name: String) -> void:
	EffectSpawner.spawn_floating_text("Craft a %s first!" % tool_name, global_position, Color.YELLOW)


## Use whatever item is in the active hotbar slot at the given world position.
## Returns true if the action was performed.
func _use_hotbar_item(target_pos: Vector2) -> bool:
	var sd := _get_hotbar_slot_data()
	if sd.is_empty():
		return false
	
	var item: ItemData = DataManager.get_item(sd["item_id"])
	if not item:
		return false
	
	var world: Node = _world
	if not world:
		return false
	
	# Seeds — plant the associated crop
	if item.category == "seed":
		# Find the crop that produces this seed
		var crop = _find_crop_by_seed(sd["item_id"])
		if crop and world.has_method("plant_seed"):
			if world.plant_seed(target_pos, crop.id):
				_update_tool_ui()
				return true
		return false
	
	# Tools
	match sd["item_id"]:
		"scythe_tool":
			if world.has_method("scythe_harvest"):
				return world.scythe_harvest(target_pos)
		"sprinkler", "quality_sprinkler", "iridium_sprinkler":
			if world.has_method("place_sprinkler"):
				return world.place_sprinkler(target_pos)
		"hoe":
			if world.has_method("till_tile"):
				return world.till_tile(target_pos)
		"watering_can":
			if world.has_method("water_tile"):
				return world.water_tile(target_pos)
		"sword_tool":
			# Sword triggers melee attack — handled by the caller's fallback
			return false
		"cutlass":
			# Cutlass is a weapon — triggers melee attack fallback
			return false
		"bow", "antler_bow":
			# Bow fires an arrow toward the target position
			_fire_bow(target_pos)
			return true
		"pickaxe_tool", "copper_pickaxe", "iron_pickaxe", "gold_pickaxe", "diamond_pickaxe", "mythril_pickaxe", "magma_pickaxe":
			# Pickaxe mines nearby ore deposits
			_mine_ore_at(target_pos)
			return true
	
	# Compost/fertilizer — apply to tile on left-click
	if sd["item_id"] in ["compost", "quality_compost", "growth_booster", "yield_enhancer", "rich_fertilizer", "super_fertilizer"]:
		if world.has_method("apply_compost"):
			return world.apply_compost(target_pos)
	
	# Spirit Harvest baits — summon a boss nearby
	if sd["item_id"] in ["soulberry_pie", "golden_hay_bale", "nectar_brew", "essence_of_inconstance"]:
		_summon_boss(sd["item_id"])
		return true
	
	# Inconstant Fruit — consume on left-click/Space (consumable category)
	if item.category == "consumable" and item.get_meta("inconstant_power", false):
		_consume_inconstant_fruit(sd["item_id"], item)
		return true
	
	# Food/meal/potion — left-click on an animal to feed it, or hold E to eat it yourself
	if item.category in ["food", "meal", "potion"]:
		# Check if there's an Animal at the click position to feed
		var space_state := get_world_2d().direct_space_state
		var query := PhysicsPointQueryParameters2D.new()
		query.position = target_pos
		query.collision_mask = 4  # Animal's collision_layer
		query.collide_with_areas = true
		var results := space_state.intersect_point(query)
		for r in results:
			var animal := r.collider as Animal
			if animal and animal.feed(sd["item_id"]):
				return true
		return false
	
	return false


## Public helper: returns the item_id of a consumable in the active hotbar
## slot, or "" if none is equipped. Used by HUD and _try_interact() to
## decide whether pressing E will eat instead of interacting.
func get_hotbar_consumable_id() -> String:
	var sd := _get_hotbar_slot_data()
	if sd.is_empty():
		return ""
	var item: ItemData = DataManager.get_item(sd.get("item_id", ""))
	if not item or item.category not in ["food", "meal", "potion"]:
		return ""
	if not InventoryManager.has_item(sd["item_id"], 1):
		return ""
	return sd["item_id"]


## ── Hold-E eating system (Minecraft-style) ──

## Try to start eating whatever food/meal/potion is in the active hotbar slot.
## Returns true if eating has started.
func _try_start_eating() -> bool:
	if _is_eating:
		return true
	# Check if active hotbar slot has food/meal/potion
	var sd := _get_hotbar_slot_data()
	if sd.is_empty():
		return false
	var item: ItemData = DataManager.get_item(sd.get("item_id", ""))
	if not item or item.category not in ["food", "meal", "potion"]:
		return false
	if not InventoryManager.has_item(sd["item_id"], 1):
		return false
	_start_eating(sd["item_id"], item)
	return true


## Begin the eating animation/timer.
func _start_eating(item_id: String, item: ItemData) -> void:
	_is_eating = true
	_eat_progress = 0.0
	_eat_item_id = item_id
	_eat_item = item
	eating_started.emit(item.display_name)


## Cancel eating (player moved, released E, or switched tools).
func _cancel_eating() -> void:
	if not _is_eating:
		return
	_is_eating = false
	_eat_progress = 0.0
	_eat_item_id = ""
	_eat_item = null
	eating_cancelled.emit()


## Eating timer completed — consume the item.
func _finish_eating() -> void:
	if not _is_eating:
		return
	_is_eating = false
	_eat_progress = 0.0
	var item_id := _eat_item_id
	var item := _eat_item
	_eat_item_id = ""
	_eat_item = null
	_consume_hotbar_item(item_id, item)
	eating_completed.emit(item.display_name if item else "")


## Consume a food/meal item from the hotbar, removing it from inventory
## and applying hunger/health effects.
func _consume_hotbar_item(item_id: String, item: ItemData) -> void:
	if not InventoryManager.has_item(item_id, 1):
		return
	
	if item.category == "meal":
		InventoryManager.remove_item(item_id, 1)
		GameManager.change_hunger(35)
		GameManager.heal(15)
		AudioManager.play(AudioManager.Sound.EAT)
		
		var world_node: Node = _world
		if world_node and world_node.has_method("get_cooking_system"):
			var cooking = world_node.get_cooking_system()
			var meal = cooking.get_meal(item_id) if cooking else null
			if meal and meal.buff_type != "none":
				BuffManager.apply_meal_buff(meal)
				var buff_name: String = meal.buff_type.capitalize()
				ToastNotification.show_toast("Ate %s! +%s Buff (%ds)" % [meal.display_name, buff_name, meal.buff_duration], ToastNotification.ToastType.SUCCESS, 2.5)
			else:
				ToastNotification.show_toast("Ate a delicious meal! +35 Hunger, +15 HP", ToastNotification.ToastType.SUCCESS, 2.5)
	elif item.category == "food":
		InventoryManager.remove_item(item_id, 1)
		GameManager.change_hunger(8)
		AudioManager.play(AudioManager.Sound.EAT)
		ToastNotification.show_toast("Ate some %s. +8 Hunger" % item.display_name, ToastNotification.ToastType.SUCCESS, 2.0)
	elif item.category == "potion":
		InventoryManager.remove_item(item_id, 1)
		AudioManager.play(AudioManager.Sound.EAT)
		_apply_potion_effect(item_id, item.display_name)


## Consume an Inconstant Fruit — applies a permanent powerful buff and
## switches Survival mode to Hardcore.
func _consume_inconstant_fruit(item_id: String, item: ItemData) -> void:
	if not InventoryManager.has_item(item_id, 1):
		return
	InventoryManager.remove_item(item_id, 1)

	var result := InconstantFruitSystem.consume_fruit(item_id)
	if result.success:
		var msg: String = result.message
		msg += "\nYour strikes may unleash the Inconstant Soul's power!"
		ToastNotification.show_toast(msg, ToastNotification.ToastType.SUCCESS, 5.0)
		# Big dramatic camera shake
		var cam := get_viewport().get_camera_2d()
		if cam and cam.has_method("shake"):
			cam.shake(5.0, 1.0)
	else:
		ToastNotification.show_toast("The fruit crumbles to ash...", ToastNotification.ToastType.ERROR, 2.0)


## Apply potion effects based on potion type.
## Potions can heal, grant buffs, or restore energy.
func _apply_potion_effect(potion_id: String, potion_name: String) -> void:
	match potion_id:
		"health_tonic":
			GameManager.heal(30)
			ToastNotification.show_toast("Drank %s! +30 HP" % potion_name, ToastNotification.ToastType.SUCCESS, 2.5)
		"health_potion":
			GameManager.heal(60)
			ToastNotification.show_toast("Drank %s! +60 HP" % potion_name, ToastNotification.ToastType.SUCCESS, 2.5)
		"greater_health_potion":
			GameManager.heal(120)
			ToastNotification.show_toast("Drank %s! +120 HP" % potion_name, ToastNotification.ToastType.SUCCESS, 2.5)
		"speed_tonic":
			BuffManager.apply_potion_effect("speed", 0.2, 5.0, potion_name)
			ToastNotification.show_toast("Drank %s! +20%% Speed (5 min)" % potion_name, ToastNotification.ToastType.SUCCESS, 2.5)
		"swift_elixir":
			BuffManager.apply_potion_effect("speed", 0.3, 10.0, potion_name)
			ToastNotification.show_toast("Drank %s! +30%% Speed (10 min)" % potion_name, ToastNotification.ToastType.SUCCESS, 2.5)
		"iron_skin_potion":
			BuffManager.apply_potion_effect("defense", 0.25, 5.0, potion_name)
			ToastNotification.show_toast("Drank %s! +25%% Defense (5 min)" % potion_name, ToastNotification.ToastType.SUCCESS, 2.5)
		"stone_skin_elixir":
			BuffManager.apply_potion_effect("defense", 0.4, 10.0, potion_name)
			ToastNotification.show_toast("Drank %s! +40%% Defense (10 min)" % potion_name, ToastNotification.ToastType.SUCCESS, 2.5)
		"luck_draught":
			BuffManager.apply_potion_effect("luck", 0.3, 5.0, potion_name)
			ToastNotification.show_toast("Drank %s! +30%% Luck (5 min)" % potion_name, ToastNotification.ToastType.SUCCESS, 2.5)
		"elixir_of_vigor":
			GameManager.heal(50)
			BuffManager.apply_potion_effect("speed", 0.2, 5.0, potion_name)
			ToastNotification.show_toast("Drank %s! +50 HP, +20%% Speed (5 min)" % potion_name, ToastNotification.ToastType.SUCCESS, 2.5)
		"mana_infusion":
			GameManager.change_hunger(50)
			ToastNotification.show_toast("Drank %s! +50 Energy" % potion_name, ToastNotification.ToastType.SUCCESS, 2.5)
		# ── Island Potions ──
		"frost_resist_tonic":
			BuffManager.apply_potion_effect("defense", 0.2, 8.0, potion_name)
			ToastNotification.show_toast("Drank %s! +20%% Cold Defense (8 min)" % potion_name, ToastNotification.ToastType.SUCCESS, 2.5)
		"sweet_elixir":
			BuffManager.apply_potion_effect("health", 0.3, 5.0, potion_name)
			ToastNotification.show_toast("Drank %s! Health Regen (5 min)" % potion_name, ToastNotification.ToastType.SUCCESS, 2.5)
		"desert_salve":
			BuffManager.apply_potion_effect("defense", 0.15, 10.0, potion_name)
			GameManager.heal(20)
			ToastNotification.show_toast("Drank %s! +15%% Defense (10 min), +20 HP" % potion_name, ToastNotification.ToastType.SUCCESS, 2.5)
		"magma_burst":
			BuffManager.apply_potion_effect("speed", 0.25, 5.0, potion_name)
			GameManager.heal(10)
			ToastNotification.show_toast("Drank %s! +25%% Speed, +10 HP (5 min)" % potion_name, ToastNotification.ToastType.SUCCESS, 2.5)
		"ethereal_infusion":
			BuffManager.apply_potion_effect("luck", 0.25, 8.0, potion_name)
			ToastNotification.show_toast("Drank %s! +25%% Luck (8 min)" % potion_name, ToastNotification.ToastType.SUCCESS, 2.5)
		"polar_balm":
			BuffManager.apply_potion_effect("energy", 0.4, 10.0, potion_name)
			GameManager.change_hunger(15)
			ToastNotification.show_toast("Drank %s! +40%% Energy Efficiency (10 min), +15 Hunger" % potion_name, ToastNotification.ToastType.SUCCESS, 2.5)
		"cosmic_dust":
			BuffManager.apply_potion_effect("luck", 0.4, 5.0, potion_name)
			BuffManager.apply_potion_effect("speed", 0.15, 3.0, potion_name)
			ToastNotification.show_toast("Drank %s! +40%% Luck, +15%% Speed" % potion_name, ToastNotification.ToastType.SUCCESS, 2.5)
		"flower_extract":
			GameManager.heal(25)
			ToastNotification.show_toast("Drank %s! +25 HP" % potion_name, ToastNotification.ToastType.SUCCESS, 2.5)
		_:
			ToastNotification.show_toast("Drank %s! No effect..." % potion_name, ToastNotification.ToastType.INFO, 2.0)


# ── Downed State / Revive (Multiplayer Co-op) ──────────────────────────────
## Called by GameManager when player enters downed state.
func apply_downed_state() -> void:
	if _is_downed:
		return
	_is_downed = true
	_revive_progress = 0.0
	_revive_target = null
	
	# Visual effects
	modulate = Color(1.0, 1.0, 1.0, 0.6)  # Semi-transparent
	sprite.modulate = Color(1.0, 0.3, 0.3, 1.0)  # Red tint
	
	# Disable movement and actions
	set_physics_process(false)
	velocity = Vector2.ZERO
	
	# Show downed UI
	_show_downed_ui()
	
	# Play downed sound/effect
	AudioManager.play(AudioManager.Sound.HIT)
	EffectSpawner.spawn_particles(global_position, Color(1.0, 0.2, 0.2), 12, 20.0)
	ToastNotification.show_toast("You are downed! Hold E near a teammate to revive.", ToastNotification.ToastType.WARNING, 8.0)

## Called by GameManager when player is revived.
func remove_downed_state() -> void:
	if not _is_downed:
		return
	_is_downed = false
	_revive_progress = 0.0
	_revive_target = null
	
	# Restore visuals
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	
	# Re-enable movement
	set_physics_process(true)
	
	# Hide downed UI
	_hide_downed_ui()
	
	# Revive effect
	EffectSpawner.spawn_particles(global_position, Color(0.2, 1.0, 0.3), 15, 25.0)
	AudioManager.play(AudioManager.Sound.LEVEL_UP)
	ToastNotification.show_toast("You have been revived!", ToastNotification.ToastType.SUCCESS, 4.0)

func _show_downed_ui() -> void:
	# Create a "DOWNED" label above player
	var downed_label := Label.new()
	downed_label.name = "DownedLabel"
	downed_label.text = "DOWNED"
	downed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	downed_label.add_theme_font_size_override("font_size", 14)
	downed_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	downed_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	downed_label.add_theme_constant_override("shadow_offset_x", 2)
	downed_label.add_theme_constant_override("shadow_offset_y", 2)
	downed_label.position = Vector2(0, -60)
	add_child(downed_label)
	
	# Revive progress bar
	var bg := ColorRect.new()
	bg.name = "ReviveProgressBG"
	bg.size = Vector2(80, 6)
	bg.position = Vector2(-40, -42)
	bg.color = Color(0.1, 0.1, 0.1, 0.8)
	add_child(bg)
	
	var fill := ColorRect.new()
	fill.name = "ReviveProgressFill"
	fill.size = Vector2(0, 6)
	fill.position = Vector2(-40, -42)
	fill.color = Color(0.2, 1.0, 0.3, 1.0)
	add_child(fill)

func _hide_downed_ui() -> void:
	var downed_label := get_node_or_null("DownedLabel")
	if downed_label:
		downed_label.queue_free()
	var bg := get_node_or_null("ReviveProgressBG")
	if bg:
		bg.queue_free()
	var fill := get_node_or_null("ReviveProgressFill")
	if fill:
		fill.queue_free()

## Update revive progress when holding E near a downed teammate.
func _update_revive_progress(delta: float) -> void:
	if not _is_downed:
		return
	
	var fill := get_node_or_null("ReviveProgressFill")
	if fill:
		fill.size.x = 80.0 * (_revive_progress / 3.0)

## Try to start reviving a downed teammate (hold E).
func _try_start_revive() -> bool:
	if _is_downed:
		return false
	if not NetworkManager.is_network_active():
		return false
	
	# Find nearest downed player
	var nearest_downed: Player = null
	var nearest_dist: float = 64.0  # max revive range
	
	for peer_id in multiplayer.get_peers():
		if peer_id == multiplayer.get_unique_id():
			continue
		var target = get_tree().get_node_or_null("Player_%d" % peer_id)
		if target and target is Player and target._is_downed:
			var dist := global_position.distance_to(target.global_position)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest_downed = target
	
	if not nearest_downed:
		return false
	
	_revive_target = nearest_downed
	_revive_progress = 0.0
	_revive_target._revive_progress = 0.0
	
	# Show revive UI on both players
	_show_revive_ui(nearest_downed)
	
	ToastNotification.show_toast("Reviving %s..." % nearest_downed.name_label.text, ToastNotification.ToastType.INFO, 1.5)
	return true

func _show_revive_ui(target: Player) -> void:
	# Reviver sees progress bar
	var bg := ColorRect.new()
	bg.name = "ReviveUI_BG"
	bg.size = Vector2(120, 8)
	bg.position = Vector2(-60, -80)
	bg.color = Color(0.1, 0.1, 0.1, 0.8)
	add_child(bg)
	
	var fill := ColorRect.new()
	fill.name = "ReviveUI_Fill"
	fill.size = Vector2(0, 8)
	fill.position = Vector2(-60, -80)
	fill.color = Color(0.2, 1.0, 0.3, 1.0)
	add_child(fill)
	
	var label := Label.new()
	label.name = "ReviveUI_Label"
	label.text = "Reviving %s..." % target.name_label.text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(0.8, 1.0, 0.8))
	label.position = Vector2(0, -95)
	add_child(label)

func _hide_revive_ui() -> void:
	var bg := get_node_or_null("ReviveUI_BG")
	if bg:
		bg.queue_free()
	var fill := get_node_or_null("ReviveUI_Fill")
	if fill:
		fill.queue_free()
	var label := get_node_or_null("ReviveUI_Label")
	if label:
		label.queue_free()

## Called each frame while holding E to revive.
func _process_revive(delta: float) -> void:
	if not _revive_target or not is_instance_valid(_revive_target):
		_cancel_revive()
		return
	
	# Check distance
	if global_position.distance_to(_revive_target.global_position) > 64.0:
		_cancel_revive()
		ToastNotification.show_toast("Too far to revive!", ToastNotification.ToastType.WARNING, 2.0)
		return
	
	_revive_progress += delta
	_revive_target._revive_progress = _revive_progress
	
	# Update progress bars
	var fill := get_node_or_null("ReviveUI_Fill")
	if fill:
		fill.size.x = 120.0 * (_revive_progress / 3.0)
	var target_fill := _revive_target.get_node_or_null("ReviveProgressFill")
	if target_fill:
		target_fill.size.x = 80.0 * (_revive_progress / 3.0)
	
	if _revive_progress >= 3.0:
		# Revive complete!
		var reviver_name := name_label.text
		rpc_id(_revive_target.get_multiplayer_authority(), "_request_revive_rpc", reviver_name)
		_cancel_revive()

func _cancel_revive() -> void:
	if _revive_target and is_instance_valid(_revive_target):
		_revive_target._revive_progress = 0.0
		_revive_target._hide_downed_ui()
		_revive_target._show_downed_ui()
		_revive_target = null
	_hide_revive_ui()
	_revive_progress = 0.0

@rpc("authority", "reliable")
func _request_revive_rpc(reviver_name: String) -> void:
	if not _is_downed:
		return
	# Only the host should process this, but we're using authority
	if multiplayer.is_server() or multiplayer.get_remote_sender_id() == get_multiplayer_authority():
		GameManager.revive_player(reviver_name)


# ── Boss Summoning ──
## The boss spawns near the player and attacks immediately.
func _summon_boss(bait_item_id: String) -> void:
	var world: Node = _world
	if not world:
		return
	
	# Determine which boss to summon
	var boss_scene: PackedScene
	var boss_name: String
	match bait_item_id:
		"soulberry_pie":
			boss_scene = BOSS_ROOT_WARDEN
			boss_name = "Root Warden"
		"golden_hay_bale":
			boss_scene = BOSS_HOLLOW_STAG
			boss_name = "Hollow Stag"
		"nectar_brew":
			boss_scene = BOSS_BLOOMING_WYRM
			boss_name = "Blooming Wyrm"
		"essence_of_inconstance":
			boss_scene = BOSS_INCONSTANT_SOUL
			boss_name = "Inconstant Soul"
		_:
			return
	
	# Remove the bait from inventory
	InventoryManager.remove_item(bait_item_id, 1)
	
	# Prevent multiple boss summons — check if any boss is already alive
	var existing_bosses := get_tree().get_nodes_in_group("bosses")
	for eb in existing_bosses:
		if is_instance_valid(eb):
			ToastNotification.show_toast("A boss is already active! Defeat it first.", ToastNotification.ToastType.WARNING, 2.5)
			return
	
	# Spawn the boss at a random position near the player
	var angle := randf_range(0.0, TAU)
	var dist := randf_range(60.0, 100.0)
	var spawn_pos := global_position + Vector2(cos(angle), sin(angle)) * dist
	
	var boss: Enemy = boss_scene.instantiate()
	boss.global_position = spawn_pos
	world.add_child(boss)
	# Apply difficulty scaling synchronously (the _ready() deferred call no-ops
	# via the _stats_scaled guard) so the boss fight starts at final stats.
	boss.apply_difficulty_scaling()
	
	# Dramatic summoning effects (delegates to boss-specific visuals)
	boss._summon_spawn_effect()
	
	ToastNotification.show_toast("The %s has been summoned!" % boss_name, ToastNotification.ToastType.WARNING, 3.0)


## Searches all crops for one whose seed_item_id matches the given item.
func _find_crop_by_seed(seed_item_id: String) -> Variant:
	# Check procedural crops first (fast path)
	var proc_crops: Array[CropData] = DataManager.get_procedural_crops()
	for c: CropData in proc_crops:
		if c.seed_item_id == seed_item_id:
			return c
	# Check discovered crops (includes non-procedural ones)
	for c_id: String in DataManager.get_discovered_crop_ids():
		var c: CropData = DataManager.get_crop(c_id)
		if c and c.seed_item_id == seed_item_id:
			return c
	# Full scan of ALL registered crops
	for val in DataManager.crops.values():
		if val is CropData:
			var c: CropData = val as CropData
			if c.seed_item_id == seed_item_id:
				return c
	return null

## Queries the World's biome system for the movement speed multiplier
## at the player's current position, so biomes like swamps slow the player
## and plains are neutral. Also applies any speed buff from meals.
func _get_current_biome_speed_mult() -> float:
	var world: Node = _world
	var biome_mult: float = 1.0
	if world and world.has_method("get_biome_at_pos"):
		var biome = world.get_biome_at_pos(global_position)
		biome_mult = biome.movement_speed_multiplier if biome else 1.0
	
	# Apply speed buff from meals (additive, stacks with biome multiplier)
	var speed_buff: float = BuffManager.get_strength("speed") if BuffManager else 0.0
	# Pet speed bonus (gingerbread man) — additive on top of biome + meal buffs
	var pet_speed: float = PetManager.get_speed_bonus() if Engine.has_singleton("PetManager") else 0.0
	return biome_mult + speed_buff + pet_speed


func _get_input_direction() -> Vector2:
	var dir := Vector2.ZERO
	dir.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	dir.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	if dir == Vector2.ZERO:
		return dir
	return dir.normalized()

func _update_interactor_position() -> void:
	if interactor:
		interactor.position = facing_direction * 14.0

## Try to interact with nearest interactable, harvest, or compost.
## Returns true if any action was performed.
func _try_interact() -> bool:
	# Fishing integration: if holding fishing rod, start/continue fishing
	var sd2 := _get_hotbar_slot_data()
	var held_item_id: String = sd2.get("item_id", "") if not sd2.is_empty() else ""
	if held_item_id == "fishing_rod":
		if _try_fishing():
			return true
	
	# ── Context-aware interaction priority ──
	# Before committing to an interaction, peek at the nearest interactable's
	# tool requirement. If the player doesn't have the required tool (e.g.
	# near a tree without an axe) BUT does have food in the hotbar, skip the
	# interactable so E falls through to eating instead.
	if interactor and interactor.has_method("get_nearest_interactable"):
		var nearest: Interactable = interactor.get_nearest_interactable()
		if nearest and nearest is Interactable:
			if nearest.required_tool >= 0 \
					and not has_tool_active(nearest.required_tool) \
					and get_hotbar_consumable_id() != "":
				# Player has food and can't use this interactable — eat instead
				return false
	
	if interactor and interactor.has_method("interact_with_nearest"):
		var interacted: bool = interactor.interact_with_nearest()
		if interacted:
			return true
		var world: Node = _world
		if not world:
			return false
		var target_pos: Vector2 = global_position + facing_direction * 16.0
		
		# Check for ruin structure interaction (clear rubble, visit NPC)
		var ruin := _get_nearby_ruin()
		if ruin and ruin.has_method("on_interact"):
			ruin.on_interact()
			return true
		
		# Check for nearby NPCs to open quest dialogue
		if _try_npc_interaction():
			return true
		
		# If holding compost (tool is any seed slot with compost in inventory),
		# try compost on the tile first
		if InventoryManager.has_item("compost", 1):
			if world.has_method("apply_compost") and world.apply_compost(target_pos):
				return true
		
		# Otherwise try to harvest
		if world.has_method("harvest_crop") and world.harvest_crop(target_pos):
			return true
	return false

## Check if any nearby town resident NPC can start quest dialogue.
## Returns true if NPC dialogue was opened.
func _try_npc_interaction() -> bool:
	# Check town residents first
	var residents := get_tree().get_nodes_in_group("town_residents")
	var nearest_resident: TownResidentNPC = null
	var nearest_dist_sq: float = INF
	var player_pos: Vector2 = global_position
	
	for r in residents:
		if not is_instance_valid(r):
			continue
		var resident := r as TownResidentNPC
		if not resident or not resident._player_in_range:
			continue
		var dist_sq: float = player_pos.distance_squared_to(resident.global_position)
		if dist_sq < nearest_dist_sq:
			nearest_dist_sq = dist_sq
			nearest_resident = resident
	
	if nearest_resident:
		nearest_resident.open_quest_dialogue()
		return true
	
	# Also check visitor NPCs
	var visitors := get_tree().get_nodes_in_group("visitor_npcs")
	var nearest_visitor: Node = null
	nearest_dist_sq = INF
	
	for v in visitors:
		if not is_instance_valid(v):
			continue
		var visitor := v as Node
		if not visitor.has_method("show_dialogue"):
			continue
		# Check if the visitor is close enough (within ~32 pixels)
		var dist_sq: float = player_pos.distance_squared_to(visitor.global_position)
		if dist_sq < 32.0 * 32.0 and dist_sq < nearest_dist_sq:
			nearest_dist_sq = dist_sq
			nearest_visitor = visitor
	
	if nearest_visitor:
		# Visitors get a recruitment dialog (with greeting + invite option)
		if nearest_visitor.has_method("open_recruitment_dialog"):
			nearest_visitor.open_recruitment_dialog()
		return true
	
	return false


## Check if the player is near a mine interactable (entrance/exit/descent)
## and start the hold-to-interact progress.
## Returns true if a hold interaction was started.
func _try_start_mine_hold_interaction() -> bool:
	if _is_mine_interacting or _is_eating:
		return false
	
	var world: Node = _world
	if not world:
		return false
	
	if GameManager.inside_interior:
		# Inside a mine room — check exit ladder or descent shaft
		if world.has_method("get_current_mine_room"):
			var mine_room: Node = world.get_current_mine_room()
			if mine_room and is_instance_valid(mine_room):
				# Check exit ladder first
				if mine_room.has_method("can_exit") and mine_room.can_exit():
					_start_mine_hold_interaction("Exiting mine...")
					return true
				# Then check descent shaft
				if mine_room.has_method("can_descend") and mine_room.can_descend():
					_start_mine_hold_interaction("Descending deeper...")
					return true
	else:
		# In the overworld — check mine entrance proximity
		if world.has_method("can_enter_mine") and world.can_enter_mine():
			_start_mine_hold_interaction("Entering mine...")
			return true
	
	return false

## Start the hold-to-interact progress for mine actions.
func _start_mine_hold_interaction(prompt_text: String) -> void:
	_is_mine_interacting = true
	_mine_interact_progress = 0.0
	_mine_interact_prompt = prompt_text
	mine_interact_started.emit(prompt_text)

## Cancel the hold-to-interact progress.
func _cancel_mine_interaction() -> void:
	if not _is_mine_interacting:
		return
	_is_mine_interacting = false
	_mine_interact_progress = 0.0
	_mine_interact_prompt = ""
	mine_interact_cancelled.emit()

## Hold timer completed — execute the mine action.
func _finish_mine_interaction() -> void:
	if not _is_mine_interacting:
		return
	_is_mine_interacting = false
	_mine_interact_progress = 0.0
	_mine_interact_prompt = ""
	
	var world: Node = _world
	if not world:
		mine_interact_cancelled.emit()
		return
	
	var did_action := false
	
	if GameManager.inside_interior:
		if world.has_method("get_current_mine_room"):
			var mine_room: Node = world.get_current_mine_room()
			if mine_room and is_instance_valid(mine_room):
				if mine_room.has_method("try_exit") and mine_room.try_exit():
					did_action = true
				elif mine_room.has_method("try_descend") and mine_room.try_descend():
					did_action = true
	else:
		if world.has_method("try_enter_mine") and world.try_enter_mine():
			did_action = true
	
	if did_action:
		mine_interact_completed.emit()
	else:
		mine_interact_cancelled.emit()

## Instant check whether a mine interaction is possible (for UI prompts).
func can_mine_interact() -> bool:
	var world: Node = _world
	if not world:
		return false
	
	if GameManager.inside_interior:
		if world.has_method("get_current_mine_room"):
			var mine_room: Node = world.get_current_mine_room()
			if mine_room and is_instance_valid(mine_room):
				if mine_room.has_method("can_exit") and mine_room.can_exit():
					return true
				if mine_room.has_method("can_descend") and mine_room.can_descend():
					return true
	else:
		if world.has_method("can_enter_mine") and world.can_enter_mine():
			return true
	
	return false

## Returns the prompt text to show at the bottom of the screen
## when the player is near a mine interactable (entrance/exit/descent).
## Used by HUD to display "[E] <prompt>" in the interaction prompt bar.
func get_mine_interact_prompt() -> String:
	var world: Node = _world
	if not world:
		return ""
	
	if GameManager.inside_interior:
		if world.has_method("get_current_mine_room"):
			var mine_room: Node = world.get_current_mine_room()
			if mine_room and is_instance_valid(mine_room):
				if mine_room.has_method("can_exit") and mine_room.can_exit():
					return "Exit Mine"
				if mine_room.has_method("can_descend") and mine_room.can_descend():
					return "Descend Deeper"
	else:
		if world.has_method("can_enter_mine") and world.can_enter_mine():
			return "Enter Mine"
	
	return ""


var _hint_fishing_shown: bool = false

## Try to fish using the fishing rod. Returns true if fishing action was taken.
func _try_fishing() -> bool:
	# Can't fish inside a mine
	if _world and _world.has_method("get_current_mine_room") and _world.get_current_mine_room() != null:
		ToastNotification.show_toast("No fish in the dark depths!", ToastNotification.ToastType.WARNING, 1.5)
		return false
	
	if not GameManager.weather_system:
		return false
	var fishing_system: FishingSystem = GameManager.weather_system.get_node_or_null("FishingSystem")
	if not fishing_system:
		fishing_system = FishingSystem.new()
		fishing_system.name = "FishingSystem"
		GameManager.weather_system.add_child(fishing_system)
	
	match fishing_system.state:
		FishingSystem.FishingState.REELING:
			fishing_system.try_reel()
			return true
		FishingSystem.FishingState.IDLE:
			if fishing_system.start_fishing(self):
				if not _hint_fishing_shown:
					_hint_fishing_shown = true
					var hud := get_tree().get_first_node_in_group("hud")
					if hud and hud.has_method("show_fishing_hint"):
						hud.show_fishing_hint()
				return true
		FishingSystem.FishingState.WAITING, FishingSystem.FishingState.CASTING:
			fishing_system.cancel_fishing()
			return true
	return false

# ── Edge-detected E key helpers ──────────────────────────────────────
# Called by the LineEdit-focus fallback in _physics_process when the GUI
# consumes E key events. Mirrors the logic in _unhandled_input.

func _handle_interact_pressed() -> void:
	if is_sitting:
		is_sitting = false
		sprite.play("idle")
		held_item.visible = true
		_update_held_item()
		ToastNotification.show_toast("You stand up.", ToastNotification.ToastType.INFO, 1.5)
		return
	
	# Downed state: if we're downed, we can't do anything
	if _is_downed:
		return
	
	# Revive teammate: hold E near downed player (multiplayer only)
	if NetworkManager.is_network_active() and _try_start_revive():
		return
	
	if _is_build_mode_active():
		_try_build_placement()
		return
	if _try_start_mine_hold_interaction():
		return
	if _try_start_rubble_clear():
		return
	if _try_interact():
		return
	_try_start_eating()

func _handle_interact_released() -> void:
	if _is_eating:
		_cancel_eating()
	if _is_mine_interacting:
		_cancel_mine_interaction()
	if _is_clearing_rubble:
		_cancel_rubble_clear()
	if _revive_target:
		_cancel_revive()

# ── Rubble clearing hold-to-interact ─────────────────────────────────

## Check if near a ruin in RUBBLE state and start the hold-to-interact.
func _try_start_rubble_clear() -> bool:
	if _is_clearing_rubble or _is_eating or _is_mine_interacting:
		return false
	var ruin := _get_nearby_ruin()
	if not ruin:
		return false
	var town_manager: TownManager = get_tree().get_first_node_in_group("town_manager")
	if not town_manager:
		return false
	var status: int = town_manager.get_ruin_status(ruin.ruin_id)
	if status != TownManager.RuinStatus.RUBBLE:
		return false
	# Check ruin is still valid
	if not is_instance_valid(ruin):
		return false
	_start_rubble_clear(ruin)
	return true

func _start_rubble_clear(ruin: RuinStructure) -> void:
	_is_clearing_rubble = true
	_rubble_clear_progress = 0.0
	_rubble_clear_prompt = "Clearing rubble..."
	_rubble_ruin_ref = ruin
	rubble_clear_started.emit(_rubble_clear_prompt)

func _cancel_rubble_clear() -> void:
	if not _is_clearing_rubble:
		return
	_is_clearing_rubble = false
	_rubble_clear_progress = 0.0
	_rubble_clear_prompt = ""
	_rubble_ruin_ref = null
	rubble_clear_cancelled.emit()

func _finish_rubble_clear() -> void:
	if not _is_clearing_rubble:
		return
	_is_clearing_rubble = false
	_rubble_clear_progress = 0.0
	_rubble_clear_prompt = ""
	var ruin := _rubble_ruin_ref
	_rubble_ruin_ref = null
	if ruin and is_instance_valid(ruin) and ruin.has_method("_clear_rubble"):
		ruin._clear_rubble()
	rubble_clear_completed.emit()

## Check if the player is still near the rubble they were clearing.
func can_clear_rubble() -> bool:
	if not _rubble_ruin_ref or not is_instance_valid(_rubble_ruin_ref):
		return false
	var dist := global_position.distance_squared_to(_rubble_ruin_ref.global_position)
	return dist < 80.0 * 80.0  # ~5 tiles radius — user requested tighter proximity

## Find the nearest ruin structure near the player.
func _get_nearby_ruin() -> RuinStructure:
	var ruins := get_tree().get_nodes_in_group("ruin_structures")
	var nearest: RuinStructure = null
	var nearest_dist: float = 64.0  # ~4 tiles — tighter proximity for rubble clearance
	for r in ruins:
		var ruin := r as RuinStructure
		if not ruin:
			continue
		var dist := global_position.distance_squared_to(ruin.global_position)
		if dist < nearest_dist * nearest_dist:
			nearest_dist = sqrt(dist)
			nearest = ruin
	return nearest

## Toggles build mode on/off via the World's building system.
func _toggle_build_mode() -> void:
	var world: Node = _world
	if world and world.has_method("toggle_build_mode"):
		world.toggle_build_mode()

## Returns true if build mode is currently active.
func _is_build_mode_active() -> bool:
	var world: Node = _world
	if world and world.has_method("get_build_mode_state"):
		return world.get_build_mode_state()
	return false

## Places the current building at the tile in front of the player.
func _try_build_placement() -> void:
	var world: Node = _world
	if not world or not world.has_method("try_place_building"):
		return
	var target_pos: Vector2 = global_position + facing_direction * 16.0
	if world.has_method("world_to_cell"):
		var cell: Vector2i = world.world_to_cell(target_pos)
		world.try_place_building(cell)

## Updates the blue pulsing tile preview based on the player's current tool
## and facing direction. Shows multi-cell area for hoe/watering can,
## single cell for seeds (only if seeds are actually available).
## and facing direction. Shows multi-cell area for hoe/watering can,
## single cell for seeds (only if seeds are actually available).
func _update_tool_preview() -> void:
	var world: Node = _world
	if not world:
		return
	
	# If build mode is active, highlight the target cell instead of tool preview
	if _is_build_mode_active():
		var build_target_pos: Vector2 = global_position + facing_direction * 16.0
		if world.has_method("show_single_cell_preview"):
			world.show_single_cell_preview(build_target_pos)
		return
	
	var target_pos: Vector2 = global_position + facing_direction * 16.0
	
	match active_tool:
		Tool.HOE, Tool.WATERING_CAN, Tool.SCYTHE:
			if world.has_method("show_tool_preview"):
				world.show_tool_preview(target_pos)
		Tool.SPRINKLER:
			if world.has_method("show_single_cell_preview"):
				world.show_single_cell_preview(target_pos)
		Tool.SWORD:
			if world.has_method("clear_tool_preview"):
				world.clear_tool_preview()
		Tool.HOTBAR_0, Tool.HOTBAR_1, Tool.HOTBAR_2, Tool.HOTBAR_3, \
		Tool.HOTBAR_4, Tool.HOTBAR_5, Tool.HOTBAR_6, Tool.HOTBAR_7:
			var sd := _get_hotbar_slot_data()
			if sd.is_empty():
				if world.has_method("clear_tool_preview"):
					world.clear_tool_preview()
			else:
				var item: ItemData = DataManager.get_item(sd["item_id"])
				if item and item.category == "seed":
					# Seeds now use tool area for mass planting — show multi-cell preview
					if world.has_method("show_tool_preview"):
						world.show_tool_preview(target_pos)
				elif sd["item_id"] in ["sprinkler", "quality_sprinkler", "iridium_sprinkler"]:
					if world.has_method("show_single_cell_preview"):
						world.show_single_cell_preview(target_pos)
				elif sd["item_id"] == "scythe_tool":
					if world.has_method("show_tool_preview"):
						world.show_tool_preview(target_pos)
				elif sd["item_id"] == "sword_tool":
					if world.has_method("clear_tool_preview"):
						world.clear_tool_preview()
				else:
					if world.has_method("clear_tool_preview"):
						world.clear_tool_preview()
		_:
			if world.has_method("clear_tool_preview"):
				world.clear_tool_preview()

func _try_use_tool() -> void:
	if _tool_cooldown_remaining > 0.0:
		return

	var world: Node = _world
	if not world:
		return

	var target_pos: Vector2 = global_position + facing_direction * 16.0
	var used := false

	match active_tool:
		Tool.HOE:
			if world.has_method("till_tile"):
				used = world.till_tile(target_pos)
		Tool.WATERING_CAN:
			if world.has_method("water_tile"):
				used = world.water_tile(target_pos)
		Tool.SPRINKLER:
			if world.has_method("place_sprinkler"):
				used = world.place_sprinkler(target_pos)
		Tool.SCYTHE:
			if world.has_method("scythe_harvest"):
				used = world.scythe_harvest(target_pos)
		Tool.HOTBAR_0, Tool.HOTBAR_1, Tool.HOTBAR_2, Tool.HOTBAR_3, \
		Tool.HOTBAR_4, Tool.HOTBAR_5, Tool.HOTBAR_6, Tool.HOTBAR_7:
			used = _use_hotbar_item(target_pos)
		# SWORD & legacy direct-tools fall through to melee attack below.
		# already calls _play_tool_swing() and sets its own cooldown.

	if used:
		_play_tool_swing()
		_tool_cooldown_remaining = base_tool_cooldown * UpgradeManager.get_farming_speed_multiplier()
	else:
		# If tool use didn't do anything, try melee attack
		_try_melee_attack()


## Auto-plant seeds from inventory on a tile. Returns true if planted.
## Called when using the Hoe on already-tilled soil — skips hotbar juggling.
func _try_auto_plant_seed(target_pos: Vector2) -> bool:
	var world: Node = _world
	if not world or not world.has_method("_find_seed_to_plant"):
		return false
	var seed_info: Array = world._find_seed_to_plant()
	if seed_info.is_empty() or seed_info.size() < 2:
		return false
	var crop_id: String = seed_info[0]
	if world.has_method("plant_seed"):
		if world.plant_seed(target_pos, crop_id):
			_update_tool_ui()
			return true
	return false


## Returns the melee damage for the currently active tool,
## including the TOOLS upgrade bonus (+5 per level).
func _get_melee_damage() -> int:
	var upgrade_bonus: int = UpgradeManager.get_level(UpgradeManager.Upgrade.TOOLS) * 5
	# Combat Training upgrade adds +3 melee damage per level.
	upgrade_bonus += UpgradeManager.get_level(UpgradeManager.Upgrade.COMBAT) * 3
	var level_mult: float = LevelManager.get_damage_multiplier()
	var pet_bonus: float = 0.0
	if Engine.has_singleton("PetManager"):
		var pet_mgr: Node = Engine.get_singleton("PetManager")
		if pet_mgr and pet_mgr.has_method("get_combat_bonus"):
			pet_bonus = pet_mgr.get_combat_bonus()
	
	# Direct tool enum lookup
	var base: int = TOOL_BASE_DAMAGE.get(active_tool, -1)
	if base >= 0:
		return roundi((base + upgrade_bonus + pet_bonus) * level_mult)
	
	# Hotbar weapon items (sword_tool, cutlass, axe_tool, pickaxe_tool + tiers)
	var hotbar_damage: Dictionary = {
		"sword_tool": 25, "copper_sword": 28, "iron_sword": 32,
		"gold_sword": 38, "diamond_sword": 45, "mythril_sword": 55,
		"cutlass": 18,
		"axe_tool": 18, "copper_axe": 21, "iron_axe": 25,
		"gold_axe": 29, "diamond_axe": 33, "mythril_axe": 38, "magma_axe": 42,
		"pickaxe_tool": 15,
		"copper_pickaxe": 18, "iron_pickaxe": 22,
		"gold_pickaxe": 26, "diamond_pickaxe": 30,
		"mythril_pickaxe": 35,
		"magma_pickaxe": 40,
	}
	var sd := _get_hotbar_slot_data()
	if not sd.is_empty():
		var item_id: String = sd.get("item_id", "")
		base = hotbar_damage.get(item_id, 15)
		return roundi((base + upgrade_bonus + pet_bonus) * level_mult)
	
	return roundi((15 + upgrade_bonus + pet_bonus) * level_mult)


## Returns true if the active tool can deal melee damage (sword, axe, pickaxe, cutlass).
## Also checks hotbar items so weapon items (sword_tool, cutlass, axe_tool, pickaxe_tool)
## in hotbar slots work as melee weapons.
func _can_deal_melee_damage() -> bool:
	if active_tool in [Tool.SWORD, Tool.AXE, Tool.PICKAXE]:
		return true
	# Check hotbar slots for weapon items
	if active_tool >= Tool.HOTBAR_0 and active_tool <= Tool.HOTBAR_7:
		var sd := _get_hotbar_slot_data()
		if sd.is_empty():
			return false
		var item_id: String = sd.get("item_id", "")
		return item_id in ["axe_tool", "copper_axe", "iron_axe", "gold_axe", "diamond_axe", "mythril_axe", "magma_axe", "pickaxe_tool", "copper_pickaxe", "iron_pickaxe", "gold_pickaxe", "diamond_pickaxe", "mythril_pickaxe", "magma_pickaxe", "sword_tool", "copper_sword", "iron_sword", "gold_sword", "diamond_sword", "mythril_sword", "cutlass"]
	return false


## Roll for a critical hit based on the active tool's crit chance.
## Also checks hotbar weapon items so cutlass/sword_tool in hotbar get proper crit rates.
func _roll_crit(tool: Tool) -> bool:
	var chance: float = CRIT_CHANCE.get(tool, 0.02)
	if chance > 0.0:
		return randf() < chance
	# Hotbar weapon items get their crit from the hotbar content
	if tool >= Tool.HOTBAR_0 and tool <= Tool.HOTBAR_7:
		var sd := _get_hotbar_slot_data()
		if sd.is_empty():
			return randf() < 0.02
		var hotbar_crit: Dictionary = {
			"sword_tool": 0.08, "copper_sword": 0.09, "iron_sword": 0.10,
			"gold_sword": 0.12, "diamond_sword": 0.14, "mythril_sword": 0.18,
			"cutlass": 0.06,
			"axe_tool": 0.05, "copper_axe": 0.06, "iron_axe": 0.07,
			"gold_axe": 0.08, "diamond_axe": 0.09, "mythril_axe": 0.10, "magma_axe": 0.12,
			"pickaxe_tool": 0.03,
			"copper_pickaxe": 0.04, "iron_pickaxe": 0.05,
			"gold_pickaxe": 0.06, "diamond_pickaxe": 0.07,
			"mythril_pickaxe": 0.08,
			"magma_pickaxe": 0.10,
		}
		chance = hotbar_crit.get(sd.get("item_id", ""), 0.02)
	return randf() < chance


## Check and emit combo notification if the streak threshold is met.
func _check_combo(combo_type: String) -> void:
	var now: float = Time.get_unix_time_from_system()
	if now - _last_combo_time > COMBO_TIMEOUT:
		# Reset combo if too much time passed
		if combo_type == "kill":
			_kill_combo = 0
		elif combo_type == "mine":
			_mine_combo = 0
	
	var streak: int = 1
	match combo_type:
		"kill":
			streak = _kill_combo
		"mine":
			streak = _mine_combo
	
	if streak >= 2:
		EffectSpawner.spawn_combo_notification(streak, global_position + Vector2(0, -28))


## Helper: returns the player's current facing as a normalized Vector2.
func _facing_vec() -> Vector2:
	return facing_direction.normalized()


## Helper: starts an attack lunge toward the aim direction.
func _apply_melee_lunge(aim: Vector2) -> void:
	if GameManager.is_creative():
		return
	if aim.length_squared() < 0.001:
		return
	_lunge_velocity = aim.normalized() * MELEE_LUNGE_SPEED
	_lunge_timer = MELEE_LUNGE_TIME


## Shared melee sweep. Hits enemies/animals within MELEE_RANGE of the player
## and inside the forward arc (dot towards aim >= MELEE_ARC_COS). Returns the
## array of damaged enemies. Reads/writes _last_swing_crit.
func _do_melee_swing(aim: Vector2) -> Array[Node2D]:
	var hit_enemies: Array[Node2D] = []
	if aim.length_squared() < 0.001:
		return hit_enemies
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	var animals: Array[Node] = get_tree().get_nodes_in_group("animals")
	var base_damage: int = _get_melee_damage()
	var is_crit: bool = _roll_crit(active_tool)
	_last_swing_crit = is_crit
	var final_damage: int = roundi(base_damage * (CRIT_MULTIPLIER if is_crit else 1.0))

	for e in enemies:
		if hit_enemies.size() >= MAX_MELEE_HITS_PER_SWING:
			break
		if not is_instance_valid(e) or not e.has_method(&"take_damage"):
			continue
		var to_e: Vector2 = (e.global_position - global_position) 
		if to_e.length() > MELEE_RANGE:
			continue
		# Enemies basically on top of the player always get hit; otherwise the
		# swing only lands on enemies in the forward arc.
		if to_e.length() > 14.0 and to_e.normalized().dot(aim) < MELEE_ARC_COS:
			continue
		e.take_damage(final_damage, self, is_crit)
		hit_enemies.append(e)
		LevelManager.add_xp_source("hit_enemy")
		# Knockback (stronger on crit) — capped to prevent runaway physics
		var knock_str: float = 180.0 if is_crit else 120.0
		var knock_dir: Vector2 = _enemy_knockback_dir(e.global_position, global_position)
		if e is CharacterBody2D:
			var eb: CharacterBody2D = e as CharacterBody2D
			if eb.velocity.length() < knock_str * 1.5:
				eb.velocity = knock_dir * knock_str
			else:
				eb.velocity += knock_dir * knock_str * 0.5

	for a in animals:
		if not is_instance_valid(a) or not a is Animal:
			continue
		var animal_ref: Animal = a as Animal
		if not animal_ref:
			continue
		var to_a: Vector2 = animal_ref.global_position - global_position
		if to_a.length() > MELEE_RANGE:
			continue
		if to_a.length() > 14.0 and to_a.normalized().dot(aim) < MELEE_ARC_COS:
			continue
		animal_ref.take_damage(final_damage)

	return hit_enemies


## Sweeps an arc in front of the player and damages any enemies or animals found.
func _try_melee_attack() -> void:
	if not _can_deal_melee_damage():
		return
	# Gingerbread invincibility: can't deal damage
	if GameManager.is_gingerbread_invincible():
		return
	var hit_enemies := _do_melee_swing(_facing_vec())
	_play_tool_swing()
	_tool_cooldown_remaining = base_tool_cooldown * 0.8
	_swing_gate_timer = MELEE_MIN_SWING_INTERVAL
	_apply_melee_lunge(facing_direction)
	if hit_enemies.is_empty():
		return
	AudioManager.play(AudioManager.Sound.HIT)
	# Combat polish: hitstop and swing arc
	_trigger_hitstop(0.1 if _last_swing_crit else 0.06)
	_spawn_swing_arc(_last_swing_crit)
	# Chance to unleash a boss attack on a random hit enemy
	_try_soul_power_proc(hit_enemies[randi() % hit_enemies.size()])


## Use the active tool at a specific world position (mouse click).
func _try_use_tool_at_pos(target_pos: Vector2) -> void:
	if _tool_cooldown_remaining > 0.0:
		return

	var world: Node = _world
	if not world:
		return

	var used := false

	# Click-to-harvest: if the cursor is on a fully-grown crop, harvest it
	# directly instead of using the equipped tool. No need to press E.
	if world.has_method("has_mature_crop") and world.has_mature_crop(target_pos):
		if world.has_method("harvest_crop"):
			used = world.harvest_crop(target_pos)
			if used == false:
				# Fully grown but inventory full — still consume the click so
				# the player doesn't accidentally till/attack the crop.
				used = true

	match active_tool:
		Tool.HOE:
			if world.has_method("till_tile"):
				used = world.till_tile(target_pos)
		Tool.WATERING_CAN:
			if world.has_method("water_tile"):
				used = world.water_tile(target_pos)
		Tool.SPRINKLER:
			if world.has_method("place_sprinkler"):
				used = world.place_sprinkler(target_pos)
		Tool.SCYTHE:
			if world.has_method("scythe_harvest"):
				used = world.scythe_harvest(target_pos)
		Tool.HOTBAR_0, Tool.HOTBAR_1, Tool.HOTBAR_2, Tool.HOTBAR_3, \
		Tool.HOTBAR_4, Tool.HOTBAR_5, Tool.HOTBAR_6, Tool.HOTBAR_7:
			used = _use_hotbar_item(target_pos)
		# SWORD & legacy direct-tools fall through to melee attack below.
		# already calls _play_tool_swing() and sets its own cooldown.

	if used:
		# Face toward the clicked position for visual feedback
		var dir: Vector2 = (target_pos - global_position).normalized()
		if abs(dir.x) > abs(dir.y):
			facing_direction = Vector2.RIGHT if dir.x > 0 else Vector2.LEFT
		else:
			facing_direction = Vector2.DOWN if dir.y > 0 else Vector2.UP
		_update_sprite_facing()
		_update_tool_preview()
		
		_play_tool_swing()
		_tool_cooldown_remaining = base_tool_cooldown * UpgradeManager.get_farming_speed_multiplier()
	else:
		# If tool use didn't do anything, check for ore deposit without pickaxe
		if _check_need_pickaxe(target_pos):
			return  # don't fall through to melee if player tried to mine
		# Otherwise try melee attack at that position
		_try_melee_attack_at_pos(target_pos)


## Check if the player clicked near an ore deposit without a pickaxe equipped.
## Returns true if a toast was shown (prevents falling through to melee attack).
func _check_need_pickaxe(target_pos: Vector2) -> bool:
	var deposits: Array[Node] = get_tree().get_nodes_in_group("ore_deposits")
	if deposits.is_empty():
		return false
	
	for d in deposits:
		if not is_instance_valid(d):
			continue
		var dist: float = d.global_position.distance_to(target_pos)
		if dist < ORE_MINE_RANGE:
			ToastNotification.show_toast("Need a pickaxe!", ToastNotification.ToastType.WARNING, 1.5)
			return true
	return false


## Interact (harvest/compost) at a specific world position (right-click).
## In build mode, picks up placed buildings instead.
func _try_interact_at_pos(target_pos: Vector2) -> void:
	var world: Node = _world
	if not world:
		return
	
	# Build mode: right-click picks up placed buildings
	if _is_build_mode_active():
		if world.has_method("world_to_cell") and world.has_method("try_pickup_building"):
			var cell: Vector2i = world.world_to_cell(target_pos)
			world.try_pickup_building(cell)
		return
	
	# First try to compost the tile
	if InventoryManager.has_item("compost", 1):
		if world.has_method("apply_compost") and world.apply_compost(target_pos):
			return
	
	# Then try to harvest
	if world.has_method("harvest_crop"):
		world.harvest_crop(target_pos)


## Place a building at a specific world position (left-click in build mode).
func _try_build_placement_at_pos(target_pos: Vector2) -> void:
	var world: Node = _world
	if not world or not world.has_method("try_place_building"):
		return
	if world.has_method("world_to_cell"):
		var cell: Vector2i = world.world_to_cell(target_pos)
		world.try_place_building(cell)


## Melee attack at a specific world position (used by mouse click fallback).
func _try_melee_attack_at_pos(attack_pos: Vector2) -> void:
	if not _can_deal_melee_damage():
		return
	# Gingerbread invincibility: can't deal damage
	if GameManager.is_gingerbread_invincible():
		return

	# The cursor sets the aim direction; the hit circle stays near the player
	# so you can't snipe enemies from halfway across the screen.
	var aim: Vector2 = attack_pos - global_position
	if aim.length_squared() < 1.0:
		aim = _facing_vec()
	aim = aim.normalized()

	# Face toward the clicked direction for better feedback.
	_update_facing_toward(attack_pos)

	var hit_enemies := _do_melee_swing(aim)
	# Always swing — a whiff still plays the animation + cooldown so holding
	# to attack keeps a readable rhythm.
	_play_tool_swing()
	_tool_cooldown_remaining = base_tool_cooldown * 0.8
	_swing_gate_timer = MELEE_MIN_SWING_INTERVAL
	_apply_melee_lunge(aim)
	if hit_enemies.is_empty():
		return
	AudioManager.play(AudioManager.Sound.HIT)
	# Combat polish: hitstop and swing arc
	_trigger_hitstop(0.1 if _last_swing_crit else 0.06)
	_spawn_swing_arc(_last_swing_crit)
	# Chance to unleash a boss attack on a random hit enemy
	_try_soul_power_proc(hit_enemies[randi() % hit_enemies.size()])
	# Update kill combo on enemy hits
	if _last_swing_crit:
		_kill_combo += 1
		_last_combo_time = Time.get_unix_time_from_system()
		_check_combo("kill")


## Fire an arrow from the player's bow toward the given world position.
## Consumes one arrow from inventory. If the player has no arrows, shows a
## warning toast and does nothing.
func _fire_bow(target_pos: Vector2, charge_ratio: float = 0.0) -> void:
	# Gingerbread invincibility: can't deal damage
	if GameManager.is_gingerbread_invincible():
		ToastNotification.show_toast("Your gingerbread armor is too sweet to fight! 🍪", ToastNotification.ToastType.WARNING, 2.0)
		return
	# Check for ammo
	if not InventoryManager.has_item("arrow", 1):
		ToastNotification.show_toast("No arrows! Craft more at the crafting table.", ToastNotification.ToastType.WARNING, 2.0)
		return
	
	# Consume one arrow
	InventoryManager.remove_item("arrow", 1)
	
	# Check for critical hit
	var is_crit: bool = randf() < CRIT_BOW_CHANCE
	var base_damage: int = _get_bow_damage()
	var final_damage: int = roundi(base_damage * (CRIT_MULTIPLIER if is_crit else 1.0))
	# Charge multiplier scales damage up to full charge (2x).
	var charge_mult: float = 1.0 + (BOW_CHARGE_DAMAGE_MULT - 1.0) * charge_ratio
	final_damage = maxi(1, roundi(final_damage * charge_mult))
	# A fully charged shot also fires a touch faster (straighter, punchier).
	var charge_speed: float = ARROW_SPEED * (1.0 + charge_ratio * 0.25)
	
	# Create the arrow projectile
	var arrow: Arrow = ARROW_SCENE.instantiate()
	arrow.arrow_damage = final_damage
	arrow.is_critical = is_crit
	arrow.shooter = self
	# Render above mine visual layers (mine map sprite z=1, darkness z=2, wall body z=3)
	arrow.z_index = 5
	# Offset upward so the arrow doesn't immediately collide with the ground tile beneath the player.
	# The player's global_position is at ground level; the arrow spawns in front and raised up so it
	# flies clear of the terrain collision at the player's feet.
	arrow.global_position = global_position + facing_direction * 18.0 + Vector2(0, -10)
	
	# Set velocity toward the target
	var dir: Vector2 = (target_pos - global_position).normalized()
	if dir == Vector2.ZERO:
		dir = facing_direction
	arrow.linear_velocity = dir * charge_speed
	
	# Rotate the arrow sprite to face the direction of travel
	arrow.rotation = dir.angle()
	
	# Add to the world
	get_parent().add_child(arrow)
	
	# Sound and visual feedback (caller handles the swing animation + cooldown)
	AudioManager.play(AudioManager.Sound.BOW_SHOOT)
	EffectSpawner.spawn_dirt_puff(global_position + facing_direction * 12.0)
	if charge_ratio >= 1.0:
		EffectSpawner.spawn_particles(global_position + facing_direction * 14.0, Color(1.0, 0.9, 0.6), 6, 10.0)
		_trigger_hitstop(0.06)


## Returns true if the active hotbar slot holds a bow that can be charged.
func _is_active_bow() -> bool:
	var sd := _get_hotbar_slot_data()
	if sd.is_empty():
		return false
	var item_id: String = sd.get("item_id", "")
	return item_id == "bow" or item_id == "antler_bow"


## Begin charging a bow shot. Called on LMB press while a bow is active.
func _start_bow_charge() -> void:
	_bow_charging = true
	_bow_charge_start = Time.get_unix_time_from_system()
	# Set the player facing the cursor so a release clearly aims at the click.
	_update_facing_toward(get_global_mouse_position())


## Complete a bow charge. Called on LMB release. Fires only at full charge.
func _finish_bow_charge(target_pos: Vector2) -> void:
	if not _bow_charging:
		return
	_bow_charging = false
	var held_time: float = Time.get_unix_time_from_system() - _bow_charge_start
	var ratio: float = clampf(held_time / BOW_CHARGE_MAX_TIME, 0.0, 1.0)
	if ratio < 1.0:
		# Released before full charge — cancel, short cooldown.
		_tool_cooldown_remaining = base_tool_cooldown * 0.5
		return
	_fire_bow(target_pos, 1.0)
	_tool_cooldown_remaining = base_tool_cooldown * 1.0

## Calculate bow damage. Uses the same upgrade scaling as melee tools but
## with its own base value so bows stay balanced.
func _get_bow_damage() -> int:
	var upgrade_bonus: int = UpgradeManager.get_level(UpgradeManager.Upgrade.TOOLS) * 5
	var level_mult: float = LevelManager.get_damage_multiplier()
	var pet_bonus: float = 0.0
	if Engine.has_singleton("PetManager"):
		var pet_mgr: Node = Engine.get_singleton("PetManager")
		if pet_mgr and pet_mgr.has_method("get_combat_bonus"):
			pet_bonus = pet_mgr.get_combat_bonus()
	# Base bow damage is 15 — between sword (25) and axe (18) so it's viable
	# but not overpowering, balanced by the ammo cost.
	return roundi((15 + upgrade_bonus + pet_bonus) * level_mult)


## Mine the nearest ore deposit at or near the given world position.
## Called by _use_hotbar_item when the player has a pickaxe equipped and
## left-clicks. Finds the closest OreDeposit within ORE_MINE_RANGE and
## starts a progress-bar mining session on it (like chopping trees).
## Better pickaxes fill the bar faster.
func _mine_ore_at(target_pos: Vector2) -> void:
	var nearest: OreDeposit = null
	var nearest_dist := ORE_MINE_RANGE
	
	var deposits: Array[Node] = get_tree().get_nodes_in_group("ore_deposits")
	if deposits.is_empty():
		return
	
	for d in deposits:
		if not is_instance_valid(d):
			continue
		var dist: float = d.global_position.distance_to(target_pos)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = d as OreDeposit
	
	if not nearest:
		return
	
	# Get the pickaxe item_id for speed calculation
	var sd := _get_hotbar_slot_data()
	var pickaxe_id: String = sd.get("item_id", "pickaxe_tool") if not sd.is_empty() else "pickaxe_tool"
	
	# Start progress-bar mining on the deposit
	var started: bool = nearest.start_mining(self, pickaxe_id)
	if started:
		# Face toward the deposit
		var dir: Vector2 = (nearest.global_position - global_position).normalized()
		if abs(dir.x) > abs(dir.y):
			facing_direction = Vector2.RIGHT if dir.x > 0 else Vector2.LEFT
		else:
			facing_direction = Vector2.DOWN if dir.y > 0 else Vector2.UP
		_update_sprite_facing()
		
		_play_tool_swing()
		_tool_cooldown_remaining = base_tool_cooldown * 0.5  # short cooldown for initiating mining


## Called by OreDeposit when a mining hit completes (progress bar filled).
## Handles combo tracking for consecutive mining actions.
func _on_ore_deposit_mined(_ore_type: String, _amount: int, _ore_name: String) -> void:
	# Mining combo tracking
	_mine_combo += 1
	_last_combo_time = Time.get_unix_time_from_system()
	_check_combo("mine")


## Returns bonus ore count based on pickaxe tier.
## Higher-tier pickaxes yield more bonus ore per hit.
func _get_pickaxe_tier_bonus(pickaxe_id: String) -> int:
	match pickaxe_id:
		"copper_pickaxe":
			return 1
		"iron_pickaxe":
			return 2
		"gold_pickaxe":
			return 3
		"diamond_pickaxe":
			return 4
		"mythril_pickaxe":
			return 5
		"magma_pickaxe":
			return 6
		_:
			return 0


## Returns bonus wood count based on axe tier.
## Higher-tier axes yield more bonus wood per tree.
func _get_axe_tier_bonus(axe_id: String) -> int:
	match axe_id:
		"copper_axe":
			return 1
		"iron_axe":
			return 2
		"gold_axe":
			return 3
		"diamond_axe":
			return 4
		"mythril_axe":
			return 5
		"magma_axe":
			return 6
		_:
			return 0


## Map ore type to a display color for resource notification.
func _get_ore_color(ore_type: String) -> Color:
	match ore_type:
		"copper_ore":
			return Color(0.85, 0.55, 0.2)
		"coal":
			return Color(0.3, 0.3, 0.3)
		"gold_ore":
			return Color(1.0, 0.85, 0.15)
		"iron_ore":
			return Color(0.75, 0.6, 0.4)
		"stone":
			return Color(0.6, 0.6, 0.6)
		"silver_ore":
			return Color(0.75, 0.75, 0.85)
		"diamond_ore":
			return Color(0.5, 0.8, 1.0)
		"ruby_ore":
			return Color(1.0, 0.3, 0.3)
		"obsidian_ore":
			return Color(0.3, 0.2, 0.4)
	return Color(0.8, 0.8, 0.8)


func _update_sprite_facing() -> void:
	if facing_direction.x < 0:
		sprite.flip_h = true
		held_item.flip_h = true
	elif facing_direction.x > 0:
		sprite.flip_h = false
		held_item.flip_h = false
	_update_held_item_position()


## Rotate the player's facing toward a world position (used to aim attacks).
func _update_facing_toward(world_pos: Vector2) -> void:
	var delta_vec := world_pos - global_position
	if delta_vec.length_squared() < 1.0:
		return
	if abs(delta_vec.x) > abs(delta_vec.y):
		facing_direction = Vector2.RIGHT if delta_vec.x > 0 else Vector2.LEFT
	else:
		facing_direction = Vector2.DOWN if delta_vec.y > 0 else Vector2.UP
	_update_sprite_facing()

## Updates the held item sprite based on the active tool.
## Shows the tool/seed icon in the player's hand, or hides it when nothing is equipped.
func _ensure_lantern_light() -> void:
	if _lantern_light != null:
		return
	_lantern_light = PointLight2D.new()
	_lantern_light.name = "LanternLight"
	_lantern_light.energy = 1.5
	_lantern_light.texture_scale = 0.8
	_lantern_light.color = Color(1.0, 0.7, 0.3, 0.9)
	_lantern_light.range_item_cull_mask = 1  # only affect world layer
	_lantern_light.shadow_enabled = false
	# PointLight2D needs a texture to emit visible light
	if _lantern_texture == null:
		_lantern_texture = _make_light_texture()
	_lantern_light.texture = _lantern_texture
	add_child(_lantern_light)


func _make_light_texture() -> Texture2D:
	## Create a soft circular gradient texture for PointLight2D.
	## Uses pixel-level alpha clipping so the light is a perfect circle.
	var size := 64
	var half := size / 2.0
	var radius := half - 1.0
	var inner_radius := radius * 0.3
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
				a = 1.0 - t * t
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(img)


func _update_lantern(_phase: int = -1) -> void:
	var holding_light := false
	match active_tool:
		Tool.HOTBAR_0, Tool.HOTBAR_1, Tool.HOTBAR_2, Tool.HOTBAR_3, \
		Tool.HOTBAR_4, Tool.HOTBAR_5, Tool.HOTBAR_6, Tool.HOTBAR_7:
			var sd := _get_hotbar_slot_data()
			if not sd.is_empty():
				var item: ItemData = DataManager.get_item(sd.get("item_id", ""))
				if item and item.is_light_source:
					holding_light = true
	
	if holding_light != _lantern_active:
		_lantern_active = holding_light
		_ensure_lantern_light()
		_lantern_light.visible = _lantern_active

func _update_held_item() -> void:
	match active_tool:
		Tool.NONE:
			held_item.visible = false
		Tool.HOE:
			held_item.texture = TEX_HOE
			held_item.scale = Vector2(1.3, 1.3)
			held_item.visible = true
		Tool.WATERING_CAN:
			held_item.texture = TEX_WATERING_CAN
			held_item.scale = Vector2(1.3, 1.3)
			held_item.visible = true
		Tool.SPRINKLER:
			held_item.visible = false
		Tool.SCYTHE:
			held_item.texture = TEX_SCYTHE
			held_item.scale = Vector2(1.3, 1.3)
			held_item.visible = true
		Tool.AXE:
			held_item.texture = TEX_AXE
			held_item.scale = Vector2(1.3, 1.3)
			held_item.visible = true
		Tool.PICKAXE:
			held_item.texture = TEX_PICKAXE
			held_item.scale = Vector2(1.3, 1.3)
			held_item.visible = true
		Tool.SWORD:
			held_item.texture = TEX_SWORD
			held_item.scale = Vector2(1.3, 1.3)
			held_item.visible = true
		Tool.HOTBAR_0, Tool.HOTBAR_1, Tool.HOTBAR_2, Tool.HOTBAR_3, \
		Tool.HOTBAR_4, Tool.HOTBAR_5, Tool.HOTBAR_6, Tool.HOTBAR_7:
			var sd := _get_hotbar_slot_data()
			if sd.is_empty():
				held_item.visible = false
			else:
				var item: ItemData = DataManager.get_item(sd["item_id"]) if not sd.is_empty() else null
				# Tools, weapons, seeds, and light sources show a held sprite; everything else hides it
				if item and (item.category == "tool" or item.category == "weapon" or item.category == "seed" or item.is_light_source or sd["item_id"] in ["sprinkler", "quality_sprinkler", "iridium_sprinkler"]):
					var tex_map := {
						"axe_tool": TEX_AXE, "copper_axe": TEX_AXE, "iron_axe": TEX_AXE,
						"gold_axe": TEX_AXE, "diamond_axe": TEX_AXE, "mythril_axe": TEX_AXE, "magma_axe": TEX_AXE,
						"pickaxe_tool": TEX_PICKAXE,
						"copper_pickaxe": TEX_PICKAXE, "iron_pickaxe": TEX_PICKAXE,
						"gold_pickaxe": TEX_PICKAXE, "diamond_pickaxe": TEX_PICKAXE,
						"mythril_pickaxe": TEX_PICKAXE,
						"scythe_tool": TEX_SCYTHE, "sword_tool": TEX_SWORD,
						"copper_sword": TEX_SWORD, "iron_sword": TEX_SWORD,
						"gold_sword": TEX_SWORD, "diamond_sword": TEX_SWORD,
						"mythril_sword": TEX_SWORD,
						"cutlass": TEX_CUTLASS,
						"sprinkler": TEX_SPRINKLER, "quality_sprinkler": TEX_SPRINKLER, "iridium_sprinkler": TEX_SPRINKLER,
						"lantern": TEX_LANTERN, "torch": TEX_LANTERN, "ember_lantern": TEX_LANTERN,
						"fishing_rod": TEX_FISHING_ROD,
						"bow": TEX_BOW,
						"antler_bow": TEX_BOW,
						"magma_pickaxe": TEX_PICKAXE,
					}
					# Use specific tool texture, seed bag for seeds, or hide tools without textures
					if tex_map.has(sd["item_id"]):
						held_item.texture = tex_map[sd["item_id"]]
						if sd["item_id"] == "bow" or sd["item_id"] == "antler_bow":
							held_item.scale = Vector2(0.8, 0.8)
						else:
							held_item.scale = Vector2(1.3, 1.3)
						held_item.visible = true
					elif item.category == "seed":
						held_item.texture = TEX_SEED
						held_item.scale = Vector2(0.9, 0.9)
						held_item.visible = true
					else:
						held_item.visible = false
				else:
					held_item.visible = false
		_:
			held_item.visible = false
	_update_held_item_position()

## Adjusts the held item position based on which direction the player is facing.
## HeldItem is a child of AnimatedSprite2D (48×48, scale 0.5), so positions are in
## the 48×48 local pixel space. The right hand is at approximately (6, 12) in this space.
## When facing LEFT, sprite.flip_h mirrors the texture so the tool goes at (-6, 12).
func _update_held_item_position() -> void:
	match facing_direction:
		Vector2.LEFT:
			held_item.position = Vector2(-6, 12)
		Vector2.RIGHT:
			held_item.position = Vector2(6, 12)
		Vector2.UP:
			held_item.position = Vector2(6, 12)
		Vector2.DOWN:
			held_item.position = Vector2(6, 12)
		_:
			held_item.position = Vector2(6, 12)

func _walk_bob(_delta: float) -> void:
	# Walk bob is now handled by the AnimatedSprite2D walk animation
	pass

func _reset_walk_bob() -> void:
	# Walk bob is now handled by the AnimatedSprite2D walk animation
	pass

# ---------------------------------------------------------------------------
# Armor visual overlays
# ---------------------------------------------------------------------------

## Check if all 4 armor slots are filled with the same material set.
## Returns "iron", "leather", or "" if no complete matching set is equipped.
func _get_full_armor_set() -> String:
	var equipped: Dictionary = GameManager.equipped_armor
	var first_material: String = ""
	for slot: String in ["helmet", "chestplate", "leggings", "boots"]:
		var item_id: String = equipped.get(slot, "")
		if item_id.is_empty():
			return ""
		if first_material.is_empty():
			if item_id.begins_with("iron_"):
				first_material = "iron"
			elif item_id.begins_with("leather_"):
				first_material = "leather"
			elif item_id.begins_with("copper_"):
				first_material = "copper"
			elif item_id.begins_with("silver_"):
				first_material = "silver"
			elif item_id.begins_with("gold_"):
				first_material = "gold"
			elif item_id.begins_with("steel_"):
				first_material = "steel"
			elif item_id.begins_with("mythril_"):
				first_material = "mythril"
			elif item_id.begins_with("diamond_"):
				first_material = "diamond"
			elif item_id.begins_with("ruby_"):
				first_material = "ruby"
			elif item_id.begins_with("obsidian_"):
				first_material = "obsidian"
			elif item_id.begins_with("gingerbread_"):
				first_material = "gingerbread"
			else:
				return ""
		else:
			# All pieces must be the same material
			if first_material == "iron" and not item_id.begins_with("iron_"):
				return ""
			if first_material == "leather" and not item_id.begins_with("leather_"):
				return ""
			if first_material == "copper" and not item_id.begins_with("copper_"):
				return ""
			if first_material == "silver" and not item_id.begins_with("silver_"):
				return ""
			if first_material == "gold" and not item_id.begins_with("gold_"):
				return ""
			if first_material == "steel" and not item_id.begins_with("steel_"):
				return ""
			if first_material == "mythril" and not item_id.begins_with("mythril_"):
				return ""
			if first_material == "diamond" and not item_id.begins_with("diamond_"):
				return ""
			if first_material == "ruby" and not item_id.begins_with("ruby_"):
				return ""
			if first_material == "obsidian" and not item_id.begins_with("obsidian_"):
				return ""
			if first_material == "gingerbread" and not item_id.begins_with("gingerbread_"):
				return ""
	return first_material


## Swap the entire character spritesheet when a full matching armor set is equipped,
## or restore the base spritesheet when armor is removed or mismatched.
## Uses separate walk (192x96) and idle (192x96) textures matching the base player format:
## 4x2 grid of 48x48 frames, 8 frames per animation.
func _update_armor_sheet(_defense: int = -1) -> void:
	var walk_tex: Texture2D
	var idle_tex: Texture2D
	var set_type: String = _get_full_armor_set()
	if set_type == "iron":
		if not ARMOR_WALK_IRON:
			ARMOR_WALK_IRON = load("res://assets/generated/player_walk_iron.png")
			ARMOR_IDLE_IRON = load("res://assets/generated/player_idle_iron.png")
		walk_tex = ARMOR_WALK_IRON
		idle_tex = ARMOR_IDLE_IRON
	elif set_type == "leather":
		if not ARMOR_WALK_LEATHER:
			ARMOR_WALK_LEATHER = load("res://assets/generated/player_walk_leather.png")
			ARMOR_IDLE_LEATHER = load("res://assets/generated/player_idle_leather.png")
		walk_tex = ARMOR_WALK_LEATHER
		idle_tex = ARMOR_IDLE_LEATHER
	elif set_type == "copper":
		if not ARMOR_WALK_COPPER:
			ARMOR_WALK_COPPER = load("res://assets/generated/player_walk_copper.png")
			ARMOR_IDLE_COPPER = load("res://assets/generated/player_idle_copper.png")
		walk_tex = ARMOR_WALK_COPPER
		idle_tex = ARMOR_IDLE_COPPER
	elif set_type == "silver":
		if not ARMOR_WALK_SILVER:
			ARMOR_WALK_SILVER = load("res://assets/generated/player_walk_silver.png")
			ARMOR_IDLE_SILVER = load("res://assets/generated/player_idle_silver.png")
		walk_tex = ARMOR_WALK_SILVER
		idle_tex = ARMOR_IDLE_SILVER
	elif set_type == "gold":
		if not ARMOR_WALK_GOLD:
			ARMOR_WALK_GOLD = load("res://assets/generated/player_walk_gold.png")
			ARMOR_IDLE_GOLD = load("res://assets/generated/player_idle_gold.png")
		walk_tex = ARMOR_WALK_GOLD
		idle_tex = ARMOR_IDLE_GOLD
	elif set_type == "steel":
		if not ARMOR_WALK_STEEL:
			ARMOR_WALK_STEEL = load("res://assets/generated/player_walk_steel.png")
			ARMOR_IDLE_STEEL = load("res://assets/generated/player_idle_steel.png")
		walk_tex = ARMOR_WALK_STEEL
		idle_tex = ARMOR_IDLE_STEEL
	elif set_type == "mythril":
		if not ARMOR_WALK_MYTHRIL:
			ARMOR_WALK_MYTHRIL = load("res://assets/generated/player_walk_mythril.png")
			ARMOR_IDLE_MYTHRIL = load("res://assets/generated/player_idle_mythril.png")
		walk_tex = ARMOR_WALK_MYTHRIL
		idle_tex = ARMOR_IDLE_MYTHRIL
	elif set_type == "diamond":
		if not ARMOR_WALK_DIAMOND:
			ARMOR_WALK_DIAMOND = load("res://assets/generated/player_walk_diamond.png")
			ARMOR_IDLE_DIAMOND = load("res://assets/generated/player_idle_diamond.png")
		walk_tex = ARMOR_WALK_DIAMOND
		idle_tex = ARMOR_IDLE_DIAMOND
	elif set_type == "ruby":
		if not ARMOR_WALK_RUBY:
			ARMOR_WALK_RUBY = load("res://assets/generated/player_walk_ruby.png")
			ARMOR_IDLE_RUBY = load("res://assets/generated/player_idle_ruby.png")
		walk_tex = ARMOR_WALK_RUBY
		idle_tex = ARMOR_IDLE_RUBY
	elif set_type == "obsidian":
		if not ARMOR_WALK_OBSIDIAN:
			ARMOR_WALK_OBSIDIAN = load("res://assets/generated/player_walk_obsidian.png")
			ARMOR_IDLE_OBSIDIAN = load("res://assets/generated/player_idle_obsidian.png")
		walk_tex = ARMOR_WALK_OBSIDIAN
		idle_tex = ARMOR_IDLE_OBSIDIAN
	elif set_type == "gingerbread":
		if not ARMOR_WALK_GINGERBREAD:
			ARMOR_WALK_GINGERBREAD = load("res://assets/gingerbread_set/player_walk_gingerbread.png")
		walk_tex = ARMOR_WALK_GINGERBREAD
		idle_tex = ARMOR_WALK_GINGERBREAD  # Use walk frames for idle too
	
	# Gingerbread armor: slightly larger sprite + invincibility & sparkle effect
	if set_type == "gingerbread":
		sprite.scale = Vector2(0.55, 0.55)
		GameManager.set_gingerbread_invincible(true)
		if _gingerbread_sparkle_timer and _gingerbread_sparkle_timer.is_stopped():
			_gingerbread_sparkle_timer.start()
	else:
		if sprite.scale != Vector2(0.5, 0.5):
			sprite.scale = Vector2(0.5, 0.5)
		GameManager.set_gingerbread_invincible(false)
		if _gingerbread_sparkle_timer and not _gingerbread_sparkle_timer.is_stopped():
			_gingerbread_sparkle_timer.stop()
	
	if walk_tex and idle_tex:
		var frame_size: int = 48
		# Swap sprites — rebuild SpriteFrames from armored sheets, matching _setup_animation() format
		var frames := SpriteFrames.new()
		frames.add_animation("idle")
		frames.add_animation("walk")
		# Gingerbread walk spritesheet has a non-matching first frame (top-left) — skip it
		var frame_start: int = 1 if set_type == "gingerbread" else 0
		for i in range(frame_start, 8):
			var idle_frame := AtlasTexture.new()
			idle_frame.atlas = idle_tex
			idle_frame.region = Rect2((i % 4) * frame_size, floori(i / 4) * frame_size, frame_size, frame_size)
			frames.add_frame("idle", idle_frame)
			var walk_frame := AtlasTexture.new()
			walk_frame.atlas = walk_tex
			walk_frame.region = Rect2((i % 4) * frame_size, floori(i / 4) * frame_size, frame_size, frame_size)
			frames.add_frame("walk", walk_frame)
		frames.set_animation_speed("idle", 6.0)
		frames.set_animation_speed("walk", 8.0)
		frames.set_animation_loop("idle", true)
		frames.set_animation_loop("walk", true)
		sprite.sprite_frames = frames
	else:
		# No full set — restore base player spritesheets
		_setup_animation()
	
	# Resume current animation
	if sprite.sprite_frames:
		sprite.play("idle")


func _play_tool_swing() -> void:
	if _tool_swing_tween and _tool_swing_tween.is_valid():
		_tool_swing_tween.kill()
	
	if NetworkManager.is_network_active() and is_multiplayer_authority():
		rpc("_sync_tool_swing")
	
	var swing_direction := facing_direction
	var rotation_amount := 15.0 if swing_direction.x != 0 else 10.0
	
	# Rotate sprite slightly in swing direction
	var target_rotation := rotation_amount if swing_direction.x > 0 or swing_direction.y > 0 else -rotation_amount
	
	_tool_swing_tween = create_tween()
	_tool_swing_tween.set_parallel(true)
	_tool_swing_tween.set_ease(Tween.EASE_OUT)
	_tool_swing_tween.set_trans(Tween.TRANS_QUART)
	
	_tool_swing_tween.tween_property(sprite, "rotation_degrees", target_rotation, 0.1)
	_tool_swing_tween.tween_property(sprite, "scale", Vector2(0.55, 0.45), 0.1)
	_tool_swing_tween.tween_interval(0.05)
	_tool_swing_tween.tween_property(sprite, "rotation_degrees", 0.0, 0.1)
	_tool_swing_tween.tween_property(sprite, "scale", Vector2(0.5, 0.5), 0.1)


# ---------------------------------------------------------------------------
# Fishing rod animations
# ---------------------------------------------------------------------------

## Plays a 3-phase fishing rod cast animation on the player sprite:
## 1. Pull rod back (anticipation, 0.2s)
## 2. Cast forward (snap, 0.25s)
## 3. Settle into holding pose (0.15s, sprite stays slightly tilted)
func play_fishing_cast() -> void:
	if _tool_swing_tween and _tool_swing_tween.is_valid():
		_tool_swing_tween.kill()
	
	# Determine cast direction sign — same convention as _play_tool_swing()
	var cast_sign := 1.0
	if facing_direction.x < 0 or (facing_direction.x == 0 and facing_direction.y < 0):
		cast_sign = -1.0
	
	var cast_tween := create_tween()
	cast_tween.set_ease(Tween.EASE_OUT)
	cast_tween.set_trans(Tween.TRANS_QUART)
	
	# Phase 1 (0.2s): Pull rod back
	cast_tween.tween_property(sprite, "rotation_degrees", -8.0 * cast_sign, 0.2)
	# Phase 2 (0.25s): Cast forward — bigger arc for emphasis
	cast_tween.tween_property(sprite, "rotation_degrees", 14.0 * cast_sign, 0.25)
	# Phase 3 (0.15s): Settle into holding pose — sprite stays tilted forward
	cast_tween.tween_property(sprite, "rotation_degrees", 4.0 * cast_sign, 0.15)


## Quick upward tug animation when reeling in a fish.
func play_fishing_reel() -> void:
	if _tool_swing_tween and _tool_swing_tween.is_valid():
		_tool_swing_tween.kill()
	
	var cast_sign := 1.0
	if facing_direction.x < 0 or (facing_direction.x == 0 and facing_direction.y < 0):
		cast_sign = -1.0
	
	var reel_tween := create_tween()
	reel_tween.set_parallel(true)
	reel_tween.set_ease(Tween.EASE_OUT)
	reel_tween.set_trans(Tween.TRANS_BACK)
	
	# Quick upward tug (0.08s up, 0.12s return)
	reel_tween.tween_property(sprite, "rotation_degrees", 8.0 * cast_sign, 0.08)
	reel_tween.tween_interval(0.04)
	reel_tween.tween_property(sprite, "rotation_degrees", 4.0 * cast_sign, 0.12)


## Reset sprite rotation back to neutral when fishing ends.
func reset_fishing_pose() -> void:
	if _tool_swing_tween and _tool_swing_tween.is_valid():
		_tool_swing_tween.kill()
	
	var reset_tween := create_tween()
	reset_tween.set_ease(Tween.EASE_OUT)
	reset_tween.set_trans(Tween.TRANS_QUART)
	reset_tween.tween_property(sprite, "rotation_degrees", 0.0, 0.15)


# ══════════════════════════════════════════════════════════════════════════
# ── Inconstant Soul Power: chance to unleash boss attacks on enemies ──
# ══════════════════════════════════════════════════════════════════════════

## After a successful melee hit, check if the player has consumed an Inconstant
## Fruit (granting the "inconstant_soul_power" buff) and roll a 20% chance to
## unleash a random Inconstant Soul boss attack on the hit enemy.
func _try_soul_power_proc(target: Node2D) -> void:
	if not is_instance_valid(target):
		return
	if not BuffManager or not BuffManager.has_buff("inconstant_soul_power"):
		return
	# 20% proc chance
	if randf() > 0.20:
		return
	
	var attack_roll: int = randi() % 9
	match attack_roll:
		0: _soul_heart_pulse(target)
		1: _soul_tendril_sweep(target)
		2: _soul_drain(target)
		3: _soul_sunburst(target)
		4: _soul_light_lances(target)
		5: _soul_shield_burst(target)
		6: _soul_chaos_orbs(target)
		7: _soul_ground_fissure(target)
		8: _soul_tendril_eruption(target)


# ── ROOT phase attacks ──────────────────────────────────────────────────

## Heart Pulse — expanding purple ring of energy centered on the enemy.
func _soul_heart_pulse(target: Node2D) -> void:
	var pos: Vector2 = target.global_position
	EffectSpawner.screen_shake(3.0, 0.2)
	for ring in range(3):
		var r: float = 8.0 + ring * 10.0
		for angle_i in range(6):
			var a: float = (angle_i / 6.0) * TAU
			var p: Vector2 = pos + Vector2(cos(a), sin(a)) * r
			EffectSpawner.spawn_particles(p, Color(0.5, 0.15, 0.7, 0.6), 2, 4.0)
	target.take_damage(8, self, false)
	EffectSpawner.spawn_floating_text("Heart Pulse!", pos, Color(0.5, 0.15, 0.7))
	AudioManager.play(AudioManager.Sound.HIT)


## Tendril Sweep — tendrils arc across in front of the enemy.
func _soul_tendril_sweep(target: Node2D) -> void:
	var pos: Vector2 = target.global_position
	EffectSpawner.screen_shake(2.0, 0.15)
	for t in range(3):
		var sweep: float = (t - 1.0) * 0.3
		for i in range(3):
			var d: float = 8.0 + i * 8.0
			var sweep_dir := Vector2(
				cos(sweep) - sin(sweep),
				sin(sweep) + cos(sweep)
			)
			var p: Vector2 = pos + sweep_dir * d
			EffectSpawner.spawn_particles(p, Color(0.5, 0.15, 0.7), 3, 4.0)
			EffectSpawner.spawn_particles(p, Color(0.3, 0.15, 0.05), 2, 3.0)
	target.take_damage(7, self, false)
	EffectSpawner.spawn_floating_text("Tendril Sweep!", pos, Color(0.5, 0.15, 0.7))
	AudioManager.play(AudioManager.Sound.HIT)


## Soul Drain — purple tendrils drain life, healing the player slightly.
func _soul_drain(target: Node2D) -> void:
	var pos: Vector2 = target.global_position
	EffectSpawner.screen_shake(3.0, 0.2)
	for i in range(5):
		var p: Vector2 = pos + Vector2(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0))
		EffectSpawner.spawn_particles(p, Color(0.5, 0.15, 0.7, 0.8), 3, 4.0)
		EffectSpawner.spawn_particles(p, Color(0.8, 0.15, 0.15, 0.6), 2, 3.0)
	target.take_damage(9, self, false)
	# Heal player by 5 HP
	if GameManager:
		GameManager.heal(5)
	EffectSpawner.spawn_floating_text("Soul Drain!", pos, Color(0.8, 0.15, 0.15))
	AudioManager.play(AudioManager.Sound.HIT)


# ── STAG phase attacks ──────────────────────────────────────────────────

## Sunburst — radial burst of golden light emanating from the enemy.
func _soul_sunburst(target: Node2D) -> void:
	var pos: Vector2 = target.global_position
	EffectSpawner.screen_shake(4.0, 0.2)
	for ring in range(3):
		var r: float = 8.0 + ring * 7.0
		for angle_i in range(6):
			var a: float = (angle_i / 6.0) * TAU + ring * 0.5
			var p: Vector2 = pos + Vector2(cos(a), sin(a)) * r
			EffectSpawner.spawn_particles(p, Color(1.0, 0.85, 0.3, 0.7), 3, 4.0)
			EffectSpawner.spawn_particles(p, Color(1.0, 1.0, 1.0, 0.4), 2, 3.0)
	target.take_damage(8, self, false)
	EffectSpawner.spawn_floating_text("Sunburst!", pos, Color(1.0, 0.85, 0.3))
	AudioManager.play(AudioManager.Sound.HIT)


## Light Lances — three beams of light strike through the enemy.
func _soul_light_lances(target: Node2D) -> void:
	var pos: Vector2 = target.global_position
	EffectSpawner.screen_shake(2.0, 0.1)
	for i in range(3):
		var spread: float = (i - 1.0) * 0.3
		var shot_dir := Vector2(cos(spread) - sin(spread), sin(spread) + cos(spread))
		for j in range(4):
			var p: Vector2 = pos + shot_dir * (6.0 + j * 8.0) + Vector2(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0))
			EffectSpawner.spawn_particles(p, Color(1.0, 0.85, 0.3, 0.8), 2, 4.0)
			EffectSpawner.spawn_particles(p, Color(1.0, 1.0, 1.0, 0.5), 1, 3.0)
	target.take_damage(7, self, false)
	EffectSpawner.spawn_floating_text("Light Lance!", pos, Color(1.0, 0.85, 0.3))
	AudioManager.play(AudioManager.Sound.HIT)


## Shield Burst — bright golden explosion of light around the enemy.
func _soul_shield_burst(target: Node2D) -> void:
	var pos: Vector2 = target.global_position
	EffectSpawner.screen_shake(4.0, 0.2)
	for ring in range(4):
		var r: float = 8.0 + ring * 8.0
		for angle_i in range(8):
			var a: float = (angle_i / 8.0) * TAU
			var p: Vector2 = pos + Vector2(cos(a), sin(a)) * r
			EffectSpawner.spawn_particles(p, Color(1.0, 0.85, 0.3), 3, 4.0)
			EffectSpawner.spawn_particles(p, Color(1.0, 1.0, 1.0), 2, 3.0)
	target.take_damage(10, self, false)
	EffectSpawner.spawn_floating_text("Shield Burst!", pos, Color(1.0, 0.85, 0.3))
	AudioManager.play(AudioManager.Sound.HIT)


# ── WYRM phase attacks ──────────────────────────────────────────────────

## Chaos Orbs — orbiting orbs of chaotic energy strike the enemy.
func _soul_chaos_orbs(target: Node2D) -> void:
	var pos: Vector2 = target.global_position
	EffectSpawner.screen_shake(3.0, 0.2)
	for i in range(3):
		var spread: float = (i - 1.0) * 0.4
		var shot_dir := Vector2(cos(spread) - sin(spread), sin(spread) + cos(spread))
		for j in range(3):
			var p: Vector2 = pos + shot_dir * (8.0 + j * 8.0) + Vector2(randf_range(-5.0, 5.0), randf_range(-5.0, 5.0))
			EffectSpawner.spawn_particles(p, Color(0.85, 0.3, 0.55, 0.8), 3, 5.0)
			EffectSpawner.spawn_particles(p, Color(0.8, 0.15, 0.15, 0.5), 2, 4.0)
	target.take_damage(6, self, false)
	EffectSpawner.spawn_floating_text("Chaos Orb!", pos, Color(0.85, 0.3, 0.55))
	AudioManager.play(AudioManager.Sound.HIT)


## Ground Fissure — cracks erupt beneath the enemy.
func _soul_ground_fissure(target: Node2D) -> void:
	var pos: Vector2 = target.global_position
	EffectSpawner.screen_shake(5.0, 0.2)
	for i in range(4):
		var p: Vector2 = pos + Vector2(randf_range(-8.0, 8.0), randf_range(-8.0, 8.0))
		EffectSpawner.spawn_particles(p, Color(0.6, 0.4, 0.2), 5, 6.0)
		EffectSpawner.spawn_particles(p, Color(0.85, 0.3, 0.55, 0.5), 3, 4.0)
	target.take_damage(8, self, false)
	EffectSpawner.spawn_floating_text("Ground Fissure!", pos, Color(0.6, 0.4, 0.2))
	AudioManager.play(AudioManager.Sound.HIT)


## Tendril Eruption — tendrils burst from the ground around the enemy.
func _soul_tendril_eruption(target: Node2D) -> void:
	var pos: Vector2 = target.global_position
	EffectSpawner.screen_shake(4.0, 0.2)
	for angle_i in range(8):
		var a: float = (angle_i / 8.0) * TAU
		for dist_i in range(2):
			var r: float = 10.0 + dist_i * 10.0
			var p: Vector2 = pos + Vector2(cos(a), sin(a)) * r
			EffectSpawner.spawn_particles(p, Color(0.5, 0.15, 0.7), 4, 5.0)
			EffectSpawner.spawn_particles(p, Color(0.3, 0.15, 0.05), 2, 4.0)
	target.take_damage(7, self, false)
	EffectSpawner.spawn_floating_text("Tendril Eruption!", pos, Color(0.5, 0.15, 0.7))
	AudioManager.play(AudioManager.Sound.HIT)


# ══════════════════════════════════════════════════════════════════════════
# ── Combat Polish: I-Frames, Hitstop, Swing Arc ─────────────────────────
# ══════════════════════════════════════════════════════════════════════════

## Returns true if the player is currently invulnerable (in i-frames).
## Called by GameManager.take_damage() to skip damage during invulnerability.
func is_invulnerable() -> bool:
	return _is_invulnerable


## Start invulnerability (i-frames) for the given duration in seconds.
## During this period the player cannot take damage and the sprite blinks.
func start_invulnerability(duration: float = 1.0) -> void:
	if _is_invulnerable:
		_invulnerability_timer.stop()
		_stop_blink_effect()
	_is_invulnerable = true
	_invulnerability_timer.wait_time = duration
	_invulnerability_timer.start()
	_start_blink_effect()


## Called when invulnerability timer expires — ends i-frames.
func _on_invulnerability_ended() -> void:
	_is_invulnerable = false
	_stop_blink_effect()
	sprite.modulate.a = 1.0


## Starts a looping blink tween on the sprite (alpha oscillates).
func _start_blink_effect() -> void:
	_stop_blink_effect()
	_invuln_blink_tween = create_tween().set_loops()
	_invuln_blink_tween.set_ease(Tween.EASE_IN_OUT)
	_invuln_blink_tween.set_trans(Tween.TRANS_SINE)
	_invuln_blink_tween.tween_property(sprite, "modulate:a", 0.25, 0.08)
	_invuln_blink_tween.tween_property(sprite, "modulate:a", 1.0, 0.08)


## Stops the blink tween if it's running.
func _stop_blink_effect() -> void:
	if _invuln_blink_tween and _invuln_blink_tween.is_valid():
		_invuln_blink_tween.kill()
		_invuln_blink_tween = null


## Brief time-freeze on hit to give attacks weight and impact.
## Uses a SceneTreeTimer that ignores time_scale so it fires in real-time.
func _trigger_hitstop(duration: float = 0.06) -> void:
	if Engine.time_scale == 0.0:
		return
	Engine.time_scale = 0.0
	# Timer fires in real-time even when Engine.time_scale = 0
	get_tree().create_timer(duration, true, true, true).timeout.connect(func():
		Engine.time_scale = 1.0
	, CONNECT_ONE_SHOT)


## Spawns a visual weapon swing arc — a fan of particles in the swing direction.
## Called at the end of _play_tool_swing().
func _spawn_swing_arc(is_critical: bool = false) -> void:
	var swing_dir := facing_direction
	var arc_angle: float = deg_to_rad(90.0)  # 90-degree arc
	var base_angle: float
	
	# Determine the base angle (center of the arc) based on facing direction
	if swing_dir.y < 0:          # Facing up
		base_angle = -PI / 2.0
	elif swing_dir.y > 0:        # Facing down
		base_angle = PI / 2.0
	elif swing_dir.x > 0:        # Facing right
		base_angle = 0.0
	else:                        # Facing left
		base_angle = PI
	
	# Color: silver by default, golden on crit
	var arc_color := Color(0.8, 0.85, 1.0, 0.6) if not is_critical else Color(1.0, 0.85, 0.3, 0.8)
	var particle_count := 5 if not is_critical else 8
	
	# Spawn particles in an arc
	var arc_start := base_angle - arc_angle / 2.0
	var arc_end := base_angle + arc_angle / 2.0
	for i in range(particle_count):
		var t: float = float(i) / float(particle_count - 1) if particle_count > 1 else 0.5
		var angle: float = arc_start + t * arc_end
		var dir := Vector2(cos(angle), sin(angle))
		var spawn_pos: Vector2 = global_position + dir * 22.0
		EffectSpawner.spawn_particles(spawn_pos, arc_color, 2, 4.0)


## Safely compute a knockback direction from an enemy position toward the player.
## Returns a normalized Vector2, or ZERO if the direction vector is zero/non-finite.
static func _enemy_knockback_dir(enemy_pos: Vector2, player_pos: Vector2) -> Vector2:
	var diff := enemy_pos - player_pos
	if diff == Vector2.ZERO or not is_finite(diff.x) or not is_finite(diff.y):
		return Vector2.ZERO
	return diff.normalized()


## Called periodically while wearing the gingerbread armor set.
## Spawns golden sparkles around the player to show invincibility is active.
func _on_gingerbread_sparkle_tick() -> void:
	EffectSpawner.spawn_particles(global_position + Vector2(randf_range(-10, 10), randf_range(-14, 6)), Color(1.0, 0.85, 0.3), 2, 6.0)


## Received by all peers to update a remote player's visible state.
## Only the authority sends this; all others apply the interpolated state.
## z_index is synced so remote copies render above interior floors/walls the
## same way the local player does when inside a building or mine.
@rpc("unreliable", "any_peer")
func _sync_remote_state(pos: Vector2, facing_x: float, facing_y: float, facing_left: bool, is_moving: bool, p_z_index: int) -> void:
	if is_multiplayer_authority():
		return
	global_position = pos
	z_index = p_z_index
	facing_direction = Vector2(facing_x, facing_y)
	sprite.flip_h = facing_left
	held_item.flip_h = facing_left
	_update_held_item_position()
	if is_moving:
		if sprite.sprite_frames and sprite.animation != "walk":
			sprite.play("walk")
	else:
		if sprite.sprite_frames and sprite.animation != "idle":
			sprite.play("idle")


@rpc("unreliable", "authority")
func _sync_tool_swing() -> void:
	if is_multiplayer_authority():
		return
	_play_tool_swing()
