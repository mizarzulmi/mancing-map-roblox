--!strict
-- InventoryService: tas ikan, umpan, joran, kosmetik, dan kapasitas tas. Semua mutasi sinkron (tanpa yield)
-- dan langsung direplikasi ke client pemilik.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local Guard = require(Shared.Util.Guard)
local Balance = require(Shared.Config.Balance)
local Bait = require(Shared.Config.Bait)
local DataService = require(script.Parent.DataService)

type FishItem = Types.FishItem

local InventoryService = {}

InventoryService.CosmeticGranted = Signal.new() :: Signal.Signal<Player, string>

function InventoryService.NewUid(): string
	return HttpService:GenerateGUID(false)
end

function InventoryService.FishCount(player: Player): number
	local data = DataService.GetData(player)
	return if data then #data.Fish else 0
end

function InventoryService.IsBagFull(player: Player): boolean
	local data = DataService.GetData(player)
	return data == nil or #data.Fish >= data.BagCapacity
end

function InventoryService.FindFish(player: Player, uid: string): (FishItem?, number?)
	local data = DataService.GetData(player)
	if data == nil then
		return nil, nil
	end
	for i, item in data.Fish do
		if item.Uid == uid then
			return item, i
		end
	end
	return nil, nil
end

function InventoryService.AddFish(player: Player, item: FishItem): boolean
	local data = DataService.GetData(player)
	if data == nil or #data.Fish >= data.BagCapacity then
		return false
	end
	table.insert(data.Fish, item)
	DataService.FishAdded(player, item)
	return true
end

-- Menghapus ikan berdasarkan Uid. Mengembalikan item yang benar-benar dihapus.
function InventoryService.RemoveFish(player: Player, uids: { string }): { FishItem }
	local data = DataService.GetData(player)
	local removed: { FishItem } = {}
	if data == nil then
		return removed
	end
	local wanted: { [string]: boolean } = {}
	for _, uid in uids do
		wanted[uid] = true
	end
	for i = #data.Fish, 1, -1 do
		local item = data.Fish[i]
		if wanted[item.Uid] then
			table.remove(data.Fish, i)
			table.insert(removed, item)
			wanted[item.Uid] = nil
		end
	end
	local removedUids: { string } = {}
	for _, item in removed do
		table.insert(removedUids, item.Uid)
	end
	DataService.FishRemoved(player, removedUids)
	return removed
end

function InventoryService.SetLock(player: Player, uid: string, locked: boolean): boolean
	local item = InventoryService.FindFish(player, uid)
	if item == nil then
		return false
	end
	item.Locked = locked
	DataService.FishUpdated(player, item)
	return true
end

function InventoryService.GetBait(player: Player, baitId: string): number
	local data = DataService.GetData(player)
	return if data then (data.Bait[baitId] or 0) else 0
end

function InventoryService.AddBait(player: Player, baitId: string, qty: number): boolean
	local data = DataService.GetData(player)
	local n = math.floor(qty)
	if data == nil or n <= 0 or Bait.Get(baitId) == nil then
		return false
	end
	data.Bait[baitId] = math.min(Balance.BaitMaxStack, (data.Bait[baitId] or 0) + n)
	DataService.Replicate(player, "Bait")
	return true
end

-- Mengurangi umpan; bila habis dan sedang dipakai, slot umpan dikosongkan dengan pemberitahuan.
function InventoryService.ConsumeBait(player: Player, baitId: string, qty: number): boolean
	local data = DataService.GetData(player)
	local n = math.floor(qty)
	if data == nil or n <= 0 then
		return false
	end
	local have = data.Bait[baitId] or 0
	if have < n then
		return false
	end
	local left = have - n
	if left > 0 then
		data.Bait[baitId] = left
	else
		(data.Bait :: any)[baitId] = nil
	end
	if left <= 0 and data.EquippedBait == baitId then
		data.EquippedBait = ""
		local def = Bait.Get(baitId)
		Net.FireClient("Notify", player, "Info", (if def then def.Name else "Umpan") .. " habis.")
		DataService.Replicate(player, "Bait", "EquippedBait")
	else
		DataService.Replicate(player, "Bait")
	end
	return true
end

function InventoryService.HasRod(player: Player, rodId: string): boolean
	local data = DataService.GetData(player)
	return data ~= nil and table.find(data.Rods, rodId) ~= nil
end

function InventoryService.GiveRod(player: Player, rodId: string): boolean
	local data = DataService.GetData(player)
	if data == nil then
		return false
	end
	if not table.find(data.Rods, rodId) then
		table.insert(data.Rods, rodId)
		DataService.Replicate(player, "Rods")
	end
	return true
end

function InventoryService.HasCosmetic(player: Player, cosmeticId: string): boolean
	local data = DataService.GetData(player)
	return data ~= nil and data.Cosmetics.Owned[cosmeticId] == true
end

function InventoryService.GiveCosmetic(player: Player, cosmeticId: string): boolean
	local data = DataService.GetData(player)
	if data == nil then
		return false
	end
	if not data.Cosmetics.Owned[cosmeticId] then
		data.Cosmetics.Owned[cosmeticId] = true
		DataService.Replicate(player, "Cosmetics")
		InventoryService.CosmeticGranted:Fire(player, cosmeticId)
	end
	return true
end

function InventoryService.SetBagCapacity(player: Player, capacity: number)
	local data = DataService.GetData(player)
	if data == nil then
		return
	end
	data.BagCapacity = math.max(data.BagCapacity, math.floor(capacity))
	DataService.Replicate(player, "BagCapacity")
end

function InventoryService.Start()
	Net.OnServerInvoke("SetFishLock", function(player: Player, uid: unknown, locked: unknown): any
		local u = Guard.Str(uid, 64)
		local l = Guard.Bool(locked)
		if u == nil or l == nil then
			Guard.Reject(player, "SetFishLock", "argumen tidak valid")
			return false
		end
		if not InventoryService.SetLock(player, u, l) then
			Guard.Reject(player, "SetFishLock", "ikan tidak ditemukan")
			return false
		end
		return true
	end)
end

return InventoryService
