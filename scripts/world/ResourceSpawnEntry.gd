class_name ResourceSpawnEntry
extends Resource

## Describes a single resource node that can spawn within a biome
## (e.g. a tree, a berry bush, a mushroom, a crystal deposit).

## Stable id used to look up scenes/sprites/loot tables elsewhere in the game.
@export var resource_id: String = ""
@export var display_name: String = ""

## Relative spawn weight against other entries registered on the same biome.
## Higher weight = more common.
@export var weight: float = 1.0

## Minimum tile distance enforced between two spawns of this same resource,
## so spawns don't overlap or crowd a single tile.
@export var min_spacing: int = 2

## If true, this resource prefers to spawn in tight clusters (e.g. mushroom
## rings, berry thickets) rather than being scattered uniformly.
@export var clusters: bool = false
@export var cluster_size_range: Vector2i = Vector2i(2, 4)

## Optional path to the scene/texture the game layer should instantiate.
## Left as a string so this resource file has no hard scene dependency.
@export var scene_path: String = ""

## Only resources marked harvestable produce gatherable yield; non-harvestable
## entries (e.g. background flora) are purely decorative.
@export var harvestable: bool = true
