## TownUI — town overview panel bound to the N key.
## Shows: town map with ruin statuses, restoration progress per building,
## list of current residents, town level, and reputation.

extends CanvasLayer
class_name TownUI

@onready var title_label: Label = %TitleLabel
@onready var town_level_label: Label = %TownLevelLabel
@onready var reputation_label: Label = %ReputationLabel
@onready var residents_label: Label = %ResidentsLabel
@onready var progress_container: VBoxContainer = %ProgressContainer
@onready var residents_container: VBoxContainer = %ResidentsContainer
@onready var close_button: Button = %CloseButton
@onready var no_town_label: Label = %NoTownLabel
@onready var recruit_vacancy_label: Label = %RecruitVacancyLabel
@onready var recruit_visitor_label: Label = %RecruitVisitorLabel
@onready var tribute_section: VBoxContainer = %TributeSection
@onready var tribute_amount_label: Label = %TributeAmountLabel
@onready var tribute_status_label: Label = %TributeStatusLabel
@onready var collect_tribute_button: Button = %CollectTributeButton

## Look up the TownManager fresh each time — it's created during world
## generation and may not exist when _ready() runs.
func _get_town_manager() -> TownManager:
	return get_tree().get_first_node_in_group("town_manager") as TownManager

func _ready() -> void:
	if close_button:
		close_button.pressed.connect(_on_close)
	if collect_tribute_button:
		collect_tribute_button.pressed.connect(_on_collect_tribute)
	
	visible = false

func toggle() -> void:
	if visible:
		close()
	else:
		open()

func open() -> void:
	var tm := _get_town_manager()
	if not tm:
		no_town_label.text = "You haven't discovered the ruined town yet. Explore the island!"
		no_town_label.show()
		visible = true
		return
	
	no_town_label.hide()
	_refresh()
	visible = true

func close() -> void:
	visible = false

func _refresh() -> void:
	var tm := _get_town_manager()
	if not tm:
		return
	
	# Title
	title_label.text = "Town Overview — Tidehaven"
	
	# Town level
	var level_names: Dictionary = {
		0: "None",
		1: "Clearing 🌅",
		2: "Settlement 🌿",
		3: "Village 🏘️",
		4: "Town 🏙️",
		5: "Thriving 🌟",
	}
	town_level_label.text = "Level: %s" % [level_names.get(tm.town_level, "Unknown")]
	
	# Reputation
	reputation_label.text = "Reputation: %d" % [tm.reputation]
	
	# Restoration progress
	for child in progress_container.get_children():
		child.queue_free()
	
	var status_names: Dictionary = {
		0: "Rubble",
		1: "Cleared",
		2: "Restoring...",
		3: "Restored!",
		4: "Occupied 👤",
	}
	
	var defs: Array = TownManager.get_builtin_ruin_defs()
	for def in defs:
		if not (def is TownManager.RuinDef):
			continue
		var state: TownManager.RuinState = tm.get_ruin_state(def.id)
		if not state:
			continue
		
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var name_label := Label.new()
		name_label.text = def.building_name
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.add_theme_font_size_override("font_size", 11)
		row.add_child(name_label)
		
		var status_label := Label.new()
		status_label.text = status_names.get(state.status, "Unknown")
		status_label.add_theme_font_size_override("font_size", 10)
		status_label.add_theme_color_override("font_color", _get_status_color(state.status))
		row.add_child(status_label)
		
		# Progress for restoring
		if state.status == TownManager.RuinStatus.CLEARED or state.status == TownManager.RuinStatus.RESTORING:
			var pct: float = tm.get_restoration_pct(def.id)
			var pct_label := Label.new()
			pct_label.text = "%d%%" % [int(pct * 100.0)]
			pct_label.add_theme_font_size_override("font_size", 10)
			row.add_child(pct_label)
		
		progress_container.add_child(row)
	
	# Residents
	for child in residents_container.get_children():
		child.queue_free()
	
	var residents: Array = tm.get_residents()
	if residents.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No residents yet. Restore buildings to attract them!"
		empty_label.add_theme_font_size_override("font_size", 10)
		empty_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		residents_container.add_child(empty_label)
	else:
		for r in residents:
			var row := HBoxContainer.new()
			var name_label := Label.new()
			name_label.text = "%s — %s" % [r.npc_name, r.role.capitalize()]
			name_label.add_theme_font_size_override("font_size", 11)
			row.add_child(name_label)
			residents_container.add_child(row)
	
	residents_label.text = "Residents (%d)" % [residents.size()]
	
	# ── Recruitment info ──
	recruit_vacancy_label.text = "Vacancies: %d" % [tm.get_vacancy_count()]
	var vm := get_tree().get_first_node_in_group("visitor_manager") as Node
	var has_visitors: bool = false
	if vm and vm.has_method("has_active_visitors"):
		has_visitors = vm.has_active_visitors()
	recruit_visitor_label.text = "Visitors in town: %s" % ["✅ Yes! Talk to them!" if has_visitors else "❌ None today — wait for a ship to arrive"]
	recruit_visitor_label.add_theme_color_override("font_color", Color(0.6, 0.9, 0.5) if has_visitors else Color(0.7, 0.7, 0.7))
	
	# ── Daily Tribute (only shows when town is fully restored) ──
	if tm.town_fully_restored:
		tribute_section.show()
		var tribute_amount: int = _calc_tribute_amount()
		tribute_amount_label.text = "Today's tribute: %d money" % [tribute_amount]
		
		if tm.is_tribute_available():
			collect_tribute_button.disabled = false
			collect_tribute_button.text = "Collect Daily Tribute ($%d)" % [tribute_amount]
			tribute_status_label.text = "Available!"
			tribute_status_label.add_theme_color_override("font_color", Color(0.35, 0.7, 0.35, 1))
		else:
			collect_tribute_button.disabled = true
			collect_tribute_button.text = "Collected"
			tribute_status_label.text = "Come back tomorrow!"
			tribute_status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.35, 1))
	else:
		tribute_section.hide()

## Calculate the daily tribute amount based on reputation and residents.
func _calc_tribute_amount() -> int:
	var tm := _get_town_manager()
	if not tm:
		return 0
	return clampi(10 + tm.reputation / 50 + tm.get_residents().size() * 2, 10, 200)

## Called when the player clicks "Collect Daily Tribute".
func _on_collect_tribute() -> void:
	var tm := _get_town_manager()
	if not tm or not tm.is_tribute_available():
		return
	
	var amount: int = tm.collect_tribute()
	if amount > 0:
		ToastNotification.show_toast("💰 Collected %d money in daily tribute!" % [amount], ToastNotification.ToastType.SUCCESS, 3.0)
		_refresh()

func _get_status_color(status: int) -> Color:
	match status:
		TownManager.RuinStatus.RUBBLE:
			return Color(0.7, 0.3, 0.3)
		TownManager.RuinStatus.CLEARED:
			return Color(0.7, 0.7, 0.3)
		TownManager.RuinStatus.RESTORING:
			return Color(0.7, 0.7, 0.5)
		TownManager.RuinStatus.RESTORED:
			return Color(0.3, 0.8, 0.3)
		TownManager.RuinStatus.OCCUPIED:
			return Color(0.3, 0.6, 1.0)
	return Color.WHITE

func _on_close() -> void:
	close()

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
