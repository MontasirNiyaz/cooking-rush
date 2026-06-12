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

-- ── Mastery (M7.1) ─────────────────────────────────────────────────────────────
function Schema.validateMastery(mastery: any, recipeIds: any): Result
	local r: Result = { ok = true, errors = {} }
	if type(mastery.xpPerServe) ~= "number" then err(r, "Mastery.xpPerServe must be number") end

	local function validateThresholds(ctx: string, thresholds: any)
		if type(thresholds) ~= "table" then
			err(r, ctx .. ".thresholds must be table"); return
		end
		if thresholds[1] ~= 0 then err(r, ctx .. ".thresholds[1] must be 0 (level 1 = 0 xp)") end
		for i = 2, #thresholds do
			if type(thresholds[i]) ~= "number" then
				err(r, ctx .. ".thresholds[" .. i .. "] must be number")
			elseif thresholds[i] <= thresholds[i - 1] then
				err(r, ctx .. ".thresholds must be strictly increasing at index " .. i)
			end
		end
	end

	validateThresholds("Mastery.default", mastery.defaultThresholds)
	if type(mastery.defaultPerLevelBonus) ~= "table" then
		err(r, "Mastery.defaultPerLevelBonus must be table")
	end

	-- Overrides must reference real recipes and keep valid shapes.
	if type(mastery.overrides) == "table" then
		for recipeId, ov in pairs(mastery.overrides) do
			local ctx = "Mastery.overrides[" .. tostring(recipeId) .. "]"
			if not recipeIds[recipeId] then err(r, ctx .. " unknown recipe id") end
			if ov.thresholds ~= nil then validateThresholds(ctx, ov.thresholds) end
			if ov.perLevelBonus ~= nil and type(ov.perLevelBonus) ~= "table" then
				err(r, ctx .. ".perLevelBonus must be table")
			end
		end
	end
	return r
end

-- ── Prestige (M7.2) ──────────────────────────────────────────────────────────
function Schema.validatePrestige(prestige: any): Result
	local r: Result = { ok = true, errors = {} }
	local NUM_FIELDS = { "maxLevel", "coinMultPerLevel", "tokensBase", "tokensPerLevel", "equipSlotsPerLevel" }
	for _, f in ipairs(NUM_FIELDS) do
		if type(prestige[f]) ~= "number" then err(r, "Prestige." .. f .. " must be number") end
	end
	if type(prestige.maxLevel) == "number" and prestige.maxLevel < 1 then
		err(r, "Prestige.maxLevel must be >= 1")
	end
	return r
end

-- ── Chefs (M8) ─────────────────────────────────────────────────────────────────
function Schema.validateChefs(chefs: any): Result
	local r: Result = { ok = true, errors = {} }
	if type(chefs.RARITY_ORDER) ~= "table" then
		err(r, "Chefs.RARITY_ORDER must be table"); return r
	end
	local validRarity: { [string]: boolean } = {}
	for _, rar in ipairs(chefs.RARITY_ORDER) do validRarity[rar] = true end

	if type(chefs.list) ~= "table" then
		err(r, "Chefs.list must be table"); return r
	end
	local VALID_TAGS = { cookSpeedMult = true, tipMult = true, burnImmuneChance = true, autoServe = true }
	for id, chef in pairs(chefs.list) do
		local ctx = "Chef[" .. tostring(id) .. "]"
		if chef.id ~= id                       then err(r, ctx .. ".id mismatch with key") end
		if type(chef.displayName) ~= "string"  then err(r, ctx .. ".displayName must be string") end
		if not validRarity[chef.rarity]        then err(r, ctx .. ".rarity invalid: " .. tostring(chef.rarity)) end
		if type(chef.shinyChance) ~= "number"  then err(r, ctx .. ".shinyChance must be number") end
		if type(chef.passives) ~= "table" then
			err(r, ctx .. ".passives must be table")
		else
			for tag in pairs(chef.passives) do
				if not VALID_TAGS[tag] then err(r, ctx .. ".passives unknown tag '" .. tostring(tag) .. "'") end
			end
		end
	end
	return r
end

-- ── RecruitCrates (M8) ─────────────────────────────────────────────────────────
function Schema.validateRecruitCrates(crates: any, chefList: any, validRarity: any): Result
	local r: Result = { ok = true, errors = {} }
	for id, crate in pairs(crates) do
		local ctx = "Crate[" .. tostring(id) .. "]"
		if crate.id ~= id                  then err(r, ctx .. ".id mismatch with key") end
		if type(crate.cost) ~= "table"     then err(r, ctx .. ".cost must be table") end
		if type(crate.cost) == "table" and crate.cost.coins == nil and crate.cost.gems == nil then
			err(r, ctx .. ".cost must specify coins and/or gems")
		end
		if type(crate.pity) ~= "table" then
			err(r, ctx .. ".pity must be table")
		else
			if type(crate.pity.pulls) ~= "number" or crate.pity.pulls < 1 then
				err(r, ctx .. ".pity.pulls must be a positive number")
			end
			if not validRarity[crate.pity.floorRarity] then
				err(r, ctx .. ".pity.floorRarity invalid: " .. tostring(crate.pity.floorRarity))
			end
		end
		if type(crate.dropTable) ~= "table" or #crate.dropTable == 0 then
			err(r, ctx .. ".dropTable must be a non-empty table")
		else
			for i, e in ipairs(crate.dropTable) do
				local ectx = ctx .. ".dropTable[" .. i .. "]"
				if not chefList[e.chefId] then err(r, ectx .. " unknown chefId '" .. tostring(e.chefId) .. "'") end
				if type(e.weight) ~= "number" or e.weight <= 0 then err(r, ectx .. ".weight must be > 0") end
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
	local Mastery      = require(Shared.Config.Mastery)
	local Prestige     = require(Shared.Config.Prestige)
	local Chefs        = require(Shared.Config.Chefs)
	local RecruitCrates = require(Shared.Config.RecruitCrates)

	local allErrors: { string } = {}

	local function collect(result: Result)
		for _, e in ipairs(result.errors) do table.insert(allErrors, e) end
	end

	collect(Schema.validateIngredients(Ingredients))
	collect(Schema.validateStations(Stations))
	collect(Schema.validateRecipes(Recipes, Ingredients))
	collect(Schema.validateRestaurants(Restaurants, Stations, Recipes))
	collect(Schema.validateMastery(Mastery, Recipes))
	collect(Schema.validatePrestige(Prestige))
	collect(Schema.validateChefs(Chefs))

	local validRarity: { [string]: boolean } = {}
	for _, rar in ipairs(Chefs.RARITY_ORDER) do validRarity[rar] = true end
	collect(Schema.validateRecruitCrates(RecruitCrates, Chefs.list, validRarity))

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
