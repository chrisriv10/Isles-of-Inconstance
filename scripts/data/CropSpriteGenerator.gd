extends Node
class_name CropSpriteGenerator

## Procedural crop sprite generator that combines layered components

var sprite_size: int = 24
var layers: Array[CropLayer] = []

func set_sprite_size(size: int) -> void:
	sprite_size = size

func add_layer(layer: CropLayer) -> void:
	layers.append(layer)

func clear_layers() -> void:
	layers.clear()

func generate() -> Image:
	var image := PixelArtUtils.create_empty_image(sprite_size, sprite_size)
	var center_x := sprite_size / 2
	var center_y := sprite_size / 2
	
	# Render each layer in order
	for layer in layers:
		layer.render(image, center_x, center_y)
	
	return image

func generate_texture() -> ImageTexture:
	var image := generate()
	return PixelArtUtils.image_to_texture(image)

func generate_growth_stages(stage_count: int = 4) -> Array[Texture2D]:
	var textures: Array[Texture2D] = []
	
	for stage in range(stage_count):
		var progress := float(stage) / float(max(stage_count - 1, 1))
		var stage_image := _generate_stage(progress)
		textures.append(PixelArtUtils.image_to_texture(stage_image))
	
	return textures

func _generate_stage(progress: float) -> Image:
	var image := PixelArtUtils.create_empty_image(sprite_size, sprite_size)
	var center_x := sprite_size / 2
	var center_y := sprite_size / 2
	
	# Scale layers based on growth progress
	for layer in layers:
		var original_scale := layer.scale
		layer.scale = progress * original_scale
		layer.render(image, center_x, center_y)
		layer.scale = original_scale
	
	return image

func save_sprite(image: Image, file_path: String) -> void:
	image.save_png(file_path)

func create_crop_from_pieces(stem_key: String, leaves_key: String, fruit_key: String, 
		flower_key: String, pattern_key: String, effect_key: String, 
		fruit_color: Color, flower_color: Color) -> CropSpriteGenerator:
	
	var generator := CropSpriteGenerator.new()
	generator.set_sprite_size(sprite_size)
	
	var library := SpritePieceLibrary
	
	# Add stem
	if stem_key != "":
		var stem := library.get_stem_pieces()[stem_key].duplicate()
		generator.add_layer(stem)
	
	# Add leaves
	if leaves_key != "":
		var leaves := library.get_leaf_pieces()[leaves_key].duplicate()
		generator.add_layer(leaves)
	
	# Add fruit/body
	if fruit_key != "":
		var fruit := library.get_fruit_pieces()[fruit_key].duplicate()
		fruit.color = fruit_color
		generator.add_layer(fruit)
	
	# Add flower
	if flower_key != "":
		var flower := library.get_flower_pieces()[flower_key].duplicate()
		flower.color = flower_color
		generator.add_layer(flower)
	
	# Add pattern
	if pattern_key != "":
		var pattern := library.get_pattern_pieces()[pattern_key].duplicate()
		generator.add_layer(pattern)
	
	# Add effect
	if effect_key != "":
		var effect := library.get_effect_pieces()[effect_key].duplicate()
		generator.add_layer(effect)
	
	return generator

func create_random_crop() -> CropSpriteGenerator:
	var generator := CropSpriteGenerator.new()
	generator.set_sprite_size(sprite_size)
	
	var library := SpritePieceLibrary
	var stem_keys := library.get_stem_pieces().keys()
	var leaf_keys := library.get_leaf_pieces().keys()
	var fruit_keys := library.get_fruit_pieces().keys()
	var flower_keys := library.get_flower_pieces().keys()
	var pattern_keys := library.get_pattern_pieces().keys()
	var effect_keys := library.get_effect_pieces().keys()
	
	# Randomly select pieces
	var stem_key := stem_keys.pick_random() if randf() > 0.2 else ""
	var leaf_key := leaf_keys.pick_random() if randf() > 0.3 else ""
	var fruit_key := fruit_keys.pick_random() if randf() > 0.1 else ""
	var flower_key = flower_keys.pick_random() if randf() > 0.5 else ""
	var pattern_key := pattern_keys.pick_random() if randf() > 0.6 else ""
	var effect_key := effect_keys.pick_random() if randf() > 0.7 else ""
	
	# Random colors
	var fruit_color := Color.from_hsv(randf(), 0.7 + randf() * 0.3, 0.8 + randf() * 0.2)
	var flower_color := Color.from_hsv(randf(), 0.6 + randf() * 0.4, 0.8 + randf() * 0.2)
	
	return create_crop_from_pieces(stem_key, leaf_key, fruit_key, flower_key, 
			pattern_key, effect_key, fruit_color, flower_color)
