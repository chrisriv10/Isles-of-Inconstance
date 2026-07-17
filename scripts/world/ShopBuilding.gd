extends Interactable
class_name ShopBuilding

## Bigger, solid shop building with a collision blocker so the player cannot
## walk through it. Displays NPC name, a speech bubble on interact, then
## opens the Shop UI for buying seeds & upgrades.

const NPC_NAME: String = "Aldric the Trader"
const DIALOGUE_TEXT: String = "Welcome to my shop! I've got seeds, tools, and upgrades for a hardworking farmer like you. Take a look!"
const DIALOGUE_DURATION: float = 2.5

@onready var sprite: Sprite2D = $BuildingSprite
@onready var interaction_label: Label = $InteractionLabel
@onready var npc_name_label: Label = $NpcNameLabel
@onready var dialogue_bubble: Node2D = $DialogueBubble
@onready var dialogue_label: Label = $DialogueBubble/DialogueLabel

var player_in_range: bool = false
var _is_dialoguing: bool = false

func _ready() -> void:
	interaction_prompt = "Shop"
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Interaction label
	interaction_label.add_theme_color_override("font_color", Color.WHITE)
	interaction_label.add_theme_constant_override("shadow_offset_x", 1)
	interaction_label.add_theme_constant_override("shadow_offset_y", 1)
	interaction_label.text = "[E] Shop"
	interaction_label.visible = false

	# NPC name label (always visible)
	npc_name_label.text = NPC_NAME

	# Style the dialogue bubble background
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.88)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	dialogue_label.add_theme_stylebox_override("normal", style)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		if not _is_dialoguing:
			interaction_label.visible = true
		sprite.modulate = Color(1.2, 1.2, 1.2)

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		interaction_label.visible = false
		sprite.modulate = Color.WHITE
		_hide_dialogue()

func interact(interactor: Node) -> void:
	if _is_dialoguing:
		return
	super.interact(interactor)
	_show_dialogue()

func _show_dialogue() -> void:
	_is_dialoguing = true
	interaction_label.visible = false
	dialogue_label.text = DIALOGUE_TEXT
	dialogue_bubble.visible = true

	# Auto-hide after delay and open the shop UI
	var tween := create_tween()
	tween.tween_interval(DIALOGUE_DURATION)
	tween.tween_callback(_on_dialogue_finished)

func _on_dialogue_finished() -> void:
	_hide_dialogue()
	_is_dialoguing = false
	# Re-show interaction label if player is still in range
	if player_in_range:
		interaction_label.visible = true

	# Open the shop UI
	var shop_ui: CanvasLayer = get_tree().get_first_node_in_group("shop_ui")
	if shop_ui and shop_ui.has_method("open"):
		shop_ui.open()
	else:
		var event := InputEventAction.new()
		event.action = "open_shop"
		event.pressed = true
		Input.parse_input_event(event)

func _hide_dialogue() -> void:
	dialogue_bubble.visible = false
