class_name DayNightCycle
extends RefCounted

## Complete day/night cycle system with smooth lighting transitions, sky colors,
## ambient light changes, and time-based gameplay effects.

# NOTE: GameManager has its own emit-ready time_changed and phase_changed signals.
# These were removed here since DayNightCycle is a pure-computation RefCounted utility
# that never emits signals — all time/phase events go through GameManager.

enum Phase { DAWN = 0, DAY = 1, DUSK = 2, NIGHT = 3 }

const PHASE_NAMES: Dictionary = {
	Phase.DAWN: "Dawn",
	Phase.DAY: "Day",
	Phase.DUSK: "Dusk",
	Phase.NIGHT: "Night"
}

# Sky colors for each phase (top, bottom)
const SKY_COLORS: Dictionary = {
	Phase.DAWN: {
		"top": Color(0.4, 0.2, 0.5),
		"bottom": Color(0.9, 0.5, 0.2),
		"horizon": Color(0.95, 0.6, 0.3)
	},
	Phase.DAY: {
		"top": Color(0.2, 0.4, 0.8),
		"bottom": Color(0.5, 0.7, 1.0),
		"horizon": Color(0.6, 0.8, 1.0)
	},
	Phase.DUSK: {
		"top": Color(0.3, 0.15, 0.4),
		"bottom": Color(0.8, 0.3, 0.1),
		"horizon": Color(0.9, 0.5, 0.2)
	},
	Phase.NIGHT: {
		"top": Color(0.02, 0.02, 0.06),
		"bottom": Color(0.05, 0.05, 0.1),
		"horizon": Color(0.1, 0.08, 0.12)
	}
}

# Darkness alpha per phase
const DARKNESS: Dictionary = {
	Phase.DAWN: 0.15,
	Phase.DAY: 0.0,
	Phase.DUSK: 0.35,
	Phase.NIGHT: 0.7
}

# Ambient light energy per phase
const AMBIENT_LIGHT: Dictionary = {
	Phase.DAWN: 0.6,
	Phase.DAY: 1.0,
	Phase.DUSK: 0.35,
	Phase.NIGHT: 0.1
}

# Shadow strength per phase
const SHADOW_STRENGTH: Dictionary = {
	Phase.DAWN: 0.3,
	Phase.DAY: 0.8,
	Phase.DUSK: 0.4,
	Phase.NIGHT: 0.05
}



var current_phase: int = Phase.DAY

## Set to true during blood moon events to tint the night overlay dark red.
var blood_moon_active: bool = false

func get_phase_for_hour(hour: int) -> int:
	if hour >= 5 and hour < 7:
		return Phase.DAWN
	elif hour >= 7 and hour < 18:
		return Phase.DAY
	elif hour >= 18 and hour < 20:
		return Phase.DUSK
	else:
		return Phase.NIGHT

func get_phase_name(phase: int = -1) -> String:
	if phase == -1:
		phase = current_phase
	return PHASE_NAMES.get(phase, "Day")

func get_darkness(hour: int) -> float:
	var phase: int = get_phase_for_hour(hour)
	var base: float = DARKNESS.get(phase, 0.0)
	
	# Interpolate during transitions
	match phase:
		Phase.DAWN:
			var progress := (hour - 5) / 2.0
			return lerpf(DARKNESS[Phase.NIGHT], DARKNESS[Phase.DAY], clampf(progress, 0.0, 1.0))
		Phase.DUSK:
			var progress := (hour - 18) / 2.0
			return lerpf(DARKNESS[Phase.DAY], DARKNESS[Phase.NIGHT], clampf(progress, 0.0, 1.0))
		_:
			return base

func get_sky_color(hour: int) -> Color:
	var phase: int = get_phase_for_hour(hour)
	var color_dict: Dictionary = SKY_COLORS.get(phase, SKY_COLORS[Phase.DAY])
	
	# Blend between phases during transitions
	if phase == Phase.DAWN:
		var progress: float = (hour - 5) / 2.0
		var night_colors: Dictionary = SKY_COLORS[Phase.NIGHT]
		return Color(
			lerpf(night_colors.top.r, color_dict.top.r, progress),
			lerpf(night_colors.top.g, color_dict.top.g, progress),
			lerpf(night_colors.top.b, color_dict.top.b, progress),
			1.0
		)
	elif phase == Phase.DUSK:
		var progress: float = (hour - 18) / 2.0
		var night_colors: Dictionary = SKY_COLORS[Phase.NIGHT]
		return Color(
			lerpf(color_dict.top.r, night_colors.top.r, progress),
			lerpf(color_dict.top.g, night_colors.top.g, progress),
			lerpf(color_dict.top.b, night_colors.top.b, progress),
			1.0
		)
	
	return color_dict.horizon

## Returns overlay color for the day/night overlay
func get_overlay_color(hour: int) -> Color:
	var darkness := get_darkness(hour)
	var phase := get_phase_for_hour(hour)
	
	var tint: Color
	match phase:
		Phase.DAWN:
			tint = Color(0.6, 0.45, 0.25, darkness * 0.5)
		Phase.DUSK:
			tint = Color(0.7, 0.4, 0.15, darkness)
		Phase.NIGHT:
			if blood_moon_active:
				tint = Color(0.15, 0.01, 0.01, minf(darkness + 0.05, 1.0))
			else:
				tint = Color(0.02, 0.02, 0.12, darkness)
		_:
			tint = Color(0.0, 0.0, 0.0, 0.0)
	
	return tint

## Check if it's currently night time
func is_night() -> bool:
	return current_phase == Phase.NIGHT

## Get ambient light energy based on time of day
func get_ambient_energy(hour: int) -> float:
	var phase := get_phase_for_hour(hour)
	return AMBIENT_LIGHT.get(phase, 1.0)

## Get shadow strength based on time of day
func get_shadow_strength(hour: int) -> float:
	var phase := get_phase_for_hour(hour)
	return SHADOW_STRENGTH.get(phase, 0.5)
