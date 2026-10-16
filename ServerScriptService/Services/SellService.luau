--!strict
-- SellService: menjual ikan ke Bu Rina. Mode: Selected (daftar Uid), AllUnlocked (semua kecuali terkunci),
-- Rarity (semua ikan rarity tertentu yang tidak terkunci). Ikan Protected tidak pernah dijual.
-- Harga dihitung server (termasuk event Musim Ikan); client hanya menampilkan estimasi untuk konfirmasi.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local Guard = require(Shared.Util.Guard)
local Format = require(Shared.Util.Format)
local Formulas = require(Shared.Formulas)
local Balance = require(Shared.Config.Balance)
local Fish = require(Shared.Config.Fish)
local NPCs = require(Shared.Config.NPCs)
local Strings = require(Shared.Config.Strings)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local InventoryService = require(script.Parent.InventoryService)
local NPCService = require(script.Parent.NPCService)
local WorldService = require(script.Parent.WorldService)

type FishItem = Types.FishItem

local SellService = {}

-- (player, coins, count, npcId)
SellService.Sold = Signal.new() :: Signal.Signal<Player, number, number, string>

local MODES = { "Selected", "AllUnlocked", "Rarity" }

local function sellable(item: FishItem): boolean
	local species = Fish.Get(item.SpeciesId)
	return species ~= nil and not item.Locked and not species.Protected
end

local function sell(player: Player, npcIdRaw: unknown, modeRaw: unknown, arg: unknown): (boolean, string, number)
	local npcId = Guard.Id(npcIdRaw, NPCs.ById)
	local mode = Guard.OneOf(modeRaw, MODES)
	if npcId == nil or mode == nil or NPCs.ById[npcId].Role ~= "Buyer" then
		Guard.Reject(player, "SellFish", "npc/mode tidak valid")
		return false, "Permintaan tidak valid.", 0
	end
	local data = DataService.GetData(player)
	if data == nil then
		return false, Strings.Loading, 0
	end
	local npc = NPCs.ById[npcId]
	if not NPCService.IsNear(player, npcId, Balance.NpcInteractRange) then
		return false, string.format(Strings.TooFar, npc.Name), 0
	end

	local chosen: { FishItem } = {}
	if mode == "Selected" then
		local uids = Guard.StrList(arg, 150, 64)
		if uids == nil then
			Guard.Reject(player, "SellFish", "daftar uid tidak valid")
			return false, "Pilihan tidak valid.", 0
		end
		local byUid: { [string]: FishItem } = {}
		for _, item in data.Fish do
			byUid[item.Uid] = item
		end
		for _, uid in uids do
			local item = byUid[uid]
			if item == nil then
				return false, "Ikan tidak ditemukan di tas.", 0
			end
			if not sellable(item) then
				return false, "Ikan terkunci atau dilindungi tidak bisa dijual.", 0
			end
			table.insert(chosen, item)
		end
	elseif mode == "AllUnlocked" then
		for _, item in data.Fish do
			if sellable(item) then
				table.insert(chosen, item)
			end
		end
	else
		local rarity = Guard.OneOf(arg, Balance.RarityOrder :: any)
		if rarity == nil then
			Guard.Reject(player, "SellFish", "rarity tidak valid")
			return false, "Rarity tidak valid.", 0
		end
		for _, item in data.Fish do
			local species = Fish.Get(item.SpeciesId)
			if species and species.Rarity == rarity and sellable(item) then
				table.insert(chosen, item)
			end
		end
	end
	if #chosen == 0 then
		return false, Strings.SellNothing, 0
	end

	local eventMul = Formulas.EventPriceMul(WorldService.GetEvent())
	local total = 0
	local uids: { string } = {}
	for _, item in chosen do
		local species = Fish.Get(item.SpeciesId) :: Types.FishSpecies
		total += Formulas.SellPrice(species, item.Weight, item.Mutation, eventMul)
		table.insert(uids, item.Uid)
	end
	local removed = InventoryService.RemoveFish(player, uids)
	if #removed ~= #uids then
		-- Tidak mungkin terjadi tanpa yield; bila terjadi, jangan beri koin untuk ikan yang tidak terhapus.
		total = 0
		for _, item in removed do
			local species = Fish.Get(item.SpeciesId) :: Types.FishSpecies
			total += Formulas.SellPrice(species, item.Weight, item.Mutation, eventMul)
		end
	end
	EconomyService.Add(player, total, "sell")
	data.Stats.TotalSold += #removed
	DataService.Replicate(player, "Stats")
	SellService.Sold:Fire(player, total, #removed, npcId)
	return true, string.format(Strings.Sold, #removed, Format.Coins(total)), total
end

function SellService.Start()
	Net.OnServerInvoke("SellFish", function(player: Player, npcId: unknown, mode: unknown, arg: unknown): any
		return sell(player, npcId, mode, arg)
	end)
end

return SellService
