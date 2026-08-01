extends CanvasLayer

## Full-screen sky gradient behind the world, driven by the day/night cycle.
## Polls GameManager each frame (cheap comparison) and only re-uploads the
## shader uniforms when the hour or phase actually changes.

var _material: ShaderMaterial = null
var _last_hour: int = -1
var _last_phase: int = -1

func _ready() -> void:
	layer = -10
	var rect := get_node_or_null("SkyRect") as ColorRect
	if rect:
		_material = rect.material as ShaderMaterial
	_update_colors()

func _process(_delta: float) -> void:
	var dnc: DayNightCycle = GameManager.day_night
	if dnc == null:
		return
	var hour := GameManager.get_hour()
	var phase := dnc.get_phase_for_hour(hour)
	if hour == _last_hour and phase == _last_phase:
		return
	_last_hour = hour
	_last_phase = phase
	_update_colors()

func _update_colors() -> void:
	if _material == null:
		return
	var dnc: DayNightCycle = GameManager.day_night
	if dnc == null:
		return
	var colors := _sky_colors_for_hour(dnc, GameManager.get_hour())
	_material.set_shader_parameter("top_color", colors.top)
	_material.set_shader_parameter("bottom_color", colors.bottom)

func _sky_colors_for_hour(dnc: DayNightCycle, hour: int) -> Dictionary:
	var phase := dnc.get_phase_for_hour(hour)
	var colors: Dictionary = dnc.SKY_COLORS[phase]
	var night: Dictionary = dnc.SKY_COLORS[DayNightCycle.Phase.NIGHT]
	match phase:
		DayNightCycle.Phase.DAWN:
			var progress := clampf((hour - 5) / 2.0, 0.0, 1.0)
			return {
				"top": night.top.lerp(colors.top, progress),
				"bottom": night.horizon.lerp(colors.horizon, progress),
			}
		DayNightCycle.Phase.DUSK:
			var progress := clampf((hour - 18) / 2.0, 0.0, 1.0)
			return {
				"top": colors.top.lerp(night.top, progress),
				"bottom": colors.horizon.lerp(night.horizon, progress),
			}
	return {"top": colors.top, "bottom": colors.horizon}
