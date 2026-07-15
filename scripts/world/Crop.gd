extends Node2D
class_name Crop

@onready var sprite: Sprite2D = $Sprite2D

var crop_id: String = ""
var days_grown: int = 0

func setup(p_crop_id: String, p_days_grown: int = 0) -> void:
	crop_id = p_crop_id
	days_grown = p_days_grown
	_update_visuals()

func grow() -> void:
	days_grown += 1
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

func _update_visuals() -> void:
	var crop_data := DataManager.get_crop(crop_id)
	if crop_data:
		sprite.texture = crop_data.get_texture_for_growth(days_grown)
		sprite.modulate = crop_data.modulate_color
