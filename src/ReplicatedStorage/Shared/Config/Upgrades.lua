--!strict
-- Upgrade trees keyed by station/recipe id.
-- Each level is applied as a MODIFIER over base Stations.lua data — never mutate base config.

export type UpgradeEffect = {
	field: string,
	mult: number?,
	add: number?,
}

export type UpgradeTier = {
	level: number,
	cost: number,
	effect: UpgradeEffect,
	displayName: string,
}

export type UpgradeTree = {
	id: string,
	tiers: { UpgradeTier },
}

local Upgrades: { [string]: UpgradeTree } = {
	grill = {
		id = "grill",
		tiers = {
			{ level = 1, cost = 200,  displayName = "Better Grill I",   effect = { field = "cookTime", mult = 0.90 } },
			{ level = 2, cost = 500,  displayName = "Better Grill II",  effect = { field = "cookTime", mult = 0.85 } },
			{ level = 3, cost = 1000, displayName = "Pro Grill",        effect = { field = "cookTime", mult = 0.75 } },
		},
	},
	fryer = {
		id = "fryer",
		tiers = {
			{ level = 1, cost = 200,  displayName = "Fryer Upgrade I",  effect = { field = "cookTime", mult = 0.90 } },
			{ level = 2, cost = 500,  displayName = "Fryer Upgrade II", effect = { field = "cookTime", mult = 0.85 } },
			{ level = 3, cost = 1000, displayName = "Speed Fryer",      effect = { field = "cookTime", mult = 0.75 } },
		},
	},
	fish_prep = {
		id = "fish_prep",
		tiers = {
			{ level = 1, cost = 300,  displayName = "Sharp Knife I",    effect = { field = "cookTime", mult = 0.88 } },
			{ level = 2, cost = 700,  displayName = "Sharp Knife II",   effect = { field = "cookTime", mult = 0.80 } },
		},
	},
	soup_pot = {
		id = "soup_pot",
		tiers = {
			{ level = 1, cost = 250,  displayName = "Faster Pot I",     effect = { field = "cookTime", mult = 0.85 } },
			{ level = 2, cost = 600,  displayName = "Faster Pot II",    effect = { field = "cookTime", mult = 0.75 } },
		},
	},
	drink_dispenser = {
		id = "drink_dispenser",
		tiers = {
			{ level = 1, cost = 150, displayName = "Extra Tank I",   effect = { field = "maxStock",   add = 4 } },
			{ level = 2, cost = 350, displayName = "Extra Tank II",  effect = { field = "refillTime", mult = 0.5 } },
		},
	},
}

return Upgrades
