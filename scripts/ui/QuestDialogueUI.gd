## QuestDialogueUI — Interactive dialogue panel for NPC quest interactions.
## Shows NPC dialogue with Accept/Decline buttons and quest progress display.
## Instanced as a child of HUD when dialogue starts, removed when closed.

extends PanelContainer
class_name QuestDialogueUI

## Emitted when the dialogue is closed by the player
signal dialogue_closed()

## NPC info
var _npc: Node = null
var _npc_name: String = ""
var _npc_role: int = -1

## Whether this dialogue is for a visitor NPC (uses visitor-specific quests).
var _is_visitor: bool = false

## Current dialogue state
var _current_quest: Dictionary = {}   # quest def being offered
var _current_dialogue_type: String = ""  # "offer", "progress", "complete"

## QuestManager is an autoload singleton — lazy reference
var _qm: Node = null

@onready var npc_name_label: Label = $VBoxContainer/NpcNameLabel
@onready var dialogue_text: RichTextLabel = $VBoxContainer/DialogueText
@onready var quest_title_label: Label = $VBoxContainer/QuestInfoVBox/QuestTitleLabel
@onready var quest_desc_label: Label = $VBoxContainer/QuestInfoVBox/QuestDescLabel
@onready var reward_label: Label = $VBoxContainer/QuestInfoVBox/RewardLabel
@onready var accept_button: Button = $VBoxContainer/ButtonRow/AcceptButton
@onready var decline_button: Button = $VBoxContainer/ButtonRow/DeclineButton
@onready var close_button: Button = $VBoxContainer/ButtonRow/CloseButton
@onready var progress_bar: ProgressBar = $VBoxContainer/QuestInfoVBox/ProgressBar
@onready var progress_text: Label = $VBoxContainer/QuestInfoVBox/ProgressText
@onready var quest_info_vbox: VBoxContainer = $VBoxContainer/QuestInfoVBox
@onready var button_row: HBoxContainer = $VBoxContainer/ButtonRow


func _ready() -> void:
	# Get the QuestManager autoload singleton
	_qm = get_node("/root/QuestManager")
	
	if accept_button:
		accept_button.pressed.connect(_on_accept)
	if decline_button:
		decline_button.pressed.connect(_on_decline)
	if close_button:
		close_button.pressed.connect(_on_close)
	
	# Hide initially
	if quest_info_vbox:
		quest_info_vbox.hide()
	if accept_button:
		accept_button.hide()
	if decline_button:
		decline_button.hide()


## Begin dialogue with a town resident NPC. Shows available quests or progress.
func start_dialogue(npc_node: Node, npc_name_str: String, npc_role: int) -> void:
	_npc = npc_node
	_npc_name = npc_name_str
	_npc_role = npc_role
	_is_visitor = false
	
	if npc_name_label:
		npc_name_label.text = _npc_name
	
	_show_next_interaction()


## Begin dialogue with a visitor NPC. Uses visitor-specific quest queries.
func start_visitor_dialogue(npc_node: Node, npc_name_str: String) -> void:
	_npc = npc_node
	_npc_name = npc_name_str
	_npc_role = -1
	_is_visitor = true
	
	if npc_name_label:
		npc_name_label.text = _npc_name
	
	_show_next_interaction()


func _show_next_interaction() -> void:
	if not _qm:
		_show_generic_dialogue()
		return
	
	if _is_visitor:
		_show_next_visitor_interaction()
		return
	
	# Priority 1: Quests that are ready to complete (turn in)
	var completable: Array = _qm.get_completable_quests_for_role(_npc_role)
	if not completable.is_empty():
		_show_complete_dialogue(completable[0])
		return
	
	# Priority 2: Available new quests
	var available: Array = _qm.get_available_quests_for_role(_npc_role)
	if not available.is_empty():
		_show_offer_dialogue(available[0])
		return
	
	# Priority 3: Show active quest progress
	var active_quest_ids: Array[String] = []
	for qid: String in _qm.active_quests.keys():
		var qdef = _qm.get_quest_defs().get(qid)
		if qdef and (qdef.get("giver_role", -1) == _npc_role or qdef.get("giver_role", -1) == -1):
			active_quest_ids.append(qid)
	
	if not active_quest_ids.is_empty():
		_show_progress_dialogue(active_quest_ids[0])
		return
	
	# Nothing quest-related — show generic greeting
	_show_generic_dialogue()


func _show_next_visitor_interaction() -> void:
	# Priority 1: Visitor quests ready to complete
	var completable: Array = _qm.get_completable_quests_for_visitor()
	if not completable.is_empty():
		_show_complete_dialogue(completable[0])
		return
	
	# Priority 2: Available new visitor quests
	var available: Array = _qm.get_available_quests_for_visitor()
	if not available.is_empty():
		_show_offer_dialogue(available[0])
		return
	
	# Priority 3: Active visitor quest progress
	var active_quest_ids: Array[String] = []
	for qid: String in _qm.active_quests.keys():
		var qdef = _qm.get_quest_defs().get(qid)
		if not qdef:
			continue
		var source: String = qdef.get("giver_source", "resident")
		if source == "visitor" or source == "any":
			active_quest_ids.append(qid)
	
	if not active_quest_ids.is_empty():
		_show_progress_dialogue(active_quest_ids[0])
		return
	
	# Nothing quest-related — show generic greeting
	_show_generic_dialogue()


# ── Offer dialogue ──────────────────────────────────────────────────────────

func _show_offer_dialogue(quest_def: Dictionary) -> void:
	_current_quest = quest_def
	_current_dialogue_type = "offer"
	
	var qid: String = quest_def.get("id", "")
	var dialogue_data: Dictionary = QuestManager.get_quest_dialogue(qid)  # static method
	
	dialogue_text.text = dialogue_data.get("intro", "I have a task for you.")
	
	_show_quest_info(quest_def)
	
	accept_button.text = "✅ Accept Quest"
	decline_button.text = "❌ Decline"
	accept_button.show()
	decline_button.show()
	close_button.hide()


# ── Progress dialogue ──────────────────────────────────────────────────────

func _show_progress_dialogue(quest_id: String) -> void:
	if not _qm:
		_show_generic_dialogue()
		return
	
	_current_dialogue_type = "progress"
	
	var qdef = QuestManager.get_quest_defs().get(quest_id)  # static method
	if not qdef:
		_show_generic_dialogue()
		return
	
	var dialogue_data: Dictionary = QuestManager.get_quest_dialogue(quest_id)  # static method
	
	if _qm.is_quest_completable(quest_id):
		dialogue_text.text = dialogue_data.get("complete", "All requirements met!")
		_show_quest_info(qdef)
		accept_button.text = "⭐ Turn In Quest"
		decline_button.text = "❌ Not Yet"
		accept_button.show()
		decline_button.show()
		close_button.hide()
	else:
		dialogue_text.text = dialogue_data.get("progress", "How goes the task?")
		_show_quest_info(qdef)
		accept_button.hide()
		decline_button.hide()
		close_button.text = "Close"
		close_button.show()


# ── Complete dialogue ──────────────────────────────────────────────────────

func _show_complete_dialogue(quest_def: Dictionary) -> void:
	_current_quest = quest_def
	_current_dialogue_type = "complete"
	
	var qid: String = quest_def.get("id", "")
	var dialogue_data: Dictionary = QuestManager.get_quest_dialogue(qid)  # static method
	
	dialogue_text.text = dialogue_data.get("complete", "You've done it!")
	
	_show_quest_info(quest_def)
	
	accept_button.text = "⭐ Claim Reward"
	decline_button.hide()
	accept_button.show()
	close_button.hide()


# ── Generic greeting ──────────────────────────────────────────────────────

func _show_generic_dialogue() -> void:
	_current_dialogue_type = "generic"
	_current_quest = {}
	
	# Pick a greeting from the NPC
	if _npc and _npc.has_method("_get_greeting"):
		dialogue_text.text = _npc._get_greeting()
	else:
		dialogue_text.text = "Hello there!"
	
	quest_info_vbox.hide()
	accept_button.hide()
	decline_button.hide()
	close_button.text = "Goodbye"
	close_button.show()


# ── Quest info display ─────────────────────────────────────────────────────

func _show_quest_info(quest_def: Dictionary) -> void:
	quest_info_vbox.show()
	
	if quest_title_label:
		quest_title_label.text = "📜 " + quest_def.get("title", "Quest")
	
	if quest_desc_label:
		quest_desc_label.text = quest_def.get("description", "")
	
	# Build reward string
	var reward_parts: Array[String] = []
	var gold: int = quest_def.get("reward_gold", 0)
	var rep: int = quest_def.get("reward_reputation", 0)
	var xp: int = quest_def.get("reward_xp", 0)
	var items: Array = quest_def.get("reward_items", [])
	
	if gold > 0:
		reward_parts.append("+%d coins" % gold)
	if rep > 0:
		reward_parts.append("+%d rep" % rep)
	if xp > 0:
		reward_parts.append("%d XP" % xp)
	for item in items:
		var id_str: String = item.get("id", "")
		var cnt: int = item.get("count", 1)
		if id_str == "gold":
			continue  # already counted above
		var display_name: String = id_str.capitalize()
		var item_data: ItemData = DataManager.get_item(id_str)
		if item_data:
			display_name = item_data.display_name
		reward_parts.append("x%d %s" % [cnt, display_name])
	
	if reward_parts.is_empty():
		reward_label.text = ""
	else:
		reward_label.text = "Rewards: " + ", ".join(reward_parts)
	
	# Show progress bar if active
	var qid: String = quest_def.get("id", "")
	if _qm and _qm.has_active_quest(qid):
		_update_progress_bar(qid)
		progress_bar.show()
		progress_text.show()
	else:
		progress_bar.hide()
		progress_text.hide()


func _update_progress_bar(quest_id: String) -> void:
	if not _qm or not progress_bar or not progress_text:
		return
	var qdef = QuestManager.get_quest_defs().get(quest_id)  # static method
	if not qdef:
		return
	var state: Dictionary = _qm.active_quests.get(quest_id, {})
	var reqs: Array = qdef.get("requirements", [])
	var total_done: int = 0
	var total_needed: int = 0
	var completed_reqs: Dictionary = state.get("completed_reqs", {})
	
	for req: Dictionary in reqs:
		var req_id: String = req.get("id", "")
		var req_count: int = req.get("count", 1)
		var done: int = completed_reqs.get(req_id, 0)
		total_done += mini(done, req_count)
		total_needed += req_count
	
	progress_bar.max_value = float(total_needed)
	progress_bar.value = float(total_done)
	progress_text.text = "%d / %d" % [total_done, total_needed]


# ── Button handlers ──────────────────────────────────────────────────────

func _on_accept() -> void:
	match _current_dialogue_type:
		"offer":
			_accept_quest()
		"complete":
			_complete_quest()
		"progress":
			if _qm and _qm.is_quest_completable(_current_quest.get("id", "")):
				_complete_quest()
			else:
				_on_close()


func _on_decline() -> void:
	_on_close()


func _on_close() -> void:
	dialogue_closed.emit()
	queue_free()


func _accept_quest() -> void:
	if not _qm:
		return
	var qid: String = _current_quest.get("id", "")
	if not qid.is_empty():
		if _qm.accept_quest(qid):
			var dialogue_data: Dictionary = QuestManager.get_quest_dialogue(qid)  # static method
			dialogue_text.text = dialogue_data.get("accept", "Thank you!")
			_show_quest_info(_current_quest)
			_close_after_delay()


func _complete_quest() -> void:
	if not _qm:
		return
	var qid: String = _current_quest.get("id", "")
	if not qid.is_empty():
		var qdef = QuestManager.get_quest_defs().get(qid)  # static method
		if not qdef:
			return
		
		var req_type: int = qdef.get("req_type", -1)
		var reqs: Array = qdef.get("requirements", [])
		
		# CRITICAL: Report delivery/collection progress BEFORE removing items,
		# so that report_delivery() populates completed_reqs before the
		# is_quest_completable() check inside complete_quest().
		if req_type == QuestManager.RequirementType.DELIVER_ITEMS:
			# Remove items from inventory first (they're being handed over)
			for req: Dictionary in reqs:
				var req_id: String = req.get("id", "")
				var req_count: int = req.get("count", 1)
				if InventoryManager.remove_item(req_id, req_count):
					_qm.report_delivery(qid, req_id, req_count)
		elif req_type == QuestManager.RequirementType.COLLECT_ITEMS:
			# For COLLECT_ITEMS, check the player's actual inventory count
			for req: Dictionary in reqs:
				var req_id: String = req.get("id", "")
				var req_count: int = req.get("count", 1)
				var have: int = InventoryManager.get_count(req_id)
				if have > 0:
					var taken: int = mini(have, req_count)
					InventoryManager.remove_item(req_id, taken)
					_qm.report_collection(req_id, taken)
		
		if _qm.complete_quest(qid):
			dialogue_text.text = "Thank you! Here's your reward!"
			_show_quest_info(_current_quest)
			_close_after_delay()


func _close_after_delay() -> void:
	accept_button.hide()
	decline_button.hide()
	close_button.hide()
	get_tree().create_timer(2.5).timeout.connect(_on_close)
