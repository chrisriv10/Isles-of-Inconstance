extends CanvasLayer

## Simple always-available shop overlay (toggle with [B]). Not tied to a
## physical shopkeeper yet - see the summary notes for how to turn this into
## an NPC-triggered panel later if desired.
##
## Three sections, matching the requested Shop features:
##   Seeds     - buy seed_item(s) for any discovered crop within the
##               player's current "Seed Vault Access" rarity tier.
##   Sell      - sell any harvested crop or gathered resource for coins.
##   Upgrades  - buy the next level of Storage Satchel / Tool Forge /
##               Green Thumb / Seed Vault Access (this doubles as "buy
##               tools", since this project only has the hoe & watering can
##               and upgrading their tier *is* buying a better tool).

@onready var dim: ColorRect = $Dim
@onready var panel: Panel = $Panel
@onready var coins_label: Label = %CoinsLabel
@onready var seeds_list: VBoxContainer = %SeedsList
@onready var sell_list: VBoxContainer = %SellList
@onready var upgrades_list: VBoxContainer = %UpgradesList

var is_open: bool = false

func _ready() -> void:
	GameManager.money_changed.connect(_on_money_changed)
	InventoryManager.changed.connect(_on_inventory_changed)
	DataManager.crop_discovered.connect(_on_crop_discovered)
	UpgradeManager.upgrade_purchased.connect(_on_upgrade_purchased)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_shop"):
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
	refresh()

func close() -> void:
	is_open = false
	dim.visible = false
	panel.visible = false

func _on_close_pressed() -> void:
	close()

func _on_money_changed(_amount: int) -> void:
	if is_open:
		coins_label.text = "$%d" % GameManager.money

func _on_inventory_changed() -> void:
	if is_open:
		refresh()

func _on_crop_discovered(_crop_id: String) -> void:
	if is_open:
		refresh()

func _on_upgrade_purchased(_upgrade: int, _level: int) -> void:
	if is_open:
		refresh()

func refresh() -> void:
	coins_label.text = "$%d" % GameManager.money
	_refresh_seeds()
	_refresh_sell()
	_refresh_upgrades()

func _clear(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()

# ---------------------------------------------------------------------------
# Seeds
# ---------------------------------------------------------------------------

func _refresh_seeds() -> void:
	_clear(seeds_list)
	var max_tier := UpgradeManager.get_max_purchasable_rarity_tier()
	var crops := DataManager.get_discovered_crops()
	crops.sort_custom(func(a, b): return a.display_name < b.display_name)

	var shown := false
	for crop in crops:
		if crop.seed_item_id == "":
			continue
		var seed_item := DataManager.get_item(crop.seed_item_id)
		if not seed_item or seed_item.buy_price <= 0:
			continue
		var rarity_tier: int = crop.genetics.rarity_tier if crop.genetics else 0
		if rarity_tier > max_tier:
			continue
		shown = true
		seeds_list.add_child(_build_row(
			"%s Seed (%s)" % [crop.display_name, crop.rarity],
			"$%d" % seed_item.buy_price,
			"Buy",
			func(): _buy_seed(seed_item)
		))

	if not shown:
		seeds_list.add_child(_hint_label(
			"Grow and harvest a crop to unlock it here." if crops.is_empty()
			else "Buy Seed Vault Access below to unlock rarer seeds."
		))

func _buy_seed(seed_item: ItemData) -> void:
	if GameManager.spend_money(seed_item.buy_price):
		InventoryManager.add_item(seed_item.id, 1)
		refresh()

# ---------------------------------------------------------------------------
# Sell
# ---------------------------------------------------------------------------

func _refresh_sell() -> void:
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
		sell_list.add_child(_hint_label("Nothing to sell yet - go harvest or gather something!"))

func _sell_item(item_id: String, count: int) -> void:
	var item := DataManager.get_item(item_id)
	if not item:
		return
	if InventoryManager.remove_item(item_id, count):
		GameManager.add_money(item.sell_price * count)
		refresh()

# ---------------------------------------------------------------------------
# Upgrades (also where tool purchases live - see class doc comment above)
# ---------------------------------------------------------------------------

func _refresh_upgrades() -> void:
	_clear(upgrades_list)
	for upgrade in UpgradeManager.Upgrade.values():
		var level := UpgradeManager.get_level(upgrade)
		var maxed := UpgradeManager.is_maxed(upgrade)
		var name_text := "%s (Lv %d/%d)" % [UpgradeManager.get_upgrade_name(upgrade), level, UpgradeManager.MAX_LEVEL]
		var cost_text := "MAXED" if maxed else "$%d" % UpgradeManager.get_cost(upgrade)

		var row := _build_row(name_text, cost_text, "Buy", func(): _buy_upgrade(upgrade))
		var button := row.get_child(row.get_child_count() - 1)
		if button is Button:
			button.disabled = maxed
		upgrades_list.add_child(row)

		var desc := Label.new()
		desc.text = UpgradeManager.get_description(upgrade)
		desc.add_theme_font_size_override("font_size", 11)
		desc.modulate = Color(1.0, 1.0, 1.0, 0.7)
		upgrades_list.add_child(desc)

func _buy_upgrade(upgrade: int) -> void:
	UpgradeManager.purchase(upgrade)
	refresh()

# ---------------------------------------------------------------------------
# Row helper
# ---------------------------------------------------------------------------

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
