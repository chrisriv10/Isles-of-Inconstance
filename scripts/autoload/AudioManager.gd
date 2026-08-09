extends Node

## Audio manager for sound effects and background music.
## Loads audio files from res://assets/audio/ â€” if a file doesn't exist,
## the sound simply doesn't play (no procedural beeps).

# â”€â”€ SFX system â”€â”€

var _audio_players: Array[AudioStreamPlayer] = []
var _player_index: int = 0
const MAX_PLAYERS: int = 32

# â”€â”€ Music system â”€â”€

var _music_player: AudioStreamPlayer = null
var _current_music: int = -1
var _music_volume: float = 0.0
var _crossfade_tween: Tween = null
## Ambient track (AMBIENT_DAY / AMBIENT_NIGHT) to restore after a zone
## override (cave/boss/interior music) ends. Phase changes keep this updated,
## so the correct day/night theme plays when the player leaves the zone.
var _base_music: int = -1

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
	# Zone music themes (loop over ambient while in caves / boss fights / interiors)
	CAVE_MUSIC, BOSS_MUSIC, INTERIOR_MUSIC,
	# Expedition island themes (one per island type, same order as
	# ExpeditionIsland.IslandType).
	PLAINS_THEME, SNOWLAND_THEME, ICE_CREAM_LAND_THEME, DESERT_THEME,
	VOLCANO_THEME, ETHEREAL_THEME,
	# Event / UI themes (zone-style overrides).
	PIRATE_RAID_THEME, BLOOD_MOON_THEME, SHOP_THEME,
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

## Load audio files from disk. No procedural fallback â€” missing files = silence.
func _load_streams() -> void:
	var sound_config := {
		Sound.TILL: "res://assets/audio/till.wav",
		Sound.WATER: "res://assets/audio/water.wav",
		Sound.PLANT: "res://assets/audio/plant.ogg",
		Sound.UI_CLICK: "res://assets/audio/click.ogg",
		Sound.UI_ERROR: "res://assets/audio/ui_error.wav",
		Sound.HIT: "res://assets/audio/hit.ogg",
		Sound.DOOR_OPEN: "res://assets/audio/door_open.ogg",
		Sound.DOOR_CLOSE: "res://assets/audio/door_close.ogg",
		Sound.ENEMY_DIE: "res://assets/audio/enemy_die.ogg",
		Sound.BOSS_ROAR: "res://assets/audio/boss_roar.ogg",
		Sound.BOSS_DIE: "res://assets/audio/boss_die.ogg",
		Sound.LEVEL_UP: "res://assets/audio/level_up.ogg",
		Sound.EAT: "res://assets/audio/eat.ogg",
		Sound.CHEST_OPEN: "res://assets/audio/chest_open.wav",
		Sound.CHEST_CLOSE: "res://assets/audio/chest_close.wav",
		Sound.MENU_OPEN: "res://assets/audio/menu_open.wav",
		Sound.MENU_CLOSE: "res://assets/audio/menu_close.wav",
		Sound.EQUIP_ARMOR: "res://assets/audio/equip_armor.ogg",
		Sound.AMBIENT_DAY: "res://assets/audio/day_ambience_theme.ogg",
		Sound.AMBIENT_NIGHT: "res://assets/audio/night_ambience_theme.ogg",
		Sound.CAVE_AMBIENCE: "res://assets/audio/cave_ambience_effect.ogg",
		Sound.MAIN_MENU: "res://assets/audio/main_menu_theme.ogg",
		Sound.CAVE_MUSIC: "res://assets/audio/cave_music_theme.ogg",
		Sound.BOSS_MUSIC: "res://assets/audio/boss_theme.ogg",
		Sound.INTERIOR_MUSIC: "res://assets/audio/interior_music.ogg",
		Sound.PLAINS_THEME: "res://assets/audio/plains_theme.ogg",
		Sound.SNOWLAND_THEME: "res://assets/audio/snowland_theme.ogg",
		Sound.ICE_CREAM_LAND_THEME: "res://assets/audio/icecreamland_theme.ogg",
		Sound.DESERT_THEME: "res://assets/audio/desert_theme.ogg",
		Sound.VOLCANO_THEME: "res://assets/audio/volcano_theme.ogg",
		Sound.ETHEREAL_THEME: "res://assets/audio/ethereal_theme.ogg",
		Sound.PIRATE_RAID_THEME: "res://assets/audio/pirate_raid_theme.ogg",
		Sound.BLOOD_MOON_THEME: "res://assets/audio/blood_moon_theme.ogg",
		Sound.SHOP_THEME: "res://assets/audio/shop_theme.ogg",
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

	# Zone overrides (cave/boss/interior) remember the ambient track that was
	# playing so resume_ambient_music() can restore it. Nested overrides keep
	# the existing base â€” an override never chains into _base_music.
	if _is_override_track(sound_type):
		if _base_music < 0:
			if _current_music == Sound.AMBIENT_DAY or _current_music == Sound.AMBIENT_NIGHT:
				_base_music = _current_music
			else:
				_base_music = _derive_ambient_from_phase()

	# Enable looping. WAV streams use loop_mode (enum), OGG/MP3 use loop (bool).
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	else:
		stream.set("loop", true)
	_current_music = sound_type

	if not _music_player.playing:
		# Nothing playing yet â€” just start
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
	_crossfade_tween = tween
	tween.tween_property(_music_player, "volume_db", -80.0, fade_seconds)
	tween.tween_callback(func():
		_music_player.stop()
	)

## Respond to day/night phase changes â€” switch ambient music.
func _on_phase_changed(phase: int) -> void:
	# Always track the ambient theme matching this phase, so leaving a
	# cave/boss/interior after a phase change restores the correct track.
	_base_music = _get_ambient_for_phase(phase)
	if _current_music >= 0 and _current_music != Sound.AMBIENT_DAY and _current_music != Sound.AMBIENT_NIGHT:
		return  # a zone override or the menu music is playing
	# Night music is tied to the NIGHT phase (hour 20+), which is exactly when
	# the day/night overlay reaches full darkness. During DUSK the screen is
	# still mostly light (the overlay only ramps 0->0.7 over hours 18-20), so
	# keep the day theme playing until night actually takes effect visually.
	match phase:
		0, 1, 2:  # DAWN, DAY, DUSK
			play_music(Sound.AMBIENT_DAY, 2.0)
		3:  # NIGHT
			play_music(Sound.AMBIENT_NIGHT, 2.0)

## True when the track is a zone override (replaces ambient while inside a
## cave, boss fight, or building interior).
func _is_override_track(sound_type: Sound) -> bool:
	return sound_type == Sound.CAVE_MUSIC or sound_type == Sound.BOSS_MUSIC or sound_type == Sound.INTERIOR_MUSIC \
		or sound_type == Sound.PLAINS_THEME or sound_type == Sound.SNOWLAND_THEME \
		or sound_type == Sound.ICE_CREAM_LAND_THEME or sound_type == Sound.DESERT_THEME \
		or sound_type == Sound.VOLCANO_THEME or sound_type == Sound.ETHEREAL_THEME \
		or sound_type == Sound.PIRATE_RAID_THEME or sound_type == Sound.BLOOD_MOON_THEME \
		or sound_type == Sound.SHOP_THEME

## Ambient theme for a day/night phase. Only the NIGHT phase uses the night
## theme (matching when the day/night overlay reaches full darkness); DAWN,
## DAY and DUSK all use the day theme.
func _get_ambient_for_phase(phase: int) -> int:
	return Sound.AMBIENT_NIGHT if phase == DayNightCycle.Phase.NIGHT else Sound.AMBIENT_DAY

## Resolve the ambient theme from the current day/night phase. Fallback used
## when no phase change has been observed yet (e.g. world regen on join).
func _derive_ambient_from_phase() -> int:
	var phase: int = 0
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		# Typed as Variant: during early worldgen "day_night" may not be a
		# Node yet (or may be a Resource-style object) â€” a typed Node local
		# would throw a RefCountedâ†’Node assignment error.
		var day_night: Variant = gm.get("day_night")
		if day_night != null:
			var current_phase: Variant = day_night.get("current_phase")
			if current_phase != null:
				phase = int(current_phase)
	return _get_ambient_for_phase(phase)

## Return to the ambient day/night theme after a zone override ends. Falls
## back to the current phase if no base track was captured.
func resume_ambient_music(fade_seconds: float = 1.0) -> void:
	# Don't stomp a non-ambient, non-zone-override track that's already playing
	# â€” e.g. the main-menu music while the world initializes behind the menu.
	# Zone overrides (cave/boss/interior) are still restored to ambient here.
	if _current_music >= 0 \
			and _current_music != Sound.AMBIENT_DAY \
			and _current_music != Sound.AMBIENT_NIGHT \
			and not _is_override_track(_current_music):
		_base_music = -1
		return
	# A boss that is still alive owns the soundtrack â€” never drop it to ambient
	# while respawning or leaving a zone during a live boss fight. (The dying
	# boss is removed from the "bosses" group before this is called on a kill.)
	if _is_boss_fight_active():
		play_music(Sound.BOSS_MUSIC, fade_seconds)
		return
	var target: int = _base_music if _base_music >= 0 else _derive_ambient_from_phase()
	_base_music = -1
	play_music(target, fade_seconds)

## Map an expedition island type to its background-music track. Order matches
## ExpeditionIsland.IslandType (PLAIN=0, SNOWLAND=1, ICE_CREAM_LAND=2,
## DESERT=3, VOLCANIC=4, ETHEREAL=5). Unknown types fall back to plains.
static func island_theme_for_type(island_type: int) -> int:
	match island_type:
		1: return Sound.SNOWLAND_THEME
		2: return Sound.ICE_CREAM_LAND_THEME
		3: return Sound.DESERT_THEME
		4: return Sound.VOLCANO_THEME
		5: return Sound.ETHEREAL_THEME
		_: return Sound.PLAINS_THEME  # 0 = PLAIN, plus any unknown fallback

## Restore the ambient track, but ONLY if the given override is currently the
## one playing. Guards against a newer override (an interior, cave, or another
## event) being stomped when an older event (raid / blood-moon / shop / island)
## ends mid-encounter.
func restore_ambient_if(sound_type: Sound, fade_seconds: float = 0.8) -> void:
	if _current_music == sound_type:
		resume_ambient_music(fade_seconds)

## True while at least one boss node is alive in the scene. Used to keep the
## boss theme playing through respawns / zone exits during a live boss fight.
func _is_boss_fight_active() -> bool:
	for b in get_tree().get_nodes_in_group("bosses"):
		if is_instance_valid(b) and b.is_inside_tree():
			return true
	return false

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
