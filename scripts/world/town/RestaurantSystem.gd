## RestaurantSystem — crop selling hub at the restaurant.
## Pays premium prices for crops (especially high-quality ones).
## Has a daily special request for bonus gold.
## Also handles recipe discovery when bringing rare ingredients.

extends Node
class_name RestaurantSystem

## Signal when crops are sold at the restaurant
signal crops_sold(item_id: String, count: int, total_gold: int)
## Signal when a new recipe is discovered
signal recipe_discovered(recipe_name: String)

## Price multiplier for selling crops here (vs market stand)
const BASE_PRICE_MULTIPLIER: float = 1.15

## Quality bonuses (additional multiplier on top of base)
const QUALITY_BONUS: Dictionary = {
	0: 1.0,   # Normal
	1: 1.2,   # Silver
	2: 1.4,   # Gold
	3: 1.75,  # Iridium
}

## Bulk bonus: sell 10+ of same crop → extra %
const BULK_BONUS_THRESHOLD: int = 10
const BULK_BONUS_MULTIPLIER: float = 1.1

## Reputation per sale
const REP_PER_SALE: int = 1
const REP_DAILY_SPECIAL: int = 5

## Track daily special
var _daily_special_crop: String = ""
var _daily_special_bonus: float = 2.0  # 2x price
var _recipes_unlocked: Array[String] = []

## Rare ingredients that unlock recipes
const RECIPE_UNLOCKS: Dictionary = {
	"giant_mushroom": {"recipe": "mushroom_risotto", "name": "Mushroom Risotto"},
	"golden_pumpkin": {"recipe": "golden_soup", "name": "Golden Soup"},
	"ancient_fruit": {"recipe": "ancient_wine", "name": "Ancient Fruit Wine"},
	"fairy_rose": {"recipe": "fairy_tea", "name": "Fairy Tea"},
	"void_berry": {"recipe": "void_cordial", "name": "Void Cordial"},
}

func _ready() -> void:
	add_to_group("restaurant_system")
	_roll_daily_special()

## Roll a new daily special crop
func _roll_daily_special() -> void:
	# Pick from available crops
	var all_crops: Array = DataManager.crops.values()
	if all_crops.is_empty():
		_daily_special_crop = "potato"
		return
	var crop: CropData = all_crops[randi() % all_crops.size()] as CropData
	if crop and not crop.id.is_empty():
		_daily_special_crop = crop.id
	else:
		_daily_special_crop = "potato"

func advance_day() -> void:
	_roll_daily_special()

## Calculate the sell price for a crop at a given quality
func calculate_price(item_id: String, count: int, quality: int = 0) -> int:
	var item_data := DataManager.get_item(item_id)
	if not item_data:
		return 0
	
	var base_value: int = item_data.sell_price if item_data.sell_price > 0 else 1
	var price: float = float(base_value) * count * BASE_PRICE_MULTIPLIER
	
	# Quality bonus
	var q_mult: float = QUALITY_BONUS.get(quality, 1.0)
	price *= q_mult
	
	# Daily special
	if item_id == _daily_special_crop:
		price *= _daily_special_bonus
	
	# Bulk bonus
	if count >= BULK_BONUS_THRESHOLD:
		price *= BULK_BONUS_MULTIPLIER
	
	return maxi(1, int(price))

## Sell crops. Returns gold earned.
func sell_crops(item_id: String, count: int, quality: int = 0) -> int:
	var item_data := DataManager.get_item(item_id)
	if not item_data:
		return 0
	
	# Check player has the items
	if not InventoryManager.has_item(item_id, count):
		return 0
	
	var price: int = calculate_price(item_id, count, quality)
	
	# Remove items from inventory
	InventoryManager.remove_item(item_id, count)
	
	# Add gold (scaled by difficulty income multiplier)
	GameManager.add_money(ceil(price * GameManager.get_income_mult()))
	
	# Reputation
	var tm := get_tree().get_first_node_in_group("town_manager")
	if tm and tm.has_method("add_reputation"):
		var rep: int = REP_PER_SALE
		if item_id == _daily_special_crop:
			rep = REP_DAILY_SPECIAL
		tm.add_reputation(rep)
	
	# Notify objective manager about restaurant sale (for Purveyor objective)
	var obj_mgr := get_tree().get_first_node_in_group("objective_manager")
	if obj_mgr and obj_mgr.has_method("on_sell_at_restaurant"):
		obj_mgr.on_sell_at_restaurant()
	
	crops_sold.emit(item_id, count, price)
	return price

## Try to unlock a recipe by bringing a rare ingredient
func try_unlock_recipe(ingredient_id: String) -> Dictionary:
	if not RECIPE_UNLOCKS.has(ingredient_id):
		return {"success": false, "message": "The chef doesn't recognize this ingredient."}
	
	if _recipes_unlocked.has(ingredient_id):
		return {"success": false, "message": "You've already shared this ingredient!"}
	
	var unlock: Dictionary = RECIPE_UNLOCKS[ingredient_id]
	_recipes_unlocked.append(ingredient_id)
	
	# Add recipe to cooking system (if exists)
	var cooking_sys := get_tree().get_first_node_in_group("cooking_system")
	if cooking_sys and cooking_sys.has_method("unlock_recipe"):
		cooking_sys.unlock_recipe(unlock["recipe"])
	
	recipe_discovered.emit(unlock["name"])
	
	return {
		"success": true,
		"message": "Chef learned '%s'! You can now cook it at any campfire." % [unlock["name"]],
		"recipe_name": unlock["name"],
	}

func get_daily_special() -> Dictionary:
	# The special is always a crop (rolled from DataManager.crops), and
	# procedural crops only live in the crops registry — look them up by
	# crop first, then fall back to the item registry / raw id.
	var crop_data := DataManager.get_crop(_daily_special_crop)
	var item_data := DataManager.get_item(_daily_special_crop)
	var display_name: String = _daily_special_crop
	if crop_data and not crop_data.display_name.is_empty():
		display_name = crop_data.display_name
	elif item_data:
		display_name = item_data.display_name
	return {
		"item_id": _daily_special_crop,
		"name": display_name,
		"bonus_mult": _daily_special_bonus,
	}

func get_daily_special_crop() -> String:
	return _daily_special_crop

## Find the crop whose yield item id matches the given id. Useful for
## resolving a yield item back to its crop so we can show a friendly name.
func get_crop_for_yield(item_id: String) -> CropData:
	for crop: CropData in DataManager.crops.values():
		if crop.yield_item_id == item_id:
			return crop
	return null

func is_recipe_unlocked(ingredient_id: String) -> bool:
	return _recipes_unlocked.has(ingredient_id)

func get_unlocked_recipes() -> Array[String]:
	return _recipes_unlocked.duplicate()
