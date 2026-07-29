extends CanvasLayer
class_name ObjectivesPanel

## Standalone objectives overlay. Shows all objectives grouped into
## category tabs with progress bars.
## Opened via O key in any game mode.
## Uses Dim + PanelContainer pattern matching CraftingUI / InventoryUI.

var _is_open: bool = false

@onready var dim: ColorRect = $Dim
@onready var panel: PanelContainer = $Panel
@onready var tab_container: TabContainer = %TabContainer
@onready var overview_label: Label = %OverviewLabel
@onready var next_goal_panel: PanelContainer = %NextGoalPanel
@onready var next_goal_icon: Label = %NextGoalIcon
@onready var next_goal_name: Label = %NextGoalName
@onready var next_goal_desc: Label = %NextGoalDesc

# Cached references
var _obj_mgr: Node = null
var _quest_mgr: Node = null


func _ready() -> void:
	dim.visible = false
	panel.visible = false
	add_to_group("objectives_panel")

	# Listen for objective updates
	_obj_mgr = get_tree().get_first_node_in_group("objective_manager")
	if _obj_mgr:
		_obj_mgr.objectives_updated.connect(_refresh_objectives)

	# Listen for quest updates
	_quest_mgr = get_tree().get_first_node_in_group("quest_manager")
	if _quest_mgr:
		if _quest_mgr.has_signal("quests_updated"):
			_quest_mgr.quests_updated.connect(_refresh_objectives)
		if _quest_mgr.has_signal("quest_accepted"):
			_quest_mgr.quest_accepted.connect(func(_a, _b): _refresh_objectives())
		if _quest_mgr.has_signal("quest_completed"):
			_quest_mgr.quest_completed.connect(func(_a, _b): _refresh_objectives())


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
	_refresh_objectives()


func close() -> void:
	_is_open = false
	AudioManager.play(AudioManager.Sound.MENU_CLOSE)
	dim.visible = false
	panel.visible = false


func is_open() -> bool:
	return _is_open


# --------------------------------------------------------------------------
# Overall progress + next-goal callout (shown above tabs)
# --------------------------------------------------------------------------

## Updates the overview header and "Next Goal" callout.
func _update_overview() -> void:
	if not _obj_mgr or not _obj_mgr.has_method("get_completed_count"):
		return
	
	var total: int = _obj_mgr.get_completed_count()
	var all_types_count: int = _get_total_objective_count()
	
	# Update overview text
	if overview_label:
		overview_label.text = "%d / %d objectives completed" % [total, all_types_count]
	
	# Update "Next Goal" callout
	next_goal_panel.visible = false
	if not _obj_mgr.has_method("get_active_objective"):
		return
	var active: Dictionary = _obj_mgr.get_active_objective()
	if active.is_empty():
		# All objectives completed!
		if overview_label:
			overview_label.text = "All %d objectives completed! 🎉" % [all_types_count]
		return
	
	if next_goal_icon:
		next_goal_icon.text = active.get("icon", "⭐")
	if next_goal_name:
		next_goal_name.text = "Next: %s" % active.get("name", "")
	if next_goal_desc:
		next_goal_desc.text = active.get("desc", "")
	next_goal_panel.visible = true


## Returns the total number of objectives across all categories.
func _get_total_objective_count() -> int:
	if not _obj_mgr:
		return 0
	var categories: Dictionary = _obj_mgr.OBJECTIVE_CATEGORIES if "OBJECTIVE_CATEGORIES" in _obj_mgr else {}
	var total: int = 0
	for cat_key in categories:
		var cat_data: Dictionary = categories.get(cat_key, {})
		total += cat_data.get("types", []).size()
	return total


# --------------------------------------------------------------------------
# Objectives display (tabbed by category)
# --------------------------------------------------------------------------

func _refresh_objectives() -> void:
	# Update the overview header first
	_update_overview()
	
	# Clear existing tab pages
	for child in tab_container.get_children():
		child.queue_free()

	if not _obj_mgr:
		var hint := Label.new()
		hint.text = "Objective system not available."
		hint.modulate = Color(0.7, 0.7, 0.7)
		tab_container.add_child(hint)
		return

	var defs: Dictionary = _obj_mgr.OBJECTIVE_DEFS if "OBJECTIVE_DEFS" in _obj_mgr else {}
	var categories: Dictionary = _obj_mgr.OBJECTIVE_CATEGORIES if "OBJECTIVE_CATEGORIES" in _obj_mgr else {}
	var category_order: Array[String] = _obj_mgr.get_category_order() if _obj_mgr.has_method("get_category_order") else []

	# Get the active (recommended) objective type
	var active_type: int = -1
	if _obj_mgr.has_method("get_active_objective"):
		var active: Dictionary = _obj_mgr.get_active_objective()
		if not active.is_empty():
			active_type = active.get("type", -1)

	for cat_key in category_order:
		var cat_data: Dictionary = categories.get(cat_key, {})
		var cat_types: Array = cat_data.get("types", [])
		var cat_name: String = cat_data.get("name", cat_key)
		var cat_icon: String = cat_data.get("icon", "📋")

		# Create the tab page: ScrollContainer with VBoxContainer
		var scroll := ScrollContainer.new()
		scroll.name = cat_icon + " " + cat_name
		var vbox := VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(vbox)
		tab_container.add_child(scroll)

		var tab_index := tab_container.get_tab_count() - 1
		tab_container.set_tab_title(tab_index, cat_icon + " " + cat_name)

		# Build summary for this category
		var cat_completed := 0
		var cat_total := cat_types.size()

		for obj_type in cat_types:
			var def_data: Dictionary = defs.get(obj_type, {})
			var name_str: String = def_data.get("name", "Objective")
			var desc_str: String = def_data.get("desc", "")
			var icon_str: String = def_data.get("icon", "⭐")
			var threshold: int = def_data.get("threshold", 1)
			var progress: int = _obj_mgr._progress.get(obj_type, 0)
			var is_completed: bool = _obj_mgr._completed.has(obj_type)
			var is_active: bool = (obj_type == active_type)

			if is_completed:
				cat_completed += 1

			var row := HBoxContainer.new()
			row.custom_minimum_size = Vector2(0, 36)

			var icon := Label.new()
			icon.text = icon_str + " "
			icon.custom_minimum_size = Vector2(24, 0)
			row.add_child(icon)

			var info := VBoxContainer.new()
			info.size_flags_horizontal = Control.SIZE_EXPAND_FILL

			var name_label := Label.new()
			if is_completed:
				name_label.text = "[DONE] " + name_str
				name_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
			elif is_active:
				name_label.text = "▶ " + name_str
				name_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.5))
			else:
				name_label.text = name_str
				name_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
			name_label.add_theme_font_size_override("font_size", 15)
			info.add_child(name_label)

			if desc_str != "":
				var desc_label := Label.new()
				desc_label.text = desc_str
				if is_active:
					desc_label.add_theme_color_override("font_color", Color(0.8, 0.9, 0.6))
				else:
					desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
				desc_label.add_theme_font_size_override("font_size", 13)
				info.add_child(desc_label)

			# Progress label
			var prog_label := Label.new()
			var clamped_progress := mini(progress, threshold)
			if is_completed:
				prog_label.text = "%d/%d ✓" % [threshold, threshold]
				prog_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
			elif is_active:
				prog_label.text = "%d/%d" % [clamped_progress, threshold]
				prog_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
			else:
				prog_label.text = "%d/%d" % [clamped_progress, threshold]
				prog_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
			prog_label.add_theme_font_size_override("font_size", 14)
			prog_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			info.add_child(prog_label)

			row.add_child(info)
			vbox.add_child(row)

			# Subtle separator between entries
			var sep := HSeparator.new()
			vbox.add_child(sep)

		# Category summary header at the top of the tab content
		var cat_header := Label.new()
		cat_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cat_header.add_theme_font_size_override("font_size", 16)
		cat_header.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
		cat_header.text = "%s: %d / %d" % [cat_name, cat_completed, cat_total]
		vbox.add_child(cat_header)
		vbox.move_child(cat_header, 0)

		# Separator after header
		var header_sep := HSeparator.new()
		vbox.add_child(header_sep)
		vbox.move_child(header_sep, 1)

	# ── Active Quests tab ──────────────────────────────────────────────
	if _quest_mgr:
		_build_quests_tab()

	# Auto-switch to the quests tab if there are active quests
	var auto_switch_to_quests := false
	if _quest_mgr:
		var active_quests_count: int = _quest_mgr.active_quests.size() if "active_quests" in _quest_mgr else 0
		auto_switch_to_quests = active_quests_count > 0
	
	if auto_switch_to_quests:
		# Quests tab is always the last tab
		tab_container.current_tab = tab_container.get_tab_count() - 1
	elif active_type >= 0:
		var tab_idx: int = 0
		for cat_key in category_order:
			var cat_data: Dictionary = categories.get(cat_key, {})
			var cat_types: Array = cat_data.get("types", [])
			if active_type in cat_types:
				tab_container.current_tab = tab_idx
				break
			tab_idx += 1
	elif tab_container.get_tab_count() > 0:
		tab_container.current_tab = 0


# --------------------------------------------------------------------------
# Quests tab — shows active NPC quests with progress
# --------------------------------------------------------------------------

## Build the "Active Quests" tab showing all in-progress quests.
func _build_quests_tab() -> void:
	if not _quest_mgr or not _quest_mgr.has_method("get_quest_defs"):
		return
	
	var active: Dictionary = _quest_mgr.active_quests if "active_quests" in _quest_mgr else {}
	var defs: Dictionary = _quest_mgr.get_quest_defs()
	var completed_list: Array = _quest_mgr.completed_quests if "completed_quests" in _quest_mgr else []
	
	# Create the tab page
	var scroll := ScrollContainer.new()
	scroll.name = "📜 Quests"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)
	tab_container.add_child(scroll)
	
	var tab_index := tab_container.get_tab_count() - 1
	tab_container.set_tab_title(tab_index, "📜 Quests")
	
	if active.is_empty():
		var empty_label := Label.new()
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		empty_label.add_theme_font_size_override("font_size", 12)
		empty_label.text = "No active quests.\nTalk to NPCs in town to find work."
		vbox.add_child(empty_label)
		
		# Show how many completed
		if completed_list.size() > 0:
			var completed_label := Label.new()
			completed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			completed_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
			completed_label.add_theme_font_size_override("font_size", 11)
			completed_label.text = "🏆 %d quests completed!" % [completed_list.size()]
			vbox.add_child(completed_label)
		return
	
	# Tab header
	var header := Label.new()
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 13)
	header.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	header.text = "Active Quests (%d)" % [active.size()]
	vbox.add_child(header)
	
	var header_sep := HSeparator.new()
	vbox.add_child(header_sep)
	
	# Show each active quest
	var quest_idx := 0
	for qid: String in active.keys():
		var qdef: Dictionary = defs.get(qid, {})
		if qdef.is_empty():
			continue
		
		var state: Dictionary = active[qid]
		var completed_reqs: Dictionary = state.get("completed_reqs", {})
		var reqs: Array = qdef.get("requirements", [])
		var title_str: String = qdef.get("title", "Quest")
		var desc_str: String = qdef.get("description", "")
		var is_completable: bool = _quest_mgr.is_quest_completable(qid) if _quest_mgr.has_method("is_quest_completable") else false
		
		# Quest entry container with subtle border
		var quest_panel := VBoxContainer.new()
		
		# Quest title
		var title_label := Label.new()
		if is_completable:
			title_label.text = "⭐ " + title_str + " — Ready to turn in!"
			title_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
		else:
			title_label.text = "📜 " + title_str
			title_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.5))
		title_label.add_theme_font_size_override("font_size", 12)
		quest_panel.add_child(title_label)
		
		# Description
		if not desc_str.is_empty():
			var desc_label := Label.new()
			desc_label.text = desc_str
			desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
			desc_label.add_theme_font_size_override("font_size", 10)
			desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			quest_panel.add_child(desc_label)
		
		# Progress bars for each requirement
		for req: Dictionary in reqs:
			var req_id: String = req.get("id", "")
			var req_count: int = req.get("count", 1)
			var done: int = completed_reqs.get(req_id, 0)
			
			var req_row := HBoxContainer.new()
			req_row.custom_minimum_size = Vector2(0, 22)
			
			var req_name := Label.new()
			req_name.text = req_id.capitalize() + ":"
			req_name.custom_minimum_size = Vector2(100, 0)
			req_name.add_theme_font_size_override("font_size", 10)
			req_name.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
			req_row.add_child(req_name)
			
			# Small progress bar
			var prog_bar := ProgressBar.new()
			prog_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			prog_bar.custom_minimum_size = Vector2(0, 14)
			prog_bar.max_value = float(req_count)
			prog_bar.value = float(mini(done, req_count))
			prog_bar.show_percentage = false
			req_row.add_child(prog_bar)
			
			var count_label := Label.new()
			count_label.text = "%d/%d" % [mini(done, req_count), req_count]
			count_label.custom_minimum_size = Vector2(40, 0)
			count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			count_label.add_theme_font_size_override("font_size", 10)
			if done >= req_count:
				count_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
			else:
				count_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.4))
			req_row.add_child(count_label)
			
			quest_panel.add_child(req_row)
		
		vbox.add_child(quest_panel)
		
		# Claim Rewards button for completable quests
		if is_completable:
			var claim_row := HBoxContainer.new()
			claim_row.alignment = BoxContainer.ALIGNMENT_CENTER
			var claim_btn := Button.new()
			claim_btn.text = "✅ Claim Rewards"
			claim_btn.add_theme_color_override("font_color", Color(0.1, 0.8, 0.1))
			claim_btn.add_theme_font_size_override("font_size", 13)
			claim_btn.custom_minimum_size = Vector2(180, 28)
			claim_btn.pressed.connect(func():
				if _quest_mgr and _quest_mgr.has_method("complete_quest"):
					if _quest_mgr.complete_quest(qid):
						_refresh_objectives()
			)
			claim_row.add_child(claim_btn)
			quest_panel.add_child(claim_row)
		
		# Separator between quests
		if quest_idx < active.size() - 1:
			var sep := HSeparator.new()
			vbox.add_child(sep)
		
		quest_idx += 1
	
	# Show completed quests count at the bottom
	if completed_list.size() > 0:
		var completed_label := Label.new()
		completed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		completed_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4, 0.7))
		completed_label.add_theme_font_size_override("font_size", 10)
		completed_label.text = "🏆 %d quests completed" % [completed_list.size()]
		vbox.add_child(completed_label)
