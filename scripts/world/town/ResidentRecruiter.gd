## ResidentRecruiter — bridges VisitorManager departure to TownManager vacancies.
## When a visitor ship departs at dusk, if there are vacancies in the town,
## one random visitor NPC stays behind and becomes a permanent resident.

extends Node
class_name ResidentRecruiter

var _town_manager: TownManager = null
var _visitor_manager: VisitorManager = null

func _ready() -> void:
	add_to_group("resident_recruiter")
	_town_manager = get_tree().get_first_node_in_group("town_manager")
	_visitor_manager = get_tree().get_first_node_in_group("visitor_manager")
	
	# Connect to visitor manager departure
	if _visitor_manager:
		# We'll connect when VisitorManager is modified to emit a departure signal
		pass

## Called by VisitorManager before NPCs depart for the day.
## Returns a Dictionary with conversion info, or an empty Dictionary if
## no conversion happens.
func try_recruit() -> Dictionary:
	_refresh_manager_refs()
	if not _town_manager or not _visitor_manager:
		return {}
	
	var vacancy_count: int = _town_manager.get_vacancy_count()
	if vacancy_count <= 0:
		return {}  # no vacancies
	
	# Gather candidate visitors: prefer the ship's roster, but fall back to
	# any valid VisitorNPC on the island. This covers the case where NPCs are
	# present (e.g. player placed them, or the ship roster is out of sync) but
	# the active ship's "npcs_ashore" flag is false.
	var visitors: Array = _collect_visitor_candidates()
	if visitors.is_empty():
		return {}  # no visitors to recruit
	
	# Pick a random visitor to stay
	var visitor: Node = visitors[randi() % visitors.size()]
	if not visitor or not visitor.has_method("convert_to_resident"):
		return {}
	
	# Find matching vacancy
	var visitor_type: int = visitor.get("npc_type") if "npc_type" in visitor else 0
	var preferred_vacancy: String = _town_manager.get_preferred_vacancy(visitor_type)
	
	if preferred_vacancy.is_empty():
		return {}  # no vacancy after all
	
	var def: TownManager.RuinDef = _town_manager.get_ruin_def(preferred_vacancy)
	if not def:
		return {}
	
	# Convert the visitor to a resident
	var npc_id: String = "resident_%s_%d" % [preferred_vacancy, Time.get_unix_time_from_system()]
	# Re-style the visitor's name to the building's role so the resident's name
	# matches their new profession ("Mara the Explorer" → "Mara the Baker").
	var base_name: String = str(visitor.get("_npc_display_name")) if "_npc_display_name" in visitor else ""
	if base_name.is_empty():
		base_name = str(visitor.get("npc_name"))
	if base_name.is_empty():
		base_name = "New Resident"
	var npc_name: String = VisitorNPC.get_resident_name(def.npc_role, base_name)
	
	visitor.convert_to_resident(npc_id, def.npc_role, preferred_vacancy, def.grid_cell, npc_name)
	# TownManager registration is handled inside convert_to_resident (multiplayer-aware)
	
	return {
		"npc_id": npc_id,
		"npc_name": npc_name,
		"role": def.npc_role,
		"home_ruin": preferred_vacancy,
		"building_name": def.building_name,
	}

## Re-fetch town/visitor manager references if they were null at _ready time.
## Guards against spawn-order issues between the ResidentRecruiter node and
## the TownManager / VisitorManager nodes.
func _refresh_manager_refs() -> void:
	if not _town_manager:
		_town_manager = get_tree().get_first_node_in_group("town_manager")
	if not _visitor_manager:
		_visitor_manager = get_tree().get_first_node_in_group("visitor_manager")

## Gather candidate VisitorNPCs to recruit. Prefers the active ship's roster,
## but also includes any valid VisitorNPC currently in the island's
## "visitor_npcs" group (covering NPCs that aren't in the ship's roster).
func _collect_visitor_candidates() -> Array:
	var candidates: Array = []
	
	# 1) The active ship's roster (if there is one)
	var ship = _get_active_ship()
	if ship and ship.has_method("get_visitor_npcs"):
		candidates.append_array(ship.get_visitor_npcs())
	
	# 2) Any VisitorNPC on the island not already captured above
	var seen := {}
	for c in candidates:
		if is_instance_valid(c):
			seen[c.get_instance_id()] = true
	for npc in get_tree().get_nodes_in_group("visitor_npcs"):
		if is_instance_valid(npc) and npc.has_method("convert_to_resident") and not seen.has(npc.get_instance_id()):
			candidates.append(npc)
	
	# Filter to valid nodes only
	var result: Array = []
	for c in candidates:
		if is_instance_valid(c) and c.has_method("convert_to_resident"):
			result.append(c)
	return result

func _get_active_ship() -> Node:
	if not _visitor_manager:
		return null
	if _visitor_manager.has_method("get_active_ship"):
		return _visitor_manager.get_active_ship()
	# Fallback: find VisitorShip in tree
	var ships := get_tree().get_nodes_in_group("visitor_ships")
	if ships.size() > 0:
		return ships[0]
	return null
