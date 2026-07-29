## Physical dock structure placed at the coastline where ships dock.
## A large walkable wooden pier extending from the shore into the water,
## with multiple berths for merchant boat, pirate ship, and future ships.
## Includes collision so the player can walk on the dock.

extends Node2D
class_name Dock

## Dock dimensions in pixels (the full platform size)
const DOCK_WIDTH: int = 384
const DOCK_HEIGHT: int = 192
## How far the dock extends from its anchor point toward the water
const DOCK_EXTEND: int = 128

## Berth positions relative to the dock's global_position.
## Ships are placed at these positions to dock alongside the pier.
## Berth 0 = expedition travel boat (Captain Briggs) — left side
## Berth 1 = pirate ship (center)
## Berth 2 = visitor ship (opposite side, above-left of dock)
## Berth 3 = merchant boat (Captain Marlin) — far right
const BERTH_POSITIONS: Array[Vector2] = [
	Vector2(-148, 60),   # Berth 0: left side — expedition (Captain Briggs)
	Vector2(0, 60),      # Berth 1: center  — pirate ship
	Vector2(-80, -60),   # Berth 2: above-left — visitor ship (opposite side from pirate)
	Vector2(155, 60),    # Berth 3: far right — merchant boat (Captain Marlin)
]

## (Gangplank removed — dock now sits flush with the coastline)

func _ready() -> void:
	add_to_group("walkable")
