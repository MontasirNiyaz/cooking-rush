--!strict
-- TestEZ spec for UpgradeMath — the pure modifier math shared by the client
-- Station entity and the server UpgradeService. Run via the Studio TestRunner.

return function()
	local UpgradeMath = require(game.ReplicatedStorage.Shared.Modules.UpgradeMath)

	-- Binary-exact multipliers (0.5) so equality checks don't hit float drift.
	local COOKER_TREE = {
		id = "grill",
		tiers = {
			{ level = 1, cost = 200, displayName = "Grill I",  effect = { field = "cookTime", mult = 0.5 } },
			{ level = 2, cost = 500, displayName = "Grill II", effect = { field = "cookTime", mult = 0.5 } },
		},
	}

	local DISPENSER_TREE = {
		id = "drink_dispenser",
		tiers = {
			{ level = 1, cost = 150, displayName = "Tank I", effect = { field = "maxStock", add = 4 } },
		},
	}

	local function cookerBase()
		return { id = "grill", cookTime = 10, capacity = 2 }
	end

	describe("effectiveStation", function()
		it("returns the base unchanged at level 0", function()
			local base = cookerBase()
			local eff  = UpgradeMath.effectiveStation(base, COOKER_TREE, 0)
			expect(eff.cookTime).to.equal(10)
		end)

		it("applies one tier's multiplier", function()
			local eff = UpgradeMath.effectiveStation(cookerBase(), COOKER_TREE, 1)
			expect(eff.cookTime).to.equal(5)
		end)

		it("applies tiers cumulatively", function()
			local eff = UpgradeMath.effectiveStation(cookerBase(), COOKER_TREE, 2)
			expect(eff.cookTime).to.equal(2.5)
		end)

		it("applies additive effects", function()
			local eff = UpgradeMath.effectiveStation({ id = "drink_dispenser", maxStock = 6 }, DISPENSER_TREE, 1)
			expect(eff.maxStock).to.equal(10)
		end)

		it("never mutates the base config", function()
			local base = cookerBase()
			UpgradeMath.effectiveStation(base, COOKER_TREE, 2)
			expect(base.cookTime).to.equal(10)
		end)

		it("returns the base when there is no tree", function()
			local base = cookerBase()
			local eff  = UpgradeMath.effectiveStation(base, nil, 3)
			expect(eff.cookTime).to.equal(10)
		end)

		it("leaves untouched fields alone", function()
			local eff = UpgradeMath.effectiveStation(cookerBase(), COOKER_TREE, 2)
			expect(eff.capacity).to.equal(2)
		end)
	end)

	describe("nextTier", function()
		it("returns the upcoming tier for the current level", function()
			local tier = UpgradeMath.nextTier(COOKER_TREE, 0)
			expect(tier).to.be.ok()
			expect(tier.cost).to.equal(200)
		end)

		it("returns the second tier when one is owned", function()
			local tier = UpgradeMath.nextTier(COOKER_TREE, 1)
			expect(tier.cost).to.equal(500)
		end)

		it("returns nil at max level", function()
			local tier = UpgradeMath.nextTier(COOKER_TREE, 2)
			expect(tier).to.equal(nil)
		end)
	end)
end
