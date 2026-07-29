class_name InconstantFruitSystem
extends RefCounted

## Generates unique Inconstant Fruit items — legendary, one-of-a-kind fruits.
## Each fruit has a procedurally generated name, random power with random
## strength, and a unique swirl-vortex icon.
##
## Also generates the legendary "Soul Fruit" — a unique fruit that grants ALL
## powers at once. The Soul Fruit only becomes findable in the wild after the
## Inconstant Soul boss is defeated.

const INCONSTANT_FRUIT_ID_PREFIX: String = "inconstant_fruit_"
const SOUL_FRUIT_ID: String = "inconstant_fruit_soul"

# ── Name generation ──────────────────────────────────────────────────────────

const NAME_PREFIXES: Array[String] = [
	"Zephyr", "Ember", "Void", "Shadow", "Crystal", "Storm", "Frost", "Flame",
	"Thunder", "Solar", "Lunar", "Phantom", "Spectral", "Iron", "Silk",
	"Rune", "Arcane", "Sylvan", "Abyssal", "Celestial", "Verdant", "Crimson",
	"Azure", "Amber", "Obsidian", "Pearl", "Jade", "Topaz", "Ruby", "Sapphire",
	"Ghost", "Dusk", "Dawn", "Wild", "Primal", "Ethereal", "Feral", "Gilded",
	"Gale", "Ash", "Bone", "Cinder", "Shade", "Tide", "Earth", "Sky",
	"Star", "Nebula", "Chaos", "Hollow", "Living", "Golden", "Silver", "Bronze",
	"Copper", "Cobalt", "Ivory", "Onyx", "Scarlet", "Violet", "Indigo",
]

const NAME_SUFFIXES: Array[String] = [
	"Whirl", "Veil", "Stride", "Surge", "Nova", "Bloom", "Shard",
	"Breath", "Song", "Dance", "Fang", "Claw", "Wing", "Root", "Tide",
	"Flux", "Pulse", "Spark", "Gleam", "Haze", "Gale", "Burst", "Crush",
	"Weave", "Mist", "Bane", "Boon", "Heart", "Soul", "Eye", "Scale",
	"Bite", "Sting", "Grasp", "Touch", "Gaze", "Roar", "Howl", "Whisper",
	"Scream", "Lament", "Rise", "Fall", "Drift", "Flow", "Rush", "Crash",
	"Flash", "Flame", "Frost", "Vine", "Bark", "Thorn", "Rose",
]

# ── Power definitions ────────────────────────────────────────────────────────

# Each power type maps to a BuffManager-supported buff_type with random strength.
const POWER_TYPES: Array[Dictionary] = [
	{
		"buff_type": "speed",
		"color": Color(0.2, 0.6, 1.0),
		"body_key": "inconstant_fruit",
		"min_strength": 0.2,
		"max_strength": 0.5,
		"display": "movement speed",
		"unit": "%%",
		"mult": 100.0,
		"flavors": [
			"The wind bends to your will",
			"You move like a falling star",
			"Time slows as you pass by",
		],
	},
	{
		"buff_type": "growth",
		"color": Color(0.1, 0.8, 0.2),
		"body_key": "inconstant_fruit",
		"min_strength": 2.0,
		"max_strength": 12.0,
		"display": "crop growth speed",
		"unit": "x",
		"mult": 1.0,
		"flavors": [
			"The land answers your call",
			"Seeds sprout at your mere presence",
			"Nature's clock ticks faster for you",
		],
	},
	{
		"buff_type": "energy",
		"color": Color(0.8, 0.6, 0.1),
		"body_key": "inconstant_fruit",
		"min_strength": 0.3,
		"max_strength": 1.0,
		"display": "energy efficiency",
		"unit": "%%",
		"mult": 100.0,
		"flavors": [
			"You never tire — the sun is your battery",
			"Fatigue is a foreign concept to you",
			"Your stamina is boundless",
		],
	},
	{
		"buff_type": "luck",
		"color": Color(0.7, 0.2, 0.9),
		"body_key": "inconstant_fruit",
		"min_strength": 2.0,
		"max_strength": 8.0,
		"display": "luck",
		"unit": "x",
		"mult": 1.0,
		"flavors": [
			"Fortune smiles upon you always",
			"The universe rearranges in your favor",
			"Every gamble pays off tenfold",
		],
	},
	{
		"buff_type": "health",
		"color": Color(0.9, 0.1, 0.3),
		"body_key": "inconstant_fruit",
		"min_strength": 1.0,
		"max_strength": 10.0,
		"display": "health regeneration",
		"unit": " HP/tick",
		"mult": 1.0,
		"flavors": [
			"Your wounds close before your eyes",
			"Your life force swells beyond mortal limits",
			"You regenerate like a mythical beast",
		],
	},
	{
		"buff_type": "defense",
		"color": Color(0.3, 0.3, 0.8),
		"body_key": "inconstant_fruit",
		"min_strength": 0.1,
		"max_strength": 0.8,
		"display": "damage reduction",
		"unit": "%%",
		"mult": 100.0,
		"flavors": [
			"You are as unyielding as ancient stone",
			"Blows glance off you like water",
			"No harm can find purchase on your skin",
		],
	},
]

# All buff keys used by the Soul Fruit
const SOUL_BUFF_TYPES: Array[String] = ["speed", "growth", "energy", "luck", "health", "defense"]
const SOUL_BUFF_STRENGTHS: Array[float] = [0.4, 5.0, 0.5, 3.0, 3.0, 0.3]

# ── Public generation ────────────────────────────────────────────────────────

## Generates [count] unique Inconstant Fruits plus the legendary Soul Fruit.
## Registers them all with DataManager and returns the full array.
func generate_fruits(world_seed: int, count: int) -> Array[ItemData]:
	var results: Array[ItemData] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + 99999

	# Generate procedural fruits
	for i in range(count):
		var fruit := _build_procedural_fruit(i, rng)
		DataManager.register_item(fruit)
		results.append(fruit)

	# Always generate the Soul Fruit (hidden until boss defeated)
	var soul_fruit := _build_soul_fruit(rng)
	if not DataManager.items.has(SOUL_FRUIT_ID):
		DataManager.register_item(soul_fruit)
	results.append(soul_fruit)

	return results


## Returns all Inconstant Fruits currently findable in the wild.
## The Soul Fruit is only included after the Inconstant Soul boss is defeated.
static func get_wild_findable_fruits() -> Array[ItemData]:
	var results: Array[ItemData] = []
	var soul_unlocked: bool = false
	if Engine.has_singleton("ObjectiveManager"):
		var om: Node = Engine.get_singleton("ObjectiveManager")
		if om and om.has_method("is_objective_completed"):
			soul_unlocked = om.is_objective_completed(15)  # DEFEAT_INCONSTANT_SOUL

	for item in DataManager.items.values():
		if item and item.get_meta("inconstant_power", false):
			var is_soul: bool = item.get_meta("is_soul_fruit", false)
			if is_soul and not soul_unlocked:
				continue  # Soul Fruit hidden until boss defeated
			results.append(item)
	return results


# ── Procedural fruit building ────────────────────────────────────────────────

func _build_procedural_fruit(index: int, rng: RandomNumberGenerator) -> ItemData:
	var fruit_id: String = INCONSTANT_FRUIT_ID_PREFIX + str(index)
	var power_def: Dictionary = POWER_TYPES[rng.randi() % POWER_TYPES.size()]

	# Random strength within the power's range
	var strength: float = rng.randf_range(power_def["min_strength"], power_def["max_strength"])
	# Round to 1 decimal
	strength = snapped(strength, 0.1)

	# Random flavor text
	var flavors: Array = power_def["flavors"]
	var flavor: String = flavors[rng.randi() % flavors.size()]

	# Generate name: "Prefix Suffix Fruit"
	var prefix: String = NAME_PREFIXES[rng.randi() % NAME_PREFIXES.size()]
	var suffix: String = NAME_SUFFIXES[rng.randi() % NAME_SUFFIXES.size()]
	var fruit_name: String = prefix + " " + suffix + " Fruit"
	var power_name: String = prefix + " " + suffix

	# Build display value
	var display_val: String = _format_strength(strength, power_def["unit"], power_def["mult"])
	var desc_line: String = "%s %s" % [display_val, power_def["display"]]

	# Main color with slight random variation
	var base_color: Color = power_def["color"]
	base_color = Color(
		clampf(base_color.r + rng.randf_range(-0.15, 0.15), 0.05, 1.0),
		clampf(base_color.g + rng.randf_range(-0.15, 0.15), 0.05, 1.0),
		clampf(base_color.b + rng.randf_range(-0.15, 0.15), 0.05, 1.0),
	)

	# Generate icon
	var icon := _generate_icon(base_color, fruit_id, rng)

	var fruit := ItemData.new()
	fruit.id = fruit_id
	fruit.display_name = fruit_name
	fruit.category = "consumable"
	fruit.stack_size = 1
	fruit.sell_price = 50000
	fruit.buy_price = 10000
	fruit.icon = icon
	fruit.description = _build_description(power_name, desc_line, flavor)

	fruit.set_meta("inconstant_power", true)
	fruit.set_meta("is_soul_fruit", false)
	fruit.set_meta("buff_type", power_def["buff_type"])
	fruit.set_meta("buff_strength", strength)
	fruit.set_meta("buff_duration", 999999)
	fruit.set_meta("power_name", power_name)

	return fruit


# ── Soul Fruit building ──────────────────────────────────────────────────────

## Builds the legendary "Soul Fruit" — the concentrated essence of the Inconstant
## Soul itself. Grants ALL powers at once at moderate strength.
func _build_soul_fruit(_rng: RandomNumberGenerator) -> ItemData:
	var icon := _generate_soul_icon()

	var fruit := ItemData.new()
	fruit.id = SOUL_FRUIT_ID
	fruit.display_name = "Soul Fruit"
	fruit.category = "consumable"
	fruit.stack_size = 1
	fruit.sell_price = 0      # Cannot be sold — too legendary
	fruit.buy_price = 0       # Cannot be bought

	# Build a multi-power description
	var power_lines: String = ""
	for i in range(SOUL_BUFF_TYPES.size()):
		var bt: String = SOUL_BUFF_TYPES[i]
		var bs: float = SOUL_BUFF_STRENGTHS[i]
		var def: Dictionary = _find_power_def(bt)
		if not def.is_empty():
			var val: String = _format_strength(bs, def["unit"], def["mult"])
			power_lines += "\n[color=#AAFFAA]•  %s %s[/color]" % [val, def["display"]]

	fruit.description = (
		"[color=#FFD700][b]✦ Soul Fruit ✦[/b][/color]\n"
		+ "[color=#CC88FF][i]The concentrated essence of the Inconstant Soul[/i][/color]\n"
		+ "[color=#FFCC44]Grants ALL powers at once:[/color]"
		+ power_lines
		+ "\n\n[color=#FF8844]━━━━━━━━━━━━━━━━━━[/color]"
		+ "\n[color=#FF4444][b]⚠ WARNING ⚠[/b][/color]"
		+ "\n[color=#FF6666]Consuming this fruit in Survival mode will[/color]"
		+ "\n[color=#FF4444][b]PERMANENTLY switch your world to HARDCORE![/b][/color]"
		+ "\n[color=#FF6666]Death will be permanent — your save will be deleted.[/color]"
		+ "\n[color=#FF8844]━━━━━━━━━━━━━━━━━━[/color]"
	)
	fruit.icon = icon

	fruit.set_meta("inconstant_power", true)
	fruit.set_meta("is_soul_fruit", true)
	fruit.set_meta("buff_type", "soul")           # special sentinel
	fruit.set_meta("buff_strength", 1.0)
	fruit.set_meta("buff_duration", 999999)
	fruit.set_meta("power_name", "Soul Fruit")
	fruit.set_meta("soul_buff_types", SOUL_BUFF_TYPES)
	fruit.set_meta("soul_buff_strengths", SOUL_BUFF_STRENGTHS)

	return fruit


# ── Icon generation ──────────────────────────────────────────────────────────

## Pre-generated AI pixel art fruit bodies for the inconstant fruits.
## Each fruit picks a random shape, then gets tinted with its base_color.
const FRUIT_BODY_SPRITES: Array[String] = [
	"res://assets/generated/fruit_body_round_frame_0.png",
	"res://assets/generated/fruit_body_teardrop_frame_0.png",
	"res://assets/generated/fruit_body_oval_frame_0.png",
	"res://assets/generated/fruit_body_diamond_frame_0.png",
	"res://assets/generated/fruit_body_star_frame_0.png",
	"res://assets/generated/fruit_body_bell_frame_0.png",
]

## The Soul Fruit uses a unique fixed AI-generated sprite (no tinting).
const SOUL_FRUIT_SPRITE_PATH: String = "res://assets/generated/soul_fruit_icon.png"


func _generate_icon(base_color: Color, _fruit_id: String, rng: RandomNumberGenerator) -> Texture2D:
	# Pick a random fruit body shape
	var shape_path: String = FRUIT_BODY_SPRITES[rng.randi() % FRUIT_BODY_SPRITES.size()]
	var base_tex: Texture2D = load(shape_path) if ResourceLoader.exists(shape_path) else null
	if base_tex:
		return _tint_texture(base_tex, base_color)

	# Fallback: generate procedural swirl (old method)
	var generator := CropSpriteGenerator.new()
	generator.set_sprite_size(24)
	var library := SpritePieceLibrary

	var swirl: FruitBodyLayer = library.get_fruit_pieces()["inconstant_fruit"].duplicate()
	swirl.color = base_color
	generator.add_layer(swirl)

	var glow: SpecialEffectsLayer = library.get_effect_pieces()["glow_blue"].duplicate()
	glow.effect_color = Color(
		clampf(base_color.r * 0.5, 0, 1),
		clampf(base_color.g * 0.5, 0, 1),
		clampf(base_color.b * 0.8, 0, 1)
	)
	glow.intensity = 0.4
	glow.radius = 2
	generator.add_layer(glow)

	return generator.generate_texture()


## Tints a grayscale/base texture with the given color.
## Works by multiplying each pixel's RGB by the target color,
## preserving the original alpha and luminance.
func _tint_texture(source: Texture2D, tint: Color) -> ImageTexture:
	var img: Image = source.get_image()
	if not img:
		return source as ImageTexture
	var w: int = img.get_width()
	var h: int = img.get_height()
	for y in range(h):
		for x in range(w):
			var pixel: Color = img.get_pixel(x, y)
			if pixel.a > 0.0:
				# Apply tint while preserving the pixel's luminance (brightness)
				var lum: float = (pixel.r * 0.299 + pixel.g * 0.587 + pixel.b * 0.114)
				var new_color: Color = Color(
					tint.r * lum,
					tint.g * lum,
					tint.b * lum,
					pixel.a
				)
				img.set_pixel(x, y, new_color)
	return ImageTexture.create_from_image(img)


## The Soul Fruit uses a unique fixed AI-generated sprite with no tinting.
## A legendary glowing purple-gold star fruit with galaxy vortex pattern.
func _generate_soul_icon() -> Texture2D:
	if ResourceLoader.exists(SOUL_FRUIT_SPRITE_PATH):
		return load(SOUL_FRUIT_SPRITE_PATH)
	# Fallback: procedural composite
	var generator := CropSpriteGenerator.new()
	generator.set_sprite_size(24)
	var library := SpritePieceLibrary

	var star: FruitBodyLayer = library.get_fruit_pieces()["star"].duplicate()
	star.color = Color(0.35, 0.1, 0.5)
	generator.add_layer(star)

	var swirl: FruitBodyLayer = library.get_fruit_pieces()["inconstant_fruit"].duplicate()
	swirl.color = Color(0.8, 0.7, 1.0, 0.7)
	generator.add_layer(swirl)

	var glow: SpecialEffectsLayer = library.get_effect_pieces()["glow_gold"].duplicate()
	glow.effect_color = Color(0.6, 0.3, 1.0)
	glow.intensity = 0.6
	glow.radius = 3
	generator.add_layer(glow)

	var sparkle: SpecialEffectsLayer = library.get_effect_pieces()["sparkle"].duplicate()
	generator.add_layer(sparkle)

	return generator.generate_texture()


# ── Consumption ──────────────────────────────────────────────────────────────

## Called when the player consumes an Inconstant Fruit (or the Soul Fruit).
## Returns {success, message, mode_changed, power_name}.
static func consume_fruit(fruit_id: String) -> Dictionary:
	var item: ItemData = DataManager.get_item(fruit_id)
	if not item or not item.get_meta("inconstant_power", false):
		return {"success": false, "message": "Not an Inconstant Fruit."}

	var was_hardcore_switch: bool = false
	var power_name: String = item.get_meta("power_name", "Unknown Power")

	# If in Survival mode, switch to Hardcore
	if GameManager.game_mode == GameManager.GameMode.SURVIVAL:
		GameManager.set_game_mode(GameManager.GameMode.HARDCORE)
		was_hardcore_switch = true

	# Check if it's the Soul Fruit (multi-power) or a regular fruit
	if item.get_meta("is_soul_fruit", false):
		_apply_soul_fruit_buffs(item)
		power_name = "the Soul Fruit"
	else:
		var buff_type: String = item.get_meta("buff_type", "luck")
		var buff_strength: float = item.get_meta("buff_strength", 1.0)
		var buff_duration: int = item.get_meta("buff_duration", 999999)
		if BuffManager:
			BuffManager.apply_potion_effect(buff_type, buff_strength, float(buff_duration), power_name)

	# Grant the permanent Inconstant Soul power (20% chance per melee hit to
	# unleash one of the boss's attacks on enemies)
	if BuffManager:
		BuffManager.apply_potion_effect("inconstant_soul_power", 1.0, 999999.0, power_name)
	var msg: String = "The power of [b]%s[/b] surges through you!" % power_name
	if was_hardcore_switch:
		msg += "\n[color=#FF4444]Your world is now HARDCORE. Death will be permanent.[/color]"

	if AudioManager and AudioManager.has_method("play"):
		AudioManager.play(AudioManager.Sound.BUY)
	var world_pos := Vector2(400, 300)
	if Engine.get_main_loop() and Engine.get_main_loop().get_root():
		var root: Window = Engine.get_main_loop().get_root()
		if root.get_viewport():
			world_pos = root.get_viewport().size / 2.0
	EffectSpawner.spawn_sparkle(world_pos, Color(1.0, 0.8, 0.3))

	return {
		"success": true,
		"message": msg,
		"mode_changed": was_hardcore_switch,
		"power_name": power_name,
	}


## Applies all 6 Soul Fruit buffs to the player.
static func _apply_soul_fruit_buffs(item: ItemData) -> void:
	if not BuffManager:
		return
	var types: Array = item.get_meta("soul_buff_types", SOUL_BUFF_TYPES)
	var strengths: Array = item.get_meta("soul_buff_strengths", SOUL_BUFF_STRENGTHS)
	for i in range(types.size()):
		var bt: String = types[i]
		var bs: float = strengths[i]
		BuffManager.apply_potion_effect(bt, bs, 999999.0, "Soul Fruit")


# ── Helpers ──────────────────────────────────────────────────────────────────

func _format_strength(strength: float, unit: String, mult: float) -> String:
	var val: float = strength * mult
	if unit == "x":
		return "%sx" % snapped(val, 0.1)
	else:
		return "+%s%s" % [snapped(val, 0.1), unit]


func _build_description(power_name: String, desc_line: String, flavor: String) -> String:
	return (
		"[color=#FFD700][b]✦ Inconstant Fruit ✦[/b][/color]"
		+ "\n[color=#BB66FF]Power: [b]%s[/b][/color]" % power_name
		+ "\n[color=#AAFFAA]%s[/color]" % desc_line
		+ "\n[color=#88DD88]\"%s\"[/color]" % flavor
		+ "\n\n[color=#FF8844]━━━━━━━━━━━━━━━━━━[/color]"
		+ "\n[color=#FF4444][b]⚠ WARNING ⚠[/b][/color]"
		+ "\n[color=#FF6666]Consuming this fruit in Survival mode will[/color]"
		+ "\n[color=#FF4444][b]PERMANENTLY switch your world to HARDCORE![/b][/color]"
		+ "\n[color=#FF6666]Death will be permanent — your save will be deleted.[/color]"
		+ "\n[color=#FF8844]━━━━━━━━━━━━━━━━━━[/color]"
	)


func _find_power_def(buff_type: String) -> Dictionary:
	for def in POWER_TYPES:
		if def["buff_type"] == buff_type:
			return def
	return {}
