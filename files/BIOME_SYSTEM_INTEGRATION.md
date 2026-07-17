# Biome System Integration

New files (drop into `scripts/world/` in the project):

- `BiomeType.gd` — enum of biome types (`PLAINS`, `FOREST`, `SWAMP`, `MOUNTAIN`)
- `ResourceSpawnEntry.gd` — one spawnable resource (tree, berries, mushrooms, crystals, etc.)
- `BiomeDefinition.gd` — one biome's terrain params, resource table, and crop-trait modifiers
- `BiomeLibrary.gd` — static registry of all biomes (Plains, Forest, Swamp, Mountain)
- `BiomeGenerator.gd` — seeded elevation/moisture noise → biome classification
- `ResourceSpawner.gd` — seeded, per-chunk resource placement driven by each biome's table
- `CropTraitGenerator.gd` — biome-flavored `CropData` variants (trait tags, multipliers, unique sprite tint)
- `WorldGenerator.gd` — top-level entry point tying the above together
- `WorldChunk.gd` — plain data container returned by `WorldGenerator.generate_chunk()`

## Everything is seeded

`WorldGenerator.new(world_seed)` derives every sub-seed (elevation noise,
moisture noise, per-chunk resource RNG, per-tile crop RNG) from that single
integer via `hash(str(world_seed) + ":" + tag)`. Same seed in → same biome
layout, same resource placement, same crop trait rolls, every time.

## Basic usage

```gdscript
var world := WorldGenerator.new(world_seed)

# Per chunk (e.g. 32x32 tiles):
var chunk := world.generate_chunk(chunk_x * 32, chunk_y * 32, 32, 32)

for y in range(chunk.size.y):
    for x in range(chunk.size.x):
        var biome_type: BiomeType.Type = chunk.get_biome_type(x, y)
        var height: float = chunk.get_height(x, y)
        # apply ground_tile_id / detail_tile_id from
        # BiomeLibrary.get_biome(biome_type) to your tilemap here

for spawn in chunk.resources:
    var scene := load(spawn.scene_path)
    # instantiate at spawn.tile, keyed by spawn.resource_id
```

## Wiring into your existing world generator

This was written as a standalone module because I could not read your
project's actual world/terrain generation script through my current
tools (GitHub blocks automated folder browsing for this repo, and I don't
have direct repo write access) — so the module doesn't assume a specific
existing class name or tilemap setup.

If your current generator already owns tile placement, the smallest
integration is:

1. In whatever currently seeds your world (probably where `world_seed` is
   first set), construct one `WorldGenerator.new(world_seed)` and keep it
   alive for the session (e.g. as an autoload or a member on your world/
   game-state singleton).
2. Wherever you currently place ground tiles, replace the terrain logic
   with `world_generator.get_biome_at(tile_x, tile_y)` to fetch a
   `BiomeDefinition`, and use its `ground_tile_id` / `detail_tile_id` /
   `get_terrain_height()` output to pick the tile.
3. Wherever you currently scatter decoration/resources, call
   `world_generator.resource_spawner.spawn_resources_for_chunk(...)`
   instead (or use `WorldGenerator.generate_chunk()`, which returns both
   in one pass).
4. Wherever crops are planted, call
   `world_generator.plant_crop(base_crop_data, tile_x, tile_y)` instead of
   using the base `CropData` directly, to get biome-flavored growth/yield
   and a chance at a unique named variant.

If your `CropData` class already has fields for growth time / yield / a
trait list, tell me their exact names and I'll switch `CropTraitGenerator`
from its current `"field" in crop` duck-typing over to those directly. If
you paste (or attach) your actual `WorldGenerator`/`CropData`/`World.gd`
files, I'll rewrite these to match your existing structure exactly instead
of the generic integration above.

## Extending with more biomes later

1. Add a new entry to the `Type` enum in `BiomeType.gd`.
2. Write a `_create_my_biome()` in `BiomeLibrary.gd` and add it to
   `get_all_biomes()`, giving it a non-overlapping (or deliberately
   overlapping — closest-band-center wins ties) `elevation_range` /
   `moisture_range`.
3. Add `ResourceSpawnEntry` instances for whatever it should spawn.
