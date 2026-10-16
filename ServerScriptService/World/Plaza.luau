--!strict
-- Pasar Pantai (plaza) di (0, 6, −10): lantai papan elips, lampu taman, umbul-umbul merah putih,
-- gapura selamat datang + SpawnLocation, Papan Pengumuman Pak Lurah, Toko Pancing Pak Darto,
-- Butik Pantai Mbak Sari, Pondok Riset Prof. Mina, dan dua papan peringkat (folder Points).

local MapConfig = require(script.Parent.MapConfig)
local Geo = require(script.Parent.Geo)

local P = MapConfig.Plaza
local C = MapConfig.Colors
local TX = MapConfig.Text
local MAT = Enum.Material
local UP = Vector3.yAxis
local PERSISTENT = Enum.ModelStreamingMode.Persistent

local Plaza = {}

local function at(cf: CFrame, x: number, y: number, z: number): Vector3
	return (cf * CFrame.new(x, y, z)).Position
end

local function ellipsePoint(deg: number, scale: number, y: number): Vector3
	local a = math.rad(deg)
	return Vector3.new(P.Center.X + P.RX * scale * math.cos(a), y, P.Center.Z + P.RZ * scale * math.sin(a))
end

local function angleDiff(a: number, b: number): number
	local d = (a - b) % 360
	return math.min(d, 360 - d)
end

local function nearExit(deg: number): boolean
	for _, e in P.Exits do
		if angleDiff(deg, e) < P.ExitHalfAngle then
			return true
		end
	end
	return false
end

-- Atap pelana dari dua papan miring + bubungan silinder. `cf` = pusat bubungan (X lokal = panjang).
local function gableRoof(
	parent: Instance,
	cf: CFrame,
	length: number,
	halfDepth: number,
	drop: number,
	color: Color3,
	material: Enum.Material
)
	for _, side in { -1, 1 } do
		local a = at(cf, -length / 2, -drop / 2, side * halfDepth / 2)
		local b = at(cf, length / 2, -drop / 2, side * halfDepth / 2)
		local slope = (at(cf, 0, -drop, side * halfDepth) - at(cf, 0, 0, 0)).Unit
		local nrm = (cf:VectorToWorldSpace(Vector3.xAxis)):Cross(slope) * -side
		Geo.Plank(
			parent,
			a,
			b,
			math.sqrt(halfDepth * halfDepth + drop * drop) + 0.2,
			0.2,
			nrm,
			color,
			material,
			{ Shadow = true }
		)
	end
	Geo.Cylinder(parent, cf, length + 0.3, 0.35, C.WoodDark, MAT.Wood, { Shadow = false })
end

-- ===================================================================== lantai & tepi

local function buildDeck(model: Model, rng: Random)
	local cx, cz = P.Center.X, P.Center.Z
	local pitch = P.PlankWidth + P.PlankGap
	local rows = math.floor(2 * P.RZ / pitch)
	local z0 = cz - rows * pitch / 2 + pitch / 2
	for r = 0, rows - 1 do
		local z = z0 + r * pitch
		local q = 1 - ((z - cz) / P.RZ) ^ 2
		if q > 0.01 then
			local half = P.RX * math.sqrt(q)
			local x = cx - half
			local xEnd = cx + half
			local len = rng:NextNumber(4, P.PlankMaxLength)
			while x < xEnd - 0.5 do
				local x1 = math.min(xEnd, x + len)
				local w = x1 - x - P.PlankGap
				if w > 0.8 then
					local thick = P.PlankThickness + rng:NextNumber(-0.03, 0.03)
					local top = P.FloorY + rng:NextNumber(-0.02, 0.025)
					local col = if rng:NextNumber() < 0.55 then C.WoodDeck else C.WoodDeckAlt
					Geo.Block(
						model,
						CFrame.new((x + x1 - P.PlankGap) / 2, top - thick / 2, z),
						Vector3.new(w, thick, P.PlankWidth),
						col,
						MAT.Wood,
						{ Collide = true, Shadow = false, Jitter = 0.05 }
					)
				end
				x = x1
				len = rng:NextNumber(P.PlankMaxLength * 0.65, P.PlankMaxLength)
			end
		end
	end
	-- Balok tepi bulat mengikuti elips (celah di pintu masuk).
	local segs = 24
	for i = 0, segs - 1 do
		local a0 = i / segs * 360
		local a1 = (i + 1) / segs * 360
		if not nearExit((a0 + a1) / 2) then
			Geo.Segment(
				model,
				ellipsePoint(a0, 1.006, P.FloorY - 0.38),
				ellipsePoint(a1, 1.006, P.FloorY - 0.38),
				0.9,
				C.WoodPost,
				MAT.Wood,
				{ Extend = 0.35, Shadow = false }
			)
		end
	end
end

-- ===================================================================== spawn & gapura

local function buildSpawn(ctx: Geo.Context, model: Model)
	local S = P.Spawn
	local g = Geo.GroundY(S.Pos.X, S.Pos.Z) - 0.3
	local base = Vector3.new(S.Pos.X, 0, S.Pos.Z)
	Geo.Disk(
		model,
		base + Vector3.new(0, (S.RingTop + g) / 2, 0),
		S.RingTop - g,
		S.RingRadius * 2,
		C.WoodDeckAlt,
		MAT.WoodPlanks,
		{ Collide = true }
	)
	Geo.Disk(
		model,
		base + Vector3.new(0, (S.DaisTop + g) / 2, 0),
		S.DaisTop - g,
		S.DaisRadius * 2,
		C.WoodDeck,
		MAT.WoodPlanks,
		{ Collide = true }
	)
	-- Inlay kompas: dua cakram tipis berbeda warna sedikit di atas dais (tanpa bidang sebidang).
	Geo.Disk(
		model,
		base + Vector3.new(0, S.DaisTop + 0.03, 0),
		0.06,
		9.2,
		C.WoodDeckAlt,
		MAT.WoodPlanks,
		{ Shadow = false, Jitter = 0 }
	)
	Geo.Disk(
		model,
		base + Vector3.new(0, S.DaisTop + 0.07, 0),
		0.06,
		1.8,
		C.WoodDark,
		MAT.Wood,
		{ Shadow = false, Jitter = 0 }
	)
	-- Tonggak kecil di cincin bawah.
	for i = 0, 7 do
		local a = (i + 0.5) / 8 * math.pi * 2
		if math.sin(a) < 0.6 then
			local p = base + Vector3.new(math.cos(a), 0, math.sin(a)) * (S.RingRadius - 0.55)
			Geo.Post(model, Vector3.new(p.X, S.RingTop - 0.2, p.Z), 1.3, 0.5, C.WoodPost, MAT.Wood, { Shadow = false })
		end
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = S.Size
	spawn.CFrame = Geo.Facing(S.Pos, Vector3.zAxis)
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Enabled = true
	spawn.AllowTeamChangeOnTouch = false
	spawn.Transparency = 1
	spawn.CanCollide = true
	spawn.CanTouch = false
	spawn.CastShadow = false
	spawn.Material = MAT.WoodPlanks
	spawn.Color = C.WoodDeck
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.BottomSurface = Enum.SurfaceType.Smooth
	spawn.Parent = ctx.Root

	-- Gapura bambu "Selamat Datang" (menghadap spawn) dengan janur kuning.
	local A = P.Arch
	local postH = A.PostHeight
	for _, sx in { -1, 1 } do
		local x = sx * A.HalfSpan
		Geo.Post(model, Vector3.new(x, P.FloorY - 0.5, A.Z), postH + 0.5, 0.95, C.Bamboo, MAT.Wood, { Collide = true })
		for k = 1, 3 do
			Geo.Disk(
				model,
				Vector3.new(x, P.FloorY + k * 3.6, A.Z),
				0.22,
				1.05,
				C.BambooDark,
				MAT.Wood,
				{ Shadow = false }
			)
		end
		Geo.Ball(model, Vector3.new(x, P.FloorY + postH + 0.35, A.Z), 1.05, C.BambooDark, MAT.Wood, { Shadow = false })
		-- janur: dua untai melengkung tergantung dari puncak tiang
		for _, dz in { -0.55, 0.55 } do
			local top = Vector3.new(x + sx * 0.4, P.FloorY + postH - 0.2, A.Z + dz)
			local pts =
				Geo.Bezier2(top, top + Vector3.new(sx * 1.6, 0.6, dz * 0.6), top + Vector3.new(sx * 1.2, -4.2, dz), 2)
			for i = 1, #pts - 1 do
				Geo.Tip(
					model,
					pts[i],
					pts[i + 1],
					if i == 1 then 0.55 else 0.45,
					0.06,
					Vector3.new(0, 0, 1),
					MapConfig.Colors.PalmLeafDry,
					MAT.SmoothPlastic,
					{ Shadow = false }
				)
			end
		end
	end
	local beamY = P.FloorY + postH - 0.6
	local arc = Geo.Bezier2(
		Vector3.new(-A.HalfSpan - 0.9, beamY, A.Z),
		Vector3.new(0, beamY + 2.6, A.Z),
		Vector3.new(A.HalfSpan + 0.9, beamY, A.Z),
		4
	)
	Geo.Chain(model, arc, 0.8, 0.8, C.Bamboo, MAT.Wood, { Shadow = true })
	local signCenter = Vector3.new(0, A.SignBottom + A.SignSize.Y / 2, A.Z)
	Geo.Sign(
		model,
		Geo.Facing(signCenter, Vector3.new(0, 0, -1)),
		A.SignSize,
		TX.Welcome,
		{ MaxTextSize = 64, PixelsPerStud = 36 }
	)
	for _, sx in { -1, 1 } do
		local x = sx * 4.9
		local t = (x + A.HalfSpan + 0.9) / (2 * (A.HalfSpan + 0.9))
		local yBeam = beamY + 2.6 * 2 * t * (1 - t)
		Geo.Segment(
			model,
			Vector3.new(x, A.SignBottom + A.SignSize.Y - 0.1, A.Z),
			Vector3.new(x, yBeam, A.Z),
			0.12,
			C.Rope,
			MAT.Fabric,
			{ Shadow = false }
		)
	end
end

-- ===================================================================== lampu, tiang bendera, umbul-umbul

local function buildLampsAndBunting(model: Model)
	local tops: { Vector3 } = {}
	for _, deg in P.LampAngles do
		local base = ellipsePoint(deg, 0.94, P.FloorY)
		table.insert(tops, Geo.LampPost(model, base, P.LampHeight))
	end

	local F = P.Flagpole
	Geo.Disk(model, F.Pos + Vector3.new(0, 0.3, 0), 0.6, 2.6, C.Stone, MAT.Slate, { Collide = true })
	local pole =
		Geo.Post(model, F.Pos - Vector3.new(0, 0.4, 0), F.Height + 0.4, 0.45, C.White, MAT.Metal, { Collide = true })
	local top = F.Pos + Vector3.new(0, F.Height, 0)
	Geo.Ball(model, top + Vector3.new(0, 0.35, 0), 0.7, C.Yellow, MAT.Metal, { Shadow = false })
	-- Sang Merah Putih (sedikit berkibar: dua bilah berputar halus)
	local flagCF = CFrame.new(top + Vector3.new(2.35, -1.6, 0)) * CFrame.Angles(0, math.rad(8), 0)
	Geo.Block(
		model,
		flagCF * CFrame.new(0, 0.7, 0),
		Vector3.new(4.2, 1.4, 0.08),
		C.FlagRed,
		MAT.Fabric,
		{ Shadow = false, Jitter = 0 }
	)
	Geo.Block(
		model,
		flagCF * CFrame.new(0, -0.7, 0),
		Vector3.new(4.2, 1.4, 0.08),
		C.FlagWhite,
		MAT.Fabric,
		{ Shadow = false, Jitter = 0 }
	)

	-- Tali umbul-umbul (Beam) dari puncak tiang ke lampu terpilih + bendera segitiga merah/putih.
	local anchor = top - Vector3.new(0, 0.6, 0)
	for _, idx in P.BuntingLamps do
		local lampTop = tops[idx]
		if lampTop then
			local sag = 2.6
			local a0 = Geo.Attach(pole, anchor)
			local a1 = Geo.Attach(pole, lampTop)
			Geo.Rope(a0, a1, sag, 0.12, C.Rope)
			local n = P.BuntingFlags
			for k = 1, n do
				local t = (k - 0.35) / (n + 0.4)
				local p = Geo.RopePoint(anchor, lampTop, sag, t)
				local p2 = Geo.RopePoint(anchor, lampTop, sag, math.min(1, t + 0.02))
				local tangent = Geo.Flat(p2 - p)
				tangent = if tangent.Magnitude > 1e-4 then tangent.Unit else Vector3.xAxis
				Geo.Triangle(
					model,
					p - tangent * 0.62,
					p + tangent * 0.62,
					p + Vector3.new(0, -1.5, 0),
					0.06,
					if k % 2 == 1 then C.FlagRed else C.FlagWhite,
					MAT.Fabric,
					{ Shadow = false, Jitter = 0.02 }
				)
			end
		end
	end
end

-- ===================================================================== papan pengumuman

local function buildBoard(ctx: Geo.Context, model: Model)
	local B = P.Board
	local cf = Geo.Facing(B.Pos, B.Face)
	for _, sx in { -1, 1 } do
		Geo.Post(model, at(cf, sx * 4.3, -0.5, 0), 5.9, 0.55, C.WoodPost, MAT.Wood, { Collide = true })
	end
	Geo.Block(
		model,
		cf * CFrame.new(0, 2.85, 0),
		Vector3.new(8.2, 3.3, 0.35),
		C.WoodDeck,
		MAT.WoodPlanks,
		{ Collide = true }
	)
	-- Kertas pengumuman (sedikit di depan papan, miring tangan)
	local papers = {
		{ X = -2.6, Y = 3.2, Color = C.Fabric },
		{ X = -0.5, Y = 2.6, Color = C.White },
		{ X = 1.8, Y = 3.1, Color = C.FabricShade },
		{ X = 3.0, Y = 2.1, Color = C.Fabric },
	}
	for i, pp in papers do
		Geo.Block(
			model,
			cf * CFrame.new(pp.X, pp.Y, -0.2) * CFrame.Angles(0, 0, math.rad(if i % 2 == 0 then 4 else -3)),
			Vector3.new(1.5, 1.9, 0.05),
			pp.Color,
			MAT.SmoothPlastic,
			{ Shadow = false }
		)
	end
	Geo.Sign(model, cf * CFrame.new(0, 4.95, -0.05), Vector3.new(8.6, 0.95, 0.3), TX.Board, { MaxTextSize = 40 })
	gableRoof(model, cf * CFrame.new(0, 6.1, 0), 9.6, 1.25, 0.75, C.Thatch, MAT.Grass)
	ctx.Npc.pak_lurah = Geo.Facing(P.LurahSpot.Pos, P.LurahSpot.Face)
end

-- ===================================================================== kios

local function kioskPosts(model: Model, cf: CFrame, hx: number, hz: number, front: number, back: number)
	for _, sx in { -1, 1 } do
		Geo.Post(model, at(cf, sx * hx, -0.4, -hz), front + 0.4, 0.7, C.Bamboo, MAT.Wood, { Collide = true })
		Geo.Post(model, at(cf, sx * hx, -0.4, hz), back + 0.4, 0.7, C.Bamboo, MAT.Wood, { Collide = true })
	end
end

local function buildToko(ctx: Geo.Context, root: Model)
	local K = P.Toko
	local model = Geo.Model(root, "TokoPancing", PERSISTENT)
	local cf = Geo.Facing(K.Pos, K.Face)
	kioskPosts(model, cf, 5.6, 3.4, 11.4, 9.9)
	-- Atap terpal miring dua bidang (melendut) + tepi bergelombang (cakram di balik valance).
	local xv = cf:VectorToWorldSpace(Vector3.xAxis)
	local backTop, mid, frontEdge = at(cf, 0, 10.0, 3.95), at(cf, 0, 9.42, 0), at(cf, 0, 8.35, -4.25)
	for _, seg in { { backTop, mid }, { mid, frontEdge } } do
		local d = seg[2] - seg[1]
		Geo.Plank(
			model,
			seg[1],
			seg[2],
			12.9,
			0.14,
			d:Cross(xv) * -1,
			C.Tarp,
			MAT.Fabric,
			{ Shadow = true, Extend = 0.08 }
		)
	end
	Geo.Block(
		model,
		cf * CFrame.new(0, 7.88, -4.25),
		Vector3.new(12.9, 0.9, 0.1),
		C.Tarp,
		MAT.Fabric,
		{ Shadow = false }
	)
	for k = 0, 5 do
		local x = -5.35 + k * 2.14
		Geo.Cylinder(
			model,
			cf * CFrame.new(x, 7.43, -4.15) * CFrame.Angles(0, math.pi / 2, 0),
			0.08,
			2.0,
			if k % 2 == 0 then C.Tarp else C.White,
			MAT.Fabric,
			{ Shadow = false }
		)
	end
	-- Meja jual
	Geo.Block(
		model,
		cf * CFrame.new(0, 1.5, -2.6),
		Vector3.new(11, 3.0, 1.6),
		C.WoodDeckAlt,
		MAT.WoodPlanks,
		{ Collide = true }
	)
	Geo.Block(
		model,
		cf * CFrame.new(0, 3.15, -2.6),
		Vector3.new(11.6, 0.3, 2.1),
		C.WoodDark,
		MAT.Wood,
		{ Collide = true }
	)
	for _, x in { -4.5, 0, 4.5 } do
		Geo.Block(
			model,
			cf * CFrame.new(x, 1.5, -3.45),
			Vector3.new(0.5, 2.8, 0.1),
			C.Tarp,
			MAT.Wood,
			{ Shadow = false }
		)
	end
	-- Dinding anyaman belakang + rak & kotak umpan
	Geo.Block(
		model,
		cf * CFrame.new(0, 3.9, 3.75),
		Vector3.new(11.2, 7.6, 0.16),
		C.Woven,
		MAT.Fabric,
		{ Collide = true }
	)
	local boxColors = { C.Tarp, C.WoodLight, C.Red, C.FabricShade, C.Teal, C.Yellow }
	for i, y in { 3.6, 5.6 } do
		Geo.Block(
			model,
			cf * CFrame.new(0, y, 3.15),
			Vector3.new(10, 0.2, 1.0),
			C.WoodDark,
			MAT.Wood,
			{ Shadow = false }
		)
		for k = 0, 2 do
			local col = boxColors[(i - 1) * 3 + k + 1]
			Geo.Block(
				model,
				cf
					* CFrame.new(-3.2 + k * 3.1 + Geo.Rand(-0.4, 0.4), y + 0.42, 3.1)
					* CFrame.Angles(0, math.rad(Geo.Rand(-8, 8)), 0),
				Vector3.new(1.1, 0.64, 0.7),
				col,
				MAT.SmoothPlastic,
				{ Shadow = false }
			)
		end
	end
	-- Papan nama di atas tepi depan (ditopang tiang depan)
	Geo.Sign(model, cf * CFrame.new(0, 10.55, -3.55), Vector3.new(9, 1.5, 0.3), TX.FishingShop, { MaxTextSize = 56 })
	-- Lentera gantung
	Geo.Segment(model, at(cf, 0, 9.3, -1.2), at(cf, 0, 8.5, -1.2), 0.08, C.MetalDark, MAT.Metal, { Shadow = false })
	Geo.Lantern(model, at(cf, 0, 7.95, -1.2), 0.9, false, 16)

	-- Rak joran di samping kanan (lokal +X)
	for _, z in { -1.3, 1.3 } do
		Geo.Post(model, at(cf, 7.4, -0.3, z), 5.9, 0.35, C.WoodPost, MAT.Wood, { Collide = true })
	end
	Geo.Segment(model, at(cf, 7.4, 5.0, -1.6), at(cf, 7.4, 5.0, 1.6), 0.28, C.WoodDark, MAT.Wood, { Shadow = false })
	Geo.Segment(model, at(cf, 6.9, 0.55, -1.6), at(cf, 6.9, 0.55, 1.6), 0.28, C.WoodDark, MAT.Wood, { Shadow = false })
	local rodColors = { C.Bamboo, C.TarpLight, C.MetalDark, C.Teal, C.Yellow }
	for k = 1, 5 do
		local z = -1.2 + (k - 1) * 0.6
		local foot = at(cf, 6.75, 0.25, z)
		local tip = at(cf, 7.65 + Geo.Rand(0, 0.3), 9.2 + Geo.Rand(-0.5, 0.4), z + Geo.Rand(-0.25, 0.25))
		Geo.Segment(model, foot, tip, 0.16, rodColors[k], MAT.SmoothPlastic, { Shadow = false })
		if k % 2 == 1 then
			local reel = foot + (tip - foot).Unit * 1.6
			Geo.Cylinder(
				model,
				Geo.AlongX(reel, cf:VectorToWorldSpace(Vector3.zAxis)),
				0.3,
				0.55,
				C.MetalDark,
				MAT.Metal,
				{ Shadow = false }
			)
		end
	end
	-- Tong umpan di samping kiri (lokal −X) + papan "UMPAN"
	local contents = { C.WoodDark, C.Pink, C.FabricShade }
	local spots = { { -7.5, -1.5, 2.1, 2.5 }, { -7.7, 1.0, 1.8, 2.1 }, { -9.4, -0.3, 1.6, 1.9 } }
	for i, s in spots do
		Geo.Barrel(model, at(cf, s[1], 0, s[2]), s[3], s[4], if i == 2 then C.Tarp else C.WoodDeck, contents[i])
	end
	Geo.Post(model, at(cf, -8.6, -0.3, -2.9), 3.6, 0.22, C.WoodPost, MAT.Wood, { Shadow = false })
	Geo.Sign(model, cf * CFrame.new(-8.6, 3.0, -3.0), Vector3.new(2.8, 0.9, 0.18), TX.Bait, { MaxTextSize = 36 })

	ctx.Npc.pak_darto = cf * CFrame.new(0, 0, -0.6)
end

local function buildButik(ctx: Geo.Context, root: Model)
	local K = P.Butik
	local model = Geo.Model(root, "ButikPantai", PERSISTENT)
	local cf = Geo.Facing(K.Pos, K.Face)
	-- Meja + papan nama di muka meja
	Geo.Block(
		model,
		cf * CFrame.new(1.5, 1.4, -2.4),
		Vector3.new(8, 2.8, 1.6),
		C.White,
		MAT.WoodPlanks,
		{ Collide = true }
	)
	Geo.Block(
		model,
		cf * CFrame.new(1.5, 2.95, -2.4),
		Vector3.new(8.6, 0.3, 2.1),
		C.WoodLight,
		MAT.Wood,
		{ Collide = true }
	)
	Geo.Sign(
		model,
		cf * CFrame.new(1.5, 1.45, -3.27),
		Vector3.new(7.4, 1.6, 0.12),
		TX.Boutique,
		{ Board = C.LeaderBoard, MaxTextSize = 48 }
	)
	-- Kain pantai terlipat di meja
	local folds = { C.Pink, C.Teal, C.Yellow }
	for i, col in folds do
		Geo.Block(
			model,
			cf * CFrame.new(-0.6 + i * 0.25, 3.2 + i * 0.19, -2.3) * CFrame.Angles(0, math.rad(Geo.Rand(-10, 10)), 0),
			Vector3.new(1.7, 0.18, 1.1),
			col,
			MAT.Fabric,
			{ Shadow = false }
		)
	end
	-- Dua payung warna-warni sebagai atap
	Geo.Umbrella(model, at(cf, -3.0, 0, 0.6), {
		Height = 8.8,
		Radius = 5.6,
		Panels = 8,
		Colors = { C.Pink, C.White },
		Tilt = cf:VectorToWorldSpace(Vector3.new(0.05, 0, -0.04)),
	})
	Geo.Umbrella(model, at(cf, 3.6, 0, 1.3), {
		Height = 8.1,
		Radius = 5.0,
		Panels = 8,
		Colors = { C.Teal, C.White },
		Tilt = cf:VectorToWorldSpace(Vector3.new(-0.04, 0, -0.05)),
	})
	-- Pajangan topi: caping bertingkat & topi jerami
	local s1 = at(cf, -4.6, 0, -2.6)
	Geo.Disk(model, s1 + Vector3.new(0, 0.1, 0), 0.2, 1.4, C.WoodDark, MAT.Wood, { Shadow = false })
	Geo.Post(model, s1, 3.6, 0.22, C.WoodDark, MAT.Wood, { Shadow = false })
	for k, d in { 2.4, 1.6, 0.8 } do
		Geo.Disk(model, s1 + Vector3.new(0, 3.62 + (k - 1) * 0.2, 0), 0.22, d, C.Thatch, MAT.Grass, { Shadow = false })
	end
	local s2 = at(cf, -2.0, 0, -3.5)
	Geo.Disk(model, s2 + Vector3.new(0, 0.1, 0), 0.2, 1.4, C.WoodDark, MAT.Wood, { Shadow = false })
	Geo.Post(model, s2, 3.1, 0.22, C.WoodDark, MAT.Wood, { Shadow = false })
	Geo.Disk(model, s2 + Vector3.new(0, 3.15, 0), 0.12, 2.3, C.WoodLight, MAT.Fabric, { Shadow = false })
	Geo.Disk(model, s2 + Vector3.new(0, 3.5, 0), 0.62, 1.2, C.WoodLight, MAT.Fabric, { Shadow = false })
	Geo.Disk(model, s2 + Vector3.new(0, 3.3, 0), 0.18, 1.26, C.Red, MAT.Fabric, { Shadow = false })
	-- Gantungan baju
	for _, x in { 3.4, 6.6 } do
		Geo.Post(model, at(cf, x, -0.3, 2.6), 5.4, 0.25, C.WoodDark, MAT.Wood, { Shadow = false })
	end
	Geo.Segment(model, at(cf, 3.2, 4.9, 2.6), at(cf, 6.8, 4.9, 2.6), 0.18, C.WoodDark, MAT.Wood, { Shadow = false })
	local shirts = { C.Pink, C.Teal, C.Yellow, C.TarpLight }
	for k, col in shirts do
		Geo.Block(
			model,
			cf * CFrame.new(3.6 + (k - 1) * 0.95, 3.85, 2.6) * CFrame.Angles(0, math.rad(80 + Geo.Rand(-6, 6)), 0),
			Vector3.new(1.4, 1.9, 0.12),
			col,
			MAT.Fabric,
			{ Shadow = false }
		)
	end
	-- Cermin berdiri
	Geo.Post(model, at(cf, -5.6, -0.2, 1.8), 1.4, 0.3, C.WoodDark, MAT.Wood, { Shadow = false })
	Geo.Ellipsoid(
		model,
		cf * CFrame.new(-5.6, 3.1, 1.8) * CFrame.Angles(0, math.rad(30), 0),
		Vector3.new(1.6, 3.4, 0.14),
		C.Glass,
		MAT.Glass,
		{ Reflectance = 0.5, Shadow = false }
	)

	ctx.Npc.mbak_sari = cf * CFrame.new(1.5, 0, -0.4)
end

local function buildRiset(ctx: Geo.Context, root: Model)
	local K = P.Riset
	local model = Geo.Model(root, "PondokRiset", PERSISTENT)
	local cf = Geo.Facing(K.Pos, K.Face)
	local center = K.Pos
	local R = K.DeckRadius
	-- Dek bundar dari papan + balok tepi
	local pitch = P.PlankWidth + P.PlankGap
	local rows = math.floor(2 * R / pitch)
	for r = 0, rows - 1 do
		local lz = -R + pitch / 2 + r * pitch + (2 * R - rows * pitch) / 2
		local half = math.sqrt(math.max(0, R * R - lz * lz))
		if half > 1 then
			Geo.Block(
				model,
				cf * CFrame.new(0, -0.35 + Geo.Rand(-0.02, 0.02), lz),
				Vector3.new(half * 2, 0.7, P.PlankWidth),
				if r % 2 == 0 then C.WoodDeck else C.WoodDeckAlt,
				MAT.Wood,
				{ Collide = true, Shadow = false, Jitter = 0.05 }
			)
		end
	end
	for i = 0, 9 do
		local a0, a1 = i / 10 * math.pi * 2, (i + 1) / 10 * math.pi * 2
		local amid = (a0 + a1) / 2
		local dirMid = cf:VectorToObjectSpace(Vector3.new(math.cos(amid), 0, math.sin(amid)))
		if dirMid.Z > -0.92 then
			Geo.Segment(
				model,
				center + Vector3.new(math.cos(a0) * (R + 0.05), -0.38, math.sin(a0) * (R + 0.05)),
				center + Vector3.new(math.cos(a1) * (R + 0.05), -0.38, math.sin(a1) * (R + 0.05)),
				0.9,
				C.WoodPost,
				MAT.Wood,
				{ Extend = 0.3, Shadow = false }
			)
		end
	end
	-- Tiang bambu & atap kerucut ijuk (8 panel segitiga)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			Geo.Post(model, at(cf, sx * 4.7, -0.3, sz * 3.7), 8.9, 0.7, C.Bamboo, MAT.Wood, { Collide = true })
		end
	end
	local apex = center + Vector3.new(0, 12.4, 0)
	local rimY = center.Y + 7.6
	for i = 0, 7 do
		local a0, a1 = (i + 0.5) / 8 * math.pi * 2, (i + 1.5) / 8 * math.pi * 2
		Geo.Triangle(
			model,
			apex + Vector3.new(0, 0, 0),
			Vector3.new(center.X + math.cos(a0) * 7.6, rimY, center.Z + math.sin(a0) * 7.6),
			Vector3.new(center.X + math.cos(a1) * 7.6, rimY, center.Z + math.sin(a1) * 7.6),
			0.35,
			if i % 2 == 0 then C.Thatch else C.ThatchDark,
			MAT.Grass,
			{ Shadow = true, Jitter = 0.02 }
		)
	end
	Geo.Post(model, apex - Vector3.new(0, 0.6, 0), 1.6, 0.3, C.WoodDark, MAT.Wood, { Shadow = false })
	Geo.Ball(model, apex + Vector3.new(0, 1.1, 0), 0.7, C.WoodDark, MAT.Wood, { Shadow = false })
	-- Meja kerja + akuarium kaca berisi ikan mini
	Geo.Block(
		model,
		cf * CFrame.new(0, 3.0, -1.6),
		Vector3.new(6.4, 0.3, 2.6),
		C.WoodLight,
		MAT.Wood,
		{ Collide = true }
	)
	for _, sx in { -1, 1 } do
		Geo.Block(
			model,
			cf * CFrame.new(sx * 2.6, 1.4, -1.6),
			Vector3.new(0.4, 2.9, 2.2),
			C.WoodDark,
			MAT.Wood,
			{ Collide = true }
		)
	end
	local tank = cf * CFrame.new(-1.2, 4.2, -1.6)
	Geo.Block(
		model,
		tank * CFrame.new(0, -1.05, 0),
		Vector3.new(3.5, 0.14, 1.6),
		C.MetalDark,
		MAT.Metal,
		{ Shadow = false }
	)
	Geo.Block(
		model,
		tank * CFrame.new(0, 1.05, 0),
		Vector3.new(3.5, 0.12, 1.6),
		C.MetalDark,
		MAT.Metal,
		{ Shadow = false }
	)
	Geo.Block(
		model,
		tank * CFrame.new(0, -0.84, 0),
		Vector3.new(3.2, 0.26, 1.3),
		C.Shell[4],
		MAT.Sand,
		{ Shadow = false }
	)
	for _, dx in { -1.1, 1.0 } do
		Geo.Segment(
			model,
			at(tank, dx, -0.8, 0.2),
			at(tank, dx + 0.2, 0.6, 0.1),
			0.12,
			C.Seaweed,
			MAT.SmoothPlastic,
			{ Shadow = false }
		)
	end
	local fishColors = { { C.Orange, C.White }, { C.Yellow, C.Blue }, { C.Blue, C.Yellow } }
	for i, fc in fishColors do
		local fcf = tank
			* CFrame.new(-1.0 + (i - 1) * 0.95, -0.2 + (i % 2) * 0.45, 0.05 - (i % 2) * 0.25)
			* CFrame.Angles(0, math.rad(i * 40), 0)
		Geo.Fish(model, fcf, 0.75, fc[1], fc[2])
	end
	Geo.Block(
		model,
		tank,
		Vector3.new(3.4, 2.0, 1.5),
		C.Glass,
		MAT.Glass,
		{ Transparency = 0.55, Shadow = false, Jitter = 0 }
	)
	-- Mikroskop, buku catatan, toples spesimen
	local scope = cf * CFrame.new(1.8, 3.15, -1.4)
	Geo.Block(
		model,
		scope * CFrame.new(0, 0.08, 0),
		Vector3.new(0.7, 0.16, 0.55),
		C.MetalDark,
		MAT.Metal,
		{ Shadow = false }
	)
	Geo.Segment(
		model,
		at(scope, 0, 0.1, 0.18),
		at(scope, 0, 1.1, 0.05),
		0.16,
		C.MetalDark,
		MAT.Metal,
		{ Shadow = false }
	)
	Geo.Segment(
		model,
		at(scope, 0, 0.75, -0.25),
		at(scope, 0, 1.45, 0.1),
		0.24,
		C.White,
		MAT.SmoothPlastic,
		{ Shadow = false }
	)
	Geo.Block(
		model,
		cf * CFrame.new(0.4, 3.2, -1.2) * CFrame.Angles(0, math.rad(12), 0),
		Vector3.new(1.0, 0.08, 1.3),
		C.Fabric,
		MAT.SmoothPlastic,
		{ Shadow = false }
	)
	Geo.Block(
		model,
		cf * CFrame.new(0, 1.7, 3.0),
		Vector3.new(4.4, 3.4, 0.9),
		C.WoodDeckAlt,
		MAT.WoodPlanks,
		{ Collide = true }
	)
	local jarColors = { C.Teal, C.Orange, C.Seaweed }
	for k, col in jarColors do
		local jp = at(cf, -1.4 + (k - 1) * 1.4, 3.42, 3.0)
		Geo.Ball(model, jp + Vector3.new(0, 0.32, 0), 0.4, col, MAT.SmoothPlastic, { Shadow = false })
		Geo.Post(model, jp, 0.85, 0.62, C.Glass, MAT.Glass, { Transparency = 0.5, Shadow = false, Jitter = 0 })
	end
	-- Papan nama & lentera
	Geo.Sign(model, cf * CFrame.new(0, 7.3, -4.15), Vector3.new(7.6, 1.2, 0.22), TX.Research, { MaxTextSize = 44 })
	Geo.Segment(
		model,
		apex - Vector3.new(0, 0.6, 0),
		center + Vector3.new(0, 7.75, 0),
		0.08,
		C.MetalDark,
		MAT.Metal,
		{ Shadow = false }
	)
	Geo.Lantern(model, center + Vector3.new(0, 7.25, 0), 0.9, false, 16)
	-- Bangku kecil
	Geo.Post(model, at(cf, -3.4, -0.2, 0.6), 1.8, 1.0, C.WoodDeckAlt, MAT.Wood, { Collide = true })
	-- Titian penghubung ke plaza
	local from = ellipsePoint(157, 1.0, P.FloorY)
	local to = center + (Geo.Flat(from - center).Unit * (R - 0.4))
	local dir = Geo.Flat(to - from)
	local nPl = math.max(2, math.floor(dir.Magnitude / 1.6))
	local side = dir.Unit:Cross(UP)
	for i = 0, nPl - 1 do
		local c0 = from + dir * ((i + 0.5) / nPl) - Vector3.new(0, 0.3, 0)
		Geo.Plank(
			model,
			c0 - side * 2,
			c0 + side * 2,
			1.4,
			0.6,
			UP,
			C.WoodDeck,
			MAT.Wood,
			{ Collide = true, Shadow = false }
		)
	end

	ctx.Npc.prof_mina = cf * CFrame.new(1.4, 0, 0.2)
end

-- ===================================================================== papan peringkat & nama pasar

local function buildLeaderboards(ctx: Geo.Context, model: Model)
	local size = P.LeaderboardSize
	for _, lb in P.Leaderboards do
		local cf = Geo.Facing(lb.Pos, lb.Face)
		local center = cf * CFrame.new(0, P.LeaderboardLift + size.Y / 2, 0)
		Geo.Block(ctx.Points, center, size, C.LeaderBoard, MAT.Wood, { Name = lb.Name, Collide = true, Jitter = 0 })
		for _, sy in { -1, 1 } do
			Geo.Block(
				model,
				center * CFrame.new(0, sy * (size.Y / 2 + 0.2), -0.05),
				Vector3.new(size.X + 0.8, 0.4, size.Z + 0.3),
				C.WoodDark,
				MAT.Wood,
				{ Shadow = false }
			)
		end
		for _, sx in { -1, 1 } do
			Geo.Block(
				model,
				center * CFrame.new(sx * (size.X / 2 + 0.2), 0, -0.05),
				Vector3.new(0.4, size.Y, size.Z + 0.3),
				C.WoodDark,
				MAT.Wood,
				{ Shadow = false }
			)
			Geo.Post(
				model,
				at(cf, sx * (size.X / 2 + 0.75), -0.4, 0),
				P.LeaderboardLift + size.Y + 1.9,
				0.65,
				C.WoodPost,
				MAT.Wood,
				{ Collide = true }
			)
		end
		Geo.Cylinder(
			model,
			center * CFrame.new(0, size.Y / 2 + 0.85, 0),
			size.X + 2.6,
			0.85,
			C.WoodDark,
			MAT.Wood,
			{ Shadow = true }
		)
		Geo.Lantern(model, at(center, 0, size.Y / 2 + 1.75, -0.2), 0.8, false, 14)
	end
end

local function buildMarketSign(model: Model)
	local pos = Vector3.new(37.5, 0, 14)
	local g = Geo.GroundY(pos.X, pos.Z)
	local cf = Geo.Facing(Vector3.new(pos.X, g, pos.Z), Vector3.new(0.42, 0, 0.91))
	for _, sx in { -1, 1 } do
		Geo.Post(model, at(cf, sx * 3.9, -0.6, 0), 5.0, 0.55, C.Bamboo, MAT.Wood, { Collide = true })
		Geo.Ball(model, at(cf, sx * 3.9, 4.55, 0), 0.75, C.BambooDark, MAT.Wood, { Shadow = false })
	end
	Geo.Sign(
		model,
		cf * CFrame.new(0, 3.2, 0),
		Vector3.new(7.2, 1.8, 0.3),
		TX.Market,
		{ BothSides = true, MaxTextSize = 60 }
	)
end

-- ===================================================================== hiasan

local function buildDecor(model: Model)
	-- Pot tanaman di sisi kios & gapura
	local pots = {
		Vector3.new(-9.6, 0, -27),
		Vector3.new(9.6, 0, -27),
		Vector3.new(-6.8, 0, -16.4),
		Vector3.new(6.8, 0, -16.4),
		Vector3.new(-41, 0, -8),
		Vector3.new(41, 0, -8),
	}
	for _, p in pots do
		local base = Vector3.new(p.X, P.FloorY, p.Z)
		Geo.Post(model, base - Vector3.new(0, 0.1, 0), 1.4, 1.5, C.Terracotta, MAT.Concrete, { Collide = true })
		Geo.Ball(
			model,
			base + Vector3.new(0, 1.9, 0),
			2.1 + Geo.Rand(-0.2, 0.3),
			C.Bush,
			MAT.LeafyGrass,
			{ Shadow = true }
		)
	end
	-- Peti & karung di belakang kios
	local crates = { Vector3.new(-37, 0, -21), Vector3.new(-35.4, 0, -23.2), Vector3.new(36.8, 0, -21.5) }
	for i, p in crates do
		Geo.Block(
			model,
			CFrame.new(p.X, P.FloorY + 0.75, p.Z) * CFrame.Angles(0, math.rad(Geo.Rand(-20, 20)), 0),
			Vector3.new(1.6, 1.5, 1.6),
			if i == 2 then C.WoodDeckAlt else C.WoodLight,
			MAT.WoodPlanks,
			{ Collide = true }
		)
	end
	local sacks = { Vector3.new(-34.2, 0, -20.4), Vector3.new(38.6, 0, -19.6), Vector3.new(35.2, 0, -23) }
	for _, p in sacks do
		Geo.Ellipsoid(
			model,
			CFrame.new(p.X, P.FloorY + 0.6, p.Z)
				* CFrame.Angles(0, math.rad(Geo.Rand(0, 180)), math.rad(Geo.Rand(-8, 8))),
			Vector3.new(1.5, 1.3, 1.1),
			C.FabricShade,
			MAT.Fabric,
			{ Shadow = false }
		)
	end
end

function Plaza.Build(ctx: Geo.Context)
	local rng = Geo.Rng(MapConfig.SeedOffsets.Plaza)
	local model = Geo.Model(ctx.Root, "PasarPantai")
	buildDeck(model, rng)
	buildSpawn(ctx, model)
	buildLampsAndBunting(model)
	buildBoard(ctx, Geo.Model(model, "PapanPengumuman", PERSISTENT))
	buildToko(ctx, model)
	buildButik(ctx, model)
	buildRiset(ctx, model)
	buildLeaderboards(ctx, model)
	buildMarketSign(model)
	buildDecor(model)
end

return Plaza
