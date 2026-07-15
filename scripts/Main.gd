extends Node2D

## Entry point for the game scene. Deliberately thin: it only wires together
## the already-independent World, Player, and HUD nodes. Add new top-level
## systems (weather, NPC manager, save/load trigger, etc.) here as siblings
## rather than growing this script into a monolith.

@onready var world: Node2D = $World
@onready var player: CharacterBody2D = $Player
@onready var hud: CanvasLayer = $HUD

func _ready() -> void:
	_position_player_at_spawn()
	
	if hud and hud.has_signal("regenerate_world_requested"):
		hud.regenerate_world_requested.connect(world.generate_world_with_seed)
		if hud.has_method("set_seed_display"):
			hud.set_seed_display(world.world_seed)

func _position_player_at_spawn() -> void:
	if world and world.has_method("cell_to_world"):
		var spawn_cell := Vector2i(world.world_width / 2, world.world_height / 2)
		player.global_position = world.cell_to_world(spawn_cell)
