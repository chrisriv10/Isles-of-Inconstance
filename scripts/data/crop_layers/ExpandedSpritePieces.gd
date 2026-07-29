class_name ExpandedSpritePieces
extends RefCounted

## Expanded sprite piece library with more stems, leaves, flowers, fruits,
## and special effects for richer crop visual variety.

static func get_expanded_stems() -> Dictionary:
	return {
		"thin_straight": {"type": "stem", "shape": "thin_line", "height": 6, "width": 1},
		"thick_straight": {"type": "stem", "shape": "thick_line", "height": 7, "width": 2},
		"curved": {"type": "stem", "shape": "arc", "height": 6, "width": 2},
		"vine": {"type": "stem", "shape": "wiggly", "height": 8, "width": 2},
		"mushroom_stalk": {"type": "stem", "shape": "tapered", "height": 5, "width": 3},
		"bamboo": {"type": "stem", "shape": "segmented", "height": 9, "width": 2},
		"twisted": {"type": "stem", "shape": "spiral", "height": 7, "width": 2},
		"thick_vine": {"type": "stem", "shape": "thick_wiggly", "height": 8, "width": 3},
		"cactus_stem": {"type": "stem", "shape": "rounded", "height": 6, "width": 3},
		"tall_stalk": {"type": "stem", "shape": "tall_line", "height": 10, "width": 1},
	}

static func get_expanded_leaves() -> Dictionary:
	return {
		"simple": {"type": "leaf", "shape": "oval", "size": 3},
		"pointed": {"type": "leaf", "shape": "pointed_oval", "size": 3},
		"rounded": {"type": "leaf", "shape": "circle", "size": 2},
		"fern": {"type": "leaf", "shape": "segmented", "size": 4},
		"vine_leaf": {"type": "leaf", "shape": "heart", "size": 2},
		"broad": {"type": "leaf", "shape": "wide_oval", "size": 4},
		"needle": {"type": "leaf", "shape": "thin_pointed", "size": 3},
		"fan": {"type": "leaf", "shape": "fan_shape", "size": 3},
		"lobed": {"type": "leaf", "shape": "maple", "size": 4},
		"succulent": {"type": "leaf", "shape": "thick_oval", "size": 3},
		"frond": {"type": "leaf", "shape": "feathery", "size": 5},
		"spade": {"type": "leaf", "shape": "spade_shape", "size": 3},
	}

static func get_expanded_fruits() -> Dictionary:
	return {
		"small_circle": {"type": "fruit", "shape": "circle", "size": 3},
		"large_circle": {"type": "fruit", "shape": "circle", "size": 5},
		"oval": {"type": "fruit", "shape": "ellipse", "size": 4},
		"diamond": {"type": "fruit", "shape": "diamond", "size": 3},
		"star": {"type": "fruit", "shape": "star", "size": 4},
		"mushroom_cap": {"type": "fruit", "shape": "dome", "size": 4},
		"bell": {"type": "fruit", "shape": "bell", "size": 3},
		"berry_cluster": {"type": "fruit", "shape": "cluster", "size": 4},
		"cone": {"type": "fruit", "shape": "triangle", "size": 4},
		"crescent": {"type": "fruit", "shape": "crescent", "size": 3},
		"heart": {"type": "fruit", "shape": "heart", "size": 4},
		"pod": {"type": "fruit", "shape": "bean", "size": 5},
		"spiky": {"type": "fruit", "shape": "spiky_circle", "size": 4},
		"tuber": {"type": "fruit", "shape": "lumpy_oval", "size": 4},
		"tendril": {"type": "fruit", "shape": "curly", "size": 3},
	}

static func get_expanded_flowers() -> Dictionary:
	return {
		"simple": {"type": "flower", "shape": "5_petal", "size": 3},
		"daisy": {"type": "flower", "shape": "many_petal", "size": 4},
		"tulip": {"type": "flower", "shape": "cup", "size": 3},
		"rose": {"type": "flower", "shape": "layered", "size": 4},
		"spikes": {"type": "flower", "shape": "spike", "size": 3},
		"bell_flower": {"type": "flower", "shape": "hanging_bell", "size": 3},
		"cluster": {"type": "flower", "shape": "small_cluster", "size": 4},
		"star_flower": {"type": "flower", "shape": "6_point", "size": 3},
		"tuft": {"type": "flower", "shape": "fluffy", "size": 3},
		"lotus": {"type": "flower", "shape": "layered_points", "size": 4},
	}

static func get_expanded_patterns() -> Dictionary:
	return {
		"dots": {"type": "pattern", "shape": "small_dots"},
		"stripes": {"type": "pattern", "shape": "vertical_lines"},
		"checker": {"type": "pattern", "shape": "checkerboard"},
		"spots": {"type": "pattern", "shape": "irregular_spots"},
		"spiral": {"type": "pattern", "shape": "spiral_lines"},
		"zigzag": {"type": "pattern", "shape": "zigzag_lines"},
		"rings": {"type": "pattern", "shape": "concentric"},
		"gradient": {"type": "pattern", "shape": "fade"},
	}

static func get_expanded_effects() -> Dictionary:
	return {
		"glow": {"type": "effect", "shape": "radial_glow"},
		"sparkle": {"type": "effect", "shape": "small_stars"},
		"shadow": {"type": "effect", "shape": "drop_shadow"},
		"outline": {"type": "effect", "shape": "border"},
		"glow_blue": {"type": "effect", "shape": "blue_glow"},
		"glow_gold": {"type": "effect", "shape": "gold_glow"},
		"pulsing": {"type": "effect", "shape": "pulse_ring"},
		"outline_dark": {"type": "effect", "shape": "dark_border"},
	}
