--!strict
-- Resep barter Kakek Bahari (GDD 4.4). Server memilih ikan bernilai terendah yang memenuhi syarat
-- (tidak terkunci, bukan Protected bila ExcludeProtected) lalu menampilkan daftarnya sebelum konfirmasi.

local Types = require(script.Parent.Parent.Types)

type BarterRecipe = Types.BarterRecipe

local list: { BarterRecipe } = {
	{
		Id = "barter_umpan_emas",
		Name = "3 Umpan Emas",
		Description = "Tukar 5 ikan Langka apa saja.",
		Rarity = "Rare",
		Count = 5,
		ExcludeProtected = true,
		GiveBait = "emas",
		GiveBaitQty = 3,
		Order = 1,
	},
	{
		Id = "barter_joran_emas",
		Name = "Joran Emas Bahari",
		Description = "Tukar 1 ikan Epik + 2.000 koin. Sekali per akun, butuh Lv 20.",
		Rarity = "Epic",
		Count = 1,
		Coins = 2000,
		Level = 20,
		Once = true,
		ExcludeProtected = true,
		GiveRod = "emas_bahari",
		Order = 2,
	},
	{
		Id = "barter_topi_tua",
		Name = "Topi Nelayan Tua",
		Description = "Tukar 10 ikan Tak Biasa. Topi eksklusif.",
		Rarity = "Uncommon",
		Count = 10,
		ExcludeProtected = true,
		GiveCosmetic = "topi_nelayan_tua",
		Order = 3,
	},
	{
		Id = "barter_aura_samudra",
		Name = "Aura Cahaya Samudra",
		Description = "Tukar 1 ikan Legenda (bukan yang dilindungi). Aura eksklusif.",
		Rarity = "Legendary",
		Count = 1,
		ExcludeProtected = true,
		GiveCosmetic = "aura_cahaya_samudra",
		Order = 4,
	},
}

local byId: { [string]: BarterRecipe } = {}
for _, r in list do
	byId[r.Id] = r
end

local Barter = {}
Barter.List = list
Barter.ById = byId

return Barter
