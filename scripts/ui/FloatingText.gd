## Enhanced floating text for damage numbers, resource pickups, and combo feedback.
## Spawned by EffectSpawner. Handles its own tween animation and auto-cleanup.
##
## Modes:
##   DAMAGE    — number bounces up, white → gold (crit: bigger, orange, screen shake)
##   RESOURCE  — "+X Name" floats up in item-appropriate color, fades
##   COLLECT   — golden "+X Coins" with sparkly rise
##   COMBO     — "Xx Combo!" in cyan with pulse + scale oscillation
##   PLAYER_DMG — red "-X HP" with slight horizontal wobble

extends Node2D
class_name FloatingText

enum Mode {
	DAMAGE,
	RESOURCE,
	COLLECT,
	COMBO,
	PLAYER_DMG,
}

var _label: Label
var _mode: Mode = Mode.DAMAGE
var _lifetime: float = 0.0
var _rise_amount: float = 32.0

func _ready() -> void:
	# Create Label child
	_label = Label.new()
	_label.name = "TextLabel"
	_label.add_theme_font_override("font", ThemeDB.fallback_font)
	_label.z_index = 100
	add_child(_label)


## Play a DAMAGE or CRITICAL number that rises and fades.
func play_damage(value: int, is_critical: bool = false) -> void:
	_mode = Mode.DAMAGE
	_label.text = str(value)
	
	if is_critical:
		# CRIT: bigger, orange, with exclamation
		_label.text = str(value) + "!"
		_label.add_theme_font_size_override("font_size", 22)
		_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.0))
		_label.add_theme_constant_override("outline_size", 3)
		_label.add_theme_color_override("font_outline_color", Color(0.3, 0.1, 0.0, 0.8))
		_lifetime = 1.2
		_rise_amount = 48.0
		
		# Scale pop-in
		scale = Vector2(0.3, 0.3)
		var pop := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		pop.tween_property(self, "scale", Vector2(1.0, 1.0), 0.25)
		
		# Trigger a brief screen shake
		EffectSpawner.screen_shake(5.0, 0.2)
		
		# Extra sparkle particles for crits
		EffectSpawner.spawn_sparkle(global_position, Color(1.0, 0.6, 0.0))
		
	else:
		_label.add_theme_font_size_override("font_size", 15)
		_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
		_label.add_theme_constant_override("outline_size", 2)
		_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.6))
		_lifetime = 0.8
		_rise_amount = 28.0
		
		# Quick scale bounce
		scale = Vector2(0.8, 1.2)
		var pop := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
		pop.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15)
	
	# Start the float-up animation
	_start_float_tween()


## Play a RESOURCE notification: "+X ItemName" in the specified color.
func play_resource(item_name: String, amount: int, color: Color) -> void:
	_mode = Mode.RESOURCE
	_label.text = "+%d %s" % [amount, item_name]
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", color)
	_label.add_theme_constant_override("outline_size", 2)
	_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.5))
	_lifetime = 0.9
	_rise_amount = 24.0
	
	# Small sparkle particles
	EffectSpawner.spawn_particles(global_position, color, 2, 4.0)
	
	_start_float_tween()


## Play a COLLECT coins notification.
func play_collect(amount: int) -> void:
	_mode = Mode.COLLECT
	_label.text = "+%d Coins" % amount
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", Color(0.95, 0.8, 0.2))
	_label.add_theme_constant_override("outline_size", 2)
	_label.add_theme_color_override("font_outline_color", Color(0.3, 0.2, 0.0, 0.7))
	_lifetime = 1.0
	_rise_amount = 36.0
	
	# Gold sparkles
	EffectSpawner.spawn_sparkle(global_position, Color(0.95, 0.8, 0.2))
	
	_start_float_tween()


## Play a COMBO text: "2x Combo!" with a pulsing bounce.
func play_combo(streak: int) -> void:
	_mode = Mode.COMBO
	_label.text = "%dx Combo!" % streak
	_label.add_theme_font_size_override("font_size", 20)
	_label.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0))
	_label.add_theme_constant_override("outline_size", 3)
	_label.add_theme_color_override("font_outline_color", Color(0.0, 0.15, 0.25, 0.8))
	_lifetime = 1.0
	_rise_amount = 32.0
	
	# Dramatic scale pop
	scale = Vector2(1.5, 0.5)
	var pop := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
	pop.tween_property(self, "scale", Vector2(1.0, 1.0), 0.3)
	
	# Particle burst
	EffectSpawner.spawn_particles(global_position, Color(0.3, 0.85, 1.0), 6, 10.0)
	
	_start_float_tween()


## Play an XP notification: "+X XP" in gold, floats up and fades.
func play_xp(amount: int) -> void:
	_mode = Mode.RESOURCE  # reuse RESOURCE mode behavior
	_label.text = "+%d XP" % amount
	_label.add_theme_font_size_override("font_size", 15)
	_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	_label.add_theme_constant_override("outline_size", 2)
	_label.add_theme_color_override("font_outline_color", Color(0.3, 0.2, 0.0, 0.7))
	_lifetime = 1.0
	_rise_amount = 32.0

	# Scale bounce
	scale = Vector2(0.8, 1.2)
	var pop := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
	pop.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15)

	# Gold sparkles
	EffectSpawner.spawn_particles(global_position, Color(1.0, 0.85, 0.2), 3, 6.0)

	_start_float_tween()


func play_player_damage(value: int, blocked: int = 0) -> void:
	_mode = Mode.PLAYER_DMG
	_label.text = "-%d HP" % value
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.1))
	_label.add_theme_constant_override("outline_size", 2)
	_label.add_theme_color_override("font_outline_color", Color(0.2, 0.0, 0.0, 0.6))
	
	if blocked > 0:
		_label.text = "-%d HP" % value
		# Show blocked amount as a secondary floating text above
		# Must add to tree BEFORE calling play methods, so _ready() creates _label
		var secondary := FloatingText.new()
		secondary.global_position = global_position + Vector2(0, -16)
		get_parent().add_child(secondary)
		secondary.play_resource("blocked", blocked, Color(0.8, 0.8, 0.3))
		
		# Also tint the main text slightly lighter to show armor helped
		_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
	
	_lifetime = 0.9
	_rise_amount = 28.0
	
	# Screen shake on big hits
	if value >= 20:
		EffectSpawner.screen_shake(3.0, 0.15)
	
	_start_float_tween()


func _start_float_tween() -> void:
	var tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	
	# Float upward
	var target_pos := position + Vector2(0, -_rise_amount)
	tween.parallel().tween_property(self, "position", target_pos, _lifetime)
	
	# Fade out in the last 40% of lifetime
	var fade_delay := _lifetime * 0.6
	var fade_duration := _lifetime * 0.4
	tween.tween_interval(fade_delay)
	tween.tween_property(_label, "modulate:a", 0.0, fade_duration)
	tween.tween_callback(queue_free)
