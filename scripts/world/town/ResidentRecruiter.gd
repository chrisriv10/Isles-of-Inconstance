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
## Returns a Dictionary with conversion info, or null if no conversion happens.
func try_recruit() -> Dictionary:
	if not _town_manager or not _visitor_manager:
		return {}
	
	var vacancy_count: int = _town_manager.get_vacancy_count()
	if vacancy_count <= 0:
		return {}  # no vacancies
	
	if not _visitor_manager.has_active_visitors():
		return {}  # no visitors to recruit
	
	# Get active NPCs from the ship
	var ship = _get_active_ship()
	if not ship or not ship.has_method("get_visitor_npcs"):
		return {}
	
	var visitors: Array = ship.get_visitor_npcs()
	if visitors.is_empty():
		return {}
	
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
	var npc_name: String = visitor.get("npc_name") if "npc_name" in visitor else "New Resident"
	if visitor.has_method("get_npc_name"):
		if "npc_type" in visitor:
			npc_name = VisitorNPC.get_npc_name(visitor.npc_type)
	
	visitor.convert_to_resident(npc_id, def.npc_role, preferred_vacancy, def.grid_cell)
	# TownManager registration is handled inside convert_to_resident (multiplayer-aware)
	
	return {
		"npc_id": npc_id,
		"npc_name": npc_name,
		"role": def.npc_role,
		"home_ruin": preferred_vacancy,
		"building_name": def.building_name,
	}

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
