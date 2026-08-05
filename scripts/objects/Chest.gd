extends Interactable
class_name Chest

## A placeable storage chest. Interacting opens the ChestStorageUI showing
## the chest's contents alongside the player's inventory.

@export var chest_title: String = "Storage Chest"

var _container: ContainerInventory = null
var _chest_key: String = ""


func _init() -> void:
	_container = ContainerInventory.new(18)
	_chest_key = ""  # set deterministically in _ready (cell-based key for MP sync)
	
	# Add starter items — a modest boost so the world doesn't feel empty,
	# but not so much that gathering becomes pointless. The 8 stone here
	# pairs with wood from log stumps (no tool needed) to craft the first axe.
	_container.add_item("wood", 8)
	_container.add_item("stone", 8)
	_container.add_item("compost", 3)
	_container.add_item("berry", 5)
	_container.add_item("wooden_planks", 5)
	_container.add_item("vine", 3)
	_container.add_item("iron_ore", 2)
	_container.add_item("fence_material", 4)
	_container.add_item("torch", 2)


func _ready() -> void:
	# Generate a simple chest sprite
	_generate_chest_sprite()
	
	# Deterministic network key from the chest's world cell. Instance ids
	# differ per peer, so a per-instance key would never match across peers
	# and chest contents could not sync. Cell keys match World.cell_to_world.
	var cell := Vector2i(floori(global_position.x / 16.0), floori(global_position.y / 16.0))
	_chest_key = "%d,%d" % [cell.x, cell.y]
	
	# Set on collision layer 3 (bit 2 = value 4) so PlayerInteractor (mask=4)
	# detects it. Without this, the chest defaults to layer 1 and is never
	# detected by the player's interaction Area2D.
	collision_layer = 4
	monitorable = true
	
	# Set up collision shape
	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var rect := RectangleShape2D.new()
	rect.size = Vector2(28, 20)
	shape.shape = rect
	add_child(shape)
	shape.owner = self


func _generate_chest_sprite() -> void:
	# Use pre-generated pixel art chest sprite for higher quality
	var path: String = "res://assets/generated/chest_sprite.png"
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path) as Texture2D
		if tex:
			_set_sprite_texture(tex)
			return
	
	# Fallback: draw a simple brown chest/box shape
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	
	var body_color := Color(0.55, 0.3, 0.1)
	var lid_color := Color(0.45, 0.25, 0.08)
	var accent_color := Color(0.85, 0.65, 0.15)
	
	for y in range(16):
		for x in range(16):
			if y >= 6 and y <= 13 and x >= 2 and x <= 13:
				var shade: float = 1.0 - ((y - 6) / 8.0) * 0.3
				img.set_pixel(x, y, Color(
					body_color.r * shade, body_color.g * shade, body_color.b * shade, 1.0
				))
			if y >= 2 and y <= 5 and x >= 2 and x <= 13:
				var shade: float = 1.0 - ((y - 2) / 4.0) * 0.15
				img.set_pixel(x, y, Color(
					lid_color.r * shade, lid_color.g * shade, lid_color.b * shade, 1.0
				))
			if y >= 5 and y <= 6 and x >= 7 and x <= 8:
				img.set_pixel(x, y, accent_color)
	
	var fallback_tex := ImageTexture.create_from_image(img)
	_set_sprite_texture(fallback_tex)


## Apply a texture to the Sprite2D child.
func _set_sprite_texture(tex: Texture2D) -> void:
	for child in get_children():
		if child is Sprite2D:
			child.texture = tex
			return
	var sprite := Sprite2D.new()
	sprite.texture = tex
	add_child(sprite)
	sprite.owner = self


func interact(interactor: Node) -> void:
	if not can_interact():
		return
	
	if not _container:
		return
	
	# Find the ChestStorageUI and open it
	var chest_ui: ChestStorageUI = get_tree().get_first_node_in_group("chest_storage_ui") as ChestStorageUI
	if not chest_ui:
		chest_ui = get_tree().root.find_child("ChestStorageUI", true, false) as ChestStorageUI
	if not chest_ui:
		ToastNotification.show_toast("No storage UI available!", ToastNotification.ToastType.ERROR, 2.0)
		return
	
	chest_ui.open_for(_container, chest_title, Callable(), _chest_key)
	AudioManager.play(AudioManager.Sound.CHEST_OPEN)
	
	super.interact(interactor)
