extends Node2D
class_name Windmill

## Windmill building — general storage container for processed goods.
##
## Provides 24 slots of general storage. The windmill is intended for
## processed/milled goods, but accepts any item type.
##
## Creates its own Interactable child for interaction (like Silo does).

var _container: ContainerInventory = null
var _interactable: Area2D = null

var _building_data: Dictionary = {}
var _b_width: int = 3
var _b_height: int = 5


func setup(building_data: Dictionary, width: int, height: int) -> void:
	_building_data = building_data
	_b_width = width
	_b_height = height


func _ready() -> void:
	# Create the storage container
	_container = ContainerInventory.new(24)

	# Restore from save data if available
	if _building_data.has("windmill_slots"):
		var saved_slots: Array = _building_data["windmill_slots"]
		if saved_slots.size() > 0:
			_container.slots = saved_slots.duplicate(true)
			if _container.slots.size() > _container.capacity:
				_container.slots.resize(_container.capacity)

	# Link container slots to building_data so serialize() captures changes
	if _building_data:
		_building_data["windmill_slots"] = _container.slots

	# Create interaction area
	_setup_interactable()


## Creates an Interactable area so the PlayerInteractor can detect this windmill.
func _setup_interactable() -> void:
	var building_node: Node = get_parent()
	if not building_node:
		return

	_interactable = Area2D.new()
	_interactable.name = "WindmillStorage"
	_interactable.set_script(preload("res://scripts/world/Interactable.gd"))
	_interactable.collision_layer = 4
	_interactable.monitoring = true
	_interactable.monitorable = true
	_interactable.interaction_prompt = "Open Windmill Storage"

	# Use building footprint for the detection area
	var shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = Vector2(_b_width * 16, _b_height * 16)
	shape.shape = rect_shape
	_interactable.add_child(shape)
	building_node.add_child(_interactable)

	# Store container reference and connect
	_interactable.set_meta("container_inventory", _container)
	_interactable.interacted.connect(_on_interacted)


func get_container() -> ContainerInventory:
	return _container


## Opens the windmill storage UI.
func _on_interacted(_interactor: Node) -> void:
	var tree := get_tree()
	if not tree:
		return
	var chest_ui: Node = tree.get_first_node_in_group("chest_storage_ui")
	if chest_ui and chest_ui.has_method("open_for") and _container:
		chest_ui.open_for(_container, "Windmill Storage")
