extends Node

## Demo script to generate example crop sprites

func _ready() -> void:
	generate_example_crops()

func generate_example_crops() -> void:
	print("Generating example crop sprites...")
	
	# Example 1: Red fruit with spikes and vines
	var red_fruit_crop := CropSpriteGenerator.new()
	red_fruit_crop.set_sprite_size(24)
	
	var library := SpritePieceLibrary
	
	# Add vine stem
	var vine_stem := library.get_stem_pieces()["vine"].duplicate()
	red_fruit_crop.add_layer(vine_stem)
	
	# Add vine leaves
	var vine_leaves := library.get_leaf_pieces()["vine_leaves"].duplicate()
	red_fruit_crop.add_layer(vine_leaves)
	
	# Add red fruit body
	var red_fruit := library.get_fruit_pieces()["large_circle"].duplicate()
	red_fruit.color = Color(0.9, 0.2, 0.2)
	red_fruit_crop.add_layer(red_fruit)
	
	# Add spikes (using flower layer with spikes type)
	var spikes := library.get_flower_pieces()["spikes"].duplicate()
	spikes.color = Color(0.7, 0.1, 0.1)
	red_fruit_crop.add_layer(spikes)
	
	# Add outline
	var outline := library.get_effect_pieces()["outline_dark"].duplicate()
	red_fruit_crop.add_layer(outline)
	
	# Generate and save
	var red_fruit_image := red_fruit_crop.generate()
	red_fruit_crop.save_sprite(red_fruit_image, "res://assets/sprites/generated_red_fruit.png")
	print("Generated: red fruit with spikes and vines")
	
	# Example 2: Glowing blue mushroom
	var mushroom_crop := CropSpriteGenerator.new()
	mushroom_crop.set_sprite_size(24)
	
	# Add mushroom stalk
	var stalk := library.get_stem_pieces()["mushroom_stalk"].duplicate()
	mushroom_crop.add_layer(stalk)
	
	# Add mushroom cap (blue)
	var cap := library.get_fruit_pieces()["mushroom_cap"].duplicate()
	cap.color = Color(0.3, 0.5, 0.9)
	mushroom_crop.add_layer(cap)
	
	# Add dots pattern
	var dots := library.get_pattern_pieces()["dots"].duplicate()
	dots.pattern_color = Color(0.6, 0.7, 1.0)
	mushroom_crop.add_layer(dots)
	
	# Add blue glow
	var glow := library.get_effect_pieces()["glow_blue"].duplicate()
	mushroom_crop.add_layer(glow)
	
	# Generate and save
	var mushroom_image := mushroom_crop.generate()
	mushroom_crop.save_sprite(mushroom_image, "res://assets/sprites/generated_blue_mushroom.png")
	print("Generated: glowing blue mushroom")
	
	# Example 3: Golden flower crop
	var flower_crop := CropSpriteGenerator.new()
	flower_crop.set_sprite_size(24)
	
	# Add thick stem
	var thick_stem := library.get_stem_pieces()["thick_straight"].duplicate()
	flower_crop.add_layer(thick_stem)
	
	# Add large leaves
	var large_leaves := library.get_leaf_pieces()["simple_large"].duplicate()
	flower_crop.add_layer(large_leaves)
	
	# Add golden flower
	var golden_flower := library.get_flower_pieces()["simple_8petal"].duplicate()
	golden_flower.color = Color(1.0, 0.8, 0.2)
	golden_flower.center_color = Color(1.0, 0.9, 0.4)
	flower_crop.add_layer(golden_flower)
	
	# Add sparkle effect
	var sparkle := library.get_effect_pieces()["sparkle"].duplicate()
	flower_crop.add_layer(sparkle)
	
	# Add gold glow
	var gold_glow := library.get_effect_pieces()["glow_gold"].duplicate()
	flower_crop.add_layer(gold_glow)
	
	# Generate and save
	var flower_image := flower_crop.generate()
	flower_crop.save_sprite(flower_image, "res://assets/sprites/generated_golden_flower.png")
	print("Generated: golden flower crop")
	
	# Generate growth stages for the golden flower
	print("Generating growth stages for golden flower...")
	var growth_stages := flower_crop.generate_growth_stages(4)
	for i in range(growth_stages.size()):
		var texture := growth_stages[i] as ImageTexture
		var image := texture.get_image()
		flower_crop.save_sprite(image, "res://assets/sprites/generated_golden_flower_stage_" + str(i) + ".png")
	print("Generated 4 growth stages for golden flower")
	
	print("All example crops generated successfully!")
