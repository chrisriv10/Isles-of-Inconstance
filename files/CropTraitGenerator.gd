class_name CropTraitGenerator
extends RefCounted

## Produces biome-flavored CropData variants: a crop planted in a Forest,
## Swamp, or Mountain tile can roll biome-exclusive trait tags, altered
## growth/yield multipliers, and a re-tinted procedural sprite, all
## reproducible from the same world seed + planting tile.
##
## This intentionally does not modify CropData.gd's schema. Extra biome
## trait data is attached via set_meta()/get_meta() so it layers on top of
## whatever fields CropData already defines, and degrades gracefully if
## CropSpriteGenerator/SpritePieceLibrary aren't available.

const META_BIOME_TYPE := "biome_type"
const META_TRAIT_TAGS := "biome_trait_tags"
const META_IS_UNIQUE := "biome_unique_variant"

var world_seed: int

func _init(seed_value: int) -> void:
	world_seed = seed_value


## Applies a biome's growth/yield/trait modifiers to a base CropData
## instance planted at (tile_x, tile_y). Returns a new duplicated CropData
## so the original template is never mutated.
func apply_biome_traits(base_crop, biome: BiomeDefinition, tile_x: int, tile_y: int):
	var crop = base_crop.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = _plant_seed(crop.id if "id" in crop else "crop", tile_x, tile_y)

	crop.set_meta(META_BIOME_TYPE, biome.type)
	crop.set_meta(META_TRAIT_TAGS, biome.crop_trait_tags.duplicate())

	var is_unique := rng.randf() < biome.unique_crop_chance
	crop.set_meta(META_IS_UNIQUE, is_unique)

	if "growth_time" in crop and crop.growth_time != null:
		crop.growth_time *= biome.crop_growth_multiplier
	if "yield_amount" in crop and crop.yield_amount != null:
		crop.yield_amount = int(round(crop.yield_amount * biome.crop_yield_multiplier))

	if is_unique and "display_name" in crop:
		crop.display_name = "%s %s" % [_unique_prefix(biome, rng), crop.display_name]

	_reroll_sprite(crop, biome, rng, is_unique)
	return crop


func _unique_prefix(biome: BiomeDefinition, rng: RandomNumberGenerator) -> String:
	match biome.type:
		BiomeType.Type.FOREST:
			return ["Wildwood", "Mossy", "Sylvan"][rng.randi_range(0, 2)]
		BiomeType.Type.SWAMP:
			return ["Bogborn", "Murkroot", "Fenweed"][rng.randi_range(0, 2)]
		BiomeType.Type.MOUNTAIN:
			return ["Crystalline", "Frostpeak", "Stonebloom"][rng.randi_range(0, 2)]
		_:
			return "Wild"


## Re-generates the crop's procedural sprite (if it uses the
## CropSpriteGenerator system) tinted for this biome, with a stronger
## visual flourish when a unique variant is rolled.
func _reroll_sprite(crop, biome: BiomeDefinition, rng: RandomNumberGenerator, is_unique: bool) -> void:
	if not ClassDB.class_exists("CropSpriteGenerator") and not Engine.has_singleton("CropSpriteGenerator"):
		# Fall back silently if the sprite system isn't present - trait
		# and multiplier changes above still apply either way.
		if not (ResourceLoader.exists("res://scripts/data/CropSpriteGenerator.gd")):
			return

	var generator = load("res://scripts/data/CropSpriteGenerator.gd").new()
	generator.set_sprite_size(24)
	var library = load("res://scripts/data/crop_layers/SpritePieceLibrary.gd")

	var stem = library.get_stem_pieces()["vine"].duplicate()
	generator.add_layer(stem)

	var fruit_key := "large_circle" if is_unique else "small_circle"
	var fruit = library.get_fruit_pieces()[fruit_key].duplicate()
	fruit.color = biome.crop_color_tint
	generator.add_layer(fruit)

	if is_unique:
		var effect_key := _unique_effect_for_biome(biome)
		if library.get_effect_pieces().has(effect_key):
			var effect = library.get_effect_pieces()[effect_key].duplicate()
			generator.add_layer(effect)

	if "growth_stage_textures" in crop:
		crop.growth_stage_textures = generator.generate_growth_stages(4)


func _unique_effect_for_biome(biome: BiomeDefinition) -> String:
	match biome.type:
		BiomeType.Type.SWAMP:
			return "glow_blue"
		BiomeType.Type.MOUNTAIN:
			return "sparkle"
		BiomeType.Type.FOREST:
			return "glow_gold"
		_:
			return "outline_dark"


## Deterministic per-plant seed so replanting the same crop id on the same
## tile with the same world seed always rolls the same trait outcome.
func _plant_seed(crop_id: String, tile_x: int, tile_y: int) -> int:
	return int(hash(str(world_seed) + ":crop:" + crop_id + ":" + str(tile_x) + "," + str(tile_y)))
