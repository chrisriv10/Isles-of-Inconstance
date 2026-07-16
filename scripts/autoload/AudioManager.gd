extends Node

## Simple audio manager for sound effects.
## Uses preloaded AudioStreamWAV files from res://assets/audio/ if available,
## otherwise falls back to generating simple tones procedurally via AudioStreamGenerator.

var _audio_players: Array[AudioStreamPlayer] = []
var _player_index: int = 0
const MAX_PLAYERS: int = 8

enum Sound { TILL, WATER, PLANT, HARVEST, GATHER, MUTATION, DAY_CHANGE, UI_CLICK, UI_ERROR, FOOTSTEP }

var _sound_streams: Dictionary = {}

func _ready() -> void:
	_load_or_create_streams()
	
	for i in range(MAX_PLAYERS):
		var player := AudioStreamPlayer.new()
		add_child(player)
		_audio_players.append(player)

## Load audio files from disk, or create procedural placeholders if missing
func _load_or_create_streams() -> void:
	var sound_config := {
		Sound.TILL: {"path": "res://assets/audio/till.wav", "freq": 200, "dur": 0.1, "wave": "square"},
		Sound.WATER: {"path": "res://assets/audio/water.wav", "freq": 400, "dur": 0.15, "wave": "sine"},
		Sound.PLANT: {"path": "res://assets/audio/plant.wav", "freq": 600, "dur": 0.08, "wave": "sine"},
		Sound.HARVEST: {"path": "res://assets/audio/harvest.wav", "freq": 800, "dur": 0.2, "wave": "triangle"},
		Sound.GATHER: {"path": "res://assets/audio/gather.wav", "freq": 300, "dur": 0.15, "wave": "square"},
		Sound.MUTATION: {"path": "res://assets/audio/mutation.wav", "freq": 1000, "dur": 0.3, "wave": "sine"},
		Sound.DAY_CHANGE: {"path": "res://assets/audio/day_change.wav", "freq": 500, "dur": 0.4, "wave": "sine"},
		Sound.UI_CLICK: {"path": "res://assets/audio/ui_click.wav", "freq": 700, "dur": 0.05, "wave": "square"},
		Sound.UI_ERROR: {"path": "res://assets/audio/ui_error.wav", "freq": 150, "dur": 0.1, "wave": "square"},
		Sound.FOOTSTEP: {"path": "res://assets/audio/footstep.wav", "freq": 100, "dur": 0.05, "wave": "noise"},
	}
	
	for sound_type in sound_config:
		var config: Dictionary = sound_config[sound_type]
		var stream := load(config["path"])
		if stream:
			_sound_streams[sound_type] = stream
		else:
			_sound_streams[sound_type] = _create_placeholder_sound(config["freq"], config["dur"], config["wave"])
	
	# Pre-create the audio streams as resources for efficiency
	# Note: In Godot 4, AudioStreamGenerator must be instantiated at runtime
	# but we can cache the generated streams

## Create a placeholder audio stream using AudioStreamGenerator
## This generates simple tones procedurally so no external audio files are needed
func _create_placeholder_sound(frequency: float, duration: float, wave_type: String) -> AudioStream:
	var generator := AudioStreamGenerator.new()
	generator.buffer_length = duration
	generator.mix_rate = 44100.0
	
	var frames := floori(duration * generator.mix_rate)
	var data := PackedFloat32Array()
	data.resize(frames)
	
	for i in range(frames):
		var t := float(i) / generator.mix_rate
		var sample := 0.0
		
		match wave_type:
			"sine":
				sample = sin(t * frequency * TAU)
			"square":
				sample = 1.0 if sin(t * frequency * TAU) > 0 else -1.0
			"triangle":
				sample = 2.0 * asin(sin(t * frequency * TAU)) / PI
			"noise":
				sample = randf() * 2.0 - 1.0
			_:
				sample = sin(t * frequency * TAU)
		
		# Apply envelope (fade in/out)
		var envelope := 1.0
		var fade_time := 0.02
		if t < fade_time:
			envelope = t / fade_time
		elif t > duration - fade_time:
			envelope = (duration - t) / fade_time
		
		data[i] = sample * envelope * 0.3
	
	# Convert to AudioStreamWAV for playback
	var wav := AudioStreamWAV.new()
	wav.data = _float_array_to_bytes(data)
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = generator.mix_rate
	wav.stereo = false
	
	return wav

## Convert float array to bytes for WAV format
func _float_array_to_bytes(data: PackedFloat32Array) -> PackedByteArray:
	var bytes := PackedByteArray()
	for sample in data:
		var int_sample := floori(sample * 32767.0)
		bytes.append(int_sample & 0xFF)
		bytes.append((int_sample >> 8) & 0xFF)
	return bytes

## Play a sound by enum type
func play(sound_type: Sound, volume_db: float = 0.0) -> void:
	var player := _get_available_player()
	if not player:
		return
	
	player.volume_db = volume_db
	player.stream = _sound_streams.get(sound_type)
	if player.stream:
		player.play()

## Get an available audio player (round-robin)
func _get_available_player() -> AudioStreamPlayer:
	for i in range(MAX_PLAYERS):
		var player := _audio_players[_player_index]
		_player_index = (_player_index + 1) % MAX_PLAYERS
		if not player.playing:
			return player
	return null

## Get the audio stream for a sound type
func _get_sound_stream(sound_type: Sound) -> AudioStream:
	return _sound_streams.get(sound_type)
