--!strict
-- Penanda dunia (kontrak PLAN.md §6): FishingZones, NPCSpawns, AmbientPoints, Boundary.
-- Dibangun PALING AKHIR: titik NPC diambil dari ctx.Npc yang didaftarkan modul pembangun
-- (agar menempel tepat di lantai/dudukan); cadangan MapConfig.NpcFallback dipakai bila tidak ada.

local MapConfig = require(script.Parent.MapConfig)
local Geo = require(script.Parent.Geo)

local Zones = {}

local function buildFishingZones(ctx: Geo.Context)
	for _, z in MapConfig.FishingZones do
		Geo.Marker(ctx.FishingZones, "FishingZone_" .. z.Id, CFrame.new(z.Center), z.Size, { ZoneId = z.Id })
	end
end

local function buildNpcSpawns(ctx: Geo.Context)
	local fallback: { [string]: MapConfig.NpcFallback } = {}
	for _, f in MapConfig.NpcFallback do
		fallback[f.Id] = f
	end
	for _, id in MapConfig.NpcIds do
		local cf: CFrame? = ctx.Npc[id]
		if not cf then
			local f = fallback[id]
			if f then
				cf = Geo.Facing(f.Pos, f.Face)
				warn("[Zones] titik NPC " .. id .. " memakai posisi cadangan MapConfig")
			end
		end
		if cf then
			Geo.Marker(ctx.NPCSpawns, "NPCSpawn_" .. id, cf, Vector3.new(1, 0.2, 1), { NpcId = id })
		end
	end
end

local function buildAmbient(ctx: Geo.Context)
	local counter: { [string]: number } = {}
	for _, a in MapConfig.Ambient do
		local n = (counter[a.Kind] or 0) + 1
		counter[a.Kind] = n
		local pos = a.Pos
		if a.OnGround then
			pos = Vector3.new(pos.X, Geo.GroundY(pos.X, pos.Z) + 0.2, pos.Z)
		end
		Geo.Marker(
			ctx.AmbientPoints,
			string.format("%s_%d", a.Kind, n),
			CFrame.new(pos),
			Vector3.new(1, 1, 1),
			{ Kind = a.Kind, Radius = a.Radius }
		)
	end
end

local function buildBoundary(ctx: Geo.Context)
	local B = MapConfig.Boundary
	local folder = Geo.Folder(ctx.Root, "Boundary")
	local n = B.Segments
	local width = 2 * B.Radius * math.tan(math.pi / n) + 4
	local height = B.Top - B.Bottom
	local midY = (B.Top + B.Bottom) * 0.5
	for i = 0, n - 1 do
		local a = i / n * math.pi * 2
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local pos = dir * (B.Radius + B.Thickness * 0.5) + Vector3.new(0, midY, 0)
		Geo.Block(
			folder,
			CFrame.lookAt(pos, pos + dir),
			Vector3.new(width, height, B.Thickness),
			Color3.new(1, 1, 1),
			Enum.Material.SmoothPlastic,
			{
				Name = string.format("Dinding_%02d", i + 1),
				Collide = true,
				Transparency = 1,
				Shadow = false,
				Jitter = 0,
			}
		)
	end
end

function Zones.Build(ctx: Geo.Context)
	buildFishingZones(ctx)
	buildNpcSpawns(ctx)
	buildAmbient(ctx)
	buildBoundary(ctx)
end

return Zones
