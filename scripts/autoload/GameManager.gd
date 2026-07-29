extends Node

## Autoload singleton. Owns global game state that many systems care about:
## the day/time cycle, currency, and pause state. Systems subscribe to the
## signals below instead of polling, which keeps them decoupled.

signal day_changed(day: int)
signal time_changed(hour: int, minute: int)
signal money_changed(amount: int)
signal bank_balance_changed(amount: int)
signal game_paused(is_paused: bool)
@warning_ignore("unused_signal")
signal crop_mutated(old_name: String, new_name: String, mutation_name: String)
signal season_changed(season: int, season_name: String)
signal phase_changed(phase: int)
signal game_mode_changed(mode: int)
signal health_changed(health: int, max_health: int)
signal hunger_changed(hunger: int, max_hunger: int)
signal armor_changed(defense: int)
signal hardcore_death_occurred()

## Peaceful = no enemies, survival = night enemies spawn, creative = god mode + tool.
## Hardcore = same as survival, but death deletes the save file.
enum GameMode { PEACEFUL, SURVIVAL, CREATIVE, HARDCORE }

## Dynamic HP/Hunger caps — recalibrated by LevelManager on level-up.
## Base values for level 1; LevelManager.get_max_health() / get_max_hunger()
## are the authoritative sources.
var MAX_HEALTH: int = 100
var MAX_HUNGER: int = 100

@export var minutes_per_day: int = 24 * 60
@export var real_seconds_per_game_minute: float = 0.5

var current_day: int = 1
var current_minute_of_day: int = 6 * 60  # start at 06:00
var money: int = 50
## Money stored in the bank (safe from death, earns daily interest)
var bank_balance: int = 0
var is_paused: bool = false

# Creative mode toggles
var creative_time_paused: bool = false
var creative_instant_growth: bool = true
var creative_infinite_health: bool = false
var creative_no_hunger: bool = false
var creative_enemy_spawning: bool = false

# Reputation bonuses (set by TownManager when thresholds reached)
var rep_bank_interest_doubled: bool = false
var rep_sell_price_mult: float = 1.0

# Season system
var season_system: SeasonSystem = null
var day_night: DayNightCycle = null

# Player identity
var player_name: String = "Farmer"
var save_name: String = ""

# Weather system
var weather_system: WeatherSystem = null

# Cooking proximity flags
static var near_campfire: bool = false
static var inside_interior: bool = false

# Game completion flag — set when the Inconstant Soul is defeated
var game_completed: bool = false

# ── Player dialogue flags ──
# Track which first-time events the player has seen, so dialogue bubbles
# only play once per playthrough.
var seen_dialogues: Dictionary = {}

# Chest inventories keyed by building cell "x,y" — persists across
# interior enter/exit cycles so stored items aren't lost.
# Each value is an Array of null or {"item_id": String, "count": int} slots.
static var chest_inventories: Dictionary = {}

# Barn animal stall collection data keyed by barn cell "x,y".
# Each entry maps stall_id -> last_collection_day.
# e.g. {"5,3": {"chickens": 2, "cows": 1, "sheep": 2}}
static var barn_stall_data: Dictionary = {}

# ── Farming stats ──
# Lifetime stats tracked for the Encyclopedia farming journal.
var total_crops_harvested: int = 0
var total_giant_crops_harvested: int = 0
var total_mutations_occurred: int = 0
var total_compost_produced: int = 0
var total_seeds_planted: int = 0
var best_quality_tier: int = 0

# Health & Hunger
var health: int = MAX_HEALTH
var hunger: int = MAX_HUNGER

# ── Armor system ──
# Armor piece slots the player can equip. Each maps slot -> item_id or "" for empty.
var equipped_armor: Dictionary = {
	"helmet": "",
	"chestplate": "",
	"leggings": "",
	"boots": "",
	"accessory": "",
}

# Gingerbread armor set bonus: full set blocks all combat damage, but the player can't deal damage either.
var _gingerbread_invincible: bool = false

func set_gingerbread_invincible(enabled: bool) -> void:
	_gingerbread_invincible = enabled

func is_gingerbread_invincible() -> bool:
	return _gingerbread_invincible

# Defense points per armor piece (item_id -> defense_value).
const ARMOR_DEFENSE: Dictionary = {
	"leather_helmet": 1,
	"leather_chestplate": 2,
	"leather_leggings": 1,
	"leather_boots": 1,
	"copper_helmet": 2,
	"copper_chestplate": 3,
	"copper_leggings": 2,
	"copper_boots": 1,
	"iron_helmet": 2,
	"iron_chestplate": 3,
	"iron_leggings": 2,
	"iron_boots": 1,
	"silver_helmet": 3,
	"silver_chestplate": 4,
	"silver_leggings": 3,
	"silver_boots": 2,
	"gold_helmet": 3,
	"gold_chestplate": 5,
	"gold_leggings": 3,
	"gold_boots": 2,
	"steel_helmet": 4,
	"steel_chestplate": 6,
	"steel_leggings": 4,
	"steel_boots": 3,
	"mythril_helmet": 5,
	"mythril_chestplate": 7,
	"mythril_leggings": 5,
	"mythril_boots": 4,
	"diamond_helmet": 6,
	"diamond_chestplate": 8,
	"diamond_leggings": 6,
	"diamond_boots": 5,
	"ruby_helmet": 5,
	"ruby_chestplate": 7,
	"ruby_leggings": 5,
	"ruby_boots": 4,
	"obsidian_helmet": 4,
	"obsidian_chestplate": 6,
	"obsidian_leggings": 4,
	"obsidian_boots": 3,
	"gingerbread_helmet": 3,
	"gingerbread_chestplate": 5,
	"gingerbread_leggings": 3,
	"gingerbread_boots": 2,
	"shell_necklace": 1,
	"starlight_amulet": 1,
	"ice_ward": 2,
}

## Returns the player's total armor defense points.
func get_armor_defense() -> int:
	var total: int = 0
	for slot: String in equipped_armor:
		var item_id: String = equipped_armor[slot]
		if not item_id.is_empty():
			total += ARMOR_DEFENSE.get(item_id, 0)
	return total

## Equip an armor item into its appropriate slot. Returns the item that was
## previously in that slot (or "" if empty) so the caller can swap them.
func equip_armor(item_id: String) -> String:
	var slot: String = _armor_slot_for(item_id)
	if slot.is_empty():
		return ""
	var old_item: String = equipped_armor[slot]
	equipped_armor[slot] = item_id
	armor_changed.emit(get_armor_defense())
	# Check if all 4 armor slots are now filled
	_on_armor_slot_changed()
	return old_item

## Called whenever an armor slot changes — notifies ObjectiveManager.
func _on_armor_slot_changed() -> void:
	var filled := 0
	for sid in ["helmet", "chestplate", "leggings", "boots"]:
		var val = equipped_armor.get(sid, "")
		if not val.is_empty():
			filled += 1
	if filled >= 4:
		var om_armor := get_tree().get_first_node_in_group("objective_manager")
		if om_armor and om_armor.has_method("on_armor_equipped"):
			om_armor.on_armor_equipped()


## Unequip the armor piece in the given slot, returning the item_id that was there.
func unequip_armor(slot: String) -> String:
	if not equipped_armor.has(slot):
		return ""
	var old_item: String = equipped_armor[slot]
	equipped_armor[slot] = ""
	armor_changed.emit(get_armor_defense())
	return old_item

## Returns the slot name for an armor item_id, or "" if it's not armor.
static func _armor_slot_for(item_id: String) -> String:
	match item_id:
		"leather_helmet", "copper_helmet", "iron_helmet", "silver_helmet", "gold_helmet", "steel_helmet", "mythril_helmet", "diamond_helmet", "ruby_helmet", "obsidian_helmet", "gingerbread_helmet":
			return "helmet"
		"leather_chestplate", "copper_chestplate", "iron_chestplate", "silver_chestplate", "gold_chestplate", "steel_chestplate", "mythril_chestplate", "diamond_chestplate", "ruby_chestplate", "obsidian_chestplate", "gingerbread_chestplate":
			return "chestplate"
		"leather_leggings", "copper_leggings", "iron_leggings", "silver_leggings", "gold_leggings", "steel_leggings", "mythril_leggings", "diamond_leggings", "ruby_leggings", "obsidian_leggings", "gingerbread_leggings":
			return "leggings"
		"leather_boots", "copper_boots", "iron_boots", "silver_boots", "gold_boots", "steel_boots", "mythril_boots", "diamond_boots", "ruby_boots", "obsidian_boots", "gingerbread_boots":
			return "boots"
		"shell_necklace", "starlight_amulet", "ice_ward":
			return "accessory"
	return ""

func reset_health() -> void:
	health = MAX_HEALTH
	health_changed.emit(health, MAX_HEALTH)

func reset_hunger() -> void:
	hunger = MAX_HUNGER
	hunger_changed.emit(hunger, MAX_HUNGER)

func take_damage(amount: int) -> void:
	if is_creative() and creative_infinite_health:
		return
	var original_amount: int = amount
	# Gingerbread armor set bonus: fully immune to combat damage
	if _gingerbread_invincible:
		if original_amount > 0:
			var player_node: Node2D = get_tree().get_first_node_in_group("player")
			var pos: Vector2 = player_node.global_position if player_node else Vector2.ZERO
			EffectSpawner.spawn_player_damage(0, pos + Vector2(0, -16), original_amount)
		return
	# Check i-frames — if the player is invulnerable, ignore damage
	var player: Node2D = get_tree().get_first_node_in_group("player")
	if player and player.has_method("is_invulnerable") and player.is_invulnerable():
		return
	# Armor reduces damage using the formula: damage * (1 - defense / (defense + 8))
	# This gives diminishing returns: 4 defense → ~33% reduction, 12 defense → 60%
	var defense: int = get_armor_defense()
	var pet_mgr: Node = PetManager
	if pet_mgr and pet_mgr.has_method("get_defense_bonus"):
		defense += int(pet_mgr.get_defense_bonus())
	if defense > 0:
		var reduction: float = float(defense) / (float(defense) + 8.0)
		amount = max(1, int(amount * (1.0 - reduction)))
	# Potion defense buff — multiplicative reduction after armor
	if BuffManager and BuffManager.has_method("get_strength"):
		var defense_buff: float = BuffManager.get_strength("defense")
		if defense_buff > 0.0:
			amount = max(1, int(amount * (1.0 - defense_buff)))
	var damage_dealt: int = amount
	health = max(0, health - damage_dealt)
	health_changed.emit(health, MAX_HEALTH)
	# Show damage as floating text near player (rises and fades like item pickups)
	if original_amount > 0:
		var pos: Vector2 = player.global_position if player else Vector2.ZERO
		var blocked_amount: int = original_amount - damage_dealt
		EffectSpawner.spawn_player_damage(damage_dealt, pos + Vector2(0, -16), blocked_amount)
	# Start i-frames after taking damage
	if player and player.has_method("start_invulnerability"):
		# Longer i-frames if the hit was big, else standard duration
		var iframe_duration: float = 1.0 if damage_dealt >= 15 else 0.5  # Harder mode — shorter i-frames
		player.start_invulnerability(iframe_duration)
	if health <= 0:
		_on_player_died()

func heal(amount: int) -> void:
	health = min(MAX_HEALTH, health + amount)
	health_changed.emit(health, MAX_HEALTH)

func change_hunger(amount: int) -> void:
	if is_creative() and creative_no_hunger and amount < 0:
		return  # no hunger drain when creative_no_hunger is on
	hunger = clampi(hunger + amount, 0, MAX_HUNGER)
	if is_creative() and creative_no_hunger and hunger < MAX_HUNGER:
		hunger = MAX_HUNGER  # always refill in creative
	hunger_changed.emit(hunger, MAX_HUNGER)

## Called when the player's level changes. Updates max HP and
## heals the player by the difference so leveling feels rewarding.
func _on_level_up(_new_level: int) -> void:
	var old_max_hp := MAX_HEALTH
	MAX_HEALTH = LevelManager.get_max_health()
	MAX_HUNGER = LevelManager.get_max_hunger()  # stays at 100 (doesn't scale)
	# Heal by the increase amount (so a +2 HP level-up heals 2 damage)
	var hp_gain := MAX_HEALTH - old_max_hp
	if hp_gain > 0:
		health = mini(MAX_HEALTH, health + hp_gain)
	health_changed.emit(health, MAX_HEALTH)
	hunger_changed.emit(hunger, MAX_HUNGER)


## Force-recalculate max stats from LevelManager (used on save load).
func refresh_max_stats() -> void:
	MAX_HEALTH = LevelManager.get_max_health()
	MAX_HUNGER = LevelManager.get_max_hunger()
	health = mini(health, MAX_HEALTH)
	hunger = mini(hunger, MAX_HUNGER)
	health_changed.emit(health, MAX_HEALTH)
	hunger_changed.emit(hunger, MAX_HUNGER)


func _hunger_tick() -> void:
	if is_creative() and creative_no_hunger:
		return
	# Energy buff reduces hunger drain (chance to skip tick)
	var energy_str: float = BuffManager.get_strength("energy") if BuffManager else 0.0
	if energy_str > 0.0:
		# Higher strength = higher chance to skip hunger tick
		if randf() < energy_str:
			return
	
	if hunger > 0:
		change_hunger(-1)
	# When starving, take damage instead
	if hunger <= 0 and health > 0:
		take_damage(2)

func _on_player_died() -> void:
	if is_hardcore():
		# Hardcore mode: delete the save and return to main menu
		print("Hardcore death! Deleting save...")
		SaveManager.delete_save_in_slot(SaveManager.current_slot)
		hardcore_death_occurred.emit()
		return
	
	print("Player died!")
	
	# If the player died inside a mine, clean up the mine state first.
	# This frees the mine room, resets inside_interior, and clears the
	# camera limits so the player isn't stuck looking at the mine void.
	var world_death := get_tree().get_first_node_in_group("world")
	if world_death and world_death.has_method("emergency_exit_mine"):
		world_death.emergency_exit_mine()
	
	# Reset health and hunger to full
	health = MAX_HEALTH
	hunger = MAX_HUNGER
	health_changed.emit(health, MAX_HEALTH)
	hunger_changed.emit(hunger, MAX_HUNGER)
	
	var player := get_tree().get_first_node_in_group("player")
	if player:
		# Teleport to overworld spawn (the player's starting island)
		if world_death:
			var spawn_cell := Vector2i(world_death.world_width - 35, world_death.world_height / 2)
			player.global_position = world_death.cell_to_world(spawn_cell)
		
		ToastNotification.show_toast("You collapsed!", ToastNotification.ToastType.WARNING, 4.0)

# Game mode
var game_mode: int = GameMode.SURVIVAL

func set_game_mode(mode: int) -> void:
	game_mode = mode
	game_mode_changed.emit(mode)

func is_survival() -> bool:
	# Hardcore mode uses all survival mechanics (enemies, hunger, etc.)
	return game_mode == GameMode.SURVIVAL or game_mode == GameMode.HARDCORE

func is_creative() -> bool:
	return game_mode == GameMode.CREATIVE

func is_hardcore() -> bool:
	return game_mode == GameMode.HARDCORE

var _minute_timer: float = 0.0

func _ready() -> void:
	day_night = DayNightCycle.new()
	# Set initial phase to match the default start time (06:00 = DAWN)
	day_night.current_phase = day_night.get_phase_for_hour(get_hour())
	_ensure_input_actions()
	# Listen for level-ups to update max HP & Hunger
	if not LevelManager.level_up.is_connected(_on_level_up):
		LevelManager.level_up.connect(_on_level_up)
	# Initialize weather system
	weather_system = WeatherSystem.new()
	add_child(weather_system)

## Create the "interact" input action if it's missing from project settings.
## This provides a robust fallback in case the project.godot file wasn't
## loaded correctly by the editor.
func _ensure_input_actions() -> void:
	if not InputMap.has_action("interact"):
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_E
		InputMap.add_action("interact")
		InputMap.action_add_event("interact", ev)

func _process(delta: float) -> void:
	if is_paused:
		return
	if is_creative() and creative_time_paused:
		return  # time frozen in creative mode
	_minute_timer += delta
	if _minute_timer >= real_seconds_per_game_minute:
		_minute_timer = 0.0
		_advance_minute()

func _advance_minute() -> void:
	current_minute_of_day += 1
	
	# Tick buff durations
	if BuffManager and BuffManager.has_method("tick_minute"):
		BuffManager.tick_minute()
	
	# Health buff: passive healing every 30 game minutes
	if current_minute_of_day % 30 == 0 and health < MAX_HEALTH:
		var health_str: float = BuffManager.get_strength("health") if BuffManager else 0.0
		if health_str > 0.0:
			var heal_amount: int = maxi(1, roundi(health_str * 2.0))
			heal(heal_amount)
	
	# Hunger decays every 20 game minutes (so ~36 per day) — Harder mode
	if current_minute_of_day % 20 == 0:
		_hunger_tick()
	
	if current_minute_of_day >= minutes_per_day:
		current_minute_of_day = 0
		current_day += 1
		
		# Advance season too
		if season_system:
			var old_season := season_system.current_season
			season_system.advance_day()
			if season_system.current_season != old_season:
				season_changed.emit(season_system.current_season, season_system.get_season_name())
		
		# Advance weather before emitting day_changed
		if weather_system:
			weather_system.advance_day()
			# Apply rain auto-watering to exposed farm plots
			var world := get_tree().get_first_node_in_group("world")
			if world and weather_system.is_raining():
				weather_system.apply_rain_watering(world)
		
		# Apply daily bank interest
		_apply_bank_interest()
		
		day_changed.emit(current_day)
		# Auto-save on day change
		SaveManager.save_game()
	
	var hour := get_hour()
	var minute := get_minute()
	time_changed.emit(hour, minute)
	
	if day_night:
		var new_phase := day_night.get_phase_for_hour(hour)
		if new_phase != day_night.current_phase:
			day_night.current_phase = new_phase
			phase_changed.emit(new_phase)
			if new_phase == DayNightCycle.Phase.NIGHT:
				AudioManager.play(AudioManager.Sound.NIGHT_START)

func get_hour() -> int:
	return floori(current_minute_of_day / 60.0)

func get_minute() -> int:
	return current_minute_of_day % 60

func get_time_string() -> String:
	return "%02d:%02d" % [get_hour(), get_minute()]

## Set time directly (for save/load)
func set_time(hour: int, minute: int) -> void:
	current_minute_of_day = hour * 60 + minute
	time_changed.emit(get_hour(), get_minute())

## Marks the game as completed (final boss defeated). Shows a permanent
## celebration toast and sets a save flag that persists across sessions.
func complete_game() -> void:
	game_completed = true
	ToastNotification.show_toast("🏆 You have conquered the Isles of Inconstance!", ToastNotification.ToastType.SUCCESS, 8.0)
	# Also mark the final objective — ObjectiveManager tracks boss kills

func add_money(amount: int) -> void:
	money = max(0, money + amount)
	money_changed.emit(money)
	if amount > 0 and Engine.has_singleton("ObjectiveManager"):
		ObjectiveManager.on_money_earned(amount)

func can_afford(amount: int) -> bool:
	return money >= amount

## Deposit money from wallet into the bank. Returns true if successful.
func deposit_money(amount: int) -> bool:
	if amount <= 0 or amount > money:
		return false
	money -= amount
	bank_balance += amount
	money_changed.emit(money)
	bank_balance_changed.emit(bank_balance)
	return true

## Withdraw money from the bank into the wallet. Returns true if successful.
func withdraw_money(amount: int) -> bool:
	if amount <= 0 or amount > bank_balance:
		return false
	bank_balance -= amount
	money += amount
	money_changed.emit(money)
	bank_balance_changed.emit(bank_balance)
	return true

## Convenience wrapper for purchases: only deducts if affordable.
## Returns true if the purchase went through.
func spend_money(amount: int) -> bool:
	if amount <= 0:
		return true
	if not can_afford(amount):
		return false
	add_money(-amount)
	return true

## Apply daily interest on bank balance (0.5% per day — ~15% per month)
func _apply_bank_interest() -> void:
	if bank_balance > 0:
		var rate: float = 0.005
		if rep_bank_interest_doubled:
			rate = 0.01
		var interest: int = max(1, ceilf(bank_balance * rate))
		bank_balance += interest
		bank_balance_changed.emit(bank_balance)

func set_paused(paused: bool) -> void:
	is_paused = paused
	game_paused.emit(is_paused)

## Get current season info
func get_season_name() -> String:
	if season_system:
		return season_system.get_season_name()
	return "Spring"

func get_season_phase() -> int:
	if day_night:
		return day_night.current_phase
	return DayNightCycle.Phase.DAY

func is_night() -> bool:
	if day_night:
		return day_night.is_night()
	return false

# ── Player dialogue flag helpers ──

## Dialogue flag IDs for first-time events.
const DIALOGUE_FIRST_EXPEDITION: String = "first_expedition"
const DIALOGUE_FIRST_MINE: String = "first_mine"
const DIALOGUE_FIRST_TOWN: String = "first_town"
const DIALOGUE_FIRST_BOSS_ENCOUNTER: String = "first_boss_encounter"
const DIALOGUE_DEFEATED_ROOT_WARDEN: String = "defeated_root_warden"
const DIALOGUE_DEFEATED_HOLLOW_STAG: String = "defeated_hollow_stag"
const DIALOGUE_DEFEATED_BLOOMING_WYRM: String = "defeated_blooming_wyrm"
const DIALOGUE_DEFEATED_INCONSTANT_SOUL: String = "defeated_inconstant_soul"

## Check if a specific dialogue has already been shown (i.e., this is a
## first-time event the player has already seen).
func has_seen_dialogue(flag_id: String) -> bool:
	return seen_dialogues.get(flag_id, false)

## Mark a dialogue as having been shown, so it won't repeat.
func mark_dialogue_seen(flag_id: String) -> void:
	seen_dialogues[flag_id] = true

## Convenience: check, show, and mark in one call.
## Returns true if the dialogue was shown (was first time), false if already seen.
func try_show_dialogue(flag_id: String, text: String, duration: float = 3.5) -> bool:
	if has_seen_dialogue(flag_id):
		return false
	mark_dialogue_seen(flag_id)
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("show_dialogue"):
		player.show_dialogue(text, duration)
	return true


# --- Creative mode helpers ---

func toggle_creative_time_pause() -> void:
	creative_time_paused = not creative_time_paused
	var msg := "Time " + ("Paused" if creative_time_paused else "Resumed")
	ToastNotification.show_toast(msg, ToastNotification.ToastType.INFO, 2.0)

func set_creative_time_paused(paused: bool) -> void:
	creative_time_paused = paused

func set_creative_instant_growth(enabled: bool) -> void:
	creative_instant_growth = enabled

func advance_days(count: int = 1) -> void:
	for i in range(count):
		current_minute_of_day = minutes_per_day  # force day rollover on next advance
		_advance_minute()  # this will trigger day change
	# ensure we're at a reasonable hour after fast-forward
	current_minute_of_day = 6 * 60  # reset to 06:00
	time_changed.emit(get_hour(), get_minute())
