--!strict
-- WeatherFXController: efek visual & suara cuaca di client dari atribut ReplicatedStorage.Weather.
-- Cerah / Berawan / Hujan / Badai: transisi awan, atmosfer, ombak, kecerahan (4 dtk); hujan partikel yang
-- mengikuti kamera; Badai menambah kilat + guntur. Mode grafis rendah mematikan partikel (pencahayaan tetap).

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local SettingsController = require(script.Parent.SettingsController)
local SoundController = require(script.Parent.SoundController)

local WeatherFXController = {}

type Profile = {
	Cover: number,
	Density: number,
	AtmoDensity: number,
	Haze: number,
	Brightness: number,
	WaveSize: number,
	WaveSpeed: number,
	Rain: number,
	Lightning: boolean,
	Tint: Color3,
}

local PROFILES: { [string]: Profile } = {
	Cerah = { Cover = 0.5, Density = 0.6, AtmoDensity = 0.3, Haze = 1.5, Brightness = 2.6, WaveSize = 0.12, WaveSpeed = 8, Rain = 0, Lightning = false, Tint = Color3.fromRGB(255, 248, 238) },
	Berawan = { Cover = 0.8, Density = 0.75, AtmoDensity = 0.36, Haze = 2.2, Brightness = 2.0, WaveSize = 0.16, WaveSpeed = 9, Rain = 0, Lightning = false, Tint = Color3.fromRGB(240, 242, 245) },
	Hujan = { Cover = 0.92, Density = 0.85, AtmoDensity = 0.42, Haze = 3, Brightness = 1.55, WaveSize = 0.26, WaveSpeed = 12, Rain = 1, Lightning = false, Tint = Color3.fromRGB(222, 230, 238) },
	Badai = { Cover = 1, Density = 0.95, AtmoDensity = 0.5, Haze = 4, Brightness = 1.1, WaveSize = 0.45, WaveSpeed = 16, Rain = 2, Lightning = true, Tint = Color3.fromRGB(200, 208, 222) },
}

local current = "Cerah"
local rainPart: Part? = nil
local rainEmitter: ParticleEmitter? = nil
local flashTimer = 0
local rng = Random.new()

local function tween(inst: Instance?, props: { [string]: any })
	if inst == nil then
		return
	end
	TweenService:Create(inst, TweenInfo.new(4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), props):Play()
end

local function colorCorrection(): ColorCorrectionEffect?
	return Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
end

local function ensureRain(): ParticleEmitter
	local e = rainEmitter
	if e then
		return e
	end
	local p = Instance.new("Part")
	p.Name = "PMN_Hujan"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(140, 1, 140)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(200, 218, 235))
	emitter.LightInfluence = 1
	emitter.Size = NumberSequence.new(0.12)
	emitter.Squash = NumberSequence.new(2.5)
	emitter.Transparency = NumberSequence.new(0.35)
	emitter.Lifetime = NumberRange.new(0.7, 0.9)
	emitter.Speed = NumberRange.new(70, 85)
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	emitter.Rate = 0
	emitter.Parent = p
	p.Parent = workspace
	rainPart = p
	rainEmitter = emitter
	return emitter
end

local function apply(weather: string)
	local profile = PROFILES[weather] or PROFILES.Cerah
	current = weather
	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
	tween(clouds, { Cover = profile.Cover, Density = profile.Density })
	tween(Lighting:FindFirstChildOfClass("Atmosphere"), { Density = profile.AtmoDensity, Haze = profile.Haze })
	tween(Lighting, { Brightness = profile.Brightness })
	tween(workspace.Terrain, { WaterWaveSize = profile.WaveSize, WaterWaveSpeed = profile.WaveSpeed })
	tween(colorCorrection(), { TintColor = profile.Tint })
	local lowGfx = SettingsController.LowGfx()
	local emitter = ensureRain()
	emitter.Rate = if lowGfx then 0 else (if profile.Rain >= 2 then 900 elseif profile.Rain >= 1 then 380 else 0)
	SoundController.SetLoop("Rain", profile.Rain > 0)
	flashTimer = rng:NextNumber(4, 9)
end

local function lightning()
	local cc = colorCorrection()
	if cc then
		local base = cc.Brightness
		cc.Brightness = base + 0.35
		TweenService:Create(cc, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = base }):Play()
	end
	task.delay(rng:NextNumber(0.5, 1.6), function()
		SoundController.Play("Thunder", 0.08)
	end)
end

function WeatherFXController.Current(): string
	return current
end

function WeatherFXController.Start()
	local initial = ReplicatedStorage:GetAttribute("Weather")
	-- Map dibangun server; tunggu sebentar agar Clouds/Atmosphere sudah tereplikasi.
	task.delay(2, function()
		apply(if type(initial) == "string" then initial else "Cerah")
	end)
	ReplicatedStorage:GetAttributeChangedSignal("Weather"):Connect(function()
		local w = ReplicatedStorage:GetAttribute("Weather")
		if type(w) == "string" then
			apply(w)
		end
	end)
	SettingsController.Changed:Connect(function()
		apply(current)
	end)
	RunService.Heartbeat:Connect(function(dt)
		local p = rainPart
		local camera = workspace.CurrentCamera
		if p and camera and rainEmitter and rainEmitter.Rate > 0 then
			p.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, 45, 0))
		end
		local profile = PROFILES[current]
		if profile and profile.Lightning then
			flashTimer -= dt
			if flashTimer <= 0 then
				flashTimer = rng:NextNumber(6, 14)
				lightning()
			end
		end
	end)
end

return WeatherFXController
