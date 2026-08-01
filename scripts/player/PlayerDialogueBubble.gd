class_name PlayerDialogueBubble
extends Node2D

## Floating toast-style dialogue above the player. Same clean aesthetic as
## the top-right toast notification — dark semi-transparent bg, centered text,
## auto-sizing width, height grows with content.

const BUBBLE_WIDTH: float = 180.0
const FONT_SIZE: int = 8
const TOP_OFFSET: float = -28.0

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
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	_label.add_theme_stylebox_override("normal", style)


func show_text(text: String, duration: float = 3.0) -> void:
	if not is_inside_tree():
		return

	if _tween and _tween.is_valid():
		_tween.kill()
		_tween = null

	_label.text = "[center]%s[/center]" % text
	# Set fixed width, height auto-sizes to fit content
	_label.size.x = BUBBLE_WIDTH
	# get_content_height() returns the text content height, not including
	# the StyleBoxFlat margins — so add top+bottom margins (4+4=8).
	var content_height: float = _label.get_content_height()
	var total_height: float = content_height + 8.0  # top 4 + bottom 4 margin
	if content_height <= 0.0:
		# Fallback: minimum height for one line of text + margins
		total_height = FONT_SIZE + 14.0
	_label.size = Vector2(BUBBLE_WIDTH, maxf(total_height, FONT_SIZE + 14.0))
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
