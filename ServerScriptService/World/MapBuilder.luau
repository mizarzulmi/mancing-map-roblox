--!strict
-- Pembangun map Pantai Mancing Nusantara (deterministik, seed tetap MapConfig.Seed).
-- Hanya menyentuh Workspace.BeachMap, Workspace.Terrain, dan Lighting.
-- Workspace.CustomMap milik pemilik proyek: TIDAK PERNAH dibaca, ditulis, dipindah, atau dihapus.
-- Boleh yield (task.wait) — panggil dari task (WorldService) atau Command Bar (scripts/bake-command.luau).

local Workspace = game:GetService("Workspace")

local MapConfig = require(script.Parent.MapConfig)
local Geo = require(script.Parent.Geo)
local Terrain = require(script.Parent.Terrain)
local Lighting = require(script.Parent.Lighting)
local Plaza = require(script.Parent.Plaza)
local Pier = require(script.Parent.Pier)
local Palms = require(script.Parent.Palms)
local Mangroves = require(script.Parent.Mangroves)
local Boats = require(script.Parent.Boats)
local Pinisi = require(script.Parent.Pinisi)
local Lighthouse = require(script.Parent.Lighthouse)
local BeachProps = require(script.Parent.BeachProps)
local Underwater = require(script.Parent.Underwater)
local Zones = require(script.Parent.Zones)

local MapBuilder = {}

export type BuildOptions = { Bake: boolean? }
export type BuildResult = { Parts: number, Seconds: number }

type Step = { Name: string, Build: (Geo.Context) -> (), Offset: number }

-- Urutan penting: Zones terakhir (memakai titik NPC yang didaftarkan modul lain).
local STEPS: { Step } = {
	{ Name = "Plaza", Build = Plaza.Build, Offset = MapConfig.SeedOffsets.Plaza },
	{ Name = "Pier", Build = Pier.Build, Offset = MapConfig.SeedOffsets.Pier },
	{ Name = "Palms", Build = Palms.Build, Offset = MapConfig.SeedOffsets.Palms },
	{ Name = "Mangroves", Build = Mangroves.Build, Offset = MapConfig.SeedOffsets.Mangroves },
	{ Name = "Boats", Build = Boats.Build, Offset = MapConfig.SeedOffsets.Boats },
	{ Name = "Pinisi", Build = Pinisi.Build, Offset = MapConfig.SeedOffsets.Pinisi },
	{ Name = "Lighthouse", Build = Lighthouse.Build, Offset = MapConfig.SeedOffsets.Lighthouse },
	{ Name = "BeachProps", Build = BeachProps.Build, Offset = MapConfig.SeedOffsets.BeachProps },
	{ Name = "Underwater", Build = Underwater.Build, Offset = MapConfig.SeedOffsets.Underwater },
	{ Name = "Zones", Build = Zones.Build, Offset = MapConfig.SeedOffsets.Zones },
}

local building = false

local function reportBudget(total: number)
	local counts = Geo.Counts()
	local budget = MapConfig.Budget :: { [string]: number }
	for _, step in STEPS do
		local n = counts[step.Name] or 0
		local cap = budget[step.Name]
		if cap and n > cap then
			warn(string.format("[MapBuilder] %s: %d part melebihi anggaran %d", step.Name, n, cap))
		else
			print(string.format("[MapBuilder] %s: %d part (anggaran %d)", step.Name, n, cap or 0))
		end
	end
	if total > MapConfig.MaxParts then
		warn(string.format("[MapBuilder] total %d part melebihi batas %d", total, MapConfig.MaxParts))
	end
end

local function buildInner(options: BuildOptions?): BuildResult
	local t0 = os.clock()
	local bake = options ~= nil and options.Bake == true

	local old = Workspace:FindFirstChild("BeachMap")
	if old then
		old:Destroy()
	end

	Lighting.Apply()
	Terrain.Build(Workspace.Terrain)

	Geo.ResetCounts()
	local root = Instance.new("Model")
	root.Name = "BeachMap"
	local ctx: Geo.Context = {
		Root = root,
		Points = Geo.Folder(root, "Points"),
		NPCSpawns = Geo.Folder(root, "NPCSpawns"),
		AmbientPoints = Geo.Folder(root, "AmbientPoints"),
		FishingZones = Geo.Folder(root, "FishingZones"),
		Npc = {},
		Bake = bake,
	}

	for _, step in STEPS do
		Geo.BeginModule(step.Name, step.Offset)
		local ok, err = pcall(step.Build :: any, ctx)
		if not ok then
			warn(string.format("[MapBuilder] modul %s gagal: %s", step.Name, tostring(err)))
		end
		task.wait()
	end

	local parts = 0
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	reportBudget(parts)

	root.Parent = Workspace
	local seconds = os.clock() - t0
	print(string.format("[MapBuilder] selesai: %d part, %.1f dtk", parts, seconds))
	return { Parts = parts, Seconds = seconds }
end

-- Bangun ulang seluruh map: hapus Workspace.BeachMap lama, tulis terrain, bangun semua modul ke Model
-- baru "BeachMap", lalu parent ke Workspace paling akhir.
function MapBuilder.Build(options: BuildOptions?): BuildResult
	if building then
		warn("[MapBuilder] pembangunan sedang berjalan; panggilan diabaikan")
		return { Parts = 0, Seconds = 0 }
	end
	building = true
	local ok, result = pcall(buildInner :: any, options)
	building = false
	if not ok then
		warn("[MapBuilder] gagal membangun map: " .. tostring(result))
		return { Parts = 0, Seconds = 0 }
	end
	return result :: BuildResult
end

-- Bangun hanya bila Workspace.BeachMap belum ada. Mengembalikan true bila membangun.
function MapBuilder.EnsureBuilt(): boolean
	if Workspace:FindFirstChild("BeachMap") then
		return false
	end
	MapBuilder.Build()
	return true
end

-- Bake (Command Bar / execute_luau, datamodel Edit): bangun + properti Lighting khusus bake.
function MapBuilder.Bake(): BuildResult
	local result = MapBuilder.Build({ Bake = true })
	Lighting.ApplyBakeOnly()
	return result
end

return MapBuilder
