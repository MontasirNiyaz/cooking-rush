--!strict
-- Recruitment crates (M8 gacha). Each crate is a cost + a weighted drop table,
-- plus a pity rule. The server rolls authoritatively; clients never compute drops.
--
-- Drop odds are derived from the weights and published in-UI (platform policy +
-- player trust). Pity: after `pulls` recruits from this crate without a chef of
-- rarity >= `floorRarity`, the next roll is restricted to chefs >= floorRarity.

export type CrateCost = { coins: number?, gems: number? }

export type DropEntry = { chefId: string, weight: number }

export type Crate = {
	id: string,
	displayName: string,
	cost: CrateCost,
	pity: { pulls: number, floorRarity: string },
	dropTable: { DropEntry },
}

local RecruitCrates: { [string]: Crate } = {
	basic_crate = {
		id = "basic_crate",
		displayName = "Basic Crate",
		cost = { coins = 250 },
		pity = { pulls = 20, floorRarity = "Epic" },
		dropTable = {
			{ chefId = "line_cook", weight = 40 },
			{ chefId = "busser",    weight = 40 },
			{ chefId = "griller",   weight = 22 },
			{ chefId = "waiter",    weight = 22 },
			{ chefId = "saucier",   weight = 9 },
			{ chefId = "fireproof", weight = 9 },
			{ chefId = "sous_chef", weight = 3 },
			{ chefId = "food_runner", weight = 3 },
			{ chefId = "head_chef", weight = 1 },
		},
	},
	premium_crate = {
		id = "premium_crate",
		displayName = "Premium Crate",
		cost = { gems = 50 },
		pity = { pulls = 10, floorRarity = "Legendary" },
		dropTable = {
			{ chefId = "saucier",     weight = 30 },
			{ chefId = "fireproof",   weight = 30 },
			{ chefId = "sous_chef",   weight = 18 },
			{ chefId = "food_runner", weight = 18 },
			{ chefId = "head_chef",   weight = 8 },
			{ chefId = "maitre_d",    weight = 8 },
			{ chefId = "iron_chef",   weight = 2 },
		},
	},
}

return RecruitCrates
