extends Node
class_name UITweenHelper

## Drop-in UI polish: Add smooth open/close animations to any Control node.
## 
## Usage:
##   Option 1: Attach this script to any Panel/Control node you want to animate
##   Option 2: Call static functions from anywhere:
##     UITweenHelper.animate_open(my_panel)
##     UITweenHelper.animate_close(my_panel, 0.3)
##
## Features:
##   - Slide + fade in/out effects
##   - Configurable duration and offset
##   - Works with any Control node (PanelContainer, ColorRect, etc.)

@export var open_duration: float = 0.25
@export var close_duration: float = 0.2
@export var slide_offset: float = 20.0
@export var use_slide: bool = true
@export var use_fade: bool = true
@export var easing: Tween.EaseType = Tween.EASE_OUT
@export var transition_type: Tween.TransitionType = Tween.TRANS_CUBIC

var _tween: Tween
var _original_position: Vector2

func _ready() -> void:
	if is_instance_valid(get_parent()) and get_parent() is Control:
		_original_position = get_parent().position

## Static helper: Animate a panel opening (slide + fade in)
static func animate_open(panel: Control, duration: float = 0.25, offset: float = 20.0) -> void:
	if not is_instance_valid(panel):
		return
	
	panel.visible = true
	panel.modulate.a = 0.0
	
	var start_pos := panel.position
	if offset > 0:
		start_pos.y += offset
	
	var tween = panel.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_parallel(true)
	
	tween.tween_property(panel, "position", panel.position, duration).from(start_pos)
	tween.tween_property(panel, "modulate:a", 1.0, duration)
	
	# Play open sound if AudioManager exists
	if Engine.has_singleton("AudioManager"):
		var audio = Engine.get_singleton("AudioManager")
		if audio and audio.has_method("play"):
			audio.play(0) # UI_CLICK enum value

## Static helper: Animate a panel closing (slide + fade out)
static func animate_close(panel: Control, duration: float = 0.2, offset: float = 20.0, callback: Callable = Callable()) -> void:
	if not is_instance_valid(panel):
		if callback.is_valid():
			callback.call()
		return
	
	var end_pos := panel.position
	if offset > 0:
		end_pos.y += offset
	
	var tween = panel.create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_parallel(true)
	
	tween.tween_property(panel, "position", end_pos, duration)
	tween.tween_property(panel, "modulate:a", 0.0, duration)
	
	if callback.is_valid():
		tween.tween_callback(callback.call)
	else:
		tween.tween_callback(func(): panel.visible = false)
	
	# Play close sound if AudioManager exists
	if Engine.has_singleton("AudioManager"):
		var audio = Engine.get_singleton("AudioManager")
		if audio and audio.has_method("play"):
			audio.play(0) # UI_CLICK enum value

## Instance method: Animate parent panel open
func animate_open_parent() -> void:
	if is_instance_valid(get_parent()) and get_parent() is Control:
		animate_open(get_parent(), open_duration, slide_offset if use_slide else 0.0)

## Instance method: Animate parent panel close
func animate_close_parent(callback: Callable = Callable()) -> void:
	if is_instance_valid(get_parent()) and get_parent() is Control:
		animate_close(get_parent(), close_duration, slide_offset if use_slide else 0.0, callback)

## Pulse effect: Quick scale pulse for highlighting
static func pulse(panel: Control, duration: float = 0.15, scale_factor: float = 1.05) -> void:
	if not is_instance_valid(panel):
		return
	
	var original_scale := panel.scale
	
	var tween = panel.create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_parallel(false)
	
	tween.tween_property(panel, "scale", original_scale * scale_factor, duration)
	tween.tween_property(panel, "scale", original_scale, duration)

## Shake effect: For errors or notifications
static func shake(panel: Control, duration: float = 0.3, intensity: float = 10.0) -> void:
	if not is_instance_valid(panel):
		return
	
	var original_position := panel.position
	
	var tween = panel.create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	
	var shakes := 4
	var shake_duration := duration / shakes
	
	for i in range(shakes):
		var offset := Vector2.RIGHT * intensity * (1 if i % 2 == 0 else -1)
		tween.tween_property(panel, "position", original_position + offset, shake_duration)
	
	tween.tween_property(panel, "position", original_position, shake_duration)
