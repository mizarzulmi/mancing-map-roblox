--!strict
-- DebugService: perintah chat untuk mempercepat uji. HANYA aktif bila RunService:IsStudio().
-- /koin <n>  /level <n>  /cuaca <Cerah|Berawan|Hujan|Badai>  /event <JamEmas|MusimIkan|BulanPurnama|None>
-- /waktu <jam 0-24>  /isitas [zona]  (isi tas dengan ikan acak dari zona, default Shore)
-- /semua [paksa]  (buka semua untuk uji: level maks, koin, poin, tas terbesar, semua joran/umpan/kosmetik & gelar,
--                  Fishdex lengkap, satu ikan tiap spesies di tas; di luar mode uji wajib "paksa")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local Net = require(Shared.Net)
local Formulas = require(Shared.Formulas)
local Format = require(Shared.Util.Format)
local Balance = require(Shared.Config.Balance)
local Fish = require(Shared.Config.Fish)
local Zones = require(Shared.Config.Zones)
local Rods = require(Shared.Config.Rods)
local Bait = require(Shared.Config.Bait)
local Bags = require(Shared.Config.Bags)
local Cosmetics = require(Shared.Config.Cosmetics)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local InventoryService = require(script.Parent.InventoryService)
local LevelService = require(script.Parent.LevelService)
local ConservationService = require(script.Parent.ConservationService)
local FishdexService = require(script.Parent.FishdexService)
local WorldService = require(script.Parent.WorldService)

local DebugService = {}

-- Jumlah pemberian /semua (alat uji Studio, bukan angka gameplay).
local UNLOCK_COINS = 1000000
local UNLOCK_POINTS = 5000

local rng = Random.new()

local function reply(player: Player, text: string)
	Net.FireClient("Notify", player, "Info", "[Debug] " .. text)
end

local function argsOf(text: string): { string }
	local out: { string } = {}
	for word in string.gmatch(text, "%S+") do
		table.insert(out, word)
	end
	table.remove(out, 1)
	return out
end

local handlers: { [string]: (Player, { string }) -> () } = {
	["/koin"] = function(player, args)
		local n = math.floor(tonumber(args[1] or "") or 1000)
		if n > 0 then
			EconomyService.Add(player, n, "debug")
			reply(player, "+" .. tostring(n) .. " koin")
		end
	end,
	["/level"] = function(player, args)
		local n = math.floor(tonumber(args[1] or "") or 10)
		LevelService.SetLevel(player, n)
		reply(player, "Level diatur ke " .. tostring(math.clamp(n, 1, Balance.MaxLevel)))
	end,
	["/cuaca"] = function(player, args)
		local w = args[1] or "Cerah"
		if Balance.WeatherChance[w] == nil then
			reply(player, "Cuaca tidak dikenal. Pilih: Cerah, Berawan, Hujan, Badai")
			return
		end
		WorldService.SetWeather(w :: Types.WeatherId)
		reply(player, "Cuaca: " .. w)
	end,
	["/event"] = function(player, args)
		local e = args[1] or "JamEmas"
		if Balance.EventLabel[e] == nil then
			reply(player, "Event tidak dikenal. Pilih: JamEmas, MusimIkan, BulanPurnama, None")
			return
		end
		WorldService.StartEvent(e :: Types.EventId)
		reply(player, "Event: " .. e)
	end,
	["/waktu"] = function(player, args)
		local h = tonumber(args[1] or "")
		if h == nil or h < 0 or h > 24 then
			reply(player, "Pakai /waktu <jam 0–24>, mis. /waktu 20")
			return
		end
		WorldService.SetClockTime(h)
		reply(player, "Jam diatur ke " .. tostring(h))
	end,
	["/isitas"] = function(player, args)
		local zoneId = args[1] or "Shore"
		if Zones.Get(zoneId) == nil then
			reply(player, "Zona tidak dikenal: Shore, Pier, Mangrove, DeepSea")
			return
		end
		local ctx: Types.RollContext = {
			Zone = zoneId,
			IsNight = WorldService.IsNight(),
			Weather = WorldService.GetWeather(),
			Event = WorldService.GetEvent(),
			Luck = 0.5,
			MutationMul = 1,
		}
		local added = 0
		while not InventoryService.IsBagFull(player) do
			local roll = Formulas.RollFish(rng, Fish.List, ctx)
			if roll == nil then
				break
			end
			local ok = InventoryService.AddFish(player, {
				Uid = InventoryService.NewUid(),
				SpeciesId = roll.Species.Id,
				Weight = roll.Weight,
				Mutation = roll.Mutation,
				Zone = zoneId,
				CaughtAt = os.time(),
				Locked = false,
			})
			if not ok then
				break
			end
			added += 1
		end
		reply(player, "Tas diisi " .. tostring(added) .. " ikan dari " .. zoneId)
	end,
	["/semua"] = function(player, args)
		-- Mode uji: data tidak disimpan. Di place yang memakai DataStore asli, perubahan ini permanen.
		if not DataService.IsMock() and args[1] ~= "paksa" then
			reply(player, "Data asli (bukan mode uji) akan berubah permanen. Ketik /semua paksa untuk tetap lanjut.")
			return
		end
		LevelService.SetLevel(player, Balance.MaxLevel)
		EconomyService.Add(player, UNLOCK_COINS, "debug:semua")
		ConservationService.AddPoints(player, UNLOCK_POINTS, "debug:semua")
		InventoryService.SetBagCapacity(player, Bags.Tiers[#Bags.Tiers].Capacity)
		for _, rod in Rods.List do
			InventoryService.GiveRod(player, rod.Id)
		end
		for _, bait in Bait.List do
			InventoryService.AddBait(player, bait.Id, Balance.BaitMaxStack)
		end
		for _, cosmetic in Cosmetics.List do
			InventoryService.GiveCosmetic(player, cosmetic.Id)
		end
		-- Fishdex lewat jalur tangkapan biasa agar quest, achievement, dan hadiah zona Prof. Mina ikut teruji.
		local added = 0
		for _, species in Fish.List do
			local weight = Formulas.RollWeight(rng, species)
			FishdexService.Record(player, species, weight)
			if not InventoryService.IsBagFull(player) then
				local ok = InventoryService.AddFish(player, {
					Uid = InventoryService.NewUid(),
					SpeciesId = species.Id,
					Weight = weight,
					Mutation = "None",
					Zone = species.Zones[1],
					CaughtAt = os.time(),
					Locked = false,
				})
				if ok then
					added += 1
				end
			end
		end
		reply(
			player,
			string.format(
				"Semua terbuka: Level %d, +%s koin, +%s poin, tas %d, semua joran/umpan/kosmetik, Fishdex %d/%d, %d ikan di tas.",
				Balance.MaxLevel,
				Format.Coins(UNLOCK_COINS),
				Format.Int(UNLOCK_POINTS),
				Bags.Tiers[#Bags.Tiers].Capacity,
				FishdexService.DiscoveredCount(player),
				#Fish.List,
				added
			)
		)
		reply(player, "Ganti joran: toko Pak Darto → Pakai. Hadiah Fishdex: Prof. Mina. Kosmetik & gelar: tombol C.")
	end,
}

local lastRun: { [string]: number } = {}

local function run(player: Player, alias: string, text: string)
	local handler = handlers[alias]
	if handler == nil then
		return
	end
	-- Penahan dobel: jalur TextChatCommand dan Chatted tidak boleh menjalankan perintah yang sama dua kali.
	local key = tostring(player.UserId) .. alias
	local now = os.clock()
	local last: number? = lastRun[key]
	if last and now - last < 1 then
		return
	end
	lastRun[key] = now
	print(string.format("[DebugService] %s oleh %s", alias, player.Name))
	local ok, err = pcall(handler :: (Player, { string }) -> ...any, player, argsOf(text))
	if not ok then
		warn("[DebugService] " .. alias .. " gagal: " .. tostring(err))
	end
end

function DebugService.Start()
	if not RunService:IsStudio() then
		return
	end
	-- Perintah di dalam folder buatan sendiri tidak pernah terpicu (Studio 2026-10-16). Taruh di folder bawaan
	-- TextChatCommands (tempat /help dkk.); bila tidak ada (CreateDefaultCommands = false), di TextChatService.
	task.spawn(function()
		local parent: Instance = TextChatService:WaitForChild("TextChatCommands", 10) or TextChatService
		for alias in handlers do
			local cmd = Instance.new("TextChatCommand")
			cmd.Name = "Debug_" .. string.sub(alias, 2)
			cmd.PrimaryAlias = alias
			cmd.Triggered:Connect(function(source: TextSource, text: string)
				local player = Players:GetPlayerByUserId(source.UserId)
				if player then
					run(player, alias, text)
				end
			end)
			cmd.Parent = parent
		end
	end)
	-- Cadangan: bila chat tidak mengenali perintah, pesan terkirim sebagai chat biasa dan Chatted menangkapnya.
	local function watch(player: Player)
		player.Chatted:Connect(function(message: string)
			local alias = string.lower(string.match(message, "^%S+") or "")
			if handlers[alias] then
				run(player, alias, message)
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	print("[DebugService] aktif (Studio): /koin /level /cuaca /event /waktu /isitas /semua")
end

return DebugService
