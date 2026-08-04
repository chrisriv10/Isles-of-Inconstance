extends Node

## Guards the difficulty wiring in the economy systems: every coin path
## (sell, tribute, raid, hotel, restaurant) must still apply the multiplier.

func _eq(actual: Variant, expected: Variant, what: String) -> bool:
	if actual != expected:
		printerr("  FAIL %s: expected=%s actual=%s" % [what, expected, actual])
	return actual == expected

func _file_contains(path: String, needle: String) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		printerr("  FAIL: cannot open " + path)
		return false
	var t := f.get_as_text()
	f.close()
	return t.contains(needle)

func test_sell_ui_uses_sell_mult() -> void:
	assert(_file_contains("res://scripts/ui/SellUI.gd", "get_sell_mult()"), "SellUI must use sell mult")

func test_hotel_uses_income_mult() -> void:
	assert(_file_contains("res://scripts/world/building/Hotel.gd", "get_income_mult()"), "Hotel must use income mult")

func test_restaurant_uses_income_mult() -> void:
	assert(_file_contains("res://scripts/world/town/RestaurantSystem.gd", "get_income_mult()"), "Restaurant must use income mult")

func test_town_tribute_uses_income_mult() -> void:
	assert(_file_contains("res://scripts/world/town/TownManager.gd", "get_income_mult()"), "Town tribute must use income mult")

func test_pirate_raid_uses_income_mult() -> void:
	assert(_file_contains("res://scripts/world/PirateRaidEvent.gd", "get_income_mult()"), "Raid reward must use income mult")

func test_enemy_loot_uses_loot_mult() -> void:
	assert(_file_contains("res://scripts/world/enemies/Enemy.gd", "get_loot_mult()"), "Enemy loot must use loot mult")

func test_hard_income_rounding_ceil() -> void:
	# Hotel pays ceil(earnings * mult); on HARD the mult is 0.5.
	var saved := GameManager.difficulty
	GameManager.set_difficulty(GameManager.Difficulty.HARD)
	var paid := ceili(float(7) * GameManager.get_income_mult())
	assert(_eq(paid, 4, "ceil(7*0.5)"))
	GameManager.set_difficulty(saved)

func test_hard_sell_price_floor() -> void:
	# A 10c item at HARD sells for floor(10 * 0.65) = 6.
	var saved := GameManager.difficulty
	GameManager.set_difficulty(GameManager.Difficulty.HARD)
	assert(_eq(floori(10 * GameManager.get_sell_mult()), 6, "floor(10*0.65)"))
	GameManager.set_difficulty(saved)