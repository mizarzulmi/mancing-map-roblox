--!strict
-- DebugService: perintah chat untuk mempercepat uji. HANYA aktif bila RunService:IsStudio().
-- /koin <n>  /level <n>  /cuaca <Cerah|Berawan|Hujan|Badai>  /event <JamEmas|MusimIkan|BulanPurnama|None>
-- /waktu <jam 0-24>  /isitas [zona]  (isi tas dengan ikan acak dari zona, default Shore)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local Net = require(Shared.Net)
local Formulas = require(Shared.Formulas)
local Balance = require(Shared.Config.Balance)
local Fish = require(Shared.Config.Fish)
local Zones = require(Shared.Config.Zones)
local EconomyService = require(script.Parent.EconomyService)
local InventoryService = require(script.Parent.InventoryService)
local LevelService = require(script.Parent.LevelService)
local WorldService = require(script.Parent.WorldService)

local DebugService = {}

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
}

function DebugService.Init()
	if not RunService:IsStudio() then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "DebugCommands"
	for alias in handlers do
		local cmd = Instance.new("TextChatCommand")
		cmd.Name = "Debug_" .. string.sub(alias, 2)
		cmd.PrimaryAlias = alias
		cmd.Parent = folder
	end
	folder.Parent = TextChatService
end

function DebugService.Start()
	if not RunService:IsStudio() then
		return
	end
	local folder = TextChatService:FindFirstChild("DebugCommands")
	if folder == nil then
		return
	end
	for _, cmd in folder:GetChildren() do
		if cmd:IsA("TextChatCommand") then
			local handler = handlers[cmd.PrimaryAlias]
			cmd.Triggered:Connect(function(source: TextSource, text: string)
				local player = Players:GetPlayerByUserId(source.UserId)
				if player and handler then
					local ok, err = pcall(handler :: (Player, { string }) -> ...any, player, argsOf(text))
					if not ok then
						warn("[DebugService] " .. cmd.PrimaryAlias .. " gagal: " .. tostring(err))
					end
				end
			end)
		end
	end
	print("[DebugService] aktif (Studio): /koin /level /cuaca /event /waktu /isitas")
end

return DebugService
