--!strict
-- FishdexService: mencatat setiap spesies (jumlah, berat terbaik, waktu pertama) dan hadiah lengkap per zona
-- yang diambil di Prof. Mina (koin + gelar). Ikan Protected tetap tercatat.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local Guard = require(Shared.Util.Guard)
local Format = require(Shared.Util.Format)
local Balance = require(Shared.Config.Balance)
local Fish = require(Shared.Config.Fish)
local Zones = require(Shared.Config.Zones)
local NPCs = require(Shared.Config.NPCs)
local Strings = require(Shared.Config.Strings)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local InventoryService = require(script.Parent.InventoryService)
local NPCService = require(script.Parent.NPCService)
local FishingService = require(script.Parent.FishingService)

local FishdexService = {}

FishdexService.Discovered = Signal.new() :: Signal.Signal<Player, string>
FishdexService.ZoneCompleted = Signal.new() :: Signal.Signal<Player, string>

function FishdexService.DiscoveredCount(player: Player): number
	local data = DataService.GetData(player)
	if data == nil then
		return 0
	end
	local n = 0
	for _ in data.Fishdex do
		n += 1
	end
	return n
end

function FishdexService.ZoneComplete(player: Player, zoneId: string): boolean
	local data = DataService.GetData(player)
	if data == nil then
		return false
	end
	local list = Fish.InZone(zoneId)
	if #list == 0 then
		return false
	end
	for _, species in list do
		if data.Fishdex[species.Id] == nil then
			return false
		end
	end
	return true
end

-- Mencatat satu ikan ke Fishdex. Spesies baru memicu Discovered (quest/achievement) dan pemberitahuan zona
-- lengkap. Dipakai tangkapan (FishCaught) dan perintah debug /semua.
function FishdexService.Record(player: Player, species: Types.FishSpecies, weight: number)
	local data = DataService.GetData(player)
	if data == nil then
		return
	end
	local entry = data.Fishdex[species.Id]
	local isNew = entry == nil
	if entry == nil then
		entry = { Count = 0, BestWeight = 0, FirstAt = os.time() }
		data.Fishdex[species.Id] = entry
	end
	local e = entry :: Types.FishdexEntry
	e.Count += 1
	if weight > e.BestWeight then
		e.BestWeight = weight
	end
	DataService.Replicate(player, "Fishdex")
	if isNew then
		FishdexService.Discovered:Fire(player, species.Id)
		for _, zoneId in species.Zones do
			if FishdexService.ZoneComplete(player, zoneId) then
				local zone = Zones.Get(zoneId)
				FishdexService.ZoneCompleted:Fire(player, zoneId)
				if zone and not data.FishdexClaimed[zoneId] then
					Net.FireClient(
						"Notify",
						player,
						"Achievement",
						string.format(Strings.FishdexZoneDone, zone.Name) .. " Ambil hadiah di Prof. Mina."
					)
				end
			end
		end
	end
end

local function claim(player: Player, zoneIdRaw: unknown): (boolean, string)
	local zoneId = Guard.Id(zoneIdRaw, Zones.ById)
	if zoneId == nil then
		Guard.Reject(player, "ClaimFishdex", "zona tidak valid")
		return false, "Zona tidak valid."
	end
	local data = DataService.GetData(player)
	if data == nil then
		return false, Strings.Loading
	end
	local npc = NPCs.ByRole("Fishdex")
	if npc and not NPCService.IsNear(player, npc.Id, Balance.NpcInteractRange) then
		return false, string.format(Strings.TooFar, npc.Name)
	end
	if data.FishdexClaimed[zoneId] then
		return false, Strings.FishdexClaimed
	end
	if not FishdexService.ZoneComplete(player, zoneId) then
		return false, "Fishdex zona ini belum lengkap."
	end
	local zone = Zones.ById[zoneId]
	data.FishdexClaimed[zoneId] = true
	DataService.Replicate(player, "FishdexClaimed")
	EconomyService.Add(player, zone.FishdexReward, "fishdex:" .. zoneId)
	InventoryService.GiveCosmetic(player, zone.FishdexTitle)
	return true, string.format("Hadiah Fishdex %s: +%s koin", zone.Name, Format.Coins(zone.FishdexReward))
end

function FishdexService.Start()
	FishingService.FishCaught:Connect(function(player, item, species)
		FishdexService.Record(player, species, item.Weight)
	end)
	Net.OnServerInvoke("ClaimFishdex", function(player: Player, zoneId: unknown): any
		return claim(player, zoneId)
	end)
end

return FishdexService
