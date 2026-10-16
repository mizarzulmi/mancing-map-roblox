--!strict
-- Mercusuar di tanjung batu (220, tinggi tanah, 180), tinggi ±60: alas batu bertingkat, menara dari
-- tumpukan silinder mengecil belang merah-putih, balkon + pagar, ruang lampu kaca bermulion, kubah,
-- lampu Neon berputar (Model bertag Spin, atribut SpinSpeed) dengan SpotLight & Beam sinar (NightLight),
-- pintu lengkung, jendela bulat, lentera pintu.

local MapConfig = require(script.Parent.MapConfig)
local Geo = require(script.Parent.Geo)

local LH = MapConfig.Lighthouse
local C = MapConfig.Colors
local MAT = Enum.Material
local UP = Vector3.yAxis

local Lighthouse = {}

local DRUMS = 8
local DRUM_H = 5

function Lighthouse.Build(ctx: Geo.Context)
	local model = Geo.Model(ctx.Root, "Mercusuar")
	local cx, cz = LH.Pos.X, LH.Pos.Z
	local gC = Geo.GroundY(cx, cz)
	local gMin = gC
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		gMin = math.min(gMin, Geo.GroundY(cx + math.cos(a) * 8, cz + math.sin(a) * 8))
	end
	local y0 = gC + 1.0
	local bottom = gMin - 1.5
	local center = Vector3.new(cx, 0, cz)

	-- Alas batu bertingkat
	Geo.Disk(
		model,
		Vector3.new(cx, (y0 - 0.55 + bottom) / 2, cz),
		y0 - 0.55 - bottom,
		16.5,
		C.StoneDark,
		MAT.Slate,
		{ Collide = true }
	)
	Geo.Disk(model, Vector3.new(cx, (y0 + bottom) / 2, cz), y0 - bottom, 13.6, C.Stone, MAT.Slate, { Collide = true })

	-- Menara belang (silinder mengecil)
	local radii: { number } = {}
	for i = 1, DRUMS do
		local d = 11 - (i - 1) * 0.5
		radii[i] = d / 2
		Geo.Post(
			model,
			Vector3.new(cx, y0 + (i - 1) * DRUM_H - 0.02, cz),
			DRUM_H + 0.04,
			d,
			if i % 2 == 1 then C.LighthouseWhite else C.LighthouseRed,
			MAT.Concrete,
			{ Collide = true, Shadow = true, Jitter = 0.015 }
		)
	end
	local topY = y0 + DRUMS * DRUM_H

	-- Balkon + pagar
	Geo.Disk(model, Vector3.new(cx, topY + 0.3, cz), 0.6, 12.4, C.LighthouseRed, MAT.Concrete, { Collide = true })
	local railR, railH = 5.9, 1.45
	local railPts: { Vector3 } = {}
	for k = 0, 9 do
		local a = k / 10 * math.pi * 2
		local p = Vector3.new(cx + math.cos(a) * railR, topY + 0.6, cz + math.sin(a) * railR)
		Geo.Post(model, p, railH, 0.2, C.White, MAT.Metal, { Shadow = false })
		table.insert(railPts, p + Vector3.new(0, railH - 0.08, 0))
	end
	table.insert(railPts, railPts[1])
	Geo.Chain(model, railPts, 0.2, 0.2, C.White, MAT.Metal, { Shadow = false })

	-- Ruang lampu kaca bermulion + kubah + kenop
	local roomBase = topY + 0.6
	Geo.Post(model, Vector3.new(cx, roomBase, cz), 0.9, 7.4, C.MetalDark, MAT.Metal, { Collide = true })
	local glassBottom = roomBase + 0.9
	local glassH = 5.0
	Geo.Post(
		model,
		Vector3.new(cx, glassBottom, cz),
		glassH,
		6.3,
		C.Glass,
		MAT.Glass,
		{ Transparency = 0.5, Shadow = false, Jitter = 0 }
	)
	for k = 0, 5 do
		local a = (k + 0.5) / 6 * math.pi * 2
		Geo.Post(
			model,
			Vector3.new(cx + math.cos(a) * 3.15, glassBottom, cz + math.sin(a) * 3.15),
			glassH,
			0.2,
			C.MetalDark,
			MAT.Metal,
			{ Shadow = false }
		)
	end
	local ringTop = glassBottom + glassH
	Geo.Post(model, Vector3.new(cx, ringTop, cz), 0.5, 7.0, C.MetalDark, MAT.Metal, { Shadow = false })
	Geo.Ellipsoid(
		model,
		CFrame.new(cx, ringTop + 0.5, cz),
		Vector3.new(6.8, 4.6, 6.8),
		C.LighthouseRed,
		MAT.Metal,
		{ Shadow = true }
	)
	Geo.Post(model, Vector3.new(cx, ringTop + 2.6, cz), 1.2, 0.5, C.MetalDark, MAT.Metal, { Shadow = false })
	Geo.Ball(model, Vector3.new(cx, ringTop + 4.0, cz), 0.8, C.MetalDark, MAT.Metal, { Shadow = false })
	Geo.Post(model, Vector3.new(cx, ringTop + 4.3, cz), 2.2, 0.1, C.MetalDark, MAT.Metal, { Shadow = false })

	-- Lampu berputar (Spin) di atas tiang dudukan
	local lampY = glassBottom + 1.6
	Geo.Post(
		model,
		Vector3.new(cx, glassBottom, cz),
		lampY - 0.7 - glassBottom,
		0.9,
		C.MetalDark,
		MAT.Metal,
		{ Shadow = false }
	)
	local spin = Geo.Model(model, "LampuPutar", Enum.ModelStreamingMode.Atomic)
	local core = Geo.Ball(spin, Vector3.new(cx, lampY, cz), 1.4, C.LampGlass, MAT.Neon, { Shadow = false, Jitter = 0 })
	Geo.PointLight(core, { Range = 24, Brightness = 2.2, Color = C.LampGlass, Night = true })
	for _, side in { -1, 1 } do
		local dir = Vector3.new(side, 0, 0)
		Geo.Cylinder(
			spin,
			CFrame.new(cx + side * 1.15, lampY, cz),
			1.5,
			1.0,
			C.MetalDark,
			MAT.Metal,
			{ Shadow = false }
		)
		local lens = Geo.Cylinder(
			spin,
			CFrame.new(cx + side * 1.95, lampY, cz),
			0.12,
			0.86,
			C.LampGlass,
			MAT.Neon,
			{ Shadow = false, Jitter = 0 }
		)
		Geo.SpotLight(lens, {
			Face = if side > 0 then Enum.NormalId.Right else Enum.NormalId.Left,
			Range = 60,
			Brightness = 6,
			Angle = 24,
			Color = C.LampGlass,
			Night = true,
		})
		-- Sinar cahaya (Beam) — dinyalakan client saat malam lewat tag NightLight.
		local a0 = Geo.Attach(lens, lens.CFrame.Position, dir)
		local a1 = Geo.Attach(lens, lens.CFrame.Position + dir * 85, dir)
		local beam = Instance.new("Beam")
		beam.Attachment0 = a0
		beam.Attachment1 = a1
		beam.Width0 = 1.2
		beam.Width1 = 16
		beam.FaceCamera = true
		beam.Segments = 1
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.Color = ColorSequence.new(C.LampGlass)
		beam.Transparency = NumberSequence.new(0.55, 1)
		beam.Enabled = false
		beam.Parent = lens
		Geo.Tag(beam, "NightLight")
	end
	spin.PrimaryPart = core
	spin:SetAttribute("SpinSpeed", LH.SpinSpeed)
	Geo.Tag(spin, "Spin")

	-- Pintu lengkung menghadap pantai
	local face = Geo.Flat(LH.DoorFace).Unit
	local r0 = radii[1]
	local doorPos = center + face * (r0 + 0.12) + Vector3.new(0, y0 + 1.6, 0)
	local doorCF = Geo.Facing(doorPos, face)
	Geo.Block(model, doorCF, Vector3.new(2.0, 3.0, 0.4), C.WoodDark, MAT.Wood, { Collide = true, Shadow = false })
	Geo.Cylinder(
		model,
		doorCF * CFrame.new(0, 1.5, -0.04) * CFrame.Angles(0, math.pi / 2, 0),
		0.4,
		2.0,
		C.WoodDark,
		MAT.Wood,
		{ Shadow = false }
	)
	-- Lentera pintu (malam)
	local side = face:Cross(UP).Unit
	local bracket = center + face * (r0 + 0.1) + side * 1.7 + Vector3.new(0, y0 + 3.9, 0)
	Geo.Segment(model, bracket - face * 0.1, bracket + face * 0.8, 0.12, C.MetalDark, MAT.Metal, { Shadow = false })
	Geo.Lantern(model, bracket + face * 0.8 - Vector3.new(0, 0.7, 0), 0.8, false, 16)

	-- Jendela bulat (sumbu radial), bergantian arah
	local baseAngle = math.atan2(face.Z, face.X)
	for k = 1, 4 do
		local i = k * 2
		local a = baseAngle + k * math.rad(75)
		local radial = Vector3.new(math.cos(a), 0, math.sin(a))
		local pos = center + radial * (radii[i] - 0.15) + Vector3.new(0, y0 + (i - 0.5) * DRUM_H, 0)
		Geo.Cylinder(model, Geo.AlongX(pos, radial), 0.5, 1.0, C.MetalDark, MAT.Glass, { Shadow = false, Jitter = 0 })
	end
end

return Lighthouse
