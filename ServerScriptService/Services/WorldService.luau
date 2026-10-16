--!strict
-- WorldService: memastikan map tersedia (bangun otomatis bila Workspace.BeachMap belum ada, pemain ditahan
-- sampai siap), jam siang–malam (atribut acuan di ReplicatedStorage), cuaca, event acak, dan zona memancing.
-- Satu loop penjadwal global (1 dtk), bukan loop per objek.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local Formulas = require(Shared.Formulas)
local Balance = require(Shared.Config.Balance)
local WeightedRandom = require(Shared.Util.WeightedRandom)

type WeatherId = Types.WeatherId
type EventId = Types.EventId

local WorldService = {}

WorldService.MapReady = Signal.new() :: Signal.Signal<>
WorldService.WeatherChanged = Signal.new() :: Signal.Signal<WeatherId>
WorldService.EventChanged = Signal.new() :: Signal.Signal<EventId>

local rng = Random.new()
local mapReady = false
local needsBuild = false
local zones: { Formulas.ZoneBox } = {}
local nextEventAt = 0

local function now(): number
	return workspace:GetServerTimeNow()
end

local function attr(name: string): any
	return ReplicatedStorage:GetAttribute(name)
end

function WorldService.GetClockTime(): number
	local refTime = attr("DayRefTime")
	local refClock = attr("DayRefClock")
	local length = attr("DayLength")
	if type(refTime) ~= "number" or type(refClock) ~= "number" or type(length) ~= "number" then
		return Balance.StartClockTime
	end
	return Formulas.ClockTime(now(), refTime, refClock, length)
end

function WorldService.IsNight(): boolean
	return Formulas.IsNight(WorldService.GetClockTime())
end

function WorldService.SetClockTime(clockTime: number)
	ReplicatedStorage:SetAttribute("DayRefTime", now())
	ReplicatedStorage:SetAttribute("DayRefClock", clockTime % 24)
end

function WorldService.GetWeather(): WeatherId
	local w = attr("Weather")
	if type(w) == "string" and Balance.WeatherChance[w] ~= nil then
		return w :: WeatherId
	end
	return "Cerah"
end

function WorldService.GetEvent(): EventId
	local e = attr("Event")
	if type(e) == "string" and Balance.EventLabel[e] ~= nil then
		return e :: EventId
	end
	return "None"
end

function WorldService.SetWeather(weather: WeatherId, duration: number?)
	local d = duration or rng:NextNumber(Balance.WeatherDurationMin, Balance.WeatherDurationMax)
	ReplicatedStorage:SetAttribute("Weather", weather)
	ReplicatedStorage:SetAttribute("WeatherEndsAt", now() + d)
	WorldService.WeatherChanged:Fire(weather)
end

-- Sisa detik malam ini (0 bila sedang siang).
local function nightSecondsLeft(): number
	local clock = WorldService.GetClockTime()
	if not Formulas.IsNight(clock) then
		return 0
	end
	local hoursLeft = if clock >= Balance.NightStart then (24 - clock) + Balance.NightEnd else Balance.NightEnd - clock
	return hoursLeft / 24 * Balance.DayLengthSeconds
end

function WorldService.StartEvent(event: EventId, duration: number?)
	if event == "None" then
		ReplicatedStorage:SetAttribute("Event", "None")
		ReplicatedStorage:SetAttribute("EventEndsAt", 0)
		WorldService.EventChanged:Fire("None")
		return
	end
	local d = duration or Balance.EventDuration[event] or 600
	if Balance.EventNightOnly[event] then
		d = math.min(d, math.max(nightSecondsLeft(), 30))
	end
	ReplicatedStorage:SetAttribute("Event", event)
	ReplicatedStorage:SetAttribute("EventEndsAt", now() + d)
	WorldService.EventChanged:Fire(event)
	local label = Balance.EventLabel[event] or event
	local desc = Balance.EventDescription[event] or ""
	Net.FireAllClients("Notify", "Event", string.format("Event %s dimulai! %s", label, desc))
end

local function rollWeather(): WeatherId
	local key = WeightedRandom.PickKey(Balance.WeatherChance, Balance.WeatherOrder :: any, rng)
	return (key or "Cerah") :: WeatherId
end

local function rollEvent(): EventId?
	local weights: { [string]: number } = {}
	local night = WorldService.IsNight()
	for _, e in Balance.EventOrder do
		if not Balance.EventNightOnly[e] or night then
			weights[e] = Balance.EventWeight[e] or 0
		end
	end
	local key = WeightedRandom.PickKey(weights, Balance.EventOrder :: any, rng)
	return key :: EventId?
end

local function scheduleNextEvent()
	nextEventAt = now() + rng:NextNumber(Balance.EventIntervalMin, Balance.EventIntervalMax)
end

local function tick()
	local t = now()
	local weatherEnds = attr("WeatherEndsAt")
	if type(weatherEnds) ~= "number" or t >= weatherEnds then
		WorldService.SetWeather(rollWeather())
	end
	local event = WorldService.GetEvent()
	local eventEnds = attr("EventEndsAt")
	if event ~= "None" then
		local endedByTime = type(eventEnds) == "number" and t >= eventEnds
		local endedByDay = Balance.EventNightOnly[event] == true and not WorldService.IsNight()
		if endedByTime or endedByDay then
			WorldService.StartEvent("None")
			scheduleNextEvent()
		end
	elseif t >= nextEventAt then
		local picked = rollEvent()
		if picked then
			WorldService.StartEvent(picked)
		end
		scheduleNextEvent()
	end
end

local function collectZones()
	table.clear(zones)
	local map = workspace:FindFirstChild("BeachMap")
	local folder = map and map:FindFirstChild("FishingZones")
	if folder == nil then
		warn("[WorldService] folder BeachMap.FishingZones tidak ditemukan")
		return
	end
	for _, part in folder:GetChildren() do
		if part:IsA("BasePart") then
			local id = part:GetAttribute("ZoneId")
			if type(id) == "string" then
				table.insert(zones, { Id = id, CFrame = part.CFrame, Size = part.Size })
			end
		end
	end
end

function WorldService.GetZoneAt(position: Vector3): string?
	return Formulas.PickZone(position, zones)
end

function WorldService.GetPoint(name: string): CFrame?
	local map = workspace:FindFirstChild("BeachMap")
	local points = map and map:FindFirstChild("Points")
	local p = points and points:FindFirstChild(name)
	if p and p:IsA("BasePart") then
		return p.CFrame
	end
	return nil
end

function WorldService.IsMapReady(): boolean
	return mapReady
end

-- Menunggu map siap (boleh yield; hanya dari task).
function WorldService.WaitForMap(timeout: number?): boolean
	local deadline = os.clock() + (timeout or 120)
	while not mapReady and os.clock() < deadline do
		task.wait(0.25)
	end
	return mapReady
end

local function loadWaitingCharacters()
	Players.CharacterAutoLoads = true
	for _, player in Players:GetPlayers() do
		if player.Character == nil then
			task.spawn(function()
				player:LoadCharacter()
			end)
		end
	end
end

local function ensureMap()
	if needsBuild then
		local worldFolder = ServerScriptService:FindFirstChild("World")
		local builderModule = worldFolder and worldFolder:FindFirstChild("MapBuilder")
		if builderModule and builderModule:IsA("ModuleScript") then
			local ok, err = pcall(function()
				local MapBuilder = require(builderModule) :: any
				MapBuilder.EnsureBuilt()
			end)
			if not ok then
				warn("[WorldService] gagal membangun map: " .. tostring(err))
			end
		else
			warn("[WorldService] ServerScriptService.World.MapBuilder tidak ditemukan")
		end
		loadWaitingCharacters()
	end
	collectZones()
	mapReady = true
	WorldService.MapReady:Fire()
end

function WorldService.Init()
	needsBuild = workspace:FindFirstChild("BeachMap") == nil
	if needsBuild then
		-- Pemain tidak boleh jatuh sebelum map siap.
		Players.CharacterAutoLoads = false
	end
	ReplicatedStorage:SetAttribute("DayRefTime", now())
	ReplicatedStorage:SetAttribute("DayRefClock", Balance.StartClockTime)
	ReplicatedStorage:SetAttribute("DayLength", Balance.DayLengthSeconds)
	ReplicatedStorage:SetAttribute("Weather", "Cerah")
	ReplicatedStorage:SetAttribute("WeatherEndsAt", now() + rng:NextNumber(Balance.WeatherDurationMin, Balance.WeatherDurationMax))
	ReplicatedStorage:SetAttribute("Event", "None")
	ReplicatedStorage:SetAttribute("EventEndsAt", 0)
	scheduleNextEvent()
end

function WorldService.Start()
	task.spawn(ensureMap)
	task.spawn(function()
		while true do
			task.wait(1)
			local ok, err = pcall(tick :: () -> ...any)
			if not ok then
				warn("[WorldService] penjadwal gagal: " .. tostring(err))
			end
		end
	end)
end

return WorldService
