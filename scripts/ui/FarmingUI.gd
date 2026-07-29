extends CanvasLayer
class_name FarmingUI

## Farming overview panel. Shows all planted crops with growth info, soil
## quality, watering status, and disease alerts, plus a tab for livestock
## management (health, affection, breeding status). Opened via the G key.

var _is_open: bool = false

@onready var dim: ColorRect = $Dim
@onready var panel: PanelContainer = $Panel
@onready var tab_container: TabContainer = %TabContainer
@onready var crop_list: VBoxContainer = %CropList
@onready var animal_list: VBoxContainer = %AnimalList
@onready var summary_label: Label = %SummaryLabel


func _ready() -> void:
	dim.visible = false
	panel.visible = false
	add_to_group("farming_ui")
	tab_container.set_tab_title(0, "🌱 Crops")
	tab_container.set_tab_title(1, "🐾 Animals")
	tab_container.tab_changed.connect(_on_tab_changed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_farming") or (event is InputEventKey and event.pressed and not event.is_echo() and event.keycode == KEY_G):
		toggle()
		get_viewport().set_input_as_handled()
	elif _is_open and event.is_action_pressed("close_menu"):
		close()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if _is_open:
		close()
	else:
		open()


func open() -> void:
	_is_open = true
	AudioManager.play(AudioManager.Sound.MENU_OPEN)
	dim.visible = true
	panel.visible = true
	_refresh()


func close() -> void:
	_is_open = false
	AudioManager.play(AudioManager.Sound.MENU_CLOSE)
	dim.visible = false
	panel.visible = false


func is_open() -> bool:
	return _is_open


## Refresh all tabs (crops + animals) and update the summary for the current tab.
func _refresh() -> void:
	_refresh_crops()
	_refresh_animals()
	_on_tab_changed(tab_container.current_tab)


## Populate the crop list with planted crops, growth info, and alerts.
func _refresh_crops() -> void:
	for child in crop_list.get_children():
		child.queue_free()

	var world := get_tree().get_first_node_in_group("world")
	if not world or not ("_soil_data" in world):
		var hint := Label.new()
		hint.text = "No world or farm data available."
		hint.modulate = Color(0.7, 0.7, 0.7)
		crop_list.add_child(hint)
		return

	var soil_data: Dictionary = world._soil_data
	var planted_crops: Array[Dictionary] = []

	for cell_key in soil_data:
		var soil = soil_data[cell_key]
		if not soil.is_tilled:
			continue
		if soil.crop_id != "":
			var crop_data: CropData = DataManager.get_crop(soil.crop_id)
			planted_crops.append({
				"cell": cell_key,
				"soil": soil,
				"crop_data": crop_data,
			})

	if planted_crops.is_empty():
		var hint := Label.new()
		hint.text = "No crops planted yet. Till soil with the Hoe [1] and plant seeds!"
		hint.modulate = Color(0.7, 0.7, 0.7)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD
		crop_list.add_child(hint)
		return

	# Sort by maturity (closest to harvest first)
	planted_crops.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_progress := float(a.soil.days_grown) / float(a.crop_data.days_to_grow if a.crop_data else 1)
		var b_progress := float(b.soil.days_grown) / float(b.crop_data.days_to_grow if b.crop_data else 1)
		return a_progress > b_progress
	)

	for entry in planted_crops:
		var soil: SoilData = entry.soil
		var crop_data = entry.crop_data
		var is_mature: bool = crop_data and soil.days_grown >= crop_data.days_to_grow

		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 26)

		# Water status icon
		var water_icon := Label.new()
		water_icon.text = "💧 " if soil.is_watered else "💦 "
		water_icon.add_theme_color_override("font_color", Color(0.3, 0.7, 1.0) if soil.is_watered else Color(0.5, 0.5, 0.6))
		water_icon.custom_minimum_size = Vector2(24, 0)
		row.add_child(water_icon)

		# Crop name + growth info
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var name_label := Label.new()
		var crop_name: String = crop_data.display_name if crop_data else "Unknown"
		if is_mature:
			name_label.text = "🌟 " + crop_name + " [READY]"
			name_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
		elif crop_data and soil.unwatered_days >= 2:
			name_label.text = "😰 " + crop_name + " (WILTED)"
			name_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.2))
		else:
			name_label.text = "🌱 " + crop_name
			name_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
		name_label.add_theme_font_size_override("font_size", 12)
		info.add_child(name_label)

		# Progress bar row
		if crop_data and crop_data.days_to_grow > 0:
			var progress_row := HBoxContainer.new()
			var bar := ProgressBar.new()
			bar.custom_minimum_size = Vector2(120, 8)
			bar.max_value = crop_data.days_to_grow
			bar.value = clampf(soil.days_grown, 0, crop_data.days_to_grow)
			bar.show_percentage = false

			# Color: green if watered, yellow if not, red if wilting
			if is_mature:
				bar.modulate = Color(0.3, 1.0, 0.3)
			elif soil.unwatered_days >= 2:
				bar.modulate = Color(1.0, 0.3, 0.2)
			elif not soil.is_watered:
				bar.modulate = Color(1.0, 0.9, 0.3)
			else:
				bar.modulate = Color(0.5, 0.9, 0.5)

			progress_row.add_child(bar)

			var day_label := Label.new()
			day_label.text = "Day %d/%d" % [soil.days_grown, crop_data.days_to_grow]
			day_label.add_theme_font_size_override("font_size", 9)
			day_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			day_label.custom_minimum_size = Vector2(60, 0)
			progress_row.add_child(day_label)

			info.add_child(progress_row)

		# Disease / mutation alerts
		var alert_str := ""
		if soil.disease and soil.disease.is_infected():
			alert_str += "⚠ Diseased! "
		if soil.has_mutation:
			alert_str += "✨ " + soil.mutation_name + "! "
		if soil.is_giant_crop:
			alert_str += "🌳 Giant! "

		if alert_str != "":
			var alert_label := Label.new()
			alert_label.text = alert_str.strip_edges()
			alert_label.add_theme_font_size_override("font_size", 9)
			alert_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))
			info.add_child(alert_label)

		row.add_child(info)
		crop_list.add_child(row)
		crop_list.add_child(HSeparator.new())


## Populate the animal list with all animals in the world group.
func _refresh_animals() -> void:
	for child in animal_list.get_children():
		child.queue_free()

	var animals: Array[Node] = get_tree().get_nodes_in_group("animals")
	if animals.is_empty():
		var hint := Label.new()
		hint.text = "No animals found on the farm. Find them in the wild and lead them to a fenced pen!"
		hint.modulate = Color(0.7, 0.7, 0.7)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD
		animal_list.add_child(hint)
		return

	# Sort by type then name
	animals.sort_custom(func(a: Node, b: Node) -> bool:
		var aa := a as Animal
		var bb := b as Animal
		if not aa or not bb:
			return false
		if aa.animal_type != bb.animal_type:
			return aa.animal_type < bb.animal_type
		return aa.animal_name < bb.animal_name
	)

	for animal_ref in animals:
		var a := animal_ref as Animal
		if not a:
			continue

		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 28)

		# Species icon based on type
		var icon_label := Label.new()
		icon_label.text = _get_animal_icon(a.animal_type) + " "
		icon_label.custom_minimum_size = Vector2(24, 0)
		row.add_child(icon_label)

		# Animal info column
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		# Name line
		var name_line := HBoxContainer.new()

		var name_label := Label.new()
		name_label.text = a.animal_name
		name_label.add_theme_font_size_override("font_size", 12)

		# Baby tag
		if a.is_baby:
			name_label.text += " 🐣"
			name_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))

		# Love mode tag
		if a.is_love_mode:
			name_label.text += " 💕"
			name_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.7))

		name_line.add_child(name_label)
		name_line.add_child(HSeparator.new())
		info.add_child(name_line)

		# Health bar row
		if a.current_health < a.max_health:
			var health_row := HBoxContainer.new()
			var bar := ProgressBar.new()
			bar.custom_minimum_size = Vector2(80, 8)
			bar.max_value = a.max_health
			bar.value = a.current_health
			bar.show_percentage = false
			var hp_ratio := float(a.current_health) / float(a.max_health)
			if hp_ratio > 0.66:
				bar.modulate = Color(0.3, 1.0, 0.3)
			elif hp_ratio > 0.33:
				bar.modulate = Color(1.0, 0.8, 0.2)
			else:
				bar.modulate = Color(1.0, 0.3, 0.2)
			health_row.add_child(bar)

			var hp_label := Label.new()
			hp_label.text = "HP %d/%d" % [a.current_health, a.max_health]
			hp_label.add_theme_font_size_override("font_size", 9)
			hp_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			health_row.add_child(hp_label)
			info.add_child(health_row)

		# Affection display
		if a._affection > 0.0:
			# ❤️ hearts proportional to affection level
			var heart_count := mini(int(a._affection / 20.0) + 1, 5)
			var affection_str := ""
			for _i in range(heart_count):
				affection_str += "❤️"
			if heart_count < 5:
				affection_str += "🖤".repeat(5 - heart_count)
			var aff_label := Label.new()
			aff_label.text = affection_str
			aff_label.add_theme_font_size_override("font_size", 9)
			info.add_child(aff_label)

		# Favorite foods display
		var love_foods: Array[String] = a.get_love_foods()
		if not love_foods.is_empty():
			var food_names: PackedStringArray = []
			for food_id in love_foods:
				var fd: ItemData = DataManager.get_item(food_id)
				food_names.append(fd.display_name if fd else food_id.capitalize())
			var food_label := Label.new()
			food_label.text = "❤️ " + ", ".join(food_names)
			food_label.add_theme_font_size_override("font_size", 9)
			food_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.7))
			info.add_child(food_label)

		row.add_child(info)
		animal_list.add_child(row)
		animal_list.add_child(HSeparator.new())


## Updates the summary label when the tab changes.
func _on_tab_changed(tab_index: int) -> void:
	if tab_index == 0:
		# Crops tab — recompute summary from _refresh_crops data stored in crop_list
		var total_planted: int = 0
		for child in crop_list.get_children():
			if child is HBoxContainer:
				total_planted += 1
		summary_label.text = "%d planted | 0 empty" % [total_planted]

		# Try to get more detailed stats from the world
		var world := get_tree().get_first_node_in_group("world")
		if world and "_soil_data" in world:
			var sd: Dictionary = world._soil_data
			var tilled: int = 0
			var watered: int = 0
			var ready_count: int = 0
			for cell_key in sd:
				var soil = sd[cell_key]
				if not soil.is_tilled:
					continue
				tilled += 1
				if soil.is_watered:
					watered += 1
				if soil.crop_id != "":
					var cd := DataManager.get_crop(soil.crop_id)
					if cd and soil.days_grown >= cd.days_to_grow:
						ready_count += 1
			var empty_tilled: int = tilled - total_planted
			summary_label.text = "%d planted (%d ready) | %d watered | %d empty" % [total_planted, ready_count, watered, empty_tilled]
	elif tab_index == 1:
		# Animals tab — count types
		var animals: Array[Node] = get_tree().get_nodes_in_group("animals")
		var total: int = animals.size()
		var babies: int = 0
		var love: int = 0
		var types: Dictionary = {}
		for a_ref in animals:
			var a := a_ref as Animal
			if not a:
				continue
			if a.is_baby:
				babies += 1
			if a.is_love_mode:
				love += 1
			types[a.animal_type] = types.get(a.animal_type, 0) + 1
		summary_label.text = "%d animals | %d babies | %d in love" % [total, babies, love]


## Returns an emoji icon for the given animal type string
func _get_animal_icon(animal_type: String) -> String:
	match animal_type:
		"chicken":
			return "🐔"
		"cow":
			return "🐄"
		"rabbit":
			return "🐰"
		"sheep":
			return "🐑"
		"pig":
			return "🐖"
		"goat":
			return "🐐"
		"deer":
			return "🦌"
		"squirrel":
			return "🐿️"
		"frog":
			return "🐸"
		"turtle":
			return "🐢"
		"snow_fox", "spirit_fox":
			return "🦊"
		"polar_bear":
			return "🐻‍❄️"
		"snow_owl":
			return "🦉"
		"gummy_bear":
			return "🧸"
		"marshmallow_puff":
			return "☁️"
		"licorice_worm":
			return "🪱"
		"ice_cream_sandwich_man":
			return "🍦"
		"gingerbread_man":
			return "🍪"
		"sand_lizard":
			return "🦎"
		"desert_scorpion":
			return "🦂"
		"meerkat":
			return "🐾"
		"ember_crawler":
			return "🐛"
		"ash_moth":
			return "🦋"
		"magma_slug":
			return "🐌"
		"glow_jelly":
			return "🪼"
		"lunar_moth":
			return "🌙"
		_:
			return "🐾"
