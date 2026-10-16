--!strict
-- Kosmetik (GDD Bagian 5). Semua model prosedural (Shared/Models/CosmeticModels.luau) berdasarkan Style.
-- Source: Starter (awal), Shop (Mbak Sari, koin), Points (Kak Laut, Poin Konservasi), Barter, Quest, Achievement, Fishdex.

local Types = require(script.Parent.Parent.Types)

type CosmeticDef = Types.CosmeticDef

local rgb = Color3.fromRGB

local list: { CosmeticDef } = {
	-- Topi
	{ Id = "topi_jerami", Name = "Topi Jerami", Slot = "Hat", Price = 250, Source = "Shop", Order = 1,
		Description = "Topi anyaman lebar, teduh di bawah terik.", Style = "Straw",
		Colors = { rgb(226, 196, 120), rgb(160, 60, 50) } },
	{ Id = "caping", Name = "Caping", Slot = "Hat", Price = 400, Source = "Shop", Order = 2,
		Description = "Caping bambu khas petani dan nelayan.", Style = "Caping",
		Colors = { rgb(214, 182, 112), rgb(150, 112, 62) } },
	{ Id = "bandana", Name = "Bandana Bajak Laut", Slot = "Hat", Price = 600, Source = "Shop", Order = 3,
		Description = "Ikat kepala merah bertotol, gaya penjelajah.", Style = "Bandana",
		Colors = { rgb(190, 46, 46), rgb(245, 240, 230) } },
	{ Id = "topi_kapten", Name = "Topi Kapten", Slot = "Hat", Price = 1200, Source = "Shop", Order = 4,
		Description = "Putih bersih dengan lencana jangkar emas.", Style = "Captain",
		Colors = { rgb(245, 245, 240), rgb(24, 40, 72), rgb(242, 193, 78) } },
	{ Id = "mahkota_kerang", Name = "Mahkota Kerang", Slot = "Hat", Price = 5000, Source = "Shop", Order = 5,
		Description = "Mahkota mutiara dan kerang dari dasar laut.", Style = "ShellCrown",
		Colors = { rgb(255, 214, 220), rgb(242, 193, 78), rgb(250, 248, 240) } },
	{ Id = "topi_nelayan_tua", Name = "Topi Nelayan Tua", Slot = "Hat", Source = "Barter", Order = 6,
		Description = "Topi lusuh kesayangan Kakek Bahari. Eksklusif barter.", Style = "OldFisher",
		Colors = { rgb(92, 84, 70), rgb(60, 52, 44) } },
	{ Id = "topi_ranger", Name = "Topi Ranger", Slot = "Hat", PointsPrice = 60, Source = "Points", Order = 7,
		Description = "Topi penjaga laut. Ditukar dengan Poin Konservasi.", Style = "Ranger",
		Colors = { rgb(110, 120, 70), rgb(70, 76, 44) } },

	-- Aksesori
	{ Id = "kacamata_hitam", Name = "Kacamata Hitam", Slot = "Accessory", Price = 350, Source = "Shop", Order = 1,
		Description = "Silau pantai? Bukan masalah.", Style = "Sunglasses",
		Colors = { rgb(20, 22, 26), rgb(200, 170, 90) } },
	{ Id = "kalung_kerang", Name = "Kalung Kerang", Slot = "Accessory", Price = 450, Source = "Shop", Order = 2,
		Description = "Untaian kerang putih dari pantai sendiri.", Style = "ShellNecklace",
		Colors = { rgb(250, 244, 230), rgb(150, 110, 70) } },
	{ Id = "rompi_pelampung", Name = "Rompi Pelampung", Slot = "Accessory", Price = 900, Source = "Shop", Order = 3,
		Description = "Oranye terang, keselamatan nomor satu.", Style = "LifeVest",
		Colors = { rgb(255, 122, 40), rgb(240, 240, 235) } },
	{ Id = "ransel_ikan", Name = "Ransel Ikan", Slot = "Accessory", Price = 1800, Source = "Shop", Order = 4,
		Description = "Ransel berbentuk ikan kembung. Lucu dan muat banyak.", Style = "FishBackpack",
		Colors = { rgb(61, 110, 143), rgb(220, 230, 236) } },

	-- Skin joran
	{ Id = "rodskin_kayu", Name = "Kayu Klasik", Slot = "RodSkin", Source = "Starter", Order = 1,
		Description = "Warna asli joran. Sederhana dan hangat.", Style = "Wood", Colors = {} },
	{ Id = "rodskin_neon", Name = "Neon Biru", Slot = "RodSkin", Price = 800, Source = "Shop", Order = 2,
		Description = "Garis neon biru yang menyala lembut.", Style = "Neon",
		Colors = { rgb(30, 40, 60), rgb(80, 200, 255) } },
	{ Id = "rodskin_loreng", Name = "Loreng Pantai", Slot = "RodSkin", Price = 1500, Source = "Shop", Order = 3,
		Description = "Belang pasir dan laut.", Style = "Camo",
		Colors = { rgb(226, 196, 120), rgb(43, 179, 177), rgb(245, 240, 230) } },
	{ Id = "rodskin_emas", Name = "Emas", Slot = "RodSkin", Price = 6000, Source = "Shop", Order = 4,
		Description = "Berkilau seperti matahari sore.", Style = "Gold",
		Colors = { rgb(232, 182, 72), rgb(255, 236, 170) } },
	{ Id = "rodskin_pelangi", Name = "Pelangi", Slot = "RodSkin", Price = 12000, Source = "Shop", Order = 5,
		Description = "Warnanya terus berganti.", Style = "Rainbow", Colors = {} },

	-- Pelampung
	{ Id = "bobber_merah_putih", Name = "Merah Putih", Slot = "Bobber", Source = "Starter", Order = 1,
		Description = "Pelampung klasik, merah di atas, putih di bawah.", Style = "RedWhite",
		Colors = { rgb(214, 48, 49), rgb(245, 245, 240) } },
	{ Id = "bobber_bebek", Name = "Bebek Kuning", Slot = "Bobber", Price = 300, Source = "Shop", Order = 2,
		Description = "Bebek karet yang setia menunggu ikan.", Style = "Duck",
		Colors = { rgb(255, 214, 64), rgb(255, 140, 40) } },
	{ Id = "bobber_bintang", Name = "Bintang Laut", Slot = "Bobber", Price = 500, Source = "Shop", Order = 3,
		Description = "Bintang laut oranye mengapung.", Style = "Starfish",
		Colors = { rgb(255, 140, 70), rgb(255, 200, 150) } },
	{ Id = "bobber_semangka", Name = "Semangka", Slot = "Bobber", Price = 700, Source = "Shop", Order = 4,
		Description = "Segar! Hijau loreng dengan isi merah.", Style = "Watermelon",
		Colors = { rgb(60, 150, 70), rgb(230, 60, 70), rgb(30, 90, 40) } },
	{ Id = "bobber_bola_api", Name = "Bola Api", Slot = "Bobber", Price = 2500, Source = "Shop", Order = 5,
		Description = "Menyala di atas air, bahkan saat hujan.", Style = "Fireball",
		Colors = { rgb(255, 120, 30), rgb(255, 220, 90) } },
	{ Id = "bobber_karang", Name = "Karang", Slot = "Bobber", PointsPrice = 40, Source = "Points", Order = 6,
		Description = "Pelampung bercabang dari karang daur ulang.", Style = "Coral",
		Colors = { rgb(255, 120, 140), rgb(255, 190, 160) } },

	-- Jejak
	{ Id = "trail_gelembung", Name = "Gelembung", Slot = "Trail", Price = 1000, Source = "Shop", Order = 1,
		Description = "Gelembung kecil mengikuti langkahmu.", Style = "Bubbles",
		Colors = { rgb(200, 240, 255), rgb(120, 200, 240) } },
	{ Id = "trail_ombak", Name = "Ombak", Slot = "Trail", Price = 2000, Source = "Shop", Order = 2,
		Description = "Riak tosca seperti ombak pantai.", Style = "Waves",
		Colors = { rgb(43, 179, 177), rgb(200, 245, 240) } },
	{ Id = "trail_pelangi", Name = "Pelangi", Slot = "Trail", Price = 6000, Source = "Shop", Order = 3,
		Description = "Selendang pelangi di belakangmu.", Style = "RainbowTrail", Colors = {} },
	{ Id = "trail_penyu", Name = "Jejak Penyu", Slot = "Trail", PointsPrice = 200, Source = "Points", Order = 4,
		Description = "Jejak pasir penyu yang pulang ke laut.", Style = "Turtle",
		Colors = { rgb(214, 190, 130), rgb(120, 160, 90) } },

	-- Aura
	{ Id = "aura_percikan", Name = "Percikan Air", Slot = "Aura", Price = 3000, Source = "Shop", Order = 1,
		Description = "Cipratan air berkilau di sekitarmu.", Style = "Splash",
		Colors = { rgb(170, 230, 255), rgb(255, 255, 255) } },
	{ Id = "aura_kunang", Name = "Kunang-kunang", Slot = "Aura", Price = 5000, Source = "Shop", Order = 2,
		Description = "Kunang-kunang menemanimu. Menyala saat malam.", Style = "Fireflies",
		Colors = { rgb(220, 255, 120), rgb(255, 240, 150) }, NightOnly = true },
	{ Id = "aura_penyu", Name = "Aura Penyu", Slot = "Aura", PointsPrice = 150, Source = "Points", Order = 3,
		Description = "Cahaya hijau lembut penjaga penyu.", Style = "TurtleAura",
		Colors = { rgb(110, 224, 138), rgb(200, 255, 210) } },
	{ Id = "aura_cahaya_samudra", Name = "Cahaya Samudra", Slot = "Aura", Source = "Barter", Order = 4,
		Description = "Pancaran biru samudra. Eksklusif barter.", Style = "OceanLight",
		Colors = { rgb(90, 174, 255), rgb(200, 240, 255) } },

	-- Gelar (tidak dijual; dari quest, achievement, dan Fishdex)
	{ Id = "title_anak_pantai", Name = "Anak Pantai", Slot = "Title", Source = "Quest", Order = 1,
		Description = "Quest cerita: Gaya Pantai.", Style = "Title", Colors = {} },
	{ Id = "title_pemula_pantai", Name = "Pemula Pantai", Slot = "Title", Source = "Achievement", Order = 2,
		Description = "Achievement: Tangkapan Pertama.", Style = "Title", Colors = {} },
	{ Id = "title_nelayan_tangguh", Name = "Nelayan Tangguh", Slot = "Title", Source = "Achievement", Order = 3,
		Description = "Achievement: tangkap 100 ikan.", Style = "Title", Colors = {} },
	{ Id = "title_ahli_pantai", Name = "Ahli Pantai", Slot = "Title", Source = "Achievement", Order = 4,
		Description = "Fishdex Pantai Dangkal lengkap.", Style = "Title", Colors = {} },
	{ Id = "title_ahli_dermaga", Name = "Ahli Dermaga", Slot = "Title", Source = "Fishdex", Order = 5,
		Description = "Fishdex Ujung Dermaga lengkap.", Style = "Title", Colors = {} },
	{ Id = "title_penjaga_bakau", Name = "Penjaga Bakau", Slot = "Title", Source = "Fishdex", Order = 6,
		Description = "Fishdex Laguna Bakau lengkap.", Style = "Title", Colors = {} },
	{ Id = "title_penjelajah_samudra", Name = "Penjelajah Samudra", Slot = "Title", Source = "Fishdex", Order = 7,
		Description = "Fishdex Laut Dalam lengkap.", Style = "Title", Colors = {} },
	{ Id = "title_pelangi_samudra", Name = "Pelangi Samudra", Slot = "Title", Source = "Achievement", Order = 8,
		Description = "Achievement: tangkap ikan bermutasi Pelangi.", Style = "Title", Colors = {} },
	{ Id = "title_juragan_ikan", Name = "Juragan Ikan", Slot = "Title", Source = "Achievement", Order = 9,
		Description = "Achievement: total pendapatan 100.000 koin.", Style = "Title", Colors = {} },
	{ Id = "title_sahabat_laut", Name = "Sahabat Laut", Slot = "Title", Source = "Achievement", Order = 10,
		Description = "Achievement: total 250 Poin Konservasi.", Style = "Title", Colors = {} },
	{ Id = "title_raja_pancing", Name = "Raja Pancing", Slot = "Title", Source = "Achievement", Order = 11,
		Description = "Achievement: tangkap 1.000 ikan.", Style = "Title", Colors = {} },
	{ Id = "title_penakluk_naga", Name = "Penakluk Naga", Slot = "Title", Source = "Achievement", Order = 12,
		Description = "Achievement: tangkap Naga Laut Samudra.", Style = "Title", Colors = {} },
	{ Id = "title_pemburu_legenda", Name = "Pemburu Legenda", Slot = "Title", Source = "Quest", Order = 13,
		Description = "Quest cerita: Sang Legenda.", Style = "Title", Colors = {} },
}

local byId: { [string]: CosmeticDef } = {}
for _, c in list do
	assert(byId[c.Id] == nil, "Id kosmetik ganda: " .. c.Id)
	byId[c.Id] = c
end

local Cosmetics = {}
Cosmetics.List = list
Cosmetics.ById = byId
Cosmetics.SlotOrder = { "Hat", "Accessory", "RodSkin", "Bobber", "Trail", "Aura", "Title" } :: { Types.CosmeticSlot }
Cosmetics.SlotLabel = {
	Hat = "Topi",
	Accessory = "Aksesori",
	RodSkin = "Skin Joran",
	Bobber = "Pelampung",
	Trail = "Jejak",
	Aura = "Aura",
	Title = "Gelar",
} :: { [string]: string }

function Cosmetics.Get(id: string): CosmeticDef?
	return byId[id]
end

function Cosmetics.InSlot(slot: string): { CosmeticDef }
	local out = {}
	for _, c in list do
		if c.Slot == slot then
			table.insert(out, c)
		end
	end
	table.sort(out, function(a, b)
		return a.Order < b.Order
	end)
	return out
end

return Cosmetics
