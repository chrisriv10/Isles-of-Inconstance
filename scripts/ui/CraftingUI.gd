extends CanvasLayer
class_name CraftingUI

## Toggleable crafting overlay. Shows available recipes with ingredient details
## on the right panel. Click a recipe row to select it and see its full details.

# UI Style constants
var LIGHT_WOOD: StyleBoxTexture
var DARK_WOOD: StyleBoxTexture
var DARK_SLOT: StyleBoxFlat

static func _make_dark_slot() -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.12, 0.12, 0.12, 0.85)
	s.border_color = Color(0.25, 0.25, 0.25, 1.0)
	s.set_border_width_all(2)
	s.set_corner_radius_all(4)
	return s

@onready var dim: ColorRect = $Dim
@onready var panel: PanelContainer = $Panel
@onready var recipe_list: VBoxContainer = %RecipeList
@onready var info_label: Label = %InfoLabel
@onready var detail_title: Label = %DetailTitle
@onready var detail_result_label: Label = %DetailResultLabel
@onready var detail_ingredient_list: VBoxContainer = %DetailIngredientList
@onready var detail_hint: Label = %DetailHint
@onready var craft_button: Button = %CraftButton
@onready var preview_icon: TextureRect = $Panel/Margin/Layout/MainBody/DetailPanel/DetailMargin/DetailLayout/PreviewIcon

# Tab buttons are now built dynamically in _build_category_tabs()

var is_open: bool = false
var _hint_crafting_shown: bool = false
var _selected_recipe: CraftingRecipe = null
var _active_category: String = "tools"  # current active category tab

# Registry of all known recipes.
var _recipes: Array[CraftingRecipe] = []

# When true, shows only ingot smelting recipes without fuel costs.
var _forge_mode: bool = false

# Ordered categories with display names
var _categories: Array[Dictionary] = [
	{"key": "tools", "icon": "⚔", "label": "Tools"},
	{"key": "armor", "icon": "🛡", "label": "Armor"},
	{"key": "materials", "icon": "🧱", "label": "Materials"},
	{"key": "farming", "icon": "🌾", "label": "Farming"},
	{"key": "building", "icon": "🏗", "label": "Building"},
	{"key": "alchemy", "icon": "⚗", "label": "Alchemy"},
	{"key": "decorations", "icon": "✨", "label": "Decor"},
	{"key": "consumables", "icon": "🍬", "label": "Consumables"},
]

# Tab button references keyed by category key
var _tab_buttons: Dictionary = {}

## Public getter for EncyclopediaUI (the crafting tab queries this).
func get_recipes() -> Array[CraftingRecipe]:
	return _recipes

## Public getter for EncyclopediaUI alchemy tab.
func get_alchemy_recipes() -> Array[CraftingRecipe]:
	var result: Array[CraftingRecipe] = []
	for r in _recipes:
		if r.category == "alchemy":
			result.append(r)
	return result


func _ready() -> void:
	LIGHT_WOOD = preload("res://resources/ui/wood_panel.tres")
	DARK_WOOD = preload("res://resources/ui/dark_wood_panel.tres")
	DARK_SLOT = _make_dark_slot()
	_build_default_recipes()
	_build_alchemy_recipes()
	_assign_categories()

	# Connect to inventory changes to refresh
	InventoryManager.changed.connect(_on_inventory_changed)

	dim.visible = false
	panel.visible = false
	craft_button.pressed.connect(_on_craft_selected)

	# Remove old tab bar children (kept from the scene), build tabs dynamically
	_build_category_tabs()


func _build_default_recipes() -> void:
	# --- Tool Upgrade Kit ---
	var tool_kit := CraftingRecipe.new()
	tool_kit.recipe_name = "Blacksmith Component Kit"
	tool_kit.result_item_id = "tool_upgrade_kit"
	tool_kit.result_display_name = "Blacksmith Component Kit"
	tool_kit.result_amount = 1
	tool_kit.ingredients = [
		{"item_id": "stone", "amount": 10},
		{"item_id": "wood", "amount": 5},
	]
	_recipes.append(tool_kit)

	# --- Compost (speeds crop growth) ---
	var compost := CraftingRecipe.new()
	compost.recipe_name = "Compost"
	compost.result_item_id = "compost"
	compost.result_display_name = "Compost"
	compost.result_amount = 1
	compost.ingredients = [
		{"item_id": "wood", "amount": 5},
	]
	_recipes.append(compost)

	# --- Wooden Planks ---
	var planks := CraftingRecipe.new()
	planks.recipe_name = "Wooden Planks"
	planks.result_item_id = "wooden_planks"
	planks.result_display_name = "Wooden Planks"
	planks.result_amount = 2
	planks.ingredients = [
		{"item_id": "wood", "amount": 3},
	]
	_recipes.append(planks)

	# --- Quality Compost ---
	var qcompost := CraftingRecipe.new()
	qcompost.recipe_name = "Quality Compost"
	qcompost.result_item_id = "quality_compost"
	qcompost.result_display_name = "Quality Compost"
	qcompost.result_amount = 1
	qcompost.ingredients = [
		{"item_id": "compost", "amount": 3},
		{"item_id": "wood", "amount": 3},
	]
	_recipes.append(qcompost)

	# --- Growth Booster ---
	var gbooster := CraftingRecipe.new()
	gbooster.recipe_name = "Growth Booster"
	gbooster.result_item_id = "growth_booster"
	gbooster.result_display_name = "Growth Booster"
	gbooster.result_amount = 1
	gbooster.ingredients = [
		{"item_id": "wooden_planks", "amount": 2},
		{"item_id": "wood", "amount": 5},
	]
	_recipes.append(gbooster)

	# --- Yield Enhancer ---
	var yenhancer := CraftingRecipe.new()
	yenhancer.recipe_name = "Yield Enhancer"
	yenhancer.result_item_id = "yield_enhancer"
	yenhancer.result_display_name = "Yield Enhancer"
	yenhancer.result_amount = 1
	yenhancer.ingredients = [
		{"item_id": "stone", "amount": 8},
		{"item_id": "quality_compost", "amount": 1},
	]
	_recipes.append(yenhancer)

	# --- Rich Fertilizer ---
	var rfert := CraftingRecipe.new()
	rfert.recipe_name = "Rich Fertilizer"
	rfert.result_item_id = "rich_fertilizer"
	rfert.result_display_name = "Rich Fertilizer"
	rfert.result_amount = 1
	rfert.ingredients = [
		{"item_id": "growth_booster", "amount": 1},
		{"item_id": "yield_enhancer", "amount": 1},
	]
	_recipes.append(rfert)

	# --- Super Fertilizer ---
	var sfert := CraftingRecipe.new()
	sfert.recipe_name = "Super Fertilizer"
	sfert.result_item_id = "super_fertilizer"
	sfert.result_display_name = "Super Fertilizer"
	sfert.result_amount = 1
	sfert.ingredients = [
		{"item_id": "rich_fertilizer", "amount": 2},
		{"item_id": "tool_upgrade_kit", "amount": 1},
	]
	_recipes.append(sfert)

	# --- Building Recipes ---
	var fence := CraftingRecipe.new()
	fence.recipe_name = "Fence"
	fence.result_item_id = "fence_material"
	fence.result_display_name = "Fence Material"
	fence.result_amount = 2
	fence.ingredients = [
		{"item_id": "wood", "amount": 4},
	]
	_recipes.append(fence)

	var stone_fence := CraftingRecipe.new()
	stone_fence.recipe_name = "Stone Fence"
	stone_fence.result_item_id = "stone_fence_material"
	stone_fence.result_display_name = "Stone Fence Material"
	stone_fence.result_amount = 2
	stone_fence.ingredients = [
		{"item_id": "stone", "amount": 5},
	]
	_recipes.append(stone_fence)

	var campfire := CraftingRecipe.new()
	campfire.recipe_name = "Campfire"
	campfire.result_item_id = "campfire_kit"
	campfire.result_display_name = "Campfire Kit"
	campfire.result_amount = 1
	campfire.ingredients = [
		{"item_id": "wood", "amount": 8},
		{"item_id": "stone", "amount": 5},
	]
	_recipes.append(campfire)

	# --- Additional Buildings ---
	var building_recipes := [
		{"name": "Small Home", "item": "small_home_kit", "display": "Small Home Kit", "amount": 1, "ing": [{"i": "wood", "a": 30}, {"i": "stone", "a": 15}]},
		{"name": "Medium Home", "item": "medium_home_kit", "display": "Medium Home Kit", "amount": 1, "ing": [{"i": "wood", "a": 60}, {"i": "stone", "a": 30}, {"i": "wooden_planks", "a": 20}]},
		{"name": "Large Home", "item": "large_home_kit", "display": "Large Home Kit", "amount": 1, "ing": [{"i": "wood", "a": 120}, {"i": "stone", "a": 60}, {"i": "wooden_planks", "a": 40}]},
		{"name": "Barn", "item": "barn_kit", "display": "Barn Kit", "amount": 1, "ing": [{"i": "wood", "a": 45}, {"i": "stone", "a": 25}]},
		{"name": "Storage Shed", "item": "storage_shed_kit", "display": "Storage Shed Kit", "amount": 1, "ing": [{"i": "wood", "a": 25}, {"i": "stone", "a": 10}]},
		{"name": "Gate", "item": "gate_kit", "display": "Gate Kit", "amount": 1, "ing": [{"i": "wood", "a": 8}, {"i": "stone", "a": 4}]},
		{"name": "Garden Bed", "item": "garden_bed_kit", "display": "Garden Bed Kit", "amount": 1, "ing": [{"i": "wood", "a": 12}, {"i": "wooden_planks", "a": 6}]},
		# Town Hall kit removed — the ruined town already has a Town Hall
		{"name": "Windmill", "item": "windmill_kit", "display": "Windmill Kit", "amount": 1, "ing": [{"i": "wood", "a": 75}, {"i": "stone", "a": 45}, {"i": "wooden_planks", "a": 30}]},
		{"name": "Greenhouse", "item": "greenhouse_kit", "display": "Greenhouse Kit", "amount": 1, "ing": [{"i": "wood", "a": 60}, {"i": "stone", "a": 30}, {"i": "wooden_planks", "a": 40}]},
		{"name": "Monument Statue", "item": "decorative_statue_kit", "display": "Monument Statue Kit", "amount": 1, "ing": [{"i": "stone", "a": 120}]},
		{"name": "Fountain", "item": "decorative_fountain_kit", "display": "Fountain Kit", "amount": 1, "ing": [{"i": "stone", "a": 45}]},
		{"name": "Bench", "item": "decorative_bench_kit", "display": "Bench Kit", "amount": 1, "ing": [{"i": "wood", "a": 8}]},
		{"name": "Placeable Lantern", "item": "decorative_lantern_kit", "display": "Lantern Kit", "amount": 1, "ing": [{"i": "stone", "a": 5}, {"i": "wood", "a": 4}]},
		{"name": "Sign", "item": "decorative_sign_kit", "display": "Sign Kit", "amount": 1, "ing": [{"i": "wood", "a": 5}]},
		{"name": "Silo", "item": "silo_kit", "display": "Silo Kit", "amount": 1, "ing": [{"i": "stone", "a": 60}, {"i": "wood", "a": 30}, {"i": "wooden_planks", "a": 20}]},
		{"name": "Well", "item": "well_kit", "display": "Well Kit", "amount": 1, "ing": [{"i": "stone", "a": 25}]},
		{"name": "Hotel", "item": "hotel_kit", "display": "Hotel Kit", "amount": 1, "ing": [{"i": "wood", "a": 90}, {"i": "stone", "a": 45}, {"i": "wooden_planks", "a": 30}, {"i": "gold_nugget", "a": 8}]},
		{"name": "Scarecrow", "item": "scarecrow_kit", "display": "Scarecrow Kit", "amount": 1, "ing": [{"i": "wood", "a": 12}, {"i": "vine", "a": 8}]},
		{"name": "Compost Bin", "item": "compost_bin_kit", "display": "Compost Bin Kit", "amount": 1, "ing": [{"i": "wood", "a": 15}, {"i": "wooden_planks", "a": 8}]},
	]
	for br in building_recipes:
		var r := CraftingRecipe.new()
		r.recipe_name = br.name
		r.result_item_id = br.item
		r.result_display_name = br.display
		r.result_amount = br.amount
		r.ingredients = []
		for ing in br.ing:
			r.ingredients.append({"item_id": ing.i, "amount": ing.a})
		_recipes.append(r)

	# --- Iron Ingot ---
	var iron := CraftingRecipe.new()
	iron.recipe_name = "Iron Ingot"
	iron.result_item_id = "iron_ingot"
	iron.result_display_name = "Iron Ingot"
	iron.result_amount = 1
	iron.ingredients = [
		{"item_id": "iron_ore", "amount": 4},
		{"item_id": "wood", "amount": 3},
	]
	_recipes.append(iron)

	# --- Copper Ingot ---
	var copper_ingot := CraftingRecipe.new()
	copper_ingot.recipe_name = "Copper Ingot"
	copper_ingot.result_item_id = "copper_ingot"
	copper_ingot.result_display_name = "Copper Ingot"
	copper_ingot.result_amount = 1
	copper_ingot.ingredients = [
		{"item_id": "copper_ore", "amount": 4},
		{"item_id": "coal", "amount": 2},
	]
	_recipes.append(copper_ingot)

	# --- Steel Ingot ---
	var steel_ingot := CraftingRecipe.new()
	steel_ingot.recipe_name = "Steel Ingot"
	steel_ingot.result_item_id = "steel_ingot"
	steel_ingot.result_display_name = "Steel Ingot"
	steel_ingot.result_amount = 1
	steel_ingot.ingredients = [
		{"item_id": "iron_ingot", "amount": 3},
		{"item_id": "coal", "amount": 2},
	]
	_recipes.append(steel_ingot)

	# --- Gold Ingot ---
	var gold_ingot := CraftingRecipe.new()
	gold_ingot.recipe_name = "Gold Ingot"
	gold_ingot.result_item_id = "gold_ingot"
	gold_ingot.result_display_name = "Gold Ingot"
	gold_ingot.result_amount = 1
	gold_ingot.ingredients = [
		{"item_id": "gold_ore", "amount": 3},
		{"item_id": "coal", "amount": 2},
	]
	_recipes.append(gold_ingot)

	# --- Silver Ingot ---
	var silver_ingot_recipe := CraftingRecipe.new()
	silver_ingot_recipe.recipe_name = "Silver Ingot"
	silver_ingot_recipe.result_item_id = "silver_ingot"
	silver_ingot_recipe.result_display_name = "Silver Ingot"
	silver_ingot_recipe.result_amount = 1
	silver_ingot_recipe.ingredients = [
		{"item_id": "silver_ore", "amount": 4},
		{"item_id": "coal", "amount": 2},
	]
	_recipes.append(silver_ingot_recipe)

	# --- Mythril Ingot ---
	var mythril_ingot_recipe := CraftingRecipe.new()
	mythril_ingot_recipe.recipe_name = "Mythril Ingot"
	mythril_ingot_recipe.result_item_id = "mythril_ingot"
	mythril_ingot_recipe.result_display_name = "Mythril Ingot"
	mythril_ingot_recipe.result_amount = 1
	mythril_ingot_recipe.ingredients = [
		{"item_id": "silver_ingot", "amount": 2},
		{"item_id": "gold_ingot", "amount": 1},
		{"item_id": "obsidian_shard", "amount": 1},
		{"item_id": "coal", "amount": 2},
	]
	_recipes.append(mythril_ingot_recipe)

	# --- Copper Pickaxe (tier 2) ---
	var copper_pickaxe := CraftingRecipe.new()
	copper_pickaxe.recipe_name = "Copper Pickaxe"
	copper_pickaxe.result_item_id = "copper_pickaxe"
	copper_pickaxe.result_display_name = "Copper Pickaxe"
	copper_pickaxe.result_amount = 1
	copper_pickaxe.ingredients = [
		{"item_id": "pickaxe_tool", "amount": 1},
		{"item_id": "copper_ingot", "amount": 3},
	]
	_recipes.append(copper_pickaxe)

	# --- Iron Pickaxe (tier 3) ---
	var iron_pickaxe_recipe := CraftingRecipe.new()
	iron_pickaxe_recipe.recipe_name = "Iron Pickaxe"
	iron_pickaxe_recipe.result_item_id = "iron_pickaxe"
	iron_pickaxe_recipe.result_display_name = "Iron Pickaxe"
	iron_pickaxe_recipe.result_amount = 1
	iron_pickaxe_recipe.ingredients = [
		{"item_id": "copper_pickaxe", "amount": 1},
		{"item_id": "iron_ingot", "amount": 5},
	]
	_recipes.append(iron_pickaxe_recipe)

	# --- Gold Pickaxe (tier 4) ---
	var gold_pickaxe_recipe := CraftingRecipe.new()
	gold_pickaxe_recipe.recipe_name = "Gold Pickaxe"
	gold_pickaxe_recipe.result_item_id = "gold_pickaxe"
	gold_pickaxe_recipe.result_display_name = "Gold Pickaxe"
	gold_pickaxe_recipe.result_amount = 1
	gold_pickaxe_recipe.ingredients = [
		{"item_id": "iron_pickaxe", "amount": 1},
		{"item_id": "gold_ingot", "amount": 5},
		{"item_id": "gold_nugget", "amount": 3},
	]
	_recipes.append(gold_pickaxe_recipe)

	# --- Diamond Pickaxe (tier 5) ---
	var diamond_pickaxe_recipe := CraftingRecipe.new()
	diamond_pickaxe_recipe.recipe_name = "Diamond Pickaxe"
	diamond_pickaxe_recipe.result_item_id = "diamond_pickaxe"
	diamond_pickaxe_recipe.result_display_name = "Diamond Pickaxe"
	diamond_pickaxe_recipe.result_amount = 1
	diamond_pickaxe_recipe.ingredients = [
		{"item_id": "gold_pickaxe", "amount": 1},
		{"item_id": "diamond_gem", "amount": 3},
		{"item_id": "gold_ingot", "amount": 3},
	]
	_recipes.append(diamond_pickaxe_recipe)

	# --- Mythril Pickaxe (tier 6, ultimate) ---
	var mythril_pickaxe_recipe := CraftingRecipe.new()
	mythril_pickaxe_recipe.recipe_name = "Mythril Pickaxe"
	mythril_pickaxe_recipe.result_item_id = "mythril_pickaxe"
	mythril_pickaxe_recipe.result_display_name = "Mythril Pickaxe"
	mythril_pickaxe_recipe.result_amount = 1
	mythril_pickaxe_recipe.ingredients = [
		{"item_id": "diamond_pickaxe", "amount": 1},
		{"item_id": "mythril_ingot", "amount": 5},
		{"item_id": "ruby_gem", "amount": 2},
		{"item_id": "obsidian_shard", "amount": 3},
	]
	_recipes.append(mythril_pickaxe_recipe)

	# --- Scythe (harvest crops) ---
	var scythe := CraftingRecipe.new()
	scythe.recipe_name = "Scythe"
	scythe.result_item_id = "scythe_tool"
	scythe.result_display_name = "Scythe"
	scythe.result_amount = 1
	scythe.ingredients = [
		{"item_id": "wood", "amount": 8},
		{"item_id": "stone", "amount": 5},
	]
	_recipes.append(scythe)

	# --- Axe (chop trees) ---
	var axe := CraftingRecipe.new()
	axe.recipe_name = "Axe"
	axe.result_item_id = "axe_tool"
	axe.result_display_name = "Axe"
	axe.result_amount = 1
	axe.ingredients = [
		{"item_id": "wood", "amount": 8},
		{"item_id": "stone", "amount": 8},
	]
	_recipes.append(axe)

	# --- Copper Axe (tier 2) ---
	var copper_axe_recipe := CraftingRecipe.new()
	copper_axe_recipe.recipe_name = "Copper Axe"
	copper_axe_recipe.result_item_id = "copper_axe"
	copper_axe_recipe.result_display_name = "Copper Axe"
	copper_axe_recipe.result_amount = 1
	copper_axe_recipe.ingredients = [
		{"item_id": "axe_tool", "amount": 1},
		{"item_id": "copper_ingot", "amount": 3},
	]
	_recipes.append(copper_axe_recipe)

	# --- Iron Axe (tier 3) ---
	var iron_axe_recipe := CraftingRecipe.new()
	iron_axe_recipe.recipe_name = "Iron Axe"
	iron_axe_recipe.result_item_id = "iron_axe"
	iron_axe_recipe.result_display_name = "Iron Axe"
	iron_axe_recipe.result_amount = 1
	iron_axe_recipe.ingredients = [
		{"item_id": "copper_axe", "amount": 1},
		{"item_id": "iron_ingot", "amount": 5},
	]
	_recipes.append(iron_axe_recipe)

	# --- Gold Axe (tier 4) ---
	var gold_axe_recipe := CraftingRecipe.new()
	gold_axe_recipe.recipe_name = "Gold Axe"
	gold_axe_recipe.result_item_id = "gold_axe"
	gold_axe_recipe.result_display_name = "Gold Axe"
	gold_axe_recipe.result_amount = 1
	gold_axe_recipe.ingredients = [
		{"item_id": "iron_axe", "amount": 1},
		{"item_id": "gold_ingot", "amount": 5},
		{"item_id": "gold_nugget", "amount": 3},
	]
	_recipes.append(gold_axe_recipe)

	# --- Diamond Axe (tier 5) ---
	var diamond_axe_recipe := CraftingRecipe.new()
	diamond_axe_recipe.recipe_name = "Diamond Axe"
	diamond_axe_recipe.result_item_id = "diamond_axe"
	diamond_axe_recipe.result_display_name = "Diamond Axe"
	diamond_axe_recipe.result_amount = 1
	diamond_axe_recipe.ingredients = [
		{"item_id": "gold_axe", "amount": 1},
		{"item_id": "diamond_gem", "amount": 3},
		{"item_id": "gold_ingot", "amount": 3},
	]
	_recipes.append(diamond_axe_recipe)

	# --- Mythril Axe (tier 6, ultimate) ---
	var mythril_axe_recipe := CraftingRecipe.new()
	mythril_axe_recipe.recipe_name = "Mythril Axe"
	mythril_axe_recipe.result_item_id = "mythril_axe"
	mythril_axe_recipe.result_display_name = "Mythril Axe"
	mythril_axe_recipe.result_amount = 1
	mythril_axe_recipe.ingredients = [
		{"item_id": "diamond_axe", "amount": 1},
		{"item_id": "mythril_ingot", "amount": 5},
		{"item_id": "ruby_gem", "amount": 2},
		{"item_id": "obsidian_shard", "amount": 3},
	]
	_recipes.append(mythril_axe_recipe)

	# --- Pickaxe (mine ore) ---
	# Uses stone so the player can mine iron BEFORE needing iron ingots.
	# Iron ingots are still required for advanced tools (sword, sprinkler, etc.).
	var pickaxe := CraftingRecipe.new()
	pickaxe.recipe_name = "Pickaxe"
	pickaxe.result_item_id = "pickaxe_tool"
	pickaxe.result_display_name = "Pickaxe"
	pickaxe.result_amount = 1
	pickaxe.ingredients = [
		{"item_id": "wood", "amount": 8},
		{"item_id": "stone", "amount": 8},
	]
	_recipes.append(pickaxe)

	# --- Sword (combat) ---
	var sword := CraftingRecipe.new()
	sword.recipe_name = "Sword"
	sword.result_item_id = "sword_tool"
	sword.result_display_name = "Sword"
	sword.result_amount = 1
	sword.ingredients = [
		{"item_id": "iron_ingot", "amount": 5},
		{"item_id": "wood", "amount": 3},
	]
	_recipes.append(sword)

	# --- Copper Sword (tier 2) ---
	var copper_sword := CraftingRecipe.new()
	copper_sword.recipe_name = "Copper Sword"
	copper_sword.result_item_id = "copper_sword"
	copper_sword.result_display_name = "Copper Sword"
	copper_sword.result_amount = 1
	copper_sword.ingredients = [
		{"item_id": "sword_tool", "amount": 1},
		{"item_id": "copper_ingot", "amount": 3},
	]
	_recipes.append(copper_sword)

	# --- Iron Sword (tier 3) ---
	var iron_sword_recipe := CraftingRecipe.new()
	iron_sword_recipe.recipe_name = "Iron Sword"
	iron_sword_recipe.result_item_id = "iron_sword"
	iron_sword_recipe.result_display_name = "Iron Sword"
	iron_sword_recipe.result_amount = 1
	iron_sword_recipe.ingredients = [
		{"item_id": "copper_sword", "amount": 1},
		{"item_id": "iron_ingot", "amount": 5},
	]
	_recipes.append(iron_sword_recipe)

	# --- Gold Sword (tier 4) ---
	var gold_sword_recipe := CraftingRecipe.new()
	gold_sword_recipe.recipe_name = "Gold Sword"
	gold_sword_recipe.result_item_id = "gold_sword"
	gold_sword_recipe.result_display_name = "Gold Sword"
	gold_sword_recipe.result_amount = 1
	gold_sword_recipe.ingredients = [
		{"item_id": "iron_sword", "amount": 1},
		{"item_id": "gold_ingot", "amount": 5},
		{"item_id": "gold_nugget", "amount": 3},
	]
	_recipes.append(gold_sword_recipe)

	# --- Diamond Sword (tier 5) ---
	var diamond_sword_recipe := CraftingRecipe.new()
	diamond_sword_recipe.recipe_name = "Diamond Sword"
	diamond_sword_recipe.result_item_id = "diamond_sword"
	diamond_sword_recipe.result_display_name = "Diamond Sword"
	diamond_sword_recipe.result_amount = 1
	diamond_sword_recipe.ingredients = [
		{"item_id": "gold_sword", "amount": 1},
		{"item_id": "diamond_gem", "amount": 3},
		{"item_id": "gold_ingot", "amount": 3},
	]
	_recipes.append(diamond_sword_recipe)

	# --- Mythril Sword (tier 6, ultimate) ---
	var mythril_sword_recipe := CraftingRecipe.new()
	mythril_sword_recipe.recipe_name = "Mythril Sword"
	mythril_sword_recipe.result_item_id = "mythril_sword"
	mythril_sword_recipe.result_display_name = "Mythril Sword"
	mythril_sword_recipe.result_amount = 1
	mythril_sword_recipe.ingredients = [
		{"item_id": "diamond_sword", "amount": 1},
		{"item_id": "mythril_ingot", "amount": 5},
		{"item_id": "ruby_gem", "amount": 2},
		{"item_id": "obsidian_shard", "amount": 3},
	]
	_recipes.append(mythril_sword_recipe)

	# --- Lantern (light source, ghost repellent) ---
	var lantern := CraftingRecipe.new()
	lantern.recipe_name = "Lantern"
	lantern.result_item_id = "lantern"
	lantern.result_display_name = "Lantern"
	lantern.result_amount = 1
	lantern.ingredients = [
		{"item_id": "iron_ingot", "amount": 3},
		{"item_id": "stone", "amount": 3},
	]
	_recipes.append(lantern)

	# --- Sprinkler (auto-waters 3x3 area daily) ---
	var sprinkler := CraftingRecipe.new()
	sprinkler.recipe_name = "Sprinkler"
	sprinkler.result_item_id = "sprinkler"
	sprinkler.result_display_name = "Sprinkler"
	sprinkler.result_amount = 1
	sprinkler.ingredients = [
		{"item_id": "iron_ore", "amount": 5},
		{"item_id": "stone", "amount": 5},
	]
	_recipes.append(sprinkler)
	
	# --- Quality Sprinkler (5×5 area) ---
	var quality_sprinkler := CraftingRecipe.new()
	quality_sprinkler.recipe_name = "Quality Sprinkler"
	quality_sprinkler.result_item_id = "quality_sprinkler"
	quality_sprinkler.result_display_name = "Quality Sprinkler"
	quality_sprinkler.result_amount = 1
	quality_sprinkler.ingredients = [
		{"item_id": "sprinkler", "amount": 2},
		{"item_id": "copper_ingot", "amount": 3},
		{"item_id": "iron_ore", "amount": 8},
	]
	_recipes.append(quality_sprinkler)
	
	# --- Iridium Sprinkler (7×7 area + mild fertilizer) ---
	var iridium_sprinkler := CraftingRecipe.new()
	iridium_sprinkler.recipe_name = "Iridium Sprinkler"
	iridium_sprinkler.result_item_id = "iridium_sprinkler"
	iridium_sprinkler.result_display_name = "Iridium Sprinkler"
	iridium_sprinkler.result_amount = 1
	iridium_sprinkler.ingredients = [
		{"item_id": "quality_sprinkler", "amount": 2},
		{"item_id": "gold_ingot", "amount": 3},
		{"item_id": "mythril_ingot", "amount": 2},
	]
	_recipes.append(iridium_sprinkler)

	# --- Fishing Rod (fish near water) ---
	var fishing_rod := CraftingRecipe.new()
	fishing_rod.recipe_name = "Fishing Rod"
	fishing_rod.result_item_id = "fishing_rod"
	fishing_rod.result_display_name = "Fishing Rod"
	fishing_rod.result_amount = 1
	fishing_rod.ingredients = [
		{"item_id": "wood", "amount": 5},
		{"item_id": "vine", "amount": 3},
	]
	_recipes.append(fishing_rod)

	# --- Bow (ranged weapon) ---
	var bow_recipe := CraftingRecipe.new()
	bow_recipe.recipe_name = "Bow"
	bow_recipe.result_item_id = "bow"
	bow_recipe.result_display_name = "Bow"
	bow_recipe.result_amount = 1
	bow_recipe.ingredients = [
		{"item_id": "wood", "amount": 5},
		{"item_id": "vine", "amount": 3},
	]
	_recipes.append(bow_recipe)

	# --- Arrow (ammunition) ---
	var arrow_recipe := CraftingRecipe.new()
	arrow_recipe.recipe_name = "Arrow"
	arrow_recipe.result_item_id = "arrow"
	arrow_recipe.result_display_name = "Arrows"
	arrow_recipe.result_amount = 10
	arrow_recipe.ingredients = [
		{"item_id": "wood", "amount": 2},
		{"item_id": "stone", "amount": 1},
		{"item_id": "feather", "amount": 1},
	]
	_recipes.append(arrow_recipe)

	# ── Armor (craftable for defense) ──

	# --- Leather Helmet ---
	var l_helmet := CraftingRecipe.new()
	l_helmet.recipe_name = "Leather Helmet"
	l_helmet.result_item_id = "leather_helmet"
	l_helmet.result_display_name = "Leather Helmet"
	l_helmet.result_amount = 1
	l_helmet.ingredients = [
		{"item_id": "leather", "amount": 3},
		{"item_id": "fur", "amount": 2},
	]
	_recipes.append(l_helmet)

	# --- Leather Tunic ---
	var l_tunic := CraftingRecipe.new()
	l_tunic.recipe_name = "Leather Tunic"
	l_tunic.result_item_id = "leather_chestplate"
	l_tunic.result_display_name = "Leather Tunic"
	l_tunic.result_amount = 1
	l_tunic.ingredients = [
		{"item_id": "leather", "amount": 5},
		{"item_id": "fur", "amount": 3},
	]
	_recipes.append(l_tunic)

	# --- Leather Pants ---
	var l_pants := CraftingRecipe.new()
	l_pants.recipe_name = "Leather Pants"
	l_pants.result_item_id = "leather_leggings"
	l_pants.result_display_name = "Leather Pants"
	l_pants.result_amount = 1
	l_pants.ingredients = [
		{"item_id": "leather", "amount": 4},
		{"item_id": "fur", "amount": 2},
		{"item_id": "wool", "amount": 1},
	]
	_recipes.append(l_pants)

	# --- Leather Boots ---
	var l_boots := CraftingRecipe.new()
	l_boots.recipe_name = "Leather Boots"
	l_boots.result_item_id = "leather_boots"
	l_boots.result_display_name = "Leather Boots"
	l_boots.result_amount = 1
	l_boots.ingredients = [
		{"item_id": "leather", "amount": 3},
		{"item_id": "fur", "amount": 1},
	]
	_recipes.append(l_boots)

	# --- Iron Helmet ---
	var i_helmet := CraftingRecipe.new()
	i_helmet.recipe_name = "Iron Helmet"
	i_helmet.result_item_id = "iron_helmet"
	i_helmet.result_display_name = "Iron Helmet"
	i_helmet.result_amount = 1
	i_helmet.ingredients = [
		{"item_id": "iron_ingot", "amount": 5},
		{"item_id": "leather", "amount": 2},
	]
	_recipes.append(i_helmet)

	# --- Iron Chestplate ---
	var i_chest := CraftingRecipe.new()
	i_chest.recipe_name = "Iron Chestplate"
	i_chest.result_item_id = "iron_chestplate"
	i_chest.result_display_name = "Iron Chestplate"
	i_chest.result_amount = 1
	i_chest.ingredients = [
		{"item_id": "iron_ingot", "amount": 8},
		{"item_id": "leather", "amount": 3},
	]
	_recipes.append(i_chest)

	# --- Iron Leggings ---
	var i_legs := CraftingRecipe.new()
	i_legs.recipe_name = "Iron Leggings"
	i_legs.result_item_id = "iron_leggings"
	i_legs.result_display_name = "Iron Leggings"
	i_legs.result_amount = 1
	i_legs.ingredients = [
		{"item_id": "iron_ingot", "amount": 7},
		{"item_id": "leather", "amount": 2},
	]
	_recipes.append(i_legs)

	# --- Iron Boots ---
	var i_boots := CraftingRecipe.new()
	i_boots.recipe_name = "Iron Boots"
	i_boots.result_item_id = "iron_boots"
	i_boots.result_display_name = "Iron Boots"
	i_boots.result_amount = 1
	i_boots.ingredients = [
		{"item_id": "iron_ingot", "amount": 4},
		{"item_id": "leather", "amount": 2},
	]
	_recipes.append(i_boots)

	# ── Copper armor ──
	var c_helmet := CraftingRecipe.new()
	c_helmet.recipe_name = "Copper Helmet"
	c_helmet.result_item_id = "copper_helmet"
	c_helmet.result_display_name = "Copper Helmet"
	c_helmet.result_amount = 1
	c_helmet.ingredients = [{"item_id": "copper_ingot", "amount": 4}, {"item_id": "leather", "amount": 2}]
	_recipes.append(c_helmet)

	var c_chest := CraftingRecipe.new()
	c_chest.recipe_name = "Copper Chestplate"
	c_chest.result_item_id = "copper_chestplate"
	c_chest.result_display_name = "Copper Chestplate"
	c_chest.result_amount = 1
	c_chest.ingredients = [{"item_id": "copper_ingot", "amount": 7}, {"item_id": "leather", "amount": 3}]
	_recipes.append(c_chest)

	var c_legs := CraftingRecipe.new()
	c_legs.recipe_name = "Copper Leggings"
	c_legs.result_item_id = "copper_leggings"
	c_legs.result_display_name = "Copper Leggings"
	c_legs.result_amount = 1
	c_legs.ingredients = [{"item_id": "copper_ingot", "amount": 5}, {"item_id": "leather", "amount": 2}]
	_recipes.append(c_legs)

	var c_boots := CraftingRecipe.new()
	c_boots.recipe_name = "Copper Boots"
	c_boots.result_item_id = "copper_boots"
	c_boots.result_display_name = "Copper Boots"
	c_boots.result_amount = 1
	c_boots.ingredients = [{"item_id": "copper_ingot", "amount": 3}, {"item_id": "leather", "amount": 2}]
	_recipes.append(c_boots)

	# ── Silver armor ──
	var s_helmet := CraftingRecipe.new()
	s_helmet.recipe_name = "Silver Helmet"
	s_helmet.result_item_id = "silver_helmet"
	s_helmet.result_display_name = "Silver Helmet"
	s_helmet.result_amount = 1
	s_helmet.ingredients = [{"item_id": "silver_ingot", "amount": 5}, {"item_id": "leather", "amount": 2}]
	_recipes.append(s_helmet)

	var s_chest := CraftingRecipe.new()
	s_chest.recipe_name = "Silver Chestplate"
	s_chest.result_item_id = "silver_chestplate"
	s_chest.result_display_name = "Silver Chestplate"
	s_chest.result_amount = 1
	s_chest.ingredients = [{"item_id": "silver_ingot", "amount": 8}, {"item_id": "leather", "amount": 3}]
	_recipes.append(s_chest)

	var s_legs := CraftingRecipe.new()
	s_legs.recipe_name = "Silver Leggings"
	s_legs.result_item_id = "silver_leggings"
	s_legs.result_display_name = "Silver Leggings"
	s_legs.result_amount = 1
	s_legs.ingredients = [{"item_id": "silver_ingot", "amount": 6}, {"item_id": "leather", "amount": 2}]
	_recipes.append(s_legs)

	var s_boots := CraftingRecipe.new()
	s_boots.recipe_name = "Silver Boots"
	s_boots.result_item_id = "silver_boots"
	s_boots.result_display_name = "Silver Boots"
	s_boots.result_amount = 1
	s_boots.ingredients = [{"item_id": "silver_ingot", "amount": 4}, {"item_id": "leather", "amount": 2}]
	_recipes.append(s_boots)

	# ── Gold armor ──
	var g_helmet := CraftingRecipe.new()
	g_helmet.recipe_name = "Gold Helmet"
	g_helmet.result_item_id = "gold_helmet"
	g_helmet.result_display_name = "Gold Helmet"
	g_helmet.result_amount = 1
	g_helmet.ingredients = [{"item_id": "gold_ingot", "amount": 5}, {"item_id": "leather", "amount": 2}]
	_recipes.append(g_helmet)

	var g_chest := CraftingRecipe.new()
	g_chest.recipe_name = "Gold Chestplate"
	g_chest.result_item_id = "gold_chestplate"
	g_chest.result_display_name = "Gold Chestplate"
	g_chest.result_amount = 1
	g_chest.ingredients = [{"item_id": "gold_ingot", "amount": 8}, {"item_id": "leather", "amount": 3}]
	_recipes.append(g_chest)

	var g_legs := CraftingRecipe.new()
	g_legs.recipe_name = "Gold Leggings"
	g_legs.result_item_id = "gold_leggings"
	g_legs.result_display_name = "Gold Leggings"
	g_legs.result_amount = 1
	g_legs.ingredients = [{"item_id": "gold_ingot", "amount": 7}, {"item_id": "leather", "amount": 2}]
	_recipes.append(g_legs)

	var g_boots := CraftingRecipe.new()
	g_boots.recipe_name = "Gold Boots"
	g_boots.result_item_id = "gold_boots"
	g_boots.result_display_name = "Gold Boots"
	g_boots.result_amount = 1
	g_boots.ingredients = [{"item_id": "gold_ingot", "amount": 4}, {"item_id": "leather", "amount": 2}]
	_recipes.append(g_boots)

	# ── Steel armor ──
	var st_helmet := CraftingRecipe.new()
	st_helmet.recipe_name = "Steel Helmet"
	st_helmet.result_item_id = "steel_helmet"
	st_helmet.result_display_name = "Steel Helmet"
	st_helmet.result_amount = 1
	st_helmet.ingredients = [{"item_id": "steel_ingot", "amount": 5}, {"item_id": "leather", "amount": 2}]
	_recipes.append(st_helmet)

	var st_chest := CraftingRecipe.new()
	st_chest.recipe_name = "Steel Chestplate"
	st_chest.result_item_id = "steel_chestplate"
	st_chest.result_display_name = "Steel Chestplate"
	st_chest.result_amount = 1
	st_chest.ingredients = [{"item_id": "steel_ingot", "amount": 8}, {"item_id": "leather", "amount": 3}]
	_recipes.append(st_chest)

	var st_legs := CraftingRecipe.new()
	st_legs.recipe_name = "Steel Leggings"
	st_legs.result_item_id = "steel_leggings"
	st_legs.result_display_name = "Steel Leggings"
	st_legs.result_amount = 1
	st_legs.ingredients = [{"item_id": "steel_ingot", "amount": 7}, {"item_id": "leather", "amount": 2}]
	_recipes.append(st_legs)

	var st_boots := CraftingRecipe.new()
	st_boots.recipe_name = "Steel Boots"
	st_boots.result_item_id = "steel_boots"
	st_boots.result_display_name = "Steel Boots"
	st_boots.result_amount = 1
	st_boots.ingredients = [{"item_id": "steel_ingot", "amount": 4}, {"item_id": "leather", "amount": 2}]
	_recipes.append(st_boots)

	# ── Mythril armor ──
	var m_helmet := CraftingRecipe.new()
	m_helmet.recipe_name = "Mythril Helmet"
	m_helmet.result_item_id = "mythril_helmet"
	m_helmet.result_display_name = "Mythril Helmet"
	m_helmet.result_amount = 1
	m_helmet.ingredients = [{"item_id": "mythril_ingot", "amount": 5}, {"item_id": "silver_ingot", "amount": 2}]
	_recipes.append(m_helmet)

	var m_chest := CraftingRecipe.new()
	m_chest.recipe_name = "Mythril Chestplate"
	m_chest.result_item_id = "mythril_chestplate"
	m_chest.result_display_name = "Mythril Chestplate"
	m_chest.result_amount = 1
	m_chest.ingredients = [{"item_id": "mythril_ingot", "amount": 8}, {"item_id": "silver_ingot", "amount": 3}]
	_recipes.append(m_chest)

	var m_legs := CraftingRecipe.new()
	m_legs.recipe_name = "Mythril Leggings"
	m_legs.result_item_id = "mythril_leggings"
	m_legs.result_display_name = "Mythril Leggings"
	m_legs.result_amount = 1
	m_legs.ingredients = [{"item_id": "mythril_ingot", "amount": 7}, {"item_id": "silver_ingot", "amount": 2}]
	_recipes.append(m_legs)

	var m_boots := CraftingRecipe.new()
	m_boots.recipe_name = "Mythril Boots"
	m_boots.result_item_id = "mythril_boots"
	m_boots.result_display_name = "Mythril Boots"
	m_boots.result_amount = 1
	m_boots.ingredients = [{"item_id": "mythril_ingot", "amount": 4}, {"item_id": "silver_ingot", "amount": 2}]
	_recipes.append(m_boots)

	# ── Diamond armor ──
	var d_helmet := CraftingRecipe.new()
	d_helmet.recipe_name = "Diamond Helmet"
	d_helmet.result_item_id = "diamond_helmet"
	d_helmet.result_display_name = "Diamond Helmet"
	d_helmet.result_amount = 1
	d_helmet.ingredients = [{"item_id": "diamond_gem", "amount": 5}, {"item_id": "steel_ingot", "amount": 3}]
	_recipes.append(d_helmet)

	var d_chest := CraftingRecipe.new()
	d_chest.recipe_name = "Diamond Chestplate"
	d_chest.result_item_id = "diamond_chestplate"
	d_chest.result_display_name = "Diamond Chestplate"
	d_chest.result_amount = 1
	d_chest.ingredients = [{"item_id": "diamond_gem", "amount": 8}, {"item_id": "steel_ingot", "amount": 4}]
	_recipes.append(d_chest)

	var d_legs := CraftingRecipe.new()
	d_legs.recipe_name = "Diamond Leggings"
	d_legs.result_item_id = "diamond_leggings"
	d_legs.result_display_name = "Diamond Leggings"
	d_legs.result_amount = 1
	d_legs.ingredients = [{"item_id": "diamond_gem", "amount": 7}, {"item_id": "steel_ingot", "amount": 3}]
	_recipes.append(d_legs)

	var d_boots := CraftingRecipe.new()
	d_boots.recipe_name = "Diamond Boots"
	d_boots.result_item_id = "diamond_boots"
	d_boots.result_display_name = "Diamond Boots"
	d_boots.result_amount = 1
	d_boots.ingredients = [{"item_id": "diamond_gem", "amount": 4}, {"item_id": "steel_ingot", "amount": 2}]
	_recipes.append(d_boots)

	# ── Ruby armor ──
	var r_helmet := CraftingRecipe.new()
	r_helmet.recipe_name = "Ruby Helmet"
	r_helmet.result_item_id = "ruby_helmet"
	r_helmet.result_display_name = "Ruby Helmet"
	r_helmet.result_amount = 1
	r_helmet.ingredients = [{"item_id": "ruby_gem", "amount": 5}, {"item_id": "gold_ingot", "amount": 3}]
	_recipes.append(r_helmet)

	var r_chest := CraftingRecipe.new()
	r_chest.recipe_name = "Ruby Chestplate"
	r_chest.result_item_id = "ruby_chestplate"
	r_chest.result_display_name = "Ruby Chestplate"
	r_chest.result_amount = 1
	r_chest.ingredients = [{"item_id": "ruby_gem", "amount": 8}, {"item_id": "gold_ingot", "amount": 4}]
	_recipes.append(r_chest)

	var r_legs := CraftingRecipe.new()
	r_legs.recipe_name = "Ruby Leggings"
	r_legs.result_item_id = "ruby_leggings"
	r_legs.result_display_name = "Ruby Leggings"
	r_legs.result_amount = 1
	r_legs.ingredients = [{"item_id": "ruby_gem", "amount": 7}, {"item_id": "gold_ingot", "amount": 3}]
	_recipes.append(r_legs)

	var r_boots := CraftingRecipe.new()
	r_boots.recipe_name = "Ruby Boots"
	r_boots.result_item_id = "ruby_boots"
	r_boots.result_display_name = "Ruby Boots"
	r_boots.result_amount = 1
	r_boots.ingredients = [{"item_id": "ruby_gem", "amount": 4}, {"item_id": "gold_ingot", "amount": 2}]
	_recipes.append(r_boots)

	# ── Obsidian armor ──
	var o_helmet := CraftingRecipe.new()
	o_helmet.recipe_name = "Obsidian Helmet"
	o_helmet.result_item_id = "obsidian_helmet"
	o_helmet.result_display_name = "Obsidian Helmet"
	o_helmet.result_amount = 1
	o_helmet.ingredients = [{"item_id": "obsidian_shard", "amount": 6}, {"item_id": "steel_ingot", "amount": 2}]
	_recipes.append(o_helmet)

	var o_chest := CraftingRecipe.new()
	o_chest.recipe_name = "Obsidian Chestplate"
	o_chest.result_item_id = "obsidian_chestplate"
	o_chest.result_display_name = "Obsidian Chestplate"
	o_chest.result_amount = 1
	o_chest.ingredients = [{"item_id": "obsidian_shard", "amount": 10}, {"item_id": "steel_ingot", "amount": 3}]
	_recipes.append(o_chest)

	var o_legs := CraftingRecipe.new()
	o_legs.recipe_name = "Obsidian Leggings"
	o_legs.result_item_id = "obsidian_leggings"
	o_legs.result_display_name = "Obsidian Leggings"
	o_legs.result_amount = 1
	o_legs.ingredients = [{"item_id": "obsidian_shard", "amount": 8}, {"item_id": "steel_ingot", "amount": 2}]
	_recipes.append(o_legs)

	var o_boots := CraftingRecipe.new()
	o_boots.recipe_name = "Obsidian Boots"
	o_boots.result_item_id = "obsidian_boots"
	o_boots.result_display_name = "Obsidian Boots"
	o_boots.result_amount = 1
	o_boots.ingredients = [{"item_id": "obsidian_shard", "amount": 5}, {"item_id": "steel_ingot", "amount": 2}]
	_recipes.append(o_boots)

	# --- Spirit Harvest: Baits ---
	var soulberry_pie := CraftingRecipe.new()
	soulberry_pie.recipe_name = "Soulberry Pie"
	soulberry_pie.result_item_id = "soulberry_pie"
	soulberry_pie.result_display_name = "Soulberry Pie"
	soulberry_pie.result_amount = 1
	soulberry_pie.ingredients = [
		{"item_id": "soulberry", "amount": 3},
	]
	_recipes.append(soulberry_pie)

	var golden_hay := CraftingRecipe.new()
	golden_hay.recipe_name = "Golden Hay Bale"
	golden_hay.result_item_id = "golden_hay_bale"
	golden_hay.result_display_name = "Golden Hay Bale"
	golden_hay.result_amount = 1
	golden_hay.ingredients = [
		{"item_id": "golden_wheat", "amount": 3},
	]
	_recipes.append(golden_hay)

	var nectar_brew := CraftingRecipe.new()
	nectar_brew.recipe_name = "Nectar Brew"
	nectar_brew.result_item_id = "nectar_brew"
	nectar_brew.result_display_name = "Nectar Brew"
	nectar_brew.result_amount = 1
	nectar_brew.ingredients = [
		{"item_id": "nectar_bloom", "amount": 2},
		{"item_id": "berry", "amount": 1},
	]
	_recipes.append(nectar_brew)

	var essence := CraftingRecipe.new()
	essence.recipe_name = "Essence of Inconstance"
	essence.result_item_id = "essence_of_inconstance"
	essence.result_display_name = "Essence of Inconstance"
	essence.result_amount = 1
	essence.ingredients = [
		{"item_id": "wardens_core", "amount": 1},
		{"item_id": "stags_essence", "amount": 1},
		{"item_id": "wyrms_petal", "amount": 1},
	]
	_recipes.append(essence)

	# ── Island Biome Recipes ──
	var island_recipes := [
		{
			"name": "Frozen Delight",
			"id": "frozen_delight",
			"amt": 2,
			"ings": [{"item_id": "ice_crystal", "amount": 2}, {"item_id": "berry", "amount": 1}]
		},
		{
			"name": "Chocolate Fondue",
			"id": "chocolate_fondue",
			"amt": 2,
			"ings": [{"item_id": "chocolate_chunk", "amount": 2}, {"item_id": "berry", "amount": 1}]
		},
		{
			"name": "Candied Cactus",
			"id": "candied_cactus",
			"amt": 2,
			"ings": [{"item_id": "cactus_fruit", "amount": 2}, {"item_id": "sugar_crystal", "amount": 1}]
		},
		{
			"name": "Magma Steel",
			"id": "magma_steel",
			"amt": 2,
			"ings": [{"item_id": "magma_core", "amount": 2}, {"item_id": "iron_ingot", "amount": 2}]
		},
		{
			"name": "Starlight Amulet",
			"id": "starlight_amulet",
			"amt": 1,
			"ings": [{"item_id": "moon_shard", "amount": 3}, {"item_id": "silver_ingot", "amount": 2}, {"item_id": "starlight_dust", "amount": 2}]
		},
		{
			"name": "Ice Ward",
			"id": "ice_ward",
			"amt": 1,
			"ings": [{"item_id": "ice_crystal", "amount": 3}, {"item_id": "snow_flower", "amount": 2}, {"item_id": "wooden_planks", "amount": 3}]
		},
		{
			"name": "Sugar Sculpture",
			"id": "sugar_sculpture",
			"amt": 1,
			"ings": [{"item_id": "sugar_crystal", "amount": 3}, {"item_id": "chocolate_chunk", "amount": 2}]
		},
		{
			"name": "Ember Lantern",
			"id": "ember_lantern",
			"amt": 1,
			"ings": [{"item_id": "ember_dust", "amount": 3}, {"item_id": "stone", "amount": 5}, {"item_id": "sulfur_crystal", "amount": 2}]
		},
	]
	for ir in island_recipes:
		var r := CraftingRecipe.new()
		r.recipe_name = ir.name
		r.result_item_id = ir.id
		r.result_display_name = ir.name
		r.result_amount = ir.amt
		r.ingredients = ir.ings
		_recipes.append(r)

	# ── Island Potions (Alchemy) ──
	var island_potions := [
		{
			"name": "Frost Resist Tonic",
			"id": "frost_resist_tonic",
			"ings": [{"item_id": "snow_flower", "amount": 2}, {"item_id": "ice_crystal", "amount": 2}, {"item_id": "coal", "amount": 2}]
		},
		{
			"name": "Sweet Elixir",
			"id": "sweet_elixir",
			"ings": [{"item_id": "gumdrop", "amount": 2}, {"item_id": "sugar_crystal", "amount": 2}, {"item_id": "berry", "amount": 1}]
		},
		{
			"name": "Desert Salve",
			"id": "desert_salve",
			"ings": [{"item_id": "cactus_fruit", "amount": 2}, {"item_id": "scorpion_stinger", "amount": 1}, {"item_id": "mushroom", "amount": 2}]
		},
		{
			"name": "Magma Burst",
			"id": "magma_burst",
			"ings": [{"item_id": "sulfur_crystal", "amount": 2}, {"item_id": "ember_dust", "amount": 2}, {"item_id": "coal", "amount": 1}]
		},
		{
			"name": "Ethereal Infusion",
			"id": "ethereal_infusion",
			"ings": [{"item_id": "ethereal_essence", "amount": 2}, {"item_id": "moon_shard", "amount": 2}, {"item_id": "ghostly_essence", "amount": 1}]
		},
		{
			"name": "Polar Balm",
			"id": "polar_balm",
			"ings": [{"item_id": "polar_bear_hide", "amount": 1}, {"item_id": "snow_flower", "amount": 2}, {"item_id": "coal", "amount": 1}]
		},
		{
			"name": "Cosmic Dust",
			"id": "cosmic_dust",
			"ings": [{"item_id": "starlight_dust", "amount": 3}, {"item_id": "moon_shard", "amount": 2}, {"item_id": "gold_nugget", "amount": 1}]
		},
	]
	for ip in island_potions:
		var r := CraftingRecipe.new()
		r.recipe_name = ip.name
		r.result_item_id = ip.id
		r.result_display_name = ip.name
		r.result_amount = 1
		r.ingredients = ip.ings
		_recipes.append(r)

	# ── New Recipes Using Underused Items ──
	var new_recipes := [
		{
			"name": "Shell Necklace",
			"id": "shell_necklace",
			"amt": 1,
			"ings": [{"item_id": "shell", "amount": 3}, {"item_id": "vine", "amount": 2}]
		},
		{
			"name": "Antler Bow",
			"id": "antler_bow",
			"amt": 1,
			"ings": [{"item_id": "antlers", "amount": 2}, {"item_id": "bow", "amount": 1}, {"item_id": "vine", "amount": 3}]
		},
		{
			"name": "Flower Extract",
			"id": "flower_extract",
			"amt": 2,
			"ings": [{"item_id": "flower", "amount": 3}, {"item_id": "coal", "amount": 1}]
		},
		{
			"name": "Ancient Compass",
			"id": "ancient_compass",
			"amt": 1,
			"ings": [{"item_id": "ancient_coin", "amount": 1}, {"item_id": "gold_ingot", "amount": 1}, {"item_id": "moon_shard", "amount": 1}]
		},
		{
			"name": "Magma Pickaxe",
			"id": "magma_pickaxe",
			"amt": 1,
			"ings": [{"item_id": "magma_steel", "amount": 2}, {"item_id": "mythril_pickaxe", "amount": 1}]
		},
		# ── Dough & Wheat Processing ──
		{
			"name": "Mill Wheat",
			"id": "minecraft_wheat",
			"amt": 1,
			"ings": [{"item_id": "crop", "amount": 3}]
		},
		{
			"name": "Dough",
			"id": "dough",
			"amt": 1,
			"ings": [{"item_id": "minecraft_wheat", "amount": 2}]
		},
		# ── Torch ──
		{
			"name": "Torch",
			"id": "torch",
			"amt": 4,
			"ings": [{"item_id": "wood", "amount": 2}, {"item_id": "coal", "amount": 1}]
		},
	]
	for nr in new_recipes:
		var r := CraftingRecipe.new()
		r.recipe_name = nr.name
		r.result_item_id = nr.id
		r.result_display_name = nr.name
		r.result_amount = nr.amt
		r.ingredients = nr.ings
		_recipes.append(r)


func _build_alchemy_recipes() -> void:
	# ── Alchemy: Potions ──
	var potion_recipes := [
		{
			"name": "Health Tonic",
			"id": "health_tonic",
			"ings": [{"item_id": "berry", "amount": 3}, {"item_id": "mushroom", "amount": 2}, {"item_id": "stone", "amount": 1}]
		},
		{
			"name": "Health Potion",
			"id": "health_potion",
			"ings": [{"item_id": "berry", "amount": 5}, {"item_id": "mushroom", "amount": 3}, {"item_id": "coal", "amount": 2}]
		},
		{
			"name": "Greater Health Potion",
			"id": "greater_health_potion",
			"ings": [{"item_id": "gold_nugget", "amount": 2}, {"item_id": "soulberry", "amount": 3}, {"item_id": "coal", "amount": 3}]
		},
		{
			"name": "Speed Tonic",
			"id": "speed_tonic",
			"ings": [{"item_id": "vine", "amount": 2}, {"item_id": "feather", "amount": 2}, {"item_id": "coal", "amount": 1}]
		},
		{
			"name": "Swift Elixir",
			"id": "swift_elixir",
			"ings": [{"item_id": "golden_wheat", "amount": 3}, {"item_id": "feather", "amount": 3}, {"item_id": "spore_sac", "amount": 2}]
		},
		{
			"name": "Iron Skin Potion",
			"id": "iron_skin_potion",
			"ings": [{"item_id": "iron_ore", "amount": 3}, {"item_id": "stone", "amount": 5}, {"item_id": "coal", "amount": 2}]
		},
		{
			"name": "Stone Skin Elixir",
			"id": "stone_skin_elixir",
			"ings": [{"item_id": "obsidian_shard", "amount": 2}, {"item_id": "shadow_hide", "amount": 2}, {"item_id": "silver_ore", "amount": 3}]
		},
		{
			"name": "Luck Draught",
			"id": "luck_draught",
			"ings": [{"item_id": "ancient_coin", "amount": 1}, {"item_id": "gold_nugget", "amount": 2}, {"item_id": "spore_sac", "amount": 2}]
		},
		{
			"name": "Elixir of Vigor",
			"id": "elixir_of_vigor",
			"ings": [{"item_id": "cinder_shard", "amount": 2}, {"item_id": "egg", "amount": 2}, {"item_id": "gold_nugget", "amount": 2}]
		},
		{
			"name": "Mana Infusion",
			"id": "mana_infusion",
			"ings": [{"item_id": "ectoplasm", "amount": 2}, {"item_id": "ghostly_essence", "amount": 1}, {"item_id": "frost_crystal", "amount": 2}]
		},
	]
	for pr in potion_recipes:
		var r := CraftingRecipe.new()
		r.recipe_name = pr.name
		r.result_item_id = pr.id
		r.result_display_name = pr.name
		r.result_amount = 1
		r.ingredients = pr.ings
		_recipes.append(r)


func _assign_categories() -> void:
	"""Assign each recipe a category based on its result_item_id and recipe_name."""
	for r in _recipes:
		var id: String = r.result_item_id
		var name: String = r.recipe_name

		# Tools & Weapons
		if id in ["pickaxe_tool", "copper_pickaxe", "iron_pickaxe", "gold_pickaxe", "diamond_pickaxe",
				  "mythril_pickaxe", "magma_pickaxe", "scythe_tool", "axe_tool", "sword_tool",
				  "copper_sword", "iron_sword", "gold_sword", "diamond_sword", "mythril_sword",
				  "fishing_rod", "bow", "antler_bow", "arrow", "lantern", "torch",
				  "tool_upgrade_kit", "ember_lantern"] or \
		   name in ["Scythe", "Axe", "Fishing Rod", "Bow", "Arrow", "Lantern",
					"Blacksmith Component Kit", "Antler Bow", "Pickaxe", "Magma Pickaxe"] or \
		   "Pickaxe" in name or "Sword" in name:
			r.category = "tools"

		# Armor (any result_id containing armor body part names)
		elif "helmet" in id or "chestplate" in id or "leggings" in id or "boots" in id:
			r.category = "armor"

		# Alchemy (potions, elixirs, tonics)
		elif "potion" in id or "tonic" in id or "elixir" in id or "draught" in id or "infusion" in id or \
			 id in ["frost_resist_tonic", "sweet_elixir", "desert_salve", "magma_burst",
				   "ethereal_infusion", "polar_balm", "cosmic_dust", "essence_of_inconstance"] or \
			 name in ["Health Tonic", "Health Potion", "Greater Health Potion", "Speed Tonic",
					 "Swift Elixir", "Iron Skin Potion", "Stone Skin Elixir", "Luck Draught",
					 "Elixir of Vigor", "Mana Infusion"]:
			r.category = "alchemy"

		# Consumables (foods, baits, treats)
		elif id in ["soulberry_pie", "golden_hay_bale", "nectar_brew", "frozen_delight",
				   "chocolate_fondue", "candied_cactus", "starlight_amulet", "ice_ward",
				   "magma_steel", "floating_snack", "sugar_sculpture"] or \
			 name in ["Soulberry Pie", "Golden Hay Bale", "Nectar Brew",
					 "Frozen Delight", "Chocolate Fondue", "Candied Cactus",
					 "Starlight Amulet", "Ice Ward", "Magma Steel",
					 "Floating Snack", "Sugar Sculpture"]:
			r.category = "consumables"

		# Farming (fertilizers, sprinklers, garden aids)
		elif id in ["compost", "quality_compost", "growth_booster", "yield_enhancer",
				   "rich_fertilizer", "super_fertilizer", "sprinkler", "quality_sprinkler",
				   "iridium_sprinkler", "scarecrow_kit", "garden_bed_kit", "compost_bin_kit",
				   "silo_kit", "greenhouse_kit"]:
			r.category = "farming"

		# Building Kits (structure kits)
		elif "kit" in id and id not in ["tool_upgrade_kit", "campfire_kit",
										"scarecrow_kit", "garden_bed_kit",
										"compost_bin_kit", "silo_kit",
										"greenhouse_kit", "decorative_statue_kit",
										"decorative_fountain_kit", "decorative_bench_kit",
										"decorative_lantern_kit", "decorative_sign_kit"]:
			r.category = "building"

		# Materials (ingots, planks, fences, building components)
		elif "ingot" in id or id in ["wooden_planks", "fence_material", "stone_fence_material",
									"campfire_kit", "shell_necklace", "flower_extract",
									"ancient_compass", "minecraft_wheat", "dough"] or \
			 name in ["Wooden Planks", "Fence", "Stone Fence", "Campfire",
					 "Shell Necklace", "Flower Extract", "Ancient Compass",
					 "Iron Ingot", "Copper Ingot", "Steel Ingot",
					 "Gold Ingot", "Silver Ingot", "Mythril Ingot"]:
			r.category = "materials"

		# Decorations
		elif "decorative" in id or id in ["sugar_sculpture", "ember_lantern"]:
			r.category = "decorations"

		# Default
		else:
			r.category = "misc"


func _build_category_tabs() -> void:
	"""Dynamically build category tab buttons in the CraftTabBar."""
	var tab_bar: HBoxContainer = $Panel/Margin/Layout/MainBody/LeftCol/CraftTabBar
	# Clear existing children
	for child in tab_bar.get_children():
		child.queue_free()
	_tab_buttons.clear()

	_active_category = _categories[0]["key"]

	for cat in _categories:
		var key: String = cat["key"]
		var icon: String = cat["icon"]
		var label: String = cat["label"]

		var btn := Button.new()
		btn.text = "%s %s" % [icon, label]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 12)
		btn.pressed.connect(_on_category_tab_pressed.bind(key))
		tab_bar.add_child(btn)
		_tab_buttons[key] = btn

		# Add separator between tabs except after the last
		if cat != _categories.back():
			var sep := VSeparator.new()
			sep.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			tab_bar.add_child(sep)

	_update_tab_button_styles()


func _on_category_tab_pressed(category_key: String) -> void:
	if _active_category == category_key:
		return
	_active_category = category_key
	_selected_recipe = null
	_update_tab_button_styles()
	refresh()


func _update_tab_button_styles() -> void:
	var active_color := Color(1.0, 0.85, 0.3, 1.0)
	var inactive_color := Color(0.6, 0.5, 0.3, 0.6)
	for key: String in _tab_buttons:
		var btn: Button = _tab_buttons[key]
		btn.add_theme_color_override("font_color", active_color if key == _active_category else inactive_color)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_crafting"):
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


## Open the crafting UI. Pass forge=true to show only ingot recipes with no fuel cost.
func open(forge := false) -> void:
	_forge_mode = forge
	is_open = true
	AudioManager.play(AudioManager.Sound.MENU_OPEN)
	dim.visible = true
	panel.visible = true
	if not _hint_crafting_shown:
		_hint_crafting_shown = true
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_crafting_hint"):
			hud.show_crafting_hint()
	# Fade-in only; position tween breaks anchored panels
	panel.modulate.a = 0.0
	var tween := panel.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(panel, "modulate:a", 1.0, 0.25)
	refresh()


func close() -> void:
	is_open = false
	_forge_mode = false
	AudioManager.play(AudioManager.Sound.MENU_CLOSE)
	var tween := panel.create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(panel, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func():
		dim.visible = false
		panel.visible = false
	)


func _on_close_pressed() -> void:
	close()


func _build_forge_recipes(result: Array[CraftingRecipe]) -> void:
	"""Build temporary ingot-smelting recipes with fuel costs removed."""
	var template_recipes := [
		{"name": "Iron Ingot", "id": "iron_ingot", "display": "Iron Ingot", "amount": 1,
		 "ings": [{"item_id": "iron_ore", "amount": 4}]},
		{"name": "Copper Ingot", "id": "copper_ingot", "display": "Copper Ingot", "amount": 1,
		 "ings": [{"item_id": "copper_ore", "amount": 4}]},
		{"name": "Steel Ingot", "id": "steel_ingot", "display": "Steel Ingot", "amount": 1,
		 "ings": [{"item_id": "iron_ingot", "amount": 3}]},
		{"name": "Gold Ingot", "id": "gold_ingot", "display": "Gold Ingot", "amount": 1,
		 "ings": [{"item_id": "gold_ore", "amount": 3}]},
		{"name": "Silver Ingot", "id": "silver_ingot", "display": "Silver Ingot", "amount": 1,
		 "ings": [{"item_id": "silver_ore", "amount": 4}]},
		{"name": "Mythril Ingot", "id": "mythril_ingot", "display": "Mythril Ingot", "amount": 1,
		 "ings": [{"item_id": "silver_ingot", "amount": 2}, {"item_id": "gold_ingot", "amount": 1}, {"item_id": "obsidian_shard", "amount": 1}]},
	]
	for t in template_recipes:
		var r := CraftingRecipe.new()
		r.recipe_name = t.name
		r.result_item_id = t.id
		r.result_display_name = t.display
		r.result_amount = t.amount
		r.ingredients = t.ings.duplicate(true)
		r.category = "materials"
		result.append(r)


func _on_inventory_changed() -> void:
	if is_open:
		refresh()


func refresh() -> void:
	_clear(recipe_list)
	info_label.text = ""

	# Cache whether tabs should be visible
	var _tabs_visible := not _forge_mode
	for btn in _tab_buttons.values():
		btn.visible = _tabs_visible

	var current_recipes: Array[CraftingRecipe] = []

	if _forge_mode:
		_build_forge_recipes(current_recipes)
	else:
		# Filter recipes by active category
		for r in _recipes:
			if r.category == _active_category or (_active_category == "misc" and r.category == ""):
				current_recipes.append(r)
		# If no recipes in this category, fall back to misc
		if current_recipes.is_empty():
			for r in _recipes:
				if r.category == "misc":
					current_recipes.append(r)

	# Show category/forge header
	if _forge_mode:
		var header := Label.new()
		header.text = "-- 🔥 Forge (Free Smelting) --"
		header.add_theme_font_size_override("font_size", 13)
		header.add_theme_color_override("font_color", Color(0.91, 0.78, 0.29))
		header.add_theme_constant_override("margin_top", 4)
		recipe_list.add_child(header)
	else:
		for cat in _categories:
			if cat["key"] == _active_category:
				var header := Label.new()
				header.text = "-- %s %s --" % [cat["icon"], cat["label"]]
				header.add_theme_font_size_override("font_size", 13)
				header.add_theme_color_override("font_color", Color(0.91, 0.78, 0.29))
				header.add_theme_constant_override("margin_top", 4)
				recipe_list.add_child(header)
				break

	for recipe in current_recipes:

		var can_craft := recipe.can_craft()
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.add_theme_constant_override("separation", 6)

		# Background panel for the row so it looks clickable
		var bg_panel := PanelContainer.new()
		bg_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bg_panel.mouse_filter = Control.MOUSE_FILTER_PASS  # allow clicks to reach parent row
		var bg_style := StyleBoxFlat.new()
		bg_style.bg_color = Color(0.36, 0.25, 0.15, 1)
		if recipe == _selected_recipe:
			bg_style.border_color = Color(0.722, 0.525, 0.176, 1)
		else:
			bg_style.border_color = Color(0.545, 0.412, 0.122, 0.4)
		bg_style.set_border_width_all(1)
		bg_style.set_corner_radius_all(6)
		bg_panel.add_theme_stylebox_override("panel", bg_style)

		var inner_row := HBoxContainer.new()
		inner_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		inner_row.add_theme_constant_override("separation", 6)

		var name_label := Label.new()
		name_label.text = recipe.recipe_name
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_font_size_override("font_size", 13)
		name_label.add_theme_color_override("font_color", Color(0.91, 0.78, 0.29))
		inner_row.add_child(name_label)

		var ing_summary := Label.new()
		ing_summary.text = recipe.get_ingredient_summary()
		ing_summary.modulate = Color(1, 1, 1, 0.6)
		ing_summary.add_theme_font_size_override("font_size", 10)
		inner_row.add_child(ing_summary)

		var result_label := Label.new()
		result_label.text = "x%d %s" % [recipe.result_amount, recipe.result_display_name]
		result_label.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6, 1))
		result_label.add_theme_font_size_override("font_size", 11)
		inner_row.add_child(result_label)

		bg_panel.add_child(inner_row)
		row.add_child(bg_panel)

		# Click to select recipe and show details
		row.gui_input.connect(_on_recipe_row_gui_input.bind(recipe))
		# Hover highlight
		row.mouse_entered.connect(_on_recipe_row_mouse_entered.bind(bg_style))
		row.mouse_exited.connect(_on_recipe_row_mouse_exited.bind(bg_style, recipe))

		recipe_list.add_child(row)

	if current_recipes.is_empty():
		recipe_list.add_child(_hint_label("No recipes in this category yet."))

	# Update detail panel for selected recipe
	if _selected_recipe and _selected_recipe in current_recipes:
		_show_recipe_detail(_selected_recipe)
	else:
		_show_recipe_detail(null)


func _on_recipe_row_gui_input(event: InputEvent, recipe: CraftingRecipe) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_selected_recipe = recipe
		_show_recipe_detail(recipe)
		refresh()


func _on_recipe_row_mouse_entered(style: StyleBoxFlat) -> void:
	style.bg_color = Color(0.361, 0.239, 0.118, 0.85)


func _on_recipe_row_mouse_exited(style: StyleBoxFlat, recipe: CraftingRecipe) -> void:
	if recipe == _selected_recipe:
		style.bg_color = Color(0.2, 0.15, 0.08, 0.9)
	else:
		style.bg_color = Color(0.12, 0.12, 0.15, 0.8)


func _show_recipe_detail(recipe: CraftingRecipe) -> void:
	_clear(detail_ingredient_list)

	if recipe == null:
		detail_title.text = "Recipe"
		detail_result_label.text = "Result: --"
		_hide_preview_icon()
		detail_hint.visible = true
		craft_button.disabled = true
		return

	detail_hint.visible = false
	detail_title.text = recipe.recipe_name

	# Show result item icon preview
	_preview_result_icon(recipe)

	detail_result_label.text = "%s x%d" % [recipe.result_display_name, recipe.result_amount]

	var can_craft := recipe.can_craft()
	craft_button.disabled = not can_craft
	craft_button.text = "Craft" if can_craft else "Missing Materials"

	# Build ingredient list
	for ing in recipe.ingredients:
		var item_id: String = ing["item_id"]
		var needed: int = ing["amount"]
		var owned: int = InventoryManager.get_count(item_id)
		var item: ItemData = DataManager.get_item(item_id)
		var item_name: String = item.display_name if item else item_id

		var ing_row := HBoxContainer.new()
		ing_row.add_theme_constant_override("separation", 4)

		var icon_rect := ColorRect.new()
		icon_rect.custom_minimum_size = Vector2(12, 12)
		icon_rect.size = Vector2(12, 12)
		icon_rect.color = Color(0.4, 0.3, 0.1, 1) if owned >= needed else Color(0.5, 0.15, 0.15, 1)
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ing_row.add_child(icon_rect)

		var ing_label := Label.new()
		ing_label.text = "%s: %d / %d" % [item_name, owned, needed]
		ing_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ing_label.add_theme_font_size_override("font_size", 11)
		if owned >= needed:
			ing_label.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6, 1))
		else:
			ing_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3, 1))
		ing_row.add_child(ing_label)

		detail_ingredient_list.add_child(ing_row)


func _on_craft_selected() -> void:
	if _selected_recipe:
		_on_craft_pressed(_selected_recipe)


func _on_craft_pressed(recipe: CraftingRecipe) -> void:
	if recipe.craft():
		ToastNotification.show_toast("Crafted %s!" % recipe.result_display_name,
			ToastNotification.ToastType.SUCCESS)
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_first_action_hint"):
			hud.show_first_action_hint("first_craft",
				"Crafted! Right-click items in your inventory for details.")
		AudioManager.play(AudioManager.Sound.CRAFT)
		if _active_category == "alchemy":
			LevelManager.add_xp_source("brew")
		else:
			LevelManager.add_xp_source("craft")
		var crft_mgr := get_tree().get_first_node_in_group("objective_manager")
		if crft_mgr and crft_mgr.has_method("on_item_crafted"):
			crft_mgr.on_item_crafted()
		# Check if this is an ingot smelting (any item_id containing "ingot")
		if recipe.result_item_id and "ingot" in recipe.result_item_id:
			if crft_mgr and crft_mgr.has_method("on_smelt_ingot"):
				crft_mgr.on_smelt_ingot()
		refresh()
	else:
		ToastNotification.show_toast("Not enough materials!",
			ToastNotification.ToastType.ERROR)


func _preview_result_icon(recipe: CraftingRecipe) -> void:
	"""Show the result item icon in the detail panel preview."""
	if not preview_icon:
		return
	var item: ItemData = DataManager.get_item(recipe.result_item_id)
	if item and item.icon:
		preview_icon.texture = item.icon
		preview_icon.modulate = Color(1, 1, 1, 1)
		preview_icon.visible = true
		# Keep the texture rect visible even with null texture for empty slot look
	else:
		preview_icon.texture = null
		preview_icon.visible = true
		preview_icon.modulate = Color(0.3, 0.3, 0.3, 0.5)


func _hide_preview_icon() -> void:
	if preview_icon:
		preview_icon.texture = null
		preview_icon.visible = false


func _clear(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()


func _hint_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.modulate = Color(1, 1, 1, 0.7)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	return label
