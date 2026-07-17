extends Interactable
class_name TreeObject

## A harvestable tree in the world. When the player interacts, it gives wood
## and disappears (or becomes a stump for visual variety later).

@export var min_wood: int = 1
@export var max_wood: int = 3

var _tree_variant: int = 0

func _ready() -> void:
	interaction_prompt = "Chop"
	# Pick a random tree sprite
	_load_tree_sprite()

func _load_tree_sprite() -> void:
	var sprite_node: Sprite2D = $Sprite2D
	if not sprite_node:
		return

	# Try loading tree textures
	var tex1 := load("res://assets/generated/tree_01_frame_0.png")
	var tex2 := load("res://assets/generated/tree_02_frame_0.png")

	_tree_variant = randi() % 2
	if _tree_variant == 0 and tex1:
		sprite_node.texture = tex1
	elif tex2:
		sprite_node.texture = tex2
	else:
		sprite_node.visible = false

func interact(interactor: Node) -> void:
	if not can_interact():
		return

	var amount := randi_range(min_wood, max_wood)
	var added := InventoryManager.add_item("wood", amount)

	if added > 0:
		EffectSpawner.spawn_dirt_puff(global_position)
		ToastNotification.show_toast("Chop! Got %d wood" % amount, ToastNotification.ToastType.SUCCESS, 1.5)
		AudioManager.play(AudioManager.Sound.GATHER)

	_used = true
	queue_free()
