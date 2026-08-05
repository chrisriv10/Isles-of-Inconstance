## TownManager — central state for the ruined town system.
## Tracks ruin structures, restoration progress, town level, reputation,
## and NPC residents. Handles save/load serialization.
## Attached as a child of World during generation.

extends Node
class_name TownManager

# ---------------------------------------------------------------------------
# Town level thresholds
# ---------------------------------------------------------------------------
const LEVEL_1_CLEARING: int = 1
const LEVEL_2_SETTLEMENT: int = 3
const LEVEL_3_VILLAGE: int = 5
const LEVEL_4_TOWN: int = 7
const LEVEL_5_THRIVING: int = 9

# Reputation thresholds
const REP_CLEARING: int = 0
const REP_SETTLEMENT: int = 50
const REP_VILLAGE: int = 150
const REP_TOWN: int = 300
const REP_THRIVING: int = 500

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------
signal town_level_changed(level: int)
signal reputation_changed(reputation: int)
signal ruin_status_changed(ruin_id: String, status: int)
signal building_restored(ruin_id: String, building_name: String)
signal resident_moved_in(npc_id: String, npc_name: String)
signal restoration_progress_changed(ruin_id: String, percentage: float)
signal all_ruins_restored()

# ---------------------------------------------------------------------------
# Ruin status enum
# ---------------------------------------------------------------------------
enum RuinStatus {
	RUBBLE,     # 0 — untouched ruins
	CLEARED,    # 1 — rubble cleared, foundation visible
	RESTORING,  # 2 — materials being contributed
	RESTORED,   # 3 — fully restored, vacancy available
	OCCUPIED,   # 4 — NPC has moved in
}

# ---------------------------------------------------------------------------
# Ruin definition resource
# ---------------------------------------------------------------------------
class RuinDef:
	var id: String
	var building_name: String
	var grid_cell: Vector2i       # tile position in world grid
	var size: Vector2i            # width, height in tiles
	var needs: Dictionary         # {"item_id": count, ...}
	var npc_role: String          # "villager", "baker", "chef", etc.
	var npc_type: int             # VisitorNPC.VisitorType or -1 for custom

	func _init(p_id: String, p_name: String, p_cell: Vector2i, p_size: Vector2i, p_needs: Dictionary, p_role: String = "villager", p_npc_type: int = -1) -> void:
		id = p_id
		building_name = p_name
		grid_cell = p_cell
		size = p_size
		needs = p_needs.duplicate()
		npc_role = p_role
		npc_type = p_npc_type

# ---------------------------------------------------------------------------
# Resident data
# ---------------------------------------------------------------------------
class ResidentData:
	var npc_id: String
	var npc_name: String
	var role: String
	var home_ruin_id: String
	var visitor_type: int  # VisitorNPC.VisitorType

	func _init(p_id: String, p_name: String, p_role: String, p_home: String, p_vtype: int) -> void:
		npc_id = p_id
		npc_name = p_name
		role = p_role
		home_ruin_id = p_home
		visitor_type = p_vtype

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
var town_level: int = 0
var reputation: int = 0

# ruin_id -> RuinState
var ruins: Dictionary = {}  # RuinState objects indexed by id
var ruin_defs: Dictionary = {}  # RuinDef objects indexed by id

# resident_id -> ResidentData
var residents: Dictionary = {}

# Building type to assign when restored (maps ruin_id -> BuildingSystem.BuildingType)
var _restored_building_types: Dictionary = {}

# Reference to World
var _world: Node2D = null

# Discovery tracking
var discovered: bool = false  # Persisted — has the player seen the ruined town?

# Full restoration flag — set when all ruins reach RESTORED status
var town_fully_restored: bool = false

# Day the player last collected their daily tribute (0 = never)
var _last_tribute_day: int = 0

# ---------------------------------------------------------------------------
# Ruin runtime state
# ---------------------------------------------------------------------------
class RuinState:
	var id: String
	var status: int = RuinStatus.RUBBLE
	var contributed: Dictionary = {}  # {"item_id": count, ...}
	
	func _init(p_id: String) -> void:
		id = p_id
		status = RuinStatus.RUBBLE
		contributed = {}

# ---------------------------------------------------------------------------
# Built-in ruin definitions
# ---------------------------------------------------------------------------
static func get_builtin_ruin_defs() -> Array[RuinDef]:
	return [
		RuinDef.new("cottage_1", "Cottage", Vector2i(0, 0), Vector2i(3, 3),
			{"wood": 5, "stone": 3, "wooden_planks": 2}, "villager", -1),
		RuinDef.new("bakery", "Bakery", Vector2i(0, 0), Vector2i(4, 3),
			{"wood": 8, "stone": 5, "wooden_planks": 3, "gold_ingot": 1}, "baker", 4),
		RuinDef.new("restaurant", "Restaurant", Vector2i(0, 0), Vector2i(4, 3),
			{"wood": 10, "stone": 6, "wooden_planks": 4, "gold_ingot": 1}, "chef", 1),
		RuinDef.new("tavern", "Tavern", Vector2i(0, 0), Vector2i(4, 3),
			{"wood": 12, "stone": 8, "wooden_planks": 5, "gold_ingot": 2, "iron_ingot": 1}, "innkeeper", 0),
		RuinDef.new("blacksmith", "Blacksmith", Vector2i(0, 0), Vector2i(4, 3),
			{"wood": 10, "stone": 6, "wooden_planks": 4, "gold_ingot": 1, "iron_ingot": 2}, "blacksmith", -1),
		RuinDef.new("general_store", "General Store", Vector2i(0, 0), Vector2i(4, 3),
			{"wood": 8, "stone": 5, "wooden_planks": 3, "gold_ingot": 1}, "shopkeep", 2),
		RuinDef.new("library", "Library", Vector2i(0, 0), Vector2i(3, 3),
			{"wood": 8, "stone": 5, "wooden_planks": 3, "gold_ingot": 1}, "scholar", 0),
		RuinDef.new("stable", "Stable", Vector2i(0, 0), Vector2i(4, 3),
			{"wood": 5, "stone": 3, "wooden_planks": 2, "fiber": 1}, "stablehand", 3),
		RuinDef.new("well", "Town Well", Vector2i(0, 0), Vector2i(3, 3),
			{"stone": 5, "wood": 3}, "", -1),
		RuinDef.new("gate", "Bank", Vector2i(0, 0), Vector2i(3, 3),
			{"wood": 8, "stone": 5, "wooden_planks": 3, "gold_ingot": 1}, "", -1),
		# ── Placeholder buildings for filling out rows ──
		RuinDef.new("stall_1", "Vendor Stall", Vector2i(0, 0), Vector2i(4, 3),
			{"wood": 5, "stone": 3}, "villager", -1),
		RuinDef.new("stall_2", "Vendor Stall", Vector2i(0, 0), Vector2i(4, 3),
			{"wood": 5, "stone": 3}, "villager", -1),
		RuinDef.new("workbench", "Town Hall", Vector2i(0, 0), Vector2i(3, 3),
			{"wood": 5, "stone": 3}, "villager", -1),
		RuinDef.new("shed", "Hotel", Vector2i(0, 0), Vector2i(3, 3),
			{"wood": 8, "stone": 5, "wooden_planks": 3, "gold_ingot": 1}, "villager", -1),
	]

# ---------------------------------------------------------------------------
# Initialization
# ---------------------------------------------------------------------------
func _ready() -> void:
	add_to_group("town_manager")
	_world = get_parent() as Node2D
	# Defer discovery checks to let save data load first
	call_deferred("_start_discovery_check")

func _start_discovery_check() -> void:
	## Begin checking if the player has entered the town area.
	## Disabled immediately if already discovered (e.g. from a loaded save).
	if discovered:
		set_process(false)
		return
	set_process(true)

func _process(_delta: float) -> void:
	## Check if the player has entered the town bounds for the first time.
	if discovered:
		set_process(false)
		return
	
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	if not _world or not _world.has_meta("town_rect"):
		return
	
	var town_rect: Rect2i = _world.get_meta("town_rect")
	# Convert player position to tile coordinates (1 tile = 16px)
	var tile_pos := Vector2i(
		int(floori(player.global_position.x / 16.0)),
		int(floori(player.global_position.y / 16.0))
	)
	
	if town_rect.has_point(tile_pos):
		discovered = true
		set_process(false)
		ToastNotification.show_toast(
			"🏚️ You discovered the Ruined Town!",
			ToastNotification.ToastType.INFO,
			5.0
		)

## Initialize ruins with their grid positions. Called after world generation
## places the ruin scenes.
func initialize(ruin_positions: Dictionary) -> void:
	var defs := get_builtin_ruin_defs()
	for def: RuinDef in defs:
		var pos: Vector2i = ruin_positions.get(def.id, Vector2i(-1, -1))
		if pos.x < 0 or pos.y < 0:
			continue  # skip ruins that couldn't be placed this seed
		def.grid_cell = pos
		ruin_defs[def.id] = def
		var state := RuinState.new(def.id)
		ruins[def.id] = state
	calculate_town_level()

# ---------------------------------------------------------------------------
# Restoration
# ---------------------------------------------------------------------------
func contribute_materials(ruin_id: String, item_id: String, count: int) -> int:
	var ruin: RuinState = ruins.get(ruin_id)
	if not ruin or ruin.status >= RuinStatus.RESTORED:
		return 0
	
	var def: RuinDef = ruin_defs.get(ruin_id)
	if not def:
		return 0
	
	var needed: int = def.needs.get(item_id, 0)
	if needed <= 0:
		return 0
	
	var already_contributed: int = ruin.contributed.get(item_id, 0)
	var remaining: int = needed - already_contributed
	var actual: int = mini(count, remaining)
	
	if actual <= 0:
		return 0
	
	ruin.contributed[item_id] = already_contributed + actual
	
	if ruin.status == RuinStatus.RUBBLE:
		ruin.status = RuinStatus.CLEARED
	elif ruin.status == RuinStatus.CLEARED:
		ruin.status = RuinStatus.RESTORING
	
	# Check if fully supplied
	if _is_fully_supplied(ruin_id):
		ruin.status = RuinStatus.RESTORED
		building_restored.emit(ruin_id, def.building_name)
		calculate_town_level()
		# Notify objective manager
		var om := get_tree().get_first_node_in_group("objective_manager")
		if om and om.has_method("on_building_restored"):
			om.on_building_restored()
		# Check if all ruins are now restored
		if _are_all_restored():
			town_fully_restored = true
			all_ruins_restored.emit()
			_swap_plaza_to_restored()
	
	ruin_status_changed.emit(ruin_id, ruin.status)
	
	var pct: float = _get_restoration_pct(ruin_id)
	restoration_progress_changed.emit(ruin_id, pct)
	
	return actual

func _is_fully_supplied(ruin_id: String) -> bool:
	var def: RuinDef = ruin_defs.get(ruin_id)
	var state: RuinState = ruins.get(ruin_id)
	if not def or not state:
		return false
	for item_id: String in def.needs:
		var needed: int = def.needs[item_id]
		var have: int = state.contributed.get(item_id, 0)
		if have < needed:
			return false
	return true

func _get_restoration_pct(ruin_id: String) -> float:
	var def: RuinDef = ruin_defs.get(ruin_id)
	var state: RuinState = ruins.get(ruin_id)
	if not def or not state:
		return 0.0
	var total_needed: int = 0
	var total_contributed: int = 0
	for item_id: String in def.needs:
		total_needed += def.needs[item_id]
		total_contributed += state.contributed.get(item_id, 0)
	if total_needed <= 0:
		return 1.0
	return float(total_contributed) / float(total_needed)

func get_restoration_pct(ruin_id: String) -> float:
	return _get_restoration_pct(ruin_id)

func get_contributed(ruin_id: String, item_id: String) -> int:
	var state: RuinState = ruins.get(ruin_id)
	if not state:
		return 0
	return state.contributed.get(item_id, 0)

func get_needed(ruin_id: String, item_id: String) -> int:
	var def: RuinDef = ruin_defs.get(ruin_id)
	if not def:
		return 0
	return def.needs.get(item_id, 0)

func get_ruin_status(ruin_id: String) -> int:
	var state: RuinState = ruins.get(ruin_id)
	if not state:
		return RuinStatus.RUBBLE
	return state.status

func set_ruin_occupied(ruin_id: String) -> void:
	var state: RuinState = ruins.get(ruin_id)
	if state and state.status == RuinStatus.RESTORED:
		state.status = RuinStatus.OCCUPIED
		ruin_status_changed.emit(ruin_id, state.status)

# ---------------------------------------------------------------------------
# Town Level
# ---------------------------------------------------------------------------
func calculate_town_level() -> void:
	var restored_count: int = 0
	for state: RuinState in ruins.values():
		if state.status >= RuinStatus.RESTORED:
			restored_count += 1
	
	var new_level: int = 0
	if restored_count >= LEVEL_1_CLEARING:
		new_level = 1
	if restored_count >= LEVEL_2_SETTLEMENT:
		new_level = 2
	if restored_count >= LEVEL_3_VILLAGE:
		new_level = 3
	if restored_count >= LEVEL_4_TOWN:
		new_level = 4
	if restored_count >= LEVEL_5_THRIVING:
		new_level = 5
	
	if new_level != town_level:
		town_level = new_level
		town_level_changed.emit(town_level)

func get_restored_count() -> int:
	var count: int = 0
	for state: RuinState in ruins.values():
		if state.status >= RuinStatus.RESTORED:
			count += 1
	return count

func get_vacancy_count() -> int:
	var count: int = 0
	for state: RuinState in ruins.values():
		if state.status == RuinStatus.RESTORED:
			var def: RuinDef = ruin_defs.get(state.id)
			if def and def.npc_role != null and def.npc_role != "":
				count += 1
	return count

func get_vacant_ruins() -> Array[String]:
	var vacant: Array[String] = []
	for state: RuinState in ruins.values():
		if state.status == RuinStatus.RESTORED:
			var def: RuinDef = ruin_defs.get(state.id)
			if def and def.npc_role != null and def.npc_role != "":
				vacant.append(state.id)
	return vacant

# ---------------------------------------------------------------------------
# Reputation
# ---------------------------------------------------------------------------
var _reached_rep_thresholds: Dictionary = {}  # threshold_name -> true
signal rep_threshold_reached(threshold_name: String, threshold_value: int)

func add_reputation(amount: int) -> void:
	reputation += amount
	reputation_changed.emit(reputation)
	_check_rep_thresholds()
	
	# Notify objective manager about reputation change (for Well Liked objective)
	var obj_mgr := get_tree().get_first_node_in_group("objective_manager")
	if obj_mgr and obj_mgr.has_method("on_town_reputation_changed"):
		obj_mgr.on_town_reputation_changed(reputation)

func _check_rep_thresholds() -> void:
	# Check thresholds in order, emit signal when a new one is crossed
	var thresholds := {
		"settlement": REP_SETTLEMENT,
		"village": REP_VILLAGE,
		"town": REP_TOWN,
		"thriving": REP_THRIVING,
	}
	for name: String in thresholds:
		var value: int = thresholds[name]
		if reputation >= value and not _reached_rep_thresholds.has(name):
			_reached_rep_thresholds[name] = true
			rep_threshold_reached.emit(name, value)

# ---------------------------------------------------------------------------
# Residents
# ---------------------------------------------------------------------------
func add_resident(npc_id: String, npc_name: String, role: String, home_ruin_id: String, visitor_type: int) -> void:
	var resident := ResidentData.new(npc_id, npc_name, role, home_ruin_id, visitor_type)
	residents[npc_id] = resident
	set_ruin_occupied(home_ruin_id)
	resident_moved_in.emit(npc_id, npc_name)

func get_resident_count() -> int:
	return residents.size()

func get_residents() -> Array[ResidentData]:
	return residents.values()

func get_resident(npc_id: String) -> ResidentData:
	return residents.get(npc_id)

# ---------------------------------------------------------------------------
# Get available ruins for visitor type matching
# ---------------------------------------------------------------------------
func get_preferred_vacancy(visitor_type: int) -> String:
	var vacant: Array[String] = get_vacant_ruins()
	if vacant.is_empty():
		return ""
	
	# Try to find a ruin matching the visitor's type
	for ruin_id: String in vacant:
		var def: RuinDef = ruin_defs.get(ruin_id)
		if def and def.npc_type == visitor_type:
			return ruin_id
	
	# Fallback: return a cottage (generic) if available, otherwise any vacancy
	for ruin_id: String in vacant:
		var def: RuinDef = ruin_defs.get(ruin_id)
		if def and def.npc_role == "villager":
			return ruin_id
	
	return vacant[0]  # any available

# ---------------------------------------------------------------------------
# Utility
# ---------------------------------------------------------------------------
func get_ruin_def(ruin_id: String) -> RuinDef:
	return ruin_defs.get(ruin_id)

func get_ruin_state(ruin_id: String) -> RuinState:
	return ruins.get(ruin_id)

## Creative mode: instantly restore all ruins to their completed state.
## Sets every ruin to RESTORED, updates town level, and signals changes.
## In multiplayer, this should be called via _server_request_creative_restore_all() from the host.
func creative_restore_all(is_host_called: bool = false) -> void:
	if NetworkManager.is_network_active() and not multiplayer.is_server():
		# This is a client requesting creative restore - should have come via RPC
		return
		
	for ruin_id: String in ruins.keys():
		var state: RuinState = ruins[ruin_id]
		if state.status < RuinStatus.RESTORED:
			state.status = RuinStatus.RESTORED
			# Fully satisfy all material requirements
			var def: RuinDef = ruin_defs.get(ruin_id)
			if def:
				for item_id: String in def.needs.keys():
					state.contributed[item_id] = def.needs[item_id]
			ruin_status_changed.emit(ruin_id, state.status)
			building_restored.emit(ruin_id, def.building_name if def else "")
	
	# Recalculate town level
	calculate_town_level()
	
	# Add reputation for all newly restored buildings
	add_reputation(get_restored_count() * 25)
	
	# Signal that every ruin is now restored
	all_ruins_restored.emit()
	
	# Also directly swap the plaza sprite — find TownPlaza under the World node
	_swap_plaza_to_restored()

## Host authority: creative restore request from a client
## In multiplayer, only the host can execute this
@rpc("authority", "reliable")
func _server_request_creative_restore_all() -> void:
	# Only the host executes creative restore
	creative_restore_all(true)

func _swap_plaza_to_restored() -> void:
	# Walk up from self to find the World node (more reliable than _world
	# which may not be set if _ready hasn't been called on this instance).
	var world_node: Node = self
	while world_node and world_node.name != "World":
		world_node = world_node.get_parent()
	if not world_node or not world_node.has_meta("town_plaza_sprite"):
		return
	var plaza := world_node.get_meta("town_plaza_sprite") as Sprite2D
	if not plaza:
		return
	plaza.texture = preload("res://assets/generated/restored.png")
	# restored.png is 1536x1024 while unrestored.png is 612x408 at scale 0.7
	# Compute scale so restored covers the same world area (428x286)
	plaza.scale = Vector2(428.4 / 1536.0, 285.6 / 1024.0)

func _are_all_restored() -> bool:
	for state: RuinState in ruins.values():
		if state.status < RuinStatus.RESTORED:
			return false
	return true

func has_any_restored() -> bool:
	for state: RuinState in ruins.values():
		if state.status >= RuinStatus.RESTORED:
			return true
	return false

# ---------------------------------------------------------------------------
# Daily Tribute
# ---------------------------------------------------------------------------

## Returns true if the player can collect today's tribute.
func is_tribute_available() -> bool:
	if not town_fully_restored:
		return false
	return GameManager.current_day > _last_tribute_day

## Collect the daily tribute. Awards a small amount of money based on
## current reputation and resident count. Returns the amount awarded.
func collect_tribute() -> int:
	if not is_tribute_available():
		return 0
	
	var amount: int = ceil(clampi(10 + reputation / 50 + residents.size() * 2, 10, 200) * GameManager.get_income_mult())
	GameManager.add_money(amount)
	
	_last_tribute_day = GameManager.current_day
	return amount

# ---------------------------------------------------------------------------
# Save / Load
# ---------------------------------------------------------------------------
func serialize() -> Dictionary:
	var ruin_data: Dictionary = {}
	for rid: String in ruins:
		var state: RuinState = ruins[rid]
		ruin_data[rid] = {
			"status": state.status,
			"contributed": state.contributed.duplicate(),
		}
	
	var resident_data: Dictionary = {}
	for rid: String in residents:
		var r: ResidentData = residents[rid]
		resident_data[rid] = {
			"npc_id": r.npc_id,
			"npc_name": r.npc_name,
			"role": r.role,
			"home_ruin_id": r.home_ruin_id,
			"visitor_type": r.visitor_type,
		}
	
	return {
		"town_level": town_level,
		"reputation": reputation,
		"ruins": ruin_data,
		"residents": resident_data,
		"discovered": discovered,
		"reached_rep_thresholds": _reached_rep_thresholds.duplicate(),
		"town_fully_restored": town_fully_restored,
		"last_tribute_day": _last_tribute_day,
	}

func deserialize(data: Dictionary) -> void:
	if data.is_empty():
		return
	
	town_level = data.get("town_level", 0)
	reputation = data.get("reputation", 0)
	discovered = data.get("discovered", false)
	_reached_rep_thresholds = data.get("reached_rep_thresholds", {}).duplicate()
	town_fully_restored = data.get("town_fully_restored", false)
	_last_tribute_day = data.get("last_tribute_day", 0)
	
	var ruin_data: Dictionary = data.get("ruins", {})
	for rid: String in ruin_data:
		var rd: Dictionary = ruin_data[rid]
		var state: RuinState = ruins.get(rid)
		if state:
			state.status = rd.get("status", 0)
			state.contributed = rd.get("contributed", {}).duplicate()
	
	var resident_data: Dictionary = data.get("residents", {})
	for rid: String in resident_data:
		var rd: Dictionary = resident_data[rid]
		var r := ResidentData.new(
			rd.get("npc_id", rid),
			rd.get("npc_name", "Visitor"),
			rd.get("role", "villager"),
			rd.get("home_ruin_id", ""),
			rd.get("visitor_type", 0)
		)
		residents[rid] = r
