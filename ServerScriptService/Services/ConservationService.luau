--!strict
-- ConservationService: melepas ikan di mana saja → Poin Konservasi (per rarity; ikan Protected = poin khusus).
-- Poin dibelanjakan di toko poin Kak Laut. Ikan terkunci tidak bisa dilepas (buka kunci dulu).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local Guard = require(Shared.Util.Guard)
local Formulas = require(Shared.Formulas)
local Fish = require(Shared.Config.Fish)
local Strings = require(Shared.Config.Strings)
local DataService = require(script.Parent.DataService)
local InventoryService = require(script.Parent.InventoryService)

type FishItem = Types.FishItem
type FishSpecies = Types.FishSpecies

local ConservationService = {}

ConservationService.Released = Signal.new() :: Signal.Signal<Player, FishItem, FishSpecies, number>
ConservationService.PointsChanged = Signal.new() :: Signal.Signal<Player, number>

function ConservationService.AddPoints(player: Player, amount: number, reason: string): boolean
	local data = DataService.GetData(player)
	local n = math.floor(amount)
	if data == nil or n <= 0 then
		return false
	end
	data.ConservationPoints += n
	data.Stats.TotalConservation += n
	DataService.Replicate(player, "ConservationPoints", "Stats")
	ConservationService.PointsChanged:Fire(player, data.ConservationPoints)
	return true
end

function ConservationService.TrySpendPoints(player: Player, amount: number, reason: string): boolean
	local data = DataService.GetData(player)
	local n = math.floor(amount)
	if data == nil or n < 0 or data.ConservationPoints < n then
		return false
	end
	data.ConservationPoints -= n
	DataService.Replicate(player, "ConservationPoints")
	ConservationService.PointsChanged:Fire(player, data.ConservationPoints)
	return true
end

-- Melepas ikan (validasi lengkap, tanpa yield). Mengembalikan (ok, pesan, poin).
function ConservationService.Release(player: Player, uids: { string }): (boolean, string, number)
	local data = DataService.GetData(player)
	if data == nil then
		return false, Strings.Loading, 0
	end
	local byUid: { [string]: FishItem } = {}
	for _, item in data.Fish do
		byUid[item.Uid] = item
	end
	local points = 0
	for _, uid in uids do
		local item = byUid[uid]
		if item == nil then
			return false, "Ikan tidak ditemukan di tas.", 0
		end
		if item.Locked then
			return false, "Ada ikan terkunci. Buka kuncinya dulu.", 0
		end
		local species = Fish.Get(item.SpeciesId)
		if species then
			points += Formulas.ConservationPoints(species)
		end
	end
	local removed = InventoryService.RemoveFish(player, uids)
	data.Stats.TotalReleased += #removed
	if points > 0 then
		data.ConservationPoints += points
		data.Stats.TotalConservation += points
	end
	DataService.Replicate(player, "ConservationPoints", "Stats")
	ConservationService.PointsChanged:Fire(player, data.ConservationPoints)
	for _, item in removed do
		local species = Fish.Get(item.SpeciesId)
		if species then
			ConservationService.Released:Fire(player, item, species, Formulas.ConservationPoints(species))
		end
	end
	return true, string.format(Strings.Released, #removed, points), points
end

function ConservationService.Start()
	Net.OnServerInvoke("ReleaseFish", function(player: Player, uids: unknown): any
		local list = Guard.StrList(uids, 150, 64)
		if list == nil then
			Guard.Reject(player, "ReleaseFish", "daftar uid tidak valid")
			return false, "Pilihan tidak valid.", 0
		end
		return ConservationService.Release(player, list)
	end)
end

return ConservationService
