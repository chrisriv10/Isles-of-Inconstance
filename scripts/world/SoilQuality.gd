class_name SoilQuality
extends RefCounted

## Manages soil quality levels that affect crop growth speed and yield.
## Quality degrades over time without crop rotation or fertilizer.

enum QualityLevel {
	DEPLETED = 0,
	POOR = 1,
	AVERAGE = 2,
	GOOD = 3,
	RICH = 4,
	FERTILE = 5
}

const QUALITY_NAMES: Dictionary = {
	QualityLevel.DEPLETED: "Depleted",
	QualityLevel.POOR: "Poor",
	QualityLevel.AVERAGE: "Average",
	QualityLevel.GOOD: "Good",
	QualityLevel.RICH: "Rich",
	QualityLevel.FERTILE: "Fertile"
}

const GROWTH_MULTIPLIERS: Dictionary = {
	QualityLevel.DEPLETED: 0.4,
	QualityLevel.POOR: 0.6,
	QualityLevel.AVERAGE: 1.0,
	QualityLevel.GOOD: 1.3,
	QualityLevel.RICH: 1.6,
	QualityLevel.FERTILE: 2.0
}

const YIELD_MULTIPLIERS: Dictionary = {
	QualityLevel.DEPLETED: 0.5,
	QualityLevel.POOR: 0.75,
	QualityLevel.AVERAGE: 1.0,
	QualityLevel.GOOD: 1.2,
	QualityLevel.RICH: 1.5,
	QualityLevel.FERTILE: 2.0
}

var current_level: int = QualityLevel.AVERAGE

func _init(level: int = QualityLevel.AVERAGE) -> void:
	current_level = clampi(level, QualityLevel.DEPLETED, QualityLevel.FERTILE)

func get_growth_multiplier() -> float:
	return GROWTH_MULTIPLIERS.get(current_level, 1.0)

func get_yield_multiplier() -> float:
	return YIELD_MULTIPLIERS.get(current_level, 1.0)

func get_quality_name() -> String:
	return QUALITY_NAMES.get(current_level, "Average")

func improve(amount: int = 1) -> void:
	current_level = clampi(current_level + amount, QualityLevel.DEPLETED, QualityLevel.FERTILE)

func degrade(amount: int = 1) -> void:
	current_level = clampi(current_level - amount, QualityLevel.DEPLETED, QualityLevel.FERTILE)

func is_depleted() -> bool:
	return current_level <= QualityLevel.DEPLETED

func is_fertile() -> bool:
	return current_level >= QualityLevel.FERTILE

func apply_compost_boost() -> void:
	improve(2)  # Compost gives a big soil quality boost

func apply_fertilizer_boost() -> void:
	improve(3)  # Fertilizer gives even more

func serialize() -> Dictionary:
	return {"level": current_level}

static func deserialize(data: Dictionary) -> SoilQuality:
	return SoilQuality.new(data.get("level", QualityLevel.AVERAGE))
