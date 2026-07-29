extends Node2D

## Entry point for the game scene. Deliberately thin: it only wires together
## the already-independent World, Player, and HUD nodes. Add new top-level
## systems (weather, NPC manager, save/load trigger, etc.) here as siblings
## rather than growing this script into a monolith.

@onready var world: Node2D = $World
@onready var player: CharacterBody2D = $Player
@onready var hud: CanvasLayer = $HUD
@onready var creative_panel: CanvasLayer = $CreativePanel
@onready var weather_fx: WeatherFXManager = null
var objectives_panel: CanvasLayer = null

## Tracks whether any UI panel was visible during the previous frame.
## Used by the Escape-to-open-menu logic to avoid reopening the menu
## immediately after the user closes a UI panel with Escape.
var _ui_was_open_last_frame: bool = false

# Edge-detection for R key when a LineEdit (creative panel search) has focus,
# since GUI-consumed events never reach _input() / _unhandled_input().
var _prev_r_pressed: bool = false

func _ready() -> void:
	# Create weather visual effects overlay (rain, lightning, fog)
	weather_fx = WeatherFXManager.new()
	weather_fx.name = "WeatherFX"
	add_child(weather_fx)
	
	# Create world map overlay programmatically (avoids scene file persistence issues)
	var wm_scene := preload("res://scenes/ui/WorldMap.tscn")
	var world_map_node: CanvasLayer = wm_scene.instantiate()
	world_map_node.name = "WorldMap"
	add_child(world_map_node)
	
	# Create objectives panel programmatically (same reason: scene file persistence)
	var op_scene := preload("res://scenes/ui/ObjectivesPanel.tscn")
	var op_node: CanvasLayer = op_scene.instantiate()
	op_node.name = "ObjectivesPanel"
	add_child(op_node)
	objectives_panel = op_node

	_position_player_at_spawn()
	
	if hud and hud.has_method("set_seed_display"):
		hud.set_seed_display(world.world_seed)
	
	# Set up groups for system discovery
	var crafting_ui := $CraftingUI
	if crafting_ui:
		crafting_ui.add_to_group("crafting_ui")
	
	var encyclopedia := $EncyclopediaUI
	if encyclopedia:
		encyclopedia.add_to_group("encyclopedia")
	
	var cooking_ui := $CookingUI
	if cooking_ui:
		cooking_ui.add_to_group("cooking_ui")
	
	var hud_instance := $HUD
	if hud_instance:
		hud_instance.add_to_group("hud")
	
	var shop_ui := $ShopUI
	if shop_ui:
		shop_ui.add_to_group("shop_ui")
	
	var world_map := $WorldMap
	if world_map:
		world_map.add_to_group("world_map")

	var sell_ui := $SellUI
	if sell_ui:
		sell_ui.add_to_group("sell_ui")
	
	var chest_ui := $ChestStorageUI
	if chest_ui:
		chest_ui.add_to_group("chest_storage_ui")
	
	var pet_ui := $PetUI
	if pet_ui:
		pet_ui.add_to_group("pet_ui")
	
	var farming_ui := $FarmingUI
	if farming_ui:
		farming_ui.add_to_group("farming_ui")
	
	var town_ui := $TownUI
	if town_ui:
		town_ui.add_to_group("town_ui")
	
	var restoration_panel := $RestorationPanelLayer/RestorationPanel
	if restoration_panel:
		restoration_panel.add_to_group("restoration_panel")
		if restoration_panel.has_signal("panel_closed"):
			restoration_panel.panel_closed.connect(_on_restoration_closed)
	
	# Connect to town manager for resident recruitment toasts
	var town_mgr := get_tree().get_first_node_in_group("town_manager")
	if town_mgr:
		if town_mgr.has_signal("resident_moved_in"):
			town_mgr.resident_moved_in.connect(_on_resident_moved_in)
		if town_mgr.has_signal("building_restored"):
			town_mgr.building_restored.connect(_on_building_restored)
	
	# Instantiate town building backend systems (exist as code but never created)
	var library_research := LibraryResearch.new()
	library_research.name = "LibraryResearch"
	add_child(library_research)
	var restaurant_system := RestaurantSystem.new()
	restaurant_system.name = "RestaurantSystem"
	add_child(restaurant_system)
	var resident_recruiter := ResidentRecruiter.new()
	resident_recruiter.name = "ResidentRecruiter"
	add_child(resident_recruiter)
	
	# Spawn the active pet if one is equipped
	_spawn_active_pet()
	
	# Listen for pet-equip changes
	PetManager.active_pet_changed.connect(_on_pet_changed)
	
	# Collections UI
	var collections_ui := $CollectionsUI
	if collections_ui:
		collections_ui.add_to_group("collections_ui")

	# Ensure collections input action exists at runtime
	if not InputMap.has_action("open_collections"):
		InputMap.add_action("open_collections")
		var col_ev := InputEventKey.new()
		col_ev.physical_keycode = KEY_L
		InputMap.action_add_event("open_collections", col_ev)

	# ObjectivesPanel self-registers in its own _ready()


## Tracks UI visibility each frame so the Escape-to-open-menu logic
## can distinguish "user pressed Escape with nothing open" from
## "user pressed Escape to close a UI panel."
func _process(_delta: float) -> void:
	_ui_was_open_last_frame = _is_any_ui_open()
	_check_r_key()


## Returns true if any non-HUD UI panel is currently visible.
func _is_any_ui_open() -> bool:
	var panels: Array[Node] = [
		$ShopUI, $InventoryUI, $CraftingUI, $SellUI,
		$EncyclopediaUI, $CookingUI, $ChestStorageUI,
		$PetUI, $FarmingUI, $TownUI, $RestorationPanelLayer/RestorationPanel,
		$CollectionsUI, $WorldMap
	]
	for panel in panels:
		if panel is CanvasLayer and panel.visible:
			return true
	if creative_panel and creative_panel.is_open():
		return true
	if objectives_panel and objectives_panel.is_open():
		return true
	return false


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var keycode: Key = event.keycode

		# Don't process keyboard shortcuts when typing in a text input field.
		# This prevents letters/numbers typed into search bars or other LineEdits
		# from accidentally opening menus or triggering item shortcuts.
		var focus_owner: Control = get_viewport().gui_get_focus_owner()
		var is_typing_in_text_input: bool = focus_owner is LineEdit or focus_owner is TextEdit
		if is_typing_in_text_input:
			# Still allow Escape (to close panels) and backtick (to toggle creative)
			# so they work even when a search bar has focus.
			# R is handled by _check_r_key() in _process() as a raw-key fallback.
			if keycode != KEY_ESCAPE and keycode != KEY_QUOTELEFT and event.physical_keycode != KEY_QUOTELEFT:
				return

		if keycode == KEY_QUOTELEFT or event.physical_keycode == KEY_QUOTELEFT:
			if GameManager.is_creative() and creative_panel:
				creative_panel.toggle()
				get_viewport().set_input_as_handled()
				return
		# Creative panel item shortcuts: 1-9 to spawn, Escape to close
		if creative_panel and creative_panel.is_open():
			if keycode >= KEY_1 and keycode <= KEY_9:
				creative_panel.spawn_item_by_index(keycode - KEY_1)
				get_viewport().set_input_as_handled()
				return
			elif keycode == KEY_ESCAPE:
				creative_panel.close()
				get_viewport().set_input_as_handled()
				return
		# Escape closes objectives panel if open
		if keycode == KEY_ESCAPE and objectives_panel and objectives_panel.is_open():
			objectives_panel.close()
			get_viewport().set_input_as_handled()
			return

		# Escape open in-game menu if no other UI is visible.
		# The _ui_was_open_last_frame check prevents immediately re-opening
		# the menu after the user pressed Escape to close a panel.
		if keycode == KEY_ESCAPE and not _ui_was_open_last_frame:
			if hud and hud.has_method("open_ingame_menu"):
				hud.open_ingame_menu()
				get_viewport().set_input_as_handled()
				return

		# O key toggles objectives panel (any mode)
		if keycode == KEY_O:
			if objectives_panel and objectives_panel.has_method("toggle"):
				objectives_panel.toggle()
			get_viewport().set_input_as_handled()
			return

		# L key toggles collections UI (item completion log)
		if keycode == KEY_L:
			var collections_ui := $CollectionsUI
			if collections_ui and collections_ui.has_method("toggle"):
				collections_ui.toggle()
			get_viewport().set_input_as_handled()
			return

		# P key toggles pet UI
		if keycode == KEY_P:
			var pet_ui_node := $PetUI
			if pet_ui_node and pet_ui_node.has_method("toggle"):
				pet_ui_node.toggle()
			get_viewport().set_input_as_handled()
			return

		# G key toggles farming overview
		if keycode == KEY_G:
			var farming_ui := $FarmingUI
			if farming_ui and farming_ui.has_method("toggle"):
				farming_ui.toggle()
			get_viewport().set_input_as_handled()
			return

		# M key toggles world map
		if keycode == KEY_M:
			var wm: CanvasLayer = $WorldMap
			if wm and wm.has_method("toggle"):
				wm.toggle()
			get_viewport().set_input_as_handled()
			return
		
		# N key toggles town overview
		if keycode == KEY_N:
			var town_ui_node := $TownUI
			if town_ui_node and town_ui_node.has_method("toggle"):
				town_ui_node.toggle()
			get_viewport().set_input_as_handled()
			return
		
		# R key near ruins: open restoration panel
		if keycode == KEY_R:
			_try_open_restoration_panel()
			get_viewport().set_input_as_handled()
			return

	# Mouse click routing for CreativePanel
	# With mouse_filter = PASS on the root Control, Godot's GUI system handles
	# all children (buttons, scrollbar, tabs) normally, so no manual routing needed.

func _position_player_at_spawn() -> void:
	if world and world.has_method("cell_to_world"):
		var spawn_cell := Vector2i(world.world_width / 2, world.world_height / 2)
		player.global_position = world.cell_to_world(spawn_cell)

# --------------------------------------------------------------------------
# Pet spawning
# --------------------------------------------------------------------------

## The current pet scene instance (or null).
var _pet_instance: Node2D = null

## Spawn the active pet (if any) as a child of the player.
func _spawn_active_pet() -> void:
	# Remove any existing pet instance
	_despawn_pet()
	
	var pet_id := PetManager.active_pet_id
	if pet_id.is_empty():
		return
	if not PetManager.has_pet(pet_id):
		return
	
	var pet_scene := preload("res://scenes/Pet.tscn")
	var pet: Node2D = pet_scene.instantiate()
	pet.name = "ActivePet"
	player.add_child(pet)
	if not pet.setup(pet_id, player):
		# setup failed (invalid pet) — pet.queue_free() was called internally
		_pet_instance = null
		return
	_pet_instance = pet

func _despawn_pet() -> void:
	if _pet_instance and is_instance_valid(_pet_instance):
		_pet_instance.queue_free()
		_pet_instance = null

func _on_pet_changed(_pet_id: String) -> void:
	_spawn_active_pet()

## Find the nearest ruin structure within max_distance pixels of the player.
func _get_nearest_ruin(max_distance: float) -> RuinStructure:
	var player: Node2D = $Player
	if not player:
		return null
	var ruins := get_tree().get_nodes_in_group("ruin_structures")
	var nearest: RuinStructure = null
	var nearest_dist: float = max_distance
	for r in ruins:
		var ruin := r as RuinStructure
		if not ruin:
			continue
		var dist: float = player.global_position.distance_squared_to(ruin.global_position)
		if dist < nearest_dist * nearest_dist:
			nearest_dist = sqrt(dist)
			nearest = ruin
	return nearest

## Called when the restoration panel is closed
func _on_restoration_closed() -> void:
	# Re-enable player input, etc.
	pass

func _on_resident_moved_in(_npc_id: String, npc_name: String) -> void:
	ToastNotification.show_toast(
		"%s has moved into town!" % [npc_name],
		ToastNotification.ToastType.SUCCESS,
		5.0
	)
	# Notify objective manager
	var om := get_tree().get_first_node_in_group("objective_manager")
	if om and om.has_method("on_resident_recruited"):
		var tm := get_tree().get_first_node_in_group("town_manager")
		var count: int = tm.get_resident_count() if tm else 1
		om.on_resident_recruited(count)

func _on_building_restored(ruin_id: String, building_name: String) -> void:
	ToastNotification.show_toast(
		"%s has been fully restored!" % [building_name],
		ToastNotification.ToastType.SUCCESS,
		5.0
	)
	# Add reputation
	var tm := get_tree().get_first_node_in_group("town_manager")
	if tm and tm.has_method("add_reputation"):
		tm.add_reputation(50)


# ── R key fallback for LineEdit focus ──────────────────────────────────
# When a LineEdit (e.g. creative panel's SearchInput) has focus, Godot's GUI
# consumes keyboard events and neither _input() nor _unhandled_input() fires.
# This edge-detection fallback in _process catches R presses directly.

func _check_r_key() -> void:
	var focus_owner := get_viewport().gui_get_focus_owner()
	if not (focus_owner is LineEdit or focus_owner is TextEdit):
		_prev_r_pressed = false
		return
	var r_pressed: bool = Input.is_key_pressed(KEY_R)
	if r_pressed and not _prev_r_pressed:
		_try_open_restoration_panel()
	_prev_r_pressed = r_pressed

func _try_open_restoration_panel() -> void:
	var ruin := _get_nearest_ruin(180.0)
	if not ruin or not ruin.has_method("on_repair"):
		return
	ruin.on_repair()
	var town_manager := get_tree().get_first_node_in_group("town_manager")
	if not town_manager:
		return
	var status: int = town_manager.get_ruin_status(ruin.ruin_id)
	if status != TownManager.RuinStatus.CLEARED and status != TownManager.RuinStatus.RESTORING:
		return
	var panel := $RestorationPanelLayer/RestorationPanel
	if not panel or not panel.has_method("open"):
		return
	var def: TownManager.RuinDef = town_manager.get_ruin_def(ruin.ruin_id)
	var name_str: String = def.building_name if def else "Building"
	panel.open(ruin.ruin_id, name_str)
