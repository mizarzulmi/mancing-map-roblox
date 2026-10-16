--!strict
-- Bawah laut zona Pantai & sekitar dermaga: gugus karang warna-warni (karang otak, karang bercabang,
-- karang meja, spons tabung), rumpun rumput laut melengkung, bintang laut (5 lengan wedge), kerang &
-- kima raksasa. Semua menapak dasar laut (Terrain.HeightAt) dan tetap ≥ 1 stud di bawah permukaan air.

local MapConfig = require(script.Parent.MapConfig)
local Geo = require(script.Parent.Geo)

local UW = MapConfig.Underwater
local C = MapConfig.Colors
local MAT = Enum.Material
local UP = Vector3.yAxis

local Underwater = {}

local placed: { Vector3 } = {}

local function blocked(x: number, z: number): boolean
	for _, r in UW.Avoid do
		if x >= r.MinX and x <= r.MaxX and z >= r.MinZ and z <= r.MaxZ then
			return true
		end
	end
	for _, rk in MapConfig.Terrain.Rocks do
		local dx, dz = x - rk.X, z - rk.Z
		local rr = rk.R + 2
		if dx * dx + dz * dz < rr * rr then
			return true
		end
	end
	return false
end

-- Cari titik dasar laut acak di area dengan kedalaman sesuai dan jarak minimum dari benda lain.
local function findSpot(
	area: MapConfig.Rect,
	rng: Random,
	minDepth: number,
	maxDepth: number,
	spacing: number
): Vector3?
	for _ = 1, 60 do
		local x = rng:NextNumber(area.MinX, area.MaxX)
		local z = rng:NextNumber(area.MinZ, area.MaxZ)
		local h = Geo.GroundY(x, z)
		local depth = -h
		if depth >= minDepth and depth <= maxDepth and not blocked(x, z) then
			local ok = true
			for _, p in placed do
				local dx, dz = p.X - x, p.Z - z
				if dx * dx + dz * dz < spacing * spacing then
					ok = false
					break
				end
			end
			if ok then
				local spot = Vector3.new(x, h, z)
				table.insert(placed, spot)
				return spot
			end
		end
	end
	return nil
end

local function coralColor(rng: Random): Color3
	return C.Coral[rng:NextInteger(1, #C.Coral)]
end

local function buildCluster(model: Instance, spot: Vector3, rng: Random)
	local depth = -spot.Y
	local room = math.min(depth - 1.0, 4.5)
	local s = math.clamp(room / 3.6, 0.45, 1.15)
	local yaw = rng:NextNumber(0, math.pi * 2)
	local cf = CFrame.new(spot) * CFrame.Angles(0, yaw, 0)
	local function p(x: number, y: number, z: number): Vector3
		return (cf * CFrame.new(x * s, y * s, z * s)).Position
	end
	-- Karang otak (elipsoid)
	Geo.Ellipsoid(
		model,
		CFrame.new(p(0, 0.55, 0)) * CFrame.Angles(0, yaw, 0),
		Vector3.new(3.4, 1.7, 3.0) * s,
		coralColor(rng),
		MAT.SmoothPlastic,
		{ Shadow = false }
	)
	-- Karang bercabang: batang + 3 cabang berujung bola
	local trunkBase = p(1.9, -0.2, 0.4)
	local trunkTop = p(1.9, 1.3, 0.4)
	local col = coralColor(rng)
	Geo.Segment(model, trunkBase, trunkTop, 0.5 * s, col, MAT.SmoothPlastic, { Shadow = false })
	for k = 1, 3 do
		local a = k / 3 * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
		local tip = trunkTop + Vector3.new(math.cos(a) * 0.9, 1.1 + rng:NextNumber(-0.2, 0.4), math.sin(a) * 0.9) * s
		Geo.Segment(model, trunkTop, tip, 0.34 * s, col, MAT.SmoothPlastic, { Shadow = false, Extend = 0.1 })
		Geo.Ball(model, tip, 0.5 * s, col:Lerp(C.White, 0.25), MAT.SmoothPlastic, { Shadow = false })
	end
	-- Karang meja
	local tcol = coralColor(rng)
	Geo.Post(model, p(-1.8, -0.2, -1.2), 1.1 * s, 0.4 * s, tcol, MAT.SmoothPlastic, { Shadow = false })
	Geo.Disk(model, p(-1.8, 0.95, -1.2), 0.26 * s, 2.6 * s, tcol, MAT.SmoothPlastic, { Shadow = false })
	-- Spons tabung
	local scol = coralColor(rng)
	Geo.Post(model, p(-0.6, -0.2, 1.8), 1.7 * s, 0.55 * s, scol, MAT.SmoothPlastic, { Shadow = false })
	Geo.Post(model, p(-0.1, -0.2, 2.3), 1.1 * s, 0.5 * s, scol, MAT.SmoothPlastic, { Shadow = false })
end

local function buildSeaweed(model: Instance, spot: Vector3, rng: Random)
	local depth = -spot.Y
	for k = 1, 3 do
		local a = rng:NextNumber(0, math.pi * 2)
		local base = spot + Vector3.new(math.cos(a), 0, math.sin(a)) * rng:NextNumber(0.3, 1.4) - UP * 0.2
		local h = math.min(depth - 1.2, rng:NextNumber(3, 6))
		if h > 1 then
			local sway = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1))
			local pts = Geo.Bezier3(
				base,
				base + sway * 0.8 + UP * (h * 0.35),
				base - sway * 0.5 + UP * (h * 0.7),
				base + sway * 0.9 + UP * h,
				4
			)
			Geo.Chain(
				model,
				pts,
				0.32,
				0.16,
				if k % 2 == 0 then C.Seaweed else C.SeaweedDark,
				MAT.SmoothPlastic,
				{ Shadow = false }
			)
		end
	end
end

-- Normal dasar laut dari selisih tinggi (agar benda pipih menempel miring mengikuti lereng).
local function seabedNormal(x: number, z: number): Vector3
	local hx = Geo.GroundY(x + 1, z) - Geo.GroundY(x - 1, z)
	local hz = Geo.GroundY(x, z + 1) - Geo.GroundY(x, z - 1)
	return Vector3.new(-hx / 2, 1, -hz / 2).Unit
end

local function buildStarfish(model: Instance, spot: Vector3, rng: Random)
	local n = seabedNormal(spot.X, spot.Z)
	local ref = if math.abs(n.X) < 0.9 then Vector3.xAxis else Vector3.zAxis
	local e1 = (ref - n * ref:Dot(n)).Unit
	local e2 = n:Cross(e1)
	local center = spot + n * 0.06
	local col = C.Starfish[rng:NextInteger(1, #C.Starfish)]
	local rot = rng:NextNumber(0, math.pi * 2)
	Geo.Cylinder(model, Geo.AlongX(center, n), 0.2, 0.75, col, MAT.SmoothPlastic, { Shadow = false })
	for k = 0, 4 do
		local a = rot + k / 5 * math.pi * 2
		local dir = e1 * math.cos(a) + e2 * math.sin(a)
		Geo.Tip(
			model,
			center + dir * 0.2,
			center + dir * 1.15,
			0.55,
			0.18,
			n,
			col,
			MAT.SmoothPlastic,
			{ Shadow = false, Jitter = 0 }
		)
	end
end

local function buildShell(model: Instance, spot: Vector3, rng: Random)
	local n = seabedNormal(spot.X, spot.Z)
	local a = rng:NextNumber(0, math.pi * 2)
	local cf = CFrame.lookAt(spot + n * 0.1, spot + n * 0.1 + Vector3.new(math.cos(a), 0, math.sin(a)), n)
	Geo.Ellipsoid(
		model,
		cf,
		Vector3.new(0.7, 0.24, 0.6),
		C.Shell[rng:NextInteger(1, #C.Shell)],
		MAT.SmoothPlastic,
		{ Shadow = false }
	)
end

local function buildClam(model: Instance, spot: Vector3, rng: Random)
	local yaw = rng:NextNumber(0, math.pi * 2)
	local cf = CFrame.new(spot + UP * 0.35) * CFrame.Angles(0, yaw, 0)
	for _, sz in { -1, 1 } do
		Geo.Ellipsoid(
			model,
			cf * CFrame.new(0, 0.25, sz * 0.35) * CFrame.Angles(math.rad(sz * 28), 0, 0),
			Vector3.new(1.9, 0.75, 1.1),
			C.Shell[3],
			MAT.SmoothPlastic,
			{ Shadow = false }
		)
	end
	Geo.Ellipsoid(
		model,
		cf * CFrame.new(0, 0.45, 0),
		Vector3.new(1.6, 0.5, 0.55),
		if rng:NextNumber() < 0.5 then C.Blue else C.Teal,
		MAT.SmoothPlastic,
		{ Shadow = false }
	)
end

function Underwater.Build(ctx: Geo.Context)
	local rng = Geo.Rng(MapConfig.SeedOffsets.Underwater)
	table.clear(placed)
	local model = Geo.Model(ctx.Root, "BawahLaut")
	for i, area in UW.Areas do
		for _ = 1, UW.Clusters[i] or 0 do
			local spot = findSpot(area, rng, 2.4, UW.MaxDepth, 9)
			if spot then
				buildCluster(model, spot, rng)
			end
		end
		for _ = 1, UW.SeaweedClumps[i] or 0 do
			local spot = findSpot(area, rng, 3.0, UW.MaxDepth, 5)
			if spot then
				buildSeaweed(model, spot, rng)
			end
		end
		for _ = 1, UW.Starfish[i] or 0 do
			local spot = findSpot(area, rng, UW.MinDepth, 14, 3)
			if spot then
				buildStarfish(model, spot, rng)
			end
		end
		for _ = 1, UW.Shells[i] or 0 do
			local spot = findSpot(area, rng, UW.MinDepth, 16, 2)
			if spot then
				buildShell(model, spot, rng)
			end
		end
		for _ = 1, UW.Clams[i] or 0 do
			local spot = findSpot(area, rng, 3.0, 14, 6)
			if spot then
				buildClam(model, spot, rng)
			end
		end
	end
end

return Underwater
