# Isles of Inconstance — Farming Prototype

A modular Godot 4.7 (GL Compatibility) prototype for a top-down, pixel-art
farming game with a procedurally generated world.

## Running it

Open the project folder in Godot 4.7+ and press Play. `scenes/Main.tscn` is
already set as the main scene. Godot will auto-generate `.import` files for
the new PNG placeholder art the first time it opens the project.

## Controls

| Action    | Key          |
|-----------|--------------|
| Move      | WASD / Arrows|
| Interact  | E            |
| Till soil | F            |

## Architecture

The project deliberately avoids a single monolithic script. Each system owns
one responsibility and talks to others through signals or small, explicit
method calls:

```
scripts/
  autoload/
    GameManager.gd     — day/time cycle, money, pause state (Autoload)
    DataManager.gd      — registry of items, crops, tile types (Autoload)
  data/
    ItemData.gd         — Resource: static item definition
    CropData.gd         — Resource: static crop definition + growth stages
    TileTypeData.gd      — Resource: static tile definition
  world/
    World.gd            — owns the TileMapLayer, painting, tilling
    WorldGenerator.gd    — pure procedural generation (FastNoiseLite), no scene-tree dependency
    Interactable.gd      — reusable base class for anything the player can interact with
  player/
    Player.gd            — input + movement only
    PlayerInteractor.gd  — detects nearby Interactables, exposes interact_with_nearest()
  camera/
    CameraController.gd  — smoothed follow camera, isolated so zoom/shake can be added later
  ui/
    HUD.gd               — pure presentation, driven entirely by GameManager/PlayerInteractor signals
  Main.gd                — thin entry point that only wires World + Player + HUD together

scenes/
  Main.tscn              — top-level scene (World + Player + HUD instances)
  player/Player.tscn
  world/World.tscn
  ui/HUD.tscn
  objects/Interactable.tscn — placeholder "rock" resource node

assets/sprites/           — placeholder pixel art (16x16), regenerate/replace freely
tilesets/ground_tileset.tres — TileSet resource for grass/dirt/tilled/water tiles
```

### Data-driven content

`DataManager` is the single source of truth for item, crop, and tile
definitions. To add a new crop, tile type, or item, add a registration call
in `DataManager._register_default_*()` (or, as the project grows, load
`.tres` resource files from a `data/` folder instead of hardcoding them —
the rest of the codebase already looks everything up by id, so no other
script needs to change).

### Procedural generation

`WorldGenerator` is a plain `RefCounted` class with no scene-tree
dependency, so it can be reused for a minimap, unit-tested, or swapped for a
different algorithm without touching `World.gd`. It reads the tile catalogue
from `DataManager`, so new biomes/tiles just need new `TileTypeData` entries.

### Interaction system

Any object that should be interactable extends/attaches `Interactable.gd`
and emits `interacted`. `PlayerInteractor.gd` (an `Area2D` child of the
player) tracks what's currently in range and calls `interact()` on the
nearest one when the player presses **E**. The HUD listens to the
interactor's signals to show/hide the prompt — nothing needs to be aware of
the UI directly.

### Suggested next systems

Because each system is isolated, these can be added as new scripts/scenes
without modifying existing ones:

- `InventorySystem.gd` (autoload) — reacts to `Interactable.interacted` and `World` harvest events
- `CropInstance.gd` (extends `Interactable.gd`) — per-tile planted crop with its own growth timer
- `SaveManager.gd` (autoload) — serializes `GameManager` + tile/crop state
- `NPCManager.gd` — spawns and manages NPCs using the same `Interactable` pattern
- Additional `TileTypeData` / `CropData` resources for new biomes and crops
