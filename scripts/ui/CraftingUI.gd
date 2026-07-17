extends CanvasLayer
class_name CraftingUI

## Toggleable crafting overlay. Shows available recipes, checks ingredients,
## and lets the player craft. New recipes can be added to the _recipes array
## without touching any UI code.

@onready var dim: ColorRect = $Dim
@onready var panel: PanelContainer = $Panel
@onready var recipe_list: VBoxContainer = %RecipeList
@onready var info_label: Label = %InfoLabel

var is_open: bool = false

# Registry of all known recipes. Add new ones here to make them craftable.
var _recipes: Array[CraftingRecipe] = []

func _ready() -> void:
	_build_default_recipes()

	# Connect to inventory changes to refresh
	InventoryManager.changed.connect(_on_inventory_changed)

	dim.visible = false
	panel.visible = false

func _build_default_recipes() -> void:
	# --- Tool Upgrade Kit ---
	var tool_kit := CraftingRecipe.new()
	tool_kit.recipe_name = "Tool Upgrade Kit"
	tool_kit.result_item_id = "tool_upgrade_kit"
	tool_kit.result_display_name = "Tool Upgrade Kit"
	tool_kit.result_amount = 1
	tool_kit.ingredients = [
		{"item_id": "stone", "amount": 5},
		{"item_id": "wood", "amount": 3},
	]
	_recipes.append(tool_kit)

	# --- Compost (speeds crop growth) ---
	var compost := CraftingRecipe.new()
	compost.recipe_name = "Compost"
	compost.result_item_id = "compost"
	compost.result_display_name = "Compost"
	compost.result_amount = 2
	compost.ingredients = [
		{"item_id": "wood", "amount": 3},
	]
	_recipes.append(compost)

	# --- Wooden Planks ---
	var planks := CraftingRecipe.new()
	planks.recipe_name = "Wooden Planks"
	planks.result_item_id = "wooden_planks"
	planks.result_display_name = "Wooden Planks"
	planks.result_amount = 4
	planks.ingredients = [
		{"item_id": "wood", "amount": 2},
	]
	_recipes.append(planks)
	
	# --- Quality Compost ---
	var qcompost := CraftingRecipe.new()
	qcompost.recipe_name = "Quality Compost"
	qcompost.result_item_id = "quality_compost"
	qcompost.result_display_name = "Quality Compost"
	qcompost.result_amount = 2
	qcompost.ingredients = [
		{"item_id": "compost", "amount": 2},
		{"item_id": "wood", "amount": 2},
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
	# These produce building items used by the building system
	var fence := CraftingRecipe.new()
	fence.recipe_name = "Fence"
	fence.result_item_id = "fence_material"
	fence.result_display_name = "Fence Material"
	fence.result_amount = 4
	fence.ingredients = [
		{"item_id": "wood", "amount": 2},
	]
	_recipes.append(fence)
	
	var stone_fence := CraftingRecipe.new()
	stone_fence.recipe_name = "Stone Fence"
	stone_fence.result_item_id = "stone_fence_material"
	stone_fence.result_display_name = "Stone Fence Material"
	stone_fence.result_amount = 4
	stone_fence.ingredients = [
		{"item_id": "stone", "amount": 3},
	]
	_recipes.append(stone_fence)
	
	var campfire := CraftingRecipe.new()
	campfire.recipe_name = "Campfire"
	campfire.result_item_id = "campfire_kit"
	campfire.result_display_name = "Campfire Kit"
	campfire.result_amount = 1
	campfire.ingredients = [
		{"item_id": "wood", "amount": 5},
		{"item_id": "stone", "amount": 3},
	]
	_recipes.append(campfire)


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

func _on_inventory_changed() -> void:
	if is_open:
		refresh()

func refresh() -> void:
	_clear(recipe_list)
	info_label.text = ""

	# Track when we hit the building recipes to add a section header
	var building_recipe_ids := ["Fence", "Stone Fence", "Campfire"]
	var tools_done := false
	var buildings_header_added := false

	for recipe in _recipes:
		# Add building section header when we reach the first building recipe
		if not buildings_header_added and recipe.recipe_name in building_recipe_ids:
			buildings_header_added = true
			var header := Label.new()
			header.text = "— Building Materials —"
			header.add_theme_font_size_override("font_size", 14)
			header.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
			header.add_theme_constant_override("margin_top", 12)
			recipe_list.add_child(header)
		
		var can_craft := recipe.can_craft()
		var row := HBoxContainer.new()

		var name_label := Label.new()
		name_label.text = recipe.recipe_name
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)

		var ing_label := Label.new()
		ing_label.text = recipe.get_ingredient_summary()
		ing_label.modulate = Color(1, 1, 1, 0.7)
		ing_label.add_theme_font_size_override("font_size", 11)
		row.add_child(ing_label)

		var result_label := Label.new()
		result_label.text = "→ %s x%d" % [recipe.result_display_name, recipe.result_amount]
		row.add_child(result_label)

		var craft_btn := Button.new()
		craft_btn.text = "Craft"
		craft_btn.disabled = not can_craft
		if can_craft:
			craft_btn.pressed.connect(_on_craft_pressed.bind(recipe))
		row.add_child(craft_btn)

		recipe_list.add_child(row)

	if _recipes.is_empty():
		recipe_list.add_child(_hint_label("No recipes available yet."))

func _on_craft_pressed(recipe: CraftingRecipe) -> void:
	if recipe.craft():
		ToastNotification.show_toast("Crafted %s!" % recipe.result_display_name,
			ToastNotification.ToastType.SUCCESS)
		refresh()
	else:
		ToastNotification.show_toast("Not enough materials!",
			ToastNotification.ToastType.ERROR)

func _clear(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()

func _hint_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.modulate = Color(1, 1, 1, 0.7)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	return label
