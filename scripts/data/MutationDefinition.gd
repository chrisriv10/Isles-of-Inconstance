extends Resource
class_name MutationDefinition

## A single possible mutation outcome. Purely data - new mutations can be
## added to MutationSystem's library without touching any mutation logic.

@export var mutation_name: String = ""          # e.g. "Crystal", "Glowcap"
@export var weight: int = 10                    # relative pick chance among eligible mutations
@export var min_rarity_tier: int = 0             # plant's genetics.rarity_tier must be >= this
@export var allowed_roots: Array[String] = []    # empty = can apply to any crop's root word

# Genetic deltas applied on top of the mutating plant's current genetics.
@export var hue_shift: float = 0.0
@export var saturation_target: float = -1.0      # -1 = leave saturation as-is
@export var value_target: float = -1.0           # -1 = leave value as-is
@export var size_multiplier: float = 1.0
@export var growth_speed_multiplier: float = 1.0
@export var sell_value_multiplier: float = 1.0
@export var rarity_tier_bump: int = 1
@export var appearance_tag: String = ""
@export var special_ability: String = ""
@export var description: String = ""

func matches_root(root_word: String) -> bool:
	if allowed_roots.is_empty():
		return true
	return allowed_roots.has(root_word)
