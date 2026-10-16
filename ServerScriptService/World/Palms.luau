--!strict
-- Pohon kelapa: ±40 pohon sebaran Poisson-disk (jarak min 14, deterministik) di pasir & tepi bukit,
-- menghindari jalur, bangunan, dan zona eksklusi MapConfig. Batang melengkung (kurva Bezier kubik →
-- 8 segmen silinder bertaper dengan cincin gelap bergantian), mahkota 7 pelepah × 3 segmen daun yang
-- melengkung turun secara radial, dan 3 buah kelapa. Condong ke arah laut.

local MapConfig = require(script.Parent.MapConfig)
local Geo = require(script.Parent.Geo)

local PA = MapConfig.Palms
local C = MapConfig.Colors
local MAT = Enum.Material
local UP = Vector3.yAxis

local Palms = {}

type Spot = { X: number, Z: number, Height: number, Lean: Vector3 }

local function excluded(x: number, z: number): boolean
	for _, e in PA.ExcludeEllipses do
		local dx, dz = (x - e.X) / e.RX, (z - e.Z) / e.RZ
		if dx * dx + dz * dz < 1 then
			return true
		end
	end
	for _, r in PA.ExcludeRects do
		if x >= r.MinX and x <= r.MaxX and z >= r.MinZ and z <= r.MaxZ then
			return true
		end
	end
	for _, c in PA.ExcludeCircles do
		local dx, dz = x - c.X, z - c.Z
		if dx * dx + dz * dz < c.R * c.R then
			return true
		end
	end
	for _, rk in MapConfig.Terrain.Rocks do
		local dx, dz = x - rk.X, z - rk.Z
		local rr = rk.R + 3
		if dx * dx + dz * dz < rr * rr then
			return true
		end
	end
	return false
end

-- Bobot penerimaan per jenis lahan: pasir pantai paling disukai, tepi bukit sedang, dataran jarang.
local function weightAt(x: number, z: number): number
	local h, mat = Geo.GroundY(x, z), Geo.GroundMaterial(x, z)
	if h < PA.MinGround or h > PA.MaxGround then
		return 0
	end
	if mat ~= MAT.Sand and mat ~= MAT.Grass and mat ~= MAT.LeafyGrass then
		return 0
	end
	if mat == MAT.Sand and h < 5.3 then
		return 1
	elseif h > 6.6 then
		return 0.75
	end
	return 0.3
end

local function farEnough(x: number, z: number, spots: { Spot }, minDist: number): boolean
	local m2 = minDist * minDist
	for _, s in spots do
		local dx, dz = x - s.X, z - s.Z
		if dx * dx + dz * dz < m2 then
			return false
		end
	end
	return true
end

local function chooseSpots(rng: Random): { Spot }
	local spots: { Spot } = {}
	for _, h in PA.Hero do
		local lean = Geo.Flat(h.Lean)
		table.insert(spots, { X = h.X, Z = h.Z, Height = h.Height, Lean = lean.Unit * (h.Height * 0.3) })
	end
	local A = PA.Area
	local attempts = 0
	while #spots < PA.Count and attempts < PA.Attempts do
		attempts += 1
		local x = rng:NextNumber(A.MinX, A.MaxX)
		local z = rng:NextNumber(A.MinZ, A.MaxZ)
		local w = weightAt(x, z)
		if w > 0 and rng:NextNumber() < w and not excluded(x, z) and farEnough(x, z, spots, PA.MinDist) then
			if not Geo.NearPath(x, z, PA.PathMargin) then
				local height = rng:NextNumber(19, 28)
				local dir: Vector3
				if z < -40 then
					local a = rng:NextNumber(0, math.pi * 2)
					dir = Vector3.new(math.cos(a), 0, math.sin(a))
				else
					local a = rng:NextNumber(-0.85, 0.85)
					dir = Vector3.new(math.sin(a), 0, math.cos(a))
				end
				local amount = height * rng:NextNumber(0.16, if z < -40 then 0.24 else 0.4)
				table.insert(spots, { X = x, Z = z, Height = height, Lean = dir * amount })
			end
		end
	end
	if #spots < PA.Count then
		warn(string.format("[Palms] hanya %d dari %d pohon mendapat tempat", #spots, PA.Count))
	end
	return spots
end

local function buildPalm(model: Instance, s: Spot, rng: Random)
	local g = Geo.GroundY(s.X, s.Z)
	local base = Vector3.new(s.X, g - 0.6, s.Z)
	local top = base + Vector3.new(s.Lean.X, s.Height, s.Lean.Z)
	-- Condong sejak pangkal lalu melengkung tegak di puncak.
	local p1 = base + s.Lean * 0.55 + UP * (s.Height * 0.3)
	local p2 = base + s.Lean * 0.95 + UP * (s.Height * 0.68)
	local pts = Geo.Bezier3(base, p1, p2, top, PA.TrunkSegments)
	local trunk = Geo.Chain(model, pts, 2.3, 1.2, C.PalmTrunk, MAT.Wood, { Shadow = true }, C.PalmTrunkDark)
	for i = 1, math.min(5, #trunk) do
		trunk[i].CanCollide = true
		trunk[i].CanQuery = true
	end

	-- Mahkota: pelepah radial, bergantian atas (lebih tegak) & bawah (lebih melengkung turun).
	local crown = top + UP * 0.2
	local rot = rng:NextNumber(0, math.pi * 2)
	for i = 1, PA.Fronds do
		local az = rot + (i - 1) / PA.Fronds * math.pi * 2 + rng:NextNumber(-0.18, 0.18)
		local dir = Vector3.new(math.cos(az), 0, math.sin(az))
		local upper = i % 2 == 0
		local len = rng:NextNumber(8.5, 11.5) * (if upper then 0.88 else 1)
		local rise = if upper then rng:NextNumber(0.35, 0.55) else rng:NextNumber(0.12, 0.28)
		local droop = if upper then rng:NextNumber(0.55, 0.75) else rng:NextNumber(0.78, 1.02)
		local q0 = crown - UP * 0.3 + dir * 0.35
		local q1 = crown + dir * (len * 0.5) + UP * (len * rise)
		local q2 = crown + dir * len + UP * (len * (rise - droop))
		local fp = Geo.Bezier2(q0, q1, q2, 3)
		local roll = rng:NextNumber(-0.35, 0.35)
		local col = if upper then C.PalmLeaf else C.PalmLeafDark
		for k = 1, 3 do
			local a, b = fp[k], fp[k + 1]
			local along = b - a
			local side = along:Cross(UP)
			if side.Magnitude < 1e-3 then
				side = dir:Cross(UP)
			end
			side = side.Unit
			local normal = side:Cross(along.Unit)
			if normal.Y < 0 then
				normal = -normal
			end
			normal = (normal + side * roll).Unit
			if k < 3 then
				Geo.Plank(
					model,
					a,
					b,
					if k == 1 then 1.0 else 1.9,
					0.14,
					normal,
					col,
					MAT.SmoothPlastic,
					{ Shadow = true, Extend = 0.25, Jitter = 0.05 }
				)
			else
				Geo.Tip(
					model,
					a,
					b + along.Unit * 0.6,
					1.8,
					0.14,
					normal,
					col:Lerp(C.PalmLeafDry, 0.3),
					MAT.SmoothPlastic,
					{ Shadow = true, Jitter = 0.05 }
				)
			end
		end
	end

	-- Buah kelapa bergerombol di bawah mahkota.
	for k = 1, PA.Coconuts do
		local a = rot + k / PA.Coconuts * math.pi * 2 + 0.4
		local p = top - UP * 0.75 + Vector3.new(math.cos(a), 0, math.sin(a)) * 0.78
		Geo.Ball(
			model,
			p,
			rng:NextNumber(0.95, 1.2),
			if k == 2 then C.CoconutBrown else C.Coconut,
			MAT.SmoothPlastic,
			{ Shadow = false }
		)
	end
end

function Palms.Build(ctx: Geo.Context)
	local rng = Geo.Rng(MapConfig.SeedOffsets.Palms)
	local model = Geo.Model(ctx.Root, "PohonKelapa")
	for i, s in chooseSpots(rng) do
		local tree = Geo.Model(model, string.format("Kelapa_%02d", i))
		buildPalm(tree, s, rng)
	end
end

-- Titik di sumbu batang kelapa "pahlawan" ke-`index` pada ketinggian `height` di atas tanah
-- (kurva yang sama dengan buildPalm; dipakai mis. untuk ayunan tali di antara dua kelapa).
function Palms.HeroTrunkPoint(index: number, height: number): Vector3?
	local h = PA.Hero[index]
	if not h then
		return nil
	end
	local g = Geo.GroundY(h.X, h.Z)
	local base = Vector3.new(h.X, g - 0.6, h.Z)
	local lean = Geo.Flat(h.Lean).Unit * (h.Height * 0.3)
	local top = base + Vector3.new(lean.X, h.Height, lean.Z)
	local p1 = base + lean * 0.55 + UP * (h.Height * 0.3)
	local p2 = base + lean * 0.95 + UP * (h.Height * 0.68)
	local pts = Geo.Bezier3(base, p1, p2, top, 40)
	local targetY = g + height
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		if a.Y <= targetY and b.Y >= targetY then
			return a:Lerp(b, (targetY - a.Y) / math.max(1e-6, b.Y - a.Y))
		end
	end
	return pts[#pts]
end

return Palms
