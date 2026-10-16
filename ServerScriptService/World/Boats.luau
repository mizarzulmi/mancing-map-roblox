--!strict
-- Jukung bercadik: 3 ditarik ke pasir (sedikit miring mengikuti lereng pantai) dan 2 tertambat di dermaga
-- (Model bertag Bobbing). Lambung dari lajur papan lengkung (Geo.Hull), haluan & buritan naik meruncing,
-- mata jukung di haluan, cat cerah dua warna, cadik bambu di dua sisi dengan batang penghubung melengkung.

local MapConfig = require(script.Parent.MapConfig)
local Geo = require(script.Parent.Geo)

local B = MapConfig.Boats
local J = B.Jukung
local PI = MapConfig.Pier
local C = MapConfig.Colors
local MAT = Enum.Material

local Boats = {}

local function lp(cf: CFrame, v: Vector3): Vector3
	return cf:PointToWorldSpace(v)
end

local function buildJukung(parent: Instance, def: MapConfig.BoatDef, index: number, rng: Random): Model
	local model =
		Geo.Model(parent, string.format("Jukung_%d", index), if def.Moored then Enum.ModelStreamingMode.Atomic else nil)
	local face = Geo.Flat(def.Face).Unit
	local cf: CFrame
	if def.Moored then
		cf = Geo.Facing(Vector3.new(def.Pos.X, 0.05, def.Pos.Z), face)
	else
		-- Di pasir: lunas menyentuh pasir, ikut miring lereng, sedikit oleng (buatan tangan).
		local half = J.Length * 0.42
		local bow = def.Pos + face * half
		local stern = def.Pos - face * half
		local lift = J.KeelDepth - 0.25
		local pb = Vector3.new(bow.X, Geo.GroundY(bow.X, bow.Z) + lift, bow.Z)
		local ps = Vector3.new(stern.X, Geo.GroundY(stern.X, stern.Z) + lift, stern.Z)
		local center = (pb + ps) / 2
		local gc = Geo.GroundY(def.Pos.X, def.Pos.Z) + lift
		center = Vector3.new(center.X, math.max(center.Y, gc), center.Z)
		cf = CFrame.lookAt(center, center + (pb - ps)) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-3, 3)))
	end

	local spec: Geo.HullSpec = {
		Length = J.Length,
		HalfBeam = J.HalfBeam,
		Freeboard = J.Freeboard,
		BowRise = J.BowRise,
		SternRise = J.SternRise,
		KeelDepth = J.KeelDepth,
		Strakes = { def.Top, def.Bottom },
		Segments = 6,
		Thickness = 0.2,
		Material = MAT.Wood,
		SternFull = 0,
		Collide = not def.Moored,
		Posts = false,
		RailColor = nil,
	}
	local hull = Geo.Hull(model, cf, spec)
	local L = J.Length

	-- Haluan & buritan menjulang meruncing (paruh jukung).
	local b0 = Vector3.new(0, hull.Sheer(1) - 0.15, -L / 2 + 0.35)
	local bowPts = { lp(cf, b0), lp(cf, b0 + Vector3.new(0, 0.95, -1.5)), lp(cf, b0 + Vector3.new(0, 1.2, -2.45)) }
	Geo.Chain(model, bowPts, 0.42, 0.18, def.Top, MAT.Wood, { Shadow = false })
	local s0 = Vector3.new(0, hull.Sheer(0) - 0.15, L / 2 - 0.35)
	local sternPts = { lp(cf, s0), lp(cf, s0 + Vector3.new(0, 0.75, 1.1)), lp(cf, s0 + Vector3.new(0, 0.92, 1.75)) }
	Geo.Chain(model, sternPts, 0.38, 0.18, def.Top, MAT.Wood, { Shadow = false })

	-- Mata jukung di kedua sisi haluan.
	for _, side in { -1, 1 } do
		local p = hull.Point(0.85, 0.22, side)
		local n = Vector3.new(side, 0.25, 0).Unit
		local axisW = cf:VectorToWorldSpace(n)
		Geo.Cylinder(
			model,
			Geo.AlongX(lp(cf, p + n * 0.1), axisW),
			0.06,
			0.55,
			C.White,
			MAT.SmoothPlastic,
			{ Shadow = false, Jitter = 0 }
		)
		Geo.Cylinder(
			model,
			Geo.AlongX(lp(cf, p + n * 0.15), axisW),
			0.06,
			0.26,
			C.MetalDark,
			MAT.SmoothPlastic,
			{ Shadow = false, Jitter = 0 }
		)
	end

	-- Cadik bambu: pelampung lurus + ujung naik, dua batang penghubung melengkung.
	local fo, fl = J.FloatOffset, J.FloatLength
	for _, side in { -1, 1 } do
		local x = side * fo
		local midHalf = fl / 2 - 1.4
		local a = Vector3.new(x, -0.12, -midHalf)
		local b = Vector3.new(x, -0.12, midHalf)
		Geo.Segment(model, lp(cf, a), lp(cf, b), 0.5, C.Bamboo, MAT.Wood, { Collide = not def.Moored, Extend = 0.1 })
		Geo.Segment(
			model,
			lp(cf, a),
			lp(cf, a + Vector3.new(0, 0.5, -1.5)),
			0.42,
			C.Bamboo,
			MAT.Wood,
			{ Shadow = false, Extend = 0.1 }
		)
		Geo.Segment(
			model,
			lp(cf, b),
			lp(cf, b + Vector3.new(0, 0.5, 1.5)),
			0.42,
			C.Bamboo,
			MAT.Wood,
			{ Shadow = false, Extend = 0.1 }
		)
	end
	for _, z in { -2.4, 2.6 } do
		local pts = Geo.Bezier3(
			Vector3.new(-fo, 0.05, z),
			Vector3.new(-fo * 0.65, 1.75, z),
			Vector3.new(fo * 0.65, 1.75, z),
			Vector3.new(fo, 0.05, z),
			4
		)
		local world: { Vector3 } = {}
		for _, p in pts do
			table.insert(world, lp(cf, p))
		end
		Geo.Chain(model, world, 0.3, 0.3, C.BambooDark, MAT.Wood, { Shadow = false })
	end

	-- Papan duduk melintang.
	local thwart = Geo.Block(
		model,
		cf * CFrame.new(0, hull.Sheer(0.5) - 0.05, 0.8),
		Vector3.new(hull.Width(0.5) * 2 + 0.2, 0.15, 0.55),
		C.WoodDeck,
		MAT.Wood,
		{ Shadow = false }
	)
	model.PrimaryPart = thwart

	if def.Mast then
		local mastBase = Vector3.new(0, -0.2, -2.0)
		local mastTop = mastBase + Vector3.new(0, 5.4, 0.5)
		Geo.Segment(model, lp(cf, mastBase), lp(cf, mastTop), 0.25, C.BambooDark, MAT.Wood, { Shadow = false })
		Geo.Segment(
			model,
			lp(cf, mastTop + Vector3.new(0, -0.3, -0.4)),
			lp(cf, Vector3.new(0, 1.1, 4.6)),
			0.6,
			C.Fabric,
			MAT.Fabric,
			{ Shadow = false }
		)
	end
	if def.Paddle then
		local a = Vector3.new(-0.35, 0.55, -3.2)
		local b = Vector3.new(0.3, 0.75, 0.6)
		Geo.Segment(model, lp(cf, a), lp(cf, b), 0.14, C.WoodLight, MAT.Wood, { Shadow = false })
		Geo.Ellipsoid(
			model,
			cf * CFrame.new(b + Vector3.new(0.1, 0.05, 0.7)) * CFrame.Angles(0, math.rad(10), 0),
			Vector3.new(0.5, 0.12, 1.4),
			C.WoodLight,
			MAT.Wood,
			{ Shadow = false }
		)
	end

	if def.Moored then
		model:SetAttribute("Amplitude", B.Bob.Amplitude)
		model:SetAttribute("Speed", B.Bob.Speed)
		model:SetAttribute("Phase", rng:NextNumber(0, math.pi * 2))
		model:SetAttribute("Tilt", B.Bob.Tilt)
		Geo.Tag(model, "Bobbing")
	end
	return model
end

-- Tonggak tambat kecil di tepi dek dermaga + tali dari paruh haluan.
local function moor(parent: Instance, boat: Model, def: MapConfig.BoatDef)
	local primary = boat.PrimaryPart
	if not primary then
		return
	end
	local face = Geo.Flat(def.Face).Unit
	local bowTip = def.Pos + face * (J.Length / 2 + 2.2) + Vector3.new(0, J.Freeboard + J.BowRise + 1.3, 0)
	local side = if def.Pos.X < PI.X then -1 else 1
	local edgeX = PI.X + side * (PI.HalfWidth - 0.6)
	local postZ = def.Pos.Z + face.Z * (J.Length / 2 - 3)
	local post =
		Geo.Post(parent, Vector3.new(edgeX, PI.DeckY - 0.2, postZ), 1.4, 0.6, C.WoodDark, MAT.Wood, { Collide = true })
	local a0 = Geo.Attach(post, Vector3.new(edgeX, PI.DeckY + 1.05, postZ))
	local a1 = Geo.Attach(primary, bowTip)
	Geo.Rope(a0, a1, 0.9, 0.16, C.Rope)
end

function Boats.Build(ctx: Geo.Context)
	local rng = Geo.Rng(MapConfig.SeedOffsets.Boats)
	local model = Geo.Model(ctx.Root, "PerahuJukung")
	for i, def in B.List do
		local boat = buildJukung(model, def, i, rng)
		if def.Moored then
			moor(model, boat, def)
		end
	end
end

return Boats
