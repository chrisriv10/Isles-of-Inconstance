extends Node

## Manages saving and loading game state using JSON serialization across
## multiple save slots. Each slot is stored as user://save_{slot}.json.
## Supports 5 save slots (0-4). Handles versioning, missing fields, corruption.

const SAVE_VERSION: int = 3
const SLOT_COUNT: int = 5
## Default display name stored in a new save when no explicit name is set.
const DEFAULT_SAVE_NAME: String = "My Island"

signal save_completed(success: bool)
signal load_completed(success: bool)

## The currently selected save slot index (0-based).
var current_slot: int = 0


func _ready() -> void:
	# NetworkManager is a LATER autoload, so hook its disconnect signal once
	# the scene tree is up. If the host drops mid-session, this peer instantly
	# persists its own personal progression instead of losing the session.
	get_tree().process_frame.connect(_hook_server_disconnect, CONNECT_ONE_SHOT)


func _hook_server_disconnect() -> void:
	var nm: Node = get_tree().root.get_node_or_null("NetworkManager")
	if nm and not nm.server_disconnected.is_connected(_on_server_disconnected):
		nm.server_disconnected.connect(_on_server_disconnected)


## Host dropped the session: write ONLY this player's personal progression.
## (Direct call, not save_game(), because NetworkManager already reset its
## mode to NONE by the time this fires, so save_game() would take the full
## world path — which a client must never write.)
func _on_server_disconnected() -> void:
	# This handler is only wired to NetworkManager.server_disconnected, which
	# fires ONLY on a client that lost its host. The former `if multiplayer
	# .is_server(): return` guard was a bug: NetworkManager nulls the network
	# peer BEFORE emitting this signal, and is_server() returns true with a null
	# peer — so the guard always bailed and the save never ran. Save here.
	_save_player_progression()
	print("SaveManager: host disconnected — personal progression saved")


## Get the file path for a specific save slot.
static func _get_save_path(slot_index: int) -> String:
	return "user://save_%d.json" % slot_index

## Save all game state to the currently selected slot.
func save_game() -> void:
	_ensure_save_directory()
	
	# In an active multiplayer session the host owns the shared world (soil,
	# buildings, chests, town), so a client must NOT write host/synced world
	# data over its own save slot. Only the host (and single-player) persists
	# the full save. A client still persists ITS OWN personal progression
	# (gear, money, level, quests/objectives, pets...) so a co-op-only player
	# keeps their progress across sessions — see load_player_progression().
	if NetworkManager.is_network_active() and not multiplayer.is_server():
		_save_player_progression()
		return
	
	var path := _get_save_path(current_slot)
	var save_data := _collect_save_data()
	save_data["save_version"] = SAVE_VERSION
	save_data["save_timestamp"] = Time.get_unix_time_from_system()
	save_data["save_slot"] = current_slot
	# Always persist a non-empty display name. Some paths (notably a client's
	# progression save) leave GameManager.save_name empty, which would make the
	# Save Select fall back to the player name (e.g. "Farmer") instead of the
	# intended default.
	save_data["save_name"] = GameManager.save_name if not GameManager.save_name.is_empty() else DEFAULT_SAVE_NAME
	
	var json_string := JSON.stringify(save_data)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		printerr("Failed to open save file for writing: ", path)
		save_completed.emit(false)
		return
	
	file.store_string(json_string)
	file.close()
	print("Game saved successfully to: ", path)
	save_completed.emit(true)


## Write ONLY the player's personal progression to the slot. This is the
## counterpart to load_player_progression(): it serializes the exact subset of
## keys _apply_player_progression restores and deliberately NEVER writes shared
## world state (soil, buildings, chests, town, difficulty, game mode, weather,
## raid...). Used by clients in a live session so they keep their own
## gear/money/level/quests/objectives without clobbering host world data.
func _save_player_progression() -> void:
	_ensure_save_directory()
	var path := _get_save_path(current_slot)
	var save_data := _collect_player_progression_data()
	save_data["save_version"] = SAVE_VERSION
	save_data["save_timestamp"] = Time.get_unix_time_from_system()
	save_data["save_slot"] = current_slot
	# Same default-name guard as the full save path.
	save_data["save_name"] = GameManager.save_name if not GameManager.save_name.is_empty() else DEFAULT_SAVE_NAME
	var json_string := JSON.stringify(save_data)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		printerr("Failed to open save file for writing (progression): ", path)
		save_completed.emit(false)
		return
	file.store_string(json_string)
	file.close()
	print("Player progression saved to: ", path)
	save_completed.emit(true)


## Collect ONLY the personal-progression fields (mirrors _apply_player_progression).
func _collect_player_progression_data() -> Dictionary:
	var data := {}
	data["player_name"] = GameManager.player_name
	data["inventory"] = InventoryManager.get_all_items()
	data["money"] = GameManager.money
	data["bank_balance"] = GameManager.bank_balance
	data["upgrades"] = UpgradeManager.get_upgrade_levels()
	data["discovered_crops"] = DataManager.get_discovered_crop_ids()
	data["discovered_items"] = DataManager.get_discovered_item_ids()
	data["farming_stats"] = {
		"total_crops_harvested": GameManager.total_crops_harvested,
		"total_giant_crops_harvested": GameManager.total_giant_crops_harvested,
		"total_mutations_occurred": GameManager.total_mutations_occurred,
		"total_compost_produced": GameManager.total_compost_produced,
		"total_seeds_planted": GameManager.total_seeds_planted,
		"best_quality_tier": GameManager.best_quality_tier
	}
	data["player_level"] = LevelManager.serialize()
	data["equipped_armor"] = GameManager.equipped_armor.duplicate()
	data["health"] = GameManager.health
	data["hunger"] = GameManager.hunger
	if PetManager and PetManager.has_method("serialize"):
		data["pets"] = PetManager.serialize()
	var quest_manager := get_tree().get_first_node_in_group("quest_manager")
	if quest_manager and quest_manager.has_method("serialize"):
		data["quests"] = quest_manager.serialize()
	var obj_mgr := get_tree().get_first_node_in_group("objective_manager")
	if obj_mgr and obj_mgr.has_method("serialize"):
		data["objectives"] = obj_mgr.serialize()
	data["seen_dialogues"] = GameManager.seen_dialogues.duplicate()
	return data

## Load all game state from the currently selected slot.
func load_game() -> void:
	_ensure_save_directory()
	
	var path := _get_save_path(current_slot)
	if not FileAccess.file_exists(path):
		print("No save file found at: ", path)
		load_completed.emit(false)
		return
	
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		printerr("Failed to open save file for reading: ", path)
		load_completed.emit(false)
		return
	
	var json_string := file.get_as_text()
	file.close()
	
	if json_string.is_empty():
		printerr("Save file is empty")
		load_completed.emit(false)
		return
	
	var json := JSON.new()
	var parse_result := json.parse(json_string)
	if parse_result != OK:
		printerr("Failed to parse save file JSON: ", json.get_error_message())
		_delete_corrupted_save(current_slot)
		load_completed.emit(false)
		return
	
	var save_data: Dictionary = json.data
	if not save_data:
		printerr("Save file contains no data")
		load_completed.emit(false)
		return
	
	_apply_save_data(save_data)
	print("Game loaded successfully from: ", path)
	load_completed.emit(true)


## Read ONLY the player's personal progression from the current slot and
## apply it WITHOUT any world data. Joining multiplayer clients use this so
## returning friends keep their gear, money, level, pets and personal quests
## instead of starting blank. Returns true if a save was applied.
func load_player_progression() -> bool:
	_ensure_save_directory()
	var path := _get_save_path(current_slot)
	if not FileAccess.file_exists(path):
		print("No save found for personal progression at: ", path)
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		printerr("Failed to open save file for reading: ", path)
		return false
	var json_string := file.get_as_text()
	file.close()
	if json_string.is_empty():
		return false
	var json := JSON.new()
	if json.parse(json_string) != OK:
		printerr("Failed to parse save file JSON: ", json.get_error_message())
		return false
	var save_data: Dictionary = json.data
	_apply_player_progression(save_data)
	print("Player progression loaded from: ", path)
	return true


## Apply ONLY the personal-progression fields. Mirrors the relevant subset of
## _apply_save_data but deliberately NEVER touches world, soil, buildings,
## chests, town, objectives, day/time, difficulty, or game mode — those are
## host-authoritative in multiplayer (8a).
func _apply_player_progression(save_data: Dictionary) -> void:
	var player: Node = get_tree().get_first_node_in_group("player")

	# Player name
	if save_data.has("player_name"):
		GameManager.player_name = save_data["player_name"]
		if player and player.has_node("NameLabel"):
			player.get_node("NameLabel").text = GameManager.player_name
	GameManager.save_name = save_data.get("save_name", "")

	# Inventory
	if save_data.has("inventory"):
		InventoryManager.clear()
		var inventory: Dictionary = save_data["inventory"]
		for item_id in inventory:
			var amount: int = inventory[item_id]
			if amount is int and amount > 0:
				InventoryManager.add_item(item_id, amount)

	# Money & bank
	if save_data.has("money"):
		var money_val: int = save_data["money"]
		if money_val is int:
			GameManager.money = money_val
	if save_data.has("bank_balance"):
		var bank_val: int = save_data["bank_balance"]
		if bank_val is int:
			GameManager.bank_balance = bank_val

	# Upgrades
	if save_data.has("upgrades"):
		var upgrades: Dictionary = save_data["upgrades"]
		for upgrade_id in upgrades:
			var level_val: int = upgrades[upgrade_id]
			if level_val is int:
				# JSON serializes enum int-keys to strings; convert back
				var upgrade_enum: int = int(upgrade_id) if upgrade_id is String else upgrade_id
				UpgradeManager.set_upgrade_level(upgrade_enum, level_val)

	# Discovered crops / items (collections)
	if save_data.has("discovered_crops"):
		for crop_id in save_data["discovered_crops"]:
			if crop_id is String:
				DataManager.mark_discovered(crop_id)
	if save_data.has("discovered_items"):
		for item_id in save_data["discovered_items"]:
			if item_id is String:
				DataManager.mark_item_discovered(item_id)

	# Farming stats
	if save_data.has("farming_stats"):
		var fs: Dictionary = save_data["farming_stats"]
		GameManager.total_crops_harvested = fs.get("total_crops_harvested", 0)
		GameManager.total_giant_crops_harvested = fs.get("total_giant_crops_harvested", 0)
		GameManager.total_mutations_occurred = fs.get("total_mutations_occurred", 0)
		GameManager.total_compost_produced = fs.get("total_compost_produced", 0)
		GameManager.total_seeds_planted = fs.get("total_seeds_planted", 0)
		GameManager.best_quality_tier = fs.get("best_quality_tier", 0)

	# Level (restore BEFORE health/hunger so max stats are correct)
	if save_data.has("player_level"):
		LevelManager.deserialize(save_data["player_level"])
		GameManager.refresh_max_stats()

	# Armor
	if save_data.has("equipped_armor"):
		var armor_data: Dictionary = save_data["equipped_armor"]
		for slot: String in armor_data:
			GameManager.equipped_armor[slot] = armor_data[slot]
		GameManager.armor_changed.emit(GameManager.get_armor_defense())

	# Health & hunger
	if save_data.has("health"):
		GameManager.health = clampi(save_data["health"], 0, GameManager.MAX_HEALTH)
	if save_data.has("hunger"):
		GameManager.hunger = clampi(save_data["hunger"], 0, GameManager.MAX_HUNGER)

	# Pets
	if save_data.has("pets") and PetManager and PetManager.has_method("deserialize"):
		PetManager.deserialize(save_data["pets"])

	# Personal quest progress
	if save_data.has("quests"):
		var quest_manager: Node = get_tree().get_first_node_in_group("quest_manager")
		if quest_manager and quest_manager.has_method("deserialize"):
			quest_manager.deserialize(save_data["quests"])

	# Personal objective progress — per-player, restored from the player's own
	# save (NOT synced from the host; no shared/co-op objectives).
	if save_data.has("objectives"):
		var obj_mgr: Node = get_tree().get_first_node_in_group("objective_manager")
		if obj_mgr and obj_mgr.has_method("deserialize"):
			obj_mgr.deserialize(save_data["objectives"])

	# Player dialogue seen flags (so first-time dialogue doesn't replay)
	if save_data.has("seen_dialogues"):
		GameManager.seen_dialogues = (save_data["seen_dialogues"] as Dictionary).duplicate()

## Check if ANY save slot has a save file.
func has_save_file() -> bool:
	for i in range(SLOT_COUNT):
		if FileAccess.file_exists(_get_save_path(i)):
			return true
	return false

## Count how many save files exist across all slots.
func count_saves() -> int:
	var count: int = 0
	for i in range(SLOT_COUNT):
		if FileAccess.file_exists(_get_save_path(i)):
			count += 1
	return count

## Check if a specific slot has a save.
func has_save_in_slot(slot_index: int) -> bool:
	return FileAccess.file_exists(_get_save_path(slot_index))

## Delete the primary save (slot 0, legacy compat).
func delete_save() -> void:
	var path := _get_save_path(0)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		print("Save file deleted")

## Delete a specific slot's save.
func delete_save_in_slot(slot_index: int) -> void:
	var path := _get_save_path(slot_index)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		print("Slot %d save deleted" % slot_index)

## Get metadata for a save slot without fully loading it.
func get_save_slot_info(slot_index: int) -> Dictionary:
	var path := _get_save_path(slot_index)
	if not FileAccess.file_exists(path):
		return {}
	
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	
	var json_string := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	if json.parse(json_string) != OK:
		return {}
	
	var data: Dictionary = json.data
	return {
		"player_name": data.get("player_name", "Unknown"),
		"save_name": data.get("save_name", ""),
		"current_day": data.get("current_day", 1),
		"money": data.get("money", 0),
		"save_timestamp": data.get("save_timestamp", 0.0),
		"save_version": data.get("save_version", 1),
		"current_hour": data.get("current_hour", 6),
		"current_minute": data.get("current_minute", 0),
		"world_seed": data.get("world_seed", 0),
		"game_mode": data.get("game_mode", GameManager.GameMode.SURVIVAL),
		"difficulty": data.get("difficulty", GameManager.Difficulty.NORMAL),
	}

## Ensure save directory exists
func _ensure_save_directory() -> void:
	var dir := DirAccess.open("user://")
	if dir:
		dir.make_dir_recursive(".")

## Delete corrupted save file for given slot
func _delete_corrupted_save(slot_index: int) -> void:
	var path := _get_save_path(slot_index)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		print("Deleted corrupted save for slot ", slot_index)

## Collect all game state into a serializable dictionary
func _collect_save_data() -> Dictionary:
	var save_data := {}
	
	# World data
	var world := get_tree().get_first_node_in_group("world")
	if world:
		save_data["world_seed"] = world.world_seed
		save_data["soil_data"] = _serialize_soil_data(world._soil_data)
		save_data["sprinklers"] = _serialize_sprinklers(world._sprinklers)
		save_data["scarecrow_cells"] = _serialize_cell_array(world._scarecrow_cells)
		save_data["compost_bin_cells"] = _serialize_cell_array(world._compost_bin_cells)
		save_data["greenhouse_cells"] = _serialize_cell_array(world._greenhouse_cells)
	
	# Player data
	var player := get_tree().get_first_node_in_group("player")
	if player:
		save_data["player_position"] = {
			"x": player.global_position.x,
			"y": player.global_position.y
		}
	
	# Player name
	save_data["player_name"] = GameManager.player_name
	
	# Inventory data
	save_data["inventory"] = InventoryManager.get_all_items()
	
	# Money
	save_data["money"] = GameManager.money
	
	# Bank balance
	save_data["bank_balance"] = GameManager.bank_balance
	
	# Difficulty
	save_data["difficulty"] = GameManager.difficulty

	# Day/time
	save_data["current_day"] = GameManager.current_day
	save_data["current_hour"] = GameManager.get_hour()
	save_data["current_minute"] = GameManager.get_minute()
	
	# Upgrades
	save_data["upgrades"] = UpgradeManager.get_upgrade_levels()
	
	# Discovered crops
	save_data["discovered_crops"] = DataManager.get_discovered_crop_ids()

	# Discovered items (collections)
	save_data["discovered_items"] = DataManager.get_discovered_item_ids()
	
	# Selected seed (deprecated — hotbar is now inventory slots 0-7)
	if player and "selected_seed_crop_id" in player:
		save_data["selected_seed_crop_id"] = player.selected_seed_crop_id
	
	# Farming stats
	save_data["farming_stats"] = {
		"total_crops_harvested": GameManager.total_crops_harvested,
		"total_giant_crops_harvested": GameManager.total_giant_crops_harvested,
		"total_mutations_occurred": GameManager.total_mutations_occurred,
		"total_compost_produced": GameManager.total_compost_produced,
		"total_seeds_planted": GameManager.total_seeds_planted,
		"best_quality_tier": GameManager.best_quality_tier
	}
	
	# Season system
	if GameManager.season_system:
		save_data["season_system"] = GameManager.season_system.serialize()
	
	# Building chest inventories
	save_data["chest_inventories"] = _serialize_chest_inventories()
	
	# Buildings
	var building_system := _get_building_system()
	if building_system:
		save_data["buildings"] = building_system.serialize()
	
	# Cooking
	var cook_sys = _get_cooking_system_from_world()
	if cook_sys:
		save_data["cooking"] = cook_sys.serialize()
	
	# Equipped armor
	save_data["equipped_armor"] = GameManager.equipped_armor.duplicate()
	
	# Health & Hunger
	save_data["health"] = GameManager.health
	save_data["hunger"] = GameManager.hunger
	
	# Active buffs
	if BuffManager:
		save_data["buffs"] = BuffManager.serialize()
	
	# Game mode
	save_data["game_mode"] = GameManager.game_mode
	
	# Objectives
	var obj_mgr := get_tree().get_first_node_in_group("objective_manager")
	if obj_mgr and obj_mgr.has_method("serialize"):
		save_data["objectives"] = obj_mgr.serialize()
	
	# Player level
	save_data["player_level"] = LevelManager.serialize()
	
	# Weather system
	if GameManager.weather_system and GameManager.weather_system.has_method("serialize"):
		save_data["weather"] = GameManager.weather_system.serialize()
	
	# Pirate raid state
	var raid_world := get_tree().get_first_node_in_group("world")
	if raid_world and "pirate_raid" in raid_world:
		var pirate_raid = raid_world.pirate_raid
		if pirate_raid and pirate_raid.has_method("serialize"):
			save_data["pirate_raid"] = pirate_raid.serialize()
	
	# Blood moon state
	if raid_world and "blood_moon_event" in raid_world:
		var bm_event = raid_world.blood_moon_event
		if bm_event and bm_event.has_method("serialize"):
			save_data["blood_moon"] = bm_event.serialize()
	
	# Pet data
	if PetManager and PetManager.has_method("serialize"):
		save_data["pets"] = PetManager.serialize()
	
	# Town data
	var town_manager := get_tree().get_first_node_in_group("town_manager")
	if town_manager and town_manager.has_method("serialize"):
		save_data["town"] = town_manager.serialize()
	
	# Removed island objects (chopped trees, mined rocks, harvested bushes) so
	# gathered resources stay gone after a single-player reload instead of
	# respawning. Mirrors the multiplayer world-state snapshot serialization.
	if world and world.has_method("_removed_cell_objects"):
		var removed: Array = []
		for cell in world._removed_cell_objects:
			removed.append([cell.x, cell.y])
		save_data["removed_objects"] = removed
	
	# Animal roster (positions, taming, names, colors) so livestock persists
	# across a single-player reload. Mirrors get_network_data / the multiplayer
	# world-state snapshot.
	var animals: Array = []
	for a in get_tree().get_nodes_in_group("animals"):
		if is_instance_valid(a) and a.has_method("get_network_data"):
			animals.append(a.get_network_data())
	save_data["animals"] = animals
	
	# Quest data
	var quest_manager := get_tree().get_first_node_in_group("quest_manager")
	if quest_manager and quest_manager.has_method("serialize"):
		save_data["quests"] = quest_manager.serialize()
	
	# Player dialogue seen flags
	save_data["seen_dialogues"] = GameManager.seen_dialogues.duplicate()
	
	return save_data

## Apply loaded save data to game state
func _apply_save_data(save_data: Dictionary) -> void:
	# Handle version migration
	var version: int = save_data.get("save_version", 1)
	if version < SAVE_VERSION:
		print("Migrating save from version %d to %d" % [version, SAVE_VERSION])
		save_data = _migrate_save(save_data, version)
	
	# World data
	var world := get_tree().get_first_node_in_group("world")
	if world and save_data.has("world_seed"):
		world.world_seed = save_data["world_seed"]
		world.generate_world()
		
		if save_data.has("soil_data"):
			_deserialize_soil_data(save_data["soil_data"], world)
		
		if save_data.has("sprinklers"):
			_deserialize_sprinklers(save_data["sprinklers"], world)
		
		if save_data.has("scarecrow_cells"):
			world._scarecrow_cells = _deserialize_cell_array(save_data["scarecrow_cells"])
		if save_data.has("compost_bin_cells"):
			world._compost_bin_cells = _deserialize_cell_array(save_data["compost_bin_cells"])
		if save_data.has("greenhouse_cells"):
			world._greenhouse_cells = _deserialize_cell_array(save_data["greenhouse_cells"])
		
		# Restore removed island objects (gathered resources stay gone instead
		# of respawning after a single-player reload). Runs after generate_world
		# so the objects exist to be removed.
		if save_data.has("removed_objects"):
			for entry in save_data["removed_objects"]:
				if entry is Array and entry.size() >= 2:
					world._remove_object_at_cell(Vector2i(int(entry[0]), int(entry[1])))
		
		# Rebuild the saved animal roster (positions, taming, names, colors),
		# replacing the freshly-scattered wild animals from generate_world so
		# the world matches what was saved. _is_remote is set correctly inside.
		if save_data.has("animals"):
			world.recreate_animals_from_roster(save_data["animals"])
	
	# Player position
	var player := get_tree().get_first_node_in_group("player")
	if player and save_data.has("player_position"):
		var pos_data: Dictionary = save_data["player_position"]
		player.global_position = Vector2(
			pos_data.get("x", 0.0),
			pos_data.get("y", 0.0)
		)
	
	# Player name
	if save_data.has("player_name"):
		GameManager.player_name = save_data["player_name"]
		if player and player.has_node("NameLabel"):
			player.get_node("NameLabel").text = GameManager.player_name
	# Save name (display name for the slot)
	GameManager.save_name = save_data.get("save_name", "")
	
	# Inventory
	if save_data.has("inventory"):
		InventoryManager.clear()
		var inventory: Dictionary = save_data["inventory"]
		for item_id in inventory:
			var amount: int = inventory[item_id]
			if amount is int and amount > 0:
				InventoryManager.add_item(item_id, amount)
	
	# Money
	if save_data.has("money"):
		var money_val: int = save_data["money"]
		if money_val is int:
			GameManager.money = money_val
	
	# Bank balance
	if save_data.has("bank_balance"):
		var bank_val: int = save_data["bank_balance"]
		if bank_val is int:
			GameManager.bank_balance = bank_val
	
	# Day/time
	if save_data.has("current_day"):
		var day_val: int = save_data["current_day"]
		if day_val is int:
			GameManager.current_day = day_val
	if save_data.has("current_hour"):
		var hour_val: int = save_data["current_hour"]
		var minute_val: int = save_data.get("current_minute", 0)
		if hour_val is int and minute_val is int:
			GameManager.set_time(hour_val, minute_val)
	
	# Upgrades
	if save_data.has("upgrades"):
		var upgrades: Dictionary = save_data["upgrades"]
		for upgrade_id in upgrades:
			var level_val: int = upgrades[upgrade_id]
			if level_val is int:
				# JSON serializes enum int-keys to strings; convert back
				var upgrade_enum: int = int(upgrade_id) if upgrade_id is String else upgrade_id
				UpgradeManager.set_upgrade_level(upgrade_enum, level_val)
	
	# Discovered crops
	if save_data.has("discovered_crops"):
		var discovered: Array = save_data["discovered_crops"]
		for crop_id in discovered:
			if crop_id is String:
				DataManager.mark_discovered(crop_id)
	
	# Discovered items (collections)
	if save_data.has("discovered_items"):
		var discovered_items: Array = save_data["discovered_items"]
		for item_id in discovered_items:
			if item_id is String:
				DataManager.mark_item_discovered(item_id)
	
	# Selected seed
	if player and save_data.has("selected_seed_crop_id") and "selected_seed_crop_id" in player:
		var seed_id: String = save_data["selected_seed_crop_id"]
		if seed_id is String:
			player.selected_seed_crop_id = seed_id
	
	# Farming stats
	if save_data.has("farming_stats"):
		var fs: Dictionary = save_data["farming_stats"]
		GameManager.total_crops_harvested = fs.get("total_crops_harvested", 0)
		GameManager.total_giant_crops_harvested = fs.get("total_giant_crops_harvested", 0)
		GameManager.total_mutations_occurred = fs.get("total_mutations_occurred", 0)
		GameManager.total_compost_produced = fs.get("total_compost_produced", 0)
		GameManager.total_seeds_planted = fs.get("total_seeds_planted", 0)
		GameManager.best_quality_tier = fs.get("best_quality_tier", 0)
	
	# Season system
	if save_data.has("season_system"):
		GameManager.season_system = SeasonSystem.deserialize(save_data["season_system"])
	
	# Weather system
	if save_data.has("weather") and GameManager.weather_system and GameManager.weather_system.has_method("deserialize"):
		GameManager.weather_system.deserialize(save_data["weather"])
	
	# Pirate raid state
	if save_data.has("pirate_raid"):
		var raid_node: Node = get_tree().get_first_node_in_group("world")
		if raid_node and "pirate_raid" in raid_node:
			var pirate_raid = raid_node.pirate_raid
			if pirate_raid and pirate_raid.has_method("deserialize"):
				pirate_raid.deserialize(save_data["pirate_raid"])
	
	# Blood moon state
	if save_data.has("blood_moon"):
		var bm_node: Node = get_tree().get_first_node_in_group("world")
		if bm_node and "blood_moon_event" in bm_node:
			var bm_event = bm_node.blood_moon_event
			if bm_event and bm_event.has_method("deserialize"):
				bm_event.deserialize(save_data["blood_moon"])
	
	# Buildings
	if save_data.has("buildings"):
		var building_system := _get_building_system()
		if building_system:
			var world_node: Node2D = get_tree().get_first_node_in_group("world")
			if world_node:
				building_system.deserialize(save_data["buildings"], world_node)
	
	# Chest inventories
	if save_data.has("chest_inventories"):
		GameManager.chest_inventories = _deserialize_chest_inventories(save_data["chest_inventories"])
	
	# Game mode
	if save_data.has("game_mode"):
		GameManager.set_game_mode(save_data["game_mode"])

	# Difficulty
	if save_data.has("difficulty"):
		GameManager.set_difficulty(save_data["difficulty"])
	
	# Objectives
	if save_data.has("objectives"):
		var obj_mgr := get_tree().get_first_node_in_group("objective_manager")
		if obj_mgr and obj_mgr.has_method("deserialize"):
			obj_mgr.deserialize(save_data["objectives"])
	
	# Active buffs restore
	if save_data.has("buffs") and BuffManager:
		BuffManager.deserialize(save_data["buffs"])
	
	# Player level (must restore BEFORE health/hunger so max stats are correct)
	if save_data.has("player_level"):
		LevelManager.deserialize(save_data["player_level"])
		GameManager.refresh_max_stats()
	
	# Armor restore
	if save_data.has("equipped_armor"):
		var armor_data: Dictionary = save_data["equipped_armor"]
		for slot: String in armor_data:
			GameManager.equipped_armor[slot] = armor_data[slot]
	GameManager.armor_changed.emit(GameManager.get_armor_defense())
	
	# Health & Hunger restore
	if save_data.has("health"):
		GameManager.health = clampi(save_data["health"], 0, GameManager.MAX_HEALTH)
	if save_data.has("hunger"):
		GameManager.hunger = clampi(save_data["hunger"], 0, GameManager.MAX_HUNGER)
	
	# Pets (restore after buildings/world, before health)
	if save_data.has("pets") and PetManager and PetManager.has_method("deserialize"):
		PetManager.deserialize(save_data["pets"])
	
	# Cooking
	if save_data.has("cooking"):
		var cook_sys = _get_cooking_system_from_world()
		if cook_sys:
			var cs: CookingSystem = CookingSystem.deserialize(save_data["cooking"])
			var world_node2: Node2D = get_tree().get_first_node_in_group("world")
			if world_node2:
				if world_node2.has_method("set_cooking_system"):
					world_node2.set_cooking_system(cs)
	
	# Town data (restore after world is generated)
	if save_data.has("town"):
		var town_manager := get_tree().get_first_node_in_group("town_manager")
		if town_manager and town_manager.has_method("deserialize"):
			# Rebuild ruin scenes from saved state
			town_manager.deserialize(save_data["town"])
			# Respawn resident NPCs from saved data
			_respawn_town_residents()
	
	# Quest data (restore after quest manager is ready)
	if save_data.has("quests"):
		var quest_manager := get_tree().get_first_node_in_group("quest_manager")
		if quest_manager and quest_manager.has_method("deserialize"):
			quest_manager.deserialize(save_data["quests"])
	
	# Player dialogue seen flags (restore so first-time dialogue doesn't replay)
	if save_data.has("seen_dialogues"):
		GameManager.seen_dialogues = (save_data["seen_dialogues"] as Dictionary).duplicate()

## Migrate save data from older versions
func _migrate_save(save_data: Dictionary, from_version: int) -> Dictionary:
	var migrated := save_data.duplicate()
	
	if from_version < 2:
		# Version 2 adds: save_version, save_timestamp
		# No data transformation needed, just ensure new fields exist
		pass
	
	# Future migrations would go here
	# if from_version < 3:
	#     ...
	
	return migrated

## Serialize soil data (crops and their genetics)
func _serialize_soil_data(soil_data: Dictionary) -> Dictionary:
	var serialized := {}
	for cell_key in soil_data:
		var soil: SoilData = soil_data[cell_key]
		# Use SoilData.serialize() which includes soil_quality, disease, and fertilizer
		var cell_data := soil.serialize()
		
		# Serialize crop genetics if present (extra data beyond SoilData)
		var world := get_tree().get_first_node_in_group("world")
		if world and world._crop_nodes.has(cell_key):
			var crop: Crop = world._crop_nodes[cell_key]
			if crop.genetics:
				cell_data["genetics"] = crop.genetics.serialize()
		
		serialized[cell_key] = cell_data
	
	return serialized

## Deserialize soil data and restore crops with genetics
func _deserialize_soil_data(serialized: Dictionary, world: Node2D) -> void:
	for cell_key in serialized:
		var cell_data: Dictionary = serialized[cell_key]
		
		# Parse cell key (Vector2i string format)
		var parts: PackedStringArray = cell_key.split(",")
		if parts.size() < 2:
			continue
		var cell := Vector2i(
			int(parts[0].substr(1)),
			int(parts[1].rstrip(")"))
		)
		
		# Use SoilData.deserialize() which fully restores soil_quality, disease,
		# fertilizer, and all other state
		var soil: SoilData = SoilData.deserialize(cell_data)
		world._soil_data[cell] = soil
		
		# Update tile appearance
		if soil.is_tilled:
			var tile_type: String = "watered_tilled" if soil.is_watered else "tilled"
			var tile_data: TileTypeData = DataManager.get_tile_type(tile_type)
			if tile_data:
				world.ground_layer.set_cell(cell, 0, tile_data.atlas_coords)
		
		# Restore crop if present
		if soil.crop_id != "":
			var crop: Crop = world.CROP_SCENE.instantiate()
			world.objects_root.add_child(crop)
			crop.global_position = world.cell_to_world(cell)
			
			# Restore genetics if saved
			var genetics: CropGenetics = null
			if cell_data.has("genetics"):
				genetics = CropGenetics.deserialize(cell_data["genetics"])
			
			crop.setup(soil.crop_id, soil.days_grown, genetics)
			crop.mutated.connect(world._on_crop_mutated.bind(cell))
			world._crop_nodes[cell] = crop

## Helper: get BuildingSystem reference from World
func _get_building_system() -> BuildingSystem:
	var world := get_tree().get_first_node_in_group("world")
	if world and world.has_method("get_building_system"):
		return world.get_building_system()
	return null

## Helper: get CookingSystem reference from World
func _get_cooking_system_from_world():
	var world_node: Node2D = get_tree().get_first_node_in_group("world")
	if world_node and world_node.has_method("get_cooking_system"):
		return world_node.get_cooking_system()
	return null

## Serialize all chest inventories for saving.
func _serialize_chest_inventories() -> Dictionary:
	var result: Dictionary = {}
	for key in GameManager.chest_inventories:
		result[key] = GameManager.chest_inventories[key]
	return result

## Serialize an array of Vector2i cells to a string array.
func _serialize_cell_array(cells: Array[Vector2i]) -> PackedStringArray:
	var result: PackedStringArray = []
	for cell in cells:
		result.append("%s,%s" % [cell.x, cell.y])
	return result

## Deserialize a string array back to an array of Vector2i cells.
func _deserialize_cell_array(data: PackedStringArray) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for s in data:
		var parts: PackedStringArray = s.split(",")
		if parts.size() >= 2:
			result.append(Vector2i(int(parts[0]), int(parts[1])))
	return result

## Deserialize chest inventories from save data.
func _deserialize_chest_inventories(data: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in data:
		result[key] = data[key]
	return result

## Serialize sprinkler data.
func _serialize_sprinklers(sprinklers: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for cell_key in sprinklers:
		var s_data: Dictionary = sprinklers[cell_key]
		result[str(cell_key)] = {
			"active": s_data.get("active", true),
			"placed_day": s_data.get("placed_day", 1),
			"tier": s_data.get("tier", 0),
		}
	return result

## Deserialize sprinkler data.
func _deserialize_sprinklers(data: Dictionary, world: Node2D) -> void:
	for cell_key_str in data:
		var parts: PackedStringArray = cell_key_str.split(",")
		if parts.size() < 2:
			continue
		var cell := Vector2i(
			int(parts[0].trim_prefix("(")),
			int(parts[1].trim_suffix(")").trim_suffix(" "))
		)
		var s_data: Dictionary = data[cell_key_str]
		world._sprinklers[cell] = {
			"active": s_data.get("active", true),
			"placed_day": s_data.get("placed_day", 1),
			"tier": s_data.get("tier", 0),
		}

## After deserializing town data, respawn resident NPC sprites in the world.
## Delegates to TownManager's canonical reconciliation (deterministic, idempotent)
## so load-time spawning and multiplayer roster sync share one code path.
func _respawn_town_residents() -> void:
	var town_manager := get_tree().get_first_node_in_group("town_manager")
	if not town_manager or not town_manager.has_method("reconcile_resident_npcs"):
		return
	town_manager.reconcile_resident_npcs()
