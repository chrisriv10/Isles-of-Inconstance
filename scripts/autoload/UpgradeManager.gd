extends Node

## Autoload singleton. Tracks purchased upgrade levels and exposes the
## gameplay effects each level grants. Shop.gd is the only thing that calls
## purchase() - everyone else (InventoryManager, Player, World) just reads
## get_level()/the helper functions below.

signal upgrade_purchased(upgrade: Upgrade, new_level: int)

enum Upgrade { INVENTORY, TOOLS, FARMING_SPEED, RARE_SEEDS }

const MAX_LEVEL: int = 4

const NAMES := {
	Upgrade.INVENTORY: "Storage Satchel",
	Upgrade.TOOLS: "Tool Forge",
	Upgrade.FARMING_SPEED: "Green Thumb",
	Upgrade.RARE_SEEDS: "Seed Vault Access",
}

const DESCRIPTIONS := {
	Upgrade.INVENTORY: "Carry more distinct stacks of items at once.",
	Upgrade.TOOLS: "Your hoe and watering can affect more tiles per swing.",
	Upgrade.FARMING_SPEED: "Reduces the delay between tool uses.",
	Upgrade.RARE_SEEDS: "Unlocks rarer seeds - and any mutations you've discovered - in the shop.",
}

const BASE_COSTS := {
	Upgrade.INVENTORY: 75,
	Upgrade.TOOLS: 120,
	Upgrade.FARMING_SPEED: 100,
	Upgrade.RARE_SEEDS: 150,
}

var levels: Dictionary = {
	Upgrade.INVENTORY: 0,
	Upgrade.TOOLS: 0,
	Upgrade.FARMING_SPEED: 0,
	Upgrade.RARE_SEEDS: 0,
}

func get_level(upgrade: Upgrade) -> int:
	return levels.get(upgrade, 0)

func is_maxed(upgrade: Upgrade) -> bool:
	return get_level(upgrade) >= MAX_LEVEL

func get_cost(upgrade: Upgrade) -> int:
	var level := get_level(upgrade)
	return int(round(BASE_COSTS[upgrade] * pow(1.6, level)))

func get_name(upgrade: Upgrade) -> String:
	return NAMES[upgrade]

func get_description(upgrade: Upgrade) -> String:
	return DESCRIPTIONS[upgrade]

## Attempts to buy the next level of `upgrade`. Returns true on success.
func purchase(upgrade: Upgrade) -> bool:
	if is_maxed(upgrade):
		return false
	var cost := get_cost(upgrade)
	if not GameManager.spend_money(cost):
		return false
	levels[upgrade] = get_level(upgrade) + 1
	_apply_effects(upgrade)
	upgrade_purchased.emit(upgrade, levels[upgrade])
	return true

func _apply_effects(upgrade: Upgrade) -> void:
	if upgrade == Upgrade.INVENTORY:
		InventoryManager.set_capacity(InventoryManager.BASE_CAPACITY + get_level(upgrade) * InventoryManager.CAPACITY_PER_UPGRADE_LEVEL)
	# TOOLS / FARMING_SPEED / RARE_SEEDS are read on-demand via the helpers
	# below - there's no separate state to push anywhere else.

# ---------------------------------------------------------------------------
# Gameplay-facing helpers
# ---------------------------------------------------------------------------

## The set of tile-grid offsets the hoe/watering can affect around the
## targeted tile, based on the Tool Forge level (0 = single tile,
## 4 = a full 5x5 block).
func get_tool_area_cells(center: Vector2i) -> Array[Vector2i]:
	var tier := get_level(Upgrade.TOOLS)
	var cells: Array[Vector2i] = [center]
	if tier >= 1:
		for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			cells.append(center + offset)
	if tier >= 2:
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var c := center + Vector2i(dx, dy)
				if not cells.has(c):
					cells.append(c)
	if tier >= 3:
		for dx in range(-2, 3):
			for dy in range(-2, 3):
				if absi(dx) + absi(dy) <= 2:
					var c := center + Vector2i(dx, dy)
					if not cells.has(c):
						cells.append(c)
	if tier >= 4:
		for dx in range(-2, 3):
			for dy in range(-2, 3):
				var c := center + Vector2i(dx, dy)
				if not cells.has(c):
					cells.append(c)
	return cells

## Multiplier applied to the base tool-use cooldown; higher Green Thumb
## level = smaller multiplier = faster.
func get_farming_speed_multiplier() -> float:
	var level := get_level(Upgrade.FARMING_SPEED)
	return clampf(1.0 - level * 0.18, 0.28, 1.0)

## Highest CropGenetics.rarity_tier the shop is currently allowed to sell
## seeds for (0 Common .. 4 Legendary). Level 0 = Common only.
func get_max_purchasable_rarity_tier() -> int:
	return get_level(Upgrade.RARE_SEEDS)
