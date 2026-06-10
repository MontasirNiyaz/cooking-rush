--!strict
-- Matches held items to customer orders and drives the serve flow.
-- Calls ComboController and LevelController.addCoins on a valid serve.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RecipeResolver = require(ReplicatedStorage.Shared.Modules.RecipeResolver)
local Recipes        = require(ReplicatedStorage.Shared.Config.Recipes)
local GameConfig     = require(ReplicatedStorage.Shared.Config.GameConfig)
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
function OrderController:tryServe(customer: any, heldItemId: string): boolean
	local LevelController = require(script.Parent.LevelController)
	local ComboController = require(script.Parent.ComboController)

	for i, recipeId in ipairs(customer.pendingOrders) do
		if RecipeResolver.itemFulfillsOrder(heldItemId, recipeId) then
			-- Remove fulfilled order
			table.remove(customer.pendingOrders, i)

			local recipe    = Recipes[recipeId]
			local basePrice = recipe and recipe.basePrice or 5

			local coins = EconomyMath.serveValue(
				basePrice,
				customer:getPatienceFraction(),
				customer.tipCurve,
				ComboController.streak,
				GameConfig
			)

			ComboController:increment()
			LevelController:addCoins(coins)
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
