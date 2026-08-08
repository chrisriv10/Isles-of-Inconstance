extends Node
## Verifies the new expedition-island / event / shop music is wired into the
## AudioManager and the World / PirateRaid / BloodMoon / Shop trigger sites.
## These are source-grep checks (matches the rest of the test suite's pattern).

var _passes: Array[String] = []
var _fails: Array[String] = []

func _check(cond: bool, msg: String) -> void:
	if cond:
		_passes.append(msg)
	else:
		_fails.append(msg)

func _file_contains(path: String, needle: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return false
	var text: String = f.get_as_text()
	f.close()
	return text.contains(needle)

func _run_all() -> void:
	test_audio_manager_registers_tracks()
	test_audio_manager_marks_overrides()
	test_island_theme_for_type()
	test_world_island_music_hooks()
	test_event_music_hooks()
	test_shop_music_hooks()
	print("== RESULT: %d passed, %d failed ==" % [_passes.size(), _fails.size()])
	if _fails.is_empty():
		print("TEST-PASS")
	else:
		print("TEST-FAIL")
		for f in _fails:
			print("  FAIL: " + f)

func test_audio_manager_registers_tracks() -> void:
	var am := "res://scripts/autoload/AudioManager.gd"
	for entry in [
		"PLAINS_THEME", "SNOWLAND_THEME", "ICE_CREAM_LAND_THEME", "DESERT_THEME",
		"VOLCANO_THEME", "ETHEREAL_THEME", "PIRATE_RAID_THEME", "BLOOD_MOON_THEME", "SHOP_THEME",
	]:
		_check(_file_contains(am, entry), "AudioManager enum has " + entry)
	for pair in [
		"plains_theme.mp3", "snowland_theme.mp3", "icecreamland_theme.wav",
		"desert_theme.wav", "volcano_theme.mp3", "ethereal_theme.wav",
		"pirate_raid_theme.mp3", "blood_moon_theme.mp3", "shop_theme.wav",
	]:
		_check(_file_contains(am, pair), "AudioManager loads " + pair)

func test_audio_manager_marks_overrides() -> void:
	var am := "res://scripts/autoload/AudioManager.gd"
	for entry in [
		"Sound.PLAINS_THEME", "Sound.SNOWLAND_THEME", "Sound.ICE_CREAM_LAND_THEME",
		"Sound.DESERT_THEME", "Sound.VOLCANO_THEME", "Sound.ETHEREAL_THEME",
		"Sound.PIRATE_RAID_THEME", "Sound.BLOOD_MOON_THEME", "Sound.SHOP_THEME",
	]:
		_check(_file_contains(am, entry), "_is_override_track handles " + entry.split(".")[1])
	# Restore guard helper must exist.
	_check(_file_contains(am, "func restore_ambient_if"), "AudioManager has restore_ambient_if")
	_check(_file_contains(am, "func island_theme_for_type"), "AudioManager has island_theme_for_type")

func test_island_theme_for_type() -> void:
	var am := "res://scripts/autoload/AudioManager.gd"
	for pair in ["1: return Sound.SNOWLAND_THEME", "2: return Sound.ICE_CREAM_LAND_THEME",
		"3: return Sound.DESERT_THEME", "4: return Sound.VOLCANO_THEME",
		"5: return Sound.ETHEREAL_THEME", "_: return Sound.PLAINS_THEME"]:
		_check(_file_contains(am, pair), "island_theme_for_type maps " + pair.split(":")[0])

func test_world_island_music_hooks() -> void:
	var w := "res://scripts/world/World.gd"
	_check(_file_contains(w, "AudioManager.island_theme_for_type(island_type)"),
		"World plays island theme on enter")
	_check(_file_contains(w, "resume_ambient_music(1.0)"),
		"World restores ambient on island exit")

func test_event_music_hooks() -> void:
	var pr := "res://scripts/world/PirateRaidEvent.gd"
	_check(_file_contains(pr, "AudioManager.play_music(AudioManager.Sound.PIRATE_RAID_THEME)"),
		"PirateRaid plays raid theme")
	_check(_file_contains(pr, "AudioManager.restore_ambient_if(AudioManager.Sound.PIRATE_RAID_THEME)"),
		"PirateRaid restores ambient when ship removed")
	var bm := "res://scripts/world/BloodMoonEvent.gd"
	_check(_file_contains(bm, "AudioManager.play_music(AudioManager.Sound.BLOOD_MOON_THEME)"),
		"BloodMoon plays theme")
	_check(_file_contains(bm, "AudioManager.restore_ambient_if(AudioManager.Sound.BLOOD_MOON_THEME)"),
		"BloodMoon restores ambient")

func test_shop_music_hooks() -> void:
	var s := "res://scripts/ui/Shop.gd"
	_check(_file_contains(s, "AudioManager.play_music(AudioManager.Sound.SHOP_THEME)"),
		"Shop opens with shop theme")
	_check(_file_contains(s, "AudioManager.restore_ambient_if(AudioManager.Sound.SHOP_THEME)"),
		"Shop close restores ambient")

func _init() -> void:
	_run_all()
