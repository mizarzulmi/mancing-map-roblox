--!strict
-- Helper geometri map: part dekorasi dengan default aman, silinder/bola/wedge/elipsoid, segmen antara
-- dua titik, kurva Bezier & Catmull-Rom, rantai segmen bertaper, segitiga dari dua wedge, variasi warna
-- deterministik ±4 %, penghitung part per modul, tinggi tanah, papan teks SurfaceGui, serta komposit kecil
-- yang dipakai banyak modul (lentera, tiang lampu, payung, tong, ember, ikan, lambung perahu, papan arah).

local CollectionService = game:GetService("CollectionService")

local MapConfig = require(script.Parent.MapConfig)
local Terrain = require(script.Parent.Terrain)

local C = MapConfig.Colors
local MAT = Enum.Material

local Geo = {}

export type Context = {
	Root: Model,
	Points: Folder,
	NPCSpawns: Folder,
	AmbientPoints: Folder,
	FishingZones: Folder,
	Npc: { [string]: CFrame },
	Bake: boolean,
}

export type Opts = {
	Name: string?,
	Collide: boolean?,
	Shadow: boolean?,
	Transparency: number?,
	Reflectance: number?,
	Jitter: number?, -- 0 = tanpa variasi warna; default 0,04
	Extend: number?, -- perpanjangan tiap ujung (segmen/papan) agar sambungan tertutup
}

export type LightOpts = {
	Range: number?,
	Brightness: number?,
	Color: Color3?,
	Night: boolean?, -- default true: Enabled=false + tag NightLight
	Flicker: boolean?,
	Angle: number?,
	Face: Enum.NormalId?,
}

export type SignOpts = {
	Board: Color3?,
	Material: Enum.Material?,
	TextColor: Color3?,
	Stroke: Color3?,
	BothSides: boolean?,
	Collide: boolean?,
	PixelsPerStud: number?,
	MaxTextSize: number?,
}

export type HullSpec = {
	Length: number,
	HalfBeam: number,
	Freeboard: number,
	BowRise: number,
	SternRise: number,
	KeelDepth: number,
	Strakes: { Color3 },
	Segments: number,
	Thickness: number,
	Material: Enum.Material,
	SternFull: number,
	Collide: boolean,
	Posts: boolean,
	RailColor: Color3?,
}

export type Hull = {
	Point: (t: number, phi: number, side: number) -> Vector3,
	Sheer: (t: number) -> number,
	Width: (t: number) -> number,
	Keel: (t: number) -> number,
	Z: (t: number) -> number,
	Length: number,
}

export type UmbrellaOpts = {
	Height: number,
	Radius: number,
	Panels: number,
	Colors: { Color3 },
	Tilt: Vector3?,
	Droop: number?,
	Pole: Color3?,
}

local EMPTY: Opts = {}
local UP = Vector3.yAxis
local DOWN = -Vector3.yAxis

-- ===================================================================== penghitung & acak

local counts: { [string]: number } = {}
local current = "Lainnya"
local total = 0
local jitterRng = Random.new(MapConfig.Seed)

function Geo.ResetCounts()
	counts = {}
	total = 0
	current = "Lainnya"
end

function Geo.BeginModule(name: string, seedOffset: number)
	current = name
	if counts[name] == nil then
		counts[name] = 0
	end
	jitterRng = Random.new(MapConfig.Seed + seedOffset * 7919)
end

function Geo.Counts(): { [string]: number }
	return counts
end

function Geo.Total(): number
	return total
end

function Geo.Rng(offset: number): Random
	return Random.new(MapConfig.Seed + offset)
end

local function bump()
	total += 1
	counts[current] = (counts[current] or 0) + 1
end

-- Variasi warna deterministik (default ±4 % pada value & saturation, pergeseran hue kecil).
function Geo.Jitter(c: Color3, amount: number?): Color3
	local a = amount or 0.04
	if a <= 0 then
		return c
	end
	local h, s, v = c:ToHSV()
	v = math.clamp(v * (1 + jitterRng:NextNumber(-a, a)), 0, 1)
	s = math.clamp(s * (1 + jitterRng:NextNumber(-a, a)), 0, 1)
	h = (h + jitterRng:NextNumber(-a, a) * 0.06) % 1
	return Color3.fromHSV(h, s, v)
end

-- Angka acak dari aliran jitter modul aktif (deterministik per modul).
function Geo.Rand(min: number, max: number): number
	return jitterRng:NextNumber(min, max)
end

local function copyOpts(o: Opts?): Opts
	local src = o or EMPTY
	return {
		Name = src.Name,
		Collide = src.Collide,
		Shadow = src.Shadow,
		Transparency = src.Transparency,
		Reflectance = src.Reflectance,
		Jitter = src.Jitter,
		Extend = src.Extend,
	}
end

-- ===================================================================== part dasar

local function apply(
	p: BasePart,
	parent: Instance,
	cf: CFrame,
	size: Vector3,
	color: Color3,
	material: Enum.Material,
	opts: Opts?
)
	local o = opts or EMPTY
	local collide = o.Collide == true
	p.Anchored = true
	p.CanCollide = collide
	p.CanQuery = collide
	p.CanTouch = false
	if o.Shadow ~= nil then
		p.CastShadow = o.Shadow
	else
		p.CastShadow = math.max(size.X, size.Y, size.Z) >= 3
	end
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = material
	p.Color = if o.Jitter == 0 then color else Geo.Jitter(color, o.Jitter)
	p.Size = size
	p.CFrame = cf
	if o.Transparency ~= nil then
		p.Transparency = o.Transparency
	end
	if o.Reflectance ~= nil then
		p.Reflectance = o.Reflectance
	end
	if o.Name ~= nil then
		p.Name = o.Name
	end
	p.Parent = parent
	bump()
end

function Geo.Block(
	parent: Instance,
	cf: CFrame,
	size: Vector3,
	color: Color3,
	material: Enum.Material,
	opts: Opts?
): Part
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Block
	apply(p, parent, cf, size, color, material, opts)
	return p
end

function Geo.Ball(
	parent: Instance,
	center: Vector3,
	diameter: number,
	color: Color3,
	material: Enum.Material,
	opts: Opts?
): Part
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	apply(p, parent, CFrame.new(center), Vector3.new(diameter, diameter, diameter), color, material, opts)
	return p
end

-- Silinder dengan sumbu = X lokal `cf`.
function Geo.Cylinder(
	parent: Instance,
	cf: CFrame,
	length: number,
	diameter: number,
	color: Color3,
	material: Enum.Material,
	opts: Opts?
): Part
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	apply(p, parent, cf, Vector3.new(length, diameter, diameter), color, material, opts)
	return p
end

function Geo.Wedge(
	parent: Instance,
	cf: CFrame,
	size: Vector3,
	color: Color3,
	material: Enum.Material,
	opts: Opts?
): WedgePart
	local p = Instance.new("WedgePart")
	apply(p, parent, cf, size, color, material, opts)
	return p
end

function Geo.CornerWedge(
	parent: Instance,
	cf: CFrame,
	size: Vector3,
	color: Color3,
	material: Enum.Material,
	opts: Opts?
): CornerWedgePart
	local p = Instance.new("CornerWedgePart")
	apply(p, parent, cf, size, color, material, opts)
	return p
end

-- Elipsoid = Part balok + SpecialMesh Sphere (tanpa MeshId) yang mengisi ukuran part.
function Geo.Ellipsoid(
	parent: Instance,
	cf: CFrame,
	size: Vector3,
	color: Color3,
	material: Enum.Material,
	opts: Opts?
): Part
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Block
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	apply(p, parent, cf, size, color, material, opts)
	return p
end

-- ===================================================================== orientasi

function Geo.Flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- CFrame dengan X lokal searah `dir` dan Y lokal sedekat mungkin ke `up`.
function Geo.AlongX(pos: Vector3, dir: Vector3, up: Vector3?): CFrame
	local x = if dir.Magnitude > 1e-6 then dir.Unit else Vector3.xAxis
	local u = up or UP
	if u.Magnitude < 1e-6 or math.abs(x:Dot(u.Unit)) > 0.999 then
		u = if math.abs(x.X) < 0.9 then Vector3.xAxis else Vector3.zAxis
	end
	local z = x:Cross(u).Unit
	local y = z:Cross(x).Unit
	return CFrame.fromMatrix(pos, x, y, z)
end

-- CFrame tegak di `pos` yang menghadap arah horizontal `face` (LookVector = face).
function Geo.Facing(pos: Vector3, face: Vector3): CFrame
	local f = Geo.Flat(face)
	if f.Magnitude < 1e-6 then
		f = Vector3.zAxis
	end
	return CFrame.lookAt(pos, pos + f.Unit)
end

-- Kemiringan "buatan tangan" kecil (derajat) dari aliran acak modul.
function Geo.HandTilt(maxDeg: number): CFrame
	local r = math.rad(maxDeg)
	return CFrame.Angles(jitterRng:NextNumber(-r, r), 0, jitterRng:NextNumber(-r, r))
end

-- ===================================================================== primitif turunan

-- Silinder tegak dengan alas di `base`.
function Geo.Post(
	parent: Instance,
	base: Vector3,
	height: number,
	diameter: number,
	color: Color3,
	material: Enum.Material,
	opts: Opts?
): Part
	local cf = CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	return Geo.Cylinder(parent, cf, height, diameter, color, material, opts)
end

-- Cakram mendatar (silinder bersumbu vertikal) berpusat di `center`.
function Geo.Disk(
	parent: Instance,
	center: Vector3,
	thickness: number,
	diameter: number,
	color: Color3,
	material: Enum.Material,
	opts: Opts?
): Part
	local cf = CFrame.new(center) * CFrame.Angles(0, 0, math.pi / 2)
	return Geo.Cylinder(parent, cf, thickness, diameter, color, material, opts)
end

-- Silinder dari A ke B.
function Geo.Segment(
	parent: Instance,
	a: Vector3,
	b: Vector3,
	diameter: number,
	color: Color3,
	material: Enum.Material,
	opts: Opts?
): Part
	local d = b - a
	local len = d.Magnitude
	if len < 1e-4 then
		d = UP
		len = 0.01
	end
	local e = (opts and opts.Extend) or 0
	return Geo.Cylinder(parent, Geo.AlongX((a + b) / 2, d), len + 2 * e, diameter, color, material, opts)
end

-- Papan/balok dari A ke B (garis tengah); tebal searah `up`, lebar tegak lurus keduanya.
function Geo.Plank(
	parent: Instance,
	a: Vector3,
	b: Vector3,
	width: number,
	thickness: number,
	up: Vector3,
	color: Color3,
	material: Enum.Material,
	opts: Opts?
): Part
	local d = b - a
	local e = (opts and opts.Extend) or 0
	return Geo.Block(
		parent,
		Geo.AlongX((a + b) / 2, d, up),
		Vector3.new(d.Magnitude + 2 * e, thickness, width),
		color,
		material,
		opts
	)
end

-- Ujung runcing (wedge) dari pangkal A (lebar penuh) ke ujung B; bidang daun tegak lurus `up`.
function Geo.Tip(
	parent: Instance,
	a: Vector3,
	b: Vector3,
	width: number,
	thickness: number,
	up: Vector3,
	color: Color3,
	material: Enum.Material,
	opts: Opts?
): WedgePart
	local d = b - a
	local dir = if d.Magnitude > 1e-6 then d.Unit else Vector3.xAxis
	local n = up - dir * up:Dot(dir)
	if n.Magnitude < 1e-4 then
		n = if math.abs(dir.X) < 0.9 then Vector3.xAxis else Vector3.zAxis
		n = (n - dir * n:Dot(dir)).Unit
	else
		n = n.Unit
	end
	local zv = -dir
	local yv = zv:Cross(n)
	return Geo.Wedge(
		parent,
		CFrame.fromMatrix((a + b) / 2, n, yv, zv),
		Vector3.new(thickness, width, d.Magnitude),
		color,
		material,
		opts
	)
end

-- Segitiga sembarang dari dua WedgePart (ketebalan dipusatkan pada bidang segitiga).
function Geo.Triangle(
	parent: Instance,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	thickness: number,
	color: Color3,
	material: Enum.Material,
	opts: Opts?
): { WedgePart }
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local nrm = ac:Cross(ab)
	if nrm.Magnitude < 1e-6 or bc.Magnitude < 1e-6 then
		return {}
	end
	local right = nrm.Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	local o = copyOpts(opts)
	local col = if o.Jitter == 0 then color else Geo.Jitter(color, o.Jitter)
	o.Jitter = 0
	local w1 = Geo.Wedge(
		parent,
		CFrame.fromMatrix((a + b) / 2, right, up, back),
		Vector3.new(thickness, height, math.abs(ab:Dot(back))),
		col,
		material,
		o
	)
	local w2 = Geo.Wedge(
		parent,
		CFrame.fromMatrix((a + c) / 2, -right, up, -back),
		Vector3.new(thickness, height, math.abs(ac:Dot(back))),
		col,
		material,
		o
	)
	return { w1, w2 }
end

-- Segiempat (a, b, c, d berurutan) = dua segitiga.
function Geo.Quad(
	parent: Instance,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	d: Vector3,
	thickness: number,
	color: Color3,
	material: Enum.Material,
	opts: Opts?
)
	local o = copyOpts(opts)
	local col = if o.Jitter == 0 then color else Geo.Jitter(color, o.Jitter)
	o.Jitter = 0
	Geo.Triangle(parent, a, b, c, thickness, col, material, o)
	Geo.Triangle(parent, a, c, d, thickness, col, material, o)
end

-- ===================================================================== kurva

function Geo.Bezier2(p0: Vector3, p1: Vector3, p2: Vector3, n: number): { Vector3 }
	local out: { Vector3 } = table.create(n + 1)
	for i = 0, n do
		local t = i / n
		local u = 1 - t
		table.insert(out, p0 * (u * u) + p1 * (2 * u * t) + p2 * (t * t))
	end
	return out
end

function Geo.Bezier3(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, n: number): { Vector3 }
	local out: { Vector3 } = table.create(n + 1)
	for i = 0, n do
		local t = i / n
		local u = 1 - t
		table.insert(out, p0 * (u * u * u) + p1 * (3 * u * u * t) + p2 * (3 * u * t * t) + p3 * (t * t * t))
	end
	return out
end

-- Titik pada tali melendut (kubik, kontrol turun 4/3 × lendut) — sama dengan kurva Beam Geo.Rope.
function Geo.RopePoint(a: Vector3, b: Vector3, sag: number, t: number): Vector3
	local k = sag * 4 / 3
	local p1 = a + DOWN * k
	local p2 = b + DOWN * k
	local u = 1 - t
	return a * (u * u * u) + p1 * (3 * u * u * t) + p2 * (3 * u * t * t) + b * (t * t * t)
end

-- Catmull-Rom melalui titik-titik kontrol (Y diabaikan → 0).
function Geo.CatmullRom(pts: { Vector3 }, step: number): { Vector3 }
	local out: { Vector3 } = {}
	local n = #pts
	for i = 1, n - 1 do
		local p0 = Geo.Flat(pts[math.max(1, i - 1)])
		local p1 = Geo.Flat(pts[i])
		local p2 = Geo.Flat(pts[i + 1])
		local p3 = Geo.Flat(pts[math.min(n, i + 2)])
		local k = math.max(1, math.ceil((p2 - p1).Magnitude / step))
		for j = 0, k - 1 do
			local t = j / k
			local t2, t3 = t * t, t * t * t
			table.insert(
				out,
				(p1 * 2 + (p2 - p0) * t + (p0 * 2 - p1 * 5 + p2 * 4 - p3) * t2 + (p1 * 3 - p0 - p2 * 3 + p3) * t3) * 0.5
			)
		end
	end
	table.insert(out, Geo.Flat(pts[n]))
	return out
end

-- Sampel ulang polyline dengan jarak busur tetap; hasil: posisi & tangen satuan.
function Geo.Resample(poly: { Vector3 }, spacing: number): ({ Vector3 }, { Vector3 })
	local pos: { Vector3 } = {}
	local tan: { Vector3 } = {}
	if #poly < 2 then
		return pos, tan
	end
	local acc = spacing * 0.5
	for i = 1, #poly - 1 do
		local a, b = poly[i], poly[i + 1]
		local seg = b - a
		local len = seg.Magnitude
		if len > 1e-6 then
			local dir = seg / len
			local d = acc
			while d <= len do
				table.insert(pos, a + dir * d)
				table.insert(tan, dir)
				d += spacing
			end
			acc = d - len
		end
	end
	return pos, tan
end

function Geo.DistToPolyline(x: number, z: number, pts: { Vector3 }): number
	local best = math.huge
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local abx, abz = b.X - a.X, b.Z - a.Z
		local apx, apz = x - a.X, z - a.Z
		local len2 = abx * abx + abz * abz
		local t = if len2 > 0 then math.clamp((apx * abx + apz * abz) / len2, 0, 1) else 0
		local dx, dz = apx - abx * t, apz - abz * t
		local d = math.sqrt(dx * dx + dz * dz)
		if d < best then
			best = d
		end
	end
	return best
end

local pathCache: { [string]: { Vector3 } } = {}

-- Polyline halus (sampel ±1 stud) dari MapConfig.Paths[name].
function Geo.PathPolyline(name: string): { Vector3 }
	local cached = pathCache[name]
	if cached then
		return cached
	end
	for _, p in MapConfig.Paths do
		if p.Name == name then
			local poly = Geo.CatmullRom(p.Points, 1)
			pathCache[name] = poly
			return poly
		end
	end
	return {}
end

-- Benar bila (x, z) berada dalam lebar jalur + margin dari jalur mana pun.
function Geo.NearPath(x: number, z: number, margin: number): boolean
	for _, p in MapConfig.Paths do
		local poly = Geo.PathPolyline(p.Name)
		if Geo.DistToPolyline(x, z, poly) < p.Width * 0.5 + margin then
			return true
		end
	end
	return false
end

-- Rantai silinder melalui titik-titik; diameter mengecil d0 → d1, warna "cincin" bergantian bila diberi.
function Geo.Chain(
	parent: Instance,
	pts: { Vector3 },
	d0: number,
	d1: number,
	color: Color3,
	material: Enum.Material,
	opts: Opts?,
	ringColor: Color3?
): { Part }
	local parts: { Part } = {}
	local n = #pts - 1
	for i = 1, n do
		local d = d0 + (d1 - d0) * ((i - 0.5) / n)
		local o = copyOpts(opts)
		o.Extend = (o.Extend or 0) + d * 0.2
		local col = if ringColor ~= nil and i % 2 == 0 then ringColor else color
		table.insert(parts, Geo.Segment(parent, pts[i], pts[i + 1], d, col, material, o))
	end
	return parts
end

-- ===================================================================== tanah

function Geo.GroundY(x: number, z: number): number
	local h = Terrain.HeightAt(x, z)
	return h
end

function Geo.Ground(pos: Vector3): Vector3
	return Vector3.new(pos.X, Geo.GroundY(pos.X, pos.Z), pos.Z)
end

function Geo.GroundMaterial(x: number, z: number): Enum.Material
	local _, m = Terrain.HeightAt(x, z)
	return m
end

-- ===================================================================== tag, cahaya, wadah

function Geo.Tag(inst: Instance, tag: string)
	CollectionService:AddTag(inst, tag)
end

function Geo.PointLight(parent: Instance, o: LightOpts?): PointLight
	local opt: LightOpts = o or {}
	local l = Instance.new("PointLight")
	l.Range = opt.Range or 18
	l.Brightness = opt.Brightness or 1.4
	l.Color = opt.Color or C.LightWarm
	l.Shadows = false
	local night = opt.Night ~= false
	l.Enabled = not night
	l.Parent = parent
	if night then
		Geo.Tag(l, "NightLight")
	end
	if opt.Flicker then
		Geo.Tag(l, "Flicker")
	end
	return l
end

function Geo.SpotLight(parent: Instance, o: LightOpts?): SpotLight
	local opt: LightOpts = o or {}
	local l = Instance.new("SpotLight")
	l.Range = opt.Range or 40
	l.Brightness = opt.Brightness or 3
	l.Color = opt.Color or C.LightWarm
	l.Angle = opt.Angle or 30
	l.Face = opt.Face or Enum.NormalId.Front
	l.Shadows = false
	local night = opt.Night ~= false
	l.Enabled = not night
	l.Parent = parent
	if night then
		Geo.Tag(l, "NightLight")
	end
	if opt.Flicker then
		Geo.Tag(l, "Flicker")
	end
	return l
end

function Geo.Model(parent: Instance, name: string, streaming: Enum.ModelStreamingMode?): Model
	local m = Instance.new("Model")
	m.Name = name
	if streaming then
		m.ModelStreamingMode = streaming
	end
	m.Parent = parent
	return m
end

function Geo.Folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- Part penanda tak terlihat (tanpa tabrakan/query/sentuh).
function Geo.Marker(parent: Instance, name: string, cf: CFrame, size: Vector3?, attrs: { [string]: any }?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Material = MAT.SmoothPlastic
	p.Size = size or Vector3.new(1, 1, 1)
	p.CFrame = cf
	if attrs then
		for k, v in attrs do
			p:SetAttribute(k, v)
		end
	end
	p.Parent = parent
	bump()
	return p
end

-- Attachment di posisi dunia; Axis (X lokal) default menghadap ke bawah (untuk tali melendut).
function Geo.Attach(part: BasePart, worldPos: Vector3, axis: Vector3?): Attachment
	local a = Instance.new("Attachment")
	a.CFrame = part.CFrame:ToObjectSpace(Geo.AlongX(worldPos, axis or DOWN))
	a.Parent = part
	return a
end

-- Tali melendut dari Beam (bukan part). Kedua attachment ber-Axis ke bawah (Geo.Attach default).
function Geo.Rope(a0: Attachment, a1: Attachment, sag: number, width: number, color: Color3): Beam
	local b = Instance.new("Beam")
	b.Attachment0 = a0
	b.Attachment1 = a1
	b.CurveSize0 = sag * 4 / 3
	b.CurveSize1 = -sag * 4 / 3
	b.Width0 = width
	b.Width1 = width
	b.FaceCamera = true
	b.Segments = 12
	b.Color = ColorSequence.new(color)
	b.Transparency = NumberSequence.new(0)
	b.LightInfluence = 1
	b.LightEmission = 0
	b.Parent = a0.Parent
	return b
end

-- ===================================================================== papan teks

function Geo.SignText(part: BasePart, face: Enum.NormalId, text: string, o: SignOpts?): SurfaceGui
	local opt: SignOpts = o or {}
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = opt.PixelsPerStud or 40
	gui.LightInfluence = 0.6
	gui.MaxDistance = 300
	gui.ClipsDescendants = true
	local label = Instance.new("TextLabel")
	label.Name = "Teks"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = Font.new(MapConfig.FontFamily)
	label.Text = text
	label.TextColor3 = opt.TextColor or C.SignText
	label.TextScaled = true
	label.TextWrapped = true
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.05, 0)
	pad.PaddingRight = UDim.new(0.05, 0)
	pad.PaddingTop = UDim.new(0.12, 0)
	pad.PaddingBottom = UDim.new(0.12, 0)
	pad.Parent = label
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = opt.MaxTextSize or 72
	limit.MinTextSize = 8
	limit.Parent = label
	local stroke = Instance.new("UIStroke")
	stroke.Color = opt.Stroke or C.SignStroke
	stroke.Thickness = 3
	stroke.Parent = label
	label.Parent = gui
	gui.Parent = part
	return gui
end

-- Papan kayu bertulisan (teks terang + stroke gelap) di sisi depan (dan belakang bila diminta).
function Geo.Sign(parent: Instance, cf: CFrame, size: Vector3, text: string, o: SignOpts?): Part
	local opt: SignOpts = o or {}
	local board = Geo.Block(
		parent,
		cf,
		size,
		opt.Board or C.SignBoard,
		opt.Material or MAT.Wood,
		{ Collide = opt.Collide, Shadow = true }
	)
	Geo.SignText(board, Enum.NormalId.Front, text, opt)
	if opt.BothSides then
		Geo.SignText(board, Enum.NormalId.Back, text, opt)
	end
	return board
end

-- ===================================================================== komposit kecil

-- Lentera: badan kaca buram + topi + kenop; PointLight malam di dalamnya (3 part).
function Geo.Lantern(parent: Instance, center: Vector3, size: number, flicker: boolean?, range: number?): Part
	local body = Geo.Ball(parent, center, size, C.LampGlass, MAT.SmoothPlastic, { Shadow = false, Jitter = 0.02 })
	Geo.Disk(
		parent,
		center + Vector3.new(0, size * 0.52, 0),
		size * 0.2,
		size * 1.15,
		C.MetalDark,
		MAT.Metal,
		{ Shadow = false }
	)
	Geo.Ball(parent, center + Vector3.new(0, size * 0.72, 0), size * 0.3, C.MetalDark, MAT.Metal, { Shadow = false })
	Geo.PointLight(body, {
		Range = range or 20,
		Brightness = 1.5,
		Color = C.LightWarm,
		Night = true,
		Flicker = flicker,
	})
	return body
end

-- Tiang lampu taman: alas batu, tiang kayu, lentera di puncak (5 part). Mengembalikan posisi puncak.
function Geo.LampPost(parent: Instance, base: Vector3, height: number, range: number?): Vector3
	Geo.Disk(parent, base + Vector3.new(0, 0.15, 0), 0.8, 1.5, C.StoneDark, MAT.Slate, { Shadow = false })
	Geo.Post(parent, base - Vector3.new(0, 0.3, 0), height + 0.3, 0.42, C.WoodDark, MAT.Wood, { Collide = true })
	local top = base + Vector3.new(0, height + 0.8, 0)
	Geo.Lantern(parent, top, 1.5, false, range or 22)
	return top + Vector3.new(0, 1.2, 0)
end

-- Payung pantai: tiang + kanopi kerucut dari panel segitiga radial bergaris + kenop (2 + 2·panel part).
function Geo.Umbrella(parent: Instance, base: Vector3, o: UmbrellaOpts): Vector3
	local axis = (UP + (o.Tilt or Vector3.zero)).Unit
	local top = base + axis * o.Height
	Geo.Segment(
		parent,
		base - axis * 0.8,
		top + axis * 0.25,
		0.26,
		o.Pole or C.WoodLight,
		MAT.Wood,
		{ Collide = true, Shadow = false }
	)
	local ref = if math.abs(axis.X) < 0.9 then Vector3.xAxis else Vector3.zAxis
	local right = (ref - axis * ref:Dot(axis)).Unit
	local fwd = axis:Cross(right)
	local apex = top + axis * 0.35
	local droop = o.Droop or o.Radius * 0.32
	local n = o.Panels
	local rot = Geo.Rand(0, math.pi * 2)
	for i = 1, n do
		local a0 = rot + (i - 1) / n * math.pi * 2
		local a1 = rot + i / n * math.pi * 2
		local r0 = top + (right * math.cos(a0) + fwd * math.sin(a0)) * o.Radius - axis * droop
		local r1 = top + (right * math.cos(a1) + fwd * math.sin(a1)) * o.Radius - axis * droop
		Geo.Triangle(
			parent,
			apex,
			r0,
			r1,
			0.12,
			o.Colors[(i - 1) % #o.Colors + 1],
			MAT.Fabric,
			{ Shadow = true, Jitter = 0.02 }
		)
	end
	Geo.Ball(parent, apex + axis * 0.2, 0.45, o.Pole or C.WoodLight, MAT.Wood, { Shadow = false })
	return top
end

-- Tong kayu bersabuk logam dengan isi (umpan/es) di atas (4 part).
function Geo.Barrel(
	parent: Instance,
	base: Vector3,
	diameter: number,
	height: number,
	color: Color3,
	content: Color3?,
	contentMaterial: Enum.Material?
): Part
	local body = Geo.Post(
		parent,
		base - Vector3.new(0, 0.25, 0),
		height + 0.25,
		diameter,
		color,
		MAT.WoodPlanks,
		{ Collide = true }
	)
	for _, f in { 0.24, 0.78 } do
		Geo.Disk(
			parent,
			base + Vector3.new(0, height * f, 0),
			0.18,
			diameter + 0.1,
			C.MetalDark,
			MAT.Metal,
			{ Shadow = false }
		)
	end
	Geo.Disk(
		parent,
		base + Vector3.new(0, height + 0.04, 0),
		0.1,
		diameter * 0.84,
		content or C.WoodDark,
		contentMaterial or MAT.Sand,
		{ Shadow = false }
	)
	return body
end

-- Ember (3 part): badan, bibir, isi air.
function Geo.Bucket(parent: Instance, base: Vector3, color: Color3): Part
	local body =
		Geo.Post(parent, base - Vector3.new(0, 0.2, 0), 1.45, 1.25, color, MAT.SmoothPlastic, { Shadow = false })
	Geo.Disk(parent, base + Vector3.new(0, 1.28, 0), 0.14, 1.38, color, MAT.SmoothPlastic, { Shadow = false })
	Geo.Disk(
		parent,
		base + Vector3.new(0, 1.27, 0),
		0.06,
		1.08,
		C.Teal,
		MAT.Glass,
		{ Shadow = false, Transparency = 0.25 }
	)
	return body
end

-- Ikan pajangan sederhana: badan elipsoid (X lokal = arah kepala) + ekor segitiga (3 part).
function Geo.Fish(parent: Instance, cf: CFrame, length: number, body: Color3, fin: Color3): Part
	local b = Geo.Ellipsoid(
		parent,
		cf,
		Vector3.new(length, length * 0.36, length * 0.2),
		body,
		MAT.SmoothPlastic,
		{ Shadow = false }
	)
	local back = cf.Position - cf.XVector * (length * 0.42)
	local tail = back - cf.XVector * (length * 0.3)
	Geo.Triangle(
		parent,
		back,
		tail + cf.YVector * (length * 0.24),
		tail - cf.YVector * (length * 0.24),
		length * 0.05,
		fin,
		MAT.SmoothPlastic,
		{ Shadow = false }
	)
	return b
end

-- Gulungan tali (3 part).
function Geo.RopeCoil(parent: Instance, base: Vector3, diameter: number)
	Geo.Disk(parent, base + Vector3.new(0, 0.18, 0), 0.38, diameter, C.Rope, MAT.Fabric, { Shadow = false })
	Geo.Disk(parent, base + Vector3.new(0, 0.5, 0), 0.32, diameter * 0.86, C.Rope, MAT.Fabric, { Shadow = false })
	Geo.Disk(parent, base + Vector3.new(0, 0.68, 0), 0.06, diameter * 0.4, C.RopeDark, MAT.Fabric, { Shadow = false })
end

-- Papan arah: tiang + kenop + (papan + ujung panah segitiga) per arah, teks di kedua sisi.
function Geo.Signpost(parent: Instance, base: Vector3, arrows: { MapConfig.ArrowDef })
	Geo.Post(parent, base - Vector3.new(0, 0.8, 0), 7.2, 0.5, C.WoodPost, MAT.Wood, { Collide = true })
	Geo.Ball(parent, base + Vector3.new(0, 6.55, 0), 0.7, C.WoodDark, MAT.Wood, { Shadow = false })
	for i, arrow in arrows do
		local y = base.Y + 5.6 - (i - 1) * 1.45
		local dir = Geo.Flat(arrow.Toward - base)
		dir = if dir.Magnitude > 1e-4 then dir.Unit else Vector3.xAxis
		local len = math.max(3.8, #arrow.Text * 0.36 + 1.4)
		local origin = Vector3.new(base.X, y, base.Z)
		local center = origin + dir * (len * 0.5 + 0.15)
		local board = Geo.Block(
			parent,
			Geo.AlongX(center, dir) * CFrame.Angles(math.rad(Geo.Rand(-2.5, 2.5)), 0, 0),
			Vector3.new(len, 1.1, 0.22),
			C.SignBoard,
			MAT.Wood,
			{ Shadow = false }
		)
		local tipBase = origin + dir * (len + 0.15)
		Geo.Triangle(
			parent,
			tipBase + UP * 0.55,
			tipBase - UP * 0.55,
			tipBase + dir * 0.8,
			0.22,
			C.SignBoard,
			MAT.Wood,
			{ Shadow = false, Jitter = 0 }
		)
		Geo.SignText(board, Enum.NormalId.Front, arrow.Text, { MaxTextSize = 48 })
		Geo.SignText(board, Enum.NormalId.Back, arrow.Text, { MaxTextSize = 48 })
	end
end

-- ===================================================================== lambung perahu

-- Lambung lengkung dari lajur papan (strake) per sisi. Ruang lokal `cf`: −Z = haluan, +Y = atas,
-- origin = garis air di tengah kapal. t: 0 buritan → 1 haluan; phi: 0 bibir lambung → π/2 lunas.
function Geo.Hull(parent: Instance, cf: CFrame, spec: HullSpec): Hull
	local L, HB = spec.Length, spec.HalfBeam

	local function zAt(t: number): number
		return L * 0.5 - t * L
	end
	local function width(t: number): number
		local s = math.sin(math.pi * t)
		if s <= 0 then
			return 0
		end
		local p = if t < 0.5 then 0.62 * (1 - 0.45 * spec.SternFull) else 0.62
		return HB * s ^ p
	end
	local function sheer(t: number): number
		local b = math.max(0, 2 * t - 1)
		local st = math.max(0, 1 - 2 * t)
		return spec.Freeboard + spec.BowRise * b * b + spec.SternRise * st * st
	end
	local function keel(t: number): number
		local e = math.abs(2 * t - 1)
		return -spec.KeelDepth * (1 - e * e * e)
	end
	local function point(t: number, phi: number, side: number): Vector3
		local w = width(t)
		local sh, kl = sheer(t), keel(t)
		local c = math.max(0, math.cos(phi))
		return Vector3.new(side * w * c ^ 0.75, sh - (sh - kl) * math.sin(phi), zAt(t))
	end
	local function station(j: number): number
		return 0.5 - 0.5 * math.cos(math.pi * j / spec.Segments)
	end

	local n = #spec.Strakes
	for _, side in { -1, 1 } do
		for i = 1, n do
			local phiA = (i - 1) / n * (math.pi / 2)
			local phiB = i / n * (math.pi / 2)
			local phiM = (phiA + phiB) * 0.5
			for j = 1, spec.Segments do
				local t0, t1 = station(j - 1), station(j)
				local tm = (t0 + t1) * 0.5
				local a = point(t0, phiM, side)
				local b = point(t1, phiM, side)
				local along = b - a
				local wv = point(tm, phiB, side) - point(tm, phiA, side)
				local nrm = along:Cross(wv)
				if nrm.X * side < 0 then
					nrm = -nrm
				end
				local thick = spec.Thickness * (if j % 2 == 0 then 1.14 else 1)
				Geo.Block(
					parent,
					cf * Geo.AlongX((a + b) * 0.5, along, nrm),
					Vector3.new(along.Magnitude + 0.24, thick, wv.Magnitude + 0.08),
					spec.Strakes[i],
					spec.Material,
					{ Collide = spec.Collide, Shadow = true, Jitter = 0.03 }
				)
			end
		end
		if spec.RailColor then
			-- List bibir lambung mengikuti garis sheer (menegaskan lengkung).
			local pts: { Vector3 } = {}
			for j = 1, spec.Segments - 1 do
				local p = point(station(j), 0, side)
				table.insert(pts, cf:PointToWorldSpace(p + Vector3.new(0, spec.Thickness * 0.6, 0)))
			end
			Geo.Chain(
				parent,
				pts,
				spec.Thickness * 1.3,
				spec.Thickness * 1.3,
				spec.RailColor,
				MAT.Wood,
				{ Shadow = false }
			)
		end
	end

	if spec.Posts then
		-- Linggi haluan & buritan menutup pertemuan papan.
		local bowLow = cf:PointToWorldSpace(Vector3.new(0, keel(0.9), zAt(0.94)))
		local bowTop = cf:PointToWorldSpace(Vector3.new(0, sheer(1) + 0.15, zAt(1) - 0.1))
		Geo.Segment(parent, bowLow, bowTop, spec.Thickness * 2.4, spec.Strakes[1], spec.Material, { Shadow = false })
		local sternLow = cf:PointToWorldSpace(Vector3.new(0, keel(0.1), zAt(0.06)))
		local sternTop = cf:PointToWorldSpace(Vector3.new(0, sheer(0) + 0.15, zAt(0) + 0.1))
		Geo.Segment(
			parent,
			sternLow,
			sternTop,
			spec.Thickness * 2.4,
			spec.Strakes[1],
			spec.Material,
			{ Shadow = false }
		)
	end

	return {
		Point = point,
		Sheer = sheer,
		Width = width,
		Keel = keel,
		Z = zAt,
		Length = L,
	}
end

return Geo
