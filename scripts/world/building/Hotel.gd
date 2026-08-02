## Hotel — a passive-income building attached to the building node.
## When visitor NPCs are on the island, the hotel generates coins per guest.
## Player walks up to auto-collect accumulated earnings.
## Attached as a child node by BuildingSystem._setup_hotel() during placement.

extends Node
class_name Hotel

## Emitted when hotel guest count changes. The interior listens to this
## to spawn or clear NPC sprites in the hotel rooms.
signal guests_changed(count: int)

## How many coins each guest generates per night
const COINS_PER_GUEST_PER_NIGHT: int = 8

## How long (real seconds) between income ticks while guests are present
const INCOME_TICK_INTERVAL: float = 8.0

## How many coins per tick per guest
const COINS_PER_TICK_PER_GUEST: int = 2

## Number of ticks per guest booking — 4 ticks × 2 coins = 8 coins/guest total
const TICKS_PER_GUEST: int = 4

## How many guests are currently staying
var guest_count: int = 0

## Total uncollected coins earned
var earnings: int = 0

## Whether guests are currently checked in
var has_guests: bool = false

## Timer for periodic income generation
var _income_timer: Timer = null

## Reference to the building node's main sprite
var _building_sprite: Sprite2D = null

## The building node (parent)
var _building_node: Node2D = null

## Vacancy sign sprite child
var _sign_sprite: Sprite2D = null

## Remaining ticks for current guest batch
var _ticks_remaining: int = 0

func _ready() -> void:
	add_to_group("hotel_buildings")
	
	_building_node = get_parent() as Node2D
	if not _building_node:
		return
	
	# Find the building sprite (first Sprite2D child of parent)
	for child in _building_node.get_children():
		if child is Sprite2D and child != _sign_sprite:
			_building_sprite = child
			break
	
	# Create vacancy sign sprite
	_sign_sprite = Sprite2D.new()
	_sign_sprite.name = "HotelSign"
	var sign_tex: Texture2D = preload("res://assets/generated/hotel_sign_open_frame_0.png")
	if sign_tex:
		_sign_sprite.texture = sign_tex
	_sign_sprite.position = Vector2(0, -34)
	_sign_sprite.visible = false
	_sign_sprite.z_index = 6
	_building_node.add_child(_sign_sprite)
	
	# Create income timer
	_income_timer = Timer.new()
	_income_timer.name = "HotelIncomeTimer"
	_income_timer.one_shot = true
	_income_timer.timeout.connect(_on_income_tick)
	add_child(_income_timer)

## Called by VisitorManager when visitors arrive on the island.
func register_guests(count: int) -> void:
	if count <= 0:
		return
	# Stop any existing income timer from a previous guest batch
	if _income_timer and _income_timer.is_inside_tree():
		_income_timer.stop()
	guest_count = count
	has_guests = true
	
	# Show vacancy sign
	if _sign_sprite:
		_sign_sprite.visible = true
	
	# Notify interior to spawn NPCs
	guests_changed.emit(count)
	
	# Start income generation timer
	_ticks_remaining = TICKS_PER_GUEST
	_start_income_timer()
	
	# Visual: warm glow on building
	if _building_sprite:
		var tween := create_tween()
		tween.tween_property(_building_sprite, "modulate", Color(1.0, 0.95, 0.7), 0.5)
	
	# Toast notification
	ToastNotification.show_toast(
		"Hotel accepting %d guest(s)! Coins accumulating from visitors." % [count],
		ToastNotification.ToastType.INFO,
		3.0
	)

func _start_income_timer() -> void:
	if _income_timer and _income_timer.is_inside_tree() and _ticks_remaining > 0:
		_income_timer.wait_time = INCOME_TICK_INTERVAL
		_income_timer.start()

func _on_income_tick() -> void:
	if _ticks_remaining <= 0 or guest_count <= 0:
		return
	
	var earned: int = guest_count * COINS_PER_TICK_PER_GUEST
	earnings += earned
	_ticks_remaining -= 1
	
	# Visual feedback: brief pulse
	if _building_sprite:
		var tween := create_tween()
		tween.tween_property(_building_sprite, "modulate", Color(0.8, 1.0, 0.7), 0.15)
		tween.tween_property(_building_sprite, "modulate", Color(1.0, 0.95, 0.7), 0.3)
	
	# Coin particle effect
	if _building_node and _building_node.is_inside_tree():
		EffectSpawner.spawn_particles(
			_building_node.global_position + Vector2(0, -16),
			Color(1.0, 0.85, 0.15),
			3,
			6.0
		)
	
	if _ticks_remaining > 0:
		_start_income_timer()
	
	# Update sign visibility
	if _sign_sprite:
		_sign_sprite.visible = _ticks_remaining > 0 or earnings > 0

## Called when visitors depart — converts remaining ticks to instant earnings.
func clear_remaining_guests() -> void:
	if _income_timer and _income_timer.is_inside_tree():
		_income_timer.stop()
	
	while _ticks_remaining > 0 and guest_count > 0:
		earnings += guest_count * COINS_PER_TICK_PER_GUEST
		_ticks_remaining -= 1
	
	guest_count = 0
	has_guests = false
	
	# Notify interior to clear NPCs
	guests_changed.emit(0)
	
	if _sign_sprite:
		_sign_sprite.visible = earnings > 0
	
	if _building_sprite:
		var tween := create_tween()
		tween.tween_property(_building_sprite, "modulate", Color.WHITE, 0.5)

## Called by building area body_entered when player walks near.
## Returns true if earnings were collected.
func try_collect() -> bool:
	if earnings <= 0:
		return false
	
	var collected: int = earnings
	GameManager.add_money(collected)
	# Notify ObjectiveManager about hotel earnings
	var om_hotel := get_tree().get_first_node_in_group("objective_manager")
	if om_hotel and om_hotel.has_method("on_hotel_earned"):
		om_hotel.on_hotel_earned(collected)
	# Floating coin notification at the building
	if _building_node and _building_node.is_inside_tree():
		EffectSpawner.spawn_collect_notification(collected, _building_node.global_position + Vector2(0, -16))
	ToastNotification.show_toast(
		"Collected %d coins from hotel guests!" % [collected],
		ToastNotification.ToastType.SUCCESS,
		3.0
	)
	earnings = 0
	
	if _sign_sprite:
		_sign_sprite.visible = has_guests
	
	if _building_sprite:
		var tween := create_tween()
		tween.tween_property(_building_sprite, "modulate", Color(0.7, 1.0, 0.7), 0.2)
		tween.tween_property(_building_sprite, "modulate", Color.WHITE, 0.4)
	
	AudioManager.play(AudioManager.Sound.SELL)
	return true

## Return the world position of the hotel building so NPCs can path toward it.
func get_hotel_position() -> Vector2:
	if _building_node and _building_node.is_inside_tree():
		return _building_node.global_position
	return Vector2.ZERO

func get_earnings_display() -> String:
	if earnings > 0:
		return "%d coins ready to collect!" % [earnings]
	elif has_guests:
		return "Guests are staying... coins accumulating."
	else:
		return "No visitors have arrived yet. Wait for the visitor ship!"

func _exit_tree() -> void:
	if _income_timer and _income_timer.is_inside_tree():
		_income_timer.stop()