--!strict
-- Signal ringan untuk komunikasi antar-service/controller.
-- Setiap handler dijalankan lewat task.spawn: berjalan segera (urutan sambungan), dan error di satu
-- handler tidak menghentikan handler lain maupun pemanggil Fire.

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	Wait: (self: Signal<T...>) -> T...,
	DisconnectAll: (self: Signal<T...>) -> (),
}

type Handler = {
	fn: (...any) -> (),
	once: boolean,
	conn: Connection,
}

type SignalImpl = {
	_handlers: { Handler },
}

local Signal = {}
Signal.__index = Signal

local ConnectionImpl = {}
ConnectionImpl.__index = ConnectionImpl

function ConnectionImpl.Disconnect(self: any)
	if not self.Connected then
		return
	end
	self.Connected = false
	local owner = self._owner :: SignalImpl
	for i, h in owner._handlers do
		if h.conn == self then
			table.remove(owner._handlers, i)
			break
		end
	end
end

local function connect(self: SignalImpl, fn: (...any) -> (), once: boolean): Connection
	local conn = setmetatable({ Connected = true, _owner = self }, ConnectionImpl) :: any
	table.insert(self._handlers, { fn = fn, once = once, conn = conn })
	return conn :: Connection
end

function Signal.Connect(self: SignalImpl, fn: (...any) -> ()): Connection
	return connect(self, fn, false)
end

function Signal.Once(self: SignalImpl, fn: (...any) -> ()): Connection
	return connect(self, fn, true)
end

function Signal.Fire(self: SignalImpl, ...: any)
	-- Salin daftar agar Disconnect di dalam handler aman.
	local list = table.clone(self._handlers)
	for _, h in list do
		if h.conn.Connected then
			if h.once then
				h.conn:Disconnect()
			end
			task.spawn(h.fn, ...)
		end
	end
end

function Signal.Wait(self: SignalImpl): ...any
	local thread = coroutine.running()
	connect(self, function(...)
		task.spawn(thread, ...)
	end, true)
	return coroutine.yield()
end

function Signal.DisconnectAll(self: SignalImpl)
	for _, h in table.clone(self._handlers) do
		h.conn:Disconnect()
	end
end

local module = {}

function module.new<T...>(): Signal<T...>
	local self = setmetatable({ _handlers = {} }, Signal)
	return (self :: any) :: Signal<T...>
end

return module
