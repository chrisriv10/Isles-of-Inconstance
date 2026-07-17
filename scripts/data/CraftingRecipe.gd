extends Resource
class_name CraftingRecipe

## A single crafting recipe: a list of required items that produces one
## result item. Add new recipes by creating instances of this in code or
## via .tres files — the system is designed to be extensible without
## touching the UI or logic code.

@export var recipe_name: String = ""
@export var result_item_id: String = ""
@export var result_display_name: String = ""
@export var result_amount: int = 1
@export var result_icon: Texture2D

# Array of { item_id: String, amount: int } dictionaries
@export var ingredients: Array = []

## Check if the player has enough of all ingredients.
func can_craft() -> bool:
	for ing in ingredients:
		var item_id: String = ing.get("item_id", "")
		var amount: int = ing.get("amount", 1)
		if not InventoryManager.has_item(item_id, amount):
			return false
	return true

## Consume ingredients and add the result. Returns true if successful.
func craft() -> bool:
	if not can_craft():
		return false

	for ing in ingredients:
		var item_id: String = ing.get("item_id", "")
		var amount: int = ing.get("amount", 1)
		InventoryManager.remove_item(item_id, amount)

	InventoryManager.add_item(result_item_id, result_amount)
	return true

func get_ingredient_summary() -> String:
	var parts: Array[String] = []
	for ing in ingredients:
		var item_id: String = ing.get("item_id", "")
		var amount: int = ing.get("amount", 1)
		var item := DataManager.get_item(item_id)
		var name := item.display_name if item else item_id
		parts.append("%s x%d" % [name, amount])
	return " + ".join(parts)
