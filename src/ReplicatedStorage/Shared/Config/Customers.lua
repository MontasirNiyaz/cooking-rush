--!strict
-- Customer archetypes: patience, visual variants, tip speed curve.

export type TipCurve = { fast: number, ok: number, slow: number }

export type CustomerType = {
	id: string,
	displayName: string,
	sprites: { string },
	basePatience: number,
	tipCurve: TipCurve,
}

local Customers: { [string]: CustomerType } = {
	casual = {
		id = "casual", displayName = "Casual",
		sprites = { "rbxassetid://0" },
		basePatience = 55,
		tipCurve = { fast = 1.5, ok = 1.0, slow = 0.5 },
	},
	hurried = {
		id = "hurried", displayName = "Hurried",
		sprites = { "rbxassetid://0" },
		basePatience = 35,
		tipCurve = { fast = 2.0, ok = 1.2, slow = 0.0 },
	},
	family = {
		id = "family", displayName = "Family",
		sprites = { "rbxassetid://0" },
		basePatience = 70,
		tipCurve = { fast = 1.3, ok = 1.0, slow = 0.7 },
	},
	tourist = {
		id = "tourist", displayName = "Tourist",
		sprites = { "rbxassetid://0" },
		basePatience = 80,
		tipCurve = { fast = 1.6, ok = 1.1, slow = 0.6 },
	},
	critic = {
		id = "critic", displayName = "Food Critic",
		sprites = { "rbxassetid://0" },
		basePatience = 28,
		tipCurve = { fast = 3.0, ok = 1.5, slow = 0.0 },
	},
}

return Customers
