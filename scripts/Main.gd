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

# ── Multiplayer remote player tracking ──
# Maps peer_id → Player node (both local and remote players).
var _remote_players: Dictionary = {}

# World sync state
var _world_generated: bool = false
var _pending_seed_peers: Array[int] = []
var _mp_setup_done: bool = false

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

	# Multiplayer setup
	NetworkManager.connection_succeeded.connect(_on_network_session_started)
	NetworkManager.peer_connected.connect(_on_peer_connected)
	NetworkManager.peer_disconnected.connect(_on_peer_disconnected)
	_setup_multiplayer()


## Called when a network session starts (host or client) after Main was
## already loaded at the main menu, where network mode was still NONE.
func _on_network_session_started(_peer_id: int) -> void:
	_setup_multiplayer()


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
		player.global_position = world.get_default_spawn_position()

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


# ── Multiplayer ────────────────────────────────────────────────────────

func _setup_multiplayer() -> void:
	if _mp_setup_done:
		return
	if not NetworkManager.is_network_active():
		return
	_mp_setup_done = true

	var my_id := multiplayer.get_unique_id()
	player.set_multiplayer_authority(my_id)
	# Name the local player like remote copies so path-based RPC routing
	# (e.g. _sync_remote_state, _sync_tool_swing) resolves to the same
	# node path on every peer.
	player.name = "Player_%d" % my_id
	_remote_players[my_id] = player
	# CameraController._ready() skips make_current() while the player's
	# authority is still the default; activate our own camera now.
	var local_cam := player.get_node_or_null("Camera2D") as Camera2D
	if local_cam and not local_cam.is_current():
		local_cam.make_current()

	if not NetworkManager.peer_connected.is_connected(_on_peer_connected):
		NetworkManager.peer_connected.connect(_on_peer_connected)
	if not NetworkManager.peer_disconnected.is_connected(_on_peer_disconnected):
		NetworkManager.peer_disconnected.connect(_on_peer_disconnected)

	# Host: register with any peers that connected before Main was ready
	# We create remote players locally and let _register_me_to_remote handle
	# the broadcast to ensure each client is ready before receiving RPCs.
	if multiplayer.is_server():
		for pid in multiplayer.get_peers():
			_instantiate_remote_player(pid)
	else:
		# Client: tell the host about us so we appear on other peers
		rpc_id(1, "_register_me_to_remote", my_id)


## Called by a client when its Main scene is ready, asking the host to
## broadcast this peer's remote player to all clients.
@rpc("any_peer", "reliable")
func _register_me_to_remote(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	# Never trust the caller-supplied peer_id for routing: a client could
	# otherwise register/spawn remote-player copies for a DIFFERENT peer.
	var sender: int = multiplayer.get_remote_sender_id()
	if sender != 0:
		peer_id = sender
	print("Main: client %d registered; world_generated=%s" % [peer_id, str(_world_generated)])
	# Ensure the remote player exists locally
	_instantiate_remote_player(peer_id)

	# Send world seed BEFORE player info so the client generates the
	# world first (remote player nodes need a valid world parent).
	if _world_generated:
		rpc_id(peer_id, "_receive_world_seed", world.world_seed)
	else:
		_pending_seed_peers.append(peer_id)

	# Propagate the host's difficulty so all clients share the same economy
	# and enemy scaling. Sent unconditionally (the host is authoritative).
	rpc_id(peer_id, "_receive_host_difficulty", GameManager.difficulty)
	# Propagate the host's game mode so all clients share the same rules.
	rpc_id(peer_id, "_receive_host_game_mode", GameManager.game_mode)

	# Broadcast the new peer to all clients
	rpc("_add_remote_player", peer_id)
	# Tell the new peer about every other existing peer
	for pid in _remote_players:
		if pid != peer_id:
			rpc_id(peer_id, "_add_remote_player", pid)


## Called by the host's Bootstrap after world generation to notify Main.
func notify_world_generated(seed: int) -> void:
	if not NetworkManager.is_network_active():
		return
	_world_generated = true
	# Send seed to any peers that connected before the world was ready
	for pid in _pending_seed_peers:
		rpc_id(pid, "_receive_world_seed", seed)
	_pending_seed_peers.clear()


## Sent by the host to a client with the world seed so the client can
## generate an identical world locally.
@rpc("authority", "reliable")
func _receive_world_seed(seed: int) -> void:
	print("Main: received world seed %d — regenerating world" % seed)
	if not (world and world.has_method("generate_world_with_seed")):
		print("Main: _receive_world_seed but world not ready yet!")
		return
	player.set_process(false)
	player.set_physics_process(false)
	world.generate_world_with_seed(seed)
	player.set_process(true)
	player.set_physics_process(true)
	# The HUD seed label was set from world.world_seed at _ready (0 for a
	# client, before the seed arrived) — refresh it with the real seed.
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("set_seed_display"):
		hud.set_seed_display(seed)
	_position_player_at_spawn()
	if not multiplayer.is_server():
		# The host's starter animals (Animal_20/21) were spawned before we
		# connected, so no spawn RPC ever reached us. Re-create them locally
		# with the same deterministic names so the host's per-node sync RPCs
		# resolve on this peer.
		if world.has_method("spawn_starter_animals_near"):
			world.spawn_starter_animals_near(player.global_position)
		# Mirror the host's fresh-game starter inventory (Bootstrap grants it
		# only in its host-side new-game flow).
		var bootstrap := get_tree().root.get_node_or_null("Bootstrap")
		if bootstrap and bootstrap.has_method("grant_starter_inventory"):
			bootstrap.grant_starter_inventory()
		# Overlay the client's own personal progression (inventory, money,
		# level, pets, personal quests) from its save slot so a returning
		# player keeps their progress instead of starting blank. Run after
		# grant_starter_inventory so a real save replaces the fresh starter
		# set; brand-new players (no save) keep the starter inventory.
		SaveManager.load_player_progression()
		# Pull the host's current town + world-event state so a late joiner
		# sees town progress, an active blood moon, and an active raid that
		# broadcast before this client was ready to receive them.
		var tm := get_tree().get_first_node_in_group("town_manager")
		if tm and tm.has_method("_server_request_town_snapshot"):
			tm.rpc_id(1, "_server_request_town_snapshot")
		var bm: BloodMoonEvent = world.get("blood_moon_event") as BloodMoonEvent
		if bm and bm.has_method("_server_request_blood_moon_state"):
			bm.rpc_id(1, "_server_request_blood_moon_state")
		var raid: PirateRaidEvent = world.get("pirate_raid") as PirateRaidEvent
		if raid and raid.has_method("_server_request_raid_state"):
			raid.rpc_id(1, "_server_request_raid_state")
		# Pull the host's live world state (removed resources, harvested
		# bushes, placed buildings, sprinklers, chests) so this late joiner
		# doesn't sit in a pristine copy of the world.
		if world.has_method("_server_request_world_state"):
			world.rpc_id(1, "_server_request_world_state")
		# Pull every enemy currently alive on the host (night mobs, raid
		# pirates, minions, bosses) so they exist on this peer too.
		var esp: EnemySpawner = world.get("enemy_spawner") as EnemySpawner
		if esp and esp.has_method("_server_request_enemy_state"):
			esp.rpc_id(1, "_server_request_enemy_state")
	# The client world is now ready — hide the scenic background layer that
	# Bootstrap shows while waiting for the world sync.
	var bootstrap := get_tree().root.get_node_or_null("Bootstrap")
	if bootstrap and bootstrap.has_method("hide_world_background"):
		bootstrap.hide_world_background()
	# Reposition any remote players to the default spawn
	var spawn_pos: Vector2 = world.get_default_spawn_position() if world.has_method("get_default_spawn_position") else Vector2.ZERO
	for pid in _remote_players:
		var p = _remote_players[pid]
		if p != player:
			p.global_position = spawn_pos


## Sent by the host to a client with the host's difficulty setting so all
## players share the same economy and enemy scaling in multiplayer.
@rpc("authority", "reliable")
func _receive_host_difficulty(diff: int) -> void:
	print("Main: received host difficulty %d" % diff)
	GameManager.set_difficulty(diff)


## Sent by the host to a client with the host's game mode (peaceful,
## survival, creative, hardcore) so all players share the same rules.
@rpc("authority", "reliable")
func _receive_host_game_mode(mode: int) -> void:
	print("Main: received host game mode %d" % mode)
	GameManager.set_game_mode(mode)


## Creates a remote player node on all clients for the given peer.
@rpc("authority", "reliable")
func _add_remote_player(peer_id: int) -> void:
	print("Main: _add_remote_player(%d) received on peer %d" % [peer_id, multiplayer.get_unique_id()])
	_instantiate_remote_player(peer_id)


## Removes a remote player node from all peers.
@rpc("authority", "call_local", "reliable")
func _remove_remote_player(peer_id: int) -> void:
	var remote = _remote_players.get(peer_id)
	if remote and remote != player:
		remote.queue_free()
	_remote_players.erase(peer_id)


func _instantiate_remote_player(peer_id: int) -> void:
	if _remote_players.has(peer_id):
		return

	# This is our own player — just register the existing node
	if peer_id == multiplayer.get_unique_id():
		_remote_players[peer_id] = player
		return

	var player_scene := preload("res://scenes/player/Player.tscn")
	var remote: CharacterBody2D = player_scene.instantiate()
	remote.name = "Player_%d" % peer_id
	remote.set_multiplayer_authority(peer_id)

	# Remote copies must live at the same node path as the local player
	# ("Bootstrap/Game/Player_<id>") so rpc() broadcasts from a peer's
	# player node resolve to the correct copy on every other peer.
	var cam := remote.get_node_or_null("Camera2D")
	if cam:
		cam.enabled = false

	# Place near spawn initially (position will be overwritten by first RPC sync)
	if world and world.has_method("get_default_spawn_position"):
		remote.global_position = world.get_default_spawn_position()

	player.get_parent().add_child(remote)
	_remote_players[peer_id] = remote


## Called when a new peer connects.
## Creates the remote player immediately on every peer. On the host this also
## broadcasts stats; on clients it pre-creates the remote copy so the host's
## per-frame state RPCs (which are unreliable and can arrive before the
## reliable _add_remote_player RPC) resolve to an existing node.
func _on_peer_connected(peer_id: int) -> void:
	_instantiate_remote_player(peer_id)
	if not multiplayer.is_server():
		return
	# Broadcast our host stats so the new peer gets current values immediately
	GameManager._try_broadcast_player_stats()
	# Tell other existing clients to broadcast their stats too
	rpc("_request_stat_broadcast")


## Asks all clients to rebroadcast their player stats so a newly joined
## peer receives current values for every player.
@rpc("authority", "reliable")
func _request_stat_broadcast() -> void:
	GameManager._try_broadcast_player_stats()


## Called on the host when a peer disconnects.
func _on_peer_disconnected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	rpc("_remove_remote_player", peer_id)
