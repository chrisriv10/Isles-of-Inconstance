class_name ProceduralCropGenerator
extends RefCounted

## Generates unique CropData instances by combining PREFIX and ROOT CropTraits.
## Adding new traits here alone is enough to expand the combinatorial space –
## no other script needs to change.
##
## Rarity is determined by the *lowest* weight among the two chosen traits:
##   weight >= 40  -> Common
##   weight >= 20  -> Uncommon
##   weight >= 8   -> Rare
##   weight >= 3   -> Epic
##   weight <  3   -> Legendary

# ---------------------------------------------------------------------------
# Trait Library
# ---------------------------------------------------------------------------

var _prefixes: Array[CropTrait] = []
var _roots: Array[CropTrait] = []

func _init() -> void:
	_build_prefix_library()
	_build_root_library()


func _build_prefix_library() -> void:
	# ---- Colors / Themes ----
	_add_prefix("Azure",    Color(0.3, 0.6, 1.0),  "blue",    "",        "",       0,   0, 1.2, 40)
	_add_prefix("Crimson",  Color(0.9, 0.2, 0.2),  "red",     "",        "",       0,   0, 1.3, 35)
	_add_prefix("Golden",   Color(1.0, 0.85, 0.2), "gold",    "",        "",       0,   1, 1.6, 20)
	_add_prefix("Pale",     Color(0.9, 0.9, 0.8),  "white",   "",        "",       1,   0, 0.9, 40)
	_add_prefix("Void",     Color(0.15,0.05,0.25), "black",   "",        "",       2,  -1, 2.5, 3)
	_add_prefix("Ember",    Color(1.0, 0.5, 0.1),  "orange",  "",        "",       0,   0, 1.4, 25)
	_add_prefix("Verdant",  Color(0.2, 0.8, 0.3),  "green",   "",        "",      -1,   1, 1.1, 45)
	_add_prefix("Violet",   Color(0.7, 0.3, 0.9),  "purple",  "",        "",       0,   0, 1.35,30)
	_add_prefix("Ivory",    Color(1.0, 0.95, 0.85),"white",   "",        "lustrous",1,  1, 1.5, 15)
	_add_prefix("Obsidian", Color(0.1, 0.1, 0.15), "black",   "",        "heavy",  3,  -1, 2.0,  5)
	_add_prefix("Rose",     Color(1.0, 0.6, 0.7),  "pink",    "",        "",       0,   1, 1.25,35)
	_add_prefix("Gilded",   Color(1.0, 0.9, 0.3),  "gold",    "",        "shining",0,   2, 2.2,  8)
	_add_prefix("Ashen",    Color(0.6, 0.6, 0.6),  "gray",    "",        "",       2,  -1, 1.1, 40)
	_add_prefix("Cobalt",   Color(0.2, 0.35, 0.9), "blue",    "",        "",       1,   0, 1.45,18)
	_add_prefix("Thorn",    Color(0.45,0.6, 0.3),  "green",   "spiky",   "barbed",-1,   0, 1.55,12)
	_add_prefix("Twisted",  Color(0.55,0.4, 0.2),  "brown",   "gnarled", "cursed", 3,  -2, 1.8,  8)
	_add_prefix("Luminous", Color(0.95,0.95,0.5),  "yellow",  "",        "glowing",-2,  0, 1.9,  6)
	_add_prefix("Shadow",   Color(0.2, 0.1, 0.3),  "dark",    "",        "shadowed",1, -1, 1.7,  9)
	_add_prefix("Crystal",  Color(0.7, 0.95, 1.0), "clear",   "faceted", "brittle",-3,  0, 3.0,  2)
	_add_prefix("Fungal",   Color(0.5, 0.7, 0.45), "mottled", "bumpy",   "sporing", 0,  0, 1.15,42, false)


func _build_root_library() -> void:
	# ---- Base Plant Forms ----
	_add_root("Melon",     2, -1, 1.0, 40, true)
	_add_root("Berry",     1,  1, 0.9, 45, true,  true, 2)
	_add_root("Root",      3,  0, 0.85,38, true)
	_add_root("Vine",      3,  1, 1.0, 35, true)
	_add_root("Bulb",      2,  0, 0.9, 30, true)
	_add_root("Stalk",     4, -1, 0.8, 42, true)
	_add_root("Pod",       2,  1, 1.0, 40, true)
	_add_root("Bloom",     2,  2, 1.2, 22, true)
	_add_root("Cactus",    4,  0, 1.1, 38, false)
	_add_root("Fungus",    3,  0, 0.95,35, false)
	_add_root("Tuber",     3,  0, 1.0, 40, true)
	_add_root("Frond",     2,  1, 0.9, 28, true)
	_add_root("Knob",      2,  0, 0.8, 45, true)
	_add_root("Cap",       2,  1, 1.05,30, false)
	_add_root("Sprig",     1,  2, 1.15,20, true,  true, 3)
	_add_root("Clump",     3, -1, 0.75,45, true)
	_add_root("Shard",     2,  0, 1.3, 10, false)
	_add_root("Husk",      4, -2, 0.7, 48, false)
	_add_root("Plume",     1,  2, 1.4, 15, true)
	_add_root("Tendril",   3,  1, 1.0, 38, true,  true, 4)


# ---------------------------------------------------------------------------
# Builder Helpers
# ---------------------------------------------------------------------------

func _add_prefix(name_part: String, color: Color, color_trait: String,
		shape_trait: String, special_effect: String,
		days_mod: int, yield_mod: int, value_mult: float,
		weight: int, requires_water_bool: bool = true) -> void:
	var t := CropTrait.new()
	t.type = CropTrait.TraitType.PREFIX
	t.name_part = name_part
	t.modulate_color = color
	t.color_trait = color_trait
	t.shape_trait = shape_trait
	t.special_effect = special_effect
	t.days_to_grow_mod = days_mod
	t.yield_amount_mod = yield_mod
	t.value_multiplier = value_mult
	t.rarity_weight = weight
	t.requires_water_override = 1 if requires_water_bool else 0
	_prefixes.append(t)


func _add_root(name_part: String, base_days: int, yield_mod: int,
		value_mult: float, weight: int, requires_water_bool: bool,
		regrows_bool: bool = false, regrow_days_val: int = 2) -> void:
	var t := CropTrait.new()
	t.type = CropTrait.TraitType.ROOT
	t.name_part = name_part
	t.days_to_grow_mod = base_days   # ROOT days_mod is the BASE days to grow
	t.yield_amount_mod = yield_mod
	t.value_multiplier = value_mult
	t.rarity_weight = weight
	t.requires_water_override = 1 if requires_water_bool else 0
	t.regrows_override = 1 if regrows_bool else 0
	t.regrow_days_override = regrow_days_val
	_roots.append(t)


# ---------------------------------------------------------------------------
# Generation
# ---------------------------------------------------------------------------

## Generates [count] unique CropData+ItemData pairs, registers them with
## DataManager, and returns the list of generated CropData resources.
func generate_batch(count: int, rng: RandomNumberGenerator) -> Array[CropData]:
	var results: Array[CropData] = []
	var used_names: Dictionary = {}

	var attempts := 0
	while results.size() < count and attempts < count * 30:
		attempts += 1
		var crop := _generate_one(rng)
		if crop == null or used_names.has(crop.display_name):
			continue
		used_names[crop.display_name] = true
		results.append(crop)

	return results


func _generate_one(rng: RandomNumberGenerator) -> CropData:
	var prefix := _pick_weighted(rng, _prefixes)
	var root   := _pick_weighted(rng, _roots)
	if prefix == null or root == null:
		return null

	var crop_name := prefix.name_part + " " + root.name_part
	var crop_id   := crop_name.to_lower().replace(" ", "_")

	# -- Build stats --
	var base_days   := 3 + root.days_to_grow_mod + prefix.days_to_grow_mod
	var days_final  := clampi(base_days, 1, 14)
	var yield_final := clampi(1 + root.yield_amount_mod + prefix.yield_amount_mod, 1, 5)
	var value_mult  := root.value_multiplier * prefix.value_multiplier
	var base_price  := floori(10.0 * value_mult)
	var requires_water := true
	if prefix.requires_water_override != -1:
		requires_water = prefix.requires_water_override == 1
	if root.requires_water_override != -1 and root.requires_water_override == 0:
		requires_water = false

	var regrows := false
	var regrow_days := 2
	if root.regrows_override == 1:
		regrows = true
		regrow_days = root.regrow_days_override

	var min_weight: float = min(prefix.rarity_weight, root.rarity_weight)
	var rarity := _weight_to_rarity(min_weight)

	# -- Procedurally generate unique sprites for this crop --
	var stages: Array[Texture2D] = _generate_crop_textures(prefix, crop_name, rng)

	# -- Assemble CropData --
	var crop := CropData.new()
	crop.id = crop_id
	crop.display_name = crop_name
	crop.days_to_grow = days_final
	crop.yield_item_id = crop_id + "_yield"
	crop.seed_item_id  = crop_id + "_seed"
	crop.yield_amount  = yield_final
	crop.regrows       = regrows
	crop.regrow_days   = regrow_days
	crop.requires_water = requires_water
	crop.modulate_color = prefix.modulate_color
	crop.rarity        = rarity
	crop.color_trait   = prefix.color_trait
	crop.shape_trait   = prefix.shape_trait if prefix.shape_trait != "" else root.name_part.to_lower()
	crop.size_trait    = _days_to_size(days_final)
	crop.special_effect = prefix.special_effect
	crop.growth_stage_textures = stages

	# -- Genetics: the baseline profile every future seed of this crop
	# germinates from, and the starting point for its first mutation --
	var genetics := CropGenetics.new()
	genetics.color_hue = prefix.modulate_color.h
	genetics.color_saturation = prefix.modulate_color.s
	genetics.color_value = prefix.modulate_color.v
	genetics.size_factor = _size_label_to_factor(crop.size_trait)
	genetics.growth_speed_factor = 1.0
	genetics.value_factor = value_mult
	genetics.rarity_tier = _rarity_to_tier(rarity)
	genetics.mutation_chance = _base_mutation_chance(min_weight)
	crop.genetics = genetics

	# -- Yield item --
	var yield_item := ItemData.new()
	yield_item.id = crop_id + "_yield"
	yield_item.display_name = crop_name
	yield_item.category = "crop"
	yield_item.stack_size = 99
	yield_item.sell_price = base_price
	yield_item.description = _build_description(crop)

	# -- Seed item --
	var seed_item := ItemData.new()
	seed_item.id = crop_id + "_seed"
	seed_item.display_name = crop_name + " Seed"
	seed_item.category = "seed"
	seed_item.stack_size = 99
	seed_item.sell_price = maxi(1, floori(base_price / 6.0))
	seed_item.buy_price = maxi(2, roundi(base_price * 0.6))
	seed_item.description = "Plant on tilled soil."
	# Generate unique seed icon using the crop's prefix/colors
	seed_item.icon = generate_seed_icon(prefix, crop_name, rng)

	DataManager.register_crop(crop)
	DataManager.register_item(yield_item)
	DataManager.register_item(seed_item)

	return crop


func _pick_weighted(rng: RandomNumberGenerator, pool: Array) -> CropTrait:
	if pool.is_empty():
		return null
	var total := 0
	for t in pool:
		total += t.rarity_weight
	var roll := rng.randi_range(0, total - 1)
	var running := 0
	for t in pool:
		running += t.rarity_weight
		if roll < running:
			return t
	return pool[-1]


func _weight_to_rarity(weight: int) -> String:
	if weight >= 40:
		return "Common"
	elif weight >= 20:
		return "Uncommon"
	elif weight >= 8:
		return "Rare"
	elif weight >= 3:
		return "Epic"
	return "Legendary"


func _size_label_to_factor(label: String) -> float:
	match label:
		"tiny":
			return 0.6
		"small":
			return 0.85
		"medium":
			return 1.0
		"large":
			return 1.3
		"massive":
			return 1.7
		_:
			return 1.0


func _rarity_to_tier(rarity_name: String) -> int:
	match rarity_name:
		"Common":
			return 0
		"Uncommon":
			return 1
		"Rare":
			return 2
		"Epic":
			return 3
		"Legendary":
			return 4
		_:
			return 0


## Rarer base crops (lower minimum trait weight) start out a little more
## "unstable" and so have a slightly higher baseline mutation chance.
func _base_mutation_chance(min_weight: float) -> float:
	var instability: float = clampf(1.0 - (min_weight / 45.0), 0.0, 1.0)
	return clampf(0.04 + instability * 0.08, 0.04, 0.14)


func _days_to_size(days: int) -> String:
	if days <= 2:
		return "tiny"
	elif days <= 4:
		return "small"
	elif days <= 7:
		return "medium"
	elif days <= 10:
		return "large"
	return "massive"


## Generates 4 unique growth-stage textures (24x24) for a crop using
## the procedural CropSpriteGenerator, seeded from the crop name for
## determinism so every session with the same seed looks identical.
func _generate_crop_textures(prefix: CropTrait, crop_name: String, rng: RandomNumberGenerator) -> Array[Texture2D]:
	# Derive a seed from the crop name for deterministic generation
	var seed_val := hash(crop_name + str(rng.seed))
	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = seed_val

	var pieces := _pick_crop_pieces(seed_val, local_rng)
	var colors := _pick_crop_colors(prefix, local_rng)

	var sprite_gen := CropSpriteGenerator.new().create_crop_from_pieces(
		pieces.stem, pieces.leaf, pieces.fruit,
		pieces.flower, pieces.pattern, pieces.effect,
		colors.fruit, colors.flower
	)
	return sprite_gen.generate_growth_stages(4)


## Generates a seed-bag icon texture (24x24) for a crop, reusing the
## same procedural pieces so the seed icon looks like a tiny version
## of the mature crop.
func generate_seed_icon(prefix: CropTrait, crop_name: String, rng: RandomNumberGenerator) -> Texture2D:
	var seed_val := hash("seed_" + crop_name + str(rng.seed))
	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = seed_val

	var pieces := _pick_crop_pieces(seed_val, local_rng)
	var colors := _pick_crop_colors(prefix, local_rng)

	var sprite_gen := CropSpriteGenerator.new().create_crop_from_pieces(
		pieces.stem, pieces.leaf, pieces.fruit,
		pieces.flower, "", pieces.effect,  # skip pattern for seed icon
		colors.fruit, colors.flower
	)
	return sprite_gen.generate_texture()


# Helper structs for cleaner code
func _pick_crop_pieces(seed_val: int, local_rng: RandomNumberGenerator) -> Dictionary:
	var lib := SpritePieceLibrary
	var stem_keys: Array = lib.get_stem_pieces().keys()
	var leaf_keys: Array = lib.get_leaf_pieces().keys()
	var fruit_keys: Array = lib.get_fruit_pieces().keys()
	var flower_keys: Array = lib.get_flower_pieces().keys()
	var pattern_keys: Array = lib.get_pattern_pieces().keys()
	var effect_keys: Array = lib.get_effect_pieces().keys()

	return {
		stem = stem_keys[seed_val % stem_keys.size()],
		leaf = leaf_keys[(seed_val / 3) % leaf_keys.size()],
		fruit = fruit_keys[(seed_val / 7) % fruit_keys.size()],
		flower = flower_keys[(seed_val / 11) % flower_keys.size()] if local_rng.randf() > 0.5 else "",
		pattern = pattern_keys[(seed_val / 13) % pattern_keys.size()] if local_rng.randf() > 0.6 else "",
		effect = effect_keys[(seed_val / 17) % effect_keys.size()] if local_rng.randf() > 0.7 else "",
	}


func _pick_crop_colors(prefix: CropTrait, local_rng: RandomNumberGenerator) -> Dictionary:
	var base_hue := prefix.modulate_color.h
	return {
		fruit = Color.from_hsv(
			fmod(base_hue + local_rng.randf_range(-0.08, 0.08), 1.0),
			0.7 + local_rng.randf() * 0.3,
			0.8 + local_rng.randf() * 0.2
		),
		flower = Color.from_hsv(
			fmod(base_hue + 0.15 + local_rng.randf_range(-0.05, 0.05), 1.0),
			0.6 + local_rng.randf() * 0.4,
			0.8 + local_rng.randf() * 0.2
		),
	}


func _build_description(crop: CropData) -> String:
	var parts: Array[String] = []
	if crop.color_trait != "":
		parts.append(crop.color_trait.capitalize())
	if crop.shape_trait != "":
		parts.append(crop.shape_trait)
	if crop.size_trait != "":
		parts.append(crop.size_trait)
	if crop.special_effect != "":
		parts.append("— " + crop.special_effect)
	parts.append("| %d days | Rarity: %s" % [crop.days_to_grow, crop.rarity])
	return " ".join(parts)
