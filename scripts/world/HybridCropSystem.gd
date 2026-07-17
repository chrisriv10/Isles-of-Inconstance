class_name HybridCropSystem
extends RefCounted

## Allows cross-breeding two different crops to create hybrids.
## When two different mature crops are adjacent, there's a chance they cross
## and produce a hybrid seed combining traits from both parents.

var world_seed: int

func _init(seed_value: int) -> void:
	world_seed = seed_value

## Try to create a hybrid from two adjacent crops.
## Returns a new CropData if successful, null otherwise.
func try_hybridize(parent_a_id: String, parent_b_id: String, tile_x: int, tile_y: int) -> CropData:
	var crop_a := DataManager.get_crop(parent_a_id)
	var crop_b := DataManager.get_crop(parent_b_id)
	
	if not crop_a or not crop_b:
		return null
	
	# Can't hybridize identical crops
	if parent_a_id == parent_b_id:
		return null
	
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(world_seed) + ":hybrid:" + parent_a_id + "+" + parent_b_id + ":" + str(tile_x) + "," + str(tile_y))
	
	# Base chance: 5% per day of adjacency
	if rng.randf() > 0.05:
		return null
	
	# Create hybrid name
	var parts_a := _split_crop_name(crop_a.display_name)
	var parts_b := _split_crop_name(crop_b.display_name)
	
	var hybrid_name := ""
	# Combine prefix from one, root from the other
	if rng.randf() > 0.5:
		hybrid_name = parts_a[0] + parts_b[1]
	else:
		hybrid_name = parts_b[0] + parts_a[1]
	
	var hybrid_id := hybrid_name.to_lower().replace(" ", "_") + "_hybrid"
	
	# Skip if already exists
	if DataManager.get_crop(hybrid_id):
		return null
	
	# Average stats
	var avg_days := int((crop_a.days_to_grow + crop_b.days_to_grow) / 2.0)
	var avg_yield := int((crop_a.yield_amount + crop_b.yield_amount) / 2.0)
	var avg_value := (crop_a.genetics.value_factor + crop_b.genetics.value_factor) / 2.0 * 1.2  # Hybrid vigor
	
	# Blend colors
	var color_a := crop_a.modulate_color
	var color_b := crop_b.modulate_color
	var hybrid_color := Color(
		(color_a.r + color_b.r) / 2.0,
		(color_a.g + color_b.g) / 2.0,
		(color_a.b + color_b.b) / 2.0
	)
	
	# Create the hybrid crop data
	var hybrid := CropData.new()
	hybrid.id = hybrid_id
	hybrid.display_name = hybrid_name
	hybrid.days_to_grow = clampi(avg_days, 2, 10)
	hybrid.yield_item_id = hybrid_id + "_yield"
	hybrid.seed_item_id = hybrid_id + "_seed"
	hybrid.yield_amount = clampi(avg_yield, 1, 4)
	hybrid.regrows = rng.randf() > 0.5
	hybrid.regrow_days = 3
	hybrid.requires_water = true
	hybrid.modulate_color = hybrid_color
	hybrid.rarity = "Rare"
	hybrid.size_trait = "medium"
	hybrid.growth_stage_textures = []
	
	# Genetics
	var genetics := CropGenetics.new()
	genetics.color_hue = hybrid_color.h
	genetics.color_saturation = hybrid_color.s
	genetics.color_value = hybrid_color.v
	genetics.size_factor = 1.2  # Hybrid vigor
	genetics.growth_speed_factor = 1.0
	genetics.value_factor = avg_value
	genetics.rarity_tier = 3
	genetics.mutation_chance = 0.08
	hybrid.genetics = genetics
	
	# Register
	DataManager.register_crop(hybrid)
	
	# Yield item
	var yield_item := ItemData.new()
	yield_item.id = hybrid_id + "_yield"
	yield_item.display_name = hybrid_name
	yield_item.category = "crop"
	yield_item.stack_size = 99
	yield_item.sell_price = maxi(1, roundi(10.0 * avg_value))
	yield_item.description = "A hybrid crop cross-bred from %s and %s." % [crop_a.display_name, crop_b.display_name]
	DataManager.register_item(yield_item)
	
	# Seed item
	var seed_item := ItemData.new()
	seed_item.id = hybrid_id + "_seed"
	seed_item.display_name = hybrid_name + " Seed"
	seed_item.category = "seed"
	seed_item.stack_size = 99
	seed_item.sell_price = maxi(1, roundi(10.0 * avg_value / 6.0))
	seed_item.buy_price = maxi(2, roundi(10.0 * avg_value * 0.6))
	seed_item.description = "A hybrid seed cross-bred from %s and %s." % [crop_a.display_name, crop_b.display_name]
	DataManager.register_item(seed_item)
	
	return hybrid

## Splits a crop display name (e.g. "Azure Melon") into [prefix, root]
func _split_crop_name(name: String) -> Array:
	var parts := name.split(" ", true, 1)
	if parts.size() >= 2:
		return [parts[0], " " + parts[1]]
	return ["Wild", " Crop"]
