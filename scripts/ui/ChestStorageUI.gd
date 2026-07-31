extends CanvasLayer
class_name ChestStorageUI

## Storage chest overlay opened by interacting with a chest or storage shed.
## Shows the chest's contents alongside the player's inventory, with buttons
## to transfer items in either direction.

@onready var dim: ColorRect = $Dim
@onready var panel: PanelContainer = $Panel
@onready var chest_list: VBoxContainer = %ChestList
@onready var player_list: VBoxContainer = %PlayerList

var is_open: bool = false

## The container inventory we're currently viewing/editing.
var _container: ContainerInventory = null
var _chest_key: String = ""

## Optional callback for "Deposit All" button (e.g. silo deposit_all_crops).
var _deposit_all_callback: Callable = Callable()
var _deposit_all_button: Button = null


func _unhandled_input(event: InputEvent) -> void:
	if is_open and event.is_action_pressed("close_menu"):
		close()
		get_viewport().set_input_as_handled()


## Opens this UI for a specific chest container.
## If deposit_all_cb is provided, shows a "Deposit All" button that calls it.
## chest_key is used for multiplayer sync of interior chest inventories.
func open_for(container: ContainerInventory, title: String = "Storage Chest",
			  deposit_all_cb: Callable = Callable(), chest_key: String = "") -> void:
	# Disconnect from previous container first if it's different
	if _container != null and _container != container:
		if _container.changed.is_connected(_on_container_changed):
			_container.changed.disconnect(_on_container_changed)

	_container = container
	_chest_key = chest_key

	# Safely connect — avoid "already connected" errors
	if not _container.changed.is_connected(_on_container_changed):
		_container.changed.connect(_on_container_changed)
	if not InventoryManager.changed.is_connected(_on_player_inventory_changed):
		InventoryManager.changed.connect(_on_player_inventory_changed)

	_deposit_all_callback = deposit_all_cb

	is_open = true
	dim.visible = true
	panel.visible = true

	# Update the title
	var title_label: Label = %TitleLabel as Label
	if title_label:
		title_label.text = title

	# Show or hide the "Deposit All" button
	_update_deposit_all_button()

	# Multiplayer: request latest chest data from host
	if NetworkManager.is_network_active() and not multiplayer.is_server() and chest_key != "":
		GameManager.request_chest_data(chest_key)

	UITweenHelper.animate_open(panel, 0.25, 20.0)
	refresh()


func close() -> void:
	if not is_open:
		return
	is_open = false
	_deposit_all_callback = Callable()

	# Multiplayer: sync chest contents to host
	if NetworkManager.is_network_active() and _chest_key != "" and _container != null:
		GameManager.sync_chest_on_close(_chest_key, _container.slots)

	if _container and _container.changed.is_connected(_on_container_changed):
		_container.changed.disconnect(_on_container_changed)
	if InventoryManager.changed.is_connected(_on_player_inventory_changed):
		InventoryManager.changed.disconnect(_on_player_inventory_changed)

	UITweenHelper.animate_close(panel, 0.2, 20.0, func():
		dim.visible = false
		panel.visible = false
		if not is_open:
			_container = null
	)


func refresh() -> void:
	if not is_open:
		return
	_refresh_chest_contents()
	_refresh_player_contents()


func _refresh_chest_contents() -> void:
	_clear(chest_list)
	if not _container:
		chest_list.add_child(_hint_label("No chest connected."))
		return

	var counts := _container.get_all_counts()
	if counts.is_empty():
		chest_list.add_child(_hint_label("Empty"))
		return

	var ids := counts.keys()
	ids.sort()
	for item_id in ids:
		var item: ItemData = DataManager.get_item(item_id)
		if not item:
			continue
		var count: int = counts[item_id]
		chest_list.add_child(_build_chest_row(item, count))


func _refresh_player_contents() -> void:
	_clear(player_list)
	var counts := InventoryManager.get_all_counts()
	if counts.is_empty():
		player_list.add_child(_hint_label("Empty"))
		return

	var ids := counts.keys()
	ids.sort()
	for item_id in ids:
		var item: ItemData = DataManager.get_item(item_id)
		if not item:
			continue
		var count: int = counts[item_id]
		player_list.add_child(_build_player_row(item, count))


## Row showing a chest item with [Take 1] and [Take All] buttons.
func _build_chest_row(item: ItemData, count: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = "%s x%d" % [item.display_name, count]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	row.add_child(label)

	var take_one := Button.new()
	take_one.text = "Take 1"
	var item_id := item.id
	take_one.pressed.connect(func():
		_transfer_to_player(item_id, 1)
	)
	row.add_child(take_one)

	var take_all := Button.new()
	take_all.text = "Take All"
	take_all.pressed.connect(func():
		_transfer_to_player(item_id, count)
	)
	row.add_child(take_all)

	return row


## Row showing a player item with [Store 1] and [Store All] buttons.
func _build_player_row(item: ItemData, count: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = "%s x%d" % [item.display_name, count]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	row.add_child(label)

	var store_one := Button.new()
	store_one.text = "Store 1"
	var item_id := item.id
	store_one.pressed.connect(func():
		_transfer_to_chest(item_id, 1)
	)
	row.add_child(store_one)

	var store_all := Button.new()
	store_all.text = "Store All"
	store_all.pressed.connect(func():
		_transfer_to_chest(item_id, count)
	)
	row.add_child(store_all)

	return row


func _transfer_to_player(item_id: String, amount: int) -> void:
	if not _container:
		return
	if _container.remove_item(item_id, amount):
		var remaining := InventoryManager.add_item(item_id, amount)
		# If some didn't fit player inventory, put it back in the chest
		if remaining > 0:
			_container.add_item(item_id, remaining)
			ToastNotification.show_toast(
				"Not enough room in your inventory!",
				ToastNotification.ToastType.WARNING,
				2.0
			)
		refresh()


func _transfer_to_chest(item_id: String, amount: int) -> void:
	if not _container:
		return
	if InventoryManager.remove_item(item_id, amount):
		var remaining := _container.add_item(item_id, amount)
		# If some didn't fit chest, put it back in player inventory
		if remaining > 0:
			InventoryManager.add_item(item_id, remaining)
			ToastNotification.show_toast(
				"Chest is full!",
				ToastNotification.ToastType.WARNING,
				2.0
			)
		refresh()


func _on_container_changed() -> void:
	if is_open:
		refresh()


func _on_player_inventory_changed() -> void:
	if is_open:
		refresh()


func _on_close_pressed() -> void:
	AudioManager.play(AudioManager.Sound.CHEST_CLOSE)
	close()


func _clear(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()


func _hint_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.modulate = Color(1.0, 1.0, 1.0, 0.7)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	return label


## Shows or hides the "Deposit All" button at the bottom of the UI.
func _update_deposit_all_button() -> void:
	if _deposit_all_button != null:
		_deposit_all_button.queue_free()
		_deposit_all_button = null

	if not _deposit_all_callback.is_valid():
		return

	_deposit_all_button = Button.new()
	_deposit_all_button.text = "Deposit All Crops"
	_deposit_all_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_deposit_all_button.pressed.connect(_on_deposit_all_pressed)
	# Insert the button right before the CloseButton in the layout
	var layout := %TitleLabel.get_parent().get_parent()  # Layout VBoxContainer
	var close_btn_idx: int = layout.get_child_count() - 1  # CloseButton is last
	layout.add_child(_deposit_all_button)
	layout.move_child(_deposit_all_button, close_btn_idx)


func _on_deposit_all_pressed() -> void:
	if _deposit_all_callback.is_valid():
		_deposit_all_callback.call()
		refresh()
