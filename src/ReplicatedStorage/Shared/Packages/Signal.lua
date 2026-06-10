--!strict
-- Minimal typed signal. No external dependencies.

local Connection = {}
Connection.__index = Connection

function Connection.new(signal: any, fn: (...any) -> ()): any
	return setmetatable({ _connected = true, _fn = fn, _signal = signal }, Connection)
end

function Connection:Disconnect()
	if not self._connected then return end
	self._connected = false
	local list = self._signal._listeners
	for i, c in ipairs(list) do
		if c == self then table.remove(list, i) break end
	end
end

export type Signal<T...> = typeof(setmetatable({} :: {
	_listeners: { any },
	Connect: (self: any, fn: (T...) -> ()) -> any,
	Once:    (self: any, fn: (T...) -> ()) -> any,
	Fire:    (self: any, T...) -> (),
	Wait:    (self: any) -> T...,
	Destroy: (self: any) -> (),
}, {} :: { __index: any }))

local Signal = {}
Signal.__index = Signal

function Signal.new<T...>(): Signal<T...>
	return setmetatable({ _listeners = {} }, Signal) :: any
end

function Signal:Connect(fn: (...any) -> ()): any
	local conn = Connection.new(self, fn)
	table.insert(self._listeners, conn)
	return conn
end

function Signal:Once(fn: (...any) -> ()): any
	local conn: any
	conn = self:Connect(function(...)
		conn:Disconnect()
		fn(...)
	end)
	return conn
end

function Signal:Fire(...: any)
	-- iterate copy so Disconnect inside a handler is safe
	for _, conn in ipairs(table.clone(self._listeners)) do
		if conn._connected then conn._fn(...) end
	end
end

function Signal:Wait(): ...any
	local thread = coroutine.running()
	self:Once(function(...) task.spawn(thread, ...) end)
	return coroutine.yield()
end

function Signal:Destroy()
	table.clear(self._listeners)
end

return Signal
