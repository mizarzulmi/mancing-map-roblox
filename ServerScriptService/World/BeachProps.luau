--!strict
-- Properti pantai: area santai (payung + kursi berjemur, voli, api unggun + bangku gelondong, istana pasir,
-- rak papan selancar, ayunan tali di antara kelapa), Pos Penjaga Pantai Kak Laut (menara jaga + pelampung),
-- gerobak es kelapa, batu tempat nelayan, jaring dijemur, serta kerang, kerikil, kayu apung, kepiting,
-- ember & jaring nelayan di dekat jukung.

local MapConfig = require(script.Parent.MapConfig)
local Geo = require(script.Parent.Geo)
local TerrainShape = require(script.Parent.Terrain)
local Palms = require(script.Parent.Palms)

local BP = MapConfig.BeachProps
local C = MapConfig.Colors
local TX = MapConfig.Text
local MAT = Enum.Material
local UP = Vector3.yAxis

local BeachProps = {}

local function at(cf: CFrame, x: number, y: number, z: number): Vector3
	return (cf * CFrame.new(x, y, z)).Position
end

local function grounded(x: number, z: number): Vector3
	return Vector3.new(x, Geo.GroundY(x, z), z)
end

-- Frame di tanah yang mengikuti kemiringan pasir sepanjang arah hadap.
local function groundFrame(pos: Vector3, face: Vector3, length: number): CFrame
	local f = Geo.Flat(face).Unit
	local a = pos + f * (length / 2)
	local b = pos - f * (length / 2)
	local ga, gb = Geo.GroundY(a.X, a.Z), Geo.GroundY(b.X, b.Z)
	local center = Vector3.new(pos.X, (ga + gb) / 2, pos.Z)
	local dir = Vector3.new(a.X, ga, a.Z) - Vector3.new(b.X, gb, b.Z)
	return CFrame.lookAt(center, center + dir)
end

-- ===================================================================== pos penjaga pantai

local function buildLifeguard(ctx: Geo.Context, root: Instance)
	local L = BP.Lifeguard
	local model = Geo.Model(root, "PosPenjagaPantai", Enum.ModelStreamingMode.Persistent)
	local g = Geo.GroundY(L.Pos.X, L.Pos.Z)
	local cf = Geo.Facing(Vector3.new(L.Pos.X, g, L.Pos.Z), L.Face)
	local deckH = 6.2
	-- Kaki melebar + palang silang
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			Geo.Segment(
				model,
				at(cf, sx * 2.8, -0.6, sz * 2.8),
				at(cf, sx * 1.95, deckH, sz * 1.95),
				0.5,
				C.WoodLight,
				MAT.Wood,
				{ Collide = true }
			)
		end
		Geo.Segment(
			model,
			at(cf, sx * 2.6, 0.6, -2.6),
			at(cf, sx * 2.05, deckH - 0.5, 2.05),
			0.22,
			C.WoodDark,
			MAT.Wood,
			{ Shadow = false }
		)
		Geo.Segment(
			model,
			at(cf, sx * 2.6, 0.6, 2.6),
			at(cf, sx * 2.05, deckH - 0.5, -2.05),
			0.22,
			C.WoodDark,
			MAT.Wood,
			{ Shadow = false }
		)
	end
	-- Lantai, dinding rendah, tiang atap, atap limas merah
	Geo.Block(
		model,
		cf * CFrame.new(0, deckH + 0.18, 0),
		Vector3.new(4.8, 0.36, 4.8),
		C.WoodDeck,
		MAT.WoodPlanks,
		{ Collide = true }
	)
	Geo.Block(
		model,
		cf * CFrame.new(0, deckH + 0.95, 2.3),
		Vector3.new(4.6, 1.2, 0.16),
		C.White,
		MAT.WoodPlanks,
		{ Collide = true }
	)
	for _, sx in { -1, 1 } do
		Geo.Block(
			model,
			cf * CFrame.new(sx * 2.3, deckH + 0.95, 0),
			Vector3.new(0.16, 1.2, 4.6),
			C.White,
			MAT.WoodPlanks,
			{ Collide = true }
		)
	end
	Geo.Block(
		model,
		cf * CFrame.new(1.2, deckH + 0.95, -2.3),
		Vector3.new(2.2, 1.2, 0.16),
		C.White,
		MAT.WoodPlanks,
		{ Collide = true }
	)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			Geo.Post(
				model,
				at(cf, sx * 2.15, deckH + 0.3, sz * 2.15),
				3.45,
				0.22,
				C.WoodLight,
				MAT.Wood,
				{ Shadow = false }
			)
		end
	end
	local apex = at(cf, 0, deckH + 5.2, 0)
	local eaves = {
		at(cf, -3, deckH + 3.2, -3),
		at(cf, 3, deckH + 3.2, -3),
		at(cf, 3, deckH + 3.2, 3),
		at(cf, -3, deckH + 3.2, 3),
	}
	for k = 1, 4 do
		Geo.Triangle(
			model,
			apex,
			eaves[k],
			eaves[k % 4 + 1],
			0.2,
			if k % 2 == 0 then C.Red else C.White,
			MAT.WoodPlanks,
			{ Shadow = true, Jitter = 0.02 }
		)
	end
	-- Bendera merah-kuning di puncak
	Geo.Post(model, apex - Vector3.new(0, 0.3, 0), 2.6, 0.12, C.MetalDark, MAT.Metal, { Shadow = false })
	Geo.Block(
		model,
		CFrame.new(apex + Vector3.new(0, 1.9, 0)) * cf.Rotation * CFrame.new(0.75, 0, 0),
		Vector3.new(1.4, 0.45, 0.05),
		C.Red,
		MAT.Fabric,
		{ Shadow = false, Jitter = 0 }
	)
	Geo.Block(
		model,
		CFrame.new(apex + Vector3.new(0, 1.45, 0)) * cf.Rotation * CFrame.new(0.75, 0, 0),
		Vector3.new(1.4, 0.45, 0.05),
		C.Yellow,
		MAT.Fabric,
		{ Shadow = false, Jitter = 0 }
	)
	-- Tangga di sisi darat (belakang, +Z lokal)
	local foot = { at(cf, -0.75, -0.4, 4.2), at(cf, 0.75, -0.4, 4.2) }
	local topP = { at(cf, -0.75, deckH + 0.3, 2.35), at(cf, 0.75, deckH + 0.3, 2.35) }
	for i = 1, 2 do
		Geo.Segment(model, foot[i], topP[i], 0.22, C.WoodLight, MAT.Wood, { Collide = true })
	end
	for k = 1, 6 do
		local t = k / 7
		Geo.Segment(
			model,
			foot[1]:Lerp(topP[1], t),
			foot[2]:Lerp(topP[2], t),
			0.18,
			C.WoodDark,
			MAT.Wood,
			{ Shadow = false }
		)
	end
	-- Pelampung penyelamat: cincin dari 8 segmen merah/putih di dinding depan (menghadap laut)
	local ringCF = cf * CFrame.new(1.2, deckH + 1.0, -2.55)
	local ringPts: { Vector3 } = {}
	for k = 0, 8 do
		local a = k / 8 * math.pi * 2
		table.insert(ringPts, at(ringCF, math.cos(a) * 0.62, math.sin(a) * 0.62, 0))
	end
	for k = 1, 8 do
		Geo.Segment(
			model,
			ringPts[k],
			ringPts[k + 1],
			0.3,
			if k % 2 == 0 then C.White else C.Red,
			MAT.SmoothPlastic,
			{ Shadow = false, Extend = 0.1, Jitter = 0 }
		)
	end
	-- Papan nama di dinding belakang (terlihat dari jalur) + papan selancar penyelamat
	Geo.Sign(
		model,
		cf * CFrame.new(0, deckH + 0.95, 2.49) * CFrame.Angles(0, math.pi, 0),
		Vector3.new(4.4, 1.05, 0.2),
		TX.Lifeguard,
		{ MaxTextSize = 34 }
	)
	Geo.Ellipsoid(
		model,
		cf * CFrame.new(2.9, 2.6, -1.0) * CFrame.Angles(math.rad(-12), 0, math.rad(-16)),
		Vector3.new(0.3, 5.6, 1.5),
		C.Red,
		MAT.SmoothPlastic,
		{ Shadow = true }
	)

	local S = BP.KakLautSpot
	ctx.Npc.kak_laut = Geo.Facing(grounded(S.Pos.X, S.Pos.Z), S.Face)
end

-- ===================================================================== area santai

local function buildLounger(model: Instance, pos: Vector3, face: Vector3, cushion: Color3): CFrame
	local cf = groundFrame(pos, face, 6.2)
	-- Rangka, kaki, alas duduk, sandaran miring, bantal
	for _, sx in { -1, 1 } do
		Geo.Block(
			model,
			cf * CFrame.new(sx * 1.0, 0.9, 0),
			Vector3.new(0.2, 0.25, 6.2),
			C.WoodLight,
			MAT.Wood,
			{ Shadow = false }
		)
	end
	for _, z in { -2.6, 2.4 } do
		Geo.Block(
			model,
			cf * CFrame.new(0, 0.38, z),
			Vector3.new(2.2, 1.05, 0.25),
			C.WoodDark,
			MAT.Wood,
			{ Shadow = false }
		)
	end
	Geo.Block(
		model,
		cf * CFrame.new(0, 1.08, -1.1),
		Vector3.new(2.0, 0.15, 3.8),
		C.WoodLight,
		MAT.Wood,
		{ Collide = true }
	)
	local back = cf * CFrame.new(0, 1.05, 0.8) * CFrame.Angles(math.rad(-40), 0, 0) * CFrame.new(0, 0, 1.25)
	Geo.Block(model, back, Vector3.new(2.0, 0.15, 2.6), C.WoodLight, MAT.Wood, { Collide = true })
	Geo.Block(
		model,
		cf * CFrame.new(0, 1.26, -1.1),
		Vector3.new(1.85, 0.22, 3.6),
		cushion,
		MAT.Fabric,
		{ Shadow = false }
	)
	Geo.Block(
		model,
		back * CFrame.new(0, 0.18, 0),
		Vector3.new(1.85, 0.22, 2.4),
		cushion,
		MAT.Fabric,
		{ Shadow = false }
	)
	-- Titik duduk: permukaan atas bantal di posisi pinggul, menghadap (datar) ke ujung kaki.
	return Geo.Facing((cf * CFrame.new(0, 1.37, -0.3)).Position, face)
end

local function buildLounge(ctx: Geo.Context, root: Instance)
	local model = Geo.Model(root, "AreaSantai")
	for _, u in BP.Umbrellas do
		local tilt = Vector3.new(math.rad(u.Tilt), 0, math.rad(-u.Tilt) * 0.5)
		Geo.Umbrella(
			model,
			grounded(u.X, u.Z),
			{ Height = 7.2, Radius = 4.4, Panels = 8, Colors = u.Colors, Tilt = tilt }
		)
	end
	local cushions = { C.Teal, C.Yellow, C.White, C.Pink, C.Orange }
	for i, l in BP.Loungers do
		local seat = buildLounger(model, Vector3.new(l.X, 0, l.Z), l.Face, cushions[(i - 1) % #cushions + 1])
		if l.NpcId ~= "" then
			ctx.Npc[l.NpcId] = seat
		end
	end
	-- Handuk, bola pantai, kotak pendingin dekat payung ketiga
	local u3 = BP.Umbrellas[3]
	local towelCF = groundFrame(Vector3.new(u3.X + 3.8, 0, u3.Z + 3.2), Vector3.new(0.2, 0, 1), 3.8)
	Geo.Block(
		model,
		towelCF * CFrame.new(0, 0.04, 0),
		Vector3.new(2.0, 0.06, 3.8),
		C.Pink,
		MAT.Fabric,
		{ Shadow = false }
	)
	Geo.Block(
		model,
		towelCF * CFrame.new(0, 0.1, 0),
		Vector3.new(2.02, 0.06, 0.5),
		C.White,
		MAT.Fabric,
		{ Shadow = false, Jitter = 0 }
	)
	local ballP = grounded(u3.X + 6.4, u3.Z + 1.2)
	Geo.Ball(model, ballP + Vector3.new(0, 0.5, 0), 1.1, C.Yellow, MAT.SmoothPlastic, { Shadow = true })
	local coolP = grounded(u3.X - 1.6, u3.Z + 2.4)
	Geo.Block(
		model,
		CFrame.new(coolP + Vector3.new(0, 0.55, 0)) * CFrame.Angles(0, 0.4, 0),
		Vector3.new(1.6, 1.1, 1.1),
		C.Blue,
		MAT.SmoothPlastic,
		{ Collide = true }
	)
	Geo.Block(
		model,
		CFrame.new(coolP + Vector3.new(0, 1.15, 0)) * CFrame.Angles(0, 0.4, 0),
		Vector3.new(1.7, 0.14, 1.2),
		C.White,
		MAT.SmoothPlastic,
		{ Shadow = false }
	)

	-- Rak papan selancar
	local R = BP.SurfRack
	local rcf = Geo.Facing(grounded(R.Pos.X, R.Pos.Z), R.Face)
	for _, sx in { -1, 1 } do
		Geo.Post(model, at(rcf, sx * 2.6, -0.4, 0.8), 3.9, 0.3, C.WoodDark, MAT.Wood, { Collide = true })
	end
	Geo.Segment(model, at(rcf, -2.9, 3.2, 0.8), at(rcf, 2.9, 3.2, 0.8), 0.25, C.WoodDark, MAT.Wood, { Shadow = false })
	Geo.Segment(model, at(rcf, -2.9, 0.5, 0.8), at(rcf, 2.9, 0.5, 0.8), 0.25, C.WoodDark, MAT.Wood, { Shadow = false })
	local boards = { C.Teal, C.Yellow, C.Orange, C.White }
	for k, col in boards do
		local x = -1.9 + (k - 1) * 1.25
		Geo.Ellipsoid(
			model,
			rcf * CFrame.new(x, 2.9, -0.2) * CFrame.Angles(math.rad(-18), 0, 0),
			Vector3.new(0.26, 6.2, 1.45),
			col,
			MAT.SmoothPlastic,
			{ Shadow = true }
		)
	end

	-- Net voli (tiang, jaring tipis, pita atas) + garis lapangan tali + bola
	local V = BP.Volley
	local vx, vz = V.Pos.X, V.Pos.Z
	local postA = grounded(vx, vz - V.HalfZ - 1.0)
	local postB = grounded(vx, vz + V.HalfZ + 1.0)
	Geo.Post(model, postA - Vector3.new(0, 0.6, 0), 6.4, 0.35, C.White, MAT.Metal, { Collide = true })
	Geo.Post(model, postB - Vector3.new(0, 0.6, 0), 6.4, 0.35, C.White, MAT.Metal, { Collide = true })
	local netTop = math.max(postA.Y, postB.Y) + 5.4
	local mid = Vector3.new(vx, netTop - 0.95, vz)
	local netLen = (postB - postA).Magnitude
	Geo.Block(
		model,
		CFrame.new(mid),
		Vector3.new(0.06, 1.9, netLen),
		C.White,
		MAT.Fabric,
		{ Transparency = 0.4, Shadow = false, Jitter = 0 }
	)
	Geo.Block(
		model,
		CFrame.new(Vector3.new(vx, netTop - 0.05, vz)),
		Vector3.new(0.1, 0.22, netLen),
		C.White,
		MAT.Fabric,
		{ Shadow = false, Jitter = 0 }
	)
	local cornersV = {
		Vector3.new(vx - V.HalfX, 0, vz - V.HalfZ),
		Vector3.new(vx + V.HalfX, 0, vz - V.HalfZ),
		Vector3.new(vx + V.HalfX, 0, vz + V.HalfZ),
		Vector3.new(vx - V.HalfX, 0, vz + V.HalfZ),
	}
	for k = 1, 4 do
		local a, b = cornersV[k], cornersV[k % 4 + 1]
		Geo.Segment(
			model,
			grounded(a.X, a.Z) + Vector3.new(0, 0.02, 0),
			grounded(b.X, b.Z) + Vector3.new(0, 0.02, 0),
			0.14,
			C.Rope,
			MAT.Fabric,
			{ Shadow = false }
		)
	end
	Geo.Ball(
		model,
		grounded(vx + 4.5, vz + 1.5) + Vector3.new(0, 0.5, 0),
		1.1,
		C.White,
		MAT.SmoothPlastic,
		{ Shadow = true }
	)

	-- Api unggun: lingkar batu, kayu bakar, partikel api + asap, cahaya berkedip; 3 bangku gelondong
	local F = BP.Campfire
	local fc = grounded(F.Pos.X, F.Pos.Z)
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		Geo.Ball(
			model,
			fc + Vector3.new(math.cos(a) * 1.45, 0.1, math.sin(a) * 1.45),
			Geo.Rand(0.75, 1.0),
			C.StoneDark,
			MAT.Slate,
			{ Shadow = false }
		)
	end
	local logs: { Part } = {}
	for k = 0, 3 do
		local a = k / 4 * math.pi * 2 + 0.4
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		table.insert(
			logs,
			Geo.Segment(
				model,
				fc + out * 1.1 + Vector3.new(0, 0.15, 0),
				fc + Vector3.new(0, 0.9, 0) - out * 0.15,
				0.35,
				C.WoodDark,
				MAT.Wood,
				{ Shadow = false }
			)
		)
	end
	local fireAtt = Geo.Attach(logs[1], fc + Vector3.new(0, 0.7, 0), Vector3.xAxis)
	local fire = Instance.new("ParticleEmitter")
	fire.Name = "Api"
	fire.Texture = "rbxasset://textures/particles/fire_main.dds"
	fire.Color = ColorSequence.new(Color3.fromRGB(255, 196, 92), Color3.fromRGB(240, 92, 40))
	fire.LightEmission = 1
	fire.LightInfluence = 0
	fire.Size = NumberSequence.new(1.3, 0.3)
	fire.Transparency = NumberSequence.new(0.15, 1)
	fire.Lifetime = NumberRange.new(0.5, 0.9)
	fire.Rate = 26
	fire.Speed = NumberRange.new(2, 3.5)
	fire.SpreadAngle = Vector2.new(10, 10)
	fire.Acceleration = Vector3.new(0, 2.5, 0)
	fire.RotSpeed = NumberRange.new(-40, 40)
	fire.Rotation = NumberRange.new(0, 360)
	fire.EmissionDirection = Enum.NormalId.Top
	fire.Parent = fireAtt
	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "Asap"
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(160, 154, 148))
	smoke.LightInfluence = 1
	smoke.Size = NumberSequence.new(1.0, 3.2)
	smoke.Transparency = NumberSequence.new(0.6, 1)
	smoke.Lifetime = NumberRange.new(2.5, 4)
	smoke.Rate = 4
	smoke.Speed = NumberRange.new(1.5, 2.5)
	smoke.SpreadAngle = Vector2.new(12, 12)
	smoke.Acceleration = Vector3.new(0.4, 0.6, 0)
	smoke.EmissionDirection = Enum.NormalId.Top
	smoke.Parent = fireAtt
	Geo.PointLight(
		fireAtt,
		{ Range = 18, Brightness = 2.2, Color = Color3.fromRGB(255, 160, 80), Night = true, Flicker = true }
	)
	local benches = {
		{ Offset = Vector3.new(0, 0, -5.4), Axis = Vector3.xAxis, Npc = "wisatawan_3" },
		{ Offset = Vector3.new(-5.2, 0, 0.6), Axis = Vector3.zAxis, Npc = "" },
		{ Offset = Vector3.new(5.2, 0, 0.6), Axis = Vector3.zAxis, Npc = "" },
	}
	for _, b in benches do
		local p = fc + b.Offset
		local g = Geo.GroundY(p.X, p.Z)
		local logY = g + 1.25
		for _, s in { -1.6, 1.6 } do
			local sp = p + b.Axis * s
			Geo.Post(
				model,
				Vector3.new(sp.X, Geo.GroundY(sp.X, sp.Z) - 0.3, sp.Z),
				logY - Geo.GroundY(sp.X, sp.Z) + 0.3,
				0.95,
				C.WoodPost,
				MAT.Wood,
				{ Shadow = false }
			)
		end
		Geo.Cylinder(
			model,
			Geo.AlongX(Vector3.new(p.X, logY, p.Z), b.Axis),
			4.6,
			1.3,
			C.WoodDeckAlt,
			MAT.Wood,
			{ Collide = true }
		)
		if b.Npc ~= "" then
			local toFire = Geo.Flat(fc - p).Unit
			ctx.Npc[b.Npc] = Geo.Facing(Vector3.new(p.X, logY + 0.65, p.Z), toFire)
		end
	end

	-- Istana pasir + ember & sekop
	local SC = BP.Sandcastle
	local sc = grounded(SC.Pos.X, SC.Pos.Z)
	local sand = Color3.fromRGB(204, 180, 128)
	Geo.Disk(model, sc + Vector3.new(0, 0.2, 0), 0.8, 5.4, sand, MAT.Sand, { Shadow = false })
	Geo.Post(model, sc + Vector3.new(0, 0.5, 0), 2.0, 2.3, sand, MAT.Sand, { Shadow = true })
	Geo.Disk(model, sc + Vector3.new(0, 2.7, 0), 0.4, 2.0, sand, MAT.Sand, { Shadow = false })
	Geo.Disk(model, sc + Vector3.new(0, 3.1, 0), 0.4, 1.3, sand, MAT.Sand, { Shadow = false })
	Geo.Ball(model, sc + Vector3.new(0, 3.45, 0), 0.6, sand, MAT.Sand, { Shadow = false })
	Geo.Post(model, sc + Vector3.new(0, 3.5, 0), 1.2, 0.08, C.WoodDark, MAT.Wood, { Shadow = false })
	Geo.Tip(
		model,
		sc + Vector3.new(0.05, 4.6, 0),
		sc + Vector3.new(0.85, 4.35, 0),
		0.5,
		0.04,
		Vector3.zAxis,
		C.Red,
		MAT.Fabric,
		{ Shadow = false }
	)
	local towers: { Vector3 } = {}
	for k = 0, 3 do
		local a = k / 4 * math.pi * 2 + math.pi / 4
		local tp = sc + Vector3.new(math.cos(a) * 1.9, 0.4, math.sin(a) * 1.9)
		table.insert(towers, tp)
		Geo.Post(model, tp, 1.4, 1.1, sand, MAT.Sand, { Shadow = false })
		Geo.Disk(model, tp + Vector3.new(0, 1.5, 0), 0.25, 1.3, sand, MAT.Sand, { Shadow = false })
	end
	for k = 1, 4 do
		local a, b = towers[k], towers[k % 4 + 1]
		Geo.Plank(
			model,
			a + Vector3.new(0, 0.55, 0),
			b + Vector3.new(0, 0.55, 0),
			0.45,
			1.0,
			UP,
			sand,
			MAT.Sand,
			{ Shadow = false }
		)
	end
	local bucketP = grounded(SC.Pos.X + 3.6, SC.Pos.Z - 1.2)
	Geo.Bucket(model, bucketP, C.Red)
	Geo.Segment(
		model,
		bucketP + Vector3.new(1.2, 0.15, 0.6),
		bucketP + Vector3.new(2.5, 0.25, 1.4),
		0.12,
		C.Yellow,
		MAT.SmoothPlastic,
		{ Shadow = false }
	)
	Geo.Block(
		model,
		CFrame.new(bucketP + Vector3.new(2.8, 0.2, 1.6)) * CFrame.Angles(0, math.rad(-32), 0),
		Vector3.new(0.5, 0.08, 0.6),
		C.Yellow,
		MAT.SmoothPlastic,
		{ Shadow = false }
	)

	-- Ayunan tali (hammock) di antara dua kelapa pahlawan
	local H = BP.Hammock
	local pa = Palms.HeroTrunkPoint(H.A, H.Height)
	local pb = Palms.HeroTrunkPoint(H.B, H.Height)
	if pa and pb then
		local dir = (pb - pa).Unit
		local a = pa + dir * 1.1
		local b = pb - dir * 1.1
		local ends = { a + dir * 1.2 - Vector3.new(0, 0.3, 0), b - dir * 1.2 - Vector3.new(0, 0.3, 0) }
		Geo.Segment(model, a, ends[1], 0.1, C.Rope, MAT.Fabric, { Shadow = false })
		Geo.Segment(model, b, ends[2], 0.1, C.Rope, MAT.Fabric, { Shadow = false })
		local colors = { C.Red, C.Yellow, C.Teal }
		local n = 3
		for k = 1, n do
			local t0, t1 = (k - 1) / n, k / n
			local p0 = Geo.RopePoint(ends[1], ends[2], 1.3, t0)
			local p1 = Geo.RopePoint(ends[1], ends[2], 1.3, t1)
			Geo.Plank(model, p0, p1, 1.5, 0.1, UP, colors[k], MAT.Fabric, { Shadow = true, Extend = 0.1 })
		end
	end

	-- Jaring nelayan dijemur
	local NR = BP.NetRack
	local ncf = Geo.Facing(grounded(NR.Pos.X, NR.Pos.Z), NR.Face)
	for _, sx in { -1, 1 } do
		Geo.Post(model, at(ncf, sx * 3.0, -0.5, 0), 4.2, 0.3, C.Bamboo, MAT.Wood, { Shadow = false })
	end
	Geo.Segment(model, at(ncf, -3.1, 3.5, 0), at(ncf, 3.1, 3.5, 0), 0.22, C.Bamboo, MAT.Wood, { Shadow = false })
	for _, sz in { -1, 1 } do
		Geo.Block(
			model,
			ncf * CFrame.new(0, 2.5, sz * 0.55) * CFrame.Angles(math.rad(sz * 26), 0, 0),
			Vector3.new(5.8, 2.3, 0.05),
			C.Teal,
			MAT.Fabric,
			{ Transparency = 0.3, Shadow = false }
		)
	end
end

-- ===================================================================== gerobak es kelapa

local function buildCart(ctx: Geo.Context, root: Instance)
	local K = BP.Cart
	local model = Geo.Model(root, "GerobakEsKelapa", Enum.ModelStreamingMode.Persistent)
	local cf = groundFrame(K.Pos, K.Face, 4.8)
	Geo.Block(model, cf * CFrame.new(0, 2.0, 0), Vector3.new(4.6, 2.2, 2.4), C.Teal, MAT.Wood, { Collide = true })
	Geo.Block(
		model,
		cf * CFrame.new(0, 3.22, 0),
		Vector3.new(5.0, 0.25, 2.8),
		C.WoodLight,
		MAT.Wood,
		{ Collide = true }
	)
	local plate = Geo.Block(
		model,
		cf * CFrame.new(0, 2.0, -1.24),
		Vector3.new(4.2, 1.5, 0.08),
		C.Fabric,
		MAT.Wood,
		{ Shadow = false }
	)
	Geo.SignText(
		plate,
		Enum.NormalId.Front,
		TX.Coconut,
		{ TextColor = C.SignText, Stroke = C.SignStroke, MaxTextSize = 40 }
	)
	for _, sx in { -1, 1 } do
		local wheel = cf * CFrame.new(sx * 2.45, 1.2, 0.3)
		Geo.Cylinder(model, wheel, 0.35, 2.4, C.WoodDark, MAT.Wood, { Collide = true })
		Geo.Cylinder(model, wheel * CFrame.new(sx * 0.2, 0, 0), 0.2, 0.6, C.MetalDark, MAT.Metal, { Shadow = false })
		Geo.Segment(
			model,
			at(cf, sx * 1.6, 2.3, 1.2),
			at(cf, sx * 1.75, 1.8, 3.6),
			0.2,
			C.WoodDark,
			MAT.Wood,
			{ Shadow = false }
		)
	end
	Geo.Post(model, at(cf, 0, -0.2, -0.9), 1.1, 0.3, C.WoodDark, MAT.Wood, { Shadow = false })
	Geo.Umbrella(model, at(cf, -2.0, 3.0, 0.9), {
		Height = 5.4,
		Radius = 4.2,
		Panels = 8,
		Colors = { C.Green, C.White },
		Tilt = cf:VectorToWorldSpace(Vector3.new(0.04, 0, 0.05)),
		Pole = C.WoodDark,
	})
	-- Tumpukan kelapa muda
	local pile = {
		Vector3.new(0.6, 0, -0.3),
		Vector3.new(1.6, 0, -0.4),
		Vector3.new(1.1, 0, 0.5),
		Vector3.new(2.0, 0, 0.45),
		Vector3.new(1.1, 0.75, 0),
		Vector3.new(1.75, 0.7, 0.05),
	}
	for _, p in pile do
		Geo.Ball(
			model,
			at(cf, p.X, 3.85 + p.Y, p.Z),
			Geo.Rand(0.95, 1.12),
			C.Coconut,
			MAT.SmoothPlastic,
			{ Shadow = false }
		)
	end
	-- Toples minuman
	for k, col in { C.Shell[1], C.Orange } do
		local base = at(cf, -1.1 + (k - 1) * 0.95, 3.35, -0.45)
		Geo.Post(model, base, 1.1, 0.62, col, MAT.SmoothPlastic, { Shadow = false })
		Geo.Post(
			model,
			base - Vector3.new(0, 0.05, 0),
			1.25,
			0.72,
			C.Glass,
			MAT.Glass,
			{ Transparency = 0.6, Shadow = false, Jitter = 0 }
		)
	end
	-- Bangku pembeli
	for _, sx in { -1, 1 } do
		local sp = at(cf, sx * 1.7, 0, -2.6)
		Geo.Post(
			model,
			Vector3.new(sp.X, Geo.GroundY(sp.X, sp.Z) - 0.2, sp.Z),
			1.7,
			1.15,
			C.WoodDeckAlt,
			MAT.Wood,
			{ Collide = true }
		)
	end
	local seller = cf * CFrame.new(0, 0, 2.4)
	local sp = seller.Position
	ctx.Npc.penjual_es = Geo.Facing(Vector3.new(sp.X, Geo.GroundY(sp.X, sp.Z), sp.Z), K.Face)
end

-- ===================================================================== tepi air: batu nelayan, kayu apung, kerang

local function buildShore(ctx: Geo.Context, root: Instance, rng: Random)
	local model = Geo.Model(root, "TepiPantai")
	-- Batu datar tempat nelayan 3 berdiri (pelampung 9 stud di depan jatuh di air terbuka).
	local FR = BP.FishermanRock
	local zEdge = TerrainShape.FindZForHeight(FR.X, 0, 92, 140)
	local rockC = Vector3.new(FR.X, 0, zEdge - 0.4)
	local top = 0.8
	Geo.Post(model, Vector3.new(rockC.X, -1.6, rockC.Z), top + 1.6, 6.6, C.StoneDark, MAT.Slate, { Collide = true })
	Geo.Ball(model, rockC + Vector3.new(-3.6, -0.4, -1.4), 2.6, C.Stone, MAT.Rock, { Collide = true })
	ctx.Npc.nelayan_3 = Geo.Facing(Vector3.new(FR.X + 1.0, top, rockC.Z + 0.8), FR.Facing)

	-- Kayu apung melengkung
	for _, p in BP.Driftwood do
		local a = rng:NextNumber(0, math.pi * 2)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local side = dir:Cross(UP)
		local base = grounded(p.X, p.Z)
		local pts = Geo.Bezier2(
			base - dir * 2.6 + Vector3.new(0, 0.15, 0),
			base + side * 0.9 + Vector3.new(0, 0.35, 0),
			base + dir * 2.8 + side * 0.4 + Vector3.new(0, 0.1, 0),
			3
		)
		for i, q in pts do
			pts[i] = Vector3.new(q.X, Geo.GroundY(q.X, q.Z) + 0.2, q.Z)
		end
		Geo.Chain(model, pts, 0.75, 0.42, C.WoodWeathered, MAT.Wood, { Shadow = false })
		Geo.Ball(model, pts[1] + Vector3.new(0, 0.1, 0), 1.0, C.WoodWeathered, MAT.Wood, { Shadow = false })
	end

	-- Kepiting hias
	for _, p in BP.Crabs do
		local base = grounded(p.X, p.Z)
		local yaw = rng:NextNumber(0, math.pi * 2)
		local cf = CFrame.new(base + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, yaw, 0)
		Geo.Ellipsoid(model, cf, Vector3.new(1.1, 0.45, 0.8), C.Orange, MAT.SmoothPlastic, { Shadow = false })
		for _, sx in { -1, 1 } do
			Geo.Ball(model, at(cf, sx * 0.55, 0.05, -0.5), 0.36, C.Red, MAT.SmoothPlastic, { Shadow = false })
			Geo.Post(
				model,
				at(cf, sx * 0.18, 0.1, -0.32),
				0.3,
				0.08,
				C.MetalDark,
				MAT.SmoothPlastic,
				{ Shadow = false }
			)
		end
	end

	-- Ember, jaring, keranjang di dekat jukung
	local gear = BP.BoatGear
	Geo.Bucket(model, grounded(gear[1].X, gear[1].Z), C.Blue)
	local net = grounded(gear[2].X, gear[2].Z)
	Geo.Ellipsoid(
		model,
		CFrame.new(net + Vector3.new(0, 0.35, 0)) * CFrame.Angles(0, 0.7, 0),
		Vector3.new(2.8, 0.8, 2.0),
		C.Teal,
		MAT.Fabric,
		{ Shadow = false }
	)
	for k = 1, 3 do
		local a = k / 3 * math.pi * 2
		Geo.Ball(
			model,
			net + Vector3.new(math.cos(a) * 0.9, 0.75, math.sin(a) * 0.55),
			0.45,
			C.Orange,
			MAT.SmoothPlastic,
			{ Shadow = false }
		)
	end
	local basket = grounded(gear[3].X, gear[3].Z)
	Geo.Post(model, basket - Vector3.new(0, 0.1, 0), 1.0, 1.7, C.Woven, MAT.Fabric, { Collide = true })
	Geo.Fish(
		model,
		CFrame.new(basket + Vector3.new(0, 1.0, 0)) * CFrame.Angles(0, 0.3, math.rad(90)),
		1.1,
		C.TarpLight,
		C.White
	)
	Geo.Bucket(model, grounded(gear[4].X, gear[4].Z), C.Orange)

	-- Kerang & kerikil di sepanjang garis air
	local band = BP.ShoreBand
	local placed = 0
	local tries = 0
	while placed < band.Count and tries < band.Count * 12 do
		tries += 1
		local x = rng:NextNumber(band.MinX, band.MaxX)
		local zs = TerrainShape.ShoreZ(x)
		local z = zs - rng:NextNumber(1.5, 10)
		local h = Geo.GroundY(x, z)
		local nearBoat = false
		for _, b in MapConfig.Boats.List do
			if not b.Moored and (Vector3.new(x, 0, z) - Vector3.new(b.Pos.X, 0, b.Pos.Z)).Magnitude < 9 then
				nearBoat = true
			end
		end
		local nearPier = (x > 60 and x < 100 and z > 80) or (x > 126 and x < 160)
		local nearRock = math.abs(x - BP.FishermanRock.X) < 7
		if not nearRock and h > 0.15 and h < 1.4 and not nearBoat and not nearPier and not Geo.NearPath(x, z, 1) then
			placed += 1
			local p = Vector3.new(x, h, z)
			local yaw = rng:NextNumber(0, math.pi * 2)
			if placed % 3 == 0 then
				Geo.Ball(
					model,
					p + Vector3.new(0, 0.12, 0),
					rng:NextNumber(0.4, 0.75),
					C.Stone,
					MAT.Pebble,
					{ Shadow = false }
				)
			else
				local col = C.Shell[rng:NextInteger(1, #C.Shell)]
				Geo.Ellipsoid(
					model,
					CFrame.new(p + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, yaw, math.rad(rng:NextNumber(-10, 10))),
					Vector3.new(0.65, 0.22, 0.55),
					col,
					MAT.SmoothPlastic,
					{ Shadow = false }
				)
			end
		end
	end
end

function BeachProps.Build(ctx: Geo.Context)
	local rng = Geo.Rng(MapConfig.SeedOffsets.BeachProps)
	local root = Geo.Model(ctx.Root, "PropertiPantai")
	buildLifeguard(ctx, root)
	buildLounge(ctx, root)
	buildCart(ctx, root)
	buildShore(ctx, root, rng)
end

return BeachProps
