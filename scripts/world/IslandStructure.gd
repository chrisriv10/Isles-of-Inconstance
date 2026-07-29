extends Interactable
class_name IslandStructure

## Configurable interactive structure that can be placed on expedition islands.
## Supports multiple behavior types: chest, buff shrine, merchant, forge, etc.
## Extends Interactable so the PlayerInteractor auto-detects it.

enum StructureType {
	CHEST,         # Give loot items from a configurable loot table
	BUFF_SHRINE,   # Grant a temporary buff on activation
	HEAL_POOL,     # Full heal + remove status effects
	FORGE,         # Free smelting station
	OVEN,          # Free cooking station
	MERCHANT,      # Opens a shop UI with island-specific wares
	WATER_WELL,    # Refill water containers
	REVEAL_MAP,    # Marks all Points Of Interest on the expedition island
	FROZEN_CHEST,  # Chest that requires a heat source (torch/fire item) to thaw
	PYRAMID_TRAP,  # Puzzle chest that needs a simple item sacrifice
}

## The type of structure — determines what happens on interact().
var structure_type: StructureType = StructureType.CHEST

## Config dictionary passed from the island generator.
var _config: Dictionary = {}

## Tracks if this structure has been interacted with (for single-use types).
var _was_used: bool = false

## Reference to the sprite node.
var _sprite: Sprite2D = null

## Reference to the collision shape for resizing.
var _collision_shape: CollisionShape2D = null

## Reference to the blocker shape (physics collision, layer 8).
var _blocker_shape: CollisionShape2D = null


func _ready() -> void:
	_sprite = $Sprite2D as Sprite2D
	_collision_shape = $CollisionShape2D as CollisionShape2D
	_blocker_shape = $Blocker/BlockerShape as CollisionShape2D
	
	collision_layer = 4
	collision_mask = 0
	monitorable = true


## Configure the structure right after instantiation.
func setup(type: StructureType, config: Dictionary) -> void:
	structure_type = type
	_config = config
	interaction_prompt = config.get("prompt", "Interact")
	single_use = config.get("single_use", false)
	
	var sprite_path: String = config.get("sprite", "")
	if not sprite_path.is_empty() and ResourceLoader.exists(sprite_path):
		var tex: Texture2D = load(sprite_path) as Texture2D
		var sprite := $Sprite2D as Sprite2D
		if tex and sprite:
			sprite.texture = tex
			sprite.centered = true
	
	var footprint: Vector2i = config.get("footprint", Vector2i(2, 2))
	var collision_shape := $CollisionShape2D as CollisionShape2D
	if collision_shape and collision_shape.shape is RectangleShape2D:
		var rect: RectangleShape2D = collision_shape.shape as RectangleShape2D
		rect.size = Vector2(footprint.x * 16.0, footprint.y * 16.0)
	
	# Size the physics blocker to match the footprint
	if _blocker_shape and _blocker_shape.shape is RectangleShape2D:
		var block_rect: RectangleShape2D = _blocker_shape.shape as RectangleShape2D
		block_rect.size = Vector2(footprint.x * 16.0, footprint.y * 16.0)


func interact(interactor: Node) -> void:
	if _was_used:
		return
	
	_was_used = true
	interacted.emit(interactor)
	
	match structure_type:
		StructureType.CHEST:
			_open_chest(interactor)
		StructureType.FROZEN_CHEST:
			_try_open_frozen_chest(interactor)
		StructureType.BUFF_SHRINE:
			_activate_buff(interactor)
		StructureType.HEAL_POOL:
			_heal_player(interactor)
		StructureType.FORGE:
			_open_forge(interactor)
		StructureType.OVEN:
			_open_oven(interactor)
		StructureType.MERCHANT:
			_open_shop(interactor)
		StructureType.WATER_WELL:
			_refill_water(interactor)
		StructureType.REVEAL_MAP:
			_reveal_map(interactor)
		StructureType.PYRAMID_TRAP:
			_solve_pyramid(interactor)


# ── Behaviour implementations ──────────────────────────────────────────

func _open_chest(interactor: Node) -> void:
	var loot: Array = _config.get("loot_table", [])
	_give_loot(interactor, loot)
	ToastNotification.show_toast("Found useful supplies!", ToastNotification.ToastType.SUCCESS, 2.5)


func _try_open_frozen_chest(interactor: Node) -> void:
	var has_heat: bool = _check_player_has_heat_source(interactor)
	
	if has_heat:
		var loot: Array = _config.get("loot_table", [])
		_give_loot(interactor, loot)
		ToastNotification.show_toast("The ice melts! Inside you find treasure.", ToastNotification.ToastType.SUCCESS, 3.0)
	else:
		_was_used = false
		ToastNotification.show_toast("The chest is frozen solid. You need a heat source to thaw it.", ToastNotification.ToastType.WARNING, 3.0)


func _activate_buff(_interactor: Node) -> void:
	var buff_type: String = _config.get("buff_type", "farming_speed")
	var duration: float = _config.get("buff_duration", 120.0)
	
	var buff_manager: Node = get_tree().get_first_node_in_group("buff_manager") if get_tree() else null
	if not buff_manager:
		buff_manager = get_tree().root.find_child("BuffManager", true, false) if get_tree() else null
	
	# BuffManager.apply_potion_effect expects: buff_type, strength, duration_in_minutes, source_name
	if buff_manager and buff_manager.has_method("apply_potion_effect"):
		var minutes: int = maxi(1, roundi(duration / 60.0))
		buff_manager.apply_potion_effect(buff_type, 1.0, minutes, "Expedition Shrine")
	
	var buff_name: String = buff_type.replace("_", " ").capitalize()
	ToastNotification.show_toast("Shrine activated! %s for %.0f seconds!" % [buff_name, duration], ToastNotification.ToastType.SUCCESS, 3.0)


func _heal_player(_interactor: Node) -> void:
	# Health is managed by the GameManager autoload, not the Player node
	GameManager.heal(999)
	
	ToastNotification.show_toast("You feel fully restored!", ToastNotification.ToastType.SUCCESS, 2.5)


func _open_forge(_interactor: Node) -> void:
	var crafting_ui: CanvasLayer = _find_ui("CraftingUI") as CanvasLayer
	if crafting_ui and crafting_ui.has_method("open"):
		crafting_ui.open(true) # forge mode — ingot recipes only, no fuel cost
	ToastNotification.show_toast("Free smelting — no fuel needed!", ToastNotification.ToastType.INFO, 2.5)


func _open_oven(_interactor: Node) -> void:
	var cooking_ui: CanvasLayer = _find_ui("CookingUI") as CanvasLayer
	if cooking_ui and cooking_ui.has_method("open"):
		cooking_ui.open()
	ToastNotification.show_toast("Fresh expedition cooking!", ToastNotification.ToastType.INFO, 2.5)


func _open_shop(_interactor: Node) -> void:
	var shop_ui: CanvasLayer = get_tree().get_first_node_in_group("shop_ui") if get_tree() else null
	if not shop_ui:
		ToastNotification.show_toast("The merchant has no goods to trade here.", ToastNotification.ToastType.WARNING, 2.5)
		return
	
	var shop_items: Array = _config.get("shop_items", [])
	var shop_title: String = _config.get("shop_title", "Expedition Trader")
	
	if shop_ui.has_method("open_with_items") and not shop_items.is_empty():
		shop_ui.open_with_items(shop_items, shop_title)
	elif shop_ui.has_method("open"):
		shop_ui.open()


func _refill_water(_interactor: Node) -> void:
	var player: Node = get_tree().get_first_node_in_group("player") if get_tree() else null
	if player:
		var inventory: Node = get_tree().get_first_node_in_group("inventory_manager") if get_tree() else null
		if inventory and inventory.has_method("refill_water"):
			inventory.refill_water(100)
	
	ToastNotification.show_toast("Water bucket filled!", ToastNotification.ToastType.SUCCESS, 2.0)


func _reveal_map(_interactor: Node) -> void:
	var world_map: Node = get_tree().get_first_node_in_group("world_map") if get_tree() else null
	if world_map and world_map.has_method("reveal_island"):
		world_map.reveal_island()
		ToastNotification.show_toast("Island layout revealed!", ToastNotification.ToastType.SUCCESS, 2.5)
	else:
		ToastNotification.show_toast("No map available to reveal.", ToastNotification.ToastType.WARNING, 2.5)


func _solve_pyramid(interactor: Node) -> void:
	var tribute_item: String = _config.get("tribute_item", "gold_ore")
	var inventory: Node = _get_player_inventory(interactor)
	
	if inventory and inventory.has_method("has_item") and inventory.has_item(tribute_item, 1):
		inventory.remove_item(tribute_item, 1)
		var loot: Array = _config.get("loot_table", [])
		_give_loot(interactor, loot)
		ToastNotification.show_toast("The pyramid accepts your offering and reveals its treasure!", ToastNotification.ToastType.SUCCESS, 3.0)
	else:
		_was_used = false
		var item_name: String = tribute_item.replace("_", " ").capitalize()
		ToastNotification.show_toast("The altar demands a %s as tribute." % [item_name], ToastNotification.ToastType.WARNING, 3.0)


# ── Helpers ────────────────────────────────────────────────────────────

func _give_loot(interactor: Node, loot_table: Array) -> void:
	var inventory: Node = _get_player_inventory(interactor)
	if not inventory:
		return
	
	for entry in loot_table:
		var item_id: String = ""
		var amount: int = 1
		var chance: float = 1.0
		
		if entry is Dictionary:
			item_id = entry.get("item_id", "")
			amount = entry.get("amount", 1)
			chance = entry.get("chance", 1.0)
		elif entry is String:
			item_id = entry
		else:
			continue
		
		if item_id.is_empty():
			continue
		
		if _get_rng().randf() < chance:
			inventory.add_item(item_id, amount)


func _check_player_has_heat_source(interactor: Node) -> bool:
	var inventory: Node = _get_player_inventory(interactor)
	if not inventory:
		return false
	
	var heat_items: Array[String] = ["torch", "lantern", "fire_starter", "lighter", "ember_dust", "coal", "magma_crystal"]
	for item_id in heat_items:
		if inventory.has_item(item_id, 1):
			return true
	
	var player: Node = interactor if interactor else get_tree().get_first_node_in_group("player") if get_tree() else null
	if player and player.has_method("get_held_item_id"):
		var held: String = player.get_held_item_id()
		for item_id in heat_items:
			if held == item_id:
				return true
	
	return false


func _get_player_inventory(interactor: Node) -> Node:
	# InventoryManager is an autoload singleton, not a child of the player.
	if get_tree() and get_tree().root.has_node("InventoryManager"):
		return get_tree().root.get_node("InventoryManager")
	if get_tree() and get_tree().current_scene and get_tree().current_scene.has_node("InventoryManager"):
		return get_tree().current_scene.get_node("InventoryManager")
	# Fallback: check if anyone in the tree has the right script
	if get_tree():
		for child in get_tree().root.get_children():
			if child is Node and child.has_method("has_item"):
				return child
	return null


func _find_ui(node_name: String) -> Node:
	## Finds a CanvasLayer UI node by name anywhere in the scene tree.
	## Searches root children first, then falls back to a deep search.
	var tree := get_tree()
	if not tree:
		return null
	# Check if we're in the Main scene (CraftingUI, CookingUI are direct children)
	var main := tree.root.find_child("Main", true, false)
	if main:
		var child := main.find_child(node_name, true, false)
		if child:
			return child
	# Fallback: deep search from root
	return tree.root.find_child(node_name, true, false)


func _get_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(_config.get("sprite", "") + str(position.length()))
	return rng
