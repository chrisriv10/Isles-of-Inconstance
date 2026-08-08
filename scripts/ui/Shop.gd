extends CanvasLayer

## NPC shop overlay opened by interacting with the Merchant ShopStand in the
## world. Requires proximity to the shop NPC to open.
##
## Three sections:
##   Seeds       - buy seed_item(s) for any discovered crop within the
##                 player's current "Seed Vault Access" rarity tier.
##   Legendary   - buy Inconstant Fruits (extremely rare, ludicrously expensive)
##   Upgrades    - buy the next level of Storage Satchel / Tool Forge /
##                 Green Thumb / Seed Vault Access (this doubles as "buy
##                 tools", since this project only has the hoe & watering can
##                 and upgrading their tier *is* buying a better tool).
## NOTE: Selling is done at the Boat, not here.

@onready var dim: ColorRect = $Dim
@onready var panel: PanelContainer = $Panel
@onready var title_label: Label = %TitleLabel
@onready var coins_label: Label = %CoinsLabel
@onready var seeds_list: VBoxContainer = %SeedsList
@onready var pets_list: VBoxContainer = %PetsList
@onready var upgrades_list: VBoxContainer = %UpgradesList
@onready var sections_container: VBoxContainer = %Sections
var legendary_header: Label
var legendary_list: VBoxContainer

## Luxuries: expensive decorative items sold as coin sinks.
## Each entry: { "item_id": String, "price": int }
var _luxury_items: Array = [
	{"item_id": "decorative_fountain_kit", "price": 250},
	{"item_id": "decorative_statue_kit", "price": 500},
	{"item_id": "decorative_lantern_kit", "price": 120},
	{"item_id": "decorative_bench_kit", "price": 80},
	{"item_id": "decorative_sign_kit", "price": 50},
]
var _luxury_header: Label
var _luxury_list: VBoxContainer

## Custom expedition merchant items, set via open_with_items().
## Each entry: { "item_id": String, "price": int, "stock": int }
var _expedition_items: Array = []
var _expedition_header: Label
var _expedition_list: VBoxContainer

var is_open: bool = false

func _ready() -> void:
	GameManager.money_changed.connect(_on_money_changed)
	InventoryManager.changed.connect(_on_inventory_changed)
	DataManager.crop_discovered.connect(_on_crop_discovered)
	UpgradeManager.upgrade_purchased.connect(_on_upgrade_purchased)
	# Build dynamic sections
	_build_legendary_section()
	_build_expedition_section()
	_build_luxury_section()

func _unhandled_input(event: InputEvent) -> void:
	if is_open and event.is_action_pressed("close_menu"):
		close()
		get_viewport().set_input_as_handled()

func toggle() -> void:
	if is_open:
		close()
	else:
		open()

## Open the shop normally (seeds, pets, upgrades).
func open() -> void:
	_expedition_items.clear()
	_open_common()

## Open the shop with custom expedition merchant items.
## items: Array of { "item_id": String, "price": int, "stock": int }
## title: optional custom shop title
func open_with_items(items: Array, title: String = "") -> void:
	_expedition_items = items.duplicate()
	_open_common()
	if not title.is_empty():
		title_label.text = title

func _open_common() -> void:
	is_open = true
	AudioManager.play(AudioManager.Sound.MENU_OPEN)
	AudioManager.play_music(AudioManager.Sound.SHOP_THEME)
	dim.visible = true
	panel.visible = true
	
	# Add smooth slide + fade animation with sound
	UITweenHelper.animate_open(panel, 0.25, 20.0)
	
	refresh()

func close() -> void:
	is_open = false
	AudioManager.play(AudioManager.Sound.MENU_CLOSE)
	AudioManager.restore_ambient_if(AudioManager.Sound.SHOP_THEME)
	
	# Animate out before hiding
	UITweenHelper.animate_close(panel, 0.2, 20.0, func(): 
		dim.visible = false
		panel.visible = false
	)

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
	_refresh_legendary()
	_refresh_pets()
	_refresh_upgrades()
	_refresh_luxury()
	_refresh_expedition_items()

func _clear(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()

# ---------------------------------------------------------------------------
# Legendary Finds (Inconstant Fruits)
# ---------------------------------------------------------------------------

## Creates the legendary finds UI section (header + list) at the bottom.
func _build_legendary_section() -> void:
	legendary_header = Label.new()
	legendary_header.text = "Legendary Finds"
	legendary_header.add_theme_font_size_override("font_size", 18)
	legendary_header.add_theme_color_override("font_color", Color(1.0, 0.6, 0.0, 1.0))
	sections_container.add_child(legendary_header)
	legendary_header.visible = false

	legendary_list = VBoxContainer.new()
	sections_container.add_child(legendary_list)
	legendary_list.visible = false

## Refresh the legendary finds section with available Inconstant Fruits.
## Only shows fruits that the player can afford (or wants to save for).
func _refresh_legendary() -> void:
	_clear(legendary_list)
	# Find Inconstant Fruits in the item registry
	var shown := false
	for item in DataManager.items.values():
		if not item or not item.get_meta("inconstant_power", false):
			continue
		if item.buy_price <= 0:
			continue
		shown = true
		var fruit_item: ItemData = item
		legendary_list.add_child(_build_row(
			fruit_item.display_name,
			"$%d" % fruit_item.buy_price,
			"Buy",
			func(): _buy_inconstant_fruit(fruit_item),
			DataManager.make_item_icon(fruit_item.category, fruit_item.id, fruit_item.display_name)
		))
		# Show a hint about the power
		var power_name: String = fruit_item.get_meta("power_name", "?")
		var hint := RichTextLabel.new()
		hint.text = "Power: [b]%s[/b]" % power_name
		hint.bbcode_enabled = true
		hint.fit_content = true
		hint.modulate = Color(1.0, 0.8, 0.3, 0.9)
		hint.add_theme_font_size_override("font_size", 13)
		legendary_list.add_child(hint)
	legendary_header.visible = shown
	legendary_list.visible = shown

func _buy_inconstant_fruit(fruit_item: ItemData) -> void:
	if GameManager.spend_money(fruit_item.buy_price):
		InventoryManager.add_item(fruit_item.id, 1)
		AudioManager.play(AudioManager.Sound.BUY)
		ToastNotification.show_toast("Legends whisper of the %s!" % fruit_item.display_name, ToastNotification.ToastType.SUCCESS)
		refresh()
	else:
		ToastNotification.show_toast("Even this fortune pales before the cost...", ToastNotification.ToastType.ERROR)

# ---------------------------------------------------------------------------
# Seeds
# ---------------------------------------------------------------------------

const RARITY_NUM_TIERS := 5

const RARITY_SUB_NAMES := ["Common", "Uncommon", "Rare", "Epic", "Legendary"]

const RARITY_SUB_COLORS := [
	Color(0.6, 0.85, 0.6),   # Common  - green
	Color(0.55, 0.8, 1.0),   # Uncommon - blue
	Color(0.45, 0.55, 1.0),  # Rare    - indigo
	Color(0.9, 0.5, 1.0),    # Epic    - purple
	Color(1.0, 0.75, 0.25),  # Legendary - gold
]

func _refresh_seeds() -> void:
	_clear(seeds_list)
	var max_tier := UpgradeManager.get_max_purchasable_rarity_tier()
	var crops: Array[CropData] = DataManager.get_discovered_crops()
	crops.sort_custom(func(a, b): return a.display_name < b.display_name)

	# Group discovered, purchasable seeds by rarity tier.
	var tiers: Array = []
	for i in RARITY_NUM_TIERS:
		tiers.append([])
	for crop in crops:
		if crop.seed_item_id == "":
			continue
		var seed_item: ItemData = DataManager.get_item(crop.seed_item_id)
		if not seed_item or seed_item.buy_price <= 0:
			continue
		var rarity_tier: int = crop.genetics.rarity_tier if crop.genetics else 0
		rarity_tier = clampi(rarity_tier, 0, RARITY_NUM_TIERS - 1)
		tiers[rarity_tier].append([crop, seed_item])

	var any_shown := false
	var locked_hinted := false
	for t in RARITY_NUM_TIERS:
		if t <= max_tier:
			if tiers[t].is_empty():
				continue
			any_shown = true
			seeds_list.add_child(_sub_header(RARITY_SUB_NAMES[t] + " Seeds", RARITY_SUB_COLORS[t]))
			for pair in tiers[t]:
				var crop: CropData = pair[0]
				var seed_item: ItemData = pair[1]
				seeds_list.add_child(_build_row(
					crop.display_name + " Seed",
					"$%d" % seed_item.buy_price,
					"Buy",
					func(): _buy_seed(seed_item),
					_seed_icon(seed_item)
				))
		elif not locked_hinted:
			# Show ONE greyed-out "next unlock" so raising the Seed Vault (all
			# the way to the last level) visibly grants a new rarity tier.
			locked_hinted = true
			var locked := _hint_label("🔒 %s seeds locked — upgrade Seed Vault to Lv %d" % [RARITY_SUB_NAMES[t], t])
			locked.modulate = Color(0.6, 0.6, 0.6, 1.0)
			seeds_list.add_child(locked)

	if not any_shown and not locked_hinted:
		seeds_list.add_child(_hint_label(
			"Grow and harvest a crop to unlock it here." if crops.is_empty()
			else "Buy Seed Vault Access below to unlock rarer seeds."
		))

func _buy_seed(seed_item: ItemData) -> void:
	if GameManager.spend_money(seed_item.buy_price):
		InventoryManager.add_item(seed_item.id, 1)
		AudioManager.play(AudioManager.Sound.BUY)
		ToastNotification.show_toast("Bought %s!" % seed_item.display_name, ToastNotification.ToastType.SUCCESS)
		refresh()
	else:
		ToastNotification.show_toast("Not enough coins!", ToastNotification.ToastType.ERROR)

# ---------------------------------------------------------------------------
# Pets
# ---------------------------------------------------------------------------

func _refresh_pets() -> void:
	_clear(pets_list)
	var pet_egg_ids := ["cat_egg", "dog_egg", "fox_egg", "bird_egg", "turtle_egg", "rabbit_egg", "ice_cream_sandwich_egg", "gingerbread_man_egg"]
	var shown := false
	for egg_id in pet_egg_ids:
		var egg: ItemData = DataManager.get_item(egg_id)
		if not egg or egg.buy_price <= 0:
			continue
		var pet_id: String = egg_id.trim_suffix("_egg")
		if PetManager.has_pet(pet_id):
			continue  # already owned
		shown = true
		var egg_icon: Texture2D = egg.icon if egg.icon else DataManager.make_item_icon(egg.category, egg.id, egg.display_name)
		pets_list.add_child(_build_row(
			egg.display_name,
			"$%d" % egg.buy_price,
			"Buy",
			func(): _buy_pet_egg(egg),
			egg_icon
		))
	if not shown:
		pets_list.add_child(_hint_label("All pets have been adopted! Check your pet menu."))

func _buy_pet_egg(egg: ItemData) -> void:
	if GameManager.spend_money(egg.buy_price):
		InventoryManager.add_item(egg.id, 1)
		AudioManager.play(AudioManager.Sound.BUY)
		ToastNotification.show_toast("Bought %s! Use it in inventory to hatch." % egg.display_name, ToastNotification.ToastType.SUCCESS)
		refresh()
	else:
		ToastNotification.show_toast("Not enough coins!", ToastNotification.ToastType.ERROR)

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

		var row := _build_row(name_text, cost_text, "Buy", func(): _buy_upgrade(upgrade), _upgrade_icon(upgrade))
		var button := row.get_child(row.get_child_count() - 1)
		if button is Button:
			button.disabled = maxed
		upgrades_list.add_child(row)

		var desc := Label.new()
		desc.text = UpgradeManager.get_description(upgrade)
		desc.add_theme_font_size_override("font_size", 13)
		desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.8))
		upgrades_list.add_child(desc)

func _buy_upgrade(upgrade: int) -> void:
	var success := UpgradeManager.purchase(upgrade)
	if success:
		var upgrade_name := UpgradeManager.get_upgrade_name(upgrade)
		var level := UpgradeManager.get_level(upgrade)
		ToastNotification.show_toast("%s upgraded to Lv %d!" % [upgrade_name, level], ToastNotification.ToastType.SUCCESS)
	else:
		if UpgradeManager.is_maxed(upgrade):
			ToastNotification.show_toast("Already at max level!", ToastNotification.ToastType.INFO)
		else:
			ToastNotification.show_toast("Not enough coins!", ToastNotification.ToastType.ERROR)
	refresh()

# ---------------------------------------------------------------------------
# Row helper
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Expedition merchant items
# ---------------------------------------------------------------------------

## Build the expedition merchant section (hidden by default).
func _build_expedition_section() -> void:
	_expedition_header = Label.new()
	_expedition_header.text = "Expedition Wares"
	_expedition_header.add_theme_font_size_override("font_size", 18)
	_expedition_header.add_theme_color_override("font_color", Color(0.4, 0.9, 0.6, 1.0))
	sections_container.add_child(_expedition_header)
	_expedition_header.visible = false

	_expedition_list = VBoxContainer.new()
	sections_container.add_child(_expedition_list)
	_expedition_list.visible = false

## Refresh the expedition merchant item listings.
func _refresh_expedition_items() -> void:
	_clear(_expedition_list)
	if _expedition_items.is_empty():
		_expedition_header.visible = false
		_expedition_list.visible = false
		return

	_expedition_header.visible = true
	_expedition_list.visible = true

	for entry in _expedition_items:
		var item_id: String = entry.get("item_id", "")
		var price: int = entry.get("price", 1)
		var stock: int = entry.get("stock", 1)
		if item_id.is_empty():
			continue

		var item_def = DataManager.get_item(item_id)
		var item_name: String = item_def.display_name if item_def else item_id.replace("_", " ").capitalize()

		_expedition_list.add_child(_build_row(
			"%s (x%d)" % [item_name, stock],
			"$%d" % price,
			"Buy",
			func(): _buy_expedition_item(item_id, price),
			DataManager.make_item_icon(item_def.category if item_def else "misc", item_id, item_name)
		))

func _buy_expedition_item(item_id: String, price: int) -> void:
	if GameManager.spend_money(price):
		InventoryManager.add_item(item_id, 1)
		AudioManager.play(AudioManager.Sound.BUY)
		var item_def = DataManager.get_item(item_id)
		var item_name: String = item_def.display_name if item_def else item_id.replace("_", " ").capitalize()
		ToastNotification.show_toast("Bought %s!" % item_name, ToastNotification.ToastType.SUCCESS)
		refresh()
	else:
		ToastNotification.show_toast("Not enough coins!", ToastNotification.ToastType.ERROR)

# ---------------------------------------------------------------------------
# Luxuries (expensive decorative coin sinks)
# ---------------------------------------------------------------------------

## Build the luxury section header + list (hidden by default).
func _build_luxury_section() -> void:
	_luxury_header = Label.new()
	_luxury_header.text = "Luxuries"
	_luxury_header.add_theme_font_size_override("font_size", 18)
	_luxury_header.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3, 1.0))
	sections_container.add_child(_luxury_header)
	_luxury_header.visible = false

	_luxury_list = VBoxContainer.new()
	sections_container.add_child(_luxury_list)
	_luxury_list.visible = false

## Refresh the luxury listing with expensive decorative items.
func _refresh_luxury() -> void:
	_clear(_luxury_list)
	_luxury_header.visible = false
	_luxury_list.visible = false
	var shown := false
	for entry in _luxury_items:
		var item_id: String = entry.get("item_id", "")
		var price: int = entry.get("price", 1)
		if item_id.is_empty():
			continue
		var item_def = DataManager.get_item(item_id)
		var item_name: String = item_def.display_name if item_def else item_id.replace("_", " ").capitalize()
		shown = true
		_luxury_list.add_child(_build_row(
			item_name,
			"$%d" % price,
			"Buy",
			func(): _buy_luxury(item_id, price),
			DataManager.make_item_icon(item_def.category if item_def else "misc", item_id, item_name)
		))
	_luxury_header.visible = shown
	_luxury_list.visible = shown

func _buy_luxury(item_id: String, price: int) -> void:
	if GameManager.spend_money(price):
		InventoryManager.add_item(item_id, 1)
		AudioManager.play(AudioManager.Sound.BUY)
		var item_def = DataManager.get_item(item_id)
		var item_name: String = item_def.display_name if item_def else item_id.replace("_", " ").capitalize()
		ToastNotification.show_toast("Enjoy your %s!" % item_name, ToastNotification.ToastType.SUCCESS)
		refresh()
	else:
		ToastNotification.show_toast("Not enough coins!", ToastNotification.ToastType.ERROR)

# ---------------------------------------------------------------------------
# Row helper
# ---------------------------------------------------------------------------

func _build_row(left_text: String, price_text: String, button_text: String, on_pressed: Callable, icon: Texture2D = null) -> HBoxContainer:
	var row := HBoxContainer.new()

	if icon:
		var texrect := TextureRect.new()
		texrect.texture = icon
		texrect.custom_minimum_size = Vector2(20, 20)
		texrect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		texrect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texrect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(texrect)

	var label := Label.new()
	label.text = left_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	row.add_child(label)

	var price := Label.new()
	price.text = price_text
	price.add_theme_font_size_override("font_size", 14)
	price.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
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

## A colored sub-section header used to group shop items into categories
## (e.g. "Rare Seeds" under the Seeds list).
func _sub_header(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", color)
	return label

## Load a bespoke icon PNG, falling back to a direct disk decode for assets
## that haven't been imported into the editor cache yet.
static func _load_icon(path: String) -> Texture2D:
	if path == "":
		return null
	if ResourceLoader.exists(path):
		return load(path)
	return DataManager._load_unimported_png(path)

## Icon for a seed row: use the seed's own generated icon, else a procedural one.
func _seed_icon(seed_item: ItemData) -> Texture2D:
	if seed_item.icon:
		return seed_item.icon
	return DataManager.make_item_icon("seed", seed_item.id, seed_item.display_name)

## Bespoke icon for each upgrade level listing (upgrades aren't items, so they
## get hand-made pixel icons rather than a procedural item icon).
static func _upgrade_icon(upgrade: int) -> Texture2D:
	var slug: String
	match upgrade:
		UpgradeManager.Upgrade.INVENTORY: slug = "satchel"
		UpgradeManager.Upgrade.TOOLS: slug = "tool_forge"
		UpgradeManager.Upgrade.FARMING_SPEED: slug = "green_thumb"
		UpgradeManager.Upgrade.RARE_SEEDS: slug = "seed_vault"
		UpgradeManager.Upgrade.COMBAT: slug = "combat"
		UpgradeManager.Upgrade.LUCK: slug = "luck"
		_: return null
	return _load_icon("res://assets/generated/icon_upgrade_" + slug + "_frame_0.png")
