extends Resource
class_name CropGenetics

## Heritable genetic profile for a crop line.
##
## Every CropData holds a "canonical" CropGenetics describing what a freshly
## planted seed of that exact id will produce (see ProceduralCropGenerator
## and MutationSystem). When a seed germinates in the ground it gets its own
## lightly-jittered copy via germinate() so no two plants of the same crop
## are bit-for-bit identical. When a plant mutates, MutationSystem builds the
## new genetics from *that specific plant's current genes* (not the static
## template), and bakes the result into a brand-new CropData + seed item
## (e.g. "Crystal Berry" / "Crystal Berry Seed"). Replanting that seed is
## what makes the mutation inheritable: every future plant grown from it
## starts from the mutated genetics instead of the original.

@export var color_hue: float = 0.0
@export var color_saturation: float = 0.65
@export var color_value: float = 0.9
@export var size_factor: float = 1.0          # sprite scale + size_trait label
@export var growth_speed_factor: float = 1.0  # <1.0 grows faster, >1.0 slower
@export var value_factor: float = 1.0         # sell price multiplier
@export var rarity_tier: int = 0              # 0 Common .. 4 Legendary
@export var mutation_chance: float = 0.06     # chance to mutate on each growth tick
@export var appearance_tags: Array[String] = []
@export var special_abilities: Array[String] = []
@export var lineage: Array[String] = []       # mutation names, oldest first
@export var generation: int = 0               # how many mutations deep this line is

const RARITY_NAMES: Array[String] = ["Common", "Uncommon", "Rare", "Epic", "Legendary"]

func rarity_name() -> String:
	return RARITY_NAMES[clampi(rarity_tier, 0, RARITY_NAMES.size() - 1)]

func to_color() -> Color:
	return Color.from_hsv(color_hue, color_saturation, color_value)

## Exact copy of every gene - use when you need an independent instance
## with no variance (e.g. as a base before applying a mutation's deltas).
func clone() -> CropGenetics:
	var c := CropGenetics.new()
	c.color_hue = color_hue
	c.color_saturation = color_saturation
	c.color_value = color_value
	c.size_factor = size_factor
	c.growth_speed_factor = growth_speed_factor
	c.value_factor = value_factor
	c.rarity_tier = rarity_tier
	c.mutation_chance = mutation_chance
	c.appearance_tags = appearance_tags.duplicate()
	c.special_abilities = special_abilities.duplicate()
	c.lineage = lineage.duplicate()
	c.generation = generation
	return c

## Genetics for a freshly-planted seed of this line: an (almost) exact copy
## with a whisper of natural variance so plants of the same crop id aren't
## perfectly uniform in the field.
func germinate(rng: RandomNumberGenerator) -> CropGenetics:
	var c := clone()
	c.color_hue = wrapf(c.color_hue + rng.randf_range(-0.015, 0.015), 0.0, 1.0)
	c.growth_speed_factor = clampf(c.growth_speed_factor + rng.randf_range(-0.01, 0.01), 0.5, 2.0)
	return c

## Combines two parent genetics into offspring. This is a forward-looking
## hook for a future cross-pollination feature (e.g. planting two seed
## types in adjacent tiles) - not wired into World/Player yet, but the
## genetics model is ready for it as soon as that gameplay is added.
static func cross(parent_a: CropGenetics, parent_b: CropGenetics, rng: RandomNumberGenerator) -> CropGenetics:
	var c := CropGenetics.new()
	c.color_hue = parent_a.color_hue if rng.randf() < 0.5 else parent_b.color_hue
	c.color_saturation = (parent_a.color_saturation + parent_b.color_saturation) / 2.0
	c.color_value = (parent_a.color_value + parent_b.color_value) / 2.0
	c.size_factor = (parent_a.size_factor + parent_b.size_factor) / 2.0
	c.growth_speed_factor = parent_a.growth_speed_factor if rng.randf() < 0.5 else parent_b.growth_speed_factor
	c.value_factor = max(parent_a.value_factor, parent_b.value_factor)
	c.rarity_tier = max(parent_a.rarity_tier, parent_b.rarity_tier)
	c.mutation_chance = (parent_a.mutation_chance + parent_b.mutation_chance) / 2.0
	c.appearance_tags = _merge_unique(parent_a.appearance_tags, parent_b.appearance_tags)
	c.special_abilities = _merge_unique(parent_a.special_abilities, parent_b.special_abilities)
	c.lineage = _merge_unique(parent_a.lineage, parent_b.lineage)
	c.generation = max(parent_a.generation, parent_b.generation) + 1
	return c

static func _merge_unique(a: Array[String], b: Array[String]) -> Array[String]:
	var result: Array[String] = a.duplicate()
	for tag in b:
		if not result.has(tag):
			result.append(tag)
	return result

## Serialize genetics to dictionary for JSON save/load
func serialize() -> Dictionary:
	return {
		"color_hue": color_hue,
		"color_saturation": color_saturation,
		"color_value": color_value,
		"size_factor": size_factor,
		"growth_speed_factor": growth_speed_factor,
		"value_factor": value_factor,
		"rarity_tier": rarity_tier,
		"mutation_chance": mutation_chance,
		"appearance_tags": appearance_tags,
		"special_abilities": special_abilities,
		"lineage": lineage,
		"generation": generation
	}

## Deserialize genetics from dictionary for JSON save/load
static func deserialize(data: Dictionary) -> CropGenetics:
	var genetics := CropGenetics.new()
	genetics.color_hue = data.get("color_hue", 0.0)
	genetics.color_saturation = data.get("color_saturation", 0.65)
	genetics.color_value = data.get("color_value", 0.9)
	genetics.size_factor = data.get("size_factor", 1.0)
	genetics.growth_speed_factor = data.get("growth_speed_factor", 1.0)
	genetics.value_factor = data.get("value_factor", 1.0)
	genetics.rarity_tier = data.get("rarity_tier", 0)
	genetics.mutation_chance = data.get("mutation_chance", 0.06)
	genetics.appearance_tags = data.get("appearance_tags", [])
	genetics.special_abilities = data.get("special_abilities", [])
	genetics.lineage = data.get("lineage", [])
	genetics.generation = data.get("generation", 0)
	return genetics
