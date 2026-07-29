extends Node

## Test script for crop sprite generation - run this to generate sprites

func _ready() -> void:
	print("=== Crop Sprite Generator Test ===")
	
	# Create a generator instance
	var generator := CropSpriteGenerator.new()
	generator.set_sprite_size(24)
	
	var library := SpritePieceLibrary
	
	# Test 1: Red fruit with spikes and vines
	print("\n--- Test 1: Red Fruit with Spikes and Vines ---")
	var red_fruit := CropSpriteGenerator.new()
	red_fruit.set_sprite_size(24)
	
	var vine_stem = library.get_stem_pieces()["vine"].duplicate()
	red_fruit.add_layer(vine_stem)
	
	var vine_leaves = library.get_leaf_pieces()["vine_leaves"].duplicate()
	red_fruit.add_layer(vine_leaves)
	
	var red_fruit_body = library.get_fruit_pieces()["large_circle"].duplicate()
	red_fruit_body.color = Color(0.9, 0.2, 0.2)
	red_fruit.add_layer(red_fruit_body)
	
	var spikes = library.get_flower_pieces()["spikes"].duplicate()
	spikes.color = Color(0.7, 0.1, 0.1)
	red_fruit.add_layer(spikes)
	
	var outline = library.get_effect_pieces()["outline_dark"].duplicate()
	red_fruit.add_layer(outline)
	
	var red_fruit_img = red_fruit.generate()
	red_fruit.save_sprite(red_fruit_img, "user://test_red_fruit.png")
	print("Saved: test_red_fruit.png")
	
	# Test 2: Glowing blue mushroom
	print("\n--- Test 2: Glowing Blue Mushroom ---")
	var mushroom := CropSpriteGenerator.new()
	mushroom.set_sprite_size(24)
	
	var stalk = library.get_stem_pieces()["mushroom_stalk"].duplicate()
	mushroom.add_layer(stalk)
	
	var cap = library.get_fruit_pieces()["mushroom_cap"].duplicate()
	cap.color = Color(0.3, 0.5, 0.9)
	mushroom.add_layer(cap)
	
	var dots = library.get_pattern_pieces()["dots"].duplicate()
	dots.pattern_color = Color(0.6, 0.7, 1.0)
	mushroom.add_layer(dots)
	
	var glow = library.get_effect_pieces()["glow_blue"].duplicate()
	mushroom.add_layer(glow)
	
	var mushroom_img = mushroom.generate()
	mushroom.save_sprite(mushroom_img, "user://test_blue_mushroom.png")
	print("Saved: test_blue_mushroom.png")
	
	# Test 3: Golden flower
	print("\n--- Test 3: Golden Flower ---")
	var flower := CropSpriteGenerator.new()
	flower.set_sprite_size(24)
	
	var thick_stem = library.get_stem_pieces()["thick_straight"].duplicate()
	flower.add_layer(thick_stem)
	
	var large_leaves = library.get_leaf_pieces()["simple_large"].duplicate()
	flower.add_layer(large_leaves)
	
	var golden_flower = library.get_flower_pieces()["simple_8petal"].duplicate()
	golden_flower.color = Color(1.0, 0.8, 0.2)
	golden_flower.center_color = Color(1.0, 0.9, 0.4)
	flower.add_layer(golden_flower)
	
	var sparkle = library.get_effect_pieces()["sparkle"].duplicate()
	flower.add_layer(sparkle)
	
	var gold_glow = library.get_effect_pieces()["glow_gold"].duplicate()
	flower.add_layer(gold_glow)
	
	var flower_img = flower.generate()
	flower.save_sprite(flower_img, "user://test_golden_flower.png")
	print("Saved: test_golden_flower.png")
	
	# Test 4: Random crop generation
	print("\n--- Test 4: Random Crop Generation ---")
	for i in range(3):
		var random_crop = generator.create_random_crop()
		var random_img = random_crop.generate()
		random_crop.save_sprite(random_img, "user://test_random_crop_" + str(i) + ".png")
		print("Saved: test_random_crop_" + str(i) + ".png")
	
	# Test 5: Growth stages
	print("\n--- Test 5: Growth Stages ---")
	var growth_stages = flower.generate_growth_stages(4)
	for i in range(growth_stages.size()):
		var texture = growth_stages[i] as ImageTexture
		var stage_img = texture.get_image()
		flower.save_sprite(stage_img, "user://test_growth_stage_" + str(i) + ".png")
		print("Saved: test_growth_stage_" + str(i) + ".png")
	
	print("\n=== All tests completed! ===")
	print("Check user:// directory for generated sprites")
