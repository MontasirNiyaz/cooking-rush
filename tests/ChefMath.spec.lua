--!strict
-- TestEZ spec for ChefMath (passive aggregation, scaling, equip slots, fusion).
-- Uses a round-friendly mock config so all float arithmetic is exact in binary.

return function()
	local ChefMath = require(game.ReplicatedStorage.Shared.Modules.ChefMath)

	local CFG = {
		CHEF_BASE_EQUIP_SLOTS = 3,
		CHEF_LEVEL_BONUS      = 0.5,   -- each level adds 50% of base bonus
		CHEF_SHINY_BONUS_MULT = 2.0,
		CHEF_FUSION_DUPES     = 3,
	}
	local PRESTIGE_CFG = { equipSlotsPerLevel = 1 }

	local CHEFS = {
		cook  = { id = "cook",  passives = { cookSpeedMult = 1.5 } },
		tipper = { id = "tipper", passives = { tipMult = 1.5 } },
		fire  = { id = "fire",  passives = { burnImmuneChance = 0.5 } },
		runner = { id = "runner", passives = { autoServe = true } },
	}

	describe("bonusScale", function()
		it("is 1.0 at level 1, non-shiny", function()
			expect(ChefMath.bonusScale(1, false, CFG)).to.equal(1)
		end)
		it("grows with level", function()
			expect(ChefMath.bonusScale(2, false, CFG)).to.equal(1.5)  -- 1 + 1*0.5
		end)
		it("doubles when shiny", function()
			expect(ChefMath.bonusScale(1, true, CFG)).to.equal(2)
		end)
	end)

	describe("aggregatePassives", function()
		it("returns neutral when nothing is equipped", function()
			local p = ChefMath.aggregatePassives({}, {}, CHEFS, CFG)
			expect(p.cookSpeedMult).to.equal(1)
			expect(p.tipMult).to.equal(1)
			expect(p.burnImmuneChance).to.equal(0)
			expect(p.autoServe).to.equal(false)
		end)

		it("applies a single chef's bonus at level 1", function()
			local owned = { { uid = 1, chefId = "cook", shiny = false, level = 1 } }
			local p = ChefMath.aggregatePassives(owned, { 1 }, CHEFS, CFG)
			expect(p.cookSpeedMult).to.equal(1.5)  -- 1 + (1.5-1)*1
		end)

		it("scales the bonus with level", function()
			local owned = { { uid = 1, chefId = "cook", shiny = false, level = 2 } }
			local p = ChefMath.aggregatePassives(owned, { 1 }, CHEFS, CFG)
			expect(p.cookSpeedMult).to.equal(1.75)  -- 1 + (0.5)*1.5
		end)

		it("doubles the bonus when shiny", function()
			local owned = { { uid = 1, chefId = "cook", shiny = true, level = 1 } }
			local p = ChefMath.aggregatePassives(owned, { 1 }, CHEFS, CFG)
			expect(p.cookSpeedMult).to.equal(2)  -- 1 + (0.5)*2
		end)

		it("stacks two chefs multiplicatively", function()
			local owned = {
				{ uid = 1, chefId = "cook", shiny = false, level = 1 },
				{ uid = 2, chefId = "cook", shiny = false, level = 1 },
			}
			local p = ChefMath.aggregatePassives(owned, { 1, 2 }, CHEFS, CFG)
			expect(p.cookSpeedMult).to.equal(2.25)  -- 1.5 * 1.5
		end)

		it("combines burn immunity as independent probabilities", function()
			local owned = {
				{ uid = 1, chefId = "fire", shiny = false, level = 1 },
				{ uid = 2, chefId = "fire", shiny = false, level = 1 },
			}
			local p = ChefMath.aggregatePassives(owned, { 1, 2 }, CHEFS, CFG)
			expect(p.burnImmuneChance).to.equal(0.75)  -- 1 - (0.5)(0.5)
		end)

		it("ORs the autoServe tag", function()
			local owned = { { uid = 1, chefId = "runner", shiny = false, level = 1 } }
			local p = ChefMath.aggregatePassives(owned, { 1 }, CHEFS, CFG)
			expect(p.autoServe).to.equal(true)
		end)

		it("ignores chefs that are owned but not equipped", function()
			local owned = { { uid = 1, chefId = "cook", shiny = false, level = 1 } }
			local p = ChefMath.aggregatePassives(owned, {}, CHEFS, CFG)
			expect(p.cookSpeedMult).to.equal(1)
		end)
	end)

	describe("totalPrestige", function()
		it("sums the prestige map", function()
			expect(ChefMath.totalPrestige({ fastfood = 2, sushi = 1 })).to.equal(3)
		end)
		it("is 0 for an empty map", function()
			expect(ChefMath.totalPrestige({})).to.equal(0)
		end)
	end)

	describe("equipSlots", function()
		it("is the base count at zero prestige", function()
			expect(ChefMath.equipSlots(0, CFG, PRESTIGE_CFG)).to.equal(3)
		end)
		it("grows with total prestige", function()
			expect(ChefMath.equipSlots(2, CFG, PRESTIGE_CFG)).to.equal(5)
		end)
	end)

	describe("fusionCost / countOfChef", function()
		it("returns the configured dupe cost", function()
			expect(ChefMath.fusionCost(1, CFG)).to.equal(3)
		end)
		it("counts owned chefs of a given id", function()
			local owned = {
				{ uid = 1, chefId = "cook" }, { uid = 2, chefId = "cook" }, { uid = 3, chefId = "fire" },
			}
			expect(ChefMath.countOfChef(owned, "cook")).to.equal(2)
			expect(ChefMath.countOfChef(owned, "fire")).to.equal(1)
		end)
	end)
end
