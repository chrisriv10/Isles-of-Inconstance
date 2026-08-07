extends Interactable
class_name Animal

## Preloaded scene so breeding spawns fully-instantiated animals (Sprite2D,
## CollisionShape2D, Label, WanderTimer, etc.) instead of bare script instances.
const ANIMAL_SCENE: PackedScene = preload("res://scenes/world/Animal.tscn")

## Procedurally generated animal that draws its own pixel-art sprite,
## picks a random species name, and wanders around with varied behaviour.
## Extends Interactable (Area2D) so the PlayerInteractor can detect it.

# ---------------------------------------------------------------------------
# Context-aware interaction types
# ---------------------------------------------------------------------------
enum InteractionType { PET, FEED, COLLECT, BREED, TALK }

# ---------------------------------------------------------------------------
# Behaviour types
# ---------------------------------------------------------------------------
enum Behavior { WANDER, GRAZE, IDLE, SKITTISH }

# ---------------------------------------------------------------------------
# Species name generators
# ---------------------------------------------------------------------------
const SPECIES_PREFIX := [
	"Glimmer", "Shadow", "Cinder", "Dew", "Frost", "Ember", "Mist",
	"Storm", "Sun", "Moon", "Star", "Thorn", "Briar", "Ash", "Flint",
	"Dusk", "Dawn", "Crystal", "Copper", "Silver", "Golden", "Ivy",
	"Fern", "Moss", "Heather", "Honey", "Maple", "Thistle", "Clover",
]

const SPECIES_SUFFIX_FOWL := [
	"beak", "plume", "wing", "crest", "feather", "talon", "claw",
	"strider", "dancer", "chirp", "flutter", "peck",
]

const SPECIES_SUFFIX_BOVINE := [
	"hoof", "mane", "hide", "horn", "snout", "muzzle", "flank",
	"strider", "trotter", "stomp", "bellow",
]

const SPECIES_SUFFIX_RABBIT := [
	"hop", "burrow", "whisker", "paw", "bounce", "scamper", "ear",
	"fluff", "twitch",
]

const SPECIES_SUFFIX_DEER := [
	"antler", "leap", "glade", "wood", "buck", "snout", "strider",
	"prowl", "dapple",
]

const SPECIES_SUFFIX_GOAT := [
	"beard", "horn", "cliff", "mountain", "bleat", "step", "scramble",
	"peak", "ridge",
]

const SPECIES_SUFFIX_PIG := [
	"snout", "trotter", "root", "wallow", "squeal", "curly", "mud",
	"forager", "grunt",
]

const SPECIES_SUFFIX_SHEEP := [
	"fleece", "baa", "meadow", "flock", "curl", "pasture", "ewe",
	"shear", "herder",
]

const SPECIES_SUFFIX_SQUIRREL := [
	"tail", "nut", "scamper", "acorn", "chatter", "bush", "dart",
	"hop", "tree",
]

const SPECIES_SUFFIX_FROG := [
	"croak", "pond", "lily", "hop", "splash", "ribbit", "marsh",
	"leap", "puddle",
]

const SPECIES_SUFFIX_TURTLE := [
	"shell", "slow", "pond", "dome", "plod", "moss", "bask",
	"drift", "shore",
]

const SPECIES_SUFFIX_FOX := [
	"paw", "brush", "den", "vixen", "sly", "dart", "leap",
	"mask", "covert",
]

const SPECIES_SUFFIX_BEAR := [
	"paw", "claw", "den", "hibernate", "snout", "shaggy", "lumber",
	"roar", "fisher",
]

const SPECIES_SUFFIX_OWL := [
	"wing", "hoot", "perch", "talon", "wise", "feather", "glide",
	"night", "gaze",
]

const SPECIES_SUFFIX_GUMMY := [
	"jiggle", "wobble", "bounce", "chew", "squish", "sweet", "glaze",
	"sparkle", "marsh",
]

const SPECIES_SUFFIX_SANDWICH := [
	"stack", "layer", "wafer", "filling", "bite", "press", "smooth",
	"creamy", "crisp",
]

const SPECIES_SUFFIX_GINGERBREAD := [
	"crumb", "spice", "mold", "crisp", "cookie", "bake", "frost",
	"snap", "ginger", "sugar",
]

const SPECIES_SUFFIX_WORM := [
	"squirm", "slither", "coil", "stretch", "wiggle", "ink", "curl",
	"black", "vine",
]

const SPECIES_SUFFIX_LIZARD := [
	"scale", "tail", "crawl", "dart", "sun", "rock", "sand",
	"crest", "claw",
]

const SPECIES_SUFFIX_SCORPION := [
	"sting", "pincer", "crawl", "venom", "shell", "sand", "stalk",
	"hunt", "nocturne",
]

const SPECIES_SUFFIX_MEERKAT := [
	"sentinel", "dig", "sun", "pack", "vigil", "paw", "tunnel",
	"lookout", "clan",
]

const SPECIES_SUFFIX_CRAWLER := [
	"ember", "cinder", "forge", "spark", "glow", "heat", "chamber",
	"core", "smolder",
]

const SPECIES_SUFFIX_MOTH := [
	"wing", "dust", "glimmer", "flutter", "scale", "night", "veil",
	"luna", "drift",
]

const SPECIES_SUFFIX_SLUG := [
	"slime", "trail", "squish", "dome", "mollusk", "slow", "glide",
	"mucus", "shell",
]

const SPECIES_SUFFIX_JELLY := [
	"glow", "pulse", "drift", "float", "shimmer", "luminous", "wisp",
	"bloom", "tide",
]

const WANDER_SPEED_MIN: float = 15.0
const WANDER_SPEED_MAX: float = 40.0
const GRAZE_SPEED: float = 8.0
const SKITTISH_SPEED: float = 60.0

## Cooldown between pets (seconds) — petting too often does nothing.
const PET_COOLDOWN: float = 120.0

## Cooldown between feedings (seconds) — prevents spam-feeding an animal
## with no benefit after love mode ends or when no breeding partner is nearby.
const FEED_COOLDOWN: float = 120.0

# Dialogue themes for special creature types
const GINGERBREAD_LINES: Array[String] = [
	"Fresh out the oven!",
	"Don't eat me \u2014 I'm your friend!",
	"I'm not just a snack, you know.",
	"Life is sweet when you're made of ginger!",
	"Crispy on the outside, soft on the inside!",
	"I run on sugar and good vibes!",
	"Watch out \u2014 I'm a tough cookie!",
	"The icing is the best part!",
]
const SANDWICH_LINES: Array[String] = [
	"Two wafers and a whole lot of cream!",
	"Sweet, cold, and ready to roll!",
	"Keep your cool around me!",
	"I'm the coolest treat on the island!",
	"Layers of deliciousness, that's me!",
	"Don't let me melt away!",
	"Freeze! \u2026 just kidding, I'm friendly!",
	"Best served with a smile!",
]

## Minimum distance animals keep from the player while following (breeding mode).
## Prevents clumping on top of the player so breeding is easier.
const FOLLOW_STOP_DISTANCE: float = 36.0
## Spread range for animals circling around the player while following.
## Each animal picks a per-instance offset so they fan out instead of stacking.
const FOLLOW_SPREAD_RANGE: float = 20.0

# ---------------------------------------------------------------------------
# Multiplayer sync
# ---------------------------------------------------------------------------
static var _next_animal_id: int = 1
var animal_id: int = 0
var _is_remote: bool = false
var _last_pos_sync_time: float = 0.0
const POS_SYNC_INTERVAL: float = 0.1

# ---------------------------------------------------------------------------
# Exports
# ---------------------------------------------------------------------------
@export var animal_name: String = "Animal"
@export var animal_type: String = "chicken"
@export var behavior: Behavior = Behavior.WANDER
@export var move_speed: float = 30.0
@export var body_color: Color = Color.WHITE
@export var accent_color: Color = Color.ORANGE_RED
@export var secondary_color: Color = Color(0.9, 0.9, 0.9)
@export var spot_color: Color = Color(0.4, 0.3, 0.2)

# ---------------------------------------------------------------------------
# Nodes
# ---------------------------------------------------------------------------
@onready var sprite: Sprite2D = $Sprite2D
# Not @onready since pre-existing instanced scenes lack the node
var animated_sprite: AnimatedSprite2D = null
@onready var label: Label = $Label
@onready var wander_timer: Timer = $WanderTimer

var _target_pos: Vector2 = Vector2.ZERO
var _home_pos: Vector2 = Vector2.ZERO
var _move_radius: float = 48.0
var _rest_time: float = 0.0
var _idle_phase: float = 0.0
var _body_shape: int = 0
var _pattern: int = 0
var _world_ref: Node = null
var _player_ref: Node2D = null
var _setup_done: bool = false  # set by setup() to prevent _ready() from overwriting values
var _last_interaction_day: int = -999  # tracks last day interacted for cooldowns
var _has_dropped_rare: bool = false  # tracks one-time rare drops

# MP: the peer id that last dealt the killing/attacking blow. Used to route
# kill drops to the killer only (not duplicated to every peer). 0 = host/local.
var _last_attacker_peer: int = 0

# Affection system (tracks how much player has pet this animal)
var _affection: float = 0.0
var _last_pet_time: float = 0.0

# Health system
var max_health: int = 20
var current_health: int = 20

# Breeding system (Minecraft-style)
var is_love_mode: bool = false
var is_baby: bool = false
var _growth_progress: float = 0.0  # 0.0 = newborn, 1.0 = adult
var _growth_sync_timer: float = 0.0  # throttle for broadcasting baby growth to clients
var _breed_cooldown: float = 0.0  # seconds until can breed again
var _feed_cooldown: float = 0.0  # seconds until can feed again
var _following_player: bool = false
var _follow_offset: Vector2 = Vector2.ZERO  # per-animal offset to spread around player
var _love_timer: float = 0.0
var _tamed: bool = false  # marked when fed — anchors home to fenced areas so the animal stays penned

# Dialogue bubble
var _dialogue_bubble: Node2D
var _dialogue_label: Label

var _loot_drops: Array[Dictionary] = []


# Health bar nodes
var _health_bar_bg: ColorRect = null
var _health_bar_fill: ColorRect = null

# ---------------------------------------------------------------------------
# Health bar
# ---------------------------------------------------------------------------

func _ensure_health_bar() -> void:
	if _health_bar_bg != null:
		return
	var bg := ColorRect.new()
	bg.name = "AnimalHealthBG"
	bg.size = Vector2(18, 4)
	bg.position = Vector2(-9, -22)
	bg.color = Color(0.1, 0.1, 0.1, 0.6)
	add_child(bg)
	_health_bar_bg = bg

	var fill := ColorRect.new()
	fill.name = "AnimalHealthFill"
	fill.size = Vector2(18, 4)
	fill.position = Vector2(-9, -22)
	fill.color = Color(0.3, 0.9, 0.3, 0.85)
	add_child(fill)
	_health_bar_fill = fill

func _update_health_bar() -> void:
	_ensure_health_bar()
	if current_health < max_health:
		var ratio := float(current_health) / float(max_health)
		_health_bar_fill.size.x = ratio * 18.0
		_health_bar_bg.visible = true
		_health_bar_fill.visible = true
	else:
		_health_bar_bg.visible = false
		_health_bar_fill.visible = false

# ---------------------------------------------------------------------------
# Damage & Death
# ---------------------------------------------------------------------------

## Detects when an Arrow (RigidBody2D) enters this Animal's Area2D.
## Since Animal extends Area2D (via Interactable) and Arrow is a RigidBody2D,
## the arrow's own body_entered can't detect us — so we detect it from this side.
func _on_arrow_hit(body: Node) -> void:
	# Check if the entering body is an arrow projectile
	if body.get("arrow_damage") != null:
		var arrow: Arrow = body as Arrow
		if arrow:
			take_damage(arrow.arrow_damage, arrow.shooter, arrow.is_critical)
			# Trigger the arrow's hit effect so it stops and fades out
			arrow._on_hit_effect()


# ── Multiplayer RPC ──────────────────────────────────────────────────────

## Returns true if this node lives under a host-only subtree (mine room or
## building interior). Such interiors are generated only on the host, so per-
## node RPC broadcasts from them can never resolve on clients — skip
## broadcasting to avoid error floods. NOTE: expedition islands are generated
## identically on every peer, so their animals are host-authoritative remote
## mirrors and MUST be allowed to broadcast through the World relay.
func _is_in_host_only_subtree() -> bool:
	var p: Node = get_parent()
	while p:
		if p is MineRoom or p is BuildingInterior:
			return true
		p = p.get_parent()
	return false


## Host: broadcast an animal RPC through World instead of this node, so a
## joining peer (whose matching Animal_N node doesn't exist yet) receives it
## on World and drops it gracefully instead of flooding "Node not found".
func _broadcast_animal_rpc(method: String, args: Array, reliable: bool) -> void:
	if not NetworkManager.is_network_active() or not multiplayer.is_server():
		return
	if _is_in_host_only_subtree():
		return
	if _world_ref and is_instance_valid(_world_ref) and _world_ref.has_method("_relay_animal_rpc_reliable"):
		if reliable:
			_world_ref.rpc("_relay_animal_rpc_reliable", method, args)
		else:
			_world_ref.rpc("_relay_animal_rpc_unreliable", method, args)

## Host → all clients: sync position for a remote copy (via World relay).
## p_scale carries the host copy's current scale so remote babies grow in sync
## with the host instead of staying at their spawn-time (0.5) scale forever.
func _sync_animal_pos(aid: int, pos: Vector2, p_scale: float = 1.0) -> void:
	if not _is_remote or animal_id != aid:
		return
	global_position = pos
	if is_baby:
		scale = Vector2(p_scale, p_scale)


## Host → all clients: incremental baby growth for a remote copy (via World relay).
## Remote babies run no local _grow_baby, so this keeps their scale in sync.
func _sync_animal_growth(aid: int, growth: float) -> void:
	if not _is_remote or animal_id != aid:
		return
	_growth_progress = growth
	scale = Vector2(0.5 + _growth_progress * 0.5, 0.5 + _growth_progress * 0.5)


## Host → all clients: a baby has grown to adult (via World relay).
func _sync_animal_adult(aid: int) -> void:
	if not _is_remote or animal_id != aid:
		return
	is_baby = false
	_growth_progress = 1.0
	scale = Vector2.ONE


## Client → host: a client fed an animal; ask the host to mark its copy
## tamed and relay to everyone so remote copies match.
@rpc("any_peer", "reliable")
func _request_animal_tamed(aid: int) -> void:
	if not multiplayer.is_server():
		return
	if animal_id != aid:
		return
	_tamed = true
	_broadcast_animal_rpc("_sync_animal_tamed", [aid], true)

## Host-side handling for a client-initiated feed (invoked via World's
## _server_feed_animal RPC). Mirrors feed()'s love-mode entry so the host's
## authoritative copy is in love mode and can breed with a mate, then broadcasts
## the tame and attempts breeding. Without this, a client-fed animal only enters
## love mode on the client's copy and the host never spawns a baby from it.
func _request_feed_from_client(aid: int) -> void:
	if not multiplayer.is_server():
		return
	if animal_id != aid:
		return
	if _feed_cooldown > 0.0:
		return
	is_love_mode = true
	_love_timer = 15.0
	_tamed = true
	EffectSpawner.spawn_hearts(global_position + Vector2(0, -12), 8, 14.0, -28.0)
	_broadcast_animal_rpc("_sync_animal_tamed", [aid], true)
	if _breed_cooldown <= 0.0:
		_try_breed()


## Host → all clients: mark the animal with this id as tamed (via World relay).
func _sync_animal_tamed(aid: int) -> void:
	if animal_id != aid:
		return
	_tamed = true

## Host → all clients: broadcast damage result so remote copies show effects.
func _sync_animal_damage(aid: int, hp: int, dmg: int, crit: bool, pos: Vector2, mhp: int) -> void:
	if not _is_remote or animal_id != aid:
		return
	current_health = hp
	max_health = mhp
	_update_health_bar()
	EffectSpawner.spawn_damage_number(dmg, pos, crit)
	if crit:
		EffectSpawner.spawn_particles(pos, Color(1.0, 0.4, 0.0), 6, 10.0)

## Host → all clients: signal that this animal has died and distribute loot.
func _sync_animal_died(aid: int, loot: Array[Dictionary] = []) -> void:
	if not _is_remote or animal_id != aid:
		return
	for drop in loot:
		var item_id: String = drop.get("item_id", "")
		var count: int = drop.get("count", 1)
		if not item_id.is_empty():
			InventoryManager.add_item(item_id, count)
	# Death effects on remote copy
	EffectSpawner.spawn_particles(global_position, Color(0.5, 0.0, 0.0), 6, 10.0)
	EffectSpawner.spawn_floating_text(animal_name + " slain!", global_position, Color(1.0, 0.3, 0.3))
	AudioManager.play(AudioManager.Sound.HIT)
	queue_free()

## Client → host: forward a melee/ranged attack on a remote copy.
@rpc("any_peer", "reliable")
func _server_receive_animal_attack(aid: int, amount: int, crit: bool) -> void:
	if not multiplayer.is_server():
		return
	if _is_remote or animal_id != aid:
		return
	# Basic validation — attacker must be their own player node, nearby
	var attacker: Node2D = null
	var sender: int = multiplayer.get_remote_sender_id()
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and p.get_multiplayer_authority() == sender:
			attacker = p as Node2D
			break
	if attacker == null:
		attacker = get_tree().get_first_node_in_group("player")
	if attacker == null:
		return
	if global_position.distance_to(attacker.global_position) > 100.0:
		return
	# Remember who's attacking so kill drops go to the killer only.
	_last_attacker_peer = sender
	take_damage(amount, attacker, crit)


func take_damage(amount: int, _source: Node2D = null, _is_critical: bool = false) -> void:
	# Client-side remote copy — forward attack to host for authoritative
	# processing via World's stable node path. The Animal node's own path can
	# differ per peer (names drift after per-peer worldgen/respawn), and an
	# rpc_id on it flooded "Node not found" when the host lacked that name.
	if NetworkManager.is_network_active() and _is_remote:
		if _world_ref and is_instance_valid(_world_ref) and _world_ref.has_method("_server_receive_animal_attack"):
			_world_ref.rpc_id(1, "_server_receive_animal_attack", animal_id, amount, _is_critical)
		return
	
	current_health -= amount
	_update_health_bar()
	EffectSpawner.spawn_particles(global_position, Color(1.0, 0.3, 0.3), 3, 6.0)
	# Flash red like Minecraft
	if sprite:
		sprite.modulate = Color(1.5, 0.3, 0.3, 1.0)
		var tween := create_tween()
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)
		tween.set_ease(Tween.EASE_OUT)
	if current_health <= 0:
		_die()
	# Host: broadcast damage update to all clients
	if NetworkManager.is_network_active() and multiplayer.is_server() and not _is_in_host_only_subtree():
		_broadcast_animal_rpc("_sync_animal_damage", [animal_id, current_health, amount, _is_critical, global_position, max_health], true)

func _die() -> void:
	# Roll meat and materials (don't grant yet — decide the recipient first).
	_loot_drops.clear()
	var rolled: Array[Dictionary] = []
	var drops: Array[Dictionary] = _get_kill_drops()
	for drop in drops:
		var item_id: String = drop.get("item_id", "")
		if item_id.is_empty():
			continue
		var amount: int = drop.get("amount", 1)
		var chance: float = drop.get("chance", 1.0)
		if randf() <= chance:
			rolled.append({"item_id": item_id, "count": amount})

	# Host-authoritative MP animal: give the drops to the KILLER only (not
	# duplicated to every peer). Remote copies just die and get no loot.
	if NetworkManager.is_network_active() and multiplayer.is_server() and not _is_in_host_only_subtree():
		var killer: int = _last_attacker_peer
		if killer <= 0 or killer == multiplayer.get_unique_id():
			# Killer is the host (or unknown) — add to the host's inventory.
			for dr in rolled:
				InventoryManager.add_item(dr["item_id"], dr["count"])
		else:
			# Killer is a remote client — route the loot to that peer only.
			if _world_ref and is_instance_valid(_world_ref) and _world_ref.has_method("_receive_animal_loot"):
				for dr in rolled:
					_world_ref.rpc_id(killer, "_receive_animal_loot", dr["item_id"], dr["count"])
		# Broadcast death (no loot) so every remote copy dies gracefully.
		_broadcast_animal_rpc("_sync_animal_died", [animal_id, []], true)
	else:
		# Single-player, or a per-peer island animal on a client: grant locally.
		for dr in rolled:
			InventoryManager.add_item(dr["item_id"], dr["count"])
			_loot_drops.append(dr)
		if NetworkManager.is_network_active() and multiplayer.is_server() and not _is_in_host_only_subtree():
			_broadcast_animal_rpc("_sync_animal_died", [animal_id, _loot_drops], true)
	_loot_drops.clear()
	
	# Expedition island animals are generated independently per peer (not
	# host-authoritative remote copies), so the per-node RPC above can't reach
	# other peers. Route removal through the island's shared sync instead: the
	# deterministic island_obj_id lets every peer remove its matching copy.
	if has_meta("island_obj_id"):
		var island := get_tree().get_first_node_in_group("expedition_island")
		if is_instance_valid(island) and island.has_method("notify_island_object_removed"):
			island.notify_island_object_removed(int(get_meta("island_obj_id")))
	
	# Death effects
	EffectSpawner.spawn_particles(global_position, Color(0.5, 0.0, 0.0), 6, 10.0)
	EffectSpawner.spawn_floating_text(animal_name + " slain!", global_position, Color(1.0, 0.3, 0.3))
	AudioManager.play(AudioManager.Sound.HIT)
	queue_free()

func _get_kill_drops() -> Array[Dictionary]:
	match animal_type:
		"chicken", "bird":
			return [{"item_id": "feather", "amount": randi() % 3 + 1, "chance": 1.0},
					{"item_id": "chicken_meat", "amount": 1, "chance": 0.8}]
		"cow":
			return [{"item_id": "leather", "amount": 1, "chance": 0.9},
					{"item_id": "venison", "amount": 2, "chance": 1.0}]
		"rabbit":
			return [{"item_id": "fur", "amount": 1, "chance": 1.0},
					{"item_id": "venison", "amount": 1, "chance": 0.7}]
		"deer":
			return [{"item_id": "leather", "amount": 1, "chance": 0.8},
					{"item_id": "venison", "amount": 3, "chance": 1.0},
					{"item_id": "antlers", "amount": 1, "chance": 0.3}]
		"goat":
			return [{"item_id": "wool", "amount": 1, "chance": 0.7},
					{"item_id": "venison", "amount": 2, "chance": 1.0}]
		"pig":
			return [{"item_id": "truffle", "amount": randi() % 2 + 1, "chance": 0.5},
					{"item_id": "venison", "amount": 2, "chance": 1.0}]
		"sheep":
			return [{"item_id": "wool", "amount": 2, "chance": 1.0},
					{"item_id": "venison", "amount": 2, "chance": 1.0}]
		"squirrel":
			return [{"item_id": "fur", "amount": 1, "chance": 1.0}]
		"frog":
			return [{"item_id": "mushroom", "amount": 1, "chance": 0.6}]
		"turtle":
			return [{"item_id": "shell", "amount": 1, "chance": 1.0}]
		"snow_fox":
			return [{"item_id": "fur", "amount": 1, "chance": 1.0},
					{"item_id": "ice_crystal", "amount": 1, "chance": 0.4}]
		"polar_bear":
			return [{"item_id": "polar_bear_hide", "amount": 1, "chance": 1.0},
					{"item_id": "venison", "amount": 3, "chance": 1.0}]
		"snow_owl":
			return [{"item_id": "feather", "amount": 2, "chance": 1.0},
					{"item_id": "ice_crystal", "amount": 1, "chance": 0.5}]
		"gummy_bear":
			return [{"item_id": "gumdrop", "amount": 2, "chance": 1.0}]
		"marshmallow_puff":
			return [{"item_id": "sugar_crystal", "amount": 1, "chance": 1.0}]
		"licorice_worm":
			return [{"item_id": "chocolate_chunk", "amount": 1, "chance": 0.7}]
		"ice_cream_sandwich_man":
			return [{"item_id": "sugar_crystal", "amount": 2, "chance": 1.0},
					{"item_id": "gumdrop", "amount": 1, "chance": 0.5}]
		"gingerbread_man":
			return [{"item_id": "sugar_crystal", "amount": 2, "chance": 1.0},
					{"item_id": "chocolate_chunk", "amount": 1, "chance": 0.5},
					{"item_id": "gingerbread_helmet", "amount": 1, "chance": 0.1},
					{"item_id": "gingerbread_chestplate", "amount": 1, "chance": 0.1},
					{"item_id": "gingerbread_leggings", "amount": 1, "chance": 0.1},
					{"item_id": "gingerbread_boots", "amount": 1, "chance": 0.1}]
		"sand_lizard":
			return [{"item_id": "leather", "amount": 1, "chance": 0.7},
					{"item_id": "cactus_fruit", "amount": 1, "chance": 0.3}]
		"desert_scorpion":
			return [{"item_id": "scorpion_stinger", "amount": 1, "chance": 1.0}]
		"meerkat":
			return [{"item_id": "fur", "amount": 1, "chance": 1.0},
					{"item_id": "golden_scarab", "amount": 1, "chance": 0.1}]
		"ember_crawler":
			return [{"item_id": "ember_dust", "amount": 1, "chance": 1.0}]
		"ash_moth":
			return [{"item_id": "ember_dust", "amount": 1, "chance": 0.6},
					{"item_id": "sulfur_crystal", "amount": 1, "chance": 0.3}]
		"magma_slug":
			return [{"item_id": "magma_core", "amount": 1, "chance": 0.5},
					{"item_id": "sulfur_crystal", "amount": 1, "chance": 0.5}]
		"spirit_fox":
			return [{"item_id": "fur", "amount": 1, "chance": 1.0},
					{"item_id": "moon_shard", "amount": 1, "chance": 0.4}]
		"glow_jelly":
			return [{"item_id": "starlight_dust", "amount": 1, "chance": 1.0},
					{"item_id": "ethereal_essence", "amount": 1, "chance": 0.2}]
		"lunar_moth":
			return [{"item_id": "starlight_dust", "amount": 1, "chance": 0.8},
					{"item_id": "ethereal_essence", "amount": 1, "chance": 0.3}]
		_:
			return [{"item_id": "venison", "amount": 1, "chance": 0.5}]

# ---------------------------------------------------------------------------
# Breeding (Minecraft-style)
# ---------------------------------------------------------------------------

func get_love_foods() -> Array[String]:
	match animal_type:
		"chicken", "bird":
			return ["berry", "mushroom", "nut"]
		"cow":
			return ["berry", "flower", "mushroom"]
		"rabbit":
			return ["berry", "mushroom"]
		"sheep":
			return ["berry", "flower"]
		"pig":
			return ["mushroom", "nut", "truffle"]
		"goat":
			return ["berry", "flower", "mushroom"]
		"deer":
			return ["berry", "flower", "mushroom"]
		"frog":
			return ["mushroom", "berry"]
		"squirrel":
			return ["nut", "berry"]
		"turtle":
			return ["mushroom", "flower"]
		"snow_fox":
			return ["ice_crystal", "berry"]
		"polar_bear":
			return ["ice_crystal", "snow_flower", "fish"]
		"snow_owl":
			return ["mushroom", "snow_flower"]
		"gummy_bear":
			return ["gumdrop", "sugar_crystal"]
		"marshmallow_puff":
			return ["sugar_crystal", "berry"]
		"licorice_worm":
			return ["chocolate_chunk", "sugar_crystal"]
		"ice_cream_sandwich_man":
			return ["sugar_crystal", "gumdrop", "chocolate_chunk"]
		"gingerbread_man":
			return ["sugar_crystal", "gumdrop", "chocolate_chunk"]
		"sand_lizard":
			return ["cactus_fruit", "mushroom"]
		"desert_scorpion":
			return ["scorpion_stinger", "mushroom"]
		"meerkat":
			return ["cactus_fruit", "bug"]
		"ember_crawler":
			return ["ember_dust", "coal"]
		"ash_moth":
			return ["sulfur_crystal", "ember_dust"]
		"magma_slug":
			return ["magma_core", "sulfur_crystal"]
		"spirit_fox":
			return ["moon_shard", "ethereal_essence"]
		"glow_jelly":
			return ["starlight_dust", "moon_shard"]
		"lunar_moth":
			return ["starlight_dust", "moon_shard"]
		_:
			return ["berry"]

func feed(food_item_id: String) -> bool:
	# Check if this animal likes this food
	var love_foods: Array[String] = get_love_foods()
	if food_item_id not in love_foods:
		return false
	
	# Respect feed cooldown — prevents spam-feeding
	if _feed_cooldown > 0.0:
		return false
	
	# Consume one of that food
	if not InventoryManager.has_item(food_item_id, 1):
		return false
	InventoryManager.remove_item(food_item_id, 1)
	
	# Start feed cooldown so this animal can't be spammed
	_feed_cooldown = FEED_COOLDOWN
	
	# Enter love mode
	is_love_mode = true
	_love_timer = 15.0  # 15 seconds of love mode
	_tamed = true  # now stays near fences

	# Multiplayer: broadcast the tame so every peer's copy (host + clients)
	# marks this animal as tamed too. Local mutation is unconditional; the
	# relay is purely additive (client → host → everyone). Routed through
	# World's stable path — per-node RPCs on the Animal node flooded
	# "Node not found" whenever per-peer animal names drifted (and the old
	# server-side rpc() skipped the host-only-subtree guard entirely).
	if NetworkManager.is_network_active():
		if multiplayer.is_server():
			_broadcast_animal_rpc("_sync_animal_tamed", [animal_id], true)
		else:
			# Tell the host to enter love mode + breed on its authoritative copy,
			# not just tame it. Taming alone leaves the host copy out of love mode
			# so a client-fed animal never produces a baby.
			if _world_ref and is_instance_valid(_world_ref) and _world_ref.has_method("_server_feed_animal"):
				_world_ref.rpc_id(1, "_server_feed_animal", animal_id)
	
	# Burst of heart sprites
	EffectSpawner.spawn_hearts(global_position + Vector2(0, -12), 8, 14.0, -28.0)
	
	# Floating text feedback
	EffectSpawner.spawn_floating_text("Fed " + animal_name + "!", global_position, Color(1.0, 0.4, 0.7))
	
	# Try to find a nearby mate of the same type
	if _breed_cooldown <= 0.0:
		_try_breed()
	
	return true

func _try_breed() -> void:
	if is_baby:
		return  # Babies can't breed
	var all_animals := get_tree().get_nodes_in_group("animals")
	for other in all_animals:
		if other == self:
			continue
		var other_animal := other as Animal
		if not other_animal:
			continue
		if other_animal.animal_type != animal_type:
			continue
		if other_animal.is_baby:
			continue
		if other_animal.is_love_mode and other_animal._breed_cooldown <= 0.0:
			# Both in love mode — breed!
			_spawn_baby(other_animal)
			_breed_cooldown = 60.0  # 60s cooldown
			other_animal._breed_cooldown = 60.0
			is_love_mode = false
			other_animal.is_love_mode = false
			return

func _spawn_baby(partner: Animal) -> void:
	# Only the host breeds; clients get the baby via _sync_spawn_animal.
	if NetworkManager.is_network_active() and not multiplayer.is_server():
		return
	# Create a baby animal at the midpoint
	var baby_pos := (global_position + partner.global_position) / 2.0
	var baby := ANIMAL_SCENE.instantiate()
	baby.animal_type = animal_type
	baby.is_baby = true
	baby._tamed = _tamed or partner._tamed  # inherit tamed status from parents
	baby.max_health = max_health
	baby.current_health = max_health
	baby.scale = Vector2(0.5, 0.5)
	baby.global_position = baby_pos
	var world := get_tree().get_first_node_in_group("world")
	if world and world.has_method("register_animal_name"):
		world.register_animal_name(baby)
	get_parent().add_child(baby)
	baby.setup(animal_type, baby_pos)
	
	# Broadcast baby spawn to remote clients
	if NetworkManager.is_network_active() and multiplayer.is_server():
		if world and world.has_method("_broadcast_animal_spawn"):
			world._broadcast_animal_spawn(baby)
	
	# Effects — hearts and sparkles for the baby
	EffectSpawner.spawn_hearts(baby_pos, 12, 16.0, -32.0)
	EffectSpawner.spawn_sparkle(baby_pos, Color(1.0, 0.7, 0.9))
	ToastNotification.show_toast("A new %s has been born!" % animal_name, ToastNotification.ToastType.SUCCESS, 3.0)
	
	# Notify ObjectiveManager about breeding
	var om_breed := get_tree().get_first_node_in_group("objective_manager")
	if om_breed and om_breed.has_method("on_baby_born"):
		om_breed.on_baby_born()

func _grow_baby(delta: float) -> void:
	if not is_baby:
		return
	_growth_progress += delta * (1.0 / 120.0)  # 2 minutes to grow up
	scale = Vector2(0.5 + _growth_progress * 0.5, 0.5 + _growth_progress * 0.5)
	if _growth_progress >= 1.0:
		is_baby = false
		scale = Vector2.ONE
		_max_health_change()  # restore to adult health
		# Sync the baby→adult transition so remote copies also grow up.
		if NetworkManager.is_network_active() and multiplayer.is_server():
			_broadcast_animal_rpc("_sync_animal_adult", [animal_id], true)
	elif NetworkManager.is_network_active() and multiplayer.is_server():
		# Incrementally sync growth so remote baby copies scale up too (they run
		# no local _grow_baby since _process returns early for _is_remote).
		# Throttled to ~0.5s so it doesn't flood with a reliable RPC every frame.
		_growth_sync_timer += delta
		if _growth_sync_timer >= 0.5:
			_growth_sync_timer = 0.0
			_broadcast_animal_rpc("_sync_animal_growth", [animal_id, _growth_progress], true)

func _max_health_change() -> void:
	# Restore to full health when growing up
	current_health = max_health

# ---------------------------------------------------------------------------
# Initialisation
# ---------------------------------------------------------------------------

func setup(p_type: String, p_home: Vector2, use_ai_sprite: bool = false) -> void:
	animal_id = _next_animal_id
	_next_animal_id += 1
	animal_type = p_type
	_home_pos = p_home
	global_position = p_home
	current_health = max_health
	# Pick a random per-animal offset so they spread out when following the player
	_follow_offset = Vector2(randf_range(-FOLLOW_SPREAD_RANGE, FOLLOW_SPREAD_RANGE), randf_range(-FOLLOW_SPREAD_RANGE, FOLLOW_SPREAD_RANGE))
	_generate_species_name()
	# Expedition animals (AI sprite) should use their clean type name, not a generated one
	if use_ai_sprite:
		animal_name = _species_display_name()
		if label:
			label.text = animal_name
	_generate_behavior()
	_generate_colors_and_pattern()
	if use_ai_sprite:
		_load_ai_sprite()
	else:
		_generate_procedural_sprite()
	_setup_dialogue()
	_pick_new_target()
	# Guard against null @onready vars when setup() is called before the
	# node enters the scene tree (e.g. barn animals inside a BuildingInterior
	# that hasn't been added to the tree yet). _ready() will start the timer
	# when the node eventually enters the tree if it's still stopped.
	if wander_timer:
		wander_timer.start()
	if is_baby:
		scale = Vector2(0.5, 0.5)
		_growth_progress = 0.0
	add_to_group("animals")
	_setup_done = true


## Client-side initialization from host broadcast data.
func setup_from_network(data: Dictionary) -> void:
	var node_name: String = data.get("node_name", "")
	if node_name != "":
		name = node_name
	animal_id = data.get("aid", 0)
	animal_type = data.get("type", "chicken")
	animal_name = data.get("name", "Animal")
	behavior = data.get("behavior", 0) as int
	move_speed = data.get("speed", 30.0)
	body_color = _dict_to_color(data.get("body_c", {}))
	accent_color = _dict_to_color(data.get("acc_c", {}))
	secondary_color = _dict_to_color(data.get("sec_c", {}))
	spot_color = _dict_to_color(data.get("spot_c", {}))
	_body_shape = data.get("shape", 0)
	_pattern = data.get("pattern", 0)
	_home_pos = Vector2(data.get("hx", 0.0), data.get("hy", 0.0))
	global_position = _home_pos
	_move_radius = data.get("radius", 48.0)
	_follow_offset = Vector2(data.get("fox", 0.0), data.get("foy", 0.0))
	is_baby = data.get("baby", false)
	_tamed = data.get("tamed", false)
	_growth_progress = data.get("growth", 0.0)
	current_health = data.get("hp", 20)
	max_health = data.get("mhp", 20)
	_last_interaction_day = data.get("int_day", -999)
	_has_dropped_rare = data.get("rare", false)
	_affection = data.get("affection", 0.0)
	_is_remote = true
	if is_baby:
		scale = Vector2(0.5 + _growth_progress * 0.5, 0.5 + _growth_progress * 0.5)
	else:
		scale = Vector2.ONE
	if label:
		label.text = animal_name
	_generate_procedural_sprite()
	_setup_dialogue()
	_pick_new_target()
	_setup_done = true


## Serialize this animal's full visual/gameplay state for network broadcast.
func get_network_data() -> Dictionary:
	return {
		"node_name": name,
		"aid": animal_id,
		"type": animal_type,
		"name": animal_name,
		"behavior": behavior,
		"speed": move_speed,
		"body_c": _color_to_dict(body_color),
		"acc_c": _color_to_dict(accent_color),
		"sec_c": _color_to_dict(secondary_color),
		"spot_c": _color_to_dict(spot_color),
		"shape": _body_shape,
		"pattern": _pattern,
		"hx": _home_pos.x,
		"hy": _home_pos.y,
		"radius": _move_radius,
		"fox": _follow_offset.x,
		"foy": _follow_offset.y,
		"baby": is_baby,
		"tamed": _tamed,
		"growth": _growth_progress,
		"hp": current_health,
		"mhp": max_health,
		"int_day": _last_interaction_day,
		"rare": _has_dropped_rare,
		"affection": _affection,
	}


## Helper: convert a Color to a {r,g,b,a} dict for RPC.
static func _color_to_dict(c: Color) -> Dictionary:
	return {"r": c.r, "g": c.g, "b": c.b, "a": c.a}


## Helper: convert a {r,g,b,a} dict from RPC data back to Color.
static func _dict_to_color(d: Dictionary) -> Color:
	return Color(
		d.get("r", 1.0),
		d.get("g", 1.0),
		d.get("b", 1.0),
		d.get("a", 1.0)
	)


## Generates a fantasy species name, e.g. "Cinderplume Fowl" or
## "Frosthoof Bovine".  Each animal type has its own suffix pool so
## the names feel like they belong to that kind of creature.
func _generate_species_name() -> void:
	var prefix: String = SPECIES_PREFIX[abs(animal_type.hash()) % SPECIES_PREFIX.size()]
	var suffix_pool: Array
	match animal_type:
		"chicken", "bird":
			suffix_pool = SPECIES_SUFFIX_FOWL
		"cow":
			suffix_pool = SPECIES_SUFFIX_BOVINE
		"rabbit":
			suffix_pool = SPECIES_SUFFIX_RABBIT
		"deer":
			suffix_pool = SPECIES_SUFFIX_DEER
		"goat":
			suffix_pool = SPECIES_SUFFIX_GOAT
		"pig":
			suffix_pool = SPECIES_SUFFIX_PIG
		"sheep":
			suffix_pool = SPECIES_SUFFIX_SHEEP
		"squirrel":
			suffix_pool = SPECIES_SUFFIX_SQUIRREL
		"frog":
			suffix_pool = SPECIES_SUFFIX_FROG
		"turtle":
			suffix_pool = SPECIES_SUFFIX_TURTLE
		"snow_fox":
			suffix_pool = SPECIES_SUFFIX_FOX
		"polar_bear":
			suffix_pool = SPECIES_SUFFIX_BEAR
		"snow_owl":
			suffix_pool = SPECIES_SUFFIX_OWL
		"gummy_bear":
			suffix_pool = SPECIES_SUFFIX_GUMMY
		"marshmallow_puff":
			suffix_pool = SPECIES_SUFFIX_GUMMY
		"licorice_worm":
			suffix_pool = SPECIES_SUFFIX_WORM
		"ice_cream_sandwich_man":
			suffix_pool = SPECIES_SUFFIX_SANDWICH
		"gingerbread_man":
			suffix_pool = SPECIES_SUFFIX_GINGERBREAD
		"sand_lizard":
			suffix_pool = SPECIES_SUFFIX_LIZARD
		"desert_scorpion":
			suffix_pool = SPECIES_SUFFIX_SCORPION
		"meerkat":
			suffix_pool = SPECIES_SUFFIX_MEERKAT
		"ember_crawler":
			suffix_pool = SPECIES_SUFFIX_CRAWLER
		"ash_moth":
			suffix_pool = SPECIES_SUFFIX_MOTH
		"magma_slug":
			suffix_pool = SPECIES_SUFFIX_SLUG
		"spirit_fox":
			suffix_pool = SPECIES_SUFFIX_FOX
		"glow_jelly":
			suffix_pool = SPECIES_SUFFIX_JELLY
		"lunar_moth":
			suffix_pool = SPECIES_SUFFIX_MOTH
		_:
			suffix_pool = SPECIES_SUFFIX_FOWL

	var suffix: String = suffix_pool[abs(animal_type.hash() + 1) % suffix_pool.size()]
	var type_label: String = _species_type_label()
	animal_name = prefix + suffix + " " + type_label
	if label:
		label.text = animal_name

## Converts a snake_case animal_type into a readable display name,
## e.g. "ice_cream_sandwich_man" -> "Ice Cream Sandwich Man"
func _species_display_name() -> String:
	var words: PackedStringArray = animal_type.replace("_", " ").split(" ", false)
	for i in words.size():
		if words[i].length() > 0:
			words[i] = words[i].substr(0, 1).capitalize() + words[i].substr(1)
	return " ".join(words)

func _species_type_label() -> String:
	match animal_type:
		"chicken", "bird":
			return ["Fowl", "Bird", "Flyer"][randi() % 3]
		"cow":
			return ["Bovine", "Herder", "Grazer"][randi() % 3]
		"rabbit":
			return ["Burrower", "Hopper", "Lagomorph"][randi() % 3]
		"deer":
			return ["Deer", "Strider", "Grazer"][randi() % 3]
		"goat":
			return ["Caprine", "Climber", "Rambler"][randi() % 3]
		"pig":
			return ["Porcine", "Rooter", "Forager"][randi() % 3]
		"sheep":
			return ["Ovine", "Flocker", "Grazer"][randi() % 3]
		"squirrel":
			return ["Sciurid", "Darter", "Tree-Hopper"][randi() % 3]
		"frog":
			return ["Anuran", "Leaper", "Pond-Hopper"][randi() % 3]
		"turtle":
			return ["Testudine", "Shell-Bearer", "Slow-Coach"][randi() % 3]
		"snow_fox":
			return ["Vulpine", "Arctic-Fox", "Snow-Walker"][randi() % 3]
		"polar_bear":
			return ["Ursine", "Ice-Bear", "Fisher"][randi() % 3]
		"snow_owl":
			return ["Strigid", "Snow-Wing", "White-Watcher"][randi() % 3]
		"gummy_bear":
			return ["Gelatin", "Chewable", "Sweetling"][randi() % 3]
		"marshmallow_puff":
			return ["Fluffball", "Puffling", "Cloudlet"][randi() % 3]
		"licorice_worm":
			return ["Serpentine", "Twizzler", "Dark-Bender"][randi() % 3]
		"ice_cream_sandwich_man":
			return ["Sandwichling", "Layer-Walker", "Wafer-Knight"][randi() % 3]
		"gingerbread_man":
			return ["Cookie-Knight", "Spice-Walker", "Gingerling"][randi() % 3]
		"sand_lizard":
			return ["Saurian", "Dune-Runner", "Scaleback"][randi() % 3]
		"desert_scorpion":
			return ["Scorpioid", "Venom-Tail", "Sand-Stalker"][randi() % 3]
		"meerkat":
			return ["Herpestid", "Lookout", "Clan-Digger"][randi() % 3]
		"ember_crawler":
			return ["Coleopteran", "Spark-Crawler", "Lava-Bug"][randi() % 3]
		"ash_moth":
			return ["Lepidopteran", "Flutter-Ash", "Dust-Wing"][randi() % 3]
		"magma_slug":
			return ["Gastropod", "Lava-Glider", "Magma-Crawler"][randi() % 3]
		"spirit_fox":
			return ["Phantom", "Ethereal-Vulpine", "Ghost-Fox"][randi() % 3]
		"glow_jelly":
			return ["Cnidarian", "Pulse-Drifter", "Luminous-Blob"][randi() % 3]
		"lunar_moth":
			return ["Lepidopteran", "Moon-Dancer", "Silk-Wing"][randi() % 3]
		_:
			return "Critter"

func _generate_behavior() -> void:
	var roll: float = randf()
	if roll < 0.35:
		behavior = Behavior.WANDER
		move_speed = randf_range(WANDER_SPEED_MIN, WANDER_SPEED_MAX)
	elif roll < 0.55:
		behavior = Behavior.GRAZE
		move_speed = GRAZE_SPEED
	elif roll < 0.75:
		behavior = Behavior.IDLE
		move_speed = 0.0
	else:
		behavior = Behavior.SKITTISH
		move_speed = SKITTISH_SPEED

## Picks a colour palette, body shape (round/tall/wide/slender),
## and pattern (solid/spotted/striped/patchy) for this animal.
func _generate_colors_and_pattern() -> void:
	_body_shape = randi() % 4      # 0=round, 1=tall, 2=wide, 3=slender
	_pattern = randi() % 4         # 0=solid, 1=spotted, 2=striped, 3=patchy

	match animal_type:
		"chicken", "bird":
			var hue: float = randf_range(0.0, 0.12)
			var sat: float = randf_range(0.1, 0.7)
			var val: float = randf_range(0.6, 1.0)
			body_color = Color.from_hsv(hue, sat, val)
			accent_color = Color.from_hsv(randf_range(0.0, 0.1), randf_range(0.8, 1.0), randf_range(0.7, 1.0))
			secondary_color = Color.from_hsv(hue, sat * 0.5, val * 0.8)
			spot_color = Color.from_hsv(hue, sat, val * 0.5)
		"cow":
			var shade: float = randf_range(0.6, 1.0)
			body_color = Color(shade, shade, shade)
			accent_color = Color.from_hsv(randf_range(0.0, 0.1), randf_range(0.4, 0.8), randf_range(0.5, 0.8))
			secondary_color = Color(shade * 0.85, shade * 0.85, shade * 0.85)
			spot_color = Color.from_hsv(randf(), randf_range(0.3, 0.8), randf_range(0.3, 0.6))
		"rabbit":
			var hue: float = randf_range(0.0, 0.15)
			var sat: float = randf_range(0.1, 0.4)
			var val: float = randf_range(0.5, 0.9)
			body_color = Color.from_hsv(hue, sat, val)
			accent_color = Color(1.0, 1.0, 1.0)
			secondary_color = Color.from_hsv(hue, sat * 0.5, val * 0.8)
			spot_color = Color.from_hsv(0.0, 0.0, val * 0.4)
		"deer":
			var hue: float = randf_range(0.05, 0.12)
			var sat: float = randf_range(0.3, 0.7)
			var val: float = randf_range(0.5, 0.85)
			body_color = Color.from_hsv(hue, sat, val)
			accent_color = Color.from_hsv(0.0, 0.0, val * 0.6)
			secondary_color = Color.from_hsv(hue, sat * 0.5, val * 1.1)
			spot_color = Color.from_hsv(0.0, 0.0, val * 0.4)
		"goat":
			var shade: float = randf_range(0.65, 0.9)
			var hue: float = randf_range(0.05, 0.12)
			body_color = Color.from_hsv(hue, randf_range(0.2, 0.5), shade)
			accent_color = Color.from_hsv(0.07, 0.6, 0.5)
			secondary_color = Color.from_hsv(hue, 0.2, shade * 0.85)
			spot_color = Color.from_hsv(0.0, 0.0, shade * 0.5)
		"pig":
			var pink_base: float = randf_range(0.88, 1.0)
			body_color = Color(pink_base, randf_range(0.75, 0.92), randf_range(0.75, 0.92))
			accent_color = Color(pink_base * 0.8, 0.65, 0.65)
			secondary_color = Color(pink_base * 0.9, 0.85, 0.85)
			spot_color = Color(pink_base * 0.7, 0.55, 0.55)
		"sheep":
			var wool: float = randf_range(0.8, 1.0)
			body_color = Color(wool, wool, wool)
			accent_color = Color.from_hsv(randf_range(0.0, 0.08), randf_range(0.2, 0.5), randf_range(0.5, 0.7))
			secondary_color = Color(wool * 0.85, wool * 0.85, wool * 0.85)
			spot_color = Color(wool * 0.6, wool * 0.6, wool * 0.6)
		"squirrel":
			var hue: float = randf_range(0.05, 0.15)
			var sat: float = randf_range(0.4, 0.8)
			var val: float = randf_range(0.5, 0.8)
			body_color = Color.from_hsv(hue, sat, val)
			accent_color = Color.from_hsv(hue, sat * 1.2, val * 0.7)
			secondary_color = Color.from_hsv(hue, sat * 0.5, val * 1.1)
			spot_color = Color.from_hsv(0.0, 0.0, val * 0.5)
		"frog":
			var hue: float = randf_range(0.25, 0.45)
			var sat: float = randf_range(0.5, 0.9)
			var val: float = randf_range(0.5, 0.9)
			body_color = Color.from_hsv(hue, sat, val)
			accent_color = Color.from_hsv(hue + 0.08, sat * 0.8, val * 0.8)
			secondary_color = Color.from_hsv(hue, sat * 0.4, val * 1.1)
			spot_color = Color.from_hsv(0.0, 0.0, val * 0.3)
		"turtle":
			var hue: float = randf_range(0.2, 0.4)
			var sat: float = randf_range(0.3, 0.7)
			var val: float = randf_range(0.3, 0.6)
			body_color = Color.from_hsv(hue, sat, val)
			accent_color = Color.from_hsv(hue, sat * 0.8, val * 0.8)
			secondary_color = Color.from_hsv(hue + 0.05, sat * 0.3, val * 1.2)
			spot_color = Color.from_hsv(0.0, 0.0, val * 0.4)
		"snow_fox":
			var white: float = randf_range(0.85, 1.0)
			body_color = Color(white, white, white)
			accent_color = Color.from_hsv(0.0, 0.0, white * 0.7)
			secondary_color = Color(white * 0.9, white * 0.9, white * 0.95)
			spot_color = Color.from_hsv(0.0, 0.0, white * 0.5)
		"polar_bear":
			var white: float = randf_range(0.8, 0.98)
			body_color = Color(white, white, white)
			accent_color = Color.from_hsv(0.08, randf_range(0.2, 0.4), randf_range(0.5, 0.7))
			secondary_color = Color(white * 0.85, white * 0.85, white * 0.88)
			spot_color = Color(white * 0.6, white * 0.6, white * 0.65)
		"snow_owl":
			var white: float = randf_range(0.8, 0.98)
			body_color = Color(white, white, white)
			accent_color = Color(white * 0.9, white * 0.85, white * 0.8)
			secondary_color = Color(white * 0.7, white * 0.7, white * 0.72)
			spot_color = Color(white * 0.5, white * 0.5, white * 0.52)
		"gummy_bear":
			var hue: float = randf_range(0.8, 1.0) if randf() < 0.5 else randf_range(0.0, 0.15)
			var sat: float = randf_range(0.5, 0.9)
			body_color = Color.from_hsv(hue, sat, 0.9)
			accent_color = Color.from_hsv(hue, sat * 0.8, 0.75)
			secondary_color = Color.from_hsv(hue, sat * 0.4, 0.95)
			spot_color = Color(1.0, 1.0, 1.0)
		"marshmallow_puff":
			body_color = Color(0.92, 0.88, 0.82)
			accent_color = Color(0.85, 0.75, 0.65)
			secondary_color = Color(0.95, 0.92, 0.88)
			spot_color = Color(0.8, 0.7, 0.6)
		"licorice_worm":
			body_color = Color(0.15, 0.1, 0.08)
			accent_color = Color(0.8, 0.15, 0.15)
			secondary_color = Color(0.3, 0.2, 0.15)
			spot_color = Color(0.4, 0.4, 0.4)
		"ice_cream_sandwich_man":
			body_color = Color(0.55, 0.28, 0.1)
			accent_color = Color(1.0, 0.95, 0.82)
			secondary_color = Color(0.7, 0.4, 0.15)
			spot_color = Color(0.3, 0.15, 0.05)
		"gingerbread_man":
			body_color = Color(0.7, 0.38, 0.15)
			accent_color = Color(0.85, 0.55, 0.25)
			secondary_color = Color(0.95, 0.9, 0.8)
			spot_color = Color(0.9, 0.8, 0.7)
		"sand_lizard":
			var hue: float = randf_range(0.06, 0.13)
			var sat: float = randf_range(0.4, 0.7)
			var val: float = randf_range(0.5, 0.8)
			body_color = Color.from_hsv(hue, sat, val)
			accent_color = Color.from_hsv(hue - 0.03, sat, val * 0.8)
			secondary_color = Color.from_hsv(hue, sat * 0.3, val * 1.1)
			spot_color = Color.from_hsv(0.0, 0.0, val * 0.5)
		"desert_scorpion":
			body_color = Color(0.6, 0.35, 0.15)
			accent_color = Color(0.7, 0.15, 0.1)
			secondary_color = Color(0.5, 0.3, 0.12)
			spot_color = Color(0.3, 0.2, 0.1)
		"meerkat":
			var hue: float = randf_range(0.06, 0.11)
			body_color = Color.from_hsv(hue, 0.5, 0.8)
			accent_color = Color.from_hsv(hue, 0.6, 0.6)
			secondary_color = Color.from_hsv(hue, 0.3, 0.9)
			spot_color = Color(0.0, 0.0, 0.3)
		"ember_crawler":
			body_color = Color.from_hsv(0.03, 0.8, 0.85)
			accent_color = Color.from_hsv(0.05, 0.9, 0.7)
			secondary_color = Color.from_hsv(0.02, 0.5, 0.9)
			spot_color = Color(1.0, 0.8, 0.3)
		"ash_moth":
			body_color = Color(0.55, 0.55, 0.5)
			accent_color = Color(0.7, 0.6, 0.5)
			secondary_color = Color(0.45, 0.45, 0.4)
			spot_color = Color(0.85, 0.6, 0.3)
		"magma_slug":
			body_color = Color.from_hsv(0.02, 0.7, 0.7)
			accent_color = Color.from_hsv(0.04, 0.8, 0.6)
			secondary_color = Color.from_hsv(0.01, 0.4, 0.8)
			spot_color = Color(0.9, 0.6, 0.2)
		"spirit_fox":
			var hue: float = randf_range(0.65, 0.8)
			var sat: float = randf_range(0.4, 0.7)
			body_color = Color.from_hsv(hue, sat, 0.9)
			accent_color = Color.from_hsv(hue + 0.1, sat, 0.8)
			secondary_color = Color.from_hsv(hue, sat * 0.3, 0.95)
			spot_color = Color.from_hsv(0.0, 0.0, 0.5)
		"glow_jelly":
			var hue: float = randf_range(0.55, 0.85)
			body_color = Color.from_hsv(hue, 0.3, 0.95)
			accent_color = Color.from_hsv(hue, 0.4, 0.8)
			secondary_color = Color.from_hsv(hue, 0.15, 1.0)
			spot_color = Color(1.0, 1.0, 0.9)
		"lunar_moth":
			body_color = Color(0.75, 0.7, 0.85)
			accent_color = Color(0.6, 0.65, 0.9)
			secondary_color = Color(0.8, 0.75, 0.9)
			spot_color = Color(0.9, 0.85, 1.0)
		_:
			body_color = Color(0.8, 0.8, 0.8)
			accent_color = Color(0.6, 0.6, 0.6)

## Draws animal pixel-art entirely in code into an Image, then assigns
## it as a texture on the Sprite2D node.
## Loads a pre-generated AI sprite for expedition island animals.
## Shows the animal type name as a label above the sprite.
func _load_ai_sprite() -> void:
	# These creatures have proper animated spritesheets — use them
	# instead of the static frames that other AI animals use.
	if animal_type == "ice_cream_sandwich_man":
		_setup_ice_cream_sandwich_animation()
		return
	if animal_type == "gingerbread_man":
		_setup_gingerbread_man_animation()
		return

	if not sprite:
		sprite = $Sprite2D
	if not sprite:
		_generate_procedural_sprite()
		return

	var ai_path := "res://assets/generated/animal_" + animal_type + "_frame_0.png"
	var ai_tex := load(ai_path) as Texture2D
	if ai_tex:
		sprite.texture = ai_tex
		sprite.modulate = body_color
		if label:
			label.text = _species_display_name()
			label.visible = true
		return

	# Fall back to procedural if the AI sprite isn't found
	_generate_procedural_sprite()


func _generate_procedural_sprite() -> void:
	# The @onready var sprite can be null if setup() is called before the
	# node enters the scene tree (e.g. barn animals spawned inside a
	# BuildingInterior that hasn't been added to the tree yet).  Fall back
	# to a direct child lookup since $Sprite2D works on instantiated scenes
	# regardless of scene-tree membership.
	if not sprite:
		sprite = $Sprite2D
	if not sprite:
		return

	var w: int = 24
	var h: int = 20
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))  # transparent background

	match animal_type:
		"chicken", "bird":
			_draw_bird_body(img, w, h)
		"cow":
			_draw_quadruped_body(img, w, h)
		"rabbit":
			_draw_rabbit_body(img, w, h)
		"deer":
			_draw_quadruped_body(img, w, h)
		"goat":
			_draw_quadruped_body(img, w, h)
		"pig":
			_draw_pig_body(img, w, h)
		"sheep":
			_draw_sheep_body(img, w, h)
		"squirrel":
			_draw_squirrel_body(img, w, h)
		"frog":
			_draw_frog_body(img, w, h)
		"turtle":
			_draw_turtle_body(img, w, h)
		"snow_fox":
			_draw_fox_body(img, w, h)
		"polar_bear":
			_draw_bear_body(img, w, h)
		"snow_owl":
			_draw_owl_body(img, w, h)
		"gummy_bear":
			_draw_gummy_body(img, w, h)
		"marshmallow_puff":
			_draw_marshmallow_body(img, w, h)
		"licorice_worm":
			_draw_worm_body(img, w, h)
		"ice_cream_sandwich_man":
			_setup_ice_cream_sandwich_animation()
			return
		"gingerbread_man":
			_setup_gingerbread_man_animation()
			return
		"sand_lizard":
			_draw_lizard_body(img, w, h)
		"desert_scorpion":
			_draw_scorpion_body(img, w, h)
		"meerkat":
			_draw_meerkat_body(img, w, h)
		"ember_crawler":
			_draw_crawler_body(img, w, h)
		"ash_moth":
			_draw_moth_body(img, w, h)
		"magma_slug":
			_draw_slug_body(img, w, h)
		"spirit_fox":
			_draw_fox_body(img, w, h)
		"glow_jelly":
			_draw_jelly_body(img, w, h)
		"lunar_moth":
			_draw_moth_body(img, w, h)
		_:
			_draw_bird_body(img, w, h)

	var tex := ImageTexture.create_from_image(img)
	sprite.texture = tex

# ---------------------------------------------------------------------------
# Animated sprite (ice_cream_sandwich_man only)
# ---------------------------------------------------------------------------

## Sets up the AnimatedSprite2D for the ice_cream_sandwich_man using the
## pet-style spritesheets (idle + walk). Hides the procedural Sprite2D.
func _setup_ice_cream_sandwich_animation() -> void:
	# Look for existing AnimatedSprite2D child first (new scene instances),
	# or create one on-the-fly (pre-existing saves without the node).
	if not animated_sprite:
		animated_sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if not animated_sprite:
		animated_sprite = AnimatedSprite2D.new()
		animated_sprite.name = "AnimatedSprite2D"
		add_child(animated_sprite)
		# Keep the animated sprite below the label
		move_child(animated_sprite, sprite.get_index() + 1 if sprite else 0)
	
	# Hide the procedural sprite, show the animated one
	if sprite:
		sprite.visible = false
	
	var walk_path := "res://assets/generated/pet_ice_cream_sandwich_walk_v4.png"
	var idle_path := "res://assets/generated/pet_ice_cream_sandwich_idle_v4.png"
	var walk_tex: Texture2D = load(walk_path) if ResourceLoader.exists(walk_path) else null
	var idle_tex: Texture2D = load(idle_path) if ResourceLoader.exists(idle_path) else null
	if not walk_tex or not idle_tex:
		# Fall back to static pet texture on the procedural sprite
		if sprite:
			sprite.visible = true
			var pet_tex := load("res://assets/generated/mini_ice_cream_sandwich_pet.png") as Texture2D
			if pet_tex:
				sprite.texture = pet_tex
				sprite.scale = Vector2(2.0, 2.0)
		return
	
	var frames := SpriteFrames.new()
	frames.add_animation("idle")
	frames.add_animation("walk")
	for i in range(8):
		var idle_frame := AtlasTexture.new()
		idle_frame.atlas = idle_tex
		idle_frame.region = Rect2((i % 4) * 48, floori(i / 4) * 48, 48, 48)
		frames.add_frame("idle", idle_frame)
		var walk_frame := AtlasTexture.new()
		walk_frame.atlas = walk_tex
		walk_frame.region = Rect2((i % 4) * 48, floori(i / 4) * 48, 48, 48)
		frames.add_frame("walk", walk_frame)
	frames.set_animation_speed("idle", 4.0)
	frames.set_animation_speed("walk", 8.0)
	frames.set_animation_loop("idle", true)
	frames.set_animation_loop("walk", true)
	animated_sprite.sprite_frames = frames
	# Slightly bigger than the pet (PET_SCALE_BASE 0.7). The Animal node's own
	# scale (0.5–0.75 applied by ExpeditionIsland) stacks on top, giving
	# roughly 0.75–1.125 total — just a bit taller than the pet.
	animated_sprite.scale = Vector2(1.5, 1.5)
	animated_sprite.visible = true
	animated_sprite.play("idle")


## Sets up the AnimatedSprite2D for the gingerbread_man using the same
## pet-style spritesheets format (idle + walk). Hides the procedural Sprite2D.
func _setup_gingerbread_man_animation() -> void:
	if not animated_sprite:
		animated_sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if not animated_sprite:
		animated_sprite = AnimatedSprite2D.new()
		animated_sprite.name = "AnimatedSprite2D"
		add_child(animated_sprite)
		if sprite:
			move_child(animated_sprite, sprite.get_index() + 1)
	
	if sprite:
		sprite.visible = false
	
	var walk_path := "res://assets/generated/pet_gingerbread_man_walk_v4.png"
	var idle_path := "res://assets/generated/pet_gingerbread_man_idle_v4.png"
	var walk_tex: Texture2D = load(walk_path) if ResourceLoader.exists(walk_path) else null
	var idle_tex: Texture2D = load(idle_path) if ResourceLoader.exists(idle_path) else null
	if not walk_tex or not idle_tex:
		if sprite:
			sprite.visible = true
			var pet_tex := load("res://assets/generated/mini_gingerbread_man_pet.png") as Texture2D
			if pet_tex:
				sprite.texture = pet_tex
				sprite.scale = Vector2(2.0, 2.0)
		return
	
	var frames := SpriteFrames.new()
	frames.add_animation("idle")
	frames.add_animation("walk")
	for i in range(8):
		var idle_frame := AtlasTexture.new()
		idle_frame.atlas = idle_tex
		idle_frame.region = Rect2((i % 4) * 48, floori(i / 4) * 48, 48, 48)
		frames.add_frame("idle", idle_frame)
		var walk_frame := AtlasTexture.new()
		walk_frame.atlas = walk_tex
		walk_frame.region = Rect2((i % 4) * 48, floori(i / 4) * 48, 48, 48)
		frames.add_frame("walk", walk_frame)
	frames.set_animation_speed("idle", 4.0)
	frames.set_animation_speed("walk", 8.0)
	frames.set_animation_loop("idle", true)
	frames.set_animation_loop("walk", true)
	animated_sprite.sprite_frames = frames
	# Slightly bigger than the pet. The Animal node's own scale
	# (0.5–0.75 applied by ExpeditionIsland) stacks on top.
	animated_sprite.scale = Vector2(1.5, 1.5)
	animated_sprite.visible = true
	animated_sprite.play("idle")


# ---------------------------------------------------------------------------
# Pixel-art drawing helpers
# ---------------------------------------------------------------------------

func _set_px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
		img.set_pixel(x, y, c)

func _draw_ellipse(img: Image, cx: int, cy: int, rx: int, ry: int, c: Color) -> void:
	for dy in range(-ry, ry + 1):
		for dx in range(-rx, rx + 1):
			if dx * dx * ry * ry + dy * dy * rx * rx <= rx * rx * ry * ry:
				_set_px(img, cx + dx, cy + dy, c)

func _draw_rect_solid(img: Image, x1: int, y1: int, x2: int, y2: int, c: Color) -> void:
	for y in range(y1, y2 + 1):
		for x in range(x1, x2 + 1):
			_set_px(img, x, y, c)

func _draw_line_h(img: Image, y: int, x1: int, x2: int, c: Color) -> void:
	for x in range(x1, x2 + 1):
		_set_px(img, x, y, c)

func _draw_line_v(img: Image, x: int, y1: int, y2: int, c: Color) -> void:
	for y in range(y1, y2 + 1):
		_set_px(img, x, y, c)

func _draw_triangle(img: Image, x1: int, y1: int, x2: int, y2: int, x3: int, y3: int, c: Color) -> void:
	# Simple filled triangle using scanlines
	var min_y: int = mini(y1, mini(y2, y3))
	var max_y: int = maxi(y1, maxi(y2, y3))
	for y in range(min_y, max_y + 1):
		var x_vals: Array[int] = []
		# helper: edge intersection
		var _add_edge := func(ax: int, ay: int, bx: int, by: int):
			if ay == by:
				return
			if (y >= mini(ay, by) and y < maxi(ay, by)) or (y == maxi(ay, by) and y == mini(ay, by)):
				var t: float = (y - ay) / float(by - ay)
				x_vals.append(int(ax + (bx - ax) * t))
		_add_edge.call(x1, y1, x2, y2)
		_add_edge.call(x2, y2, x3, y3)
		_add_edge.call(x3, y3, x1, y1)
		if x_vals.size() >= 2:
			x_vals.sort()
			_draw_line_h(img, y, x_vals[0], x_vals[x_vals.size() - 1], c)

# --- Bird (chicken-like) body ---
func _draw_bird_body(img: Image, w: int, h: int) -> void:
	var cx: int = w / 2
	var body_top: int = 6
	var body_bottom: int = 15
	var body_left: int = 5
	var body_right: int = 18

	# Body oval
	_draw_ellipse(img, cx, 10, 7, 5, body_color)

	# Apply pattern on body area
	match _pattern:
		1: _apply_spots(img, body_left, body_top, body_right, body_bottom, spot_color, 5)
		2: _apply_stripes(img, body_left, body_top, body_right, body_bottom, spot_color, 3)
		3: _apply_patches(img, body_left, body_top, body_right, body_bottom, secondary_color, spot_color, 4)

	# Head
	_draw_ellipse(img, cx + 5, 6, 3, 3, body_color)

	# Eye
	_set_px(img, cx + 6, 6, Color(0.0, 0.0, 0.0))
	_set_px(img, cx + 6, 5, Color(1.0, 1.0, 1.0))

	# Beak
	_draw_triangle(img, cx + 8, 6, cx + 11, 5, cx + 11, 7, accent_color)

	# Comb (on top of head)
	var comb_color: Color = Color.from_hsv(0.02, 0.9, 0.8)
	_set_px(img, cx + 4, 3, comb_color)
	_set_px(img, cx + 5, 2, comb_color)
	_set_px(img, cx + 6, 3, comb_color)

	# Tail feathers
	_draw_ellipse(img, cx - 7, 10, 3, 2, secondary_color)

	# Fill a solid attachment block so legs connect seamlessly to body
	_draw_rect_solid(img, cx - 3, body_bottom - 2, cx + 3, body_bottom - 1, body_color)

	# Legs (2px wide, start inside body so they connect solidly)
	# Spaced with a 3px gap so legs don't touch
	_draw_rect_solid(img, cx - 3, body_bottom - 2, cx - 2, h - 2, accent_color)
	_draw_rect_solid(img, cx + 2, body_bottom - 2, cx + 3, h - 2, accent_color)

	# Feet (separate, not bridging the gap)
	_draw_line_h(img, h - 1, cx - 4, cx - 2, accent_color)
	_draw_line_h(img, h - 1, cx + 2, cx + 4, accent_color)

# --- Quadruped (cow/deer-like) body ---
func _draw_quadruped_body(img: Image, w: int, h: int) -> void:
	var cx: int = w / 2
	var body_top: int = 6
	var body_bottom: int = 13
	var body_left: int = 4
	var body_right: int = 19

	# Body rectangle (torso)
	_draw_round_rect(img, body_left, body_top, body_right, body_bottom, body_color)

	# Apply pattern
	match _pattern:
		1: _apply_spots(img, body_left, body_top, body_right, body_bottom, spot_color, 6)
		2: _apply_stripes(img, body_left, body_top, body_right, body_bottom, spot_color, 4)
		3: _apply_patches(img, body_left, body_top, body_right, body_bottom, secondary_color, spot_color, 3)

	# Head (offset to right side)
	var head_cx: int = cx + 7
	var head_cy: int = body_top - 2
	_draw_ellipse(img, head_cx, head_cy, 3, 3, body_color)

	# Eyes
	_set_px(img, head_cx + 1, head_cy - 1, Color(0.0, 0.0, 0.0))
	_set_px(img, head_cx + 2, head_cy, Color(1.0, 1.0, 1.0))

	# Snout
	if animal_type == "cow":
		_draw_ellipse(img, head_cx + 4, head_cy + 1, 2, 1, accent_color)
	elif animal_type == "goat":
		_draw_ellipse(img, head_cx + 4, head_cy, 1, 1, accent_color)
	else: # deer
		_draw_ellipse(img, head_cx + 4, head_cy, 1, 1, accent_color)

	# Ears
	_draw_ellipse(img, head_cx - 1, head_cy - 4, 1, 2, secondary_color)

	# Horns (deer antlers, goat swept-back horns) or tiny horn nubs (cow)
	if animal_type == "deer":
		_draw_line_v(img, head_cx, 0, head_cy - 4, accent_color)
		_draw_line_v(img, head_cx + 1, 1, head_cy - 4, accent_color)
	elif animal_type == "goat":
		# Swept-back horns
		_draw_line_v(img, head_cx, 1, head_cy - 3, accent_color)
		_set_px(img, head_cx - 1, 2, accent_color)
		_draw_line_v(img, head_cx + 1, 2, head_cy - 3, accent_color)
		_set_px(img, head_cx + 2, 3, accent_color)
		# Goat beard
		_set_px(img, head_cx + 4, head_cy + 2, accent_color)
		_set_px(img, head_cx + 4, head_cy + 3, accent_color)
	else:
		_set_px(img, head_cx, head_cy - 4, accent_color)
		_set_px(img, head_cx + 1, head_cy - 4, accent_color)

	# Fill leg attachment zone so legs connect to body solidly
	_draw_rect_solid(img, body_left, body_bottom, body_right, body_bottom, body_color)

	# Legs (2px wide each, starting at body_bottom)
	# Spaced so paired legs have a 2px gap between them
	_draw_rect_solid(img, body_left + 1, body_bottom, body_left + 2, h - 2, secondary_color)
	_draw_rect_solid(img, body_left + 5, body_bottom, body_left + 6, h - 2, secondary_color)
	_draw_rect_solid(img, body_right - 6, body_bottom, body_right - 5, h - 2, secondary_color)
	_draw_rect_solid(img, body_right - 2, body_bottom, body_right - 1, h - 2, secondary_color)

	# Hooves (separate under each leg, not bridging the gap)
	_draw_rect_solid(img, body_left + 1, h - 2, body_left + 2, h - 1, Color(0.2, 0.2, 0.2))
	_draw_rect_solid(img, body_left + 5, h - 2, body_left + 6, h - 1, Color(0.2, 0.2, 0.2))
	_draw_rect_solid(img, body_right - 6, h - 2, body_right - 5, h - 1, Color(0.2, 0.2, 0.2))
	_draw_rect_solid(img, body_right - 2, h - 2, body_right - 1, h - 1, Color(0.2, 0.2, 0.2))

	# Tail (small)
	var tail_x: int = body_left - 1
	var tail_y: int = body_top + 2
	_set_px(img, tail_x, tail_y, secondary_color)
	_set_px(img, tail_x - 1, tail_y, secondary_color)

# --- Rabbit body ---
func _draw_rabbit_body(img: Image, w: int, h: int) -> void:
	var cx: int = w / 2
	var body_top: int = 8
	var body_bottom: int = 14
	var body_left: int = 7
	var body_right: int = 16

	# Body (round ball)
	_draw_ellipse(img, cx, 12, 5, 4, body_color)

	# Apply pattern
	match _pattern:
		1: _apply_spots(img, body_left, body_top, body_right, body_bottom, spot_color, 3)
		2: _apply_stripes(img, body_left, body_top, body_right, body_bottom, spot_color, 2)
		3: _apply_patches(img, body_left, body_top, body_right, body_bottom, secondary_color, spot_color, 2)

	# Head
	_draw_ellipse(img, cx + 4, 7, 3, 3, body_color)

	# Eye
	_set_px(img, cx + 5, 7, Color(0.0, 0.0, 0.0))
	_set_px(img, cx + 5, 6, Color(1.0, 1.0, 1.0))

	# Nose
	_set_px(img, cx + 7, 7, accent_color)

	# Ears (long pointing up)
	_draw_line_v(img, cx + 3, 1, 5, secondary_color)
	_draw_line_v(img, cx + 5, 1, 5, secondary_color)
	_draw_line_v(img, cx + 3, 1, 1, Color(0.9, 0.7, 0.7))
	_draw_line_v(img, cx + 5, 1, 1, Color(0.9, 0.7, 0.7))

	# Fill a solid attachment zone at the bottom of the body
	_draw_rect_solid(img, cx - 3, body_bottom, cx + 3, body_bottom, body_color)

	# Legs (2px wide solid blocks, attached at body_bottom)
	# Spaced with a 3px gap so legs don't touch
	_draw_rect_solid(img, cx - 3, body_bottom, cx - 2, h - 2, secondary_color)
	_draw_rect_solid(img, cx + 2, body_bottom, cx + 3, h - 2, secondary_color)

	# Tail (tiny ball)
	_set_px(img, cx - 6, 11, Color(1.0, 1.0, 1.0))
	_set_px(img, cx - 6, 12, Color(1.0, 1.0, 1.0))

# --- Pig body (stouter, rounder quadruped) ---
func _draw_pig_body(img: Image, w: int, h: int) -> void:
	var cx: int = w / 2
	var body_top: int = 7
	var body_bottom: int = 14
	var body_left: int = 5
	var body_right: int = 18

	# Round body
	_draw_ellipse(img, cx, 10, 7, 4, body_color)

	# Apply pattern on body
	match _pattern:
		1: _apply_spots(img, body_left, body_top, body_right, body_bottom, spot_color, 4)
		2: _apply_stripes(img, body_left, body_top, body_right, body_bottom, spot_color, 3)
		3: _apply_patches(img, body_left, body_top, body_right, body_bottom, secondary_color, spot_color, 2)

	# Head (snout pointing right)
	_draw_ellipse(img, cx + 7, 8, 3, 3, body_color)

	# Snout (flat end)
	_draw_ellipse(img, cx + 10, 9, 2, 2, accent_color)

	# Eye
	_set_px(img, cx + 8, 7, Color(0.0, 0.0, 0.0))

	# Ear
	_set_px(img, cx + 5, 5, secondary_color)
	_set_px(img, cx + 6, 5, secondary_color)

	# Tail (curly swirl hint)
	_set_px(img, cx - 6, 8, secondary_color)
	_set_px(img, cx - 7, 9, secondary_color)

	# Fill leg attachment zone
	_draw_rect_solid(img, body_left, body_bottom, body_right, body_bottom, body_color)

	# Short stubby legs
	_draw_rect_solid(img, body_left + 1, body_bottom, body_left + 2, h - 2, secondary_color)
	_draw_rect_solid(img, body_left + 5, body_bottom, body_left + 6, h - 2, secondary_color)
	_draw_rect_solid(img, body_right - 6, body_bottom, body_right - 5, h - 2, secondary_color)
	_draw_rect_solid(img, body_right - 2, body_bottom, body_right - 1, h - 2, secondary_color)

	# Tiny hooves
	_draw_rect_solid(img, body_left + 1, h - 2, body_left + 2, h - 1, Color(0.3, 0.25, 0.2))
	_draw_rect_solid(img, body_left + 5, h - 2, body_left + 6, h - 1, Color(0.3, 0.25, 0.2))
	_draw_rect_solid(img, body_right - 6, h - 2, body_right - 5, h - 1, Color(0.3, 0.25, 0.2))
	_draw_rect_solid(img, body_right - 2, h - 2, body_right - 1, h - 1, Color(0.3, 0.25, 0.2))

# --- Sheep body (fluffy, wide) ---
func _draw_sheep_body(img: Image, w: int, h: int) -> void:
	var cx: int = w / 2
	var body_top: int = 5
	var body_bottom: int = 13
	var body_left: int = 4
	var body_right: int = 19

	# Fluffy wool body (wider than normal quadruped)
	_draw_ellipse(img, cx, 9, 8, 5, body_color)

	# Apply pattern as wool markings
	match _pattern:
		1: _apply_spots(img, body_left, body_top, body_right, body_bottom, spot_color, 5)
		2: _apply_stripes(img, body_left, body_top, body_right, body_bottom, spot_color, 3)
		3: _apply_patches(img, body_left, body_top, body_right, body_bottom, secondary_color, spot_color, 3)

	# Head (small, facing right)
	_draw_ellipse(img, cx + 7, 6, 2, 2, secondary_color)

	# Eye
	_set_px(img, cx + 8, 6, Color(0.0, 0.0, 0.0))

	# Ears (floppy)
	_set_px(img, cx + 5, 4, accent_color)
	_set_px(img, cx + 6, 4, accent_color)

	# Fill leg attachment
	_draw_rect_solid(img, body_left, body_bottom, body_right, body_bottom, body_color)

	# Thin legs
	_draw_rect_solid(img, body_left + 2, body_bottom, body_left + 2, h - 2, secondary_color)
	_draw_rect_solid(img, body_left + 6, body_bottom, body_left + 6, h - 2, secondary_color)
	_draw_rect_solid(img, body_right - 6, body_bottom, body_right - 6, h - 2, secondary_color)
	_draw_rect_solid(img, body_right - 2, body_bottom, body_right - 2, h - 2, secondary_color)

	# Hooves
	_draw_rect_solid(img, body_left + 2, h - 2, body_left + 2, h - 1, Color(0.25, 0.25, 0.25))
	_draw_rect_solid(img, body_left + 6, h - 2, body_left + 6, h - 1, Color(0.25, 0.25, 0.25))
	_draw_rect_solid(img, body_right - 6, h - 2, body_right - 6, h - 1, Color(0.25, 0.25, 0.25))
	_draw_rect_solid(img, body_right - 2, h - 2, body_right - 2, h - 1, Color(0.25, 0.25, 0.25))

	# Fluffy tail
	_draw_ellipse(img, cx - 8, 9, 2, 2, body_color)

# --- Squirrel body (small, big tail) ---
func _draw_squirrel_body(img: Image, w: int, h: int) -> void:
	var cx: int = w / 2
	var body_top: int = 7
	var body_bottom: int = 14

	# Small body
	_draw_ellipse(img, cx, 10, 4, 4, body_color)

	# Apply pattern
	match _pattern:
		1: _apply_spots(img, cx - 3, body_top, cx + 3, body_bottom, spot_color, 2)
		2: _apply_stripes(img, cx - 3, body_top, cx + 3, body_bottom, accent_color, 2)
		3: _apply_patches(img, cx - 3, body_top, cx + 3, body_bottom, secondary_color, spot_color, 2)

	# Head
	_draw_ellipse(img, cx + 4, 7, 2, 2, body_color)

	# Eye
	_set_px(img, cx + 5, 7, Color(0.0, 0.0, 0.0))

	# Ear tufts
	_set_px(img, cx + 3, 5, accent_color)
	_set_px(img, cx + 4, 5, accent_color)

	# Big bushy tail (behind body, curling up)
	_draw_ellipse(img, cx - 5, 7, 3, 3, secondary_color)
	_set_px(img, cx - 7, 6, secondary_color)
	_set_px(img, cx - 8, 7, secondary_color)
	_set_px(img, cx - 8, 5, secondary_color)

	# Legs (small)
	_draw_rect_solid(img, cx - 2, body_bottom, cx - 1, h - 2, secondary_color)
	_draw_rect_solid(img, cx + 1, body_bottom, cx + 2, h - 2, secondary_color)

	# Tiny paws
	_draw_rect_solid(img, cx - 2, h - 2, cx - 1, h - 1, accent_color)
	_draw_rect_solid(img, cx + 1, h - 2, cx + 2, h - 1, accent_color)

# --- Frog body (crouched, wide) ---
func _draw_frog_body(img: Image, w: int, h: int) -> void:
	var cx: int = w / 2

	# Body (wide oval)
	_draw_ellipse(img, cx, 10, 7, 4, body_color)

	# Apply pattern
	match _pattern:
		1: _apply_spots(img, cx - 5, 6, cx + 5, 14, spot_color, 4)
		3: _apply_patches(img, cx - 5, 6, cx + 5, 14, secondary_color, spot_color, 2)

	# Head (merged with body, wide)
	_draw_ellipse(img, cx + 6, 9, 3, 3, body_color)

	# Big eyes (on top of head)
	_draw_ellipse(img, cx + 6, 7, 2, 2, Color(1.0, 1.0, 1.0))
	_set_px(img, cx + 7, 7, Color(0.0, 0.0, 0.0))
	_draw_ellipse(img, cx + 9, 7, 2, 2, Color(1.0, 1.0, 1.0))
	_set_px(img, cx + 10, 7, Color(0.0, 0.0, 0.0))

	# Mouth line
	_draw_line_h(img, 11, cx + 7, cx + 11, accent_color)

	# Front legs (bent)
	_draw_rect_solid(img, cx - 5, 12, cx - 4, h - 3, secondary_color)
	_draw_rect_solid(img, cx - 6, h - 3, cx - 4, h - 2, secondary_color)
	_draw_rect_solid(img, cx + 4, 12, cx + 5, h - 3, secondary_color)
	_draw_rect_solid(img, cx + 4, h - 3, cx + 6, h - 2, secondary_color)

	# Back legs (large, folded)
	_draw_ellipse(img, cx - 3, 13, 3, 2, secondary_color)
	_draw_ellipse(img, cx + 3, 13, 3, 2, secondary_color)

	# Webbed feet hints
	_draw_line_h(img, h - 1, cx - 4, cx - 2, accent_color)
	_draw_line_h(img, h - 1, cx + 2, cx + 4, accent_color)

# --- Turtle body (dome shell) ---
func _draw_turtle_body(img: Image, w: int, h: int) -> void:
	var cx: int = w / 2
	var body_top: int = 5
	var body_bottom: int = 14

	# Shell (large dome)
	_draw_ellipse(img, cx, 9, 7, 5, body_color)

	# Shell pattern (hexagonal/scute hint)
	_draw_ellipse(img, cx, 8, 4, 3, secondary_color)
	_set_px(img, cx, 8, accent_color)
	_set_px(img, cx - 2, 9, accent_color)
	_set_px(img, cx + 2, 9, accent_color)
	_set_px(img, cx, 11, accent_color)

	# Apply pattern overlay
	match _pattern:
		1: _apply_spots(img, cx - 5, body_top, cx + 5, body_bottom, spot_color, 3)
		2: _apply_stripes(img, cx - 5, body_top, cx + 5, body_bottom, spot_color, 2)

	# Head (small, sticking out front)
	_draw_ellipse(img, cx + 8, 10, 2, 2, Color(0.6, 0.6, 0.5))

	# Eye
	_set_px(img, cx + 9, 9, Color(0.0, 0.0, 0.0))

	# Legs (four stubby ones)
	_draw_rect_solid(img, cx - 5, body_bottom, cx - 4, h - 2, Color(0.6, 0.6, 0.5))
	_draw_rect_solid(img, cx - 1, body_bottom, cx + 0, h - 2, Color(0.6, 0.6, 0.5))
	_draw_rect_solid(img, cx + 3, body_bottom, cx + 4, h - 2, Color(0.6, 0.6, 0.5))
	_draw_rect_solid(img, cx + 6, body_bottom, cx + 7, h - 2, Color(0.6, 0.6, 0.5))

	# Tiny claws
	_set_px(img, cx - 5, h - 1, Color(0.9, 0.9, 0.7))
	_set_px(img, cx - 1, h - 1, Color(0.9, 0.9, 0.7))
	_set_px(img, cx + 3, h - 1, Color(0.9, 0.9, 0.7))
	_set_px(img, cx + 6, h - 1, Color(0.9, 0.9, 0.7))

	# Tail (tiny stub)
	_set_px(img, cx - 8, 11, Color(0.6, 0.6, 0.5))


# --- Fox body (snow_fox, spirit_fox) ---
func _draw_fox_body(img: Image, w: int, h: int) -> void:
	var cx: int = w / 2
	# Slim body
	_draw_ellipse(img, cx, 9, 6, 4, body_color)
	match _pattern:
		1: _apply_spots(img, cx - 4, 6, cx + 4, 12, spot_color, 3)
		2: _apply_stripes(img, cx - 4, 6, cx + 4, 12, spot_color, 2)
		3: _apply_patches(img, cx - 4, 6, cx + 4, 12, secondary_color, spot_color, 3)
	# Head
	_draw_ellipse(img, cx + 7, 8, 3, 3, body_color)
	# Pointed snout
	_set_px(img, cx + 10, 8, accent_color)
	_set_px(img, cx + 10, 9, accent_color)
	_set_px(img, cx + 10, 7, accent_color)
	# Ears (pointed triangles)
	_set_px(img, cx + 5, 3, accent_color)
	_set_px(img, cx + 6, 2, accent_color)
	_set_px(img, cx + 7, 3, accent_color)
	# Eye
	_set_px(img, cx + 8, 7, Color(0.0, 0.0, 0.0))
	# Legs
	_draw_rect_solid(img, cx - 3, 12, cx - 2, h - 2, secondary_color)
	_draw_rect_solid(img, cx + 3, 12, cx + 4, h - 2, secondary_color)
	# Bushy tail
	_draw_ellipse(img, cx - 7, 10, 3, 2, body_color)
	_set_px(img, cx - 9, 10, accent_color)


# --- Bear body (polar_bear) ---
func _draw_bear_body(img: Image, w: int, h: int) -> void:
	var cx: int = w / 2
	# Large bulky body
	_draw_ellipse(img, cx, 9, 8, 5, body_color)
	match _pattern:
		1: _apply_spots(img, cx - 6, 6, cx + 6, 13, spot_color, 4)
		2: _apply_stripes(img, cx - 6, 6, cx + 6, 13, spot_color, 2)
		3: _apply_patches(img, cx - 6, 6, cx + 6, 13, secondary_color, spot_color, 3)
	# Large head
	_draw_ellipse(img, cx + 9, 8, 4, 4, body_color)
	# Snout
	_draw_ellipse(img, cx + 12, 9, 2, 2, accent_color)
	# Small ears
	_draw_ellipse(img, cx + 7, 4, 1, 2, secondary_color)
	_draw_ellipse(img, cx + 9, 4, 1, 2, secondary_color)
	# Eyes
	_set_px(img, cx + 10, 7, Color(0.0, 0.0, 0.0))
	_set_px(img, cx + 11, 7, Color(0.0, 0.0, 0.0))
	# Thick legs
	_draw_rect_solid(img, cx - 5, 13, cx - 3, h - 2, secondary_color)
	_draw_rect_solid(img, cx + 3, 13, cx + 5, h - 2, secondary_color)
	# Paws
	_draw_rect_solid(img, cx - 5, h - 2, cx - 3, h - 1, Color(0.3, 0.3, 0.3))
	_draw_rect_solid(img, cx + 3, h - 2, cx + 5, h - 1, Color(0.3, 0.3, 0.3))


# --- Owl body (snow_owl) ---
func _draw_owl_body(img: Image, w: int, h: int) -> void:
	var cx: int = w / 2
	# Round body
	_draw_ellipse(img, cx, 10, 7, 6, body_color)
	match _pattern:
		1: _apply_spots(img, cx - 5, 5, cx + 5, 15, spot_color, 5)
		2: _apply_stripes(img, cx - 5, 5, cx + 5, 15, spot_color, 3)
	# Head (big round)
	_draw_ellipse(img, cx + 1, 5, 5, 4, body_color)
	# Ear tufts
	_set_px(img, cx - 3, 1, accent_color)
	_set_px(img, cx - 2, 1, accent_color)
	_set_px(img, cx + 4, 1, accent_color)
	_set_px(img, cx + 5, 1, accent_color)
	# Big eyes
	_draw_ellipse(img, cx, 5, 2, 2, Color(1.0, 1.0, 0.8))
	_draw_ellipse(img, cx + 3, 5, 2, 2, Color(1.0, 1.0, 0.8))
	_set_px(img, cx, 5, Color(0.0, 0.0, 0.0))
	_set_px(img, cx + 3, 5, Color(0.0, 0.0, 0.0))
	# Beak
	_draw_triangle(img, cx + 1, 6, cx + 2, 6, cx + 2, 8, accent_color)
	# Wings
	_draw_ellipse(img, cx - 7, 10, 2, 4, secondary_color)
	_draw_ellipse(img, cx + 8, 10, 2, 4, secondary_color)
	# Feet
	_draw_rect_solid(img, cx - 2, h - 2, cx - 1, h - 1, accent_color)
	_draw_rect_solid(img, cx + 2, h - 2, cx + 3, h - 1, accent_color)


# --- Gummy body (gummy_bear) ---
func _draw_gummy_body(img: Image, w: int, h: int) -> void:
	var cx: int = w / 2
	# Round blob body
	_draw_ellipse(img, cx, 9, 7, 6, body_color)
	# Shiny highlight
	_draw_ellipse(img, cx - 2, 6, 2, 2, Color(body_color.r * 1.3, body_color.g * 1.3, body_color.b * 1.3, 0.7))
	# Small stubby limbs
	_draw_ellipse(img, cx - 4, 13, 2, 2, body_color)
	_draw_ellipse(img, cx + 4, 13, 2, 2, body_color)
	# Eyes (cute dots)
	_set_px(img, cx - 2, 8, Color(0.0, 0.0, 0.0))
	_set_px(img, cx + 2, 8, Color(0.0, 0.0, 0.0))
	# Tiny smile
	_set_px(img, cx - 1, 10, Color(0.0, 0.0, 0.0))
	_set_px(img, cx, 11, Color(0.0, 0.0, 0.0))
	_set_px(img, cx + 1, 10, Color(0.0, 0.0, 0.0))


# --- Marshmallow body (marshmallow_puff) ---
func _draw_marshmallow_body(img: Image, w: int, h: int) -> void:
	var cx: int = w / 2
	# Pillow-shaped body
	_draw_round_rect(img, cx - 6, 5, cx + 6, 14, body_color)
	# Roundness at top
	_draw_ellipse(img, cx, 6, 6, 3, body_color)
	# Fluffy top highlight
	_draw_ellipse(img, cx - 2, 5, 2, 2, Color(1.0, 1.0, 1.0, 0.5))
	# Eyes
	_set_px(img, cx - 2, 8, Color(0.0, 0.0, 0.0))
	_set_px(img, cx + 2, 8, Color(0.0, 0.0, 0.0))
	# Cute blush
	_draw_ellipse(img, cx - 4, 9, 1, 1, Color(1.0, 0.7, 0.7, 0.5))


# --- Worm body (licorice_worm) ---
func _draw_worm_body(img: Image, w: int, h: int) -> void:
	var cx: int = w / 2
	# Long wavy body
	var body_points: Array[Vector2] = [Vector2(cx - 8, 11), Vector2(cx - 5, 10), Vector2(cx - 1, 9), Vector2(cx + 3, 10), Vector2(cx + 6, 11), Vector2(cx + 9, 10)]
	for i in range(body_points.size() - 1):
		var p1 := body_points[i]
		var p2 := body_points[i + 1]
		var mid := (p1 + p2) / 2.0
		_draw_ellipse(img, int(mid.x), int(mid.y), 2, 3, body_color)
	# Head segment
	_draw_ellipse(img, cx + 9, 9, 2, 2, body_color)
	# Eyes
	_set_px(img, cx + 10, 8, Color(1.0, 1.0, 1.0))
	_set_px(img, cx + 11, 8, Color(1.0, 1.0, 1.0))
	_set_px(img, cx + 10, 8, Color(0.0, 0.0, 0.0))
	# Stripes along body (licorice twist)
	for i in range(3):
		var sx := cx - 6 + i * 4
		_draw_line_v(img, sx, 8, 12, accent_color)


# --- Ice cream sandwich man body (ice_cream_sandwich_man) ---
# Rectangular ice cream sandwich character: tall rectangular body made of
# bottom wafer + cream + top wafer, with rectangular arm/leg stubs.
func _draw_ice_cream_sandwich_man_body(img: Image, w: int, h: int) -> void:
	var cx: int = w / 2
	# ── Legs (two rectangular stubs at bottom, chocolate brown) ──
	_draw_rect_solid(img, cx - 4, h - 5, cx - 2, h - 1, secondary_color)
	_draw_rect_solid(img, cx + 2, h - 5, cx + 4, h - 1, secondary_color)
	# Little feet/shoes
	_draw_rect_solid(img, cx - 4, h - 1, cx - 2, h - 1, spot_color)
	_draw_rect_solid(img, cx + 2, h - 1, cx + 4, h - 1, spot_color)
	# ── Body: bottom chocolate wafer (wide rectangle) ──
	_draw_rect_solid(img, cx - 6, 12, cx + 6, 15, body_color)
	# Wafer texture dots on bottom wafer
	_set_px(img, cx - 4, 13, secondary_color)
	_set_px(img, cx - 1, 13, secondary_color)
	_set_px(img, cx + 2, 13, secondary_color)
	_set_px(img, cx + 5, 13, secondary_color)
	_set_px(img, cx - 4, 14, secondary_color)
	_set_px(img, cx - 1, 14, secondary_color)
	_set_px(img, cx + 2, 14, secondary_color)
	_set_px(img, cx + 5, 14, secondary_color)
	# ── Body: cream filling (tall rectangle) ──
	_draw_rect_solid(img, cx - 5, 7, cx + 5, 11, accent_color)
	# Cream highlight stripe
	_draw_line_h(img, 8, cx - 4, cx + 4, Color(accent_color.r * 1.08, accent_color.g * 1.08, accent_color.b * 1.08))
	# Drip detail on cream
	_set_px(img, cx - 5, 12, accent_color)
	_set_px(img, cx + 5, 12, accent_color)
	# ── Arms (rectangular stubs sticking out from cream section) ──
	_draw_rect_solid(img, cx - 9, 8, cx - 6, 10, secondary_color)
	_draw_rect_solid(img, cx + 6, 8, cx + 9, 10, secondary_color)
	# Little hands
	_draw_rect_solid(img, cx - 10, 8, cx - 9, 10, spot_color)
	_draw_rect_solid(img, cx + 9, 8, cx + 10, 10, spot_color)
	# ── Body: top chocolate wafer (wide rectangle) ──
	_draw_rect_solid(img, cx - 6, 4, cx + 6, 6, body_color)
	# Wafer texture dots on top wafer
	_set_px(img, cx - 4, 4, secondary_color)
	_set_px(img, cx - 1, 4, secondary_color)
	_set_px(img, cx + 2, 4, secondary_color)
	_set_px(img, cx + 5, 4, secondary_color)
	_set_px(img, cx - 4, 5, secondary_color)
	_set_px(img, cx - 1, 5, secondary_color)
	_set_px(img, cx + 2, 5, secondary_color)
	_set_px(img, cx + 5, 5, secondary_color)
	# ── Head (small rectangular cream blob on top) ──
	_draw_rect_solid(img, cx - 4, 0, cx + 4, 3, accent_color)
	_draw_rect_solid(img, cx - 3, 0, cx + 3, 0, Color(accent_color.r * 1.1, accent_color.g * 1.1, accent_color.b * 1.1))
	# ── Eyes (black dots) ──
	_set_px(img, cx - 2, 1, Color(0.0, 0.0, 0.0))
	_set_px(img, cx + 2, 1, Color(0.0, 0.0, 0.0))
	# ── Cute smile ──
	_set_px(img, cx - 1, 2, Color(0.0, 0.0, 0.0))
	_set_px(img, cx, 3, Color(0.0, 0.0, 0.0))
	_set_px(img, cx + 1, 2, Color(0.0, 0.0, 0.0))
	# ── Rosy blush ──
	_set_px(img, cx - 4, 2, Color(1.0, 0.6, 0.6, 0.6))
	_set_px(img, cx + 4, 2, Color(1.0, 0.6, 0.6, 0.6))


# --- Gingerbread man body (gingerbread_man) ---
# Round-headed gingerbread cookie character with icing details
func _draw_gingerbread_man_body(img: Image, w: int, h: int) -> void:
	var cx: int = w / 2
	# ── Legs (two rounded stubs at bottom) ──
	_draw_rect_solid(img, cx - 4, h - 5, cx - 2, h - 1, body_color)
	_draw_rect_solid(img, cx + 2, h - 5, cx + 4, h - 1, body_color)
	_set_px(img, cx - 5, h - 2, body_color)
	_set_px(img, cx - 5, h - 3, body_color)
	_set_px(img, cx + 5, h - 2, body_color)
	_set_px(img, cx + 5, h - 3, body_color)
	# ── Body (torso, wider at hips, narrower at shoulders) ──
	_draw_rect_solid(img, cx - 5, 7, cx + 5, 14, body_color)
	# Shoulders (slightly narrower)
	_draw_rect_solid(img, cx - 4, 6, cx + 4, 6, body_color)
	# ── Icing zigzag on chest ──
	_set_px(img, cx - 3, 8, secondary_color)
	_set_px(img, cx - 2, 9, secondary_color)
	_set_px(img, cx - 1, 8, secondary_color)
	_set_px(img, cx, 9, secondary_color)
	_set_px(img, cx + 1, 8, secondary_color)
	_set_px(img, cx + 2, 9, secondary_color)
	_set_px(img, cx + 3, 8, secondary_color)
	# ── Icing buttons ──
	_set_px(img, cx - 1, 10, secondary_color)
	_set_px(img, cx, 10, secondary_color)
	_set_px(img, cx - 1, 12, secondary_color)
	_set_px(img, cx, 12, secondary_color)
	# ── Arms (sticking out from shoulders) ──
	_draw_rect_solid(img, cx - 8, 6, cx - 5, 8, body_color)
	_draw_rect_solid(img, cx + 5, 6, cx + 8, 8, body_color)
	# Little round hands
	_set_px(img, cx - 9, 7, body_color)
	_set_px(img, cx - 9, 6, body_color)
	_set_px(img, cx + 9, 7, body_color)
	_set_px(img, cx + 9, 6, body_color)
	# ── Head (round) ──
	_draw_rect_solid(img, cx - 4, 0, cx + 4, 5, body_color)
	_set_px(img, cx - 5, 1, body_color)
	_set_px(img, cx - 5, 2, body_color)
	_set_px(img, cx - 5, 3, body_color)
	_set_px(img, cx + 5, 1, body_color)
	_set_px(img, cx + 5, 2, body_color)
	_set_px(img, cx + 5, 3, body_color)
	_set_px(img, cx - 4, 0, body_color)
	_set_px(img, cx + 4, 0, body_color)
	# ── Eyes ──
	_set_px(img, cx - 2, 2, Color(0.0, 0.0, 0.0))
	_set_px(img, cx + 2, 2, Color(0.0, 0.0, 0.0))
	# ── Eye shine ──
	_set_px(img, cx - 1, 1, Color(1.0, 1.0, 1.0))
	_set_px(img, cx + 3, 1, Color(1.0, 1.0, 1.0))
	# ── Smile ──
	_set_px(img, cx - 2, 4, Color(0.0, 0.0, 0.0))
	_set_px(img, cx - 1, 5, Color(0.0, 0.0, 0.0))
	_set_px(img, cx, 5, Color(0.0, 0.0, 0.0))
	_set_px(img, cx + 1, 5, Color(0.0, 0.0, 0.0))
	_set_px(img, cx + 2, 4, Color(0.0, 0.0, 0.0))
	# ── Rosy cheeks ──
	_set_px(img, cx - 4, 3, Color(1.0, 0.5, 0.5, 0.6))
	_set_px(img, cx + 4, 3, Color(1.0, 0.5, 0.5, 0.6))


# --- Lizard body (sand_lizard) ---
func _draw_lizard_body(img: Image, w: int, h: int) -> void:
	var cx: int = w / 2
	# Elongated body
	_draw_ellipse(img, cx, 9, 5, 3, body_color)
	match _pattern:
		1: _apply_spots(img, cx - 4, 7, cx + 4, 12, spot_color, 3)
		2: _apply_stripes(img, cx - 4, 7, cx + 4, 12, spot_color, 2)
	# Head (pointed)
	_draw_ellipse(img, cx + 8, 8, 3, 2, body_color)
	# Eye
	_set_px(img, cx + 9, 7, Color(0.0, 0.0, 0.0))
	# Tiny legs
	_draw_line_v(img, cx - 3, 11, h - 2, secondary_color)
	_draw_line_v(img, cx + 2, 11, h - 2, secondary_color)
	_draw_line_v(img, cx - 1, 11, h - 2, secondary_color)
	_draw_line_v(img, cx + 4, 11, h - 2, secondary_color)
	# Long tail
	_draw_line_h(img, 10, cx - 9, cx - 4, body_color)
	_draw_line_h(img, 11, cx - 9, cx - 4, body_color)


# --- Scorpion body ---
func _draw_scorpion_body(img: Image, w: int, h: int) -> void:
	var cx: int = w / 2
	# Body segments
	_draw_ellipse(img, cx, 9, 4, 3, body_color)
	_draw_ellipse(img, cx - 3, 9, 2, 2, secondary_color)
	# Tail (curved upward)
	var tail_x := cx - 5
	var tail_y := 9
	for i in range(4):
		_set_px(img, tail_x, tail_y, body_color)
		tail_x -= 1
		tail_y -= 1
	# Stinger tip
	_draw_ellipse(img, tail_x - 1, tail_y, 1, 1, accent_color)
	# Head
	_draw_ellipse(img, cx + 5, 8, 2, 2, body_color)
	# Eyes
	_set_px(img, cx + 6, 7, Color(0.0, 0.0, 0.0))
	_set_px(img, cx + 7, 7, Color(0.0, 0.0, 0.0))
	# Pincers
	_draw_ellipse(img, cx + 7, 10, 2, 1, accent_color)
	_draw_ellipse(img, cx + 8, 9, 1, 1, accent_color)
	# Legs
	for i in range(4):
		_set_px(img, cx - 1 + i * 2, 11, secondary_color)
		_set_px(img, cx - 1 + i * 2, 12, secondary_color)
		_set_px(img, cx - 1 + i * 2, h - 1, secondary_color)


# --- Meerkat body ---
func _draw_meerkat_body(img: Image, w: int, h: int) -> void:
	var cx: int = w / 2
	# Tall upright body
	_draw_ellipse(img, cx, 11, 4, 5, body_color)
	# Head
	_draw_ellipse(img, cx, 5, 3, 3, body_color)
	# Dark eye patches
	_draw_ellipse(img, cx - 1, 4, 2, 1, spot_color)
	_draw_ellipse(img, cx + 1, 4, 2, 1, spot_color)
	# Eyes
	_set_px(img, cx - 1, 4, Color(0.0, 0.0, 0.0))
	_set_px(img, cx + 1, 4, Color(0.0, 0.0, 0.0))
	# Snout
	_set_px(img, cx, 6, accent_color)
	_set_px(img, cx, 7, accent_color)
	# Arms at sides
	_draw_rect_solid(img, cx - 6, 9, cx - 5, 12, secondary_color)
	_draw_rect_solid(img, cx + 5, 9, cx + 6, 12, secondary_color)
	# Legs
	_draw_rect_solid(img, cx - 2, 14, cx - 1, h - 1, secondary_color)
	_draw_rect_solid(img, cx + 1, 14, cx + 2, h - 1, secondary_color)


# --- Crawler body (ember_crawler, insect) ---
func _draw_crawler_body(img: Image, w: int, h: int) -> void:
	var cx: int = w / 2
	# Segmented insect body
	_draw_ellipse(img, cx - 2, 9, 4, 3, body_color)
	_draw_ellipse(img, cx + 3, 9, 3, 2, secondary_color)
	# Glowing abdomen (ember)
	_draw_ellipse(img, cx - 5, 9, 2, 2, spot_color)
	# Head
	_draw_ellipse(img, cx + 7, 8, 2, 2, body_color)
	# Eyes (glowing)
	_set_px(img, cx + 8, 7, spot_color)
	_set_px(img, cx + 9, 7, spot_color)
	# Antennae
	_set_px(img, cx + 8, 5, secondary_color)
	_set_px(img, cx + 9, 4, secondary_color)
	# Legs
	for i in range(3):
		_set_px(img, cx - 3 + i * 3, 11, secondary_color)
		_set_px(img, cx - 3 + i * 3, h - 2, secondary_color)


# --- Moth body (ash_moth, lunar_moth) ---
func _draw_moth_body(img: Image, w: int, h: int) -> void:
	var cx: int = w / 2
	# Small body
	_draw_ellipse(img, cx, 10, 3, 5, body_color)
	# Large wings
	_draw_ellipse(img, cx - 6, 9, 5, 4, secondary_color)
	_draw_ellipse(img, cx + 6, 9, 5, 4, secondary_color)
	# Wing details
	_draw_ellipse(img, cx - 5, 8, 3, 2, accent_color)
	_draw_ellipse(img, cx + 5, 8, 3, 2, accent_color)
	# Head
	_draw_ellipse(img, cx, 6, 2, 2, body_color)
	# Antennae
	_set_px(img, cx - 2, 4, secondary_color)
	_set_px(img, cx - 3, 3, secondary_color)
	_set_px(img, cx + 2, 4, secondary_color)
	_set_px(img, cx + 3, 3, secondary_color)
	# Eyes
	_set_px(img, cx, 5, spot_color)
	_set_px(img, cx + 1, 5, spot_color)


# --- Slug body (magma_slug) ---
func _draw_slug_body(img: Image, w: int, h: int) -> void:
	var cx: int = w / 2
	# Elongated body with a hump
	_draw_ellipse(img, cx, 11, 7, 4, body_color)
	# Shell hump
	_draw_ellipse(img, cx - 2, 9, 4, 3, secondary_color)
	# Glowing core in hump
	_draw_ellipse(img, cx - 2, 9, 2, 2, spot_color)
	# Eye stalks
	_draw_line_v(img, cx - 2, 4, 6, body_color)
	_draw_line_v(img, cx + 2, 4, 6, body_color)
	# Eyes
	_set_px(img, cx - 2, 4, Color(0.0, 0.0, 0.0))
	_set_px(img, cx + 2, 4, Color(0.0, 0.0, 0.0))
	# Slime trail
	_draw_line_h(img, h - 1, cx - 7, cx + 7, Color(0.5, 0.5, 0.5, 0.5))


# --- Jelly body (glow_jelly) ---
func _draw_jelly_body(img: Image, w: int, h: int) -> void:
	var cx: int = w / 2
	# Translucent dome
	_draw_ellipse(img, cx, 8, 6, 6, body_color)
	# Inner glow
	_draw_ellipse(img, cx, 8, 4, 4, secondary_color)
	# Core
	_draw_ellipse(img, cx, 8, 2, 2, spot_color)
	# Tentacles
	var tentacle_x := [cx - 4, cx - 1, cx + 1, cx + 4]
	for tx in tentacle_x:
		_draw_line_v(img, tx, 12, h - 1, body_color)
		_set_px(img, tx, h - 1, spot_color)


func _draw_round_rect(img: Image, x1: int, y1: int, x2: int, y2: int, c: Color) -> void:
	_draw_rect_solid(img, x1, y1, x2, y2, c)
	# Round the corners slightly
	_set_px(img, x1, y1, c)
	_set_px(img, x2, y1, c)
	_set_px(img, x1, y2, c)
	_set_px(img, x2, y2, c)

# --- Pattern helpers ---
func _apply_spots(img: Image, x1: int, y1: int, x2: int, y2: int, c: Color, count: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.set_seed(randi())
	for i in range(count):
		var sx: int = rng.randi_range(x1 + 1, x2 - 1)
		var sy: int = rng.randi_range(y1 + 1, y2 - 1)
		var r: int = rng.randi_range(1, 2)
		_draw_ellipse(img, sx, sy, r, r, c)

func _apply_stripes(img: Image, x1: int, y1: int, x2: int, y2: int, c: Color, count: int) -> void:
	var step: float = (x2 - x1) / float(count + 1)
	for i in range(1, count + 1):
		var sx: int = x1 + int(i * step)
		_draw_line_v(img, sx, y1, y2, c)

func _apply_patches(img: Image, x1: int, y1: int, x2: int, y2: int, c1: Color, c2: Color, count: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.set_seed(randi())
	for i in range(count):
		var sx: int = rng.randi_range(x1, x2 - 2)
		var sy: int = rng.randi_range(y1, y2 - 2)
		var pw: int = rng.randi_range(2, 4)
		var ph: int = rng.randi_range(1, 2)
		var patch_color: Color = c1 if i % 2 == 0 else c2
		_draw_rect_solid(img, sx, sy, sx + pw, sy + ph, patch_color)

# ---------------------------------------------------------------------------
# Creature dialogue
# ---------------------------------------------------------------------------

## Cooldown between dialogue shows to prevent spam while player is nearby.
const DIALOGUE_COOLDOWN: float = 5.0

var _last_dialogue_time: float = -999.0

## Whether this creature type has unique dialogue lines.
func _has_dialogue() -> bool:
	return animal_type in ["gingerbread_man", "ice_cream_sandwich_man"]

## Returns a random dialogue line appropriate for this creature type.
func _get_dialogue_line() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	match animal_type:
		"gingerbread_man":
			return GINGERBREAD_LINES[rng.randi() % GINGERBREAD_LINES.size()]
		"ice_cream_sandwich_man":
			return SANDWICH_LINES[rng.randi() % SANDWICH_LINES.size()]
		_:
			return "..."

## Build the dialogue bubble as a child Node2D with a styled Label.
func _setup_dialogue() -> void:
	if not _has_dialogue():
		return
	_dialogue_bubble = Node2D.new()
	_dialogue_bubble.name = "DialogueBubble"
	_dialogue_bubble.position = Vector2(0, -38)
	_dialogue_bubble.visible = false
	
	_dialogue_label = Label.new()
	_dialogue_label.name = "DialogueLabel"
	_dialogue_label.size = Vector2(80, 18)
	_dialogue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dialogue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_dialogue_label.add_theme_font_size_override("font_size", 6)
	_dialogue_label.add_theme_color_override("font_color", Color.WHITE)
	
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.15, 0.85)
	sb.border_color = Color(1.0, 0.7, 0.3, 0.9)
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = 5
	sb.corner_radius_top_right = 5
	sb.corner_radius_bottom_left = 5
	sb.corner_radius_bottom_right = 5
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	_dialogue_label.add_theme_stylebox_override("normal", sb)
	
	_dialogue_bubble.add_child(_dialogue_label)
	add_child(_dialogue_bubble)

## Show a floating dialogue bubble above the animal with a random line.
func _show_dialogue() -> void:
	if not _has_dialogue() or not _dialogue_bubble or not _dialogue_label:
		return
	var now := Time.get_unix_time_from_system()
	if now - _last_dialogue_time < DIALOGUE_COOLDOWN:
		return
	_last_dialogue_time = now
	_dialogue_label.text = _get_dialogue_line()
	_dialogue_bubble.visible = true
	# Auto-hide after 3 seconds
	get_tree().create_timer(3.0).timeout.connect(func():
		if is_instance_valid(_dialogue_bubble):
			_dialogue_bubble.visible = false
	)

## Called when a body (e.g. the player) enters this animal's Area2D.
func _on_player_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_show_dialogue()

# ---------------------------------------------------------------------------
# Behaviour loop
# ---------------------------------------------------------------------------

func _ready() -> void:
	# If setup() already ran (e.g. barn animals), move_radius was set there
	# and must NOT be overwritten with a random value.
	if not _setup_done:
		_move_radius = randf_range(32.0, 80.0)
	# If setup() didn't run, the sprite @onready assignment just happened
	# so double-check the sprite reference for safety.
	if not sprite:
		sprite = $Sprite2D
	# If setup() ran before the node was in the scene tree, @onready vars
	# were null and label.text was never set. Fix it now.
	if label and label.text.is_empty() and animal_name != "Animal":
		label.text = animal_name
	# If setup() already generated the sprite texture, we're good.
	# If setup() never ran and thus no sprite was generated, generate one now.
	if sprite and not sprite.texture:
		_generate_procedural_sprite()
	# Start the wander timer if it hasn't been started yet (was null during
	# setup() for barn animals, or setup() was never called).
	if wander_timer and wander_timer.is_stopped():
		wander_timer.start()
	add_to_group("animals")
	# Detect arrows fired from the player's bow (Area2D detects RigidBody2D)
	body_entered.connect(_on_arrow_hit)
	# Show dialogue bubble when player walks near (only for creatures with dialogue)
	body_entered.connect(_on_player_entered)
	# Build dialogue bubble if this creature type has one
	_setup_dialogue()
	_update_contextual_prompt()
	_world_ref = get_tree().get_first_node_in_group("world")
	_player_ref = get_tree().get_first_node_in_group("player") as Node2D

## Returns the best interaction type based on current context (player's held item, drops available, love mode)
func get_contextual_interaction() -> int:
	var player := _get_nearest_player()
	if not player or not player.has_method("_get_hotbar_slot_data"):
		return InteractionType.PET
	
	# 1. Check if animal has daily drops ready
	var drops: Array[Dictionary] = _get_drops_for_type()
	var current_day := GameManager.current_day if GameManager else 0
	for drop in drops:
		var cooldown: int = drop.get("cooldown", 0)
		if cooldown > 0 and current_day - _last_interaction_day >= cooldown:
			return InteractionType.COLLECT
		if cooldown == 0 and drop.get("chance", 0) > 0 and not drop.get("one_time", false):
			if not (_has_dropped_rare and drop.get("one_time", false)):
				return InteractionType.COLLECT
	
	# 2. Check if holding love food → Feed
	var sd = player._get_hotbar_slot_data()
	if not sd.is_empty():
		var held_item_id: String = sd.get("item_id", "")
		if held_item_id in get_love_foods():
			if not is_love_mode and _breed_cooldown <= 0.0 and _feed_cooldown <= 0.0:
				return InteractionType.FEED
	
	# 3. Check if can breed (both animals in love mode nearby)
	if is_love_mode and _breed_cooldown <= 0.0:
		var all_animals := get_tree().get_nodes_in_group("animals")
		for other in all_animals:
			if other == self: continue
			var oa := other as Animal
			if oa and oa.animal_type == animal_type and oa.is_love_mode and oa._breed_cooldown <= 0.0:
				if not oa.is_baby and global_position.distance_to(oa.global_position) < 80.0:
					return InteractionType.BREED
	
	# 4. Default: Pet
	return InteractionType.PET

## Updates the interaction_prompt label based on the current context.
func _update_contextual_prompt() -> void:
	var ctx := get_contextual_interaction()
	match ctx:
		InteractionType.PET:
			interaction_prompt = "Pet " + animal_name
		InteractionType.FEED:
			var sd = _get_nearest_player()._get_hotbar_slot_data() if _get_nearest_player() else {}
			var item_name: String = "Food"
			if not sd.is_empty():
				var item: ItemData = DataManager.get_item(sd.get("item_id", ""))
				if item: item_name = item.display_name
			interaction_prompt = "Feed " + item_name
		InteractionType.COLLECT:
			interaction_prompt = "Collect from " + animal_name
		InteractionType.BREED:
			interaction_prompt = "Breed " + animal_name
		InteractionType.TALK:
			interaction_prompt = "Talk to " + animal_name

func _process(delta: float) -> void:
	if _is_remote:
		return
	
	_idle_phase += delta * 2.0
	var dist: float = global_position.distance_to(_target_pos)
	var is_moving: bool = false

	# Baby growth
	if is_baby:
		_grow_baby(delta)
	
	# Love mode timer
	if is_love_mode:
		_love_timer -= delta
		if _love_timer <= 0.0:
			is_love_mode = false
		# Spawn floating heart sprites occasionally
		if randf() < 0.05:
			EffectSpawner.spawn_hearts(global_position + Vector2(0, -14), 1, 4.0, -24.0)
	
	# Breed cooldown
	if _breed_cooldown > 0.0:
		_breed_cooldown -= delta
	
	# Feed cooldown
	if _feed_cooldown > 0.0:
		_feed_cooldown -= delta
	
	# Following behavior: check if player is holding a love food
	_following_player = false
	var player: Node2D = _get_nearest_player()
	if player and player.has_method("_get_hotbar_slot_data"):
		var slot_data = player._get_hotbar_slot_data()
		if not slot_data.is_empty():
			var item_id: String = slot_data.get("item_id", "")
			var love_foods: Array[String] = get_love_foods()
			if item_id in love_foods:
				var pdist := global_position.distance_to(player.global_position)
				if pdist < 100.0:
					_following_player = true
					# Walk toward a target position offset from the player,
					# so animals don't all clump on top of the player.
					# Each animal has its own follow_offset for natural spread.
					var target_pos := player.global_position + _follow_offset
					var dist_to_target := global_position.distance_to(target_pos)
					if dist_to_target > FOLLOW_STOP_DISTANCE:
						var dir := (target_pos - global_position).normalized()
						var new_pos := global_position + dir * move_speed * 3.0 * delta
						if _is_walkable_position(new_pos):
							global_position = new_pos
							sprite.flip_h = dir.x < 0
							if animated_sprite: animated_sprite.flip_h = dir.x < 0
							is_moving = true
						else:
							# Can't walk there — orbit slightly to find a clear path
							_follow_offset = _follow_offset.rotated(0.5)
					else:
						# Within stop distance — small gentle idle bob to show life
						sprite.position.y = sin(_idle_phase) * 1.5
						if animated_sprite:
							animated_sprite.position.y = sin(_idle_phase) * 1.5
							if animated_sprite.sprite_frames and animated_sprite.animation != "idle":
								animated_sprite.play("idle")
					# Sync animation for the moving-while-following case
					if is_moving and animated_sprite and animated_sprite.sprite_frames and animated_sprite.animation != "walk":
						animated_sprite.play("walk")
					# Don't wander while following
					return

	match behavior:
		Behavior.IDLE:
			is_moving = false

		Behavior.SKITTISH:
			if player and global_position.distance_to(player.global_position) < 56.0:
				var flee_dir: Vector2 = (global_position - player.global_position).normalized()
				var flee_pos: Vector2 = global_position + flee_dir * move_speed * delta
				if _is_walkable_position(flee_pos):
					global_position = flee_pos
					sprite.flip_h = flee_dir.x > 0
					if animated_sprite: animated_sprite.flip_h = flee_dir.x > 0
					is_moving = true
				else:
					# Hit water boundary — pick a new target away from the player
					_pick_new_target()
			elif dist > 3.0:
				_walk_toward(delta)
				is_moving = true

		Behavior.GRAZE:
			if _rest_time > 0.0:
				_rest_time -= delta
			elif dist > 3.0:
				_walk_toward(delta)
				is_moving = true
				if randf() < 0.005:
					_rest_time = randf_range(1.0, 3.0)

		_:  # WANDER
			if dist > 3.0:
				_walk_toward(delta)
				is_moving = true

	# Gentle idle bob when stationary
	if not is_moving:
		sprite.position.y = sin(_idle_phase) * 1.5
	
	# Animated sprite state for ice_cream_sandwich_man
	if animated_sprite and animated_sprite.visible and animated_sprite.sprite_frames:
		if is_moving:
			if animated_sprite.animation != "walk":
				animated_sprite.play("walk")
		else:
			if animated_sprite.animation != "idle":
				animated_sprite.play("idle")
	
	# Host: broadcast position to remote clients
	if NetworkManager.is_network_active() and multiplayer.is_server() and not _is_in_host_only_subtree():
		_last_pos_sync_time += delta
		if _last_pos_sync_time >= POS_SYNC_INTERVAL:
			_last_pos_sync_time = 0.0
			_broadcast_animal_rpc("_sync_animal_pos", [animal_id, global_position, scale.x], false)

func _walk_toward(delta: float) -> void:
	var dir: Vector2 = (_target_pos - global_position).normalized()
	var new_pos: Vector2 = global_position + dir * move_speed * delta
	# Don't walk into water - if the next position is non-walkable, stop and pick a new target
	if _is_walkable_position(new_pos):
		global_position = new_pos
		if abs(dir.x) > 0.2:
			sprite.flip_h = dir.x < 0
			if animated_sprite: animated_sprite.flip_h = dir.x < 0
	else:
		_pick_new_target()

func _pick_new_target() -> void:
	# If this animal has been fed/tamed and is inside a fenced area, anchor its
	# wander center to its current position. Since fence tiles are unwalkable,
	# all future wander targets will be inside the pen — the animal stays put.
	if _tamed and _world_ref and _world_ref.has_method("is_position_near_fence"):
		if _world_ref.is_position_near_fence(global_position, 3):
			_home_pos = global_position
	
	# Try up to 20 times to find a walkable target (not in water)
	for _attempt in 20:
		var candidate := _home_pos + Vector2(
			randf_range(-_move_radius, _move_radius),
			randf_range(-_move_radius, _move_radius)
		)
		if _is_walkable_position(candidate):
			_target_pos = candidate
			return
	# Fallback: go home (which should always be walkable)
	_target_pos = _home_pos

## Returns true if this animal is within 3 cells of a fence (wooden or stone).
## Used to limit animal wander range; fences act as pens.
func _is_near_any_fence() -> bool:
	if not _world_ref or not _world_ref.has_method("is_position_near_fence"):
		return true  # can't check, assume ok (avoids blocking breeding in worlds without fences)
	return _world_ref.is_position_near_fence(global_position, 3)


## Returns true if the given world position is on a walkable tile
## (not water, edge, out of bounds, occupied by a fence, or a building/shop
## blocker). Animals teleport-walk, so physics blockers must be checked by hand.
## On expedition islands, checks against the island's own tile grid instead
## of the main world's (which is offset to INTERIOR_VOID and would be out
## of bounds for every position on the island).
func _is_walkable_position(pos: Vector2) -> bool:
	if not is_inside_tree():
		return true  # not in scene tree yet (e.g. barn animals being set up), assume walkable

	# On expedition islands the main world's cell-walkability check is useless
	# because all island coordinates are way out of bounds on the world tilemap.
	var tree := get_tree()
	if tree:
		var island_node: Node = tree.get_first_node_in_group("expedition_island")
		if island_node and island_node.has_method("is_water_tile"):
			var island_pos: Vector2 = island_node.get("global_position")
			var local_x: float = pos.x - island_pos.x
			var local_y: float = pos.y - island_pos.y
			var cell_x: int = int(local_x / 16)
			var cell_y: int = int(local_y / 16)
			if island_node.call("is_water_tile", cell_x, cell_y):
				return false
			return not _is_blocked_by_building(pos)

	if not _world_ref:
		return true  # can't check, assume walkable
	if _world_ref.has_method("is_cell_walkable") and not _world_ref.is_cell_walkable(pos):
		return false
	# Also check if a fence occupies this position — animals can't walk through fences
	if _world_ref.has_method("is_fence_at_cell"):
		var cell: Vector2i
		if _world_ref.has_method("world_to_cell"):
			cell = _world_ref.world_to_cell(pos)
		else:
			cell = Vector2i(int(pos.x / 16), int(pos.y / 16))
		if _world_ref.is_fence_at_cell(cell):
			return false
	# Also avoid walking onto building/shop blockers (collision layer 8)
	if _is_blocked_by_building(pos):
		return false
	return true


## Returns true if a building/shop physics blocker (collision layer 8) covers
## the given world position, so animals don't walk on top of their sprites.
func _is_blocked_by_building(pos: Vector2) -> bool:
	var shape_node := get_node_or_null("CollisionShape2D")
	if shape_node == null or shape_node.shape == null:
		return false
	if get_world_2d() == null:
		return false
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape_node.shape
	query.transform = Transform2D(0.0, pos)
	query.collision_mask = 8  # building/shop/fence blocker layer
	return not get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


func _on_wander_timer_timeout() -> void:
	if behavior == Behavior.IDLE:
		return
	_pick_new_target()

func _get_nearest_player() -> Node2D:
	if not _player_ref:
		# Player may not have been ready when this animal's _ready() ran
		_player_ref = get_tree().get_first_node_in_group("player") as Node2D
	return _player_ref

# ---------------------------------------------------------------------------
# Interaction
# ---------------------------------------------------------------------------

func interact(interactor: Node) -> void:
	# Context-aware interaction dispatcher.
	# The action performed depends on context determined by get_contextual_interaction().
	var _interact_player: Player = interactor as Player if interactor is Player else null
	if not _interact_player:
		_interact_player = _resolve_player(interactor) as Player

	var ctx := get_contextual_interaction()
	match ctx:
		InteractionType.COLLECT:
			if _try_collect():
				return
		InteractionType.FEED:
			if _interact_player and _interact_player.has_method("_get_hotbar_slot_data"):
				var sd = _interact_player._get_hotbar_slot_data()
				if not sd.is_empty():
					var held_item_id: String = sd.get("item_id", "")
					if feed(held_item_id):
						_update_contextual_prompt()
						return
		InteractionType.BREED:
			_do_breed_action()
			return
		_:  # PET or anything else
			_do_pet()
			return
	
	# Fallback: nothing actionable — pet anyway
	_do_pet()

## Pet the animal — builds affection over time.
func _do_pet() -> void:
	var now := Time.get_unix_time_from_system()
	if now - _last_pet_time < PET_COOLDOWN:
		ToastNotification.show_toast(animal_name + " has been petted recently.", ToastNotification.ToastType.INFO, 1.5)
		return
	_affection = minf(100.0, _affection + 5.0)
	_last_pet_time = now
	
	# Show a heart for petting at high affection
	if _affection >= 50.0 and randi() % 3 == 0:
		EffectSpawner.spawn_particles(global_position, Color(1.0, 0.4, 0.7), 2, 6.0)
	
	# Happy sound
	AudioManager.play(AudioManager.Sound.GATHER)
	
	var pet_message: String
	if _affection < 20.0:
		pet_message = animal_name + " seems wary of you."
	elif _affection < 50.0:
		pet_message = animal_name + " enjoys the attention!"
	elif _affection < 80.0:
		pet_message = animal_name + " loves you! ♥"
	else:
		pet_message = animal_name + " is your best friend! ♥♥"
	ToastNotification.show_toast(pet_message, ToastNotification.ToastType.INFO, 2.0)

## Try to collect daily drops from this animal. Returns true if anything was collected.
func _try_collect() -> bool:
	var drops: Array[Dictionary] = _get_drops_for_type()
	var dropped_any := false
	var current_day := GameManager.current_day if GameManager else 0

	for drop in drops:
		var item_id: String = drop.get("item_id", "")
		if item_id.is_empty():
			continue
		var cooldown_days: int = drop.get("cooldown", 0)
		var is_one_time: bool = drop.get("one_time", false)
		var chance: float = drop.get("chance", 1.0)

		if is_one_time and _has_dropped_rare:
			continue
		if cooldown_days > 0 and current_day - _last_interaction_day < cooldown_days:
			continue
		if chance < 1.0 and randf() > chance:
			continue

		var drop_amount: int = drop.get("amount", 1)
		var leftover: int = InventoryManager.add_item(item_id, drop_amount)
		var gathered: int = drop_amount - leftover
		if gathered > 0:
			var item_data: ItemData = DataManager.get_item(item_id)
			var item_name: String = item_data.display_name if item_data else item_id
			EffectSpawner.spawn_floating_text("+%d %s" % [gathered, item_name], global_position, Color.WHITE)
			dropped_any = true
			if is_one_time:
				_has_dropped_rare = true

	if dropped_any:
		_last_interaction_day = current_day
		AudioManager.play(AudioManager.Sound.GATHER)
		EffectSpawner.spawn_particles(global_position, body_color, 4, 8.0)
		ToastNotification.show_toast("Collected from " + animal_name + "!", ToastNotification.ToastType.SUCCESS, 2.0)
		_update_contextual_prompt()
		return true
	return false

## Trigger the breed action between two nearby love-mode animals.
func _do_breed_action() -> void:
	if is_baby or _breed_cooldown > 0.0:
		ToastNotification.show_toast(animal_name + " isn't ready to breed yet.", ToastNotification.ToastType.INFO, 2.0)
		return
	var all_animals := get_tree().get_nodes_in_group("animals")
	for other in all_animals:
		if other == self: continue
		var oa := other as Animal
		if not oa: continue
		if oa.animal_type != animal_type: continue
		if oa.is_baby: continue
		if oa.is_love_mode and oa._breed_cooldown <= 0.0:
			# Both in love mode — spawn a baby!
			_spawn_baby(oa)
			_breed_cooldown = 60.0
			oa._breed_cooldown = 60.0
			is_love_mode = false
			oa.is_love_mode = false
			_update_contextual_prompt()
			return
	ToastNotification.show_toast("No compatible mate nearby for " + animal_name, ToastNotification.ToastType.INFO, 2.0)

## Returns a list of drops for this animal type.
## Each drop has: item_id, amount, cooldown (days), chance (0-1), one_time (bool)
func _get_drops_for_type() -> Array[Dictionary]:
	## Interaction drops: non-lethal items like milk, eggs, wool, feathers.
	## Fur, leather, and venison are ONLY obtained when killing the animal.
	match animal_type:
		"chicken", "bird":
			return [
				{"item_id": "feather", "amount": 1, "cooldown": 0, "chance": 0.8},
				{"item_id": "egg", "amount": 1, "cooldown": 1, "chance": 1.0},
			]
		"cow":
			return [
				{"item_id": "milk", "amount": 1, "cooldown": 1, "chance": 1.0},
			]
		"rabbit":
			return [
				# Rabbits are shy — no interaction drops
			]
		"deer":
			return [
				{"item_id": "antlers", "amount": 1, "cooldown": 0, "chance": 0.05, "one_time": true},
			]
		"goat":
			return [
				{"item_id": "milk", "amount": 1, "cooldown": 1, "chance": 1.0},
			]
		"pig":
			return [
				{"item_id": "truffle", "amount": 1, "cooldown": 2, "chance": 0.7},
			]
		"sheep":
			return [
				{"item_id": "wool", "amount": 1, "cooldown": 1, "chance": 1.0},
			]
		"squirrel":
			return [
				{"item_id": "nut", "amount": 1, "cooldown": 0, "chance": 0.8},
			]
		"frog":
			# Frogs are just curious — no drops
			return []
		"turtle":
			return [
				{"item_id": "shell", "amount": 1, "cooldown": 0, "chance": 0.15, "one_time": true},
			]
		"snow_fox":
			return [
				{"item_id": "fur", "amount": 1, "cooldown": 1, "chance": 0.7},
			]
		"polar_bear":
			return [
				{"item_id": "polar_bear_hide", "amount": 1, "cooldown": 1, "chance": 0.5},
			]
		"snow_owl":
			return [
				{"item_id": "feather", "amount": 1, "cooldown": 0, "chance": 0.8},
			]
		"gummy_bear":
			return [
				{"item_id": "gumdrop", "amount": 1, "cooldown": 1, "chance": 0.9},
			]
		"marshmallow_puff":
			return [
				{"item_id": "sugar_crystal", "amount": 1, "cooldown": 0, "chance": 0.6},
			]
		"licorice_worm":
			return []
		"gingerbread_man":
			return [
				{"item_id": "sugar_crystal", "amount": 1, "cooldown": 1, "chance": 0.8},
			]
		"sand_lizard":
			return []
		"desert_scorpion":
			return []
		"meerkat":
			return [
				{"item_id": "golden_scarab", "amount": 1, "cooldown": 3, "chance": 0.3},
			]
		"ember_crawler":
			return [
				{"item_id": "ember_dust", "amount": 1, "cooldown": 1, "chance": 0.8},
			]
		"ash_moth":
			return [
				{"item_id": "ember_dust", "amount": 1, "cooldown": 0, "chance": 0.5},
			]
		"magma_slug":
			return [
				{"item_id": "sulfur_crystal", "amount": 1, "cooldown": 1, "chance": 0.6},
			]
		"spirit_fox":
			return [
				{"item_id": "moon_shard", "amount": 1, "cooldown": 1, "chance": 0.5},
			]
		"glow_jelly":
			return [
				{"item_id": "starlight_dust", "amount": 1, "cooldown": 0, "chance": 0.7},
			]
		"lunar_moth":
			return [
				{"item_id": "starlight_dust", "amount": 1, "cooldown": 1, "chance": 0.6},
			]
		_:
			return []
