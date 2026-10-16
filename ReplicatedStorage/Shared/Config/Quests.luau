--!strict
-- Quest cerita (berurutan, dari Pak Lurah) dan pool quest harian (GDD 4.6).
-- Objective yang bersifat "absolut" (DiscoverSpecies) dihitung dari total Fishdex, sisanya bertambah sejak diterima.

local Types = require(script.Parent.Parent.Types)

type QuestDef = Types.QuestDef
type DailyQuestDef = Types.DailyQuestDef

local story: { QuestDef } = {
	{
		Id = "selamat_datang",
		Title = "Selamat Datang",
		Description = "Bicara dengan Pak Lurah di papan pengumuman plaza.",
		Objective = { Type = "TalkNpc", Npc = "pak_lurah", Count = 1 },
		Reward = { Coins = 50 },
	},
	{
		Id = "umpan_pertama",
		Title = "Umpan Pertama",
		Description = "Beli 5 Cacing di Toko Pancing Pak Darto.",
		Objective = { Type = "BuyBait", Bait = "cacing", Count = 5 },
		Reward = { Coins = 20, XP = 10 },
	},
	{
		Id = "tangkapan_perdana",
		Title = "Tangkapan Perdana",
		Description = "Tangkap 3 ikan di mana saja.",
		Objective = { Type = "CatchFish", Count = 3 },
		Reward = { Coins = 50, XP = 30 },
	},
	{
		Id = "rezeki_nelayan",
		Title = "Rezeki Nelayan",
		Description = "Jual ikan senilai total 100 koin ke Bu Rina.",
		Objective = { Type = "SellCoins", Npc = "bu_rina", Count = 100 },
		Reward = { Coins = 60 },
	},
	{
		Id = "gaya_pantai",
		Title = "Gaya Pantai",
		Description = "Beli 1 kosmetik di Butik Pantai Mbak Sari.",
		Objective = { Type = "BuyCosmetic", Count = 1 },
		Reward = { Coins = 100, Title = "title_anak_pantai" },
	},
	{
		Id = "ujung_dermaga",
		Title = "Ujung Dermaga",
		Description = "Tangkap 1 ikan di zona Ujung Dermaga.",
		Objective = { Type = "CatchInZone", Zone = "Pier", Count = 1 },
		Reward = { Coins = 80, XP = 50 },
	},
	{
		Id = "peneliti_muda",
		Title = "Peneliti Muda",
		Description = "Temukan 8 spesies berbeda untuk Fishdex Prof. Mina.",
		Objective = { Type = "DiscoverSpecies", Count = 8 },
		Reward = { Coins = 300 },
	},
	{
		Id = "bakau_misterius",
		Title = "Bakau Misterius",
		Description = "Tangkap 3 ikan di Laguna Bakau.",
		Objective = { Type = "CatchInZone", Zone = "Mangrove", Count = 3 },
		Reward = { Coins = 400 },
		Level = 5,
	},
	{
		Id = "mengarungi_samudra",
		Title = "Mengarungi Samudra",
		Description = "Naik kapal Nahkoda Jaka ke Laut Dalam.",
		Objective = { Type = "Ferry", Destination = "DeepSea", Count = 1 },
		Reward = { Coins = 200 },
		Level = 10,
	},
	{
		Id = "penjaga_laut",
		Title = "Penjaga Laut",
		Description = "Lepaskan 1 ikan yang dilindungi.",
		Objective = { Type = "ReleaseProtected", Count = 1 },
		Reward = { ConservationPoints = 50 },
	},
	{
		Id = "sang_legenda",
		Title = "Sang Legenda",
		Description = "Tangkap 1 ikan Legenda.",
		Objective = { Type = "CatchRarity", Rarity = "Legendary", Count = 1 },
		Reward = { Coins = 3000, Title = "title_pemburu_legenda" },
	},
}

local daily: { DailyQuestDef } = {
	{ Id = "d_catch15", Title = "Tangkap 15 ikan", Objective = { Type = "CatchFish", Count = 15 } },
	{ Id = "d_rare3", Title = "Tangkap 3 ikan Langka atau lebih tinggi", Objective = { Type = "CatchRarityAtLeast", Rarity = "Rare", Count = 3 } },
	{ Id = "d_sell1000", Title = "Jual ikan senilai 1.000 koin", Objective = { Type = "SellCoins", Count = 1000 } },
	{ Id = "d_heavy10", Title = "Tangkap ikan seberat 10 kg atau lebih", Objective = { Type = "CatchWeightAtLeast", Weight = 10, Count = 1 } },
	{ Id = "d_night5", Title = "Tangkap 5 ikan saat malam", Objective = { Type = "CatchAtNight", Count = 5 } },
	{ Id = "d_bait10", Title = "Pakai 10 umpan", Objective = { Type = "UseBait", Count = 10 } },
	{ Id = "d_release2", Title = "Lepaskan 2 ikan", Objective = { Type = "ReleaseFish", Count = 2 } },
	{ Id = "d_mutated1", Title = "Tangkap 1 ikan bermutasi", Objective = { Type = "CatchMutated", Count = 1 } },
}

local dailyById: { [string]: DailyQuestDef } = {}
for _, d in daily do
	dailyById[d.Id] = d
end

local Quests = {}
Quests.Story = story
Quests.Daily = daily
Quests.DailyById = dailyById

function Quests.StoryAt(index: number): QuestDef?
	return story[index]
end

return Quests
