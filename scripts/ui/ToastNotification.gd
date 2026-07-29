extends PanelContainer
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

# Static cache to avoid creating duplicate CanvasLayers when toasts fire before
# a deferred add_child has executed (e.g., during world generation / _ready).
static var _fallback_canvas: CanvasLayer = null

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
	
	# Black translucent background with rounded corners
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.35)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	add_theme_stylebox_override("panel", style)
	
	# Compact padding so the background is tight around the text
	add_theme_constant_override("margin_left", 10)
	add_theme_constant_override("margin_right", 10)
	add_theme_constant_override("margin_top", 6)
	add_theme_constant_override("margin_bottom", 6)
	
	# Create rich label (supports BBCode for [b], [color=...], etc.)
	var label := RichTextLabel.new()
	label.name = "ToastLabel"
	label.bbcode_enabled = true
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("normal_font_size", 16)
	add_child(label)

## Static helper: Show a toast from anywhere
static func show_toast(message: String, type: ToastType = ToastType.INFO, duration: float = 2.5) -> void:
	var toast: Node = Engine.get_main_loop().root.get_tree().get_first_node_in_group("toasts")
	if not is_instance_valid(toast):
		# Create a temporary toast if none exists
		toast = ToastNotification.new()
		toast.name = "ToastNotification"
		toast.add_to_group("toasts")
		
		# Find or create a CanvasLayer parent for the fallback toast
		var root = Engine.get_main_loop().root
		var canvas: CanvasLayer = null
		for child in root.get_children():
			if child is CanvasLayer:
				canvas = child
				break
		if not canvas:
			if is_instance_valid(_fallback_canvas):
				canvas = _fallback_canvas
			else:
				canvas = CanvasLayer.new()
				canvas.name = "ToastFallbackCanvas"
				_fallback_canvas = canvas
				# Defer to avoid "busy setting up children" errors during _ready() /
				# world generation. Subsequent toasts will find the cached canvas.
				root.call_deferred("add_child", canvas)
		
		canvas.add_child(toast)
		toast.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		toast.anchor_right = 1.0
		toast.anchor_bottom = 0.0
		toast.offset_right = -20
		toast.offset_left = -320
		toast.offset_top = 110
		toast.offset_bottom = 110
	
	if toast and toast.has_method("_queue_toast"):
		# If this is a freshly-created toast, _ready() may not have run yet,
		# so the ToastLabel child won't exist. Defer the queue to next frame.
		if toast.is_node_ready():
			toast._queue_toast(message, type, duration)
		else:
			toast._queue_toast.call_deferred(message, type, duration)

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
	
	var data: Dictionary = _toast_queue.pop_front()
	
	var label = get_node_or_null("ToastLabel")
	if not label:
		return
	
	# Update content
	var icon = _type_icons.get(data.type, "ℹ")
	label.text = "%s %s" % [icon, data.message]
	
	# Update color (RichTextLabel uses "default_color" instead of "font_color")
	var color = _type_colors.get(data.type, Color.WHITE)
	label.add_theme_color_override("default_color", color)
	
	# Estimate height from text length (~35 chars per line at 300px width, 16px font)
	var msg_len: int = ("%s %s" % [icon, data.message]).length()
	var estimated_lines: int = maxi(1, ceil(msg_len / 35.0))
	var content_h: float = estimated_lines * 24.0 + 24.0
	offset_bottom = offset_top + clampi(content_h as int, 48, 200)
	
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
