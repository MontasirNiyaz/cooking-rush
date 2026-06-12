--!strict
-- TestEZ spec for the pure TokenBucket rate-limit math (P0.2 / ISSUES #10).

return function()
	local TokenBucket = require(game.ReplicatedStorage.Shared.Modules.TokenBucket)

	describe("new", function()
		it("starts full", function()
			local s = TokenBucket.new(5)
			expect(s.tokens).to.equal(5)
		end)
	end)

	describe("available", function()
		it("refills over time, capped at capacity", function()
			local s = { tokens = 0, lastTime = 0 }
			-- 3s at 1 token/s = 3 tokens
			expect(TokenBucket.available(s, 3, 5, 1)).to.equal(3)
			-- 100s would overflow → capped at 5
			expect(TokenBucket.available(s, 100, 5, 1)).to.equal(5)
		end)

		it("never goes backwards if now < lastTime", function()
			local s = { tokens = 2, lastTime = 10 }
			expect(TokenBucket.available(s, 5, 5, 1)).to.equal(2)
		end)
	end)

	describe("consume", function()
		it("allows while tokens remain and charges one", function()
			local allowed, s = TokenBucket.consume(TokenBucket.new(3), 0, 3, 1, 1)
			expect(allowed).to.equal(true)
			expect(s.tokens).to.equal(2)
		end)

		it("denies once the bucket is empty (burst exhausted at one instant)", function()
			-- Spend all 3 tokens at the same timestamp (no refill between calls).
			local s = TokenBucket.new(3)
			local a1; a1, s = TokenBucket.consume(s, 0, 3, 1, 1)
			local a2; a2, s = TokenBucket.consume(s, 0, 3, 1, 1)
			local a3; a3, s = TokenBucket.consume(s, 0, 3, 1, 1)
			local a4; a4, s = TokenBucket.consume(s, 0, 3, 1, 1)
			expect(a1).to.equal(true)
			expect(a2).to.equal(true)
			expect(a3).to.equal(true)
			expect(a4).to.equal(false)  -- 4th call in the same instant is dropped
		end)

		it("recovers after enough time passes to refill a token", function()
			local s = TokenBucket.new(1)
			local a1; a1, s = TokenBucket.consume(s, 0, 1, 1, 1)  -- spends the only token
			local a2; a2, s = TokenBucket.consume(s, 0, 1, 1, 1)  -- empty → deny
			local a3; a3, s = TokenBucket.consume(s, 1, 1, 1, 1)  -- +1s refills 1 → allow
			expect(a1).to.equal(true)
			expect(a2).to.equal(false)
			expect(a3).to.equal(true)
		end)

		it("does not charge on denial", function()
			local s = { tokens = 0, lastTime = 0 }
			local allowed, ns = TokenBucket.consume(s, 0, 5, 1, 1)
			expect(allowed).to.equal(false)
			expect(ns.tokens).to.equal(0)
		end)
	end)
end
