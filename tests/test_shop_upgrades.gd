extends Node

## Guards recent Shop / upgrade fixes:
##   1. Every Tool Forge level must widen the hoe/watering-can area (Lv1 was
##      previously identical to Lv0 — a paid upgrade that did nothing).
##   2. Green Thumb must actually feed into the tool cooldown.
##   3. Shop: seed list must group by rarity sub-sections, and rows must carry
##      an icon plus have pet eggs as their own section.

func _file_contains(path: String, needle: String) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		printerr("  FAIL: cannot open " + path)
		return false
	var t := f.get_as_text()
	f.close()
	return t.contains(needle)

func test_tool_forge_level1_grants_area() -> void:
	assert(_file_contains("res://scripts/autoload/UpgradeManager.gd", "1: size = 2"), \
		"Tool Forge Lv1 must widen tool area to 2x2 (was 1x1/no effect)")
	assert(_file_contains("res://scripts/autoload/UpgradeManager.gd", "4: size = 5"), \
		"Tool Forge Lv4 must be 5x5")

func test_green_thumb_feeds_cooldown() -> void:
	assert(_file_contains("res://scripts/player/Player.gd", "get_farming_speed_multiplier()"), \
		"Green Thumb must scale the tool cooldown in Player.gd")

func test_shop_seeds_grouped_by_rarity() -> void:
	assert(_file_contains("res://scripts/ui/Shop.gd", "RARITY_SUB_NAMES"), \
		"Shop must define rarity sub-category names")
	assert(_file_contains("res://scripts/ui/Shop.gd", "_sub_header("), \
		"Shop must render rarity sub-category headers")
	assert(_file_contains("res://scripts/ui/Shop.gd", "seeds locked"), \
		"Shop must show a 'locked' hint for the next Seed Vault tier")

func test_shop_rows_have_icons() -> void:
	assert(_file_contains("res://scripts/ui/Shop.gd", "icon: Texture2D = null"), \
		"_build_row must accept an icon")
	assert(_file_contains("res://scripts/ui/Shop.gd", "TextureRect.new()"), \
		"_build_row must render an icon TextureRect")

func test_seed_vault_tiers_have_real_content() -> void:
	assert(_file_contains("res://scripts/autoload/DataManager.gd", "seed_buy_price"), \
		"Rare chef seeds must become purchasable (Seed Vault gates them)")
	assert(_file_contains("res://scripts/autoload/DataManager.gd", "genetics.rarity_tier = {\"Common\""), \
		"Rare chef crops must carry an Epic/Legendary rarity tier")
	assert(_file_contains("res://scripts/autoload/DataManager.gd", "mark_discovered(crop.id)"), \
		"Rare chef crops must be discovered so they appear in the shop")

func test_crafting_ui_boss_items_section() -> void:
	assert(_file_contains("res://scripts/ui/CraftingUI.gd", "\"boss_items\""), \
		"Crafting UI must define a Boss Items category")
	assert(_file_contains("res://scripts/ui/CraftingUI.gd", "essence_of_inconstance\"]:"), \
		"Boss bait recipes (incl. essence) must route to the Boss Items category")

func test_pets_have_own_section() -> void:
	var shop_scene := "res://scenes/ui/Shop.tscn"
	var text := ""
	var f := FileAccess.open(shop_scene, FileAccess.READ)
	if f:
		text = f.get_as_text()
		f.close()
	# Pets section must come before the Upgrades section in the Sections stack.
	assert(text.find("PetsHeader") != -1 and text.find("UpgradesHeader") != -1, "both headers present")
	assert(text.find("PetsHeader") < text.find("UpgradesHeader"), \
		"Pets header must precede Upgrades header (own section)")
