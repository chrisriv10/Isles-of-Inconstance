## QuestManager — Central quest registry and state tracker.
## Defines all NPC quests with their requirements and rewards.
## Other systems query this for available/active/completed quests.
## Save/load is handled via serialize/deserialize (called by SaveManager).

extends Node
## QuestManager is registered as an autoload in project.godot.
## Accessible globally as QuestManager (singleton).

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------
signal quest_accepted(quest_id: String, quest_title: String)
signal quest_progressed(quest_id: String, progress_value: int, target_value: int)
signal quest_completed(quest_id: String, quest_title: String)
signal quests_updated()

# ---------------------------------------------------------------------------
# Requirement types
# ---------------------------------------------------------------------------
enum RequirementType {
	DELIVER_ITEMS,    # Bring specific items to the NPC
	KILL_ENEMIES,     # Defeat a number of enemies
	COLLECT_ITEMS,    # Gather items in inventory
	VISIT_LOCATION,   # Visit a named location
	BUILD_STRUCTURE,  # Build or place something
	REACH_LEVEL,      # Reach a player level
}

# ===========================================================================
# Quest Template — each entry defines one quest that NPCs can offer.
# ===========================================================================
#
# Fields:
#   id                    Unique string identifier
#   giver_role            TownResidentNPC.Role value (who offers this)
#   giver_source          String — "resident" (default), "visitor", or "any"
#                         "resident" = only town residents offer this
#                         "visitor"  = only visitor NPCs offer this
#                         "any"      = either can offer it
#   title                 Short quest name
#   description           Full description shown to player
#   req_type              RequirementType enum
#   requirements          Array of {"id", "count"} dicts — e.g. [{"id":"wood", "count":20}]
#   reward_items          Array of {"id", "count"} — items given on completion
#   reward_gold           Gold awarded on completion
#   reward_reputation     Town reputation awarded
#   reward_xp             XP awarded (boosts farmer level)
#   tags                  Array[String] — optional categorization tags
#   prerequisite_ids      Array[String] — quest IDs the player must have already completed
#   repeatable            bool — can be done more than once (default false)
#   min_town_level        int — minimum town level required to unlock this quest
#
# ===========================================================================

static func get_quest_defs() -> Dictionary:
	return {
	# ── VILLAGER quests ────────────────────────────────────────────────────
	"wood_gathering": {
		"id": "wood_gathering",
		"giver_role": TownResidentNPC.Role.VILLAGER,
		"title": "Help with Repairs",
		"description": "The village needs timber for patching roofs. Bring 30 wood to any villager.",
		"req_type": RequirementType.DELIVER_ITEMS,
		"requirements": [{"id": "wood", "count": 30}],
		"reward_items": [{"id": "wooden_planks", "count": 8}],
		"reward_gold": 80,
		"reward_reputation": 6,
		"reward_xp": 40,
		"prerequisite_ids": [],
		"min_town_level": 0,
	},
	"stone_path": {
		"id": "stone_path",
		"giver_role": TownResidentNPC.Role.VILLAGER,
		"title": "Paving the Way",
		"description": "The paths through town are a muddy mess. Bring 25 stone for paving.",
		"req_type": RequirementType.DELIVER_ITEMS,
		"requirements": [{"id": "stone", "count": 25}],
		"reward_items": [{"id": "stone", "count": 12}],
		"reward_gold": 60,
		"reward_reputation": 6,
		"reward_xp": 30,
		"prerequisite_ids": [],
		"min_town_level": 0,
	},
	"flower_pots": {
		"id": "flower_pots",
		"giver_role": TownResidentNPC.Role.VILLAGER,
		"title": "Town Beautification",
		"description": "Let's brighten the streets! Bring 10 flowers to decorate the town.",
		"req_type": RequirementType.DELIVER_ITEMS,
		"requirements": [{"id": "flower", "count": 10}],
		"reward_items": [{"id": "flower", "count": 6}],
		"reward_gold": 50,
		"reward_reputation": 10,
		"reward_xp": 25,
		"prerequisite_ids": [],
		"min_town_level": 0,
	},

	# ── BAKER quests ───────────────────────────────────────────────────────
	"baker_fruit": {
		"id": "baker_fruit",
		"giver_role": TownResidentNPC.Role.BAKER,
		"title": "Fruit for Pies",
		"description": "I'm baking pies but I'm low on fruit. Bring me 20 berries!",
		"req_type": RequirementType.DELIVER_ITEMS,
		"requirements": [{"id": "berry", "count": 20}],
		"reward_items": [{"id": "bread", "count": 4}],
		"reward_gold": 90,
		"reward_reputation": 12,
		"reward_xp": 45,
		"prerequisite_ids": [],
		"min_town_level": 1,
	},
	"baker_wheat": {
		"id": "baker_wheat",
		"giver_role": TownResidentNPC.Role.BAKER,
		"title": "Eggs for Baking",
		"description": "I'm baking sponge cakes for the town, but I'm out of eggs! Bring me 8 eggs.",
		"req_type": RequirementType.DELIVER_ITEMS,
		"requirements": [{"id": "egg", "count": 8}],
		"reward_items": [{"id": "croissant", "count": 2}],
		"reward_gold": 100,
		"reward_reputation": 14,
		"reward_xp": 50,
		"prerequisite_ids": [],
		"min_town_level": 1,
	},

	# ── CHEF quests ────────────────────────────────────────────────────────
	"chef_mushroom_soup": {
		"id": "chef_mushroom_soup",
		"giver_role": TownResidentNPC.Role.CHEF,
		"title": "Wild Mushroom Soup",
		"description": "The daily special needs wild mushrooms! Collect 15 mushrooms for the kitchen.",
		"req_type": RequirementType.COLLECT_ITEMS,
		"requirements": [{"id": "mushroom", "count": 15}],
		"reward_items": [{"id": "mushroom_stew", "count": 3}],
		"reward_gold": 120,
		"reward_reputation": 12,
		"reward_xp": 50,
		"prerequisite_ids": [],
		"min_town_level": 1,
	},
	"chef_feast": {
		"id": "chef_feast",
		"giver_role": TownResidentNPC.Role.CHEF,
		"title": "Town Feast",
		"description": "We're preparing a grand feast! Bring 5 Hearty Stew dishes to serve everyone.",
		"req_type": RequirementType.DELIVER_ITEMS,
		"requirements": [{"id": "hearty_stew", "count": 5}],
		"reward_items": [{"id": "golden_soup", "count": 3}],
		"reward_gold": 250,
		"reward_reputation": 25,
		"reward_xp": 90,
		"prerequisite_ids": [],
		"min_town_level": 2,
	},

	# ── INNKEEPER quests ───────────────────────────────────────────────────
	"innkeeper_wood": {
		"id": "innkeeper_wood",
		"giver_role": TownResidentNPC.Role.INNKEEPER,
		"title": "Tavern Expansion",
		"description": "I'm building new tables for the tavern. Bring me 40 wood!",
		"req_type": RequirementType.DELIVER_ITEMS,
		"requirements": [{"id": "wood", "count": 40}],
		"reward_items": [{"id": "bread", "count": 8}],
		"reward_gold": 150,
		"reward_reputation": 15,
		"reward_xp": 60,
		"prerequisite_ids": [],
		"min_town_level": 1,
	},
	"innkeeper_ale": {
		"id": "innkeeper_ale",
		"giver_role": TownResidentNPC.Role.INNKEEPER,
		"title": "Berry Brew",
		"description": "I'm experimenting with a new berry brew recipe. Bring me 25 berries for the brew!",
		"req_type": RequirementType.DELIVER_ITEMS,
		"requirements": [{"id": "berry", "count": 25}],
		"reward_items": [{"id": "berry_juice", "count": 8}],
		"reward_gold": 180,
		"reward_reputation": 18,
		"reward_xp": 70,
		"prerequisite_ids": [],
		"min_town_level": 2,
	},

	# ── BLACKSMITH quests ──────────────────────────────────────────────────
	"blacksmith_copper": {
		"id": "blacksmith_copper",
		"giver_role": TownResidentNPC.Role.BLACKSMITH,
		"title": "Copper Rush",
		"description": "The forge needs copper for new tools. Mine 15 Copper Ore and bring it here.",
		"req_type": RequirementType.DELIVER_ITEMS,
		"requirements": [{"id": "copper_ore", "count": 15}],
		"reward_items": [{"id": "copper_ingot", "count": 5}],
		"reward_gold": 150,
		"reward_reputation": 12,
		"reward_xp": 60,
		"prerequisite_ids": [],
		"min_town_level": 1,
	},
	"blacksmith_iron": {
		"id": "blacksmith_iron",
		"giver_role": TownResidentNPC.Role.BLACKSMITH,
		"title": "Iron Tools",
		"description": "I need iron to forge stronger tools. Bring 12 Iron Ore and 8 Coal.",
		"req_type": RequirementType.DELIVER_ITEMS,
		"requirements": [{"id": "iron_ore", "count": 12}, {"id": "coal", "count": 8}],
		"reward_items": [{"id": "iron_ingot", "count": 5}],
		"reward_gold": 220,
		"reward_reputation": 18,
		"reward_xp": 90,
		"prerequisite_ids": ["blacksmith_copper"],
		"min_town_level": 2,
	},
	"blacksmith_arms": {
		"id": "blacksmith_arms",
		"giver_role": TownResidentNPC.Role.BLACKSMITH,
		"title": "For the Guard",
		"description": "The town needs arms! Deliver 5 Steel Ingots for crafting weapons.",
		"req_type": RequirementType.DELIVER_ITEMS,
		"requirements": [{"id": "steel_ingot", "count": 5}],
		"reward_items": [{"id": "tool_upgrade_kit", "count": 1}, {"id": "gold_ingot", "count": 2}],
		"reward_gold": 400,
		"reward_reputation": 30,
		"reward_xp": 150,
		"prerequisite_ids": ["blacksmith_iron"],
		"min_town_level": 3,
	},

	# ── SHOPKEEP quests ────────────────────────────────────────────────────
	"shopkeep_rare_goods": {
		"id": "shopkeep_rare_goods",
		"giver_role": TownResidentNPC.Role.SHOPKEEP,
		"title": "Rare Finds",
		"description": "Customers want exotic goods! Bring me 4 Diamonds from the deep mines.",
		"req_type": RequirementType.DELIVER_ITEMS,
		"requirements": [{"id": "diamond_gem", "count": 4}],
		"reward_items": [{"id": "gold_ingot", "count": 3}],
		"reward_gold": 450,
		"reward_reputation": 25,
		"reward_xp": 120,
		"prerequisite_ids": [],
		"min_town_level": 2,
	},
	"shopkeep_stock_up": {
		"id": "shopkeep_stock_up",
		"giver_role": TownResidentNPC.Role.SHOPKEEP,
		"title": "Restock the Shelves",
		"description": "I'm running low on basic supplies. Bring 15 Wooden Planks and 15 Stone.",
		"req_type": RequirementType.DELIVER_ITEMS,
		"requirements": [{"id": "wooden_planks", "count": 15}, {"id": "stone", "count": 15}],
		"reward_items": [{"id": "compost", "count": 8}],
		"reward_gold": 120,
		"reward_reputation": 10,
		"reward_xp": 50,
		"prerequisite_ids": [],
		"min_town_level": 1,
	},

	# ── SCHOLAR quests ─────────────────────────────────────────────────────
	"scholar_crops": {
		"id": "scholar_crops",
		"giver_role": TownResidentNPC.Role.SCHOLAR,
		"title": "Botanical Study",
		"description": "I'm documenting the island's flora. Discover 3 new crop types for my research.",
		"req_type": RequirementType.COLLECT_ITEMS,
		"requirements": [{"id": "crop_discovery", "count": 3}],
		"reward_items": [{"id": "growth_booster", "count": 4}],
		"reward_gold": 200,
		"reward_reputation": 25,
		"reward_xp": 120,
		"prerequisite_ids": [],
		"min_town_level": 2,
	},
	"scholar_rare_flower": {
		"id": "scholar_rare_flower",
		"giver_role": TownResidentNPC.Role.SCHOLAR,
		"title": "Exotic Flora",
		"description": "I've heard tales of rare flowers. Bring me 15 flowers of any variety!",
		"req_type": RequirementType.DELIVER_ITEMS,
		"requirements": [{"id": "flower", "count": 15}],
		"reward_items": [{"id": "quality_compost", "count": 5}],
		"reward_gold": 150,
		"reward_reputation": 18,
		"reward_xp": 80,
		"prerequisite_ids": [],
		"min_town_level": 1,
	},

	# ── STABLEHAND quests ──────────────────────────────────────────────────
	"stablehand_fiber": {
		"id": "stablehand_fiber",
		"giver_role": TownResidentNPC.Role.STABLEHAND,
		"title": "Bedding for the Animals",
		"description": "The stables need fresh bedding. Bring 30 wood — I'll use it as animal bedding.",
		"req_type": RequirementType.DELIVER_ITEMS,
		"requirements": [{"id": "wood", "count": 30}],
		"reward_items": [{"id": "feather", "count": 8}, {"id": "egg", "count": 2}],
		"reward_gold": 90,
		"reward_reputation": 12,
		"reward_xp": 40,
		"prerequisite_ids": [],
		"min_town_level": 0,
	},
	"stablehand_feed": {
		"id": "stablehand_feed",
		"giver_role": TownResidentNPC.Role.STABLEHAND,
		"title": "Animal Feed",
		"description": "The animals are hungry! Bring 25 berries to feed them.",
		"req_type": RequirementType.DELIVER_ITEMS,
		"requirements": [{"id": "berry", "count": 25}],
		"reward_items": [{"id": "egg", "count": 8}],
		"reward_gold": 140,
		"reward_reputation": 15,
		"reward_xp": 55,
		"prerequisite_ids": [],
		"min_town_level": 1,
	},

	# ── VISITOR quests (only visitor NPCs offer these) ──────────────────────
	"visitor_explore_cove": {
		"id": "visitor_explore_cove",
		"giver_role": -1,
		"giver_source": "visitor",
		"title": "Pirate Raider Hunt",
		"description": "Pirates keep raiding the island! Defeat 10 pirate raiders and send them back to the deep.",
		"req_type": RequirementType.KILL_ENEMIES,
		"requirements": [{"id": "PirateRaider", "count": 10}],
		"reward_items": [{"id": "gold_nugget", "count": 5}, {"id": "ancient_coin", "count": 2}],
		"reward_gold": 300,
		"reward_reputation": 15,
		"reward_xp": 120,
		"prerequisite_ids": [],
		"min_town_level": 1,
	},
	"visitor_fish_catch": {
		"id": "visitor_fish_catch",
		"giver_role": -1,
		"giver_source": "visitor",
		"title": "Fresh Catch",
		"description": "I'm a traveling angler and I'd love to try the local catch! Bring me 5 Raw Fish from the waters here.",
		"req_type": RequirementType.DELIVER_ITEMS,
		"requirements": [{"id": "raw_fish", "count": 5}],
		"reward_items": [{"id": "gold_nugget", "count": 5}],
		"reward_gold": 120,
		"reward_reputation": 8,
		"reward_xp": 50,
		"prerequisite_ids": [],
		"min_town_level": 0,
	},
	"visitor_tour_guide": {
		"id": "visitor_tour_guide",
		"giver_role": -1,
		"giver_source": "visitor",
		"title": "Show Me Around",
		"description": "I'm new to this island! Pick 8 flowers and show me the best spots.",
		"req_type": RequirementType.DELIVER_ITEMS,
		"requirements": [{"id": "flower", "count": 8}],
		"reward_items": [{"id": "berry", "count": 12}],
		"reward_gold": 60,
		"reward_reputation": 6,
		"reward_xp": 30,
		"prerequisite_ids": [],
		"min_town_level": 0,
	},
	"visitor_trade_goods": {
		"id": "visitor_trade_goods",
		"giver_role": -1,
		"giver_source": "visitor",
		"title": "Rare Trade Goods",
		"description": "I'm a merchant looking for exotic items. Bring me 2 obsidian shards from the deep mines and I'll make it worth your while!",
		"req_type": RequirementType.DELIVER_ITEMS,
		"requirements": [{"id": "obsidian_shard", "count": 2}],
		"reward_items": [{"id": "gold_ingot", "count": 2}],
		"reward_gold": 300,
		"reward_reputation": 12,
		"reward_xp": 100,
		"prerequisite_ids": [],
		"min_town_level": 2,
	},
	"visitor_scenic_spot": {
		"id": "visitor_scenic_spot",
		"giver_role": -1,
		"giver_source": "visitor",
		"title": "Forager's Collection",
		"description": "I'm documenting every wild food this island has to offer! Bring me 10 mushrooms and 10 flowers from your travels.",
		"req_type": RequirementType.DELIVER_ITEMS,
		"requirements": [{"id": "mushroom", "count": 10}, {"id": "flower", "count": 10}],
		"reward_items": [{"id": "feather", "count": 8}],
		"reward_gold": 80,
		"reward_reputation": 8,
		"reward_xp": 40,
		"prerequisite_ids": [],
		"min_town_level": 0,
	},
	"visitor_help_vendor": {
		"id": "visitor_help_vendor",
		"giver_role": -1,
		"giver_source": "visitor",
		"title": "Vendor's Errand",
		"description": "My cart took a beating on the road! I need 15 wood and 10 stone for repairs. Help me out?",
		"req_type": RequirementType.DELIVER_ITEMS,
		"requirements": [{"id": "wood", "count": 15}, {"id": "stone", "count": 10}],
		"reward_items": [{"id": "gold_nugget", "count": 8}],
		"reward_gold": 150,
		"reward_reputation": 10,
		"reward_xp": 60,
		"prerequisite_ids": [],
		"min_town_level": 0,
	},

	# ── Combat quests (any NPC can give these at higher town levels) ───────
	"slay_sporelings": {
		"id": "slay_sporelings",
		"giver_role": -1,
		"giver_source": "any",
		"title": "Pest Control",
		"description": "Sporelings have been spotted near the farms! Defeat 8 of them to protect the crops.",
		"req_type": RequirementType.KILL_ENEMIES,
		"requirements": [{"id": "SporelingEnemy", "count": 8}],
		"reward_items": [{"id": "mushroom", "count": 15}, {"id": "health_potion", "count": 2}],
		"reward_gold": 180,
		"reward_reputation": 18,
		"reward_xp": 110,
		"prerequisite_ids": [],
		"min_town_level": 2,
	},
	"shadow_hound_hunt": {
		"id": "shadow_hound_hunt",
		"giver_role": -1,
		"giver_source": "any",
		"title": "Shadow Hound Menace",
		"description": "Shadow Hounds are prowling at night. Defeat 5 of them to keep the town safe.",
		"req_type": RequirementType.KILL_ENEMIES,
		"requirements": [{"id": "ShadowHound", "count": 5}],
		"reward_items": [{"id": "health_potion", "count": 3}, {"id": "shadow_hide", "count": 5}],
		"reward_gold": 300,
		"reward_reputation": 25,
		"reward_xp": 150,
		"prerequisite_ids": [],
		"min_town_level": 3,
	},
}


# ===========================================================================
# Quest dialogue templates
# ===========================================================================
static func get_quest_dialogue(quest_id: String) -> Dictionary:
	var dialogues := {
		"wood_gathering": {
			"intro": "Ah, a strong pair of hands! The roofs are leaking again. Could you gather 30 wood for repairs?",
			"accept": "Splendid! I'll be right here when you return with the timber.",
			"decline": "No worries. Perhaps another time.",
			"progress": "The roofs are still leaking... Have you gathered that wood yet?",
			"complete": "Perfect! This will patch up the roofs nicely. Here's your reward!",
		},
		"stone_path": {
			"intro": "The paths are a muddy mess when it rains. Could you haul 25 stone for paving?",
			"accept": "Excellent! The town will thank you.",
			"decline": "I understand, it's heavy work.",
			"progress": "Still waiting on that stone delivery...",
			"complete": "Marvelous! The paths will be dry and clean now!",
		},
		"flower_pots": {
			"intro": "The town could use some color! Would you pick 10 flowers to brighten the streets?",
			"accept": "Wonderful! The flower pots will look gorgeous.",
			"decline": "Maybe another time then.",
			"progress": "The streets are still so plain... Any flowers yet?",
			"complete": "Beautiful! These will look perfect in the flower pots!",
		},
		"baker_fruit": {
			"intro": "I'm in the middle of baking, but I'm short on fruit! Could you bring me 20 berries?",
			"accept": "Thank you! I'll save you a fresh pie.",
			"decline": "Oh well, I'll manage somehow.",
			"progress": "The pie crusts are waiting... Any berries yet?",
			"complete": "Perfect! These berries will make wonderful pies! Share some bread with your family.",
		},
		"baker_wheat": {
			"intro": "I'm baking sponge cakes for the town, but I'm completely out of eggs! Bring me 8 fresh eggs?",
			"accept": "Wonderful! The cakes will rise beautifully!",
			"decline": "I'll have to make do with a plain loaf then.",
			"progress": "The mixing bowl is waiting... any eggs yet?",
			"complete": "Perfect eggs! Have some fresh croissants as thanks!",
		},
		"chef_mushroom_soup": {
			"intro": "The daily special is mushroom soup, but I'm out of mushrooms! Gather 15 for me?",
			"accept": "Perfect! The soup will be legendary!",
			"decline": "I'll have to change the menu then...",
			"progress": "My soup pot is still empty...",
			"complete": "Beautiful mushrooms! Take this Mushroom Stew for your journey!",
		},
		"chef_feast": {
			"intro": "We're preparing a grand town feast! Could you contribute 5 Hearty Stew dishes?",
			"accept": "The whole town will celebrate!",
			"decline": "We'll manage with what we have.",
			"progress": "The feast table looks bare without those stews...",
			"complete": "These stews are wonderful! Have some Golden Soup as thanks!",
		},
		"innkeeper_wood": {
			"intro": "I'm building new tables for the tavern. Bring me 40 wood and I'll reward you well!",
			"accept": "Good man! The tavern will be cozier than ever!",
			"decline": "No problem, I'll wait.",
			"progress": "The tavern floor is piled with broken tables...",
			"complete": "Excellent timber! Have some fresh bread on the house!",
		},
		"innkeeper_ale": {
			"intro": "I'm experimenting with a new berry brew recipe. Bring me 25 fresh berries!",
			"accept": "The brews will be flowing!",
			"decline": "The kegs will stay dry then...",
			"progress": "The brew is flat without those berries...",
			"complete": "Perfect berries! Have some Berry Juice as thanks!",
		},
		"blacksmith_copper": {
			"intro": "The forge is cold because I'm out of copper. Mine 15 Copper Ore for me?",
			"accept": "The forge will roar again!",
			"decline": "I'll find another miner.",
			"progress": "My hammer is idle without copper...",
			"complete": "Pure copper ore! Take these ingots as payment.",
		},
		"blacksmith_iron": {
			"intro": "Ready for real work? Bring me 12 Iron Ore and 8 Coal. I'll make you something special.",
			"accept": "Now we're talking! Real forge work!",
			"decline": "It's not for everyone, I suppose.",
			"progress": "The forge is hot but I have no iron...",
			"complete": "Quality materials! These iron ingots are yours.",
		},
		"blacksmith_arms": {
			"intro": "The town guard needs proper weapons. Bring me 5 Steel Ingots and I'll craft you a blacksmith component kit!",
			"accept": "The town will be safe with proper arms!",
			"decline": "The guards will have to do with what they have.",
			"progress": "The weapons rack is still empty...",
			"complete": "Top quality steel! This blacksmith component kit is yours!",
		},
		"shopkeep_rare_goods": {
			"intro": "Wealthy customers want rare gems! Bring me 4 Diamonds from the deep mines!",
			"accept": "The shop will be the talk of the town!",
			"decline": "Not everyone is a miner, I understand.",
			"progress": "My display case sits empty without those gems...",
			"complete": "Magnificent! These will sell for a fortune! Here are some gold ingots!",
		},
		"shopkeep_stock_up": {
			"intro": "I'm running low on basic supplies. Can you bring 15 Wooden Planks and 15 Stone?",
			"accept": "The shelves will be full again!",
			"decline": "I'll have to ration what I have.",
			"progress": "The shelves are looking bare...",
			"complete": "Perfect! Just what I needed. Take this compost for your farm!",
		},
		"scholar_crops": {
			"intro": "I'm writing a botanical encyclopedia. Discover 3 new crop types and share your findings!",
			"accept": "Science marches forward!",
			"decline": "A shame, the island has so many secrets.",
			"progress": "How many crops have you discovered so far?",
			"complete": "Fascinating specimens! This growth booster will help your farming studies!",
		},
		"scholar_rare_flower": {
			"intro": "I'm collecting specimens for my herbarium. Bring me 15 flowers of any kind!",
			"accept": "My collection grows!",
			"decline": "I'll keep pressing the common weeds then.",
			"progress": "The herbarium pages are still empty...",
			"complete": "Lovely specimens! This quality compost should help your garden!",
		},
		"stablehand_fiber": {
			"intro": "The animals need fresh bedding. Can you gather 30 wood for shavings?",
			"accept": "The stables will be cozy again!",
			"decline": "The animals won't be happy...",
			"progress": "The stalls are still dirty without bedding...",
			"complete": "Soft and clean! Take these feathers as a thank you!",
		},
		"stablehand_feed": {
			"intro": "The animals are hungry! Bring 25 berries to feed them, will you?",
			"accept": "The animals will love you!",
			"decline": "Someone has to feed them...",
			"progress": "The troughs are empty and the animals are restless...",
			"complete": "They'll eat well tonight! Here are some fresh eggs as thanks!",
		},
		"slay_sporelings": {
			"intro": "Dangerous sporelings have been seen near the farms! Could you defeat 8 of them?",
			"accept": "The farms will be safe with you on patrol!",
			"decline": "I'll ask someone else then...",
			"progress": "The sporelings are still causing trouble...",
			"complete": "Well done! The farms are safe again. Here's your reward!",
		},
		"shadow_hound_hunt": {
			"intro": "Shadow Hounds are terrorizing the town at night! Defeat 5 of them for us!",
			"accept": "The town will sleep soundly!",
			"decline": "We'll have to barricade the doors...",
			"progress": "The howling keeps everyone awake at night...",
			"complete": "You've banished the darkness! Take these potions for your trouble!",
		},

		# ── Visitor quest dialogues ──
		"visitor_explore_cove": {
			"intro": "Avast! Those pirates nearly sank my ship on the way here — and now they're raiding this island too! Defeat 10 pirate raiders and I'll share my treasure with you!",
			"accept": "Give 'em what-for, matey! I'll be counting the cannon fire!",
			"decline": "The sea dogs will only get bolder...",
			"progress": "Heard any cannon fire? The raiders are still on the loose...",
			"complete": "You sent those scallywags packing! Here — treasure fit for a true captain!",
		},
		"visitor_fish_catch": {
			"intro": "I've heard the fishing here is legendary! Could you catch me 5 Raw Fish so I can taste the local flavor?",
			"accept": "Wonderful! The fresher the better!",
			"decline": "Maybe next time I visit!",
			"progress": "The fish are biting today, or so I hear!",
			"complete": "Beautiful catch! Here's some gold nuggets for your trouble!",
		},
		"visitor_tour_guide": {
			"intro": "I'm new to this island — I've heard the flowers are stunning! Pick 8 flowers and show me the best spots!",
			"accept": "Perfect! I'd love to see what grows here!",
			"decline": "I'll explore on my own then.",
			"progress": "Found any nice flowers yet?",
			"complete": "Lovely! These are so different from my homeland. Some berries for your time!",
		},
		"visitor_trade_goods": {
			"intro": "I'm a trader looking for rare minerals! Bring me 2 obsidian shards from the deep mines and I'll make you a deal you can't refuse!",
			"accept": "A merchant's instinct tells me you'll find something good!",
			"decline": "Ah, not a deep-miner? Well, another time perhaps.",
			"progress": "The market waits for no one — any obsidian yet?",
			"complete": "Superb quality! Gold ingots for your troubles, friend!",
		},
		"visitor_scenic_spot": {
			"intro": "I'm a traveling botanist documenting every wild food this island has to offer! Bring me 10 mushrooms and 10 flowers from your journeys.",
			"accept": "Wonderful! The island's bounty must be recorded!",
			"decline": "Perhaps another time you're out exploring.",
			"progress": "Found any good foraging spots yet?",
			"complete": "A forager's bounty! Have some feathers from my hat!",
		},
		"visitor_help_vendor": {
			"intro": "My cart took a beating on the road! I need 15 wood and 10 stone for repairs. Help me out?",
			"accept": "You're a lifesaver! My wares will reach the next town!",
			"decline": "I'll patch it up as best I can.",
			"progress": "My poor cart is still wobbling...",
			"complete": "Perfect materials! Take these gold nuggets as thanks!",
		},
	}
	return dialogues.get(quest_id, {
		"intro": "I have a task for you, if you're interested.",
		"accept": "Thank you! I knew I could count on you.",
		"decline": "Perhaps another time.",
		"progress": "Have you made any progress on that task?",
		"complete": "You did it! Here's your reward!",
	})


# ===========================================================================
# Runtime state
# ===========================================================================

## quest_id -> {"progress": int, "completed_reqs": Dictionary, "accepted_day": int}
var active_quests: Dictionary = {}

## Array of quest IDs that have been completed (ever, across all playthroughs)
var completed_quests: Array[String] = []

## quest_id -> day_number when completed (for repeatable cooldowns)
var completed_history: Dictionary = {}


func _ready() -> void:
	add_to_group("quest_manager")
	
	# Connect to crop discovery so the scholar_crops quest works
	if DataManager.crop_discovered.is_connected(_on_crop_discovered_for_quests):
		DataManager.crop_discovered.disconnect(_on_crop_discovered_for_quests)
	DataManager.crop_discovered.connect(_on_crop_discovered_for_quests)
	
	print("QuestManager ready — %d quest definitions loaded" % get_quest_defs().size())


# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------

## Fired when DataManager.crop_discovered emits. Updates the scholar_crops
## quest progress with the current total discovered crop count.
func _on_crop_discovered_for_quests(_crop_id: String) -> void:
	var total_discovered: int = DataManager.discovered_crop_ids.size()
	report_crop_discovery(total_discovered)


# ---------------------------------------------------------------------------
# Queries
# ---------------------------------------------------------------------------

## Get quests that a specific NPC role can offer. If role is -1, return all.
## Excludes visitor-only quests (giver_source = "visitor").
static func get_quests_for_role(role: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var defs := get_quest_defs()
	for qid: String in defs:
		var qdef: Dictionary = defs[qid]
		var source: String = qdef.get("giver_source", "resident")
		if source == "visitor":
			continue  # Skip visitor-only quests for residents
		if qdef.get("giver_role", -1) == role or qdef.get("giver_role", -1) == -1:
			result.append(qdef)
	return result

## Get quests that visitor NPCs can offer. Filters by giver_source = "visitor" or "any".
static func get_quests_for_visitor() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var defs := get_quest_defs()
	for qid: String in defs:
		var qdef: Dictionary = defs[qid]
		var source: String = qdef.get("giver_source", "resident")
		if source == "visitor" or source == "any":
			result.append(qdef)
	return result

## Get available (not yet accepted, meets requirements) visitor quests.
func get_available_quests_for_visitor() -> Array[Dictionary]:
	var all_for_visitor := get_quests_for_visitor()
	var result: Array[Dictionary] = []
	var town_manager := get_tree().get_first_node_in_group("town_manager")
	var town_level: int = town_manager.town_level if town_manager else 0
	
	for qdef: Dictionary in all_for_visitor:
		var qid: String = qdef.get("id", "")
		if qid.is_empty():
			continue
		if active_quests.has(qid):
			continue
		if not qdef.get("repeatable", false) and qid in completed_quests:
			continue
		if qdef.get("min_town_level", 0) > town_level:
			continue
		var prereqs: Array = qdef.get("prerequisite_ids", [])
		var prereqs_met := true
		for prereq_id: String in prereqs:
			if prereq_id not in completed_quests:
				prereqs_met = false
				break
		if not prereqs_met:
			continue
		result.append(qdef)
	return result

## Get visitor quests that are ready to turn in.
func get_completable_quests_for_visitor() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for qid: String in active_quests.keys():
		var qdef = get_quest_defs().get(qid)
		if not qdef:
			continue
		var source: String = qdef.get("giver_source", "resident")
		if source != "visitor" and source != "any":
			continue
		if is_quest_completable(qid):
			result.append(qdef)
	return result


## Get quests this NPC can offer that the player hasn't completed (or that are repeatable).
func get_available_quests_for_role(role: int) -> Array[Dictionary]:
	var all_for_role := get_quests_for_role(role)
	var result: Array[Dictionary] = []
	var town_manager := get_tree().get_first_node_in_group("town_manager")
	var town_level: int = town_manager.town_level if town_manager else 0

	for qdef: Dictionary in all_for_role:
		var qid: String = qdef.get("id", "")
		if qid.is_empty():
			continue

		# Skip if already active
		if active_quests.has(qid):
			continue

		# Skip if completed and not repeatable
		if not qdef.get("repeatable", false) and qid in completed_quests:
			continue

		# Check town level requirement
		if qdef.get("min_town_level", 0) > town_level:
			continue

		# Check prerequisites
		var prereqs: Array = qdef.get("prerequisite_ids", [])
		var prereqs_met := true
		for prereq_id: String in prereqs:
			if prereq_id not in completed_quests:
				prereqs_met = false
				break
		if not prereqs_met:
			continue

		result.append(qdef)

	return result


## Get the quests that are ready to turn in for a given NPC role.
## Excludes visitor-only quests (giver_source = "visitor").
func get_completable_quests_for_role(role: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for qid: String in active_quests.keys():
		var qdef = get_quest_defs().get(qid)
		if not qdef:
			continue
		var source: String = qdef.get("giver_source", "resident")
		if source == "visitor":
			continue
		if qdef.get("giver_role", -1) != role and qdef.get("giver_role", -1) != -1:
			continue
		if is_quest_completable(qid):
			result.append(qdef)
	return result


## Check if a quest's requirements are met for turn-in.
func is_quest_completable(quest_id: String) -> bool:
	if not active_quests.has(quest_id):
		return false
	var qdef = get_quest_defs().get(quest_id)
	if not qdef:
		return false

	var reqs: Array = qdef.get("requirements", [])
	var state: Dictionary = active_quests.get(quest_id, {"completed_reqs": {}})
	var completed_reqs: Dictionary = state.get("completed_reqs", {})

	for req: Dictionary in reqs:
		var req_id: String = req.get("id", "")
		var req_count: int = req.get("count", 1)
		var completed: int = completed_reqs.get(req_id, 0)
		if completed < req_count:
			return false
	return true


## Check if the player has a quest active (regardless of role).
func has_active_quest(quest_id: String) -> bool:
	return active_quests.has(quest_id)


## Check if a quest has been completed ever.
func is_quest_completed(quest_id: String) -> bool:
	return quest_id in completed_quests


## Friendly display name for a quest requirement id (handles enemy ids too).
static func _quest_req_display_name(req_id: String) -> String:
	var enemy_names := {
		"SporelingEnemy": "Sporeling",
		"ShadowHound": "Shadow Hound",
		"GhostEnemy": "Casper",
		"PirateRaider": "Pirate Raider",
		"crop_discovery": "Crop Discoveries",
	}
	if enemy_names.has(req_id):
		return enemy_names[req_id]
	var item_data: ItemData = DataManager.get_item(req_id)
	if item_data:
		return item_data.display_name
	return req_id.capitalize()


## Get the current progress text for an active quest.
func get_quest_progress_text(quest_id: String) -> String:
	if not active_quests.has(quest_id):
		return ""
	var qdef = get_quest_defs().get(quest_id)
	if not qdef:
		return ""
	var state: Dictionary = active_quests[quest_id]
	var completed_reqs: Dictionary = state.get("completed_reqs", {})
	var parts: Array[String] = []
	var reqs: Array = qdef.get("requirements", [])
	for req: Dictionary in reqs:
		var req_id: String = req.get("id", "")
		var req_count: int = req.get("count", 1)
		var done: int = completed_reqs.get(req_id, 0)
		var display_name: String = _quest_req_display_name(req_id)
		parts.append("%s %d/%d" % [display_name, done, req_count])
	return ", ".join(parts)


# ---------------------------------------------------------------------------
# Actions
# ---------------------------------------------------------------------------

## Player accepts a quest. Returns true if accepted successfully.
func accept_quest(quest_id: String) -> bool:
	if active_quests.has(quest_id):
		return false
	var qdef = get_quest_defs().get(quest_id)
	if not qdef:
		return false

	active_quests[quest_id] = {
		"progress": 0,
		"completed_reqs": {},
		"accepted_day": GameManager.current_day,
	}

	quest_accepted.emit(quest_id, qdef.get("title", ""))
	quests_updated.emit()
	ToastNotification.show_toast("📜 Quest accepted: %s" % qdef.get("title", ""), ToastNotification.ToastType.INFO, 4.0)
	return true


## Complete a quest and give rewards. Returns true if successful.
func complete_quest(quest_id: String) -> bool:
	if not is_quest_completable(quest_id):
		return false

	var qdef = get_quest_defs().get(quest_id)
	if not qdef:
		return false

	# Remove from active
	active_quests.erase(quest_id)

	# Mark completed
	completed_quests.append(quest_id)
	completed_history[quest_id] = GameManager.current_day

	# ── Grant rewards ──
	# Items
	var reward_items: Array = qdef.get("reward_items", [])
	for reward: Dictionary in reward_items:
		var item_id: String = reward.get("id", "")
		var count: int = reward.get("count", 1)
		if item_id == "gold":
			GameManager.money += count
		else:
			InventoryManager.add_item(item_id, count)

	# Gold
	var gold: int = qdef.get("reward_gold", 0)
	if gold > 0:
		GameManager.money += gold

	# Reputation
	var rep: int = qdef.get("reward_reputation", 0)
	if rep > 0:
		var tm := get_tree().get_first_node_in_group("town_manager")
		if tm and tm.has_method("add_reputation"):
			tm.add_reputation(rep)

	# XP
	var xp: int = qdef.get("reward_xp", 0)
	if xp > 0 and LevelManager:
		LevelManager.add_xp(xp)

	quest_completed.emit(quest_id, qdef.get("title", ""))
	quests_updated.emit()
	ToastNotification.show_toast("✅ Quest complete: %s!" % qdef.get("title", ""), ToastNotification.ToastType.SUCCESS, 5.0)
	return true


## Internal: update quest progress when items are delivered.
## Called by the NPC when items are handed in.
func report_delivery(quest_id: String, item_id: String, count: int) -> bool:
	if not active_quests.has(quest_id):
		return false
	var state: Dictionary = active_quests[quest_id]
	var completed_reqs: Dictionary = state.get("completed_reqs", {})
	completed_reqs[item_id] = completed_reqs.get(item_id, 0) + count
	state["completed_reqs"] = completed_reqs
	quests_updated.emit()

	# Check if completable
	if is_quest_completable(quest_id):
		quest_progressed.emit(quest_id, 1, 1)
	else:
		# Emit progress update
		var qdef = get_quest_defs().get(quest_id)
		if qdef:
			var reqs: Array = qdef.get("requirements", [])
			for req: Dictionary in reqs:
				var req_id: String = req.get("id", "")
				if req_id == item_id:
					quest_progressed.emit(quest_id, completed_reqs.get(item_id, 0), req.get("count", 1))
	return true


## Called by external systems (e.g. Enemy when killed, World when crop discovered).
## Automatically progresses any active quests that track this event.
func report_kill(enemy_script_name: String) -> void:
	for qid: String in active_quests.keys():
		var qdef = get_quest_defs().get(qid)
		if not qdef or qdef.get("req_type", -1) != RequirementType.KILL_ENEMIES:
			continue
		var reqs: Array = qdef.get("requirements", [])
		for req: Dictionary in reqs:
			if req.get("id", "") == enemy_script_name:
				var state: Dictionary = active_quests[qid]
				var completed_reqs: Dictionary = state.get("completed_reqs", {})
				completed_reqs[enemy_script_name] = completed_reqs.get(enemy_script_name, 0) + 1
				state["completed_reqs"] = completed_reqs
				quests_updated.emit()
				if is_quest_completable(qid):
					quest_progressed.emit(qid, req.get("count", 1), req.get("count", 1))
				else:
					quest_progressed.emit(qid, completed_reqs[enemy_script_name], req.get("count", 1))
				return


## Report crop discovery (for scholar_botany quest).
func report_crop_discovery(crop_count: int) -> void:
	var qid := "scholar_crops"
	if not active_quests.has(qid):
		return
	var state: Dictionary = active_quests[qid]
	var completed_reqs: Dictionary = state.get("completed_reqs", {})
	completed_reqs["crop_discovery"] = crop_count
	state["completed_reqs"] = completed_reqs
	quests_updated.emit()
	if is_quest_completable(qid):
		quest_progressed.emit(qid, 3, 3)
	else:
		quest_progressed.emit(qid, crop_count, 3)


## Report item collection (for COLLECT_ITEMS type quests).
func report_collection(item_id: String, count: int) -> void:
	for qid: String in active_quests.keys():
		var qdef = get_quest_defs().get(qid)
		if not qdef or qdef.get("req_type", -1) != RequirementType.COLLECT_ITEMS:
			continue
		var reqs: Array = qdef.get("requirements", [])
		for req: Dictionary in reqs:
			if req.get("id", "") == item_id:
				var state: Dictionary = active_quests[qid]
				var completed_reqs: Dictionary = state.get("completed_reqs", {})
				# For COLLECT_ITEMS, we check the player's actual inventory on turn-in,
				# but track the requirement here for display purposes.
				completed_reqs[item_id] = mini(completed_reqs.get(item_id, 0) + count, req.get("count", 1))
				state["completed_reqs"] = completed_reqs
				quests_updated.emit()
				return


# ---------------------------------------------------------------------------
# Save / Load
# ---------------------------------------------------------------------------

func serialize() -> Dictionary:
	return {
		"active_quests": _serialize_active(),
		"completed_quests": completed_quests.duplicate(),
		"completed_history": completed_history.duplicate(),
	}


func _serialize_active() -> Dictionary:
	var data: Dictionary = {}
	for qid: String in active_quests:
		var state: Dictionary = active_quests[qid]
		data[qid] = {
			"progress": state.get("progress", 0),
			"completed_reqs": state.get("completed_reqs", {}).duplicate(),
			"accepted_day": state.get("accepted_day", 1),
		}
	return data


func deserialize(data: Dictionary) -> void:
	if data.is_empty():
		return
	if data.has("active_quests"):
		var raw: Dictionary = data["active_quests"]
		active_quests.clear()
		for qid: String in raw:
			var s: Dictionary = raw[qid]
			active_quests[qid] = {
				"progress": s.get("progress", 0),
				"completed_reqs": s.get("completed_reqs", {}).duplicate(),
				"accepted_day": s.get("accepted_day", 1),
			}
	if data.has("completed_quests"):
		completed_quests.assign(data["completed_quests"])
	if data.has("completed_history"):
		completed_history.assign(data["completed_history"])
