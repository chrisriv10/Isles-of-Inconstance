extends Node2D
class_name ToolPreview

## Draws a pulsing blue outline on the tile cells that the player's
## current tool will affect (tilling, watering, or planting).
## Uses a built-in AnimationPlayer for the pulse to avoid per-frame _process overhead.

const CELL_SIZE: int = 16
const LINE_WIDTH: float = 2.0

var _target_cells: Array[Vector2i] = []
var _pulse_phase: float = 0.0
var _visible: bool = false

func _ready() -> void:
	# Use a short timer to pulse instead of _process for efficiency
	var timer := Timer.new()
	timer.name = "PulseTimer"
	timer.wait_time = 0.05
	timer.autostart = false
	add_child(timer)
	timer.timeout.connect(_on_pulse_tick)

func _on_pulse_tick() -> void:
	if _visible and not _target_cells.is_empty():
		_pulse_phase += 0.2
		queue_redraw()

## Show the preview outline on the given tile cells.
func show_cells(cells: Array[Vector2i]) -> void:
	_target_cells = cells
	_visible = true
	_pulse_phase = 0.0
	queue_redraw()
	# Start the pulse timer
	var timer: Timer = $PulseTimer
	if timer:
		timer.stop()
		timer.start()

## Hide and clear the preview.
func hide_preview() -> void:
	_target_cells.clear()
	_visible = false
	queue_redraw()
	# Stop the pulse timer
	var timer: Timer = $PulseTimer
	if timer and not timer.is_stopped():
		timer.stop()

func _draw() -> void:
	if not _visible or _target_cells.is_empty():
		return

	# Pulse alpha between 0.3 and 0.8
	var alpha: float = 0.55 + sin(_pulse_phase) * 0.25
	var color := Color(0.2, 0.5, 1.0, alpha)

	for cell in _target_cells:
		var pos := Vector2(cell.x * CELL_SIZE, cell.y * CELL_SIZE)
		var rect := Rect2(pos, Vector2(CELL_SIZE, CELL_SIZE))
		draw_rect(rect, color, false, LINE_WIDTH)
