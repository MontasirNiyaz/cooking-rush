--!strict
-- Cleanup/lifecycle utility. Holds connections, instances, and callbacks for batch teardown.

export type Trove = {
	Add:     <T>(self: Trove, item: T, method: string?) -> T,
	Connect: (self: Trove, signal: any, fn: (...any) -> ()) -> any,
	Extend:  (self: Trove) -> Trove,
	Clean:   (self: Trove) -> (),
	Destroy: (self: Trove) -> (),
}

local Trove = {}
Trove.__index = Trove

function Trove.new(): Trove
	return setmetatable({ _items = {} }, Trove) :: any
end

function Trove:Add(item: any, method: string?): any
	table.insert(self._items, { item = item, method = method })
	return item
end

function Trove:Connect(signal: any, fn: (...any) -> ()): any
	return self:Add(signal:Connect(fn), "Disconnect")
end

function Trove:Extend(): Trove
	return self:Add(Trove.new(), "Destroy")
end

local function cleanupItem(entry: any)
	local item, method = entry.item, entry.method
	if method then
		item[method](item)
	elseif type(item) == "function" then
		item()
	elseif typeof(item) == "RBXScriptConnection" then
		item:Disconnect()
	elseif typeof(item) == "Instance" then
		item:Destroy()
	elseif type(item) == "table" then
		if item.Destroy then item:Destroy()
		elseif item.Disconnect then item:Disconnect() end
	end
end

function Trove:Clean()
	local items = self._items
	self._items = {}
	for i = #items, 1, -1 do cleanupItem(items[i]) end
end

function Trove:Destroy()
	self:Clean()
end

return Trove
