class_name BossDefeatCutscene
extends CanvasLayer

## Full-screen defeat cutscene that plays after each boss is slain.
## Extends CanvasLayer with PROCESS_MODE_ALWAYS so it animates while paused.
## The final boss (Inconstant Soul) gets the longest sequence.

signal finished()

# ── Narrative sequences per boss (index matches ObjectiveManager._boss_counter) ──

const BOSS_SEQUENCES: Array[Dictionary] = [
	# 0 — Root Warden (Boss 1)
	{
		"name": "Root Warden",
		"lines": [
			"The Root Warden crumbles into dust...",
			"The earth trembles as the first of the ancient spirits falls.",
			"But darker forces stir beneath the surface...",
		],
		"per_line_delay": 2.8,
		"fade_color": Color(0.55, 0.2, 0.7, 0.85),
	},
	# 1 — Hollow Stag (Boss 2)
	{
		"name": "Hollow Stag",
		"lines": [
			"The Hollow Stag fades into pure light...",
			"As the second spirit is freed, a cold wind sweeps across the isles.",
			"The veil between worlds grows thin.",
			"Something ancient is watching...",
		],
		"per_line_delay": 3.2,
		"fade_color": Color(1.0, 0.85, 0.3, 0.85),
	},
	# 2 — Blooming Wyrm (Boss 3)
	{
		"name": "Blooming Wyrm",
		"lines": [
			"The Blooming Wyrm wilts away...",
			"With the third spirit released, flowers bloom and wither in rapid succession.",
			"The cycle of life and death accelerates.",
			"You feel the weight of countless seasons pressing upon you.",
			"One more spirit remains... the most powerful of them all.",
		],
		"per_line_delay": 3.5,
		"fade_color": Color(0.85, 0.3, 0.55, 0.85),
	},
	# 3 — Inconstant Soul (Final Boss — longest cutscene)
	{
		"name": "Inconstant Soul",
		"lines": [
			"The Inconstant Soul shatters into pure light!",
			"As the final spirit breaks free, reality itself seems to ripple.",
			"A brilliant pillar of light erupts from the shattered core.",
			"The four essences — Root, Stag, Wyrm, and Soul — swirl together in a cosmic dance.",
			"The land around you begins to heal... colors return to the world.",
			"The curse that has plagued these isles for centuries is finally broken.",
			"You have freed the spirits from their endless torment.",
			"The Isles of Inconstance are at peace once more.",
			"You are the true champion of the Spirit Harvest.",
		],
		"per_line_delay": 4.0,
		"fade_color": Color(0.8, 0.15, 0.15, 0.85),
	},
]

# ── References to children (created in _ready) ──
var _bg: ColorRect = null
var _title_label: Label = null
var _boss_name_label: Label = null
var _narrative_label: Label = null
var _skip_label: Label = null
var _boss_index: int = 0
var _can_skip: bool = false
var _master_tween: Tween = null


## Helper: create a one-shot Timer child and return its timeout signal.
## Since THIS node has PROCESS_MODE_ALWAYS, child Timer nodes will process
## even while the SceneTree is paused.
func _delay(seconds: float) -> Signal:
	var t := Timer.new()
	t.one_shot = true
	t.wait_time = seconds
	t.autostart = true
	t.process_callback = Timer.TIMER_PROCESS_IDLE
	add_child(t)
	return t.timeout


func _ready() -> void:
	layer = 128
	process_mode = PROCESS_MODE_ALWAYS

	_build_ui()


func _exit_tree() -> void:
	# Safety: ensure the game is unpaused if cutscene is removed unexpectedly
	if get_tree() and get_tree().paused:
		get_tree().paused = false


func _process(_delta: float) -> void:
	# Check skip input in _process because _input/gui_input don't fire when paused.
	if not _can_skip:
		return
	if Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_ENTER):
		_can_skip = false
		_skip_cutscene()
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_can_skip = false
		_skip_cutscene()


## Build the UI elements programmatically.
func _build_ui() -> void:
	# Full-screen black background (transparent initially)
	# ColorRect extends Control, so mouse_filter and anchors work.
	_bg = ColorRect.new()
	_bg.name = "Background"
	_bg.color = Color(0, 0, 0, 0)
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP  # capture clicks for skip
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)

	# Center container for text
	var center := CenterContainer.new()
	center.name = "Content"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 16)
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL | Control.SIZE_SHRINK_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(vbox)

	# ── Title: "⚠ BOSS DEFEATED" ──
	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.text = "⚠ BOSS DEFEATED"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", Color(0.95, 0.8, 0.3))
	_title_label.add_theme_constant_override("outline_size", 2)
	_title_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_title_label.modulate = Color(1, 1, 1, 0)
	vbox.add_child(_title_label)

	# ── Boss name ──
	_boss_name_label = Label.new()
	_boss_name_label.name = "BossNameLabel"
	_boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_name_label.add_theme_font_size_override("font_size", 38)
	_boss_name_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_boss_name_label.add_theme_constant_override("outline_size", 3)
	_boss_name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_boss_name_label.modulate = Color(1, 1, 1, 0)
	vbox.add_child(_boss_name_label)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)

	# ── Narrative text ──
	_narrative_label = Label.new()
	_narrative_label.name = "NarrativeLabel"
	_narrative_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_narrative_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_narrative_label.add_theme_font_size_override("font_size", 17)
	_narrative_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 0.95))
	_narrative_label.add_theme_constant_override("outline_size", 1)
	_narrative_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_narrative_label.custom_minimum_size = Vector2(600, 0)
	_narrative_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_narrative_label.modulate = Color(1, 1, 1, 0)
	vbox.add_child(_narrative_label)

	# ── Skip hint ──
	_skip_label = Label.new()
	_skip_label.name = "SkipLabel"
	_skip_label.text = "Press [Space] or click to skip"
	_skip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skip_label.add_theme_font_size_override("font_size", 12)
	_skip_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 0.6))
	_skip_label.modulate = Color(1, 1, 1, 0)
	_skip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Position at bottom of screen
	_skip_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_skip_label.offset_bottom = -30
	add_child(_skip_label)


## Start the cutscene for the given boss index.
## Returns the cutscene instance so callers can await finished.
static func play(boss_index: int) -> BossDefeatCutscene:
	var cutscene := BossDefeatCutscene.new()
	cutscene._boss_index = boss_index
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.current_scene.add_child(cutscene)
	cutscene._start()
	return cutscene


func _start() -> void:
	var seq: Dictionary = BOSS_SEQUENCES[_boss_index]

	# 1. Pause game (also reset time_scale in case hitstop left it frozen)
	Engine.time_scale = 1.0
	get_tree().paused = true

	# 2. Fade to black (0.6s)
	var fade_tween := create_tween().set_parallel(true).set_ease(Tween.EASE_IN)
	fade_tween.tween_property(_bg, "color:a", 0.92, 0.6)
	await fade_tween.finished

	# 3. Show title + boss name (fade in 0.4s)
	var seq_tween := create_tween()
	seq_tween.set_parallel(true)
	seq_tween.set_ease(Tween.EASE_OUT)
	seq_tween.tween_property(_title_label, "modulate:a", 1.0, 0.4)
	seq_tween.tween_property(_boss_name_label, "modulate:a", 1.0, 0.4)
	_boss_name_label.text = seq["name"]
	# Color the boss name with the sequence's fade color
	_boss_name_label.add_theme_color_override("font_color", seq["fade_color"].lerp(Color.WHITE, 0.4))
	await seq_tween.finished

	await _delay(0.6)

	# 4. Show narrative lines one by one
	_can_skip = true

	# Fade in skip hint
	var skip_tween := create_tween()
	skip_tween.set_ease(Tween.EASE_OUT)
	skip_tween.tween_property(_skip_label, "modulate:a", 1.0, 0.5)

	var lines: Array = seq["lines"]
	for i in range(lines.size()):
		if not is_inside_tree():
			return
		var line: String = lines[i] as String

		# Set text, fade in
		_narrative_label.text = line
		_narrative_label.modulate.a = 0.0
		var line_tween := create_tween()
		line_tween.set_ease(Tween.EASE_OUT)
		line_tween.tween_property(_narrative_label, "modulate:a", 1.0, 0.35)
		await line_tween.finished

		# Wait for reading time
		var delay: float = seq["per_line_delay"]
		# Last line gets a bit more time
		if i == lines.size() - 1:
			delay += 1.0
		await _delay(delay)

		if not is_inside_tree():
			return

		# Fade out the line (unless it's the last one — keep it visible)
		if i < lines.size() - 1:
			var out_tween := create_tween()
			out_tween.set_ease(Tween.EASE_IN)
			out_tween.tween_property(_narrative_label, "modulate:a", 0.0, 0.25)
			await out_tween.finished

	_can_skip = false

	# 5. Brief pause then fade out
	await _delay(0.8)

	if not is_inside_tree():
		return

	# Fade out skip label
	var hide_skip := create_tween()
	hide_skip.tween_property(_skip_label, "modulate:a", 0.0, 0.3)

	# 6. Fade back to game (1.0s)
	var out_tween := create_tween().set_parallel(true).set_ease(Tween.EASE_OUT)
	out_tween.tween_property(_bg, "color:a", 0.0, 1.0)
	out_tween.tween_property(_title_label, "modulate:a", 0.0, 0.6)
	out_tween.tween_property(_boss_name_label, "modulate:a", 0.0, 0.6)
	out_tween.tween_property(_narrative_label, "modulate:a", 0.0, 0.5)
	await out_tween.finished

	# 7. Unpause game
	get_tree().paused = false

	_finish()


## Called when player skips the cutscene.
func _skip_cutscene() -> void:
	_can_skip = false
	# Quick fade out
	var skip_tween := create_tween().set_parallel(true).set_ease(Tween.EASE_OUT)
	skip_tween.tween_property(_bg, "color:a", 0.0, 0.4)
	skip_tween.tween_property(_title_label, "modulate:a", 0.0, 0.2)
	skip_tween.tween_property(_boss_name_label, "modulate:a", 0.0, 0.2)
	skip_tween.tween_property(_narrative_label, "modulate:a", 0.0, 0.2)
	skip_tween.tween_property(_skip_label, "modulate:a", 0.0, 0.2)

	# Unpause immediately
	get_tree().paused = false

	await skip_tween.finished
	_finish()


func _finish() -> void:
	finished.emit()
	queue_free()
