extends Node

## Tracks active meal-based buffs with durations in game-minutes.
## Each buff has a type, strength, and remaining duration.
## When duration reaches zero, the buff expires automatically.
##
## Buff types:
##   "speed"   → 1.0 + strength = movement speed multiplier
##   "growth"  → crops grow faster (growth timer divided by strength)
##   "energy"  → reduces hunger drain (hunger tick skipped with strength probability)
##   "luck"    → increased mutation chance / double harvest
##   "health"  → passive healing over time (strength HP per game-hour)
##   "none"    → just food, no buff

signal potion_applied(buff_type: String, strength: float, duration_minutes: int, source_name: String)
signal buff_applied(buff_type: String, strength: float, duration_minutes: int)
signal buff_expired(buff_type: String)
signal buffs_updated()  # emitted when any buff state changes

class ActiveBuff:
	var buff_type: String
	var strength: float
	var remaining_minutes: int  # how many game-minutes this buff lasts
	var source_name: String     # name of the meal that granted this buff

var _active_buffs: Dictionary = {}  # buff_type -> ActiveBuff


func apply_meal_buff(meal: Variant) -> void:
	if not meal or meal.buff_type == "none":
		return
	
	var duration_minutes: int = roundi(meal.buff_duration * 60.0)  # hours -> minutes
	
	var buff := ActiveBuff.new()
	buff.buff_type = meal.buff_type
	buff.strength = meal.buff_strength
	buff.remaining_minutes = duration_minutes
	buff.source_name = meal.display_name
	
	# Replace existing buff of same type (stronger or equal overwrites)
	if _active_buffs.has(meal.buff_type):
		var existing: ActiveBuff = _active_buffs[meal.buff_type]
		# Keep whichever has longer remaining duration
		if existing.remaining_minutes > duration_minutes:
			# Only extend if new buff is stronger
			if meal.buff_strength > existing.strength:
				existing.strength = meal.buff_strength
				existing.source_name = meal.display_name
			return
		# New buff replaces old
		_active_buffs[meal.buff_type] = buff
	else:
		_active_buffs[meal.buff_type] = buff
	
	buff_applied.emit(meal.buff_type, meal.buff_strength, duration_minutes)
	buffs_updated.emit()


## Apply a potion effect directly (like apply_meal_buff but for potions).
## Potions can use standard buff types ("speed", "growth", "energy", "luck", "health")
## plus a "defense" type which reduces incoming damage.
func apply_potion_effect(buff_type: String, strength: float, duration_minutes: float, source_name: String) -> void:
	if buff_type.is_empty() or strength <= 0.0:
		return
	
	var duration_minutes_int: int = maxi(1, roundi(duration_minutes * 60.0))
	
	var buff := ActiveBuff.new()
	buff.buff_type = buff_type
	buff.strength = strength
	buff.remaining_minutes = duration_minutes_int
	buff.source_name = source_name
	
	# Replace existing buff of same type (keep whichever is stronger/longer)
	if _active_buffs.has(buff_type):
		var existing: ActiveBuff = _active_buffs[buff_type]
		if existing.remaining_minutes > duration_minutes_int and existing.strength >= strength:
			return  # existing is better, keep it
		_active_buffs[buff_type] = buff
	else:
		_active_buffs[buff_type] = buff
	
	potion_applied.emit(buff_type, strength, duration_minutes_int, source_name)
	buffs_updated.emit()


## Called every game-minute by GameManager to tick down buff durations.
func tick_minute() -> void:
	var expired: Array[String] = []
	for buff_type in _active_buffs:
		var buff: ActiveBuff = _active_buffs[buff_type]
		buff.remaining_minutes -= 1
		if buff.remaining_minutes <= 0:
			expired.append(buff_type)
	
	for buff_type in expired:
		_active_buffs.erase(buff_type)
		buff_expired.emit(buff_type)
		buffs_updated.emit()


func has_buff(buff_type: String) -> bool:
	return _active_buffs.has(buff_type)


func get_buff(buff_type: String) -> ActiveBuff:
	return _active_buffs.get(buff_type)


func get_strength(buff_type: String) -> float:
	var buff: ActiveBuff = _active_buffs.get(buff_type)
	return buff.strength if buff else 0.0


func get_all_buffs() -> Array[ActiveBuff]:
	var result: Array[ActiveBuff] = []
	for buff_type in _active_buffs:
		result.append(_active_buffs[buff_type])
	return result


func get_buff_count() -> int:
	return _active_buffs.size()


func clear_all() -> void:
	_active_buffs.clear()
	buffs_updated.emit()


func serialize() -> Dictionary:
	var buffs_data: Dictionary = {}
	for buff_type in _active_buffs:
		var buff: ActiveBuff = _active_buffs[buff_type]
		buffs_data[buff_type] = {
			"type": buff.buff_type,
			"strength": buff.strength,
			"remaining": buff.remaining_minutes,
			"source": buff.source_name
		}
	return buffs_data


func deserialize(data: Dictionary) -> void:
	_active_buffs.clear()
	if data.is_empty():
		return
	for buff_type in data:
		var entry: Dictionary = data[buff_type]
		var buff := ActiveBuff.new()
		buff.buff_type = entry.get("type", buff_type)
		buff.strength = entry.get("strength", 0.0)
		buff.remaining_minutes = entry.get("remaining", 0)
		buff.source_name = entry.get("source", "Unknown")
		_active_buffs[buff_type] = buff
