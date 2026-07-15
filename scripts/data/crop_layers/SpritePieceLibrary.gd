extends Resource
class_name SpritePieceLibrary

## Library of reusable sprite pieces for procedural crop generation

static func get_stem_pieces() -> Dictionary:
	return {
		"thin_straight": _create_thin_straight_stem(),
		"thick_straight": _create_thick_straight_stem(),
		"curved": _create_curved_stem(),
		"vine": _create_vine_stem(),
		"mushroom_stalk": _create_mushroom_stalk(),
	}

static func get_leaf_pieces() -> Dictionary:
	return {
		"simple_small": _create_simple_small_leaves(),
		"simple_large": _create_simple_large_leaves(),
		"pointed": _create_pointed_leaves(),
		"rounded": _create_rounded_leaves(),
		"fern": _create_fern_leaves(),
		"vine_leaves": _create_vine_leaves(),
	}

static func get_fruit_pieces() -> Dictionary:
	return {
		"small_circle": _create_small_circle_fruit(),
		"large_circle": _create_large_circle_fruit(),
		"oval_horizontal": _create_oval_horizontal_fruit(),
		"oval_vertical": _create_oval_vertical_fruit(),
		"diamond": _create_diamond_fruit(),
		"star": _create_star_fruit(),
		"mushroom_cap": _create_mushroom_cap(),
		"bell": _create_bell_fruit(),
	}

static func get_flower_pieces() -> Dictionary:
	return {
		"simple_5petal": _create_simple_5petal(),
		"simple_8petal": _create_simple_8petal(),
		"daisy": _create_daisy(),
		"tulip": _create_tulip(),
		"rose": _create_rose(),
		"spikes": _create_spikes(),
	}

static func get_pattern_pieces() -> Dictionary:
	return {
		"dots": _create_dots_pattern(),
		"stripes": _create_stripes_pattern(),
		"checker": _create_checker_pattern(),
		"spots": _create_spots_pattern(),
		"spiral": _create_spiral_pattern(),
	}

static func get_effect_pieces() -> Dictionary:
	return {
		"glow_blue": _create_glow_blue(),
		"glow_gold": _create_glow_gold(),
		"sparkle": _create_sparkle(),
		"shadow": _create_shadow(),
		"outline_dark": _create_outline_dark(),
	}

# Stem pieces
static func _create_thin_straight_stem() -> StemLayer:
	var stem := StemLayer.new()
	stem.stem_type = StemLayer.StemType.STRAIGHT
	stem.height = 8
	stem.width = 2
	stem.color = Color(0.3, 0.5, 0.2)
	return stem

static func _create_thick_straight_stem() -> StemLayer:
	var stem := StemLayer.new()
	stem.stem_type = StemLayer.StemType.STRAIGHT
	stem.height = 10
	stem.width = 4
	stem.color = Color(0.3, 0.5, 0.2)
	return stem

static func _create_curved_stem() -> StemLayer:
	var stem := StemLayer.new()
	stem.stem_type = StemLayer.StemType.CURVED
	stem.height = 10
	stem.width = 3
	stem.curve_amount = 3
	stem.color = Color(0.3, 0.5, 0.2)
	return stem

static func _create_vine_stem() -> StemLayer:
	var stem := StemLayer.new()
	stem.stem_type = StemLayer.StemType.VINE
	stem.height = 12
	stem.width = 2
	stem.color = Color(0.2, 0.4, 0.15)
	return stem

static func _create_mushroom_stalk() -> StemLayer:
	var stem := StemLayer.new()
	stem.stem_type = StemLayer.StemType.MUSHROOM_STALK
	stem.height = 8
	stem.width = 4
	stem.color = Color(0.9, 0.9, 0.85)
	return stem

# Leaf pieces
static func _create_simple_small_leaves() -> LeavesLayer:
	var leaves := LeavesLayer.new()
	leaves.leaf_type = LeavesLayer.LeafType.SIMPLE
	leaves.leaf_count = 4
	leaves.leaf_size = 3
	leaves.color = Color(0.3, 0.6, 0.25)
	return leaves

static func _create_simple_large_leaves() -> LeavesLayer:
	var leaves := LeavesLayer.new()
	leaves.leaf_type = LeavesLayer.LeafType.SIMPLE
	leaves.leaf_count = 6
	leaves.leaf_size = 5
	leaves.color = Color(0.3, 0.6, 0.25)
	return leaves

static func _create_pointed_leaves() -> LeavesLayer:
	var leaves := LeavesLayer.new()
	leaves.leaf_type = LeavesLayer.LeafType.POINTED
	leaves.leaf_count = 5
	leaves.leaf_size = 4
	leaves.color = Color(0.35, 0.55, 0.2)
	return leaves

static func _create_rounded_leaves() -> LeavesLayer:
	var leaves := LeavesLayer.new()
	leaves.leaf_type = LeavesLayer.LeafType.ROUNDED
	leaves.leaf_count = 4
	leaves.leaf_size = 4
	leaves.color = Color(0.3, 0.6, 0.25)
	return leaves

static func _create_fern_leaves() -> LeavesLayer:
	var leaves := LeavesLayer.new()
	leaves.leaf_type = LeavesLayer.LeafType.FERN
	leaves.leaf_count = 3
	leaves.leaf_size = 5
	leaves.color = Color(0.25, 0.5, 0.2)
	return leaves

static func _create_vine_leaves() -> LeavesLayer:
	var leaves := LeavesLayer.new()
	leaves.leaf_type = LeavesLayer.LeafType.VINE_LEAVES
	leaves.leaf_count = 4
	leaves.leaf_size = 3
	leaves.color = Color(0.35, 0.55, 0.2)
	return leaves

# Fruit pieces
static func _create_small_circle_fruit() -> FruitBodyLayer:
	var fruit := FruitBodyLayer.new()
	fruit.body_type = FruitBodyLayer.BodyType.CIRCLE
	fruit.size = 6
	return fruit

static func _create_large_circle_fruit() -> FruitBodyLayer:
	var fruit := FruitBodyLayer.new()
	fruit.body_type = FruitBodyLayer.BodyType.CIRCLE
	fruit.size = 10
	return fruit

static func _create_oval_horizontal_fruit() -> FruitBodyLayer:
	var fruit := FruitBodyLayer.new()
	fruit.body_type = FruitBodyLayer.BodyType.OVAL
	fruit.size = 8
	fruit.width_ratio = 1.5
	return fruit

static func _create_oval_vertical_fruit() -> FruitBodyLayer:
	var fruit := FruitBodyLayer.new()
	fruit.body_type = FruitBodyLayer.BodyType.OVAL
	fruit.size = 8
	fruit.width_ratio = 0.7
	return fruit

static func _create_diamond_fruit() -> FruitBodyLayer:
	var fruit := FruitBodyLayer.new()
	fruit.body_type = FruitBodyLayer.BodyType.DIAMOND
	fruit.size = 8
	return fruit

static func _create_star_fruit() -> FruitBodyLayer:
	var fruit := FruitBodyLayer.new()
	fruit.body_type = FruitBodyLayer.BodyType.STAR
	fruit.size = 8
	return fruit

static func _create_mushroom_cap() -> FruitBodyLayer:
	var fruit := FruitBodyLayer.new()
	fruit.body_type = FruitBodyLayer.BodyType.MUSHROOM_CAP
	fruit.size = 10
	return fruit

static func _create_bell_fruit() -> FruitBodyLayer:
	var fruit := FruitBodyLayer.new()
	fruit.body_type = FruitBodyLayer.BodyType.BELL
	fruit.size = 8
	return fruit

# Flower pieces
static func _create_simple_5petal() -> FlowerLayer:
	var flower := FlowerLayer.new()
	flower.flower_type = FlowerLayer.FlowerType.SIMPLE
	flower.petal_count = 5
	flower.petal_size = 3
	flower.center_color = Color.YELLOW
	return flower

static func _create_simple_8petal() -> FlowerLayer:
	var flower := FlowerLayer.new()
	flower.flower_type = FlowerLayer.FlowerType.SIMPLE
	flower.petal_count = 8
	flower.petal_size = 3
	flower.center_color = Color.YELLOW
	return flower

static func _create_daisy() -> FlowerLayer:
	var flower := FlowerLayer.new()
	flower.flower_type = FlowerLayer.FlowerType.DAISY
	flower.petal_count = 8
	flower.petal_size = 4
	flower.center_color = Color.YELLOW
	return flower

static func _create_tulip() -> FlowerLayer:
	var flower := FlowerLayer.new()
	flower.flower_type = FlowerLayer.FlowerType.TULIP
	flower.petal_count = 3
	flower.petal_size = 4
	flower.center_color = Color(0.8, 0.6, 0.4)
	return flower

static func _create_rose() -> FlowerLayer:
	var flower := FlowerLayer.new()
	flower.flower_type = FlowerLayer.FlowerType.ROSE
	flower.petal_count = 6
	flower.petal_size = 4
	flower.center_color = Color(0.8, 0.4, 0.4)
	return flower

static func _create_spikes() -> FlowerLayer:
	var flower := FlowerLayer.new()
	flower.flower_type = FlowerLayer.FlowerType.SPIKES
	flower.petal_count = 8
	flower.petal_size = 4
	flower.center_color = Color(0.5, 0.3, 0.2)
	return flower

# Pattern pieces
static func _create_dots_pattern() -> PatternLayer:
	var pattern := PatternLayer.new()
	pattern.pattern_type = PatternLayer.PatternType.DOTS
	pattern.pattern_scale = 2
	pattern.pattern_color = Color.WHITE
	pattern.density = 0.5
	return pattern

static func _create_stripes_pattern() -> PatternLayer:
	var pattern := PatternLayer.new()
	pattern.pattern_type = PatternLayer.PatternType.STRIPES
	pattern.pattern_scale = 3
	pattern.pattern_color = Color.WHITE
	pattern.density = 0.5
	return pattern

static func _create_checker_pattern() -> PatternLayer:
	var pattern := PatternLayer.new()
	pattern.pattern_type = PatternLayer.PatternType.CHECKER
	pattern.pattern_scale = 2
	pattern.pattern_color = Color.WHITE
	pattern.density = 0.5
	return pattern

static func _create_spots_pattern() -> PatternLayer:
	var pattern := PatternLayer.new()
	pattern.pattern_type = PatternLayer.PatternType.SPOTS
	pattern.pattern_scale = 2
	pattern.pattern_color = Color.WHITE
	pattern.density = 0.3
	return pattern

static func _create_spiral_pattern() -> PatternLayer:
	var pattern := PatternLayer.new()
	pattern.pattern_type = PatternLayer.PatternType.SPIRAL
	pattern.pattern_scale = 3
	pattern.pattern_color = Color.WHITE
	pattern.density = 0.5
	return pattern

# Effect pieces
static func _create_glow_blue() -> SpecialEffectsLayer:
	var effect := SpecialEffectsLayer.new()
	effect.effect_type = SpecialEffectsLayer.EffectType.GLOW
	effect.effect_color = Color(0.5, 0.7, 1.0)
	effect.intensity = 0.6
	effect.radius = 3
	return effect

static func _create_glow_gold() -> SpecialEffectsLayer:
	var effect := SpecialEffectsLayer.new()
	effect.effect_type = SpecialEffectsLayer.EffectType.GLOW
	effect.effect_color = Color(1.0, 0.8, 0.3)
	effect.intensity = 0.6
	effect.radius = 3
	return effect

static func _create_sparkle() -> SpecialEffectsLayer:
	var effect := SpecialEffectsLayer.new()
	effect.effect_type = SpecialEffectsLayer.EffectType.SPARKLE
	effect.effect_color = Color.WHITE
	effect.intensity = 0.3
	effect.radius = 1
	return effect

static func _create_shadow() -> SpecialEffectsLayer:
	var effect := SpecialEffectsLayer.new()
	effect.effect_type = SpecialEffectsLayer.EffectType.SHADOW
	effect.effect_color = Color.BLACK
	effect.intensity = 0.5
	effect.radius = 1
	return effect

static func _create_outline_dark() -> SpecialEffectsLayer:
	var effect := SpecialEffectsLayer.new()
	effect.effect_type = SpecialEffectsLayer.EffectType.OUTLINE
	effect.effect_color = Color(0.1, 0.1, 0.1)
	effect.intensity = 1.0
	effect.radius = 1
	return effect
