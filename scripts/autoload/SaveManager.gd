extends Node

## Manages saving and loading game state using JSON serialization.
## Saves include: world seed, player position, inventory, crops, genetics, money, upgrades.

const SAVE_FILE_PATH: String = "user://savegame.json"

signal save_completed(success: bool)
signal load_completed(success: bool)

## Save all game state to file
func save_game() -> void:
	var save_data := _collect_save_data()
	var json_string := JSON.stringify(save_data)
	
	var file := FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if not file:
		printerr("Failed to open save file for writing: ", SAVE_FILE_PATH)
		save_completed.emit(false)
		return
	
	file.store_string(json_string)
	file.close()
	
	print("Game saved successfully to: ", SAVE_FILE_PATH)
	save_completed.emit(true)

## Load all game state from file
func load_game() -> void:
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		print("No save file found at: ", SAVE_FILE_PATH)
		load_completed.emit(false)
		return
	
	var file := FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if not file:
		printerr("Failed to open save file for reading: ", SAVE_FILE_PATH)
		load_completed.emit(false)
		return
	
	var json_string := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var parse_result := json.parse(json_string)
	if parse_result != OK:
		printerr("Failed to parse save file JSON: ", json.get_error_message())
		load_completed.emit(false)
		return
	
	var save_data: Dictionary = json.data
	_apply_save_data(save_data)
	
	print("Game loaded successfully from: ", SAVE_FILE_PATH)
	load_completed.emit(true)

## Check if a save file exists
func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_FILE_PATH)

## Delete the save file
func delete_save() -> void:
	if FileAccess.file_exists(SAVE_FILE_PATH):
		DirAccess.remove_absolute(SAVE_FILE_PATH)
		print("Save file deleted")

## Collect all game state into a serializable dictionary
func _collect_save_data() -> Dictionary:
	var save_data := {}
	
	# World data
	var world := get_tree().get_first_node_in_group("world")
	if world:
		save_data["world_seed"] = world.world_seed
		save_data["soil_data"] = _serialize_soil_data(world._soil_data)
	
	# Player data
	var player := get_tree().get_first_node_in_group("player")
	if player:
		save_data["player_position"] = {
			"x": player.global_position.x,
			"y": player.global_position.y
		}
	
	# Inventory data
	save_data["inventory"] = InventoryManager.get_all_items()
	
	# Money
	save_data["money"] = GameManager.money
	
	# Day/time
	save_data["current_day"] = GameManager.current_day
	save_data["current_hour"] = GameManager.get_hour()
	save_data["current_minute"] = GameManager.get_minute()
	
	# Upgrades
	save_data["upgrades"] = UpgradeManager.get_upgrade_levels()
	
	# Discovered crops
	save_data["discovered_crops"] = DataManager.get_discovered_crop_ids()
	
	# Selected seed
	if player:
		save_data["selected_seed_crop_id"] = player.selected_seed_crop_id
	
	return save_data

## Apply loaded save data to game state
func _apply_save_data(save_data: Dictionary) -> void:
	# World data
	var world := get_tree().get_first_node_in_group("world")
	if world and save_data.has("world_seed"):
		world.world_seed = save_data["world_seed"]
		world.generate_world()
		
		if save_data.has("soil_data"):
			_deserialize_soil_data(save_data["soil_data"], world)
	
	# Player position
	var player := get_tree().get_first_node_in_group("player")
	if player and save_data.has("player_position"):
		var pos_data: Dictionary = save_data["player_position"]
		player.global_position = Vector2(pos_data["x"], pos_data["y"])
	
	# Inventory
	if save_data.has("inventory"):
		InventoryManager.clear()
		var inventory: Dictionary = save_data["inventory"]
		for item_id in inventory:
			InventoryManager.add_item(item_id, inventory[item_id])
	
	# Money
	if save_data.has("money"):
		GameManager.money = save_data["money"]
	
	# Day/time
	if save_data.has("current_day"):
		GameManager.current_day = save_data["current_day"]
	if save_data.has("current_hour"):
		GameManager.set_time(save_data["current_hour"], save_data.get("current_minute", 0))
	
	# Upgrades
	if save_data.has("upgrades"):
		var upgrades: Dictionary = save_data["upgrades"]
		for upgrade_id in upgrades:
			UpgradeManager.set_upgrade_level(upgrade_id, upgrades[upgrade_id])
	
	# Discovered crops
	if save_data.has("discovered_crops"):
		var discovered: Array = save_data["discovered_crops"]
		for crop_id in discovered:
			DataManager.mark_discovered(crop_id)
	
	# Selected seed
	if player and save_data.has("selected_seed_crop_id"):
		player.selected_seed_crop_id = save_data["selected_seed_crop_id"]

## Serialize soil data (crops and their genetics)
func _serialize_soil_data(soil_data: Dictionary) -> Dictionary:
	var serialized := {}
	for cell_key in soil_data:
		var soil: SoilData = soil_data[cell_key]
		var cell_data := {
			"is_tilled": soil.is_tilled,
			"is_watered": soil.is_watered,
			"crop_id": soil.crop_id,
			"days_grown": soil.days_grown
		}
		
		# Serialize crop genetics if present
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
		var cell := Vector2i(int(parts[0].substr(1)), int(parts[1].rstrip(")"))
		
		# Restore soil state
		if not world._soil_data.has(cell):
			world._soil_data[cell] = SoilData.new()
		
		var soil: SoilData = world._soil_data[cell]
		soil.is_tilled = cell_data["is_tilled"]
		soil.is_watered = cell_data["is_watered"]
		soil.crop_id = cell_data["crop_id"]
		soil.days_grown = cell_data["days_grown"]
		
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
