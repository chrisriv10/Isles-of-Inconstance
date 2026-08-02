class_name PlayerDialogueBubble
extends Node2D

## Floating toast-style dialogue above the player. Same clean aesthetic as
## the top-right toast notification — dark semi-transparent bg, centered text,
## auto-sizing width, height grows with content.

const BUBBLE_WIDTH: float = 170.0
const FONT_SIZE: int = 6
const TOP_OFFSET: float = -26.0
# Cap the bubble at roughly three wrapped lines at FONT_SIZE + margins so it
# never grows tall enough to collide with the screen's top HUD bar.
const MAX_BUBBLE_HEIGHT: float = 30.0

@onready var _label: RichTextLabel = $BubbleLabel

var _tween: Tween = null
var is_visible: bool = false


func _ready() -> void:
	# Draw above town buildings (z=0) and NPCs so speech never gets cut off.
	z_index = 5
	hide()
	_label.add_theme_font_size_override("normal_font_size", FONT_SIZE)
	# Toast-style background — same dark rounded look as the toast notification
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	_label.add_theme_stylebox_override("normal", style)


func show_text(text: String, duration: float = 3.0) -> void:
	if not is_inside_tree():
		return

	if _tween and _tween.is_valid():
		_tween.kill()
		_tween = null

	# Trim so the bubble never grows past ~2 lines (see MAX_BUBBLE_HEIGHT).
	var display := _fit_to_height(text)
	_label.text = "[center]%s[/center]" % display
	# Set fixed width, height auto-sizes to fit content
	_label.size.x = BUBBLE_WIDTH
	# get_content_height() returns the text content height, not including
	# the StyleBoxFlat margins — so add top+bottom margins (3+3=6).
	var content_height: float = _label.get_content_height()
	var total_height: float = minf(content_height + 6.0, MAX_BUBBLE_HEIGHT)
	if content_height <= 0.0:
		# Fallback: minimum height for one line of text + margins
		total_height = FONT_SIZE + 12.0
	total_height = minf(total_height, MAX_BUBBLE_HEIGHT)
	_label.size = Vector2(BUBBLE_WIDTH, total_height)
	_label.position = Vector2(-BUBBLE_WIDTH / 2.0, -total_height / 2.0)
	position = Vector2(0, TOP_OFFSET)

	modulate.a = 0.0
	show()
	is_visible = true

	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(self, "modulate:a", 1.0, 0.15)
	_tween.tween_interval(duration)
	_tween.tween_property(self, "modulate:a", 0.0, 0.25)
	_tween.tween_callback(_on_hide)


## Trim long text so it fits within MAX_BUBBLE_HEIGHT, appending an ellipsis.
func _fit_to_height(text: String) -> String:
	var candidate := text.strip_edges()
	if candidate.is_empty():
		return ""
	_label.size.x = BUBBLE_WIDTH
	_label.text = "[center]%s[/center]" % candidate
	if _label.get_content_height() + 6.0 <= MAX_BUBBLE_HEIGHT:
		return candidate
	# Bisect until the wrapped content fits the capped height.
	var hi := candidate.length()
	var lo := 4
	while lo < hi - 1:
		var mid := (lo + hi) / 2
		var slice := candidate.substr(0, mid)
		_label.text = "[center]%s[/center]" % slice
		if _label.get_content_height() + 6.0 <= MAX_BUBBLE_HEIGHT:
			lo = mid
		else:
			hi = mid
	return candidate.substr(0, lo).strip_edges() + "…"


func hide_bubble() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
		_tween = null
	modulate.a = 0.0
	hide()
	is_visible = false


func _on_hide() -> void:
	hide()
	is_visible = false
