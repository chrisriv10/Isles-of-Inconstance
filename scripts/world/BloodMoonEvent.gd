class_name BloodMoonEvent
extends Node

## Blood Moon Event for Isles of Inconstance.
## Randomly triggers on some nights, turning the sky dark red and
## increasing enemy spawns dramatically. Alerts the player to take shelter.

signal blood_moon_started()
signal blood_moon_ended()

const BLOOD_MOON_CHANCE: float = 0.15  # 15% chance each night
const TRIGGER_HOUR_MIN: int = 20  # Earliest hour it can trigger (8 PM)
const TRIGGER_HOUR_MAX: int = 2   # Latest hour it can trigger (2 AM, wraps past midnight)

var is_active: bool = false
var _rng: RandomNumberGenerator

## Whether this is a remote copy (client) — blood moon rolls run on the host
## only, and remote copies just apply the host's broadcast state.
var _is_remote: bool = false


func _init() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.randomize()


func _ready() -> void:
	if NetworkManager.is_network_active() and not multiplayer.is_server():
		_is_remote = true
	GameManager.phase_changed.connect(_on_phase_changed)


func _on_phase_changed(phase: int) -> void:
	if _is_remote:
		return  # host drives blood moon rolls and broadcasts the result
	match phase:
		DayNightCycle.Phase.NIGHT:
			_try_trigger()
		DayNightCycle.Phase.DAWN:
			_end_blood_moon()


## Roll the dice and start a blood moon if the RNG gods decree it.
func _try_trigger() -> void:
	if is_active or _is_remote:
		return
	
	if _rng.randf() < BLOOD_MOON_CHANCE:
		_start_blood_moon()


func _start_blood_moon() -> void:
	is_active = true
	
	# Tell the day/night system to tint the overlay red
	if GameManager.day_night:
		GameManager.day_night.blood_moon_active = true
	
	# Alert the player
	ToastNotification.show_toast(
		"🌕 BLOOD MOON RISING! Seek shelter!",
		ToastNotification.ToastType.WARNING,
		6.0
	)
	
	blood_moon_started.emit()
	_broadcast_state()


func _end_blood_moon() -> void:
	if not is_active:
		return
	
	is_active = false
	
	# Restore normal night tint
	if GameManager.day_night:
		GameManager.day_night.blood_moon_active = false
	
	ToastNotification.show_toast(
		"🌅 The blood moon fades...",
		ToastNotification.ToastType.INFO,
		4.0
	)
	
	blood_moon_ended.emit()
	_broadcast_state()


## Public method to force-trigger a blood moon (used by Creative Panel).
## Clients forward the trigger to the host; the host starts it and broadcasts.
func trigger_blood_moon() -> void:
	if NetworkManager.is_network_active() and not multiplayer.is_server():
		rpc_id(1, "_server_request_blood_moon")
		return
	if not is_active:
		_start_blood_moon()


# ── Multiplayer sync ──

## Host: broadcast the blood moon state to all clients.
func _broadcast_state() -> void:
	if _is_remote or not NetworkManager.is_network_active():
		return
	if not multiplayer.is_server():
		return
	rpc("_sync_blood_moon", is_active)


## Client: apply the host's blood moon state — tint, alerts, and signals.
@rpc("authority", "reliable")
func _sync_blood_moon(active: bool) -> void:
	if multiplayer.is_server():
		return
	if active == is_active:
		# Already in the correct state — nothing to do (also covers idempotent
		# re-broadcasts for late joiners).
		return
	is_active = active
	if GameManager.day_night:
		GameManager.day_night.blood_moon_active = active
	if active:
		ToastNotification.show_toast(
			"🌕 BLOOD MOON RISING! Seek shelter!",
			ToastNotification.ToastType.WARNING,
			6.0
		)
		blood_moon_started.emit()
	else:
		ToastNotification.show_toast(
			"🌅 The blood moon fades...",
			ToastNotification.ToastType.INFO,
			4.0
		)
		blood_moon_ended.emit()


## Creative-panel trigger forwarded from a client.
@rpc("any_peer", "reliable")
func _server_request_blood_moon() -> void:
	if not multiplayer.is_server():
		return
	if not is_active:
		_start_blood_moon()


## Join-time pull: a freshly connected client asks the host for the current
## blood moon state (a broadcast may have happened before it was ready).
@rpc("any_peer", "reliable")
func _server_request_blood_moon_state() -> void:
	if not multiplayer.is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = multiplayer.get_unique_id()
	rpc_id(sender, "_sync_blood_moon", is_active)


# ── Save / Load ──

func serialize() -> Dictionary:
	return {
		"is_active": is_active,
	}


func deserialize(data: Dictionary) -> void:
	if data.has("is_active"):
		is_active = data["is_active"] as bool
		# If we loaded with an active blood moon, restore the visual state
		if is_active and GameManager.day_night:
			GameManager.day_night.blood_moon_active = true
