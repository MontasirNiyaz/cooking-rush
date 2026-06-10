--!strict
-- Represents what the player is currently carrying.
-- Simple value object: one item at a time (extend to a stack if design requires).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Ingredients = require(ReplicatedStorage.Shared.Config.Ingredients)

export type ItemStack = {
	itemId: string?,
	has:   (self: ItemStack) -> boolean,
	set:   (self: ItemStack, itemId: string) -> (),
	take:  (self: ItemStack) -> string?,
	clear: (self: ItemStack) -> (),
}

local ItemStack = {}
ItemStack.__index = ItemStack

function ItemStack.new(): ItemStack
	return setmetatable({ itemId = nil }, ItemStack) :: any
end

function ItemStack:has(): boolean
	return self.itemId ~= nil
end

function ItemStack:set(itemId: string)
	assert(Ingredients[itemId], "ItemStack.set: unknown ingredient '" .. itemId .. "'")
	self.itemId = itemId
end

function ItemStack:take(): string?
	local id    = self.itemId
	self.itemId = nil
	return id
end

function ItemStack:clear()
	self.itemId = nil
end

return ItemStack
