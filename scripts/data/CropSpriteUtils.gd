class_name CropSpriteUtils
extends RefCounted

## Shared utility for generating crop growth-stage textures and seed icons.
## Extracted from ProceduralCropGenerator so ExpandedCropGenerator and
## HybridCropSystem can also produce visible sprites — preventing the
## "invisible crop" bug from recurring.

# Root-word → visual template map. Each entry defines which stem, leaf, fruit,
# and flower pieces to use so crops LOOK like what their name describes.
# Roots not in this map fall through to the random piece selection (old behaviour).
const ROOT_TEMPLATES: Dictionary = {
	# ── Root vegetables ──
	"Carrot":  {"stem": "thin_straight", "leaf": "pointed",     "fruit": "carrot",   "flower": ""},
	"Turnip":  {"stem": "thin_straight", "leaf": "pointed",     "fruit": "carrot",   "flower": ""},
	"Root":    {"stem": "thin_straight", "leaf": "simple_small", "fruit": "carrot",   "flower": ""},
	"Tuber":   {"stem": "thin_straight", "leaf": "simple_small", "fruit": "oval_horizontal", "flower": ""},
	# ── Big fruit / vine crops ──
	"Melon":   {"stem": "vine",          "leaf": "broad_leaf",   "fruit": "large_circle",     "flower": "simple_5petal"},
	"Pumpkin": {"stem": "vine",          "leaf": "broad_leaf",   "fruit": "pumpkin",   "flower": "simple_5petal"},
	"Gourd":   {"stem": "curved",        "leaf": "broad_leaf",   "fruit": "pumpkin",   "flower": "simple_5petal"},
	"Tomato":  {"stem": "curved",        "leaf": "simple_small", "fruit": "tomato",    "flower": "simple_5petal"},
	# ── Berries / small fruit ──
	"Berry":   {"stem": "thin_straight", "leaf": "simple_small", "fruit": "small_circle",     "flower": "simple_5petal"},
	"Grape":   {"stem": "vine",          "leaf": "vine_leaves",  "fruit": "small_circle",     "flower": ""},
	"Coffee":  {"stem": "thin_straight", "leaf": "rounded",      "fruit": "small_circle",     "flower": "simple_5petal"},
	"Herb":    {"stem": "thin_straight", "leaf": "simple_small", "fruit": "small_circle",     "flower": ""},
	# ── Grains / grasses ──
	"Corn":    {"stem": "corn_stalk",    "leaf": "corn_leaf",    "fruit": "corn_cob",   "flower": ""},
	"Wheat":   {"stem": "thick_straight", "leaf": "corn_leaf",   "fruit": "corn_cob",   "flower": ""},
	"Rice":    {"stem": "thick_straight", "leaf": "corn_leaf",   "fruit": "corn_cob",   "flower": ""},
	"Flax":    {"stem": "thick_straight", "leaf": "pointed",     "fruit": "bell",       "flower": "simple_5petal"},
	# ── Leafy greens ──
	"Lettuce": {"stem": "thin_straight", "leaf": "broad_leaf",   "fruit": "small_circle",     "flower": ""},
	"Clump":   {"stem": "thin_straight", "leaf": "simple_large", "fruit": "small_circle",     "flower": ""},
	# ── Pods / beans ──
	"Bean":    {"stem": "vine",          "leaf": "vine_leaves",  "fruit": "oval_vertical",    "flower": ""},
	"Pod":     {"stem": "curved",        "leaf": "simple_small", "fruit": "oval_vertical",    "flower": ""},
	"Hops":    {"stem": "vine",          "leaf": "vine_leaves",  "fruit": "bell",       "flower": ""},
	# ── Flowers / decorative ──
	"Bloom":   {"stem": "thin_straight", "leaf": "simple_small", "fruit": "small_circle",     "flower": "rose"},
	"Sunflower":{"stem": "thick_straight", "leaf": "simple_large","fruit": "small_circle",     "flower": "daisy"},
	# ── Mushrooms ──
	"Fungus":  {"stem": "mushroom_stalk","leaf": "",             "fruit": "mushroom_cap",     "flower": ""},
	"Cap":     {"stem": "mushroom_stalk","leaf": "",             "fruit": "mushroom_cap",     "flower": ""},
	# ── Spiky / cactus ──
	"Cactus":  {"stem": "thick_straight", "leaf": "pointed",     "fruit": "diamond",    "flower": "spikes"},
	"Shard":   {"stem": "thick_straight", "leaf": "",            "fruit": "diamond",    "flower": ""},
	# ── Bulbs ──
	"Bulb":    {"stem": "thin_straight", "leaf": "pointed",      "fruit": "bell",       "flower": ""},
	"Knob":    {"stem": "thin_straight", "leaf": "simple_small", "fruit": "bell",       "flower": ""},
	# ── Stalks / tall plants ──
	"Stalk":   {"stem": "corn_stalk",    "leaf": "pointed",      "fruit": "corn_cob",   "flower": ""},
	"Frond":   {"stem": "curved",        "leaf": "fern",         "fruit": "small_circle",     "flower": ""},
	"Sprig":   {"stem": "thin_straight", "leaf": "fern",         "fruit": "small_circle",     "flower": ""},
	"Plume":   {"stem": "curved",        "leaf": "fern",         "fruit": "bell",       "flower": ""},
	# ── Vine / climber ──
	"Vine":    {"stem": "vine",          "leaf": "vine_leaves",  "fruit": "small_circle",     "flower": ""},
	"Tendril": {"stem": "vine",          "leaf": "vine_leaves",  "fruit": "small_circle",     "flower": ""},
	# ── Husk / cotton / fibrous ──
	"Husk":    {"stem": "thick_straight", "leaf": "pointed",     "fruit": "star",       "flower": ""},
	"Cotton":  {"stem": "thick_straight", "leaf": "rounded",     "fruit": "star",       "flower": ""},
	# ── Tree fruit ──
	"Apple":   {"stem": "thick_straight", "leaf": "rounded",     "fruit": "large_circle",     "flower": "simple_5petal"},
	"Pepper":  {"stem": "thin_straight", "leaf": "simple_small", "fruit": "bell",       "flower": ""},
	# ── Tea ──
	"Tea":     {"stem": "thin_straight", "leaf": "simple_small", "fruit": "small_circle",     "flower": "simple_5petal"},
}

## Pre-generated AI pixel-art base sprites for each root word.
## These are loaded at runtime and tinted by the crop's prefix color,
## giving each crop a recognizable, hand-crafted look.
const ROOT_BASE_SPRITES: Dictionary = {
	"Melon":    "res://assets/generated/crop_base_melon_frame_0.png",
	"Berry":    "res://assets/generated/crop_base_berry_frame_0.png",
	"Root":     "res://assets/generated/crop_base_carrot_frame_0.png",
	"Carrot":   "res://assets/generated/crop_base_carrot_frame_0.png",
	"Tuber":    "res://assets/generated/crop_base_tuber_frame_0.png",
	"Vine":     "res://assets/generated/crop_base_vine_frame_0.png",
	"Bulb":     "res://assets/generated/crop_base_bulb_frame_0.png",
	"Stalk":    "res://assets/generated/crop_base_stalk_frame_0.png",
	"Pod":      "res://assets/generated/crop_base_pod_frame_0.png",
	"Bloom":    "res://assets/generated/crop_base_bloom_frame_0.png",
	"Cactus":   "res://assets/generated/crop_base_cactus_frame_0.png",
	"Fungus":   "res://assets/generated/crop_base_fungus_frame_0.png",
	"Cap":      "res://assets/generated/crop_base_fungus_frame_0.png",
	"Frond":    "res://assets/generated/crop_base_frond_frame_0.png",
	"Knob":     "res://assets/generated/crop_base_knob_frame_0.png",
	"Sprig":    "res://assets/generated/crop_base_sprig_frame_0.png",
	"Clump":    "res://assets/generated/crop_base_clump_frame_0.png",
	"Shard":    "res://assets/generated/crop_base_shard_frame_0.png",
	"Husk":     "res://assets/generated/crop_base_husk_frame_0.png",
	"Plume":    "res://assets/generated/crop_base_plume_frame_0.png",
	"Tendril":  "res://assets/generated/crop_base_tendril_frame_0.png",
	"Corn":     "res://assets/generated/crop_base_corn_frame_0.png",
}

## Pre-generated AI pixel-art seed packet sprites for each root word.
## These are loaded at runtime and tinted by the crop's prefix color,
## giving each seed a recognizable, hand-crafted look that's distinct
## from the crop's icon while sharing the same color identity.
const SEED_BASE_SPRITES: Dictionary = {
	"Melon":    "res://assets/generated/seed_base_melon_frame_0.png",
	"Berry":    "res://assets/generated/seed_base_berry_frame_0.png",
	"Root":     "res://assets/generated/seed_base_carrot_frame_0.png",
	"Carrot":   "res://assets/generated/seed_base_carrot_frame_0.png",
	"Tuber":    "res://assets/generated/seed_base_tuber_frame_0.png",
	"Vine":     "res://assets/generated/seed_base_vine_frame_0.png",
	"Bulb":     "res://assets/generated/seed_base_bulb_frame_0.png",
	"Stalk":    "res://assets/generated/seed_base_stalk_frame_0.png",
	"Pod":      "res://assets/generated/seed_base_pod_frame_0.png",
	"Bloom":    "res://assets/generated/seed_base_bloom_frame_0.png",
	"Cactus":   "res://assets/generated/seed_base_cactus_frame_0.png",
	"Fungus":   "res://assets/generated/seed_base_fungus_frame_0.png",
	"Cap":      "res://assets/generated/seed_base_fungus_frame_0.png",
	"Frond":    "res://assets/generated/seed_base_frond_frame_0.png",
	"Knob":     "res://assets/generated/seed_base_knob_frame_0.png",
	"Sprig":    "res://assets/generated/seed_base_sprig_frame_0.png",
	"Clump":    "res://assets/generated/seed_base_clump_frame_0.png",
	"Shard":    "res://assets/generated/seed_base_shard_frame_0.png",
	"Husk":     "res://assets/generated/seed_base_husk_frame_0.png",
	"Plume":    "res://assets/generated/seed_base_plume_frame_0.png",
	"Tendril":  "res://assets/generated/seed_base_tendril_frame_0.png",
	"Corn":     "res://assets/generated/seed_base_corn_frame_0.png",
}

static func generate_crop_textures(crop_name: String, base_color: Color, rng_seed: int, root_word: String = "") -> Array[Texture2D]:
	if root_word != "" and ROOT_BASE_SPRITES.has(root_word):
		return _generate_base_crop_textures(crop_name, base_color, rng_seed, root_word)

	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = rng_seed + hash(crop_name)

	var pieces := _pick_crop_pieces(rng_seed, local_rng, root_word)
	var colors := _pick_crop_colors(base_color, local_rng)

	var sprite_gen := CropSpriteGenerator.new().create_crop_from_pieces(
		pieces.stem, pieces.leaf, pieces.fruit,
		pieces.flower, pieces.pattern, pieces.effect,
		colors.fruit, colors.flower,
		colors.stem_tint, colors.leaf_tint
	)
	return sprite_gen.generate_growth_stages(4)


static func generate_seed_icon(crop_name: String, base_color: Color, rng_seed: int, root_word: String = "", for_seed: bool = false) -> Texture2D:
	if root_word != "" and ROOT_BASE_SPRITES.has(root_word):
		if for_seed:
			# Use the seed packet base sprite — same tint, different shape
			if SEED_BASE_SPRITES.has(root_word):
				return _generate_root_base_icon(root_word, base_color, true)
			return _generate_root_base_icon(root_word, base_color)
		return _generate_root_base_icon(root_word, base_color)

	var seed_val := hash("seed_" + crop_name + str(rng_seed))
	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = seed_val

	var pieces := _pick_crop_pieces(seed_val, local_rng, root_word)
	var colors := _pick_crop_colors(base_color, local_rng)

	var sprite_gen := CropSpriteGenerator.new().create_crop_from_pieces(
		pieces.stem, pieces.leaf, pieces.fruit,
		pieces.flower, "", pieces.effect,
		colors.fruit, colors.flower,
		colors.stem_tint, colors.leaf_tint
	)
	return sprite_gen.generate_texture()


static func _pick_crop_pieces(seed_val: int, local_rng: RandomNumberGenerator, root_word: String = "") -> Dictionary:
	var lib := SpritePieceLibrary

	# If we have a root template for this crop, use its recognisable pieces
	if root_word != "" and ROOT_TEMPLATES.has(root_word):
		var tmpl: Dictionary = ROOT_TEMPLATES[root_word]
		return {
			stem = tmpl.get("stem", "thin_straight"),
			leaf = tmpl.get("leaf", "simple_small"),
			fruit = tmpl.get("fruit", "small_circle"),
			flower = tmpl.get("flower", "") if local_rng.randf() > 0.5 else "",
			pattern = "",
			effect = "",
		}

	# Fallback: random selection (old behaviour for roots without a template)
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


static func _pick_crop_colors(base_color: Color, _local_rng: RandomNumberGenerator) -> Dictionary:
	# Use a deterministic RNG seeded from the base_color itself so seed icons
	# and crop textures always produce IDENTICAL fruit/flower colors from the
	# same base — no matter which caller RNG seed they use. This guarantees
	# every seed shares its crop's palette: a blue seed grows a blue crop.
	#
	# FRUIT uses the base_color *directly* (no jitter) so the seed icon's
	# most prominent piece is an exact visual match to the crop's modulate_color.
	# FLOWER gets only a whisper of shift (±0.03) to stay in the same family.
	# STEM_TINT and LEAF_TINT use the crop's hue directly (with lower sat/val
	# so they still read as plant matter) — a red crop gets reddish stems,
	# a blue crop gets bluish stems, not always green.
	var color_rng := RandomNumberGenerator.new()
	color_rng.seed = hash(base_color)
	var base_hue := base_color.h
	var base_sat := base_color.s
	var base_val := base_color.v

	# Stem/leaf tint: use the crop's own hue, just with subdued saturation/value
	# so the plant parts still look organic but share the crop's color identity.
	var stem_leaf_hue := wrapf(base_hue, 0.0, 1.0)
	var stem_leaf_sat := clampf(base_sat * 0.3 + 0.15, 0.2, 0.55)
	var stem_leaf_val := clampf(base_val * 0.4 + 0.3, 0.3, 0.7)

	return {
		fruit = base_color,
		flower = Color.from_hsv(
			fmod(base_hue + color_rng.randf_range(-0.03, 0.03), 1.0),
			clampf(base_sat + color_rng.randf_range(-0.1, 0.1), 0.5, 1.0),
			clampf(base_val + color_rng.randf_range(-0.1, 0.1), 0.6, 1.0)
		),
		stem_tint = Color.from_hsv(stem_leaf_hue, stem_leaf_sat, stem_leaf_val),
		leaf_tint = Color.from_hsv(stem_leaf_hue, stem_leaf_sat, stem_leaf_val),
	}


## Loads the pre-generated base sprite for a root word, tints every pixel
## by the given color, and returns it as a 24x24 ImageTexture.
## If `for_seed` is true, loads from SEED_BASE_SPRITES instead so seed
## icons get a distinct packet shape while sharing the crop's color.
static func _generate_root_base_icon(root_word: String, tint: Color, for_seed: bool = false) -> Texture2D:
	var sprite_dict: Dictionary = SEED_BASE_SPRITES if for_seed else ROOT_BASE_SPRITES
	var path: String = sprite_dict.get(root_word, "")
	if path.is_empty() or not ResourceLoader.exists(path):
		return _generate_root_base_icon_fallback(root_word, tint)

	var src_texture: Texture2D = load(path)
	if not src_texture:
		return _generate_root_base_icon_fallback(root_word, tint)
	var src: Image = src_texture.get_image()
	if not src:
		return _generate_root_base_icon_fallback(root_word, tint)

	var size: int = src.get_width()
	var tinted: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	tinted.fill(Color.TRANSPARENT)

	for y in range(size):
		for x in range(size):
			var px: Color = src.get_pixel(x, y)
			if px.a > 0.01:
				tinted.set_pixel(x, y, Color(
					px.r * tint.r,
					px.g * tint.g,
					px.b * tint.b,
					px.a
				))

	return ImageTexture.create_from_image(tinted)


## Fallback when the pre-generated base sprite fails to load.
## Creates a simple colored circle as a placeholder.
static func _generate_root_base_icon_fallback(_root_word: String, tint: Color) -> Texture2D:
	var img: Image = Image.create(24, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	for y in range(24):
		for x in range(24):
			var px: float = float(x) - 11.5
			var py: float = float(y) - 11.5
			if px * px + py * py <= 100.0:
				img.set_pixel(x, y, tint)
	return ImageTexture.create_from_image(img)


## Generates 4 growth stage textures compositing stem/leaf pieces from the
## template (background) with the tinted base sprite (foreground) scaled by
## growth progress.
static func _generate_base_crop_textures(crop_name: String, base_color: Color, rng_seed: int, root_word: String) -> Array[Texture2D]:
	var root_path: String = ROOT_BASE_SPRITES.get(root_word, "")
	if root_path.is_empty() or not ResourceLoader.exists(root_path):
		return generate_crop_textures(crop_name, base_color, rng_seed, root_word)

	var src_texture: Texture2D = load(root_path)
	if not src_texture:
		return generate_crop_textures(crop_name, base_color, rng_seed, root_word)
	var src: Image = src_texture.get_image()
	if not src:
		return generate_crop_textures(crop_name, base_color, rng_seed, root_word)

	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = rng_seed + hash(crop_name)
	var pieces := _pick_crop_pieces(rng_seed, local_rng, root_word)
	var colors := _pick_crop_colors(base_color, local_rng)

	const SIZE: int = 24
	const STAGE_COUNT: int = 4
	var result: Array[Texture2D] = []

	for stage in range(STAGE_COUNT):
		var progress := float(stage + 1) / float(STAGE_COUNT)
		var stage_img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
		stage_img.fill(Color.TRANSPARENT)

		# Render stem/leaf at this growth stage
		var stem_gen := CropSpriteGenerator.new()
		stem_gen.set_sprite_size(SIZE)
		var lib := SpritePieceLibrary

		if pieces.stem != "":
			var stem: StemLayer = lib.get_stem_pieces()[pieces.stem].duplicate()
			stem.color = colors.stem_tint
			var orig_scale := stem.scale
			stem.scale = progress * orig_scale
			stem.render(stage_img, SIZE / 2, SIZE / 2)
			stem.scale = orig_scale

		if pieces.leaf != "":
			var leaf: LeavesLayer = lib.get_leaf_pieces()[pieces.leaf].duplicate()
			leaf.color = colors.leaf_tint
			var orig_scale := leaf.scale
			leaf.scale = progress * orig_scale
			leaf.render(stage_img, SIZE / 2, SIZE / 2)
			leaf.scale = orig_scale

		if pieces.flower != "":
			var flower: FlowerLayer = lib.get_flower_pieces()[pieces.flower].duplicate()
			flower.color = colors.flower
			flower.render(stage_img, SIZE / 2, SIZE / 2)

		# Composite the tinted base sprite on top, scaled by progress
		var scale_factor: float = max(0.2, progress * 0.9)
		var dst_w: int = maxi(2, ceili(SIZE * scale_factor))
		var dst_h: int = maxi(2, ceili(SIZE * scale_factor))
		var src_resized: Image = src.duplicate()
		src_resized.resize(dst_w, dst_h, Image.INTERPOLATE_NEAREST)

		var offset_x: int = (SIZE - dst_w) / 2
		var offset_y: int = (SIZE - dst_h) / 2

		for sy in range(dst_h):
			for sx in range(dst_w):
				var px: Color = src_resized.get_pixel(sx, sy)
				if px.a > 0.01:
					var tinted := Color(
						px.r * base_color.r,
						px.g * base_color.g,
						px.b * base_color.b,
						px.a
					)
					# Blend over stem/leaf using alpha compositing
					var existing := stage_img.get_pixel(offset_x + sx, offset_y + sy)
					var blend := Color(
						tinted.r * tinted.a + existing.r * (1.0 - tinted.a),
						tinted.g * tinted.a + existing.g * (1.0 - tinted.a),
						tinted.b * tinted.a + existing.b * (1.0 - tinted.a),
						max(tinted.a, existing.a)
					)
					stage_img.set_pixel(offset_x + sx, offset_y + sy, blend)

		result.append(ImageTexture.create_from_image(stage_img))

	return result
