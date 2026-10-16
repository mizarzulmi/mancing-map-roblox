--!strict
-- CosmeticModels: kosmetik prosedural (GDD Bagian 5) dari Style di Config/Cosmetics.
--   • BuildAccessory(cosmetic) → Accessory (slot Hat & Accessory) untuk Humanoid:AddAccessory di server.
--   • ApplyTrail / ApplyAura → efek di HumanoidRootPart; mengembalikan instance yang dibuat (untuk dibersihkan).
--   • BuildPreview(cosmetic) → Model anchored untuk ViewportFrame toko/inventaris (Title → nil).
-- Geometri wearable ditulis dalam ruang attachment karakter R15 (data rig characterR15 bawaan Studio):
--   HatAttachment = puncak tengah kepala (kepala bulat-silinder Ø1,25 × tinggi 1,25, pusatnya 0,6 di bawah);
--   FaceFrontAttachment = muka depan tengah kepala; NeckAttachment = tengah atas UpperTorso (2 × 1,6 × 1);
--   BodyFront/BodyBackAttachment = muka depan/belakang UpperTorso, 0,2 stud di bawah tengahnya.
-- Semua orientasi attachment tersebut identitas (depan = −Z). Hanya primitif Roblox + SpecialMesh Sphere,
-- efek bawaan, dan tekstur partikel rbxasset:// bawaan.

local Types = require(script.Parent.Parent.Types)
local Rods = require(script.Parent.Parent.Config.Rods)
local RodModel = require(script.Parent.RodModel)
local BobberModel = require(script.Parent.BobberModel)

type CosmeticDef = Types.CosmeticDef

type Ctx = {
	Origin: CFrame,
	Anchored: boolean,
	Parts: { BasePart },
}

type Wearable = {
	Attachment: string,
	AccessoryType: Enum.AccessoryType,
	Build: (ctx: Ctx, cosmetic: CosmeticDef) -> BasePart,
}

type TrailSpec = {
	Color: ColorSequence,
	Transparency: NumberSequence,
	Width: NumberSequence,
	Lifetime: number,
	Top: Vector3,
	Bottom: Vector3,
	LightEmission: number,
	LightInfluence: number,
	Bubbles: boolean,
	Flat: boolean,
}

type EmitterSpec = {
	Name: string,
	Texture: string,
	Color: ColorSequence,
	Size: NumberSequence,
	Transparency: NumberSequence,
	Lifetime: NumberRange,
	Rate: number,
	Speed: NumberRange,
	Spread: Vector2,
	Acceleration: Vector3,
	LightEmission: number,
	Drag: number,
	Locked: boolean,
	Direction: Enum.NormalId,
}

local CosmeticModels = {}

local SIDES = { 1, -1 }
local UP = Vector3.yAxis
local FABRIC = Enum.Material.Fabric
local PLASTIC = Enum.Material.SmoothPlastic
local METAL = Enum.Material.Metal

local TEX_SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local TEX_GLOW = "rbxasset://textures/particles/forcefield_glow_main.dds"

local STRAP_DARK = Color3.fromRGB(46, 48, 54)
local BUCKLE = Color3.fromRGB(32, 34, 38)
local LURE_RED = Color3.fromRGB(214, 70, 52)
local HOOK_SILVER = Color3.fromRGB(200, 206, 214)
local FISH_EYE = Color3.fromRGB(250, 250, 246)
local FISH_PUPIL = Color3.fromRGB(18, 22, 28)
local STAND = Color3.fromRGB(226, 211, 186)
local STAND_BASE = Color3.fromRGB(150, 112, 76)

-- Posisi attachment karakter dalam ruang penyangga pratinjau (kepala/torso berpusat di origin).
local STAND_ATTACH: { [string]: CFrame } = {
	HatAttachment = CFrame.new(0, 0.6, 0),
	FaceFrontAttachment = CFrame.new(0, 0, -0.6),
	NeckAttachment = CFrame.new(0, 0.8, 0),
	BodyFrontAttachment = CFrame.new(0, -0.2, -0.5),
	BodyBackAttachment = CFrame.new(0, -0.2, 0.5),
}

-- =========================================================================
-- Utilitas
-- =========================================================================

local function sideTag(s: number): string
	return if s > 0 then "R" else "L"
end

local function shade(c: Color3, factor: number): Color3
	return Color3.new(math.clamp(c.R * factor, 0, 1), math.clamp(c.G * factor, 0, 1), math.clamp(c.B * factor, 0, 1))
end

local function pick(colors: { Color3 }, index: number, fallback: Color3): Color3
	local c: Color3? = colors[index]
	return if c then c else fallback
end

-- Bingkai dengan sumbu Z searah `dir` dan Y sedekat mungkin ke `up` (aman bila sejajar).
local function frameZ(pos: Vector3, dir: Vector3, up: Vector3?): CFrame
	local z = dir.Unit
	local hint = up or UP
	if math.abs(z:Dot(hint)) > 0.98 then
		hint = if math.abs(z.X) < 0.9 then Vector3.xAxis else Vector3.zAxis
	end
	local y = (hint - z * hint:Dot(z)).Unit
	return CFrame.fromMatrix(pos, y:Cross(z), y, z)
end

-- Bingkai dengan sumbu X searah `dir` (sumbu Part Cylinder).
local function frameX(pos: Vector3, dir: Vector3): CFrame
	local x = dir.Unit
	local hint = if math.abs(x:Dot(UP)) > 0.98 then Vector3.zAxis else UP
	local z = x:Cross(hint).Unit
	return CFrame.fromMatrix(pos, x, z:Cross(x), z)
end

-- Titik & normal permukaan elipsoid sumbu-sejajar (pusat, setengah-sumbu) pada arah `dir`.
local function surfaceAlong(center: Vector3, semi: Vector3, dir: Vector3): (Vector3, Vector3)
	local q = (dir.X / semi.X) ^ 2 + (dir.Y / semi.Y) ^ 2 + (dir.Z / semi.Z) ^ 2
	local d = dir / math.sqrt(q)
	local n = Vector3.new(d.X / (semi.X * semi.X), d.Y / (semi.Y * semi.Y), d.Z / (semi.Z * semi.Z)).Unit
	return center + d, n
end

local function seq(points: { { number } }): NumberSequence
	local keys: { NumberSequenceKeypoint } = {}
	for _, p in points do
		table.insert(keys, NumberSequenceKeypoint.new(p[1], p[2]))
	end
	return NumberSequence.new(keys)
end

local function sampleNumber(s: NumberSequence, t: number): number
	local keys = s.Keypoints
	for i = 1, #keys - 1 do
		local a, b = keys[i], keys[i + 1]
		if t <= b.Time then
			local u = if b.Time > a.Time then (t - a.Time) / (b.Time - a.Time) else 0
			return a.Value + (b.Value - a.Value) * u
		end
	end
	return keys[#keys].Value
end

local function sampleColor(s: ColorSequence, t: number): Color3
	local keys = s.Keypoints
	for i = 1, #keys - 1 do
		local a, b = keys[i], keys[i + 1]
		if t <= b.Time then
			local u = if b.Time > a.Time then (t - a.Time) / (b.Time - a.Time) else 0
			return a.Value:Lerp(b.Value, u)
		end
	end
	return keys[#keys].Value
end

local function rainbowSequence(): ColorSequence
	local keys: { ColorSequenceKeypoint } = {}
	for i = 0, 6 do
		table.insert(keys, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6 * 0.83, 0.72, 1)))
	end
	return ColorSequence.new(keys)
end

local function newCtx(origin: CFrame, anchored: boolean): Ctx
	return { Origin = origin, Anchored = anchored, Parts = {} }
end

-- =========================================================================
-- Pembuat part (CFrame dalam ruang ctx.Origin)
-- =========================================================================

local function finish(
	ctx: Ctx,
	part: BasePart,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material,
	shadow: boolean
): BasePart
	part.Name = name
	part.Size = size
	part.CFrame = ctx.Origin * cf
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = ctx.Anchored
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = shadow
	table.insert(ctx.Parts, part)
	return part
end

local function ellipsoid(
	ctx: Ctx,
	name: string,
	cf: CFrame,
	size: Vector3,
	color: Color3,
	material: Enum.Material?,
	shadow: boolean?
): BasePart
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Block
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return finish(ctx, part, name, size, cf, color, material or PLASTIC, shadow == true)
end

local function ball(
	ctx: Ctx,
	name: string,
	pos: Vector3,
	diameter: number,
	color: Color3,
	material: Enum.Material?
): BasePart
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Ball
	return finish(ctx, part, name, Vector3.one * diameter, CFrame.new(pos), color, material or PLASTIC, false)
end

-- Silinder tegak (sumbu Y) berpusat di `pos`.
local function cylY(
	ctx: Ctx,
	name: string,
	pos: Vector3,
	diameter: number,
	height: number,
	color: Color3,
	material: Enum.Material?,
	shadow: boolean?
): BasePart
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Cylinder
	local cf = CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2)
	return finish(
		ctx,
		part,
		name,
		Vector3.new(height, diameter, diameter),
		cf,
		color,
		material or PLASTIC,
		shadow == true
	)
end

local function rod(
	ctx: Ctx,
	name: string,
	a: Vector3,
	b: Vector3,
	diameter: number,
	color: Color3,
	material: Enum.Material?
): BasePart
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Cylinder
	local d = b - a
	return finish(
		ctx,
		part,
		name,
		Vector3.new(d.Magnitude, diameter, diameter),
		frameX((a + b) / 2, d),
		color,
		material or PLASTIC,
		false
	)
end

local function block(ctx: Ctx, name: string, cf: CFrame, size: Vector3, color: Color3): BasePart
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Block
	return finish(ctx, part, name, size, cf, color, PLASTIC, true)
end

-- Sirip segitiga siku-siku (WedgePart): tepi p0 → p1, tinggi ke arah `up`, sudut tinggi di p1.
local function fin(
	ctx: Ctx,
	name: string,
	p0: Vector3,
	p1: Vector3,
	height: number,
	up: Vector3,
	color: Color3
): BasePart
	local along = p1 - p0
	local z = along.Unit
	local y = (up - z * up:Dot(z)).Unit
	local cf = CFrame.fromMatrix((p0 + p1) / 2 + y * (height / 2), y:Cross(z), y, z)
	return finish(
		ctx,
		Instance.new("WedgePart"),
		name,
		Vector3.new(0.035, height, along.Magnitude),
		cf,
		color,
		PLASTIC,
		false
	)
end

-- Pita horizontal melingkari elipsoid (bingkai pusat `frame`, setengah-sumbu `semi`) pada tinggi lokal y.
local function bandAround(
	ctx: Ctx,
	name: string,
	frame: CFrame,
	semi: Vector3,
	y: number,
	visible: number,
	bulge: number,
	color: Color3,
	material: Enum.Material?
): BasePart
	local t = y / semi.Y
	local f = math.sqrt(math.max(1 - t * t, 0.04))
	local semiY = visible / (2 * math.sqrt(1 - 1 / (bulge * bulge)))
	local size = Vector3.new(semi.X * f * bulge, semiY, semi.Z * f * bulge) * 2
	return ellipsoid(ctx, name, frame * CFrame.new(0, y, 0), size, color, material)
end

-- =========================================================================
-- Topi (ruang HatAttachment: origin = puncak kepala)
-- =========================================================================

-- Topi jerami lebar: kubah anyaman, pinggiran melandai, pita + simpul berekor di sisi belakang-kiri.
local function buildStraw(ctx: Ctx, c: CosmeticDef): BasePart
	ctx.Origin *= CFrame.Angles(math.rad(-4), 0, math.rad(3))
	local straw = pick(c.Colors, 1, Color3.fromRGB(226, 196, 120))
	local ribbon = pick(c.Colors, 2, Color3.fromRGB(160, 60, 50))
	local crown = ellipsoid(ctx, "Handle", CFrame.identity, Vector3.new(1.5, 0.84, 1.5), straw, FABRIC, true)
	ellipsoid(ctx, "Brim", CFrame.new(0, -0.17, 0), Vector3.new(2.5, 0.11, 2.5), shade(straw, 0.96), FABRIC, true)
	cylY(ctx, "Ribbon", Vector3.new(0, -0.085, 0), 1.53, 0.13, ribbon, FABRIC)
	local a = math.rad(-40)
	local radial = Vector3.new(math.sin(a), 0, math.cos(a))
	ellipsoid(
		ctx,
		"Bow",
		frameZ(radial * 0.775 + Vector3.new(0, -0.08, 0), radial),
		Vector3.new(0.17, 0.15, 0.12),
		shade(ribbon, 0.9),
		FABRIC
	)
	for i, da in { -7, 7 } do
		local b = a + math.rad(da)
		local dir = Vector3.new(math.sin(b), 0, math.cos(b))
		local cf = frameZ(dir * 0.98 + Vector3.new(0, -0.124, 0), dir + Vector3.new(0, -0.1, 0))
		ellipsoid(ctx, "BowTail" .. i, cf, Vector3.new(0.09, 0.03, 0.3), ribbon, FABRIC)
	end
	return crown
end

-- Caping: kerucut landai dari enam silinder bertingkat berselang warna anyaman + kenop puncak.
local function buildCaping(ctx: Ctx, c: CosmeticDef): BasePart
	ctx.Origin *= CFrame.Angles(math.rad(-3), 0, math.rad(-2))
	local light = pick(c.Colors, 1, Color3.fromRGB(214, 182, 112))
	local dark = pick(c.Colors, 2, Color3.fromRGB(150, 112, 62))
	local diameters = { 2.5, 2.1, 1.7, 1.3, 0.9, 0.5 }
	local rim = cylY(ctx, "Handle", Vector3.new(0, -0.2, 0), diameters[1], 0.085, dark, FABRIC, true)
	for i = 2, #diameters do
		local color = if i % 2 == 0 then light else light:Lerp(dark, 0.3)
		cylY(ctx, "Tier" .. i, Vector3.new(0, -0.2 + (i - 1) * 0.072, 0), diameters[i], 0.085, color, FABRIC, i <= 3)
	end
	ball(ctx, "Knob", Vector3.new(0, 0.235, 0), 0.16, dark, FABRIC)
	return rim
end

-- Bandana bajak laut: kain menutup kepala, ikat kepala, simpul + dua ekor di belakang, totol putih.
local function buildBandana(ctx: Ctx, c: CosmeticDef): BasePart
	local red = pick(c.Colors, 1, Color3.fromRGB(190, 46, 46))
	local dot = pick(c.Colors, 2, Color3.fromRGB(245, 240, 230))
	local domeCenter = Vector3.new(0, -0.18, 0)
	local domeSemi = Vector3.new(0.67, 0.4, 0.68)
	local dome = ellipsoid(ctx, "Handle", CFrame.new(domeCenter), domeSemi * 2, red, FABRIC, true)
	cylY(ctx, "Band", Vector3.new(0, -0.36, 0), 1.36, 0.17, shade(red, 0.9), FABRIC)
	ellipsoid(ctx, "Knot", CFrame.new(0, -0.33, 0.71), Vector3.new(0.24, 0.2, 0.18), shade(red, 0.86), FABRIC)
	for _, s in SIDES do
		local cf = CFrame.new(0.08 * s, -0.53, 0.74) * CFrame.Angles(math.rad(-12), 0, math.rad(14 * s))
		ellipsoid(ctx, "Tail" .. sideTag(s), cf, Vector3.new(0.16, 0.4, 0.06), shade(red, 0.84), FABRIC)
	end
	for i, ae in
		{ Vector2.new(0, 34), Vector2.new(72, 42), Vector2.new(144, 30), Vector2.new(216, 38), Vector2.new(288, 30) }
	do
		local az, el = math.rad(ae.X), math.rad(ae.Y)
		local dir = Vector3.new(math.sin(az) * math.cos(el), math.sin(el), -math.cos(az) * math.cos(el))
		local p, n = surfaceAlong(domeCenter, domeSemi, dir)
		ellipsoid(ctx, "Dot" .. i, frameZ(p - n * 0.004, n), Vector3.new(0.12, 0.1, 0.03), dot)
	end
	return dome
end

-- Topi kapten: pita navy, penutup putih membulat, visor gelap mengilap, lencana jangkar emas.
local function buildCaptain(ctx: Ctx, c: CosmeticDef): BasePart
	local white = pick(c.Colors, 1, Color3.fromRGB(245, 245, 240))
	local navy = pick(c.Colors, 2, Color3.fromRGB(24, 40, 72))
	local gold = pick(c.Colors, 3, Color3.fromRGB(242, 193, 78))
	local band = cylY(ctx, "Handle", Vector3.new(0, -0.13, 0), 1.36, 0.3, navy, FABRIC, true)
	cylY(ctx, "Cover", Vector3.new(0, 0.07, 0), 1.56, 0.12, white, FABRIC, true)
	ellipsoid(ctx, "Top", CFrame.new(0, 0.12, 0), Vector3.new(1.56, 0.2, 1.56), white, FABRIC, true)
	local visorCF = CFrame.new(0, -0.255, -0.6) * CFrame.Angles(math.rad(-18), 0, 0)
	local visor = ellipsoid(ctx, "Visor", visorCF, Vector3.new(1, 0.07, 0.64), shade(navy, 0.7), PLASTIC, true)
	visor.Reflectance = 0.2
	local badge: { BasePart } = {
		cylY(ctx, "AnchorShank", Vector3.new(0, -0.11, -0.7), 0.035, 0.16, gold, METAL),
		rod(ctx, "AnchorStock", Vector3.new(-0.06, -0.05, -0.705), Vector3.new(0.06, -0.05, -0.705), 0.03, gold, METAL),
		ball(ctx, "AnchorRing", Vector3.new(0, -0.01, -0.7), 0.055, gold, METAL),
		ellipsoid(ctx, "AnchorFlukes", CFrame.new(0, -0.18, -0.705), Vector3.new(0.18, 0.05, 0.035), gold, METAL),
	}
	for _, part in badge do
		part.Reflectance = 0.3
	end
	return band
end

-- Mahkota kerang: lingkar emas, lima kerang tegak condong keluar, mutiara di antaranya + satu di puncak depan.
local function buildShellCrown(ctx: Ctx, c: CosmeticDef): BasePart
	local pink = pick(c.Colors, 1, Color3.fromRGB(255, 214, 220))
	local gold = pick(c.Colors, 2, Color3.fromRGB(242, 193, 78))
	local pearl = pick(c.Colors, 3, Color3.fromRGB(250, 248, 240))
	local circlet = cylY(ctx, "Handle", Vector3.new(0, -0.14, 0), 1.36, 0.16, gold, METAL, true)
	circlet.Reflectance = 0.25
	for i, deg in { 0, 60, -60, 140, -140 } do
		local a = math.rad(deg)
		local radial = Vector3.new(math.sin(a), 0, -math.cos(a))
		local big = i == 1
		local size = if big then Vector3.new(0.38, 0.42, 0.08) else Vector3.new(0.3, 0.34, 0.07)
		local pos = radial * 0.7 + Vector3.new(0, if big then 0.05 else 0.02, 0)
		local cf = frameZ(pos, radial) * CFrame.Angles(math.rad(12), 0, 0)
		ellipsoid(ctx, "Shell" .. i, cf, size, if big then pink else shade(pink, 0.97), PLASTIC, true)
	end
	for i, deg in { 30, -30, 100, -100, 180 } do
		local a = math.rad(deg)
		local pos = Vector3.new(math.sin(a), 0, -math.cos(a)) * 0.7 + Vector3.new(0, -0.14, 0)
		ball(ctx, "Pearl" .. i, pos, 0.1, pearl).Reflectance = 0.25
	end
	ball(ctx, "PearlTop", Vector3.new(0, 0.29, -0.745), 0.12, pearl).Reflectance = 0.3
	return circlet
end

-- Topi nelayan tua: bucket kain lusuh agak miring, pinggiran melorot, tambalan, umpan tiruan tersemat.
local function buildOldFisher(ctx: Ctx, c: CosmeticDef): BasePart
	ctx.Origin *= CFrame.Angles(math.rad(-5), 0, math.rad(4))
	local cloth = pick(c.Colors, 1, Color3.fromRGB(92, 84, 70))
	local dark = pick(c.Colors, 2, Color3.fromRGB(60, 52, 44))
	local crown = cylY(ctx, "Handle", Vector3.zero, 1.38, 0.36, cloth, FABRIC, true)
	local topCF = CFrame.new(0.02, 0.17, 0) * CFrame.Angles(math.rad(4), 0, math.rad(-5))
	ellipsoid(ctx, "Top", topCF, Vector3.new(1.38, 0.26, 1.38), shade(cloth, 1.05), FABRIC, true)
	ellipsoid(ctx, "Brim", CFrame.new(0, -0.2, 0), Vector3.new(2, 0.24, 2), shade(cloth, 0.94), FABRIC, true)
	cylY(ctx, "Band", Vector3.new(0, -0.12, 0), 1.42, 0.1, dark, FABRIC)
	local pa = math.rad(70)
	local patchDir = Vector3.new(math.sin(pa), 0, -math.cos(pa))
	ellipsoid(
		ctx,
		"Patch",
		frameZ(patchDir * 0.69 + Vector3.new(0, 0.05, 0), patchDir),
		Vector3.new(0.3, 0.24, 0.04),
		cloth:Lerp(dark, 0.55),
		FABRIC
	)
	local la = math.rad(-35)
	local lureDir = Vector3.new(math.sin(la), 0, -math.cos(la))
	local tangent = Vector3.new(math.cos(la), 0, math.sin(la))
	local lurePos = lureDir * 0.72 + Vector3.new(0, 0.05, 0)
	local lureAxis = (tangent * 0.6 + Vector3.new(0, -0.8, 0)).Unit
	ellipsoid(ctx, "Lure", frameZ(lurePos, lureAxis, lureDir), Vector3.new(0.07, 0.07, 0.2), LURE_RED)
	ball(ctx, "LureHook", lurePos + lureAxis * 0.11, 0.045, HOOK_SILVER, METAL)
	return crown
end

-- Topi ranger: pinggiran lebar kaku, mahkota tinggi berpuncak, pita gelap, tali dagu melingkar di belakang kepala.
local function buildRanger(ctx: Ctx, c: CosmeticDef): BasePart
	local olive = pick(c.Colors, 1, Color3.fromRGB(110, 120, 70))
	local dark = pick(c.Colors, 2, Color3.fromRGB(70, 76, 44))
	local crown = cylY(ctx, "Handle", Vector3.new(0, -0.03, 0), 1.34, 0.3, olive, FABRIC, true)
	cylY(ctx, "Brim", Vector3.new(0, -0.19, 0), 2.3, 0.06, shade(olive, 0.95), FABRIC, true)
	ellipsoid(ctx, "Crown", CFrame.new(0, 0.12, 0), Vector3.new(1.34, 0.6, 1.34), olive, FABRIC, true)
	ellipsoid(ctx, "Peak", CFrame.new(0, 0.33, 0), Vector3.new(0.84, 0.5, 0.84), shade(olive, 1.04), FABRIC, true)
	cylY(ctx, "Band", Vector3.new(0, -0.1, 0), 1.38, 0.1, dark, FABRIC)
	local strap = {
		Vector3.new(-0.55, -0.17, 0.38),
		Vector3.new(-0.3, -0.62, 0.66),
		Vector3.new(0.3, -0.62, 0.66),
		Vector3.new(0.55, -0.17, 0.38),
	}
	for i = 1, 3 do
		rod(ctx, "Strap" .. i, strap[i], strap[i + 1], 0.04, dark, FABRIC)
	end
	return crown
end

-- =========================================================================
-- Aksesori
-- =========================================================================

-- Kacamata hitam (FaceFrontAttachment): lensa mengilap melengkung mengikuti wajah, bingkai & gagang emas.
local function buildSunglasses(ctx: Ctx, c: CosmeticDef): BasePart
	local lensColor = pick(c.Colors, 1, Color3.fromRGB(20, 22, 26))
	local frame = pick(c.Colors, 2, Color3.fromRGB(200, 170, 90))
	local bridge =
		rod(ctx, "Handle", Vector3.new(-0.08, 0.17, -0.06), Vector3.new(0.08, 0.17, -0.06), 0.035, frame, METAL)
	for _, s in SIDES do
		local tag = sideTag(s)
		local lensCF = CFrame.new(0.25 * s, 0.12, -0.05) * CFrame.Angles(0, math.rad(-12 * s), 0)
		ellipsoid(ctx, "Lens" .. tag, lensCF, Vector3.new(0.38, 0.26, 0.07), lensColor).Reflectance = 0.35
		ellipsoid(ctx, "Rim" .. tag, lensCF * CFrame.new(0, 0, 0.014), Vector3.new(0.42, 0.3, 0.04), frame, METAL)
		rod(
			ctx,
			"Temple" .. tag,
			Vector3.new(0.47 * s, 0.15, 0),
			Vector3.new(0.68 * s, 0.13, 0.62),
			0.035,
			frame,
			METAL
		)
	end
	return bridge
end

-- Kalung kerang (NeckAttachment): tali melewati bahu dan turun ke dada, kerang kecil + liontin kerang besar.
local function buildShellNecklace(ctx: Ctx, c: CosmeticDef): BasePart
	local shellColor = pick(c.Colors, 1, Color3.fromRGB(250, 244, 230))
	local cord = pick(c.Colors, 2, Color3.fromRGB(150, 110, 70))
	local forward = Vector3.new(0, 0.15, -1)
	local pendant = ellipsoid(
		ctx,
		"Handle",
		frameZ(Vector3.new(0, -0.35, -0.565), forward),
		Vector3.new(0.3, 0.34, 0.08),
		shellColor,
		PLASTIC,
		true
	)
	for _, s in SIDES do
		local tag = sideTag(s)
		local back = Vector3.new(0.7 * s, 0.035, 0.1)
		local edge = Vector3.new(0.55 * s, 0.035, -0.535)
		local chest = Vector3.new(0.27 * s, -0.2, -0.545)
		local low = Vector3.new(0.05 * s, -0.25, -0.55)
		rod(ctx, "CordTop" .. tag, back, edge, 0.035, cord, FABRIC)
		rod(ctx, "CordFront" .. tag, edge, chest, 0.035, cord, FABRIC)
		rod(ctx, "CordLow" .. tag, chest, low, 0.035, cord, FABRIC)
		local topCF = frameZ(edge + Vector3.new(0, 0.025, -0.012), Vector3.new(0, 0.6, -0.8))
		ellipsoid(ctx, "ShellTop" .. tag, topCF, Vector3.new(0.18, 0.19, 0.06), shade(shellColor, 0.97))
		ellipsoid(
			ctx,
			"Shell" .. tag,
			frameZ(chest + Vector3.new(0, -0.02, -0.02), forward),
			Vector3.new(0.2, 0.22, 0.06),
			shellColor
		)
		local smallCF = frameZ((chest + low) / 2 + Vector3.new(0, -0.03, -0.02), forward)
		ellipsoid(ctx, "ShellSmall" .. tag, smallCF, Vector3.new(0.14, 0.15, 0.055), shade(shellColor, 0.95))
	end
	return pendant
end

-- Rompi pelampung (BodyFrontAttachment): panel busa depan & belakang membulat, tali bahu melengkung,
-- pita reflektif, dua tali + gesper di depan.
local function buildLifeVest(ctx: Ctx, c: CosmeticDef): BasePart
	local orange = pick(c.Colors, 1, Color3.fromRGB(255, 122, 40))
	local tape = pick(c.Colors, 2, Color3.fromRGB(240, 240, 235))
	local panelSemi = Vector3.new(0.43, 0.62, 0.22)
	local back =
		ellipsoid(ctx, "Handle", CFrame.new(0, 0.2, 1.03), Vector3.new(1.84, 1.24, 0.44), orange, PLASTIC, true)
	for _, s in SIDES do
		local tag = sideTag(s)
		local panel = CFrame.new(0.47 * s, 0.2, -0.03)
		ellipsoid(ctx, "Front" .. tag, panel, panelSemi * 2, orange, PLASTIC, true)
		bandAround(ctx, "Tape" .. tag, panel, panelSemi, -0.1, 0.08, 1.08, tape)
		bandAround(ctx, "StrapUpper" .. tag, panel, panelSemi, 0.24, 0.06, 1.06, STRAP_DARK, FABRIC)
		bandAround(ctx, "StrapLower" .. tag, panel, panelSemi, -0.34, 0.06, 1.06, STRAP_DARK, FABRIC)
		-- Lengkung tali bahu: elipsoid besar berpusat di dalam torso, tampak sebagai busur di atas bahu.
		ellipsoid(ctx, "Shoulder" .. tag, CFrame.new(0.68 * s, 0.72, 0.5), Vector3.new(0.3, 0.72, 1.32), orange)
	end
	for i, y in { 0.44, -0.14 } do
		ellipsoid(ctx, "Buckle" .. i, CFrame.new(0, y, -0.2), Vector3.new(0.2, 0.1, 0.07), BUCKLE)
	end
	return back
end

-- Ransel ikan kembung (BodyBackAttachment): badan ikan melintang miring di punggung, perut perak, ritsleting,
-- sirip & ekor, satu mata di sisi luar, dan tali bahu empuk.
local function buildFishBackpack(ctx: Ctx, c: CosmeticDef): BasePart
	local blue = pick(c.Colors, 1, Color3.fromRGB(61, 110, 143))
	local silver = pick(c.Colors, 2, Color3.fromRGB(220, 230, 236))
	local fish = CFrame.new(0, 0.32, 0.27) * CFrame.Angles(0, 0, math.rad(10))
	local semi = Vector3.new(0.82, 0.43, 0.27)
	local body = ellipsoid(ctx, "Handle", fish, semi * 2, blue, PLASTIC, true)
	ellipsoid(ctx, "Belly", fish * CFrame.new(0, -0.1, 0.005), Vector3.new(1.48, 0.68, 0.51), silver)
	bandAround(ctx, "Zipper", fish, semi, 0.17, 0.035, 1.05, Color3.fromRGB(86, 92, 102))
	local pullPos = fish * Vector3.new(-0.35, 0.17, 0.24)
	ball(ctx, "ZipPull", pullPos, 0.07, HOOK_SILVER, METAL)
	rod(ctx, "ZipTab", pullPos, fish * Vector3.new(-0.35, 0.07, 0.235), 0.035, HOOK_SILVER, METAL)

	-- Ekor (ke −X lokal) dan sirip punggung; pelat sirip sejajar bidang XY ikan.
	local root = fish * Vector3.new(-0.78, 0, 0)
	local cosA, sinA = math.cos(math.rad(22)), math.sin(math.rad(22))
	local rot = fish.Rotation
	local finColor = shade(blue, 0.85)
	fin(
		ctx,
		"TailUpper",
		root,
		root + rot * Vector3.new(-cosA, sinA, 0) * 0.32,
		0.27,
		rot * Vector3.new(sinA, cosA, 0),
		finColor
	)
	fin(
		ctx,
		"TailLower",
		root,
		root + rot * Vector3.new(-cosA, -sinA, 0) * 0.32,
		0.27,
		rot * Vector3.new(sinA, -cosA, 0),
		finColor
	)
	fin(
		ctx,
		"Dorsal",
		fish * Vector3.new(0.22, 0.384, 0),
		fish * Vector3.new(-0.28, 0.374, 0),
		0.17,
		rot * UP,
		finColor
	)

	-- Mata menghadap belakang (sisi luar ransel) + mulut di ujung kepala (+X lokal).
	local eyeLocal = Vector3.new(0.56, 0.08, 0.191)
	local normal = rot * Vector3.new(0.298, 0.155, 0.942).Unit
	local eyeCenter = fish * eyeLocal - normal * 0.028
	ball(ctx, "Eye", eyeCenter, 0.19, FISH_EYE)
	ball(ctx, "Pupil", eyeCenter + (normal + rot * Vector3.new(0.35, 0, 0)).Unit * 0.066, 0.105, FISH_PUPIL)
	ellipsoid(
		ctx,
		"Mouth",
		fish * CFrame.new(0.805, -0.07, 0),
		Vector3.new(0.06, 0.05, 0.12),
		Color3.fromRGB(40, 44, 52)
	)

	-- Tali bahu: elipsoid berpusat di dalam torso, menonjol di atas bahu dan di dada.
	for _, s in SIDES do
		ellipsoid(
			ctx,
			"Strap" .. sideTag(s),
			CFrame.new(0.7 * s, 0.62, -0.5),
			Vector3.new(0.14, 0.88, 1.28),
			STRAP_DARK,
			FABRIC
		)
	end
	return body
end

local WEARABLES: { [string]: Wearable } = {
	Straw = { Attachment = "HatAttachment", AccessoryType = Enum.AccessoryType.Hat, Build = buildStraw },
	Caping = { Attachment = "HatAttachment", AccessoryType = Enum.AccessoryType.Hat, Build = buildCaping },
	Bandana = { Attachment = "HatAttachment", AccessoryType = Enum.AccessoryType.Hat, Build = buildBandana },
	Captain = { Attachment = "HatAttachment", AccessoryType = Enum.AccessoryType.Hat, Build = buildCaptain },
	ShellCrown = { Attachment = "HatAttachment", AccessoryType = Enum.AccessoryType.Hat, Build = buildShellCrown },
	OldFisher = { Attachment = "HatAttachment", AccessoryType = Enum.AccessoryType.Hat, Build = buildOldFisher },
	Ranger = { Attachment = "HatAttachment", AccessoryType = Enum.AccessoryType.Hat, Build = buildRanger },
	Sunglasses = {
		Attachment = "FaceFrontAttachment",
		AccessoryType = Enum.AccessoryType.Face,
		Build = buildSunglasses,
	},
	ShellNecklace = {
		Attachment = "NeckAttachment",
		AccessoryType = Enum.AccessoryType.Neck,
		Build = buildShellNecklace,
	},
	LifeVest = { Attachment = "BodyFrontAttachment", AccessoryType = Enum.AccessoryType.Front, Build = buildLifeVest },
	FishBackpack = {
		Attachment = "BodyBackAttachment",
		AccessoryType = Enum.AccessoryType.Back,
		Build = buildFishBackpack,
	},
}

local function wearableFor(cosmetic: CosmeticDef): Wearable?
	if cosmetic.Slot ~= "Hat" and cosmetic.Slot ~= "Accessory" then
		return nil
	end
	return WEARABLES[cosmetic.Style]
end

-- =========================================================================
-- Jejak & aura
-- =========================================================================

local function rootPartOf(character: Model): BasePart?
	local found = character:FindFirstChild("HumanoidRootPart")
	if found and found:IsA("BasePart") then
		return found
	end
	return nil
end

-- Jarak tanah dari pusat HumanoidRootPart (negatif). R15: HipHeight + setengah tinggi root; R6: 3 stud.
local function groundOffset(character: Model, root: BasePart): number
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		if humanoid.RigType == Enum.HumanoidRigType.R6 then
			return -3
		end
		return -(humanoid.HipHeight + root.Size.Y / 2)
	end
	return -2.35
end

local function trailSpec(cosmetic: CosmeticDef, groundY: number): TrailSpec
	local c1 = pick(cosmetic.Colors, 1, Color3.fromRGB(200, 240, 255))
	local c2 = pick(cosmetic.Colors, 2, c1)
	local style = cosmetic.Style
	if style == "Waves" then
		-- Riak tosca setinggi betis; lebar bergelombang di sepanjang jejak.
		return {
			Color = ColorSequence.new(c1, c2),
			Transparency = seq({ { 0, 0.2 }, { 0.55, 0.55 }, { 1, 1 } }),
			Width = seq({ { 0, 1 }, { 0.2, 0.55 }, { 0.4, 0.95 }, { 0.6, 0.5 }, { 0.8, 0.75 }, { 1, 0.2 } }),
			Lifetime = 0.9,
			Top = Vector3.new(0, groundY + 0.75, 0.35),
			Bottom = Vector3.new(0, groundY + 0.05, 0.35),
			LightEmission = 0.3,
			LightInfluence = 0.6,
			Bubbles = false,
			Flat = false,
		}
	elseif style == "RainbowTrail" then
		-- Selendang pelangi di belakang punggung.
		return {
			Color = rainbowSequence(),
			Transparency = seq({ { 0, 0.12 }, { 0.7, 0.4 }, { 1, 1 } }),
			Width = seq({ { 0, 1 }, { 1, 0.55 } }),
			Lifetime = 1.1,
			Top = Vector3.new(0, 1.2, 0.45),
			Bottom = Vector3.new(0, -0.4, 0.45),
			LightEmission = 0.3,
			LightInfluence = 0.5,
			Bubbles = false,
			Flat = false,
		}
	elseif style == "Turtle" then
		-- Jejak pasir penyu: pita hampir rata di tanah, bertahan lama.
		return {
			Color = ColorSequence.new(c1, c1:Lerp(c2, 0.45)),
			Transparency = seq({ { 0, 0.1 }, { 0.7, 0.45 }, { 1, 1 } }),
			Width = NumberSequence.new(1),
			Lifetime = 2.4,
			Top = Vector3.new(-0.42, groundY + 0.1, 0.15),
			Bottom = Vector3.new(0.42, groundY + 0.04, 0.15),
			LightEmission = 0,
			LightInfluence = 1,
			Bubbles = false,
			Flat = true,
		}
	end
	-- Bubbles (dan gaya tak dikenal): pita air tipis + gelembung naik dari kaki.
	return {
		Color = ColorSequence.new(c1, c2),
		Transparency = seq({ { 0, 0.55 }, { 0.6, 0.8 }, { 1, 1 } }),
		Width = seq({ { 0, 1 }, { 1, 0.35 } }),
		Lifetime = 0.6,
		Top = Vector3.new(0, 0.2, 0.45),
		Bottom = Vector3.new(0, groundY + 0.2, 0.45),
		LightEmission = 0.35,
		LightInfluence = 0.6,
		Bubbles = true,
		Flat = false,
	}
end

local function makeEmitter(spec: EmitterSpec): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = spec.Name
	e.Texture = spec.Texture
	e.Color = spec.Color
	e.Size = spec.Size
	e.Transparency = spec.Transparency
	e.Lifetime = spec.Lifetime
	e.Rate = spec.Rate
	e.Speed = spec.Speed
	e.SpreadAngle = spec.Spread
	e.Acceleration = spec.Acceleration
	e.LightEmission = spec.LightEmission
	e.LightInfluence = 0
	e.Drag = spec.Drag
	e.LockedToPart = spec.Locked
	e.EmissionDirection = spec.Direction
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-60, 60)
	return e
end

local function makeLight(name: string, color: Color3, brightness: number, range: number): PointLight
	local light = Instance.new("PointLight")
	light.Name = name
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Shadows = false
	return light
end

local function bubbleEmitter(c1: Color3, c2: Color3): ParticleEmitter
	return makeEmitter({
		Name = "Gelembung",
		Texture = TEX_GLOW,
		Color = ColorSequence.new(c1, c2),
		Size = seq({ { 0, 0.15 }, { 0.6, 0.35 }, { 1, 0.42 } }),
		Transparency = seq({ { 0, 0.3 }, { 0.8, 0.5 }, { 1, 1 } }),
		Lifetime = NumberRange.new(1.2, 2),
		Rate = 7,
		Speed = NumberRange.new(0.4, 1),
		Spread = Vector2.new(30, 30),
		Acceleration = Vector3.new(0, 1.6, 0),
		LightEmission = 0.5,
		Drag = 0.4,
		Locked = false,
		Direction = Enum.NormalId.Top,
	})
end

-- Efek aura per gaya (belum di-parent).
local function auraEffects(cosmetic: CosmeticDef): { Instance }
	local c1 = pick(cosmetic.Colors, 1, Color3.fromRGB(170, 230, 255))
	local c2 = pick(cosmetic.Colors, 2, c1)
	local style = cosmetic.Style
	if style == "Fireflies" then
		return {
			makeEmitter({
				Name = "KunangKunang",
				Texture = TEX_GLOW,
				Color = ColorSequence.new(c1, c2),
				Size = seq({ { 0, 0 }, { 0.15, 0.22 }, { 0.85, 0.22 }, { 1, 0 } }),
				Transparency = seq({ { 0, 0 }, { 0.3, 0.5 }, { 0.5, 0 }, { 0.75, 0.6 }, { 1, 1 } }),
				Lifetime = NumberRange.new(3, 5),
				Rate = 3,
				Speed = NumberRange.new(0.3, 0.8),
				Spread = Vector2.new(180, 180),
				Acceleration = Vector3.new(0, 0.15, 0),
				LightEmission = 1,
				Drag = 0.6,
				Locked = false,
				Direction = Enum.NormalId.Top,
			}),
			makeLight("CahayaKunang", c1, 0.8, 7),
		}
	elseif style == "TurtleAura" then
		return {
			makeEmitter({
				Name = "AuraPenyu",
				Texture = TEX_GLOW,
				Color = ColorSequence.new(c1, c2),
				Size = seq({ { 0, 0.5 }, { 1, 1.2 } }),
				Transparency = seq({ { 0, 0.75 }, { 0.5, 0.85 }, { 1, 1 } }),
				Lifetime = NumberRange.new(1.6, 2.2),
				Rate = 4,
				Speed = NumberRange.new(0.2, 0.5),
				Spread = Vector2.new(180, 180),
				Acceleration = Vector3.new(0, 0.3, 0),
				LightEmission = 0.6,
				Drag = 0.5,
				Locked = true,
				Direction = Enum.NormalId.Top,
			}),
			makeLight("CahayaPenyu", c1, 0.9, 8),
		}
	elseif style == "OceanLight" then
		return {
			makeEmitter({
				Name = "CahayaSamudra",
				Texture = TEX_SPARKLE,
				Color = ColorSequence.new(c2, c1),
				Size = seq({ { 0, 0.12 }, { 0.5, 0.3 }, { 1, 0 } }),
				Transparency = seq({ { 0, 0.2 }, { 1, 1 } }),
				Lifetime = NumberRange.new(1.4, 2.4),
				Rate = 8,
				Speed = NumberRange.new(1, 2),
				Spread = Vector2.new(40, 40),
				Acceleration = Vector3.new(0, 0.6, 0),
				LightEmission = 1,
				Drag = 0.3,
				Locked = false,
				Direction = Enum.NormalId.Top,
			}),
			makeEmitter({
				Name = "PendarSamudra",
				Texture = TEX_GLOW,
				Color = ColorSequence.new(c1, c2),
				Size = seq({ { 0, 1.4 }, { 1, 2 } }),
				Transparency = seq({ { 0, 0.82 }, { 1, 1 } }),
				Lifetime = NumberRange.new(1.2, 1.6),
				Rate = 3,
				Speed = NumberRange.new(0, 0.2),
				Spread = Vector2.new(180, 180),
				Acceleration = Vector3.zero,
				LightEmission = 0.8,
				Drag = 0,
				Locked = true,
				Direction = Enum.NormalId.Top,
			}),
			makeLight("CahayaSamudra", c1, 1.4, 10),
		}
	end
	-- Splash (dan gaya tak dikenal): cipratan berkilau yang melengkung jatuh.
	return {
		makeEmitter({
			Name = "Percikan",
			Texture = TEX_SPARKLE,
			Color = ColorSequence.new(c1, c2),
			Size = seq({ { 0, 0.32 }, { 1, 0.06 } }),
			Transparency = seq({ { 0, 0.1 }, { 0.7, 0.3 }, { 1, 1 } }),
			Lifetime = NumberRange.new(0.7, 1.1),
			Rate = 10,
			Speed = NumberRange.new(4, 6.5),
			Spread = Vector2.new(28, 28),
			Acceleration = Vector3.new(0, -16, 0),
			LightEmission = 0.6,
			Drag = 0.5,
			Locked = false,
			Direction = Enum.NormalId.Top,
		}),
	}
end

-- =========================================================================
-- API
-- =========================================================================

-- Accessory untuk slot "Hat"/"Accessory" (lainnya → nil). Handle membawa Attachment bernama standar R15 sehingga
-- Humanoid:AddAccessory (server) menyelaraskannya; part lain dilas WeldConstraint ke Handle.
function CosmeticModels.BuildAccessory(cosmetic: CosmeticDef): Accessory?
	local wearable = wearableFor(cosmetic)
	if wearable == nil then
		return nil
	end
	local ctx = newCtx(CFrame.identity, false)
	local handle = wearable.Build(ctx, cosmetic)
	handle.Name = "Handle"
	local attachment = Instance.new("Attachment")
	attachment.Name = wearable.Attachment
	attachment.CFrame = handle.CFrame:Inverse()
	attachment.Parent = handle
	for _, part in ctx.Parts do
		if part ~= handle then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = handle
			weld.Part1 = part
			weld.Parent = part
		end
	end
	local accessory = Instance.new("Accessory")
	accessory.Name = cosmetic.Id
	accessory.AccessoryType = wearable.AccessoryType
	accessory:SetAttribute("CosmeticId", cosmetic.Id)
	for _, part in ctx.Parts do
		part.Parent = accessory
	end
	return accessory
end

-- Jejak: dua Attachment di HumanoidRootPart (atas & bawah) + Trail (Bubbles juga gelembung partikel).
function CosmeticModels.ApplyTrail(character: Model, cosmetic: CosmeticDef): { Instance }
	local created: { Instance } = {}
	local root = rootPartOf(character)
	if root == nil or cosmetic.Slot ~= "Trail" then
		return created
	end
	local spec = trailSpec(cosmetic, groundOffset(character, root))
	local top = Instance.new("Attachment")
	top.Name = "TrailTop"
	top.CFrame = CFrame.new(spec.Top)
	local bottom = Instance.new("Attachment")
	bottom.Name = "TrailBottom"
	bottom.CFrame = CFrame.new(spec.Bottom)
	local trail = Instance.new("Trail")
	trail.Name = "JejakKosmetik"
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Color = spec.Color
	trail.Transparency = spec.Transparency
	trail.WidthScale = spec.Width
	trail.Lifetime = spec.Lifetime
	trail.MinLength = 0.1
	trail.FaceCamera = false
	trail.LightEmission = spec.LightEmission
	trail.LightInfluence = spec.LightInfluence
	trail:SetAttribute("CosmeticId", cosmetic.Id)
	top.Parent = root
	bottom.Parent = root
	trail.Parent = root
	table.insert(created, top)
	table.insert(created, bottom)
	table.insert(created, trail)
	if spec.Bubbles then
		local emitter = bubbleEmitter(
			pick(cosmetic.Colors, 1, Color3.fromRGB(200, 240, 255)),
			pick(cosmetic.Colors, 2, Color3.fromRGB(120, 200, 240))
		)
		emitter:SetAttribute("CosmeticId", cosmetic.Id)
		emitter.Parent = bottom
		table.insert(created, emitter)
	end
	return created
end

-- Aura: ParticleEmitter/PointLight di HumanoidRootPart. Gaya NightOnly (Fireflies) diberi atribut "NightOnly" = true
-- dan Enabled awal false; klien menyalakannya saat malam.
function CosmeticModels.ApplyAura(character: Model, cosmetic: CosmeticDef): { Instance }
	local created: { Instance } = {}
	local root = rootPartOf(character)
	if root == nil or cosmetic.Slot ~= "Aura" then
		return created
	end
	local nightOnly = cosmetic.NightOnly == true or cosmetic.Style == "Fireflies"
	for _, effect in auraEffects(cosmetic) do
		if nightOnly then
			effect:SetAttribute("NightOnly", true)
			if effect:IsA("ParticleEmitter") then
				effect.Enabled = false
			elseif effect:IsA("Light") then
				effect.Enabled = false
			end
		end
		effect:SetAttribute("CosmeticId", cosmetic.Id)
		effect.Parent = root
		table.insert(created, effect)
	end
	return created
end

-- Penyangga kepala: kepala bulat-silinder Ø1,25 (seukuran kepala R15) di origin, leher, dan alas kayu.
local function buildHeadStand(ctx: Ctx): BasePart
	local head = cylY(ctx, "StandHead", Vector3.zero, 1.25, 0.72, STAND, PLASTIC, true)
	ellipsoid(ctx, "StandHeadTop", CFrame.new(0, 0.36, 0), Vector3.new(1.25, 0.53, 1.25), STAND)
	ellipsoid(ctx, "StandHeadBottom", CFrame.new(0, -0.36, 0), Vector3.new(1.25, 0.53, 1.25), STAND)
	cylY(ctx, "StandNeck", Vector3.new(0, -0.85, 0), 0.46, 0.5, shade(STAND, 0.92))
	cylY(ctx, "StandBase", Vector3.new(0, -1.14, 0), 1.1, 0.12, STAND_BASE, Enum.Material.Wood, true)
	return head
end

-- Penyangga torso: UpperTorso R15 (2 × 1,6 × 1) di origin + kepala, tiang, dan alas kayu.
local function buildTorsoStand(ctx: Ctx): BasePart
	local torso = block(ctx, "StandTorso", CFrame.identity, Vector3.new(2, 1.6, 1), STAND)
	cylY(ctx, "StandHead", Vector3.new(0, 1.3, 0), 1.25, 0.72, STAND)
	ellipsoid(ctx, "StandHeadTop", CFrame.new(0, 1.66, 0), Vector3.new(1.25, 0.53, 1.25), STAND)
	ellipsoid(ctx, "StandHeadBottom", CFrame.new(0, 0.94, 0), Vector3.new(1.25, 0.53, 1.25), STAND)
	cylY(ctx, "StandPole", Vector3.new(0, -1.25, 0), 0.3, 0.9, shade(STAND, 0.85))
	cylY(ctx, "StandBase", Vector3.new(0, -1.72, 0), 1.3, 0.12, STAND_BASE, Enum.Material.Wood, true)
	return torso
end

local function previewWearable(cosmetic: CosmeticDef, wearable: Wearable): Model
	-- Ransel dipajang membelakangi: seluruh pratinjau diputar 180° agar ransel menghadap depan model (−Z).
	local base = if wearable.Attachment == "BodyBackAttachment" then CFrame.Angles(0, math.pi, 0) else CFrame.identity
	local ctx = newCtx(base, true)
	local onHead = wearable.Attachment == "HatAttachment" or wearable.Attachment == "FaceFrontAttachment"
	local stand = if onHead then buildHeadStand(ctx) else buildTorsoStand(ctx)
	ctx.Origin = base * (STAND_ATTACH[wearable.Attachment] or CFrame.identity)
	wearable.Build(ctx, cosmetic)
	local model = Instance.new("Model")
	model.Name = "Preview_" .. cosmetic.Id
	for _, part in ctx.Parts do
		part.Parent = model
	end
	model.PrimaryPart = stand
	return model
end

-- Contoh pita warna melengkung: ujung terbaru (kanan) pekat, memudar ke kiri sesuai Transparency jejak.
-- Pita = rantai bilah tipis bersambung rapat (tanpa tumpang-tindih) sehingga tepinya mulus dan transparansinya rata.
local function previewTrail(cosmetic: CosmeticDef): Model
	local spec = trailSpec(cosmetic, -2.35)
	local ctx = newCtx(if spec.Flat then CFrame.Angles(math.rad(-60), 0, 0) else CFrame.identity, true)
	local function curve(t: number): Vector3
		return Vector3.new(2.1 - 4.2 * t, 0.55 * math.sin(math.pi * t * 1.15) - 0.25 * t, 0.25 * math.sin(math.pi * t))
	end
	local count = 16
	local first: BasePart? = nil
	for i = 1, count do
		local t0, t1 = (i - 1) / count, i / count
		local tm = (t0 + t1) / 2
		local a, b = curve(t0), curve(t1)
		local width = sampleNumber(spec.Width, tm)
		local length = (b - a).Magnitude + 0.012
		local size = if spec.Flat
			then Vector3.new(length, 0.05, 0.9 * width)
			else Vector3.new(length, 1.0 * width, 0.05)
		local piece = block(ctx, "Ribbon" .. i, frameX((a + b) / 2, b - a), size, sampleColor(spec.Color, tm))
		piece.CastShadow = false
		piece.Transparency = math.clamp(sampleNumber(spec.Transparency, tm), 0, 0.85)
		if first == nil then
			first = piece
		end
	end
	local c1 = pick(cosmetic.Colors, 1, Color3.fromRGB(200, 240, 255))
	if spec.Bubbles then
		for i, t in { 0.12, 0.3, 0.5, 0.72 } do
			local bubble = ball(
				ctx,
				"Bubble" .. i,
				curve(t) + Vector3.new(0, 0.55 + 0.1 * i, -0.1),
				0.42 - 0.07 * i,
				c1,
				Enum.Material.Glass
			)
			bubble.Transparency = 0.5
			bubble.Reflectance = 0.25
		end
	elseif spec.Flat then
		-- Bekas sirip penyu bergantian di kedua tepi jejak.
		local mark = shade(c1, 0.8)
		for i, t in { 0.15, 0.35, 0.55, 0.75 } do
			local side = if i % 2 == 1 then 1 else -1
			local p = curve(t) + Vector3.new(0, 0.03, 0.33 * side)
			ellipsoid(
				ctx,
				"FlipperMark" .. i,
				CFrame.new(p) * CFrame.Angles(0, math.rad(25 * side), 0),
				Vector3.new(0.16, 0.03, 0.08),
				mark
			)
		end
	end
	local model = Instance.new("Model")
	model.Name = "Preview_" .. cosmetic.Id
	for _, part in ctx.Parts do
		part.Parent = model
	end
	model.PrimaryPart = first
	return model
end

-- Bola cahaya berpartikel. ViewportFrame tidak merender partikel/cahaya, jadi butir kecil di sekitar bola ikut
-- menggambarkan gayanya.
local function previewAura(cosmetic: CosmeticDef): Model
	local ctx = newCtx(CFrame.identity, true)
	local c1 = pick(cosmetic.Colors, 1, Color3.fromRGB(170, 230, 255))
	local c2 = pick(cosmetic.Colors, 2, c1)
	local core = ball(ctx, "Core", Vector3.zero, 1.1, c1, Enum.Material.Neon)
	core.Transparency = 0.1
	local halo = ball(ctx, "Halo", Vector3.zero, 1.8, c2, Enum.Material.Glass)
	halo.Transparency = 0.72
	local moteMaterial = if cosmetic.Style == "Splash" then Enum.Material.Glass else Enum.Material.Neon
	for i = 1, 5 do
		local a = math.rad(i * 72 + 15)
		local pos = Vector3.new(math.cos(a) * 1.25, 0.35 * math.sin(i * 1.9), math.sin(a) * 1.25)
		ball(ctx, "Mote" .. i, pos, 0.14 + 0.03 * (i % 3), if i % 2 == 0 then c1 else c2, moteMaterial)
	end
	for _, effect in auraEffects(cosmetic) do
		effect.Parent = core
	end
	local model = Instance.new("Model")
	model.Name = "Preview_" .. cosmetic.Id
	for _, part in ctx.Parts do
		part.Parent = model
	end
	model.PrimaryPart = core
	return model
end

-- Model pratinjau anchored untuk ViewportFrame. Title (dan gaya tak dikenal) → nil.
function CosmeticModels.BuildPreview(cosmetic: CosmeticDef): Model?
	local slot = cosmetic.Slot
	if slot == "Hat" or slot == "Accessory" then
		local wearable = wearableFor(cosmetic)
		if wearable == nil then
			return nil
		end
		return previewWearable(cosmetic, wearable)
	elseif slot == "RodSkin" then
		local rod = Rods.Get("bambu") or Rods.List[1]
		local model = RodModel.BuildDisplay(rod, cosmetic)
		-- Diagonal agar joran ±7 stud pas di kartu persegi.
		model:PivotTo(CFrame.Angles(0, 0, math.rad(35)))
		return model
	elseif slot == "Bobber" then
		return BobberModel.Build(cosmetic)
	elseif slot == "Trail" then
		return previewTrail(cosmetic)
	elseif slot == "Aura" then
		return previewAura(cosmetic)
	end
	return nil
end

return CosmeticModels
