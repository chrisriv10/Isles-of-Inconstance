extends CanvasLayer

## Read-only-ish inventory overlay (toggle with [I]). Groups everything the
## player is carrying into the 3 requested categories - seeds, crops,
## resources - by reading ItemData.category, so any new item type slots in
## automatically. The one interactive bit: picking a seed here calls
## Player.select_seed() so purchased/rare/mutated seeds (which don't have a
## fixed hotbar slot) become plantable via the "Selected Seed" tool.

@onready var dim: ColorRect = $Dim
@onready var panel: PanelContainer = $Panel
@onready var capacity_label: Label = %CapacityLabel
@onready var seeds_list: VBoxContainer = %SeedsList
@onready var crops_list: VBoxContainer = %CropsList
@onready var resources_list: VBoxContainer = %ResourcesList

var is_open: bool = false

func _ready() -> void:
	InventoryManager.changed.connect(_on_inventory_changed)
	InventoryManager.capacity_changed.connect(_on_capacity_changed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_inventory"):
		toggle()
		get_viewport().set_input_as_handled()
	elif is_open and event.is_action_pressed("close_menu"):
		close()
		get_viewport().set_input_as_handled()

func toggle() -> void:
	if is_open:
		close()
	else:
		open()

func open() -> void:
	is_open = true
	dim.visible = true
	panel.visible = true
	
	# Add smooth slide + fade animation with sound
	UITweenHelper.animate_open(panel, 0.25, 20.0)
	
	refresh()

func close() -> void:
	is_open = false
	
	# Animate out before hiding
	UITweenHelper.animate_close(panel, 0.2, 20.0, func(): 
		dim.visible = false
		panel.visible = false
	)

func _on_close_pressed() -> void:
	close()

func _on_inventory_changed() -> void:
	if is_open:
		refresh()

func _on_capacity_changed(_new_capacity: int) -> void:
	if is_open:
		refresh()

func refresh() -> void:
	capacity_label.text = "%d / %d slots used" % [InventoryManager.get_used_slot_count(), InventoryManager.capacity]
	_refresh_seeds()
	_refresh_category(crops_list, "crop")
	_refresh_category(resources_list, "resource")

func _clear(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()

func _refresh_seeds() -> void:
	_clear(seeds_list)
	var shown := false
	for crop in DataManager.crops.values():
		if crop.seed_item_id == "":
			continue
		var count := InventoryManager.get_count(crop.seed_item_id)
		if count <= 0:
			continue
		shown = true

		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = "%s Seed x%d" % [crop.display_name, count]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)

		var select_button := Button.new()
		select_button.text = "Plant This"
		select_button.pressed.connect(func(): _select_seed(crop.id))
		row.add_child(select_button)

		seeds_list.add_child(row)

	if not shown:
		seeds_list.add_child(_hint_label("No seeds yet - visit the Shop [B] to buy some."))

func _select_seed(crop_id: String) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("select_seed"):
		player.select_seed(crop_id)
		var crop = DataManager.get_crop(crop_id)
		if crop:
			ToastNotification.show_toast("Selected %s seeds for planting" % crop.display_name, ToastNotification.ToastType.INFO)
	close()

func _refresh_category(container: VBoxContainer, category: String) -> void:
	_clear(container)
	var counts := InventoryManager.get_counts_by_category(category)
	var ids := counts.keys()
	ids.sort()

	var shown := false
	for item_id in ids:
		var item := DataManager.get_item(item_id)
		if not item:
			continue
		shown = true
		var label := Label.new()
		label.text = "%s x%d" % [item.display_name, counts[item_id]]
		container.add_child(label)

	if not shown:
		container.add_child(_hint_label("Nothing here yet."))

func _hint_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.modulate = Color(1.0, 1.0, 1.0, 0.7)
	return label
