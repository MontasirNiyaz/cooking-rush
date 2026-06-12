--!strict
-- P0.5 / ISSUES #14 — exercises the SHIPPED FastFood/Sushi configs (not mocks):
-- (a) every menu recipe is producible by the real stations (walk steps vs archetypes),
-- (b) generator invariants across ALL level indices,
-- (c) difficulty monotonicity on the base curve,
-- (d) snapshot drift detection for pinned levels {1,10,25,40}.

return function()
	local Shared = game:GetService("ReplicatedStorage").Shared
	local Restaurants    = require(Shared.Config.Restaurants)
	local Recipes        = require(Shared.Config.Recipes)
	local Stations       = require(Shared.Config.Stations)
	local Customers      = require(Shared.Config.Customers)
	local GameConfig     = require(Shared.Config.GameConfig)
	local LevelGenerator = require(Shared.Modules.LevelGenerator)
	local Snapshots      = require(game:GetService("ServerStorage").Tests.LevelSnapshots)

	-- ── Producibility model (against the GLOBAL station set; ingredient shelves
	--    aren't listed in any restaurant's stationIds) ──────────────────────────
	local dispensable: { [string]: boolean } = {}
	local hasAssembler = false
	for _, s in pairs(Stations) do
		if s.archetype == "Dispenser" then dispensable[s.produces] = true end
		if s.archetype == "Assembler" then hasAssembler = true end
	end

	-- Returns (ok, reason). Walks the recipe's steps, tracking items produced so
	-- far; each cook needs a real Cooker whose input is already obtainable, each
	-- dispense a real Dispenser, each assemble an Assembler + obtainable parts.
	local function recipeProducible(recipe: any): (boolean, string)
		local produced: { [string]: boolean } = {}
		local function obtainable(item: string): boolean
			return dispensable[item] == true or produced[item] == true
		end
		for i, step in ipairs(recipe.steps) do
			local where = recipe.id .. ".steps[" .. i .. "]"
			if step.kind == "dispense" then
				local s = Stations[step.station]
				if not s then return false, where .. " unknown station " .. tostring(step.station) end
				if s.archetype ~= "Dispenser" then return false, where .. " station not a Dispenser" end
				if s.produces ~= step.item then return false, where .. " produces " .. tostring(s.produces) .. " not " .. tostring(step.item) end
				produced[step.item] = true
			elseif step.kind == "cook" then
				local s = Stations[step.station]
				if not s then return false, where .. " unknown station " .. tostring(step.station) end
				if s.archetype ~= "Cooker" then return false, where .. " station not a Cooker" end
				if s.output ~= step.item then return false, where .. " outputs " .. tostring(s.output) .. " not " .. tostring(step.item) end
				if not obtainable(s.input) then return false, where .. " cooker input " .. tostring(s.input) .. " not obtainable" end
				produced[step.item] = true
			elseif step.kind == "assemble" then
				if not hasAssembler then return false, where .. " no Assembler station exists" end
				if not obtainable(step.base) then return false, where .. " base " .. tostring(step.base) .. " not obtainable" end
				for _, add in ipairs(step.add) do
					if not obtainable(add) then return false, where .. " add " .. tostring(add) .. " not obtainable" end
				end
				produced[recipe.id] = true
			end
		end
		return true, "ok"
	end

	-- Same serializer used to mint tests/LevelSnapshots.lua (keep byte-identical).
	local function serializeLevel(level: any): string
		local lines = {}
		lines[1] = string.format("%s#%d g=%d/%d/%d dur=%d",
			level.restaurantId, level.index,
			level.goals.oneStar, level.goals.twoStar, level.goals.threeStar,
			math.floor(level.duration))
		for _, sp in ipairs(level.spawns) do
			lines[#lines + 1] = string.format("@%.2f %s [%s] p=%.3f",
				sp.atSecond, sp.customerTypeId, table.concat(sp.orders, ","), sp.patienceScale)
		end
		return table.concat(lines, "\n")
	end

	describe("every shipped recipe is producible by the real stations", function()
		it("all recipes resolve a valid station path", function()
			local problems = {}
			for id, recipe in pairs(Recipes) do
				local ok, reason = recipeProducible(recipe)
				if not ok then table.insert(problems, reason) end
			end
			expect(table.concat(problems, "; ")).to.equal("")
		end)
	end)

	describe("every restaurant's menu is valid + producible", function()
		it("menu recipes exist and are producible", function()
			local problems = {}
			for rid, rest in pairs(Restaurants) do
				for _, recipeId in ipairs(rest.menu) do
					local recipe = Recipes[recipeId]
					if not recipe then
						table.insert(problems, rid .. " menu has unknown recipe " .. recipeId)
					else
						local ok, reason = recipeProducible(recipe)
						if not ok then table.insert(problems, rid .. ": " .. reason) end
					end
				end
			end
			expect(table.concat(problems, "; ")).to.equal("")
		end)
	end)

	describe("generator invariants across all level indices", function()
		it("orders subset menu, customers valid, spawns sorted, goals strictly ordered", function()
			local problems = {}
			for rid, rest in pairs(Restaurants) do
				local menuSet = {}
				for _, m in ipairs(rest.menu) do menuSet[m] = true end
				for index = 1, rest.levelCount do
					local level = LevelGenerator.generate(rest, index, GameConfig, Recipes)
					local tag = rid .. "#" .. index
					local g = level.goals
					if not (g.oneStar < g.twoStar and g.twoStar < g.threeStar) then
						table.insert(problems, tag .. " goals not strictly ordered: " ..
							g.oneStar .. "/" .. g.twoStar .. "/" .. g.threeStar)
					end
					if #level.spawns < 1 then table.insert(problems, tag .. " has no spawns") end
					local prevAt = -math.huge
					for _, sp in ipairs(level.spawns) do
						if sp.atSecond < prevAt then
							table.insert(problems, tag .. " spawns not sorted by atSecond")
						end
						prevAt = sp.atSecond
						if not Customers[sp.customerTypeId] then
							table.insert(problems, tag .. " invalid customer type " .. tostring(sp.customerTypeId))
						end
						if #sp.orders < 1 then table.insert(problems, tag .. " spawn has empty order") end
						for _, oid in ipairs(sp.orders) do
							if not menuSet[oid] then
								table.insert(problems, tag .. " order " .. tostring(oid) .. " not in menu")
							end
						end
					end
				end
			end
			expect(table.concat(problems, "; ")).to.equal("")
		end)
	end)

	describe("difficulty monotonicity on the base curve (overrides excluded)", function()
		it("customerCount non-decreasing, patienceScale non-increasing", function()
			local problems = {}
			for rid, rest in pairs(Restaurants) do
				local bare = table.clone(rest)
				bare.levelOverrides = {}
				local prevCount, prevPatience = -math.huge, math.huge
				for index = 1, rest.levelCount do
					local level = LevelGenerator.generate(bare, index, GameConfig, Recipes)
					local count = #level.spawns
					local patience = level.spawns[1] and level.spawns[1].patienceScale or 0
					if count < prevCount then
						table.insert(problems, rid .. "#" .. index .. " customerCount dropped")
					end
					if patience > prevPatience + 1e-9 then
						table.insert(problems, rid .. "#" .. index .. " patienceScale rose")
					end
					prevCount, prevPatience = count, patience
				end
			end
			expect(table.concat(problems, "; ")).to.equal("")
		end)
	end)

	describe("snapshot drift detection for pinned levels", function()
		it("generated {1,10,25,40} match the committed snapshots", function()
			local problems = {}
			for _, rid in ipairs({ "fastfood", "sushi" }) do
				for _, index in ipairs({ 1, 10, 25, 40 }) do
					local key = rid .. ":" .. index
					local expected = Snapshots[key]
					local actual = serializeLevel(LevelGenerator.generate(Restaurants[rid], index, GameConfig, Recipes))
					if expected == nil then
						table.insert(problems, key .. " missing snapshot")
					elseif actual ~= expected then
						table.insert(problems, key .. " drifted")
					end
				end
			end
			expect(table.concat(problems, "; ")).to.equal("")
		end)
	end)
end
