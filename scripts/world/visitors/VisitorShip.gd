## VisitorShip — a friendly ship that docks at Berth 2 for the day.
## Carries NPCs who disembark, explore the island, and return at dusk.
## Follows the same scheduling pattern as PirateRaidEvent.

extends Node2D
class_name VisitorShip

signal visitors_disembarked
signal visitors_embarked
signal ship_departed

## NPC types carried by this ship
enum VisitorType {
	EXPLORER,    # Curious wanderer — explores buildings and landmarks
	FISHER,      # Heads to water and fishes
	SHOPPER,     # Visits the shop stand
	SIGHTSEER,   # Admires flowers, trees, and nature
	VENDOR,      # Stays near dock with a portable shop
	ARTIST,      # Paints/draws scenic spots
	FORAGER,     # Gathers wild plants and mushrooms
}

## The ship's NPC roster — each entry is {type: VisitorType, npc: VisitorNPC}
var _npc_roster: Array[Dictionary] = []

## Reference to the dock position (set by World)
var dock_position: Vector2 = Vector2.ZERO

## Berth spot — the visitor ship shares the center berth (Berth 1) with the
## pirate ship, which is the highly-visible spot at the dock's edge. When a
## pirate raid is active at the same time, the visitor ship shifts south below
## the pirate ship so the two never overlap.
const BERTH_BASE := Vector2(0, 60)
## Visitor ship's position when a pirate ship is occupying the shared berth.
const BERTH_DISPLACED := Vector2(0, 200)

## Current berth offset — normally BERTH_BASE, BERTH_DISPLACED during a raid.
var berth_offset: Vector2 = BERTH_BASE

## Whether the ship is currently docked and NPCs are ashore
var is_docked: bool = false

## Whether NPCs are currently ashore
var npcs_ashore: bool = false

@onready var ship_sprite: Sprite2D = $ShipSprite
@onready var block_body: StaticBody2D = $BlockBody
@onready var arrival_timer: Timer = $ArrivalTimer
@onready var departure_timer: Timer = $DepartureTimer

func _ready() -> void:
	add_to_group("visitor_ships")
	add_to_group("visitor_ship")
	arrival_timer.timeout.connect(_on_arrival_animation_done)
	departure_timer.timeout.connect(_depart)

## Called by World when the ship should arrive at the dock.
## Spawns the ship at the berth, plays arrival effects, then deploys NPCs.
func arrive() -> void:
	if is_docked:
		return
	
	is_docked = true
	# Pick berth: share the pirate's center berth normally, but shift south
	# below the pirate ship if a raid is already underway.
	berth_offset = BERTH_DISPLACED if _pirate_ship_present() else BERTH_BASE
	# Position at berth
	global_position = dock_position + berth_offset
	
	# Arrival animation: sail in from off-screen right (far right side of dock)
	var start_pos := global_position + Vector2(300, 0)
	global_position = start_pos
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", dock_position + berth_offset, 2.0)
	tween.parallel().tween_property(ship_sprite, "modulate:a", 1.0, 0.5).from(0.0)
	
	# Play boat travel sound
	AudioManager.play(AudioManager.Sound.BOAT_TRAVEL)
	
	# After arrival animation, deploy NPCs
	arrival_timer.one_shot = true
	arrival_timer.wait_time = 2.5
	arrival_timer.start()

## True when a pirate raid is active (pirate ship at the center berth).
func _pirate_ship_present() -> bool:
	var world := get_tree().get_first_node_in_group("world")
	if world and "pirate_raid" in world:
		var raid = world.pirate_raid
		if raid and raid.has_method("is_raid_active"):
			return raid.is_raid_active()
	return false

## Called by PirateRaidEvent when a raid starts while we're docked at the
## shared berth — shift south below the pirate ship so they don't overlap.
func displace_for_pirate() -> void:
	if not is_docked or berth_offset == BERTH_DISPLACED:
		return
	berth_offset = BERTH_DISPLACED
	var target := dock_position + berth_offset
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", target, 1.2)
	_broadcast_berth()

## Called by PirateRaidEvent when the pirate ship leaves — slide the visitor
## ship back up to its normal berth at the dock's edge.
func restore_berth() -> void:
	if not is_docked or berth_offset == BERTH_BASE:
		return
	berth_offset = BERTH_BASE
	var target := dock_position + berth_offset
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", target, 1.2)
	_broadcast_berth()

## Client: apply a host-dictated berth offset (e.g. pirate displacement).
func set_berth_offset(offset: Vector2) -> void:
	if berth_offset == offset:
		return
	berth_offset = offset
	if not is_inside_tree():
		return
	var target := dock_position + berth_offset
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", target, 1.2)

## Host: broadcast this ship's berth offset so clients move their copies.
func _broadcast_berth() -> void:
	if not NetworkManager.is_network_active() or not multiplayer.is_server():
		return
	var world := get_tree().get_first_node_in_group("world")
	if world and world.has_method("notify_visitor_berth_changed"):
		world.notify_visitor_berth_changed(berth_offset)

## Called after the arrival sail-in animation finishes.
func _on_arrival_animation_done() -> void:
	_deploy_npcs()
	visitors_disembarked.emit()

## Deploy NPCs from the ship onto the dock.
func _deploy_npcs() -> void:
	if not is_inside_tree():
		return
	
	var world := get_tree().get_first_node_in_group("world")
	if not world or not world.has_method("get_dock_position"):
		return
	
	_npc_roster.clear()
	var npc_types := generate_roster()
	
	const NPC_SCENE := preload("res://scenes/world/visitors/VisitorNPC.tscn")
	for i in range(npc_types.size()):
		var ntype: int = npc_types[i]
		var npc := NPC_SCENE.instantiate() as VisitorNPC
		npc.npc_type = ntype
		npc._synced_index = i
		npc.dock_position = dock_position
		
		# The ship berths over water, so spawn NPCs on the dock walkway
		# (spaced along its right edge toward the ship) instead of
		# ship-relative offsets that land in the harbor and get stuck.
		var spawn_pos := dock_spawn_position(dock_position, i, world)
		npc.home_position = spawn_pos
		
		# Stagger spawns so NPCs walk off the ship one by one
		npc.global_position = spawn_pos
		npc.modulate.a = 0.0
		world.add_child(npc)
		
		var entry_tween := create_tween()
		entry_tween.set_trans(Tween.TRANS_SINE)
		entry_tween.set_ease(Tween.EASE_OUT)
		entry_tween.tween_interval(0.3 * i + 0.5)
		entry_tween.tween_property(npc, "modulate:a", 1.0, 0.4)
		entry_tween.tween_callback(func():
			if is_instance_valid(npc):
				npc.start_wandering()
		)
		
		_npc_roster.append({"type": ntype, "npc": npc})
	
	npcs_ashore = true

## Find a walkable dock position for the i-th deploying NPC. Tries a spread
## of candidates across the dock walkway, falling back to a jittered spot
## still on the walkway (never an exact pixel stack) when nothing passes.
## Static so both the host (_deploy_npcs) and clients (_sync_spawn_visitor_ship)
## place NPCs identically on the dock instead of ship-relative water offsets.
## Crucial: candidates must stay clear of the dock shop's solid blocker (which
## sits mid-dock). An NPC spawned inside that blocker can't move in any
## direction (simple wall-slide movement) and is stuck on the dock forever.
static func dock_spawn_position(dock_pos: Vector2, index: int, world: Node = null) -> Vector2:
	var row: int = index / 4
	var col: int = index % 4
	# Spread across the dock's walkable width, alternating to the LEFT and RIGHT
	# of the shop blocker (which spans x -48..48, y -24..24 relative to dock_pos).
	# The walkable dock flanks are roughly x -96..-56 and x 56..96 at these rows.
	var side: float = 1.0 if index % 2 == 0 else -1.0
	var flank: float = 72.0 + (col % 2) * 20.0  # 72 or 92 px from center
	var candidates: Array[Vector2] = [
		dock_pos + Vector2(side * flank, 20.0 + row * 18.0),
		dock_pos + Vector2(side * (flank + 16.0), 12.0 + row * 18.0),
		dock_pos + Vector2(-side * flank, 20.0 + row * 18.0),
		dock_pos + Vector2(col * 26.0 - 40.0, 20.0 + row * 18.0),
		dock_pos + Vector2(randf_range(-90.0, 90.0), randf_range(0.0, 18.0)),
	]
	for candidate in candidates:
		if _spawn_spot_clear(candidate, world):
			return candidate
	return dock_pos + Vector2(side * 80.0, 16.0)

## True if a spawn spot is walkable AND not inside the dock shop's solid blocker.
static func _spawn_spot_clear(spot: Vector2, world: Node) -> bool:
	if world and world.has_method("is_position_in_shop_blocker") and world.is_position_in_shop_blocker(spot):
		return false
	if world and world.has_method("is_cell_walkable"):
		return world.is_cell_walkable(spot)
	return true

## Generate a random roster of 3-5 NPCs for this visit.
## Always includes at least one vendor and one explorer.
func generate_roster() -> Array[int]:
	var types: Array[int] = []
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	
	var count := rng.randi_range(3, 5)
	
	# Always include at least one Vendor and one Explorer
	types.append(VisitorType.VENDOR)
	types.append(VisitorType.EXPLORER)
	
	# Fill remaining slots randomly from the full NPC pool
	var pool: Array[int] = [
		VisitorType.EXPLORER,
		VisitorType.FISHER,
		VisitorType.SHOPPER,
		VisitorType.SIGHTSEER,
		VisitorType.ARTIST,
		VisitorType.FORAGER,
	]
	pool.shuffle()
	for i in range(count - 2):
		types.append(pool[i % pool.size()])
	
	types.shuffle()
	return types

## Called when it's time for NPCs to return and disembark.
## NPCs walk back to the dock walkway (not the ship, which moors over water)
## and fade out there — they never cross the water to board.
func recall_npcs() -> void:
	if not npcs_ashore:
		return
	
	for entry in _npc_roster:
		var npc = entry.get("npc")
		if is_instance_valid(npc):
			var walkway_target: Vector2 = dock_position + Vector2(
				randf_range(32.0, 96.0),    # dx 2..6 tiles — on the pier
				randf_range(-32.0, 8.0))    # dy 1.4..3.9 tiles (dock anchor is +54px below the coast row)
			npc.call_deferred("return_to_ship", walkway_target)
	
	npcs_ashore = false
	
	# Wait for NPCs to arrive, then depart
	departure_timer.one_shot = true
	departure_timer.wait_time = 3.0
	departure_timer.start()

## Sail away from the dock.
func _depart() -> void:
	if not is_inside_tree():
		return
	
	# Ensure any remaining NPCs are cleaned up
	for entry in _npc_roster:
		if not entry.has("npc"):
			continue
		var npc_variant = entry.get("npc")
		if is_instance_valid(npc_variant):
			npc_variant.queue_free()
	_npc_roster.clear()
	
	# Sail off
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(ship_sprite, "modulate:a", 0.0, 0.5)
	tween.parallel().tween_property(self, "global_position", global_position + Vector2(300, 0), 2.0)
	tween.tween_callback(func():
		is_docked = false
		ship_departed.emit()
		queue_free()
	)

## Check if this ship has NPCs ashore.
func has_active_visitors() -> bool:
	return npcs_ashore

## Get the number of NPCs carried by this ship.
func get_npc_count() -> int:
	return _npc_roster.size()

## Return an array of all active VisitorNPC nodes currently ashore.
func get_visitor_npcs() -> Array:
	var result: Array[Node] = []
	for entry in _npc_roster:
		if entry.has("npc"):
			var npc = entry["npc"]
			if is_instance_valid(npc):
				result.append(npc)
	return result
