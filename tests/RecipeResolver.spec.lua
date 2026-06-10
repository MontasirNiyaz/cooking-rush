--!strict
-- TestEZ spec for RecipeResolver.

return function()
	local RecipeResolver = require(game.ReplicatedStorage.Shared.Modules.RecipeResolver)

	local MOCK_RECIPES = {
		cheeseburger = {
			id = "cheeseburger",
			steps = {
				{ kind = "cook",    station = "grill",       item = "cooked_patty" },
				{ kind = "assemble", base = "bun", add = { "cooked_patty", "cheese_slice" } },
			},
		},
		cola = {
			id = "cola",
			steps = {
				{ kind = "dispense", station = "drink_dispenser", item = "cola" },
			},
		},
		fries = {
			id = "fries",
			steps = {
				{ kind = "cook", station = "fryer", item = "fries" },
			},
		},
	}

	local MOCK_GRILL = { id = "grill", archetype = "Cooker", input = "raw_patty", output = "cooked_patty" }

	describe("itemFulfillsOrder", function()
		it("returns true when heldItemId matches recipeId", function()
			expect(RecipeResolver.itemFulfillsOrder("cheeseburger", "cheeseburger")).to.equal(true)
		end)

		it("returns false when they differ", function()
			expect(RecipeResolver.itemFulfillsOrder("fries", "cheeseburger")).to.equal(false)
		end)
	end)

	describe("getRequiredItems", function()
		it("includes cook output", function()
			local items = RecipeResolver.getRequiredItems(MOCK_RECIPES.cheeseburger)
			local found = false
			for _, v in ipairs(items) do if v == "cooked_patty" then found = true end end
			expect(found).to.equal(true)
		end)

		it("includes assemble base and add items", function()
			local items = RecipeResolver.getRequiredItems(MOCK_RECIPES.cheeseburger)
			local set: { [string]: boolean } = {}
			for _, v in ipairs(items) do set[v] = true end
			expect(set["bun"]).to.equal(true)
			expect(set["cheese_slice"]).to.equal(true)
		end)

		it("includes dispense item for cola", function()
			local items = RecipeResolver.getRequiredItems(MOCK_RECIPES.cola)
			expect(items[1]).to.equal("cola")
		end)
	end)

	describe("assemblerMatchesRecipe", function()
		it("matches when base and add items are correct", function()
			local ok = RecipeResolver.assemblerMatchesRecipe(
				MOCK_RECIPES.cheeseburger,
				"bun",
				{ "cooked_patty", "cheese_slice" }
			)
			expect(ok).to.equal(true)
		end)

		it("matches add items regardless of order", function()
			local ok = RecipeResolver.assemblerMatchesRecipe(
				MOCK_RECIPES.cheeseburger,
				"bun",
				{ "cheese_slice", "cooked_patty" }
			)
			expect(ok).to.equal(true)
		end)

		it("fails when base is wrong", function()
			local ok = RecipeResolver.assemblerMatchesRecipe(
				MOCK_RECIPES.cheeseburger,
				"lettuce",
				{ "cooked_patty", "cheese_slice" }
			)
			expect(ok).to.equal(false)
		end)

		it("fails when a topping is missing", function()
			local ok = RecipeResolver.assemblerMatchesRecipe(
				MOCK_RECIPES.cheeseburger,
				"bun",
				{ "cooked_patty" }  -- missing cheese_slice
			)
			expect(ok).to.equal(false)
		end)

		it("returns false for a recipe with no assemble step", function()
			local ok = RecipeResolver.assemblerMatchesRecipe(MOCK_RECIPES.cola, "bun", {})
			expect(ok).to.equal(false)
		end)
	end)

	describe("findAssemblerRecipe", function()
		it("returns recipeId when contents match", function()
			local id = RecipeResolver.findAssemblerRecipe(
				"bun",
				{ "cooked_patty", "cheese_slice" },
				MOCK_RECIPES
			)
			expect(id).to.equal("cheeseburger")
		end)

		it("returns nil for incomplete assembly", function()
			local id = RecipeResolver.findAssemblerRecipe("bun", { "cooked_patty" }, MOCK_RECIPES)
			expect(id).to.equal(nil)
		end)
	end)

	describe("cookerOutput", function()
		it("returns output when input matches", function()
			local out = RecipeResolver.cookerOutput(MOCK_GRILL, "raw_patty")
			expect(out).to.equal("cooked_patty")
		end)

		it("returns nil when input does not match", function()
			local out = RecipeResolver.cookerOutput(MOCK_GRILL, "raw_fries")
			expect(out).to.equal(nil)
		end)
	end)
end
