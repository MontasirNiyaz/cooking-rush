--!strict
-- TestEZ spec for GachaMath (weighted rolling + pity).

return function()
	local GachaMath = require(game.ReplicatedStorage.Shared.Modules.GachaMath)

	local RARITY = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }

	-- Minimal chef list for filtering/pity by rarity.
	local CHEFS = {
		c1 = { id = "c1", rarity = "Common",    shinyChance = 0 },
		c2 = { id = "c2", rarity = "Rare",      shinyChance = 0 },
		c3 = { id = "c3", rarity = "Legendary", shinyChance = 1 },  -- always shiny
	}

	describe("rarityRank", function()
		it("ranks in ladder order", function()
			expect(GachaMath.rarityRank("Common", RARITY)).to.equal(1)
			expect(GachaMath.rarityRank("Mythic", RARITY)).to.equal(6)
		end)
		it("is 0 for unknown rarity", function()
			expect(GachaMath.rarityRank("Nope", RARITY)).to.equal(0)
		end)
	end)

	describe("totalWeight", function()
		it("sums weights", function()
			expect(GachaMath.totalWeight({ { chefId = "a", weight = 1 }, { chefId = "b", weight = 3 } })).to.equal(4)
		end)
	end)

	describe("pick", function()
		local dt = { { chefId = "a", weight = 1 }, { chefId = "b", weight = 1 }, { chefId = "c", weight = 2 } }
		-- total 4; bands: a [0,1) b [1,2) c [2,4)
		it("picks the first band at roll 0", function()
			expect(GachaMath.pick(dt, 0)).to.equal("a")
		end)
		it("picks the middle band", function()
			expect(GachaMath.pick(dt, 0.25)).to.equal("b")  -- 0.25*4 = 1.0 → band b
		end)
		it("picks the wide band", function()
			expect(GachaMath.pick(dt, 0.5)).to.equal("c")   -- 0.5*4 = 2.0 → band c
			expect(GachaMath.pick(dt, 0.9)).to.equal("c")
		end)
		it("returns nil for an empty table", function()
			expect(GachaMath.pick({}, 0.5)).to.equal(nil)
		end)
	end)

	describe("filterByMinRarity", function()
		local dt = {
			{ chefId = "c1", weight = 1 }, { chefId = "c2", weight = 1 }, { chefId = "c3", weight = 1 },
		}
		it("keeps only chefs at or above the floor", function()
			local out = GachaMath.filterByMinRarity(dt, "Rare", CHEFS, RARITY)
			expect(#out).to.equal(2)  -- c2 (Rare) + c3 (Legendary)
		end)
		it("keeps all when floor is the lowest", function()
			expect(#GachaMath.filterByMinRarity(dt, "Common", CHEFS, RARITY)).to.equal(3)
		end)
	end)

	describe("nextPity", function()
		it("resets to 0 when the floor is met", function()
			expect(GachaMath.nextPity(5, "Epic", "Rare", RARITY)).to.equal(0)
		end)
		it("increments when below the floor", function()
			expect(GachaMath.nextPity(5, "Common", "Rare", RARITY)).to.equal(6)
		end)
	end)

	describe("resolveRecruit", function()
		local crate = {
			pity = { pulls = 3, floorRarity = "Legendary" },
			dropTable = {
				{ chefId = "c1", weight = 99 },  -- Common, dominates normal rolls
				{ chefId = "c3", weight = 1 },   -- Legendary
			},
		}
		it("rolls normally below the pity threshold", function()
			-- pityCounter 0 → next pull is #1, < 3 → no pity; roll 0 → c1
			local r = GachaMath.resolveRecruit(crate, 0, 0, 0.5, CHEFS, RARITY)
			expect(r.chefId).to.equal("c1")
			expect(r.pityTriggered).to.equal(false)
			expect(r.pity).to.equal(1)  -- below floor → counter increments
		end)
		it("forces a floor drop when pity triggers", function()
			-- pityCounter 2 → next pull is #3 == pulls → pity; table filtered to Legendary → c3
			local r = GachaMath.resolveRecruit(crate, 2, 0, 1.0, CHEFS, RARITY)
			expect(r.chefId).to.equal("c3")
			expect(r.pityTriggered).to.equal(true)
			expect(r.pity).to.equal(0)   -- met floor → reset
		end)
		it("flags shiny when the shiny roll is under the chance", function()
			-- c3 has shinyChance 1 → any shinyRoll < 1 is shiny
			local r = GachaMath.resolveRecruit(crate, 2, 0, 0.0, CHEFS, RARITY)
			expect(r.shiny).to.equal(true)
		end)
	end)
end
