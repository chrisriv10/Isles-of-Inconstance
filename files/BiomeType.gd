class_name BiomeType
extends RefCounted

## Enumeration of all biome types available in the procedural world.
## To add a new biome: add an entry here, then register a matching
## BiomeDefinition in BiomeLibrary.gd.
enum Type {
	PLAINS,
	FOREST,
	SWAMP,
	MOUNTAIN,
}

static func to_display_name(type: Type) -> String:
	match type:
		Type.PLAINS:
			return "Plains"
		Type.FOREST:
			return "Forest"
		Type.SWAMP:
			return "Swamp"
		Type.MOUNTAIN:
			return "Mountain"
		_:
			return "Unknown"
