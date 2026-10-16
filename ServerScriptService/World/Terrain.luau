--!strict
-- Terrain prosedural Pantai Nusantara.
-- HeightAt(x, z) adalah fungsi tinggi deterministik yang juga dipakai modul lain (lewat Geo.GroundY)
-- agar setiap benda menapak tanah. Build() menulis laut besar dengan FillBlock (cepat), lalu
-- pulau/lereng/laguna per chunk ≤ 64×96×64 stud dengan WriteVoxelChannels (cadangan: WriteVoxels).

local MapConfig = require(script.Parent.MapConfig)

local T = MapConfig.Terrain
local CO = T.Coast
local SEA = T.Sea
local BE = T.Beach
local HI = T.Hills
local CA = T.Cape
local LA = T.Lagoon
local CN = T.Canal

local M = Enum.Material
local RES = 4

local Terrain = {}

-- Offset noise dari seed (deterministik, tetap selama seed sama).
local NZ: { number } = {}
do
	local rng = Random.new(MapConfig.Seed + MapConfig.SeedOffsets.Terrain)
	for i = 1, 16 do
		NZ[i] = rng:NextNumber(0, 97) + 0.371
	end
end

local function clamp01(x: number): number
	if x < 0 then
		return 0
	elseif x > 1 then
		return 1
	end
	return x
end

local function smoothstep(e0: number, e1: number, x: number): number
	local t = clamp01((x - e0) / (e1 - e0))
	return t * t * (3 - 2 * t)
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function bell(t: number): number
	local q = 1 - t * t
	if q <= 0 then
		return 0
	end
	return q * q
end

-- Smooth max polinomial: sama dengan max(a, b) bila |a − b| ≥ k, halus di dekat sudut.
local function smax(a: number, b: number, k: number): number
	local h = clamp01(0.5 + 0.5 * (b - a) / k)
	return lerp(a, b, h) + k * h * (1 - h)
end

-- Garis pantai selatan (Z) sebagai fungsi X: teluk landai + tonjolan tanjung timur & barat (laguna).
local function shoreZ(x: number): number
	local u = (x - CO.ShoreCenterX) / 200
	local z = CO.ShoreBase + CO.ShoreCurve * u * u
	z += math.noise(x / CO.ShoreNoiseScale, NZ[1], NZ[2]) * 2 * CO.ShoreNoiseAmp
	z += CO.CapeReach * bell((x - CO.CapeX) / CO.CapeHalf)
	z += CO.WestReach * bell((x - CO.WestX) / CO.WestHalf)
	return z
end

local function northZ(x: number): number
	return CO.NorthBase + math.noise(x / CO.NorthScale, NZ[3], NZ[4]) * 2 * CO.NorthAmp
end

-- Jarak bertanda ke garis pantai (positif = laut) dan bobot "sisi selatan" 0..1.
local function coast(x: number, z: number): (number, number)
	local zs = shoreZ(x)
	local ds = (shoreZ(x + 1) - shoreZ(x - 1)) * 0.5
	local sS = (z - zs) / math.sqrt(1 + ds * ds)
	local zn = northZ(x)
	local dn = (northZ(x + 1) - northZ(x - 1)) * 0.5
	local sN = (zn - z) / math.sqrt(1 + dn * dn)
	local sW = CO.West - x
	local sE = x - CO.East
	local k = CO.CornerSmooth
	local other = smax(smax(sN, sW, k), sE, k)
	local s = smax(sS, other, k)
	return s, smoothstep(-25, 25, sS - other)
end

-- Polyline kanal (XZ) untuk jarak titik–segmen.
local canalPts: { Vector3 } = CN.Points

local function distToPolyline(x: number, z: number, pts: { Vector3 }): number
	local best = math.huge
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local abx, abz = b.X - a.X, b.Z - a.Z
		local apx, apz = x - a.X, z - a.Z
		local len2 = abx * abx + abz * abz
		local t = if len2 > 0 then clamp01((apx * abx + apz * abz) / len2) else 0
		local dx, dz = apx - abx * t, apz - abz * t
		local d = math.sqrt(dx * dx + dz * dz)
		if d < best then
			best = d
		end
	end
	return best
end

-- Tinggi permukaan tanah/dasar laut di (x, z) beserta material permukaannya.
function Terrain.HeightAt(x: number, z: number): (number, Enum.Material)
	local s, southDom = coast(x, z)
	local h: number
	local mat: Enum.Material = M.Sand

	if s >= 0 then
		-- Laut: rak dangkal → lereng → dasar dalam.
		local se = s / lerp(SEA.OtherSideScale, 1, southDom)
		if se <= SEA.ShelfDist then
			h = SEA.ShelfY * (se / SEA.ShelfDist)
		elseif se <= SEA.SlopeDist then
			h = SEA.ShelfY + (SEA.SlopeY - SEA.ShelfY) * smoothstep(SEA.ShelfDist, SEA.SlopeDist, se)
		elseif se <= SEA.DeepDist then
			h = SEA.SlopeY + (T.SeaFloor - SEA.SlopeY) * smoothstep(SEA.SlopeDist, SEA.DeepDist, se)
		else
			h = T.SeaFloor
		end
		local ripple = smoothstep(4, 30, se) * (1 - smoothstep(SEA.SlopeDist, SEA.DeepDist, se))
		h += math.noise(x / 18, z / 18, NZ[5]) * 2 * SEA.RippleAmp * ripple
	else
		local u = -s
		local width = lerp(BE.WidthOther, BE.WidthSouth, southDom)
		if u <= width then
			-- Pita pasir: turun landai dari +5 ke 0 di garis pantai.
			h = BE.SandTop * (u / width)
		else
			h = BE.SandTop + BE.PlateauRise * smoothstep(width, width + 40, u)
			local tg = smoothstep(width, width + BE.GrassBlend, u) + math.noise(x / 14, z / 14, NZ[6]) * 0.7
			if tg >= 0.5 then
				mat = if math.noise(x / 30, z / 30, NZ[7]) > 0.12 then M.LeafyGrass else M.Grass
			end
			-- Bukit rumput di utara.
			local hm = smoothstep(HI.StartZ, HI.FullZ, z) * smoothstep(HI.EdgeIn, HI.EdgeFull, u)
			if hm > 0 then
				local n = 0.5
					+ math.noise(x / HI.Scale, z / HI.Scale, NZ[8]) * 0.6
					+ math.noise(x / 42, z / 42, NZ[9]) * 0.3
					+ math.noise(x / 17, z / 17, NZ[10]) * 0.12
				local hill = HI.Height * hm * (0.45 + 0.55 * clamp01(n))
				h += hill
				if hill > HI.RockAbove and math.noise(x / 22, z / 22, NZ[11]) > 0.18 then
					mat = M.Rock
				elseif mat == M.Sand and hill > 1.5 then
					mat = M.Grass
				end
			end
		end
	end

	-- Gumuk pasir (memudar di garis air).
	local duneFade = 1 - smoothstep(-2, 6, s)
	if duneFade > 0 then
		for _, d in T.Dunes do
			local dx, dz = (x - d.X) / d.R, (z - d.Z) / d.R
			local q = dx * dx + dz * dz
			if q < 1 then
				h += d.H * (1 - q) * (1 - q) * duneFade
			end
		end
	end

	-- Tanjung batu timur (tebing naik dari garis air ke dataran mercusuar).
	do
		local cdx, cdz = (x - CA.X) / CA.RX, (z - CA.Z) / CA.RZ
		local cd = math.sqrt(cdx * cdx + cdz * cdz)
		if cd < 1 then
			local cm = 1 - smoothstep(0.55, 1.0, cd)
			if s < 0 then
				local u = -s
				local hc = CA.Base + (CA.Top - CA.Base) * smoothstep(0, CA.Rise, u)
				hc += math.noise(x / 9, z / 9, NZ[12]) * 1.6
				h = lerp(h, math.max(h, hc), cm)
				if cm > 0.35 then
					local r = math.noise(x / 16, z / 16, NZ[13])
					if u > CA.Rise + 2 and r > -0.05 and cm > 0.6 then
						mat = if r > 0.25 then M.LeafyGrass else M.Grass
					elseif r > 0.2 then
						mat = M.Slate
					elseif r < -0.22 then
						mat = M.Basalt
					else
						mat = M.Rock
					end
				end
			else
				h -= 3 * smoothstep(0, 18, s) * cm
				if cm > 0.4 and s < 40 then
					mat = M.Rock
				end
			end
		end
	end

	-- Area rata (plaza, spawn, pondok riset).
	for _, p in T.Pads do
		local dx, dz = (x - p.X) / p.RX, (z - p.Z) / p.RZ
		local d = math.sqrt(dx * dx + dz * dz)
		local w = 1 - smoothstep(1, 1 + p.Blend / ((p.RX + p.RZ) * 0.5), d)
		if w > 0 then
			h = lerp(h, p.Y, w)
		end
	end

	-- Pasar pantai berdiri di atas pasir.
	do
		local ps = T.PlazaSand
		local dx, dz = (x - ps.X) / ps.RX, (z - ps.Z) / ps.RZ
		local q = dx * dx + dz * dz
		if q < 1 and (mat == M.Grass or mat == M.LeafyGrass) then
			if q < 0.75 or math.noise(x / 12, z / 12, NZ[14]) > (q - 0.75) * 4 - 0.5 then
				mat = M.Sand
			end
		end
	end

	-- Laguna bakau: cekungan dangkal −2..−6 dengan tepi lumpur.
	do
		local dx, dz = (x - LA.X) / LA.RX, (z - LA.Z) / LA.RZ
		local ld = math.sqrt(dx * dx + dz * dz)
		if ld < 2 then
			ld *= 1 + LA.NoiseAmp * math.noise(x / 22, z / 22, NZ[15]) * 2
			local lag: number
			if ld < 1 then
				lag = LA.BedEdge + (LA.BedCenter - LA.BedEdge) * (1 - ld * ld)
			else
				local r = (ld - 1) * LA.AvgR
				lag = LA.BedEdge
					+ (LA.MudTop - LA.BedEdge) * smoothstep(0, LA.MudWidth, r)
					+ (LA.BankTop - LA.MudTop) * smoothstep(LA.MudWidth, LA.MudWidth + LA.BankWidth, r)
			end
			if lag < h then
				h = lag
				mat = if ld < 1 or h < 1.4 then M.Mud else M.LeafyGrass
			end
		end
	end

	-- Kanal sempit laguna → laut.
	do
		local dc = distToPolyline(x, z, canalPts)
		if dc < CN.HalfWidth + CN.Bank then
			local ch = CN.Bed + (CN.BankTop - CN.Bed) * smoothstep(CN.HalfWidth, CN.HalfWidth + CN.Bank, dc)
			if ch < h then
				h = ch
				mat = if s > 0 then M.Sand elseif h < 0.8 then M.Mud else M.Sand
			end
		end
	end

	-- Pulau lumpur kecil di laguna.
	do
		local I = T.Islet
		local dx, dz = x - I.X, z - I.Z
		local id = math.sqrt(dx * dx + dz * dz) / I.R
		if id < 1.6 then
			local ih = I.H - (I.H + 3) * smoothstep(0.35, 1.6, id)
			if ih > h then
				h = ih
				mat = M.Mud
			end
		end
	end

	if h < T.SeaFloor then
		h = T.SeaFloor
	elseif h > 30 then
		h = 30
	end
	return h, mat
end

-- Z garis pantai selatan pada X tertentu (perkiraan; untuk meletakkan benda di tepi air).
function Terrain.ShoreZ(x: number): number
	return shoreZ(x)
end

-- Cari Z di sepanjang X di mana tinggi tanah = target (pencarian maju dari z0 ke z1).
function Terrain.FindZForHeight(x: number, target: number, z0: number, z1: number): number
	local step = if z1 > z0 then 0.5 else -0.5
	local prevZ = z0
	local prevH = Terrain.HeightAt(x, z0)
	local z = z0 + step
	while (step > 0 and z <= z1) or (step < 0 and z >= z1) do
		local h = Terrain.HeightAt(x, z)
		if (prevH - target) * (h - target) <= 0 then
			local span = h - prevH
			local t = if math.abs(span) > 1e-6 then (target - prevH) / span else 0
			return prevZ + (z - prevZ) * t
		end
		prevZ, prevH = z, h
		z += step
	end
	return z1
end

local function applyAppearance(terrain: Terrain)
	local W = T.Water
	terrain.WaterColor = W.Color
	terrain.WaterTransparency = W.Transparency
	terrain.WaterReflectance = W.Reflectance
	terrain.WaterWaveSize = W.WaveSize
	terrain.WaterWaveSpeed = W.WaveSpeed
	for _, mc in T.MaterialColors do
		terrain:SetMaterialColor(mc.Material, mc.Color)
	end
	local cfgClouds = T.Clouds
	local found = terrain:FindFirstChildOfClass("Clouds")
	if found then
		found.Cover = cfgClouds.Cover
		found.Density = cfgClouds.Density
		found.Color = cfgClouds.Color
		found.Enabled = true
	else
		local clouds = Instance.new("Clouds")
		clouds.Cover = cfgClouds.Cover
		clouds.Density = cfgClouds.Density
		clouds.Color = cfgClouds.Color
		clouds.Enabled = true
		clouds.Parent = terrain
	end
end

type Grid3<V> = { { { V } } }

-- Susun kanal voxel (resolusi 4) untuk satu chunk dari tinggi kolom.
local function buildChannels(
	heights: { number },
	mats: { Enum.Material },
	nx: number,
	ny: number,
	nz: number,
	y0: number
): (Grid3<Enum.Material>, Grid3<number>, Grid3<number>)
	local solidMat: Grid3<Enum.Material> = table.create(nx)
	local solidOcc: Grid3<number> = table.create(nx)
	local liquid: Grid3<number> = table.create(nx)
	for ix = 1, nx do
		local mx: { { Enum.Material } } = table.create(ny)
		local ox: { { number } } = table.create(ny)
		local lx: { { number } } = table.create(ny)
		for iy = 1, ny do
			local bottom = y0 + (iy - 1) * RES
			local underwater = bottom + RES <= 0
			local my: { Enum.Material } = table.create(nz)
			local oy: { number } = table.create(nz)
			local ly: { number } = table.create(nz)
			for iz = 1, nz do
				local idx = (ix - 1) * nz + iz
				local occ = (heights[idx] - bottom) / RES
				if occ >= 1 then
					my[iz] = mats[idx]
					oy[iz] = 1
					ly[iz] = 0
				elseif occ > 0 then
					my[iz] = mats[idx]
					oy[iz] = occ
					ly[iz] = if underwater then 1 - occ else 0
				else
					my[iz] = M.Air
					oy[iz] = 0
					ly[iz] = if underwater then 1 else 0
				end
			end
			mx[iy] = my
			ox[iy] = oy
			lx[iy] = ly
		end
		solidMat[ix] = mx
		solidOcc[ix] = ox
		liquid[ix] = lx
	end
	return solidMat, solidOcc, liquid
end

-- Cadangan WriteVoxels: sel permukaan bawah air dibulatkan (padat penuh atau air) agar tidak ada kantong udara.
local function buildLegacy(
	solidMat: Grid3<Enum.Material>,
	solidOcc: Grid3<number>,
	liquid: Grid3<number>,
	nx: number,
	ny: number,
	nz: number
): (Grid3<Enum.Material>, Grid3<number>)
	local materials: Grid3<Enum.Material> = table.create(nx)
	local occupancy: Grid3<number> = table.create(nx)
	for ix = 1, nx do
		local mx: { { Enum.Material } } = table.create(ny)
		local ox: { { number } } = table.create(ny)
		for iy = 1, ny do
			local my: { Enum.Material } = table.create(nz)
			local oy: { number } = table.create(nz)
			for iz = 1, nz do
				local occ = solidOcc[ix][iy][iz]
				local liq = liquid[ix][iy][iz]
				if occ >= 1 then
					my[iz] = solidMat[ix][iy][iz]
					oy[iz] = 1
				elseif occ > 0 and liq > 0 then
					if occ >= 0.5 then
						my[iz] = solidMat[ix][iy][iz]
						oy[iz] = 1
					else
						my[iz] = M.Water
						oy[iz] = 1
					end
				elseif occ > 0 then
					my[iz] = solidMat[ix][iy][iz]
					oy[iz] = occ
				elseif liq > 0 then
					my[iz] = M.Water
					oy[iz] = 1
				else
					my[iz] = M.Air
					oy[iz] = 0
				end
			end
			mx[iy] = my
			ox[iy] = oy
		end
		materials[ix] = mx
		occupancy[ix] = ox
	end
	return materials, occupancy
end

-- Titik darat untuk verifikasi baca-ulang (titik dengan tinggi rancangan ≤ 1,5 dilewati).
local CHECK_POINTS: { Vector2 } = {
	Vector2.new(0, 0),
	Vector2.new(0, 48),
	Vector2.new(-32, -16),
	Vector2.new(60, 40),
	Vector2.new(-60, 60),
	Vector2.new(220, 180),
}

-- Baca ulang kolom voxel di titik darat: padatan di atas y=0 harus ≈ tinggi rancangan dan tidak ada air di atas
-- permukaan laut. Mengembalikan (titik bermasalah, ringkasan per titik).
local function verify(terrain: Terrain): ({ string }, { string })
	local problems: { string } = {}
	local report: { string } = {}
	for _, p in CHECK_POINTS do
		local h = Terrain.HeightAt(p.X, p.Y)
		if h > 1.5 then
			local x0 = math.floor(p.X / RES) * RES
			local z0 = math.floor(p.Y / RES) * RES
			local top = (math.ceil(h / RES) + 2) * RES
			local region = Region3.new(Vector3.new(x0, 0, z0), Vector3.new(x0 + RES, top, z0 + RES))
			local ok, data = pcall(function(): ...any
				return terrain:ReadVoxelChannels(region, RES, { "SolidOccupancy", "LiquidOccupancy" })
			end)
			if ok and type(data) == "table" then
				local d = data :: any
				local solid, liquid = 0, 0
				for iy = 1, (d.Size :: Vector3).Y do
					solid += d.SolidOccupancy[1][iy][1] * RES
					liquid += d.LiquidOccupancy[1][iy][1] * RES
				end
				local label = string.format("(%d,%d)", p.X, p.Y)
				table.insert(report, string.format("%s rancangan %.1f padat %.1f air %.1f", label, h, solid, liquid))
				if math.abs(solid - h) > 2 or liquid > 1 then
					table.insert(problems, label)
				end
			end
		end
	end
	return problems, report
end

-- Verifikasi daratan di titik cek (dipakai Build dan MapBuilder.EnsureTerrain untuk map hasil bake).
-- Mengembalikan (titik bermasalah, ringkasan per titik yang berhasil dibaca).
function Terrain.Verify(terrain: Terrain): ({ string }, { string })
	return verify(terrain)
end

-- Tulis pulau/lereng/laguna per chunk. Mengembalikan (jumlah chunk ditulis, memakai WriteVoxels).
local function writeIsland(terrain: Terrain, forceLegacy: boolean): (number, boolean)
	local floor = T.SeaFloor
	local rmin, rmax = T.RegionMin, T.RegionMax
	local cs, chY = T.ChunkXZ, T.ChunkY
	local nx, ny, nz = cs // RES, chY // RES, cs // RES
	local useLegacy = forceLegacy
	local written = 0
	local x0 = rmin.X
	while x0 + cs <= rmax.X do
		local z0 = rmin.Z
		while z0 + cs <= rmax.Z do
			local y0 = rmin.Y
			local heights: { number } = table.create(nx * nz)
			local mats: { Enum.Material } = table.create(nx * nz)
			local maxH = -math.huge
			for ix = 1, nx do
				for iz = 1, nz do
					local h, m = Terrain.HeightAt(x0 + (ix - 0.5) * RES, z0 + (iz - 0.5) * RES)
					local idx = (ix - 1) * nz + iz
					heights[idx] = h
					mats[idx] = m
					if h > maxH then
						maxH = h
					end
				end
			end
			-- Chunk laut dalam (seluruhnya −60) sudah benar dari FillBlock → lewati.
			if maxH > floor + 0.05 then
				local region = Region3.new(Vector3.new(x0, y0, z0), Vector3.new(x0 + cs, y0 + chY, z0 + cs))
					:ExpandToGrid(RES)
				local solidMat, solidOcc, liquid = buildChannels(heights, mats, nx, ny, nz, y0)
				local done = false
				if not useLegacy then
					local channels: { [string]: any } = {
						SolidMaterial = solidMat,
						SolidOccupancy = solidOcc,
						LiquidOccupancy = liquid,
					}
					local function writeChannels(): ...any
						terrain:WriteVoxelChannels(region, RES, channels)
						return true
					end
					local ok, err = pcall(writeChannels)
					if ok then
						done = true
					else
						useLegacy = true
						warn("[Terrain] WriteVoxelChannels gagal, beralih ke WriteVoxels: " .. tostring(err))
					end
				end
				if not done then
					local materials, occupancy = buildLegacy(solidMat, solidOcc, liquid, nx, ny, nz)
					terrain:WriteVoxels(region, RES, materials, occupancy)
				end
				written += 1
				if written % T.WaitEvery == 0 then
					task.wait()
				end
			end
			z0 += cs
		end
		x0 += cs
	end
	return written, useLegacy
end

-- Bangun seluruh terrain. Boleh yield (task.wait) — dipanggil dari task/command bar.
function Terrain.Build(terrain: Terrain): number
	terrain:Clear()
	applyAppearance(terrain)

	-- 1) Dasar pasir di bawah −60 lalu laut besar ±1200 (FillBlock per ubin).
	local half, tile, floor = T.SeaHalf, T.FillTile, T.SeaFloor
	local cx = -half + tile / 2
	while cx < half do
		local cz = -half + tile / 2
		while cz < half do
			terrain:FillBlock(
				CFrame.new(cx, floor - T.BaseThickness / 2, cz),
				Vector3.new(tile, T.BaseThickness, tile),
				M.Sand
			)
			terrain:FillBlock(CFrame.new(cx, floor / 2, cz), Vector3.new(tile, -floor, tile), M.Water)
			cz += tile
		end
		task.wait()
		cx += tile
	end

	-- 2) Pulau, lereng, laguna per chunk, lalu verifikasi baca-ulang. Pemilik melihat daratan tergenang setelah bake
	-- dari Command Bar (2026-10-16, penyebab belum dipastikan): bila hasil WriteVoxelChannels tidak sesuai
	-- rancangan, pulau ditulis ulang dengan WriteVoxels.
	local written, usedLegacy = writeIsland(terrain, false)
	local problems, report = verify(terrain)
	if #problems > 0 and not usedLegacy then
		warn("[Terrain] daratan tidak sesuai rancangan di " .. table.concat(problems, ", ") .. "; tulis ulang dengan WriteVoxels")
		written = writeIsland(terrain, true)
		problems, report = verify(terrain)
	end
	print("[Terrain] cek darat: " .. table.concat(report, " · "))
	if #problems > 0 then
		warn("[Terrain] daratan masih tidak sesuai rancangan di " .. table.concat(problems, ", "))
	end

	-- 3) Bentuk organik: batu besar & rumpun semak (tanpa part).
	for _, r in T.Rocks do
		local g = Terrain.HeightAt(r.X, r.Z)
		terrain:FillBall(Vector3.new(r.X, g + r.R * r.Lift, r.Z), r.R, r.Material)
	end
	for _, b in T.Bushes do
		local g = Terrain.HeightAt(b.X, b.Z)
		terrain:FillBall(Vector3.new(b.X, g + b.H - b.R * 0.5, b.Z), b.R, M.LeafyGrass)
	end
	task.wait()
	return written
end

return Terrain
