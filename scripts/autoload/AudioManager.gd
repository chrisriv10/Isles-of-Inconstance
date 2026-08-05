extends Node

## Audio manager for sound effects and background music.
## Loads audio files from res://assets/audio/ — if a file doesn't exist,
## the sound simply doesn't play (no procedural beeps).

# ── SFX system ──

var _audio_players: Array[AudioStreamPlayer] = []
var _player_index: int = 0
const MAX_PLAYERS: int = 32

# ── Music system ──

var _music_player: AudioStreamPlayer = null
var _current_music: int = -1
var _music_volume: float = 0.0
var _crossfade_tween: Tween = null

enum Sound {
	# Farming
	TILL, WATER, PLANT,
	HARVEST, GATHER, MUTATION, DAY_CHANGE,
	# UI
	UI_CLICK, UI_ERROR,
	FOOTSTEP,
	# Combat
	HIT, ENEMY_DIE, BOSS_ROAR, BOSS_DIE,
	BOW_SHOOT,
	# Interactions / Building
	BUILD, DESTROY, DOOR_OPEN, DOOR_CLOSE,
	COOK, CRAFT, BUY, SELL,
	# Player
	LEVEL_UP, EAT,
	# Storage
	CHEST_OPEN, CHEST_CLOSE,
	# Menus
	MENU_OPEN, MENU_CLOSE,
	# Equipment
	EQUIP_ARMOR,
	# World / Environment
	NIGHT_START, BOAT_TRAVEL,
	TOOL_UPGRADE, DROP_ITEM, PICKUP_ITEM,
	AMBIENT_DAY, AMBIENT_NIGHT,
	STORM_RUMBLE,
	PICKAXE_HIT, PICKAXE_BREAK, MINE_ENTER, MINE_EXIT,
	# New sounds
	CAVE_AMBIENCE, MAIN_MENU,
}

var _sound_streams: Dictionary = {}

func _ready() -> void:
	_load_streams()

	# SFX player pool
	for i in range(MAX_PLAYERS):
		var player := AudioStreamPlayer.new()
		add_child(player)
		_audio_players.append(player)

	# Music player (dedicated, separate from SFX pool)
	_music_player = AudioStreamPlayer.new()
	_music_player.volume_db = _music_volume
	add_child(_music_player)

	# Wire day/night cycle ambient switching
	var gm_node: Node = get_node("/root/GameManager") if has_node("/root/GameManager") else null
	if gm_node and gm_node.has_signal("phase_changed"):
		gm_node.phase_changed.connect(_on_phase_changed)

## Load audio files from disk. No procedural fallback — missing files = silence.
func _load_streams() -> void:
	var sound_config := {
		Sound.TILL: "res://assets/audio/till.wav",
		Sound.WATER: "res://assets/audio/water.wav",
		Sound.PLANT: "res://assets/audio/plant.ogg",
		Sound.UI_CLICK: "res://assets/audio/click.mp3",
		Sound.UI_ERROR: "res://assets/audio/ui_error.wav",
		Sound.HIT: "res://assets/audio/hit.mp3",
		Sound.DOOR_OPEN: "res://assets/audio/door_open.mp3",
		Sound.DOOR_CLOSE: "res://assets/audio/door_close.mp3",
		Sound.ENEMY_DIE: "res://assets/audio/enemy_die.mp3",
		Sound.BOSS_ROAR: "res://assets/audio/boss_roar.mp3",
		Sound.BOSS_DIE: "res://assets/audio/boss_die.mp3",
		Sound.LEVEL_UP: "res://assets/audio/level_up.mp3",
		Sound.EAT: "res://assets/audio/eat.mp3",
		Sound.CHEST_OPEN: "res://assets/audio/chest_open.wav",
		Sound.CHEST_CLOSE: "res://assets/audio/chest_close.wav",
		Sound.MENU_OPEN: "res://assets/audio/menu_open.wav",
		Sound.MENU_CLOSE: "res://assets/audio/menu_close.wav",
		Sound.EQUIP_ARMOR: "res://assets/audio/equip_armor.mp3",
		Sound.AMBIENT_DAY: "res://assets/audio/day_ambience_theme.wav",
		Sound.AMBIENT_NIGHT: "res://assets/audio/night_ambience_theme.mp3",
		Sound.CAVE_AMBIENCE: "res://assets/audio/cave_ambience_effect.mp3",
		Sound.MAIN_MENU: "res://assets/audio/main_menu_theme.mp3",
	}

	for sound_type in sound_config:
		var path: String = sound_config[sound_type]
		if ResourceLoader.exists(path):
			var stream := load(path)
			if stream:
				_sound_streams[sound_type] = stream

## Play a one-shot SFX. If the sound file doesn't exist, nothing plays.
func play(sound_type: Sound, volume_db: float = 0.0) -> void:
	var player := _get_available_player()
	if not player:
		return

	var stream = _sound_streams.get(sound_type)
	if not stream:
		return

	player.volume_db = volume_db
	player.stream = stream
	player.play()

## Play background music (looping). Crossfades from previous music if any.
func play_music(sound_type: Sound, fade_seconds: float = 1.0) -> void:
	if sound_type == _current_music and _music_player.playing:
		return

	var stream = _sound_streams.get(sound_type)
	if not stream:
		stop_music(fade_seconds)
		return

	# Kill any in-progress crossfade
	if _crossfade_tween and _crossfade_tween.is_valid():
		_crossfade_tween.kill()

	stream.loop = true
	_current_music = sound_type

	if not _music_player.playing:
		# Nothing playing yet — just start
		_music_player.stream = stream
		_music_player.volume_db = _music_volume
		_music_player.play()
	else:
		# Crossfade: fade out old, switch, fade in new
		var old_vol := _music_player.volume_db
		_crossfade_tween = create_tween()
		_crossfade_tween.tween_property(_music_player, "volume_db", -80.0, fade_seconds * 0.5)
		_crossfade_tween.tween_callback(func():
			_music_player.stream = stream
			_music_player.volume_db = -80.0
			_music_player.play()
		)
		_crossfade_tween.tween_property(_music_player, "volume_db", _music_volume, fade_seconds * 0.5)

## Stop background music with optional fade-out.
func stop_music(fade_seconds: float = 0.5) -> void:
	if _crossfade_tween and _crossfade_tween.is_valid():
		_crossfade_tween.kill()

	_current_music = -1

	if not _music_player.playing:
		return

	if fade_seconds <= 0.0:
		_music_player.stop()
		return

	var tween := create_tween()
	tween.tween_property(_music_player, "volume_db", -80.0, fade_seconds)
	tween.tween_callback(func():
		_music_player.stop()
	)

## Respond to day/night phase changes — switch ambient music.
func _on_phase_changed(phase: int) -> void:
	if _current_music >= 0 and _current_music != Sound.AMBIENT_DAY and _current_music != Sound.AMBIENT_NIGHT:
		return
	match phase:
		0, 1:  # DAWN, DAY
			play_music(Sound.AMBIENT_DAY, 2.0)
		2, 3:  # DUSK, NIGHT
			play_music(Sound.AMBIENT_NIGHT, 2.0)

## Get an available audio player (round-robin).
func _get_available_player() -> AudioStreamPlayer:
	if _audio_players.is_empty():
		return null
	for i in range(MAX_PLAYERS):
		var player := _audio_players[_player_index]
		_player_index = (_player_index + 1) % MAX_PLAYERS
		if not player.playing:
			return player
	return null

## Get the audio stream for a sound type (used by ButtonSound helper).
func _get_sound_stream(sound_type: Sound) -> AudioStream:
	return _sound_streams.get(sound_type)
