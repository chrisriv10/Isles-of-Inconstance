extends Node

## Validates the quest definition table: quests exist and every entry
## carries the fields the UI / progression expects.

func _eq(actual: Variant, expected: Variant, what: String) -> bool:
	if actual != expected:
		printerr("  FAIL %s: expected=%s actual=%s" % [what, expected, actual])
	return actual == expected

func test_quests_load() -> void:
	var defs := QuestManager.get_quest_defs()
	assert(defs.size() > 20, "expected >20 quests, got %d" % defs.size())
	# Matches the count logged at startup ("32 quest definitions loaded").
	assert(_eq(defs.size(), 32, "quest count"))

func test_each_quest_has_valid_fields() -> void:
	var defs := QuestManager.get_quest_defs()
	for key: String in defs:
		var q: Dictionary = defs[key]
		assert(q.has("id"), "quest %s missing id" % key)
		assert(_eq(String(q["id"]), key, "quest id for " + key))
		assert(not String(q.get("title", "")).is_empty(), "Quest '%s' missing title" % key)
		assert(not String(q.get("description", "")).is_empty(), "Quest '%s' missing description" % key)
		assert(q.has("req_type"), "Quest '%s' missing req_type" % key)
		assert(q.has("requirements"), "Quest '%s' missing requirements" % key)
		assert(q.has("reward_items"), "Quest '%s' missing reward_items" % key)
		assert(q.has("reward_gold"), "Quest '%s' missing reward_gold" % key)

func test_each_quest_rewards_positive_gold_or_items() -> void:
	var defs := QuestManager.get_quest_defs()
	for key: String in defs:
		var q: Dictionary = defs[key]
		var gold: int = int(q.get("reward_gold", 0))
		var items: Array = q.get("reward_items", [])
		assert(gold > 0 or items.size() > 0, "Quest '%s' has no reward" % key)