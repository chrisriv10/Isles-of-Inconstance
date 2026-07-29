extends Interactable
class_name ReturnBoat

## Captain Briggs' expedition ship on the island. Interacting with it returns the
## player to the main island (calls back on the World node).

const NPC_NAME: String = "Expedition Ship"
const DIALOGUE_TEXT: String = "The expedition ship is ready to take you back to the main island. Ready to set sail?"

@onready var sprite: Sprite2D = $Sprite2D
@onready var interaction_label: Label = $InteractionLabel
@onready var npc_name_label: Label = $NpcNameLabel
@onready var dialogue_bubble: Node2D = $DialogueBubble
@onready var dialogue_label: Label = $DialogueBubble/DialogueLabel

var player_in_range: bool = false
var _is_returning: bool = false

func _ready() -> void:
	interaction_prompt = "Return Home"
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	interaction_label.add_theme_color_override("font_color", Color.WHITE)
	interaction_label.add_theme_constant_override("shadow_offset_x", 1)
	interaction_label.add_theme_constant_override("shadow_offset_y", 1)
	interaction_label.text = "[E] Return"
	interaction_label.visible = false

	npc_name_label.text = NPC_NAME

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.88)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	dialogue_label.add_theme_stylebox_override("normal", style)
	dialogue_label.add_theme_constant_override("outline_size", 1)
	dialogue_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		if not _is_returning:
			interaction_label.visible = true
		sprite.modulate = Color(1.2, 1.2, 1.2)

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		interaction_label.visible = false
		sprite.modulate = Color.WHITE
		_hide_dialogue()

func interact(interactor: Node) -> void:
	if _is_returning:
		return
	super.interact(interactor)
	_show_dialogue()

func _show_dialogue() -> void:
	_is_returning = true
	interaction_label.visible = false
	dialogue_label.text = DIALOGUE_TEXT
	dialogue_bubble.visible = true

	# Brief pause then return to main island
	var tween := create_tween()
	tween.tween_interval(1.0)
	tween.tween_callback(_return_to_main_island)

func _return_to_main_island() -> void:
	_hide_dialogue()
	_is_returning = false

	AudioManager.play(AudioManager.Sound.BOAT_TRAVEL)

	# Find the World node and call return method
	var world: Node = get_tree().get_first_node_in_group("world")
	if world and world.has_method("return_from_island"):
		world.return_from_island()
	else:
		push_error("ReturnBoat: Could not find world node to return from island")
		# Fallback: just log
		var player := get_tree().get_first_node_in_group("player")
		if player:
			player.global_position = Vector2(800, 800)

func _hide_dialogue() -> void:
	dialogue_bubble.visible = false

func _on_dialogue_finished() -> void:
	_hide_dialogue()
	_is_returning = false
	if player_in_range:
		interaction_label.visible = true
