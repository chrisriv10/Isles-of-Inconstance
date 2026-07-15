extends Resource
class_name CropData

## Static definition of a growable crop. Each crop has a number of visual
## growth stages and takes a number of in-game days to reach the final stage.

@export var id: String = ""
@export var display_name: String = ""
@export var growth_stage_textures: Array[Texture2D] = []
@export var days_to_grow: int = 4
@export var yield_item_id: String = ""
@export var yield_amount: int = 1
@export var regrows: bool = false
@export var regrow_days: int = 2
@export var requires_water: bool = true
@export var modulate_color: Color = Color.WHITE

# Procedural identity – populated by ProceduralCropGenerator
@export var rarity: String = "Common"
@export var color_trait: String = ""
@export var shape_trait: String = ""
@export var size_trait: String = ""
@export var special_effect: String = ""
@export var seed_item_id: String = ""     # ID of the matching seed item

# Genetics & mutation lineage – populated by ProceduralCropGenerator and,
# for mutated variants, by MutationSystem. `genetics` is the canonical
# profile a fresh seed of this exact crop id will germinate from; see
# CropGenetics.gd and MutationSystem.gd for how mutation/inheritance works.
@export var genetics: CropGenetics = null
@export var base_crop_id: String = ""     # non-mutated crop this line came from, "" if original
@export var mutation_name: String = ""    # name of the mutation that produced this crop, "" if none
@export var mutation_generation: int = 0  # how many mutations deep this line is

func get_stage_count() -> int:
	return growth_stage_textures.size()

func get_texture_for_growth(days_growing: int) -> Texture2D:
	if growth_stage_textures.is_empty():
		return null
	var stage_length: float = float(days_to_grow) / float(growth_stage_textures.size())
	var stage_index: int = clampi(int(float(days_growing) / max(stage_length, 0.01)), 0, growth_stage_textures.size() - 1)
	return growth_stage_textures[stage_index]
