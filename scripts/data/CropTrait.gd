extends Resource
class_name CropTrait

enum TraitType { PREFIX, ROOT }

@export var type: TraitType = TraitType.PREFIX
@export var name_part: String = ""
@export var rarity_weight: int = 10 # Higher = more common

# Identity / Text
@export var color_trait: String = ""
@export var shape_trait: String = ""
@export var size_trait: String = ""
@export var special_effect: String = ""

# Visuals
@export var modulate_color: Color = Color.WHITE

# Stats Modifiers
@export var days_to_grow_mod: int = 0
@export var yield_amount_mod: int = 0
@export var value_multiplier: float = 1.0

# Booleans (can be overridden)
# -1 means "don't override", 0 means false, 1 means true
@export var requires_water_override: int = -1
@export var regrows_override: int = -1
@export var regrow_days_override: int = -1
