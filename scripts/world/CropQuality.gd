class_name CropQuality
extends RefCounted

## Determines crop quality tiers (normal, silver star, gold star) based on
## soil quality, season alignment, fertilizer use, and watering consistency.
## Higher quality crops yield more when sold or provide better ingredients.

enum QualityTier {
	NORMAL = 0,
	SILVER = 1,
	GOLD = 2,
	IRIDIUM = 3
}

const QUALITY_NAMES: Dictionary = {
	QualityTier.NORMAL: "",
	QualityTier.SILVER: "★",
	QualityTier.GOLD: "★★",
	QualityTier.IRIDIUM: "★★★"
}

const QUALITY_LABELS: Dictionary = {
	QualityTier.NORMAL: "",
	QualityTier.SILVER: "Silver",
	QualityTier.GOLD: "Gold",
	QualityTier.IRIDIUM: "Iridium"
}

const SELL_PRICE_MULTIPLIERS: Dictionary = {
	QualityTier.NORMAL: 1.0,
	QualityTier.SILVER: 1.25,
	QualityTier.GOLD: 1.5,
	QualityTier.IRIDIUM: 2.0
}

## Calculate final quality tier based on growing conditions
static func calculate_quality(
	soil_level: int,           # SoilQuality.current_level (0-5)
	fertilizer_was_used: bool, # Was fertilizer active?
	watered_every_day: bool,   # Was crop watered every day?
	season_favorable: bool,    # Is this crop's preferred season?
	growth_days: int,          # Days the crop actually grew
	required_days: int,         # Days required to mature
	rng: RandomNumberGenerator
) -> int:
	var score := 0
	
	# Soil contribution (0-5)
	score += soil_level
	
	# Fertilizer bonus
	if fertilizer_was_used:
		score += 2
	
	# Watering bonus
	if watered_every_day:
		score += 2
	elif growth_days > 0:
		# Partial watering gives partial credit
		var watered_ratio := float(growth_days) / float(maxi(required_days, 1))
		if watered_ratio > 0.5:
			score += 1
	
	# Season bonus
	if season_favorable:
		score += 2
	
	# Slight randomness
	score += rng.randi_range(-1, 1)
	
	# Convert score to tier
	if score >= 10:
		return QualityTier.IRIDIUM
	elif score >= 7:
		return QualityTier.GOLD
	elif score >= 4:
		return QualityTier.SILVER
	else:
		return QualityTier.NORMAL

static func get_tier_name(tier: int) -> String:
	return QUALITY_LABELS.get(tier, "")

static func get_tier_suffix(tier: int) -> String:
	return QUALITY_NAMES.get(tier, "")

static func get_price_multiplier(tier: int) -> float:
	return SELL_PRICE_MULTIPLIERS.get(tier, 1.0)
