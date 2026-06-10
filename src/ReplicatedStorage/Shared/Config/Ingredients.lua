--!strict
-- Every ingredient in the game: raw, intermediate, final, drink, topping.
-- Adding content = adding an entry here. No code changes required.

export type Ingredient = {
	id: string,
	displayName: string,
	icon: string,
	category: "raw" | "intermediate" | "final" | "drink" | "topping",
}

local Ingredients: { [string]: Ingredient } = {

	-- ── FastFood ──────────────────────────────────────────────────────────────
	raw_patty = {
		id = "raw_patty", displayName = "Raw Patty",
		icon = "rbxassetid://0", category = "raw",
	},
	cooked_patty = {
		id = "cooked_patty", displayName = "Cooked Patty",
		icon = "rbxassetid://0", category = "intermediate",
	},
	bun = {
		id = "bun", displayName = "Bun",
		icon = "rbxassetid://0", category = "topping",
	},
	cheese_slice = {
		id = "cheese_slice", displayName = "Cheese Slice",
		icon = "rbxassetid://0", category = "topping",
	},
	raw_fries = {
		id = "raw_fries", displayName = "Raw Fries",
		icon = "rbxassetid://0", category = "raw",
	},
	fries = {
		id = "fries", displayName = "Fries",
		icon = "rbxassetid://0", category = "final",
	},
	cola = {
		id = "cola", displayName = "Cola",
		icon = "rbxassetid://0", category = "drink",
	},
	cheeseburger = {
		id = "cheeseburger", displayName = "Cheeseburger",
		icon = "rbxassetid://0", category = "final",
	},

	-- ── Sushi ─────────────────────────────────────────────────────────────────
	sushi_rice = {
		id = "sushi_rice", displayName = "Sushi Rice",
		icon = "rbxassetid://0", category = "intermediate",
	},
	raw_salmon = {
		id = "raw_salmon", displayName = "Raw Salmon",
		icon = "rbxassetid://0", category = "raw",
	},
	salmon_slice = {
		id = "salmon_slice", displayName = "Salmon Slice",
		icon = "rbxassetid://0", category = "intermediate",
	},
	nori = {
		id = "nori", displayName = "Nori Sheet",
		icon = "rbxassetid://0", category = "topping",
	},
	salmon_nigiri = {
		id = "salmon_nigiri", displayName = "Salmon Nigiri",
		icon = "rbxassetid://0", category = "final",
	},
	green_tea = {
		id = "green_tea", displayName = "Green Tea",
		icon = "rbxassetid://0", category = "drink",
	},
	miso_soup = {
		id = "miso_soup", displayName = "Miso Soup",
		icon = "rbxassetid://0", category = "final",
	},
	tuna_roll = {
		id = "tuna_roll", displayName = "Tuna Roll",
		icon = "rbxassetid://0", category = "final",
	},
	raw_tuna = {
		id = "raw_tuna", displayName = "Raw Tuna",
		icon = "rbxassetid://0", category = "raw",
	},
	tuna_slice = {
		id = "tuna_slice", displayName = "Tuna Slice",
		icon = "rbxassetid://0", category = "intermediate",
	},
	miso_base = {
		id = "miso_base", displayName = "Miso Base",
		icon = "rbxassetid://0", category = "intermediate",
	},
}

return Ingredients
