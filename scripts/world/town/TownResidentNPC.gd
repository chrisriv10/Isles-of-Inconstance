## TownResidentNPC — a permanent NPC that lives in a restored building.
## Has a daily schedule (emerge, go to post, wander town, sleep),
## dialogue, and offers services. Extends the visual style of VisitorNPC.

extends Area2D
class_name TownResidentNPC

## NPC roles
enum Role {
	VILLAGER,     # generic resident
	BAKER,        # runs the bakery
	CHEF,         # runs the restaurant
	INNKEEPER,    # runs the tavern
	BLACKSMITH,   # runs the forge
	SHOPKEEP,     # runs the general store
	SCHOLAR,      # runs the library
	STABLEHAND,   # runs the stable
}

signal service_requested(npc_id: String, role: int)

## Unique ID for this NPC
var npc_id: String = ""
## Display name
var npc_name: String = "Resident"
## NPC role
var role: int = Role.VILLAGER
## The ruin this NPC occupies
var home_ruin_id: String = ""
## Schedule: position at each time of day
var home_position: Vector2 = Vector2.ZERO
var post_position: Vector2 = Vector2.ZERO  # where they serve (e.g., bakery counter)

## The original VisitorNPC.VisitorType this resident was recruited from.
## Used to look up the correct NPC texture for the interior.
var visitor_type: int = 0

## Movement speed in px/sec
var speed: float = 38.0

var _sprite: Sprite2D = null
var _label: Label = null
var _dialogue_bubble: Node2D = null
var _dialogue_label: Label = null
var _is_wandering: bool = false
var _target_pos: Vector2 = Vector2.ZERO
var _idle_timer: float = 0.0
var _current_schedule: String = "home"  # home, post, wander, sleep, inside

## Ruin IDs of buildings that have NO interior scene.
## Residents assigned to these buildings never go "inside" — they wander always.
const NO_INTERIOR_RUIN_IDS: Array[String] = [
	"stall_1", "stall_2", "general_store", "stable", "well"
]

## Whether this resident's building has a navigable interior.
## If false, "inside"/"sleep"/"home" states are replaced with "wander".
var _has_interior: bool = true

## Public check: is this resident currently inside their building
## (invisible and not available outdoors)? Returns true for "inside",
## "sleep", and any state where they should appear in the interior view.
func is_inside_building() -> bool:
	if not _has_interior:
		return false
	return _current_schedule == "inside" or _current_schedule == "sleep"

var _world: Node2D = null

## Idle bob animation state
var _bob_offset: float = 0.0
var _bob_direction: int = 1
var _idle_at_post: bool = false

func _ready() -> void:
	add_to_group("town_residents")
	_world = get_tree().get_first_node_in_group("world")
	
	_sprite = $Sprite2D if has_node("Sprite2D") else null
	_label = $Label if has_node("Label") else null
	
	# Set texture — use player sprite so they're always visible
	_sprite_modulate_for_role()
	
	# Interaction
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	_setup_dialogue()
	
	# Set name label text (initialize() was called before _ready(), so
	# _label was null when npc_name was assigned there)
	if _label:
		_label.text = npc_name
	
	# Start schedule — begin invisible inside the building (if it has one),
	# otherwise start visible and wandering.
	if _has_interior:
		_current_schedule = "inside"
		visible = false
	else:
		_current_schedule = "wander"
		visible = true
		monitoring = true
	_update_schedule()

## Apply NPC texture with role-specific color tint so residents are visible.
func _sprite_modulate_for_role() -> void:
	if not _sprite:
		return
	# Pick a random NPC texture variant for variety
	var rng := RandomNumberGenerator.new()
	var npc_variant: int = rng.randi() % 5  # pick from first 5 common types
	match npc_variant:
		0:
			var tex := load("res://assets/generated/npc_explorer_frame_0.png") 
			if tex: _sprite.texture = tex
		1:
			var tex := load("res://assets/generated/npc_explorer_b_frame_0.png")
			if tex: _sprite.texture = tex
		2:
			var tex := load("res://assets/generated/npc_vendor_frame_0.png")
			if tex: _sprite.texture = tex
		3:
			var tex := load("res://assets/generated/npc_vendor_b_frame_0.png")
			if tex: _sprite.texture = tex
		_:
			var tex := load("res://assets/generated/npc_sightseer_frame_0.png")
			if tex: _sprite.texture = tex
	if not _sprite.texture:
		_sprite.texture = load("res://assets/sprites/player.png")
	# Tint by role for visual variety
	match role:
		Role.VILLAGER:
			_sprite.modulate = Color(0.7, 0.85, 1.0)  # light blue
		Role.BAKER:
			_sprite.modulate = Color(1.0, 0.85, 0.6)  # warm tan
		Role.CHEF:
			_sprite.modulate = Color(1.0, 0.95, 0.75) # cream
		Role.INNKEEPER:
			_sprite.modulate = Color(0.75, 0.55, 0.35) # brown
		Role.BLACKSMITH:
			_sprite.modulate = Color(0.6, 0.6, 0.6)   # grey
		Role.SHOPKEEP:
			_sprite.modulate = Color(0.7, 1.0, 0.7)   # light green
		Role.SCHOLAR:
			_sprite.modulate = Color(0.75, 0.6, 1.0)  # lavender
		Role.STABLEHAND:
			_sprite.modulate = Color(0.55, 0.45, 0.35) # earthy

func initialize(p_id: String, p_name: String, p_role: int, p_home_id: String, p_home_pos: Vector2, p_post_pos: Vector2, p_visitor_type: int = -1) -> void:
	npc_id = p_id
	npc_name = p_name
	role = p_role
	home_ruin_id = p_home_id
	home_position = p_home_pos
	post_position = p_post_pos
	visitor_type = p_visitor_type
	_has_interior = not (home_ruin_id in NO_INTERIOR_RUIN_IDS)
	
	if _label:
		_label.text = npc_name

func _setup_dialogue() -> void:
	_dialogue_bubble = Node2D.new()
	_dialogue_bubble.name = "DialogueBubble"
	_dialogue_bubble.position = Vector2(0, -18)
	# Draw above building sprites (z=0) and the NPC sprite (z=3) so the
	# bubble never gets cut off behind town buildings.
	_dialogue_bubble.z_index = 5
	_dialogue_bubble.visible = false
	
	_dialogue_label = Label.new()
	_dialogue_label.name = "DialogueLabel"
	_dialogue_label.size = Vector2(100, 18)
	_dialogue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dialogue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_dialogue_label.add_theme_font_size_override("font_size", 7)
	
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.15, 0.85)
	sb.border_color = Color(0.6, 1.0, 0.6, 0.8)
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

func _process(delta: float) -> void:
	_update_schedule()
	
	match _current_schedule:
		"inside":
			# Invisible, at home, not moving
			visible = false
			_idle_at_post = false
			if _sprite:
				_sprite.position.y = 0.0
		"home":
			_move_toward(home_position, delta * 1.2)
			_idle_at_post = false
			# Once arrived, transition to inside
			if _has_arrived(home_position, 12.0):
				_switch_to("inside")
		"post":
			if _has_arrived(post_position, 16.0):
				_idle_at_post = true
				_bob_offset += delta * 1.5 * _bob_direction
				if abs(_bob_offset) > 2.0:
					_bob_direction *= -1
				if _sprite:
					_sprite.position.y = _bob_offset
					_sprite.flip_h = false
			else:
				_idle_at_post = false
				if _sprite:
					_sprite.position.y = 0.0
				_move_toward(post_position, delta)
		"wander":
			_idle_at_post = false
			if _sprite:
				_sprite.position.y = 0.0
			_wander_update(delta)
		"sleep":
			_idle_at_post = false
			if _sprite:
				_sprite.position.y = 0.0
			_move_toward(home_position, delta * 1.5)
			if _has_arrived(home_position, 12.0):
				_switch_to("inside")

func _update_schedule() -> void:
	if not GameManager.day_night:
		return
	var hour: int = GameManager.get_hour()
	
	# Day-night cycle schedule for natural inside/outside rhythm:
	# 6:00-8:00   — inside (waking up, invisible)
	# 8:00-10:00  — wander (come outside, wander near home)
	# 10:00-12:00 — inside (back inside doing chores)
	# 12:00-14:00 — post (at workplace offering services)
	# 14:00-15:00 — inside (afternoon break)
	# 15:00-17:00 — wander (wander town)
	# 17:00-18:00 — inside (back home)
	# 18:00-20:00 — wander (evening stroll)
	# 20:00-21:00 — home (heading inside for the night)
	# 21:00-6:00  — inside (sleeping, invisible)
	
	if hour >= 21 or hour < 6:
		_switch_to("sleep" if _has_interior else "wander")
	elif hour >= 6 and hour < 8:
		_switch_to("inside" if _has_interior else "wander")
	elif hour >= 8 and hour < 10:
		_switch_to("wander")
	elif hour >= 10 and hour < 12:
		_switch_to("inside" if _has_interior else "wander")
	elif hour >= 12 and hour < 14:
		_switch_to("post" if _has_interior else "wander")
	elif hour >= 14 and hour < 15:
		_switch_to("inside" if _has_interior else "wander")
	elif hour >= 15 and hour < 17:
		_switch_to("wander")
	elif hour >= 17 and hour < 18:
		_switch_to("inside" if _has_interior else "wander")
	elif hour >= 18 and hour < 20:
		_switch_to("wander")
	else:
		# 20-21 — head home, then go inside
		_switch_to("home" if _has_interior else "wander")


## Switch schedule and handle visibility transitions.
func _switch_to(new_schedule: String) -> void:
	if _current_schedule == new_schedule:
		return
	
	var prev: String = _current_schedule
	_current_schedule = new_schedule
	
	if new_schedule == "inside" or new_schedule == "sleep":
		# Going inside/sleep — become invisible, disable interaction, teleport home
		visible = false
		monitoring = false
		_is_wandering = false
		global_position = home_position
		if _sprite:
			_sprite.position.y = 0.0
	elif prev == "inside" or prev == "sleep":
		# Coming out from inside — appear at home, enable interaction, become visible
		visible = true
		monitoring = true
		global_position = home_position
		_is_wandering = false
	else:
		# Transitioning between outside states (wander/post/home) — stay visible
		visible = true
		monitoring = true
		# Don't teleport — let them walk naturally

func _move_toward(target: Vector2, delta: float) -> void:
	var dir := (target - global_position).normalized()
	if global_position.distance_squared_to(target) > 16.0:
		var step: Vector2 = dir * speed * delta
		var new_pos: Vector2 = global_position + step
		# Check if the new position is clear (same walls that block the player)
		if _can_move_to(new_pos):
			global_position = new_pos
			if _sprite:
				_sprite.flip_h = dir.x < -0.1
		else:
			# Blocked — try moving on each axis separately (wall sliding)
			var slide_x: Vector2 = Vector2(step.x, 0)
			if _can_move_to(global_position + slide_x):
				global_position.x += slide_x.x
				if _sprite:
					_sprite.flip_h = dir.x < -0.1
			var slide_y: Vector2 = Vector2(0, step.y)
			if _can_move_to(global_position + slide_y):
				global_position.y += slide_y.y
	else:
		# At target, face toward center
		if _sprite:
			_sprite.flip_h = false

## Check if a position is free of walls/building blockers (same layers as player uses).
func _can_move_to(pos: Vector2) -> bool:
	var shape_owner := $CollisionShape2D
	if not shape_owner or not shape_owner.shape:
		return true
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape_owner.shape
	query.transform = Transform2D(0.0, pos)
	query.collision_mask = 1 | 8  # layer 1 = walls/terrain, layer 8 = building blockers
	return space_state.intersect_shape(query, 1).is_empty()

func _has_arrived(target: Vector2, threshold: float) -> bool:
	return global_position.distance_squared_to(target) < threshold * threshold

# Wander logic (similar to VisitorNPC)
var _wander_timer: float = 0.0

func _wander_update(delta: float) -> void:
	if not _is_wandering:
		_pick_wander_target()
		_is_wandering = true
	
	if _target_pos == Vector2.ZERO:
		return
	
	var dist_sq := global_position.distance_squared_to(_target_pos)
	if dist_sq > 64.0:
		_move_toward(_target_pos, delta)
	else:
		_wander_timer -= delta
		if _wander_timer <= 0.0:
			_pick_wander_target()

func _pick_wander_target() -> void:
	if not _world or not _world.has_method("is_cell_walkable"):
		# Fallback: wander within a few tiles of home (same range as town wander below)
		_target_pos = home_position + Vector2(randf_range(-64, 64), randf_range(-48, 48))
		_wander_timer = 2.0 + randf() * 2.0
		return
	
	# Wander throughout the town district (wide range)
	for _attempt in 30:
		var offset := Vector2(randf_range(-300, 300), randf_range(-200, 200))
		var candidate := home_position + offset
		var cell := Vector2i(int(candidate.x / 16), int(candidate.y / 16))
		if _world.has_method("_is_in_bounds") and _world._is_in_bounds(cell):
			if _world.is_cell_walkable(candidate):
				# Check not too close to current position
				if _is_wandering and candidate.distance_squared_to(global_position) < 400.0:
					continue
				_target_pos = candidate
				_wander_timer = 2.0 + randf() * 2.0
				return
	
	# No walkable cell found — pick a nearby spot so they still move around
	_target_pos = home_position + Vector2(randf_range(-48, 48), randf_range(-48, 48))
	_wander_timer = 2.0 + randf() * 2.0

# Interaction — _on_body_entered / _on_body_exited are defined below (after open_quest_dialogue)

func show_dialogue(msg: String, duration: float = 2.0) -> void:
	if not _dialogue_bubble or not _dialogue_label:
		return
	_dialogue_label.text = msg
	_dialogue_bubble.visible = true
	get_tree().create_timer(duration).timeout.connect(func():
		if is_instance_valid(_dialogue_bubble):
			_dialogue_bubble.visible = false
	)

func _get_greeting() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	match role:
		Role.VILLAGER:
			return ["Hello, neighbor!", "The town is looking lovely!", "Glad we settled here."][rng.randi() % 3]
		Role.BAKER:
			return ["Fresh bread just out of the oven!", "Want to try your hand at baking?", "I've got a new recipe to try."][rng.randi() % 3]
		Role.CHEF:
			return ["Your crops have been wonderful!", "Got any new ingredients for me?", "The daily special is ready!"][rng.randi() % 3]
		Role.INNKEEPER:
			return ["Welcome to the tavern!", "Try today's special brew!", "Pull up a chair and rest."][rng.randi() % 3]
		Role.BLACKSMITH:
			return ["Need your tools sharpened?", "I can forge something strong for you.", "Got any rare ore?"][rng.randi() % 3]
		Role.SHOPKEEP:
			return ["New stock just arrived!", "Always a pleasure.", "See anything you like?"][rng.randi() % 3]
		Role.SCHOLAR:
			return ["I found a fascinating book!", "Knowledge is the greatest treasure.", "Care to learn something new?"][rng.randi() % 3]
		Role.STABLEHAND:
			return ["The horses are well-fed today.", "Want to go for a ride?", "I've been training a new foal."][rng.randi() % 3]
	return "Hello!"

## Track whether the player is in range for interaction
var _player_in_range: bool = false

## Open the full quest dialogue panel for this NPC
func open_quest_dialogue() -> void:
	if not _player_in_range:
		return
	
	# Check if we're at the post (service hours) — emit service signal too
	if _current_schedule == "post":
		service_requested.emit(npc_id, role)
	
	# Open the quest dialogue UI
	var dialogue_scene := preload("res://scenes/ui/QuestDialogueUI.tscn")
	if not dialogue_scene:
		return
	var dialogue := dialogue_scene.instantiate() as QuestDialogueUI
	if not dialogue:
		return
	
	var hud := get_tree().get_first_node_in_group("HUD")
	if not hud:
		# Add to player as fallback
		var player := get_tree().get_first_node_in_group("player")
		if player:
			player.add_child(dialogue)
		else:
			# Last resort — add to root viewport
			get_tree().root.add_child(dialogue)
	else:
		hud.add_child(dialogue)
	
	dialogue.start_dialogue(self, npc_name, role)

## Handle quest-related interaction on body_entered (E key press while nearby)
## Override: instead of just saying a greeting bubble, we also allow the
## player to press E to open the full quest dialogue panel.
func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		var greeting := _get_greeting()
		show_dialogue(greeting, 2.5)

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
		if _dialogue_bubble:
			_dialogue_bubble.visible = false
