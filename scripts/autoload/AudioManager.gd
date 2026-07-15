extends Node

## Simple audio manager for sound effects.
## Uses placeholder sounds that can be replaced with actual audio files.

var _audio_players: Array[AudioStreamPlayer] = []
var _player_index: int = 0
const MAX_PLAYERS: int = 8

enum Sound { TILL, WATER, PLANT, HARVEST, GATHER, MUTATION, DAY_CHANGE, UI_CLICK, UI_ERROR, FOOTSTEP }

func _ready() -> void:
	for i in range(MAX_PLAYERS):
		var player := AudioStreamPlayer.new()
		add_child(player)
		_audio_players.append(player)

## Play a sound by enum type
func play(sound_type: Sound, volume_db: float = 0.0) -> void:
	var player := _get_available_player()
	if not player:
		return
	
	player.volume_db = volume_db
	player.stream = _get_sound_stream(sound_type)
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
## In a full implementation, these would load actual audio files
func _get_sound_stream(sound_type: Sound) -> AudioStream:
	match sound_type:
		Sound.TILL:
			return _create_placeholder_sound(200, 0.1, "square")
		Sound.WATER:
			return _create_placeholder_sound(400, 0.15, "sine")
		Sound.PLANT:
			return _create_placeholder_sound(600, 0.08, "sine")
		Sound.HARVEST:
			return _create_placeholder_sound(800, 0.2, "triangle")
		Sound.GATHER:
			return _create_placeholder_sound(300, 0.15, "square")
		Sound.MUTATION:
			return _create_placeholder_sound(1000, 0.3, "sine")
		Sound.DAY_CHANGE:
			return _create_placeholder_sound(500, 0.4, "sine")
		Sound.UI_CLICK:
			return _create_placeholder_sound(700, 0.05, "square")
		Sound.UI_ERROR:
			return _create_placeholder_sound(150, 0.1, "square")
		Sound.FOOTSTEP:
			return _create_placeholder_sound(100, 0.05, "noise")
		_:
			return null

## Create a placeholder audio stream using AudioStreamGenerator
## This generates simple tones procedurally so no external audio files are needed
func _create_placeholder_sound(frequency: float, duration: float, wave_type: String) -> AudioStream:
	var generator := AudioStreamGenerator.new()
	generator.buffer_length = duration
	generator.mix_rate = 44100.0
	
	var playback: AudioStreamPlayback = generator.instantiate()
	var frames := int(duration * generator.mix_rate)
	
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
	
	playback.push_buffer(data)
	
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
		var int_sample := int(sample * 32767.0)
		bytes.append(int_sample & 0xFF)
		bytes.append((int_sample >> 8) & 0xFF)
	return bytes
