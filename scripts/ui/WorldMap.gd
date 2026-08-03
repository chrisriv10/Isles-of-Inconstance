extends CanvasLayer
class_name WorldMap

## World map overlay showing a top-down pixel view of the world's biomes,
## player position, and building locations. Toggled with M key.
## Uses persistent exploration: cells the player walks near are permanently
## revealed on the map. The Bird pet's "scout" bonus reveals the entire map.

const EXPLORE_RADIUS: int = 15  # cells around player that get revealed each step

var is_open: bool = false

## Explored cells tracked as a Dictionary for O(1) lookup: "x,y" → true.
## Persisted with the save system so exploration carries across sessions.
var explored: Dictionary = {}

# Display-name → color for all 16 biomes
const BIOME_COLORS: Dictionary = {
	"Plains": Color(0.45, 0.72, 0.32),
	"Forest": Color(0.18, 0.45, 0.18),
	"Dense Forest": Color(0.10, 0.35, 0.12),
	"Swamp": Color(0.32, 0.42, 0.30),
	"Mountain": Color(0.52, 0.42, 0.30),
	"Rocky Hills": Color(0.60, 0.50, 0.35),
	"Beach": Color(0.80, 0.75, 0.50),
	"Meadow": Color(0.62, 0.82, 0.32),
	"Flower Fields": Color(0.70, 0.75, 0.50),
	"Pine Forest": Color(0.15, 0.40, 0.28),
	"Cherry Grove": Color(0.85, 0.55, 0.55),
	"Savanna": Color(0.70, 0.60, 0.25),
	"Autumn Forest": Color(0.65, 0.50, 0.20),
	"Snow Fields": Color(0.85, 0.88, 0.92),
	"Wetlands": Color(0.35, 0.55, 0.50),
	"Jungle": Color(0.15, 0.55, 0.25),
}

const WATER_COLOR: Color = Color(0.2, 0.3, 0.6)
const UNKNOWN_COLOR: Color = Color(0.08, 0.08, 0.1)

const MAP_SCALE: int = 4  # pixels per cell (main world: 100×100 → 400×400)
const EXPEDITION_MAP_SCALE: int = 10  # pixels per cell (expedition: 50×50 → 500×500)

@onready var dim: ColorRect = $Dim
@onready var panel: PanelContainer = $Panel
@onready var map_texture: TextureRect = $Panel/Margin/VBox/MapContainer/MapTexture
@onready var player_marker: ColorRect = $Panel/Margin/VBox/MapContainer/PlayerMarker
@onready var legend_container: VBoxContainer = $Panel/Margin/VBox/Legend
@onready var title_label: Label = $Panel/Margin/VBox/Title

var _map_image: Image = null
var _map_texture_obj: ImageTexture = null


func _ready() -> void:
	dim.visible = false
	panel.visible = false
	_start_exploration_timer()


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func open() -> void:
	is_open = true
	AudioManager.play(AudioManager.Sound.MENU_OPEN)
	dim.visible = true
	panel.visible = true
	_record_surrounding_cells()
	_render_map()
	_update_player_marker()


func close() -> void:
	is_open = false
	AudioManager.play(AudioManager.Sound.MENU_CLOSE)
	dim.visible = false
	panel.visible = false


func _render_map() -> void:
	var world: Node = get_tree().get_first_node_in_group("world")
	if not world:
		return

	# ── Expedition island override ──────────────────────────────
	var expedition: Node = get_tree().get_first_node_in_group("expedition_island")
	if expedition and expedition.has_method("get_island_cell_color"):
		_render_expedition_island(expedition)
		return
	# ── End expedition island override ──────────────────────────

	var w: int = world.world_width
	var h: int = world.world_height
	var img_w: int = w * MAP_SCALE
	var img_h: int = h * MAP_SCALE

	# Bird pet scout reveals the full map
	var full_reveal: bool = false
	if Engine.has_singleton("PetManager"):
		var pm = Engine.get_singleton("PetManager")
		if pm and pm.has_method("get_scout_bonus"):
			full_reveal = pm.get_scout_bonus() > 0.0

	# If scout is active, mark every cell as explored immediately
	if full_reveal:
		for y in range(h):
			for x in range(w):
				var key := "%d,%d" % [x, y]
				if not explored.has(key):
					explored[key] = true

	_map_image = Image.create(img_w, img_h, false, Image.FORMAT_RGBA8)

	for y in range(h):
		for x in range(w):
			var biome_def = world.get_biome_definition_at(x, y) if world.has_method("get_biome_definition_at") else null
			var biome_type: int = world.get_biome_at(x, y)
			var is_explored: bool = explored.has("%d,%d" % [x, y])

			var color: Color
			if biome_type < 0:
				color = WATER_COLOR
			elif biome_def and BIOME_COLORS.has(biome_def.display_name):
				color = BIOME_COLORS[biome_def.display_name]
			else:
				color = UNKNOWN_COLOR

			if not is_explored:
				color = UNKNOWN_COLOR

			for dy in range(MAP_SCALE):
				for dx in range(MAP_SCALE):
					_map_image.set_pixel(x * MAP_SCALE + dx, y * MAP_SCALE + dy, color)

	# Helper: returns true if the cell has been explored
	var _is_explored := func(c: Vector2i) -> bool:
		return explored.has("%d,%d" % [c.x, c.y])

	# Mark buildings as small dots — only if explored
	if world.has_method("get_building_system"):
		var bs = world.get_building_system()
		if bs:
			for b in bs.placed_buildings:
				var b_cell: Vector2i = b.get("cell", Vector2i(0, 0))
				if not _is_explored.call(b_cell):
					continue
				var cx := b_cell.x * MAP_SCALE + MAP_SCALE / 2
				var cy := b_cell.y * MAP_SCALE + MAP_SCALE / 2
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var px := clampi(cx + dx, 0, img_w - 1)
						var py := clampi(cy + dy, 0, img_h - 1)
						_map_image.set_pixel(px, py, Color(0.9, 0.7, 0.3))

	# Draw shop marker (5x5 green dot) — only if explored
	if world.has_method("get_shop_position"):
		var shop_pos: Vector2 = world.get_shop_position()
		var shop_cell: Vector2i = world.world_to_cell(shop_pos)
		if _is_explored.call(shop_cell):
			var scx := shop_cell.x * MAP_SCALE + MAP_SCALE / 2
			var scy := shop_cell.y * MAP_SCALE + MAP_SCALE / 2
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					var px := clampi(scx + dx, 0, img_w - 1)
					var py := clampi(scy + dy, 0, img_h - 1)
					_map_image.set_pixel(px, py, Color(0.2, 0.9, 0.3))

	# Draw dock marker (7x7 brown dot) — only if explored
	if world.has_method("get_dock_position"):
		var dock_pos: Vector2 = world.get_dock_position()
		var dock_cell: Vector2i = world.world_to_cell(dock_pos)
		if _is_explored.call(dock_cell):
			var dcx := dock_cell.x * MAP_SCALE + MAP_SCALE / 2
			var dcy := dock_cell.y * MAP_SCALE + MAP_SCALE / 2
			for dy in range(-3, 4):
				for dx in range(-3, 4):
					var px := clampi(dcx + dx, 0, img_w - 1)
					var py := clampi(dcy + dy, 0, img_h - 1)
					_map_image.set_pixel(px, py, Color(0.55, 0.35, 0.15))

	# Draw mine entrance markers (5x5 purple dots) — only if explored
	if world.has_method("get_mine_entrance_positions"):
		var mine_positions: Array[Vector2] = world.get_mine_entrance_positions()
		for mine_pos in mine_positions:
			var mine_cell: Vector2i = world.world_to_cell(mine_pos)
			if _is_explored.call(mine_cell):
				var mx := mine_cell.x * MAP_SCALE + MAP_SCALE / 2
				var my := mine_cell.y * MAP_SCALE + MAP_SCALE / 2
				for dy in range(-2, 3):
					for dx in range(-2, 3):
						var px := clampi(mx + dx, 0, img_w - 1)
						var py := clampi(my + dy, 0, img_h - 1)
						_map_image.set_pixel(px, py, Color(0.6, 0.3, 0.8))

	# Draw boat marker (3x3 blue dot) — only if explored
	if world.has_method("get_boat_position"):
		var boat_pos: Vector2 = world.get_boat_position()
		var boat_cell: Vector2i = world.world_to_cell(boat_pos)
		if _is_explored.call(boat_cell):
			var bcx := boat_cell.x * MAP_SCALE + MAP_SCALE / 2
			var bcy := boat_cell.y * MAP_SCALE + MAP_SCALE / 2
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var px := clampi(bcx + dx, 0, img_w - 1)
					var py := clampi(bcy + dy, 0, img_h - 1)
					_map_image.set_pixel(px, py, Color(0.3, 0.6, 1.0))

	_map_texture_obj = ImageTexture.create_from_image(_map_image)
	map_texture.texture = _map_texture_obj

	# Set map container size (capped so it fits the shrunk panel; the map
	# texture scales down to fit via KEEP_ASPECT_CENTERED)
	var map_container: Control = $Panel/Margin/VBox/MapContainer
	map_container.custom_minimum_size = Vector2(mini(img_w, 320), mini(img_h, 320))

	# Build legend
	_build_legend()


## Render a compact 50x50 map for the expedition island
## instead of the full world map. Auto-reveals the whole island.
func _render_expedition_island(expedition: Node) -> void:
	# Use a higher scale so expedition islands fill the panel (vs the main world
	# which uses MAP_SCALE=4 on 100x100 cells, giving a 400x400 image).
	var s: int = EXPEDITION_MAP_SCALE  # 50 × 10 = 500×500
	var img_w: int = 50 * s  # ISLAND_W
	var img_h: int = 50 * s  # ISLAND_H

	_map_image = Image.create(img_w, img_h, false, Image.FORMAT_RGBA8)
	_map_image.fill(UNKNOWN_COLOR)

	for y in range(50):
		for x in range(50):
			var color: Color = expedition.get_island_cell_color(x, y)
			if color.a == 0.0:
				color = UNKNOWN_COLOR
			for dy in range(s):
				for dx in range(s):
					_map_image.set_pixel(x * s + dx, y * s + dy, color)

	_map_texture_obj = ImageTexture.create_from_image(_map_image)
	map_texture.texture = _map_texture_obj

	# Set map container size (capped so it fits the shrunk panel)
	var map_container: Control = $Panel/Margin/VBox/MapContainer
	map_container.custom_minimum_size = Vector2(mini(img_w, 320), mini(img_h, 320))


	# Update title
	title_label.text = "Expedition: " + expedition.get_island_type_name()

	# No legend
	for child in legend_container.get_children():
		child.queue_free()


func _build_legend() -> void:
	for child in legend_container.get_children():
		child.queue_free()

	var legend_title := Label.new()
	legend_title.text = "Legend"
	legend_title.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	legend_title.add_theme_font_size_override("font_size", 11)
	legend_container.add_child(legend_title)

	var biome_names: Array[String] = []
	for k in BIOME_COLORS.keys():
		biome_names.append(k)
	biome_names.sort()
	for bname in biome_names:
		var row := HBoxContainer.new()
		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(12, 12)
		swatch.color = BIOME_COLORS[bname]
		row.add_child(swatch)

		var label := Label.new()
		label.text = bname
		label.add_theme_font_size_override("font_size", 10)
		label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		row.add_child(label)
		legend_container.add_child(row)

	# Water and player
	var water_row := HBoxContainer.new()
	var water_swatch := ColorRect.new()
	water_swatch.custom_minimum_size = Vector2(12, 12)
	water_swatch.color = WATER_COLOR
	water_row.add_child(water_swatch)
	var water_label := Label.new()
	water_label.text = "Water"
	water_label.add_theme_font_size_override("font_size", 10)
	water_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	water_row.add_child(water_label)
	legend_container.add_child(water_row)

	var player_row := HBoxContainer.new()
	var player_swatch := ColorRect.new()
	player_swatch.custom_minimum_size = Vector2(12, 12)
	player_swatch.color = Color(1, 1, 1)
	player_row.add_child(player_swatch)
	var player_label := Label.new()
	player_label.text = "Player"
	player_label.add_theme_font_size_override("font_size", 10)
	player_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	player_row.add_child(player_label)
	legend_container.add_child(player_row)

	var bld_row := HBoxContainer.new()
	var bld_swatch := ColorRect.new()
	bld_swatch.custom_minimum_size = Vector2(12, 12)
	bld_swatch.color = Color(0.9, 0.7, 0.3)
	bld_row.add_child(bld_swatch)
	var bld_label := Label.new()
	bld_label.text = "Buildings"
	bld_label.add_theme_font_size_override("font_size", 10)
	bld_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	bld_row.add_child(bld_label)
	legend_container.add_child(bld_row)

	# Shop
	var shop_row := HBoxContainer.new()
	var shop_swatch := ColorRect.new()
	shop_swatch.custom_minimum_size = Vector2(12, 12)
	shop_swatch.color = Color(0.2, 0.9, 0.3)
	shop_row.add_child(shop_swatch)
	var shop_label := Label.new()
	shop_label.text = "Shop"
	shop_label.add_theme_font_size_override("font_size", 10)
	shop_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	shop_row.add_child(shop_label)
	legend_container.add_child(shop_row)

	# Mine
	var mine_row := HBoxContainer.new()
	var mine_swatch := ColorRect.new()
	mine_swatch.custom_minimum_size = Vector2(12, 12)
	mine_swatch.color = Color(0.6, 0.3, 0.8)
	mine_row.add_child(mine_swatch)
	var mine_label := Label.new()
	mine_label.text = "Mine"
	mine_label.add_theme_font_size_override("font_size", 10)
	mine_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	mine_row.add_child(mine_label)
	legend_container.add_child(mine_row)

	# Dock
	var dock_row := HBoxContainer.new()
	var dock_swatch := ColorRect.new()
	dock_swatch.custom_minimum_size = Vector2(12, 12)
	dock_swatch.color = Color(0.55, 0.35, 0.15)
	dock_row.add_child(dock_swatch)
	var dock_label := Label.new()
	dock_label.text = "Dock"
	dock_label.add_theme_font_size_override("font_size", 10)
	dock_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	dock_row.add_child(dock_label)
	legend_container.add_child(dock_row)

	# Boat
	var boat_row := HBoxContainer.new()
	var boat_swatch := ColorRect.new()
	boat_swatch.custom_minimum_size = Vector2(12, 12)
	boat_swatch.color = Color(0.3, 0.6, 1.0)
	boat_row.add_child(boat_swatch)
	var boat_label := Label.new()
	boat_label.text = "Boat"
	boat_label.add_theme_font_size_override("font_size", 10)
	boat_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	boat_row.add_child(boat_label)
	legend_container.add_child(boat_row)


func _update_player_marker() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		player_marker.visible = false
		return

	# Expedition island: player position is relative to the island's GroundLayer.
	# Must use EXPEDITION_MAP_SCALE to match _render_expedition_island().
	var expedition: Node = get_tree().get_first_node_in_group("expedition_island")
	if expedition:
		var island_vp: Vector2 = expedition.to_local(player.global_position)
		var cell_x := int(floor(island_vp.x / 16.0))
		var cell_y := int(floor(island_vp.y / 16.0))
		var px := cell_x * EXPEDITION_MAP_SCALE
		var py := cell_y * EXPEDITION_MAP_SCALE
		var display_size := map_texture.get_size()
		var native_w: int = 50 * EXPEDITION_MAP_SCALE  # ISLAND_W
		var native_h: int = 50 * EXPEDITION_MAP_SCALE  # ISLAND_H
		if display_size.x > 0 and display_size.y > 0 and native_w > 0 and native_h > 0:
			var scale_x := display_size.x / float(native_w)
			var scale_y := display_size.y / float(native_h)
			player_marker.position = Vector2(px * scale_x, py * scale_y)
		else:
			player_marker.position = Vector2(px, py)
		player_marker.visible = true
		player_marker.modulate = Color(1, 1, 1, 1.0)
		return

	var world: Node = get_tree().get_first_node_in_group("world")
	if not world or not world.has_method("world_to_cell"):
		player_marker.visible = false
		return

	var cell: Vector2i = world.world_to_cell(player.global_position)
	var px := cell.x * MAP_SCALE
	var py := cell.y * MAP_SCALE

	# Scale marker position to match the displayed texture size
	var display_size := map_texture.get_size()
	var native_w: int = world.world_width * MAP_SCALE
	var native_h: int = world.world_height * MAP_SCALE
	if display_size.x > 0 and display_size.y > 0 and native_w > 0 and native_h > 0:
		var scale_x := display_size.x / float(native_w)
		var scale_y := display_size.y / float(native_h)
		var tex_offset := Vector2(
			abs(display_size.x - native_w * scale_x) * 0.5,
			abs(display_size.y - native_h * scale_y) * 0.5
		)
		player_marker.position = Vector2(px * scale_x, py * scale_y) + tex_offset
	else:
		player_marker.position = Vector2(px, py)
	player_marker.visible = true
	player_marker.modulate = Color(1, 1, 1, 1.0)


## Reveal a circular area of the map centered on a cell.
## Used by LibraryResearch to reveal fog around the player.
func reveal_area(center_cell: Vector2i, radius: int) -> void:
	var r_sq: int = radius * radius
	var world: Node = get_tree().get_first_node_in_group("world")
	var world_w: int = world.world_width if world else 100
	var world_h: int = world.world_height if world else 100
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var cx: int = center_cell.x + dx
			var cy: int = center_cell.y + dy
			if cx < 0 or cy < 0 or cx >= world_w or cy >= world_h:
				continue
			if dx * dx + dy * dy <= r_sq:
				explored["%d,%d" % [cx, cy]] = true
	if is_open:
		_render_map()

## Reveal the entire expedition island (50×50 cells) on the map.
## Expedition islands are auto-revealed in their render, but this marks
## the world cells as explored for persistence and future use.
func reveal_island() -> void:
	var expedition := get_tree().get_first_node_in_group("expedition_island")
	if expedition:
		# Mark all 50x50 island cells as explored
		for y in range(50):
			for x in range(50):
				explored["%d,%d" % [x, y]] = true
	if is_open:
		_render_map()

func _record_surrounding_cells() -> void:
	## Mark all cells within EXPLORE_RADIUS of the player as explored.
	var player := get_tree().get_first_node_in_group("player")
	# Don't record exploration when on an expedition island
	if get_tree().get_first_node_in_group("expedition_island"):
		return
	var world: Node = get_tree().get_first_node_in_group("world")
	if not player or not world or not world.has_method("world_to_cell"):
		return
	var cell: Vector2i = world.world_to_cell(player.global_position)
	var r_sq: int = EXPLORE_RADIUS * EXPLORE_RADIUS
	for dy in range(-EXPLORE_RADIUS, EXPLORE_RADIUS + 1):
		for dx in range(-EXPLORE_RADIUS, EXPLORE_RADIUS + 1):
			var cx: int = cell.x + dx
			var cy: int = cell.y + dy
			if cx < 0 or cy < 0 or cx >= world.world_width or cy >= world.world_height:
				continue
			if dx * dx + dy * dy <= r_sq:
				explored["%d,%d" % [cx, cy]] = true


func _start_exploration_timer() -> void:
	## Every 2 seconds, record the player's current surroundings.
	## Stops firing when the map is fully explored.
	var timer := Timer.new()
	timer.name = "ExplorationTimer"
	timer.wait_time = 2.0
	timer.autostart = true
	add_child(timer)
	timer.timeout.connect(_on_exploration_tick)


func _on_exploration_tick() -> void:
	## If the player exists, record explored cells in the current surroundings.
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return
	_record_surrounding_cells()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and is_open:
			close()
			get_viewport().set_input_as_handled()
