extends CanvasLayer

## Pure presentation layer. Listens to GameManager / player interactor
## signals and updates labels - contains no game logic of its own so new UI
## panels can be added without risk of coupling gameplay to display code.

signal regenerate_world_requested(seed: int)

@onready var day_label: Label = %DayLabel
@onready var time_label: Label = %TimeLabel
@onready var money_label: Label = %MoneyLabel
@onready var interaction_prompt: Label = %InteractionPrompt
@onready var seed_input: LineEdit = %SeedInput
@onready var random_button: Button = %RandomButton
@onready var regenerate_button: Button = %RegenerateButton

func _ready() -> void:
	GameManager.day_changed.connect(_on_day_changed)
	GameManager.time_changed.connect(_on_time_changed)
	GameManager.money_changed.connect(_on_money_changed)

	_on_day_changed(GameManager.current_day)
	_on_time_changed(GameManager.get_hour(), GameManager.get_minute())
	_on_money_changed(GameManager.money)

	interaction_prompt.visible = false

	random_button.pressed.connect(_on_random_seed_pressed)
	regenerate_button.pressed.connect(_on_regenerate_pressed)

	var player := get_tree().get_first_node_in_group("player")
	if player:
		var interactor: Area2D = player.get_node_or_null("Interactor")
		if interactor:
			interactor.interactable_in_range.connect(_on_interactable_in_range)
			interactor.interactable_out_of_range.connect(_on_interactable_out_of_range)

func set_seed_display(seed_value: int) -> void:
	seed_input.text = str(seed_value)

func _on_random_seed_pressed() -> void:
	var new_seed := randi()
	seed_input.text = str(new_seed)

func _on_regenerate_pressed() -> void:
	var seed_value := seed_input.text.to_int()
	regenerate_world_requested.emit(seed_value)

func _on_day_changed(day: int) -> void:
	day_label.text = "Day %d" % day

func _on_time_changed(hour: int, minute: int) -> void:
	time_label.text = "%02d:%02d" % [hour, minute]

func _on_money_changed(amount: int) -> void:
	money_label.text = "$%d" % amount

func _on_interactable_in_range(interactable: Interactable) -> void:
	if interactable:
		interaction_prompt.text = "[E] %s" % interactable.interaction_prompt
		interaction_prompt.visible = true

func _on_interactable_out_of_range() -> void:
	interaction_prompt.visible = false
