--!strict
-- DataController: salinan data pemain di client (hanya untuk tampilan). Snapshot awal via GetInitialData,
-- lalu delta DataChanged. Delta yang tiba sebelum snapshot di-buffer lalu diputar ulang (idempoten).
-- Data otoritatif tetap di server; client tidak pernah mengubah data ini selain dari delta server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Net = require(Shared:WaitForChild("Net"))
local Signal = require(Shared.Util.Signal)

type ProfileData = Types.ProfileData
type FishItem = Types.FishItem

local DataController = {}

-- Kunci tingkat atas yang berubah ("Coins", "Fish", "Quests", ...).
DataController.Changed = Signal.new() :: Signal.Signal<string>
DataController.FishAdded = Signal.new() :: Signal.Signal<FishItem>
DataController.Ready = Signal.new() :: Signal.Signal<>

local data: ProfileData? = nil
local isMock = false
local serverOffset = 0
local pending: { { op: string, payload: any } } = {}

local function applyDelta(op: string, payload: any)
	local d = data
	if d == nil then
		table.insert(pending, { op = op, payload = payload })
		return
	end
	if op == "Set" and typeof(payload) == "table" then
		for key, value in payload do
			(d :: any)[key] = value
			DataController.Changed:Fire(key)
		end
	elseif op == "FishAdd" and typeof(payload) == "table" then
		local item = payload :: FishItem
		for _, existing in d.Fish do
			if existing.Uid == item.Uid then
				return
			end
		end
		table.insert(d.Fish, item)
		DataController.FishAdded:Fire(item)
		DataController.Changed:Fire("Fish")
	elseif op == "FishRemove" and typeof(payload) == "table" then
		local remove: { [string]: boolean } = {}
		for _, uid in payload do
			remove[uid] = true
		end
		for i = #d.Fish, 1, -1 do
			if remove[d.Fish[i].Uid] then
				table.remove(d.Fish, i)
			end
		end
		DataController.Changed:Fire("Fish")
	elseif op == "FishUpdate" and typeof(payload) == "table" then
		local item = payload :: FishItem
		for i, existing in d.Fish do
			if existing.Uid == item.Uid then
				d.Fish[i] = item
				break
			end
		end
		DataController.Changed:Fire("Fish")
	end
end

function DataController.Get(): ProfileData?
	return data
end

function DataController.IsReady(): boolean
	return data ~= nil
end

function DataController.IsMock(): boolean
	return isMock
end

-- Menunggu data siap (hanya dari task; boleh yield).
function DataController.WaitReady(): ProfileData
	while data == nil do
		DataController.Ready:Wait()
	end
	return data :: ProfileData
end

-- Memanggil fn sekarang (bila siap) dan setiap kali salah satu kunci berubah.
function DataController.Observe(keys: { string }, fn: (ProfileData) -> ()): Signal.Connection
	local watch: { [string]: boolean } = {}
	for _, k in keys do
		watch[k] = true
	end
	if data then
		task.spawn(fn, data)
	else
		DataController.Ready:Once(function()
			if data then
				fn(data)
			end
		end)
	end
	return DataController.Changed:Connect(function(key)
		if watch[key] and data then
			fn(data)
		end
	end)
end

function DataController.FindFish(uid: string): FishItem?
	local d = data
	if d == nil then
		return nil
	end
	for _, item in d.Fish do
		if item.Uid == uid then
			return item
		end
	end
	return nil
end

-- Selisih jam server (GetServerTimeNow) terhadap os.time client saat snapshot (untuk tampilan tanggal).
function DataController.ServerOffset(): number
	return serverOffset
end

function DataController.Start()
	Net.OnClientEvent("DataChanged", applyDelta)
	task.spawn(function()
		local delay = 1
		while data == nil do
			local snapshot = Net.Invoke("GetInitialData")
			if typeof(snapshot) == "table" and typeof((snapshot :: any).Data) == "table" then
				local snap = snapshot :: Types.Snapshot
				data = snap.Data
				isMock = snap.IsMock
				serverOffset = snap.ServerNow - os.time()
				local queued = pending
				pending = {}
				for _, entry in queued do
					applyDelta(entry.op, entry.payload)
				end
				DataController.Ready:Fire()
				for key in snap.Data :: any do
					DataController.Changed:Fire(key)
				end
			else
				task.wait(delay)
				delay = math.min(delay * 1.5, 3)
			end
		end
	end)
end

return DataController
