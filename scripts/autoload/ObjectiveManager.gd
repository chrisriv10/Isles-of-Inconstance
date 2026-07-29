extends Node

## Simple milestone tracker. Listens to game events and marks objectives
## as complete when thresholds are hit. Shows a celebratory toast on
## completion and a small HUD indicator for the next goal.

signal objective_completed(objective_id: int, objective_name: String)
signal objectives_updated()

enum ObjectiveType {
	PLANT_FIRST_CROP,
	HARVEST_10_CROPS,
	HARVEST_50_CROPS,
	TILL_25_TILES,
	WATER_25_TILES,
	CRAFT_ITEM,
	BUY_UPGRADE,
	EARN_1000_GOLD,
	EARN_5000_GOLD,
	PLACE_SPRINKLER,
	COOK_A_MEAL,
	SLAY_ENEMIES,
	DEFEAT_ROOT_WARDEN,
	DEFEAT_HOLLOW_STAG,
	DEFEAT_BLOOMING_WYRM,
	DEFEAT_INCONSTANT_SOUL,
	SURVIVE_PIRATE_RAID,
	# === New objectives (v2) ===
	ENTER_MINE,           # 17
	COLLECT_100_ORE,      # 18
	SMELT_INGOT,          # 19
	REACH_DEPTH_3,        # 20
	PLACE_FIRST_BUILDING, # 21
	PLACE_10_BUILDINGS,   # 22
	UNLOCK_FIRST_PET,     # 23
	UNLOCK_3_PETS,        # 24
	EQUIP_ALL_ARMOR,      # 25
	BREED_FIRST_ANIMAL,   # 26
	SLAY_25_ENEMIES,      # 27
	COOK_5_MEALS,         # 28
	DISCOVER_5_CROPS,     # 29
	INNKEEPER_100_GOLD,   # 30
	REACH_LEVEL_25,       # 31
	REACH_LEVEL_50,       # 32
	# === Town objectives (v3) ===
	RESTORE_FIRST_BUILDING,  # 33
	RESTORE_3_BUILDINGS,     # 34
	RESTORE_6_BUILDINGS,     # 35
	RESTORE_ALL_BUILDINGS,   # 36
	RECRUIT_FIRST_RESIDENT,  # 37
	RECRUIT_3_RESIDENTS,     # 38
	RECRUIT_ALL_RESIDENTS,   # 39
	EARN_TOWN_REPUTATION_300, # 40
	BAKE_IRIDIUM_ITEM,       # 41
	SELL_AT_RESTAURANT,      # 42
	REACH_TOWN_LEVEL_3,      # 43
	REACH_TOWN_LEVEL_5,      # 44
}

const OBJECTIVE_DEFS := {
	ObjectiveType.PLANT_FIRST_CROP: {"name": "First Steps", "desc": "Plant your first crop", "icon": "🌱"},
	ObjectiveType.HARVEST_10_CROPS: {"name": "Budding Farmer", "desc": "Harvest 10 crops", "icon": "🌾", "threshold": 10},
	ObjectiveType.HARVEST_50_CROPS: {"name": "Green Thumb", "desc": "Harvest 50 crops", "icon": "🌾", "threshold": 50},
	ObjectiveType.TILL_25_TILES: {"name": "Soil Turner", "desc": "Till 25 tiles", "icon": "⛏️", "threshold": 25},
	ObjectiveType.WATER_25_TILES: {"name": "Water Bearer", "desc": "Water 25 tiles", "icon": "💧", "threshold": 25},
	ObjectiveType.CRAFT_ITEM: {"name": "Crafter", "desc": "Craft your first item", "icon": "🔨"},
	ObjectiveType.BUY_UPGRADE: {"name": "Investor", "desc": "Buy your first upgrade", "icon": "⬆️"},
	ObjectiveType.EARN_1000_GOLD: {"name": "Shop Regular", "desc": "Earn 1000 coins total", "icon": "💰", "threshold": 1000},
	ObjectiveType.EARN_5000_GOLD: {"name": "Merchant Prince", "desc": "Earn 5000 coins total", "icon": "💰", "threshold": 5000},
	ObjectiveType.PLACE_SPRINKLER: {"name": "Auto-Farmer", "desc": "Place a sprinkler", "icon": "💦"},
	ObjectiveType.COOK_A_MEAL: {"name": "Chef", "desc": "Cook a meal at a campfire", "icon": "🍲"},
	ObjectiveType.SLAY_ENEMIES: {"name": "Ghost Buster", "desc": "Defeat your first enemy", "icon": "⚔️", "threshold": 1},
	ObjectiveType.DEFEAT_ROOT_WARDEN: {"name": "Spirit Harvest I", "desc": "Defeat the Root Warden", "icon": "🌿"},
	ObjectiveType.DEFEAT_HOLLOW_STAG: {"name": "Spirit Harvest II", "desc": "Defeat the Hollow Stag", "icon": "🦌"},
	ObjectiveType.DEFEAT_BLOOMING_WYRM: {"name": "Spirit Harvest III", "desc": "Defeat the Blooming Wyrm", "icon": "🐛"},
	ObjectiveType.DEFEAT_INCONSTANT_SOUL: {"name": "Spirit Harvest IV", "desc": "Defeat the Inconstant Soul", "icon": "💜"},
	ObjectiveType.SURVIVE_PIRATE_RAID: {"name": "Seafarer", "desc": "Survive a pirate raid", "icon": "🏴‍☠️"},
	# === New objectives (v2) ===
	ObjectiveType.ENTER_MINE: {"name": "Caver", "desc": "Enter the mines for the first time", "icon": "⛏️"},
	ObjectiveType.COLLECT_100_ORE: {"name": "Prospector", "desc": "Mine 100 ores total", "icon": "💎", "threshold": 100},
	ObjectiveType.SMELT_INGOT: {"name": "Smelter", "desc": "Smelt your first ingot", "icon": "🔥"},
	ObjectiveType.REACH_DEPTH_3: {"name": "Deep Digger", "desc": "Reach mine depth level 3", "icon": "⬇️", "threshold": 3},
	ObjectiveType.PLACE_FIRST_BUILDING: {"name": "Homesteader", "desc": "Place your first building", "icon": "🏠"},
	ObjectiveType.PLACE_10_BUILDINGS: {"name": "Architect", "desc": "Place 10 buildings", "icon": "🏘️", "threshold": 10},
	ObjectiveType.UNLOCK_FIRST_PET: {"name": "New Friend", "desc": "Unlock your first pet companion", "icon": "🐾"},
	ObjectiveType.UNLOCK_3_PETS: {"name": "Menagerie", "desc": "Unlock 3 different pets", "icon": "🦊", "threshold": 3},
	ObjectiveType.EQUIP_ALL_ARMOR: {"name": "Kitted Out", "desc": "Equip armor in all 4 slots", "icon": "🛡️"},
	ObjectiveType.BREED_FIRST_ANIMAL: {"name": "New Life", "desc": "Breed two animals to produce a baby", "icon": "🐣"},
	ObjectiveType.SLAY_25_ENEMIES: {"name": "Vanquisher", "desc": "Defeat 25 enemies", "icon": "⚔️", "threshold": 25},
	ObjectiveType.COOK_5_MEALS: {"name": "Home Cook", "desc": "Cook 5 meals at a campfire", "icon": "🍲", "threshold": 5},
	ObjectiveType.DISCOVER_5_CROPS: {"name": "Botanist", "desc": "Discover 5 different crop types", "icon": "🔬", "threshold": 5},
	ObjectiveType.INNKEEPER_100_GOLD: {"name": "Innkeeper", "desc": "Earn 100 coins from hotel guests", "icon": "🏨", "threshold": 100},
	ObjectiveType.REACH_LEVEL_25: {"name": "Journeyman", "desc": "Reach Farmer Level 25", "icon": "🌟", "threshold": 25},
	ObjectiveType.REACH_LEVEL_50: {"name": "Master Farmer", "desc": "Reach Farmer Level 50", "icon": "👑", "threshold": 50},
	# === Town objectives (v3) ===
	ObjectiveType.RESTORE_FIRST_BUILDING: {"name": "First Light", "desc": "Restore your first ruined building", "icon": "🌅"},
	ObjectiveType.RESTORE_3_BUILDINGS: {"name": "Rebuilder", "desc": "Restore 3 buildings", "icon": "🏗️", "threshold": 3},
	ObjectiveType.RESTORE_6_BUILDINGS: {"name": "Town Planner", "desc": "Restore 6 buildings", "icon": "🏘️", "threshold": 6},
	ObjectiveType.RESTORE_ALL_BUILDINGS: {"name": "Restorer", "desc": "Restore all ruined buildings", "icon": "🏛️", "threshold": 11},
	ObjectiveType.RECRUIT_FIRST_RESIDENT: {"name": "New Neighbor", "desc": "Welcome your first town resident", "icon": "🤝"},
	ObjectiveType.RECRUIT_3_RESIDENTS: {"name": "Growing Community", "desc": "Have 3 town residents", "icon": "👨‍👩‍👧‍👦", "threshold": 3},
	ObjectiveType.RECRUIT_ALL_RESIDENTS: {"name": "Mayor", "desc": "Fill all town residences", "icon": "👑", "threshold": 8},
	ObjectiveType.EARN_TOWN_REPUTATION_300: {"name": "Well Liked", "desc": "Earn 300 town reputation", "icon": "⭐", "threshold": 300},
	ObjectiveType.BAKE_IRIDIUM_ITEM: {"name": "Master Baker", "desc": "Bake an Iridium-quality item", "icon": "🥇"},
	ObjectiveType.SELL_AT_RESTAURANT: {"name": "Purveyor", "desc": "Sell crops at the restaurant", "icon": "🧺"},
	ObjectiveType.REACH_TOWN_LEVEL_3: {"name": "Village Status", "desc": "Reach Town Level 3", "icon": "🏘️", "threshold": 3},
	ObjectiveType.REACH_TOWN_LEVEL_5: {"name": "Thriving Settlement", "desc": "Reach Town Level 5", "icon": "🌟", "threshold": 5},
}

# ---------------------------------------------------------------------------
# Objective categories (for tabbed display)
# ---------------------------------------------------------------------------

## Category key -> {name, icon, types[]}
const OBJECTIVE_CATEGORIES := {
	"farming": {
		"name": "Farming",
		"icon": "🌾",
		"types": [
			ObjectiveType.PLANT_FIRST_CROP,
			ObjectiveType.HARVEST_10_CROPS,
			ObjectiveType.HARVEST_50_CROPS,
			ObjectiveType.TILL_25_TILES,
			ObjectiveType.WATER_25_TILES,
			ObjectiveType.DISCOVER_5_CROPS,
			ObjectiveType.PLACE_SPRINKLER,
		],
	},
	"crafting": {
		"name": "Crafting & Coins",
		"icon": "🔨",
		"types": [
			ObjectiveType.CRAFT_ITEM,
			ObjectiveType.COOK_A_MEAL,
			ObjectiveType.COOK_5_MEALS,
			ObjectiveType.SMELT_INGOT,
			ObjectiveType.BUY_UPGRADE,
			ObjectiveType.EARN_1000_GOLD,
			ObjectiveType.EARN_5000_GOLD,
			ObjectiveType.INNKEEPER_100_GOLD,
		],
	},
	"combat": {
		"name": "Combat",
		"icon": "⚔️",
		"types": [
			ObjectiveType.SLAY_ENEMIES,
			ObjectiveType.SLAY_25_ENEMIES,
			ObjectiveType.DEFEAT_ROOT_WARDEN,
			ObjectiveType.DEFEAT_HOLLOW_STAG,
			ObjectiveType.DEFEAT_BLOOMING_WYRM,
			ObjectiveType.DEFEAT_INCONSTANT_SOUL,
			ObjectiveType.SURVIVE_PIRATE_RAID,
		],
	},
	"exploration": {
		"name": "Exploration",
		"icon": "⛏️",
		"types": [
			ObjectiveType.ENTER_MINE,
			ObjectiveType.COLLECT_100_ORE,
			ObjectiveType.REACH_DEPTH_3,
		],
	},
	"progression": {
		"name": "Progression",
		"icon": "🏠",
		"types": [
			ObjectiveType.PLACE_FIRST_BUILDING,
			ObjectiveType.PLACE_10_BUILDINGS,
			ObjectiveType.UNLOCK_FIRST_PET,
			ObjectiveType.UNLOCK_3_PETS,
			ObjectiveType.EQUIP_ALL_ARMOR,
			ObjectiveType.BREED_FIRST_ANIMAL,
			ObjectiveType.REACH_LEVEL_25,
			ObjectiveType.REACH_LEVEL_50,
		],
	},
	"town": {
		"name": "Town",
		"icon": "🏘️",
		"types": [
			ObjectiveType.RESTORE_FIRST_BUILDING,
			ObjectiveType.RESTORE_3_BUILDINGS,
			ObjectiveType.RESTORE_6_BUILDINGS,
			ObjectiveType.RESTORE_ALL_BUILDINGS,
			ObjectiveType.RECRUIT_FIRST_RESIDENT,
			ObjectiveType.RECRUIT_3_RESIDENTS,
			ObjectiveType.RECRUIT_ALL_RESIDENTS,
			ObjectiveType.EARN_TOWN_REPUTATION_300,
			ObjectiveType.BAKE_IRIDIUM_ITEM,
			ObjectiveType.SELL_AT_RESTAURANT,
			ObjectiveType.REACH_TOWN_LEVEL_3,
			ObjectiveType.REACH_TOWN_LEVEL_5,
		],
	},
}

## Returns category keys in display order.
static func get_category_order() -> Array[String]:
	return ["farming", "crafting", "combat", "exploration", "progression", "town"]


var _progress: Dictionary = {}  # objective_type -> current_count
var _completed: Dictionary = {}  # objective_type -> true

# Total earnings tracker for EARN_1000/5000_GOLD objectives
var _total_earned: int = 0


func _ready() -> void:
	add_to_group("objective_manager")
	# Connect to game events
	# NOTE: money_changed is NOT connected here — GameManager.add_money()
	# calls ObjectiveManager.on_money_earned() directly for positive earnings.
	# The old _on_money_changed() listener was removed because it was a no-op.
	UpgradeManager.upgrade_purchased.connect(_on_upgrade_purchased)
	
	# Connect to pet unlock signal (deferred in case PetManager isn't ready)
	get_tree().create_timer(0.1).timeout.connect(_lazy_connect)


## Register a progress increment for an objective type.
func track_progress(type: int, amount: int = 1) -> void:
	if _completed.has(type):
		return
	
	var current_raw = _progress.get(type, 0)
	var current: int = current_raw + amount
	_progress[type] = current
	
	var def_raw = OBJECTIVE_DEFS.get(type, {})
	var def: Dictionary = def_raw
	var threshold: int = def.get("threshold", 1)
	
	if current >= threshold:
		_completed[type] = true
		var name_str: String = def.get("name", "Objective")
		var icon_str: String = def.get("icon", "⭐")
		ToastNotification.show_toast("%s %s complete!" % [icon_str, name_str], ToastNotification.ToastType.SUCCESS, 5.0)
		objective_completed.emit(type, name_str)
	
	objectives_updated.emit()


## Returns the current active (next incomplete) objective info.
func get_active_objective() -> Dictionary:
	# Return first incomplete objective in priority order
	for t in [
			# Early game — farming basics
			ObjectiveType.PLANT_FIRST_CROP, ObjectiveType.HARVEST_10_CROPS,
			ObjectiveType.TILL_25_TILES, ObjectiveType.WATER_25_TILES,
			ObjectiveType.CRAFT_ITEM, ObjectiveType.COOK_A_MEAL,
			ObjectiveType.COOK_5_MEALS, ObjectiveType.PLACE_SPRINKLER,
			ObjectiveType.BUY_UPGRADE, ObjectiveType.EARN_1000_GOLD,
			# Early game — exploration & expansion
			ObjectiveType.DISCOVER_5_CROPS, ObjectiveType.PLACE_FIRST_BUILDING,
			ObjectiveType.PLACE_10_BUILDINGS, ObjectiveType.ENTER_MINE,
			ObjectiveType.COLLECT_100_ORE, ObjectiveType.SMELT_INGOT,
			ObjectiveType.REACH_DEPTH_3, ObjectiveType.SLAY_ENEMIES,
			ObjectiveType.SLAY_25_ENEMIES, ObjectiveType.UNLOCK_FIRST_PET,
			ObjectiveType.UNLOCK_3_PETS, ObjectiveType.EQUIP_ALL_ARMOR,
			ObjectiveType.BREED_FIRST_ANIMAL,
			# Mid game
			ObjectiveType.HARVEST_50_CROPS, ObjectiveType.REACH_LEVEL_25,
			ObjectiveType.REACH_LEVEL_50, ObjectiveType.EARN_5000_GOLD,
			ObjectiveType.INNKEEPER_100_GOLD,
			# Town objectives
			ObjectiveType.RESTORE_FIRST_BUILDING, ObjectiveType.RESTORE_3_BUILDINGS,
			ObjectiveType.RESTORE_6_BUILDINGS, ObjectiveType.RECRUIT_FIRST_RESIDENT,
			ObjectiveType.RECRUIT_3_RESIDENTS, ObjectiveType.EARN_TOWN_REPUTATION_300,
			ObjectiveType.SELL_AT_RESTAURANT, ObjectiveType.BAKE_IRIDIUM_ITEM,
			ObjectiveType.REACH_TOWN_LEVEL_3,
			ObjectiveType.RESTORE_ALL_BUILDINGS, ObjectiveType.RECRUIT_ALL_RESIDENTS,
			ObjectiveType.REACH_TOWN_LEVEL_5,
			# End game — boss chain
			ObjectiveType.DEFEAT_ROOT_WARDEN, ObjectiveType.DEFEAT_HOLLOW_STAG,
			ObjectiveType.DEFEAT_BLOOMING_WYRM, ObjectiveType.DEFEAT_INCONSTANT_SOUL,
			ObjectiveType.SURVIVE_PIRATE_RAID,
		]:
		if not _completed.has(t):
			var def_raw = OBJECTIVE_DEFS.get(t, {})
			var def: Dictionary = def_raw
			var current_raw = _progress.get(t, 0)
			var current: int = current_raw
			var threshold: int = def.get("threshold", 1)
			return {
				"type": t,
				"name": def.get("name", ""),
				"desc": def.get("desc", ""),
				"icon": def.get("icon", ""),
				"progress": current,
				"threshold": threshold,
			}
	return {}


func get_completed_count() -> int:
	return _completed.size()


## Returns true if a specific objective type has been completed.
func is_objective_completed(type: int) -> bool:
	return _completed.has(type)


## Lazy-connect to autoloads that may not be ready at _ready().
func _lazy_connect() -> void:
	var pm: Node = get_tree().get_first_node_in_group("pet_manager")
	if pm and pm.has_signal("pet_unlocked"):
		if not pm.pet_unlocked.is_connected(_on_pet_unlocked):
			pm.pet_unlocked.connect(_on_pet_unlocked)
	var dm := get_tree().get_first_node_in_group("data_manager") as Node
	if dm and "crop_discovered" in dm:
		if not dm.crop_discovered.is_connected(_on_crop_discovered):
			dm.crop_discovered.connect(_on_crop_discovered)
	var lm := get_tree().get_first_node_in_group("level_manager") as Node
	if lm and lm.has_signal("level_up"):
		if not lm.level_up.is_connected(_on_player_level_up_obj):
			lm.level_up.connect(_on_player_level_up_obj)


func _on_pet_unlocked(_pet_id: String) -> void:
	on_pet_unlocked()


func _on_crop_discovered(_crop_id: String) -> void:
	on_crop_discovered()


func _on_player_level_up_obj(new_level: int) -> void:
	on_player_level_up(new_level)


func _on_upgrade_purchased(_upgrade, _new_level) -> void:
	track_progress(ObjectiveType.BUY_UPGRADE)


# Called externally by World/Player when events happen
func on_crop_planted() -> void:
	if not _completed.has(ObjectiveType.PLANT_FIRST_CROP):
		track_progress(ObjectiveType.PLANT_FIRST_CROP)
	# Progress for HARVEST_10_CROPS is incremented in on_crop_harvested()


func on_crop_harvested() -> void:
	track_progress(ObjectiveType.HARVEST_10_CROPS)
	track_progress(ObjectiveType.HARVEST_50_CROPS)


func on_tile_tilled() -> void:
	track_progress(ObjectiveType.TILL_25_TILES)


func on_tile_watered() -> void:
	track_progress(ObjectiveType.WATER_25_TILES)


func on_item_crafted() -> void:
	track_progress(ObjectiveType.CRAFT_ITEM)


func on_sprinkler_placed() -> void:
	track_progress(ObjectiveType.PLACE_SPRINKLER)


func on_meal_cooked() -> void:
	track_progress(ObjectiveType.COOK_A_MEAL)
	track_progress(ObjectiveType.COOK_5_MEALS)


func on_enemy_slain() -> void:
	track_progress(ObjectiveType.SLAY_ENEMIES)
	track_progress(ObjectiveType.SLAY_25_ENEMIES)


## Called when a pirate raid is survived.
func on_pirate_raid_survived() -> void:
	track_progress(ObjectiveType.SURVIVE_PIRATE_RAID)


# Boss defeat tracking — called by each boss's _die() method
# Uses counter to track which boss was defeated sequentially
var _boss_counter: int = 0

func on_boss_defeated() -> void:
	_boss_counter += 1
	match _boss_counter:
		1: track_progress(ObjectiveType.DEFEAT_ROOT_WARDEN)
		2: track_progress(ObjectiveType.DEFEAT_HOLLOW_STAG)
		3: track_progress(ObjectiveType.DEFEAT_BLOOMING_WYRM)
		4: track_progress(ObjectiveType.DEFEAT_INCONSTANT_SOUL)


func on_money_earned(amount: int) -> void:
	_total_earned += amount
	# track_progress is additive, so pass the increment (amount) not the cumulative total
	track_progress(ObjectiveType.EARN_1000_GOLD, amount)
	track_progress(ObjectiveType.EARN_5000_GOLD, amount)


# ---------------------------------------------------------------------------
# New objective hooks (v2)
# ---------------------------------------------------------------------------

## Called when the player enters any mine room.
func on_enter_mine(_depth: int) -> void:
	track_progress(ObjectiveType.ENTER_MINE)

## Called when the player collects ore from a mine deposit.
func on_ore_collected(amount: int) -> void:
	track_progress(ObjectiveType.COLLECT_100_ORE, amount)

## Called when the player smelts an ingot at the crafting table.
func on_smelt_ingot() -> void:
	track_progress(ObjectiveType.SMELT_INGOT)

## Called when the player reaches a specific mine depth.
## Depth is tracked as progress (depth 3 = threshold 3).
func on_reach_mine_depth(depth: int) -> void:
	if depth > _progress.get(ObjectiveType.REACH_DEPTH_3, 0):
		_progress[ObjectiveType.REACH_DEPTH_3] = depth
		_check_completion(ObjectiveType.REACH_DEPTH_3)

## Called when a building is placed in the world.
func on_building_placed() -> void:
	track_progress(ObjectiveType.PLACE_FIRST_BUILDING)
	track_progress(ObjectiveType.PLACE_10_BUILDINGS)

## Called when a pet is unlocked via pet egg.
func on_pet_unlocked() -> void:
	track_progress(ObjectiveType.UNLOCK_FIRST_PET)
	track_progress(ObjectiveType.UNLOCK_3_PETS)

## Called when any armor piece is equipped. Checks if all 4 slots are filled.
func on_armor_equipped() -> void:
	var gm: Node = get_tree().get_first_node_in_group("game_manager")
	if not gm:
		return
	var equipped: Dictionary = gm.equipped_armor if "equipped_armor" in gm else {}
	var filled_slots := 0
	for slot_val in equipped.values():
		if slot_val is String and not (slot_val as String).is_empty():
			filled_slots += 1
	if filled_slots >= 4:
		track_progress(ObjectiveType.EQUIP_ALL_ARMOR)

## Called when a baby animal is born via breeding.
func on_baby_born() -> void:
	track_progress(ObjectiveType.BREED_FIRST_ANIMAL)

## Called when a new crop is discovered.
func on_crop_discovered() -> void:
	track_progress(ObjectiveType.DISCOVER_5_CROPS)

## Called when hotel earnings are collected from any hotel building.
## Total accumulated hotel gold is tracked as progress.
func on_hotel_earned(amount: int) -> void:
	if _completed.has(ObjectiveType.INNKEEPER_100_GOLD):
		return
	var current: int = _progress.get(ObjectiveType.INNKEEPER_100_GOLD, 0)
	current += amount
	_progress[ObjectiveType.INNKEEPER_100_GOLD] = current
	_check_completion(ObjectiveType.INNKEEPER_100_GOLD)

## Called when a building is restored in the ruined town.
func on_building_restored() -> void:
	track_progress(ObjectiveType.RESTORE_FIRST_BUILDING)
	track_progress(ObjectiveType.RESTORE_3_BUILDINGS)
	track_progress(ObjectiveType.RESTORE_6_BUILDINGS)
	track_progress(ObjectiveType.RESTORE_ALL_BUILDINGS)
	var tm := get_tree().get_first_node_in_group("town_manager")
	if tm and "town_level" in tm:
		var level: int = tm.get("town_level")
		if level >= 3:
			track_progress(ObjectiveType.REACH_TOWN_LEVEL_3)
		if level >= 5:
			track_progress(ObjectiveType.REACH_TOWN_LEVEL_5)

## Called when a new resident moves into the town.
func on_resident_recruited(resident_count: int) -> void:
	track_progress(ObjectiveType.RECRUIT_FIRST_RESIDENT)
	track_progress(ObjectiveType.RECRUIT_3_RESIDENTS)
	track_progress(ObjectiveType.RECRUIT_ALL_RESIDENTS)

## Called when the player bakes an item at the bakery.
func on_bake_completed(quality: int) -> void:
	if quality >= 3:  # Iridium quality
		track_progress(ObjectiveType.BAKE_IRIDIUM_ITEM)

## Called when the player sells crops at the restaurant.
func on_sell_at_restaurant() -> void:
	track_progress(ObjectiveType.SELL_AT_RESTAURANT)

## Called when town reputation changes.
func on_town_reputation_changed(reputation: int) -> void:
	if _completed.has(ObjectiveType.EARN_TOWN_REPUTATION_300):
		return
	if reputation >= 300:
		track_progress(ObjectiveType.EARN_TOWN_REPUTATION_300)

## Called when the player levels up.
func on_player_level_up(new_level: int) -> void:
	if new_level >= 50:
		track_progress(ObjectiveType.REACH_LEVEL_50)
		track_progress(ObjectiveType.REACH_LEVEL_25)
	elif new_level >= 25:
		track_progress(ObjectiveType.REACH_LEVEL_25)

## Helper: check a single objective for completion without the additive track_progress.
func _check_completion(type: int) -> void:
	if _completed.has(type):
		return
	var def_raw = OBJECTIVE_DEFS.get(type, {})
	var def: Dictionary = def_raw
	var threshold: int = def.get("threshold", 1)
	var current: int = _progress.get(type, 0)
	if current >= threshold:
		_completed[type] = true
		var name_str: String = def.get("name", "Objective")
		var icon_str: String = def.get("icon", "⭐")
		ToastNotification.show_toast("%s %s complete!" % [icon_str, name_str], ToastNotification.ToastType.SUCCESS, 5.0)
		objective_completed.emit(type, name_str)
	objectives_updated.emit()


func serialize() -> Dictionary:
	return {
		"progress": _progress.duplicate(),
		"completed": _completed.duplicate(),
		"total_earned": _total_earned,
	}


func deserialize(data: Dictionary) -> void:
	if data.has("progress"):
		_progress = data["progress"].duplicate()
	if data.has("completed"):
		_completed = data["completed"].duplicate()
	if data.has("total_earned"):
		_total_earned = data["total_earned"]
