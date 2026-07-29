class_name WeatherSystem
extends Node

## Weather system for Isles of Inconstance.
## Each day, a weather type is set: Clear, Rain, Storm, or Fog.
## Weather affects crop growth (rain auto-waters soil), player visibility,
## and enemy spawn rates.

enum WeatherType {
	CLEAR,
	RAIN,
	STORM,
	FOG,
}

signal weather_changed(new_weather: WeatherType)

var current_weather: WeatherType = WeatherType.CLEAR
var _days_remaining: int = 1
var _rng: RandomNumberGenerator

func _init() -> void:
	_rng = RandomNumberGenerator.new()
	current_weather = WeatherType.CLEAR
	_days_remaining = 1

func advance_day() -> void:
	_days_remaining -= 1
	if _days_remaining <= 0:
		_roll_new_weather()

## Roll a new weather event for the next period.
func _roll_new_weather() -> void:
	var roll: float = _rng.randf()
	
	# 60% clear, 25% rain, 10% storm, 5% fog
	if roll < 0.60:
		current_weather = WeatherType.CLEAR
	elif roll < 0.85:
		current_weather = WeatherType.RAIN
	elif roll < 0.95:
		current_weather = WeatherType.STORM
	else:
		current_weather = WeatherType.FOG
	
	_days_remaining = _rng.randi_range(1, 3)
	weather_changed.emit(current_weather)

func is_raining() -> bool:
	return current_weather == WeatherType.RAIN or current_weather == WeatherType.STORM

func is_storming() -> bool:
	return current_weather == WeatherType.STORM

func is_foggy() -> bool:
	return current_weather == WeatherType.FOG

func serialize() -> Dictionary:
	return {
		"current_weather": int(current_weather),
		"days_remaining": _days_remaining,
	}

func deserialize(data: Dictionary) -> void:
	if data.has("current_weather"):
		current_weather = data["current_weather"] as int
	if data.has("days_remaining"):
		_days_remaining = data["days_remaining"] as int

## Force-set the weather (used by Creative Panel)
func force_weather(weather: WeatherType) -> void:
	current_weather = weather
	_days_remaining = 3  # Give it some duration so it doesn't immediately reroll
	weather_changed.emit(current_weather)

## Auto-water all exposed tilled soil (called at day start when raining).

func apply_rain_watering(world: Node) -> void:
	if not is_raining():
		return
	if not world or not ("_soil_data" in world) or not ("ground_layer" in world):
		return
	
	var soil_data: Dictionary = world._soil_data
	var ground_layer = world.ground_layer
	var watered_tile := DataManager.get_tile_type("watered_tilled")
	var watered_count: int = 0
	
	for cell in soil_data:
		var soil = soil_data[cell]
		if soil.is_tilled and not soil.is_watered:
			soil.is_watered = true
			watered_count += 1
			if watered_tile:
				ground_layer.set_cell(cell, 0, watered_tile.atlas_coords)
	
	if watered_count > 0:
		ToastNotification.show_toast("Rain watered %d farm plots!" % watered_count, ToastNotification.ToastType.SUCCESS, 3.0)

## Storm increases enemy spawn rate.
func get_enemy_spawn_multiplier() -> float:
	match current_weather:
		WeatherType.STORM:
			return 2.0
		WeatherType.FOG:
			return 1.5
		WeatherType.RAIN:
			return 0.7  # enemies spawn less in rain
		_:
			return 1.0

## Fog reduces player vision radius on map.
func get_vision_penalty() -> int:
	if is_foggy():
		return -5
	return 0
