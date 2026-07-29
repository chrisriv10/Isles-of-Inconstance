## BakeryMiniGame — timing-based baking mini-game.
## A moving marker oscillates on a bar; press a key when it's in the
## target zone to determine quality (Normal → Silver → Gold → Iridium).
## Higher quality = better buffs and sell price.
## The bar shows colored sub-zones so the player can see each quality tier.

extends Control
class_name BakeryMiniGame

signal baking_completed(quality: int)

## Quality tiers
enum Quality {
	BURNT = -1,
	NORMAL = 0,
	SILVER = 1,
	GOLD = 2,
	IRIDIUM = 3,
}

const QUALITY_NAMES: Dictionary = {
	Quality.BURNT: "Burnt!",
	Quality.NORMAL: "Normal",
	Quality.SILVER: "Silver",
	Quality.GOLD: "Gold",
	Quality.IRIDIUM: "Iridium ✨",
}

const QUALITY_COLORS: Dictionary = {
	Quality.BURNT: Color(0.5, 0.3, 0.1),
	Quality.NORMAL: Color(0.8, 0.8, 0.8),
	Quality.SILVER: Color(0.75, 0.85, 1.0),
	Quality.GOLD: Color(1.0, 0.85, 0.2),
	Quality.IRIDIUM: Color(0.6, 1.0, 0.8),
}

# -- Quality tier zone thresholds (fraction of zone half-width from center) --
const ZONE_NORMAL_FRAC: float = 1.0    # outer 100% of zone = Normal
const ZONE_SILVER_FRAC: float = 0.75   # inner 75% = Silver
const ZONE_GOLD_FRAC: float = 0.45     # inner 45% = Gold
const ZONE_IRIDIUM_FRAC: float = 0.15  # inner 15% = Iridium

## Cost in gold to attempt a bake (cost now charged in resources — dough + wood — by BuildingInterior)
const BAKE_COST: int = 0

## Zone width as fraction of bar width (0.0 - 1.0)
var _zone_width: float = 0.25
## Current marker position (0.0 - 1.0)
var _marker_pos: float = 0.5
## Marker direction: 1 = right, -1 = left
var _direction: int = 1
## Marker speed
var _speed: float = 1.5
## Whether the mini-game is active
var _active: bool = false
## Result quality
var _result_quality: int = Quality.NORMAL

@onready var bar: ColorRect = %Bar
@onready var marker: ColorRect = %Marker
@onready var zone: ColorRect = %Zone
@onready var silver_zone: ColorRect = %SilverZone
@onready var gold_zone: ColorRect = %GoldZone
@onready var iridium_zone: ColorRect = %IridiumZone
@onready var result_label: Label = %ResultLabel
@onready var instruction_label: Label = %InstructionLabel
@onready var timer_label: Label = %TimerLabel
@onready var close_button: Button = %CloseButton

func _ready() -> void:
	hide()
	if close_button:
		close_button.pressed.connect(_on_close)

## Try to start the minigame — returns false if the player can't afford it.
func try_start(_item_name: String = "Bread") -> bool:
	if GameManager.money < BAKE_COST:
		return false
	GameManager.add_money(-BAKE_COST)
	start_minigame()
	return true

func start_minigame(_item_name: String = "Bread") -> void:
	# Randomize difficulty
	_zone_width = 0.2 + randf() * 0.15  # 20-35% of bar
	_speed = 1.2 + randf() * 0.8  # 1.2-2.0 speed
	_marker_pos = 0.5
	_direction = 1 if randf() > 0.5 else -1
	_active = true
	_result_quality = Quality.BURNT
	_result_made = false
	
	instruction_label.text = "Press [SPACE / E] to bake! Hit the green zone."
	result_label.text = ""
	
	# Position the zone randomly on the bar
	var zone_center: float = 0.15 + randf() * 0.7  # 15-85% of bar
	zone.position.x = (zone_center - _zone_width / 2.0) * bar.size.x
	zone.size.x = _zone_width * bar.size.x
	_update_sub_zones()
	
	show()

func _update_sub_zones() -> void:
	## Position the quality tier sub-zones inside the main zone.
	var zx: float = zone.position.x
	var zw: float = zone.size.x
	var cx: float = zx + zw / 2.0  # center of zone
	
	var set_zone := func(rect: ColorRect, frac: float, color: Color) -> void:
		var w: float = zw * frac
		rect.position.x = cx - w / 2.0
		rect.size.x = w
		rect.color = color
		rect.visible = frac > 0.0
	
	set_zone.call(silver_zone, ZONE_SILVER_FRAC / ZONE_NORMAL_FRAC, Color(0.3, 0.6, 1.0, 0.45))
	set_zone.call(gold_zone, ZONE_GOLD_FRAC / ZONE_NORMAL_FRAC, Color(1.0, 0.85, 0.2, 0.5))
	set_zone.call(iridium_zone, ZONE_IRIDIUM_FRAC / ZONE_NORMAL_FRAC, Color(0.5, 1.0, 0.8, 0.55))

func _process(delta: float) -> void:
	if not _active:
		return
	
	# Move marker
	_marker_pos += _direction * _speed * delta
	if _marker_pos >= 1.0:
		_marker_pos = 1.0
		_direction = -1
	elif _marker_pos <= 0.0:
		_marker_pos = 0.0
		_direction = 1
	
	# Update marker visual
	marker.position.x = _marker_pos * bar.size.x - marker.size.x / 2.0

func _input(event: InputEvent) -> void:
	if not _active or not visible:
		return
	
	if event.is_action_pressed("till") or event.is_action_pressed("interact"):
		_finish_baking()
		accept_event()

func _finish_baking() -> void:
	_active = false
	
	# Calculate quality based on marker position relative to zone
	var marker_center: float = _marker_pos
	var zone_center_x: float = (zone.position.x + zone.size.x / 2.0) / bar.size.x
	var zone_start: float = zone.position.x / bar.size.x
	var zone_end: float = (zone.position.x + zone.size.x) / bar.size.x
	
	if marker_center >= zone_start and marker_center <= zone_end:
		# Hit the zone! Calculate how close to center
		var dist_to_center: float = abs(marker_center - zone_center_x)
		var max_dist: float = _zone_width / 2.0
		var accuracy: float = 1.0 - (dist_to_center / max_dist) if max_dist > 0 else 1.0
		
		if accuracy > 0.9:
			_result_quality = Quality.IRIDIUM
		elif accuracy > 0.7:
			_result_quality = Quality.GOLD
		elif accuracy > 0.5:
			_result_quality = Quality.SILVER
		else:
			_result_quality = Quality.NORMAL
	else:
		_result_quality = Quality.BURNT
	
	var color: Color = QUALITY_COLORS.get(_result_quality, Color.WHITE)
	var name_str: String = QUALITY_NAMES.get(_result_quality, "Unknown")
	result_label.text = name_str
	result_label.add_theme_color_override("font_color", color)
	
	# Mark result as made so Close button doesn't fire again
	_result_made = true
	
	# Emit result after a short delay
	get_tree().create_timer(1.0).timeout.connect(func():
		if is_instance_valid(self):
			baking_completed.emit(_result_quality)
			hide()
			queue_free()
	)

var _result_made: bool = false

func _on_close() -> void:
	_active = false
	if _result_made:
		# Baking already completed — emit the stored result immediately
		baking_completed.emit(_result_quality)
	else:
		baking_completed.emit(Quality.BURNT)
	queue_free()
