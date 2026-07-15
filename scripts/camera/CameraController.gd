extends Camera2D
class_name CameraController

## Simple smoothed 2D camera. Kept as its own script (rather than default
## Camera2D settings) so zoom, shake, or bounds-following can be added later
## without touching Player.gd.

@export var zoom_level: float = 4.0
@export var smoothing_enabled: bool = true
@export var smoothing_speed: float = 5.0

func _ready() -> void:
	zoom = Vector2(zoom_level, zoom_level)
	position_smoothing_enabled = smoothing_enabled
	position_smoothing_speed = smoothing_speed
	make_current()

## Placeholder hook for a future screen-shake system.
func shake(_strength: float = 4.0, _duration: float = 0.2) -> void:
	pass
