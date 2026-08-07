## LibraryResearch — research system at the library.
## Player can pay coins to unlock encyclopedia entries, reveal map fog,
## or research crop mutation paths.

extends Node
class_name LibraryResearch

## Research categories
enum ResearchType {
	ENCYCLOPEDIA,  # unlock an entry in the game guide
	MAP_FOG,       # reveal a patch of the world map
	CROP_MUTATION, # reveal a crop's mutation paths
}

## Cost for each research type
const ENCYCLOPEDIA_COST: int = 50
const MAP_FOG_COST: int = 100
const CROP_MUTATION_COST: int = 150

## Radius of map fog to reveal (in cells)
const MAP_REVEAL_RADIUS: int = 10

## How many encyclopedia entries are locked behind research
var _locked_encyclopedia_tabs: Array[String] = ["animals", "biomes", "buildings"]

func _ready() -> void:
	add_to_group("library_system")

## Get available research topics
func get_encyclopedia_topics() -> Array[Dictionary]:
	var topics: Array[Dictionary] = []
	for tab: String in _locked_encyclopedia_tabs:
		topics.append({
			"type": "encyclopedia",
			"tab": tab,
			"name": "Unlock '%s' Encyclopedia" % [tab.capitalize()],
			"cost": ENCYCLOPEDIA_COST,
			"completed": false,
		})
	return topics

func get_map_topic() -> Array[Dictionary]:
	return [{
		"type": "map_fog",
		"name": "Reveal Map Area",
		"desc": "Reveals a large patch of unexplored territory on the world map.",
		"cost": MAP_FOG_COST,
		"completed": false,
	}]

func get_crop_topics() -> Array[Dictionary]:
	var crops: Array = DataManager.crops.values()
	var topics: Array[Dictionary] = []
	for crop_res: Resource in crops:
		var crop: CropData = crop_res as CropData
		if not crop or crop.id.is_empty():
			continue
		# Only show crops the player has discovered
		if DataManager.is_discovered(crop.id):
			topics.append({
				"type": "crop_mutation",
				"crop_id": crop.id,
				"name": "Research %s" % [crop.display_name],
				"cost": CROP_MUTATION_COST,
				"completed": false,
			})
	return topics

## Perform a research action
func do_research(research_type: int, topic_id: String) -> Dictionary:
	match research_type:
		ResearchType.ENCYCLOPEDIA:
			return _research_encyclopedia(topic_id)
		ResearchType.MAP_FOG:
			return _research_map_fog()
		ResearchType.CROP_MUTATION:
			return _research_crop_mutation(topic_id)
	return {"success": false, "message": "Unknown research type."}

func _research_encyclopedia(tab_name: String) -> Dictionary:
	if not _locked_encyclopedia_tabs.has(tab_name):
		return {"success": false, "message": "This encyclopedia section is already unlocked!"}
	
	if GameManager.money < ENCYCLOPEDIA_COST:
		return {"success": false, "message": "Not enough coins! Need %d." % [ENCYCLOPEDIA_COST]}
	
	GameManager.money -= ENCYCLOPEDIA_COST
	GameManager.money_changed.emit(GameManager.money)
	_locked_encyclopedia_tabs.erase(tab_name)
	
	# Unlock in encyclopedia UI
	var enc := get_tree().get_first_node_in_group("encyclopedia")
	if enc and enc.has_method("unlock_tab"):
		enc.unlock_tab(tab_name)
	
	return {
		"success": true,
		"message": "'%s' section unlocked in the Encyclopedia!" % [tab_name.capitalize()],
	}

func _research_map_fog() -> Dictionary:
	if GameManager.money < MAP_FOG_COST:
		return {"success": false, "message": "Not enough coins! Need %d." % [MAP_FOG_COST]}
	
	GameManager.money -= MAP_FOG_COST
	GameManager.money_changed.emit(GameManager.money)
	
	# Reveal fog on world map around the player
	var player := get_tree().get_first_node_in_group("player")
	if player:
		var world_map := get_tree().get_first_node_in_group("world_map")
		if world_map and world_map.has_method("reveal_area"):
			var world_ref: Node = get_tree().get_first_node_in_group("world")
			var cell: Vector2i
			if world_ref and world_ref.has_method("world_to_cell"):
				cell = world_ref.world_to_cell(player.global_position)
			else:
				cell = Vector2i(int(player.global_position.x / 16), int(player.global_position.y / 16))
			world_map.reveal_area(cell, MAP_REVEAL_RADIUS)
	
	return {
		"success": true,
		"message": "A large area of the map has been revealed!",
	}

func _research_crop_mutation(crop_id: String) -> Dictionary:
	if GameManager.money < CROP_MUTATION_COST:
		return {"success": false, "message": "Not enough coins! Need %d." % [CROP_MUTATION_COST]}
	
	GameManager.money -= CROP_MUTATION_COST
	GameManager.money_changed.emit(GameManager.money)
	
	var crop_data := DataManager.get_crop(crop_id)
	if crop_data:
		var mutation_sys := MutationSystem.new()
		var info: String = mutation_sys.get_mutation_info(crop_id)
		return {
			"success": true,
			"message": info,
		}
	
	return {
		"success": true,
		"message": "Research complete! Study your crops carefully for mutations.",
	}

func _connect_research_button(btn: Button, research_node: LibraryResearch, topic: Dictionary, research_type_str: String) -> void:
	## Connect a research button with captured values (avoids loop capture bug).
	var t_type: String = topic.get("type", research_type_str)
	var t_id: String = topic.get("tab", topic.get("crop_id", topic.get("type", "")))
	btn.pressed.connect(func() -> void:
		var res_type: int
		match t_type:
			"encyclopedia": res_type = ResearchType.ENCYCLOPEDIA
			"map_fog": res_type = ResearchType.MAP_FOG
			"crop_mutation": res_type = ResearchType.CROP_MUTATION
			_: res_type = ResearchType.ENCYCLOPEDIA
		var result: Dictionary = research_node.do_research(res_type, t_id)
		ToastNotification.show_toast(result.get("message", "Research complete!"),
			ToastNotification.ToastType.SUCCESS if result.get("success", false) else ToastNotification.ToastType.INFO, 4.0)
	)

func get_locked_tabs() -> Array[String]:
	return _locked_encyclopedia_tabs.duplicate()

func is_completed(topic_type: String, topic_id: String) -> bool:
	return false  # Placeholder — track in serialization if needed

## Open the library research UI — shows available research topics the player
## can pay coins to unlock (encyclopedia tabs, map fog, crop mutations).
func open_ui() -> void:
	# Find a CanvasLayer to parent the popup (HUD is ideal)
	var hud: CanvasLayer = get_tree().get_first_node_in_group("hud") as CanvasLayer
	if not hud:
		ToastNotification.show_toast("The research desk is not ready yet.", ToastNotification.ToastType.INFO, 2.0)
		return
	
	# Create popup panel (declare FIRST so the dim's closure can reference it)
	var panel := Panel.new()
	panel.name = "LibraryResearchPopup"
	panel.size = Vector2(360, 300)
	panel.position = Vector2(
		(hud.get_viewport().get_visible_rect().size.x - panel.size.x) / 2.0,
		(hud.get_viewport().get_visible_rect().size.y - panel.size.y) / 2.0
	)
	panel.z_index = 100
	
	# Dim background (added FIRST so panel is on top for input)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.size = hud.get_viewport().get_visible_rect().size
	dim.z_index = 99
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			if is_instance_valid(panel):
				panel.queue_free()
			if is_instance_valid(dim):
				dim.queue_free()
	)
	hud.add_child(dim)
	
	# Add panel (added SECOND so it's on top for input, beating the dim)
	hud.add_child(panel)
	
	# Title
	var title := Label.new()
	title.text = "📚 Library Research"
	title.size = Vector2(panel.size.x, 30)
	title.position = Vector2(10, 10)
	title.add_theme_font_size_override("font_size", 16)
	panel.add_child(title)
	
	# Scroll container for topics
	var scroll := ScrollContainer.new()
	scroll.size = Vector2(panel.size.x - 20, panel.size.y - 80)
	scroll.position = Vector2(10, 45)
	panel.add_child(scroll)
	
	var vbox := VBoxContainer.new()
	vbox.size = Vector2(scroll.size.x, 0)
	vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(vbox)
	
	# Add research topics
	_add_topic_to_ui(vbox, self, "Unlock Encyclopedia Tab", get_encyclopedia_topics, "encyclopedia")
	_add_topic_to_ui(vbox, self, "Reveal Map Area", get_map_topic, "map_fog")
	_add_topic_to_ui(vbox, self, "Research Crop Mutation", get_crop_topics, "crop_mutation")
	
	# Close button
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.size = Vector2(100, 30)
	close_btn.position = Vector2((panel.size.x - 100) / 2.0, panel.size.y - 35)
	close_btn.pressed.connect(func() -> void:
		if is_instance_valid(panel):
			panel.queue_free()
		if is_instance_valid(dim):
			dim.queue_free()
	)
	panel.add_child(close_btn)

func _add_topic_to_ui(vbox: VBoxContainer, research_node: LibraryResearch, section_name: String, topics_getter: Callable, research_type_str: String) -> void:
	## Add a section header and its topics to the research UI.
	var header := Label.new()
	header.text = section_name
	header.add_theme_font_size_override("font_size", 13)
	header.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	vbox.add_child(header)
	
	var topics: Array[Dictionary] = topics_getter.call()
	if topics.is_empty():
		var empty := Label.new()
		empty.text = "  (nothing available)"
		empty.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		vbox.add_child(empty)
		return
	
	for topic: Dictionary in topics:
		var hbox := HBoxContainer.new()
		var name_label := Label.new()
		name_label.text = topic.get("name", "Unknown")
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(name_label)
		
		var cost_label := Label.new()
		cost_label.text = "$%d" % [topic.get("cost", 0)]
		cost_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
		hbox.add_child(cost_label)
		
		var btn := Button.new()
		btn.text = "Research"
		_connect_research_button(btn, research_node, topic, research_type_str)
		hbox.add_child(btn)
		vbox.add_child(hbox)
