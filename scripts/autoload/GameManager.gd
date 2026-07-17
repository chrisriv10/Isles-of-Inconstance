extends Node

## Autoload singleton. Owns global game state that many systems care about:
## the day/time cycle, currency, and pause state. Systems subscribe to the
## signals below instead of polling, which keeps them decoupled.

signal day_changed(day: int)
signal time_changed(hour: int, minute: int)
signal money_changed(amount: int)
signal game_paused(is_paused: bool)
@warning_ignore("unused_signal")
signal crop_mutated(old_name: String, new_name: String, mutation_name: String)
signal season_changed(season: int, season_name: String)
signal phase_changed(phase: int)

@export var minutes_per_day: int = 24 * 60
@export var real_seconds_per_game_minute: float = 0.5

var current_day: int = 1
var current_minute_of_day: int = 6 * 60  # start at 06:00
var money: int = 500
var is_paused: bool = false

# Season system
var season_system: SeasonSystem = null
var day_night: DayNightCycle = null

var _minute_timer: float = 0.0

func _ready() -> void:
	day_night = DayNightCycle.new()

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
		
		# Advance season too
		if season_system:
			var old_season := season_system.current_season
			season_system.advance_day()
			if season_system.current_season != old_season:
				season_changed.emit(season_system.current_season, season_system.get_season_name())
		
		day_changed.emit(current_day)
		# Auto-save on day change
		SaveManager.save_game()
	
	var hour := get_hour()
	var minute := get_minute()
	time_changed.emit(hour, minute)
	
	if day_night:
		var new_phase := day_night.get_phase_for_hour(hour)
		if new_phase != day_night.current_phase:
			day_night.current_phase = new_phase
			phase_changed.emit(new_phase)

func get_hour() -> int:
	return floori(current_minute_of_day / 60.0)

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

## Get current season info
func get_season_name() -> String:
	if season_system:
		return season_system.get_season_name()
	return "Spring"

func get_season_phase() -> int:
	if day_night:
		return day_night.current_phase
	return DayNightCycle.Phase.DAY

func is_night() -> bool:
	if day_night:
		return day_night.is_night()
	return false
