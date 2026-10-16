--!strict
-- Konfigurasi map Pantai Mancing Nusantara: semua angka, posisi, warna, dan anggaran part.
-- Koordinat (GDD Bagian 3): Y = 0 permukaan laut, +Z ke arah laut (selatan), −Z ke daratan (utara).
-- Satuan stud. Modul World lain hanya membaca dari sini; jangan menulis angka map di tempat lain.

export type Circle = { X: number, Z: number, R: number }
export type Ellipse = { X: number, Z: number, RX: number, RZ: number }
export type Rect = { MinX: number, MaxX: number, MinZ: number, MaxZ: number }
export type Bump = { X: number, Z: number, R: number, H: number }
export type Pad = { X: number, Z: number, RX: number, RZ: number, Y: number, Blend: number }
export type RockDef = { X: number, Z: number, R: number, Lift: number, Material: Enum.Material }
export type PathDef = { Name: string, Points: { Vector3 }, Width: number, Stepping: boolean }
export type ArrowDef = { Text: string, Toward: Vector3 }
export type SignpostDef = { Pos: Vector3, Arrows: { ArrowDef } }
export type AmbientDef = { Kind: string, Pos: Vector3, Radius: number, OnGround: boolean }
export type ZoneBox = { Id: string, Center: Vector3, Size: Vector3 }
export type NpcFallback = { Id: string, Pos: Vector3, Face: Vector3 }
export type PalmHero = { X: number, Z: number, Lean: Vector3, Height: number }
export type BoatDef = {
	Pos: Vector3,
	Face: Vector3,
	Top: Color3,
	Bottom: Color3,
	Mast: boolean,
	Paddle: boolean,
	Moored: boolean,
}
export type LoungerDef = { X: number, Z: number, Face: Vector3, NpcId: string }
export type UmbrellaSpot = { X: number, Z: number, Colors: { Color3 }, Tilt: number }

local rgb = Color3.fromRGB
local v3 = Vector3.new

local MapConfig = {}

-- Seed tetap: semua acak = Random.new(Seed + offset modul).
MapConfig.Seed = 20261016
MapConfig.SeedOffsets = {
	Terrain = 11,
	Plaza = 23,
	Pier = 37,
	Palms = 41,
	Mangroves = 53,
	Boats = 67,
	Pinisi = 71,
	Lighthouse = 83,
	BeachProps = 97,
	Underwater = 101,
	Zones = 113,
}

-- Anggaran part per modul (dicek & dicetak MapBuilder). Palms melebihi 22 part/pohon karena
-- spesifikasi bentuk (8 segmen batang + 7 pelepah × 3 segmen + 3 kelapa = 32); dikompensasi modul lain.
MapConfig.MaxParts = 6000
MapConfig.Budget = {
	Plaza = 900,
	Pier = 950,
	Palms = 1300,
	Mangroves = 360,
	Boats = 300,
	Pinisi = 160,
	Lighthouse = 120,
	BeachProps = 900,
	Underwater = 650,
	Zones = 120,
}

-- Palet dunia: netral hangat mendominasi; saturasi hanya pada benda yang dicat manusia
-- (perahu, payung, layar/bendera) dan karang.
MapConfig.Colors = {
	-- kayu & serat
	WoodDeck = rgb(170, 126, 84),
	WoodDeckAlt = rgb(152, 110, 72),
	WoodWeathered = rgb(158, 136, 108),
	WoodPost = rgb(112, 86, 60),
	WoodDark = rgb(92, 66, 46),
	WoodLight = rgb(198, 164, 116),
	Bamboo = rgb(196, 172, 104),
	BambooDark = rgb(150, 128, 72),
	Rope = rgb(196, 170, 122),
	RopeDark = rgb(110, 90, 64),
	Thatch = rgb(176, 146, 88),
	ThatchDark = rgb(140, 112, 64),
	Woven = rgb(184, 156, 108),
	-- tumbuhan
	PalmTrunk = rgb(142, 114, 84),
	PalmTrunkDark = rgb(116, 92, 66),
	PalmLeaf = rgb(82, 146, 64),
	PalmLeafDark = rgb(62, 118, 52),
	PalmLeafDry = rgb(156, 154, 78),
	Coconut = rgb(98, 118, 48),
	CoconutBrown = rgb(122, 86, 50),
	MangroveBark = rgb(98, 80, 64),
	MangroveRoot = rgb(112, 92, 72),
	MangroveLeaf = rgb(58, 112, 58),
	MangroveLeafLight = rgb(78, 132, 66),
	Bush = rgb(70, 128, 60),
	-- batu, logam, kaca
	Stone = rgb(150, 144, 134),
	StoneDark = rgb(104, 100, 96),
	Metal = rgb(122, 126, 130),
	MetalDark = rgb(64, 66, 70),
	Glass = rgb(206, 232, 236),
	LampGlass = rgb(255, 238, 200),
	LightWarm = rgb(255, 192, 122),
	Ice = rgb(214, 238, 246),
	Terracotta = rgb(186, 98, 62),
	-- kain
	Fabric = rgb(240, 228, 202),
	FabricShade = rgb(222, 208, 180),
	Tarp = rgb(72, 126, 168),
	TarpLight = rgb(120, 166, 196),
	-- aksen jenuh (hanya cat perahu, payung, bendera, karang)
	Red = rgb(212, 64, 56),
	Blue = rgb(38, 112, 194),
	Yellow = rgb(244, 196, 54),
	Teal = rgb(34, 168, 160),
	White = rgb(242, 240, 232),
	Orange = rgb(238, 130, 54),
	Pink = rgb(232, 116, 150),
	Green = rgb(72, 168, 92),
	FlagRed = rgb(206, 30, 38),
	FlagWhite = rgb(248, 248, 244),
	-- mercusuar
	LighthouseRed = rgb(194, 54, 46),
	LighthouseWhite = rgb(240, 236, 226),
	-- papan nama (teks terang + stroke gelap)
	SignBoard = rgb(96, 64, 42),
	SignText = rgb(255, 246, 226),
	SignStroke = rgb(36, 22, 14),
	LeaderBoard = rgb(15, 47, 58),
	-- bawah laut
	Coral = {
		rgb(255, 122, 110),
		rgb(255, 170, 80),
		rgb(182, 110, 204),
		rgb(250, 214, 92),
		rgb(92, 198, 190),
		rgb(236, 92, 132),
	},
	Seaweed = rgb(78, 150, 72),
	SeaweedDark = rgb(54, 110, 58),
	Starfish = { rgb(240, 120, 52), rgb(214, 70, 64), rgb(70, 120, 214), rgb(170, 96, 196) },
	Shell = { rgb(246, 226, 210), rgb(238, 182, 170), rgb(250, 240, 226), rgb(222, 196, 160) },
}

-- Teks dalam game (Bahasa Indonesia).
MapConfig.Text = {
	Welcome = "Selamat Datang di Pantai Nusantara",
	Market = "Pasar Pantai",
	Board = "PAPAN PENGUMUMAN",
	FishingShop = "TOKO PANCING",
	Bait = "UMPAN",
	Boutique = "BUTIK PANTAI",
	Research = "PONDOK RISET",
	Collector = "PENGEPUL IKAN",
	Barter = "BARTER",
	Ferry = "KAPAL KE LAUT DALAM",
	DeepSea = "PLATFORM LAUT DALAM",
	Lifeguard = "POS PENJAGA PANTAI",
	Coconut = "ES KELAPA MUDA",
	ToPier = "DERMAGA",
	ToLagoon = "LAGUNA BAKAU (Lv 5)",
	ToDeepSea = "KE LAUT DALAM",
}

MapConfig.FontFamily = "rbxasset://fonts/families/FredokaOne.json"

-- ===================================================================== Terrain
MapConfig.Terrain = {
	SeaHalf = 1200, -- laut X & Z ±1200
	SeaFloor = -60,
	BaseThickness = 12, -- lapisan pasir dasar di bawah −60
	FillTile = 600, -- ukuran ubin FillBlock air/dasar
	-- Wilayah yang ditulis voxel per chunk (selaras grid 4).
	RegionMin = v3(-544, -64, -416),
	RegionMax = v3(480, 32, 544),
	ChunkXZ = 64,
	ChunkY = 96,
	WaitEvery = 4, -- task.wait() tiap N chunk yang ditulis
	-- Garis pantai selatan: Z = Base + Curve·((x − CenterX)/200)² + noise + tonjolan tanjung & barat.
	Coast = {
		ShoreBase = 116,
		ShoreCurve = 8,
		ShoreCenterX = -20,
		ShoreNoiseAmp = 2.5,
		ShoreNoiseScale = 60,
		NorthBase = -215,
		NorthAmp = 12,
		NorthScale = 110,
		West = -352,
		East = 288,
		CornerSmooth = 30,
		CapeX = 222,
		CapeHalf = 52,
		CapeReach = 80,
		WestX = -255,
		WestHalf = 95,
		WestReach = 16,
	},
	-- Profil lereng bawah air (jarak dari garis pantai → tinggi).
	Sea = {
		ShelfDist = 80,
		ShelfY = -12,
		SlopeDist = 200,
		SlopeY = -40,
		DeepDist = 330,
		OtherSideScale = 0.5, -- sisi utara/barat/timur turun dua kali lebih cepat
		RippleAmp = 0.6,
	},
	Beach = {
		SandTop = 5, -- pasir Z 20 → 120 turun dari +5 ke 0
		WidthSouth = 100,
		WidthOther = 26,
		PlateauRise = 0.5,
		GrassBlend = 24,
	},
	Hills = {
		Height = 18.5, -- puncak ±24 (5,5 + 18,5)
		StartZ = -50,
		FullZ = -115,
		EdgeIn = 20,
		EdgeFull = 70,
		Scale = 95,
		RockAbove = 13,
	},
	-- Tanjung batu timur untuk mercusuar.
	Cape = {
		X = 224,
		Z = 160,
		RX = 54,
		RZ = 74,
		Base = 2,
		Top = 16,
		Rise = 16,
	},
	-- Area diratakan (plaza ≈ 5,5; lantai plaza di Y 6).
	Pads = {
		{ X = 0, Z = -10, RX = 50, RZ = 29, Y = 5.5, Blend = 14 },
		{ X = 0, Z = -40, RX = 12, RZ = 12, Y = 5.6, Blend = 10 },
		{ X = -60, Z = 0, RX = 12, RZ = 12, Y = 5.5, Blend = 10 },
	} :: { Pad },
	PlazaSand = { X = 0, Z = -8, RX = 82, RZ = 42 } :: Ellipse,
	-- Gumuk pasir (ditambahkan ke tinggi pasir).
	Dunes = {
		{ X = -170, Z = 62, R = 26, H = 1.4 },
		{ X = -205, Z = 100, R = 18, H = 0.9 },
		{ X = 60, Z = 40, R = 20, H = 0.9 },
		{ X = 130, Z = 60, R = 28, H = 1.6 },
		{ X = 170, Z = 95, R = 20, H = 1.0 },
		{ X = 80, Z = 92, R = 24, H = 1.6 }, -- gundukan pangkal dermaga
		{ X = -10, Z = 70, R = 16, H = 0.5 },
		{ X = 138, Z = 97, R = 18, H = 1.7 }, -- gundukan pangkal dermaga kapal
	} :: { Bump },
	Lagoon = {
		X = -250,
		Z = 40,
		RX = 60,
		RZ = 50,
		AvgR = 55,
		BedEdge = -2,
		BedCenter = -6,
		NoiseAmp = 0.07,
		MudTop = 0.7,
		MudWidth = 7,
		BankTop = 6,
		BankWidth = 26,
	},
	Canal = {
		Points = { v3(-246, 0, 78), v3(-242, 0, 100), v3(-236, 0, 120), v3(-230, 0, 142), v3(-225, 0, 166) },
		HalfWidth = 7,
		Bed = -3,
		Bank = 6,
		BankTop = 6,
	},
	Islet = { X = -264, Z = 26, R = 7, H = 0.8 } :: Bump,
	-- Batu besar (Terrain FillBall). Pusat Y = tinggi tanah + R × Lift.
	Rocks = {
		-- tanjung
		{ X = 246, Z = 196, R = 9, Lift = -0.15, Material = Enum.Material.Rock },
		{ X = 202, Z = 202, R = 7, Lift = -0.2, Material = Enum.Material.Basalt },
		{ X = 230, Z = 214, R = 8, Lift = -0.3, Material = Enum.Material.Slate },
		{ X = 252, Z = 168, R = 10, Lift = -0.35, Material = Enum.Material.Rock },
		{ X = 196, Z = 166, R = 6, Lift = -0.2, Material = Enum.Material.Basalt },
		{ X = 214, Z = 226, R = 9, Lift = -0.4, Material = Enum.Material.Rock },
		{ X = 240, Z = 228, R = 7, Lift = -0.3, Material = Enum.Material.Basalt },
		{ X = 188, Z = 140, R = 5, Lift = -0.2, Material = Enum.Material.Rock },
		-- tepi bukit
		{ X = -150, Z = -72, R = 8, Lift = -0.25, Material = Enum.Material.Rock },
		{ X = -95, Z = -86, R = 6, Lift = -0.2, Material = Enum.Material.Basalt },
		{ X = 62, Z = -74, R = 7, Lift = -0.25, Material = Enum.Material.Rock },
		{ X = 140, Z = -62, R = 9, Lift = -0.3, Material = Enum.Material.Rock },
		{ X = 196, Z = -24, R = 6, Lift = -0.2, Material = Enum.Material.Slate },
		{ X = -40, Z = -96, R = 7, Lift = -0.3, Material = Enum.Material.Rock },
		{ X = -210, Z = -40, R = 7, Lift = -0.3, Material = Enum.Material.Slate },
		-- pantai & karang dangkal
		{ X = -186, Z = 112, R = 3.5, Lift = -0.1, Material = Enum.Material.Rock },
		{ X = -60, Z = 124, R = 3.4, Lift = -0.25, Material = Enum.Material.Basalt },
		{ X = -110, Z = 160, R = 4, Lift = -0.3, Material = Enum.Material.Rock },
		{ X = 12, Z = 178, R = 3.2, Lift = -0.3, Material = Enum.Material.Rock },
		{ X = -320, Z = 72, R = 5, Lift = -0.2, Material = Enum.Material.Rock },
	} :: { RockDef },
	-- Rumpun semak terrain di tepi laguna (tanpa part).
	Bushes = {
		{ X = -308, Z = 30, R = 3.6, H = 1.6 },
		{ X = -300, Z = 66, R = 3.2, H = 1.4 },
		{ X = -282, Z = 92, R = 3.4, H = 1.4 },
		{ X = -215, Z = 92, R = 3.0, H = 1.3 },
		{ X = -196, Z = 70, R = 3.4, H = 1.5 },
		{ X = -194, Z = 8, R = 3.2, H = 1.5 },
		{ X = -226, Z = -14, R = 3.6, H = 1.6 },
		{ X = -262, Z = -16, R = 3.4, H = 1.6 },
		{ X = -296, Z = -2, R = 3.4, H = 1.5 },
	} :: { Bump },
	Water = {
		Color = rgb(26, 162, 166),
		Transparency = 0.55,
		Reflectance = 0.3,
		WaveSize = 0.12,
		WaveSpeed = 7,
	},
	MaterialColors = {
		{ Material = Enum.Material.Sand, Color = rgb(214, 192, 140) },
		{ Material = Enum.Material.Grass, Color = rgb(98, 152, 66) },
		{ Material = Enum.Material.LeafyGrass, Color = rgb(84, 138, 58) },
		{ Material = Enum.Material.Rock, Color = rgb(130, 122, 112) },
		{ Material = Enum.Material.Basalt, Color = rgb(86, 82, 80) },
		{ Material = Enum.Material.Slate, Color = rgb(112, 110, 106) },
		{ Material = Enum.Material.Mud, Color = rgb(112, 90, 66) },
		{ Material = Enum.Material.Ground, Color = rgb(150, 122, 86) },
	},
	Clouds = { Cover = 0.5, Density = 0.7, Color = rgb(255, 252, 246) },
}

-- ===================================================================== Plaza (Pasar Pantai)
MapConfig.Plaza = {
	Center = v3(0, 6, -10),
	FloorY = 6,
	RX = 46,
	RZ = 25,
	PlankWidth = 2.2,
	PlankGap = 0.12,
	PlankThickness = 0.7,
	PlankMaxLength = 22,
	-- Celah tepi papan (sudut parameter elips, derajat): utara, selatan, tenggara, barat daya, barat.
	Exits = { 270, 90, 49, 131, 157 },
	ExitHalfAngle = 9,
	LampAngles = { 20, 160, 205, 250, 290, 335 },
	LampHeight = 8.5,
	Board = { Pos = v3(0, 6, -20), Face = v3(0, 0, -1) },
	LurahSpot = { Pos = v3(-5.6, 6, -23.2), Face = v3(5.6, 0, -16.8) },
	Toko = { Pos = v3(-30, 6, -15), Face = v3(1, 0, -0.35) },
	Butik = { Pos = v3(30, 6, -15), Face = v3(-1, 0, -0.35) },
	Riset = { Pos = v3(-60, 6, 0), Face = v3(1, 0, -0.15), DeckRadius = 8.5 },
	Leaderboards = {
		{ Name = "Leaderboard_Heaviest", Pos = v3(-22, 6, 5), Face = v3(0.757, 0, -0.654) },
		{ Name = "Leaderboard_Coins", Pos = v3(22, 6, 5), Face = v3(-0.757, 0, -0.654) },
	},
	LeaderboardSize = v3(10, 7, 0.5),
	LeaderboardLift = 1.4, -- celah dari lantai ke tepi bawah papan
	Spawn = {
		Pos = v3(0, 7, -40),
		Size = v3(10, 1, 10),
		DaisRadius = 7.5,
		DaisTop = 7.45,
		RingRadius = 9.25,
		RingTop = 6.7,
	},
	Arch = { Z = -29, HalfSpan = 7.2, PostHeight = 13.4, SignBottom = 16, SignSize = v3(12.4, 2.6, 0.4) },
	Flagpole = { Pos = v3(0, 6, -3), Height = 19 },
	BuntingLamps = { 1, 2, 3, 6 }, -- indeks LampAngles yang diberi tali umbul-umbul
	BuntingFlags = 7,
}

-- ===================================================================== Dermaga & jalur
MapConfig.Pier = {
	X = 90,
	HalfWidth = 5,
	DeckY = 3,
	StemStartZ = 108,
	StemEndZ = 240,
	T = { MinX = 70, MaxX = 110, MinZ = 240, MaxZ = 260 },
	Root = { MinX = 66, MaxX = 95, MinZ = 86, MaxZ = 108 },
	PlankWidth = 1.5,
	PlankPitch = 1.65,
	PlankThickness = 0.55,
	PileSpacing = 12,
	PileDiameter = 1.1,
	PostAbove = 2.4, -- tiang pinggir menonjol di atas dek (tiang pagar tali)
	RopeHeight = 2.0,
	Lamps = {
		{ X = 94, Z = 128 },
		{ X = 86, Z = 164 },
		{ X = 94, Z = 188 },
		{ X = 86, Z = 224 },
		{ X = 72.4, Z = 257.6 },
		{ X = 107.6, Z = 257.6 },
	},
	-- Celah pagar (untuk nelayan & perahu tambat): {Side = −1 barat / 1 timur, Z}
	RailGaps = { { Side = -1, Z = 200 }, { Side = -1, Z = 152 }, { Side = 1, Z = 172 } },
	Barter = { Pos = v3(90, 3, 254), Size = v3(9, 0, 7), BenchX = 86.4 },
	Lapak = { Pos = v3(74, 3, 96), Face = v3(0.87, 0, -0.49) },
	Buckets = { v3(93.2, 3, 136), v3(87.0, 3, 214), v3(104, 3, 243) },
	Coils = { v3(87.2, 3, 166), v3(93.4, 3, 231), v3(74.5, 3, 256) },
	Jetty = { X = 140, HalfWidth = 3.5, MinZ = 100, MaxZ = 152, DeckY = 3 },
	Ferry = { Pos = v3(148.6, 0, 140), Face = v3(0, 0, 1) },
	JakaSpot = { Pos = v3(140, 3, 107.5), Face = v3(-0.6, 0, -0.8) },
	FerryArrivalShore = { Pos = v3(140, 6, 128), Face = v3(0, 0, -1) },
	DeepSea = {
		Center = v3(60, 4, 820),
		Apothem = 35,
		DeckY = 4,
		Hut = { Pos = v3(60, 4, 838), Size = v3(10, 0, 8) },
		Boat = { Pos = v3(60, 0, 779.4), Face = v3(-1, 0, 0) },
		Arrival = { Pos = v3(60, 7, 792), Face = v3(0, 0, 1) },
		AwakSpot = { Pos = v3(67, 4, 791), Face = v3(-1, 0, 0.25) },
	},
}

MapConfig.Paths = {
	-- Pasar (pintu tenggara) → pangkal dermaga
	{
		Name = "ToPier",
		Points = { v3(30, 0, 8.8), v3(40, 0, 30), v3(56, 0, 56), v3(70, 0, 74), v3(79, 0, 85.6) },
		Width = 5,
		Stepping = false,
	},
	-- Pasar (pintu barat daya) → area santai
	{
		Name = "ToBeach",
		Points = { v3(-30, 0, 8.8), v3(-44, 0, 26), v3(-62, 0, 40), v3(-84, 0, 50) },
		Width = 4.5,
		Stepping = false,
	},
	-- Cabang ke dermaga kapal
	{
		Name = "ToJetty",
		Points = { v3(68, 0, 72), v3(96, 0, 82), v3(118, 0, 92), v3(136.4, 0, 101.4) },
		Width = 4,
		Stepping = false,
	},
	-- Titian injak ke laguna
	{
		Name = "ToLagoon",
		Points = { v3(-88, 0, 50), v3(-104, 0, 34), v3(-124, 0, 26), v3(-152, 0, 20), v3(-174, 0, 26), v3(-182, 0, 33) },
		Width = 2.6,
		Stepping = true,
	},
} :: { PathDef }

MapConfig.Signposts = {
	{
		Pos = v3(0, 0, 18.6),
		Arrows = {
			{ Text = "DERMAGA", Toward = v3(80, 0, 92) },
			{ Text = "LAGUNA BAKAU (Lv 5)", Toward = v3(-186, 0, 31) },
		},
	},
	{
		Pos = v3(75.5, 0, 69),
		Arrows = {
			{ Text = "DERMAGA", Toward = v3(88, 0, 110) },
			{ Text = "KE LAUT DALAM", Toward = v3(140, 0, 104) },
		},
	},
	{
		Pos = v3(-92.5, 0, 45),
		Arrows = {
			{ Text = "LAGUNA BAKAU (Lv 5)", Toward = v3(-186, 0, 31) },
		},
	},
} :: { SignpostDef }

-- ===================================================================== Kelapa
MapConfig.Palms = {
	Count = 40,
	MinDist = 14,
	Attempts = 5000,
	Area = { MinX = -236, MaxX = 206, MinZ = -96, MaxZ = 113 } :: Rect,
	MinGround = 0.7,
	MaxGround = 17,
	PathMargin = 5,
	TrunkSegments = 8,
	Fronds = 7,
	Coconuts = 3,
	Hero = {
		{ X = -54, Z = -26, Lean = v3(0.45, 0, 1), Height = 27 },
		{ X = 55, Z = -24, Lean = v3(-0.35, 0, 1), Height = 25 },
		{ X = -63, Z = 21, Lean = v3(0.25, 0, 1), Height = 24 },
		{ X = 59, Z = 18, Lean = v3(0.3, 0, 1), Height = 26 },
		{ X = 24, Z = 47.5, Lean = v3(0.2, 0, 1), Height = 23 },
		{ X = -21, Z = -57, Lean = v3(-0.3, 0, 1), Height = 28 },
		{ X = 23, Z = -59, Lean = v3(0.35, 0, 1), Height = 26 },
		{ X = -142, Z = 90, Lean = v3(-0.6, 0, 1), Height = 22 },
		{ X = -133, Z = 93, Lean = v3(0.55, 0, 1), Height = 24 },
		{ X = -182, Z = 76, Lean = v3(-0.2, 0, 1), Height = 25 },
		{ X = 122, Z = 72, Lean = v3(0.3, 0, 1), Height = 26 },
		{ X = 166, Z = 92, Lean = v3(0.5, 0, 1), Height = 23 },
	} :: { PalmHero },
	-- Zona eksklusi (bangunan, jalur, properti, perahu)
	ExcludeEllipses = {
		{ X = 0, Z = -10, RX = 53, RZ = 32 },
		{ X = -250, Z = 40, RX = 74, RZ = 64 },
	} :: { Ellipse },
	ExcludeRects = {
		{ MinX = 60, MaxX = 100, MinZ = 80, MaxZ = 114 },
		{ MinX = 82, MaxX = 98, MinZ = 108, MaxZ = 262 },
		{ MinX = 128, MaxX = 160, MinZ = 94, MaxZ = 156 },
		{ MinX = -132, MaxX = -104, MinZ = 34, MaxZ = 50 },
		{ MinX = -250, MaxX = -218, MinZ = 70, MaxZ = 150 },
	} :: { Rect },
	ExcludeCircles = {
		{ X = 0, Z = -40, R = 13 },
		{ X = -60, Z = 0, R = 13 },
		{ X = -38, Z = 110, R = 10 },
		{ X = -13, Z = 112, R = 10 },
		{ X = 15, Z = 108, R = 10 },
		{ X = 15, Z = 40, R = 8 },
		{ X = -90, Z = 68, R = 9 },
		{ X = -101, Z = 58, R = 5 },
		{ X = -52, Z = 64, R = 9 },
		{ X = -124, Z = 73, R = 8 },
		{ X = -146, Z = 67, R = 8 },
		{ X = -66, Z = 85, R = 7 },
		{ X = -98, Z = 96, R = 5 },
		{ X = -172, Z = 121, R = 6 },
		{ X = -52, Z = 98, R = 5 },
		{ X = 0, Z = 18.6, R = 4 },
		{ X = 75.5, Z = 69, R = 4 },
		{ X = -92.5, Z = 45, R = 4 },
		{ X = 220, Z = 180, R = 16 },
		{ X = 37.5, Z = 14, R = 4 },
	} :: { Circle },
}

-- ===================================================================== Bakau
MapConfig.Mangroves = {
	-- Sudut (derajat) di elips laguna; X = cx + RX·d·cos, Z = cz + RZ·d·sin.
	RingAngles = { 30, 52, 118, 140, 163, 186, 209, 232, 255, 278, 302, 326 },
	RingD = { 0.98, 1.03, 0.97, 1.02, 0.96, 1.04, 0.99, 1.02, 0.97, 1.03, 0.98, 1.0 },
	Islet = { v3(-264, 0, 26) },
	Roots = 5,
	RootSegments = 3,
	Canopy = 3,
	Boardwalk = {
		From = v3(-177, 0, 35),
		To = v3(-224, 0, 37.5),
		Width = 3.2,
		DeckY = 1.6,
		PlankWidth = 1.25,
		PlankPitch = 1.42,
		Platform = { MinX = -232.5, MaxX = -224, MinZ = 33.5, MaxZ = 42 } :: Rect,
	},
	Bridge = { From = v3(-247, 0, 121.5), To = v3(-225, 0, 121.5), Width = 3.4, Rise = 2.4 },
	Nelayan4 = { Pos = v3(-231.4, 1.6, 38.6), Face = v3(-1, 0, 0) },
	Fireflies = {
		{ Kind = "Fireflies", Pos = v3(-276, 4, 18), Radius = 16, OnGround = false },
		{ Kind = "Fireflies", Pos = v3(-218, 4, 70), Radius = 14, OnGround = false },
		{ Kind = "Fireflies", Pos = v3(-292, 4, 62), Radius = 14, OnGround = false },
		{ Kind = "Fireflies", Pos = v3(-240, 3, 8), Radius = 12, OnGround = false },
	} :: { AmbientDef },
}

-- ===================================================================== Perahu
local C = MapConfig.Colors
MapConfig.Boats = {
	Jukung = {
		Length = 14,
		HalfBeam = 0.95,
		Freeboard = 1.0,
		BowRise = 0.9,
		SternRise = 0.7,
		KeelDepth = 0.4,
		FloatOffset = 4.6,
		FloatLength = 11,
	},
	List = {
		{
			Pos = v3(-38, 0, 110),
			Face = v3(0.1, 0, 1),
			Top = C.Blue,
			Bottom = C.White,
			Mast = true,
			Paddle = false,
			Moored = false,
		},
		{
			Pos = v3(-13, 0, 112),
			Face = v3(-0.15, 0, 1),
			Top = C.Red,
			Bottom = C.Yellow,
			Mast = false,
			Paddle = true,
			Moored = false,
		},
		{
			Pos = v3(15, 0, 108),
			Face = v3(0.2, 0, 1),
			Top = C.Teal,
			Bottom = C.White,
			Mast = true,
			Paddle = false,
			Moored = false,
		},
		{
			Pos = v3(76.6, 0, 152),
			Face = v3(0, 0, 1),
			Top = C.Yellow,
			Bottom = C.Blue,
			Mast = false,
			Paddle = true,
			Moored = true,
		},
		{
			Pos = v3(103.6, 0, 172),
			Face = v3(0, 0, -1),
			Top = C.Orange,
			Bottom = C.White,
			Mast = true,
			Paddle = false,
			Moored = true,
		},
	} :: { BoatDef },
	Bob = { Amplitude = 0.25, Speed = 0.9, Tilt = 2.5 },
}

MapConfig.Pinisi = {
	Pos = v3(-60, 0, 360),
	Face = v3(0.98, 0, 0.2),
	Length = 44,
	HalfBeam = 5.2,
	Freeboard = 4.2,
	BowRise = 2.8,
	SternRise = 5.0,
	KeelDepth = 3.0,
	Bob = { Amplitude = 0.35, Speed = 0.5, Tilt = 1.2 },
}

MapConfig.Lighthouse = {
	Pos = v3(220, 0, 180), -- Y dihitung dari tinggi tanah tanjung
	Height = 60,
	DoorFace = v3(-0.85, 0, -0.5),
	SpinSpeed = 36,
}

-- ===================================================================== Properti pantai
MapConfig.BeachProps = {
	Lifeguard = { Pos = v3(-90, 0, 68), Face = v3(0, 0, 1) },
	KakLautSpot = { Pos = v3(-85.6, 0, 59.4), Face = v3(0.45, 0, -0.9) },
	SurfRack = { Pos = v3(-101, 0, 58), Face = v3(0, 0, 1) },
	Campfire = { Pos = v3(-52, 0, 64) },
	Volley = { Pos = v3(-118, 0, 42), HalfX = 8, HalfZ = 4.4 },
	Umbrellas = {
		{ X = -124, Z = 71.4, Colors = { C.Red, C.White }, Tilt = 4 },
		{ X = -146, Z = 65.4, Colors = { C.Teal, C.White }, Tilt = -3 },
		{ X = -66.2, Z = 83, Colors = { C.Yellow, C.Orange }, Tilt = 3 },
	} :: { UmbrellaSpot },
	Loungers = {
		{ X = -127.2, Z = 74.6, Face = v3(0, 0, 1), NpcId = "wisatawan_1" },
		{ X = -120.8, Z = 74.6, Face = v3(0.05, 0, 1), NpcId = "" },
		{ X = -149.2, Z = 68.6, Face = v3(-0.05, 0, 1), NpcId = "" },
		{ X = -142.8, Z = 68.6, Face = v3(0, 0, 1), NpcId = "wisatawan_2" },
		{ X = -68.8, Z = 86, Face = v3(0.1, 0, 1), NpcId = "" },
	} :: { LoungerDef },
	Sandcastle = { Pos = v3(-98, 0, 96) },
	Cart = { Pos = v3(15, 0, 40), Face = v3(-0.35, 0, -1) },
	FishermanRock = { X = -172, Facing = v3(0, 0, 1) },
	NetRack = { Pos = v3(-52, 0, 98), Face = v3(1, 0, 0.1) },
	Hammock = { A = 8, B = 9, Height = 3.4 }, -- indeks Palms.Hero
	Driftwood = { v3(-186, 0, 104), v3(-70, 0, 109), v3(58, 0, 112), v3(150, 0, 112) },
	Crabs = { v3(-60, 0, 106), v3(176, 0, 118), v3(-206, 0, 104) },
	BoatGear = { v3(-30, 0, 104), v3(-24.5, 0, 103), v3(-4.5, 0, 105), v3(9.5, 0, 103) },
	ShoreBand = { MinX = -205, MaxX = 165, Count = 34 },
}

-- ===================================================================== Bawah laut
MapConfig.Underwater = {
	Areas = {
		{ MinX = -200, MaxX = 62, MinZ = 128, MaxZ = 206 },
		{ MinX = 60, MaxX = 132, MinZ = 150, MaxZ = 290 },
	} :: { Rect },
	MinDepth = 1.8,
	MaxDepth = 24,
	Clusters = { 12, 7 },
	SeaweedClumps = { 7, 4 },
	Starfish = { 8, 4 },
	Shells = { 14, 6 },
	Clams = { 2, 1 },
	Avoid = {
		{ MinX = 80, MaxX = 100, MinZ = 100, MaxZ = 266 },
		{ MinX = 64, MaxX = 116, MinZ = 234, MaxZ = 266 },
		{ MinX = 130, MaxX = 160, MinZ = 96, MaxZ = 156 },
		{ MinX = 66, MaxX = 88, MinZ = 140, MaxZ = 166 },
		{ MinX = 96, MaxX = 112, MinZ = 160, MaxZ = 186 },
		{ MinX = -252, MaxX = -214, MinZ = 120, MaxZ = 176 },
	} :: { Rect },
}

-- ===================================================================== Zona, penanda, ambient, batas
MapConfig.FishingZones = {
	{ Id = "Shore", Center = v3(-20, -8, 175), Size = v3(440, 24, 120) },
	{ Id = "Pier", Center = v3(90, -8, 255), Size = v3(110, 24, 90) },
	{ Id = "Mangrove", Center = v3(-250, -6, 58.5), Size = v3(136, 20, 153) },
	{ Id = "DeepSea", Center = v3(60, -8, 820), Size = v3(300, 24, 300) },
} :: { ZoneBox }

-- Urutan & cadangan posisi NPC (dipakai bila modul pembangun tidak mendaftarkan titik).
MapConfig.NpcIds = {
	"pak_lurah",
	"pak_darto",
	"mbak_sari",
	"bu_rina",
	"kakek_bahari",
	"nahkoda_jaka",
	"awak_kapal",
	"kak_laut",
	"prof_mina",
	"nelayan_1",
	"nelayan_2",
	"nelayan_3",
	"nelayan_4",
	"wisatawan_1",
	"wisatawan_2",
	"wisatawan_3",
	"penjual_es",
}
MapConfig.NpcFallback = {
	{ Id = "pak_lurah", Pos = v3(-5.6, 6, -23.2), Face = v3(0.3, 0, -1) },
	{ Id = "pak_darto", Pos = v3(-30, 6, -15), Face = v3(1, 0, -0.35) },
	{ Id = "mbak_sari", Pos = v3(30, 6, -15), Face = v3(-1, 0, -0.35) },
	{ Id = "bu_rina", Pos = v3(74, 3, 96), Face = v3(0.87, 0, -0.49) },
	{ Id = "kakek_bahari", Pos = v3(86.4, 4.6, 249.4), Face = v3(0, 0, -1) },
	{ Id = "nahkoda_jaka", Pos = v3(140, 3, 107.5), Face = v3(-0.6, 0, -0.8) },
	{ Id = "awak_kapal", Pos = v3(67, 4, 791), Face = v3(-1, 0, 0.25) },
	{ Id = "kak_laut", Pos = v3(-85.6, 2.6, 59.4), Face = v3(0.45, 0, -0.9) },
	{ Id = "prof_mina", Pos = v3(-60, 6, 0), Face = v3(1, 0, -0.15) },
	{ Id = "nelayan_1", Pos = v3(85.9, 3, 200), Face = v3(-1, 0, 0) },
	{ Id = "nelayan_2", Pos = v3(109.2, 3, 245.5), Face = v3(1, 0, 0) },
	{ Id = "nelayan_3", Pos = v3(-171, 0.8, 121.6), Face = v3(0, 0, 1) },
	{ Id = "nelayan_4", Pos = v3(-231.4, 1.6, 38.6), Face = v3(-1, 0, 0) },
	{ Id = "wisatawan_1", Pos = v3(-127.2, 3.2, 74.6), Face = v3(0, 0, 1) },
	{ Id = "wisatawan_2", Pos = v3(-142.8, 3.4, 68.6), Face = v3(0, 0, 1) },
	{ Id = "wisatawan_3", Pos = v3(-52, 4.5, 59), Face = v3(0, 0, 1) },
	{ Id = "penjual_es", Pos = v3(16, 4, 42.4), Face = v3(-0.35, 0, -1) },
} :: { NpcFallback }

MapConfig.Ambient = {
	{ Kind = "Seagulls", Pos = v3(40, 30, 150), Radius = 70, OnGround = false },
	{ Kind = "Seagulls", Pos = v3(-120, 26, 100), Radius = 60, OnGround = false },
	{ Kind = "Seagulls", Pos = v3(220, 45, 200), Radius = 40, OnGround = false },
	{ Kind = "Seagulls", Pos = v3(-60, 32, 360), Radius = 45, OnGround = false },
	{ Kind = "Seagulls", Pos = v3(60, 28, 820), Radius = 60, OnGround = false },
	{ Kind = "Crabs", Pos = v3(-70, 0, 104), Radius = 18, OnGround = true },
	{ Kind = "Crabs", Pos = v3(40, 0, 104), Radius = 16, OnGround = true },
	{ Kind = "Crabs", Pos = v3(176, 0, 112), Radius = 12, OnGround = true },
	{ Kind = "Crabs", Pos = v3(-206, 0, 100), Radius = 12, OnGround = true },
	{ Kind = "FishSchool", Pos = v3(-40, -4, 160), Radius = 14, OnGround = false },
	{ Kind = "FishSchool", Pos = v3(120, -6, 205), Radius = 14, OnGround = false },
	{ Kind = "FishSchool", Pos = v3(60, -8, 285), Radius = 18, OnGround = false },
	{ Kind = "FishSchool", Pos = v3(-250, -2.5, 45), Radius = 12, OnGround = false },
	{ Kind = "FishSchool", Pos = v3(60, -12, 862), Radius = 24, OnGround = false },
} :: { AmbientDef }

MapConfig.Boundary = {
	Radius = 1150,
	Segments = 48,
	Bottom = -80,
	Top = 150,
	Thickness = 8,
}

-- ===================================================================== Cahaya
MapConfig.Lighting = {
	ClockTime = 14,
	GeographicLatitude = -7,
	Brightness = 2.4,
	Ambient = rgb(92, 84, 74),
	OutdoorAmbient = rgb(148, 136, 118),
	EnvironmentDiffuseScale = 0.55,
	EnvironmentSpecularScale = 0.6,
	ShadowSoftness = 0.25,
	ExposureCompensation = 0,
	Atmosphere = {
		Density = 0.3,
		Offset = 0.22,
		Color = rgb(214, 196, 168),
		Decay = rgb(122, 150, 168),
		Glare = 0.25,
		Haze = 1.5,
	},
	Bloom = { Intensity = 0.32, Size = 22, Threshold = 1.55 },
	SunRays = { Intensity = 0.035, Spread = 0.55 },
	ColorCorrection = { Brightness = 0.02, Contrast = 0.06, Saturation = 0.1, TintColor = rgb(255, 246, 232) },
}

return MapConfig
