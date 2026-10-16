--!strict
-- Kapal pinisi berlabuh di (−60, 0, 360): lambung kayu dengan garis sheer melengkung (buritan tinggi),
-- haluan runcing naik dengan cucur (bowsprit), dua tiang, layar gaf trapesium + layar puncak + tiga layar
-- haluan (Fabric krem), tali-temali, bendera Merah Putih, rantai jangkar. Model bertag Bobbing.

local MapConfig = require(script.Parent.MapConfig)
local Geo = require(script.Parent.Geo)

local PN = MapConfig.Pinisi
local C = MapConfig.Colors
local MAT = Enum.Material
local UP = Vector3.yAxis

local Pinisi = {}

local function sailOpts(): Geo.Opts
	return { Shadow = true, Jitter = 0.03 }
end

function Pinisi.Build(ctx: Geo.Context)
	local rng = Geo.Rng(MapConfig.SeedOffsets.Pinisi)
	local model = Geo.Model(ctx.Root, "KapalPinisi", Enum.ModelStreamingMode.Atomic)
	local cf = Geo.Facing(PN.Pos + Vector3.new(0, 0.1, 0), PN.Face)
	local function w(v: Vector3): Vector3
		return cf:PointToWorldSpace(v)
	end

	local hull = Geo.Hull(model, cf, {
		Length = PN.Length,
		HalfBeam = PN.HalfBeam,
		Freeboard = PN.Freeboard,
		BowRise = PN.BowRise,
		SternRise = PN.SternRise,
		KeelDepth = PN.KeelDepth,
		Strakes = { C.WoodDeck, C.WoodDark, Color3.fromRGB(112, 52, 40) },
		Segments = 8,
		Thickness = 0.35,
		Material = MAT.WoodPlanks,
		SternFull = 0.7,
		Collide = false,
		Posts = true,
		RailColor = C.White,
	})
	local L = PN.Length
	local function zt(t: number): number
		return hull.Z(t)
	end
	local function deckY(t: number): number
		return hull.Sheer(t) - 0.6
	end

	-- Dek utama mengikuti lengkung sheer.
	local stations = { 0.12, 0.3, 0.5, 0.7, 0.86 }
	local primary: Part? = nil
	for i = 1, #stations - 1 do
		local t0, t1 = stations[i], stations[i + 1]
		local width = 2 * math.min(hull.Width(t0), hull.Width(t1)) * 0.95
		local p = Geo.Plank(
			model,
			w(Vector3.new(0, deckY(t0), zt(t0))),
			w(Vector3.new(0, deckY(t1), zt(t1))),
			width,
			0.3,
			cf:VectorToWorldSpace(UP),
			C.WoodDeck,
			MAT.WoodPlanks,
			{ Shadow = false, Extend = 0.15 }
		)
		if i == 2 then
			primary = p
		end
	end
	if primary then
		model.PrimaryPart = primary
	end
	-- Dek buritan tinggi + rumah kemudi
	local poopT = 0.06
	local poopY = hull.Sheer(poopT) - 0.5
	Geo.Block(
		model,
		cf * CFrame.new(0, poopY, zt(poopT)),
		Vector3.new(hull.Width(poopT) * 1.9, 0.35, L * 0.12),
		C.WoodDeck,
		MAT.WoodPlanks,
		{ Shadow = false }
	)
	local cabin = cf * CFrame.new(0, deckY(0.18) + 1.35, zt(0.18))
	Geo.Block(model, cabin, Vector3.new(6.2, 2.7, 5.0), C.WoodLight, MAT.WoodPlanks, { Shadow = true })
	Geo.Block(model, cabin * CFrame.new(0, 1.5, 0), Vector3.new(7.0, 0.3, 5.8), C.WoodDark, MAT.Wood, { Shadow = true })
	for _, sx in { -1, 1 } do
		Geo.Cylinder(
			model,
			cabin * CFrame.new(sx * 3.5, 1.5, 0) * CFrame.Angles(0, math.pi / 2, 0),
			5.8,
			0.45,
			C.WoodDark,
			MAT.Wood,
			{ Shadow = false }
		)
		Geo.Block(
			model,
			cabin * CFrame.new(sx * 3.12, 0.3, 0),
			Vector3.new(0.08, 0.8, 3.6),
			C.MetalDark,
			MAT.Glass,
			{ Shadow = false }
		)
	end
	-- Dek haluan
	Geo.Block(
		model,
		cf * CFrame.new(0, deckY(0.92) + 0.25, zt(0.92)),
		Vector3.new(hull.Width(0.9) * 1.7, 0.3, L * 0.09),
		C.WoodDeck,
		MAT.WoodPlanks,
		{ Shadow = false }
	)

	-- Cucur (bowsprit)
	local bowBase = Vector3.new(0, hull.Sheer(1) + 0.1, zt(1) + 1.2)
	local bowTip = bowBase + Vector3.new(0, 3.2, -12.5)
	Geo.Segment(model, w(bowBase), w(bowTip), 0.55, C.WoodDark, MAT.Wood, { Shadow = false })

	-- Tiang: utama & depan (tiang bawah + tiang atas)
	local masts = {
		{ T = 0.42, Lower = 22, Upper = 10, Boom = 7, GaffAt = 17.5, Gaff = 12 },
		{ T = 0.66, Lower = 20, Upper = 9, Boom = 9.5, GaffAt = 15.5, Gaff = 10 },
	}
	local heads: { Vector3 } = {}
	for i, m in masts do
		local z = zt(m.T)
		local foot = Vector3.new(0, deckY(m.T) - 0.3, z)
		local lowerTop = foot + Vector3.new(0, m.Lower, 0.4)
		local upperTop = lowerTop + Vector3.new(0, m.Upper - 2, 0.15)
		Geo.Segment(model, w(foot), w(lowerTop), 0.85, C.WoodDark, MAT.Wood, { Shadow = true })
		Geo.Segment(
			model,
			w(lowerTop - Vector3.new(0, 2, 0)),
			w(upperTop),
			0.5,
			C.WoodDark,
			MAT.Wood,
			{ Shadow = false }
		)
		table.insert(heads, upperTop)
		-- Boom & gaf (mengarah ke buritan, +Z lokal)
		local boomFoot = foot + Vector3.new(0, 3.0, 0.5)
		local boomEnd = boomFoot + Vector3.new(0, 0.6, m.Boom)
		local throat = foot + Vector3.new(0, m.GaffAt, 0.45)
		local peak = throat + Vector3.new(0, m.Gaff * 0.55, m.Gaff * 0.83)
		Geo.Segment(model, w(boomFoot), w(boomEnd), 0.4, C.WoodDark, MAT.Wood, { Shadow = false })
		Geo.Segment(model, w(throat), w(peak), 0.36, C.WoodDark, MAT.Wood, { Shadow = false })
		-- Layar gaf (trapesium) + layar puncak (segitiga), sedikit bergeser agar tidak sebidang.
		local off = Vector3.new(0.12 * i, 0, 0)
		Geo.Quad(
			model,
			w(boomFoot + Vector3.new(0, 0.3, 0.3) + off),
			w(throat + Vector3.new(0, -0.2, 0.3) + off),
			w(peak + Vector3.new(0, -0.3, -0.2) + off),
			w(boomEnd + Vector3.new(0, 0.25, -0.3) + off),
			0.12,
			C.Fabric,
			MAT.Fabric,
			sailOpts()
		)
		Geo.Triangle(
			model,
			w(throat + Vector3.new(0, 0.4, 0.3) + off),
			w(upperTop + Vector3.new(0, -0.6, 0.2) + off),
			w(peak + Vector3.new(0, 0.2, -0.5) + off),
			0.1,
			C.FabricShade,
			MAT.Fabric,
			sailOpts()
		)
		-- Tali-temali: dua tali samping per tiang ke bibir lambung.
		for _, side in { -1, 1 } do
			local chain = hull.Point(m.T + 0.02, 0, side) + Vector3.new(0, 0.3, 0)
			Geo.Segment(
				model,
				w(lowerTop - Vector3.new(0, 1.2, 0)),
				w(chain),
				0.12,
				C.RopeDark,
				MAT.Fabric,
				{ Shadow = false }
			)
		end
	end

	-- Layar haluan: tiga segitiga dari tiang depan ke cucur.
	local foreHead = heads[2]
	local foreFoot = Vector3.new(0, deckY(masts[2].T), zt(masts[2].T))
	local jibs = { { 0.4, 13, -0.1 }, { 0.72, 18, 0.15 }, { 1.0, 23, 0.4 } }
	for _, j in jibs do
		local tack = bowBase:Lerp(bowTip, j[1])
		local head = foreFoot + Vector3.new(j[3], j[2], 0.2)
		local clew = foreFoot + Vector3.new(j[3], 3.2, -2.2 - j[1] * 2)
		Geo.Triangle(
			model,
			w(head),
			w(tack + Vector3.new(j[3], 0.2, 0)),
			w(clew),
			0.1,
			C.Fabric,
			MAT.Fabric,
			sailOpts()
		)
	end
	-- Tali depan & belakang
	Geo.Segment(model, w(foreHead), w(bowTip), 0.12, C.RopeDark, MAT.Fabric, { Shadow = false })
	Geo.Segment(
		model,
		w(heads[1]),
		w(foreHead - Vector3.new(0, 1.5, 0)),
		0.12,
		C.RopeDark,
		MAT.Fabric,
		{ Shadow = false }
	)
	Geo.Segment(
		model,
		w(heads[1]),
		w(Vector3.new(0, hull.Sheer(0) + 0.5, zt(0) - 0.4)),
		0.12,
		C.RopeDark,
		MAT.Fabric,
		{ Shadow = false }
	)

	-- Bendera Merah Putih di puncak tiang utama & panji di tiang depan
	local flagBase = heads[1] + Vector3.new(0, 0.3, 0)
	local flagCF = cf * CFrame.new(flagBase + Vector3.new(0, -0.6, 1.3))
	Geo.Block(
		model,
		flagCF * CFrame.new(0, 0.4, 0),
		Vector3.new(0.06, 0.8, 2.4),
		C.FlagRed,
		MAT.Fabric,
		{ Shadow = false, Jitter = 0 }
	)
	Geo.Block(
		model,
		flagCF * CFrame.new(0, -0.4, 0),
		Vector3.new(0.06, 0.8, 2.4),
		C.FlagWhite,
		MAT.Fabric,
		{ Shadow = false, Jitter = 0 }
	)
	Geo.Tip(
		model,
		w(heads[2] + Vector3.new(0, -0.4, 0.2)),
		w(heads[2] + Vector3.new(0, -0.6, 3.2)),
		0.8,
		0.06,
		cf:VectorToWorldSpace(Vector3.xAxis),
		C.Yellow,
		MAT.Fabric,
		{ Shadow = false }
	)

	-- Rantai jangkar dari lubang haluan ke dalam air
	local hawse = Vector3.new(-0.9, hull.Sheer(0.95) - 0.6, zt(0.95))
	Geo.Segment(
		model,
		w(hawse),
		w(hawse + Vector3.new(-0.6, -9, -6)),
		0.2,
		C.MetalDark,
		MAT.CorrodedMetal,
		{ Shadow = false }
	)
	-- Muatan kecil di dek
	for k = 1, 2 do
		Geo.Block(
			model,
			cf
				* CFrame.new(1.4 * (k - 1.5) * 2, deckY(0.55) + 0.85, zt(0.55) + rng:NextNumber(-1, 1))
				* CFrame.Angles(0, math.rad(rng:NextNumber(-20, 20)), 0),
			Vector3.new(1.6, 1.4, 1.6),
			C.WoodLight,
			MAT.WoodPlanks,
			{ Shadow = false }
		)
	end

	model:SetAttribute("Amplitude", PN.Bob.Amplitude)
	model:SetAttribute("Speed", PN.Bob.Speed)
	model:SetAttribute("Phase", rng:NextNumber(0, math.pi * 2))
	model:SetAttribute("Tilt", PN.Bob.Tilt)
	Geo.Tag(model, "Bobbing")
end

return Pinisi
