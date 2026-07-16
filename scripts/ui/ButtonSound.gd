extends Node
class_name ButtonSound

## Drop-in button sound effect add-on.
## 
## Usage:
##   Option 1: Add this node as a child of any Button
##   Option 2: Attach this script directly to a Button node
##   Option 3: Call static function:
##     ButtonSound.add_to_button(my_button)
##
## Features:
##   - Plays sound on hover and/or click
##   - Uses AudioManager if available (procedural fallback)
##   - Configurable volume and pitch variation

@export var play_on_hover: bool = true
@export var play_on_click: bool = true
@export var volume_db: float = -5.0
@export var pitch_variation: float = 0.1  # Random pitch variation (0.0 = none)

var _audio_player: AudioStreamPlayer

func _ready() -> void:
	var button = get_parent() if get_parent() is Button else null
	
	if not button:
		button = get_node_or_null("..")
	
	if not (button is Button):
		push_warning("ButtonSound must be a child of or attached to a Button node")
		return
	
	_setup_audio()
	
	if play_on_hover:
		button.mouse_entered.connect(_on_mouse_entered)
	
	if play_on_click:
		button.pressed.connect(_on_pressed)

func _setup_audio() -> void:
	_audio_player = AudioStreamPlayer.new()
	_audio_player.volume_db = volume_db
	add_child(_audio_player)
	
	# Try to load from AudioManager
	if Engine.has_singleton("AudioManager"):
		var audio = Engine.get_singleton("AudioManager")
		if audio and audio.has_method("_get_sound_stream"):
			var Sound = audio.get("Sound")
			if Sound:
				_audio_player.stream = audio._get_sound_stream(Sound.UI_CLICK)
	
	# Fallback: create procedural sound
	if not _audio_player.stream:
		_audio_player.stream = _create_procedural_click()

func _create_procedural_click() -> AudioStream:
	var generator := AudioStreamGenerator.new()
	generator.buffer_length = 0.05
	generator.mix_rate = 44100.0
	
	var frames := floori(0.05 * generator.mix_rate)
	var data := PackedFloat32Array()
	data.resize(frames)
	
	for i in range(frames):
		var t := float(i) / generator.mix_rate
		var sample := 1.0 if sin(t * 700.0 * TAU) > 0 else -1.0
		
		# Apply envelope
		var envelope := 1.0
		var fade_time := 0.01
		if t < fade_time:
			envelope = t / fade_time
		elif t > 0.05 - fade_time:
			envelope = (0.05 - t) / fade_time
		
		data[i] = sample * envelope * 0.2
	
	var wav := AudioStreamWAV.new()
	wav.data = _float_array_to_bytes(data)
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = generator.mix_rate
	wav.stereo = false
	
	return wav

func _float_array_to_bytes(data: PackedFloat32Array) -> PackedByteArray:
	var bytes := PackedByteArray()
	for sample in data:
		var int_sample := floori(sample * 32767.0)
		bytes.append(int_sample & 0xFF)
		bytes.append((int_sample >> 8) & 0xFF)
	return bytes

func _on_mouse_entered() -> void:
	_play_sound()

func _on_pressed() -> void:
	_play_sound()

func _play_sound() -> void:
	if not _audio_player:
		return
	
	# Apply pitch variation
	if pitch_variation > 0:
		_audio_player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	else:
		_audio_player.pitch_scale = 1.0
	
	_audio_player.play()

## Static helper: Add button sounds to any button
static func add_to_button(button: Button, hover: bool = true, click: bool = true, volume: float = -5.0) -> void:
	if not is_instance_valid(button):
		return
	
	var sound_node = ButtonSound.new()
	sound_node.name = "ButtonSound"
	sound_node.play_on_hover = hover
	sound_node.play_on_click = click
	sound_node.volume_db = volume
	button.add_child(sound_node)
