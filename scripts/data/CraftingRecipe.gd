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

# Category for UI tab grouping: "tools", "armor", "materials", "farming", "building", "decorations", "alchemy", "consumables", "misc"
@export var category: String = "misc"

# Array of { item_id: String, amount: int } dictionaries
@export var ingredients: Array = []

## Check if the player has enough of all ingredients.
func can_craft() -> bool:
	for ing in ingredients:
		var item_id: String = ing.get("item_id", "")
		var amount: int = ing.get("amount", 1)
		var has: bool = false
		if _is_category_id(item_id):
			has = _count_by_category(item_id) >= amount
		else:
			has = InventoryManager.has_item(item_id, amount)
		if not has:
			return false
	return true

## Consume ingredients and add the result. Returns true if successful.
func craft() -> bool:
	if not can_craft():
		return false

	for ing in ingredients:
		var item_id: String = ing.get("item_id", "")
		var amount: int = ing.get("amount", 1)
		if _is_category_id(item_id):
			_consume_by_category(item_id, amount)
		else:
			InventoryManager.remove_item(item_id, amount)

	InventoryManager.add_item(result_item_id, result_amount)
	return true

## Returns true if the given ingredient ID refers to an ItemData category
## (e.g. "crop", "resource") rather than a specific item.
static func _is_category_id(id: String) -> bool:
	return id in ["crop", "resource", "seed", "food", "meal", "flower", "mushroom", "berry", "fish"]

## Count how many items the player has across ALL items of the given category.
static func _count_by_category(category: String) -> int:
	var counts: Dictionary = InventoryManager.get_counts_by_category(category)
	var total: int = 0
	for item_key in counts:
		total += counts[item_key]
	return total

## Consume items from a category, removing from inventory until the amount is met.
static func _consume_by_category(category: String, amount: int) -> void:
	var counts: Dictionary = InventoryManager.get_counts_by_category(category)
	var remaining: int = amount
	for item_key in counts:
		if remaining <= 0:
			break
		var have: int = counts[item_key]
		var take: int = mini(have, remaining)
		InventoryManager.remove_item(item_key, take)
		remaining -= take

func get_ingredient_summary() -> String:
	var parts: Array[String] = []
	for ing in ingredients:
		var item_id: String = ing.get("item_id", "")
		var amount: int = ing.get("amount", 1)
		if _is_category_id(item_id):
			var cat_name: String = item_id.capitalize() + "s"
			parts.append("Any %s x%d" % [cat_name, amount])
		else:
			var item: ItemData = DataManager.get_item(item_id)
			var item_name: String = item.display_name if item else item_id
			parts.append("%s x%d" % [item_name, amount])
	return " + ".join(parts)
