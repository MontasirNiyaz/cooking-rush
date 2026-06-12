--!strict
-- TestEZ spec for the pure EnvConfig DataStore-namespacing math (P0.4 / ISSUES #12).

return function()
	local EnvConfig = require(game.ReplicatedStorage.Shared.Modules.EnvConfig)

	local MAP = {
		[111] = "prod",
		[222] = "dev",
	}

	describe("resolveEnv", function()
		it("maps a listed prod place id to prod", function()
			expect(EnvConfig.resolveEnv(111, MAP)).to.equal("prod")
		end)

		it("maps a listed dev place id to dev", function()
			expect(EnvConfig.resolveEnv(222, MAP)).to.equal("dev")
		end)

		it("defaults an unlisted place id to dev (prod must be opted in)", function()
			expect(EnvConfig.resolveEnv(999, MAP)).to.equal("dev")
		end)

		it("defaults to dev with an empty map", function()
			expect(EnvConfig.resolveEnv(111, {})).to.equal("dev")
		end)
	end)

	describe("storeName", function()
		it("prefixes the base name with the dev environment", function()
			expect(EnvConfig.storeName("CookingRushV1", "dev")).to.equal("dev_CookingRushV1")
		end)

		it("prefixes the base name with the prod environment", function()
			expect(EnvConfig.storeName("CookingRushV1", "prod")).to.equal("prod_CookingRushV1")
		end)
	end)
end
