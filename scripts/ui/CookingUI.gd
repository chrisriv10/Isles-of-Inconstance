extends CanvasLayer
class_name CookingUI

## Cooking overlay UI. Opens with [K], shows all recipes from the CookingSystem,
## lets the player cook meals if they have the ingredients.

@onready var dim: ColorRect = $Dim
@onready var panel: PanelContainer = $Panel
@onready var recipe_list: VBoxContainer = %RecipeList
@onready var info_label: Label = %InfoLabel

var is_open: bool = false

# Cached meal categories for display
var _meal_categories: Dictionary = {
	"meal": "🍲 Meals",
	"drink": "🥤 Drinks",
	"dessert": "🍰 Desserts",
	"snack": "🥗 Snacks",
}

func _ready() -> void:
	add_to_group("cooking_ui")
	# open_cooking action is now defined in project.godot (bound to K key)

	# Connect to inventory changes to refresh
	InventoryManager.changed.connect(_on_inventory_changed)

	dim.visible = false
	panel.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_cooking"):
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
	# Animate open
	UITweenHelper.animate_open(panel, 0.25, 20.0)
	refresh()

func close() -> void:
	is_open = false
	UITweenHelper.animate_close(panel, 0.2, 20.0, func():
		dim.visible = false
		panel.visible = false
	)

func _on_close_pressed() -> void:
	close()

func _on_inventory_changed() -> void:
	if is_open:
		refresh()

## Get CookingSystem from the world node
func _get_cooking_system() -> CookingSystem:
	var world := get_tree().get_first_node_in_group("world")
	if world and world.has_method("get_cooking_system"):
		return world.get_cooking_system()
	return null

func refresh() -> void:
	_clear(recipe_list)
	info_label.text = ""

	var cs := _get_cooking_system()
	if not cs:
		info_label.text = "Build a campfire or kitchen to start cooking!"
		return

	var all_recipes: Array = cs.get_all_recipes()
	if all_recipes.is_empty():
		recipe_list.add_child(_hint_label("No recipes available."))
		return

	# Group recipes by category
	var grouped: Dictionary = {}  # category -> Array[MealData]
	for recipe_id in all_recipes:
		var meal := cs.get_meal(recipe_id)
		if not meal:
			continue
		var cat: String = meal.category
		if not grouped.has(cat):
			grouped[cat] = []
		grouped[cat].append(meal)

	# Display recipes grouped by category
	var category_order: Array[String] = ["meal", "drink", "snack", "dessert"]
	for cat in category_order:
		if not grouped.has(cat):
			continue
		var meals: Array = grouped[cat]

		# Category header
		var cat_header := Label.new()
		cat_header.text = _meal_categories.get(cat, cat)
		cat_header.add_theme_font_size_override("font_size", 14)
		cat_header.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
		cat_header.add_theme_constant_override("margin_top", 8)
		recipe_list.add_child(cat_header)

		for meal in meals:
			var can_cook := cs.can_cook(meal.id)
			var row := HBoxContainer.new()

			# Name + buff info
			var name_vbox := VBoxContainer.new()
			name_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

			var name_label := Label.new()
			name_label.text = meal.display_name
			name_label.add_theme_font_size_override("font_size", 12)
			name_vbox.add_child(name_label)

			var desc_label := Label.new()
			desc_label.text = meal.description
			desc_label.add_theme_font_size_override("font_size", 9)
			desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
			name_vbox.add_child(desc_label)

			var buff_str := ""
			var buff_name: String = meal.buff_type.capitalize()
			buff_str = "%s +%.0f%% (%dh)" % [buff_name, meal.buff_strength * 100.0, int(meal.buff_duration)]
			var buff_label := Label.new()
			buff_label.text = "✨ " + buff_str
			buff_label.add_theme_font_size_override("font_size", 9)
			buff_label.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
			name_vbox.add_child(buff_label)

			row.add_child(name_vbox)

			# Ingredients summary
			var ing_str := ""
			for ing_id in meal.ingredients:
				var needed: int = meal.ingredients[ing_id]
				if ing_id == "crop":
					ing_str += "Any crop x%d " % needed
				else:
					var item: ItemData = DataManager.get_item(ing_id)
					var ing_name: String = item.display_name if item else ing_id
					ing_str += "%s x%d " % [ing_name, needed]

			var ing_label := Label.new()
			ing_label.text = ing_str.strip_edges()
			ing_label.add_theme_font_size_override("font_size", 10)
			ing_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
			ing_label.custom_minimum_size = Vector2(140, 0)
			row.add_child(ing_label)

			# Cook button
			var cook_btn := Button.new()
			cook_btn.text = "Cook"
			cook_btn.disabled = not can_cook
			if can_cook:
				cook_btn.pressed.connect(_on_cook_pressed.bind(cs, meal.id))
			row.add_child(cook_btn)

			recipe_list.add_child(row)

func _on_cook_pressed(cs: CookingSystem, recipe_id: String) -> void:
	if cs.cook(recipe_id) > 0:
		var meal := cs.get_meal(recipe_id)
		var meal_name := meal.display_name if meal else recipe_id
		ToastNotification.show_toast("🍳 Cooked %s!" % meal_name, ToastNotification.ToastType.SUCCESS)
		refresh()
	else:
		ToastNotification.show_toast("Not enough ingredients!", ToastNotification.ToastType.ERROR)

func _clear(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()

func _hint_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	return label
