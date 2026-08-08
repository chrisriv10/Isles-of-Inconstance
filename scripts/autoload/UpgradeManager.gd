extends Node

## Autoload singleton. Tracks purchased upgrade levels and exposes the
## gameplay effects each level grants. Shop.gd is the only thing that calls
## purchase() - everyone else (InventoryManager, Player, World) just reads
## get_level()/the helper functions below.

signal upgrade_purchased(upgrade: Upgrade, new_level: int)

enum Upgrade { INVENTORY, TOOLS, FARMING_SPEED, RARE_SEEDS, COMBAT, LUCK }

const MAX_LEVEL: int = 4

const NAMES := {
	Upgrade.INVENTORY: "Storage Satchel",
	Upgrade.TOOLS: "Tool Forge",
	Upgrade.FARMING_SPEED: "Green Thumb",
	Upgrade.RARE_SEEDS: "Seed Vault Access",
	Upgrade.COMBAT: "Combat Training",
	Upgrade.LUCK: "Mystic Luck",
}

const DESCRIPTIONS := {
	Upgrade.INVENTORY: "Carry more distinct stacks of items at once.",
	Upgrade.TOOLS: "Your hoe and watering can affect more tiles per swing.",
	Upgrade.FARMING_SPEED: "Reduces the delay between tool uses.",
	Upgrade.RARE_SEEDS: "Unlocks rarer seeds - and any mutations you've discovered - in the shop.",
	Upgrade.COMBAT: "Permanent melee damage boost - strikes hit harder (+3 damage per level).",
	Upgrade.LUCK: "Enemies drop loot more often, and rarities are more generous.",
}

const BASE_COSTS := {
	Upgrade.INVENTORY: 75,
	Upgrade.TOOLS: 120,
	Upgrade.FARMING_SPEED: 100,
	Upgrade.RARE_SEEDS: 150,
	Upgrade.COMBAT: 600,
	Upgrade.LUCK: 800,
}

var levels: Dictionary = {
	Upgrade.INVENTORY: 0,
	Upgrade.TOOLS: 0,
	Upgrade.FARMING_SPEED: 0,
	Upgrade.RARE_SEEDS: 0,
	Upgrade.COMBAT: 0,
	Upgrade.LUCK: 0,
}

func get_level(upgrade: Upgrade) -> int:
	return levels.get(upgrade, 0)

func is_maxed(upgrade: Upgrade) -> bool:
	return get_level(upgrade) >= MAX_LEVEL

func get_cost(upgrade: Upgrade) -> int:
	var level := get_level(upgrade)
	return roundi(BASE_COSTS[upgrade] * pow(1.6, level))

func get_upgrade_name(upgrade: Upgrade) -> String:
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
	AudioManager.play(AudioManager.Sound.LEVEL_UP)
	LevelManager.add_xp_source("buy_upgrade")
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
## targeted tile, based on the Tool Forge level.
func get_tool_area_cells(center: Vector2i) -> Array[Vector2i]:
	var tier := get_level(Upgrade.TOOLS)
	var size: int
	# Each Tool Forge level widens the hoe/watering-can area by one tile per
	# side, so EVERY level grants a benefit (previously Lv1 was identical to 0).
	match tier:
		0: size = 1   # 1 × 1   (single tile)
		1: size = 2   # 2 × 2   (4 tiles)
		2: size = 3   # 3 × 3   (9 tiles)
		3: size = 4   # 4 × 4   (16 tiles)
		4: size = 5   # 5 × 5   (25 tiles)
		_: size = 1
	var cells: Array[Vector2i] = []
	var half := (size - 1) / 2
	for dx in range(size):
		for dy in range(size):
			cells.append(center + Vector2i(dx - half, dy - half))
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

## Get all upgrade levels as dictionary (for save/load)
func get_upgrade_levels() -> Dictionary:
	return levels.duplicate()

## Set upgrade level directly (for save/load)
func set_upgrade_level(upgrade: Upgrade, level: int) -> void:
	var old_level := get_level(upgrade)
	levels[upgrade] = clampi(level, 0, MAX_LEVEL)
	if old_level != levels[upgrade]:
		_apply_effects(upgrade)
