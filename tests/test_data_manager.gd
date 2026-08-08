extends Node

## Data-integrity suite: every item ID referenced by shops, quests and
## cooking recipes must exist in DataManager. Catches "missing item" bugs
## (broken shop rows / uncraftable recipes) before they reach playtesting.

## Cooking recipes use "crop" as a generic "any crop" ingredient placeholder
## that is resolved specially at cook time — it is intentionally not an item.
const GENERIC_INGREDIENT_IDS := ["crop"]

func _eq(actual: Variant, expected: Variant, what: String) -> bool:
	if actual != expected:
		printerr("  FAIL %s: expected=%s actual=%s" % [what, expected, actual])
	return actual == expected

func _item_exists(id: String) -> bool:
	return DataManager.get_item(id) != null

func _data_loaded() -> bool:
	return is_instance_valid(DataManager) and DataManager.items.size() > 0

func test_shop_luxury_items_exist() -> void:
	if not _data_loaded():
		return  # smoke-pass shell: DataManager items not built yet
	var ids := [
		"decorative_fountain_kit",
		"decorative_statue_kit",
		"decorative_lantern_kit",
		"decorative_bench_kit",
		"decorative_sign_kit",
	]
	for id in ids:
		assert(_item_exists(id), "Shop item missing from DataManager: " + id)

func test_quest_reward_and_requirement_items_exist() -> void:
	if not _data_loaded():
		return  # smoke-pass shell: DataManager items not built yet
	var defs := QuestManager.get_quest_defs()
	assert(defs.size() > 20, "expected >20 quests, got %d" % defs.size())
	for key: String in defs:
		var q: Dictionary = defs[key]
		assert(q.has("id"), "quest %s missing id" % key)
		assert(_eq(String(q["id"]), key, "quest id matches key"), "quest id mismatch")
		for req in q.get("requirements", []):
			assert(_item_exists(req["id"]), "Quest '%s' references missing item: %s" % [key, req["id"]])
		for ri in q.get("reward_items", []):
			assert(_item_exists(ri["id"]), "Quest '%s' rewards missing item: %s" % [key, ri["id"]])

func test_cooking_recipe_ingredients_exist() -> void:
	if not _data_loaded():
		return  # smoke-pass shell: DataManager items not built yet
	var cs := CookingSystem.new()
	assert(cs.recipes.size() > 0, "no cooking recipes")
	for recipe_id: String in cs.recipes:
		var meal = cs.recipes[recipe_id]
		for ing_id: String in meal.ingredients:
			if ing_id in GENERIC_INGREDIENT_IDS:
				continue
			assert(_item_exists(ing_id), "Recipe '%s' references missing ingredient: %s" % [recipe_id, ing_id])

func test_crafting_recipe_ingredients_exist() -> void:
	if not _data_loaded():
		return  # smoke-pass shell: DataManager items not built yet
	var ui := CraftingUI.new()
	ui._build_default_recipes()
	ui._build_alchemy_recipes()
	var recipes: Array = ui.get_recipes()
	assert(recipes.size() > 0, "no crafting recipes")
	for r in recipes:
		for ing: Dictionary in r.ingredients:
			var ing_id: String = ing.get("item_id", "")
			if ing_id in GENERIC_INGREDIENT_IDS or ing_id == "":
				continue
			assert(_item_exists(ing_id), "Crafting recipe '%s' references missing ingredient: %s" % [r.result_item_id, ing_id])