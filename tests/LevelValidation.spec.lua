--!strict
-- TestEZ spec for the P0.1 level-result validation rules (ISSUES #8 + #9).
-- Covers the pure pieces the server relies on: the instant-submit floor and the
-- server-authoritative star computation that makes a client's star claim irrelevant.

return function()
	local EconomyMath = require(game.ReplicatedStorage.Shared.Modules.EconomyMath)

	describe("minPlausibleSeconds", function()
		it("returns 0 for an empty roster", function()
			expect(EconomyMath.minPlausibleSeconds({ spawns = {} }, 0.5)).to.equal(0)
		end)

		it("scales the LAST spawn's atSecond by the factor", function()
			local level = { spawns = { { atSecond = 2 }, { atSecond = 10 } } }
			expect(EconomyMath.minPlausibleSeconds(level, 0.5)).to.equal(5)
		end)

		it("ignores earlier spawns (uses the final arrival)", function()
			local level = { spawns = { { atSecond = 2 }, { atSecond = 20 }, { atSecond = 40 } } }
			expect(EconomyMath.minPlausibleSeconds(level, 0.25)).to.equal(10)
		end)

		it("a factor of 0 disables the floor", function()
			local level = { spawns = { { atSecond = 99 } } }
			expect(EconomyMath.minPlausibleSeconds(level, 0)).to.equal(0)
		end)
	end)

	describe("starsFor (server is the source of truth — no star inflation)", function()
		local goals = { oneStar = 100, twoStar = 200, threeStar = 300 }

		it("computes 1 star from 1-star coins even if the client claims 3", function()
			-- The server passes coinsEarned (not payload.stars) through starsFor, so a
			-- 3-star claim on 1-star coins can only ever resolve to 1 star.
			expect(EconomyMath.starsFor(120, goals)).to.equal(1)
		end)

		it("computes 0 stars below the 1-star threshold", function()
			expect(EconomyMath.starsFor(99, goals)).to.equal(0)
		end)
	end)
end
