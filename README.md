# 🌾 Isles of Inconstance

**v0.2.1**

A Stardew Valley and Minecraft inspired farming, survival, and crafting game built in **Godot 4.7**, featuring procedurally generated crops, a fully deterministic seeded world, co-op multiplayer, and a surprising amount of stuff to do.

> Plant something weird. See what it becomes. Bake a pie, eat it, or summon a boss.

---

## ✨ What's in the game

- **🌱 Procedural crop generation** — beyond the standard crops, every playthrough generates unique procedural crops (like *"Azure Melon"* or *"Void Bloom"*) with their own rarity and traits
- **🧬 Crop mutations & genetics** — 10 possible mutations (Crystal, Golden, Prismatic, and more), each with real gameplay effects like light emission or bonus value
- **🌍 Deterministic seeded worlds** — every world is generated from a single seed. The same seed always produces the same island, biomes, and crop pool
- **⚔️ Combat & bosses** — 5 common enemy types plus 4 unique bosses, each with phase changes and a full defeat sequence
- **⛏️ Mining** — procedurally generated underground mines with depth levels, HP-based ore deposits, and depth-gated loot
- **🎣 Fishing** — 9 fish types with a cast-and-reel minigame, plus a rare legendary catch
- **🏘️ Town restoration** — rebuild the ruined town of Tidehaven building-by-building to unlock NPCs, shops, and services
- **🐾 Pets** — 8 companion pets with passive bonuses and their own leveling system
- **🐄 Animal breeding** — Minecraft-style feed-and-breed mechanics for livestock
- **🏗️ Building & interiors** — 24 building types, several with fully furnished dynamic interiors
- **🧪 Alchemy & cooking** — potion brewing and a full meal-cooking system with buffs
- **🌦️ Weather & seasons** — 4 seasons with growth/yield effects, plus dynamic weather (rain, storms, fog)
- **🏝️ Expedition islands** — pay Captain Briggs to visit a randomly generated bonus island (6 possible biomes, from ethereal to volcanic to ice cream land)
- **🤝 Co-op multiplayer** — play with up to 8 players online through public lobbies or join codes
- **🏆 Game completion** — an endgame capstone tracks four pillars (defeat the final boss, restore every building, visit every island biome, and reach level 50) toward finishing the game

---

## 🎮 Controls

| Key | Action |
|---|---|
| `WASD` | Move |
| `1` / `2` | Hoe / Watering Can slots |
| `3`–`0` | Hotbar slots |
| `F` | Use tool |
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
| `Enter` | Open/close chat |
| `Esc` | Close menus |

Four game modes are available: **Peaceful**, **Survival**, **Hardcore**, and **Creative**.

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

## 🤝 Multiplayer

Host or join a co-op game with up to 8 players from the main menu:
 
- **Join code** — host a game and share the generated code with friends
- **Public lobbies** — browse and join open lobbies directly from the lobby browser
- One player hosts and acts as the authority for shared world state (weather, day/night, enemies, town progress, and so on); everyone's individual farm, inventory, and progress stays their own
- Online multiplayer is desktop-only. The web build only supports single-player.

---

## 🛠️ Tech notes

- Built entirely in **GDScript**, no external game frameworks
- World generation uses layered Perlin noise (`FastNoiseLite`) with a seeded island mask
- All randomness for object placement is derived from the world seed, so results are fully reproducible. Useful for debugging and for sharing interesting seeds
- Save data is versioned JSON with automatic migration support for older saves

---

## 📌 Project status

This is an actively developed solo project. Expect some rough edges, ongoing balance tuning, and new systems arriving over time. Known areas being worked on:
- Multiplayer stability and edge-case sync fixes (newest major system, still hardening)
- Progression pacing 
- Additional automated test coverage
- Onboarding/tutorial flow for new players
- More features

Bug reports and suggestions are welcome via [Issues](../../issues).

---

## 📄 License

See [LICENSE](LICENSE) for details.
