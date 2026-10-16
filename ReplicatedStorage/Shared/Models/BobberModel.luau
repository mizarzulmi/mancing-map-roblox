--!strict
-- BobberModel: pelampung prosedural (GDD 4.1 & Bagian 5) sesuai Style kosmetik slot "Bobber".
-- PrimaryPart "Float" (Ø ±0,9) berpusat di pivot model = garis air: PivotTo(titik di permukaan air) membuat bagian
-- bawah tenggelam dan bagian berwarna di atas air. Attachment "LineAttachment" (titik tali pancing) ada di Float,
-- pada puncak model. Semua part Anchored = true, CanCollide/CanQuery/CanTouch = false. Maksimum 10 part per gaya.

local Types = require(script.Parent.Parent.Types)

type CosmeticDef = Types.CosmeticDef

type Ctx = { Parts: { BasePart } }

-- Pembuat gaya: mengembalikan Float dan posisi LineAttachment (ruang lokal Float).
type StyleBuilder = (ctx: Ctx, colors: { Color3 }) -> (BasePart, Vector3)

local BobberModel = {}

local SIDES = { 1, -1 }
local UP = Vector3.yAxis
local WHITE = Color3.fromRGB(245, 245, 240)
local DARK_EYE = Color3.fromRGB(24, 24, 28)
local RIND_PALE = Color3.fromRGB(222, 240, 200)
local SEED = Color3.fromRGB(30, 26, 24)

local DEFAULT_COLORS = { Color3.fromRGB(214, 48, 49), WHITE }

local function shade(c: Color3, factor: number): Color3
	return Color3.new(math.clamp(c.R * factor, 0, 1), math.clamp(c.G * factor, 0, 1), math.clamp(c.B * factor, 0, 1))
end

local function pick(colors: { Color3 }, index: number, fallback: Color3): Color3
	local c: Color3? = colors[index]
	return if c then c else fallback
end

local function frameZ(pos: Vector3, dir: Vector3): CFrame
	local z = dir.Unit
	local hint = if math.abs(z:Dot(UP)) > 0.98 then Vector3.xAxis else UP
	local y = (hint - z * hint:Dot(z)).Unit
	return CFrame.fromMatrix(pos, y:Cross(z), y, z)
end

local function frameX(pos: Vector3, dir: Vector3): CFrame
	local x = dir.Unit
	local hint = if math.abs(x:Dot(UP)) > 0.98 then Vector3.zAxis else UP
	local z = x:Cross(hint).Unit
	return CFrame.fromMatrix(pos, x, z:Cross(x), z)
end

local function finish(
	ctx: Ctx,
	part: BasePart,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	shadow: boolean
): BasePart
	part.Name = name
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = shadow
	table.insert(ctx.Parts, part)
	return part
end

local function ball(ctx: Ctx, name: string, pos: Vector3, diameter: number, color: Color3, shadow: boolean?): BasePart
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Ball
	return finish(ctx, part, name, Vector3.one * diameter, CFrame.new(pos), color, shadow == true)
end

-- Elipsoid (SpecialMesh Sphere) berukuran penuh `size` dengan bingkai `cf`.
local function ellipsoid(ctx: Ctx, name: string, cf: CFrame, size: Vector3, color: Color3, shadow: boolean?): BasePart
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Block
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return finish(ctx, part, name, size, cf, color, shadow == true)
end

local function cylinder(ctx: Ctx, name: string, a: Vector3, b: Vector3, diameter: number, color: Color3): BasePart
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Cylinder
	local d = b - a
	return finish(ctx, part, name, Vector3.new(d.Magnitude, diameter, diameter), frameX((a + b) / 2, d), color, false)
end

-- Setengah irisan segitiga dari WedgePart: tepi p0 → p1, tinggi `height` ke arah `out`, sudut tinggi di p1.
local function halfSlice(
	ctx: Ctx,
	name: string,
	p0: Vector3,
	p1: Vector3,
	height: number,
	out: Vector3,
	thick: number,
	color: Color3
): BasePart
	local along = p1 - p0
	local z = along.Unit
	local y = (out - z * out:Dot(z)).Unit
	local cf = CFrame.fromMatrix((p0 + p1) / 2 + y * (height / 2), y:Cross(z), y, z)
	return finish(ctx, Instance.new("WedgePart"), name, Vector3.new(thick, height, along.Magnitude), cf, color, false)
end

-- Merah Putih: bola putih, tudung merah di atas garis air, tongkat antena, pasak bawah.
local function buildRedWhite(ctx: Ctx, colors: { Color3 }): (BasePart, Vector3)
	local red = pick(colors, 1, DEFAULT_COLORS[1])
	local white = pick(colors, 2, WHITE)
	local float = ball(ctx, "Float", Vector3.zero, 0.9, white, true)
	ellipsoid(ctx, "Cap", CFrame.new(0, 0.16, 0), Vector3.new(0.94, 0.62, 0.94), red, true)
	cylinder(ctx, "Stick", Vector3.new(0, 0.4, 0), Vector3.new(0, 0.92, 0), 0.07, white)
	ball(ctx, "StickTip", Vector3.new(0, 0.93, 0), 0.12, red)
	cylinder(ctx, "Peg", Vector3.new(0, -0.38, 0), Vector3.new(0, -0.62, 0), 0.08, white)
	return float, Vector3.new(0, 0.99, 0)
end

-- Bebek Kuning: badan elipsoid, kepala bola, paruh oranye, sayap, ekor terangkat.
local function buildDuck(ctx: Ctx, colors: { Color3 }): (BasePart, Vector3)
	local yellow = pick(colors, 1, Color3.fromRGB(255, 214, 64))
	local orange = pick(colors, 2, Color3.fromRGB(255, 140, 40))
	local float = ellipsoid(ctx, "Float", CFrame.identity, Vector3.new(0.9, 0.62, 1.05), yellow, true)
	ball(ctx, "Head", Vector3.new(0, 0.42, -0.32), 0.56, yellow, true)
	ellipsoid(ctx, "Beak", CFrame.new(0, 0.37, -0.62), Vector3.new(0.3, 0.1, 0.26), orange)
	ellipsoid(
		ctx,
		"Tail",
		CFrame.new(0, 0.2, 0.5) * CFrame.Angles(math.rad(-35), 0, 0),
		Vector3.new(0.3, 0.16, 0.28),
		yellow
	)
	for _, s in SIDES do
		local tag = if s > 0 then "R" else "L"
		ball(ctx, "Eye" .. tag, Vector3.new(0.15 * s, 0.5, -0.53), 0.09, DARK_EYE)
		ball(ctx, "Glint" .. tag, Vector3.new(0.165 * s, 0.525, -0.57), 0.035, WHITE)
		ellipsoid(
			ctx,
			"Wing" .. tag,
			CFrame.new(0.41 * s, 0.06, 0.06),
			Vector3.new(0.14, 0.32, 0.52),
			shade(yellow, 0.93)
		)
	end
	return float, Vector3.new(0, 0.7, -0.32)
end

-- Bintang Laut: cakram tengah + lima lengan membulat yang ujungnya sedikit terangkat.
local function buildStarfish(ctx: Ctx, colors: { Color3 }): (BasePart, Vector3)
	local orange = pick(colors, 1, Color3.fromRGB(255, 140, 70))
	local peach = pick(colors, 2, Color3.fromRGB(255, 200, 150))
	local float = ellipsoid(ctx, "Float", CFrame.identity, Vector3.new(0.6, 0.22, 0.6), orange, true)
	for i = 1, 5 do
		local a = math.rad(-90 + (i - 1) * 72)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local color = shade(orange, 1 + 0.04 * math.sin(i * 2.1))
		ellipsoid(
			ctx,
			"Arm" .. i,
			frameZ(dir * 0.33 + Vector3.new(0, 0.015, 0), dir + Vector3.new(0, 0.1, 0)),
			Vector3.new(0.24, 0.15, 0.62),
			color,
			true
		)
	end
	ball(ctx, "Center", Vector3.new(0, 0.1, 0), 0.18, peach)
	return float, Vector3.new(0, 0.19, 0)
end

-- Semangka: elipsoid hijau bergaris gelap + irisan semangka merah berkulit di puncaknya.
local function buildWatermelon(ctx: Ctx, colors: { Color3 }): (BasePart, Vector3)
	local green = pick(colors, 1, Color3.fromRGB(60, 150, 70))
	local red = pick(colors, 2, Color3.fromRGB(230, 60, 70))
	local dark = pick(colors, 3, Color3.fromRGB(30, 90, 40))
	local semi = Vector3.new(0.43, 0.4, 0.5)
	local float = ellipsoid(ctx, "Float", CFrame.identity, semi * 2, green, true)
	-- Garis meridian: cakram tebal sedikit lebih besar dari badan, tampak sebagai belang di sisi.
	for i = 1, 3 do
		local a = math.rad((i - 1) * 60)
		local dir = Vector3.new(math.sin(a), 0, math.cos(a))
		local r = 1 / math.sqrt((dir.X / semi.X) ^ 2 + (dir.Z / semi.Z) ^ 2)
		ellipsoid(
			ctx,
			"Stripe" .. i,
			frameZ(Vector3.zero, dir),
			Vector3.new(0.2, semi.Y * 2 * 0.86, r * 2 * 1.06),
			dark
		)
	end
	-- Irisan tegak di puncak: segitiga merah meruncing ke atas (dua setengah wedge), kulit hijau tua + daging
	-- pucat di alasnya, dua biji hitam.
	for _, s in SIDES do
		local tag = if s > 0 then "R" else "L"
		halfSlice(
			ctx,
			"Slice" .. tag,
			Vector3.new(0, 0.84, 0),
			Vector3.new(0, 0.4, 0),
			0.27,
			Vector3.new(s, 0, 0),
			0.1,
			red
		)
		ellipsoid(ctx, "Seed" .. tag, CFrame.new(0.07 * s, 0.56, 0), Vector3.new(0.036, 0.056, 0.12), SEED)
	end
	ellipsoid(ctx, "RindInner", CFrame.new(0, 0.44, 0), Vector3.new(0.56, 0.07, 0.112), RIND_PALE)
	ellipsoid(ctx, "Rind", CFrame.new(0, 0.395, 0), Vector3.new(0.6, 0.09, 0.12), dark)
	return float, Vector3.new(0, 0.86, 0)
end

-- Bola Api: bola Neon oranye berinti kuning + Fire + PointLight.
local function buildFireball(ctx: Ctx, colors: { Color3 }): (BasePart, Vector3)
	local orange = pick(colors, 1, Color3.fromRGB(255, 120, 30))
	local yellow = pick(colors, 2, Color3.fromRGB(255, 220, 90))
	local float = ball(ctx, "Float", Vector3.zero, 0.9, orange, true)
	float.Material = Enum.Material.Neon
	float.Transparency = 0.2
	local core = ball(ctx, "Core", Vector3.zero, 0.6, yellow)
	core.Material = Enum.Material.Neon
	local fire = Instance.new("Fire")
	fire.Name = "Api"
	fire.Size = 2
	fire.Heat = 6
	fire.Color = orange
	fire.SecondaryColor = yellow
	fire.Parent = float
	local light = Instance.new("PointLight")
	light.Name = "Cahaya"
	light.Color = orange:Lerp(yellow, 0.4)
	light.Brightness = 1.6
	light.Range = 10
	light.Shadows = false
	light.Parent = float
	return float, Vector3.new(0, 0.46, 0)
end

-- Karang: dasar membulat dengan cabang silinder merah muda berujung bola persik.
local function buildCoral(ctx: Ctx, colors: { Color3 }): (BasePart, Vector3)
	local pink = pick(colors, 1, Color3.fromRGB(255, 120, 140))
	local peach = pick(colors, 2, Color3.fromRGB(255, 190, 160))
	local float = ellipsoid(ctx, "Float", CFrame.identity, Vector3.new(0.8, 0.5, 0.8), pink, true)
	local branches: { { From: Vector3, To: Vector3, Diameter: number } } = {
		{ From = Vector3.new(0, 0.15, 0), To = Vector3.new(0.02, 0.86, 0.03), Diameter = 0.14 },
		{ From = Vector3.new(0.12, 0.12, 0.05), To = Vector3.new(0.36, 0.62, 0.1), Diameter = 0.12 },
		{ From = Vector3.new(-0.1, 0.12, 0.08), To = Vector3.new(-0.32, 0.56, 0.2), Diameter = 0.11 },
		{ From = Vector3.new(0, 0.12, -0.12), To = Vector3.new(-0.06, 0.6, -0.34), Diameter = 0.11 },
	}
	for i, b in branches do
		cylinder(ctx, "Branch" .. i, b.From, b.To, b.Diameter, shade(pink, 1 + 0.04 * math.sin(i * 1.3)))
		ball(ctx, "Tip" .. i, b.To, b.Diameter * 1.25, peach)
	end
	cylinder(ctx, "Twig", Vector3.new(0.24, 0.37, 0.075), Vector3.new(0.47, 0.5, -0.06), 0.08, pink)
	return float, Vector3.new(0.02, 0.95, 0.03)
end

local BUILDERS: { [string]: StyleBuilder } = {
	RedWhite = buildRedWhite,
	Duck = buildDuck,
	Starfish = buildStarfish,
	Watermelon = buildWatermelon,
	Fireball = buildFireball,
	Coral = buildCoral,
}

-- Membangun pelampung; style nil (atau bukan slot Bobber) → Merah Putih bawaan. Model belum di-parent.
function BobberModel.Build(style: CosmeticDef?): Model
	local styleName = "RedWhite"
	local colors: { Color3 } = DEFAULT_COLORS
	if style and style.Slot == "Bobber" then
		if BUILDERS[style.Style] then
			styleName = style.Style
		end
		colors = style.Colors
	end
	local ctx: Ctx = { Parts = {} }
	local builder: StyleBuilder = BUILDERS[styleName] or buildRedWhite
	local float, linePoint = builder(ctx, colors)
	float.Name = "Float"
	local line = Instance.new("Attachment")
	line.Name = "LineAttachment"
	line.CFrame = CFrame.new(linePoint)
	line.Parent = float

	local model = Instance.new("Model")
	model.Name = "Pelampung"
	for _, part in ctx.Parts do
		part.Parent = model
	end
	model.PrimaryPart = float
	model:SetAttribute("Style", styleName)
	if style then
		model:SetAttribute("CosmeticId", style.Id)
	end
	return model
end

return BobberModel
