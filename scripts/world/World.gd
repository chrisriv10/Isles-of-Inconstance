extends Node2D

## Owns the tile-based world: procedural generation, tile lookups, and
## simple farming actions (tilling). Keeps generation logic delegated to
## WorldGenerator so this script only deals with the scene tree.

const TILE_SIZE: int = 16
const RESOURCE_NODE_SCENE: PackedScene = preload("res://scenes/objects/ResourceNode.tscn")
const CROP_SCENE: PackedScene = preload("res://scenes/world/Crop.tscn")
const SHOP_BUILDING_SCENE: PackedScene = preload("res://scenes/objects/ShopBuilding.tscn")
const BOAT_SCENE: PackedScene = preload("res://scenes/objects/Boat.tscn")
const TREE_SCENE: PackedScene = preload("res://scenes/objects/Tree.tscn")
const ANIMAL_SCENE: PackedScene = preload("res://scenes/world/Animal.tscn")

## Nature scene paths - loaded on demand
const BUSH_SCENE_PATH: String = "res://scripts/world/nature/Bush.gd"
const FLOWER_SCENE_PATH: String = "res://scripts/world/nature/FlowerPatch.gd"
const MUSHROOM_SCENE_PATH: String = "res://scripts/world/nature/MushroomPatch.gd"
const LOG_STUMP_SCENE_PATH: String = "res://scripts/world/nature/LogStump.gd"

@export var world_width: int = 60
@export var world_height: int = 60
@export var world_seed: int = 0
@export var object_count: int = 12

@onready var ground_layer: TileMapLayer = $GroundLayer
@onready var objects_root: Node2D = $Objects
@onready var tool_preview: ToolPreview = $ToolPreview

var _tile_grid: Array = []
var _generator: WorldGenerator
var _soil_data: Dictionary = {}
var _crop_nodes: Dictionary = {}

# New system references
var building_system: BuildingSystem = null
var cooking_system: CookingSystem = null
var hybrid_system: HybridCropSystem = null
var crop_trait_generator: CropTraitGenerator = null
var biome_generator: BiomeGenerator = null

# Build mode state
var build_mode_active: bool = false
var build_item_id: String = ""
var build_type: int = BuildingSystem.BuildingType.NONE

## Maps craftable building items to their BuildingSystem type
const BUILD_ITEM_TO_TYPE: Dictionary = {
	"fence_material": BuildingSystem.BuildingType.FENCE,
	"stone_fence_material": BuildingSystem.BuildingType.STONE_FENCE,
	"campfire_kit": BuildingSystem.BuildingType.CAMPFIRE,
}

func _init() -> void:
	building_system = BuildingSystem.new()
	cooking_system = CookingSystem.new()
	crop_trait_generator = CropTraitGenerator.new(0)

func _ready() -> void:
	GameManager.day_changed.connect(_on_day_changed)
	generate_world()
	_setup_water_collision()

func generate_world() -> void:
	_clear_world()
	_generator = WorldGenerator.create(world_width, world_height, world_seed)
	_tile_grid = _generator.generate_tile_grid()
	_paint_ground()
	_scatter_objects()
	_scatter_trees()
	_scatter_nature_objects()
	_spawn_shop_stand()
	_spawn_boat()
	_scatter_animals()
	_scatter_buildings()
	
	# Initialize season system if not already
	if GameManager.season_system == null:
		GameManager.season_system = SeasonSystem.new(world_seed)
	
	# Initialize hybrid system
	hybrid_system = HybridCropSystem.new(world_seed)
	
	# Initialize biome generator for biome-aware crop traits
	biome_generator = BiomeGenerator.new(world_seed)
	
	# Sync crop trait generator with current world seed
	if crop_trait_generator:
		crop_trait_generator.world_seed = world_seed

func generate_world_with_seed(new_seed: int) -> void:
	world_seed = new_seed
	generate_world()

func _clear_world() -> void:
	ground_layer.clear()
	for child in objects_root.get_children():
		child.queue_free()
	# Clear placed buildings so a fresh world gets fresh buildings
	if building_system:
		building_system.placed_buildings.clear()
	_soil_data.clear()
	_crop_nodes.clear()

func _paint_ground() -> void:
	for y in range(world_height):
		for x in range(world_width):
			var tile_id: String = _tile_grid[y][x]
			var tile_type: TileTypeData = DataManager.get_tile_type(tile_id)
			if tile_type:
				ground_layer.set_cell(Vector2i(x, y), 0, tile_type.atlas_coords)
	
	# Post-process: add beach sand and coastline edge tiles around the island
	_add_beach_and_edge_tiles()

## Post-processes the tile grid to add beach sand and coastline edge tiles.
## Beach: walkable tiles adjacent to water get replaced with sand.
## Edge: water tiles adjacent to land get replaced with direction-specific
## cliff-edge tiles (N/S/W/E + corners) so the coastline looks varied.
func _add_beach_and_edge_tiles() -> void:
	for y in range(world_height):
		for x in range(world_width):
			var cell := Vector2i(x, y)
			var tile_id: String = _tile_grid[y][x]
			
			# Water cell with land neighbours → directional edge tile
			if tile_id == "water" and _has_land_neighbor(cell):
				var edge_id: String = _get_edge_direction(cell)
				if edge_id != "":
					_tile_grid[y][x] = edge_id
					var edge_type: TileTypeData = DataManager.get_tile_type(edge_id)
					if edge_type:
						ground_layer.set_cell(cell, 0, edge_type.atlas_coords)
			
			# Land cell with a water neighbour → beach sand
			elif tile_id != "water" and not tile_id.begins_with("edge") and tile_id != "tilled" \
				and tile_id != "watered_tilled" and _has_water_neighbor(cell):
				_tile_grid[y][x] = "sand"
				var sand_type: TileTypeData = DataManager.get_tile_type("sand")
				if sand_type:
					ground_layer.set_cell(cell, 0, sand_type.atlas_coords)

## Determines which directional edge tile to use for a water cell that
## has land neighbours. Checks cardinal directions first, then corners.
## Returns an edge tile id like "edge_n", "edge_ne", etc., or "" if none.
func _get_edge_direction(cell: Vector2i) -> String:
	var north: bool = _is_neighbor_land(cell, 0, -1)  # land above
	var south: bool = _is_neighbor_land(cell, 0, 1)   # land below
	var west: bool = _is_neighbor_land(cell, -1, 0)    # land left
	var east: bool = _is_neighbor_land(cell, 1, 0)     # land right
	
	# Cardinal directions
	if south and not west and not east and not north:
		return "edge_n"   # land is south → north-facing cliff
	if north and not west and not east and not south:
		return "edge_s"   # land is north → south-facing cliff
	if east and not north and not south and not west:
		return "edge_w"   # land is east → west-facing cliff
	if west and not north and not south and not east:
		return "edge_e"   # land is west → east-facing cliff
	
	# Corners (two adjacent directions)
	if south and east and not west and not north:
		return "edge_nw"  # land is SE → NW corner
	if south and west and not east and not north:
		return "edge_ne"  # land is SW → NE corner
	if north and east and not west and not south:
		return "edge_sw"  # land is NE → SW corner
	if north and west and not east and not south:
		return "edge_se"  # land is NW → SE corner
	
	# Fallback for complex cases (3+ land neighbours): pick first cardinal
	if north: return "edge_s"
	if south: return "edge_n"
	if west: return "edge_e"
	if east: return "edge_w"
	
	return ""

## Returns true if the neighbour at offset (dx, dy) from cell is land.
func _is_neighbor_land(cell: Vector2i, dx: int, dy: int) -> bool:
	var nc := Vector2i(cell.x + dx, cell.y + dy)
	if not _is_in_bounds(nc):
		return false
	var nid: String = _tile_grid[nc.y][nc.x]
	return nid in ["grass", "dirt", "fertile_soil", "sand", "trees", "rocks", "tilled", "watered_tilled"]

## Returns true if any neighbour of the given cell is land.
func _has_land_neighbor(cell: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			if _is_neighbor_land(cell, dx, dy):
				return true
	return false

## Returns true if any neighbour of the given cell is water.
func _has_water_neighbor(cell: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var nc := Vector2i(cell.x + dx, cell.y + dy)
			if not _is_in_bounds(nc):
				return true  # out of bounds acts like water
			var nid: String = _tile_grid[nc.y][nc.x]
			if nid == "water" or nid.begins_with("edge"):
				return true
	return false

## Public helper so Animal.gd can check if a world position is walkable
## (not water or edge). Returns true if the cell at the given position is
## safe for an animal to walk on.
func is_cell_walkable(world_pos: Vector2) -> bool:
	var cell := world_to_cell(world_pos)
	if not _is_in_bounds(cell):
		return false
	var tile_id: String = _tile_grid[cell.y][cell.x]
	var tile_type: TileTypeData = DataManager.get_tile_type(tile_id)
	return tile_type != null and tile_type.walkable

func _scatter_objects() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + 1
	var positions: Array = _generator.pick_object_positions(_tile_grid, object_count, rng)
	for pos in positions:
		var obj := RESOURCE_NODE_SCENE.instantiate()
		objects_root.add_child(obj)
		obj.global_position = cell_to_world(pos)

# ---------------------------------------------------------------------------
# Coordinate helpers
# ---------------------------------------------------------------------------

func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE_SIZE + TILE_SIZE / 2.0, cell.y * TILE_SIZE + TILE_SIZE / 2.0)

func world_to_cell(world_pos: Vector2) -> Vector2i:
	return Vector2i(floori(world_pos.x / TILE_SIZE), floori(world_pos.y / TILE_SIZE))

# ---------------------------------------------------------------------------
# Tool targeting preview (pulsing blue outline)
# ---------------------------------------------------------------------------

## Show a preview of which tiles the player's current tool would affect.
## Calls through so the Player can request a preview for hoe (multi-cell)
## or seeds (single cell). Pass null/empty world_pos to clear.
func show_tool_preview(target_world_pos: Vector2) -> void:
	var cell := world_to_cell(target_world_pos)
	if not _is_in_bounds(cell):
		_clear_tool_preview()
		return
	var cells: Array[Vector2i] = UpgradeManager.get_tool_area_cells(cell)
	# Filter to only show cells that are valid for the action
	var valid: Array[Vector2i] = []
	for c in cells:
		if _is_in_bounds(c):
			valid.append(c)
	if valid.is_empty():
		_clear_tool_preview()
	else:
		tool_preview.show_cells(valid)

## Show preview for a single-cell action (planting seeds).
func show_single_cell_preview(target_world_pos: Vector2) -> void:
	var cell := world_to_cell(target_world_pos)
	if not _is_in_bounds(cell):
		_clear_tool_preview()
		return
	tool_preview.show_cells([cell])

func clear_tool_preview() -> void:
	tool_preview.hide_preview()

func _clear_tool_preview() -> void:
	clear_tool_preview()

# ---------------------------------------------------------------------------
# Farming actions
# ---------------------------------------------------------------------------

func till_tile(world_pos: Vector2) -> bool:
	var cells := UpgradeManager.get_tool_area_cells(world_to_cell(world_pos))
	var tilled_any := false
	for cell in cells:
		if _till_cell(cell):
			tilled_any = true
	return tilled_any

func _till_cell(cell: Vector2i) -> bool:
	if not _is_in_bounds(cell):
		return false
	var tile_id: String = _tile_grid[cell.y][cell.x]
	var tile_type: TileTypeData = DataManager.get_tile_type(tile_id)
	if tile_type == null or not tile_type.tillable:
		return false
	if _soil_data.has(cell) and _soil_data[cell].is_tilled:
		return false
	
	_tile_grid[cell.y][cell.x] = "tilled"
	
	var soil := SoilData.new()
	soil.is_tilled = true
	_soil_data[cell] = soil
	
	var tilled_type: TileTypeData = DataManager.get_tile_type("tilled")
	ground_layer.set_cell(cell, 0, tilled_type.atlas_coords)
	
	# Effects
	EffectSpawner.spawn_dirt_puff(cell_to_world(cell))
	AudioManager.play(AudioManager.Sound.TILL)
	
	return true

func water_tile(world_pos: Vector2) -> bool:
	var cells := UpgradeManager.get_tool_area_cells(world_to_cell(world_pos))
	var watered_any := false
	for cell in cells:
		if _water_cell(cell):
			watered_any = true
	return watered_any

func _water_cell(cell: Vector2i) -> bool:
	if not _soil_data.has(cell) or not _soil_data[cell].is_tilled or _soil_data[cell].is_watered:
		return false
	_soil_data[cell].is_watered = true
	
	# Watering improves soil quality slightly
	if _soil_data[cell].soil_quality:
		_soil_data[cell].soil_quality.improve(1)
		# Cap at good quality from watering alone
		if _soil_data[cell].soil_quality.current_level > SoilQuality.QualityLevel.GOOD:
			_soil_data[cell].soil_quality.current_level = SoilQuality.QualityLevel.GOOD
	
	var watered_type: TileTypeData = DataManager.get_tile_type("watered_tilled")
	ground_layer.set_cell(cell, 0, watered_type.atlas_coords)
	
	# Effects
	EffectSpawner.spawn_water_droplets(cell_to_world(cell))
	AudioManager.play(AudioManager.Sound.WATER)
	
	return true

func plant_seed(world_pos: Vector2, crop_id: String) -> bool:
	var cell := world_to_cell(world_pos)
	if not _soil_data.has(cell) or not _soil_data[cell].is_tilled or _soil_data[cell].crop_id != "":
		return false

	var crop_data := DataManager.get_crop(crop_id)
	if not crop_data or crop_data.seed_item_id == "":
		return false
	if not InventoryManager.remove_item(crop_data.seed_item_id, 1):
		return false
	
	# Apply biome-specific traits if the trait generator and biome generator are available
	var effective_crop_id := crop_id
	if crop_trait_generator and biome_generator:
		var biome: BiomeDefinition = biome_generator.get_biome_at(cell.x, cell.y)
		if biome and biome.crop_trait_tags.size() > 0:
			var modified = crop_trait_generator.apply_biome_traits(crop_data, biome, cell.x, cell.y)
			if modified:
				# Store the modified crop id for lookup — the actual crop data
				# lives in DataManager; we use a meta-tagged variant id pattern
				effective_crop_id = crop_id  # keep same base id, biome traits are applied per-instance via soil metadata
	
	_soil_data[cell].crop_id = effective_crop_id
	_soil_data[cell].days_grown = 0
	
	# Store biome trait metadata on the soil for later reference
	if biome_generator:
		var biome: BiomeDefinition = biome_generator.get_biome_at(cell.x, cell.y)
		if biome:
			_soil_data[cell].season_tag = BiomeType.Type.keys()[biome.type] if biome.type >= 0 else ""
	
	var crop: Crop = CROP_SCENE.instantiate()
	objects_root.add_child(crop)
	crop.global_position = cell_to_world(cell)
	crop.setup(effective_crop_id, 0)
	crop.mutated.connect(_on_crop_mutated.bind(cell))
	_crop_nodes[cell] = crop
	
	# Effects
	AudioManager.play(AudioManager.Sound.PLANT)
	
	return true

func harvest_crop(world_pos: Vector2) -> bool:
	var cell := world_to_cell(world_pos)
	if not _crop_nodes.has(cell):
		return false
	var crop: Crop = _crop_nodes[cell]
	if not crop.is_mature():
		return false
	
	var crop_data := DataManager.get_crop(crop.crop_id)
	if not crop_data:
		return false

	if not InventoryManager.can_fit(crop_data.yield_item_id, crop_data.yield_amount):
		return false  # inventory full - leave the crop growing rather than losing the harvest
	
	var soil: SoilData = _soil_data.get(cell)
	
	# Calculate quality tier
	var quality_tier := CropQuality.QualityTier.NORMAL
	if soil:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(str(world_seed) + ":quality:" + str(cell.x) + "," + str(cell.y))
		var watered_every_day := soil.unwatered_days == 0
		var season_favorable := true
		if GameManager.season_system:
			season_favorable = GameManager.season_system.is_season_favorable(soil.season_tag)
		
		var soil_level := SoilQuality.QualityLevel.AVERAGE
		if soil.soil_quality:
			soil_level = soil.soil_quality.current_level
		
		quality_tier = CropQuality.calculate_quality(
			soil_level,
			soil.fertilizer and soil.fertilizer.is_active(),
			watered_every_day,
			season_favorable,
			soil.days_grown,
			crop_data.days_to_grow,
			rng
		)
	
	# Calculate yield with quality multiplier
	var base_yield := crop_data.yield_amount
	var quality_mult := CropQuality.get_price_multiplier(quality_tier)
	var effective_yield := maxi(1, roundi(base_yield * quality_mult))
	
	# Apply soil yield boost
	if soil:
		effective_yield = maxi(1, roundi(effective_yield * soil.get_effective_yield_boost()))
	
	# Giant crop chance (1% with fertile soil)
	var is_giant := false
	if soil and soil.soil_quality and soil.soil_quality.current_level >= SoilQuality.QualityLevel.RICH:
		if randf() < 0.01:
			is_giant = true
			effective_yield *= 3
			soil.is_giant_crop = true
	
	# Add the yield items
	InventoryManager.add_item(crop_data.yield_item_id, clamp(effective_yield, 1, 99))
	DataManager.mark_discovered(crop_data.id)
	
	# Also drop 1-2 seeds back so the farming loop is self-sustaining
	var seed_to_drop: int = 1 if randi() % 3 == 0 else 2  # 2/3 chance of 2 seeds
	# Higher quality = more seeds
	if quality_tier >= CropQuality.QualityTier.GOLD:
		seed_to_drop += 1
	if crop_data.seed_item_id != "":
		InventoryManager.add_item(crop_data.seed_item_id, min(seed_to_drop, 5))
	
	# Rare drop chance
	if randi() % 20 == 0:  # 5% chance for rare seed
		var all_crops := DataManager.crops.values()
		if not all_crops.is_empty():
			var rare_crop: CropData = all_crops[randi() % all_crops.size()]
			if rare_crop and rare_crop.seed_item_id != "":
				InventoryManager.add_item(rare_crop.seed_item_id, 1)
				ToastNotification.show_toast("Found rare %s seed!" % rare_crop.display_name, ToastNotification.ToastType.SUCCESS, 3.0)
	
	# Effects
	var harvest_color := crop_data.modulate_color
	if crop.genetics:
		harvest_color = crop.genetics.to_color()
	
	# Enhanced harvest animation
	var quality_suffix := CropQuality.get_tier_suffix(quality_tier)
	HarvestAnimation.play_harvest_effect(crop.global_position, crop_data.display_name + quality_suffix, harvest_color, quality_tier)
	AudioManager.play(AudioManager.Sound.HARVEST)
	
	# Giant crop notification
	if is_giant:
		ToastNotification.show_toast("Giant %s harvested! ★★★" % crop_data.display_name, ToastNotification.ToastType.SUCCESS, 4.0)
	
	# Quality notification for silver+
	if quality_tier >= CropQuality.QualityTier.SILVER:
		var tier_name := CropQuality.get_tier_name(quality_tier)
		ToastNotification.show_toast("%s quality %s!" % [tier_name, crop_data.display_name], ToastNotification.ToastType.SUCCESS, 2.5)
	
	if crop_data.regrows:
		crop.harvest()
		_soil_data[cell].days_grown = crop_data.regrow_days
	else:
		crop.queue_free()
		_crop_nodes.erase(cell)
		_soil_data[cell].crop_id = ""
		_soil_data[cell].days_grown = 0
	return true

## Keeps SoilData in sync when a Crop mutates into a new crop id mid-growth,
## and forwards a notification for the UI to display.
@warning_ignore("unused_parameter")
func _on_crop_mutated(crop: Crop, old_crop_id: String, new_crop_id: String, mutation_name: String, cell: Vector2i) -> void:
	if _soil_data.has(cell):
		_soil_data[cell].crop_id = new_crop_id

	var old_crop_data := DataManager.get_crop(old_crop_id)
	var new_crop_data := DataManager.get_crop(new_crop_id)
	var old_name := old_crop_data.display_name if old_crop_data else old_crop_id
	var new_name := new_crop_data.display_name if new_crop_data else new_crop_id
	GameManager.crop_mutated.emit(old_name, new_name, mutation_name)

## Apply compost to a tilled tile with a growing crop. Boosts growth by 1
## day immediately (composted crops grow 2 days on the next day change).
## Returns true if compost was used.
func apply_compost(world_pos: Vector2) -> bool:
	var cell := world_to_cell(world_pos)
	if not _soil_data.has(cell) or not _soil_data[cell].is_tilled:
		return false
	var soil: SoilData = _soil_data[cell]
	if soil.crop_id == "":
		return false
	
	# Check for different fertilizer types
	var fertilizer_type := FertilizerSystem.FertilizerType.NONE
	var fertilizer_duration := 3
	var fertilizer_item := ""
	
	if InventoryManager.has_item("super_fertilizer", 1):
		fertilizer_type = FertilizerSystem.FertilizerType.SUPER_FERTILIZER
		fertilizer_duration = 10
		fertilizer_item = "super_fertilizer"
	elif InventoryManager.has_item("rich_fertilizer", 1):
		fertilizer_type = FertilizerSystem.FertilizerType.RICH_FERTILIZER
		fertilizer_duration = 7
		fertilizer_item = "rich_fertilizer"
	elif InventoryManager.has_item("yield_enhancer", 1):
		fertilizer_type = FertilizerSystem.FertilizerType.YIELD_ENHANCER
		fertilizer_duration = 6
		fertilizer_item = "yield_enhancer"
	elif InventoryManager.has_item("growth_booster", 1):
		fertilizer_type = FertilizerSystem.FertilizerType.GROWTH_BOOSTER
		fertilizer_duration = 4
		fertilizer_item = "growth_booster"
	elif InventoryManager.has_item("quality_compost", 1):
		fertilizer_type = FertilizerSystem.FertilizerType.QUALITY_COMPOST
		fertilizer_duration = 5
		fertilizer_item = "quality_compost"
	elif InventoryManager.has_item("compost", 1):
		fertilizer_type = FertilizerSystem.FertilizerType.BASIC_COMPOST
		fertilizer_duration = 3
		fertilizer_item = "compost"
	else:
		ToastNotification.show_toast("No compost or fertilizer available!", ToastNotification.ToastType.WARNING, 2.0)
		return false
	
	InventoryManager.remove_item(fertilizer_item, 1)
	
	if fertilizer_type == FertilizerSystem.FertilizerType.BASIC_COMPOST:
		soil.is_composted = true
	
	soil.apply_fertilizer(fertilizer_type, fertilizer_duration)
	
	# Immediate visual feedback
	var fert_color := soil.fertilizer.get_color() if soil.fertilizer else Color(0.3, 0.7, 0.3)
	if _crop_nodes.has(cell):
		_crop_nodes[cell].modulate = fert_color
	
	EffectSpawner.spawn_particles(cell_to_world(cell), fert_color, 8, 14.0)
	var fert_name := soil.fertilizer.get_name() if soil.fertilizer else "Compost"
	ToastNotification.show_toast("%s applied! Growth & soil boosted." % fert_name, ToastNotification.ToastType.SUCCESS, 2.0)
	AudioManager.play(AudioManager.Sound.PLANT)
	return true

func _on_day_changed(_day: int) -> void:
	for cell in _soil_data.keys():
		var soil: SoilData = _soil_data[cell]
		
		# Advance daily soil systems
		soil.advance_daily()
		
		if soil.crop_id != "":
			var crop_data := DataManager.get_crop(soil.crop_id)
			if crop_data and (not crop_data.requires_water or soil.is_watered):
				# Crop got water (or doesn't need it) — grows normally
				soil.unwatered_days = 0
				
				# Calculate growth based on soil quality, fertilizer, season, compost
				var growth_boost := soil.get_effective_growth_boost()
				
				# Season effect
				if GameManager.season_system:
					var season_mult := GameManager.season_system.get_growth_multiplier(soil.season_tag)
					growth_boost *= season_mult
				
				# Apply growth (rounded, minimum 1)
				var growth_days := maxi(1, roundi(growth_boost))
				soil.days_grown += growth_days
				
				if _crop_nodes.has(cell):
					for g in range(growth_days):
						_crop_nodes[cell].grow()
					
					# Check for disease
					if not soil.disease.is_infected():
						var disease_chance := 0.02  # 2% base chance per day
						# Poor soil = more disease
						if soil.soil_quality and soil.soil_quality.current_level <= SoilQuality.QualityLevel.POOR:
							disease_chance = 0.08
						# Rich soil = less disease
						elif soil.soil_quality and soil.soil_quality.current_level >= SoilQuality.QualityLevel.RICH:
							disease_chance = 0.005
						
						var resistance_tags: Array = []
						if crop_data.has("trait_tags"):
							resistance_tags = crop_data.get("trait_tags")
						
						if soil.disease.try_infect(disease_chance, resistance_tags):
							ToastNotification.show_toast("%s has %s!" % [crop_data.display_name, soil.disease.get_disease_name()], ToastNotification.ToastType.WARNING, 3.0)
					
					# Show disease visual
					if soil.disease.is_infected():
						var dc := soil.disease.get_disease_color()
						_crop_nodes[cell].modulate = dc
					
					# Check for hybrid crop opportunity (adjacent different crops)
					if _check_hybrid_opportunity(cell, soil):
						pass
					
			elif crop_data and crop_data.requires_water:
				# Crop needs water but wasn't watered — track stress
				soil.unwatered_days += 1
				if _crop_nodes.has(cell):
					if soil.unwatered_days >= 3:
						# Crop dies after 3 days without water
						_crop_nodes[cell].queue_free()
						_crop_nodes.erase(cell)
						soil.crop_id = ""
						soil.days_grown = 0
						soil.unwatered_days = 0
						EffectSpawner.spawn_particles(cell_to_world(cell), Color(0.6, 0.3, 0.1), 4, 8.0)
						ToastNotification.show_toast("Crop wilted from thirst!", ToastNotification.ToastType.WARNING, 3.0)
					else:
						# Show wilted visual (brownish tint)
						_crop_nodes[cell].modulate = Color(0.7, 0.6, 0.4)
		
		# Update tile appearance based on watered/dry state
		if soil.is_tilled and soil.crop_id == "":
			var tilled_type: TileTypeData = DataManager.get_tile_type("tilled")
			ground_layer.set_cell(cell, 0, tilled_type.atlas_coords)
		elif soil.is_tilled and soil.is_watered:
			var watered_type: TileTypeData = DataManager.get_tile_type("watered_tilled")
			ground_layer.set_cell(cell, 0, watered_type.atlas_coords)

## Check if two different crops are adjacent and can hybridize
func _check_hybrid_opportunity(cell: Vector2i, soil: SoilData) -> bool:
	if not hybrid_system or soil.crop_id == "":
		return false
	
	var crop_data := DataManager.get_crop(soil.crop_id)
	if not crop_data or not _crop_nodes.has(cell):
		return false
	var crop_node: Crop = _crop_nodes[cell]
	if not crop_node.is_mature():
		return false
	
	# Check adjacent cells for a different mature crop
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var nc := Vector2i(cell.x + dx, cell.y + dy)
			if not _soil_data.has(nc):
				continue
			var neighbor_soil: SoilData = _soil_data[nc]
			if neighbor_soil.crop_id == "" or neighbor_soil.crop_id == soil.crop_id:
				continue
			if not _crop_nodes.has(nc):
				continue
			var neighbor_crop: Crop = _crop_nodes[nc]
			if not neighbor_crop.is_mature():
				continue
			
			# Try to create hybrid
			var hybrid := hybrid_system.try_hybridize(soil.crop_id, neighbor_soil.crop_id, cell.x, cell.y)
			if hybrid:
				ToastNotification.show_toast("New hybrid discovered: %s!" % hybrid.display_name, ToastNotification.ToastType.SUCCESS, 5.0)
				# Give the player a hybrid seed
				InventoryManager.add_item(hybrid.seed_item_id, 1)
				return true
	
	return false

# ---------------------------------------------------------------------------
# Terrain collision
# ---------------------------------------------------------------------------

## Adds collision shapes to non-walkable tiles in the TileSet so the player
## (CharacterBody2D with collision_mask layer 1) cannot walk into water,
## trees, or rocks.
func _setup_water_collision() -> void:
	var tileset: TileSet = ground_layer.tile_set
	if not tileset:
		return

	# Ensure the TileSet has at least one physics layer.
	while tileset.get_physics_layers_count() < 1:
		tileset.add_physics_layer()

	var source: TileSetAtlasSource = tileset.get_source(0)
	if not source:
		return

	# Apply full-tile collision to all non-walkable tile types only
	# (water=3, trees=7, rocks=8, edge tiles 13-20). Walkable tiles keep no collision.
	var non_walkable_coords: Array[Vector2i] = [
		Vector2i(3, 0), Vector2i(7, 0), Vector2i(8, 0),
	]
	for i in range(13, 21):  # edge tiles at positions 13-20
		non_walkable_coords.append(Vector2i(i, 0))
	for coords in non_walkable_coords:
		var tile_data: TileData = source.get_tile_data(coords, 0)
		if tile_data and tile_data.get_collision_polygons_count(0) == 0:
			var polygon := PackedVector2Array([
				Vector2(0, 0),
				Vector2(16, 0),
				Vector2(16, 16),
				Vector2(0, 16),
			])
			tile_data.add_collision_polygon(0)
			tile_data.set_collision_polygon_points(0, 0, polygon)

	# Enable collision on the TileMapLayer.
	ground_layer.collision_enabled = true

	# Tell the TileSet's physics layer which collision layer to use.
	# Layer 1 matches the Player's collision_mask (default).
	tileset.set_physics_layer_collision_layer(0, 1)

## Places tree objects across the "trees" tile regions so the forest
## areas have 3D-looking tree sprites instead of flat tile textures.
func _scatter_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + 3333

	for y in range(world_height):
		for x in range(world_width):
			var tile_id: String = _tile_grid[y][x]
			if tile_id != "trees":
				continue
			# Place a tree on ~60% of trees tiles for a natural look
			if rng.randf() > 0.6:
				continue

			var cell := Vector2i(x, y)
			# Skip if there's already something here
			var blocked := false
			for child in objects_root.get_children():
				if child.global_position.distance_squared_to(cell_to_world(cell)) < 100.0:
					blocked = true
					break
			if blocked:
				continue

			var tree: Area2D = TREE_SCENE.instantiate()
			objects_root.add_child(tree)
			tree.global_position = cell_to_world(cell)


func _is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < world_width and cell.y < world_height


# ---------------------------------------------------------------------------
# Shop Stand spawning
# ---------------------------------------------------------------------------

## Places the NPC shop stand at a random walkable position near-ish the
## centre so the player almost always finds it within the first minute.
func _spawn_shop_stand() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + 7777

	# Pick a walkable cell within the inner ~60% of the island
	var centre_x := world_width / 2
	var centre_y := world_height / 2
	var radius := mini(world_width, world_height) / 5

	for attempt in 100:
		var cell := Vector2i(
			centre_x + rng.randi_range(-radius, radius),
			centre_y + rng.randi_range(-radius, radius)
		)
		if not _is_in_bounds(cell):
			continue

		var tile_id: String = _tile_grid[cell.y][cell.x] if cell.y < _tile_grid.size() and cell.x < _tile_grid[cell.y].size() else "water"
		var tile_type: TileTypeData = DataManager.get_tile_type(tile_id)
		if tile_type and tile_type.walkable and tile_type.tillable:
			# Make sure no resource node is already here
			var blocked := false
			for child in objects_root.get_children():
				if child.global_position.distance_squared_to(cell_to_world(cell)) < 64.0:
					blocked = true
					break
			if blocked:
				continue

			var stand: Area2D = SHOP_BUILDING_SCENE.instantiate()
			objects_root.add_child(stand)
			stand.global_position = cell_to_world(cell)
			return

	# Fallback: place at centre
	var fallback := SHOP_BUILDING_SCENE.instantiate()
	objects_root.add_child(fallback)
	fallback.global_position = cell_to_world(Vector2i(centre_x, centre_y))

## Places the Boat at the outermost coastline cell so the player can sell
## items there. Scans from the world edges inward so the boat always sits
## on the true outer coast of the island (not an interior pond).
func _spawn_boat() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + 8888

	var candidates: Array[Vector2i] = []

	# Scan perimeter bands from the outside in, collecting candidate cells
	# that are walkable sand tiles adjacent to water or edge tiles.
	for band in range(0, world_width / 4):
		var min_x := band
		var max_x := world_width - 1 - band
		var min_y := band
		var max_y := world_height - 1 - band

		# Top edge
		for x in range(min_x, max_x + 1):
			_add_boat_candidate(Vector2i(x, min_y), candidates)
		# Bottom edge
		for x in range(min_x, max_x + 1):
			_add_boat_candidate(Vector2i(x, max_y), candidates)
		# Left edge (excluding corners already done)
		for y in range(min_y + 1, max_y):
			_add_boat_candidate(Vector2i(min_x, y), candidates)
		# Right edge
		for y in range(min_y + 1, max_y):
			_add_boat_candidate(Vector2i(max_x, y), candidates)

		if not candidates.is_empty():
			break

	# Shuffle candidates and try to place the boat
	candidates.shuffle()
	for cell in candidates:
		# Make sure nothing is already here
		var blocked := false
		for child in objects_root.get_children():
			if child.global_position.distance_squared_to(cell_to_world(cell)) < 64.0:
				blocked = true
				break
		if blocked:
			continue

		var boat: Area2D = BOAT_SCENE.instantiate()
		objects_root.add_child(boat)
		boat.global_position = cell_to_world(cell)
		return

	# Fallback: scan outward in a square spiral for any walkable tile
	var centre_x := world_width / 2
	var centre_y := world_height / 2
	for r in range(1, world_width / 2):
		for sx in range(-r, r + 1):
			for sy in [-r, r]:
				var cell := Vector2i(centre_x + sx, centre_y + sy)
				if not _is_in_bounds(cell):
					continue
				var tile_id: String = _tile_grid[cell.y][cell.x] if cell.y < _tile_grid.size() and cell.x < _tile_grid[cell.y].size() else ""
				var tt: TileTypeData = DataManager.get_tile_type(tile_id)
				if tt and tt.walkable and not tile_id.begins_with("sand"):
					var boat_inst := BOAT_SCENE.instantiate()
					objects_root.add_child(boat_inst)
					boat_inst.global_position = cell_to_world(cell)
					return
	# Last resort absolute centre (should never reach here)
	var boat_last := BOAT_SCENE.instantiate()
	objects_root.add_child(boat_last)
	boat_last.global_position = cell_to_world(Vector2i(centre_x, centre_y))

## Helper: if the cell is a walkable sand tile adjacent to water, add it
## to the candidates list.
func _add_boat_candidate(cell: Vector2i, candidates: Array[Vector2i]) -> void:
	if not _is_in_bounds(cell):
		return
	var tile_id: String = _tile_grid[cell.y][cell.x] if cell.y < _tile_grid.size() and cell.x < _tile_grid[cell.y].size() else ""
	if tile_id != "sand":
		return
	# Must have a water or edge neighbor
	for d: Vector2i in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
		var nc: Vector2i = cell + d
		if not _is_in_bounds(nc):
			continue
		var nt: String = _tile_grid[nc.y][nc.x] if nc.y < _tile_grid.size() and nc.x < _tile_grid[nc.y].size() else "water"
		if nt == "water" or nt.begins_with("edge"):
			candidates.append(cell)
			return

## Spawns procedurally named animals with varied behaviours across
## walkable tiles of the island.
func _scatter_animals() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = world_seed + 10000
	var animal_count: int = rng.randi_range(4, 8)  # Increased from 3-6
	var animal_types: Array[String] = ["chicken", "cow", "rabbit", "deer", "goat", "pig", "sheep", "squirrel", "frog", "turtle"]
	var positions: Array = _generator.pick_object_positions(_tile_grid, animal_count, rng)
	for i in range(positions.size()):
		var p_type: String = animal_types[rng.randi() % animal_types.size()]
		var animal: Animal = ANIMAL_SCENE.instantiate()
		objects_root.add_child(animal)
		animal.setup(p_type, cell_to_world(positions[i]))

## Places starter buildings near the player spawn area so the world
## feels more inhabited. Uses BuildingSystem.place_building() which
## handles collision checks and visual node creation.
func _scatter_buildings() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + 33333
	
	# Player spawns at (world_width - 12, world_height / 2), so place
	# buildings in a cluster to the left/west of the spawn point.
	var spawn_cell := Vector2i(world_width - 18, world_height / 2)
	var buildings_to_place: Array[Dictionary] = [
		{"type": BuildingSystem.BuildingType.SMALL_HOME, "offset": Vector2i(-5, -2), "rot": 0},
		{"type": BuildingSystem.BuildingType.CAMPFIRE, "offset": Vector2i(-2, 3), "rot": 0},
		{"type": BuildingSystem.BuildingType.STORAGE_SHED, "offset": Vector2i(-2, -5), "rot": 0},
		{"type": BuildingSystem.BuildingType.DECORATIVE_BENCH, "offset": Vector2i(-4, 3), "rot": 0},
	]
	# Shuffle offsets a bit with the rng so placement varies per seed
	buildings_to_place.shuffle()
	
	for entry in buildings_to_place:
		var cell: Vector2i = spawn_cell + (entry["offset"] as Vector2i)
		var b_type: int = entry["type"] as int
		if _is_in_bounds(cell):
			var result: Dictionary = building_system.can_place(
				b_type, cell, entry["rot"] as int, _tile_grid, world_width, world_height
			)
			if result.get("valid", false):
				building_system.place_building(b_type, cell, entry["rot"] as int, self)
			else:
				# Fallback: scan for a nearby walkable tile
				var found := false
				for radius in range(1, 5):
					for dx in range(-radius, radius + 1):
						for dy in range(-radius, radius + 1):
							var try_cell: Vector2i = spawn_cell + (entry["offset"] as Vector2i) + Vector2i(dx, dy)
							if _is_in_bounds(try_cell):
								var try_result: Dictionary = building_system.can_place(
									b_type, try_cell, entry["rot"] as int, _tile_grid, world_width, world_height
								)
								if try_result.get("valid", false):
									building_system.place_building(b_type, try_cell, entry["rot"] as int, self)
									found = true
									break
						if found:
							break
					if found:
						break

## Scatters nature objects (bushes, flowers, mushrooms, stumps) across the
## world to make the environment feel more alive and varied.
func _scatter_nature_objects() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + 22222
	
	var bush_count := rng.randi_range(6, 12)
	var flower_count := rng.randi_range(8, 16)
	var mushroom_count := rng.randi_range(4, 8)
	var stump_count := rng.randi_range(3, 6)
	
	# Scatter on grass/dirt/fertile tiles only
	_scatter_nature_type(bush_count, "Bush", rng)
	_scatter_nature_type(flower_count, "FlowerPatch", rng)
	_scatter_nature_type(mushroom_count, "MushroomPatch", rng)
	_scatter_nature_type(stump_count, "LogStump", rng)

func _scatter_nature_type(count: int, type_name: String, rng: RandomNumberGenerator) -> void:
	var attempts := 0
	var placed := 0
	while placed < count and attempts < count * 30:
		attempts += 1
		var x := rng.randi_range(2, world_width - 3)
		var y := rng.randi_range(2, world_height - 3)
		var cell := Vector2i(x, y)
		
		if not _is_in_bounds(cell):
			continue
		
		var tile_id: String = _tile_grid[y][x]
		var tile_type := DataManager.get_tile_type(tile_id)
		if not tile_type or not tile_type.walkable:
			continue
		
		# Check not blocked by existing object
		var blocked := false
		var w_pos := cell_to_world(cell)
		for child in objects_root.get_children():
			if child.global_position.distance_squared_to(w_pos) < 64.0:
				blocked = true
				break
		if blocked:
			continue
		
		var node: Area2D = null
		match type_name:
			"Bush":
				var script := load(BUSH_SCENE_PATH) as GDScript
				if script:
					node = Area2D.new()
					node.set_script(script)
					node.name = "Bush_%d_%d" % [x, y]
			"FlowerPatch":
				var script := load(FLOWER_SCENE_PATH) as GDScript
				if script:
					node = Area2D.new()
					node.set_script(script)
					node.name = "Flower_%d_%d" % [x, y]
			"MushroomPatch":
				var script := load(MUSHROOM_SCENE_PATH) as GDScript
				if script:
					node = Area2D.new()
					node.set_script(script)
					node.name = "Mushroom_%d_%d" % [x, y]
			"LogStump":
				var script := load(LOG_STUMP_SCENE_PATH) as GDScript
				if script:
					node = Area2D.new()
					node.set_script(script)
					node.name = "Stump_%d_%d" % [x, y]
		
		if node:
			var sprite := Sprite2D.new()
			sprite.name = "Sprite2D"
			node.add_child(sprite)
			objects_root.add_child(node)
			node.global_position = w_pos
			placed += 1

# ---------------------------------------------------------------------------
# Build Mode (player-facing building placement)
# ---------------------------------------------------------------------------

## Attempts to enter build mode. Returns true if a building item is available.
func enter_build_mode() -> bool:
	if build_mode_active:
		return true
	
	# Scan inventory for any placeable building material
	for item_id: String in BUILD_ITEM_TO_TYPE:
		if InventoryManager.has_item(item_id, 1):
			build_item_id = item_id
			build_type = BUILD_ITEM_TO_TYPE[item_id]
			build_mode_active = true
			ToastNotification.show_toast("Build mode [V]: point at a tile and press [E] to place", ToastNotification.ToastType.INFO, 3.5)
			# Also show a persistent hint
			_show_hud_hint("Build mode active — move cursor and press E to place")
			return true
	
	# No materials — give unmistakable persistent feedback so the player can't miss it
	ToastNotification.show_toast("⚠ No building materials! Craft fence or campfire from the Crafting menu [C] first", ToastNotification.ToastType.ERROR, 5.0)
	_show_hud_hint("Need fence_material, stone_fence_material, or campfire_kit — press C to craft then V to build")
	return false

## Exits build mode and clears the preview.
func exit_build_mode() -> void:
	build_mode_active = false
	build_item_id = ""
	build_type = BuildingSystem.BuildingType.NONE
	_clear_tool_preview()

## Shows a persistent tutorial-style hint on the HUD (auto-hides after 5s).
func _show_hud_hint(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_tutorial_hint"):
		hud.show_tutorial_hint(text)

## Toggles build mode on/off. Returns the new state.
func toggle_build_mode() -> bool:
	if build_mode_active:
		exit_build_mode()
		return false
	return enter_build_mode()

## Places the current building at the given tile cell if valid.
## Consumes the building item from inventory on success.
func try_place_building(cell: Vector2i) -> bool:
	if not build_mode_active or build_type == BuildingSystem.BuildingType.NONE:
		return false
	if not _is_in_bounds(cell):
		ToastNotification.show_toast("Out of bounds!", ToastNotification.ToastType.ERROR)
		return false
	if not InventoryManager.has_item(build_item_id, 1):
		exit_build_mode()
		ToastNotification.show_toast("Out of building materials!", ToastNotification.ToastType.ERROR)
		return false
	
	var result: Dictionary = building_system.can_place(build_type, cell, 0, _tile_grid, world_width, world_height)
	if not result.get("valid", false):
		ToastNotification.show_toast(result.get("reason", "Cannot place here!"), ToastNotification.ToastType.ERROR)
		return false
	
	building_system.place_building(build_type, cell, 0, self)
	InventoryManager.remove_item(build_item_id, 1)
	
	var data: Dictionary = BuildingSystem.BUILDING_DATA.get(build_type, {})
	var name_str: String = data.get("name", "Building")
	ToastNotification.show_toast("Placed %s!" % name_str, ToastNotification.ToastType.SUCCESS)
	
	# Exit build mode after successful placement
	exit_build_mode()
	return true

# ---------------------------------------------------------------------------
# System accessors for save/load and other systems
# ---------------------------------------------------------------------------

## Returns the BuildingSystem reference for save/load and building interaction
func get_building_system() -> BuildingSystem:
	return building_system

## Returns the CookingSystem reference for cooking UI
func get_cooking_system() -> CookingSystem:
	return cooking_system

## Set the cooking system from save data
func set_cooking_system(cs: CookingSystem) -> void:
	cooking_system = cs

## Returns whether build mode is currently active.
func get_build_mode_state() -> bool:
	return build_mode_active

# Current interior scene the player is inside (null if outside)
var current_interior: BuildingInterior = null
var _exit_cooldown: bool = false  # prevents re-entering briefly after exit

## Enter a building interior. Called when the player walks into a building.
var _outside_player_pos: Vector2 = Vector2.ZERO  # where to return the player on exit
var _previous_player_z: int = 0  # z_index to restore on exit

# Void location for interior rendering — far from world tiles so nothing shows through
const INTERIOR_VOID := Vector2(10000, 10000)
const INTERIOR_SCALE := 1.0

func enter_building(interior: BuildingInterior) -> void:
	if current_interior:
		return  # already inside
	if _exit_cooldown:
		return  # just exited, brief cooldown
	
	current_interior = interior
	
	# Defer the scene tree changes to avoid "flushing queries" error
	# (called from Area2D.body_entered physics callback)
	call_deferred("_deferred_setup_interior", interior)

	# Player setup (non-deferred — position/velocity changes are safe)
	var player := get_tree().get_first_node_in_group("player")
	if player:
		_outside_player_pos = player.global_position
		if player is CharacterBody2D:
			player.velocity = Vector2.ZERO
		# Player renders above room floor
		_previous_player_z = player.z_index
		player.z_index = 2
		# Place player in the center of the room (NOT at the exit door to avoid instant exit)
		player.global_position = INTERIOR_VOID + Vector2(40, 36) * INTERIOR_SCALE
		player.visible = true
		player.set_process(true)
		player.set_physics_process(true)
	
	# Fade transition (safe to call anytime)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("fade_to_black"):
		hud.fade_to_black(0.3)

func _deferred_setup_interior(interior: BuildingInterior) -> void:
	if not is_instance_valid(interior):
		return
	interior.position = INTERIOR_VOID
	interior.scale = Vector2(INTERIOR_SCALE, INTERIOR_SCALE)
	add_child(interior)
	interior.exited_interior.connect(_on_exit_interior)

func _on_exit_interior() -> void:
	current_interior = null
	# Brief cooldown so the player doesn't immediately re-enter the building
	_exit_cooldown = true
	get_tree().create_timer(0.5).timeout.connect(func(): _exit_cooldown = false)
	
	# Fade transition
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("fade_to_black"):
		hud.fade_to_black(0.3)
	
	# Move player back outside
	var player := get_tree().get_first_node_in_group("player")
	if player:
		if _outside_player_pos != Vector2.ZERO:
			player.global_position = _outside_player_pos
		if player is CharacterBody2D:
			player.velocity = Vector2.ZERO
		player.z_index = _previous_player_z
		player.visible = true
		player.set_process(true)
		player.set_physics_process(true)
