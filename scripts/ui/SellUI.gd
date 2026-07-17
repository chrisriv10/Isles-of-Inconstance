extends CanvasLayer

## Sell overlay opened by interacting with the Boat. Shows all sellable
## inventory items (non-seeds) and lets the player sell them for coins.

@onready var dim: ColorRect = $Dim
@onready var panel: PanelContainer = $Panel
@onready var coins_label: Label = %CoinsLabel
@onready var sell_list: VBoxContainer = %SellList

var is_open: bool = false

func _ready() -> void:
	GameManager.money_changed.connect(_on_money_changed)
	InventoryManager.changed.connect(_on_inventory_changed)

func _unhandled_input(event: InputEvent) -> void:
	if is_open and event.is_action_pressed("close_menu"):
		close()
		get_viewport().set_input_as_handled()

func open() -> void:
	is_open = true
	dim.visible = true
	panel.visible = true
	UITweenHelper.animate_open(panel, 0.25, 20.0)
	refresh()

func close() -> void:
	is_open = false
	UITweenHelper.animate_close(panel, 0.2, 20.0, func():
		dim.visible = false
		panel.visible = false
	)

func refresh() -> void:
	coins_label.text = "$%d" % GameManager.money
	_clear(sell_list)
	var counts := InventoryManager.get_all_counts()
	var ids := counts.keys()
	ids.sort()

	var shown := false
	for item_id in ids:
		var item := DataManager.get_item(item_id)
		if not item or item.category == "seed" or item.sell_price <= 0:
			continue
		var count: int = counts[item_id]
		shown = true
		sell_list.add_child(_build_row(
			"%s x%d" % [item.display_name, count],
			"$%d each" % item.sell_price,
			"Sell All",
			func(): _sell_item(item_id, count)
		))

	if not shown:
		sell_list.add_child(_hint_label("Nothing to sell yet – go harvest or gather something!"))

func _sell_item(item_id: String, count: int) -> void:
	var item := DataManager.get_item(item_id)
	if not item:
		return
	if InventoryManager.remove_item(item_id, count):
		GameManager.add_money(item.sell_price * count)
		ToastNotification.show_toast("Sold %d %s for $%d!" % [count, item.display_name, item.sell_price * count], ToastNotification.ToastType.SUCCESS)
		refresh()

func _on_money_changed(_amount: int) -> void:
	if is_open:
		coins_label.text = "$%d" % GameManager.money

func _on_inventory_changed() -> void:
	if is_open:
		refresh()

func _on_close_pressed() -> void:
	close()

func _clear(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()

func _build_row(left_text: String, price_text: String, button_text: String, on_pressed: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = left_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var price := Label.new()
	price.text = price_text
	row.add_child(price)
	var button := Button.new()
	button.text = button_text
	button.pressed.connect(on_pressed)
	row.add_child(button)
	return row

func _hint_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.modulate = Color(1.0, 1.0, 1.0, 0.7)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	return label
