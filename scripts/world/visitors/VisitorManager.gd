## VisitorManager — schedules and manages visitor ship arrivals and departures.
## Ships arrive in the morning (06:00-09:00), NPCs explore the island during
## the day, and ships depart at dusk (18:00-20:00).
##
## Follows the same scheduling pattern as PirateRaidEvent (called from
## World._on_day_changed → advance_day, and from World._process for time checks).

extends Node
class_name VisitorManager

## Preloaded scene for visitor ship
const SHIP_SCENE := preload("res://scenes/world/visitors/VisitorShip.tscn")

## Minimum gap between ship visits (in days) for a ship to arrive
const MIN_VISIT_GAP: int = 2

## Chance each eligible day that a ship arrives
const ARRIVAL_CHANCE: float = 0.6

## Chance that any given NPC decides to be a paying hotel guest (0.0 - 1.0).
const HOTEL_REGISTER_CHANCE: float = 0.55

## Hour range for morning arrival (6:00 AM to 9:00 AM)
const ARRIVAL_HOUR_MIN: int = 6
const ARRIVAL_HOUR_MAX: int = 9

## Hour range for evening departure (18:00 = 6 PM to 20:00 = 8 PM)
const DEPARTURE_HOUR_MIN: int = 18
const DEPARTURE_HOUR_MAX: int = 20

## Hour at night when remaining roaming NPCs head to the hotel (if one exists).
const HOTEL_NIGHT_HOUR: int = 20

## Days since last ship visit
var _days_since_last_visit: int = 99

## Current active visitor ship, if any
var _active_ship: VisitorShip = null

## Whether we've already deployed NPCs today (after arrival)
var _deployed_today: bool = false

## Whether NPCs have been recalled today (before departure)
var _recalled_today: bool = false

## Whether the ship has already departed
var _departed_today: bool = false

## Whether we should spawn a ship on the next eligible day
var _arrival_scheduled: bool = false

## Whether the nighttime hotel-directing has already been done today
var _night_hotel_triggered: bool = false

## Whether this is a remote copy (client) — skip decision logic
var _is_remote: bool = false


func _ready() -> void:
	add_to_group("visitor_manager")
	if NetworkManager.is_network_active() and not multiplayer.is_server():
		_is_remote = true
		# A joining peer may have missed the one-shot visitor-ship broadcast
		# (connected after the ship arrived, or dock not ready at the time).
		# Pull the current snapshot from the host once connected.
		call_deferred("_request_visitor_state_deferred")

## Called each day from World._on_day_changed.
func advance_day(_day: int) -> void:
	if _is_remote:
		return
	_days_since_last_visit += 1
	_deployed_today = false
	_recalled_today = false
	_departed_today = false
	_night_hotel_triggered = false
	
	# Check if a new ship should arrive today
	if not _active_ship and _days_since_last_visit >= MIN_VISIT_GAP:
		if randf() < ARRIVAL_CHANCE:
			_arrival_scheduled = true

## Called from World._process each frame to handle time-of-day triggers.
func check_time(hour: int) -> void:
	if _is_remote or not is_inside_tree():
		return
	
	# Arrival window: spawn a ship if scheduled and it's arrival time
	if _arrival_scheduled and not _active_ship and not _departed_today:
		if hour >= ARRIVAL_HOUR_MIN and hour < ARRIVAL_HOUR_MAX:
			_spawn_ship()
			_arrival_scheduled = false
	
	# Deployment: after ship arrives and starts deploying NPCs naturally
	# (handled by VisitorShip's arrival timer)
	
	# Nighttime: direct any roaming NPCs that haven't been recalled to the
	# hotel. These NPCs check in and stay overnight instead of departing.
	if _active_ship and _active_ship.is_docked:
		if hour >= HOTEL_NIGHT_HOUR and not _night_hotel_triggered:
			_night_hotel_triggered = true
			_direct_roamers_to_hotel()
	
	# Departure window: recall NPCs and depart
	if _active_ship and _active_ship.is_docked:
		if hour >= DEPARTURE_HOUR_MIN and hour < DEPARTURE_HOUR_MAX:
			if not _recalled_today:
				_recalled_today = true
				_try_recruit_resident()
				# Clear daytime hotel guests (they've generated their income)
				_clear_hotel_guests()
				_active_ship.recall_npcs()
				_broadcast_recall()
				_broadcast_ship_departure()
		elif hour >= DEPARTURE_HOUR_MAX and not _departed_today:
			_departed_today = true
			if not _recalled_today:
				# Missed the normal window — NPCs still roaming have already been
				# directed to the hotel by the night trigger above, so just recruit.
				_try_recruit_resident()
			# Tell the ship to sail off (queue_frees remaining NPC nodes, including
			# checked-in ones). Don't clear hotel guests here — nighttime guests
			# stay overnight and are handled on the next arrival or departure.
			_active_ship.recall_npcs()
			_broadcast_recall()
			_broadcast_ship_departure()

## Spawn a visitor ship at the dock.
func _spawn_ship() -> void:
	if not is_inside_tree():
		return
	
	var world := get_tree().get_first_node_in_group("world")
	if not world or not world.has_method("get_dock_position"):
		return
	
	var dock_pos: Vector2 = world.get_dock_position()
	if dock_pos == Vector2.ZERO:
		return
	
	var dock_node: Dock = null
	if world.has_method("get_dock"):
		dock_node = world.get_dock()
	if not dock_node:
		return
	
	# Instantiate and position at Berth 2
	var ship: VisitorShip = SHIP_SCENE.instantiate() as VisitorShip
	if not ship:
		return
	ship.dock_position = dock_pos
	# berth_offset is set by default in VisitorShip.gd
	world.add_child(ship)
	
	_active_ship = ship
	_days_since_last_visit = 0
	
	# Start arrival sequence
	ship.arrive()
	
	# Connect to ship's deployed signal to register guests at hotels
	ship.visitors_disembarked.connect(_on_visitors_disembarked)
	
	# Show toast notification for the visit
	ToastNotification.show_toast("A visitor ship has arrived! Friendly travelers are ashore.", ToastNotification.ToastType.INFO, 4.0)

## Called when visitor NPCs disembark from the ship.
## Registers them as guests at any hotel buildings on the island.
func _on_visitors_disembarked() -> void:
	if not _active_ship or not _active_ship.is_inside_tree():
		return
	_register_hotel_guests()

	# Broadcast NPC roster to remote clients
	if not _is_remote:
		var roster := _build_roster_data()
		if not roster.is_empty():
			var world := get_tree().get_first_node_in_group("world")
			if world and world.has_method("notify_visitor_arrived"):
				world.notify_visitor_arrived(roster, _active_ship.berth_offset)

## Build serialisable roster data from the active ship's NPCs.
func _build_roster_data() -> Array[Dictionary]:
	if not _active_ship or not _active_ship.has_method("get_visitor_npcs"):
		return []
	var npcs: Array = _active_ship.get_visitor_npcs()
	var result: Array[Dictionary] = []
	for npc in npcs:
		if not is_instance_valid(npc):
			continue
		result.append({
			"type": npc.npc_type,
			"name": npc._npc_display_name,
			"tex": npc._npc_texture_variant,
		})
	return result


## Client → host pull: ask for the current ship + NPC roster snapshot.
func _request_visitor_state_deferred() -> void:
	if not NetworkManager.is_network_active() or not _is_remote:
		return
	var world := get_tree().get_first_node_in_group("world")
	if world and world.has_method("_server_request_visitor_state"):
		world.rpc_id(1, "_server_request_visitor_state")


## Host-side snapshot of the current docked visitor ship (roster + berth),
## sent to a joining client on request. Empty dict = no ship to show.
func current_ship_snapshot() -> Dictionary:
	if _is_remote or not _active_ship or not is_instance_valid(_active_ship) or not _active_ship.is_docked:
		return {}
	var roster := _build_roster_data()
	if roster.is_empty():
		return {}
	return {"roster": roster, "berth": _active_ship.berth_offset}


## Broadcast ship departure to remote clients.
func _broadcast_ship_departure() -> void:
	if _is_remote:
		return
	var world := get_tree().get_first_node_in_group("world")
	if world and world.has_method("notify_visitor_departed"):
		world.notify_visitor_departed()


## Tell clients to walk their roaming NPCs to the hotel at night too.
func _broadcast_hotel_direct(hotel_pos: Vector2) -> void:
	if _is_remote:
		return
	var world := get_tree().get_first_node_in_group("world")
	if world and world.has_method("notify_visitor_hotel_direct"):
		world.notify_visitor_hotel_direct(hotel_pos)


## Tell clients to recall their NPCs to the dock walkway before departure.
func _broadcast_recall() -> void:
	if _is_remote:
		return
	var world := get_tree().get_first_node_in_group("world")
	if world and world.has_method("notify_visitor_recall"):
		world.notify_visitor_recall()


## Find all placed hotel buildings and register guests.
## Each NPC has a HOTEL_REGISTER_CHANCE to become a paying guest,
## so not all visitors end up at the hotel every time.
func _register_hotel_guests() -> void:
	if not _active_ship:
		return
	
	var hotels: Array[Node] = get_tree().get_nodes_in_group("hotel_buildings")
	if hotels.is_empty():
		return
	
	# Collect all visitor NPCs from the ship's roster
	var all_visitors: Array = _get_active_visitor_npcs()
	if all_visitors.is_empty():
		return
	
	# Each NPC independently decides to become a hotel guest (chance-based).
	# This prevents 100% of visitors from filling the hotel every trip.
	var registering_count: int = 0
	for npc in all_visitors:
		if not is_instance_valid(npc):
			continue
		if randf() < HOTEL_REGISTER_CHANCE:
			registering_count += 1
			# Give the NPC the first hotel's position so they know where to go
			var first_hotel := hotels[0] as Hotel
			if first_hotel and npc.has_method("set_hotel_position"):
				npc.set_hotel_position(first_hotel.get_hotel_position())
	
	if registering_count <= 0:
		return  # No NPCs decided to register this time
	
	# Distribute registered guests across all hotels
	var guests_per_hotel: int = ceil(float(registering_count) / float(hotels.size()))
	
	for hotel_node in hotels:
		var hotel := hotel_node as Hotel
		if hotel:
			hotel.register_guests(guests_per_hotel)

## Count how many NPCs are currently active from the ship's roster.
func _get_active_npc_count() -> int:
	if not _active_ship or not _active_ship.is_inside_tree():
		return 0
	return _active_ship.get_npc_count()

## Return all active VisitorNPC nodes from the ship's roster.
func _get_active_visitor_npcs() -> Array:
	if not _active_ship or not _active_ship.is_inside_tree():
		return []
	if _active_ship.has_method("get_visitor_npcs"):
		return _active_ship.get_visitor_npcs()
	return []

## At night, direct any remaining roaming NPCs to head to the hotel.
## NPCs that have already checked in are skipped.
func _direct_roamers_to_hotel() -> void:
	var hotels: Array[Node] = get_tree().get_nodes_in_group("hotel_buildings")
	if hotels.is_empty():
		return
	var first_hotel := hotels[0] as Hotel
	if not first_hotel or not first_hotel.is_inside_tree():
		return
	var hotel_pos: Vector2 = first_hotel.get_hotel_position()
	if hotel_pos == Vector2.ZERO:
		return
	
	var roamers := _get_active_visitor_npcs()
	for npc in roamers:
		if not is_instance_valid(npc):
			continue
		if npc.has_method("go_to_hotel"):
			npc.go_to_hotel(hotel_pos)
	_broadcast_hotel_direct(hotel_pos)

## Called during departure — clears hotel guests before ship leaves.
func _clear_hotel_guests() -> void:
	var hotels: Array[Node] = get_tree().get_nodes_in_group("hotel_buildings")
	for hotel_node in hotels:
		var hotel := hotel_node as Hotel
		if hotel:
			hotel.clear_remaining_guests()

## Format a list of names with commas and "and".
static func _format_list(items: Array) -> String:
	if items.size() <= 2:
		return " and ".join(items)
	var parts := items.slice(0, -1)
	return ", ".join(parts) + ", and " + items[-1]

## Creative-mode: instantly spawn a visitor ship (bypasses arrival window checks).
## Used by CreativePanel's "Spawn Visitor Boat" button for testing.
func creative_spawn_ship() -> void:
	if _active_ship and _active_ship.is_inside_tree():
		ToastNotification.show_toast("A visitor ship is already here!", ToastNotification.ToastType.WARNING, 2.0)
		return
	_arrival_scheduled = false
	_spawn_ship()

## Whether there's currently an active ship with visitors ashore.
func has_active_visitors() -> bool:
	return _active_ship != null and _active_ship.has_active_visitors()

func get_active_ship():
	return _active_ship

## Try to recruit a town resident from the departing visitors.
func _try_recruit_resident() -> void:
	var recruiter := get_tree().get_first_node_in_group("resident_recruiter")
	if not recruiter or not recruiter.has_method("try_recruit"):
		return
	var result: Dictionary = recruiter.try_recruit()
	if not result.is_empty():
		ToastNotification.show_toast(
			"%s has decided to stay and settle in town!" % [result.get("npc_name", "A visitor")],
			ToastNotification.ToastType.SUCCESS,
			5.0
		)