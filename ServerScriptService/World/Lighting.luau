--!strict
-- Cahaya & suasana pantai: siang hangat ClockTime 14, atmosfer berkabut tipis, bloom halus,
-- sun rays tipis, color correction sedikit hangat. Efek dibuat sekali lalu diperbarui (tidak diduplikasi).

local LightingService = game:GetService("Lighting")

local MapConfig = require(script.Parent.MapConfig)

local L = MapConfig.Lighting

local Lighting = {}

function Lighting.Apply()
	LightingService.ClockTime = L.ClockTime
	LightingService.GeographicLatitude = L.GeographicLatitude
	LightingService.Brightness = L.Brightness
	LightingService.Ambient = L.Ambient
	LightingService.OutdoorAmbient = L.OutdoorAmbient
	LightingService.EnvironmentDiffuseScale = L.EnvironmentDiffuseScale
	LightingService.EnvironmentSpecularScale = L.EnvironmentSpecularScale
	LightingService.ShadowSoftness = L.ShadowSoftness
	LightingService.ExposureCompensation = L.ExposureCompensation
	LightingService.GlobalShadows = true

	-- Gaya pencahayaan baru; dibungkus pcall karena tidak semua versi mengizinkan diubah skrip.
	local function setStyle(): ...any
		LightingService.LightingStyle = Enum.LightingStyle.Realistic
		return true
	end
	pcall(setStyle)

	local A = L.Atmosphere
	local found = LightingService:FindFirstChildOfClass("Atmosphere")
	local atmosphere = found or Instance.new("Atmosphere")
	atmosphere.Density = A.Density
	atmosphere.Offset = A.Offset
	atmosphere.Color = A.Color
	atmosphere.Decay = A.Decay
	atmosphere.Glare = A.Glare
	atmosphere.Haze = A.Haze
	if not found then
		atmosphere.Parent = LightingService
	end

	local B = L.Bloom
	local foundBloom = LightingService:FindFirstChildOfClass("BloomEffect")
	local bloom = foundBloom or Instance.new("BloomEffect")
	bloom.Enabled = true
	bloom.Intensity = B.Intensity
	bloom.Size = B.Size
	bloom.Threshold = B.Threshold
	if not foundBloom then
		bloom.Parent = LightingService
	end

	local S = L.SunRays
	local foundRays = LightingService:FindFirstChildOfClass("SunRaysEffect")
	local rays = foundRays or Instance.new("SunRaysEffect")
	rays.Enabled = true
	rays.Intensity = S.Intensity
	rays.Spread = S.Spread
	if not foundRays then
		rays.Parent = LightingService
	end

	local CC = L.ColorCorrection
	local foundCC = LightingService:FindFirstChildOfClass("ColorCorrectionEffect")
	local cc = foundCC or Instance.new("ColorCorrectionEffect")
	cc.Enabled = true
	cc.Brightness = CC.Brightness
	cc.Contrast = CC.Contrast
	cc.Saturation = CC.Saturation
	cc.TintColor = CC.TintColor
	if not foundCC then
		cc.Parent = LightingService
	end
end

-- Properti yang tidak bisa diubah skrip saat runtime; hanya berhasil dari Command Bar / execute_luau
-- (bake). Mengembalikan true bila berhasil. Bila gagal: atur manual Lighting.Technology = Future.
function Lighting.ApplyBakeOnly(): boolean
	local function setTechnology(): ...any
		(LightingService :: any).Technology = Enum.Technology.Future
		return true
	end
	local ok, err = pcall(setTechnology)
	if not ok then
		warn("[Lighting] Technology = Future tidak bisa diatur dari skrip: " .. tostring(err))
	end
	return ok
end

return Lighting
