extends Node

## Autoload singleton. Tracks the player's Farmer Level (1-100) and grants
## passive perks as they level up. XP is earned from every gameplay activity:
## farming, combat, crafting, cooking, gathering, building, and trading.
##
## Perks (cumulative):
##   • Every level:  +2 Max HP
##   • Every 5 lv:   +5% melee damage
##   • Every 10 lv:  +5% movement speed
##   • Every 25 lv:  +15% harvest yield
##   • Every level:  +0.5% luck (mutation/harvest bonus chance)
##   • Level 100:    "Master Farmer" — all perks maxed
##
## XP curve:  xp_to_next(level) = floor(35 * level^1.3 + 25)
##   L1→L2: 60      L25→L26: ~2,348     L50→L51: ~5,683     L99→L100: ~13,777

signal xp_changed(current_xp: int, xp_for_next: int)
signal level_up(new_level: int)

const MAX_LEVEL: int = 100

# Base stats that perks are applied on top of
const BASE_MAX_HEALTH: int = 100
const BASE_MAX_HUNGER: int = 100

var player_level: int = 1
var current_xp: int = 0
var total_xp_earned: int = 0
var recent_xp_sources: Array[Dictionary] = []

## XP awarded per activity. Indexed by source string.
const XP_REWARDS := {
	# Farming
	"till": 3,
	"water": 3,
	"plant": 4,
	"harvest": 8,
	"harvest_quality": 8,  # bonus per quality tier above Normal
	"mutation": 30,
	"sprinkler": 10,
	# Combat
	"hit_enemy": 4,
	"kill_enemy": 20,
	"kill_boss": 750,
	# Crafting & building
	"craft": 6,
	"cook": 8,
	"brew": 8,
	"build": 12,
	# Mining
	"mine_ore": 3,
	"mine_ore_final": 6,
	# Gathering
	"gather": 5,
	# Economy
	"sell": 1,        # per item sold (capped per transaction in add_xp)
	"buy_upgrade": 30,
	# Discovery
	"discover_crop": 20,
	"discover_mutation": 40,
}

func _ready() -> void:
	add_to_group("level_manager")


## Add XP from a gameplay activity. Source is a string key in XP_REWARDS.
## Pass a custom amount to override the default (e.g. for sell: amount = item count).
func add_xp(amount: int, source: String = "") -> void:
	if player_level >= MAX_LEVEL:
		return  # already maxed
	if amount <= 0:
		return
	total_xp_earned += amount
	if not source.is_empty():
		recent_xp_sources.append({"source": source, "amount": amount, "time": Time.get_ticks_msec()})
		if recent_xp_sources.size() > 5:
			recent_xp_sources.pop_front()
	current_xp += amount

	# Show floating XP text above the player
	_spawn_xp_floating_text(amount)

	_check_level_up()
	xp_changed.emit(current_xp, get_xp_for_next_level())


## Spawn a floating "+X XP" text above the player's head.
func _spawn_xp_floating_text(amount: int) -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if not player:
		return
	EffectSpawner.spawn_xp_notification(amount, player.global_position + Vector2(0, -32))


## Add XP by looking up the reward for a named source activity.
func add_xp_source(source: String, multiplier: float = 1.0) -> void:
	var base: int = XP_REWARDS.get(source, 0)
	if base <= 0:
		return
	add_xp(roundi(base * multiplier), source)


## XP required to advance from `level` to `level + 1`.
static func xp_to_next(level: int) -> int:
	return floori(35.0 * pow(float(level), 1.3) + 25.0)


## XP needed for the player to reach the next level.
func get_xp_for_next_level() -> int:
	return xp_to_next(player_level)


## Current XP progress as a 0.0-1.0 ratio (for UI bars).
func get_xp_progress_ratio() -> float:
	if player_level >= MAX_LEVEL:
		return 1.0
	var needed: int = get_xp_for_next_level()
	if needed <= 0:
		return 0.0
	return clampf(float(current_xp) / float(needed), 0.0, 1.0)


func get_level() -> int:
	return player_level

func get_xp() -> int:
	return current_xp

func get_total_xp() -> int:
	return total_xp_earned

func is_max_level() -> bool:
	return player_level >= MAX_LEVEL


func _check_level_up() -> void:
	while player_level < MAX_LEVEL and current_xp >= get_xp_for_next_level():
		current_xp -= get_xp_for_next_level()
		player_level += 1
		_on_level_reached(player_level)


func _on_level_reached(new_level: int) -> void:
	level_up.emit(new_level)
	AudioManager.play(AudioManager.Sound.LEVEL_UP)
	# Perk milestones
	if new_level == MAX_LEVEL:
		ToastNotification.show_toast("⭐ MASTER FARMER! You reached level 100!", ToastNotification.ToastType.SUCCESS, 6.0)
	elif new_level % 25 == 0:
		ToastNotification.show_toast("🌟 Level %d! Major milestone reached!" % new_level, ToastNotification.ToastType.SUCCESS, 4.0)
	elif new_level % 10 == 0:
		ToastNotification.show_toast("✨ Level %d! +Speed perk gained!" % new_level, ToastNotification.ToastType.SUCCESS, 3.5)
	elif new_level % 5 == 0:
		ToastNotification.show_toast("⚔️ Level %d! +Damage perk gained!" % new_level, ToastNotification.ToastType.SUCCESS, 3.0)
	else:
		ToastNotification.show_toast("📈 Level %d! Max HP increased!" % new_level, ToastNotification.ToastType.SUCCESS, 2.5)


# ---------------------------------------------------------------------------
# Perk calculations
# ---------------------------------------------------------------------------

## Max HP: base 100 + 2 per level above 1.  L100 = 298.
func get_max_health() -> int:
	return BASE_MAX_HEALTH + (player_level - 1) * 2

## Max Hunger: fixed at base 100 (does NOT scale with level).
func get_max_hunger() -> int:
	return BASE_MAX_HUNGER

## Melee damage multiplier: 1.0 + 5% per 5 levels.  L100 = 1.99 (~2x).
func get_damage_multiplier() -> float:
	return 1.0 + floori(float(player_level - 1) / 5.0) * 0.05

## Movement speed multiplier: 1.0 + 3% per 10 levels.  L100 ≈ 1.3x.
func get_speed_multiplier() -> float:
	return 1.0 + floori(float(player_level - 1) / 10.0) * 0.03

## Harvest yield multiplier: 1.0 + 15% per 25 levels.  L100 = 1.59.
func get_harvest_multiplier() -> float:
	return 1.0 + floori(float(player_level - 1) / 25.0) * 0.15

## Luck multiplier (mutation/harvest bonus chance): 1.0 + 0.5% per level.  L100 = 1.495.
func get_luck_multiplier() -> float:
	return 1.0 + (player_level - 1) * 0.005


## Returns a human-readable perks summary for the current level (for UI).
func get_perks_summary() -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("Max HP: %d" % get_max_health())
	lines.append("Max Hunger: %d" % get_max_hunger())
	lines.append("Damage: +%d%%" % roundi((get_damage_multiplier() - 1.0) * 100.0))
	lines.append("Speed: +%d%%" % roundi((get_speed_multiplier() - 1.0) * 100.0))
	lines.append("Harvest: +%d%%" % roundi((get_harvest_multiplier() - 1.0) * 100.0))
	lines.append("Luck: +%d%%" % roundi((get_luck_multiplier() - 1.0) * 100.0))
	return "\n".join(lines)


# ---------------------------------------------------------------------------
# Save / Load
# ---------------------------------------------------------------------------

func serialize() -> Dictionary:
	return {
		"level": player_level,
		"current_xp": current_xp,
		"total_xp": total_xp_earned,
	}


func deserialize(data: Dictionary) -> void:
	player_level = clampi(int(data.get("level", 1)), 1, MAX_LEVEL)
	current_xp = maxi(0, int(data.get("current_xp", 0)))
	total_xp_earned = maxi(0, int(data.get("total_xp", 0)))
	xp_changed.emit(current_xp, get_xp_for_next_level())


func reset() -> void:
	player_level = 1
	current_xp = 0
	total_xp_earned = 0
	xp_changed.emit(current_xp, get_xp_for_next_level())
	level_up.emit(player_level)
