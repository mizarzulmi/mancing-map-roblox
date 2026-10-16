--!strict
-- TerrainCheckController (khusus Studio): diagnosis daratan di sisi client. Pemilik melihat pantai "tenggelam"
-- (permukaan berwarna air) padahal server membaca daratan padat & kering di titik yang sama (2026-10-16).
-- Raycast (dengan & tanpa air) + baca voxel di titik cek yang sama dengan server; hasil ke Output dengan awalan
-- "[Terrain/klien]" agar bisa dibandingkan dengan "[Terrain] cek darat" dari server.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local TerrainCheckController = {}

-- Titik darat yang sama dengan Terrain.luau (CHECK_POINTS) + satu titik laut sebagai pembanding.
local POINTS: { Vector2 } = {
	Vector2.new(0, 0),
	Vector2.new(0, 48),
	Vector2.new(-32, -16),
	Vector2.new(60, 40),
	Vector2.new(-60, 60),
	Vector2.new(220, 180),
	Vector2.new(0, 160),
}

local function describe(result: RaycastResult?): string
	if result == nil then
		return "kosong"
	end
	return string.format("%s/%s y=%.1f", result.Instance.Name, result.Material.Name, result.Position.Y)
end

local function columnReport(terrain: Terrain, p: Vector2): string
	local x0 = math.floor(p.X / 4) * 4
	local z0 = math.floor(p.Y / 4) * 4
	local region = Region3.new(Vector3.new(x0, 0, z0), Vector3.new(x0 + 4, 24, z0 + 4))
	local ok, data = pcall(function(): ...any
		return terrain:ReadVoxelChannels(region, 4, { "SolidOccupancy", "LiquidOccupancy" })
	end)
	if not ok or type(data) ~= "table" then
		return "voxel gagal dibaca"
	end
	local d = data :: any
	local solid, liquid = 0, 0
	for iy = 1, (d.Size :: Vector3).Y do
		solid += d.SolidOccupancy[1][iy][1] * 4
		liquid += d.LiquidOccupancy[1][iy][1] * 4
	end
	return string.format("voxel y0-24 padat %.1f air %.1f", solid, liquid)
end

-- Uji slab sinar vs kotak part (ruang lokal part). Mengembalikan t (0–1) pada segmen bila kena.
local function slab(o: number, d: number, h: number, tmin: number, tmax: number): (number, number)
	if math.abs(d) < 1e-9 then
		if o < -h or o > h then
			return 1, 0
		end
		return tmin, tmax
	end
	local t1 = (-h - o) / d
	local t2 = (h - o) / d
	if t1 > t2 then
		t1, t2 = t2, t1
	end
	return math.max(tmin, t1), math.min(tmax, t2)
end

local function segmentHits(part: BasePart, origin: Vector3, segment: Vector3): number?
	local o = part.CFrame:PointToObjectSpace(origin)
	local d = part.CFrame:VectorToObjectSpace(segment)
	local half = part.Size / 2
	local tmin, tmax = 0, 1
	tmin, tmax = slab(o.X, d.X, half.X, tmin, tmax)
	tmin, tmax = slab(o.Y, d.Y, half.Y, tmin, tmax)
	tmin, tmax = slab(o.Z, d.Z, half.Z, tmin, tmax)
	if tmin > tmax then
		return nil
	end
	return tmin
end

-- Sinar dari kamera ke separuh bawah layar: apa yang terkena (terrain/part) dan part BeachMap mana (termasuk
-- CanQuery=false yang tak terlihat raycast) yang menghalangi pandangan sebelum titik itu.
local function viewReport(): string
	local camera = workspace.CurrentCamera
	local map = workspace:FindFirstChild("BeachMap")
	if camera == nil or map == nil then
		return "kamera/BeachMap belum ada"
	end
	local parts: { BasePart } = {}
	for _, d in map:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 0.98 then
			table.insert(parts, d)
		end
	end
	local params = RaycastParams.new()
	params.IgnoreWater = false
	local hits: { [string]: number } = {}
	local blockers: { [BasePart]: number } = {}
	local view = camera.ViewportSize
	for ix = 1, 5 do
		for iy = 1, 3 do
			local ray = camera:ViewportPointToRay(view.X * ix / 6, view.Y * (0.5 + iy * 0.12))
			local reach = ray.Direction.Unit * 600
			local result = workspace:Raycast(ray.Origin, reach, params)
			local label = if result then result.Instance.Name .. "/" .. result.Material.Name else "langit"
			hits[label] = (hits[label] or 0) + 1
			local segment = if result then result.Position - ray.Origin else reach
			local nearest: BasePart? = nil
			local nearestT = math.huge
			for _, part in parts do
				if result == nil or part ~= result.Instance then
					local t = segmentHits(part, ray.Origin, segment)
					if t and t > 0.001 and t < nearestT then
						nearest, nearestT = part, t
					end
				end
			end
			if nearest then
				blockers[nearest] = (blockers[nearest] or 0) + 1
			end
		end
	end
	local hitList: { string } = {}
	for label, n in hits do
		table.insert(hitList, label .. "×" .. n)
	end
	local blockList: { string } = {}
	for part, n in blockers do
		local c = part.Color
		table.insert(
			blockList,
			string.format(
				"%s ×%d [ukuran %.0f×%.0f×%.0f y=%.1f warna %d,%d,%d %s transp %.2f CanQuery=%s]",
				part:GetFullName(),
				n,
				part.Size.X,
				part.Size.Y,
				part.Size.Z,
				part.Position.Y,
				math.floor(c.R * 255),
				math.floor(c.G * 255),
				math.floor(c.B * 255),
				part.Material.Name,
				part.Transparency,
				tostring(part.CanQuery)
			)
		)
	end
	return string.format(
		"kamera di %s · terkena: %s · penghalang: %s",
		tostring(camera.CFrame.Position),
		table.concat(hitList, ", "),
		if #blockList > 0 then table.concat(blockList, "; ") else "tidak ada"
	)
end

local function check()
	local terrain = workspace.Terrain
	local withWater = RaycastParams.new()
	withWater.IgnoreWater = false
	local solidOnly = RaycastParams.new()
	solidOnly.IgnoreWater = true
	local lines: { string } = {}
	for _, p in POINTS do
		local origin = Vector3.new(p.X, 80, p.Y)
		local down = Vector3.new(0, -160, 0)
		table.insert(
			lines,
			string.format(
				"(%d,%d) pertama %s · padat %s · %s",
				p.X,
				p.Y,
				describe(workspace:Raycast(origin, down, withWater)),
				describe(workspace:Raycast(origin, down, solidOnly)),
				columnReport(terrain, p)
			)
		)
	end
	local sand = terrain:GetMaterialColor(Enum.Material.Sand)
	print(
		string.format(
			"[Terrain/klien] StreamingEnabled=%s · warna pasir %d,%d,%d · air %d,%d,%d transp %.2f | %s",
			tostring(workspace.StreamingEnabled),
			math.floor(sand.R * 255),
			math.floor(sand.G * 255),
			math.floor(sand.B * 255),
			math.floor(terrain.WaterColor.R * 255),
			math.floor(terrain.WaterColor.G * 255),
			math.floor(terrain.WaterColor.B * 255),
			terrain.WaterTransparency,
			table.concat(lines, " | ")
		)
	)
	print("[Terrain/klien] pandangan: " .. viewReport())
end

function TerrainCheckController.Start()
	if not RunService:IsStudio() then
		return
	end
	task.spawn(function()
		local player = Players.LocalPlayer
		local character = player.Character or player.CharacterAdded:Wait()
		if character:WaitForChild("HumanoidRootPart", 20) then
			task.wait(8) -- beri waktu streaming terrain di sekitar spawn
			check()
			task.wait(17) -- sekali lagi saat pemain sudah melihat-lihat sekitar
			check()
		end
	end)
end

return TerrainCheckController
