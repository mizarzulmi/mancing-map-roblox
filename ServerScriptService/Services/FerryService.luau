--!strict
-- FerryService: kapal Nahkoda Jaka ke Platform Laut Dalam (Lv 10, 150 koin) dan pulang gratis lewat Awak Kapal.
-- Layar client fade, server memindahkan karakter dengan PivotTo. Syarat level zona tetap dicek saat melempar.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local Guard = require(Shared.Util.Guard)
local Format = require(Shared.Util.Format)
local Balance = require(Shared.Config.Balance)
local NPCs = require(Shared.Config.NPCs)
local Strings = require(Shared.Config.Strings)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local NPCService = require(script.Parent.NPCService)
local WorldService = require(script.Parent.WorldService)
local FishingService = require(script.Parent.FishingService)

local FerryService = {}

FerryService.Traveled = Signal.new() :: Signal.Signal<Player, string>

local DESTINATIONS = { "DeepSea", "Shore" }
local traveling: { [Player]: boolean } = {}

local function travel(player: Player, destinationRaw: unknown): (boolean, string)
	local destination = Guard.OneOf(destinationRaw, DESTINATIONS)
	if destination == nil then
		Guard.Reject(player, "FerryTravel", "tujuan tidak valid")
		return false, "Tujuan tidak valid."
	end
	local data = DataService.GetData(player)
	if data == nil then
		return false, Strings.Loading
	end
	if traveling[player] then
		return false, Strings.FerryDeparting
	end
	local npc = NPCs.ByRole(if destination == "DeepSea" then "FerryOut" else "FerryBack")
	if npc == nil or not NPCService.IsNear(player, npc.Id, Balance.NpcInteractRange) then
		return false, string.format(Strings.TooFar, if npc then npc.Name else "kapal")
	end
	local arrival = WorldService.GetPoint("FerryArrival_" .. destination)
	if arrival == nil then
		return false, "Dermaga tujuan belum siap."
	end
	if destination == "DeepSea" then
		if data.Level < Balance.Ferry.Level then
			return false, string.format(Strings.LevelRequired, Balance.Ferry.Level)
		end
		if not EconomyService.TrySpend(player, Balance.Ferry.Price, "ferry:deepsea") then
			return false, Strings.NotEnoughCoins .. " (" .. Format.Coins(Balance.Ferry.Price) .. " koin)"
		end
	end
	traveling[player] = true
	FishingService.Cancel(player, Strings.FerryDeparting)
	Net.FireClient("FerryEvent", player, "Depart", { Destination = destination })
	local target = arrival :: CFrame
	task.delay(Balance.Ferry.FadeSeconds + Balance.Ferry.TravelSeconds * 0.5, function()
		local character = player.Character
		if player.Parent == Players and character then
			character:PivotTo(target + Vector3.new(0, 3.5, 0))
		end
		task.wait(Balance.Ferry.TravelSeconds * 0.5)
		traveling[player] = nil
		if player.Parent == Players then
			Net.FireClient("FerryEvent", player, "Arrive", { Destination = destination })
			FerryService.Traveled:Fire(player, destination)
		end
	end)
	return true, if destination == "DeepSea" then Strings.FerryArrivedDeep else Strings.FerryArrivedShore
end

function FerryService.Start()
	Net.OnServerInvoke("FerryTravel", function(player: Player, destination: unknown): any
		return travel(player, destination)
	end)
	Players.PlayerRemoving:Connect(function(player)
		traveling[player] = nil
	end)
end

return FerryService
