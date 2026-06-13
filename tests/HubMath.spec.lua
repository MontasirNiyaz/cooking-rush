--!strict
-- TestEZ spec for the pure HubMath module (P1.1 hub visual tiers).

return function()
	local HubMath = require(game.ReplicatedStorage.Shared.Modules.HubMath)

	describe("ownedUpgradeCount", function()
		it("sums upgrade levels across the restaurant's stations only", function()
			local upgrades = { grill = 2, fryer = 1, sushi_roller = 5 }
			local stationIds = { "grill", "fryer", "bun_counter" }
			-- 2 + 1 + 0 (bun_counter unowned) = 3; sushi_roller ignored (other restaurant)
			expect(HubMath.ownedUpgradeCount(upgrades, stationIds)).to.equal(3)
		end)

		it("returns 0 for a fresh profile (nil upgrades)", function()
			expect(HubMath.ownedUpgradeCount(nil, { "grill", "fryer" })).to.equal(0)
		end)

		it("returns 0 when no station is upgraded", function()
			expect(HubMath.ownedUpgradeCount({}, { "grill" })).to.equal(0)
		end)
	end)

	describe("tierFor", function()
		local THRESH = { 0, 3, 8, 15 }

		it("is tier 1 with zero upgrades", function()
			expect(HubMath.tierFor(0, THRESH)).to.equal(1)
		end)

		it("stays tier 1 just below the next threshold", function()
			expect(HubMath.tierFor(2, THRESH)).to.equal(1)
		end)

		it("reaches tier 2 at exactly 3 owned upgrades (the P1.1 accept)", function()
			expect(HubMath.tierFor(3, THRESH)).to.equal(2)
		end)

		it("reaches tier 3 at the third threshold", function()
			expect(HubMath.tierFor(8, THRESH)).to.equal(3)
		end)

		it("caps at the top tier past the last threshold", function()
			expect(HubMath.tierFor(999, THRESH)).to.equal(4)
		end)
	end)
end
