extends Resource
class_name TileTypeData

## Static definition of a ground tile type. Used by WorldGenerator to decide
## what to paint and by World to decide walkability / tillability.

@export var id: String = ""
@export var atlas_coords: Vector2i = Vector2i.ZERO
@export var walkable: bool = true
@export var tillable: bool = false
@export var noise_min: float = -1.0
@export var noise_max: float = 1.0
