--!strict
-- Represents a single pending order item within a customer's ticket.
-- Lightweight value object; OrderController drives state changes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Enums   = require(ReplicatedStorage.Shared.Modules.Enums)
local Recipes = require(ReplicatedStorage.Shared.Config.Recipes)

export type Order = {
	recipeId: string,
	state: string,

	markReady:  (self: Order) -> (),
	markServed: (self: Order) -> (),
	markFailed: (self: Order) -> (),
}

local Order = {}
Order.__index = Order

function Order.new(recipeId: string): Order
	assert(Recipes[recipeId], "Order.new: unknown recipe '" .. recipeId .. "'")
	return setmetatable({
		recipeId = recipeId,
		state    = Enums.OrderState.Waiting,
	}, Order) :: any
end

function Order:markReady()
	self.state = Enums.OrderState.Ready
end

function Order:markServed()
	self.state = Enums.OrderState.Served
end

function Order:markFailed()
	self.state = Enums.OrderState.Failed
end

return Order
