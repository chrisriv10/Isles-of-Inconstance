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
	# Wood and plant matter break down into nutrient-rich compost
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

	for recipe in _recipes:
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
