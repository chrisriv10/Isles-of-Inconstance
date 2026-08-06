extends RigidBody2D
class_name Arrow

## Arrow projectile fired by the player's bow. Follows the same pattern as
## enemy projectiles (FrostWisp ice bolt, CinderImp fireball): no gravity,
## contact monitoring, and body_entered hit detection.

## Damage dealt on impact. Set by Player._fire_bow() before spawning.
var arrow_damage: int = 0
## Reference to the player that fired this arrow, so we don't hit ourselves.
var shooter: Node2D = null
## Whether this arrow is a critical hit (set by Player._fire_bow()).
var is_critical: bool = false
## True for visual-only copies spawned on peers that did NOT fire this arrow
## (via Player._sync_arrow_fired). These never deal damage nor forward attacks;
## they exist so other players can see the shot.
var is_visual: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


## Custom physics integration: keep the arrow's sprite aligned with its
## travel direction and prevent physics-induced spinning.
func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if freeze:
		return
	# Always face the direction of travel so the arrow doesn't spiral
	var vel := state.linear_velocity
	if vel.length_squared() > 1.0:
		state.transform = Transform2D(vel.angle(), state.transform.origin)


## Hit detection: damages enemies/animals, stops on world terrain, ignores the shooter.
## Only the host's authoritative arrow deals damage; remote copies are visual only.
func _on_body_entered(body: Node) -> void:
	# Don't hit the player who fired the arrow
	if body == shooter:
		return
	
	# Visual copies (spawned on peers that didn't fire) never deal damage —
	# they just play the impact effect so the shot looks real to onlookers.
	if is_visual:
		_on_hit_effect()
		return
	
	# Only the host applies damage (authoritative hit detection)
	if not multiplayer.is_server():
		# Client's own arrow hit a damageable target. Enemies/bosses expose the
		# ranged forward RPC (melee's 100px adjacency gate would wrongly reject
		# long-range bow shots), so the host resolves the hit on its authoritative
		# same-named copy and broadcasts _sync_enemy_damage back to update ours.
		# Animals are detected via their own Area2D _on_arrow_hit path (forwarded
		# through World), so we deliberately don't forward here for them.
		if not is_visual and body.has_method("_server_receive_enemy_attack") and \
				(body.is_in_group("enemies") or body.is_in_group("bosses")):
			body.rpc_id(1, "_server_receive_enemy_attack", body.enemy_id, arrow_damage, is_critical, true)
		_on_hit_effect()
		return
	
	# Host: apply actual damage
	if body.has_method("take_damage") and (body.is_in_group("enemies") or body.is_in_group("animals") or body.is_in_group("bosses")):
		body.take_damage(arrow_damage, shooter, is_critical)
		_on_hit_effect()
		# XP for ranged attack
		LevelManager.add_xp_source("hit_enemy")
		return
	
	# Hit everything else (terrain, buildings, etc.) — stick briefly then vanish
	_on_hit_effect()


## Visual effect on impact — brief pause then clean up.
func _on_hit_effect() -> void:
	# Stop all motion — defer to avoid changing physics state during flush
	linear_velocity = Vector2.ZERO
	set_deferred("freeze", true)
	# Fade out quickly
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.TRANSPARENT, 0.3)
	tween.tween_callback(queue_free)
