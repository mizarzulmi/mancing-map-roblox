--!strict
-- EconomyService: SATU-SATUNYA pintu perubahan koin. Koin tidak pernah negatif dan setiap mutasi
-- tercatat beserta alasannya (Profile.CoinLog, 30 entri terakhir).
-- Alasan berawalan "trade:" adalah perpindahan antar pemain, bukan pendapatan (tidak menambah TotalEarned).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Signal = require(Shared.Util.Signal)
local Balance = require(Shared.Config.Balance)
local DataService = require(script.Parent.DataService)

local EconomyService = {}

EconomyService.CoinsChanged = Signal.new() :: Signal.Signal<Player, number, number, string>
EconomyService.Earned = Signal.new() :: Signal.Signal<Player, number, string>

local function isTransfer(reason: string): boolean
	return string.sub(reason, 1, 6) == "trade:"
end

local function log(player: Player, delta: number, reason: string)
	local data = DataService.GetData(player)
	if data == nil then
		return
	end
	table.insert(data.CoinLog, { T = os.time(), D = delta, R = string.sub(reason, 1, 40) })
	while #data.CoinLog > Balance.CoinLogSize do
		table.remove(data.CoinLog, 1)
	end
end

function EconomyService.Get(player: Player): number
	local data = DataService.GetData(player)
	return if data then data.Coins else 0
end

-- Menambah koin (amount bulat > 0). Mengembalikan false bila profil belum siap atau jumlah tidak valid.
function EconomyService.Add(player: Player, amount: number, reason: string): boolean
	local data = DataService.GetData(player)
	local n = math.floor(amount)
	if data == nil or n <= 0 or n ~= n then
		return false
	end
	data.Coins += n
	local transfer = isTransfer(reason)
	if not transfer then
		data.Stats.TotalEarned += n
	end
	log(player, n, reason)
	DataService.Replicate(player, "Coins", "Stats")
	DataService.SetLeaderstat(player, "Koin", data.Coins)
	EconomyService.CoinsChanged:Fire(player, data.Coins, n, reason)
	if not transfer then
		EconomyService.Earned:Fire(player, n, reason)
	end
	return true
end

-- Mengurangi koin bila cukup. amount 0 selalu berhasil tanpa mutasi.
function EconomyService.TrySpend(player: Player, amount: number, reason: string): boolean
	local data = DataService.GetData(player)
	local n = math.floor(amount)
	if data == nil or n < 0 or n ~= n then
		return false
	end
	if n == 0 then
		return true
	end
	if data.Coins < n then
		return false
	end
	data.Coins -= n
	log(player, -n, reason)
	DataService.Replicate(player, "Coins")
	DataService.SetLeaderstat(player, "Koin", data.Coins)
	EconomyService.CoinsChanged:Fire(player, data.Coins, -n, reason)
	return true
end

-- Mengembalikan koin (mis. kapal gagal berangkat). Tidak dihitung sebagai pendapatan (TotalEarned).
function EconomyService.Refund(player: Player, amount: number, reason: string): boolean
	local data = DataService.GetData(player)
	local n = math.floor(amount)
	if data == nil or n <= 0 or n ~= n then
		return false
	end
	data.Coins += n
	log(player, n, "refund:" .. reason)
	DataService.Replicate(player, "Coins")
	DataService.SetLeaderstat(player, "Koin", data.Coins)
	EconomyService.CoinsChanged:Fire(player, data.Coins, n, "refund:" .. reason)
	return true
end

function EconomyService.CanAfford(player: Player, amount: number): boolean
	local data = DataService.GetData(player)
	return data ~= nil and data.Coins >= math.floor(amount)
end

return EconomyService
