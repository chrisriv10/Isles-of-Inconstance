extends Interactable
class_name TravelBoat

## A separate boat docked at the pier offering expeditions via an expedition
## selection UI. Interacting opens the ExpeditionUI where the player can pick
## a random island (cheap) or choose a specific island type (more expensive).

const NPC_NAME: String = "Captain Briggs"
const DIALOGUE_TEXT: String = "Ahoy, explorer! Pick yer adventure — a random island for a fair price, or name yer destination for a heftier fee!"
const DIALOGUE_DURATION: float = 2.5

const EXPEDITION_UI_SCENE: PackedScene = preload("res://scenes/ui/ExpeditionUI.tscn")

@onready var sprite: Sprite2D = $BoatSprite
@onready var interaction_label: Label = $InteractionLabel
@onready var npc_name_label: Label = $NpcNameLabel
@onready var dialogue_bubble: Node2D = $DialogueBubble
@onready var dialogue_label: Label = $DialogueBubble/DialogueLabel

var player_in_range: bool = false
var _is_dialoguing: bool = false
var expedition_ui: CanvasLayer = null


func _ready() -> void:
	interaction_prompt = "Expedition"
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	interaction_label.add_theme_color_override("font_color", Color.WHITE)
	interaction_label.add_theme_constant_override("shadow_offset_x", 1)
	interaction_label.add_theme_constant_override("shadow_offset_y", 1)
	interaction_label.text = "[E] Expedition"
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

	# Instantiate the expedition UI and add it to the scene tree so it's ready
	# when the player interacts.
	expedition_ui = EXPEDITION_UI_SCENE.instantiate()
	add_child(expedition_ui)
	expedition_ui.visible = false


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

	# Brief pause, then open the expedition UI
	var tween := create_tween()
	tween.tween_interval(DIALOGUE_DURATION)
	tween.tween_callback(_on_dialogue_finished)


func _on_dialogue_finished() -> void:
	_hide_dialogue()
	_is_dialoguing = false
	if player_in_range:
		interaction_label.visible = true

	# Open the expedition selection UI
	if expedition_ui and expedition_ui.has_method("open"):
		expedition_ui.open()


func _hide_dialogue() -> void:
	dialogue_bubble.visible = false