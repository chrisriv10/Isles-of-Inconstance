## RuinStructure — a single ruined building in the town district.
## Handles interaction, rubble clearing animation, material contribution,
## and restoration visual update. Attached to a Sprite2D within the world.

extends Interactable
class_name RuinStructure

const Hotel = preload("res://scripts/world/building/Hotel.gd")

## Emitted when the restoration panel should be opened for this ruin
signal restoration_panel_requested(ruin_id: String, building_name: String)

## Emitted when the player interacts while in RUBBLE state
signal rubble_cleared(ruin_id: String)

@export var ruin_id: String = ""

var _ruin_def: TownManager.RuinDef = null
var _sprite: Sprite2D = null
var _world: Node2D = null
var _town_manager: TownManager = null

# Foundation outline state (blueprint-style pulsing outline)
var _show_outline: bool = false
var _pulse_phase: float = 0.0

func _ready() -> void:
	add_to_group("ruin_structures")
	
	_world = get_tree().get_first_node_in_group("world")
	_town_manager = get_tree().get_first_node_in_group("town_manager")
	
	# Get sprite (first child or self)
	_sprite = $Sprite2D if has_node("Sprite2D") else null
	
	# Physics block: the CollisionBody child (StaticBody2D) blocks player movement.
	# The root Area2D handles interaction via Interactable (the PlayerInteractor detects us).
	# The InteractionArea child detects player body overlap for naming/prompts.
	var interact_area := get_node_or_null("InteractionArea") as Area2D
	if interact_area:
		interact_area.body_entered.connect(_on_body_entered)
		interact_area.body_exited.connect(_on_body_exited)
		# Check if player is already overlapping (e.g. spawned nearby)
		for body in interact_area.get_overlapping_bodies():
			_on_body_entered(body)
	
	# Set initial visual
	_update_visual()
	
	# If this is the Hotel ruin and it's already restored (e.g. loaded from save),
	# attach the Hotel logic node so it works immediately.
	if ruin_id == "shed" and _town_manager and _town_manager.get_ruin_status(ruin_id) >= TownManager.RuinStatus.RESTORED:
		_ensure_hotel_logic()
	
	# Listen for status changes
	if _town_manager:
		_town_manager.ruin_status_changed.connect(_on_status_changed)
	
	# Pulse timer for the blueprint-style foundation outline
	var pulse_timer := Timer.new()
	pulse_timer.name = "OutlinePulseTimer"
	pulse_timer.wait_time = 0.05
	pulse_timer.autostart = false
	add_child(pulse_timer)
	pulse_timer.timeout.connect(_on_outline_pulse_tick)
	
	# Label that appears when player walks near the building
	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.visible = true
	name_label.position = Vector2(-60, -72)
	name_label.size = Vector2(120, 20)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.theme_type_variation = &"Label"
	name_label.modulate = Color(0.0, 1.0, 1.0)  # cyan text
	name_label.z_index = 100
	add_child(name_label)

	# Set initial prompt
	_update_interaction_prompt()

func initialize(p_ruin_id: String, def: TownManager.RuinDef) -> void:
	ruin_id = p_ruin_id
	_ruin_def = def
	_update_visual()
	
	# Set the name label
	var name_label := get_node_or_null("NameLabel") as Label
	if name_label and _ruin_def:
		name_label.text = _ruin_def.building_name + " (%s)" % ruin_id
	
func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		# building info available: _ruin_def.building_name, ruin_id, global_position
		# Toggle label visibility so it works like a floating label
		var name_label := get_node_or_null("NameLabel") as Label
		if name_label:
			name_label.visible = true
		
		# Show interaction prompt
		var prompt: String = _get_prompt_text()
		if not prompt.is_empty():
			var hud := get_tree().get_first_node_in_group("hud")
			if hud and hud.has_method("show_interaction_prompt"):
				hud.show_interaction_prompt(prompt)

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		var name_label := get_node_or_null("NameLabel") as Label
		if name_label:
			name_label.visible = false
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("hide_interaction_prompt"):
			hud.hide_interaction_prompt()

func _get_prompt_text() -> String:
	if not _town_manager:
		return ""
	var status: int = _town_manager.get_ruin_status(ruin_id)
	match status:
		TownManager.RuinStatus.RUBBLE:
			return "Hold [E] to Clear Rubble"
		TownManager.RuinStatus.CLEARED, TownManager.RuinStatus.RESTORING:
			return "Press [R] to contribute materials"
		TownManager.RuinStatus.RESTORED, TownManager.RuinStatus.OCCUPIED:
			# Buildings without interiors don't show an E prompt
			if ruin_id == "well":
				return "A source of fresh water"
			if ruin_id == "stable":
				return "Press [E] to Visit Stable"
			var name_str: String = _ruin_def.building_name if _ruin_def else "enter"
			return "Press [E] to Enter " + name_str
	return ""

## Override can_interact to only allow E-interaction for RESTORED/OCCUPIED
## (enter building). RUBBLE uses a hold-to-interact with progress bar
## (handled in Player.gd). CLEARED/RESTORING use the R key (repair panel).
func can_interact() -> bool:
	if not _town_manager:
		return false
	var status: int = _town_manager.get_ruin_status(ruin_id)
	return status >= TownManager.RuinStatus.RESTORED

## Interactable override — called by PlayerInteractor when player presses E.
func interact(_interactor: Node) -> void:
	on_interact()

## Called externally when the player presses E near this ruin
func on_interact() -> void:
	if not _town_manager:
		return
	var status: int = _town_manager.get_ruin_status(ruin_id)
	match status:
		TownManager.RuinStatus.RUBBLE:
			_clear_rubble()
		TownManager.RuinStatus.RESTORED, TownManager.RuinStatus.OCCUPIED:
			# Some buildings skip interior and open UI or show a toast instead
			match ruin_id:
				"stall_1", "stall_2", "general_store":
					_open_shop_ui()
				"stable":
					EffectSpawner.spawn_floating_text("*neigh!* 🐴", global_position, Color(0.9, 0.85, 0.7))
					ToastNotification.show_toast("A horse whinnies from the stable.", ToastNotification.ToastType.INFO, 2.5)
				"well":
					ToastNotification.show_toast("You draw fresh, cool water from the well.", ToastNotification.ToastType.INFO, 2.0)
				_:
					_open_npc_interaction()
		_:
			pass  # can't interact with CLEARED/RESTORING from E

## Called externally when the player presses R near this ruin
func on_repair() -> void:
	if not _town_manager:
		return
	var status: int = _town_manager.get_ruin_status(ruin_id)
	match status:
		TownManager.RuinStatus.CLEARED, TownManager.RuinStatus.RESTORING:
			restoration_panel_requested.emit(ruin_id, _ruin_def.building_name if _ruin_def else "Building")

func _clear_rubble() -> void:
	if not _town_manager or not _ruin_def:
		return
	
	# Transition from RUBBLE to CLEARED
	var state: TownManager.RuinState = _town_manager.get_ruin_state(ruin_id)
	if state and state.status == TownManager.RuinStatus.RUBBLE:
		state.status = TownManager.RuinStatus.CLEARED
		_town_manager.ruin_status_changed.emit(ruin_id, state.status)
		rubble_cleared.emit(ruin_id)
		# _update_visual() is called by the signal handler above, swapping
		# from darkened building sprite to foundation texture.
		
		ToastNotification.show_toast("Rubble cleared! Now bring materials to rebuild.", ToastNotification.ToastType.INFO, 3.0)

func _on_status_changed(p_ruin_id: String, status: int) -> void:
	if p_ruin_id != ruin_id:
		return
	_update_visual()
	_update_interaction_prompt()
	
	# When the Hotel (shed) is fully restored, attach Hotel logic so it
	# registers with VisitorManager, earns gold from visiting NPCs, and
	# the front desk inside the interior can collect earnings.
	if ruin_id == "shed" and status >= TownManager.RuinStatus.RESTORED:
		_ensure_hotel_logic()
	# Refresh the prompt if the player is still nearby (e.g. after rubble
	# clears, show "Press [R] to contribute materials" without needing to
	# walk away and come back).
	var interact_area := get_node_or_null("InteractionArea") as Area2D
	if interact_area:
		for body in interact_area.get_overlapping_bodies():
			if body.is_in_group("player"):
				var prompt: String = _get_prompt_text()
				if not prompt.is_empty():
					var hud := get_tree().get_first_node_in_group("hud")
					if hud and hud.has_method("show_interaction_prompt"):
						hud.show_interaction_prompt(prompt)
				break

## When the Hotel (shed) is restored, attach a Hotel.gd logic node so it
## (a) registers with the "hotel_buildings" group for VisitorManager,
## (b) generates gold from visiting NPCs, and
## (c) provides the interior front desk with a reference for collection.
func _ensure_hotel_logic() -> void:
	for child in get_children():
		if child is Hotel:
			return  # Already attached
	var hotel := Hotel.new()
	hotel.name = "HotelLogic"
	add_child(hotel)

func _update_interaction_prompt() -> void:
	# HUD shows "[E] <prompt>" — extract just the action verb.
	var txt: String = _get_prompt_text()
	if txt.begins_with("Hold [E] to "):
		interaction_prompt = txt.trim_prefix("Hold [E] to ")
	elif txt.begins_with("Press [E] to "):
		interaction_prompt = txt.trim_prefix("Press [E] to ")
	elif txt.begins_with("Press [R] to "):
		interaction_prompt = txt.trim_prefix("Press [R] to ")
	else:
		interaction_prompt = txt

func _update_visual() -> void:
	if not _sprite:
		return
	var status: int = _town_manager.get_ruin_status(ruin_id) if _town_manager else TownManager.RuinStatus.RUBBLE
	
	_sprite.centered = true
	
	match status:
		TownManager.RuinStatus.RUBBLE:
			_stop_outline()
			_sprite.visible = true
			_sprite.texture = _get_rubble_texture()
			_sprite.modulate = Color.WHITE
			_sprite.scale = Vector2(_get_rubble_scale(), _get_rubble_scale())
		TownManager.RuinStatus.CLEARED, TownManager.RuinStatus.RESTORING:
			# Hide the sprite and show a pulsing blueprint-style outline
			# instead of the generic small house placeholder
			_sprite.visible = false
			_start_outline()
			_sprite.scale = Vector2(SPRITE_SCALES.get(ruin_id, 1.0), SPRITE_SCALES.get(ruin_id, 1.0))
		TownManager.RuinStatus.RESTORED, TownManager.RuinStatus.OCCUPIED:
			_stop_outline()
			_sprite.visible = true
			_sprite.texture = _get_restored_texture()
			_sprite.modulate = Color.WHITE
			_sprite.scale = Vector2(SPRITE_SCALES.get(ruin_id, 1.0), SPRITE_SCALES.get(ruin_id, 1.0))
	# Use nearest-neighbor filtering for high-res sprites (stalls) to keep them crisp
	if ruin_id in ["stall_1", "stall_2"]:
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	else:
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	# Update collision shape to match the building's footprint
	_update_collision_shape()

## Dynamically sizes the collision shape to match the building footprint,
## with a margin so the player can slip past adjacent buildings.
## When showing the blueprint outline, uses the building's tile footprint.
func _update_collision_shape() -> void:
	var collision_shape := get_node_or_null("CollisionBody/CollisionShape2D") as CollisionShape2D
	if not collision_shape:
		return

	var shape_size: Vector2
	var margin := 24.0

	if _show_outline and _ruin_def:
		# Use the actual building footprint (tile count × 16px per tile)
		shape_size = Vector2(
			_ruin_def.size.x * 16.0,
			_ruin_def.size.y * 16.0
		)
	elif _sprite and _sprite.texture:
		var tex_size := _sprite.texture.get_size()
		var scale_factor := _sprite.scale.x  # uniform scale
		shape_size = Vector2(
			tex_size.x * scale_factor,
			tex_size.y * scale_factor
		)
	else:
		return

	# Shrink by margin on each side so the player can walk between
	# closely-spaced buildings without getting stuck.
	shape_size.x = maxf(16.0, shape_size.x - margin * 2.0)
	shape_size.y = maxf(16.0, shape_size.y - margin * 2.0)

	if collision_shape.shape is RectangleShape2D:
		collision_shape.shape.size = shape_size
	else:
		var new_shape := RectangleShape2D.new()
		new_shape.size = shape_size
		collision_shape.shape = new_shape

# ── Texture path tables ──────────────────────────────────────────────
const RUIN_TEX: Dictionary = {
	"small": "res://assets/generated/rubble_generic_small_frame_0.png",
	"medium": "res://assets/generated/rubble_generic_medium_frame_0.png",
	"large": "res://assets/generated/rubble_generic_large_frame_0.png",
}

const RESTORED_TEX: Dictionary = {
	"bakery": "res://assets/generated/bakery.png",
	"restaurant": "res://assets/generated/restaurant.png",
	"general_store": "res://assets/generated/store.png",
	"tavern": "res://assets/generated/tavern.png",
	"blacksmith": "res://assets/generated/blacksmith.png",
	"stable": "res://assets/generated/building_stable_european_v2_frame_0.png",
	"library": "res://assets/generated/library_96_frame_0.png",
	"cottage_1": "res://assets/generated/building_cottage_fachwerk_2_frame_0.png",
	"cottage_2": "res://assets/generated/building_cottage_fachwerk_2_frame_0.png",
	"shed": "res://assets/generated/building_hotel_frame_0.png",
	"workbench": "res://assets/generated/building_general_store_fachwerk_v3_frame_0.png",
	"well": "res://assets/generated/building_town_well_fachwerk_4_frame_0.png",
	"stall_1": "res://assets/generated/stall1.png",
	"stall_2": "res://assets/generated/stall2.png",
	"gate": "res://assets/generated/bank_v4_large_frame_0.png",
}

const FALLBACK_TEX: String = "res://assets/generated/building_small_home_frame_0.png"

## Per-building sprite scale — ALL buildings are consistently sized so the
## player (8px wide in world space) has room to walk between them.
## 96×96 sprites → 0.75 (~72px ≈ 4.5 tiles); 192×192 bank → 0.375.
## 64×64 stable → 1.125 (~72px); 128×112 shed → 0.6 (~72px).
## Stalls are 782×782 → 0.09 (~70px).
const SPRITE_SCALES: Dictionary = {
	"bakery": 0.75,
	"tavern": 1.0,
	"blacksmith": 1.0,
	"restaurant": 1.0,
	"general_store": 1.0,
	"stable": 1.125,
	"library": 0.75,
	"well": 0.75,
	"workbench": 0.75,
	"cottage_1": 0.75,
	"cottage_2": 0.75,
	"gate": 0.375,
	"shed": 0.6,
	"stall_1": 0.09,
	"stall_2": 0.09,
}

# ── Size-based ruin category ─────────────────────────────────────────
func _get_ruin_category() -> String:
	if not _ruin_def:
		return "medium"
	var area: int = _ruin_def.size.x * _ruin_def.size.y
	if area <= 4:
		return "small"
	elif area <= 9:
		return "medium"
	else:
		return "large"

func _get_rubble_scale() -> float:
	if not _ruin_def:
		return 1.0
	var tex := _get_rubble_texture()
	if not tex:
		return 1.0
	var tex_w: float = tex.get_width()
	if tex_w <= 0:
		return 1.0
	# Target: the rubble should fill the building's tile footprint width
	var target_width: float = _ruin_def.size.x * 16.0
	# Scale to fill the width, with 1.2x oversize for visual heft
	return (target_width / tex_w) * 1.2

func _get_rubble_texture() -> Texture2D:
	var category: String = _get_ruin_category()
	var tex_path: String = RUIN_TEX.get(category, "res://assets/generated/rubble_generic_medium_frame_0.png")
	return load(tex_path) as Texture2D

# _get_foundation_texture removed — foundations now use the blueprint outline instead

func _get_restored_texture() -> Texture2D:
	if not _ruin_def:
		return null
	var tex_path: String = RESTORED_TEX.get(ruin_id, FALLBACK_TEX)
	return load(tex_path) as Texture2D

func _open_npc_interaction() -> void:
	# Enter a generated interior using the existing BuildingInterior system.
	# Map ruin role to an interior type.
	if not _ruin_def or not _world:
		ToastNotification.show_toast("You visit the %s." % [_ruin_def.building_name if _ruin_def else "Building"], ToastNotification.ToastType.INFO, 2.0)
		return
	
	# Map ruin role to BuildingInterior.InteriorType
	var role_map := {
		"villager": BuildingInterior.InteriorType.SMALL_HOME,
		"baker": BuildingInterior.InteriorType.BAKERY,
		"chef": BuildingInterior.InteriorType.RESTAURANT,
		"innkeeper": BuildingInterior.InteriorType.TAVERN,
		"blacksmith": BuildingInterior.InteriorType.BLACKSMITH,
		"shopkeep": BuildingInterior.InteriorType.GENERAL_STORE,
		"scholar": BuildingInterior.InteriorType.LIBRARY,
		"stablehand": BuildingInterior.InteriorType.STABLE,
	}
	# Special cases: named ruins get unique interior types
	var interior_type: int
	if ruin_id == "gate":
		interior_type = BuildingInterior.InteriorType.BANK
	elif ruin_id == "shed":
		interior_type = BuildingInterior.InteriorType.HOTEL
	elif ruin_id == "workbench":
		interior_type = BuildingInterior.InteriorType.TOWN_HALL
	else:
		interior_type = role_map.get(_ruin_def.npc_role, BuildingInterior.InteriorType.SMALL_HOME)
	
	var interior := BuildingInterior.new()
	interior.setup(interior_type, Vector2i.ZERO)
	
	# For the Hotel ruin, pass the Hotel.gd reference so the interior's
	# front desk interactable can collect gold from visiting NPCs.
	if ruin_id == "shed":
		for child in get_children():
			if child is Hotel:
				interior.set_hotel_reference(child as Hotel)
				break
	
	# Pass resident info so the actual recruited NPC appears inside
	if _town_manager:
		for rid: String in _town_manager.residents:
			var rd = _town_manager.residents[rid] as TownManager.ResidentData
			if rd and rd.home_ruin_id == ruin_id:
				interior.set_resident_info(rd.npc_name, rd.visitor_type)
				break
	
	_world.enter_building(interior)

## Opens the Shop UI directly, used by vendor stalls instead of an interior.
func _open_shop_ui() -> void:
	var shop_ui: CanvasLayer = get_tree().get_first_node_in_group("shop_ui")
	if shop_ui and shop_ui.has_method("open"):
		shop_ui.open()
	else:
		push_warning("RuinStructure: shop_ui not found in 'shop_ui' group")

# ── Blueprint-style foundation outline ──────────────────────────────
## Matches the building mode preview visual (pulsing blue outline)
const OUTLINE_COLOR: Color = Color(0.2, 0.5, 1.0)
const OUTLINE_WIDTH: float = 2.0
const CELL_SIZE: int = 16

func _start_outline() -> void:
	_show_outline = true
	_pulse_phase = 0.0
	# Raise z_index so the outline renders above ground sprites (plaza, etc.)
	z_index = 10
	var timer := get_node_or_null("OutlinePulseTimer") as Timer
	if timer:
		timer.stop()
		timer.start()
	queue_redraw()

func _stop_outline() -> void:
	_show_outline = false
	z_index = 0
	var timer := get_node_or_null("OutlinePulseTimer") as Timer
	if timer:
		timer.stop()
	queue_redraw()

func _on_outline_pulse_tick() -> void:
	if _show_outline and _ruin_def:
		_pulse_phase += 0.2
		queue_redraw()

func _draw() -> void:
	if not _show_outline or not _ruin_def:
		return
	
	# Pulse alpha between 0.30 and 0.80, matching the build mode preview style
	var alpha: float = 0.55 + sin(_pulse_phase) * 0.25
	var color := Color(OUTLINE_COLOR, alpha)
	
	# Draw a single rectangle matching the building's full footprint
	var footprint_w: float = _ruin_def.size.x * CELL_SIZE
	var footprint_h: float = _ruin_def.size.y * CELL_SIZE
	var rect := Rect2(-footprint_w / 2.0, -footprint_h / 2.0, footprint_w, footprint_h)
	draw_rect(rect, color, false, OUTLINE_WIDTH)
