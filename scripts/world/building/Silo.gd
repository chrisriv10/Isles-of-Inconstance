extends Node2D
class_name Silo

## Silo building — massive crop-only storage container.
##
## Provides 36 slots of storage that only accepts items in the "crop"
## category. Also features a "Deposit All Crops" button that quickly
## transfers every crop from the player's inventory into the silo.
##
## Creates its own Interactable child for interaction (like Hotel does).

var _container: ContainerInventory = null
var _interactable: Area2D = null


func _ready() -> void:
	# Create the crop-only storage container
	_container = ContainerInventory.new(36)
	
	# Restore from save data if available
	var building_data := _find_my_building_data()
	if building_data and building_data.has("silo_slots"):
		var saved_slots: Array = building_data["silo_slots"]
		if saved_slots.size() > 0:
			_container.slots = saved_slots.duplicate(true)
			if _container.slots.size() > _container.capacity:
				_container.slots.resize(_container.capacity)
	
	# Link container slots back to building_data so serialize() captures changes
	if building_data:
		building_data["silo_slots"] = _container.slots
	
	# Create interaction area
	_setup_interactable()


## Creates an Interactable area so the PlayerInteractor can detect this silo.
func _setup_interactable() -> void:
	var building_node: Node = get_parent()
	if not building_node:
		return
	
	_interactable = Area2D.new()
	_interactable.name = "SiloStorage"
	_interactable.set_script(preload("res://scripts/world/Interactable.gd"))
	_interactable.collision_layer = 4
	_interactable.monitoring = true
	_interactable.monitorable = true
	_interactable.interaction_prompt = "Open Crop Silo"
	
	# Use building footprint for the detection area
	var b_width: int = 3
	var b_height: int = 4
	var shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = Vector2(b_width * 16, b_height * 16)
	shape.shape = rect_shape
	_interactable.add_child(shape)
	building_node.add_child(_interactable)
	
	# Store container reference and connect
	_interactable.set_meta("container_inventory", _container)
	_interactable.interacted.connect(_on_interacted)


## Find the parent building node's data in BuildingSystem.
func _find_my_building_data() -> Dictionary:
	var parent: Node = get_parent()
	if not parent:
		return {}
	# Walk up to find the building cell
	var cell_str: String = parent.name.trim_prefix("Building_")
	var parts: PackedStringArray = cell_str.split("_")
	if parts.size() < 2:
		return {}
	var cell := Vector2i(int(parts[0]), int(parts[1]))
	
	# Look up in BuildingSystem
	var tree := get_tree()
	if not tree:
		return {}
	var building_sys: Node = tree.get_first_node_in_group("building_system")
	if not building_sys or not building_sys.has_method("get_building_at"):
		return {}
	var data: Dictionary = building_sys.get_building_at(cell)
	return data


## Attempts to deposit a specific item. Returns amount not stored (0 = all fit).
func store_item(item_id: String, amount: int = 1) -> int:
	if not _container:
		return amount
	var item: ItemData = DataManager.get_item(item_id)
	if item and item.category != "crop":
		# Silo only accepts crop items
		ToastNotification.show_toast(
			"Silo only stores crops!",
			ToastNotification.ToastType.WARNING,
			1.5
		)
		return amount
	return _container.add_item(item_id, amount)


## Transfer ALL crop items from the player's inventory into the silo.
## Returns the total number of items transferred.
func deposit_all_crops() -> int:
	if not _container:
		return 0
	
	var all_counts: Dictionary = InventoryManager.get_all_counts()
	var total_moved := 0
	
	for item_id in all_counts.keys():
		var item: ItemData = DataManager.get_item(item_id)
		if not item or item.category != "crop":
			continue
		
		var player_count: int = all_counts[item_id]
		if player_count <= 0:
			continue
		
		# Calculate how much the silo can actually accept
		var silo_room := _calculate_capacity_for(item_id)
		var to_move := mini(player_count, silo_room)
		if to_move <= 0:
			continue
		
		# Move from player to silo
		if InventoryManager.remove_item(item_id, to_move):
			var rejected := _container.add_item(item_id, to_move)
			# If some rejected, put back in player inventory
			if rejected > 0:
				InventoryManager.add_item(item_id, rejected)
				to_move -= rejected
			total_moved += to_move
	
	if total_moved > 0:
		ToastNotification.show_toast(
			"Stored %d crops in silo!" % [total_moved],
			ToastNotification.ToastType.SUCCESS,
			2.0
		)
		# Play a satisfying sound
		if AudioManager and AudioManager.has_method("play"):
			AudioManager.play(AudioManager.Sound.CHEST_CLOSE)
	else:
		ToastNotification.show_toast(
			"No crops to store.",
			ToastNotification.ToastType.INFO,
			1.5
		)
	
	return total_moved


## Calculate how many more of item_id the silo can hold.
func _calculate_capacity_for(item_id: String) -> int:
	if not _container:
		return 0
	var item: ItemData = DataManager.get_item(item_id)
	var stack_size: int = item.stack_size if item else 99
	var free := 0
	for slot in _container.slots:
		if slot == null:
			free += stack_size
		elif slot["item_id"] == item_id:
			free += stack_size - slot["count"]
	return free


func get_container() -> ContainerInventory:
	return _container


## Opens the silo storage UI.
func _on_interacted(_interactor: Node) -> void:
	var tree := get_tree()
	if not tree:
		return
	var chest_ui: Node = tree.get_first_node_in_group("chest_storage_ui")
	if chest_ui and chest_ui.has_method("open_for") and _container:
		chest_ui.open_for(_container, "Crop Silo", deposit_all_crops)
