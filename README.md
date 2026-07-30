# 🌾 Isles of Inconstance

A Stardew Valley and Minecraft inspired farming, survival, and crafting game built in **Godot 4.7**, featuring procedurally generated crops, a fully deterministic seeded world, and a surprising amount of stuff to do once you get past the first few days.

> Plant something weird. See what it becomes. Bake a pie, eat it, or summon a boss. 

---

## ✨ What's in the game

- **🌱 Procedural crop generation** — beyond the standard crops, every playthrough generates unique procedural crops (prefix + root combos like *"Azure Melon"* or *"Void Bloom"*) with their own rarity and traits
- **🧬 Crop mutations & genetics** — 10 possible mutations (Crystal, Golden, Prismatic, and more), each with real gameplay effects like light emission or bonus value
- **🌍 Deterministic seeded worlds** — every world is generated from a single seed. The same seed always produces the same island, biomes, and crop pool
- **⚔️ Combat & bosses** — 5 common enemy types plus 4 unique bosses, each with phase changes and a full defeat sequence
- **⛏️ Mining** — procedurally generated underground mines with 6 depth levels, HP-based ore deposits, and depth-gated loot
- **🎣 Fishing** — 9 fish types with a cast-and-reel minigame, plus a rare legendary catch
- **🏘️ Town restoration** — rebuild the ruined town of Tidehaven building-by-building to unlock NPCs, shops, and services
- **🐾 Pets** — 8 companion pets with passive bonuses and their own leveling system
- **🐄 Animal breeding** — Minecraft-style feed-and-breed mechanics for livestock
- **🏗️ Building & interiors** — 24 building types, several with fully furnished dynamic interiors
- **🧪 Alchemy & cooking** — potion brewing and a full meal-cooking system with buffs
- **🌦️ Weather & seasons** — 4 seasons with growth/yield effects, plus dynamic weather (rain, storms, fog)
- **🏝️ Expedition islands** — pay Captain Briggs to visit a randomly generated bonus island (6 possible biomes, from ethereal to volcanic to ice cream land)

---

## 🎮 Controls

| Key | Action |
|---|---|
| `WASD` | Move |
| `1` / `2` | Hoe / Watering Can slots |
| `3`–`0` | Hotbar slots |
| `Space` / `F` | Use tool |
| `E` | Interact, sit, cast fishing line |
| `I` | Inventory |
| `C` | Crafting |
| `V` | Build mode |
| `M` | Map |
| `O` | Objectives |
| `H` | Encyclopedia |
| `P` | Pets |
| `G` | Farm overview |
| `K` | Cooking |
| `N` | Town overview |
| `L` | Collections |
| `Esc` | Close menus |

Three game modes are available: **Peaceful** (no enemies), **Survival** (night enemies), **Harcore** (Survival with one life), and **Creative** (god mode).

---

## 🚀 Running the game

**Requirements:** [Godot 4.7+](https://godotengine.org/download)

1. Clone the repo:
   ```bash
   git clone https://github.com/chrisriv10/Isles-of-Inconstance.git
   ```
2. Open the project folder in Godot.
3. Run `scenes/Bootstrap.tscn` (or just hit **F5** — it's set as the main scene).

Saves are stored per-slot (5 slots) in Godot's user data folder, so you can run multiple save files without conflicts.

---

## 🛠️ Tech notes

- Built entirely in **GDScript**, no external game frameworks
- World generation uses layered Perlin noise (`FastNoiseLite`) with a seeded island mask
- All randomness for object placement is derived from the world seed, so results are fully reproducible. Useful for debugging and for sharing interesting seeds
- Save data is versioned JSON with automatic migration support for older saves

---

## 📌 Project status

This is an actively developed solo project. Expect some rough edges, ongoing balance tuning, and new systems arriving over time. Known areas being worked on:
- Progression pacing 
- Additional automated test coverage
- Onboarding/tutorial flow for new players
- More features

Bug reports and suggestions are welcome via [Issues](../../issues).

---

## 📄 License

See [LICENSE](LICENSE) for details.
