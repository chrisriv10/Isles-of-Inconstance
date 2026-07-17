extends Node2D
class_name Crop

## Emitted when this plant mutates mid-growth. `crop` is this node,
## `old_crop_id`/`new_crop_id` are the CropData ids before/after, and
## `mutation_name` is e.g. "Crystal" or "Glowcap". World listens for this to
## keep soil bookkeeping in sync and to surface a notification to the player.
signal mutated(crop: Crop, old_crop_id: String, new_crop_id: String, mutation_name: String)

@onready var sprite: Sprite2D = $Sprite2D

var crop_id: String = ""
var days_grown: int = 0

## This specific plant's genetic profile. Distinct from CropData.genetics
## (the template): each planted seed germinates its own slightly-varied
## copy, and mutation rolls/effects are evaluated against this instance so
## no two plants in the field are guaranteed to behave identically.
var genetics: CropGenetics = null

# Shared across all Crop instances - the mutation library only needs to be
# built once.
static var _mutation_system: MutationSystem = null

var _growth_tween: Tween
var _sway_tween: Tween

func setup(p_crop_id: String, p_days_grown: int = 0, p_genetics: CropGenetics = null) -> void:
	crop_id = p_crop_id
	days_grown = p_days_grown
	if p_genetics != null:
		genetics = p_genetics
	else:
		var crop_data := DataManager.get_crop(crop_id)
		if crop_data and crop_data.genetics:
			var rng := RandomNumberGenerator.new()
			rng.randomize()
			genetics = crop_data.genetics.germinate(rng)
		else:
			genetics = CropGenetics.new()
	_update_visuals()
	_start_idle_sway()

func grow() -> void:
	days_grown += 1
	_play_growth_pop()
	_try_mutate()
	_update_visuals()

func is_mature() -> bool:
	var crop_data := DataManager.get_crop(crop_id)
	if not crop_data:
		return false
	return days_grown >= crop_data.days_to_grow

func harvest() -> void:
	# Called by World when harvesting.
	# Reset days_grown if it regrows, or we just rely on World to queue_free() if not.
	var crop_data := DataManager.get_crop(crop_id)
	if crop_data and crop_data.regrows:
		days_grown = crop_data.regrow_days
		_update_visuals()

## Rolls this plant's mutation chance and, if it hits, transforms the plant
## into a newly-registered mutated crop (e.g. Berry -> Crystal Berry). The
## mutated crop's own genetics/seed become what gets inherited from here on.
func _try_mutate() -> void:
	var crop_data := DataManager.get_crop(crop_id)
	if not crop_data or genetics == null:
		return

	if _mutation_system == null:
		_mutation_system = MutationSystem.new()

	var rng := RandomNumberGenerator.new()
	rng.randomize()

	if not _mutation_system.roll_for_mutation(genetics, rng):
		return

	var mutation := _mutation_system.pick_mutation(crop_data, genetics, rng)
	if mutation == null:
		return

	var new_crop := _mutation_system.create_mutated_crop(crop_data, mutation, genetics, rng)
	var old_id := crop_id
	crop_id = new_crop.id
	genetics = new_crop.genetics
	_play_mutation_effect()
	mutated.emit(self, old_id, crop_id, mutation.mutation_name)

func _update_visuals() -> void:
	var crop_data := DataManager.get_crop(crop_id)
	if crop_data:
		sprite.texture = crop_data.get_texture_for_growth(days_grown)
		sprite.modulate = crop_data.modulate_color
		if genetics:
			sprite.scale = Vector2.ONE * clampf(genetics.size_factor, 0.5, 2.0)

func _play_growth_pop() -> void:
	if _growth_tween and _growth_tween.is_valid():
		_growth_tween.kill()
	
	var base_scale := 1.0
	if genetics:
		base_scale = clampf(genetics.size_factor, 0.5, 2.0)
	
	sprite.scale = Vector2.ONE * base_scale * 0.8
	_growth_tween = create_tween()
	_growth_tween.set_ease(Tween.EASE_OUT)
	_growth_tween.set_trans(Tween.TRANS_BACK)
	_growth_tween.tween_property(sprite, "scale", Vector2.ONE * base_scale, 0.3)

func _play_mutation_effect() -> void:
	var effect_color := Color.GOLD
	if genetics:
		effect_color = genetics.to_color()
	
	EffectSpawner.spawn_sparkle(global_position, effect_color)
	AudioManager.play(AudioManager.Sound.MUTATION)
	
	# Flash the sprite
	var original_modulate := sprite.modulate
	sprite.modulate = Color.WHITE
	var flash_tween := create_tween()
	flash_tween.tween_property(sprite, "modulate", original_modulate, 0.4)

func _start_idle_sway() -> void:
	if _sway_tween and _sway_tween.is_valid():
		_sway_tween.kill()
	
	_sway_tween = create_tween()
	_sway_tween.set_loops(true)
	_sway_tween.set_parallel(false)
	
	var sway_amount := 0.05
	var sway_duration := 2.0 + randf() * 1.0
	
	_sway_tween.tween_property(sprite, "rotation_degrees", sway_amount, sway_duration * 0.5)
	_sway_tween.tween_property(sprite, "rotation_degrees", -sway_amount, sway_duration)
	_sway_tween.tween_property(sprite, "rotation_degrees", 0.0, sway_duration * 0.5)
