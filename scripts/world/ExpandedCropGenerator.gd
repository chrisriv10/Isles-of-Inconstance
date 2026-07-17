class_name ExpandedCropGenerator
extends RefCounted

## Generates a much larger variety of procedurally generated crop types.
## Extends the base ProceduralCropGenerator with more prefixes, roots,
## richer color palettes, larger silhouettes, and unique visual identities.

# Expanded prefix library - more vibrant and distinct colors/themes
const EXPANDED_PREFIXES: Array = [
	# Color-based prefixes with richer palettes
	{"name": "Sunfire", "hue": 0.08, "sat": 0.9, "val": 1.0, "weight": 20},
	{"name": "Ocean", "hue": 0.58, "sat": 0.7, "val": 0.9, "weight": 25},
	{"name": "Amber", "hue": 0.10, "sat": 0.8, "val": 0.85, "weight": 22},
	{"name": "Jade", "hue": 0.35, "sat": 0.6, "val": 0.8, "weight": 24},
	{"name": "Ruby", "hue": 0.0, "sat": 0.85, "val": 0.85, "weight": 18},
	{"name": "Sapphire", "hue": 0.6, "sat": 0.75, "val": 0.9, "weight": 16},
	{"name": "Topaz", "hue": 0.12, "sat": 0.7, "val": 0.9, "weight": 20},
	{"name": "Emerald", "hue": 0.3, "sat": 0.8, "val": 0.75, "weight": 18},
	{"name": "Amethyst", "hue": 0.75, "sat": 0.6, "val": 0.85, "weight": 15},
	{"name": "Copper", "hue": 0.07, "sat": 0.7, "val": 0.7, "weight": 22},
	{"name": "Pearl", "hue": 0.0, "sat": 0.0, "val": 0.95, "weight": 12},
	{"name": "Coral", "hue": 0.03, "sat": 0.8, "val": 0.85, "weight": 14},
	{"name": "Lavender", "hue": 0.75, "sat": 0.4, "val": 0.9, "weight": 20},
	{"name": "Mint", "hue": 0.4, "sat": 0.5, "val": 0.85, "weight": 22},
	{"name": "Peach", "hue": 0.09, "sat": 0.5, "val": 0.95, "weight": 20},
	{"name": "Storm", "hue": 0.6, "sat": 0.3, "val": 0.6, "weight": 10},
	{"name": "Blaze", "hue": 0.05, "sat": 0.9, "val": 0.95, "weight": 12},
	{"name": "Glacier", "hue": 0.55, "sat": 0.2, "val": 0.95, "weight": 10},
	{"name": "Autumn", "hue": 0.08, "sat": 0.8, "val": 0.8, "weight": 16},
	{"name": "Spring", "hue": 0.25, "sat": 0.6, "val": 0.9, "weight": 20},
	{"name": "Solar", "hue": 0.12, "sat": 0.85, "val": 1.0, "weight": 14},
	{"name": "Lunar", "hue": 0.0, "sat": 0.0, "val": 0.85, "weight": 10},
	{"name": "Wildfire", "hue": 0.04, "sat": 0.9, "val": 0.9, "weight": 8},
	{"name": "Deepwater", "hue": 0.62, "sat": 0.8, "val": 0.7, "weight": 10},
	{"name": "Thunder", "hue": 0.55, "sat": 0.7, "val": 0.75, "weight": 8},
	{"name": "Breeze", "hue": 0.3, "sat": 0.3, "val": 0.85, "weight": 18},
	{"name": "Dewdrop", "hue": 0.55, "sat": 0.4, "val": 0.9, "weight": 16},
	{"name": "Frost", "hue": 0.6, "sat": 0.15, "val": 0.95, "weight": 12},
	{"name": "Sunkissed", "hue": 0.09, "sat": 0.6, "val": 0.95, "weight": 18},
	{"name": "Meadow", "hue": 0.3, "sat": 0.5, "val": 0.8, "weight": 22},
	{"name": "Tropic", "hue": 0.25, "sat": 0.8, "val": 0.9, "weight": 14},
	{"name": "Highland", "hue": 0.22, "sat": 0.3, "val": 0.7, "weight": 14},
	{"name": "Crimson", "hue": 0.0, "sat": 0.9, "val": 0.8, "weight": 22},
	{"name": "Verdant", "hue": 0.28, "sat": 0.7, "val": 0.8, "weight": 28},
	{"name": "Azure", "hue": 0.58, "sat": 0.7, "val": 0.9, "weight": 24},
	{"name": "Golden", "hue": 0.12, "sat": 0.85, "val": 0.95, "weight": 20},
	{"name": "Violet", "hue": 0.75, "sat": 0.6, "val": 0.85, "weight": 18},
	{"name": "Ember", "hue": 0.05, "sat": 0.85, "val": 0.9, "weight": 16},
	{"name": "Shadow", "hue": 0.75, "sat": 0.3, "val": 0.25, "weight": 8},
	{"name": "Crystal", "hue": 0.55, "sat": 0.4, "val": 1.0, "weight": 6},
]

# Expanded root library - more plant forms
const EXPANDED_ROOTS: Array = [
	{"name": "Melon", "base_days": 2, "yield": -1, "value": 1.0, "weight": 35},
	{"name": "Berry", "base_days": 1, "yield": 1, "value": 0.8, "weight": 40, "regrows": true, "regrow_days": 2},
	{"name": "Root", "base_days": 3, "yield": 0, "value": 0.85, "weight": 32},
	{"name": "Vine", "base_days": 3, "yield": 1, "value": 1.0, "weight": 30},
	{"name": "Bulb", "base_days": 2, "yield": 0, "value": 0.9, "weight": 28},
	{"name": "Stalk", "base_days": 4, "yield": -1, "value": 0.75, "weight": 36},
	{"name": "Pod", "base_days": 2, "yield": 1, "value": 1.0, "weight": 35},
	{"name": "Bloom", "base_days": 2, "yield": 2, "value": 1.2, "weight": 18},
	{"name": "Cactus", "base_days": 4, "yield": 0, "value": 1.1, "weight": 32},
	{"name": "Fungus", "base_days": 3, "yield": 0, "value": 0.9, "weight": 30},
	{"name": "Tuber", "base_days": 3, "yield": 0, "value": 1.0, "weight": 35},
	{"name": "Frond", "base_days": 2, "yield": 1, "value": 0.85, "weight": 24},
	{"name": "Knob", "base_days": 2, "yield": 0, "value": 0.8, "weight": 38},
	{"name": "Cap", "base_days": 2, "yield": 1, "value": 1.0, "weight": 26},
	{"name": "Sprig", "base_days": 1, "yield": 2, "value": 1.15, "weight": 16, "regrows": true, "regrow_days": 3},
	{"name": "Clump", "base_days": 3, "yield": -1, "value": 0.7, "weight": 38},
	{"name": "Shard", "base_days": 2, "yield": 0, "value": 1.3, "weight": 8},
	{"name": "Husk", "base_days": 4, "yield": -2, "value": 0.65, "weight": 40},
	{"name": "Plume", "base_days": 1, "yield": 2, "value": 1.4, "weight": 12},
	{"name": "Tendril", "base_days": 3, "yield": 1, "value": 1.0, "weight": 32, "regrows": true, "regrow_days": 4},
	# New roots
	{"name": "Apple", "base_days": 3, "yield": 0, "value": 1.1, "weight": 22},
	{"name": "Corn", "base_days": 4, "yield": 0, "value": 0.9, "weight": 28},
	{"name": "Tomato", "base_days": 3, "yield": 1, "value": 1.0, "weight": 26, "regrows": true, "regrow_days": 2},
	{"name": "Pepper", "base_days": 3, "yield": 1, "value": 1.1, "weight": 20},
	{"name": "Lettuce", "base_days": 2, "yield": 0, "value": 0.7, "weight": 35},
	{"name": "Bean", "base_days": 2, "yield": 1, "value": 0.85, "weight": 30},
	{"name": "Carrot", "base_days": 3, "yield": 0, "value": 0.8, "weight": 32},
	{"name": "Turnip", "base_days": 2, "yield": 0, "value": 0.75, "weight": 34},
	{"name": "Pumpkin", "base_days": 5, "yield": 0, "value": 1.4, "weight": 10},
	{"name": "Sunflower", "base_days": 3, "yield": 2, "value": 1.2, "weight": 16, "regrows": true, "regrow_days": 3},
	{"name": "Wheat", "base_days": 3, "yield": 1, "value": 0.65, "weight": 38},
	{"name": "Rice", "base_days": 4, "yield": 1, "value": 0.8, "weight": 28},
	{"name": "Gourd", "base_days": 4, "yield": 0, "value": 1.1, "weight": 18},
	{"name": "Herb", "base_days": 1, "yield": 1, "value": 0.9, "weight": 30, "regrows": true, "regrow_days": 1},
	{"name": "Flax", "base_days": 3, "yield": 0, "value": 0.7, "weight": 32},
	{"name": "Hops", "base_days": 4, "yield": 1, "value": 1.0, "weight": 20, "regrows": true, "regrow_days": 3},
	{"name": "Coffee", "base_days": 5, "yield": 1, "value": 1.5, "weight": 8, "regrows": true, "regrow_days": 4},
	{"name": "Tea", "base_days": 4, "yield": 1, "value": 1.2, "weight": 12, "regrows": true, "regrow_days": 3},
	{"name": "Grape", "base_days": 4, "yield": 1, "value": 1.3, "weight": 14, "regrows": true, "regrow_days": 4},
	{"name": "Cotton", "base_days": 3, "yield": 0, "value": 0.9, "weight": 22},
]

var _rng: RandomNumberGenerator

func _init(rng: RandomNumberGenerator) -> void:
	_rng = rng

## Generate a batch of N unique crops using the expanded libraries
func generate_batch(count: int, existing_ids: Dictionary = {}) -> Array:
	var results: Array = []
	var used_names: Dictionary = existing_ids.duplicate()
	
	var attempts := 0
	while results.size() < count and attempts < count * 50:
		attempts += 1
		var crop := _generate_one()
		if crop == null or used_names.has(crop.display_name):
			continue
		used_names[crop.display_name] = true
		results.append(crop)
	
	return results

func _generate_one() -> CropData:
	var prefix_data := _pick_weighted(EXPANDED_PREFIXES)
	var root_data := _pick_weighted(EXPANDED_ROOTS)
	
	if prefix_data == null or root_data == null:
		return null
	
	var crop_name: String = prefix_data.name + " " + root_data.name
	var crop_id: String = crop_name.to_lower().replace(" ", "_")
	
	# Build stats
	var base_days: int = root_data.base_days
	var yield_final: int = clampi(1 + root_data.yield, 1, 5)
	var value_mult: float = root_data.value
	var base_price: int = maxi(1, floori(8.0 * value_mult))
	
	# Rarity
	var rarity: String = _weight_to_rarity(min(prefix_data.weight, root_data.weight))
	
	# Color - generate rich, varied colors
	var hue: float = prefix_data.hue + randf_range(-0.03, 0.03)
	var sat: float = prefix_data.sat + randf_range(-0.1, 0.1)
	var val: float = prefix_data.val + randf_range(-0.1, 0.1)
	var crop_color := Color.from_hsv(fmod(hue, 1.0), clampf(sat, 0.3, 1.0), clampf(val, 0.4, 1.0))
	
	# Assemble CropData
	var crop := CropData.new()
	crop.id = crop_id
	crop.display_name = crop_name
	crop.days_to_grow = base_days
	crop.yield_item_id = crop_id + "_yield"
	crop.seed_item_id = crop_id + "_seed"
	crop.yield_amount = yield_final
	crop.regrows = root_data.get("regrows", false)
	crop.regrow_days = root_data.get("regrow_days", 2)
	crop.requires_water = true
	crop.modulate_color = crop_color
	crop.rarity = rarity
	crop.size_trait = _days_to_size(base_days)
	crop.growth_stage_textures = []
	
	# Genetics
	var genetics := CropGenetics.new()
	genetics.color_hue = crop_color.h
	genetics.color_saturation = crop_color.s
	genetics.color_value = crop_color.v
	genetics.size_factor = _size_label_to_factor(crop.size_trait)
	genetics.growth_speed_factor = 1.0
	genetics.value_factor = value_mult
	genetics.rarity_tier = _rarity_to_tier(rarity)
	genetics.mutation_chance = _base_mutation_chance(min(prefix_data.weight, root_data.weight))
	crop.genetics = genetics
	
	# Yield item
	var yield_item := ItemData.new()
	yield_item.id = crop_id + "_yield"
	yield_item.display_name = crop_name
	yield_item.category = "crop"
	yield_item.stack_size = 99
	yield_item.sell_price = base_price
	yield_item.description = "A %s harvested from the fields." % crop_name
	DataManager.register_item(yield_item)
	
	# Seed item
	var seed_item := ItemData.new()
	seed_item.id = crop_id + "_seed"
	seed_item.display_name = crop_name + " Seed"
	seed_item.category = "seed"
	seed_item.stack_size = 99
	seed_item.sell_price = maxi(1, floori(base_price / 6.0))
	seed_item.buy_price = maxi(2, roundi(base_price * 0.6))
	seed_item.description = "Plant on tilled soil and watch it grow into %s." % crop_name
	seed_item.icon = null
	DataManager.register_item(seed_item)
	
	DataManager.register_crop(crop)
	return crop

func _pick_weighted(pool: Array) -> Dictionary:
	if pool.is_empty():
		return {}
	var total := 0
	for entry in pool:
		total += entry.weight
	var roll := _rng.randi_range(0, total - 1)
	var running := 0
	for entry in pool:
		running += entry.weight
		if roll < running:
			return entry
	return pool[-1]

func _weight_to_rarity(weight: int) -> String:
	if weight >= 35: return "Common"
	elif weight >= 22: return "Uncommon"
	elif weight >= 12: return "Rare"
	elif weight >= 6: return "Epic"
	else: return "Legendary"

func _days_to_size(days: int) -> String:
	if days <= 2: return "small"
	elif days <= 4: return "medium"
	else: return "large"

func _size_label_to_factor(size: String) -> float:
	match size:
		"small": return 0.8
		"medium": return 1.0
		"large": return 1.3
	return 1.0

func _rarity_to_tier(rarity: String) -> int:
	match rarity:
		"Common": return 0
		"Uncommon": return 1
		"Rare": return 2
		"Epic": return 3
		"Legendary": return 4
	return 0

func _base_mutation_chance(min_weight: int) -> float:
	if min_weight >= 35: return 0.03
	elif min_weight >= 22: return 0.05
	elif min_weight >= 12: return 0.08
	elif min_weight >= 6: return 0.12
	else: return 0.15
