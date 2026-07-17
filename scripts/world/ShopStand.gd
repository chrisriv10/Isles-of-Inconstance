extends Interactable
class_name ShopStand

## Physical shop stand + NPC that spawns at a random walkable position on the
## island. When the player walks near, shows an interaction prompt and opens
## the shop UI on interaction.

@onready var sprite_npc: Sprite2D = $NPCSprite
@onready var sprite_stand: Sprite2D = $StandSprite
@onready var label: Label = $Label

var player_in_range: bool = false

func _ready() -> void:
	interaction_prompt = "Shop"

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Style the label
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_font_size_override("font_size", 10)

	# Load the merchant NPC sprite
	var npc_tex := load("res://assets/generated/merchant_npc_frame_0.png")
	if npc_tex:
		sprite_npc.texture = npc_tex
	else:
		sprite_npc.visible = false

	# Load the market stand sprite
	var stand_tex := load("res://assets/generated/market_stand_frame_0.png")
	if stand_tex:
		sprite_stand.texture = stand_tex
	else:
		sprite_stand.visible = false

	label.visible = false

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		label.text = "[E] Shop"
		label.visible = true
		# Auto-highlight the shop (visual feedback)
		sprite_npc.modulate = Color(1.2, 1.2, 1.2)
		sprite_stand.modulate = Color(1.2, 1.2, 1.2)

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		label.visible = false
		sprite_npc.modulate = Color.WHITE
		sprite_stand.modulate = Color.WHITE

## Opens the shop UI when the player interacts.
func interact(interactor: Node) -> void:
	var shop_ui: CanvasLayer = get_tree().get_first_node_in_group("shop_ui")
	if shop_ui and shop_ui.has_method("open"):
		shop_ui.open()
	else:
		# Fallback: try opening shop via [B] action
		var event := InputEventAction.new()
		event.action = "open_shop"
		event.pressed = true
		Input.parse_input_event(event)
