extends Node

## Autoload singleton. Owns global game state that many systems care about:
## the day/time cycle, currency, and pause state. Systems subscribe to the
## signals below instead of polling, which keeps them decoupled.

signal day_changed(day: int)
signal time_changed(hour: int, minute: int)
signal money_changed(amount: int)
signal game_paused(is_paused: bool)
signal crop_mutated(old_name: String, new_name: String, mutation_name: String)

@export var minutes_per_day: int = 24 * 60
@export var real_seconds_per_game_minute: float = 0.5

var current_day: int = 1
var current_minute_of_day: int = 6 * 60  # start at 06:00
var money: int = 500
var is_paused: bool = false

var _minute_timer: float = 0.0

func _process(delta: float) -> void:
	if is_paused:
		return
	_minute_timer += delta
	if _minute_timer >= real_seconds_per_game_minute:
		_minute_timer = 0.0
		_advance_minute()

func _advance_minute() -> void:
	current_minute_of_day += 1
	if current_minute_of_day >= minutes_per_day:
		current_minute_of_day = 0
		current_day += 1
		day_changed.emit(current_day)
		# Auto-save on day change
		SaveManager.save_game()
	time_changed.emit(get_hour(), get_minute())

func get_hour() -> int:
	return current_minute_of_day / 60

func get_minute() -> int:
	return current_minute_of_day % 60

func get_time_string() -> String:
	return "%02d:%02d" % [get_hour(), get_minute()]

## Set time directly (for save/load)
func set_time(hour: int, minute: int) -> void:
	current_minute_of_day = hour * 60 + minute
	time_changed.emit(get_hour(), get_minute())

func add_money(amount: int) -> void:
	money = max(0, money + amount)
	money_changed.emit(money)

func can_afford(amount: int) -> bool:
	return money >= amount

## Convenience wrapper for purchases: only deducts if affordable.
## Returns true if the purchase went through.
func spend_money(amount: int) -> bool:
	if amount <= 0:
		return true
	if not can_afford(amount):
		return false
	add_money(-amount)
	return true

func set_paused(paused: bool) -> void:
	is_paused = paused
	game_paused.emit(is_paused)
