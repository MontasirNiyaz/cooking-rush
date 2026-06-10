--!strict
-- Registry: require every restaurant module and expose as a keyed map.
-- To add a restaurant: create its module, require it here.

local FastFood = require(script.FastFood)
local Sushi    = require(script.Sushi)

export type RestaurantConfig = {
	id: string,
	displayName: string,
	unlock: { level: number, coins: number, gems: number },
	stationIds: { string },
	menu: { string },
	customerTypeIds: { string },
	dailyIncome: number,
	levelCount: number,
	levelOverrides: { [number]: { [string]: any } },
}

local Restaurants: { [string]: RestaurantConfig } = {
	[FastFood.id] = FastFood,
	[Sushi.id]    = Sushi,
}

return Restaurants
