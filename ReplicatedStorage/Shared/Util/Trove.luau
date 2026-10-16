--!strict
-- Trove: mengumpulkan sumber daya (Instance, koneksi, fungsi, objek ber-Destroy) lalu membersihkan semuanya sekaligus.

export type Trove = {
	Add: <T>(self: Trove, item: T) -> T,
	Connect: (self: Trove, signal: RBXScriptSignal, fn: (...any) -> ()) -> RBXScriptConnection,
	Clean: (self: Trove) -> (),
	Destroy: (self: Trove) -> (),
}

type TroveImpl = {
	_items: { any },
}

local Trove = {}
Trove.__index = Trove

local function cleanItem(item: any): ...any
	local kind = typeof(item)
	if kind == "Instance" then
		item:Destroy()
	elseif kind == "RBXScriptConnection" then
		item:Disconnect()
	elseif kind == "function" then
		item()
	elseif kind == "thread" then
		pcall(task.cancel, item)
	elseif kind == "table" then
		if type(item.Destroy) == "function" then
			item:Destroy()
		elseif type(item.Disconnect) == "function" then
			item:Disconnect()
		elseif type(item.Cancel) == "function" then
			item:Cancel()
		end
	end
end

function Trove.Add(self: TroveImpl, item: any): any
	table.insert(self._items, item)
	return item
end

function Trove.Connect(self: TroveImpl, signal: RBXScriptSignal, fn: (...any) -> ()): RBXScriptConnection
	local conn = signal:Connect(fn)
	table.insert(self._items, conn)
	return conn
end

function Trove.Clean(self: TroveImpl)
	local items = self._items
	self._items = {}
	for i = #items, 1, -1 do
		local ok, err = pcall(cleanItem, items[i])
		if not ok then
			warn("[Trove] gagal membersihkan item:", err)
		end
	end
end

function Trove.Destroy(self: TroveImpl)
	Trove.Clean(self)
end

local module = {}

function module.new(): Trove
	return (setmetatable({ _items = {} }, Trove) :: any) :: Trove
end

return module
