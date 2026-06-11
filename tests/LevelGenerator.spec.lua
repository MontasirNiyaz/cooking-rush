--!strict
-- TestEZ spec for LevelGenerator.
-- All dependencies injected — no Roblox API required.

return function()
	local LevelGenerator = require(game.ReplicatedStorage.Shared.Modules.LevelGenerator)

	-- ── Minimal stubs ─────────────────────────────────────────────────────────

	local MOCK_CONFIG = {
		MIN_CUSTOMERS       = 4,
		MAX_CUSTOMERS       = 18,
		MAX_PATIENCE_SCALE  = 1.3,
		MIN_PATIENCE_SCALE  = 0.8,
		MAX_SPAWN_GAP       = 12,
		MIN_SPAWN_GAP       = 3,
		SPAWN_GAP_JITTER    = 0.3,
		MIN_MAX_ORDERS      = 1,
		MAX_MAX_ORDERS      = 3,
	}

	local MOCK_RECIPES = {
		cheeseburger = { id = "cheeseburger", basePrice = 25 },
		fries        = { id = "fries",        basePrice = 12 },
		cola         = { id = "cola",         basePrice = 8  },
	}

	local MOCK_RESTAURANT = {
		id              = "fastfood",
		levelCount      = 40,
		menu            = { "cheeseburger", "fries", "cola" },
		customerTypeIds = { "casual", "hurried" },
		levelOverrides  = {
			[1] = { customerCount = 4, tutorial = true },
			[5] = { customerCount = 6, durationScale = 1.5 },
		},
	}

	local function gen(index: number)
		return LevelGenerator.generate(MOCK_RESTAURANT, index, MOCK_CONFIG, MOCK_RECIPES)
	end

	-- ── Shape ─────────────────────────────────────────────────────────────────

	describe("output shape", function()
		it("returns a Level with restaurantId and index", function()
			local level = gen(1)
			expect(level.restaurantId).to.equal("fastfood")
			expect(level.index).to.equal(1)
		end)

		it("has a spawns list and a goals table", function()
			local level = gen(10)
			expect(type(level.spawns)).to.equal("table")
			expect(type(level.goals)).to.equal("table")
			expect(type(level.goals.oneStar)).to.equal("number")
			expect(type(level.goals.twoStar)).to.equal("number")
			expect(type(level.goals.threeStar)).to.equal("number")
		end)

		it("has duration = 0 (roster-exhausted mode) by default", function()
			local level = gen(10)
			expect(level.duration).to.equal(0)
		end)

		it("each spawn entry has required fields", function()
			local level = gen(10)
			local s = level.spawns[1]
			expect(type(s.atSecond)).to.equal("number")
			expect(type(s.customerTypeId)).to.equal("string")
			expect(type(s.orders)).to.equal("table")
			expect(type(s.patienceScale)).to.equal("number")
		end)
	end)

	-- ── Customer count scaling ────────────────────────────────────────────────

	describe("customer count", function()
		it("early levels have fewer customers than late levels", function()
			local early = gen(2)
			local late  = gen(38)
			expect(#early.spawns < #late.spawns).to.equal(true)
		end)

		it("spawn count is within [MIN, MAX] bounds", function()
			for _, idx in ipairs({ 1, 10, 20, 30, 40 }) do
				local level = gen(idx)
				-- Override levels may set a fixed count outside the smoothstep range;
				-- only test non-overridden levels here.
				if not (MOCK_RESTAURANT.levelOverrides and MOCK_RESTAURANT.levelOverrides[idx]) then
					expect(#level.spawns >= MOCK_CONFIG.MIN_CUSTOMERS).to.equal(true)
					expect(#level.spawns <= MOCK_CONFIG.MAX_CUSTOMERS).to.equal(true)
				end
			end
		end)
	end)

	-- ── Determinism ───────────────────────────────────────────────────────────

	describe("determinism", function()
		it("generates identical output for the same (restaurant, index)", function()
			local a = gen(15)
			local b = gen(15)
			expect(#a.spawns).to.equal(#b.spawns)
			for i, sa in ipairs(a.spawns) do
				local sb = b.spawns[i]
				expect(sa.atSecond).to.equal(sb.atSecond)
				expect(sa.customerTypeId).to.equal(sb.customerTypeId)
				expect(#sa.orders).to.equal(#sb.orders)
				for j, item in ipairs(sa.orders) do
					expect(item).to.equal(sb.orders[j])
				end
			end
		end)

		it("different indices produce different spawn lists", function()
			local a = gen(5)
			local b = gen(6)
			-- Not a strict equality check (they *could* collide by chance, but won't
			-- for consecutive indices in practice).  Compare first spawn time or
			-- archetype as a proxy for independence.
			local differ = (a.spawns[1].atSecond ~= b.spawns[1].atSecond)
				or (a.spawns[1].customerTypeId ~= b.spawns[1].customerTypeId)
				or (#a.spawns ~= #b.spawns)
			expect(differ).to.equal(true)
		end)
	end)

	-- ── levelOverride: tutorial ───────────────────────────────────────────────

	describe("levelOverrides – tutorial (index 1)", function()
		it("produces exactly 4 spawns", function()
			local level = gen(1)
			expect(#level.spawns).to.equal(4)
		end)

		it("each tutorial spawn has exactly 1 order", function()
			local level = gen(1)
			for _, s in ipairs(level.spawns) do
				expect(#s.orders).to.equal(1)
			end
		end)

		it("tutorial patience scale is inflated (more forgiving)", function()
			-- Tutorial applies patienceScale * 1.4 vs. standard index-1 value
			local tutorial = gen(1)
			local normal   = gen(2)  -- no override
			expect(tutorial.spawns[1].patienceScale > normal.spawns[1].patienceScale).to.equal(true)
		end)

		it("all orders come from the restaurant menu", function()
			local level = gen(1)
			local menuSet: { [string]: boolean } = {}
			for _, item in ipairs(MOCK_RESTAURANT.menu) do menuSet[item] = true end
			for _, s in ipairs(level.spawns) do
				for _, item in ipairs(s.orders) do
					expect(menuSet[item]).to.equal(true)
				end
			end
		end)
	end)

	-- ── levelOverride: durationScale ─────────────────────────────────────────

	describe("levelOverrides – durationScale (index 5)", function()
		it("sets duration > 0 when durationScale is applied", function()
			local level = gen(5)
			expect(level.duration > 0).to.equal(true)
		end)
	end)

	-- ── Goal ordering ─────────────────────────────────────────────────────────

	describe("goal thresholds", function()
		it("oneStar < twoStar < threeStar for mid-game levels", function()
			for _, idx in ipairs({ 10, 20, 30 }) do
				local g = gen(idx).goals
				expect(g.oneStar < g.twoStar).to.equal(true)
				expect(g.twoStar < g.threeStar).to.equal(true)
			end
		end)

		it("all goals are positive integers", function()
			local g = gen(10).goals
			expect(g.oneStar >= 1).to.equal(true)
			expect(g.twoStar >= 2).to.equal(true)
			expect(g.threeStar >= 3).to.equal(true)
		end)
	end)
end
