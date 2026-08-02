## VisitorNPC — a friendly NPC that disembarks from a VisitorShip,
## wanders the island for the day, then returns to the ship at dusk.
## Uses simple Animal-style movement (random target + walkability check).

extends Area2D
class_name VisitorNPC

## NPC types (mirrors VisitorShip.VisitorType)
enum VisitorType {
	EXPLORER,       # 0 — explores buildings and landmarks
	FISHER,         # 1 — heads to water and fishes
	SHOPPER,        # 2 — visits the shop stand
	SIGHTSEER,      # 3 — admires flowers, trees, and nature
	VENDOR,         # 4 — stays near dock with portable shop
	ARTIST,         # 5 — draws/paints scenic spots
	FORAGER,        # 6 — gathers wild plants and mushrooms
}

## Which type of NPC this is
var npc_type: int = VisitorType.EXPLORER

## Home position (where this NPC lives / where the ship is)
var home_position: Vector2 = Vector2.ZERO

## The dock position (for vendor and return behavior)
var dock_position: Vector2 = Vector2.ZERO

## Movement speed in pixels/sec
var speed: float = 28.0

## Whether the NPC is actively wandering
var _is_wandering: bool = false

## Current wander target position
var _target_pos: Vector2 = Vector2.ZERO

## How long to idle at a target before picking a new one
var _idle_timer: float = 0.0

## Whether the NPC is returning to the ship
var _is_returning: bool = false

## Ship position to return to
var _return_target: Vector2 = Vector2.ZERO

## Dialogue bubble elements
var _dialogue_bubble: Node2D
var _dialogue_label: Label

## Reference to the world
var _world: Node

## Hotel position — set by VisitorManager when this NPC is a potential guest.
var _hotel_position: Vector2 = Vector2.ZERO

## Whether this NPC is heading to the hotel (either daytime random or nighttime forced).
var _is_going_to_hotel: bool = false

## Whether this NPC has arrived at the hotel and is now "inside" (invisible, inactive).
var _checked_in: bool = false

## Chosen display name variant for this NPC instance.
var _npc_display_name: String = ""

## Chosen texture variant index for this NPC instance.
var _npc_texture_variant: int = 0

## Chance (0.0 - 1.0) per wander timeout to head to the hotel during the day.
const DAYTIME_HOTEL_CHANCE: float = 0.15

## Squared distance threshold for considering the NPC to have arrived at the hotel.
const HOTEL_ARRIVAL_DIST_SQ: float = 600.0

## NPC display name per type — returns a randomly picked name.
## External callers (BuildingInterior, ResidentRecruiter) get the default name.
static func get_npc_name(ntype: int) -> String:
	return get_npc_names(ntype)[0]

## Possible names per NPC type (pick randomly for variety).
static func get_npc_names(ntype: int) -> Array[String]:
	match ntype:
		VisitorType.EXPLORER:
			return ["Mara the Explorer", "Finn the Adventurer", "Sage the Trailblazer"]
		VisitorType.FISHER:
			return ["Old Finn", "Captain Cora", "Ned the Angler"]
		VisitorType.SHOPPER:
			return ["Lena the Shopper", "Bertie the Buyer", "Molly the Collector"]
		VisitorType.SIGHTSEER:
			return ["Pippin the Sightseer", "Rosie the Gazer", "Wally the Wanderer"]
		VisitorType.VENDOR:
			return ["Merchant Vela", "Trader Tobin", "Bargain Bess"]
		VisitorType.ARTIST:
			return ["Palette Pete", "Sketchy Sal", "Brushstroke Bella"]
		VisitorType.FORAGER:
			return ["Fern the Forager", "Clover the Picker", "Moss the Gatherer"]
	return ["Visitor"]

## Possible texture paths per NPC type — pick randomly for variety.
static func get_npc_texture_paths(ntype: int) -> Array[String]:
	match ntype:
		VisitorType.EXPLORER:
			return ["res://assets/generated/npc_explorer_frame_0.png", "res://assets/generated/npc_explorer_b_frame_0.png"]
		VisitorType.FISHER:
			return ["res://assets/generated/npc_fisher_frame_0.png", "res://assets/generated/npc_fisher_b_frame_0.png"]
		VisitorType.VENDOR:
			return ["res://assets/generated/npc_vendor_frame_0.png", "res://assets/generated/npc_vendor_b_frame_0.png"]
		VisitorType.SIGHTSEER:
			return ["res://assets/generated/npc_sightseer_frame_0.png", "res://assets/generated/npc_sightseer_b_frame_0.png"]
		VisitorType.SHOPPER:
			return ["res://assets/generated/npc_shopper_frame_0.png", "res://assets/generated/npc_shopper_b_frame_0.png"]
		VisitorType.ARTIST:
			return ["res://assets/generated/npc_artist_frame_0.png", "res://assets/generated/npc_artist_b_frame_0.png"]
		VisitorType.FORAGER:
			return ["res://assets/generated/npc_forager_frame_0.png", "res://assets/generated/npc_forager_b_frame_0.png"]
		_:
			return ["res://assets/generated/npc_explorer_frame_0.png"]

## Backward-compatible single-texture getter (variant 0).
static func get_npc_texture_path(ntype: int) -> String:
	return get_npc_texture_paths(ntype)[0]

@onready var sprite: Sprite2D = $Sprite2D
@onready var coll_shape: CollisionShape2D = $CollisionShape2D
@onready var interaction_area: Area2D = $InteractionArea
@onready var label: Label = $Label
@onready var wander_timer: Timer = $WanderTimer

func _ready() -> void:
	add_to_group("visitor_npcs")
	_world = get_tree().get_first_node_in_group("world")
	
	# Pick random name and texture variant for variety
	var rng := RandomNumberGenerator.new()
	var name_pool: Array[String] = get_npc_names(npc_type)
	_npc_display_name = name_pool[rng.randi() % name_pool.size()]
	
	var tex_pool: Array[String] = get_npc_texture_paths(npc_type)
	_npc_texture_variant = rng.randi() % tex_pool.size()
	var tex_path := tex_pool[_npc_texture_variant]
	var tex := load(tex_path) if ResourceLoader.exists(tex_path) else load("res://assets/sprites/player.png")
	if tex:
		sprite.texture = tex
	
	label.text = _npc_display_name
	
	# Build dialogue bubble programmatically
	_setup_dialogue()
	
	# Connect interaction
	if interaction_area:
		interaction_area.body_entered.connect(_on_body_entered)
	
	# Wander timer
	if wander_timer:
		wander_timer.timeout.connect(_on_wander_timeout)
		wander_timer.one_shot = true

func _setup_dialogue() -> void:
	_dialogue_bubble = Node2D.new()
	_dialogue_bubble.name = "DialogueBubble"
	_dialogue_bubble.position = Vector2(0, -18)
	# Draw above building sprites (z=0) and the NPC sprite (z=4) so the
	# bubble never gets cut off behind town buildings.
	_dialogue_bubble.z_index = 5
	_dialogue_bubble.visible = false
	
	_dialogue_label = Label.new()
	_dialogue_label.name = "DialogueLabel"
	_dialogue_label.size = Vector2(72, 16)
	_dialogue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dialogue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_dialogue_label.add_theme_font_size_override("font_size", 6)
	
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.15, 0.85)
	sb.border_color = Color(1.0, 1.0, 0.6, 0.8)
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	_dialogue_label.add_theme_stylebox_override("normal", sb)
	
	_dialogue_bubble.add_child(_dialogue_label)
	add_child(_dialogue_bubble)

## Start wandering the island.
func start_wandering() -> void:
	if _is_wandering or _is_returning or _checked_in:
		return
	_is_wandering = true
	_pick_new_target()

## Set the hotel position so the NPC knows where to go on random visits.
func set_hotel_position(pos: Vector2) -> void:
	_hotel_position = pos

## Tell this NPC to head to the hotel (called by VisitorManager at night,
## or triggered randomly during daytime wandering).
func go_to_hotel(hotel_pos: Vector2) -> void:
	if _checked_in or _is_returning:
		return
	_hotel_position = hotel_pos
	if _hotel_position == Vector2.ZERO:
		return
	_is_going_to_hotel = true
	_is_wandering = false
	_target_pos = _hotel_position
	_idle_timer = 0.0
	if wander_timer and wander_timer.is_inside_tree():
		wander_timer.stop()

## Pick a random walkable position on the island based on NPC type.
func _pick_new_target() -> void:
	if not _world or not _world.has_method("is_cell_walkable"):
		_idle_timer = 5.0
		return
	
	var max_attempts := 30
	for _attempt in range(max_attempts):
		var candidate: Vector2 = _pick_biased_position()
		var cell := Vector2i(int(candidate.x / 16), int(candidate.y / 16))
		
		if _world.has_method("_is_in_bounds") and not _world._is_in_bounds(cell):
			continue
		if not _world.is_cell_walkable(candidate):
			continue
		
		_target_pos = candidate
		_idle_timer = 0.0
		
		# Start wander timer
		if wander_timer:
			wander_timer.wait_time = 4.0 + randf() * 4.0
			wander_timer.start()
		return
	
	# Fallback: stay near the dock
	_target_pos = dock_position + Vector2(randf_range(-48.0, 48.0), randf_range(-48.0, 48.0))

## Pick a position biased by NPC type's interests.
func _pick_biased_position() -> Vector2:
	# Use the actual island center (world is 100×100 tiles = 1600×1600 px)
	# This ensures NPCs reach the town in the northwest, not just the dock area
	var world_center := Vector2(800, 800)  # Center of 1600×1600 world
	
	match npc_type:
		VisitorType.EXPLORER:
			# Roam the ENTIRE island — wide range to reach town, farm, dock, everything
			return world_center + Vector2(randf_range(-700.0, 700.0), randf_range(-700.0, 700.0))
		VisitorType.FISHER:
			# Head toward shoreline and water edges — prefer south/west coasts
			return world_center + Vector2(randf_range(-600.0, 400.0), randf_range(200.0, 700.0))
		VisitorType.SHOPPER:
			# Roam the central/west area — town shops, general store, stalls
			return world_center + Vector2(randf_range(-600.0, 200.0), randf_range(-400.0, 300.0))
		VisitorType.SIGHTSEER:
			# Explore the whole island — trees, decorations, scenic spots everywhere
			return world_center + Vector2(randf_range(-750.0, 750.0), randf_range(-750.0, 750.0))
		VisitorType.VENDOR:
			# Stays near the dock but also wanders into the island a bit
			return world_center + Vector2(randf_range(-200.0, 400.0), randf_range(200.0, 600.0))
		VisitorType.ARTIST:
			# Drawn toward scenic areas — flowers, water, nice views
			return world_center + Vector2(randf_range(-700.0, 500.0), randf_range(-600.0, 600.0))
		VisitorType.FORAGER:
			# Heads toward forests, farm fields, and wild areas
			return world_center + Vector2(randf_range(-600.0, 300.0), randf_range(-300.0, 600.0))
		_:
			return world_center + Vector2(randf_range(-600.0, 600.0), randf_range(-600.0, 600.0))

func _process(delta: float) -> void:
	# Already checked in — do nothing (invisible, waiting for departure)
	if _checked_in:
		return
	
	# Heading to the hotel
	if _is_going_to_hotel:
		if _hotel_position != Vector2.ZERO:
			_move_toward(_hotel_position, delta)
			# Arrived at hotel — check in
			if global_position.distance_squared_to(_hotel_position) < HOTEL_ARRIVAL_DIST_SQ:
				_enter_hotel()
		else:
			_is_going_to_hotel = false
			_is_wandering = true
			_pick_new_target()
		return
	
	if _is_returning and _return_target != Vector2.ZERO:
		_move_toward(_return_target, delta * 1.5)
		if global_position.distance_squared_to(_return_target) < 200.0:
			_on_arrived_at_ship()
		return
	
	if not _is_wandering:
		return
	
	# Move toward target
	if _target_pos != Vector2.ZERO:
		var dist_sq := global_position.distance_squared_to(_target_pos)
		if dist_sq > 64.0:
			_move_toward(_target_pos, delta)
		elif _idle_timer <= 0.0:
			# Reached target, idle a moment then find new target
			_idle_timer = 4.0 + randf() * 3.0
			_set_idle_sprite()
		else:
			_idle_timer -= delta
			if _idle_timer <= 0.0:
				_pick_new_target()

func _move_toward(target: Vector2, delta: float) -> void:
	var dir := (target - global_position).normalized()
	var step: Vector2 = dir * speed * delta
	var new_pos: Vector2 = global_position + step
	# Check if the new position is clear (same walls that block the player).
	# Water blocks wandering NPCs; returning NPCs may cross it to board.
	if _can_move_to(new_pos) and (_is_returning or _is_walkable(new_pos)):
		global_position = new_pos
	else:
		# Blocked — try moving on each axis separately (wall sliding)
		var slide_x: Vector2 = Vector2(step.x, 0)
		if _can_move_to(global_position + slide_x) and (_is_returning or _is_walkable(global_position + slide_x)):
			global_position.x += slide_x.x
		var slide_y: Vector2 = Vector2(0, step.y)
		if _can_move_to(global_position + slide_y) and (_is_returning or _is_walkable(global_position + slide_y)):
			global_position.y += slide_y.y
	# Flip sprite to face direction
	if dir.x < -0.1:
		sprite.flip_h = true
	elif dir.x > 0.1:
		sprite.flip_h = false

## Check if a position sits on walkable ground (not water). Falls back to
## true when the world grid is unavailable.
func _is_walkable(pos: Vector2) -> bool:
	if not _world or not _world.has_method("is_cell_walkable"):
		return true
	return _world.is_cell_walkable(pos)

## Check if a position is free of walls/building blockers (same layers as player uses).
func _can_move_to(pos: Vector2) -> bool:
	var shape_node := $CollisionShape2D
	if not shape_node or not shape_node.shape:
		return true
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape_node.shape
	query.transform = Transform2D(0.0, pos)
	query.collision_mask = 1 | 8  # layer 1 = walls/terrain, layer 8 = building blockers
	return space_state.intersect_shape(query, 1).is_empty()

func _set_idle_sprite() -> void:
	sprite.flip_h = sprite.flip_h  # Keep last facing direction

func _on_wander_timeout() -> void:
	if _is_wandering and not _is_returning and not _checked_in:
		# Random chance during the day to head to the hotel
		if _hotel_position != Vector2.ZERO and randf() < DAYTIME_HOTEL_CHANCE:
			go_to_hotel(_hotel_position)
		else:
			_pick_new_target()

## Called when the NPC arrives at the hotel — they become invisible/inactive
## (they're now "inside" the hotel). The hotel interior will show guest sprites.
func _enter_hotel() -> void:
	_checked_in = true
	_is_going_to_hotel = false
	_is_wandering = false
	visible = false
	# Disable collision so the player doesn't bump into an invisible NPC
	collision_layer = 0
	collision_mask = 0
	if wander_timer and wander_timer.is_inside_tree():
		wander_timer.stop()
	set_process(false)  # Stop processing entirely

## Begin returning to the ship for departure.
func return_to_ship(ship_pos: Vector2) -> void:
	if _checked_in:
		# Checked-in NPCs don't return — they stay at the hotel until the ship departs
		return
	_is_wandering = false
	_is_returning = true
	_return_target = ship_pos + Vector2(-32 + randi() % 48, 16)
	speed = 36.0  # Walk faster when returning

func _on_arrived_at_ship() -> void:
	if is_inside_tree():
		queue_free()

## Show a dialogue bubble with a message for 2 seconds.
func show_dialogue(msg: String, duration: float = 2.0) -> void:
	if not _dialogue_bubble or not _dialogue_label:
		return
	_dialogue_label.text = msg
	_dialogue_bubble.visible = true
	get_tree().create_timer(duration).timeout.connect(func():
		if is_instance_valid(_dialogue_bubble):
			_dialogue_bubble.visible = false
	)

## Convert this visitor to a permanent town resident
func convert_to_resident(npc_id: String, role_name: String, home_ruin_id: String, home_cell: Vector2i) -> void:
	# Create a TownResidentNPC at this position
	var resident_scene := preload("res://scenes/world/town/TownResidentNPC.tscn")
	if not resident_scene:
		return
	var resident := resident_scene.instantiate() as TownResidentNPC
	if not resident:
		return
	
	# Map role name to enum
	var role_map: Dictionary = {
		"villager": TownResidentNPC.Role.VILLAGER,
		"baker": TownResidentNPC.Role.BAKER,
		"chef": TownResidentNPC.Role.CHEF,
		"innkeeper": TownResidentNPC.Role.INNKEEPER,
		"blacksmith": TownResidentNPC.Role.BLACKSMITH,
		"shopkeep": TownResidentNPC.Role.SHOPKEEP,
		"scholar": TownResidentNPC.Role.SCHOLAR,
		"stablehand": TownResidentNPC.Role.STABLEHAND,
	}
	var role: int = role_map.get(role_name, TownResidentNPC.Role.VILLAGER)
	
	# Place the resident at their assigned building, not at the visitor's location
	var home_world_pos: Vector2 = Vector2(home_cell.x * 16 + 8, home_cell.y * 16 + 8)
	# The building sprite is centered on home_world_pos, so the resident
	# needs a door position at the bottom edge of the sprite — roughly
	# 1.5–2 tiles below center (24–36 px depending on sprite size).
	var door_pos: Vector2 = home_world_pos + Vector2(0, 32)
	resident.global_position = door_pos
	resident.initialize(npc_id, VisitorNPC.get_npc_name(npc_type), role, home_ruin_id, door_pos, door_pos, npc_type)
	
	# Add to world's objects root
	var world := get_tree().get_first_node_in_group("world")
	if world and world.has_node("Objects"):
		world.get_node("Objects").add_child(resident)
	
	# Remove this visitor from the scene
	queue_free()

# ── Conversation flow state ───────────────────────────────────────────
var _recruit_panel: PanelContainer = null
var _recruit_vbox: VBoxContainer = null
var _recruit_dim: ColorRect = null
var _recruit_step: int = 0
var _recruit_ruin_id: String = ""       # stored after step 1 lookup
var _recruit_building_name: String = ""
var _recruit_role_name: String = ""
var _recruit_home_cell: Vector2i = Vector2i.ZERO

## Open a conversation-style recruitment dialog.
func open_recruitment_dialog() -> void:
	var hud: CanvasLayer = get_tree().get_first_node_in_group("hud") as CanvasLayer
	if not hud:
		return
	
	# Build the panel once
	_build_conversation_panel(hud)
	_recruit_step = 0
	_show_conversation_step()

func _build_conversation_panel(hud: CanvasLayer) -> void:
	# Listen for Escape key globally on the panel
	var close_panel: Callable = func():
		_recruit_close()
	
	# Dim background
	_recruit_dim = ColorRect.new()
	_recruit_dim.name = "RecruitDim"
	_recruit_dim.color = Color(0, 0, 0, 0.55)
	_recruit_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_recruit_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_recruit_dim.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_recruit_close()
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			_recruit_close()
	)
	hud.add_child(_recruit_dim)
	
	# Panel
	_recruit_panel = PanelContainer.new()
	_recruit_panel.name = "RecruitPanel"
	_recruit_panel.custom_minimum_size = Vector2(320, 200)
	_recruit_panel.position = Vector2(
		hud.get_viewport().get_visible_rect().size.x / 2.0 - 160,
		hud.get_viewport().get_visible_rect().size.y / 2.0 - 100
	)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.102, 0.063, 0.031, 0.95)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.722, 0.525, 0.176)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	_recruit_panel.add_theme_stylebox_override("panel", style)
	hud.add_child(_recruit_panel)
	
	# VBox
	_recruit_vbox = VBoxContainer.new()
	_recruit_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_recruit_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_recruit_vbox.add_theme_constant_override("separation", 8)
	_recruit_panel.add_child(_recruit_vbox)
	
	# Close X button in the panel's top-right corner
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(24, 20)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	close_btn.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.pressed.connect(_recruit_close)
	close_btn.position = Vector2(
		_recruit_panel.custom_minimum_size.x - 28, 4
	)
	_recruit_panel.add_child(close_btn)
	
	# Entrance tween
	_recruit_panel.modulate = Color(1, 1, 1, 0)
	_recruit_panel.scale = Vector2(0.85, 0.85)
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(_recruit_panel, "modulate", Color(1, 1, 1, 1), 0.25)
	tween.parallel().tween_property(_recruit_panel, "scale", Vector2(1, 1), 0.25)

func _clear_dialog_content() -> void:
	if _recruit_vbox:
		for child: Node in _recruit_vbox.get_children():
			_recruit_vbox.remove_child(child)
			child.queue_free()

func _add_name_header() -> void:
	if not _recruit_vbox:
		return
	var name_label := Label.new()
	name_label.text = "  " + _npc_display_name
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", Color(0.85, 0.7, 0.25))
	_recruit_vbox.add_child(name_label)

func _add_dialog_text(text: String) -> void:
	if not _recruit_vbox:
		return
	var line := Label.new()
	line.text = text
	line.add_theme_font_size_override("font_size", 10)
	line.add_theme_color_override("font_color", Color(0.8, 0.75, 0.65))
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_recruit_vbox.add_child(line)

func _add_spacer(height: float = 8.0) -> void:
	if not _recruit_vbox:
		return
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, height)
	_recruit_vbox.add_child(sp)

func _add_button(text: String, callback: Callable, primary: bool = true) -> void:
	if not _recruit_vbox:
		return
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(160, 0)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(callback)
	_recruit_vbox.add_child(btn)

func _show_conversation_step() -> void:
	_clear_dialog_content()
	_add_name_header()
	
	match _recruit_step:
		0:
			# Step 1: Visitor greets the player
			var greeting: String = _get_greeting()
			_add_dialog_text("\"%s\"" % greeting)
			_add_spacer()
			_add_dialog_text("(They smile warmly as you approach.)")
			_add_spacer(12)
			_add_button("💬 Talk to " + _npc_display_name, _advance_conversation)
			# Quest option — check if any visitor quests are available or active
			if _has_visitor_quests():
				_add_button("📜 Got any tasks for me?", _open_quest_from_recruit)
		
		1:
			# Step 2: Visitor responds, mentions staying
			var visitor_name: String = _npc_display_name
			var interest_lines: Array[String] = [
				"I've been wandering this island all day — it's really something special!",
				"You know, I was thinking... I wouldn't mind settling down here.",
				"The town has so much charm. I could see myself calling this place home.",
			]
			var rng := RandomNumberGenerator.new()
			var line_text: String = interest_lines[rng.randi() % interest_lines.size()]
			
			_add_dialog_text("\"%s\"" % line_text)
			_add_spacer(4)
			_add_dialog_text("(They look at you hopefully.)")
			_add_spacer(8)
			
			# Check vacancies
			var town_mgr := get_tree().get_first_node_in_group("town_manager") as TownManager
			if not town_mgr or town_mgr.get_vacancy_count() <= 0:
				_add_dialog_text("...but there's nowhere for me to live yet. Restore some buildings first!")
				_add_spacer(12)
				_add_button("Maybe next time!", _recruit_close)
				return
			
			var ruin_id: String = town_mgr.get_preferred_vacancy(npc_type)
			if ruin_id.is_empty():
				_add_dialog_text("Hmm, none of the available homes quite suit me. Maybe later!")
				_add_spacer(12)
				_add_button("Alright, see you around!", _recruit_close)
				return
			
			var def: TownManager.RuinDef = town_mgr.get_ruin_def(ruin_id)
			if not def:
				_add_dialog_text("Something's not right with the buildings... I'll check back later.")
				_add_button("Okay!", _recruit_close)
				return
			
			# Store for later steps
			_recruit_ruin_id = ruin_id
			_recruit_building_name = def.building_name
			_recruit_role_name = def.npc_role
			_recruit_home_cell = def.grid_cell
			
			_add_dialog_text("You could move into %s — it's all ready for you!" % def.building_name)
			_add_spacer(6)
			_add_button("🏠 Invite them to stay!", _advance_conversation)
			_add_button("Maybe another time", _recruit_close, false)
		
		2:
			# Step 3: Confirmation
			_add_dialog_text("\"Wait, really? I'd love to live in %s! Are you sure?\"" % _recruit_building_name)
			_add_spacer(8)
			_add_button("✅ Yes, welcome to town!", _do_recruit_visitor)
			_add_button("Actually, not right now", _recruit_close, false)
		
		_:
			# Step 4: Success / fallback
			_add_dialog_text("\"Thank you so much! I promise I'll be a great neighbor!\"")
			_add_spacer(4)
			_add_dialog_text("(%s looks thrilled.)" % _npc_display_name)
			_add_spacer(8)
			_add_button("See you around town!", _recruit_close)

func _advance_conversation() -> void:
	_recruit_step += 1
	_show_conversation_step()

func _do_recruit_visitor() -> void:
	var town_mgr := get_tree().get_first_node_in_group("town_manager") as TownManager
	if not town_mgr:
		return
	
	# Re-check ruin still available
	var def := town_mgr.get_ruin_def(_recruit_ruin_id)
	if not def or town_mgr.get_ruin_status(_recruit_ruin_id) != TownManager.RuinStatus.RESTORED:
		ToastNotification.show_toast("That building is no longer available!", ToastNotification.ToastType.ERROR, 2.0)
		_recruit_close()
		return
	
	# Generate ID and convert
	var npc_id: String = "resident_%s_%d" % [_recruit_ruin_id, Time.get_unix_time_from_system()]
	var visitor_name: String = _npc_display_name
	
	# Close the panel first, then do the conversion (which queue_frees this node)
	var visitor_name2: String = visitor_name
	var bld_name: String = _recruit_building_name
	_recruit_close()
	
	convert_to_resident(npc_id, _recruit_role_name, _recruit_ruin_id, _recruit_home_cell)
	town_mgr.add_resident(npc_id, visitor_name2, _recruit_role_name, _recruit_ruin_id, npc_type)
	
	ToastNotification.show_toast("%s has moved into %s!" % [visitor_name2, bld_name], ToastNotification.ToastType.SUCCESS, 4.0)

func _recruit_close() -> void:
	if is_instance_valid(_recruit_dim):
		_recruit_dim.queue_free()
	if is_instance_valid(_recruit_panel):
		_recruit_panel.queue_free()
	_recruit_dim = null
	_recruit_panel = null
	_recruit_vbox = null

## Check if there are any available or active visitor quests.
func _has_visitor_quests() -> bool:
	var qm := get_tree().get_first_node_in_group("quest_manager")
	if not qm:
		return false
	if not qm.has_method("get_available_quests_for_visitor"):
		return false
	if not qm.get_available_quests_for_visitor().is_empty():
		return true
	if not qm.has_method("get_completable_quests_for_visitor"):
		return false
	if not qm.get_completable_quests_for_visitor().is_empty():
		return true
	return false

## Open the quest dialogue panel, closing the recruitment dialog first.
func _open_quest_from_recruit() -> void:
	_recruit_close()
	open_quest_dialogue()

## Open the QuestDialogueUI for visitor-specific quests.
func open_quest_dialogue() -> void:
	if _checked_in:
		return
	var dialogue_scene := preload("res://scenes/ui/QuestDialogueUI.tscn")
	if not dialogue_scene:
		return
	var dialogue := dialogue_scene.instantiate() as QuestDialogueUI
	if not dialogue:
		return
	
	var hud := get_tree().get_first_node_in_group("HUD")
	if not hud:
		var player := get_tree().get_first_node_in_group("player")
		if player:
			player.add_child(dialogue)
		else:
			get_tree().root.add_child(dialogue)
	else:
		hud.add_child(dialogue)
	
	dialogue.start_visitor_dialogue(self, _npc_display_name)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		var greeting := _get_greeting()
		show_dialogue(greeting, 2.5)

## Return a random greeting based on NPC type.
func _get_greeting() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	match npc_type:
		VisitorType.EXPLORER:
			return ["These shores are lovely!", "I've mapped half the island today!", "Every cove tells a story."][rng.randi() % 3]
		VisitorType.FISHER:
			return ["Bit quiet today... need a storm.", "Caught a glimmerfin earlier!", "Best fishing is at dawn, y'know."][rng.randi() % 3]
		VisitorType.SHOPPER:
			return ["Looking for a good deal!", "I heard the trader has rare goods.", "Always something new to buy!"][rng.randi() % 3]
		VisitorType.SIGHTSEER:
			return ["The flowers here are stunning!", "Have you seen the sunset from the hill?", "Every corner of this island is beautiful!"][rng.randi() % 3]
		VisitorType.VENDOR:
			return ["Care to see my wares?", "Fresh goods from across the sea!", "I travel far for the best merchandise."][rng.randi() % 3]
		VisitorType.ARTIST:
			return ["The light here is perfect!", "What a beautiful landscape!", "I must capture this in my sketchbook!"][rng.randi() % 3]
		VisitorType.FORAGER:
			return ["These woods are full of treasures!", "Found some rare herbs today!", "The island's bounty is incredible!"][rng.randi() % 3]
		_:
			return "Lovely day for a visit!"

func _exit_tree() -> void:
	# Clean up timers
	if wander_timer and wander_timer.is_inside_tree():
		wander_timer.stop()