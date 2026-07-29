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

## Current berth offset — positioned left of the dock, close to the gangplank area
var berth_offset: Vector2 = Vector2(200, -25)

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
		# Ship is above-left of the dock walkable area, so NPCs spawn
		# below and right of the ship to reach the dock surface.
		npc.home_position = global_position + Vector2(8 + i * 24, 72)
		npc.dock_position = dock_position
		
		# Stagger spawns so NPCs walk off the ship one by one
		npc.global_position = global_position + Vector2(8 + i * 24, 60)
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

## Called when it's time for NPCs to return to the ship.
func recall_npcs() -> void:
	if not npcs_ashore:
		return
	
	for entry in _npc_roster:
		var npc = entry.get("npc")
		if is_instance_valid(npc):
			npc.call_deferred("return_to_ship", global_position)
	
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
