--!strict
-- Hub plot layout + visual tiers for each restaurant building (P1.1).
--
-- One entry per restaurant building in the food-court plaza. Pure data (plain
-- numbers — no Roblox datatypes) so it stays unit-testable and the world builder,
-- server, and client all read the same truth. Adding a restaurant's building =
-- add an entry here; no per-restaurant world scripts.
--
-- Coordinate convention (matches build_world.lua): kitchens sit behind the plaza
-- at Z<0, shared seats at Z=+4, the plaza/doors face the player at Z>+6.
--   door      — plaza-side interaction anchor; the builder places a tagged door
--               Part here. yaw = facing in degrees.
--   building  — facade greybox centre + size (the signage Part rides its front).
--   signageTiers — tier (1-based) → greybox signage colour {r,g,b}. Asset ids
--               slot in later; greybox colour makes the tier change visible now.
--   tierThresholds — tier (1-based) → minimum owned upgrades; ascending, [1]=0.
--               At 3 owned upgrades a building reaches tier 2 (the P1.1 accept).

export type HubPlot = {
	restaurantId: string,
	door: { x: number, y: number, z: number, yaw: number },
	building: { x: number, y: number, z: number, sizeX: number, sizeY: number, sizeZ: number },
	signageTiers: { { number } },
	tierThresholds: { number },
}

local TIER_COLOURS = {
	{ 120, 120, 120 },  -- tier 1: plain grey (starter)
	{ 70, 130, 200 },   -- tier 2: blue
	{ 210, 160, 40 },   -- tier 3: gold
	{ 210, 80, 80 },    -- tier 4: red (prestige flair later)
}
local TIER_THRESHOLDS = { 0, 3, 8, 15 }

local HubPlots: { HubPlot } = {
	{
		restaurantId   = "fastfood",
		door           = { x = -10, y = 3, z = 8, yaw = 180 },
		building       = { x = -10, y = 6, z = -3, sizeX = 28, sizeY = 12, sizeZ = 6 },
		signageTiers   = TIER_COLOURS,
		tierThresholds = TIER_THRESHOLDS,
	},
	{
		restaurantId   = "sushi",
		door           = { x = 34, y = 3, z = 8, yaw = 180 },
		building       = { x = 34, y = 6, z = -3, sizeX = 32, sizeY = 12, sizeZ = 6 },
		signageTiers   = TIER_COLOURS,
		tierThresholds = TIER_THRESHOLDS,
	},
}

return HubPlots
