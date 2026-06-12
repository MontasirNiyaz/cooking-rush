--!strict
-- Chef roster (M8). Chefs are this game's collectible "pets": rarity-tiered,
-- equip-able, and they grant passive bonuses to the kitchen.
--
-- Passives are EFFECT TAGS consumed by existing systems, not bespoke code:
--   cookSpeedMult    → Station cooker (faster cooking)              [>1 = faster]
--   tipMult          → serve earnings (folded into earningsMult)    [>1 = more coins]
--   burnImmuneChance → Station cooker (chance to ignore a burn)     [0..1]
--   autoServe        → ChefController auto-delivers a ready dish periodically
--
-- Adding a chef = one row here. New *tags* are the only thing that ever needs
-- engine code; every tag above is already consumed by a system.

export type ChefPassives = {
	cookSpeedMult: number?,
	tipMult: number?,
	burnImmuneChance: number?,
	autoServe: boolean?,
}

export type Chef = {
	id: string,
	displayName: string,
	rarity: string,
	model: string,          -- reserved: model shown in-kitchen / following the player
	passives: ChefPassives,
	shinyChance: number,    -- per-recruit chance this chef rolls as a shiny variant
}

local Chefs = {}

-- Rarity ladder, low → high. Used for pity floors and UI ordering/colour.
Chefs.RARITY_ORDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }

Chefs.RARITY_COLOR = {
	Common    = Color3.fromRGB(180, 180, 185),
	Uncommon  = Color3.fromRGB(110, 205, 120),
	Rare      = Color3.fromRGB(90, 150, 240),
	Epic      = Color3.fromRGB(180, 110, 230),
	Legendary = Color3.fromRGB(245, 180, 60),
	Mythic    = Color3.fromRGB(240, 90, 110),
}

-- The roster, keyed by id. A 200-chef game is just more rows here.
Chefs.list = {
	line_cook = {
		id = "line_cook", displayName = "Line Cook", rarity = "Common", model = "",
		passives = { cookSpeedMult = 1.05 }, shinyChance = 0.01,
	},
	busser = {
		id = "busser", displayName = "Busser", rarity = "Common", model = "",
		passives = { tipMult = 1.05 }, shinyChance = 0.01,
	},
	griller = {
		id = "griller", displayName = "Grill Hand", rarity = "Uncommon", model = "",
		passives = { cookSpeedMult = 1.12 }, shinyChance = 0.01,
	},
	waiter = {
		id = "waiter", displayName = "Waiter", rarity = "Uncommon", model = "",
		passives = { tipMult = 1.12 }, shinyChance = 0.01,
	},
	saucier = {
		id = "saucier", displayName = "Saucier", rarity = "Rare", model = "",
		passives = { cookSpeedMult = 1.15, tipMult = 1.05 }, shinyChance = 0.012,
	},
	fireproof = {
		id = "fireproof", displayName = "Fireproof Cook", rarity = "Rare", model = "",
		passives = { burnImmuneChance = 0.25 }, shinyChance = 0.012,
	},
	sous_chef = {
		id = "sous_chef", displayName = "Sous Chef", rarity = "Epic", model = "",
		passives = { cookSpeedMult = 1.25, tipMult = 1.10 }, shinyChance = 0.015,
	},
	food_runner = {
		id = "food_runner", displayName = "Food Runner", rarity = "Epic", model = "",
		passives = { autoServe = true, tipMult = 1.05 }, shinyChance = 0.015,
	},
	head_chef = {
		id = "head_chef", displayName = "Head Chef", rarity = "Legendary", model = "",
		passives = { cookSpeedMult = 1.35, tipMult = 1.20, burnImmuneChance = 0.30 }, shinyChance = 0.02,
	},
	maitre_d = {
		id = "maitre_d", displayName = "Maître d'", rarity = "Legendary", model = "",
		passives = { tipMult = 1.35, autoServe = true }, shinyChance = 0.02,
	},
	iron_chef = {
		id = "iron_chef", displayName = "Iron Chef", rarity = "Mythic", model = "",
		passives = { cookSpeedMult = 1.50, tipMult = 1.50, burnImmuneChance = 0.50, autoServe = true }, shinyChance = 0.03,
	},
} :: { [string]: Chef }

return Chefs
