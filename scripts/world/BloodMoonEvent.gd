class_name BloodMoonEvent
extends Node

## Blood Moon Event for Isles of Inconstance.
## Randomly triggers on some nights, turning the sky dark red and
## increasing enemy spawns dramatically. Alerts the player to take shelter.

signal blood_moon_started()
signal blood_moon_ended()

const BLOOD_MOON_CHANCE: float = 0.15  # 15% chance each night
const TRIGGER_HOUR_MIN: int = 20  # Earliest hour it can trigger (8 PM)
const TRIGGER_HOUR_MAX: int = 2   # Latest hour it can trigger (2 AM, wraps past midnight)

var is_active: bool = false
var _rng: RandomNumberGenerator


func _init() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.randomize()


func _ready() -> void:
	GameManager.phase_changed.connect(_on_phase_changed)


func _on_phase_changed(phase: int) -> void:
	match phase:
		DayNightCycle.Phase.NIGHT:
			_try_trigger()
		DayNightCycle.Phase.DAWN:
			_end_blood_moon()


## Roll the dice and start a blood moon if the RNG gods decree it.
func _try_trigger() -> void:
	if is_active:
		return
	
	if _rng.randf() < BLOOD_MOON_CHANCE:
		_start_blood_moon()


func _start_blood_moon() -> void:
	is_active = true
	
	# Tell the day/night system to tint the overlay red
	if GameManager.day_night:
		GameManager.day_night.blood_moon_active = true
	
	# Alert the player
	ToastNotification.show_toast(
		"🌕 BLOOD MOON RISING! Seek shelter!",
		ToastNotification.ToastType.WARNING,
		6.0
	)
	
	blood_moon_started.emit()


func _end_blood_moon() -> void:
	if not is_active:
		return
	
	is_active = false
	
	# Restore normal night tint
	if GameManager.day_night:
		GameManager.day_night.blood_moon_active = false
	
	ToastNotification.show_toast(
		"🌅 The blood moon fades...",
		ToastNotification.ToastType.INFO,
		4.0
	)
	
	blood_moon_ended.emit()


## Public method to force-trigger a blood moon (used by Creative Panel).
func trigger_blood_moon() -> void:
	if not is_active:
		_start_blood_moon()


# ── Save / Load ──

func serialize() -> Dictionary:
	return {
		"is_active": is_active,
	}


func deserialize(data: Dictionary) -> void:
	if data.has("is_active"):
		is_active = data["is_active"] as bool
		# If we loaded with an active blood moon, restore the visual state
		if is_active and GameManager.day_night:
			GameManager.day_night.blood_moon_active = true
