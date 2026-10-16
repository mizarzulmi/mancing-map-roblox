--!strict
-- AchievementService: memeriksa pencapaian (GDD 4.6) dan memberi gelar. Dipicu Signal tangkapan, pendapatan,
-- konservasi, dan Fishdex; juga diperiksa saat profil dimuat.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local Net = require(Shared.Net)
local Achievements = require(Shared.Config.Achievements)
local Cosmetics = require(Shared.Config.Cosmetics)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local InventoryService = require(script.Parent.InventoryService)
local ConservationService = require(script.Parent.ConservationService)
local FishingService = require(script.Parent.FishingService)
local FishdexService = require(script.Parent.FishdexService)

type AchievementDef = Types.AchievementDef

local AchievementService = {}

local function unlock(player: Player, def: AchievementDef)
	local data = DataService.GetData(player)
	if data == nil or data.Achievements[def.Id] then
		return
	end
	data.Achievements[def.Id] = os.time()
	DataService.Replicate(player, "Achievements")
	InventoryService.GiveCosmetic(player, def.Title)
	local title = Cosmetics.Get(def.Title)
	Net.FireClient(
		"Notify",
		player,
		"Achievement",
		string.format("Achievement: %s · gelar \"%s\" terbuka", def.Name, if title then title.Name else def.Title)
	)
end

-- Memeriksa achievement berbasis statistik (tidak termasuk yang dipicu tangkapan tertentu).
local function checkStats(player: Player)
	local data = DataService.GetData(player)
	if data == nil then
		return
	end
	for _, def in Achievements.List do
		if not data.Achievements[def.Id] then
			local ok = false
			if def.Stat == "TotalCaught" then
				ok = data.Stats.TotalCaught >= def.Count
			elseif def.Stat == "TotalEarned" then
				ok = data.Stats.TotalEarned >= def.Count
			elseif def.Stat == "TotalConservation" then
				ok = data.Stats.TotalConservation >= def.Count
			elseif def.Stat == "FishdexZone" and def.Arg then
				ok = FishdexService.ZoneComplete(player, def.Arg)
			elseif def.Stat == "CaughtSpecies" and def.Arg then
				ok = data.Fishdex[def.Arg] ~= nil
			end
			if ok then
				unlock(player, def)
			end
		end
	end
end

function AchievementService.Start()
	FishingService.FishCaught:Connect(function(player, item, species)
		for _, def in Achievements.List do
			if def.Stat == "CaughtMutation" and def.Arg == item.Mutation then
				unlock(player, def)
			elseif def.Stat == "CaughtSpecies" and def.Arg == species.Id then
				unlock(player, def)
			end
		end
		checkStats(player)
	end)
	EconomyService.Earned:Connect(function(player)
		checkStats(player)
	end)
	ConservationService.PointsChanged:Connect(function(player)
		checkStats(player)
	end)
	FishdexService.ZoneCompleted:Connect(function(player)
		checkStats(player)
	end)
	DataService.ProfileLoaded:Connect(function(player)
		checkStats(player)
	end)
end

return AchievementService
