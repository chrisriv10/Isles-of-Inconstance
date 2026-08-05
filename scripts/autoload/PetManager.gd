extends Node

## Autoload singleton. Owns pet state: unlocks, equip, serialization.
## Only one active pet at a time.

## Emitted when the active pet changes (null = no pet, String = pet_id).
signal active_pet_changed(pet_id: String)
## Emitted when the player unlocks a new pet.
signal pet_unlocked(pet_id: String)
## Emitted when a pet is renamed. Passes pet_id and the new display name.
signal pet_name_changed(pet_id: String, display_name: String)

# --------------------------------------------------------------------------
# Pet type definitions (plain Dictionary, no inner classes to avoid
# collision with autoload singleton naming.)
# --------------------------------------------------------------------------

## Build a pet data dict. Keys: id, name, desc, offset (Vector2),
## speed (float), bonus_type (String), bonus_val (float), color (Color).
static func make_pet(id: String, pet_name: String, desc: String,
		offset_x: float, offset_y: float, speed: float,
		bonus_type: String, bonus_val: float,
		r: float, g: float, b: float) -> Dictionary:
	return {
		"id": id, "name": pet_name, "desc": desc,
		"offset": Vector2(offset_x, offset_y),
		"speed": speed,
		"bonus_type": bonus_type, "bonus_val": bonus_val,
		"color": Color(r, g, b),
		"combat_damage": 0,  # base damage dealt when pet attacks enemies nearby
	}

static var pet_db: Dictionary = {}  # pet_id -> Dictionary

static func _init_pet_db() -> void:
	if not pet_db.is_empty():
		return
	pet_db["cat"] = make_pet("cat", "Cat",
		"A nimble feline that sometimes finds rare trinkets.",
		-20, 0, 180.0, "loot", 0.08, 0.9, 0.5, 0.2)
	pet_db["cat"]["combat_damage"] = 3
	pet_db["dog"] = make_pet("dog", "Dog",
		"A loyal companion that aids in combat.",
		-24, 0, 200.0, "combat", 5.0, 0.7, 0.45, 0.3)
	pet_db["dog"]["combat_damage"] = 8
	pet_db["fox"] = make_pet("fox", "Fox",
		"A clever creature that helps gather resources.",
		-22, 0, 220.0, "gather", 0.15, 0.85, 0.4, 0.1)
	pet_db["fox"]["combat_damage"] = 4
	pet_db["bird"] = make_pet("bird", "Bird",
		"A watchful scout that reveals the map.",
		-16, -10, 250.0, "scout", 1.0, 0.3, 0.6, 0.9)
	pet_db["bird"]["combat_damage"] = 2
	pet_db["turtle"] = make_pet("turtle", "Turtle",
		"A sturdy shell that grants defense.",
		-18, 0, 100.0, "defense", 2.0, 0.3, 0.7, 0.3)
	pet_db["turtle"]["combat_damage"] = 2
	pet_db["rabbit"] = make_pet("rabbit", "Rabbit",
		"A speedy hopper that boosts crop growth nearby.",
		-18, 0, 260.0, "growth", 0.1, 0.85, 0.75, 0.65)
	pet_db["rabbit"]["combat_damage"] = 1
	pet_db["ice_cream_sandwich"] = make_pet("ice_cream_sandwich", "Mini Ice Cream Sandwich Man",
		"A sweet frozen companion that chills enemies and finds treats.",
		-18, 0, 190.0, "loot", 0.1, 0.7, 0.4, 0.2)
	pet_db["ice_cream_sandwich"]["combat_damage"] = 4
	pet_db["gingerbread_man"] = make_pet("gingerbread_man", "Mini Gingerbread Man",
		"A fresh-baked cookie companion that makes you move faster. Run run as fast as you can!",
		-18, 0, 160.0, "speed", 0.15, 0.7, 0.4, 0.2)
	pet_db["gingerbread_man"]["combat_damage"] = 3

# --------------------------------------------------------------------------
# Instance state
# --------------------------------------------------------------------------

## Custom names assigned by the player. pet_id -> custom_name ("" = use default).
var pet_names: Dictionary = {}  # pet_id -> String

## Pet IDs the player owns.
var owned_pets: Array[String] = []

## Pet progression: each pet has XP and a level (1-10 max).
## XP is earned when the pet's bonus triggers (loot bonus, etc.).
var pet_xp: Dictionary = {}   # pet_id -> current_xp
var pet_level: Dictionary = {} # pet_id -> level (1-10)

const XP_PER_LEVEL: int = 50   # XP needed per level
const MAX_PET_LEVEL: int = 10

## Currently active pet ID ("" = none).
var active_pet_id: String = "":
	set(id):
		if id == active_pet_id:
			return
		active_pet_id = id
		active_pet_changed.emit(id)
		# Broadcast stats so remote peers see pet change immediately
		GameManager._try_broadcast_player_stats()

func _init() -> void:
	_init_pet_db()

## Grant a pet. Returns false if already owned or unknown.
func unlock_pet(pet_id: String) -> bool:
	if not pet_db.has(pet_id):
		push_error("PetManager: unknown pet '%s'" % pet_id)
		return false
	if owned_pets.has(pet_id):
		return false
	owned_pets.append(pet_id)
	pet_unlocked.emit(pet_id)
	if active_pet_id.is_empty():
		active_pet_id = pet_id
	return true

func has_pet(pet_id: String) -> bool:
	return owned_pets.has(pet_id)

## Rename a pet the player owns. Returns the final name.
func rename_pet(pet_id: String, new_name: String) -> String:
	if not owned_pets.has(pet_id):
		return get_pet_display_name(pet_id)
	var trimmed := new_name.strip_edges()
	if trimmed.is_empty():
		# Clearing the custom name resets to default
		if pet_names.has(pet_id):
			pet_names.erase(pet_id)
	else:
		pet_names[pet_id] = trimmed
	# Emit a name-changed signal so in-world pets and UI can refresh
	pet_name_changed.emit(pet_id, get_pet_display_name(pet_id))
	return get_pet_display_name(pet_id)

## Get the display name for a pet (custom name if set, else default).
func get_pet_display_name(pet_id: String) -> String:
	if pet_names.has(pet_id) and not pet_names[pet_id].is_empty():
		return pet_names[pet_id]
	var data: Dictionary = pet_db.get(pet_id, {})
	return data.get("name", pet_id)

## Returns a pet data dict, or empty dict if not found.
func get_pet_data(pet_id: String) -> Dictionary:
	if not pet_db.has(pet_id):
		return {}
	return pet_db[pet_id] as Dictionary

func get_active_pet_data() -> Dictionary:
	if active_pet_id.is_empty() or not pet_db.has(active_pet_id):
		return {}
	return pet_db[active_pet_id] as Dictionary

# --------------------------------------------------------------------------
# Pet Progression (XP & Level)
# --------------------------------------------------------------------------

## Award XP to the active pet. Called when the pet's bonus triggers in the world.
func award_xp(amount: int = 1) -> void:
	if active_pet_id.is_empty():
		return
	var pid: String = active_pet_id
	var current_xp: int = pet_xp.get(pid, 0)
	var current_level: int = pet_level.get(pid, 1)
	
	current_xp += amount
	
	# Check for level up
	while current_xp >= XP_PER_LEVEL and current_level < MAX_PET_LEVEL:
		current_xp -= XP_PER_LEVEL
		current_level += 1
		_on_pet_level_up(pid, current_level)
	
	# Clamp: don't accumulate XP beyond max level
	if current_level >= MAX_PET_LEVEL:
		current_xp = 0
	
	pet_xp[pid] = current_xp
	pet_level[pid] = current_level

## Called when a pet levels up. Shows a notification and potentially evolves.
func _on_pet_level_up(pet_id: String, new_level: int) -> void:
	var pet_name: String = get_pet_display_name(pet_id)
	ToastNotification.show_toast("%s reached level %d!" % [pet_name, new_level], ToastNotification.ToastType.SUCCESS, 3.0)
	# Scale bonus based on level (10% per level)
	# This is accessed through get_scaled_bonus() below.

## Get the scaled bonus value for the active pet, accounting for level.
func _get_scaled_bonus(base_val: float) -> float:
	var pid: String = active_pet_id
	if pid.is_empty():
		return 0.0
	var level: int = pet_level.get(pid, 1)
	return base_val * (1.0 + (level - 1) * 0.1)  # +10% per level

## Get active pet's current level (1 = default).
func get_pet_level(pet_id: String = "") -> int:
	if pet_id.is_empty():
		pet_id = active_pet_id
	if pet_id.is_empty():
		return 1
	return pet_level.get(pet_id, 1)

## Get active pet's current xp.
func get_pet_xp(pet_id: String = "") -> int:
	if pet_id.is_empty():
		pet_id = active_pet_id
	if pet_id.is_empty():
		return 0
	return pet_xp.get(pet_id, 0)

# --------------------------------------------------------------------------
# Bonus accessors (now scale with pet level)
# --------------------------------------------------------------------------

func get_loot_bonus() -> float:
	var d: Dictionary = get_active_pet_data()
	var base: float = d.get("bonus_val", 0.0) if not d.is_empty() and d.get("bonus_type") == "loot" else 0.0
	return _get_scaled_bonus(base)

func get_combat_bonus() -> float:
	var d: Dictionary = get_active_pet_data()
	var base: float = d.get("bonus_val", 0.0) if not d.is_empty() and d.get("bonus_type") == "combat" else 0.0
	return _get_scaled_bonus(base)

func get_gather_bonus() -> float:
	var d: Dictionary = get_active_pet_data()
	var base: float = d.get("bonus_val", 0.0) if not d.is_empty() and d.get("bonus_type") == "gather" else 0.0
	return _get_scaled_bonus(base)

func get_defense_bonus() -> float:
	var d: Dictionary = get_active_pet_data()
	var base: float = d.get("bonus_val", 0.0) if not d.is_empty() and d.get("bonus_type") == "defense" else 0.0
	return _get_scaled_bonus(base)

func get_scout_bonus() -> float:
	var d: Dictionary = get_active_pet_data()
	var base: float = d.get("bonus_val", 0.0) if not d.is_empty() and d.get("bonus_type") == "scout" else 0.0
	return _get_scaled_bonus(base)

func get_growth_bonus() -> float:
	var d: Dictionary = get_active_pet_data()
	var base: float = d.get("bonus_val", 0.0) if not d.is_empty() and d.get("bonus_type") == "growth" else 0.0
	return _get_scaled_bonus(base)

func get_speed_bonus() -> float:
	var d: Dictionary = get_active_pet_data()
	var base: float = d.get("bonus_val", 0.0) if not d.is_empty() and d.get("bonus_type") == "speed" else 0.0
	return _get_scaled_bonus(base)

# --------------------------------------------------------------------------
# Serialization
# --------------------------------------------------------------------------

func serialize() -> Dictionary:
	return {
		"owned": owned_pets.duplicate(),
		"active": active_pet_id,
		"xp": pet_xp.duplicate(),
		"level": pet_level.duplicate(),
		"names": pet_names.duplicate(),
	}

## Returns a read-only copy of the pet database for display purposes.
func get_all_pet_data() -> Dictionary:
	return pet_db.duplicate()

func deserialize(data: Dictionary) -> void:
	# Only load pets with valid IDs (filter out corrupted save entries)
	var raw_owned: Array = data.get("owned", [])
	owned_pets.clear()
	for pid in raw_owned:
		if pid is String and pet_db.has(pid):
			owned_pets.append(pid)
	active_pet_id = data.get("active", "")
	if not active_pet_id.is_empty() and not pet_db.has(active_pet_id):
		active_pet_id = ""
	# Restore progression
	var raw_xp: Dictionary = data.get("xp", {})
	pet_xp.clear()
	for pid in raw_xp:
		if pid is String and pet_db.has(pid):
			pet_xp[pid] = int(raw_xp[pid])
	var raw_level: Dictionary = data.get("level", {})
	pet_level.clear()
	for pid in raw_level:
		if pid is String and pet_db.has(pid):
			pet_level[pid] = clampi(int(raw_level[pid]), 1, MAX_PET_LEVEL)
	# Restore custom names
	var raw_names: Dictionary = data.get("names", {})
	pet_names.clear()
	for pid in raw_names:
		if pid is String and pet_db.has(pid) and raw_names[pid] is String and not raw_names[pid].is_empty():
			pet_names[pid] = raw_names[pid]
