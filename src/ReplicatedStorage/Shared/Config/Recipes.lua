--!strict
-- Recipes: ordered steps that yield a final/drink ingredient.
-- recipe.id MUST match an Ingredient id with category "final" or "drink".

export type RecipeStep =
	{ kind: "cook",     station: string, item: string }
  | { kind: "dispense", station: string, item: string }
  | { kind: "assemble", base: string,   add: { string } }

export type Recipe = {
	id: string,
	displayName: string,
	icon: string,
	steps: { RecipeStep },
	basePrice: number,
	prepHintSeconds: number,
}

local Recipes: { [string]: Recipe } = {

	-- ── FastFood ──────────────────────────────────────────────────────────────
	cheeseburger = {
		id = "cheeseburger", displayName = "Cheeseburger",
		icon = "rbxassetid://0",
		steps = {
			{ kind = "cook",    station = "grill",       item = "cooked_patty" },
			{ kind = "assemble", base = "bun", add = { "cooked_patty", "cheese_slice" } },
		},
		basePrice = 12, prepHintSeconds = 14,
	},

	fries = {
		id = "fries", displayName = "Fries",
		icon = "rbxassetid://0",
		steps = {
			{ kind = "cook", station = "fryer", item = "fries" },
		},
		basePrice = 6, prepHintSeconds = 10,
	},

	cola = {
		id = "cola", displayName = "Cola",
		icon = "rbxassetid://0",
		steps = {
			{ kind = "dispense", station = "drink_dispenser", item = "cola" },
		},
		basePrice = 4, prepHintSeconds = 2,
	},

	-- ── Sushi ─────────────────────────────────────────────────────────────────
	salmon_nigiri = {
		id = "salmon_nigiri", displayName = "Salmon Nigiri",
		icon = "rbxassetid://0",
		steps = {
			{ kind = "cook",     station = "fish_prep",   item = "salmon_slice" },
			{ kind = "assemble", base = "sushi_rice", add = { "salmon_slice" } },
		},
		basePrice = 14, prepHintSeconds = 12,
	},

	tuna_roll = {
		id = "tuna_roll", displayName = "Tuna Roll",
		icon = "rbxassetid://0",
		steps = {
			{ kind = "cook",     station = "fish_prep",   item = "tuna_slice" },
			{ kind = "assemble", base = "sushi_rice", add = { "tuna_slice", "nori" } },
		},
		basePrice = 16, prepHintSeconds = 15,
	},

	miso_soup = {
		id = "miso_soup", displayName = "Miso Soup",
		icon = "rbxassetid://0",
		steps = {
			{ kind = "cook", station = "soup_pot", item = "miso_soup" },
		},
		basePrice = 8, prepHintSeconds = 20,
	},

	green_tea = {
		id = "green_tea", displayName = "Green Tea",
		icon = "rbxassetid://0",
		steps = {
			{ kind = "dispense", station = "tea_dispenser", item = "green_tea" },
		},
		basePrice = 5, prepHintSeconds = 2,
	},
}

return Recipes
