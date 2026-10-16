--!strict
-- FishModel: model 3D ikan prosedural dari Config/Fish (species.Shape + warna Primary/Secondary).
-- Dipakai kartu tangkapan (ViewportFrame berputar), Fishdex (siluet), ember NPC, dan ikan yang dipegang.
-- Hanya primitif Roblox: Part Ball/Cylinder, WedgePart, dan SpecialMesh Sphere (elipsoid) tanpa MeshId.
-- Arah visual: stylized tropis membulat (docs/UI-DIRECTION.md) — siluet dari elipsoid, sirip dari wedge tipis.
--
-- Ruang lokal (semua bentuk):
--   • Kepala menghadap LookVector Body (−Z), ekor ke +Z, punggung ke +Y, sisi kanan ikan ke +X.
--   • Panjang moncong–ujung ekor ≈ opts.Length (default 2 stud); kepiting: rentang kaki & capit.
--   • PrimaryPart "Body" = pivot model. Bentuk berantai (Belut, Naga): Body = segmen tengah.
-- Geometri ditulis dalam satuan kanonik (panjang 2) lalu diskalakan Length / 2.
-- Semua part CanCollide/CanQuery/CanTouch = false, Massless = true; detail kecil CastShadow = false.
-- Mutasi Pelangi: tiap part diberi tag "Rainbow" + atribut "RainbowPhase" (hue awal 0..1); klien memutar hue
-- dengan mempertahankan saturasi & kecerahan warna awal (mata tetap terbaca).

local CollectionService = game:GetService("CollectionService")

local Types = require(script.Parent.Parent.Types)

type FishSpecies = Types.FishSpecies
type Mutation = Types.Mutation

export type BuildOptions = {
	Mutation: Types.Mutation?,
	Length: number?,
	Silhouette: boolean?,
	Anchored: boolean?,
}

-- Elipsoid kanonik: pusat & setengah-sumbu.
type Ell = { C: Vector3, R: Vector3 }

type Ctx = {
	Scale: number,
	Origin: Vector3,
	Anchored: boolean,
	Plain: boolean,
	Rng: Random,
	Parts: { BasePart },
	Roles: { [BasePart]: string },
	Canon: { [BasePart]: Vector3 },
	SparkleHosts: { BasePart },
	HueAxis: string,
}

type Palette = {
	Skin: Color3,
	Light: Color3,
	Dark: Color3?,
	Fin: Color3,
	Accent: Color3,
	Mouth: Color3,
}

type Builder = (ctx: Ctx, species: FishSpecies, detail: string?) -> BasePart

local FishModel = {}

local CANON_LENGTH = 2
local FIN_T = 0.03
local SIDES = { 1, -1 }
local UP = Vector3.yAxis
local DOWN = -Vector3.yAxis
local GAZE = Vector3.new(0, 0.05, -0.45)

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local EYE_WHITE = Color3.fromRGB(250, 250, 246)
local PUPIL = Color3.fromRGB(18, 22, 28)
local SILHOUETTE = Color3.fromRGB(11, 36, 45)
local ALBINO_PUPIL = Color3.fromRGB(236, 104, 138)
local BAND_EDGE = Color3.fromRGB(28, 26, 30)
local MANE_RED = Color3.fromRGB(212, 56, 46)
local CRYSTAL_PUPIL = Color3.fromRGB(38, 72, 132)

local RAINBOW_TAG = "Rainbow"
local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

-- Warna mutasi Emas per peran part (Material Metal + Reflectance).
local GOLD: { [string]: Color3 } = {
	Skin = Color3.fromRGB(240, 186, 64),
	Light = Color3.fromRGB(255, 220, 128),
	Dark = Color3.fromRGB(212, 148, 40),
	Fin = Color3.fromRGB(230, 168, 52),
	Pattern = Color3.fromRGB(200, 136, 32),
	Accent = Color3.fromRGB(222, 160, 48),
	Mouth = Color3.fromRGB(168, 108, 30),
	Glow = Color3.fromRGB(255, 228, 150),
	EyeWhite = Color3.fromRGB(255, 238, 186),
	Pupil = Color3.fromRGB(64, 40, 14),
}

-- Detail khas opsional per spesies. Spesies baru tanpa entri tetap memakai bentuk dasar dari Shape.
local DETAIL: { [string]: string } = {
	selar = "Stripe",
	barakuda = "Bars",
	tuna_sirip_kuning = "YellowFins",
	badut = "Bands",
	kerapu_macan = "Spots",
	kerapu_kertang = "Spots",
	coelacanth = "Spots",
	napoleon = "Hump",
	marlin_biru = "Bars",
	layaran = "Sail",
	ikan_pedang = "Sword",
}

-- =========================================================================
-- Geometri
-- =========================================================================

local function E(cx: number, cy: number, cz: number, rx: number, ry: number, rz: number): Ell
	return { C = Vector3.new(cx, cy, cz), R = Vector3.new(rx, ry, rz) }
end

local function sideTag(s: number): string
	return if s > 0 then "R" else "L"
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

-- Jarak permukaan sisi (+X) dari sumbu elipsoid pada ketinggian y dan posisi z.
local function sideX(e: Ell, y: number, z: number): number
	local u = 1 - ((y - e.C.Y) / e.R.Y) ^ 2 - ((z - e.C.Z) / e.R.Z) ^ 2
	return e.R.X * math.sqrt(math.max(u, 0))
end

local function topY(e: Ell, x: number, z: number): number
	local u = 1 - ((x - e.C.X) / e.R.X) ^ 2 - ((z - e.C.Z) / e.R.Z) ^ 2
	return e.C.Y + e.R.Y * math.sqrt(math.max(u, 0))
end

local function normalAt(e: Ell, p: Vector3): Vector3
	local d = p - e.C
	return Vector3.new(d.X / (e.R.X * e.R.X), d.Y / (e.R.Y * e.R.Y), d.Z / (e.R.Z * e.R.Z)).Unit
end

-- Titik permukaan elipsoid pada arah `dir` dari pusatnya.
local function surfaceAlong(e: Ell, dir: Vector3): Vector3
	local q = (dir.X / e.R.X) ^ 2 + (dir.Y / e.R.Y) ^ 2 + (dir.Z / e.R.Z) ^ 2
	return e.C + dir / math.sqrt(q)
end

-- Titik akar sirip di garis punggung (x = 0) gabungan beberapa elipsoid, dibenamkan `sink`.
local function topPoint(list: { Ell }, z: number, sink: number): Vector3
	local y = -math.huge
	for _, e in list do
		if math.abs(z - e.C.Z) < e.R.Z then
			y = math.max(y, topY(e, 0, z))
		end
	end
	return Vector3.new(0, y - sink, z)
end

local function bottomPoint(list: { Ell }, z: number, sink: number): Vector3
	local y = math.huge
	for _, e in list do
		if math.abs(z - e.C.Z) < e.R.Z then
			y = math.min(y, 2 * e.C.Y - topY(e, 0, z))
		end
	end
	return Vector3.new(0, y + sink, z)
end

-- Elipsoid dengan puncak tertinggi pada (x, z).
local function highest(list: { Ell }, x: number, z: number): Ell
	local best = list[1]
	local bestY = -math.huge
	for _, e in list do
		local u = ((x - e.C.X) / e.R.X) ^ 2 + ((z - e.C.Z) / e.R.Z) ^ 2
		if u < 1 then
			local y = topY(e, x, z)
			if y > bestY then
				best, bestY = e, y
			end
		end
	end
	return best
end

-- Penampang gabungan beberapa elipsoid pada posisi z: (pusat y, setengah tinggi, setengah lebar).
local function crossSection(list: { Ell }, z: number): (number, number, number)
	local top, bottom, half = -math.huge, math.huge, 0
	for _, e in list do
		local t = (z - e.C.Z) / e.R.Z
		if math.abs(t) < 1 then
			local f = math.sqrt(1 - t * t)
			top = math.max(top, e.C.Y + e.R.Y * f)
			bottom = math.min(bottom, e.C.Y - e.R.Y * f)
			half = math.max(half, e.R.X * f)
		end
	end
	return (top + bottom) / 2, (top - bottom) / 2, half
end

-- =========================================================================
-- Warna
-- =========================================================================

local function luminance(c: Color3): number
	return 0.2126 * c.R + 0.7152 * c.G + 0.0722 * c.B
end

local function shade(c: Color3, factor: number): Color3
	return Color3.new(math.clamp(c.R * factor, 0, 1), math.clamp(c.G * factor, 0, 1), math.clamp(c.B * factor, 0, 1))
end

-- Variasi kecerahan ±amount, deterministik (Random ber-seed id spesies).
local function vary(ctx: Ctx, c: Color3, amount: number): Color3
	return shade(c, 1 + ctx.Rng:NextNumber(-amount, amount))
end

local function seedOf(id: string): number
	local h = 7
	for i = 1, #id do
		h = (h * 31 + string.byte(id, i)) % 2147483647
	end
	return h
end

-- Countershading: warna lebih gelap di punggung, lebih terang di perut. Bila Secondary dipakai sebagai pola
-- (pita, garis, totol), perut memakai Primary yang dipucatkan.
local function palette(sp: FishSpecies, patternUsesSecondary: boolean): Palette
	local p, s = sp.Primary, sp.Secondary
	local light: Color3
	local dark: Color3? = nil
	if patternUsesSecondary then
		light = p:Lerp(WHITE, 0.55)
	elseif luminance(s) >= luminance(p) then
		light = s
	else
		light = p:Lerp(WHITE, 0.55)
		dark = s
	end
	return {
		Skin = p,
		Light = light,
		Dark = dark,
		Fin = p:Lerp(s, 0.45),
		Accent = s,
		Mouth = p:Lerp(BLACK, 0.45),
	}
end

-- =========================================================================
-- Pembuat part
-- =========================================================================

local function place(
	ctx: Ctx,
	part: BasePart,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	role: string,
	shadow: boolean
): BasePart
	local s = ctx.Scale
	part.Name = name
	part.Size = size * s
	part.CFrame = CFrame.new((cf.Position - ctx.Origin) * s) * cf.Rotation
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Reflectance = 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = ctx.Anchored
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = shadow
	table.insert(ctx.Parts, part)
	ctx.Roles[part] = role
	ctx.Canon[part] = cf.Position
	return part
end

local function newEllipsoidPart(): Part
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Block
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

local function addEll(
	ctx: Ctx,
	name: string,
	e: Ell,
	color: Color3,
	role: string,
	rot: CFrame?,
	shadow: boolean?
): BasePart
	local cf = CFrame.new(e.C)
	if rot then
		cf *= rot
	end
	return place(ctx, newEllipsoidPart(), name, e.R * 2, cf, color, role, shadow == true)
end

-- Elipsoid dengan sumbu Z lokal searah `dir`; semi = setengah-sumbu (X, Y, Z lokal).
local function addEllAlong(
	ctx: Ctx,
	name: string,
	center: Vector3,
	dir: Vector3,
	semi: Vector3,
	color: Color3,
	role: string,
	up: Vector3?,
	shadow: boolean?
): BasePart
	return place(ctx, newEllipsoidPart(), name, semi * 2, frameZ(center, dir, up), color, role, shadow == true)
end

local function addBall(ctx: Ctx, name: string, center: Vector3, diameter: number, color: Color3, role: string): BasePart
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Ball
	return place(ctx, part, name, Vector3.one * diameter, CFrame.new(center), color, role, false)
end

-- Silinder dari a ke b; `overlap` memanjangkan kedua ujung agar sambungan rantai tidak bercelah.
local function addCyl(
	ctx: Ctx,
	name: string,
	a: Vector3,
	b: Vector3,
	diameter: number,
	color: Color3,
	role: string,
	overlap: number?
): BasePart
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Cylinder
	local d = b - a
	local length = d.Magnitude + 2 * (overlap or 0)
	return place(ctx, part, name, Vector3.new(length, diameter, diameter), frameX((a + b) / 2, d), color, role, false)
end

-- Sirip segitiga siku-siku dari WedgePart: tepi dasar p0 (depan) → p1 (belakang), tinggi `height` ke arah `up`.
-- rising = true: sudut tertinggi di p1; false: di p0. Tebal pelat FIN_T.
local function addFin(
	ctx: Ctx,
	name: string,
	p0: Vector3,
	p1: Vector3,
	height: number,
	up: Vector3,
	rising: boolean,
	color: Color3,
	role: string?
): BasePart
	local along = p1 - p0
	local z = along.Unit
	local y = (up - z * up:Dot(z)).Unit
	local cf = CFrame.fromMatrix((p0 + p1) / 2 + y * (height / 2), y:Cross(z), y, z)
	if not rising then
		cf *= CFrame.Angles(0, math.pi, 0)
	end
	local part = Instance.new("WedgePart")
	return place(ctx, part, name, Vector3.new(FIN_T, height, along.Magnitude), cf, color, role or "Fin", false)
end

-- =========================================================================
-- Bagian tubuh bersama
-- =========================================================================

-- Mata: bola putih setengah terbenam + pupil gelap yang menonjol ke arah pandang.
local function addEye(
	ctx: Ctx,
	suffix: string,
	surface: Vector3,
	normal: Vector3,
	diameter: number,
	gaze: Vector3,
	pupilColor: Color3?
)
	local r = diameter / 2
	local center = surface - normal * (r * 0.3)
	addBall(ctx, "Eye" .. suffix, center, diameter, EYE_WHITE, "EyeWhite")
	local pd = diameter * 0.56
	local dir = (normal + gaze).Unit
	addBall(ctx, "Pupil" .. suffix, center + dir * (r - pd * 0.28), pd, pupilColor or PUPIL, "Pupil")
end

local function addSideEyes(ctx: Ctx, e: Ell, y: number, z: number, diameter: number, pupilColor: Color3?)
	local x = sideX(e, y, z)
	for _, s in SIDES do
		local p = Vector3.new(e.C.X + s * x, y, z)
		addEye(ctx, sideTag(s), p, normalAt(e, p), diameter, GAZE, pupilColor)
	end
end

-- Perut terang (dan punggung gelap bila ada) dari elipsoid badan. Mengembalikan daftar kontur luar.
local function addShading(ctx: Ctx, body: Ell, pal: Palette): { Ell }
	local r = body.R
	local belly: Ell =
		{ C = body.C + Vector3.new(0, -0.33 * r.Y, 0), R = Vector3.new(r.X * 0.93, r.Y * 0.8, r.Z * 0.8) }
	addEll(ctx, "Belly", belly, pal.Light, "Light")
	local outline: { Ell } = { body, belly }
	local dark = pal.Dark
	if dark then
		local back: Ell =
			{ C = body.C + Vector3.new(0, 0.33 * r.Y, -0.02), R = Vector3.new(r.X * 0.93, r.Y * 0.8, r.Z * 0.82) }
		addEll(ctx, "Back", back, dark, "Dark")
		table.insert(outline, back)
	end
	return outline
end

-- Ekor bercabang dua lobus; `fork` = sudut bukaan tiap lobus dari garis tengah.
local function addTail(
	ctx: Ctx,
	root: Vector3,
	length: number,
	height: number,
	fork: number,
	color: Color3
): (BasePart, BasePart)
	local c, s = math.cos(fork), math.sin(fork)
	local upper =
		addFin(ctx, "TailUpper", root, root + Vector3.new(0, s, c) * length, height, Vector3.new(0, c, -s), true, color)
	local lower = addFin(
		ctx,
		"TailLower",
		root,
		root + Vector3.new(0, -s, c) * length,
		height,
		Vector3.new(0, -c, -s),
		true,
		color
	)
	return upper, lower
end

local function addPectorals(
	ctx: Ctx,
	e: Ell,
	y: number,
	z: number,
	length: number,
	height: number,
	color: Color3
): { BasePart }
	local x = sideX(e, y, z)
	local fins: { BasePart } = {}
	for _, s in SIDES do
		local p0 = Vector3.new(s * (x - 0.015), y, z)
		local dir = Vector3.new(s * 0.42, -0.32, 0.85).Unit
		table.insert(fins, addFin(ctx, "Pectoral" .. sideTag(s), p0, p0 + dir * length, height, UP, false, color))
	end
	return fins
end

-- Cincin warna melingkari kontur `list` pada posisi z; lebar tampak ≈ width, menonjol `bulge` (1,05 = 5%).
local function addBand(
	ctx: Ctx,
	name: string,
	list: { Ell },
	z: number,
	width: number,
	bulge: number,
	color: Color3,
	role: string
): BasePart
	local cy, semiY, semiX = crossSection(list, z)
	local semiZ = width / (2 * math.sqrt(1 - 1 / (bulge * bulge)))
	return addEll(ctx, name, E(0, cy, z, semiX * bulge, semiY * bulge, semiZ), color, role)
end

-- Totol pipih menempel pada sisi elipsoid (side = 1 kanan, -1 kiri).
local function addSpot(ctx: Ctx, name: string, e: Ell, y: number, z: number, side: number, size: number, color: Color3)
	local p = Vector3.new(e.C.X + side * sideX(e, y, z), y, z)
	local n = normalAt(e, p)
	addEllAlong(ctx, name, p - n * (size * 0.12), n, Vector3.new(size, size * 0.85, size * 0.24), color, "Pattern")
end

-- =========================================================================
-- Bentuk ikan bersirip
-- =========================================================================

-- Ramping: torpedo ramping (kembung, tongkol, tuna, barakuda).
local function buildRamping(ctx: Ctx, sp: FishSpecies, detail: string?): BasePart
	local yellowFins = detail == "YellowFins"
	local pal = palette(sp, detail == "Stripe" or detail == "Bars" or yellowFins)
	if yellowFins then
		pal.Fin = shade(pal.Skin, 0.8)
	end
	local body = E(0, 0, -0.2, 0.18, 0.23, 0.78)
	ctx.Origin = body.C
	local main = addEll(ctx, "Body", body, pal.Skin, "Skin", nil, true)
	local outline = addShading(ctx, body, pal)
	local stalk = E(0, 0, 0.6, 0.045, 0.07, 0.2)
	addEll(ctx, "Stalk", stalk, pal.Skin, "Skin")
	table.insert(outline, stalk)
	addTail(ctx, Vector3.new(0, 0, 0.74), 0.3, 0.25, math.rad(24), pal.Fin)

	local accentFin = if yellowFins then pal.Accent else pal.Fin
	local small = if yellowFins then 0.15 else 0.09
	addFin(ctx, "Dorsal", topPoint(outline, -0.42, 0.03), topPoint(outline, -0.06, 0.03), 0.2, UP, true, pal.Fin)
	addFin(ctx, "Dorsal2", topPoint(outline, 0.14, 0.025), topPoint(outline, 0.33, 0.025), small, UP, false, accentFin)
	addFin(
		ctx,
		"Anal",
		bottomPoint(outline, 0.13, 0.025),
		bottomPoint(outline, 0.33, 0.025),
		small,
		DOWN,
		false,
		accentFin
	)
	if yellowFins then
		addFin(
			ctx,
			"FinletTop",
			topPoint(outline, 0.42, 0.015),
			topPoint(outline, 0.5, 0.015),
			0.05,
			UP,
			false,
			pal.Accent
		)
		addFin(
			ctx,
			"FinletBottom",
			bottomPoint(outline, 0.42, 0.015),
			bottomPoint(outline, 0.5, 0.015),
			0.05,
			DOWN,
			false,
			pal.Accent
		)
	end
	addPectorals(ctx, body, -0.07, -0.52, 0.22, 0.1, accentFin)
	addSideEyes(ctx, body, 0.055, -0.78, 0.115)
	addEll(ctx, "Mouth", E(0, -0.035, -0.965, 0.05, 0.016, 0.03), pal.Mouth, "Mouth")

	if detail == "Stripe" then
		-- Selar: garis kuning memanjang di sisi badan.
		addEll(ctx, "Stripe", E(0, 0.02, -0.18, 0.1935, 0.085, 0.8), pal.Accent, "Pattern")
	elseif detail == "Bars" then
		-- Barakuda: belang gelap melintang.
		for i, z in { -0.42, -0.2, 0.02, 0.22 } do
			addBand(ctx, "Bar" .. i, outline, z, 0.05, 1.05, pal.Accent, "Pattern")
		end
	end
	return main
end

-- Gemuk: badan dalam/tinggi berkepala tumpul (kerapu, kakap, badut, napoleon berjidat).
local function buildGemuk(ctx: Ctx, sp: FishSpecies, detail: string?): BasePart
	local pal = palette(sp, detail == "Bands" or detail == "Spots")
	local body = E(0, 0, -0.16, 0.21, 0.36, 0.66)
	local head = E(0, 0.03, -0.55, 0.195, 0.29, 0.37)
	ctx.Origin = body.C
	local main = addEll(ctx, "Body", body, pal.Skin, "Skin", nil, true)
	addEll(ctx, "Head", head, pal.Skin, "Skin", nil, true)
	local outline = addShading(ctx, body, pal)
	table.insert(outline, head)
	local stalk = E(0, 0, 0.5, 0.06, 0.12, 0.2)
	addEll(ctx, "Stalk", stalk, pal.Skin, "Skin")
	table.insert(outline, stalk)

	local hump = detail == "Hump"
	local lips = if hump then E(0, -0.1, -0.9, 0.095, 0.066, 0.085) else E(0, -0.1, -0.9, 0.075, 0.05, 0.065)
	addEll(ctx, "Lips", lips, pal.Mouth, "Mouth")
	local dorsalStart = -0.5
	if hump then
		-- Napoleon: jidat menonjol.
		local bump = E(0, 0.26, -0.52, 0.15, 0.14, 0.21)
		addEll(ctx, "Hump", bump, pal.Skin, "Skin", nil, true)
		table.insert(outline, bump)
		dorsalStart = -0.3
	end

	addTail(ctx, Vector3.new(0, 0, 0.62), 0.36, 0.3, math.rad(8), pal.Fin)
	local peak = topPoint(outline, 0.1, 0.03)
	addFin(ctx, "Dorsal", topPoint(outline, dorsalStart, 0.03), peak, 0.17, UP, true, pal.Fin)
	addFin(ctx, "Dorsal2", peak, topPoint(outline, 0.42, 0.03), 0.17, UP, false, pal.Fin)
	addFin(ctx, "Anal", bottomPoint(outline, 0.12, 0.03), bottomPoint(outline, 0.4, 0.03), 0.14, DOWN, false, pal.Fin)
	addPectorals(ctx, body, -0.08, -0.4, 0.26, 0.13, pal.Fin)
	addSideEyes(ctx, head, 0.1, -0.68, 0.13)

	if detail == "Bands" then
		-- Ikan badut: tiga pita putih bertepi gelap.
		for i, z in { -0.5, -0.12, 0.3 } do
			addBand(ctx, "BandEdge" .. i, outline, z, 0.12, 1.045, BAND_EDGE, "Pattern")
			addBand(ctx, "Band" .. i, outline, z, 0.09, 1.09, pal.Accent, "Pattern")
		end
	elseif detail == "Spots" then
		-- Kerapu & coelacanth: totol di kedua sisi.
		for i, yz in { Vector2.new(0.17, -0.3), Vector2.new(0, -0.1), Vector2.new(0.16, 0.1) } do
			for _, s in SIDES do
				addSpot(ctx, "Spot" .. i .. sideTag(s), body, yz.X, yz.Y, s, 0.065, pal.Accent)
			end
		end
	end
	return main
end

-- Paruh: marlin, layaran (sirip punggung layar), ikan pedang (pedang pipih lebar).
local function buildParuh(ctx: Ctx, sp: FishSpecies, detail: string?): BasePart
	local pal = palette(sp, detail == "Bars")
	local body = E(0, 0, -0.02, 0.15, 0.21, 0.62)
	ctx.Origin = body.C
	local main = addEll(ctx, "Body", body, pal.Skin, "Skin", nil, true)
	local outline = addShading(ctx, body, pal)
	local stalk = E(0, 0, 0.62, 0.035, 0.055, 0.18)
	addEll(ctx, "Stalk", stalk, pal.Skin, "Skin")
	table.insert(outline, stalk)
	local bill = if detail == "Sword"
		then E(0, -0.005, -0.72, 0.055, 0.016, 0.3)
		else E(0, -0.015, -0.73, 0.022, 0.026, 0.27)
	addEll(ctx, "Bill", bill, shade(pal.Skin, 0.85), "Skin")
	addTail(ctx, Vector3.new(0, 0, 0.72), 0.28, 0.3, math.rad(32), pal.Fin)

	if detail == "Sail" then
		addEll(ctx, "Sail", E(0, 0.17, -0.06, 0.012, 0.34, 0.44), pal.Accent, "Fin")
		for i, p in { Vector3.new(0, 0.36, -0.2), Vector3.new(0, 0.4, 0.02), Vector3.new(0, 0.3, 0.2) } do
			addBall(ctx, "SailSpot" .. i, p, 0.05, shade(pal.Skin, 0.6), "Pattern")
		end
	elseif detail == "Sword" then
		addFin(ctx, "Dorsal", topPoint(outline, -0.42, 0.025), topPoint(outline, -0.2, 0.025), 0.26, UP, true, pal.Fin)
	else
		addFin(ctx, "Dorsal", topPoint(outline, -0.44, 0.025), topPoint(outline, 0.22, 0.025), 0.24, UP, false, pal.Fin)
	end
	addFin(ctx, "Anal", bottomPoint(outline, 0.24, 0.02), bottomPoint(outline, 0.42, 0.02), 0.08, DOWN, false, pal.Fin)
	addPectorals(ctx, body, -0.08, -0.38, 0.3, 0.07, pal.Fin)
	addSideEyes(ctx, body, 0.045, -0.5, 0.1)

	if detail == "Bars" then
		for i, z in { -0.22, 0.02, 0.26 } do
			addBand(ctx, "Bar" .. i, outline, z, 0.05, 1.05, pal.Accent, "Pattern")
		end
	end
	return main
end

-- Kristal: badan Glass bening berkilau dengan inti Neon lembut dan PointLight.
local function buildKristal(ctx: Ctx, sp: FishSpecies, _detail: string?): BasePart
	local glass, glow = sp.Primary, sp.Secondary
	local body = E(0, 0, -0.12, 0.22, 0.38, 0.74)
	ctx.Origin = body.C
	local main = addEll(ctx, "Body", body, glass, "Skin", nil, true)
	local core = addEll(ctx, "Core", E(0, 0.01, -0.16, 0.1, 0.17, 0.4), glow, "Glow")
	core.Material = Enum.Material.Neon
	core.Transparency = 0.35
	local stalk = E(0, 0, 0.6, 0.06, 0.1, 0.2)
	local outline: { Ell } = { body, stalk }
	local crystal: { BasePart } = { main, addEll(ctx, "Stalk", stalk, glass, "Skin") }
	local upper, lower = addTail(ctx, Vector3.new(0, 0, 0.72), 0.3, 0.3, math.rad(18), glow)
	table.insert(crystal, upper)
	table.insert(crystal, lower)
	-- Pecahan kristal di punggung.
	table.insert(
		crystal,
		addFin(ctx, "Shard1", topPoint(outline, -0.46, 0.04), topPoint(outline, -0.3, 0.04), 0.22, UP, true, glow)
	)
	table.insert(
		crystal,
		addFin(ctx, "Shard2", topPoint(outline, -0.22, 0.04), topPoint(outline, -0.02, 0.04), 0.3, UP, true, glow)
	)
	table.insert(
		crystal,
		addFin(ctx, "Shard3", topPoint(outline, 0.08, 0.04), topPoint(outline, 0.24, 0.04), 0.2, UP, true, glow)
	)
	table.insert(
		crystal,
		addFin(ctx, "Anal", bottomPoint(outline, 0.1, 0.03), bottomPoint(outline, 0.36, 0.03), 0.13, DOWN, false, glow)
	)
	for _, fin in addPectorals(ctx, body, -0.1, -0.42, 0.24, 0.12, glow) do
		table.insert(crystal, fin)
	end
	for _, part in crystal do
		part.Material = Enum.Material.Glass
		part.Transparency = if part == main then 0.32 else 0.18
		part.Reflectance = 0.3
	end
	addSideEyes(ctx, body, 0.1, -0.66, 0.12, CRYSTAL_PUPIL)
	if not ctx.Plain then
		local light = Instance.new("PointLight")
		light.Name = "CahayaBulan"
		light.Color = glass:Lerp(glow, 0.5)
		light.Brightness = 0.9
		light.Range = 7 * ctx.Scale
		light.Shadows = false
		light.Parent = main
	end
	return main
end

-- =========================================================================
-- Bentuk khusus
-- =========================================================================

-- Pipih: pari — cakram lebar pipih, kepala menonjol, ekor cambuk, totol di punggung.
local function buildPipih(ctx: Ctx, sp: FishSpecies, _detail: string?): BasePart
	local pal = palette(sp, true)
	local disc = E(0, 0, -0.45, 0.74, 0.075, 0.42)
	local hump = E(0, 0.025, -0.47, 0.21, 0.1, 0.33)
	local head = E(0, 0.01, -0.82, 0.13, 0.065, 0.12)
	ctx.Origin = disc.C
	local main = addEll(ctx, "Body", disc, pal.Skin, "Skin", nil, true)
	addEll(ctx, "Hump", hump, pal.Skin, "Skin", nil, true)
	addEll(ctx, "Head", head, pal.Skin, "Skin", nil, true)
	local top: { Ell } = { disc, hump, head }

	for _, s in SIDES do
		local x, z = 0.12 * s, -0.72
		local e = highest(top, x, z)
		local p = Vector3.new(x, topY(e, x, z), z)
		addEye(ctx, sideTag(s), p, (normalAt(e, p) + Vector3.new(0.6 * s, 0, 0)).Unit, 0.075, Vector3.new(0, 0, -0.3))
	end

	-- Ekor cambuk melengkung tipis.
	local tail = {
		Vector3.new(0, 0.005, -0.08),
		Vector3.new(0, 0.015, 0.3),
		Vector3.new(0.025, 0.025, 0.66),
		Vector3.new(0.06, 0.035, 1),
	}
	local tailD = { 0.06, 0.038, 0.02 }
	local tailColor = shade(pal.Skin, 0.85)
	for i = 1, 3 do
		addCyl(ctx, "Tail" .. i, tail[i], tail[i + 1], tailD[i], tailColor, "Skin", 0.012)
	end
	addFin(ctx, "Dorsal", Vector3.new(0, 0.02, -0.02), Vector3.new(0, 0.025, 0.1), 0.07, UP, false, pal.Fin)
	for _, s in SIDES do
		addEll(ctx, "Pelvic" .. sideTag(s), E(0.1 * s, -0.005, -0.06, 0.07, 0.018, 0.075), pal.Skin, "Skin")
	end

	-- Totol putih di punggung (pari totol).
	for i, xz in
		{ Vector2.new(0.42, -0.5), Vector2.new(0.27, -0.28), Vector2.new(0.56, -0.38), Vector2.new(0.24, -0.66) }
	do
		for _, s in SIDES do
			local x, z = xz.X * s, xz.Y
			local e = highest(top, x, z)
			local p = Vector3.new(x, topY(e, x, z), z)
			local n = normalAt(e, p)
			addEllAlong(
				ctx,
				"Spot" .. i .. sideTag(s),
				p - n * 0.004,
				n,
				Vector3.new(0.04, 0.034, 0.012),
				pal.Accent,
				"Pattern"
			)
		end
	end
	return main
end

-- Kepiting: karapas lebar, duri samping, sepasang capit, tiga pasang kaki jalan + kaki dayung.
local function buildKepiting(ctx: Ctx, sp: FishSpecies, _detail: string?): BasePart
	local pal = palette(sp, false)
	ctx.HueAxis = "X"
	local shell = E(0, 0.1, 0, 0.5, 0.15, 0.33)
	ctx.Origin = shell.C
	local main = addEll(ctx, "Body", shell, pal.Skin, "Skin", nil, true)
	addEll(ctx, "Belly", E(0, 0.04, 0.01, 0.44, 0.11, 0.3), pal.Light, "Light")
	local legColor = pal.Skin:Lerp(pal.Light, 0.2)
	local tipColor = pal.Skin:Lerp(BLACK, 0.35)
	for _, s in SIDES do
		local tag = sideTag(s)
		addEllAlong(
			ctx,
			"Spine" .. tag,
			Vector3.new(0.53 * s, 0.1, -0.05),
			Vector3.new(s, 0, -0.12),
			Vector3.new(0.03, 0.026, 0.1),
			pal.Skin,
			"Skin"
		)
		local shoulder = Vector3.new(0.3 * s, 0.08, -0.22)
		local wrist = Vector3.new(0.52 * s, 0.12, -0.5)
		local arm = wrist - shoulder
		addEllAlong(
			ctx,
			"Arm" .. tag,
			(shoulder + wrist) / 2,
			arm,
			Vector3.new(0.065, 0.06, arm.Magnitude / 2 + 0.04),
			pal.Skin,
			"Skin"
		)
		local clawDir = Vector3.new(-0.32 * s, 0.04, -1).Unit
		local palm = Vector3.new(0.6 * s, 0.14, -0.66)
		addEllAlong(ctx, "Claw" .. tag, palm, clawDir, Vector3.new(0.11, 0.1, 0.17), pal.Skin, "Skin", nil, true)
		local fingerDir = (clawDir + Vector3.new(0, 0.42, 0)).Unit
		addEllAlong(
			ctx,
			"Pincer" .. tag,
			palm + clawDir * 0.1 + Vector3.new(0, 0.07, 0),
			fingerDir,
			Vector3.new(0.035, 0.03, 0.11),
			tipColor,
			"Accent"
		)
		for i, z in { -0.12, 0.04, 0.19 } do
			local a = Vector3.new(0.36 * s, 0.06, z)
			local b = Vector3.new(0.8 * s, -0.12, z + 0.1)
			addEllAlong(
				ctx,
				"Leg" .. i .. tag,
				(a + b) / 2,
				b - a,
				Vector3.new(0.035, 0.035, (b - a).Magnitude / 2 + 0.02),
				legColor,
				"Fin"
			)
		end
		addEllAlong(
			ctx,
			"Paddle" .. tag,
			Vector3.new(0.56 * s, 0.03, 0.3),
			Vector3.new(0.8 * s, 0, 0.6),
			Vector3.new(0.075, 0.022, 0.13),
			legColor,
			"Fin"
		)
		local ex, ez = 0.13 * s, -0.26
		local p = Vector3.new(ex, topY(shell, ex, ez) + 0.035, ez)
		addEye(ctx, tag, p, Vector3.new(0.3 * s, 0.6, -0.75).Unit, 0.11, Vector3.new(0, 0, -0.2))
	end
	return main
end

-- Cumi: mantel (ujung ke depan), sirip segitiga di ujung mantel, kepala bermata besar, lengan & dua tentakel.
local function buildCumi(ctx: Ctx, sp: FishSpecies, _detail: string?): BasePart
	local pal = palette(sp, true)
	local mantle = E(0, 0, -0.38, 0.17, 0.17, 0.56)
	ctx.Origin = mantle.C
	local main = addEll(ctx, "Body", mantle, pal.Skin, "Skin", nil, true)
	local finColor = pal.Skin:Lerp(pal.Accent, 0.25)
	for _, s in SIDES do
		addFin(
			ctx,
			"Fin" .. sideTag(s),
			Vector3.new(0.05 * s, 0, -0.9),
			Vector3.new(0.15 * s, 0, -0.5),
			0.2,
			Vector3.new(s, 0, 0),
			true,
			finColor
		)
	end
	local head = E(0, -0.01, 0.27, 0.14, 0.14, 0.14)
	addEll(ctx, "Head", head, pal.Skin, "Skin", nil, true)
	addSideEyes(ctx, head, 0.02, 0.25, 0.13)

	for i = 1, 6 do
		local a = math.rad(30 + (i - 1) * 60)
		local base = Vector3.new(0.06 * math.cos(a), -0.01 + 0.06 * math.sin(a), 0.36)
		local tip = Vector3.new(0.17 * math.cos(a), -0.01 + 0.14 * math.sin(a), 0.88)
		local d = tip - base
		addEllAlong(
			ctx,
			"Arm" .. i,
			(base + tip) / 2,
			d,
			Vector3.new(0.034, 0.034, d.Magnitude / 2 + 0.03),
			pal.Skin,
			"Skin"
		)
	end
	local clubColor = pal.Skin:Lerp(pal.Accent, 0.3)
	for _, s in SIDES do
		local tag = sideTag(s)
		local a = Vector3.new(0.035 * s, -0.04, 0.36)
		local b = Vector3.new(0.07 * s, -0.085, 0.9)
		addCyl(ctx, "Tentacle" .. tag, a, b, 0.024, pal.Skin, "Skin")
		addEllAlong(
			ctx,
			"Club" .. tag,
			b + (b - a).Unit * 0.04,
			b - a,
			Vector3.new(0.032, 0.026, 0.07),
			clubColor,
			"Skin"
		)
	end

	-- Bintik kromatofor di mantel (sudut keliling, posisi z).
	for i, az in { Vector2.new(90, -0.6), Vector2.new(45, -0.3), Vector2.new(135, -0.3), Vector2.new(90, -0.05) } do
		local ang = math.rad(az.X)
		local p = surfaceAlong(
			mantle,
			Vector3.new(math.cos(ang), math.sin(ang), 0) * 0.17 + Vector3.new(0, 0, az.Y - mantle.C.Z)
		)
		local n = normalAt(mantle, p)
		addEllAlong(ctx, "Spot" .. i, p - n * 0.004, n, Vector3.new(0.04, 0.034, 0.012), pal.Accent, "Pattern")
	end
	return main
end

-- Lobster: karapas + perut bersegmen melengkung, kipas ekor, antena panjang, sepasang capit, kaki.
local function buildLobster(ctx: Ctx, sp: FishSpecies, _detail: string?): BasePart
	local pal = palette(sp, false)
	local shell = E(0, 0.02, -0.32, 0.19, 0.17, 0.34)
	ctx.Origin = shell.C
	local main = addEll(ctx, "Body", shell, pal.Skin, "Skin", nil, true)
	local banded = pal.Skin:Lerp(pal.Accent, 0.35)
	local pale = pal.Skin:Lerp(pal.Accent, 0.6)
	local centers = {
		Vector3.new(0, 0, 0.1),
		Vector3.new(0, -0.015, 0.27),
		Vector3.new(0, -0.035, 0.42),
		Vector3.new(0, -0.06, 0.55),
	}
	local semis = {
		Vector3.new(0.17, 0.145, 0.11),
		Vector3.new(0.155, 0.13, 0.1),
		Vector3.new(0.135, 0.115, 0.09),
		Vector3.new(0.115, 0.095, 0.08),
	}
	for i = 1, 4 do
		local color = if i % 2 == 1 then banded else pal.Skin
		addEll(
			ctx,
			"Segment" .. i,
			{ C = centers[i], R = semis[i] },
			vary(ctx, color, 0.03),
			"Skin",
			CFrame.Angles(math.rad(5 * i), 0, 0),
			true
		)
	end
	local fanColor = pal.Skin:Lerp(pal.Accent, 0.5)
	local tilt = CFrame.Angles(math.rad(25), 0, 0)
	addEll(ctx, "Telson", E(0, -0.09, 0.72, 0.06, 0.018, 0.12), fanColor, "Fin", tilt)
	for _, s in SIDES do
		local tag = sideTag(s)
		addEll(
			ctx,
			"Uropod" .. tag,
			E(0.1 * s, -0.085, 0.69, 0.055, 0.016, 0.11),
			fanColor,
			"Fin",
			CFrame.Angles(0, math.rad(30 * s), 0) * tilt
		)
		addCyl(
			ctx,
			"Antenna" .. tag,
			Vector3.new(0.08 * s, 0.1, -0.6),
			Vector3.new(0.3 * s, 0.52, -0.98),
			0.035,
			pale,
			"Fin"
		)
		local shoulder = Vector3.new(0.14 * s, -0.03, -0.55)
		local wrist = Vector3.new(0.25 * s, -0.01, -0.79)
		local arm = wrist - shoulder
		addEllAlong(
			ctx,
			"Arm" .. tag,
			(shoulder + wrist) / 2,
			arm,
			Vector3.new(0.045, 0.045, arm.Magnitude / 2 + 0.03),
			pal.Skin,
			"Skin"
		)
		local clawDir = Vector3.new(-0.12 * s, 0.02, -1).Unit
		local palm = Vector3.new(0.28 * s, 0, -0.88)
		addEllAlong(ctx, "Claw" .. tag, palm, clawDir, Vector3.new(0.075, 0.06, 0.12), banded, "Skin", nil, true)
		addEllAlong(
			ctx,
			"Pincer" .. tag,
			palm + clawDir * 0.07 + Vector3.new(0, 0.045, 0),
			(clawDir + Vector3.new(0, 0.35, 0)).Unit,
			Vector3.new(0.026, 0.022, 0.08),
			shade(pal.Skin, 0.7),
			"Accent"
		)
		for i, z in { -0.4, -0.22 } do
			local a = Vector3.new(0.15 * s, -0.08, z)
			local b = Vector3.new(0.36 * s, -0.22, z + 0.07)
			addEllAlong(
				ctx,
				"Leg" .. i .. tag,
				(a + b) / 2,
				b - a,
				Vector3.new(0.025, 0.025, (b - a).Magnitude / 2 + 0.02),
				pale,
				"Fin"
			)
		end
		local ex, ez = 0.08 * s, -0.58
		local p = Vector3.new(ex, topY(shell, ex, ez) + 0.02, ez)
		addEye(ctx, tag, p, Vector3.new(0.4 * s, 0.6, -0.7).Unit, 0.07, Vector3.new(0, 0, -0.2))
	end
	return main
end

local function eelPoint(s: number): Vector3
	return Vector3.new(
		0.05 * math.sin(2 * math.pi * 0.9 * s),
		0.06 * math.sin(2 * math.pi * 1.3 * s + 0.4),
		-0.72 + 1.68 * s
	)
end

-- Belut: badan panjang dari rantai segmen bergelombang + sirip pita sambung punggung–perut.
local function buildBelut(ctx: Ctx, sp: FishSpecies, _detail: string?): BasePart
	local pal = palette(sp, false)
	local count = 9
	local mid = 5
	ctx.Origin = eelPoint((mid - 0.5) / count)
	local segments: { BasePart } = {}
	for k = 1, count do
		local sc = (k - 0.5) / count
		local a, b = eelPoint((k - 1) / count), eelPoint(k / count)
		local r = 0.1 * (1 - 0.68 * sc ^ 1.15)
		local len = (b - a).Magnitude
		local name = if k == mid then "Body" else "Segment" .. k
		-- Tumpang-tindih besar antarsegmen agar badan licin (bukan rantai manik); variasi warna halus ±2%.
		segments[k] = addEllAlong(
			ctx,
			name,
			eelPoint(sc),
			b - a,
			Vector3.new(r, r * 0.92, len * 0.88),
			vary(ctx, pal.Skin, 0.02),
			"Skin",
			nil,
			true
		)
		if k >= 4 and k <= 8 then
			-- Sirip pita sambung punggung–perut.
			addEllAlong(
				ctx,
				"Ribbon" .. k,
				eelPoint(sc),
				b - a,
				Vector3.new(0.008, r * 1.9 + 0.012, len * 0.85),
				pal.Fin,
				"Fin"
			)
		end
	end
	local p0 = eelPoint(0)
	local head = E(p0.X, p0.Y + 0.005, p0.Z - 0.1, 0.1, 0.082, 0.17)
	local headPart = addEll(ctx, "Head", head, pal.Skin, "Skin", nil, true)
	addEll(ctx, "Jaw", E(p0.X, p0.Y - 0.04, p0.Z - 0.12, 0.085, 0.048, 0.15), pal.Light, "Light")
	addSideEyes(ctx, head, head.C.Y + 0.03, head.C.Z - 0.11, 0.055)
	for _, s in SIDES do
		local root = Vector3.new(p0.X + 0.075 * s, p0.Y - 0.02, p0.Z + 0.02)
		addFin(
			ctx,
			"Pectoral" .. sideTag(s),
			root,
			root + Vector3.new(0.45 * s, -0.2, 0.87).Unit * 0.1,
			0.06,
			UP,
			false,
			pal.Fin
		)
	end
	local tailEnd = eelPoint(1)
	local tailDir = tailEnd - eelPoint(0.96)
	addEllAlong(ctx, "TailFin", tailEnd + tailDir.Unit * 0.04, tailDir, Vector3.new(0.008, 0.075, 0.11), pal.Fin, "Fin")
	ctx.SparkleHosts = { headPart, segments[mid], segments[count - 1] }
	return segments[mid]
end

local function dragonPoint(s: number): Vector3
	local y = 0.15 * math.sin(2 * math.pi * 1.1 * s + 0.3) * (0.55 + 0.45 * s)
	return Vector3.new(0.09 * math.sin(2 * math.pi * 0.75 * s + 1.1), y, -0.55 + 1.5 * s)
end

local function dragonRadius(s: number): number
	return 0.13 * (1 - 0.7 * s)
end

-- Naga: badan ular laut bersegmen, kepala bertanduk, surai merah, kumis emas, sirip ekor api.
local function buildNaga(ctx: Ctx, sp: FishSpecies, _detail: string?): BasePart
	local pal = palette(sp, true)
	local belly = pal.Skin:Lerp(pal.Accent, 0.35)
	local count = 7
	local mid = 4
	ctx.Origin = dragonPoint((mid - 0.5) / count)
	local segments: { BasePart } = {}
	for k = 1, count do
		local sc = (k - 0.5) / count
		local a, b = dragonPoint((k - 1) / count), dragonPoint(k / count)
		local r = dragonRadius(sc)
		local name = if k == mid then "Body" else "Segment" .. k
		segments[k] = addEllAlong(
			ctx,
			name,
			dragonPoint(sc),
			b - a,
			Vector3.new(r, r * 0.94, (b - a).Magnitude * 0.68),
			vary(ctx, pal.Skin, 0.04),
			"Skin",
			nil,
			true
		)
	end

	local n = dragonPoint(0)
	local cranium = E(n.X, n.Y + 0.05, n.Z - 0.12, 0.12, 0.105, 0.14)
	local craniumPart = addEll(ctx, "Head", cranium, pal.Skin, "Skin", nil, true)
	addEll(ctx, "Snout", E(n.X, n.Y, n.Z - 0.3, 0.08, 0.068, 0.15), pal.Skin, "Skin", nil, true)
	addEll(
		ctx,
		"Jaw",
		E(n.X, n.Y - 0.065, n.Z - 0.25, 0.07, 0.034, 0.14),
		belly,
		"Light",
		CFrame.Angles(math.rad(-9), 0, 0)
	)
	addSideEyes(ctx, cranium, cranium.C.Y + 0.03, cranium.C.Z - 0.05, 0.07)
	for _, s in SIDES do
		local tag = sideTag(s)
		local hornStart = n + Vector3.new(0.06 * s, 0.13, -0.1)
		local hornDir = Vector3.new(0.22 * s, 0.6, 0.77).Unit
		addEllAlong(
			ctx,
			"Horn" .. tag,
			hornStart + hornDir * 0.13,
			hornDir,
			Vector3.new(0.026, 0.026, 0.15),
			pal.Accent,
			"Accent"
		)
		addEllAlong(
			ctx,
			"Mane" .. tag,
			n + Vector3.new(0.11 * s, 0, -0.05),
			Vector3.new(0.55 * s, 0.2, 0.81),
			Vector3.new(0.015, 0.085, 0.16),
			MANE_RED,
			"Accent"
		)
		addCyl(
			ctx,
			"Whisker" .. tag,
			n + Vector3.new(0.07 * s, -0.01, -0.4),
			n + Vector3.new(0.3 * s, -0.13, -0.17),
			0.018,
			pal.Accent,
			"Accent"
		)
	end
	for i, s in { 0.05, 0.17 } do
		local p = dragonPoint(s) + Vector3.new(0, dragonRadius(s) * 0.85 + 0.03, 0)
		addEllAlong(ctx, "Crest" .. i, p, Vector3.new(0, 0.7, 0.71), Vector3.new(0.014, 0.07, 0.14), MANE_RED, "Accent")
	end
	local tailEnd = dragonPoint(1)
	local tailDir = tailEnd - dragonPoint(0.95)
	addEllAlong(
		ctx,
		"TailFin",
		tailEnd + tailDir.Unit * 0.06,
		tailDir,
		Vector3.new(0.012, 0.11, 0.13),
		MANE_RED,
		"Accent"
	)
	ctx.SparkleHosts = { craniumPart, segments[mid], segments[count - 1] }
	return segments[mid]
end

local BUILDERS: { [string]: Builder } = {
	Ramping = buildRamping,
	Gemuk = buildGemuk,
	Pipih = buildPipih,
	Belut = buildBelut,
	Paruh = buildParuh,
	Kepiting = buildKepiting,
	Cumi = buildCumi,
	Lobster = buildLobster,
	Naga = buildNaga,
	Kristal = buildKristal,
}

-- =========================================================================
-- Mutasi & siluet
-- =========================================================================

local function applySilhouette(ctx: Ctx)
	for _, part in ctx.Parts do
		part.Color = SILHOUETTE
		part.Material = Enum.Material.SmoothPlastic
		part.Reflectance = 0
		part.Transparency = 0
	end
end

local function applyAlbino(ctx: Ctx)
	for _, part in ctx.Parts do
		local role = ctx.Roles[part]
		if role == "Pupil" then
			part.Color = ALBINO_PUPIL
		elseif role ~= "EyeWhite" then
			part.Color = part.Color:Lerp(WHITE, if role == "Pattern" or role == "Accent" then 0.68 else 0.82)
		end
	end
end

local function applyGold(ctx: Ctx)
	for _, part in ctx.Parts do
		local role = ctx.Roles[part]
		local base = GOLD[role] or GOLD.Skin
		part.Material = Enum.Material.Metal
		part.Transparency = 0
		part.Color = if role == "Pupil" or role == "EyeWhite" then base else vary(ctx, base, 0.03)
		part.Reflectance = if role == "Pupil" then 0.1 else 0.32
		for _, child in part:GetChildren() do
			if child:IsA("PointLight") then
				child.Color = GOLD.Glow
			end
		end
	end
end

-- Gradien pelangi sepanjang sumbu badan; S & V per peran agar mata tetap terbaca saat hue diputar klien.
local function applyRainbow(ctx: Ctx)
	local lo, hi = math.huge, -math.huge
	for _, part in ctx.Parts do
		local p = ctx.Canon[part]
		local v = if ctx.HueAxis == "X" then p.X else p.Z
		lo = math.min(lo, v)
		hi = math.max(hi, v)
	end
	local span = math.max(hi - lo, 0.001)
	for _, part in ctx.Parts do
		local p = ctx.Canon[part]
		local v = if ctx.HueAxis == "X" then p.X else p.Z
		local hue = (v - lo) / span * 0.85
		local role = ctx.Roles[part]
		local sat, val = 0.62, 1
		if role == "EyeWhite" then
			sat, val = 0.08, 1
		elseif role == "Pupil" then
			sat, val = 0.5, 0.22
		elseif role == "Light" or role == "Glow" then
			sat, val = 0.38, 1
		elseif role == "Pattern" or role == "Dark" or role == "Mouth" then
			sat, val = 0.78, 0.86
		end
		part.Color = Color3.fromHSV(hue, sat, val)
		part.Reflectance = math.max(part.Reflectance, 0.06)
		part:SetAttribute("RainbowPhase", hue)
		CollectionService:AddTag(part, RAINBOW_TAG)
	end
end

local function applySparkle(ctx: Ctx)
	for _, part in ctx.Parts do
		local role = ctx.Roles[part]
		if role ~= "Pupil" and role ~= "EyeWhite" then
			part.Reflectance = math.max(part.Reflectance, 0.18)
		end
	end
	local s = ctx.Scale
	local rate = 9 / math.max(#ctx.SparkleHosts, 1)
	for _, host in ctx.SparkleHosts do
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "Kilau"
		emitter.Texture = SPARKLE_TEXTURE
		emitter.Rate = rate
		emitter.Lifetime = NumberRange.new(0.6, 1.1)
		emitter.Speed = NumberRange.new(0.15 * s, 0.5 * s)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Rotation = NumberRange.new(0, 360)
		emitter.RotSpeed = NumberRange.new(-90, 90)
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.35, 0.22 * s),
			NumberSequenceKeypoint.new(1, 0),
		})
		emitter.Transparency = NumberSequence.new(0.1, 0.6)
		emitter.Color = ColorSequence.new(Color3.fromRGB(255, 248, 210), Color3.fromRGB(255, 224, 130))
		emitter.LightEmission = 1
		emitter.LightInfluence = 0
		emitter.Parent = host
	end
end

-- =========================================================================
-- API
-- =========================================================================

-- Membangun model ikan. Model belum di-parent; pemanggil menaruhnya (Parent paling akhir).
function FishModel.Build(species: FishSpecies, opts: BuildOptions?): Model
	local length = CANON_LENGTH
	local mutation: Mutation = "None"
	local silhouette = false
	local anchored = true
	if opts then
		local l = opts.Length
		if l ~= nil and l == l and l > 0 then
			length = math.clamp(l, 0.2, 60)
		end
		local m = opts.Mutation
		if m ~= nil then
			mutation = m
		end
		silhouette = opts.Silhouette == true
		anchored = opts.Anchored ~= false
	end

	local ctx: Ctx = {
		Scale = length / CANON_LENGTH,
		Origin = Vector3.zero,
		Anchored = anchored,
		Plain = silhouette,
		Rng = Random.new(seedOf(species.Id)),
		Parts = {},
		Roles = {},
		Canon = {},
		SparkleHosts = {},
		HueAxis = "Z",
	}
	local builder: Builder = BUILDERS[species.Shape] or buildRamping
	local body = builder(ctx, species, DETAIL[species.Id])
	body.Name = "Body"
	if #ctx.SparkleHosts == 0 then
		table.insert(ctx.SparkleHosts, body)
	end

	if silhouette then
		applySilhouette(ctx)
	elseif mutation == "Albino" then
		applyAlbino(ctx)
	elseif mutation == "Emas" then
		applyGold(ctx)
	elseif mutation == "Pelangi" then
		applyRainbow(ctx)
	elseif mutation == "Berkilau" then
		applySparkle(ctx)
	end

	local model = Instance.new("Model")
	model.Name = species.Id
	for _, part in ctx.Parts do
		if not anchored and part ~= body then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = body
			weld.Part1 = part
			weld.Parent = part
		end
		part.Parent = model
	end
	model.PrimaryPart = body
	model:SetAttribute("SpeciesId", species.Id)
	model:SetAttribute("Mutation", if silhouette then "None" else mutation)
	return model
end

-- Panjang tampilan (stud) dari berat relatif dalam rentang spesies. Ukuran khas spesies tumbuh pelan terhadap
-- berat rata-ratanya (akar pangkat empat) agar teri dan naga sama-sama muat; individu teringan 80%, terberat 120%.
function FishModel.LengthFor(species: FishSpecies, weight: number): number
	local minW = math.max(species.MinWeight, 0.001)
	local maxW = math.max(species.MaxWeight, minW)
	local w = if weight == weight then math.clamp(weight, minW, maxW) else (minW + maxW) / 2
	local t = if maxW > minW then (w - minW) / (maxW - minW) else 0.5
	local base = 1.6 * ((minW + maxW) / 2) ^ 0.25
	return math.clamp(base * (0.8 + 0.4 * t), 1.2, 9)
end

return FishModel
