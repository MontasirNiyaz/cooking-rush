--!strict
-- Station archetype instances. Behaviour is selected by `archetype`; no per-station code.
-- Differences between a Grill and a Fryer are entirely in this file.

export type Station = {
	id: string,
	displayName: string,
	archetype: "Cooker" | "Dispenser" | "Assembler",
	capacity: number,
	upgradeTreeId: string?,

	-- Cooker fields
	input: string?,
	output: string?,
	cookTime: number?,
	burnTime: number?,

	-- Dispenser fields
	produces: string?,
	refillTime: number?,
	maxStock: number?,

	-- Assembler: behaviour driven by matching recipe.steps assemble entries
}

local Stations: { [string]: Station } = {

	-- ── FastFood ──────────────────────────────────────────────────────────────
	grill = {
		id = "grill", displayName = "Grill",
		archetype = "Cooker", capacity = 2,
		input = "raw_patty", output = "cooked_patty",
		cookTime = 12, burnTime = 8,
		upgradeTreeId = "grill",
	},
	fryer = {
		id = "fryer", displayName = "Fryer",
		archetype = "Cooker", capacity = 2,
		input = "raw_fries", output = "fries",
		cookTime = 10, burnTime = 6,
		upgradeTreeId = "fryer",
	},
	bun_counter = {
		id = "bun_counter", displayName = "Assembly Counter",
		archetype = "Assembler", capacity = 1,
	},
	drink_dispenser = {
		id = "drink_dispenser", displayName = "Drink Dispenser",
		archetype = "Dispenser", capacity = 1,
		produces = "cola", refillTime = 1, maxStock = 8,
	},

	-- ── FastFood ingredient shelves (effectively infinite stock) ───────────────
	raw_patty_shelf = {
		id = "raw_patty_shelf", displayName = "Patty Shelf",
		archetype = "Dispenser", capacity = 1,
		produces = "raw_patty", refillTime = 1, maxStock = 999,
	},
	raw_fries_shelf = {
		id = "raw_fries_shelf", displayName = "Fries Shelf",
		archetype = "Dispenser", capacity = 1,
		produces = "raw_fries", refillTime = 1, maxStock = 999,
	},
	bun_shelf = {
		id = "bun_shelf", displayName = "Bun Shelf",
		archetype = "Dispenser", capacity = 1,
		produces = "bun", refillTime = 1, maxStock = 999,
	},
	cheese_shelf = {
		id = "cheese_shelf", displayName = "Cheese Shelf",
		archetype = "Dispenser", capacity = 1,
		produces = "cheese_slice", refillTime = 1, maxStock = 999,
	},

	-- ── Sushi ─────────────────────────────────────────────────────────────────
	fish_prep = {
		id = "fish_prep", displayName = "Fish Prep Station",
		archetype = "Cooker", capacity = 2,
		-- input is determined at runtime from the recipe step item being placed;
		-- multiple fish types handled by mapping input→output via Recipes
		input = "raw_salmon", output = "salmon_slice",
		cookTime = 10, burnTime = 12,
		upgradeTreeId = "fish_prep",
	},
	sushi_roller = {
		id = "sushi_roller", displayName = "Sushi Roller",
		archetype = "Assembler", capacity = 1,
	},
	soup_pot = {
		id = "soup_pot", displayName = "Soup Pot",
		archetype = "Cooker", capacity = 1,
		input = "miso_base", output = "miso_soup",
		cookTime = 20, burnTime = 15,
		upgradeTreeId = "soup_pot",
	},
	rice_dispenser = {
		id = "rice_dispenser", displayName = "Rice Dispenser",
		archetype = "Dispenser", capacity = 1,
		produces = "sushi_rice", refillTime = 3, maxStock = 6,
	},
	tea_dispenser = {
		id = "tea_dispenser", displayName = "Tea Dispenser",
		archetype = "Dispenser", capacity = 1,
		produces = "green_tea", refillTime = 2, maxStock = 8,
	},
}

return Stations
