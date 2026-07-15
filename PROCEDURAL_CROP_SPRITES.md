# Procedural Crop Sprite System

A layered sprite generator for creating procedural pixel art crops in Godot.

## Overview

This system generates crop sprites by combining multiple layers:
- **Stem** - The base structure of the plant
- **Leaves** - Foliage around the plant
- **Fruit/Body** - The main crop body
- **Flower** - Decorative flower elements
- **Patterns** - Surface patterns on the crop
- **Special Effects** - Glow, sparkle, shadows, outlines

## File Structure

```
scripts/data/
├── PixelArtUtils.gd              # Drawing utilities
├── CropSpriteGenerator.gd        # Main generator class
├── crop_layers/
│   ├── CropLayer.gd              # Base layer class
│   ├── StemLayer.gd              # Stem implementations
│   ├── LeavesLayer.gd            # Leaf implementations
│   ├── FruitBodyLayer.gd         # Fruit/body implementations
│   ├── FlowerLayer.gd            # Flower implementations
│   ├── PatternLayer.gd           # Pattern implementations
│   ├── SpecialEffectsLayer.gd    # Effect implementations
│   └── SpritePieceLibrary.gd     # Reusable sprite pieces
```

## Quick Start

### Basic Usage

```gdscript
var generator := CropSpriteGenerator.new()
generator.set_sprite_size(24)

var library := SpritePieceLibrary

# Add layers
var stem := library.get_stem_pieces()["vine"].duplicate()
generator.add_layer(stem)

var fruit := library.get_fruit_pieces()["large_circle"].duplicate()
fruit.color = Color.RED
generator.add_layer(fruit)

# Generate sprite
var image := generator.generate()
var texture := PixelArtUtils.image_to_texture(image)
```

### Generate Example Crops

Run the test script to generate example sprites:

```gdscript
# Attach test_crop_generator.gd to a node in your scene
# It will generate sprites to the user:// directory
```

## Layer Types

### StemLayer

Available stem types:
- `STRAIGHT` - Simple vertical stem
- `CURVED` - Curved stem with bend
- `VINE` - Wavy vine with tendrils
- `MUSHROOM_STALK` - Tapered mushroom stalk

### LeavesLayer

Available leaf types:
- `SIMPLE` - Basic round leaves
- `POINTED` - Elongated pointed leaves
- `ROUNDED` - Circular leaf clusters
- `FERN` - Fern-like branching leaves
- `VINE_LEAVES` - Small paired leaves for vines

### FruitBodyLayer

Available body types:
- `CIRCLE` - Round fruit
- `OVAL` - Elliptical fruit (adjustable width ratio)
- `DIAMOND` - Diamond-shaped fruit
- `STAR` - Star-shaped fruit
- `MUSHROOM_CAP` - Semicircle mushroom cap
- `BELL` - Bell-shaped fruit

### FlowerLayer

Available flower types:
- `SIMPLE` - Basic petal arrangement
- `DAISY` - Long petals with center
- `TULIP` - Cup-shaped petals
- `ROSE` - Layered petals
- `SPIKES` - Sharp spikes (can be used for thorny fruits)

### PatternLayer

Available pattern types:
- `DOTS` - Regular dot pattern
- `STRIPES` - Diagonal stripes
- `CHECKER` - Checkerboard pattern
- `SPOTS` - Random spots
- `SPIRAL` - Spiral pattern

### SpecialEffectsLayer

Available effect types:
- `GLOW` - Colored glow around sprite
- `SPARKLE` - Random sparkle highlights
- `SHADOW` - Drop shadow
- `OUTLINE` - Dark outline

## Sprite Piece Library

The `SpritePieceLibrary` contains pre-configured sprite pieces:

### Stems
- `thin_straight` - 2px wide straight stem
- `thick_straight` - 4px wide straight stem
- `curved` - Curved stem
- `vine` - Wavy vine with tendrils
- `mushroom_stalk` - Tapered stalk

### Leaves
- `simple_small` - 4 small simple leaves
- `simple_large` - 6 large simple leaves
- `pointed` - 5 pointed leaves
- `rounded` - 4 rounded leaves
- `fern` - 3 fern leaves
- `vine_leaves` - Paired vine leaves

### Fruits
- `small_circle` - 6px circle
- `large_circle` - 10px circle
- `oval_horizontal` - Wide oval
- `oval_vertical` - Tall oval
- `diamond` - Diamond shape
- `star` - Star shape
- `mushroom_cap` - Mushroom cap
- `bell` - Bell shape

### Flowers
- `simple_5petal` - 5-petal flower
- `simple_8petal` - 8-petal flower
- `daisy` - Daisy-style flower
- `tulip` - Tulip-style flower
- `rose` - Rose-style flower
- `spikes` - Spike arrangement

### Patterns
- `dots` - Dot pattern
- `stripes` - Stripe pattern
- `checker` - Checkerboard
- `spots` - Random spots
- `spiral` - Spiral pattern

### Effects
- `glow_blue` - Blue glow
- `glow_gold` - Gold glow
- `sparkle` - Sparkle effect
- `shadow` - Drop shadow
- `outline_dark` - Dark outline

## Examples

### Red Fruit with Spikes and Vines

```gdscript
var crop := CropSpriteGenerator.new()
crop.set_sprite_size(24)

var library := SpritePieceLibrary

var vine_stem := library.get_stem_pieces()["vine"].duplicate()
crop.add_layer(vine_stem)

var vine_leaves := library.get_leaf_pieces()["vine_leaves"].duplicate()
crop.add_layer(vine_leaves)

var red_fruit := library.get_fruit_pieces()["large_circle"].duplicate()
red_fruit.color = Color(0.9, 0.2, 0.2)
crop.add_layer(red_fruit)

var spikes := library.get_flower_pieces()["spikes"].duplicate()
spikes.color = Color(0.7, 0.1, 0.1)
crop.add_layer(spikes)

var outline := library.get_effect_pieces()["outline_dark"].duplicate()
crop.add_layer(outline)

var image := crop.generate()
```

### Glowing Blue Mushroom

```gdscript
var crop := CropSpriteGenerator.new()
crop.set_sprite_size(24)

var library := SpritePieceLibrary

var stalk := library.get_stem_pieces()["mushroom_stalk"].duplicate()
crop.add_layer(stalk)

var cap := library.get_fruit_pieces()["mushroom_cap"].duplicate()
cap.color = Color(0.3, 0.5, 0.9)
crop.add_layer(cap)

var dots := library.get_pattern_pieces()["dots"].duplicate()
dots.pattern_color = Color(0.6, 0.7, 1.0)
crop.add_layer(dots)

var glow := library.get_effect_pieces()["glow_blue"].duplicate()
crop.add_layer(glow)

var image := crop.generate()
```

### Golden Flower Crop

```gdscript
var crop := CropSpriteGenerator.new()
crop.set_sprite_size(24)

var library := SpritePieceLibrary

var thick_stem := library.get_stem_pieces()["thick_straight"].duplicate()
crop.add_layer(thick_stem)

var large_leaves := library.get_leaf_pieces()["simple_large"].duplicate()
crop.add_layer(large_leaves)

var golden_flower := library.get_flower_pieces()["simple_8petal"].duplicate()
golden_flower.color = Color(1.0, 0.8, 0.2)
golden_flower.center_color = Color(1.0, 0.9, 0.4)
crop.add_layer(golden_flower)

var sparkle := library.get_effect_pieces()["sparkle"].duplicate()
crop.add_layer(sparkle)

var gold_glow := library.get_effect_pieces()["glow_gold"].duplicate()
crop.add_layer(gold_glow)

var image := crop.generate()
```

## Advanced Features

### Growth Stages

Generate multiple growth stages for a crop:

```gdscript
var stages := crop.generate_growth_stages(4)
# Returns Array[Texture2D] with 4 growth stages
```

### Random Crop Generation

Generate random crops:

```gdscript
var generator := CropSpriteGenerator.new()
var random_crop := generator.create_random_crop()
var image := random_crop.generate()
```

### Custom Colors

Modify colors of any layer:

```gdscript
var fruit := library.get_fruit_pieces()["large_circle"].duplicate()
fruit.color = Color.from_hsv(0.0, 0.8, 0.9)  # Custom red
```

### Save Sprites

Save generated sprites to disk:

```gdscript
crop.save_sprite(image, "res://assets/sprites/my_crop.png")
```

## Integration with CropData

The system integrates with the existing `CropData` class:

```gdscript
var crop_data := CropData.new()
crop_data.id = "procedural_crop_001"
crop_data.display_name = "Mystic Mushroom"

var generator := CropSpriteGenerator.new()
# ... configure generator ...

crop_data.growth_stage_textures = generator.generate_growth_stages(4)
```

## Extending the System

### Adding New Layer Types

1. Create a new class extending `CropLayer`
2. Implement the `render(image, center_x, center_y)` method
3. Add to the layer composition system

### Adding New Sprite Pieces

Add new pieces to `SpritePieceLibrary.gd`:

```gdscript
static func _create_my_custom_piece() -> StemLayer:
	var stem := StemLayer.new()
	stem.stem_type = StemLayer.StemType.STRAIGHT
	stem.height = 12
	stem.width = 3
	stem.color = Color.PURPLE
	return stem

# Then add to get_stem_pieces():
static func get_stem_pieces() -> Dictionary:
	return {
		# ... existing pieces ...
		"my_custom": _create_my_custom_piece(),
	}
```

## Tips

- Layer order matters: render stems first, then leaves, then fruit/body, then flowers, then patterns, then effects
- Use `duplicate()` when getting pieces from the library to avoid modifying the original
- Adjust `sprite_size` based on your game's tile size
- Combine multiple pattern layers for complex designs
- Use glow effects sparingly as they can be performance-intensive
