--!strict
-- TestEZ spec for EconomyMath.
-- Run via a TestEZ runner in Studio (no live game session needed).

return function()
	local EconomyMath = require(game.ReplicatedStorage.Shared.Modules.EconomyMath)

	local MOCK_CONFIG = {
		COMBO_MULTIPLIERS     = { 1.0, 1.1, 1.25, 1.5 },
		COMBO_TIER_THRESHOLDS = { 0, 2, 4, 7 },
		TIP_FAST              = 1.5,
		TIP_OK                = 1.0,
		TIP_SLOW              = 0.5,
		TIP_FAST_THRESHOLD    = 0.35,
		TIP_SLOW_THRESHOLD    = 0.75,
		GEM_FIRST_THREE_STAR  = 3,
		XP_PER_STAR           = 10,
	}

	local MOCK_CURVE = { fast = 1.5, ok = 1.0, slow = 0.5 }

	describe("tipMultiplier", function()
		it("returns fast multiplier when plenty of patience remains", function()
			-- patienceFraction 0.9 → remaining > (1 - 0.35) = 0.65 → fast
			local m = EconomyMath.tipMultiplier(0.9, MOCK_CURVE, MOCK_CONFIG)
			expect(m).to.equal(MOCK_CURVE.fast)
		end)

		it("returns slow multiplier when patience nearly gone", function()
			-- patienceFraction 0.1 → remaining < (1 - 0.75) = 0.25 → slow
			local m = EconomyMath.tipMultiplier(0.1, MOCK_CURVE, MOCK_CONFIG)
			expect(m).to.equal(MOCK_CURVE.slow)
		end)

		it("returns ok multiplier in the middle band", function()
			local m = EconomyMath.tipMultiplier(0.5, MOCK_CURVE, MOCK_CONFIG)
			expect(m).to.equal(MOCK_CURVE.ok)
		end)
	end)

	describe("comboMultiplier", function()
		it("returns 1.0 for streak 0", function()
			expect(EconomyMath.comboMultiplier(0, MOCK_CONFIG)).to.equal(1.0)
		end)

		it("returns 1.0 for streak 1", function()
			expect(EconomyMath.comboMultiplier(1, MOCK_CONFIG)).to.equal(1.0)
		end)

		it("returns 1.1 for streak 2", function()
			expect(EconomyMath.comboMultiplier(2, MOCK_CONFIG)).to.equal(1.1)
		end)

		it("returns 1.25 for streak 4", function()
			expect(EconomyMath.comboMultiplier(4, MOCK_CONFIG)).to.equal(1.25)
		end)

		it("returns 1.5 (cap) for streak 7+", function()
			expect(EconomyMath.comboMultiplier(7,  MOCK_CONFIG)).to.equal(1.5)
			expect(EconomyMath.comboMultiplier(20, MOCK_CONFIG)).to.equal(1.5)
		end)
	end)

	describe("serveValue", function()
		it("floors the result", function()
			-- basePrice 10, fast patience (fraction 0.9), no combo (streak 0)
			local v = EconomyMath.serveValue(10, 0.9, MOCK_CURVE, 0, MOCK_CONFIG)
			expect(v).to.equal(math.floor(10 * 1.5 * 1.0))  -- 15
		end)

		it("applies combo multiplier", function()
			local v = EconomyMath.serveValue(10, 0.9, MOCK_CURVE, 7, MOCK_CONFIG)
			expect(v).to.equal(math.floor(10 * 1.5 * 1.5))  -- 22
		end)
	end)

	describe("starsFor", function()
		local goals = { oneStar = 100, twoStar = 200, threeStar = 300 }

		it("returns 0 below 1-star threshold", function()
			expect(EconomyMath.starsFor(50, goals)).to.equal(0)
		end)

		it("returns 1 at 1-star threshold", function()
			expect(EconomyMath.starsFor(100, goals)).to.equal(1)
		end)

		it("returns 2 at 2-star threshold", function()
			expect(EconomyMath.starsFor(200, goals)).to.equal(2)
		end)

		it("returns 3 at 3-star threshold", function()
			expect(EconomyMath.starsFor(300, goals)).to.equal(3)
		end)

		it("returns 3 above 3-star threshold", function()
			expect(EconomyMath.starsFor(9999, goals)).to.equal(3)
		end)
	end)

	describe("levelReward", function()
		it("grants gems only on first 3-star clear", function()
			local r = EconomyMath.levelReward(3, 300, true, 0, MOCK_CONFIG)
			expect(r.gems).to.equal(MOCK_CONFIG.GEM_FIRST_THREE_STAR)
		end)

		it("no gems on repeat 3-star", function()
			local r = EconomyMath.levelReward(3, 300, false, 3, MOCK_CONFIG)
			expect(r.gems).to.equal(0)
		end)

		it("grants XP proportional to stars", function()
			local r = EconomyMath.levelReward(2, 200, true, 0, MOCK_CONFIG)
			expect(r.xp).to.equal(2 * MOCK_CONFIG.XP_PER_STAR)
		end)

		it("awards 0 coins when stars did not improve", function()
			local r = EconomyMath.levelReward(2, 200, false, 3, MOCK_CONFIG)
			expect(r.coins).to.equal(0)
		end)
	end)

	describe("canClaimDaily", function()
		local DAY = 86400

		it("is false immediately after a claim", function()
			expect(EconomyMath.canClaimDaily(1000, 1000, DAY)).to.equal(false)
		end)

		it("is false before the interval elapses", function()
			expect(EconomyMath.canClaimDaily(0, DAY - 1, DAY)).to.equal(false)
		end)

		it("is true exactly at the interval boundary", function()
			expect(EconomyMath.canClaimDaily(0, DAY, DAY)).to.equal(true)
		end)

		it("is true well past the interval", function()
			expect(EconomyMath.canClaimDaily(0, DAY * 3, DAY)).to.equal(true)
		end)

		it("is true on a fresh profile (lastClaim 0)", function()
			expect(EconomyMath.canClaimDaily(0, 9999999, DAY)).to.equal(true)
		end)
	end)
end
