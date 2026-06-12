--!strict
-- Matches held items to customer orders and drives the serve flow.
-- Calls ComboController and LevelController.addCoins on a valid serve.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RecipeResolver = require(ReplicatedStorage.Shared.Modules.RecipeResolver)
local Recipes        = require(ReplicatedStorage.Shared.Config.Recipes)
local GameConfig     = require(ReplicatedStorage.Shared.Config.GameConfig)
local Mastery        = require(ReplicatedStorage.Shared.Config.Mastery)
local Prestige       = require(ReplicatedStorage.Shared.Config.Prestige)
local EconomyMath    = require(ReplicatedStorage.Shared.Modules.EconomyMath)
local Signal         = require(ReplicatedStorage.Shared.Packages.Signal)

local OrderController = {}
OrderController.__index = OrderController

OrderController.ServeSuccess = Signal.new()  -- fires(customerId, recipeId, coins)
OrderController.ServeFail    = Signal.new()  -- fires(customerId, heldItemId)

-- Attempt to serve a held item to a customer.
-- customer: Customer entity (has .orderIds, .tipCurve, .patienceFraction)
-- heldItemId: the ingredient id the player is carrying
-- Returns true on success.
-- Combined mastery + prestige + equipped-chef earnings multiplier for the active
-- restaurant/recipe. Reads the shared profile cache + ChefController aggregate; all
-- factors default to 1 when missing. The server independently recomputes this same
-- ceiling, so the client value here is purely for the live coin feel.
local function earningsMult(recipeId: string, restaurantId: string?): number
	local ProfileController = require(script.Parent.ProfileController)
	local profile = ProfileController:get()
	if not profile then return 1 end

	local masteryEntry = profile.mastery and profile.mastery[recipeId]
	local masteryMult  = EconomyMath.masteryMult(masteryEntry and masteryEntry.xp or 0, Mastery.resolve(recipeId))

	local prestigeLevel = restaurantId and profile.prestige and profile.prestige[restaurantId] or 0
	local prestigeMult  = EconomyMath.prestigeMultiplier(prestigeLevel, Prestige)

	local ChefController = require(script.Parent.ChefController)
	local chefTipMult    = ChefController:getPassives().tipMult

	return masteryMult * prestigeMult * chefTipMult
end

function OrderController:tryServe(customer: any, heldItemId: string): boolean
	local LevelController = require(script.Parent.LevelController)
	local ComboController = require(script.Parent.ComboController)

	for i, recipeId in ipairs(customer.pendingOrders) do
		if RecipeResolver.itemFulfillsOrder(heldItemId, recipeId) then
			-- Remove fulfilled order
			table.remove(customer.pendingOrders, i)

			local recipe    = Recipes[recipeId]
			local basePrice = recipe and recipe.basePrice or 5

			local restaurantId = LevelController.currentLevel and LevelController.currentLevel.restaurantId
			local coins = EconomyMath.serveValue(
				basePrice,
				customer:getPatienceFraction(),
				customer.tipCurve,
				ComboController.streak,
				GameConfig,
				earningsMult(recipeId, restaurantId)
			)

			ComboController:increment()
			LevelController:addCoins(coins)
			LevelController:recordServe(recipeId)
			OrderController.ServeSuccess:Fire(customer.id, recipeId, coins)
			return true
		end
	end

	-- Wrong item
	ComboController:reset()
	OrderController.ServeFail:Fire(customer.id, heldItemId)
	return false
end

function OrderController:init()
end

return OrderController
