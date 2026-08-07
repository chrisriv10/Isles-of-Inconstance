extends CanvasLayer
class_name MineMinimap

## Always-on corner minimap shown while the player is inside a mine.
## Renders that peer's own deterministic mine floor (each peer generates an
## identical grid from the shared seed), so it is purely local, read-only UI:
## it never mutates state, sends no RPCs, and cannot interfere with the
## host-authoritative enemy/session sync.
##
## Multiplayer notes:
## - Draws from this peer's local `World.current_mine_room` (same grid on every
##   peer thanks to deterministic generation).
## - Tracks ONLY the local player via `_is_local_player()` so the marker never
##   jumps to a remote player doll.
## - Show/hide is driven by GameManager.inside_mine (set/cleared per peer on
##   enter/descend/exit), so it does not persist after leaving the mine.
## - Non-blocking: the panel and map pass through mouse input except the
##   minimize/expand buttons, so it never steals clicks from the HUD/game.

## Pixels per tile on the minimap (64x48 grid → 192x144 image).
const TILE_PX: int = 3

const FLOOR_COLOR := Color(0.18, 0.16, 0.14)
const DEEPER_COLOR := Color(0.25, 0.20, 0.16)
const WALL_COLOR := Color(0.05, 0.05, 0.06)
const WATER_COLOR := Color(0.04, 0.06, 0.18)
const UNKNOWN_COLOR := Color(0.0, 0.0, 0.0, 0.0)

@onready var root: Control = $Root
@onready var panel: PanelContainer = $Root/Panel
@onready var title_label: Label = $Root/Panel/Margin/VBox/Header/Title
@onready var map_container: Control = $Root/Panel/Margin/VBox/MapContainer
@onready var map_texture: TextureRect = $Root/Panel/Margin/VBox/MapContainer/MapTexture
@onready var player_marker: ColorRect = $Root/Panel/Margin/VBox/MapContainer/PlayerMarker
@onready var exit_marker: ColorRect = $Root/Panel/Margin/VBox/MapContainer/ExitMarker
@onready var shaft_marker: ColorRect = $Root/Panel/Margin/VBox/MapContainer/ShaftMarker
@onready var expand_button: Button = $Root/ExpandBtn

var _map_image: Image = null
var _map_texture_obj: ImageTexture = null
var _native_size: Vector2 = Vector2.ZERO
var _rendered_depth: int = -1
var _minimized: bool = false


func _ready() -> void:
	root.visible = false
	$Root/Panel/Margin/VBox/Header/MinimizeBtn.pressed.connect(_on_minimize_pressed)
	expand_button.pressed.connect(_on_expand_pressed)
	_apply_minimize_state()


func _process(_delta: float) -> void:
	var world := get_tree().get_first_node_in_group("world") as Node
	var room: Node = world.get_current_mine_room() if world and world.has_method("get_current_mine_room") else null

	# Show only while this peer is actually inside the mine and holds a valid
	# room. Hiding on !inside_mine (and when the room is freed on exit/descent)
	# guarantees the minimap never persists after leaving the mine.
	if not GameManager.inside_mine or not room or not is_instance_valid(room):
		root.visible = false
		_rendered_depth = -1
		return

	root.visible = true
	if _minimized:
		return

	var depth: int = int(room.get("depth_level"))
	if depth != _rendered_depth or _map_texture_obj == null:
		_render_floor(room)
	title_label.text = "Mine — Floor %d" % depth
	_update_markers(room)


## Rebuild the tile map image from this peer's local generator grid.
func _render_floor(room: Node) -> void:
	var generator: RefCounted = room.get("generator") as RefCounted
	if not generator or not (generator.get("grid") is Array):
		return
	var grid: Array = generator.get("grid")
	if grid.is_empty():
		return
	var g_h: int = grid.size()
	var g_w: int = (grid[0] as Array).size()
	var img_w: int = g_w * TILE_PX
	var img_h: int = g_h * TILE_PX

	_map_image = Image.create(img_w, img_h, false, Image.FORMAT_RGBA8)
	_map_image.fill(UNKNOWN_COLOR)
	for y in range(g_h):
		var row: Array = grid[y]
		for x in range(g_w):
			var color: Color = WALL_COLOR
			match str(row[x]):
				&"mine_floor":
					color = FLOOR_COLOR
				&"mine_deeper":
					color = DEEPER_COLOR
				&"mine_water":
					color = WATER_COLOR
			for dy in range(TILE_PX):
				for dx in range(TILE_PX):
					_map_image.set_pixel(x * TILE_PX + dx, y * TILE_PX + dy, color)

	_map_texture_obj = ImageTexture.create_from_image(_map_image)
	map_texture.texture = _map_texture_obj
	_native_size = Vector2(img_w, img_h)
	_rendered_depth = int(room.get("depth_level"))


## Position the player / exit / shaft markers over the map texture.
func _update_markers(room: Node) -> void:
	var map_size := map_container.size
	if map_size.x <= 0.0 or map_size.y <= 0.0:
		return

	# Player marker — always the LOCAL player so it doesn't follow a remote doll.
	var local_player: Node = null
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and _is_local_player(p):
			local_player = p
			break
	if local_player and room.has_method("to_local"):
		var local_pos: Vector2 = room.to_local(local_player.global_position)
		player_marker.position = _to_map(local_pos, map_size)
		player_marker.visible = true
	else:
		player_marker.visible = false

	# Exit ladder and descent shaft are child nodes with readable positions.
	var exit_node: Node = room.get_node_or_null("MineExit")
	if exit_node:
		exit_marker.position = _to_map(exit_node.position, map_size)
		exit_marker.visible = true
	else:
		exit_marker.visible = false

	var shaft_node: Node = room.get_node_or_null("DescentShaft")
	if shaft_node:
		shaft_marker.position = _to_map(shaft_node.position, map_size)
		shaft_marker.visible = true
	else:
		shaft_marker.visible = false


## Convert a room-local world position (px) to map-container coordinates.
func _to_map(world_pos: Vector2, map_size: Vector2) -> Vector2:
	if _native_size.x <= 0.0 or _native_size.y <= 0.0:
		return Vector2.ZERO
	# World px (16px/tile) → image px (TILE_PX/tile), then scale to the
	# container's displayed size (the texture is KEEP_ASPECT_CENTERED).
	var img_x: float = world_pos.x * (TILE_PX / 16.0)
	var img_y: float = world_pos.y * (TILE_PX / 16.0)
	var scale_x: float = map_size.x / _native_size.x
	var scale_y: float = map_size.y / _native_size.y
	return Vector2(img_x * scale_x, img_y * scale_y)


## Same authority check used by World.gd: true for our own player.
func _is_local_player(player: Node) -> bool:
	if not NetworkManager.is_network_active():
		return true
	return int(player.get_multiplayer_authority()) == multiplayer.get_unique_id()


func _on_minimize_pressed() -> void:
	_minimized = true
	_apply_minimize_state()


func _on_expand_pressed() -> void:
	_minimized = false
	_apply_minimize_state()


func _apply_minimize_state() -> void:
	panel.visible = not _minimized
	expand_button.visible = _minimized