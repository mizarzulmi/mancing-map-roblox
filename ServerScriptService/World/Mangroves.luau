--!strict
-- Laguna Bakau (barat): bakau mengelilingi laguna — batang bengkok, 5 akar tunjang melengkung (3 segmen,
-- menancap di air/lumpur), kanopi bola daun bertumpuk — titian kayu ke tengah laguna (platform nelayan),
-- jembatan lengkung di atas kanal, dan titik ambient kunang-kunang.

local MapConfig = require(script.Parent.MapConfig)
local Geo = require(script.Parent.Geo)

local MG = MapConfig.Mangroves
local LA = MapConfig.Terrain.Lagoon
local C = MapConfig.Colors
local MAT = Enum.Material
local UP = Vector3.yAxis

local Mangroves = {}

local function buildTree(model: Instance, x: number, z: number, scale: number, rng: Random)
	local g = Geo.GroundY(x, z)
	local junction = Vector3.new(x, math.max(g, 0) + 2.3 * scale, z)
	local lean = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) * (0.7 * scale)
	local mid = junction + UP * (2.3 * scale) + lean
	local top = mid + UP * (2.0 * scale) + lean * 0.6
	Geo.Segment(
		model,
		junction - UP * 0.3,
		mid,
		1.0 * scale,
		C.MangroveBark,
		MAT.Wood,
		{ Extend = 0.25, Collide = true }
	)
	Geo.Segment(model, mid, top, 0.78 * scale, C.MangroveBark, MAT.Wood, { Extend = 0.25 })

	-- Akar tunjang: dari batang melengkung keluar-naik lalu turun menancap.
	for r = 1, MG.Roots do
		local az = (r - 1) / MG.Roots * math.pi * 2 + rng:NextNumber(-0.35, 0.35)
		local dir = Vector3.new(math.cos(az), 0, math.sin(az))
		local start = junction + UP * (rng:NextNumber(0.1, 1.5) * scale) + dir * 0.35
		local reach = rng:NextNumber(2.8, 4.4) * scale
		local fx, fz = x + dir.X * reach, z + dir.Z * reach
		local foot = Vector3.new(fx, Geo.GroundY(fx, fz) - 0.35, fz)
		local ctrl = start + dir * (reach * 0.45) + UP * (0.9 * scale)
		local pts = Geo.Bezier2(start, ctrl, foot, MG.RootSegments)
		Geo.Chain(model, pts, 0.46 * scale, 0.28 * scale, C.MangroveRoot, MAT.Wood, { Shadow = false })
	end

	-- Kanopi: kubah daun pipih bertumpuk (bukan bola di atas tongkat).
	local crown = top + UP * (0.7 * scale)
	Geo.Ellipsoid(
		model,
		CFrame.new(crown) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
		Vector3.new(9.6, 5.2, 8.6) * scale,
		C.MangroveLeaf,
		MAT.LeafyGrass,
		{ Shadow = true }
	)
	for _ = 1, MG.Canopy - 1 do
		local a = rng:NextNumber(0, math.pi * 2)
		local off = Vector3.new(math.cos(a), 0, math.sin(a)) * (rng:NextNumber(3.0, 3.8) * scale)
			+ UP * (rng:NextNumber(-1.3, 0.8) * scale)
		Geo.Ellipsoid(
			model,
			CFrame.new(crown + off) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
			Vector3.new(5.8, 3.6, 5.2) * (scale * rng:NextNumber(0.9, 1.12)),
			C.MangroveLeafLight,
			MAT.LeafyGrass,
			{ Shadow = true }
		)
	end
end

local function buildBoardwalk(ctx: Geo.Context, model: Instance, rng: Random)
	local B = MG.Boardwalk
	local from, to = B.From, B.To
	local dir = Geo.Flat(to - from)
	local len = dir.Magnitude
	dir = dir.Unit
	local across = dir:Cross(UP).Unit
	local half = B.Width / 2
	local deckAt = function(p: Vector3): number
		return math.max(B.DeckY, Geo.GroundY(p.X, p.Z) + 0.3)
	end
	local n = math.floor(len / B.PlankPitch)
	for i = 0, n - 1 do
		local c = from + dir * ((i + 0.5) * B.PlankPitch)
		local top = deckAt(c)
		local center = Vector3.new(c.X, top - 0.25, c.Z)
		Geo.Plank(
			model,
			center - across * half,
			center + across * half,
			B.PlankWidth,
			0.5 + rng:NextNumber(-0.03, 0.03),
			UP,
			if rng:NextNumber() < 0.75 then C.WoodWeathered else C.WoodDeckAlt,
			MAT.Wood,
			{ Collide = true, Shadow = false, Jitter = 0.06 }
		)
	end
	-- Tiang berpasangan; sisi utara menjadi tiang pegangan tali.
	local rail: { Part } = {}
	local k = 0
	while k <= len do
		local c = from + dir * k
		local top = deckAt(c)
		for _, sgn in { -1, 1 } do
			local p = c + across * (half - 0.2) * sgn
			local g = Geo.GroundY(p.X, p.Z)
			if top - g > 0.6 then
				local isRail = sgn == -1
				local post = Geo.Segment(
					model,
					Vector3.new(p.X, g - 1, p.Z),
					Vector3.new(p.X, if isRail then top + 2.2 else top - 0.1, p.Z),
					0.55,
					C.WoodWeathered,
					MAT.Wood,
					{ Collide = isRail }
				)
				if isRail then
					table.insert(rail, post)
				end
			end
		end
		k += 6.5
	end
	-- Platform ujung (tempat nelayan) + tiang sudut.
	local P = B.Platform
	local pitch = 1.65
	local rows = math.floor((P.MaxZ - P.MinZ) / pitch)
	for r = 0, rows - 1 do
		local z = P.MinZ + (P.MaxZ - P.MinZ - rows * pitch) / 2 + pitch / 2 + r * pitch
		Geo.Block(
			model,
			CFrame.new((P.MinX + P.MaxX) / 2, B.DeckY - 0.25 + rng:NextNumber(-0.02, 0.02), z),
			Vector3.new(P.MaxX - P.MinX, 0.5, 1.5),
			if rng:NextNumber() < 0.7 then C.WoodWeathered else C.WoodDeckAlt,
			MAT.Wood,
			{ Collide = true, Shadow = false, Jitter = 0.06 }
		)
	end
	local corners = {
		Vector3.new(P.MinX + 0.4, 0, P.MinZ + 0.4),
		Vector3.new(P.MaxX - 0.4, 0, P.MinZ + 0.4),
		Vector3.new(P.MinX + 0.4, 0, P.MaxZ - 0.4),
		Vector3.new(P.MaxX - 0.4, 0, P.MaxZ - 0.4),
	}
	local cornerPosts: { Part } = {}
	for _, cpos in corners do
		local g = Geo.GroundY(cpos.X, cpos.Z)
		table.insert(
			cornerPosts,
			Geo.Segment(
				model,
				Vector3.new(cpos.X, g - 1, cpos.Z),
				Vector3.new(cpos.X, B.DeckY + 2.2, cpos.Z),
				0.6,
				C.WoodWeathered,
				MAT.Wood,
				{ Collide = true }
			)
		)
	end
	for i = 1, #rail - 1 do
		local a, b = rail[i], rail[i + 1]
		local pa, pb = a.CFrame.Position, b.CFrame.Position
		local ya = pa.Y + a.Size.X / 2 - 0.35
		local yb = pb.Y + b.Size.X / 2 - 0.35
		local a0 = Geo.Attach(a, Vector3.new(pa.X, ya, pa.Z))
		local a1 = Geo.Attach(b, Vector3.new(pb.X, yb, pb.Z))
		Geo.Rope(a0, a1, 0.35, 0.18, C.Rope)
	end
	-- Tali di sisi utara platform (sisi barat dibiarkan terbuka untuk memancing).
	local nA, nB = cornerPosts[3], cornerPosts[4]
	Geo.Rope(
		Geo.Attach(nA, Vector3.new(nA.CFrame.Position.X, B.DeckY + 1.9, nA.CFrame.Position.Z)),
		Geo.Attach(nB, Vector3.new(nB.CFrame.Position.X, B.DeckY + 1.9, nB.CFrame.Position.Z)),
		0.35,
		0.18,
		C.Rope
	)
	ctx.Npc.nelayan_4 = Geo.Facing(MG.Nelayan4.Pos, MG.Nelayan4.Face)
end

-- Jembatan lengkung di atas kanal (papan mengikuti busur + pegangan lengkung).
local function buildBridge(model: Instance, rng: Random)
	local B = MG.Bridge
	local from, to = B.From, B.To
	local dir = Geo.Flat(to - from)
	local len = dir.Magnitude
	dir = dir.Unit
	local across = dir:Cross(UP).Unit
	local gA = Geo.GroundY(from.X, from.Z)
	local gB = Geo.GroundY(to.X, to.Z)
	local function deckY(t: number): number
		return (gA + 0.3) * (1 - t)
			+ (gB + 0.3) * t
			+ B.Rise * 4 * t * (1 - t)
			+ math.max(0, 1.4 - math.min(gA, gB)) * 4 * t * (1 - t)
	end
	local n = math.floor(len / 1.45)
	for i = 0, n - 1 do
		local t = (i + 0.5) / n
		local c = from + dir * (t * len)
		local y = deckY(t)
		local slope = (deckY(math.min(1, t + 0.02)) - deckY(math.max(0, t - 0.02))) / (0.04 * len)
		local up = (UP - dir * slope).Unit
		local center = Vector3.new(c.X, y - 0.22, c.Z)
		Geo.Plank(
			model,
			center - across * (B.Width / 2),
			center + across * (B.Width / 2),
			1.3,
			0.44,
			up,
			C.WoodDeck,
			MAT.Wood,
			{ Collide = true, Shadow = false, Jitter = 0.06 }
		)
	end
	for _, sgn in { -1, 1 } do
		local railPts: { Vector3 } = {}
		for i = 0, 4 do
			local t = i / 4
			local c = from + dir * (t * len) + across * (sgn * (B.Width / 2 - 0.1))
			table.insert(railPts, Vector3.new(c.X, deckY(t) + 1.9, c.Z))
		end
		Geo.Chain(model, railPts, 0.3, 0.3, C.Bamboo, MAT.Wood, { Shadow = false })
		for _, t in { 0.02, 0.5, 0.98 } do
			local c = from + dir * (t * len) + across * (sgn * (B.Width / 2 - 0.1))
			local y = deckY(t)
			local g = Geo.GroundY(c.X, c.Z)
			Geo.Segment(
				model,
				Vector3.new(c.X, math.min(g, y) - 1.2, c.Z),
				Vector3.new(c.X, y + 2.0, c.Z),
				0.4,
				C.Bamboo,
				MAT.Wood,
				{ Collide = true, Jitter = rng:NextNumber(0.02, 0.05) }
			)
		end
	end
end

function Mangroves.Build(ctx: Geo.Context)
	local rng = Geo.Rng(MapConfig.SeedOffsets.Mangroves)
	local model = Geo.Model(ctx.Root, "LagunaBakau")
	for i, deg in MG.RingAngles do
		local a = math.rad(deg)
		local d = MG.RingD[i] or 1
		local x = LA.X + LA.RX * d * math.cos(a)
		local z = LA.Z + LA.RZ * d * math.sin(a)
		local tree = Geo.Model(model, string.format("Bakau_%02d", i))
		buildTree(tree, x, z, rng:NextNumber(0.9, 1.15), rng)
	end
	for i, p in MG.Islet do
		local tree = Geo.Model(model, string.format("BakauPulau_%d", i))
		buildTree(tree, p.X, p.Z, 0.85, rng)
	end
	buildBoardwalk(ctx, model, rng)
	buildBridge(model, rng)
	for i, f in MG.Fireflies do
		Geo.Marker(
			ctx.AmbientPoints,
			string.format("%s_%d", f.Kind, i),
			CFrame.new(f.Pos),
			Vector3.new(1, 1, 1),
			{ Kind = f.Kind, Radius = f.Radius }
		)
	end
end

return Mangroves
