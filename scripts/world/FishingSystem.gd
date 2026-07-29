class_name FishingSystem
extends Node

## Fishing system for Isles of Inconstance.
## Player equips fishing rod, stands near water, and presses use.
## A casting minigame plays: wait for a bite, then reel in.

signal fish_caught(fish_item_id: String)

enum FishingState {
	IDLE,
	CASTING,
	WAITING,
	REELING,
}

var state: FishingState = FishingState.IDLE
var _cast_timer: float = 0.0
var _wait_time: float = 0.0
var _bite_chance: float = 0.0
var _reel_progress: float = 0.0
var _reel_target: float = 5.0
var _fish_item_id: String = ""
var _player_ref: Node2D = null
var _start_fishing_position: Vector2 = Vector2.ZERO
var _rng: RandomNumberGenerator

## Fish table: item_id -> {"min_weight":0..1, "max_weight":0..1, "bite_time":2..8}
## Higher weight = rarer. Bite time = seconds to wait for bite.
var _fish_table: Array[Dictionary] = []


func _init() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.randomize()
	_build_fish_table()


func _build_fish_table() -> void:
	_fish_table = [
		# Common fish (weight 0.0-0.6)
		{"item_id": "raw_fish", "name": "Raw Fish", "min_weight": 0.0, "max_weight": 0.5, "bite_time": 3.0, "sell_price": 8},
		{"item_id": "carp", "name": "Carp", "min_weight": 0.1, "max_weight": 0.55, "bite_time": 4.0, "sell_price": 12},
		{"item_id": "perch", "name": "Perch", "min_weight": 0.15, "max_weight": 0.6, "bite_time": 3.5, "sell_price": 10},
		# Uncommon fish (weight 0.4-0.8)
		{"item_id": "salmon", "name": "Salmon", "min_weight": 0.4, "max_weight": 0.75, "bite_time": 5.0, "sell_price": 20},
		{"item_id": "trout", "name": "Trout", "min_weight": 0.45, "max_weight": 0.8, "bite_time": 5.5, "sell_price": 22},
		# Rare fish (weight 0.7-0.95)
		{"item_id": "tuna", "name": "Tuna", "min_weight": 0.7, "max_weight": 0.9, "bite_time": 7.0, "sell_price": 40},
		{"item_id": "swordfish", "name": "Swordfish", "min_weight": 0.75, "max_weight": 0.93, "bite_time": 8.0, "sell_price": 55},
		# Very rare (weight 0.9+)
		{"item_id": "golden_fish", "name": "Golden Fish", "min_weight": 0.9, "max_weight": 1.0, "bite_time": 6.0, "sell_price": 100},
		{"item_id": "moonfish", "name": "Moonfish", "min_weight": 0.92, "max_weight": 1.0, "bite_time": 8.0, "sell_price": 80},
	]


## Start fishing. Called when player uses fishing rod near water.
func start_fishing(player: Node2D) -> bool:
	if state != FishingState.IDLE:
		return false
	
	# Check player is near water
	var world := get_tree().get_first_node_in_group("world")
	if not world or not world.has_method("has_water_neighbor"):
		ToastNotification.show_toast("No water nearby to fish in!", ToastNotification.ToastType.WARNING, 2.0)
		return false
	
	var cell := Vector2i(int(player.global_position.x / 16), int(player.global_position.y / 16))
	var has_water_nearby: bool = world.has_water_neighbor(cell)
	
	if not has_water_nearby:
		ToastNotification.show_toast("Must be near water to fish!", ToastNotification.ToastType.WARNING, 2.0)
		return false
	
	_player_ref = player
	_start_fishing_position = player.global_position
	state = FishingState.CASTING
	_cast_timer = 0.8  # short casting animation time
	
	# Play cast animation on the player sprite
	if _player_ref.has_method("play_fishing_cast"):
		_player_ref.play_fishing_cast()
	
	# Choose what fish will bite
	_pick_fish()
	
	ToastNotification.show_toast("Casting line...", ToastNotification.ToastType.INFO, 1.5)
	return true


## Pick a random fish based on weight table.
func _pick_fish() -> void:
	var roll: float = _rng.randf()
	for entry in _fish_table:
		if roll >= entry["min_weight"] and roll <= entry["max_weight"]:
			_fish_item_id = entry["item_id"]
			_wait_time = entry["bite_time"]
			_bite_chance = 1.0 / _wait_time  # per-second chance during wait
			return
	# Fallback
	_fish_item_id = "raw_fish"
	_wait_time = 3.0
	_bite_chance = 1.0 / 3.0


## Cancel fishing (player moved or pressed something else).
func cancel_fishing() -> void:
	if state != FishingState.IDLE:
		state = FishingState.IDLE
		_reset_player_pose()
		ToastNotification.show_toast("Fishing cancelled!", ToastNotification.ToastType.INFO, 1.0)


func is_fishing() -> bool:
	return state != FishingState.IDLE


func _process(delta: float) -> void:
	match state:
		FishingState.CASTING:
			_cast_timer -= delta
			if _cast_timer <= 0.0:
				state = FishingState.WAITING
				ToastNotification.show_toast("Waiting for a bite...", ToastNotification.ToastType.INFO, 1.5)
		
		FishingState.WAITING:
			# Check if player moved too far
			if _player_ref and _player_moved_too_far():
				cancel_fishing()
				return
			# Random bite check
			if _rng.randf() < _bite_chance * delta * 60.0:
				state = FishingState.REELING
				_reel_progress = 0.0
				_reel_target = float(_rng.randi_range(3, 7))
				ToastNotification.show_toast("Something bit! Press [E] to reel in!", ToastNotification.ToastType.SUCCESS, 3.0)
		
		FishingState.REELING:
			if _player_ref and _player_moved_too_far():
				cancel_fishing()
				return
			# Player must press E to reel
			# (handled externally via interact/reel_input)
			pass


## Called when player presses E/reel during REELING state.
func try_reel() -> bool:
	if state != FishingState.REELING:
		return false
	
	# Quick reel tug animation
	if _player_ref and _player_ref.has_method("play_fishing_reel"):
		_player_ref.play_fishing_reel()
	
	_reel_progress += 1.0
	if _reel_progress >= _reel_target:
		_catch_fish()
		return true
	
	# Show progress
	var pct: int = int(_reel_progress / _reel_target * 100)
	ToastNotification.show_toast("Reeling... %d%%" % pct, ToastNotification.ToastType.INFO, 0.8)
	return true


## Catch the fish and add to inventory.
func _catch_fish() -> void:
	state = FishingState.IDLE
	_reset_player_pose()
	
	if _fish_item_id.is_empty():
		ToastNotification.show_toast("Fish got away!", ToastNotification.ToastType.WARNING, 2.0)
		return
	
	var leftover: int = InventoryManager.add_item(_fish_item_id, 1)
	var caught := leftover == 0
	
	var item_data: ItemData = DataManager.get_item(_fish_item_id)
	var fish_name: String = item_data.display_name if item_data else _fish_item_id
	
	if caught:
		ToastNotification.show_toast("Caught a %s!" % fish_name, ToastNotification.ToastType.SUCCESS, 3.0)
		EffectSpawner.spawn_floating_text("+1 %s" % fish_name, _player_ref.global_position if _player_ref else Vector2.ZERO, Color(0.3, 0.8, 1.0))
		fish_caught.emit(_fish_item_id)
	else:
		ToastNotification.show_toast("Inventory full! Fish got away...", ToastNotification.ToastType.WARNING, 2.0)
	
	# Ultra-rare chance to hook an Inconstant Fruit as well (~0.5% per catch)
	_try_hook_inconstant_fruit()
	
	_fish_item_id = ""
	_player_ref = null


## Very rare chance (0.5%) to hook an Inconstant Fruit from the depths.
## Thematically these are sealed ancient fruits that wash into fishing waters.
func _try_hook_inconstant_fruit() -> void:
	if _rng.randf() >= 0.005:
		return  # 99.5% — nothing special
	
	# Find findable Inconstant Fruits (Soul Fruit gated behind boss defeat)
	var available_fruits: Array[ItemData] = InconstantFruitSystem.get_wild_findable_fruits()
	if available_fruits.is_empty():
		return
	
	var fruit: ItemData = available_fruits[_rng.randi() % available_fruits.size()]
	var leftover: int = InventoryManager.add_item(fruit.id, 1)
	if leftover == 0:
		ToastNotification.show_toast("[color=#FFD700][b]✦ Legendary Catch! ✦[/b][/color]\nYou reel in a [color=#BB66FF]%s[/color]!" % fruit.display_name, ToastNotification.ToastType.SUCCESS, 5.0)
		EffectSpawner.spawn_sparkle(
			_player_ref.global_position if _player_ref else Vector2.ZERO,
			Color(1.0, 0.8, 0.3)
		)
		if AudioManager and AudioManager.has_method("play"):
			AudioManager.play(AudioManager.Sound.LEVEL_UP)
		fish_caught.emit(fruit.id)
	else:
		ToastNotification.show_toast("The %s slipped away... inventory full!" % fruit.display_name, ToastNotification.ToastType.WARNING, 2.0)


## Reset the player's sprite rotation back to neutral after fishing ends.
func _reset_player_pose() -> void:
	if _player_ref and _player_ref.has_method("reset_fishing_pose"):
		_player_ref.reset_fishing_pose()


func _player_moved_too_far() -> bool:
	if not _player_ref:
		return true
	# Cancel fishing if player moves more than 6 tiles (96px) from where they started
	var dist_sq: float = _player_ref.global_position.distance_squared_to(_start_fishing_position)
	return dist_sq > 9216.0  # 96^2


## Returns the current fishing state as a display string.
func get_state_string() -> String:
	match state:
		FishingState.IDLE:
			return "Not fishing"
		FishingState.CASTING:
			return "Casting..."
		FishingState.WAITING:
			return "Waiting for bite..."
		FishingState.REELING:
			return "Reeling in! (%d%%)" % int(_reel_progress / _reel_target * 100)
	return ""
