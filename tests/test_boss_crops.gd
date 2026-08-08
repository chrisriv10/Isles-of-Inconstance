extends Node

## Guards the boss-bait crop wiring so the materials for summoning the 3 base
## bosses are actually obtainable in legitimate play:
##   - DataManager defines _register_boss_crops() that sets seed_item_id/yield
##     (so seeds can be planted and return seeds on harvest) and unlocks seeds
##     in the shop with buy_price > 0.
##   - No genetics is set, so shop rarity_tier stays 0 (never hidden behind the
##     Seed Vault upgrade).
##   - Bootstrap grants a Soulberry seed at game start (Root Warden path).
##   - The boss crops join the generic rare-harvest seed-drop pool in World.gd.

func _file_contains(path: String, needle: String) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		printerr("  FAIL: cannot open " + path)
		return false
	var t := f.get_as_text()
	f.close()
	return t.contains(needle)

func test_boss_crop_registration_defined() -> void:
	assert(_file_contains("res://scripts/autoload/DataManager.gd", "func _register_boss_crops"), \
		"DataManager must define _register_boss_crops")
	# Seeds/growth wiring: each boss crop must return its seed and have stages.
	assert(_file_contains("res://scripts/autoload/DataManager.gd", 'crop.seed_item_id = crop_id + "_seed"'), \
		"boss crops must set seed_item_id (harvest returns seeds)")
	assert(_file_contains("res://scripts/autoload/DataManager.gd", "crop.growth_stage_textures"), \
		"boss crops must have growth-stage textures (visible when planted)")
	assert(_file_contains("res://scripts/autoload/DataManager.gd", "seed_item.buy_price <= 0"), \
		"_register_boss_crops must set seed buy_price so it is shop-listed")
	# Boss-bait crops MUST NOT mutate, or harvest yields a mutated crop the
	# summon altar won't accept (matches the reported Crystal-Soulberry bug).
	assert(_file_contains("res://scripts/autoload/DataManager.gd", "locked.mutation_chance = 0.0"), \
		"boss crops must carry a locked zero-mutation genetics")
	# Each boss species is wired in.
	for cid in ["soulberry", "golden_wheat", "nectar_bloom"]:
		assert(_file_contains("res://scripts/autoload/DataManager.gd", '"' + cid + '"'), \
			"boss crop %s must be wired in DataManager" % cid)

func test_boss_seed_prices_specified() -> void:
	assert(_file_contains("res://scripts/autoload/DataManager.gd", '"soulberry", "Soulberry"'), "soulberry def")
	assert(_file_contains("res://scripts/autoload/DataManager.gd", '"golden_wheat", "Golden Wheat"'), "golden_wheat def")
	assert(_file_contains("res://scripts/autoload/DataManager.gd", '"nectar_bloom", "Nectar Bloom"'), "nectar_bloom def")
	# Expensive-gate: golden wheat + nectar bloom priced above our "cheap" bar.
	assert(_file_contains("res://scripts/autoload/DataManager.gd", "250"), "expensive seeds set to 250")

func test_starter_grants_soulberry_seed() -> void:
	assert(_file_contains("res://scripts/Bootstrap.gd", '"soulberry_seed", 3'), \
		"Bootstrap must grant 3 Soulberry seeds at game start")
	# The grant sits BEFORE the procedural-crop early-return so it can never be
	# skipped, keeping host and joining clients in sync.
	assert(_file_contains("res://scripts/Bootstrap.gd", "soulberry_seed\", 3)\n\n\tvar starter_crops"), \
		"Soulberry grant must precede the procedural-crop check (sync safety)")
	# Clients are routed through the same grant function on join.
	assert(_file_contains("res://scripts/Main.gd", "bootstrap.grant_starter_inventory()"), \
		"Clients must receive the same starter grant during world sync")
