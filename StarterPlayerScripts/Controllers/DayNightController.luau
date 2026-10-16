--!strict
-- DayNightController: tiap client menghitung ClockTime sendiri dari atribut acuan server
-- (DayRefTime, DayRefClock, DayLength) + workspace:GetServerTimeNow(). Menyalakan lampu bertag NightLight
-- dan emitter/lampu kosmetik beratribut NightOnly saat malam (ClockTime ≥ 18,5 atau < 5,5).

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Signal = require(Shared.Util.Signal)
local Formulas = require(Shared.Formulas)
local Balance = require(Shared.Config.Balance)

local DayNightController = {}

DayNightController.NightChanged = Signal.new() :: Signal.Signal<boolean>

local clock = Balance.StartClockTime
local night = false
local accumulator = 0
local nightOnlyTimer = 0

local function readClock(): number
	local refTime = ReplicatedStorage:GetAttribute("DayRefTime")
	local refClock = ReplicatedStorage:GetAttribute("DayRefClock")
	local length = ReplicatedStorage:GetAttribute("DayLength")
	if type(refTime) ~= "number" or type(refClock) ~= "number" or type(length) ~= "number" then
		return clock
	end
	return Formulas.ClockTime(workspace:GetServerTimeNow(), refTime, refClock, length)
end

local function setLight(inst: Instance, on: boolean)
	if inst:IsA("Light") or inst:IsA("ParticleEmitter") or inst:IsA("Beam") or inst:IsA("Fire") then
		(inst :: any).Enabled = on
	end
	for _, d in inst:GetDescendants() do
		if d:IsA("Light") or d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Fire") then
			(d :: any).Enabled = on
		end
	end
end

local function applyNightLights()
	for _, inst in CollectionService:GetTagged("NightLight") do
		setLight(inst, night)
	end
end

-- Kosmetik NightOnly (mis. aura kunang-kunang) berada di karakter pemain.
local function applyNightOnly()
	for _, p in Players:GetPlayers() do
		local character = p.Character
		if character then
			for _, d in character:GetDescendants() do
				if d:GetAttribute("NightOnly") == true and (d:IsA("Light") or d:IsA("ParticleEmitter")) then
					(d :: any).Enabled = night
				end
			end
		end
	end
end

function DayNightController.Clock(): number
	return clock
end

function DayNightController.IsNight(): boolean
	return night
end

function DayNightController.Start()
	clock = readClock()
	night = Formulas.IsNight(clock)
	Lighting.ClockTime = clock
	applyNightLights()
	CollectionService:GetInstanceAddedSignal("NightLight"):Connect(function(inst)
		setLight(inst, night)
	end)
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		nightOnlyTimer += dt
		if accumulator < 0.1 then
			return
		end
		accumulator = 0
		clock = readClock()
		Lighting.ClockTime = clock
		local isNight = Formulas.IsNight(clock)
		if isNight ~= night then
			night = isNight
			applyNightLights()
			applyNightOnly()
			DayNightController.NightChanged:Fire(night)
		end
		if nightOnlyTimer >= 3 then
			nightOnlyTimer = 0
			applyNightOnly()
		end
	end)
end

return DayNightController
