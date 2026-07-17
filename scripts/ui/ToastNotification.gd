extends MarginContainer
class_name ToastNotification

## Drop-in toast notification system.
## 
## Usage:
##   Option 1: Add this scene as a child of your main UI canvas
##   Option 2: Call static function from anywhere:
##     ToastNotification.show_toast("Your message here")
##     ToastNotification.show_toast("Item purchased!", Color.GREEN)
##
## Features:
##   - Auto-fade in/out
##   - Configurable duration
##   - Optional icons and colors
##   - Queue system for multiple toasts

@export var default_duration: float = 2.5
@export var fade_duration: float = 0.3
@export var max_queue_size: int = 3

var _toast_queue: Array[Dictionary] = []
var _is_showing: bool = false
var _current_tween: Tween

# Predefined toast styles
enum ToastType { INFO, SUCCESS, WARNING, ERROR }

var _type_colors := {
	ToastType.INFO: Color("#3498db"),
	ToastType.SUCCESS: Color("#2ecc71"),
	ToastType.WARNING: Color("#f39c12"),
	ToastType.ERROR: Color("#e74c3c")
}

var _type_icons := {
	ToastType.INFO: "ℹ",
	ToastType.SUCCESS: "✓",
	ToastType.WARNING: "⚠",
	ToastType.ERROR: "✕"
}

func _ready() -> void:
	# Set initial state
	modulate.a = 0.0
	visible = false
	
	# Style the container
	add_theme_constant_override("margin_left", 16)
	add_theme_constant_override("margin_right", 16)
	add_theme_constant_override("margin_top", 8)
	add_theme_constant_override("margin_bottom", 8)
	
	# Create background
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0, 0, 0, 0.85)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	move_child(bg, 0)
	
	# Create label
	var label := Label.new()
	label.name = "ToastLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(label)

## Static helper: Show a toast from anywhere
static func show_toast(message: String, type: ToastType = ToastType.INFO, duration: float = 2.5) -> void:
	var toast: Node = Engine.get_main_loop().root.get_tree().get_first_node_in_group("toasts")
	if not is_instance_valid(toast):
		# Create a temporary toast if none exists
		toast = ToastNotification.new()
		toast.name = "ToastNotification"
		toast.add_to_group("toasts")
		
		# Find a suitable parent (first CanvasLayer or Control)
		var root = Engine.get_main_loop().root
		var canvas = root.get_node_or_null("CanvasLayer")
		if not canvas:
			canvas = root.get_child(0) if root.get_child_count() > 0 else null
		
		if canvas:
			canvas.add_child(toast)
			toast.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
			toast.anchor_right = 0.5
			toast.offset_right = 0
			toast.offset_left = -300
			toast.offset_bottom = -50
			toast.offset_top = -100
	
	if toast and toast.has_method("_queue_toast"):
		toast._queue_toast(message, type, duration)

## Instance method: Queue a toast
func _queue_toast(message: String, type: ToastType = ToastType.INFO, duration: float = -1.0) -> void:
	if duration < 0:
		duration = default_duration
	
	_toast_queue.append({
		"message": message,
		"type": type,
		"duration": duration
	})
	
	# Trim queue if too large
	while _toast_queue.size() > max_queue_size:
		_toast_queue.pop_front()
	
	if not _is_showing:
		_show_next_toast()

func _show_next_toast() -> void:
	if _toast_queue.is_empty():
		_is_showing = false
		return
	
	_is_showing = true
	var data: Dictionary = _toast_queue.pop_front()
	
	var label = get_node_or_null("ToastLabel")
	if not label:
		return
	
	# Update content
	var icon = _type_icons.get(data.type, "ℹ")
	label.text = "%s %s" % [icon, data.message]
	
	# Update color
	var color = _type_colors.get(data.type, Color.WHITE)
	label.add_theme_color_override("font_color", color)
	
	# Animate in
	visible = true
	
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
	
	_current_tween = create_tween()
	_current_tween.set_ease(Tween.EASE_OUT)
	_current_tween.set_trans(Tween.TRANS_CUBIC)
	
	# Fade in
	_current_tween.tween_property(self, "modulate:a", 1.0, fade_duration)
	
	# Wait
	_current_tween.tween_interval(data.duration)
	
	# Fade out
	_current_tween.tween_property(self, "modulate:a", 0.0, fade_duration)
	_current_tween.tween_callback(_on_toast_finished)

func _on_toast_finished() -> void:
	_show_next_toast()
