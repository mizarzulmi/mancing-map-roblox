--!strict
-- Semua angka gameplay. Nilai awal mengikuti GDD 4.2; perubahan lewat BalanceSim dicatat di docs/PROGRESS.md.

local Types = require(script.Parent.Parent.Types)

type Rarity = Types.Rarity
type Mutation = Types.Mutation
type WeatherId = Types.WeatherId
type EventId = Types.EventId

local Balance = {}

-- Awal pemain baru
Balance.StartCoins = 50
Balance.StartRod = "bambu"
Balance.StartBagCapacity = 20
Balance.StartCosmetics = { "rodskin_kayu", "bobber_merah_putih" }

-- Rarity (GDD 4.2)
Balance.RarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" } :: { Rarity }
Balance.RarityRank = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6 } :: { [string]: number }
Balance.RarityLabel = {
	Common = "Biasa",
	Uncommon = "Tak Biasa",
	Rare = "Langka",
	Epic = "Epik",
	Legendary = "Legenda",
	Mythic = "Mitos",
} :: { [string]: string }
Balance.RarityBaseWeight = {
	Common = 600,
	Uncommon = 250,
	Rare = 100,
	Epic = 38,
	Legendary = 10,
	Mythic = 2,
} :: { [string]: number }
Balance.RarityLuckExponent = {
	Common = 0,
	Uncommon = 0.5,
	Rare = 1,
	Epic = 1.5,
	Legendary = 2,
	Mythic = 2.5,
} :: { [string]: number }

-- Berat = min + (max - min) * r^WeightExponent
Balance.WeightExponent = 2.2

-- Mutasi (peluang dasar per tangkapan)
Balance.MutationOrder = { "Pelangi", "Emas", "Albino", "Berkilau" } :: { Mutation }
Balance.MutationChance = {
	Berkilau = 0.04,
	Albino = 0.012,
	Emas = 0.006,
	Pelangi = 0.002,
} :: { [string]: number }
Balance.MutationPriceMul = {
	None = 1,
	Berkilau = 2,
	Albino = 3,
	Emas = 5,
	Pelangi = 10,
} :: { [string]: number }
Balance.MutationXPMul = {
	None = 1,
	Berkilau = 1.5,
	Albino = 2,
	Emas = 3,
	Pelangi = 5,
} :: { [string]: number }

-- Harga jual = round(base * (berat / rata-rata)^SellWeightExponent * mutasi * event); rata-rata = (min+max)/2
Balance.SellWeightExponent = 0.75

-- XP
Balance.XPByRarity = {
	Common = 5,
	Uncommon = 12,
	Rare = 30,
	Epic = 80,
	Legendary = 200,
	Mythic = 600,
} :: { [string]: number }
Balance.XPCurveBase = 40
Balance.XPCurveExponent = 1.35
Balance.MaxLevel = 50
Balance.LevelUpCoinsPerLevel = 25

-- Konservasi (melepas ikan)
Balance.ConservationByRarity = {
	Common = 0,
	Uncommon = 1,
	Rare = 3,
	Epic = 8,
	Legendary = 20,
	Mythic = 50,
} :: { [string]: number }

-- Memancing (GDD 4.1)
Balance.Fishing = {
	CastMinDistance = 8,
	CastCooldown = 1.0,
	FlightTimeMin = 0.45,
	FlightTimeMax = 1.1,
	RaycastAbove = 40,
	RaycastDepth = 140,
	WaitMin = 4,
	WaitMax = 11,
	NoBaitWaitMul = 1.15,
	BiteWindow = 1.5,
	BiteTolerance = 0.5,
	FakeBitesMax = 2,
	ReelStart = 0.30,
	ReelGain = 0.35,
	ReelLoss = 0.25,
	HardLossMul = 2,
	ReelTimeLimit = 25,
	ReelTimeTolerance = 2,
	MinDurationFactor = 0.9,
	-- Batal bila pemain menjauh lebih dari (jarak lempar joran + nilai ini) dari pelampung.
	CancelExtraDistance = 14,
	-- Batas waktu keadaan Casting+Waiting sebelum sesi dianggap kedaluwarsa.
	SessionMaxSeconds = 60,
}

-- Cuaca (GDD 4.7)
Balance.WeatherOrder = { "Cerah", "Berawan", "Hujan", "Badai" } :: { WeatherId }
Balance.WeatherChance = { Cerah = 0.55, Berawan = 0.25, Hujan = 0.15, Badai = 0.05 } :: { [string]: number }
Balance.WeatherLuck = { Cerah = 0, Berawan = 0, Hujan = 0.1, Badai = 0.2 } :: { [string]: number }
Balance.WeatherWaitMul = { Cerah = 1, Berawan = 1, Hujan = 0.95, Badai = 0.9 } :: { [string]: number }
Balance.WeatherDurationMin = 240
Balance.WeatherDurationMax = 480
Balance.WeatherLabel = { Cerah = "Cerah", Berawan = "Berawan", Hujan = "Hujan", Badai = "Badai" } :: { [string]: string }

-- Event acak (GDD 4.7)
Balance.EventOrder = { "JamEmas", "MusimIkan", "BulanPurnama" } :: { EventId }
Balance.EventIntervalMin = 25 * 60
Balance.EventIntervalMax = 35 * 60
Balance.EventWeight = { JamEmas = 1, MusimIkan = 1, BulanPurnama = 1 } :: { [string]: number }
Balance.EventDuration = { JamEmas = 600, MusimIkan = 600, BulanPurnama = 420 } :: { [string]: number }
Balance.EventMutationMul = { JamEmas = 2 } :: { [string]: number }
Balance.EventPriceMul = { MusimIkan = 1.25 } :: { [string]: number }
Balance.EventZoneLuck = { BulanPurnama = { Mangrove = 0.3 } } :: { [string]: { [string]: number } }
Balance.EventNightOnly = { BulanPurnama = true } :: { [string]: boolean }
Balance.EventLabel = {
	None = "",
	JamEmas = "Jam Emas",
	MusimIkan = "Musim Ikan",
	BulanPurnama = "Bulan Purnama",
} :: { [string]: string }
Balance.EventDescription = {
	JamEmas = "Peluang mutasi ×2",
	MusimIkan = "Harga jual +25%",
	BulanPurnama = "Ikan Kristal Bulan muncul · Luck Laguna +0,3",
} :: { [string]: string }

-- Siang–malam
Balance.DayLengthSeconds = 15 * 60
Balance.StartClockTime = 14
Balance.NightStart = 18.5
Balance.NightEnd = 5.5

-- Ekonomi & inventaris
Balance.BaitMaxStack = 999
Balance.BaitBuyOptions = { 1, 10, 50 }
Balance.CoinLogSize = 30
Balance.TradeLogSize = 20
Balance.NpcInteractRange = 20
Balance.NpcPromptDistance = 10

-- Quest harian
Balance.DailyCount = 3
Balance.DailyCoinBase = 100
Balance.DailyCoinPerLevel = 20
Balance.DailyXPBase = 50
Balance.DailyXPPerLevel = 10
Balance.WibOffsetSeconds = 7 * 3600

-- Trade (GDD 4.5)
Balance.Trade = {
	InviteRange = 30,
	InviteExpire = 20,
	InviteCooldown = 10,
	MaxFish = 8,
	CancelDistance = 50,
	CountdownSeconds = 5,
	ImbalanceRatio = 1.5,
	MaxCoins = 10000000,
}

-- Kapal
Balance.Ferry = {
	Price = 150,
	Level = 10,
	FadeSeconds = 0.6,
	TravelSeconds = 1.4,
}

-- Papan peringkat
Balance.Leaderboard = {
	RefreshSeconds = 300,
	Top = 10,
}

-- Data
Balance.AutoSaveSeconds = 60
Balance.DataStoreName = "PantaiMancingNusantara_v1"

-- Dunia
Balance.WorldRadius = 1150

return Balance
