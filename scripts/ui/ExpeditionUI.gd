extends CanvasLayer
class_name ExpeditionUI

## Expedition selection UI opened by interacting with Captain Briggs (TravelBoat)
## at the dock. Offers two options:
##   1. Random island for a cheap fee ($50)
##   2. Pick a specific island type for a more expensive fee ($200)

const RANDOM_FEE: int = 50
const SPECIFIC_FEE: int = 200

## Island type data for display
const ISLAND_INFO: Array = [
	{ "type": 0, "name": "Plain", "desc": "A familiar grassy island with gentle hills", "color": Color(0.45, 0.72, 0.32) },
	{ "type": 1, "name": "Snowland", "desc": "A frosty snow-covered island", "color": Color(0.75, 0.80, 0.88) },
	{ "type": 2, "name": "Ice Cream Land", "desc": "A sweet candy-filled island", "color": Color(0.95, 0.75, 0.85) },
	{ "type": 3, "name": "Desert", "desc": "A scorching desert island", "color": Color(0.80, 0.70, 0.40) },
	{ "type": 4, "name": "Volcanic", "desc": "A fiery volcanic island", "color": Color(0.50, 0.30, 0.25) },
	{ "type": 5, "name": "Ethereal", "desc": "A mystical ethereal island", "color": Color(0.60, 0.40, 0.75) },
]

@onready var dim: ColorRect = $Dim
@onready var panel: PanelContainer = $Panel
@onready var coins_label: Label = %CoinsLabel
@onready var coins_label2: Label = %CoinsLabel2
@onready var island_list: VBoxContainer = %IslandList
@onready var random_button: Button = %RandomButton

var is_open: bool = false

func _ready() -> void:
	GameManager.money_changed.connect(_on_money_changed)

func _unhandled_input(event: InputEvent) -> void:
	if is_open and event.is_action_pressed("close_menu"):
		close()
		get_viewport().set_input_as_handled()

func open() -> void:
	is_open = true
	visible = true
	AudioManager.play(AudioManager.Sound.MENU_OPEN)
	dim.visible = true
	panel.visible = true

	UITweenHelper.animate_open(panel, 0.25, 20.0)
	_refresh()

func close() -> void:
	is_open = false
	AudioManager.play(AudioManager.Sound.MENU_CLOSE)
	UITweenHelper.animate_close(panel, 0.2, 20.0, func():
		visible = false
		dim.visible = false
		panel.visible = false
	)

func _on_money_changed(_amount: int) -> void:
	if is_open:
		_refresh()

func _refresh() -> void:
	coins_label.text = "$%d" % GameManager.money
	coins_label2.text = "$%d" % GameManager.money

	# Update random button state
	random_button.disabled = not GameManager.can_afford(RANDOM_FEE)
	if GameManager.can_afford(RANDOM_FEE):
		random_button.text = "Random Expedition ($%d)" % RANDOM_FEE
	else:
		random_button.text = "Random Expedition ($%d) — Not Enough Coins" % RANDOM_FEE

	# Rebuild island list
	_build_island_list()

func _build_island_list() -> void:
	# Clear existing buttons (keep the header)
	for child in island_list.get_children():
		child.queue_free()

	for info in ISLAND_INFO:
		var row: HBoxContainer = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_FILL
		row.add_theme_constant_override("separation", 8)

		# Color swatch
		var swatch: ColorRect = ColorRect.new()
		swatch.custom_minimum_size = Vector2(24, 24)
		swatch.size = Vector2(24, 24)
		swatch.color = info["color"]
		row.add_child(swatch)

		# Name and description
		var vbox: VBoxContainer = VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.add_theme_constant_override("separation", 1)

		var name_label: Label = Label.new()
		name_label.text = info["name"]
		name_label.add_theme_font_size_override("font_size", 12)
		name_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7, 1.0))
		vbox.add_child(name_label)

		var desc_label: Label = Label.new()
		desc_label.text = info["desc"]
		desc_label.add_theme_font_size_override("font_size", 9)
		desc_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.55, 0.8))
		vbox.add_child(desc_label)

		row.add_child(vbox)

		# Buy button
		var buy_btn: Button = Button.new()
		buy_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		buy_btn.custom_minimum_size = Vector2(80, 32)
		var can_buy: bool = GameManager.can_afford(SPECIFIC_FEE)
		buy_btn.disabled = not can_buy
		buy_btn.text = "$%d" % SPECIFIC_FEE

		buy_btn.pressed.connect(_on_specific_island_pressed.bind(info["type"]))

		# Add button sound
		ButtonSound.add_to_button(buy_btn)

		row.add_child(buy_btn)
		island_list.add_child(row)

func _on_random_pressed() -> void:
	if not GameManager.can_afford(RANDOM_FEE):
		ToastNotification.show_toast("Need $%d for a random expedition!" % RANDOM_FEE, ToastNotification.ToastType.ERROR, 3.0)
		return

	GameManager.spend_money(RANDOM_FEE)
	AudioManager.play(AudioManager.Sound.BOAT_TRAVEL)
	close()

	var world: Node = get_tree().get_first_node_in_group("world")
	if world and world.has_method("travel_to_island"):
		world.travel_to_island()
	else:
		push_error("ExpeditionUI: Could not find world with travel_to_island()")

func _on_specific_island_pressed(type_val: int) -> void:
	if not GameManager.can_afford(SPECIFIC_FEE):
		ToastNotification.show_toast("Need $%d to choose your destination!" % SPECIFIC_FEE, ToastNotification.ToastType.ERROR, 3.0)
		return

	GameManager.spend_money(SPECIFIC_FEE)
	AudioManager.play(AudioManager.Sound.BOAT_TRAVEL)
	close()

	var world: Node = get_tree().get_first_node_in_group("world")
	if world and world.has_method("travel_to_island_with_type"):
		world.travel_to_island_with_type(type_val)
	else:
		push_error("ExpeditionUI: Could not find world with travel_to_island_with_type()")

func _on_close_pressed() -> void:
	close()
