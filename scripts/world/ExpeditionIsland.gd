extends Node2D
class_name ExpeditionIsland

## Procedurally generated expedition island — reached by paying Captain Briggs
## at the dock. Each visit generates a fresh island of a random type.
## Types include: Plain, Snowland, Ice Cream Land, Desert, Volcanic, and Ethereal.
## Each island has 3 sub-biomes for visual and gameplay variety.
##
## Plain island uses the main tileset (source 0) via DataManager tile lookups.
## All other island types paint directly from their own dedicated atlas so no
## tiles from the main world's tileset ever leak through.

const TILE_SIZE: int = 16
const ISLAND_W: int = 50
const ISLAND_H: int = 50

const RESOURCE_NODE_SCENE: PackedScene = preload("res://scenes/objects/ResourceNode.tscn")
const TREE_SCENE: PackedScene = preload("res://scenes/objects/Tree.tscn")
const FRUIT_TREE_SCENE: PackedScene = preload("res://scenes/objects/FruitTree.tscn")
const ANIMAL_SCENE: PackedScene = preload("res://scenes/world/Animal.tscn")
const RETURN_BOAT_SCENE: PackedScene = preload("res://scenes/objects/ReturnBoat.tscn")
const ISLAND_STRUCTURE_SCENE: PackedScene = preload("res://scenes/objects/IslandStructure.tscn")

# ── Island Types ──────────────────────────────────────────────────────────
enum IslandType {
	PLAIN,
	SNOWLAND,
	ICE_CREAM_LAND,
	DESERT,
	VOLCANIC,
	ETHEREAL,
}

const ISLAND_NAMES: Dictionary = {
	IslandType.PLAIN: "a familiar grassy island",
	IslandType.SNOWLAND: "a frosty snow-covered island",
	IslandType.ICE_CREAM_LAND: "a sweet candy-filled island",
	IslandType.DESERT: "a scorching desert island",
	IslandType.VOLCANIC: "a fiery volcanic island",
	IslandType.ETHEREAL: "a mystical ethereal island",
}

## Which TileSetAtlasSource index to paint from. 0 = use DataManager lookups
## (Plain island, main tileset). > 0 = paint directly from a dedicated atlas.
var _island_source_id: int = 0

## Which TileSetAtlasSource to use for edge/cliff tiles.
## 0 = main world tileset (sand cliffs). > 0 = island-specific edge atlas.
var _edge_source_id: int = 0

## Noise-band-to-atlas-coords palette for non-Plain islands.
## Each entry: {min_noise, max_noise, coords: [Vector2i, Vector2i, Vector2i]}
## where the 3 coords are for sub-biomes 0, 1, and 2.
## Only used when _island_source_id > 0.
var _ground_palette: Array = []

## Seeds: each trip gets a fresh random seed so the island is different every time.
var _island_seed: int = 0
var _island_obj_counter: int = 0
var _tile_grid: Array = []
var _sub_biome_grid: Array = []  # 0,1,2 per cell
var _generator: WorldGenerator
var _rng: RandomNumberGenerator
var _island_type: int = IslandType.PLAIN

## The return boat node — stored so we can validate it exists.
var _return_boat: Node2D = null


## Mapping of base tile IDs to type-specific ground tiles per sub-biome.
## Each entry: base_id => [sub_biome_0_tile, sub_biome_1_tile, sub_biome_2_tile]
## Only used for Plain island (where _island_source_id == 0).
var _tile_mappings: Dictionary = {}

## Resource node configs per island type
var _resource_configs: Array = []

## Animal types per island type
var _animal_types: Array = []

## Tree configuration per island type
var _tree_config: Dictionary = {}

## Nature object densities per island type
var _nature_config: Dictionary = {}

## Set of cells (Vector2i) where trees have been placed, so nature objects
## and other spawns can avoid spawning on top of them.
var _tree_cells: Array[Vector2i] = []

## Structure configs per island type
var _structure_configs: Array = []


func _island_config(type: int) -> void:
	# Reset per-island atlas state
	_island_source_id = 0
	_edge_source_id = 0
	_ground_palette = []

	match type:
		IslandType.PLAIN:
			# Plain island uses the main tileset (source 0) via DataManager
			_tile_mappings = {
				"grass": ["grass", "forest_floor", "flower_fields_0"],
				"dirt": ["dirt", "dirt", "forest_floor"],
				"trees": ["trees", "trees", "trees"],
				"rocks": ["rocks", "rocks", "rocks"],
				"sand": ["sand", "sand", "sand"],
				"fertile_soil": ["fertile_soil", "dirt", "dirt"],
			}
			_resource_configs = [
				{"item_id": "iron_ore", "prompt": "Mine Iron Ore", "tool": 2, "min": 1, "max": 3, "count": [5, 9]},
				{"item_id": "stone", "prompt": "Mine Stone", "tool": 2, "min": 2, "max": 5, "count": [6, 12]},
				{"item_id": "clay", "prompt": "Dig Clay", "tool": -1, "min": 1, "max": 3, "count": [4, 8]},
			]
			_animal_types = ["chicken", "rabbit", "deer", "goat", "squirrel", "frog"]
			_tree_config = {"count": [15, 25], "fruit_chance": 0.25,
				"sprites": ["res://assets/generated/plain_tree_01.png", "res://assets/generated/plain_tree_02.png", "res://assets/generated/plain_tree_03.png"]}
			_nature_config = {"bush": [14, 22], "flower": [16, 26], "mushroom": [8, 14],
				"bush_sprite": "res://assets/generated/plain_bush_01.png",
				"flower_sprite": "res://assets/generated/plain_flower_01.png",
				"mushroom_sprite": "res://assets/generated/plain_mushroom_01.png",
				"bush_sprite_pool": ["res://assets/generated/plain_bush_01.png", "res://assets/generated/plain_bush_02.png", "res://assets/generated/plain_bush_03.png"],
				"flower_sprite_pool": ["res://assets/generated/plain_flower_01.png", "res://assets/generated/plain_flower_02.png", "res://assets/generated/plain_flower_03.png"],
				"mushroom_sprite_pool": ["res://assets/generated/plain_mushroom_01.png", "res://assets/generated/plain_mushroom_02.png", "res://assets/generated/plain_mushroom_03.png"]}
			_structure_configs = [
				{
					"type": IslandStructure.StructureType.CHEST,
					"sprite": "res://assets/generated/hermit_hut_frame_0.png",
					"footprint": Vector2i(3, 3),
					"count": [1, 1],
					"prompt": "Search the hermit's hut",
					"single_use": true,
					"loot_table": [
						{"item_id": "wooden_planks", "amount": 8, "chance": 1.0},
						{"item_id": "stone", "amount": 6, "chance": 1.0},
						{"item_id": "berry", "amount": 5, "chance": 0.8},
						{"item_id": "carrot_seeds", "amount": 3, "chance": 0.6},
						{"item_id": "torch", "amount": 3, "chance": 0.7},
					]
				},
				{
					"type": IslandStructure.StructureType.BUFF_SHRINE,
					"sprite": "res://assets/generated/stone_circle_frame_0.png",
					"footprint": Vector2i(3, 3),
					"count": [0, 1],
					"prompt": "Activate the stone circle",
					"single_use": true,
					"buff_type": "farming_speed",
					"buff_strength": 1.5,
					"buff_duration": 120.0,  # game-minutes -> "Crops grow 50% faster (2h 0m)"
				},
			]

		IslandType.SNOWLAND:
			_island_source_id = 8  # snowland_terrain_atlas.png — 4 snowy terrain tiles
			_edge_source_id = 10  # snowland_edge_atlas.png — 8 recolored cliff tiles
			_ground_palette = [
				{"min": -0.6, "max": -0.2, "coords": [Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0)]},
				{"min": -0.2, "max": 0.4, "coords": [Vector2i(1, 0), Vector2i(1, 0), Vector2i(2, 0)]},
				{"min": 0.4, "max": 0.8, "coords": [Vector2i(2, 0), Vector2i(2, 0), Vector2i(3, 0)]},
				{"min": 0.8, "max": 1.0, "coords": [Vector2i(3, 0), Vector2i(3, 0), Vector2i(3, 0)]},
			]
			_resource_configs = [
				{"item_id": "ice_crystal", "prompt": "Harvest Ice Crystal", "tool": -1, "min": 1, "max": 3, "count": [5, 10]},
				{"item_id": "diamond_ore", "prompt": "Mine Diamond", "tool": 2, "min": 1, "max": 2, "count": [3, 6]},
				{"item_id": "coal", "prompt": "Mine Coal", "tool": 2, "min": 2, "max": 4, "count": [6, 11]},
			]
			_animal_types = ["snow_fox", "polar_bear", "snow_owl"]
			_tree_config = {"count": [12, 20], "fruit_chance": 0.0,
				"sprites": ["res://assets/generated/snowland_tree_01_frame_0.png", "res://assets/generated/snowland_tree_02_frame_0.png", "res://assets/generated/snowland_tree_03_frame_0.png"]}
			_nature_config = {"bush": [10, 18], "flower": [12, 22], "mushroom": [6, 12],
				"bush_sprite": "res://assets/generated/snowland_bush_01.png",
				"flower_sprite": "res://assets/generated/snowland_flower_01.png",
				"mushroom_sprite": "res://assets/generated/snowland_mushroom_01.png"}
			_structure_configs = [
				{
					"type": IslandStructure.StructureType.FROZEN_CHEST,
					"sprite": "res://assets/generated/frozen_cabin_frame_0.png",
					"footprint": Vector2i(3, 3),
					"count": [1, 1],
					"prompt": "Enter the frozen cabin",
					"single_use": true,
					"loot_table": [
						{"item_id": "diamond_ore", "amount": 3, "chance": 1.0},
						{"item_id": "ice_crystal", "amount": 8, "chance": 1.0},
						{"item_id": "coal", "amount": 10, "chance": 0.8},
						{"item_id": "polar_bear_hide", "amount": 1, "chance": 0.5},
					]
				},
				{
					"type": IslandStructure.StructureType.BUFF_SHRINE,
					"sprite": "res://assets/generated/glacial_shrine_frame_0.png",
					"footprint": Vector2i(2, 2),
					"count": [0, 1],
					"prompt": "Channel the glacial shrine",
					"single_use": true,
					"buff_type": "cold_resistance",
					"buff_strength": 0.5,
					"buff_duration": 180.0,  # game-minutes -> "+50% Cold Defense (3h 0m)"
				},
			]

		IslandType.ICE_CREAM_LAND:
			_island_source_id = 3  # ice_cream_atlas.png — 4 tiles
			_edge_source_id = 11  # ice_cream_edge_atlas.png — 8 recolored cliff tiles
			_ground_palette = [
				{"min": -0.6, "max": -0.2, "coords": [Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0)]},
				{"min": -0.2, "max": 0.4, "coords": [Vector2i(1, 0), Vector2i(1, 0), Vector2i(2, 0)]},
				{"min": 0.4, "max": 0.8, "coords": [Vector2i(2, 0), Vector2i(2, 0), Vector2i(3, 0)]},
				{"min": 0.8, "max": 1.0, "coords": [Vector2i(3, 0), Vector2i(3, 0), Vector2i(3, 0)]},
			]
			_resource_configs = [
				{"item_id": "sugar_crystal", "prompt": "Harvest Sugar", "tool": -1, "min": 1, "max": 4, "count": [6, 12]},
				{"item_id": "gumdrop", "prompt": "Pick Gumdrop", "tool": -1, "min": 1, "max": 3, "count": [5, 10]},
				{"item_id": "chocolate_chunk", "prompt": "Mine Chocolate", "tool": -1, "min": 1, "max": 2, "count": [4, 8]},
			]
			_animal_types = ["gummy_bear", "marshmallow_puff", "licorice_worm", "ice_cream_sandwich_man", "gingerbread_man"]
			_tree_config = {"count": [12, 20], "fruit_chance": 0.0,
				"sprites": ["res://assets/generated/icecream_tree_01_frame_0.png", "res://assets/generated/icecream_tree_02_frame_0.png", "res://assets/generated/icecream_tree_03_frame_0.png"]}
			_nature_config = {"bush": [12, 20], "flower": [14, 24], "mushroom": [6, 12],
				"bush_sprite": "res://assets/generated/icecream_bush_01.png",
				"flower_sprite": "res://assets/generated/icecream_flower_01.png",
				"mushroom_sprite": "res://assets/generated/icecream_mushroom_01.png"}
			_structure_configs = [
				{
					"type": IslandStructure.StructureType.OVEN,
					"sprite": "res://assets/generated/gingerbread_house_frame_0.png",
					"footprint": Vector2i(3, 3),
					"count": [1, 1],
					"prompt": "Bake in the gingerbread oven",
					"single_use": false,
				},
				{
					"type": IslandStructure.StructureType.BUFF_SHRINE,
					"sprite": "res://assets/generated/candy_altar_frame_0.png",
					"footprint": Vector2i(2, 2),
					"count": [0, 1],
					"prompt": "Taste the candy altar",
					"single_use": true,
					"buff_type": "movement_speed",
					"buff_strength": 0.5,
					"buff_duration": 90.0,  # game-minutes -> "+50% Movement Speed (1h 30m)"
				},
			]

		IslandType.DESERT:
			_island_source_id = 4  # desert_atlas.png — 4 tiles
			_ground_palette = [
				{"min": -0.6, "max": -0.2, "coords": [Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0)]},
				{"min": -0.2, "max": 0.4, "coords": [Vector2i(1, 0), Vector2i(1, 0), Vector2i(2, 0)]},
				{"min": 0.4, "max": 0.8, "coords": [Vector2i(2, 0), Vector2i(2, 0), Vector2i(3, 0)]},
				{"min": 0.8, "max": 1.0, "coords": [Vector2i(3, 0), Vector2i(3, 0), Vector2i(3, 0)]},
			]
			_resource_configs = [
				{"item_id": "gold_ore", "prompt": "Mine Gold", "tool": 2, "min": 1, "max": 2, "count": [4, 8]},
				{"item_id": "silver_ore", "prompt": "Mine Silver", "tool": 2, "min": 1, "max": 3, "count": [4, 7]},
				{"item_id": "cactus_fruit", "prompt": "Pick Cactus Fruit", "tool": -1, "min": 1, "max": 3, "count": [5, 10]},
			]
			_animal_types = ["sand_lizard", "desert_scorpion", "meerkat"]
			_tree_config = {"count": [8, 14], "fruit_chance": 0.0,
				"sprites": ["res://assets/generated/desert_tree_01_frame_0.png", "res://assets/generated/desert_tree_02_frame_0.png", "res://assets/generated/desert_tree_03_frame_0.png"]}
			_nature_config = {"bush": [8, 16], "flower": [8, 15], "mushroom": [3, 8],
				"bush_sprite": "res://assets/generated/desert_bush_01.png",
				"flower_sprite": "res://assets/generated/desert_flower_01.png",
				"mushroom_sprite": "res://assets/generated/desert_mushroom_01.png"}
			_structure_configs = [
				{
					"type": IslandStructure.StructureType.PYRAMID_TRAP,
					"sprite": "res://assets/generated/pyramid_frame_0.png",
					"footprint": Vector2i(3, 3),
					"count": [1, 1],
					"prompt": "Enter the ancient pyramid",
					"single_use": true,
					"tribute_item": "gold_ore",
					"loot_table": [
						{"item_id": "gold_ore", "amount": 5, "chance": 1.0},
						{"item_id": "silver_ore", "amount": 4, "chance": 0.8},
						{"item_id": "ruby_ore", "amount": 1, "chance": 0.4},
						{"item_id": "cactus_fruit", "amount": 3, "chance": 0.6},
					]
				},
				{
					"type": IslandStructure.StructureType.MERCHANT,
					"sprite": "res://assets/generated/oasis_tent_frame_0.png",
					"footprint": Vector2i(3, 3),
					"count": [0, 1],
					"prompt": "Browse the nomad's wares",
					"single_use": false,
					"shop_title": "Desert Nomad Trader",
					"shop_items": [
						{"item_id": "cactus_fruit", "price": 15, "stock": 5},
						{"item_id": "gold_ore", "price": 80, "stock": 3},
						{"item_id": "silver_ore", "price": 60, "stock": 3},
						{"item_id": "rope", "price": 25, "stock": 4},
					]
				},
			]

		IslandType.VOLCANIC:
			_island_source_id = 15  # volcanic_atlas_v2_2.png — 4 tiles (v2 improved)
			_edge_source_id = 12  # volcanic_edge_atlas.png — 8 recolored cliff tiles
			_ground_palette = [
				{"min": -0.6, "max": -0.2, "coords": [Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0)]},
				{"min": -0.2, "max": 0.4, "coords": [Vector2i(1, 0), Vector2i(1, 0), Vector2i(2, 0)]},
				{"min": 0.4, "max": 0.8, "coords": [Vector2i(2, 0), Vector2i(2, 0), Vector2i(3, 0)]},
				{"min": 0.8, "max": 1.0, "coords": [Vector2i(3, 0), Vector2i(3, 0), Vector2i(3, 0)]},
			]
			_resource_configs = [
				{"item_id": "sulfur_crystal", "prompt": "Gather Sulfur", "tool": -1, "min": 1, "max": 3, "count": [5, 10]},
				{"item_id": "obsidian_ore", "prompt": "Mine Obsidian", "tool": 2, "min": 1, "max": 2, "count": [4, 7]},
				{"item_id": "ruby_ore", "prompt": "Mine Ruby", "tool": 2, "min": 1, "max": 2, "count": [3, 6]},
				{"item_id": "ember_dust", "prompt": "Scoop Ember Dust", "tool": -1, "min": 1, "max": 2, "count": [4, 8]},
			]
			_animal_types = ["ember_crawler", "ash_moth", "magma_slug"]
			_tree_config = {"count": [6, 12], "fruit_chance": 0.0,
				"sprites": ["res://assets/generated/volcanic_tree_01_frame_0.png", "res://assets/generated/volcanic_tree_02_frame_0.png", "res://assets/generated/volcanic_tree_03_frame_0.png"]}
			_nature_config = {"bush": [6, 12], "flower": [5, 10], "mushroom": [3, 8],
				"bush_sprite": "res://assets/generated/volcanic_bush_01.png",
				"flower_sprite": "res://assets/generated/volcanic_flower_01.png",
				"mushroom_sprite": "res://assets/generated/volcanic_mushroom_01.png"}
			_structure_configs = [
				{
					"type": IslandStructure.StructureType.FORGE,
					"sprite": "res://assets/generated/obsidian_forge_frame_0.png",
					"footprint": Vector2i(3, 2),
					"count": [1, 1],
					"prompt": "Use the obsidian forge",
					"single_use": false,
				},
				{
					"type": IslandStructure.StructureType.BUFF_SHRINE,
					"sprite": "res://assets/generated/fire_shrine_frame_0.png",
					"footprint": Vector2i(2, 2),
					"count": [0, 1],
					"prompt": "Pledge to the fire shrine",
					"single_use": true,
					"buff_type": "fire_resistance",
					"buff_strength": 0.5,
					"buff_duration": 120.0,  # game-minutes -> "+50% Fire Defense (2h 0m)"
				},
			]

		IslandType.ETHEREAL:
			_island_source_id = 9  # ethereal_terrain_atlas.png — 4 grass/stone tiles
			_edge_source_id = 13  # ethereal_edge_atlas.png — 8 recolored cliff tiles
			_ground_palette = [
				{"min": -0.6, "max": -0.2, "coords": [Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0)]},
				{"min": -0.2, "max": 0.4, "coords": [Vector2i(1, 0), Vector2i(1, 0), Vector2i(2, 0)]},
				{"min": 0.4, "max": 0.8, "coords": [Vector2i(2, 0), Vector2i(2, 0), Vector2i(3, 0)]},
				{"min": 0.8, "max": 1.0, "coords": [Vector2i(3, 0), Vector2i(3, 0), Vector2i(3, 0)]},
			]
			_resource_configs = [
				{"item_id": "moon_shard", "prompt": "Collect Moon Shard", "tool": -1, "min": 1, "max": 3, "count": [5, 10]},
				{"item_id": "starlight_dust", "prompt": "Gather Starlight", "tool": -1, "min": 1, "max": 2, "count": [5, 9]},
				{"item_id": "gold_ore", "prompt": "Mine Gold", "tool": 2, "min": 1, "max": 3, "count": [4, 7]},
			]
			_animal_types = ["spirit_fox", "glow_jelly", "lunar_moth"]
			_tree_config = {"count": [10, 18], "fruit_chance": 0.0,
				"sprites": ["res://assets/generated/ethereal_tree_01_frame_0.png", "res://assets/generated/ethereal_tree_02_frame_0.png", "res://assets/generated/ethereal_tree_03_frame_0.png"]}
			_nature_config = {"bush": [10, 18], "flower": [12, 20], "mushroom": [5, 10],
				"bush_sprite": "res://assets/generated/ethereal_bush_01.png",
				"flower_sprite": "res://assets/generated/ethereal_flower_01.png",
				"mushroom_sprite": "res://assets/generated/ethereal_mushroom_01.png"}
			_structure_configs = [
				{
					"type": IslandStructure.StructureType.REVEAL_MAP,
					"sprite": "res://assets/generated/crystal_spire_frame_0.png",
					"footprint": Vector2i(2, 3),
					"count": [1, 1],
					"prompt": "Touch the crystal spire",
					"single_use": true,
				},
				{
					"type": IslandStructure.StructureType.HEAL_POOL,
					"sprite": "res://assets/generated/starlight_pool_frame_0.png",
					"footprint": Vector2i(3, 3),
					"count": [0, 1],
					"prompt": "Bathe in the starlight pool",
					"single_use": true,
				},
			]


# ── Public API ────────────────────────────────────────────────────────────

## Initialise and generate a brand new island with a random type and seed.
func generate_fresh() -> void:
	_island_seed = randi()
	_island_type = randi() % IslandType.size()
	_generate()

## Generate with a specific type.
func generate_with_type(type_val: int) -> void:
	_island_type = type_val
	_island_seed = randi()
	_generate()

## Generate with a specific seed and type (debug/creative).
func generate_with_seed(seed_val: int, type_val: int = IslandType.PLAIN) -> void:
	_island_seed = seed_val
	_island_type = type_val
	_generate()

## Get the human-readable name of the island type.
func get_island_name() -> String:
	return ISLAND_NAMES.get(_island_type, "a mysterious island")

## Get the island type enum value.
func get_island_type() -> int:
	return _island_type

## Get a clean display name for the island type (e.g. "Snowland", "Plain").
func get_island_type_name() -> String:
	match _island_type:
		IslandType.PLAIN:
			return "Plain"
		IslandType.SNOWLAND:
			return "Snowland"
		IslandType.ICE_CREAM_LAND:
			return "Ice Cream Land"
		IslandType.DESERT:
			return "Desert"
		IslandType.VOLCANIC:
			return "Volcanic"
		IslandType.ETHEREAL:
			return "Ethereal"
	return "Expedition"

## Get the color for a given cell on this island, used by the WorldMap
## to render an expedition-island view instead of the main world map.
## Returns distinct colors per sub-biome (0, 1, or 2) so the map shows
## the same regions visible in the game world.
## Returns transparent for out-of-bounds, water-blue for water, and a
## darkened variant of the sub-biome color for cliff edge tiles.
func get_island_cell_color(cell_x: int, cell_y: int) -> Color:
	if cell_x < 0 or cell_x >= ISLAND_W or cell_y < 0 or cell_y >= ISLAND_H:
		return Color(0.0, 0.0, 0.0, 0.0)  # transparent / off-island

	var tile_id: String = ""
	if cell_y < _tile_grid.size() and cell_x < _tile_grid[cell_y].size():
		tile_id = _tile_grid[cell_y][cell_x]

	# Water
	if tile_id == "water" or tile_id.is_empty():
		return Color(0.2, 0.3, 0.6)  # same as WATER_COLOR in WorldMap

	# Look up which sub-biome this cell belongs to (0, 1, or 2)
	var sub_biome: int = 0
	if cell_y < _sub_biome_grid.size() and cell_x < _sub_biome_grid[cell_y].size():
		sub_biome = _sub_biome_grid[cell_y][cell_x]

	var land_color: Color = _get_sub_biome_color(_island_type, sub_biome)

	# Edge tiles: darken to differentiate from walkable land
	if tile_id.begins_with("edge"):
		return land_color.darkened(0.25)

	return land_color


## Returns a map color for the given island type and sub-biome index.
## Sub-biomes match those documented in EncyclopediaUI and defined in
## _island_config()'s _ground_palette / _tile_mappings entries.
func _get_sub_biome_color(island_type: int, sub_biome: int) -> Color:
	match island_type:
		IslandType.SNOWLAND:
			match sub_biome:
				0: return Color(0.75, 0.80, 0.88)  # Snowy Forest
				1: return Color(0.55, 0.70, 0.85)  # Frozen Lake
				2: return Color(0.88, 0.90, 0.95)  # Glacial Peak
		IslandType.ICE_CREAM_LAND:
			match sub_biome:
				0: return Color(0.95, 0.75, 0.85)  # Strawberry Swirl
				1: return Color(0.98, 0.92, 0.75)  # Vanilla Frosting
				2: return Color(0.65, 0.45, 0.30)  # Chocolate Sprinkles
		IslandType.DESERT:
			match sub_biome:
				0: return Color(0.80, 0.70, 0.40)  # Sand Dunes
				1: return Color(0.60, 0.45, 0.25)  # Rocky Badlands
				2: return Color(0.50, 0.75, 0.50)  # Oasis Pool
		IslandType.VOLCANIC:
			match sub_biome:
				0: return Color(0.50, 0.30, 0.25)  # Lava Fields
				1: return Color(0.35, 0.30, 0.28)  # Ash Plains
				2: return Color(0.22, 0.18, 0.22)  # Obsidian Cliffs
		IslandType.ETHEREAL:
			match sub_biome:
				0: return Color(0.60, 0.40, 0.75)  # Crystal Grove
				1: return Color(0.45, 0.35, 0.70)  # Starfall Meadow
				2: return Color(0.35, 0.55, 0.60)  # Misty Fen
		_:  # Plain island and fallback
			match sub_biome:
				0: return Color(0.45, 0.72, 0.32)  # Grassy Meadow
				1: return Color(0.22, 0.50, 0.22)  # Forest Grove
				2: return Color(0.62, 0.82, 0.32)  # Flower Field
	return Color(0.45, 0.72, 0.34)


func _generate() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = _island_seed

	add_to_group("expedition_island")
	_clear()
	_island_config(_island_type)

	# ── Step 1: Generate terrain ────────────────────────────────
	_generator = WorldGenerator.create(ISLAND_W, ISLAND_H, _island_seed)
	_generator.noise.frequency = 0.10
	_tile_grid = _generator.generate_tile_grid()

	# ── Step 2: Generate sub-biome grid ─────────────────────────
	_generate_sub_biomes()

	# ── Step 3: Paint ground on the TileMapLayer ────────────────
	_paint_ground()

	# ── Step 4: Add beach/edge tiles ──────────────────────────
	_add_beach_and_edges()

	# ── Step 5: Scatter island content ─────────────────────────
	_scatter_trees()
	_scatter_resource_nodes()
	_scatter_nature_objects()
	_scatter_structures()
	_scatter_animals()

	# ── Step 6: Place the return boat ─────────────────────────
	_place_return_boat()


func _generate_sub_biomes() -> void:
	var sub_noise := FastNoiseLite.new()
	sub_noise.seed = _island_seed + 7777
	sub_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	# Frequency of ~0.025 means a full noise cycle is ~40 tiles wide, giving
	# roughly 1.25 cycles across the 50-tile island. This produces larger,
	# more sweeping contiguous biome regions so each sub-biome forms one or
	# two sizeable patches rather than many small speckled regions.
	sub_noise.frequency = 0.025

	_sub_biome_grid = []
	_sub_biome_grid.resize(ISLAND_H)
	for y in range(ISLAND_H):
		var row: Array = []
		row.resize(ISLAND_W)
		for x in range(ISLAND_W):
			var n: float = sub_noise.get_noise_2d(x, y)
			# Tightened thresholds (±0.15 instead of ±0.33) ensure all three
			# sub-biomes get fair representation. Standard Perlin noise has
			# ~68% of values within ±0.25 of the mean; ±0.15 means each outer
			# band claims roughly 27% and the middle band ~46% of island area —
			# far more balanced than before when the middle band dominated.
			if n < -0.15:
				row[x] = 0
			elif n < 0.15:
				row[x] = 1
			else:
				row[x] = 2
		_sub_biome_grid[y] = row


func _paint_ground() -> void:
	var ground_layer: TileMapLayer = $GroundLayer
	if not ground_layer:
		return

	if _island_source_id == 0:
		# ── Plain island: use the existing DataManager tile-lookup path ──
		for y in range(ISLAND_H):
			for x in range(ISLAND_W):
				var cell := Vector2i(x, y)
				var tile_id: String = _tile_grid[y][x]
				var sub_biome: int = _sub_biome_grid[y][x] if y < _sub_biome_grid.size() and x < _sub_biome_grid[y].size() else 0

				var mapped_id: String = _map_tile(tile_id, sub_biome)
				var tile_type: TileTypeData = DataManager.get_tile_type(mapped_id)
				if tile_type:
					ground_layer.set_cell(cell, tile_type.source_id, tile_type.atlas_coords)

				_tile_grid[y][x] = mapped_id
	else:
		# ── Non-Plain island: paint directly from the dedicated atlas ──
		for y in range(ISLAND_H):
			for x in range(ISLAND_W):
				var cell := Vector2i(x, y)
				var tile_id: String = _tile_grid[y][x]

				# Skip water — handled by _add_beach_and_edges
				if tile_id == "water":
					continue

				var sub_biome: int = _sub_biome_grid[y][x] if y < _sub_biome_grid.size() and x < _sub_biome_grid[y].size() else 0

				# Sample the same noise WorldGenerator used for tile picking
				var n: float = _generator.noise.get_noise_2d(x, y)

				var coords: Vector2i = _pick_atlas_coords(n, sub_biome)
				ground_layer.set_cell(cell, _island_source_id, coords)

				# Keep _tile_grid with original WorldGenerator IDs for walkability
				# (grass, dirt, trees, rocks, sand, fertile_soil are all registered
				# in DataManager with proper walkability flags)


func _pick_atlas_coords(noise_value: float, sub_biome: int) -> Vector2i:
	for band in _ground_palette:
		var b: Dictionary = band as Dictionary
		if noise_value >= b["min"] and noise_value < b["max"]:
			var variants: Array = b["coords"] as Array
			var idx := clampi(sub_biome, 0, variants.size() - 1)
			return variants[idx] as Vector2i
	# Fallback: last band's last variant
	var last: Dictionary = _ground_palette.back() as Dictionary
	var last_variants: Array = last["coords"] as Array
	return last_variants.back() as Vector2i


func _map_tile(tile_id: String, sub_biome: int) -> String:
	if tile_id in _tile_mappings:
		var variants: Array = _tile_mappings[tile_id]
		var idx := clampi(sub_biome, 0, variants.size() - 1)
		return variants[idx] as String
	return tile_id


func _clear() -> void:
	var ground_layer: TileMapLayer = $GroundLayer
	if ground_layer:
		ground_layer.clear()
	for child in $Objects.get_children():
		child.queue_free()
	_return_boat = null
	_tile_grid.clear()
	_sub_biome_grid.clear()
	_structure_configs.clear()
	_tree_cells.clear()


func _add_beach_and_edges() -> void:
	var ground_layer: TileMapLayer = $GroundLayer
	if not ground_layer:
		return

	for y in range(ISLAND_H):
		for x in range(ISLAND_W):
			var cell := Vector2i(x, y)
			var tile_id: String = _tile_grid[y][x]

			# ── Edge tiles: water-adjacent-to-land → cliff drop-off ──
			if tile_id == "water" and _has_land_neighbor(cell):
				var edge_id: String = _get_edge_direction(cell)
				if edge_id != "":
					_tile_grid[y][x] = edge_id
					if _edge_source_id > 0:
						# Island-specific edge atlas: use matching themed cliff tiles
						var edge_coords_map: Dictionary = {
							"edge_n": Vector2i(0, 0),
							"edge_s": Vector2i(1, 0),
							"edge_w": Vector2i(2, 0),
							"edge_e": Vector2i(3, 0),
							"edge_nw": Vector2i(4, 0),
							"edge_ne": Vector2i(5, 0),
							"edge_sw": Vector2i(6, 0),
							"edge_se": Vector2i(7, 0),
						}
						var coords: Vector2i = edge_coords_map.get(edge_id, Vector2i(0, 0))
						ground_layer.set_cell(cell, _edge_source_id, coords)
					else:
						# Plain/Desert: use source 0 (main tileset) edge tiles
						var edge_type: TileTypeData = DataManager.get_tile_type(edge_id)
						if edge_type:
							ground_layer.set_cell(cell, edge_type.source_id, edge_type.atlas_coords)

			# ── Beach tiles: land-adjacent-to-water → shore/beach ──
			elif tile_id != "water" and _has_water_neighbor(cell):
				if _island_source_id == 0:
					# Plain island: use DataManager path
					var sub_biome: int = _sub_biome_grid[y][x] if y < _sub_biome_grid.size() and x < _sub_biome_grid[y].size() else 0
					var mapped_sand: String = _map_tile("sand", sub_biome)
					_tile_grid[y][x] = mapped_sand
					var sand_type: TileTypeData = DataManager.get_tile_type(mapped_sand)
					if sand_type:
						ground_layer.set_cell(cell, sand_type.source_id, sand_type.atlas_coords)
				else:
					# Non-Plain island: paint beach tile (0,0) from the dedicated atlas
					_tile_grid[y][x] = "sand"
					ground_layer.set_cell(cell, _island_source_id, Vector2i(0, 0))

	# ── Water tiles: remaining water cells → animated water from main tileset ──
	# After edge and beach processing, paint any leftover "water" cells with
	# the standard water tile (source 0, atlas (3,0)). This covers water cells
	# not adjacent to land that would otherwise be left blank.
	for y in range(ISLAND_H):
		for x in range(ISLAND_W):
			var cell := Vector2i(x, y)
			var tile_id: String = _tile_grid[y][x]
			if tile_id == "water":
				ground_layer.set_cell(cell, 0, Vector2i(3, 0))


func _has_land_neighbor(cell: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var nc := Vector2i(cell.x + dx, cell.y + dy)
			if _is_land_cell(nc):
				return true
	return false


func _has_water_neighbor(cell: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var nc := Vector2i(cell.x + dx, cell.y + dy)
			if nc.x < 0 or nc.x >= ISLAND_W or nc.y < 0 or nc.y >= ISLAND_H:
				return true
			var nid: String = _tile_grid[nc.y][nc.x] if nc.y < _tile_grid.size() and nc.x < _tile_grid[nc.y].size() else ""
			if nid == "water" or nid.is_empty() or nid.begins_with("edge"):
				return true
	return false


func _is_land_cell(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.x >= ISLAND_W or cell.y < 0 or cell.y >= ISLAND_H:
		return false
	var tid: String = _tile_grid[cell.y][cell.x]
	return tid != "water" and not tid.is_empty()


func _get_edge_direction(cell: Vector2i) -> String:
	var north: bool = _is_neighbor_land(cell, 0, -1)
	var south: bool = _is_neighbor_land(cell, 0, 1)
	var west: bool = _is_neighbor_land(cell, -1, 0)
	var east: bool = _is_neighbor_land(cell, 1, 0)

	if south and not west and not east and not north:
		return "edge_n"
	if north and not west and not east and not south:
		return "edge_s"
	if east and not north and not south and not west:
		return "edge_w"
	if west and not north and not south and not east:
		return "edge_e"
	if south and east and not west and not north:
		return "edge_nw"
	if south and west and not east and not north:
		return "edge_ne"
	if north and east and not west and not south:
		return "edge_sw"
	if north and west and not east and not south:
		return "edge_se"
	if north:
		return "edge_s"
	if south:
		return "edge_n"
	if west:
		return "edge_e"
	if east:
		return "edge_w"
	return ""


func _is_neighbor_land(cell: Vector2i, dx: int, dy: int) -> bool:
	var nc := Vector2i(cell.x + dx, cell.y + dy)
	if nc.x < 0 or nc.x >= ISLAND_W or nc.y < 0 or nc.y >= ISLAND_H:
		return false
	var nid: String = _tile_grid[nc.y][nc.x]
	if nid == "water" or nid.begins_with("edge"):
		return false
	return true


func _pick_walkable_cell() -> Vector2i:
	for _attempt in range(200):
		var x := _rng.randi_range(1, ISLAND_W - 2)
		var y := _rng.randi_range(1, ISLAND_H - 2)
		var cell := Vector2i(x, y)
		var tid: String = _tile_grid[y][x]
		if tid != "water" and not tid.is_empty():
			# On non-Plain islands, _tile_grid stores original WorldGenerator IDs
			# (grass, dirt, trees, rocks, sand, fertile_soil) which are all
			# registered in DataManager with proper walkability flags.
			var tile_type: TileTypeData = DataManager.get_tile_type(tid)
			if tile_type and tile_type.walkable:
				return cell
	return Vector2i(ISLAND_W / 2, ISLAND_H / 2)


func _pick_nature_cell() -> Vector2i:
	## Like _pick_walkable_cell but also avoids tree cells and other
	## nearby objects so bushes/flowers/mushrooms don't overlap trees.
	for _attempt in range(200):
		var x := _rng.randi_range(1, ISLAND_W - 2)
		var y := _rng.randi_range(1, ISLAND_H - 2)
		var cell := Vector2i(x, y)

		# Must be walkable terrain
		var tid: String = _tile_grid[y][x]
		if tid == "water" or tid.is_empty():
			continue
		var tile_type: TileTypeData = DataManager.get_tile_type(tid)
		if not tile_type or not tile_type.walkable:
			continue

		# Must not be on a tree cell
		if cell in _tree_cells:
			continue

		# Must not be too close to any tree (foliage radius ~1.5 tiles)
		var w_pos := _cell_to_world(cell)
		var too_close := false
		for tc in _tree_cells:
			var tree_world := _cell_to_world(tc)
			if tree_world.distance_squared_to(w_pos) < 576.0:  # ~1.5 tile radius
				too_close = true
				break
		if too_close:
			continue

		# Check against other placed nature objects — relaxed spacing for denser clusters
		var objects_root: Node = $Objects
		if objects_root:
			for child in objects_root.get_children():
				if child.position.distance_squared_to(w_pos) < 144.0:  # ~0.75 tiles (was 256)
					too_close = true
					break
		if too_close:
			continue

		return cell
	return _pick_walkable_cell()


func _cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE_SIZE + TILE_SIZE / 2.0, cell.y * TILE_SIZE + TILE_SIZE / 2.0)


# ── Content Scattering ───────────────────────────────────────────────────

## Assigns a deterministic, session-unique id to a scatterable island object so
## gather/remove actions can be broadcast to other peers building the same island.
## The id is seeded so distinct island sessions never collide (prevents a
## broadcast on one island from removing a matching object on another island).
func _tag_island_obj(node: Node) -> void:
	_island_obj_counter += 1
	node.set_meta("island_obj_id", _island_seed * 100000 + _island_obj_counter)


## Acting peer notifies peers when an island object is gathered/removed. Mirrors
## the main world's client-authoritative broadcast (_sync_remove_cell_object).
## The removal is routed through the always-present World node (not this island,
## which only exists while a peer is on-island) so it is tracked centrally and
## can be backfilled to a late joiner on island entry.
func notify_island_object_removed(obj_id: int) -> void:
	if not NetworkManager.is_network_active():
		return
	var world: Node = get_tree().get_first_node_in_group("world")
	if is_instance_valid(world) and world.has_method("notify_island_removal"):
		world.notify_island_removal(_island_seed, obj_id)


## Applies an island-object removal on every peer. any_peer + call_local so the
## acting peer's own broadcast also removes its local copy.
@rpc("any_peer", "call_local")
func _sync_island_object_removed(obj_id: int) -> void:
	for child in $Objects.get_children():
		if is_instance_valid(child) and child.get_meta("island_obj_id", -1) == obj_id:
			child.queue_free()
			return


func _scatter_trees() -> void:
	var count_range: Array = _tree_config.get("count", [8, 16])
	var tree_count: int = _rng.randi_range(count_range[0], count_range[1])
	var objects_root: Node = $Objects
	if not objects_root:
		return

	var tree_sprites_raw: Array = _tree_config.get("sprites", [])
	# Build a properly typed Array[String] for the typed property on tree nodes
	var tree_sprites: Array[String] = []
	for s in tree_sprites_raw:
		tree_sprites.append(s)

	for _i in range(tree_count):
		var cell := _pick_walkable_cell()
		var tree: Node2D

		var fruit_chance: float = _tree_config.get("fruit_chance", 0.25)
		if _rng.randf() < fruit_chance:
			tree = FRUIT_TREE_SCENE.instantiate()
		else:
			tree = TREE_SCENE.instantiate()

		# Set island-specific tree sprites if configured (must be set BEFORE add_child)
		if not tree_sprites.is_empty():
			tree.sprite_pool_override = tree_sprites

		_tag_island_obj(tree)
		# Deterministic sprite variant (matches the island_obj_id) so every peer
		# renders the same sprite for the same tree.
		if tree is TreeObject:
			tree.sprite_seed = int(tree.get_meta("island_obj_id"))
		objects_root.add_child(tree)
		tree.position = _cell_to_world(cell)

		# ICE_CREAM_LAND: trees that rolled the icecream_tree_02 sprite
		# bear chocolate ice cream cones when chopped.
		if _island_type == IslandType.ICE_CREAM_LAND and tree is TreeObject:
			var sprite_node := tree.get_node_or_null("Sprite2D") as Sprite2D
			if sprite_node and sprite_node.texture:
				var tex_path: String = sprite_node.texture.resource_path
				if "icecream_tree_02" in tex_path:
					tree.fruit_item_id = "ice_cream_cone"

		_tree_cells.append(cell)


func _scatter_resource_nodes() -> void:
	var objects_root: Node = $Objects
	if not objects_root:
		return

	for rc in _resource_configs:
		var count: int = _rng.randi_range(rc.count[0], rc.count[1])
		for _i in range(count):
			var cell := _pick_walkable_cell()
			var node := RESOURCE_NODE_SCENE.instantiate()
			_tag_island_obj(node)
			node.item_id = rc.item_id
			node.interaction_prompt = rc.prompt
			if rc.tool >= 0:
				node.required_tool = rc.tool
			node.min_amount = rc.min
			node.max_amount = rc.max
			objects_root.add_child(node)
			node.position = _cell_to_world(cell)


func _scatter_nature_objects() -> void:
	var objects_root: Node = $Objects
	if not objects_root:
		return

	var bush_range: Array = _nature_config.get("bush", [4, 8])
	var flower_range: Array = _nature_config.get("flower", [6, 12])
	var mushroom_range: Array = _nature_config.get("mushroom", [2, 5])

	var bush_count: int = _rng.randi_range(bush_range[0], bush_range[1])
	var flower_count: int = _rng.randi_range(flower_range[0], flower_range[1])
	var mushroom_count: int = _rng.randi_range(mushroom_range[0], mushroom_range[1])

	const BUSH_SCENE := preload("res://scenes/objects/Bush.tscn")
	const FLOWER_SCENE := preload("res://scenes/objects/FlowerPatch.tscn")
	const MUSHROOM_SCENE := preload("res://scenes/objects/MushroomPatch.tscn")

	var bush_sprite_path: String = _nature_config.get("bush_sprite", "")
	var flower_sprite_path: String = _nature_config.get("flower_sprite", "")
	var mushroom_sprite_path: String = _nature_config.get("mushroom_sprite", "")

	# Optional sprite pools for random-variant + color-tinted nature objects
	var bush_sprite_pool: Array = _nature_config.get("bush_sprite_pool", [])
	var flower_sprite_pool: Array = _nature_config.get("flower_sprite_pool", [])
	var mushroom_sprite_pool: Array = _nature_config.get("mushroom_sprite_pool", [])

	for _i in range(bush_count):
		var cell := _pick_nature_cell()
		var bush: Node2D = BUSH_SCENE.instantiate()
		if not bush_sprite_pool.is_empty():
			bush.texture_override_pool = bush_sprite_pool
		elif not bush_sprite_path.is_empty():
			bush.texture_override_path = bush_sprite_path
		_tag_island_obj(bush)
		objects_root.add_child(bush)
		bush.position = _cell_to_world(cell)

	for _i in range(flower_count):
		var cell := _pick_nature_cell()
		var flower: Node2D = FLOWER_SCENE.instantiate()
		if not flower_sprite_pool.is_empty():
			flower.texture_override_pool = flower_sprite_pool
		elif not flower_sprite_path.is_empty():
			flower.texture_override_path = flower_sprite_path
		_tag_island_obj(flower)
		objects_root.add_child(flower)
		flower.position = _cell_to_world(cell)

	for _i in range(mushroom_count):
		var cell := _pick_nature_cell()
		var mushroom: Node2D = MUSHROOM_SCENE.instantiate()
		if not mushroom_sprite_pool.is_empty():
			mushroom.texture_override_pool = mushroom_sprite_pool
		elif not mushroom_sprite_path.is_empty():
			mushroom.texture_override_path = mushroom_sprite_path
		_tag_island_obj(mushroom)
		objects_root.add_child(mushroom)
		mushroom.position = _cell_to_world(cell)


func _scatter_structures() -> void:
	var objects_root: Node = $Objects
	if not objects_root or _structure_configs.is_empty():
		return

	for config in _structure_configs:
		if not config is Dictionary:
			continue

		var min_count: int = config.get("count", [1, 1])[0]
		var max_count: int = config.get("count", [1, 1])[1]
		var to_place: int = _rng.randi_range(min_count, max_count)

		for _i in range(to_place):
			var footprint: Vector2i = config.get("footprint", Vector2i(2, 2))

			# Find a clear walkable area large enough for the structure
			var cell: Vector2i = _find_structure_site(footprint)
			if cell == Vector2i(-1, -1):
				print("ExpeditionIsland: could not find suitable site for structure type ", config.get("type", "unknown"))
				continue

			# Mark cells as occupied so nothing else spawns here
			for dy in range(footprint.y):
				for dx in range(footprint.x):
					var oc := Vector2i(cell.x + dx, cell.y + dy)
					if oc.y < _tile_grid.size() and oc.x < _tile_grid[oc.y].size():
						_tile_grid[oc.y][oc.x] = "structure_occupied"

			var structure: IslandStructure = ISLAND_STRUCTURE_SCENE.instantiate()
			var struct_type: int = config.get("type", IslandStructure.StructureType.CHEST)
			structure.setup(struct_type, config)
			objects_root.add_child(structure)
			structure.position = _cell_to_world(cell + Vector2i(footprint.x / 2, footprint.y / 2))


## Find a clear, walkable area large enough for a structure footprint.
## Returns the top-left cell of the area, or Vector2i(-1,-1) if none found.
func _find_structure_site(footprint: Vector2i) -> Vector2i:
	# Try many random positions to find suitable flat land
	for _attempt in range(300):
		var x := _rng.randi_range(1, ISLAND_W - footprint.x - 1)
		var y := _rng.randi_range(1, ISLAND_H - footprint.y - 1)
		var valid := true

		for dy in range(footprint.y):
			for dx in range(footprint.x):
				var cx := x + dx
				var cy := y + dy
				if cy >= _tile_grid.size() or cx >= _tile_grid[cy].size():
					valid = false
					break
				var tid: String = _tile_grid[cy][cx]
				if tid == "water" or tid.is_empty() or tid == "structure_occupied":
					valid = false
					break
				# Check walkability
				var tile_type: TileTypeData = DataManager.get_tile_type(tid)
				if tile_type and not tile_type.walkable:
					valid = false
					break

				# Also check the Objects node doesn't already have something here
				var world_pos := _cell_to_world(Vector2i(cx, cy))
				for child in $Objects.get_children():
					if child is IslandStructure:
						continue
					# Small nature objects (bushes, flowers, mushrooms) don't block structures
					if child is Bush or child is FlowerPatch or child is MushroomPatch:
						continue
					if child is Animal:
						continue
					var dist: float = child.position.distance_squared_to(world_pos)
					if dist < 64.0:  # ~0.5 tiles spacing — reduced from 128 to make placement easier
						valid = false
						break

			if not valid:
				break

		if valid:
			return Vector2i(x, y)

	return Vector2i(-1, -1)


func _scatter_animals() -> void:
	var objects_root: Node = $Objects
	if not objects_root:
		return

	var animal_count: int = _rng.randi_range(6, 14)

	for _i in range(animal_count):
		var cell := _pick_walkable_cell()
		var p_type: String = _animal_types[_rng.randi() % _animal_types.size()]
		var animal: Animal = ANIMAL_SCENE.instantiate()
		objects_root.add_child(animal)
		# Set local position FIRST so that global_position is correct by the time
		# setup() stores _home_pos. _home_pos must be a global coordinate because
		# _is_walkable_position() subtracts the island's global_position to
		# convert back to local tile coords.
		var local_pos := _cell_to_world(cell)
		animal.position = local_pos
		animal.setup(p_type, animal.global_position, true)
		# Scale down expedition animals so they fit better on the smaller islands
		animal.scale *= _rng.randf_range(0.5, 0.75)
		# Tag with a deterministic island_obj_id (shared counter) so a death on
		# one peer can be broadcast and applied to every peer's matching copy.
		_tag_island_obj(animal)
		# Host-authoritative shared HP/damage: derive a deterministic animal_id
		# from the island_obj_id so the World relay can match this animal across
		# peers. On clients the copy becomes a remote mirror that reports damage
		# to the host instead of processing it locally (host is authoritative
		# when its player is on the island session).
		animal.animal_id = int(animal.get_meta("island_obj_id"))
		if NetworkManager.is_network_active() and not multiplayer.is_server():
			animal._is_remote = true


func _place_return_boat() -> void:
	var ground_layer: TileMapLayer = $GroundLayer
	var objects_root: Node = $Objects
	if not ground_layer or not objects_root:
		return

	var candidates: Array[Vector2i] = []
	for y in range(1, ISLAND_H - 1):
		for x in range(1, ISLAND_W - 1):
			var cell := Vector2i(x, y)
			var tid: String = _tile_grid[y][x]
			if tid != "water" and not tid.is_empty() and not tid.begins_with("edge"):
				var below: String = _tile_grid[y + 1][x] if y + 1 < ISLAND_H else "water"
				if below == "water" or below.begins_with("edge"):
					candidates.append(cell)

	if candidates.is_empty():
		for y in range(1, ISLAND_H - 1):
			for x in range(1, ISLAND_W - 1):
				var cell := Vector2i(x, y)
				var tid: String = _tile_grid[y][x]
				if tid != "water" and not tid.is_empty() and not tid.begins_with("edge"):
					candidates.append(cell)

	if candidates.is_empty():
		candidates.append(_pick_walkable_cell())

	var boat_cell := candidates[_rng.randi() % candidates.size()]
	var boat := RETURN_BOAT_SCENE.instantiate()
	objects_root.add_child(boat)
	boat.position = _cell_to_world(boat_cell) + Vector2(-24, 0)
	_return_boat = boat


## Checks if a cell in the island's local grid is non-walkable (water or edge).
## Used by the Player to block movement past the island boundary.
## Returns true for water, edge tiles, or any cell outside the island bounds.
func is_water_tile(cell_x: int, cell_y: int) -> bool:
	if cell_x < 0 or cell_x >= ISLAND_W or cell_y < 0 or cell_y >= ISLAND_H:
		return true  # Out of island bounds = blocked
	var tile_id: String = _tile_grid[cell_y][cell_x] if cell_y < _tile_grid.size() and cell_x < _tile_grid[cell_y].size() else ""
	return tile_id == "water" or tile_id.is_empty() or tile_id.begins_with("edge")
