extends Camera2D
class_name CameraController

## Simple smoothed 2D camera. Kept as its own script (rather than default
## Camera2D settings) so zoom, shake, or bounds-following can be added later
## without touching Player.gd.

@export var zoom_level: float = 4.0
@export var smoothing_enabled: bool = true
@export var smoothing_speed: float = 20.0

var _shake_tween: Tween
var _punch_tween: Tween

func _ready() -> void:
	zoom = Vector2(zoom_level, zoom_level)
	position_smoothing_enabled = smoothing_enabled
	position_smoothing_speed = smoothing_speed
	make_current()

## Shake the camera with given strength and duration
func shake(strength: float = 4.0, duration: float = 0.2) -> void:
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
	
	_shake_tween = create_tween()
	_shake_tween.set_parallel(true)
	
	var shake_count := floori(duration * 60.0)  # 60 shakes per second
	
	for i in range(shake_count):
		var delay := float(i) / float(shake_count) * duration
		var shake_vector := Vector2(
			randf_range(-strength, strength),
			randf_range(-strength, strength)
		)
		_shake_tween.tween_property(self, "offset", shake_vector, 0.016).set_delay(delay)
	
	_shake_tween.tween_property(self, "offset", Vector2.ZERO, 0.05).set_delay(duration)

## Punch the camera in a direction (for impact feedback)
func punch(direction: Vector2, strength: float = 8.0, duration: float = 0.15) -> void:
	if _punch_tween and _punch_tween.is_valid():
		_punch_tween.kill()
	
	var target_offset := direction.normalized() * strength
	_punch_tween = create_tween()
	_punch_tween.set_ease(Tween.EASE_OUT)
	_punch_tween.set_trans(Tween.TRANS_BACK)
	_punch_tween.tween_property(self, "offset", target_offset, duration * 0.5)
	_punch_tween.tween_property(self, "offset", Vector2.ZERO, duration * 0.5)
