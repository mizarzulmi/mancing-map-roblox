--!strict
-- LevelService: XP & level (kurva GDD 4.2), hadiah naik level 25 × L koin, maksimum Lv 50.
-- Level membuka joran dan zona (dicek oleh Shop/Fishing/Barter). Mengirim LevelUp ke client untuk perayaan.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local Formulas = require(Shared.Formulas)
local Balance = require(Shared.Config.Balance)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

local LevelService = {}

LevelService.LevelChanged = Signal.new() :: Signal.Signal<Player, number, number>

function LevelService.GetLevel(player: Player): number
	local data = DataService.GetData(player)
	return if data then data.Level else 1
end

-- Menambah XP. Setiap level yang tercapai memberi koin dan memicu LevelChanged sekali (level akhir).
function LevelService.AddXP(player: Player, amount: number, reason: string)
	local data = DataService.GetData(player)
	local gain = math.floor(amount)
	if data == nil or gain <= 0 then
		return
	end
	local oldLevel = data.Level
	local newLevel, newXP, reached = Formulas.ApplyXP(data.Level, data.XP, gain)
	data.Level = newLevel
	data.XP = newXP
	DataService.Replicate(player, "Level", "XP")
	if #reached > 0 then
		local totalCoins = 0
		for _, lvl in reached do
			local reward = Formulas.LevelUpReward(lvl)
			totalCoins += reward
			EconomyService.Add(player, reward, "levelup:" .. tostring(lvl))
		end
		DataService.SetLeaderstat(player, "Level", newLevel)
		Net.FireClient("LevelUp", player, newLevel, totalCoins)
		LevelService.LevelChanged:Fire(player, newLevel, oldLevel)
	end
end

-- Perintah debug: atur level langsung (XP direset).
function LevelService.SetLevel(player: Player, level: number)
	local data = DataService.GetData(player)
	if data == nil then
		return
	end
	local old = data.Level
	data.Level = math.clamp(math.floor(level), 1, Balance.MaxLevel)
	data.XP = 0
	DataService.Replicate(player, "Level", "XP")
	DataService.SetLeaderstat(player, "Level", data.Level)
	if data.Level ~= old then
		LevelService.LevelChanged:Fire(player, data.Level, old)
	end
end

return LevelService
