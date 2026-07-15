class_name MutationSystem
extends RefCounted

## Rolls and applies crop mutations.
##
## Each mutation takes a growing plant's current CropData + CropGenetics and
## produces a brand-new *registered* CropData (e.g. "Azure Berry" mutating
## into "Crystal Berry"), complete with its own yield item and seed item.
## Because the mutated crop is a first-class, independently seed-able crop
## type, replanting its seed is exactly what makes the mutation heritable -
## no separate "instance data on items" system is needed for the mutation
## to breed true.

var _mutations: Array[MutationDefinition] = []

func _init() -> void:
	_build_mutation_library()

func _build_mutation_library() -> void:
	# name,            weight, min_rarity, roots,                         hue_shift, sat,  val,  size, growth, sell, rarity_bump, appearance,        ability,        description
	_add("Crystal",     8, 2, [],                                          0.50,  0.90, 0.95, 1.15, 0.85, 2.5, 2, "faceted",        "sparkle_glow", "Turned translucent and crystalline - sells for far more.")
	_add("Glowcap",    10, 1, ["Mushroom", "Cap", "Fungus"],                0.60,  0.60, 1.00, 1.00, 1.00, 1.6, 1, "glowing",        "light_source", "Bioluminescent - softly lights up the field at night.")
	_add("Giant",      12, 0, [],                                          0.00, -1.0, -1.0, 1.60, 1.25, 1.8, 1, "colossal",       "bonus_yield",  "Grew far larger than normal, yielding more produce.")
	_add("Runt",       14, 0, [],                                          0.00, -1.0, -1.0, 0.60, 0.70, 0.6, 0, "tiny",           "fast_growth",  "Stunted growth, but matures unusually fast.")
	_add("Golden",      6, 2, [],                                          0.13,  0.90, 0.95, 1.05, 1.00, 3.0, 2, "gilded",         "midas_touch",  "Veins of gold run through it.")
	_add("Shadow",      9, 1, [],                                        -0.35,  0.50, 0.25, 1.00, 0.85, 1.7, 1, "shadowed",       "night_growth", "Thrives after dark; grows faster overnight.")
	_add("Swift",      15, 0, [],                                          0.00, -1.0, -1.0, 1.00, 0.70, 1.1, 0, "quick-growing",  "fast_growth",  "Grows noticeably faster than its kin.")
	_add("Prismatic",   4, 3, [],                                          0.00,  0.90, 1.00, 1.10, 1.00, 2.2, 3, "shifting-hued",  "color_shift",  "Its color seems to shift when you're not looking - a truly rare find.")
	_add("Frostkissed", 8, 1, [],                                          0.55,  0.50, 0.95, 1.00, 1.15, 1.5, 1, "frosted",        "chill_aura",   "Coated in a permanent light frost.")
	_add("Thorned",    10, 0, [],                                          0.00,  0.80, -1.0, 1.00, 1.00, 1.3, 0, "spiky",          "pest_resist",  "Grew defensive spines that ward off pests.")

func _add(mutation_name: String, weight: int, min_rarity: int, roots: Array,
		hue_shift: float, sat_target: float, val_target: float,
		size_mult: float, growth_mult: float, sell_mult: float, rarity_bump: int,
		appearance: String, ability: String, description: String) -> void:
	var m := MutationDefinition.new()
	m.mutation_name = mutation_name
	m.weight = weight
	m.min_rarity_tier = min_rarity
	var typed_roots: Array[String] = []
	for r in roots:
		typed_roots.append(r)
	m.allowed_roots = typed_roots
	m.hue_shift = hue_shift
	m.saturation_target = sat_target
	m.value_target = val_target
	m.size_multiplier = size_mult
	m.growth_speed_multiplier = growth_mult
	m.sell_value_multiplier = sell_mult
	m.rarity_tier_bump = rarity_bump
	m.appearance_tag = appearance
	m.special_ability = ability
	m.description = description
	_mutations.append(m)

# ---------------------------------------------------------------------------
# Rolling
# ---------------------------------------------------------------------------

## Returns true if a mutation should be attempted this growth tick.
func roll_for_mutation(genetics: CropGenetics, rng: RandomNumberGenerator) -> bool:
	if genetics == null:
		return false
	return rng.randf() < genetics.mutation_chance

## Picks an eligible mutation for the given base crop/genetics, weighted by
## rarity, or null if nothing qualifies.
func pick_mutation(base_crop: CropData, genetics: CropGenetics, rng: RandomNumberGenerator) -> MutationDefinition:
	var root_word := _extract_root_word(base_crop.display_name)
	var eligible: Array[MutationDefinition] = []
	for m in _mutations:
		if genetics.rarity_tier < m.min_rarity_tier:
			continue
		if not m.matches_root(root_word):
			continue
		eligible.append(m)

	if eligible.is_empty():
		return null

	var total := 0
	for m in eligible:
		total += m.weight
	if total <= 0:
		return null
	var roll := rng.randi_range(0, total - 1)
	var running := 0
	for m in eligible:
		running += m.weight
		if roll < running:
			return m
	return eligible[-1]

# ---------------------------------------------------------------------------
# Applying
# ---------------------------------------------------------------------------

## Creates and registers a brand-new mutated CropData derived from
## base_crop, layering the mutation's deltas on top of the plant's current
## genetics. The new crop gets its own id/name/seed (e.g. "Crystal Berry"),
## so future harvests from this line keep breeding true to the mutation
## unless it mutates again.
func create_mutated_crop(base_crop: CropData, mutation: MutationDefinition,
		parent_genetics: CropGenetics, rng: RandomNumberGenerator) -> CropData:
	var child_genetics := parent_genetics.germinate(rng)
	child_genetics.color_hue = wrapf(child_genetics.color_hue + mutation.hue_shift, 0.0, 1.0)
	if mutation.saturation_target >= 0.0:
		child_genetics.color_saturation = mutation.saturation_target
	if mutation.value_target >= 0.0:
		child_genetics.color_value = mutation.value_target
	child_genetics.size_factor *= mutation.size_multiplier
	child_genetics.growth_speed_factor = clampf(child_genetics.growth_speed_factor * mutation.growth_speed_multiplier, 0.3, 2.5)
	child_genetics.value_factor *= mutation.sell_value_multiplier
	child_genetics.rarity_tier = clampi(child_genetics.rarity_tier + mutation.rarity_tier_bump, 0, 4)
	if mutation.appearance_tag != "" and not child_genetics.appearance_tags.has(mutation.appearance_tag):
		child_genetics.appearance_tags.append(mutation.appearance_tag)
	if mutation.special_ability != "" and not child_genetics.special_abilities.has(mutation.special_ability):
		child_genetics.special_abilities.append(mutation.special_ability)
	child_genetics.lineage.append(mutation.mutation_name)
	child_genetics.generation += 1
	# Each mutation makes the line a little more prone to mutating again -
	# unstable magic compounds on itself.
	child_genetics.mutation_chance = clampf(child_genetics.mutation_chance + 0.015, 0.01, 0.5)

	var root_word := _extract_root_word(base_crop.display_name)
	var new_name := mutation.mutation_name + " " + root_word
	var new_id := new_name.to_lower().replace(" ", "_")

	# If this exact mutated variant already exists (another plant already
	# rolled the same mutation on the same root crop), reuse it so the
	# world doesn't fill up with duplicate crop ids.
	var existing := DataManager.get_crop(new_id)
	if existing:
		return existing

	var child := CropData.new()
	child.id = new_id
	child.display_name = new_name
	child.growth_stage_textures = base_crop.growth_stage_textures
	child.days_to_grow = clampi(int(round(base_crop.days_to_grow * mutation.growth_speed_multiplier)), 1, 20)
	child.yield_item_id = new_id + "_yield"
	child.seed_item_id = new_id + "_seed"
	child.yield_amount = clampi(base_crop.yield_amount + (1 if mutation.special_ability == "bonus_yield" else 0), 1, 10)
	child.regrows = base_crop.regrows
	child.regrow_days = base_crop.regrow_days
	child.requires_water = base_crop.requires_water
	child.modulate_color = child_genetics.to_color()
	child.rarity = child_genetics.rarity_name()
	child.color_trait = mutation.appearance_tag if mutation.appearance_tag != "" else base_crop.color_trait
	child.shape_trait = base_crop.shape_trait
	child.size_trait = _size_factor_to_label(child_genetics.size_factor)
	child.special_effect = mutation.description
	child.genetics = child_genetics
	child.base_crop_id = base_crop.id
	child.mutation_name = mutation.mutation_name
	child.mutation_generation = child_genetics.generation

	var base_value := 10.0 * child_genetics.value_factor
	var yield_item := ItemData.new()
	yield_item.id = child.yield_item_id
	yield_item.display_name = new_name
	yield_item.stack_size = 99
	yield_item.sell_price = maxi(1, int(round(base_value)))
	yield_item.description = "%s | %s | Gen %d" % [mutation.description, child.rarity, child_genetics.generation]

	var seed_item := ItemData.new()
	seed_item.id = child.seed_item_id
	seed_item.display_name = new_name + " Seed"
	seed_item.stack_size = 99
	seed_item.sell_price = maxi(1, yield_item.sell_price / 4)
	seed_item.description = "Plant on tilled soil. Carries the " + mutation.mutation_name + " mutation."

	DataManager.register_crop(child)
	DataManager.register_item(yield_item)
	DataManager.register_item(seed_item)

	return child

func _extract_root_word(display_name: String) -> String:
	var parts := display_name.split(" ")
	return parts[-1] if not parts.is_empty() else display_name

func _size_factor_to_label(factor: float) -> String:
	if factor <= 0.7:
		return "tiny"
	elif factor <= 0.9:
		return "small"
	elif factor <= 1.2:
		return "medium"
	elif factor <= 1.6:
		return "large"
	return "massive"
