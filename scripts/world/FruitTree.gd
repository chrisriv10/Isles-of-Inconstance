extends TreeObject
class_name FruitTree

## A tree that gives both wood and fruit when harvested.
## Spawned in some biome locations instead of regular trees.
## Hold E to harvest — a progress bar fills above the tree.
## Fruit trees can be harvested with bare hands for fruit (no axe required).

func _ready() -> void:
	super()
	# Set inherited defaults for fruit trees (moved from exports to avoid
	# duplicating the parent class properties).
	fruit_item_id = "berry"
	min_fruit = 1
	max_fruit = 3
	interaction_prompt = "Harvest"
	required_tool = -1
	# Fruit trees give more wood than regular trees
	min_wood = 1
	max_wood = 3
	# Quick harvest hold (parent's chop_time is used for the progress bar)
	chop_time = 0.5
	if ResourceLoader.exists("res://assets/generated/fruit_tree_frame_0.png"):
		var sprite_node: Sprite2D = $Sprite2D
		if sprite_node:
			sprite_node.texture = load("res://assets/generated/fruit_tree_frame_0.png")


func interact(interactor: Node) -> void:
	if not can_interact():
		return
	
	# Start the parent's hold-to-chop progress bar (reused for harvest)
	_is_chopping = true
	_chop_progress = 0.0
	_chopper_ref = interactor
	_used = true
	_current_chop_time = chop_time  # 0.5 seconds
	
	# Show the progress bar (created by parent in _setup_progress_bar)
	_progress_bg.visible = true
	_progress_fill.visible = true
	_progress_fill.size.x = 0.0


## Override parent's completion to give fruit + conditional wood.
## The parent's _process() ticks the bar and calls this when full.
func _complete_chopping() -> void:
	_is_chopping = false
	_progress_bg.visible = false
	_progress_fill.visible = false
	
	var player: Player = _chopper_ref as Player if _chopper_ref and is_instance_valid(_chopper_ref) else null
	if not player:
		player = Interactable._resolve_player(_chopper_ref)
	
	var has_axe: bool = player != null and player.has_tool_active(Player.Tool.AXE)
	
	# Give wood if chopping with an axe
	if has_axe:
		var wood_pile := randi_range(min_wood, max_wood)
		var added_wood := InventoryManager.add_item("wood", wood_pile)
		if added_wood > 0:
			EffectSpawner.spawn_resource_notification("Wood", added_wood, global_position + Vector2(0, -8), Color(0.6, 0.4, 0.2))
	
	# Give fruit (works with or without axe — bare hands harvest)
	var level_bonus: int = 0
	if player:
		level_bonus = floori(LevelManager.get_level() / 10.0)
	if InventoryManager.can_fit(fruit_item_id, 1) or InventoryManager.has_item(fruit_item_id):
		var fruit_amount := randi_range(min_fruit, max_fruit) + level_bonus
		var added := InventoryManager.add_item(fruit_item_id, fruit_amount)
		if added > 0:
			EffectSpawner.spawn_floating_text("+%d %s" % [added, fruit_item_id.capitalize()], global_position + (Vector2(0, 8) if has_axe else Vector2.ZERO), Color(1.0, 0.6, 0.8))
			AudioManager.play(AudioManager.Sound.GATHER)
			LevelManager.add_xp_source("gather")
	else:
		EffectSpawner.spawn_floating_text("Inventory full!", global_position, Color.YELLOW)
		return
	
	_used = true
	AudioManager.play(AudioManager.Sound.DESTROY)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property($Sprite2D, "modulate:a", 0.0, 0.3)
	tween.tween_callback(_notify_and_free)


func _notify_and_free() -> void:
	var world: Node = get_tree().get_first_node_in_group("world")
	if world and world.has_method("notify_cell_object_removed"):
		world.notify_cell_object_removed(global_position)
	queue_free()


func _get_available_fruits() -> PackedStringArray:
	return PackedStringArray(["berry", "mushroom"])
