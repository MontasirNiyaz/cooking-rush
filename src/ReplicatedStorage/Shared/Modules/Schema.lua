--!strict
-- Runtime validation of all config tables. Called once on server boot.
-- Catches content bugs (wrong field names, bad ids) before they hit gameplay.

local Schema = {}

type Error = string
type Result = { ok: boolean, errors: { Error } }

local function err(result: Result, msg: Error)
	result.ok = false
	table.insert(result.errors, msg)
end

local VALID_CATEGORIES = { raw = true, intermediate = true, final = true, drink = true, topping = true }
local VALID_ARCHETYPES  = { Cooker = true, Dispenser = true, Assembler = true }
local VALID_STEP_KINDS  = { cook = true, dispense = true, assemble = true }

-- ── Ingredients ──────────────────────────────────────────────────────────────
function Schema.validateIngredients(ingredients: any): Result
	local r: Result = { ok = true, errors = {} }
	for id, ing in pairs(ingredients) do
		local ctx = "Ingredient[" .. id .. "]"
		if type(ing.id) ~= "string"          then err(r, ctx .. ".id must be string") end
		if ing.id ~= id                       then err(r, ctx .. ".id mismatch with key") end
		if type(ing.displayName) ~= "string"  then err(r, ctx .. ".displayName must be string") end
		if type(ing.icon) ~= "string"         then err(r, ctx .. ".icon must be string") end
		if not VALID_CATEGORIES[ing.category] then err(r, ctx .. ".category invalid: " .. tostring(ing.category)) end
	end
	return r
end

-- ── Stations ─────────────────────────────────────────────────────────────────
function Schema.validateStations(stations: any): Result
	local r: Result = { ok = true, errors = {} }
	for id, s in pairs(stations) do
		local ctx = "Station[" .. id .. "]"
		if type(s.id) ~= "string"           then err(r, ctx .. ".id must be string") end
		if s.id ~= id                        then err(r, ctx .. ".id mismatch with key") end
		if not VALID_ARCHETYPES[s.archetype] then err(r, ctx .. ".archetype invalid: " .. tostring(s.archetype)) end
		if type(s.capacity) ~= "number"      then err(r, ctx .. ".capacity must be number") end
		if s.archetype == "Cooker" then
			if type(s.cookTime) ~= "number" then err(r, ctx .. " Cooker requires cookTime") end
			if type(s.burnTime) ~= "number" then err(r, ctx .. " Cooker requires burnTime") end
		end
		if s.archetype == "Dispenser" then
			if type(s.produces)    ~= "string" then err(r, ctx .. " Dispenser requires produces") end
			if type(s.refillTime)  ~= "number" then err(r, ctx .. " Dispenser requires refillTime") end
			if type(s.maxStock)    ~= "number" then err(r, ctx .. " Dispenser requires maxStock") end
		end
	end
	return r
end

-- ── Recipes ───────────────────────────────────────────────────────────────────
function Schema.validateRecipes(recipes: any, ingredients: any): Result
	local r: Result = { ok = true, errors = {} }
	for id, recipe in pairs(recipes) do
		local ctx = "Recipe[" .. id .. "]"
		if type(recipe.id) ~= "string"          then err(r, ctx .. ".id must be string") end
		if recipe.id ~= id                       then err(r, ctx .. ".id mismatch with key") end
		if type(recipe.basePrice) ~= "number"    then err(r, ctx .. ".basePrice must be number") end
		if type(recipe.prepHintSeconds) ~= "number" then err(r, ctx .. ".prepHintSeconds must be number") end
		if type(recipe.steps) ~= "table"         then err(r, ctx .. ".steps must be table") end

		-- Final item (recipe.id) must exist in Ingredients
		if not ingredients[recipe.id] then
			err(r, ctx .. " no Ingredient with id '" .. recipe.id .. "'")
		end

		for i, step in ipairs(recipe.steps) do
			local sctx = ctx .. ".steps[" .. i .. "]"
			if not VALID_STEP_KINDS[step.kind] then err(r, sctx .. ".kind invalid: " .. tostring(step.kind)) end
			if step.kind == "cook" or step.kind == "dispense" then
				if type(step.station) ~= "string" then err(r, sctx .. " requires station string") end
				if type(step.item)    ~= "string" then err(r, sctx .. " requires item string") end
			end
			if step.kind == "assemble" then
				if type(step.base) ~= "string" then err(r, sctx .. " requires base string") end
				if type(step.add)  ~= "table"  then err(r, sctx .. " requires add table") end
			end
		end
	end
	return r
end

-- ── Restaurants ───────────────────────────────────────────────────────────────
function Schema.validateRestaurants(restaurants: any, stationIds: any, recipeIds: any): Result
	local r: Result = { ok = true, errors = {} }
	for id, rest in pairs(restaurants) do
		local ctx = "Restaurant[" .. id .. "]"
		if rest.id ~= id then err(r, ctx .. ".id mismatch") end
		if type(rest.displayName)    ~= "string" then err(r, ctx .. ".displayName must be string") end
		if type(rest.levelCount)     ~= "number" then err(r, ctx .. ".levelCount must be number") end
		if type(rest.stationIds)     ~= "table"  then err(r, ctx .. ".stationIds must be table") end
		if type(rest.menu)           ~= "table"  then err(r, ctx .. ".menu must be table") end
		if type(rest.customerTypeIds) ~= "table" then err(r, ctx .. ".customerTypeIds must be table") end
		for _, sid in ipairs(rest.stationIds) do
			if not stationIds[sid] then err(r, ctx .. " unknown stationId '" .. sid .. "'") end
		end
		for _, rid in ipairs(rest.menu) do
			if not recipeIds[rid] then err(r, ctx .. " unknown menu recipe '" .. rid .. "'") end
		end
	end
	return r
end

-- ── Hub plots ─────────────────────────────────────────────────────────────────
local function isVec3ish(t: any, keys: { string }): boolean
	if type(t) ~= "table" then return false end
	for _, k in ipairs(keys) do
		if type(t[k]) ~= "number" then return false end
	end
	return true
end

function Schema.validateHubPlots(plots: any, restaurantIds: any): Result
	local r: Result = { ok = true, errors = {} }
	if type(plots) ~= "table" then
		err(r, "HubPlots must be a table")
		return r
	end
	for i, plot in ipairs(plots) do
		local ctx = "HubPlot[" .. i .. "]"
		if not restaurantIds[plot.restaurantId] then
			err(r, ctx .. " unknown restaurantId '" .. tostring(plot.restaurantId) .. "'")
		end
		if not isVec3ish(plot.door, { "x", "y", "z", "yaw" }) then
			err(r, ctx .. ".door needs numeric x,y,z,yaw")
		end
		if not isVec3ish(plot.building, { "x", "y", "z", "sizeX", "sizeY", "sizeZ" }) then
			err(r, ctx .. ".building needs numeric x,y,z,sizeX,sizeY,sizeZ")
		end

		local tiers = plot.signageTiers
		local thresholds = plot.tierThresholds
		if type(tiers) ~= "table" or #tiers == 0 then
			err(r, ctx .. ".signageTiers must be a non-empty array")
		end
		if type(thresholds) ~= "table" or #thresholds == 0 then
			err(r, ctx .. ".tierThresholds must be a non-empty array")
		elseif thresholds[1] ~= 0 then
			err(r, ctx .. ".tierThresholds[1] must be 0 (every player is ≥ tier 1)")
		else
			for t = 2, #thresholds do
				if thresholds[t] <= thresholds[t - 1] then
					err(r, ctx .. ".tierThresholds must be strictly ascending")
					break
				end
			end
		end
		if type(tiers) == "table" and type(thresholds) == "table" and #tiers ~= #thresholds then
			err(r, ctx .. " signageTiers and tierThresholds must have equal length (one colour per tier)")
		end
		if type(tiers) == "table" then
			for t, colour in ipairs(tiers) do
				if not (type(colour) == "table" and #colour == 3
					and type(colour[1]) == "number" and type(colour[2]) == "number" and type(colour[3]) == "number") then
					err(r, ctx .. ".signageTiers[" .. t .. "] must be {r,g,b}")
				end
			end
		end
	end
	return r
end

-- ── Master validator ──────────────────────────────────────────────────────────
function Schema.validateAll()
	local Shared = game:GetService("ReplicatedStorage").Shared
	local Ingredients  = require(Shared.Config.Ingredients)
	local Stations     = require(Shared.Config.Stations)
	local Recipes      = require(Shared.Config.Recipes)
	local Restaurants  = require(Shared.Config.Restaurants)
	local Customers    = require(Shared.Config.Customers)
	local HubPlots     = require(Shared.Config.HubPlots)

	local allErrors: { string } = {}

	local function collect(result: Result)
		for _, e in ipairs(result.errors) do table.insert(allErrors, e) end
	end

	collect(Schema.validateIngredients(Ingredients))
	collect(Schema.validateStations(Stations))
	collect(Schema.validateRecipes(Recipes, Ingredients))
	collect(Schema.validateRestaurants(Restaurants, Stations, Recipes))
	collect(Schema.validateHubPlots(HubPlots, Restaurants))

	-- Customers: minimal check
	for id, c in pairs(Customers) do
		if c.id ~= id then
			table.insert(allErrors, "Customer[" .. id .. "].id mismatch")
		end
		if type(c.basePatience) ~= "number" then
			table.insert(allErrors, "Customer[" .. id .. "].basePatience must be number")
		end
	end

	if #allErrors > 0 then
		error("[Schema] Config validation failed:\n" .. table.concat(allErrors, "\n"), 2)
	end

	print("[Schema] All config tables validated OK.")
end

return Schema
