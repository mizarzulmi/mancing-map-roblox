--!strict
-- Dermaga & jalur: dermaga utama (90, 3, 110 → Z 250) berujung T, pangkal dermaga + Lapak Pengepul
-- Bu Rina, Gubuk Barter Kakek Bahari, Dermaga Kapal Nahkoda Jaka + feri tertambat, Platform Laut Dalam
-- (dek oktagon, gubuk, lampu, kapal pulang), titian kayu Spawn → Pasar → Dermaga, dan papan arah.

local MapConfig = require(script.Parent.MapConfig)
local Geo = require(script.Parent.Geo)

local PI = MapConfig.Pier
local C = MapConfig.Colors
local TX = MapConfig.Text
local MAT = Enum.Material
local UP = Vector3.yAxis
local PERSISTENT = Enum.ModelStreamingMode.Persistent
local ATOMIC = Enum.ModelStreamingMode.Atomic

local Pier = {}

local function at(cf: CFrame, x: number, y: number, z: number): Vector3
	return (cf * CFrame.new(x, y, z)).Position
end

local function weathered(rng: Random): Color3
	local r = rng:NextNumber()
	if r < 0.5 then
		return C.WoodWeathered
	elseif r < 0.8 then
		return C.WoodDeck
	end
	return C.WoodDeckAlt
end

-- ===================================================================== dek, tiang, tali

-- Dek papan persegi: papan sejajar X (baris melangkah di Z) atau sejajar Z.
local function deckRect(
	model: Instance,
	minX: number,
	maxX: number,
	minZ: number,
	maxZ: number,
	topY: number,
	alongX: boolean,
	rng: Random
)
	local pitch, width, thick = PI.PlankPitch, PI.PlankWidth, PI.PlankThickness
	local span = if alongX then maxZ - minZ else maxX - minX
	local len0 = if alongX then maxX - minX else maxZ - minZ
	local n = math.floor(span / pitch)
	local start = (if alongX then minZ else minX) + (span - n * pitch) / 2 + pitch / 2
	local yawMax = 0.5 * math.min(1, 10 / len0)
	for i = 0, n - 1 do
		local u = start + i * pitch
		local e0 = rng:NextNumber(-0.18, 0.1)
		local e1 = rng:NextNumber(-0.1, 0.18)
		local len = len0 + e1 - e0
		local mid = (if alongX then (minX + maxX) / 2 else (minZ + maxZ) / 2) + (e0 + e1) / 2
		local th = thick + rng:NextNumber(-0.03, 0.03)
		local y = topY + rng:NextNumber(-0.025, 0.02) - th / 2
		local cf = if alongX then CFrame.new(mid, y, u) else CFrame.new(u, y, mid) * CFrame.Angles(0, math.pi / 2, 0)
		Geo.Block(
			model,
			cf * CFrame.Angles(0, math.rad(rng:NextNumber(-yawMax, yawMax)), 0),
			Vector3.new(len, th, width),
			weathered(rng),
			MAT.Wood,
			{ Collide = true, Shadow = false, Jitter = 0.06 }
		)
	end
end

-- Tiang pancang dari dasar laut/tanah sampai `topY` (sedikit miring buatan tangan).
local function pile(model: Instance, x: number, z: number, topY: number, d: number?): Part
	local g = Geo.GroundY(x, z)
	return Geo.Segment(
		model,
		Vector3.new(x, g - 1.2, z),
		Vector3.new(x + Geo.Rand(-0.14, 0.14), topY, z + Geo.Rand(-0.14, 0.14)),
		d or PI.PileDiameter,
		C.WoodWeathered,
		MAT.Wood,
		{ Collide = true, Jitter = 0.05 }
	)
end

-- Puncak tiang pancang (segmen: X lokal mengarah dari bawah ke atas).
local function pileTop(p: Part): Vector3
	return p.CFrame.Position + p.CFrame.XVector * (p.Size.X / 2)
end

local function rope(a: Part, b: Part, ropeY: number, sag: number)
	local pa, pb = a.CFrame.Position, b.CFrame.Position
	local a0 = Geo.Attach(a, Vector3.new(pa.X, ropeY, pa.Z))
	local a1 = Geo.Attach(b, Vector3.new(pb.X, ropeY, pb.Z))
	Geo.Rope(a0, a1, sag, 0.2, C.Rope)
end

local function gapBetween(side: number, z0: number, z1: number): boolean
	for _, g in PI.RailGaps do
		if g.Side == side and g.Z > math.min(z0, z1) and g.Z < math.max(z0, z1) then
			return true
		end
	end
	return false
end

-- ===================================================================== atap ijuk berlapis & gubuk

-- Satu lapis atap ijuk berupa wedge (tebal di bawah) → profil gergaji berlapis.
local function thatchCourse(
	model: Instance,
	ridgeCF: CFrame,
	length: number,
	sDir: Vector3,
	nDir: Vector3,
	s0: number,
	s1: number,
	thick: number,
	color: Color3
)
	local corner = ridgeCF.Position + sDir * s1
	local zv = sDir
	local yv = nDir
	local xv = yv:Cross(zv)
	local center = corner + yv * (thick / 2) - zv * ((s1 - s0) / 2)
	Geo.Wedge(
		model,
		CFrame.fromMatrix(center, xv, yv, zv),
		Vector3.new(length, thick, s1 - s0),
		color,
		MAT.Grass,
		{ Shadow = true, Jitter = 0.03 }
	)
end

export type HutOpts = {
	Width: number,
	Depth: number,
	WallHeight: number,
	DoorX: number,
	Sign: string,
	Bench: boolean,
	BenchX: number,
	Flicker: boolean,
}

-- Gubuk kayu beratap ijuk berlapis. `cf` di lantai, −Z = depan. Mengembalikan CFrame dudukan bangku (atau nil).
local function buildHut(model: Model, cf: CFrame, o: HutOpts): CFrame?
	local w, d, H = o.Width, o.Depth, o.WallHeight
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			Geo.Post(
				model,
				at(cf, sx * w / 2, -0.3, sz * d / 2),
				H + 0.5,
				0.75,
				C.WoodPost,
				MAT.Wood,
				{ Collide = true }
			)
		end
	end
	-- Dinding papan vertikal (WoodPlanks diputar 90°).
	local vertical = CFrame.Angles(0, 0, math.pi / 2)
	Geo.Block(
		model,
		cf * CFrame.new(0, H / 2, d / 2) * vertical,
		Vector3.new(H, w - 0.4, 0.25),
		C.WoodDeckAlt,
		MAT.WoodPlanks,
		{ Collide = true }
	)
	for _, sx in { -1, 1 } do
		Geo.Block(
			model,
			cf * CFrame.new(sx * w / 2, H / 2, 0) * CFrame.Angles(0, math.pi / 2, 0) * vertical,
			Vector3.new(H, d - 0.4, 0.25),
			C.WoodDeckAlt,
			MAT.WoodPlanks,
			{ Collide = true }
		)
	end
	-- Dinding depan dengan pintu.
	local doorW, doorH = 2.3, 4.3
	local leftW = (o.DoorX - doorW / 2) - (-w / 2 + 0.2)
	local rightW = (w / 2 - 0.2) - (o.DoorX + doorW / 2)
	if leftW > 0.2 then
		Geo.Block(
			model,
			cf * CFrame.new(-w / 2 + 0.2 + leftW / 2, H / 2, -d / 2) * vertical,
			Vector3.new(H, leftW, 0.25),
			C.WoodDeckAlt,
			MAT.WoodPlanks,
			{ Collide = true }
		)
	end
	if rightW > 0.2 then
		Geo.Block(
			model,
			cf * CFrame.new(w / 2 - 0.2 - rightW / 2, H / 2, -d / 2) * vertical,
			Vector3.new(H, rightW, 0.25),
			C.WoodDeckAlt,
			MAT.WoodPlanks,
			{ Collide = true }
		)
	end
	Geo.Block(
		model,
		cf * CFrame.new(o.DoorX, (H + doorH) / 2, -d / 2),
		Vector3.new(doorW, H - doorH, 0.25),
		C.WoodDeckAlt,
		MAT.WoodPlanks,
		{ Collide = true }
	)
	Geo.Block(
		model,
		cf * CFrame.new(o.DoorX, doorH / 2, -d / 2 + 0.05),
		Vector3.new(doorW, doorH, 0.1),
		C.WoodDark,
		MAT.Wood,
		{ Shadow = false }
	)
	-- Jendela berpenutup di sisi kanan.
	Geo.Block(
		model,
		cf * CFrame.new(w / 2 + 0.16, H * 0.58, 0),
		Vector3.new(0.08, 1.5, 2.0),
		C.WoodDark,
		MAT.Wood,
		{ Shadow = false }
	)
	Geo.Plank(
		model,
		at(cf, w / 2 + 0.6, H * 0.58 + 1.05, -1.2),
		at(cf, w / 2 + 0.6, H * 0.58 + 1.05, 1.2),
		1.1,
		0.12,
		cf:VectorToWorldSpace(Vector3.new(0.5, 1, 0)),
		C.Thatch,
		MAT.Grass,
		{ Shadow = false }
	)

	-- Atap pelana ijuk berlapis (3 lapis wedge per sisi) + bubungan + segitiga pelana.
	local over = 1.5
	local rise = 2.8
	local ridgeCF = cf * CFrame.new(0, H + rise, 0)
	local halfRun = d / 2 + over
	local slopeLen = math.sqrt(halfRun * halfRun + (rise + 0.4) ^ 2)
	for _, side in { -1, 1 } do
		local sDir = cf:VectorToWorldSpace(Vector3.new(0, -(rise + 0.4), side * halfRun)).Unit
		local nDir = cf:VectorToWorldSpace(Vector3.new(0, halfRun, side * (rise + 0.4))).Unit
		local courses = 3
		for k = 1, courses do
			local s0 = (k - 1) / courses * slopeLen - 0.35
			local s1 = k / courses * slopeLen
			thatchCourse(
				model,
				ridgeCF,
				w + 2 * over,
				sDir,
				nDir,
				math.max(0, s0),
				s1,
				0.55,
				if k % 2 == 0 then C.ThatchDark else C.Thatch
			)
		end
	end
	Geo.Cylinder(
		model,
		ridgeCF * CFrame.new(0, 0.25, 0),
		w + 2 * over + 0.4,
		0.6,
		C.ThatchDark,
		MAT.Grass,
		{ Shadow = false }
	)
	for _, sx in { -1, 1 } do
		Geo.Triangle(
			model,
			at(cf, sx * w / 2, H + rise - 0.1, 0),
			at(cf, sx * w / 2, H, -d / 2),
			at(cf, sx * w / 2, H, d / 2),
			0.25,
			C.WoodDeckAlt,
			MAT.WoodPlanks,
			{ Shadow = false }
		)
	end

	-- Papan nama di atas pintu & lentera di emper.
	local signW = math.min(w - 0.8, math.max(3.4, #o.Sign * 0.5))
	local signX = math.clamp(o.DoorX, -w / 2 + signW / 2 + 0.4, w / 2 - signW / 2 - 0.4)
	Geo.Sign(
		model,
		cf * CFrame.new(signX, doorH + 0.75, -d / 2 - 0.2),
		Vector3.new(signW, 1.0, 0.2),
		o.Sign,
		{ MaxTextSize = 40 }
	)
	local lanternX = if o.DoorX > 0 then o.DoorX - doorW / 2 - 0.9 else o.DoorX + doorW / 2 + 0.9
	Geo.Segment(
		model,
		at(cf, lanternX, H - 0.1, -d / 2 - 0.1),
		at(cf, lanternX, H - 0.1, -d / 2 - 0.95),
		0.12,
		C.MetalDark,
		MAT.Metal,
		{ Shadow = false }
	)
	Geo.Segment(
		model,
		at(cf, lanternX, H - 0.1, -d / 2 - 0.95),
		at(cf, lanternX, H - 0.75, -d / 2 - 0.95),
		0.06,
		C.MetalDark,
		MAT.Metal,
		{ Shadow = false }
	)
	Geo.Lantern(model, at(cf, lanternX, H - 1.3, -d / 2 - 0.95), 0.85, o.Flicker, 18)

	if o.Bench then
		local seatTop = 1.6
		local bcf = cf * CFrame.new(o.BenchX, 0, -d / 2 - 0.75)
		Geo.Block(
			model,
			bcf * CFrame.new(0, seatTop - 0.125, 0),
			Vector3.new(2.8, 0.25, 1.05),
			C.WoodDeck,
			MAT.Wood,
			{ Collide = true, Shadow = false }
		)
		for _, sx in { -1, 1 } do
			Geo.Block(
				model,
				bcf * CFrame.new(sx * 1.15, (seatTop - 0.25) / 2, 0),
				Vector3.new(0.3, seatTop - 0.25, 0.9),
				C.WoodDark,
				MAT.Wood,
				{ Shadow = false }
			)
		end
		return bcf * CFrame.new(0, seatTop, 0)
	end
	return nil
end

-- ===================================================================== kapal feri kecil (Bobbing)

local function buildFerry(parent: Instance, name: string, pos: Vector3, face: Vector3, rng: Random): Model
	local model = Geo.Model(parent, name, ATOMIC)
	local cf = Geo.Facing(pos, face)
	local spec: Geo.HullSpec = {
		Length = 22,
		HalfBeam = 3.9,
		Freeboard = 2.2,
		BowRise = 1.3,
		SternRise = 0.5,
		KeelDepth = 1.6,
		Strakes = { C.White, C.Blue },
		Segments = 5,
		Thickness = 0.3,
		Material = MAT.WoodPlanks,
		SternFull = 0.8,
		Collide = false,
		Posts = true,
		RailColor = C.WoodDark,
	}
	local hull = Geo.Hull(model, cf, spec)
	local deckY = hull.Sheer(0.5) - 0.45
	local deck = Geo.Block(
		model,
		cf * CFrame.new(0, deckY, 0.6),
		Vector3.new(hull.Width(0.5) * 1.8, 0.3, 15.5),
		C.WoodDeck,
		MAT.WoodPlanks,
		{ Shadow = false }
	)
	model.PrimaryPart = deck
	Geo.Block(
		model,
		cf * CFrame.new(0, hull.Sheer(0.82) - 0.4, -6.9),
		Vector3.new(hull.Width(0.82) * 1.7, 0.3, 3.4),
		C.WoodDeck,
		MAT.WoodPlanks,
		{ Shadow = false }
	)
	-- Kabin
	local cabin = cf * CFrame.new(0, deckY + 1.55, 3.0)
	Geo.Block(model, cabin, Vector3.new(5.6, 2.8, 5.2), C.White, MAT.WoodPlanks, { Shadow = true })
	Geo.Block(model, cabin * CFrame.new(0, 1.6, 0), Vector3.new(6.6, 0.35, 6.4), C.Blue, MAT.Wood, { Shadow = true })
	for _, sx in { -1, 1 } do
		Geo.Cylinder(
			model,
			cabin * CFrame.new(sx * 3.3, 1.6, 0) * CFrame.Angles(0, math.pi / 2, 0),
			6.4,
			0.5,
			C.Blue,
			MAT.Wood,
			{ Shadow = false }
		)
		Geo.Block(
			model,
			cabin * CFrame.new(sx * 2.84, 0.35, 0),
			Vector3.new(0.08, 0.9, 4.2),
			C.MetalDark,
			MAT.Glass,
			{ Shadow = false }
		)
	end
	local plate = Geo.Block(
		model,
		cabin * CFrame.new(0, 0.45, -2.64),
		Vector3.new(4.0, 0.9, 0.1),
		C.LeaderBoard,
		MAT.Wood,
		{ Shadow = false }
	)
	Geo.SignText(plate, Enum.NormalId.Front, "KM NUSANTARA", { MaxTextSize = 36 })
	-- Tiang & bendera
	local mastBase = at(cf, 0, deckY + 3.2, 4.6)
	Geo.Post(model, mastBase, 3.6, 0.22, C.White, MAT.Metal, { Shadow = false })
	local flagCF = CFrame.new(mastBase + Vector3.new(0, 3.1, 0)) * cf.Rotation * CFrame.new(0, 0, 0.95)
	Geo.Block(
		model,
		flagCF * CFrame.new(0, 0.3, 0),
		Vector3.new(0.06, 0.6, 1.8),
		C.FlagRed,
		MAT.Fabric,
		{ Shadow = false, Jitter = 0 }
	)
	Geo.Block(
		model,
		flagCF * CFrame.new(0, -0.3, 0),
		Vector3.new(0.06, 0.6, 1.8),
		C.FlagWhite,
		MAT.Fabric,
		{ Shadow = false, Jitter = 0 }
	)
	-- Ban bekas sebagai fender di sisi kanan & kiri
	for _, z in { -4, 0.5, 5 } do
		for _, sx in { -1, 1 } do
			local t = 0.5 - z / 22
			local p = hull.Point(t, 0.35, sx)
			Geo.Cylinder(
				model,
				cf * CFrame.new(p + Vector3.new(sx * 0.25, -0.2, 0)),
				0.45,
				1.1,
				C.MetalDark,
				MAT.SmoothPlastic,
				{ Shadow = false }
			)
		end
	end
	model:SetAttribute("Amplitude", 0.18)
	model:SetAttribute("Speed", 0.8)
	model:SetAttribute("Phase", rng:NextNumber(0, math.pi * 2))
	model:SetAttribute("Tilt", 1.2)
	Geo.Tag(model, "Bobbing")
	return model
end

-- ===================================================================== dermaga utama

local function buildMainPier(ctx: Geo.Context, root: Model, rng: Random)
	local model = Geo.Model(root, "DermagaUtama")
	local Y = PI.DeckY
	local x0, x1 = PI.X - PI.HalfWidth, PI.X + PI.HalfWidth
	local T, R = PI.T, PI.Root
	local postTop = Y + PI.PostAbove
	local ropeY = Y + PI.RopeHeight

	-- Dek: pangkal, batang, kepala T
	deckRect(model, R.MinX, R.MaxX, R.MinZ, R.MaxZ, Y, true, rng)
	deckRect(model, x0, x1, PI.StemStartZ, PI.StemEndZ, Y, true, rng)
	deckRect(model, T.MinX, T.MaxX, T.MinZ, T.MaxZ, Y, false, rng)

	-- Gelagar di bawah papan
	local sy = Y - PI.PlankThickness - 0.4
	for _, x in { x0 + 1.6, x1 - 1.6 } do
		for _, seg in { { PI.StemStartZ - 2, 174 }, { 174, PI.StemEndZ + 1 } } do
			Geo.Block(
				model,
				CFrame.new(x, sy, (seg[1] + seg[2]) / 2),
				Vector3.new(0.6, 0.8, seg[2] - seg[1]),
				C.WoodDark,
				MAT.Wood,
				{ Shadow = false }
			)
		end
	end
	for _, z in { T.MinZ + 1.5, (T.MinZ + T.MaxZ) / 2, T.MaxZ - 1.5 } do
		Geo.Block(
			model,
			CFrame.new((T.MinX + T.MaxX) / 2, sy, z),
			Vector3.new(T.MaxX - T.MinX - 0.6, 0.8, 0.6),
			C.WoodDark,
			MAT.Wood,
			{ Shadow = false }
		)
	end
	for _, z in { R.MinZ + 1.5, (R.MinZ + R.MaxZ) / 2, R.MaxZ - 1.5 } do
		Geo.Block(
			model,
			CFrame.new((R.MinX + R.MaxX) / 2, sy, z),
			Vector3.new(R.MaxX - R.MinX - 0.6, 0.8, 0.6),
			C.WoodDark,
			MAT.Wood,
			{ Shadow = false }
		)
	end

	-- Tiang pancang batang (berpasangan) + pagar tali
	local west: { Part } = {}
	local east: { Part } = {}
	local zs: { number } = {}
	local z = PI.StemStartZ + 2
	while z < PI.StemEndZ - 4 do
		table.insert(zs, z)
		table.insert(west, pile(model, x0 + 0.4, z, postTop))
		table.insert(east, pile(model, x1 - 0.4, z, postTop))
		z += PI.PileSpacing
	end
	-- Tiang kepala T (urut keliling dari sambungan barat → selatan → timur)
	local tw, te = T.MinX + 0.6, T.MaxX - 0.6
	local tn, ts = T.MinZ + 0.6, T.MaxZ - 0.6
	local ring = {
		Vector3.new(x0 + 0.4, 0, tn),
		Vector3.new((tw + x0) / 2, 0, tn),
		Vector3.new(tw, 0, tn),
		Vector3.new(tw, 0, (tn + ts) / 2),
		Vector3.new(tw, 0, ts),
		Vector3.new(80, 0, ts),
		Vector3.new(90, 0, ts),
		Vector3.new(100, 0, ts),
		Vector3.new(te, 0, ts),
		Vector3.new(te, 0, (tn + ts) / 2),
		Vector3.new(te, 0, tn),
		Vector3.new((te + x1) / 2, 0, tn),
		Vector3.new(x1 - 0.4, 0, tn),
	}
	local ringParts: { Part } = {}
	for _, p in ring do
		table.insert(ringParts, pile(model, p.X, p.Z, postTop))
	end
	-- Tali batang
	for i = 1, #zs - 1 do
		if not gapBetween(-1, zs[i], zs[i + 1]) then
			rope(west[i], west[i + 1], ropeY, 0.45)
		end
		if not gapBetween(1, zs[i], zs[i + 1]) then
			rope(east[i], east[i + 1], ropeY, 0.45)
		end
	end
	rope(west[#west], ringParts[1], ropeY, 0.45)
	rope(east[#east], ringParts[#ringParts], ropeY, 0.45)
	-- Tali keliling T (celah di ujung timur untuk nelayan)
	local nelayan2 = Vector3.new(109.2, Y, 245.5)
	for i = 1, #ringParts - 1 do
		local a, b = ring[i], ring[i + 1]
		local blocked = math.abs(a.X - te) < 0.1
			and math.abs(b.X - te) < 0.1
			and nelayan2.Z > math.min(a.Z, b.Z)
			and nelayan2.Z < math.max(a.Z, b.Z)
		if not blocked then
			rope(ringParts[i], ringParts[i + 1], ropeY, 0.55)
		end
	end
	-- Tiang & pagar pangkal (sisi barat, selatan-barat, timur)
	local rp = {
		pile(model, R.MinX + 0.6, R.MinZ + 0.6, postTop, 0.9),
		pile(model, R.MinX + 0.6, (R.MinZ + R.MaxZ) / 2, postTop, 0.9),
		pile(model, R.MinX + 0.6, R.MaxZ - 0.6, postTop, 0.9),
		pile(model, (R.MinX + x0) / 2, R.MaxZ - 0.6, postTop, 0.9),
	}
	for i = 1, #rp - 1 do
		rope(rp[i], rp[i + 1], ropeY, 0.4)
	end
	rope(rp[#rp], west[1], ropeY, 0.4)
	local re1 = pile(model, R.MaxX - 0.6, R.MinZ + 0.6, postTop, 0.9)
	local re2 = pile(model, R.MaxX - 0.4, (R.MinZ + R.MaxZ) / 2, postTop, 0.9)
	rope(re1, re2, ropeY, 0.4)
	rope(re2, east[1], ropeY, 0.4)

	-- Lampu dermaga
	for _, l in PI.Lamps do
		Geo.LampPost(model, Vector3.new(l.X, Y, l.Z), 6.4, 20)
	end
	-- Ember & gulungan tali/jaring
	local bucketColors = { C.Blue, C.Orange, C.Teal }
	for i, b in PI.Buckets do
		Geo.Bucket(model, b, bucketColors[(i - 1) % #bucketColors + 1])
	end
	for i, c in PI.Coils do
		if i % 2 == 1 then
			Geo.RopeCoil(model, c, 2.3)
		else
			-- tumpukan jaring dengan pelampung oranye
			Geo.Ellipsoid(
				model,
				CFrame.new(c + Vector3.new(0, 0.45, 0)) * CFrame.Angles(0, math.rad(Geo.Rand(0, 180)), 0),
				Vector3.new(3.0, 1.0, 2.2),
				C.Teal,
				MAT.Fabric,
				{ Shadow = false }
			)
			for k = 1, 3 do
				local a = k / 3 * math.pi * 2
				Geo.Ball(
					model,
					c + Vector3.new(math.cos(a) * 0.9, 0.95, math.sin(a) * 0.6),
					0.5,
					C.Orange,
					MAT.SmoothPlastic,
					{ Shadow = false }
				)
			end
		end
	end

	-- Nelayan di tepi batang & ujung T (menghadap air terbuka)
	ctx.Npc.nelayan_1 = Geo.Facing(Vector3.new(x0 + 0.9, Y, 200), Vector3.new(-1, 0, 0))
	ctx.Npc.nelayan_2 = Geo.Facing(nelayan2, Vector3.new(1, 0, 0))

	-- Gubuk Barter Kakek Bahari di kepala T
	local B = PI.Barter
	local hutModel = Geo.Model(model, "GubukBarter", PERSISTENT)
	local hutCF = Geo.Facing(B.Pos, Vector3.new(0, 0, -1))
	local seat = buildHut(hutModel, hutCF, {
		Width = B.Size.X,
		Depth = B.Size.Z,
		WallHeight = 5.6,
		DoorX = 2.2,
		Sign = TX.Barter,
		Bench = true,
		BenchX = B.BenchX - B.Pos.X,
		Flicker = true,
	})
	if seat then
		ctx.Npc.kakek_bahari = seat
	end
	-- Tong, bubu (perangkap ikan bambu), ikan asin tergantung
	Geo.Barrel(hutModel, at(hutCF, -B.Size.X / 2 - 1.4, 0, -1.0), 1.8, 2.3, C.WoodDeck, C.Shell[2])
	Geo.Barrel(hutModel, at(hutCF, -B.Size.X / 2 - 1.2, 0, 1.3), 1.5, 1.9, C.WoodDeckAlt, C.WoodDark)
	for k, off in { Vector3.new(B.Size.X / 2 + 1.6, 0.6, -1.4), Vector3.new(B.Size.X / 2 + 1.2, 0.6, 1.2) } do
		local trapCF = hutCF * CFrame.new(off) * CFrame.Angles(0, math.rad(80 + k * 25), 0)
		Geo.Cylinder(hutModel, trapCF, 2.2, 1.2, C.Woven, MAT.Fabric, { Shadow = false })
		Geo.Ball(hutModel, (trapCF * CFrame.new(1.1, 0, 0)).Position, 1.15, C.Woven, MAT.Fabric, { Shadow = false })
	end
	local lineA = at(hutCF, -B.Size.X / 2 - 0.55, 4.7, -2.4)
	local lineB = at(hutCF, -B.Size.X / 2 - 0.55, 4.7, 0.9)
	local along = hutCF:VectorToWorldSpace(Vector3.zAxis)
	for k = 1, 3 do
		local p = lineA:Lerp(lineB, k / 4) - Vector3.new(0, 0.6, 0)
		Geo.Fish(hutModel, CFrame.fromMatrix(p, -UP, along, (-UP):Cross(along)), 0.9, C.Shell[4], C.WoodLight)
	end
	Geo.Block(
		hutModel,
		hutCF * CFrame.new(-B.Size.X / 2 - 0.16, 3.4, 0),
		Vector3.new(0.06, 2.6, 4.2),
		C.Teal,
		MAT.Fabric,
		{ Transparency = 0.35, Shadow = false }
	)

	-- Lapak Pengepul Bu Rina di pangkal dermaga
	local L = PI.Lapak
	local lapak = Geo.Model(model, "LapakPengepul", PERSISTENT)
	local lcf = Geo.Facing(L.Pos, L.Face)
	Geo.Block(
		lapak,
		lcf * CFrame.new(0, 3.0, -1.6),
		Vector3.new(7, 0.3, 2.4),
		C.WoodLight,
		MAT.Wood,
		{ Collide = true }
	)
	for _, sx in { -1, 1 } do
		Geo.Block(
			lapak,
			lcf * CFrame.new(sx * 3.0, 1.43, -1.6),
			Vector3.new(0.4, 2.85, 2.0),
			C.WoodDark,
			MAT.Wood,
			{ Collide = true }
		)
	end
	Geo.Block(
		lapak,
		lcf * CFrame.new(0, 3.32, -1.6),
		Vector3.new(6.6, 0.34, 2.1),
		C.Ice,
		MAT.Ice,
		{ Shadow = false, Jitter = 0.02 }
	)
	for k = 1, 6 do
		local s = Geo.Rand(0.45, 0.8)
		Geo.Block(
			lapak,
			lcf
				* CFrame.new(-3.0 + k * 0.9, 3.55 + s * 0.2, -1.6 + Geo.Rand(-0.75, 0.75))
				* CFrame.Angles(math.rad(Geo.Rand(0, 40)), math.rad(Geo.Rand(0, 90)), math.rad(Geo.Rand(0, 40))),
			Vector3.new(s, s * 0.8, s),
			C.Ice,
			MAT.Glass,
			{ Transparency = 0.3, Shadow = false, Jitter = 0.02 }
		)
	end
	local displayFish = {
		{ Body = C.TarpLight, Fin = C.White, Length = 1.5 },
		{ Body = C.Red, Fin = C.Orange, Length = 1.9 },
		{ Body = C.WoodLight, Fin = C.WoodDark, Length = 2.1 },
		{ Body = C.Blue, Fin = C.Shell[3], Length = 1.6 },
	}
	for k, f in displayFish do
		local head = lcf:VectorToWorldSpace(Vector3.new(if k % 2 == 0 then 1 else -1, 0, 0.15)).Unit
		local side = UP:Cross(head).Unit
		local pos = at(lcf, -2.4 + (k - 1) * 1.6, 3.62, -1.55 + (k % 2) * 0.3)
		Geo.Fish(lapak, CFrame.fromMatrix(pos, head, side, head:Cross(side)), f.Length, f.Body, f.Fin)
	end
	-- Kanopi bergaris
	for _, sx in { -1, 1 } do
		Geo.Post(lapak, at(lcf, sx * 3.8, -0.3, -2.7), 7.2, 0.45, C.Bamboo, MAT.Wood, { Collide = true })
		Geo.Post(lapak, at(lcf, sx * 3.8, -0.3, 2.4), 7.8, 0.45, C.Bamboo, MAT.Wood, { Collide = true })
	end
	local stripes = { C.Red, C.Fabric, C.Red }
	for k, col in stripes do
		local x = -2.75 + (k - 1) * 2.75
		Geo.Plank(
			lapak,
			at(lcf, x, 7.62, 2.6),
			at(lcf, x, 6.95, -2.95),
			2.78,
			0.12,
			lcf:VectorToWorldSpace(Vector3.new(0, 1, -0.12)),
			col,
			MAT.Fabric,
			{ Shadow = true }
		)
	end
	Geo.Block(
		lapak,
		lcf * CFrame.new(0, 6.5, -2.98),
		Vector3.new(8.3, 0.85, 0.08),
		C.Red,
		MAT.Fabric,
		{ Shadow = false }
	)
	-- Timbangan gantung
	local hook = lcf * CFrame.new(2.6, 6.05, -2.75)
	Geo.Segment(lapak, at(hook, 0, 0.4, 0), at(hook, 0, -0.5, 0), 0.06, C.MetalDark, MAT.Metal, { Shadow = false })
	local dial = hook * CFrame.new(0, -1.1, 0)
	Geo.Cylinder(
		lapak,
		dial * CFrame.Angles(0, math.pi / 2, 0),
		0.35,
		1.25,
		C.White,
		MAT.SmoothPlastic,
		{ Shadow = false }
	)
	Geo.Block(
		lapak,
		dial * CFrame.new(0.12, 0.12, -0.2) * CFrame.Angles(0, 0, math.rad(-35)),
		Vector3.new(0.08, 0.5, 0.04),
		C.Red,
		MAT.SmoothPlastic,
		{ Shadow = false }
	)
	Geo.Segment(lapak, at(dial, 0, -0.62, 0), at(dial, 0, -1.4, 0), 0.06, C.MetalDark, MAT.Metal, { Shadow = false })
	Geo.Disk(lapak, at(dial, 0, -1.45, 0), 0.12, 1.5, C.Metal, MAT.Metal, { Shadow = false })
	-- Papan nama, kotak gabus, bakul, lentera
	Geo.Sign(
		lapak,
		lcf * CFrame.new(0, 1.55, -2.86),
		Vector3.new(5.6, 1.2, 0.12),
		TX.Collector,
		{ Board = C.LeaderBoard, MaxTextSize = 40 }
	)
	for k, off in { Vector3.new(-4.7, 0, 0.5), Vector3.new(-4.5, 0, 2.3) } do
		local bcf = lcf * CFrame.new(off + Vector3.new(0, 0.7, 0)) * CFrame.Angles(0, math.rad(k * 7), 0)
		Geo.Block(lapak, bcf, Vector3.new(2.0, 1.4, 1.4), C.White, MAT.SmoothPlastic, { Collide = true })
		Geo.Block(
			lapak,
			bcf * CFrame.new(0, 0.76, 0),
			Vector3.new(2.1, 0.14, 1.5),
			C.Blue,
			MAT.SmoothPlastic,
			{ Shadow = false }
		)
	end
	for _, off in { Vector3.new(3.9, 0, 0.9), Vector3.new(4.6, 0, -0.8) } do
		local base = at(lcf, off.X, 0, off.Z)
		Geo.Post(lapak, base - Vector3.new(0, 0.1, 0), 1.1, 1.8, C.Woven, MAT.Fabric, { Collide = true })
		Geo.Disk(lapak, base + Vector3.new(0, 0.98, 0), 0.08, 1.5, C.Shell[3], MAT.SmoothPlastic, { Shadow = false })
	end
	Geo.Segment(
		lapak,
		at(lcf, -1.2, 7.25, -0.6),
		at(lcf, -1.2, 6.2, -0.6),
		0.06,
		C.MetalDark,
		MAT.Metal,
		{ Shadow = false }
	)
	Geo.Lantern(lapak, at(lcf, -1.2, 5.7, -0.6), 0.85, false, 16)
	ctx.Npc.bu_rina = lcf * CFrame.new(0, 0, 0.2)

	-- Rak penjemuran ikan asin di sisi barat pangkal
	local rack = lcf * CFrame.new(-6.2, 0, -4.0)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			Geo.Post(lapak, at(rack, sx * 2.0, -0.2, sz * 1.0), 2.6, 0.25, C.Bamboo, MAT.Wood, { Shadow = false })
		end
	end
	Geo.Block(
		lapak,
		rack * CFrame.new(0, 2.3, 0),
		Vector3.new(4.3, 0.06, 2.3),
		C.Woven,
		MAT.Fabric,
		{ Transparency = 0.2, Shadow = false }
	)
	for k = 1, 6 do
		Geo.Ellipsoid(
			lapak,
			rack
				* CFrame.new(-1.6 + ((k - 1) % 3) * 1.6, 2.42, if k <= 3 then -0.5 else 0.5)
				* CFrame.Angles(0, math.rad(Geo.Rand(-20, 20)), 0),
			Vector3.new(1.1, 0.12, 0.45),
			C.WoodLight,
			MAT.SmoothPlastic,
			{ Shadow = false }
		)
	end
end

-- ===================================================================== dermaga kapal & feri

local function buildJetty(ctx: Geo.Context, root: Model, rng: Random)
	local J = PI.Jetty
	local model = Geo.Model(root, "DermagaKapal")
	local x0, x1 = J.X - J.HalfWidth, J.X + J.HalfWidth
	local postTop = J.DeckY + PI.PostAbove
	deckRect(model, x0, x1, J.MinZ, J.MaxZ, J.DeckY, true, rng)
	local sy = J.DeckY - PI.PlankThickness - 0.4
	for _, x in { x0 + 1.2, x1 - 1.2 } do
		Geo.Block(
			model,
			CFrame.new(x, sy, (J.MinZ + J.MaxZ) / 2),
			Vector3.new(0.6, 0.8, J.MaxZ - J.MinZ - 1),
			C.WoodDark,
			MAT.Wood,
			{ Shadow = false }
		)
	end
	local westPiles: { Part } = {}
	local eastPiles: { Part } = {}
	local z = J.MinZ + 3
	while z < J.MaxZ do
		table.insert(westPiles, pile(model, x0 + 0.4, z, postTop, 1.0))
		table.insert(eastPiles, pile(model, x1 - 0.4, z, postTop, 1.0))
		z += 10
	end
	table.insert(westPiles, pile(model, x0 + 0.4, J.MaxZ - 0.6, postTop, 1.0))
	table.insert(eastPiles, pile(model, x1 - 0.4, J.MaxZ - 0.6, postTop, 1.0))
	for i = 1, #westPiles - 1 do
		rope(westPiles[i], westPiles[i + 1], J.DeckY + PI.RopeHeight, 0.4)
	end
	-- Papan "Kapal ke Laut Dalam" di pangkal jetty
	local sp = Vector3.new(x0 - 2.6, 0, J.MinZ + 1.5)
	local g = Geo.GroundY(sp.X, sp.Z)
	local scf = Geo.Facing(Vector3.new(sp.X, g, sp.Z), Vector3.new(-0.7, 0, -0.7))
	for _, sx in { -1, 1 } do
		Geo.Post(model, at(scf, sx * 3.0, -0.6, 0), 4.6, 0.45, C.WoodPost, MAT.Wood, { Collide = true })
	end
	Geo.Sign(
		model,
		scf * CFrame.new(0, 3.0, -0.05),
		Vector3.new(6.4, 1.5, 0.25),
		TX.Ferry,
		{ BothSides = true, MaxTextSize = 44 }
	)

	-- Feri tertambat + papan titian + tali tambat
	local F = PI.Ferry
	local ferry = buildFerry(root, "FeriPantai", F.Pos, F.Face, rng)
	local plankA = Vector3.new(x1 - 0.2, J.DeckY - 0.12, F.Pos.Z - 3)
	local plankB = Vector3.new(F.Pos.X - 2.4, 1.9, F.Pos.Z - 3)
	Geo.Plank(model, plankA, plankB, 1.6, 0.25, UP, C.WoodDeck, MAT.WoodPlanks, { Collide = true, Shadow = false })
	local primary = ferry.PrimaryPart
	if primary then
		for _, targetZ in { F.Pos.Z - 8.5, F.Pos.Z + 8.5 } do
			local best: Part? = nil
			local bestD = math.huge
			for _, post in eastPiles do
				local dz = math.abs(post.CFrame.Position.Z - targetZ)
				if dz < bestD then
					best, bestD = post, dz
				end
			end
			if best then
				local a0 = Geo.Attach(best, pileTop(best) - Vector3.new(0, 0.4, 0))
				local a1 = Geo.Attach(primary, Vector3.new(F.Pos.X - 2.4, 2.1, targetZ))
				Geo.Rope(a0, a1, 0.6, 0.18, C.Rope)
			end
		end
	end

	local A = PI.FerryArrivalShore
	Geo.Marker(ctx.Points, "FerryArrival_Shore", Geo.Facing(A.Pos, A.Face), Vector3.new(2, 1, 2))
	ctx.Npc.nahkoda_jaka = Geo.Facing(PI.JakaSpot.Pos, PI.JakaSpot.Face)
end

-- ===================================================================== platform laut dalam

local function buildDeepSea(ctx: Geo.Context, root: Model, rng: Random)
	local D = PI.DeepSea
	local model = Geo.Model(root, "PlatformLautDalam")
	local cx, cz, A = D.Center.X, D.Center.Z, D.Apothem
	local diag = A * (1 + math.tan(math.rad(22.5)))
	local Y = D.DeckY
	-- Dek oktagon: baris papan sejajar X, tiap baris dipotong di sisi miring.
	local pitch, width = 3.45, 3.3
	local rows = math.floor(2 * A / pitch)
	local z0 = cz - rows * pitch / 2 + pitch / 2
	for r = 0, rows - 1 do
		local z = z0 + r * pitch
		local dz = math.abs(z - cz) + width / 2
		local half = math.min(A, diag - dz)
		local split = rng:NextNumber(-half * 0.5, half * 0.5)
		for _, seg in { { -half, split }, { split, half } } do
			local len = seg[2] - seg[1] - 0.12
			if len > 1 then
				local th = 0.6 + rng:NextNumber(-0.03, 0.03)
				Geo.Block(
					model,
					CFrame.new(cx + (seg[1] + seg[2]) / 2, Y - th / 2 + rng:NextNumber(-0.02, 0.02), z),
					Vector3.new(len, th, width),
					weathered(rng),
					MAT.Wood,
					{ Collide = true, Shadow = false, Jitter = 0.06 }
				)
			end
		end
	end
	-- Balok tepi, tiang pancang di sudut + tengah, pagar tali (sisi utara terbuka untuk kapal)
	local R = A / math.cos(math.rad(22.5))
	local corners: { Part } = {}
	local cornerPos: { Vector3 } = {}
	for k = 0, 7 do
		local a = math.rad(22.5 + k * 45)
		local p = Vector3.new(cx + math.cos(a) * (R - 0.8), 0, cz + math.sin(a) * (R - 0.8))
		table.insert(cornerPos, p)
		table.insert(corners, pile(model, p.X, p.Z, Y + PI.PostAbove, 1.3))
	end
	for k = 1, 8 do
		local a, b = cornerPos[k], cornerPos[k % 8 + 1]
		Geo.Segment(
			model,
			Vector3.new(a.X, Y - 0.5, a.Z),
			Vector3.new(b.X, Y - 0.5, b.Z),
			0.85,
			C.WoodPost,
			MAT.Wood,
			{ Extend = 0.4, Shadow = false }
		)
		local mid = (a + b) / 2
		local northEdge = mid.Z < cz - A * 0.8
		if not northEdge then
			rope(corners[k], corners[k % 8 + 1], Y + PI.RopeHeight, 0.9)
		end
	end
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			pile(model, cx + sx * 16, cz + sz * 16, Y - 0.6, 1.4)
		end
	end
	-- Gubuk istirahat
	local H = D.Hut
	local hut = Geo.Model(model, "GubukPlatform", PERSISTENT)
	buildHut(hut, Geo.Facing(H.Pos, Vector3.new(0, 0, -1)), {
		Width = H.Size.X,
		Depth = H.Size.Z,
		WallHeight = 5.8,
		DoorX = -2.4,
		Sign = TX.DeepSea,
		Bench = false,
		BenchX = 0,
		Flicker = false,
	})
	-- Lampu di empat sudut miring
	for _, k in { 1, 3, 5, 7 } do
		local p = cornerPos[k]
		local inward = Geo.Flat(Vector3.new(cx, 0, cz) - p).Unit
		Geo.LampPost(model, Vector3.new(p.X, Y, p.Z) + inward * 2.6, 6.8, 24)
	end
	-- Tiang bendera
	local fp = Vector3.new(cx + 9, Y, cz + 10)
	Geo.Post(model, fp - Vector3.new(0, 0.3, 0), 12.3, 0.35, C.White, MAT.Metal, { Collide = true })
	Geo.Block(
		model,
		CFrame.new(fp + Vector3.new(1.75, 10.9, 0)),
		Vector3.new(3.2, 1.0, 0.07),
		C.FlagRed,
		MAT.Fabric,
		{ Shadow = false, Jitter = 0 }
	)
	Geo.Block(
		model,
		CFrame.new(fp + Vector3.new(1.75, 9.9, 0)),
		Vector3.new(3.2, 1.0, 0.07),
		C.FlagWhite,
		MAT.Fabric,
		{ Shadow = false, Jitter = 0 }
	)
	-- Muatan: peti, tong, gulungan tali, kotak ikan
	local crates = {
		Vector3.new(cx - 14, Y, cz - 6),
		Vector3.new(cx - 15.8, Y, cz - 3.8),
		Vector3.new(cx - 14.6, Y + 1.5, cz - 5.2),
	}
	for i, p in crates do
		Geo.Block(
			model,
			CFrame.new(p + Vector3.new(0, 0.75, 0)) * CFrame.Angles(0, math.rad(Geo.Rand(-15, 15) + i * 10), 0),
			Vector3.new(1.6, 1.5, 1.6),
			C.WoodLight,
			MAT.WoodPlanks,
			{ Collide = true }
		)
	end
	Geo.Barrel(model, Vector3.new(cx + 15, Y, cz - 8), 1.8, 2.4, C.Blue, C.Teal, MAT.Glass)
	Geo.Barrel(model, Vector3.new(cx + 16.6, Y, cz - 5.6), 1.6, 2.1, C.WoodDeck, C.WoodDark)
	Geo.RopeCoil(model, Vector3.new(cx - 6, Y, cz - 25), 2.4)
	Geo.RopeCoil(model, Vector3.new(cx + 20, Y, cz + 14), 2.2)
	for k = 1, 2 do
		local bcf = CFrame.new(cx + 4 + k * 2.4, Y + 0.6, cz + 22) * CFrame.Angles(0, math.rad(k * 9), 0)
		Geo.Block(model, bcf, Vector3.new(2.0, 1.2, 1.4), C.White, MAT.SmoothPlastic, { Collide = true })
		Geo.Block(
			model,
			bcf * CFrame.new(0, 0.66, 0),
			Vector3.new(2.1, 0.12, 1.5),
			C.Teal,
			MAT.SmoothPlastic,
			{ Shadow = false }
		)
	end

	-- Kapal pulang tertambat di sisi utara + titian
	local Bt = D.Boat
	local boat = buildFerry(root, "KapalPulang", Bt.Pos, Bt.Face, rng)
	local edgeZ = cz - A
	Geo.Plank(
		model,
		Vector3.new(cx, Y - 0.1, edgeZ + 0.6),
		Vector3.new(cx, 1.9, Bt.Pos.Z + 2.2),
		1.7,
		0.25,
		UP,
		C.WoodDeck,
		MAT.WoodPlanks,
		{ Collide = true, Shadow = false }
	)
	local primary = boat.PrimaryPart
	if primary then
		for _, k in { 6, 7 } do
			local post = corners[k]
			local top = pileTop(post)
			local a0 = Geo.Attach(post, top - Vector3.new(0, 0.4, 0))
			local a1 = Geo.Attach(primary, Vector3.new(top.X * 0.7 + Bt.Pos.X * 0.3, 2.1, Bt.Pos.Z + 2.6))
			Geo.Rope(a0, a1, 0.7, 0.18, C.Rope)
		end
	end

	local Ar = D.Arrival
	Geo.Marker(ctx.Points, "FerryArrival_DeepSea", Geo.Facing(Ar.Pos, Ar.Face), Vector3.new(2, 1, 2))
	ctx.Npc.awak_kapal = Geo.Facing(D.AwakSpot.Pos, D.AwakSpot.Face)
end

-- ===================================================================== titian & papan arah

local function buildPaths(root: Model, rng: Random)
	local model = Geo.Model(root, "TitianKayu")
	for _, path in MapConfig.Paths do
		local poly = Geo.PathPolyline(path.Name)
		local pitch = if path.Stepping then 4.3 else 1.78
		local positions, tangents = Geo.Resample(poly, pitch)
		for i, p in positions do
			local t = tangents[i]
			local across = t:Cross(UP).Unit
			local g = Geo.GroundY(p.X, p.Z)
			local gA = Geo.GroundY(p.X + t.X * 0.7, p.Z + t.Z * 0.7)
			local gB = Geo.GroundY(p.X - t.X * 0.7, p.Z - t.Z * 0.7)
			local slope = (t * 1.4 + Vector3.new(0, gA - gB, 0)).Unit
			local up = across:Cross(slope)
			if up.Y < 0 then
				up = -up
			end
			local thick = 0.5
			local center = Vector3.new(p.X, g + 0.3 - thick / 2, p.Z)
			local half = path.Width / 2
			if path.Stepping then
				local yaw = math.rad(rng:NextNumber(-12, 12))
				local dir = CFrame.fromAxisAngle(UP, yaw):VectorToWorldSpace(across)
				local off = t * rng:NextNumber(-0.4, 0.4)
				Geo.Plank(
					model,
					center + off - dir * half,
					center + off + dir * half,
					1.7,
					thick,
					up,
					weathered(rng),
					MAT.Wood,
					{ Collide = true, Shadow = false }
				)
			else
				local e = rng:NextNumber(-0.15, 0.15)
				Geo.Plank(
					model,
					center - across * (half + e),
					center + across * (half - e),
					1.55,
					thick + rng:NextNumber(-0.03, 0.03),
					up,
					if rng:NextNumber() < 0.5 then C.WoodDeck else C.WoodWeathered,
					MAT.Wood,
					{ Collide = true, Shadow = false, Jitter = 0.06 }
				)
			end
		end
	end
	for _, sp in MapConfig.Signposts do
		local base = Vector3.new(sp.Pos.X, Geo.GroundY(sp.Pos.X, sp.Pos.Z), sp.Pos.Z)
		Geo.Signpost(model, base, sp.Arrows)
	end
end

function Pier.Build(ctx: Geo.Context)
	local rng = Geo.Rng(MapConfig.SeedOffsets.Pier)
	local root = Geo.Model(ctx.Root, "Dermaga")
	buildMainPier(ctx, root, rng)
	buildJetty(ctx, root, rng)
	buildDeepSea(ctx, root, rng)
	buildPaths(root, rng)
end

return Pier
