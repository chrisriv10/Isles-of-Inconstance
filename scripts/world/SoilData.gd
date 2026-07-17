class_name SoilData
extends RefCounted

## Expanded soil data with quality, disease tracking, fertilizer system.
## Each tilled tile in the world has one of these.

var is_tilled: bool = false
var is_watered: bool = false
var is_composted: bool = false  # Legacy field, kept for save compat
var crop_id: String = ""
var days_grown: int = 0
## How many consecutive days a water-requiring crop has gone without water.
## Once this hits 2, the crop shows a wilted visual. At 3+, it stops growing.
var unwatered_days: int = 0

# New farming expansion fields
var soil_quality: SoilQuality = null
var disease: CropDisease = null
var fertilizer: FertilizerSystem = null
var season_tag: String = "all"  # crop season preference tag
var quality_level: int = 1  # 0=normal, 1=silver_star, 2=gold_star crop quality
var is_giant_crop: bool = false
var has_mutation: bool = false
var mutation_name: String = ""
var days_since_harvest: int = 0

func _init() -> void:
    soil_quality = SoilQuality.new()
    disease = CropDisease.new()
    fertilizer = FertilizerSystem.new()

func get_effective_growth_boost() -> float:
    var boost := 1.0
    if soil_quality:
        boost *= soil_quality.get_growth_multiplier()
    if fertilizer and fertilizer.is_active():
        boost *= fertilizer.get_growth_boost()
    if is_composted:
        boost *= 1.5
    return boost

func get_effective_yield_boost() -> float:
    var boost := 1.0
    if soil_quality:
        boost *= soil_quality.get_yield_multiplier()
    if is_giant_crop:
        boost *= 3.0
    if disease and disease.is_infected():
        boost *= disease.get_yield_penalty()
    return boost

func apply_compost() -> void:
    is_composted = true
    if soil_quality:
        soil_quality.apply_compost_boost()
    if disease:
        disease.apply_compost_benefit()

func apply_fertilizer(ftype: int, duration: int) -> void:
    if not fertilizer:
        fertilizer = FertilizerSystem.new()
    fertilizer.apply(ftype, duration)
    if soil_quality:
        soil_quality.improve(fertilizer.get_soil_improvement())

func advance_daily() -> void:
    # Soil dries
    is_watered = false
    
    # Compost effect decays
    if is_composted:
        is_composted = false  # one-time boost consumed
    
    # Fertilizer decays
    if fertilizer:
        fertilizer.advance_day()
    
    # Disease progresses if present
    if disease and disease.is_infected():
        var sq_level := 2  # default average
        if soil_quality:
            sq_level = soil_quality.current_level
        disease.advance_disease(sq_level)
    
    # Soil quality slowly degrades if cropped
    if crop_id != "" and days_grown > 0 and soil_quality:
        if randi() % 10 == 0:  # 10% chance per day
            soil_quality.degrade(1)

func serialize() -> Dictionary:
    var data := {
        "is_tilled": is_tilled,
        "is_watered": is_watered,
        "is_composted": is_composted,
        "crop_id": crop_id,
        "days_grown": days_grown,
        "unwatered_days": unwatered_days,
        "quality_level": quality_level,
        "is_giant_crop": is_giant_crop,
        "has_mutation": has_mutation,
        "mutation_name": mutation_name,
        "days_since_harvest": days_since_harvest
    }
    if soil_quality:
        data["soil_quality"] = soil_quality.serialize()
    if disease and disease.is_infected():
        data["disease"] = disease.serialize()
    if fertilizer and fertilizer.is_active():
        data["fertilizer"] = fertilizer.serialize()
    return data

static func deserialize(data: Dictionary) -> SoilData:
    var soil := SoilData.new()
    soil.is_tilled = data.get("is_tilled", false)
    soil.is_watered = data.get("is_watered", false)
    soil.is_composted = data.get("is_composted", false)
    soil.crop_id = data.get("crop_id", "")
    soil.days_grown = data.get("days_grown", 0)
    soil.unwatered_days = data.get("unwatered_days", 0)
    soil.quality_level = data.get("quality_level", 1)
    soil.is_giant_crop = data.get("is_giant_crop", false)
    soil.has_mutation = data.get("has_mutation", false)
    soil.mutation_name = data.get("mutation_name", "")
    soil.days_since_harvest = data.get("days_since_harvest", 0)
    
    if data.has("soil_quality"):
        soil.soil_quality = SoilQuality.deserialize(data["soil_quality"])
    if data.has("disease"):
        soil.disease = CropDisease.deserialize(data["disease"])
    if data.has("fertilizer"):
        soil.fertilizer = FertilizerSystem.deserialize(data["fertilizer"])
    
    return soil
