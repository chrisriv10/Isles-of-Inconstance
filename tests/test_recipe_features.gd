extends Node

## Guards the wiring for three recent fixes:
##   1. GameManager must call building_peer_disconnected on peer drop.
##   2. HUD must tick _periodic_buff_refresh from a _process loop.
##   3. Gates must carry a layer-16 blocker that animals query but players don't.
##   4. Restaurant must expose a "share ingredient" path wired to try_unlock_recipe.

func _file_contains(path: String, needle: String) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		printerr("  FAIL: cannot open " + path)
		return false
	var t := f.get_as_text()
	f.close()
	return t.contains(needle)

func test_building_peer_disconnected_is_called() -> void:
	assert(_file_contains(
		"res://scripts/autoload/GameManager.gd",
		'world.building_peer_disconnected(peer_id)'
	), "GameManager must call building_peer_disconnected on peer drop")

func test_hud_process_ticks_buff_refresh() -> void:
	assert(_file_contains(
		"res://scripts/ui/HUD.gd",
		"_periodic_buff_refresh(_delta)"
	), "HUD _process must call _periodic_buff_refresh")
	assert(_file_contains(
		"res://scripts/ui/HUD.gd",
		"func _process(_delta: float) -> void:"
	), "HUD must define a _process")

func test_gate_uses_layer16_blocker() -> void:
	assert(_file_contains(
		"res://scripts/world/building/BuildingSystem.gd",
		"blocker.collision_layer = 16 if is_gate else 8"
	), "Gate blocker must be on layer 16 so players (mask 8) pass")
	assert(_file_contains(
		"res://scripts/world/building/BuildingSystem.gd",
		"BuildingType.STONE_FENCE or is_gate"
	), "Gate must be included in should_add_blocker")

func test_animal_queries_gate_layer() -> void:
	assert(_file_contains(
		"res://scripts/world/Animal.gd",
		"query.collision_mask = 8 | 16"
	), "Animal building query must check gate layer 16")

func test_restaurant_share_ingredient_wired() -> void:
	assert(_file_contains(
		"res://scripts/world/building/BuildingInterior.gd",
		"restaurant.try_unlock_recipe(ingredient_id)"
	), "Share-ingredient popup must call restaurant.try_unlock_recipe")
	assert(_file_contains(
		"res://scripts/world/building/BuildingInterior.gd",
		"_add_ingredient_board"
	), "Restaurant must spawn an ingredient board interactable")

func test_rare_crops_registered() -> void:
	assert(_file_contains(
		"res://scripts/autoload/DataManager.gd",
		"func _register_rare_crops()"
	), "DataManager must define _register_rare_crops")
	assert(_file_contains(
		"res://scripts/autoload/DataManager.gd",
		"_register_rare_crops()"
	), "DataManager must call _register_rare_crops from crop generation")
	for id in ["giant_mushroom", "golden_pumpkin", "ancient_fruit", "fairy_rose", "void_berry"]:
		assert(_file_contains("res://scripts/autoload/DataManager.gd", "\"%s\"" % id),
			"DataManager must register %s" % id)

func test_cooking_unlock_recipe_exists() -> void:
	assert(_file_contains(
		"res://scripts/world/cooking/CookingSystem.gd",
		"func unlock_recipe(recipe_id: String)"
	), "CookingSystem must define unlock_recipe")
	for rid in ["mushroom_risotto", "ancient_wine", "fairy_tea", "void_cordial"]:
		assert(_file_contains("res://scripts/world/cooking/CookingSystem.gd", "\"%s\"" % rid),
			"CookingSystem must register recipe %s" % rid)

func test_client_summon_updates_objective() -> void:
	assert(_file_contains(
		"res://scripts/world/enemies/EnemySpawner.gd",
		"om.on_boss_summoned()"
	), "Client-initiated boss summon must progress the objective")

func test_chef_quests_reward_rare_seeds() -> void:
	assert(_file_contains(
		"res://scripts/autoload/QuestManager.gd",
		'"chef_gourmet_harvest"'
	), "Chef gourmet harvest quest must exist")
	assert(_file_contains(
		"res://scripts/autoload/QuestManager.gd",
		'"chef_secret_spice"'
	), "Chef secret spice quest must exist")
	assert(_file_contains(
		"res://scripts/autoload/QuestManager.gd",
		'"id": "giant_mushroom_seed"'
	), "Quest must reward a rare seed")

func test_bespoke_meal_icons_resolve() -> void:
	# Regenerated icon PNGs can sit in res://assets/generated/ before the editor's
	# import pass picks them up. make_item_icon must decode them from disk so the
	# hand-authored icons always show (this guards the chocolate_fondue and
	# fairy_tea icons specifically, and any future regenerated icon).
	assert(_file_contains(
		"res://scripts/autoload/DataManager.gd",
		"func _load_unimported_png"
	), "DataManager must define the un-imported PNG fallback decoder")
	for id in ["chocolate_fondue", "fairy_tea"]:
		var icon: Texture2D = DataManager.make_item_icon("meal", id, "")
		assert(icon != null, "Bespoke meal icon must resolve for %s" % id)
		assert(icon.get_size() == Vector2(16, 16) or icon.get_size() == Vector2(32, 32),
			"%s icon must be a normalized small size" % id)
