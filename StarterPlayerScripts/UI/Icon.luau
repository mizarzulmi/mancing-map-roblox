--!strict
-- Icon: set ikon garis yang DIGAMBAR dari Frame + UICorner + UIStroke + rotasi (tanpa emoji, glyph unicode,
-- atau aset gambar). Kanvas 24 unit seperti grid ikon garis; satu bobot garis: 2 px pada ukuran HUD (≤ 34 px),
-- naik proporsional untuk ikon besar agar bobot visual tetap sama. Busur = cincin UIStroke yang dipotong Frame
-- ClipsDescendants (jangan memutar wadah ikon: pemotongan Roblox tidak berlaku pada leluhur yang dirotasi).
-- Setiap bagian ditandai atribut IconRole ("Ink" = warna utama, "Deep" = turunan lebih gelap) untuk SetColor.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.Shared.Config.Theme)

export type IconName =
	"coin"
	| "leaf"
	| "bag"
	| "fish"
	| "book"
	| "scroll"
	| "shirt"
	| "gear"
	| "clock"
	| "sun"
	| "cloud"
	| "rain"
	| "storm"
	| "moon"
	| "star"
	| "lock"
	| "close"
	| "check"
	| "anchor"
	| "users"
	| "rod"
	| "bait"
	| "boat"
	| "swap"
	| "alert"
	| "chevron_left"
	| "chevron_right"
	| "chevron_up"
	| "chevron_down"
	| "plus"
	| "minus"
	| "sell"
	| "trophy"
	| "map"
	| "info"

type Role = "Ink" | "Deep"

type Ctx = {
	root: Frame,
	u: number, -- px per unit grid
	w: number, -- bobot garis (px, bilangan bulat)
	wu: number, -- bobot garis dalam unit grid
	ink: Color3,
	deep: Color3,
}

type Bounds = { minX: number?, maxX: number?, minY: number?, maxY: number? }

local Icon = {}

local GRID = 24

-- Bobot garis: 2 px sampai ±34 px, lalu ±1/14 ukuran.
local function weightFor(size: number): number
	return math.max(2, math.floor(size / 14 + 0.5))
end

-- Turunan gelap untuk detail (cincin koin). Emas koin memakai token CoinDeep.
local function deepOf(color: Color3): Color3
	if color == Theme.Color.Coin then
		return Theme.Color.CoinDeep
	end
	return color:Lerp(Theme.Color.Scrim, 0.25)
end

local function colorFor(ctx: Ctx, role: Role): Color3
	return if role == "Deep" then ctx.deep else ctx.ink
end

local function round(value: number): number
	return math.floor(value + 0.5)
end

local function setCorner(part: GuiObject, radius: UDim)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius
	corner.Parent = part
end

-- Garis lurus dengan ujung membulat (seperti stroke-linecap round). Koordinat dalam unit grid;
-- ox/oy = posisi px wadah (untuk bagian di dalam Frame pemotong).
local function line(ctx: Ctx, x1: number, y1: number, x2: number, y2: number, parent: Instance?, ox: number?, oy: number?)
	local u, w = ctx.u, ctx.w
	local offsetX, offsetY = ox or 0, oy or 0
	local ax, ay = x1 * u - offsetX, y1 * u - offsetY
	local bx, by = x2 * u - offsetX, y2 * u - offsetY
	local dx, dy = bx - ax, by - ay
	local length = math.sqrt(dx * dx + dy * dy)
	local part = Instance.new("Frame")
	part.Name = "Line"
	part.BorderSizePixel = 0
	part.BackgroundColor3 = ctx.ink
	if math.abs(dy) < 1e-3 then
		-- Horizontal: tepi diselaraskan ke piksel utuh agar garis 2 px tetap tajam.
		local long = round(length + w)
		part.Size = UDim2.fromOffset(long, w)
		part.Position = UDim2.fromOffset(round(math.min(ax, bx) - w / 2), round(ay - w / 2))
	elseif math.abs(dx) < 1e-3 then
		local long = round(length + w)
		part.Size = UDim2.fromOffset(w, long)
		part.Position = UDim2.fromOffset(round(ax - w / 2), round(math.min(ay, by) - w / 2))
	else
		part.AnchorPoint = Vector2.new(0.5, 0.5)
		part.Size = UDim2.fromOffset(length + w, w)
		part.Position = UDim2.fromOffset((ax + bx) / 2, (ay + by) / 2)
		part.Rotation = math.deg(math.atan2(dy, dx))
	end
	setCorner(part, UDim.new(0, w / 2))
	part:SetAttribute("IconRole", "Ink")
	part.Parent = parent or ctx.root
end

-- Cincin (outline lingkaran) dengan garis tengah berjari-jari r unit. UIStroke klasik digambar ke luar tepi
-- Frame, jadi diameter Frame = 2r − bobot.
local function ring(ctx: Ctx, cx: number, cy: number, r: number, role: Role?, parent: Instance?, ox: number?, oy: number?)
	local u, w = ctx.u, ctx.w
	local diameter = math.max(2, round(2 * r * u - w))
	local part = Instance.new("Frame")
	part.Name = "Ring"
	part.BackgroundTransparency = 1
	part.BorderSizePixel = 0
	part.Size = UDim2.fromOffset(diameter, diameter)
	part.Position = UDim2.fromOffset(round(cx * u - diameter / 2) - (ox or 0), round(cy * u - diameter / 2) - (oy or 0))
	setCorner(part, UDim.new(0.5, 0))
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Thickness = w
	local strokeRole: Role = role or "Ink"
	stroke.Color = colorFor(ctx, strokeRole)
	stroke:SetAttribute("IconRole", strokeRole)
	stroke.Parent = part
	part.Parent = parent or ctx.root
end

-- Busur: cincin yang dipotong persegi panjang sejajar sumbu (setengah atau seperempat, atau dipotong tali busur).
local function arc(ctx: Ctx, cx: number, cy: number, r: number, bounds: Bounds, role: Role?)
	local u, w = ctx.u, ctx.w
	local outer = r * u + w + 1
	local left = cx * u - outer
	local right = cx * u + outer
	local top = cy * u - outer
	local bottom = cy * u + outer
	if bounds.minX then
		left = math.max(left, bounds.minX * u)
	end
	if bounds.maxX then
		right = math.min(right, bounds.maxX * u)
	end
	if bounds.minY then
		top = math.max(top, bounds.minY * u)
	end
	if bounds.maxY then
		bottom = math.min(bottom, bounds.maxY * u)
	end
	local px, py = round(left), round(top)
	local clip = Instance.new("Frame")
	clip.Name = "Arc"
	clip.BackgroundTransparency = 1
	clip.BorderSizePixel = 0
	clip.ClipsDescendants = true
	clip.Position = UDim2.fromOffset(px, py)
	clip.Size = UDim2.fromOffset(math.max(1, round(right) - px), math.max(1, round(bottom) - py))
	ring(ctx, cx, cy, r, role, clip, px, py)
	clip.Parent = ctx.root
end

-- Lingkaran penuh (titik mata, lubang label, dsb.).
local function disc(ctx: Ctx, cx: number, cy: number, r: number, role: Role?)
	local u = ctx.u
	local diameter = math.max(2, round(2 * r * u))
	local part = Instance.new("Frame")
	part.Name = "Dot"
	part.BorderSizePixel = 0
	local partRole: Role = role or "Ink"
	part.BackgroundColor3 = colorFor(ctx, partRole)
	part.Size = UDim2.fromOffset(diameter, diameter)
	part.Position = UDim2.fromOffset(round(cx * u - diameter / 2), round(cy * u - diameter / 2))
	setCorner(part, UDim.new(0.5, 0))
	part:SetAttribute("IconRole", partRole)
	part.Parent = ctx.root
end

-- Titik selebar bobot garis: membulatkan ujung busur yang terpotong datar.
local function cap(ctx: Ctx, x: number, y: number)
	disc(ctx, x, y, ctx.wu / 2)
end

-- Persegi panjang membulat (outline); x/y/lebar/tinggi/radius pada garis tengah stroke, dalam unit.
local function rrect(ctx: Ctx, x: number, y: number, width: number, height: number, radius: number)
	local u, w = ctx.u, ctx.w
	local px, py = round(x * u + w / 2), round(y * u + w / 2)
	local part = Instance.new("Frame")
	part.Name = "Box"
	part.BackgroundTransparency = 1
	part.BorderSizePixel = 0
	part.Position = UDim2.fromOffset(px, py)
	part.Size = UDim2.fromOffset(math.max(1, round((x + width) * u - w / 2) - px), math.max(1, round((y + height) * u - w / 2) - py))
	setCorner(part, UDim.new(0, math.max(0, radius * u - w / 2)))
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Thickness = w
	stroke.Color = ctx.ink
	stroke:SetAttribute("IconRole", "Ink")
	stroke.Parent = part
	part.Parent = ctx.root
end

-- Persegi panjang terisi, berpusat, bisa dirotasi (gigi roda gigi).
local function block(ctx: Ctx, cx: number, cy: number, width: number, height: number, radius: number, rotation: number)
	local u = ctx.u
	local part = Instance.new("Frame")
	part.Name = "Block"
	part.BorderSizePixel = 0
	part.BackgroundColor3 = ctx.ink
	part.AnchorPoint = Vector2.new(0.5, 0.5)
	part.Position = UDim2.fromOffset(cx * u, cy * u)
	part.Size = UDim2.fromOffset(width * u, height * u)
	part.Rotation = rotation
	setCorner(part, UDim.new(0, radius * u))
	part:SetAttribute("IconRole", "Ink")
	part.Parent = ctx.root
end

local function polyline(ctx: Ctx, points: { Vector2 }, closed: boolean)
	local count = #points
	for i = 1, count - 1 do
		local a, b = points[i], points[i + 1]
		line(ctx, a.X, a.Y, b.X, b.Y)
	end
	if closed and count > 2 then
		local a, b = points[count], points[1]
		line(ctx, a.X, a.Y, b.X, b.Y)
	end
end

-- Awan dari tiga busur (kiri, atas, kanan) + garis dasar; sambungan di titik singgung tepat.
local function cloud(ctx: Ctx, top: number, big: number, small: number)
	local centerY = top + big
	local leftX, rightX = 12 - big, 12 + big
	local bumpY = centerY + small
	local base = centerY + 2 * small
	arc(ctx, leftX, bumpY, small, { maxX = leftX })
	arc(ctx, 12, centerY, big, { maxY = centerY })
	arc(ctx, rightX, bumpY, small, { minX = rightX })
	line(ctx, leftX, base, rightX, base)
	cap(ctx, leftX, centerY)
	cap(ctx, rightX, centerY)
end

local DRAW: { [string]: (ctx: Ctx) -> () } = {}

-- Koin: cakram emas + cincin tepi + cincin dalam (koin cincin ganda), bukan huruf.
DRAW.coin = function(ctx)
	disc(ctx, 12, 12, 10, "Ink")
	ring(ctx, 12, 12, 10 - ctx.wu / 2, "Deep")
	ring(ctx, 12, 12, 4.6, "Deep")
end

-- Daun konservasi: lensa dari dua busur seperempat lingkaran + tulang daun yang menjadi tangkai.
DRAW.leaf = function(ctx)
	arc(ctx, 5, 5, 14, { minX = 5, minY = 5 })
	arc(ctx, 19, 19, 14, { maxX = 19, maxY = 19 })
	cap(ctx, 19, 5)
	cap(ctx, 5, 19)
	line(ctx, 3.5, 20.5, 13, 11)
end

DRAW.bag = function(ctx)
	rrect(ctx, 4, 8.5, 16, 12.5, 3)
	arc(ctx, 12, 8.5, 4, { maxY = 8.5 })
end

-- Ikan: badan lensa dari dua busur 120°, ekor segitiga, mata.
DRAW.fish = function(ctx)
	arc(ctx, 9.5, 15.75, 7.5, { maxY = 12 })
	arc(ctx, 9.5, 8.25, 7.5, { minY = 12 })
	cap(ctx, 3, 12)
	polyline(ctx, { Vector2.new(16, 12), Vector2.new(21, 8), Vector2.new(21, 16) }, true)
	disc(ctx, 7, 11, 1.15)
end

-- Buku terbuka: dua halaman bersudut membulat (lekuk di punggung) + baris teks.
DRAW.book = function(ctx)
	rrect(ctx, 2.5, 5, 9.5, 14, 2)
	rrect(ctx, 12, 5, 9.5, 14, 2)
	line(ctx, 5.5, 9.5, 9, 9.5)
	line(ctx, 5.5, 13, 9, 13)
	line(ctx, 15, 9.5, 18.5, 9.5)
	line(ctx, 15, 13, 18.5, 13)
end

-- Gulungan quest: dua gulungan kapsul, sisi kertas, baris teks.
DRAW.scroll = function(ctx)
	rrect(ctx, 4, 3.5, 16, 4.5, 2.25)
	rrect(ctx, 4, 16, 16, 4.5, 2.25)
	line(ctx, 6.5, 8, 6.5, 16)
	line(ctx, 17.5, 8, 17.5, 16)
	line(ctx, 9.5, 10.5, 14.5, 10.5)
	line(ctx, 9.5, 13.5, 13, 13.5)
end

DRAW.shirt = function(ctx)
	polyline(ctx, {
		Vector2.new(15.5, 3.5),
		Vector2.new(21, 6.5),
		Vector2.new(19.5, 11),
		Vector2.new(17, 10),
		Vector2.new(17, 20.5),
		Vector2.new(7, 20.5),
		Vector2.new(7, 10),
		Vector2.new(4.5, 11),
		Vector2.new(3, 6.5),
		Vector2.new(8.5, 3.5),
	}, false)
	arc(ctx, 12, 3.5, 3.5, { minY = 3.5 })
end

-- Roda gigi: cincin luar + lubang + 8 gigi padat (beda dari matahari yang sinarnya terlepas).
DRAW.gear = function(ctx)
	ring(ctx, 12, 12, 6.5)
	ring(ctx, 12, 12, 2.6)
	for i = 0, 7 do
		local angle = i * 45
		local rad = math.rad(angle)
		block(ctx, 12 + math.cos(rad) * 8.6, 12 + math.sin(rad) * 8.6, 3.6, 3.4, 0.8, angle)
	end
end

DRAW.clock = function(ctx)
	ring(ctx, 12, 12, 9)
	line(ctx, 12, 12, 12, 6.5)
	line(ctx, 12, 12, 16, 14)
end

DRAW.sun = function(ctx)
	ring(ctx, 12, 12, 4)
	for i = 0, 7 do
		local rad = math.rad(i * 45)
		local c, s = math.cos(rad), math.sin(rad)
		line(ctx, 12 + c * 7, 12 + s * 7, 12 + c * 9.5, 12 + s * 9.5)
	end
end

DRAW.cloud = function(ctx)
	cloud(ctx, 6, 5, 3.5)
end

DRAW.rain = function(ctx)
	cloud(ctx, 3.5, 4.5, 3)
	line(ctx, 8.5, 17, 7.5, 20.5)
	line(ctx, 12.5, 17, 11.5, 20.5)
	line(ctx, 16.5, 17, 15.5, 20.5)
end

DRAW.storm = function(ctx)
	cloud(ctx, 3.5, 4.5, 3)
	polyline(ctx, { Vector2.new(14, 12.5), Vector2.new(10, 17.5), Vector2.new(14.5, 17.5), Vector2.new(10.5, 22.5) }, false)
end

-- Bulan sabit: busur luar dan busur dalam dari dua lingkaran, dipotong tepat di titik potong keduanya.
DRAW.moon = function(ctx)
	local outerR, innerR, offset = 9, 8, 6
	local cutX = 14 + (outerR * outerR - innerR * innerR + offset * offset) / (2 * offset)
	local half = math.sqrt(outerR * outerR - (cutX - 14) ^ 2)
	arc(ctx, 14, 12, outerR, { maxX = cutX })
	arc(ctx, 14 + offset, 12, innerR, { maxX = cutX })
	cap(ctx, cutX, 12 - half)
	cap(ctx, cutX, 12 + half)
end

DRAW.star = function(ctx)
	local points: { Vector2 } = {}
	for k = 0, 9 do
		local radius = if k % 2 == 0 then 9.5 else 4.2
		local rad = math.rad(-90 + 36 * k)
		table.insert(points, Vector2.new(12 + math.cos(rad) * radius, 12.6 + math.sin(rad) * radius))
	end
	polyline(ctx, points, true)
end

DRAW.lock = function(ctx)
	rrect(ctx, 5, 10.5, 14, 10, 2.5)
	arc(ctx, 12, 7.5, 4, { maxY = 7.5 })
	line(ctx, 8, 7.5, 8, 10.5)
	line(ctx, 16, 7.5, 16, 10.5)
	disc(ctx, 12, 15, 1.4)
	line(ctx, 12, 15, 12, 17.2)
end

DRAW.close = function(ctx)
	line(ctx, 6, 6, 18, 18)
	line(ctx, 18, 6, 6, 18)
end

DRAW.check = function(ctx)
	polyline(ctx, { Vector2.new(4.5, 12.5), Vector2.new(9.5, 17.5), Vector2.new(19.5, 7) }, false)
end

DRAW.anchor = function(ctx)
	ring(ctx, 12, 4.8, 2)
	line(ctx, 12, 6.8, 12, 21)
	line(ctx, 8, 10.5, 16, 10.5)
	arc(ctx, 12, 13.5, 7.5, { minY = 13.5 })
	line(ctx, 2.5, 13.5, 4.5, 13.5)
	line(ctx, 19.5, 13.5, 21.5, 13.5)
end

-- Dua orang: kepala + bahu depan, kepala & bahu belakang sebagian.
DRAW.users = function(ctx)
	ring(ctx, 9, 8, 3.5)
	arc(ctx, 9, 20.5, 6, { maxY = 20.5 })
	arc(ctx, 16, 8, 3.5, { minX = 16 })
	arc(ctx, 16.5, 20.5, 5, { minX = 16.5, maxY = 20.5 })
end

-- Joran: batang diagonal, gulungan, senar, dan kail.
DRAW.rod = function(ctx)
	line(ctx, 4.5, 20.5, 19.5, 3.5)
	ring(ctx, 8.5, 16, 2.2)
	line(ctx, 19.5, 3.5, 19.5, 13)
	arc(ctx, 17.5, 13, 2, { minY = 13 })
	cap(ctx, 15.5, 13)
end

-- Umpan cacing: lekuk tiga busur bergantian + kepala.
DRAW.bait = function(ctx)
	arc(ctx, 6, 12, 3, { maxY = 12 })
	arc(ctx, 12, 12, 3, { minY = 12 })
	arc(ctx, 18, 12, 3, { maxY = 12 })
	cap(ctx, 3, 12)
	disc(ctx, 21, 12, 1.9)
end

-- Perahu layar (pinisi kecil): lambung trapesium, tiang, layar segitiga.
DRAW.boat = function(ctx)
	polyline(ctx, { Vector2.new(3, 15), Vector2.new(21, 15), Vector2.new(17.5, 19.5), Vector2.new(6.5, 19.5) }, true)
	line(ctx, 12, 15, 12, 3.5)
	polyline(ctx, { Vector2.new(12, 4), Vector2.new(18.5, 12.5), Vector2.new(12, 12.5) }, false)
end

DRAW.swap = function(ctx)
	line(ctx, 4, 8, 19.5, 8)
	polyline(ctx, { Vector2.new(16, 4.5), Vector2.new(19.5, 8), Vector2.new(16, 11.5) }, false)
	line(ctx, 20, 16, 4.5, 16)
	polyline(ctx, { Vector2.new(8, 12.5), Vector2.new(4.5, 16), Vector2.new(8, 19.5) }, false)
end

DRAW.alert = function(ctx)
	polyline(ctx, { Vector2.new(12, 3.5), Vector2.new(21.5, 19.5), Vector2.new(2.5, 19.5) }, true)
	line(ctx, 12, 9, 12, 13.5)
	disc(ctx, 12, 16.4, 1.2)
end

DRAW.info = function(ctx)
	ring(ctx, 12, 12, 9)
	disc(ctx, 12, 7.9, 1.2)
	line(ctx, 12, 11, 12, 16.5)
end

DRAW.chevron_left = function(ctx)
	polyline(ctx, { Vector2.new(15, 5), Vector2.new(8, 12), Vector2.new(15, 19) }, false)
end

DRAW.chevron_right = function(ctx)
	polyline(ctx, { Vector2.new(9, 5), Vector2.new(16, 12), Vector2.new(9, 19) }, false)
end

DRAW.chevron_up = function(ctx)
	polyline(ctx, { Vector2.new(5, 15.5), Vector2.new(12, 8.5), Vector2.new(19, 15.5) }, false)
end

DRAW.chevron_down = function(ctx)
	polyline(ctx, { Vector2.new(5, 8.5), Vector2.new(12, 15.5), Vector2.new(19, 8.5) }, false)
end

DRAW.plus = function(ctx)
	line(ctx, 12, 5, 12, 19)
	line(ctx, 5, 12, 19, 12)
end

DRAW.minus = function(ctx)
	line(ctx, 5, 12, 19, 12)
end

-- Jual: label harga bersudut dengan lubang tali (bahasa "kartu timbang" lapak ikan).
DRAW.sell = function(ctx)
	polyline(ctx, {
		Vector2.new(3.5, 3.5),
		Vector2.new(11.5, 3.5),
		Vector2.new(20.5, 12.5),
		Vector2.new(12.5, 20.5),
		Vector2.new(3.5, 11.5),
	}, true)
	disc(ctx, 7.5, 7.5, 1.6)
end

DRAW.trophy = function(ctx)
	line(ctx, 6.5, 4, 17.5, 4)
	line(ctx, 7, 4, 7, 9)
	line(ctx, 17, 4, 17, 9)
	arc(ctx, 12, 9, 5, { minY = 9 })
	arc(ctx, 7, 7.5, 2.5, { maxX = 7 })
	arc(ctx, 17, 7.5, 2.5, { minX = 17 })
	line(ctx, 12, 14, 12, 17.5)
	rrect(ctx, 8, 17.5, 8, 3, 1)
end

-- Peta lipat tiga panel.
DRAW.map = function(ctx)
	polyline(ctx, { Vector2.new(3, 6), Vector2.new(9, 4), Vector2.new(15, 6), Vector2.new(21, 4) }, false)
	polyline(ctx, { Vector2.new(3, 20), Vector2.new(9, 18), Vector2.new(15, 20), Vector2.new(21, 18) }, false)
	line(ctx, 3, 6, 3, 20)
	line(ctx, 9, 4, 9, 18)
	line(ctx, 15, 6, 15, 20)
	line(ctx, 21, 4, 21, 18)
end

-- Membuat ikon: Frame persegi transparan berisi bentuk. Warna default Theme.Color.Text; koin default emas.
function Icon.new(name: IconName, size: number, color: Color3?): Frame
	local ink = color or (if name == "coin" then Theme.Color.Coin else Theme.Color.Text)
	local root = Instance.new("Frame")
	root.Name = "Icon_" .. name
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.Size = UDim2.fromOffset(size, size)
	root:SetAttribute("IconName", name)
	local weight = weightFor(size)
	local ctx: Ctx = {
		root = root,
		u = size / GRID,
		w = weight,
		wu = weight / (size / GRID),
		ink = ink,
		deep = deepOf(ink),
	}
	local draw = DRAW[name]
	if draw then
		draw(ctx)
	else
		warn("[Icon] nama ikon tidak dikenal: " .. tostring(name))
	end
	return root
end

local function paint(part: Instance, color: Color3)
	if part:IsA("UIStroke") then
		part.Color = color
	elseif part:IsA("GuiObject") then
		part.BackgroundColor3 = color
	end
end

function Icon.SetColor(icon: Frame, color: Color3)
	local deep = deepOf(color)
	for _, part in icon:GetDescendants() do
		local role = part:GetAttribute("IconRole")
		if role == "Ink" then
			paint(part, color)
		elseif role == "Deep" then
			paint(part, deep)
		end
	end
end

-- Transparansi seluruh bentuk (mis. state nonaktif / terkunci).
function Icon.SetTransparency(icon: Frame, transparency: number)
	for _, part in icon:GetDescendants() do
		if part:GetAttribute("IconRole") ~= nil then
			if part:IsA("UIStroke") then
				part.Transparency = transparency
			elseif part:IsA("GuiObject") then
				part.BackgroundTransparency = transparency
			end
		end
	end
end

-- Segitiga terisi (indikator naik/turun): belah ketupat 45° yang dipotong separuh oleh Frame pemotong.
function Icon.Triangle(direction: "Up" | "Down", size: number, color: Color3?): Frame
	local height = math.max(2, round(size / 2))
	local root = Instance.new("Frame")
	root.Name = "Triangle" .. direction
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.ClipsDescendants = true
	root.Size = UDim2.fromOffset(size, height)
	local diamond = Instance.new("Frame")
	diamond.Name = "Shape"
	diamond.BorderSizePixel = 0
	diamond.BackgroundColor3 = color or Theme.Color.Text
	diamond.AnchorPoint = Vector2.new(0.5, 0.5)
	diamond.Position = if direction == "Up" then UDim2.fromScale(0.5, 1) else UDim2.fromScale(0.5, 0)
	local side = size / math.sqrt(2)
	diamond.Size = UDim2.fromOffset(side, side)
	diamond.Rotation = 45
	setCorner(diamond, UDim.new(0, math.max(1, size * 0.08)))
	diamond:SetAttribute("IconRole", "Ink")
	diamond.Parent = root
	return root
end

return Icon
