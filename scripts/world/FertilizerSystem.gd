class_name FertilizerSystem
extends RefCounted

## Manages different fertilizer types that players can craft or buy to boost
## crop growth, soil quality, disease resistance, and yield.

enum FertilizerType {
	NONE = -1,
	BASIC_COMPOST = 0,
	QUALITY_COMPOST = 1,
	GROWTH_BOOSTER = 2,
	YIELD_ENHANCER = 3,
	RICH_FERTILIZER = 4,
	SUPER_FERTILIZER = 5
}

const FERTILIZER_DATA: Dictionary = {
	FertilizerType.BASIC_COMPOST: {
		"name": "Basic Compost",
		"item_id": "compost",
		"growth_boost": 1.5,
		"soil_improvement": 1,
		"disease_resistance": 0.1,
		"duration_days": 3,
		"color": Color(0.5, 0.35, 0.2)
	},
	FertilizerType.QUALITY_COMPOST: {
		"name": "Quality Compost",
		"item_id": "quality_compost",
		"growth_boost": 2.0,
		"soil_improvement": 2,
		"disease_resistance": 0.2,
		"duration_days": 5,
		"color": Color(0.4, 0.3, 0.15)
	},
	FertilizerType.GROWTH_BOOSTER: {
		"name": "Growth Booster",
		"item_id": "growth_booster",
		"growth_boost": 2.5,
		"soil_improvement": 1,
		"disease_resistance": 0.0,
		"duration_days": 4,
		"color": Color(0.2, 0.8, 0.4)
	},
	FertilizerType.YIELD_ENHANCER: {
		"name": "Yield Enhancer",
		"item_id": "yield_enhancer",
		"growth_boost": 1.0,
		"soil_improvement": 1,
		"disease_resistance": 0.3,
		"duration_days": 6,
		"color": Color(0.9, 0.7, 0.2)
	},
	FertilizerType.RICH_FERTILIZER: {
		"name": "Rich Fertilizer",
		"item_id": "rich_fertilizer",
		"growth_boost": 2.0,
		"soil_improvement": 3,
		"disease_resistance": 0.4,
		"duration_days": 7,
		"color": Color(0.6, 0.3, 0.1)
	},
	FertilizerType.SUPER_FERTILIZER: {
		"name": "Super Fertilizer",
		"item_id": "super_fertilizer",
		"growth_boost": 3.0,
		"soil_improvement": 4,
		"disease_resistance": 0.6,
		"duration_days": 10,
		"color": Color(0.8, 0.2, 0.8)
	}
}

var fertilizer_type: int = FertilizerType.NONE
var remaining_days: int = 0

func _init() -> void:
	pass

func is_active() -> bool:
	return fertilizer_type != FertilizerType.NONE and remaining_days > 0

func get_name() -> String:
	var data: Dictionary = FERTILIZER_DATA.get(fertilizer_type, {})
	return data.get("name", "")

func get_growth_boost() -> float:
	if not is_active():
		return 1.0
	var data: Dictionary = FERTILIZER_DATA.get(fertilizer_type, {})
	return data.get("growth_boost", 1.0)

func get_soil_improvement() -> int:
	if not is_active():
		return 0
	var data: Dictionary = FERTILIZER_DATA.get(fertilizer_type, {})
	return data.get("soil_improvement", 0)

func get_disease_resistance() -> float:
	if not is_active():
		return 0.0
	var data: Dictionary = FERTILIZER_DATA.get(fertilizer_type, {})
	return data.get("disease_resistance", 0.0)

func get_color() -> Color:
	var data: Dictionary = FERTILIZER_DATA.get(fertilizer_type, {})
	return data.get("color", Color.WHITE)

func apply(ftype: int, duration: int) -> void:
	fertilizer_type = ftype
	remaining_days = duration

func advance_day() -> void:
	if is_active():
		remaining_days -= 1
		if remaining_days <= 0:
			fertilizer_type = FertilizerType.NONE
			remaining_days = 0

func serialize() -> Dictionary:
	return {
		"fertilizer_type": fertilizer_type,
		"remaining_days": remaining_days
	}

static func deserialize(data: Dictionary) -> FertilizerSystem:
	var fs := FertilizerSystem.new()
	fs.fertilizer_type = data.get("fertilizer_type", FertilizerType.NONE)
	fs.remaining_days = data.get("remaining_days", 0)
	return fs
