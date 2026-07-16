extends CanvasLayer

## Pure presentation layer. Listens to GameManager / player interactor
## signals and updates labels - contains no game logic of its own so new UI
## panels can be added without risk of coupling gameplay to display code.

signal exit_to_menu_requested()

@onready var day_label: Label = %DayLabel
@onready var time_label: Label = %TimeLabel
@onready var money_label: Label = %MoneyLabel
@onready var interaction_prompt: Label = %InteractionPrompt/Label
@onready var interaction_prompt_panel: PanelContainer = %InteractionPrompt
@onready var seed_display_label: Label = %SeedDisplayLabel
@onready var menu_button: Button = %MenuButton
@onready var tool_label: Label = %ToolLabel
@onready var mutation_label: Label = %MutationLabel/Label
@onready var mutation_label_panel: PanelContainer = %MutationLabel
@onready var mutation_toast_timer: Timer = %MutationToastTimer
@onready var fade_overlay: ColorRect = %FadeOverlay
@onready var tutorial_hint: Label = %TutorialHint/Label
@onready var tutorial_hint_panel: PanelContainer = %TutorialHint
@onready var tutorial_hint_timer: Timer = %TutorialHintTimer

var _fade_tween: Tween
var _menu_confirm_dialog: ConfirmationDialog

func _ready() -> void:
	GameManager.day_changed.connect(_on_day_changed)
	GameManager.time_changed.connect(_on_time_changed)
	GameManager.money_changed.connect(_on_money_changed)
	GameManager.crop_mutated.connect(_on_crop_mutated)
	mutation_toast_timer.timeout.connect(_on_mutation_toast_timeout)

	_on_day_changed(GameManager.current_day)
	_on_time_changed(GameManager.get_hour(), GameManager.get_minute())
	_on_money_changed(GameManager.money)

	interaction_prompt_panel.visible = false
	
	# Initialize fade overlay
	if fade_overlay:
		fade_overlay.color = Color.BLACK
		fade_overlay.visible = false
	
	# Initialize tutorial hints
	if tutorial_hint:
		tutorial_hint.visible = false
	if tutorial_hint_panel:
		tutorial_hint_panel.visible = false
	if tutorial_hint_timer:
		tutorial_hint_timer.timeout.connect(_on_tutorial_hint_timeout)
		tutorial_hint_timer.one_shot = true
	
	# Show first tutorial hint after a delay
	get_tree().create_timer(2.0).timeout.connect(_show_first_hint)

	# Build confirmation dialog for returning to menu
	_menu_confirm_dialog = ConfirmationDialog.new()
	_menu_confirm_dialog.title = "Return to Menu"
	_menu_confirm_dialog.dialog_text = "Return to the main menu?\nYour game will be saved first."
	_menu_confirm_dialog.ok_button_text = "Yes, Return"
	_menu_confirm_dialog.cancel_button_text = "Cancel"
	_menu_confirm_dialog.exclusive = true
	_menu_confirm_dialog.confirmed.connect(_on_menu_confirmed)
	add_child(_menu_confirm_dialog)

	menu_button.pressed.connect(_on_menu_pressed)

	var player := get_tree().get_first_node_in_group("player")
	if player:
		if player.has_signal("active_tool_changed"):
			player.active_tool_changed.connect(_on_active_tool_changed)
		
		var interactor: Area2D = player.get_node_or_null("Interactor")
		if interactor:
			interactor.interactable_in_range.connect(_on_interactable_in_range)
			interactor.interactable_out_of_range.connect(_on_interactable_out_of_range)

func _on_active_tool_changed(tool_name: String) -> void:
	tool_label.text = "Tool: " + tool_name

func set_seed_display(seed_value: int) -> void:
	seed_display_label.text = "Seed: %d" % seed_value

func _on_menu_pressed() -> void:
	_menu_confirm_dialog.popup_centered()

func _on_menu_confirmed() -> void:
	exit_to_menu_requested.emit()

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
		interaction_prompt_panel.visible = true

func _on_interactable_out_of_range() -> void:
	interaction_prompt_panel.visible = false

func _on_crop_mutated(old_name: String, new_name: String, mutation_name: String) -> void:
	mutation_label.text = "✨ %s mutated into %s! (%s mutation)" % [old_name, new_name, mutation_name]
	mutation_label.visible = true
	mutation_label_panel.visible = true
	mutation_toast_timer.start()
	
	# Show toast notification for extra polish
	ToastNotification.show_toast("%s → %s!" % [old_name, new_name], ToastNotification.ToastType.SUCCESS, 4.0)

func _on_mutation_toast_timeout() -> void:
	mutation_label_panel.visible = false

## Fade screen to black, call callback, then fade back in
func fade_to_black(duration: float = 0.5, callback: Callable = Callable()) -> void:
	if not fade_overlay:
		if callback.is_valid():
			callback.call()
		return
	
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	
	fade_overlay.visible = true
	fade_overlay.modulate.a = 0.0
	
	_fade_tween = create_tween()
	_fade_tween.set_parallel(false)
	_fade_tween.tween_property(fade_overlay, "modulate:a", 1.0, duration)
	
	if callback.is_valid():
		_fade_tween.tween_callback(callback.call)
	
	_fade_tween.tween_property(fade_overlay, "modulate:a", 0.0, duration)
	_fade_tween.tween_callback(func(): fade_overlay.visible = false)

## Quick flash effect (for day changes, etc.)
func flash_screen(color: Color = Color.WHITE, duration: float = 0.3) -> void:
	if not fade_overlay:
		return
	
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	
	fade_overlay.visible = true
	fade_overlay.color = color
	fade_overlay.modulate.a = 0.5
	
	var flash_tween := create_tween()
	flash_tween.tween_property(fade_overlay, "modulate:a", 0.0, duration)
	flash_tween.tween_callback(func(): fade_overlay.visible = false)

# ---------------------------------------------------------------------------
# Tutorial hints
# ---------------------------------------------------------------------------

func _show_first_hint() -> void:
	show_tutorial_hint("Use WASD to move, F or SPACE to till soil")

func show_tutorial_hint(text: String) -> void:
	if not tutorial_hint:
		return
	
	tutorial_hint.text = text
	tutorial_hint.visible = true
	tutorial_hint_panel.visible = true
	
	if tutorial_hint_timer:
		tutorial_hint_timer.start(5.0)

func _on_tutorial_hint_timeout() -> void:
	tutorial_hint_panel.visible = false
