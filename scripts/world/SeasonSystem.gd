class_name SeasonSystem
extends RefCounted

## Manages seasonal cycles that affect crop growth, animal behavior, and visual
## appearance of the world. Each season lasts a configurable number of days.

enum Season {
	SPRING = 0,
	SUMMER = 1,
	AUTUMN = 2,
	WINTER = 3
}

const SEASON_NAMES: Dictionary = {
	Season.SPRING: "Spring",
	Season.SUMMER: "Summer",
	Season.AUTUMN: "Autumn",
	Season.WINTER: "Winter"
}

const SEASON_COLORS: Dictionary = {
	Season.SPRING: Color(0.7, 0.9, 0.6),
	Season.SUMMER: Color(0.5, 0.85, 0.3),
	Season.AUTUMN: Color(1.0, 0.6, 0.2),
	Season.WINTER: Color(0.85, 0.9, 1.0)
}

# Which seasons each crop prefers (tags match CropData tags)
var crop_season_preferences: Dictionary = {
	"spring": [Season.SPRING],
	"summer": [Season.SUMMER],
	"autumn": [Season.AUTUMN],
	"winter": [Season.WINTER],
	"all": [Season.SPRING, Season.SUMMER, Season.AUTUMN, Season.WINTER],
	"warm": [Season.SPRING, Season.SUMMER],
	"cool": [Season.AUTUMN, Season.WINTER],
	"arid": [Season.SUMMER],
	"wet": [Season.SPRING, Season.AUTUMN]
}

@export var days_per_season: int = 28
@export var current_season: int = Season.SPRING
@export var day_in_season: int = 1

var total_days: int = 0

signal season_changed(season: int, season_name: String)
signal day_in_season_changed(day: int)

func _init(seed_value: int = 0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	# Start in a random season if seeded
	current_season = rng.randi_range(Season.SPRING, Season.WINTER)

func advance_day() -> void:
	total_days += 1
	day_in_season += 1
	if day_in_season > days_per_season:
		day_in_season = 1
		current_season = (current_season + 1) % 4
		season_changed.emit(current_season, get_season_name())
	else:
		day_in_season_changed.emit(day_in_season)

func get_season_name() -> String:
	return SEASON_NAMES.get(current_season, "Spring")

func get_season_color() -> Color:
	return SEASON_COLORS.get(current_season, Color.WHITE)

func get_preferred_seasons(preference_tag: String) -> Array:
	return crop_season_preferences.get(preference_tag, [Season.SPRING, Season.SUMMER])

func is_season_favorable(preference_tag: String) -> bool:
	var preferred := get_preferred_seasons(preference_tag)
	return current_season in preferred

func get_growth_multiplier(preference_tag: String) -> float:
	if preference_tag == "" or not is_season_favorable(preference_tag):
		return 0.75  # slower in non-preferred seasons
	return 1.25  # faster in preferred seasons

func get_season_from_days(total: int) -> int:
	var season_cycle := total / days_per_season
	return season_cycle % 4

func get_day_in_season_from_days(total: int) -> int:
	return total % days_per_season + 1

func serialize() -> Dictionary:
	return {
		"current_season": current_season,
		"day_in_season": day_in_season,
		"total_days": total_days,
		"days_per_season": days_per_season
	}

static func deserialize(data: Dictionary) -> SeasonSystem:
	var ss := SeasonSystem.new()
	ss.current_season = data.get("current_season", Season.SPRING)
	ss.day_in_season = data.get("day_in_season", 1)
	ss.total_days = data.get("total_days", 0)
	ss.days_per_season = data.get("days_per_season", 28)
	return ss
