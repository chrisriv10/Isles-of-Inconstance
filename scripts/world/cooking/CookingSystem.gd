class_name CookingSystem
extends RefCounted

## Complete cooking system with recipes, ingredients, and buffs.
## Meals can be cooked at a campfire or in a home kitchen.

signal recipe_discovered(recipe_id: String)
signal meal_cooked(meal_id: String, count: int)

class MealData:
	var id: String
	var display_name: String
	var description: String
	var ingredients: Dictionary  # {item_id: count}
	var sell_price: int
	var buff_type: String  # "speed", "growth", "energy", "luck", "health", "none"
	var buff_duration: float  # in-game hours
	var buff_strength: float
	var category: String  # "meal", "drink", "dessert", "snack"

var recipes: Dictionary = {}  # recipe_id -> MealData
var discovered_recipes: Dictionary = {}
var cooked_count: Dictionary = {}  # meal_id -> total cooked

func _init() -> void:
	_register_default_recipes()

func _register_default_recipes() -> void:
	# Basic meals
	_add_recipe("grilled_vegetables", "Grilled Vegetables", "A healthy mix of grilled garden vegetables.", 
		{"crop": 3}, 15, "energy", 4.0, 0.3, "meal")
	_add_recipe("vegetable_soup", "Vegetable Soup", "A warm and hearty vegetable soup.", 
		{"crop": 4, "wood": 1}, 25, "energy", 6.0, 0.5, "meal")
	_add_recipe("garden_salad", "Garden Salad", "Fresh garden greens with a light dressing.", 
		{"crop": 2}, 12, "energy", 3.0, 0.2, "snack")
	_add_recipe("roasted_roots", "Roasted Roots", "Slow-roasted root vegetables.", 
		{"crop": 3, "wood": 2}, 20, "energy", 5.0, 0.4, "meal")
	_add_recipe("fruit_compote", "Fruit Compote", "Sweet stewed fruits.", 
		{"crop": 3}, 18, "energy", 4.0, 0.35, "dessert")
	_add_recipe("berry_juice", "Berry Juice", "Refreshing juice from wild berries.", 
		{"crop": 2}, 10, "speed", 2.0, 1.2, "drink")
	_add_recipe("hearty_stew", "Hearty Stew", "A filling stew with meat and vegetables.", 
		{"crop": 5, "wood": 3}, 45, "health", 8.0, 0.6, "meal")
	_add_recipe("growth_tea", "Growth Tea", "A herbal tea that helps crops grow faster.", 
		{"crop": 3}, 30, "growth", 6.0, 1.5, "drink")
	_add_recipe("lucky_salad", "Lucky Salad", "A salad said to bring good fortune.", 
		{"crop": 4}, 35, "luck", 4.0, 0.3, "snack")
	_add_recipe("farmers_breakfast", "Farmer's Breakfast", "A hearty breakfast to start the day.", 
		{"crop": 4, "wood": 1}, 30, "energy", 8.0, 0.8, "meal")
	_add_recipe("golden_soup", "Golden Soup", "A luxurious soup with rare ingredients.", 
		{"crop": 6}, 60, "luck", 8.0, 0.5, "meal")
	_add_recipe("herbal_tea", "Herbal Tea", "Soothing tea made from aromatic herbs.", 
		{"crop": 2}, 15, "growth", 3.0, 1.2, "drink")
	_add_recipe("stuffed_vegetables", "Stuffed Vegetables", "Vegetables stuffed with seasoned grains.", 
		{"crop": 4, "wood": 2}, 35, "health", 6.0, 0.5, "meal")
	_add_recipe("candied_fruit", "Candied Fruit", "Fruit preserved in sweet syrup.", 
		{"crop": 3}, 22, "energy", 5.0, 0.4, "dessert")
	_add_recipe("mushroom_stew", "Mushroom Stew", "Earthy mushroom stew.", 
		{"crop": 3, "wood": 2}, 28, "health", 5.0, 0.45, "meal")

func _add_recipe(id: String, name: String, desc: String, ingredients: Dictionary, price: int, buff: String, duration: float, strength: float, category: String) -> void:
	var meal := MealData.new()
	meal.id = id
	meal.display_name = name
	meal.description = desc
	meal.ingredients = ingredients
	meal.sell_price = price
	meal.buff_type = buff
	meal.buff_duration = duration
	meal.buff_strength = strength
	meal.category = category
	recipes[id] = meal

func can_cook(recipe_id: String) -> bool:
	var meal: MealData = recipes.get(recipe_id)
	if not meal:
		return false
	
	for key in meal.ingredients:
		var ingredient_id: String = key
		var needed: int = meal.ingredients[ingredient_id]
		var total: int = 0
		
		if ingredient_id == "crop":
			# Count all crop items in inventory
			var counts: Dictionary = InventoryManager.get_counts_by_category("crop")
			for item_key in counts:
				total += counts[item_key]
		else:
			total = InventoryManager.get_count(ingredient_id)
		
		if total < needed:
			return false
	
	return true

func cook(recipe_id: String) -> int:
	var meal: MealData = recipes.get(recipe_id)
	if not meal or not can_cook(recipe_id):
		return 0
	
	# Consume ingredients
	for key in meal.ingredients:
		var ingredient_id: String = key
		var needed: int = meal.ingredients[ingredient_id]
		var remaining: int = needed
		
		if ingredient_id == "crop":
			# Consume from crop category
			var counts: Dictionary = InventoryManager.get_counts_by_category("crop")
			for item_key in counts:
				if remaining <= 0:
					break
				var have: int = counts[item_key]
				var take: int = mini(have, remaining)
				InventoryManager.remove_item(item_key, take)
				remaining -= take
		else:
			InventoryManager.remove_item(ingredient_id, needed)
	
	# Discover this recipe if not already known
	if not discovered_recipes.has(recipe_id):
		discovered_recipes[recipe_id] = true
		recipe_discovered.emit(recipe_id)
	
	# Track count
	cooked_count[recipe_id] = cooked_count.get(recipe_id, 0) + 1
	
	# Add the meal item to inventory (use recipe_id as item ID)
	InventoryManager.add_item(recipe_id, 1)
	
	meal_cooked.emit(recipe_id, 1)
	return 1

func get_known_recipes() -> Array:
	return discovered_recipes.keys()

func get_all_recipes() -> Array:
	return recipes.keys()

func get_meal(recipe_id: String) -> MealData:
	var meal: MealData = recipes.get(recipe_id)
	return meal

func serialize() -> Dictionary:
	return {
		"discovered_recipes": discovered_recipes.duplicate(),
		"cooked_count": cooked_count.duplicate()
	}

static func deserialize(data: Dictionary) -> CookingSystem:
	var cs: CookingSystem = CookingSystem.new()
	if data.has("discovered_recipes"):
		var disc: Dictionary = data["discovered_recipes"]
		for key in disc:
			cs.discovered_recipes[key] = disc[key]
	if data.has("cooked_count"):
		var ccount: Dictionary = data["cooked_count"]
		for key in ccount:
			cs.cooked_count[key] = ccount[key]
	return cs
