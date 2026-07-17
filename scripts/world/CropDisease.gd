class_name CropDisease
extends RefCounted

## Optional disease/pest system that adds risk and depth to farming.
## Diseases can spread between adjacent crops and reduce yield/growth.
## Balanced so experienced farmers can manage them without frustration.

enum DiseaseType {
	NONE = -1,
	BLIGHT = 0,
	ROOT_ROT = 1,
	APHDIS = 2,
	MILDEW = 3,
	WILT = 4
}

const DISEASE_NAMES: Dictionary = {
	DiseaseType.BLIGHT: "Blight",
	DiseaseType.ROOT_ROT: "Root Rot",
	DiseaseType.APHDIS: "Aphids",
	DiseaseType.MILDEW: "Powdery Mildew",
	DiseaseType.WILT: "Wilt"
}

const DISEASE_COLORS: Dictionary = {
	DiseaseType.BLIGHT: Color(0.4, 0.2, 0.1),
	DiseaseType.ROOT_ROT: Color(0.5, 0.35, 0.2),
	DiseaseType.APHDIS: Color(0.6, 0.7, 0.3),
	DiseaseType.MILDEW: Color(0.8, 0.75, 0.7),
	DiseaseType.WILT: Color(0.5, 0.4, 0.3)
}

const GROWTH_PENALTIES: Dictionary = {
	DiseaseType.BLIGHT: 0.3,
	DiseaseType.ROOT_ROT: 0.4,
	DiseaseType.APHDIS: 0.25,
	DiseaseType.MILDEW: 0.35,
	DiseaseType.WILT: 0.5
}

const YIELD_PENALTIES: Dictionary = {
	DiseaseType.BLIGHT: 0.4,
	DiseaseType.ROOT_ROT: 0.5,
	DiseaseType.APHDIS: 0.3,
	DiseaseType.MILDEW: 0.6,
	DiseaseType.WILT: 0.7
}

# Disease resistance tags crops can have
const RESISTANCE_TAGS: Dictionary = {
	"hardy": 0.3,     # 30% less chance
	"robust": 0.5,    # 50% less
	"crystalline": 0.7, # 70% less
	"fungal": -0.3,   # 30% more (fungal crops attract disease)
}

var disease_type: int = DiseaseType.NONE
var severity: float = 0.0  # 0.0 to 1.0
var days_infected: int = 0

func _init() -> void:
	pass

func is_infected() -> bool:
	return disease_type != DiseaseType.NONE

func get_disease_name() -> String:
	return DISEASE_NAMES.get(disease_type, "")

func get_disease_color() -> Color:
	return DISEASE_COLORS.get(disease_type, Color.WHITE)

func get_growth_penalty() -> float:
	if not is_infected():
		return 1.0
	var penalty: float = GROWTH_PENALTIES.get(disease_type, 0.5)
	return 1.0 - (penalty * severity)

func get_yield_penalty() -> float:
	if not is_infected():
		return 1.0
	var penalty: float = YIELD_PENALTIES.get(disease_type, 0.5)
	return 1.0 - (penalty * severity)

## Roll for disease infection. Returns true if infected.
## chance: base probability 0.0-1.0
## resistance_tags: array of crop trait tags
func try_infect(chance: float, resistance_tags: Array = []) -> bool:
	if is_infected():
		return false
	
	# Apply resistance modifiers
	var modified_chance := chance
	for tag in resistance_tags:
		if RESISTANCE_TAGS.has(tag):
			modified_chance *= (1.0 - RESISTANCE_TAGS[tag])
	
	modified_chance = clampf(modified_chance, 0.0, 0.8)
	
	if randf() < modified_chance:
		disease_type = randi() % 5  # 0-4 (skip NONE=-1)
		severity = randf_range(0.1, 0.5)
		days_infected = 0
		return true
	return false

func advance_disease(soil_quality: int) -> void:
	if not is_infected():
		return
	days_infected += 1
	# Disease progresses faster in poor soil
	var progression_rate := 0.02
	if soil_quality < 2:  # Poor or depleted
		progression_rate = 0.05
	elif soil_quality > 3:  # Rich or fertile
		progression_rate = 0.005  # Almost no progression
	severity = minf(1.0, severity + progression_rate)

func cure() -> void:
	disease_type = DiseaseType.NONE
	severity = 0.0
	days_infected = 0

func apply_compost_benefit() -> void:
	# Compost helps cure disease
	if is_infected():
		severity = maxf(0.0, severity - 0.3)
		if severity <= 0.0:
			cure()

func serialize() -> Dictionary:
	return {
		"disease_type": disease_type,
		"severity": severity,
		"days_infected": days_infected
	}

static func deserialize(data: Dictionary) -> CropDisease:
	var cd := CropDisease.new()
	cd.disease_type = data.get("disease_type", DiseaseType.NONE)
	cd.severity = data.get("severity", 0.0)
	cd.days_infected = data.get("days_infected", 0)
	return cd
