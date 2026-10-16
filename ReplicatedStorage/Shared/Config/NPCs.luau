--!strict
-- NPC (GDD Bagian 5 & 4.8). Posisi berasal dari penanda NPCSpawn_<Id> yang dibuat World/Zones.luau.
-- Menambah NPC = menambah baris di sini + titik di World/MapConfig.luau (NpcSpawns).

local Types = require(script.Parent.Parent.Types)

type NpcDef = Types.NpcDef

local rgb = Color3.fromRGB

local SKIN = {
	rgb(176, 124, 84),
	rgb(160, 110, 74),
	rgb(196, 140, 98),
	rgb(142, 96, 64),
	rgb(204, 152, 110),
}

local list: { NpcDef } = {
	{
		Id = "pak_lurah",
		Name = "Pak Lurah",
		Title = "Kepala Desa",
		Role = "Quest",
		Greeting = "Selamat datang di Pantai Nusantara! Warga sini butuh bantuanmu.",
		Skin = SKIN[2],
		Shirt = rgb(122, 78, 45),
		Pants = rgb(47, 42, 38),
		Outfit = { "Peci" },
		Pose = "Idle",
		Menu = { "Quest", "Daily" },
	},
	{
		Id = "pak_darto",
		Name = "Pak Darto",
		Title = "Toko Pancing",
		Role = "ShopFishing",
		Greeting = "Mau mancing? Joran kuat, umpan segar, harga bersahabat!",
		Skin = SKIN[1],
		Shirt = rgb(62, 107, 138),
		Pants = rgb(70, 62, 52),
		Outfit = { "Topi" },
		Pose = "Idle",
		Menu = { "Shop" },
		ShopCategories = { "Rod", "Bait", "Bag" },
	},
	{
		Id = "mbak_sari",
		Name = "Mbak Sari",
		Title = "Butik Pantai",
		Role = "ShopCosmetic",
		Greeting = "Biar makin kece pas mancing, cobain koleksi baru!",
		Skin = SKIN[5],
		Shirt = rgb(224, 122, 154),
		Pants = rgb(60, 70, 110),
		Outfit = { "None" },
		Pose = "Idle",
		Menu = { "Shop", "Wardrobe" },
		ShopCategories = { "Hat", "Accessory", "RodSkin", "Bobber", "Trail", "Aura" },
	},
	{
		Id = "bu_rina",
		Name = "Bu Rina",
		Title = "Pengepul Ikan",
		Role = "Buyer",
		Greeting = "Ikan segar? Sini, Ibu beli dengan harga pas.",
		Skin = SKIN[3],
		Shirt = rgb(176, 72, 70),
		Pants = rgb(54, 50, 60),
		Outfit = { "Celemek" },
		Pose = "Idle",
		Menu = { "Sell" },
	},
	{
		Id = "kakek_bahari",
		Name = "Kakek Bahari",
		Title = "Barter",
		Role = "Barter",
		Greeting = "Laut menyimpan banyak rahasia, Nak.",
		Skin = SKIN[4],
		Shirt = rgb(140, 130, 112),
		Pants = rgb(74, 66, 56),
		Outfit = { "Caping" },
		Pose = "Sitting",
		Menu = { "Barter" },
	},
	{
		Id = "nahkoda_jaka",
		Name = "Nahkoda Jaka",
		Title = "Kapal ke Laut Dalam",
		Role = "FerryOut",
		Greeting = "Laut Dalam menunggu. Siap berlayar?",
		Skin = SKIN[1],
		Shirt = rgb(236, 236, 232),
		Pants = rgb(26, 40, 72),
		Outfit = { "TopiKapten" },
		Pose = "Idle",
		Menu = { "Ferry" },
	},
	{
		Id = "awak_kapal",
		Name = "Awak Kapal",
		Title = "Kapal Pulang",
		Role = "FerryBack",
		Greeting = "Mau balik ke pantai? Naik saja.",
		Skin = SKIN[2],
		Shirt = rgb(44, 93, 138),
		Pants = rgb(60, 56, 50),
		Outfit = { "Topi" },
		Pose = "Idle",
		Menu = { "Ferry" },
	},
	{
		Id = "kak_laut",
		Name = "Kak Laut",
		Title = "Penjaga Pantai",
		Role = "Conservation",
		Greeting = "Ikan dilindungi wajib dilepas. Bantu jaga laut kita, ya!",
		Skin = SKIN[3],
		Shirt = rgb(110, 120, 70),
		Pants = rgb(70, 60, 44),
		Outfit = { "TopiRanger" },
		Pose = "Idle",
		Menu = { "Shop", "Conservation" },
		ShopCategories = { "Points" },
	},
	{
		Id = "prof_mina",
		Name = "Prof. Mina",
		Title = "Pondok Riset",
		Role = "Fishdex",
		Greeting = "Setiap ikan punya cerita. Catat semuanya!",
		Skin = SKIN[5],
		Shirt = rgb(242, 242, 238),
		Pants = rgb(80, 90, 100),
		Outfit = { "Kacamata" },
		Pose = "Idle",
		Menu = { "Fishdex" },
	},

	-- Ambient: kalimat acak tanpa menu
	{
		Id = "nelayan_1",
		Name = "Pak Udin",
		Title = "Nelayan",
		Role = "Ambient",
		Greeting = "",
		Lines = {
			"Kalau pelampung goyang dua kali, sabar dulu. Yang ketiga baru tarik!",
			"Ujung dermaga itu tempat kakap merah suka nongkrong.",
			"Dulu kakek saya mancing pakai joran bambu juga.",
			"Malam hari cumi-cumi mendekat ke lampu.",
		},
		Skin = SKIN[4],
		Shirt = rgb(90, 120, 150),
		Pants = rgb(60, 60, 60),
		Outfit = { "Caping" },
		Pose = "Fishing",
	},
	{
		Id = "nelayan_2",
		Name = "Mas Bayu",
		Title = "Nelayan",
		Role = "Ambient",
		Greeting = "",
		Lines = {
			"Hari ini ombak tenang, rezeki lancar.",
			"Umpan udang bikin ikan besar lebih sering mampir.",
			"Jangan lupa jual tangkapan ke Bu Rina sebelum tas penuh.",
		},
		Skin = SKIN[2],
		Shirt = rgb(200, 80, 60),
		Pants = rgb(50, 56, 70),
		Outfit = { "Caping" },
		Pose = "Fishing",
	},
	{
		Id = "nelayan_3",
		Name = "Bang Jali",
		Title = "Nelayan",
		Role = "Ambient",
		Greeting = "",
		Lines = {
			"Katanya ada ikan yang cuma muncul pas badai. Ngeri juga.",
			"Pari totol suka di pasir dangkal, lho.",
			"Kalau dapat Napoleon, lepaskan. Dia dilindungi.",
			"Joran karbon itu mantap buat laguna.",
		},
		Skin = SKIN[1],
		Shirt = rgb(70, 140, 90),
		Pants = rgb(70, 62, 52),
		Outfit = { "Caping" },
		Pose = "Fishing",
	},
	{
		Id = "nelayan_4",
		Name = "Mak Ijah",
		Title = "Nelayan",
		Role = "Ambient",
		Greeting = "",
		Lines = {
			"Ikan badut cuma kelihatan siang hari di karang.",
			"Sabar itu kunci. Ikan tidak bisa dipaksa.",
			"Laguna bakau itu sejuk, tapi kau harus Lv 5 dulu.",
		},
		Skin = SKIN[3],
		Shirt = rgb(160, 90, 140),
		Pants = rgb(60, 50, 50),
		Outfit = { "Caping" },
		Pose = "Fishing",
	},
	{
		Id = "wisatawan_1",
		Name = "Rani",
		Title = "Wisatawan",
		Role = "Ambient",
		Greeting = "",
		Lines = {
			"Pantainya bersih banget! Betah deh.",
			"Sore nanti mau lihat matahari terbenam dari dermaga.",
			"Es kelapanya wajib dicoba!",
		},
		Skin = SKIN[5],
		Shirt = rgb(255, 196, 80),
		Pants = rgb(60, 140, 180),
		Outfit = { "None" },
		Pose = "Lounging",
	},
	{
		Id = "wisatawan_2",
		Name = "Tom",
		Title = "Wisatawan",
		Role = "Ambient",
		Greeting = "",
		Lines = {
			"Indonesia indah sekali. Saya mau belajar memancing!",
			"Itu kapal pinisi? Cantik sekali layarnya.",
			"Mercusuar itu bisa dilihat dari jauh, ya.",
		},
		Skin = rgb(232, 196, 164),
		Shirt = rgb(240, 240, 235),
		Pants = rgb(200, 120, 80),
		Outfit = { "Topi" },
		Pose = "Lounging",
	},
	{
		Id = "wisatawan_3",
		Name = "Dewi",
		Title = "Wisatawan",
		Role = "Ambient",
		Greeting = "",
		Lines = {
			"Main voli pantai, yuk, nanti sore!",
			"Aku lihat kepiting kecil lari ke lubang pasir tadi.",
			"Kunang-kunang di laguna katanya cantik saat malam.",
			"Jangan lupa pakai tabir surya!",
		},
		Skin = SKIN[2],
		Shirt = rgb(43, 179, 177),
		Pants = rgb(240, 230, 210),
		Outfit = { "None" },
		Pose = "Sitting",
	},
	{
		Id = "penjual_es",
		Name = "Mang Ujang",
		Title = "Es Kelapa Muda",
		Role = "Ambient",
		Greeting = "",
		Lines = {
			"Es kelapa muda! Segar, manis, dingin!",
			"Kelapanya dipetik pagi tadi dari pohon di belakang.",
			"Habis mancing paling enak minum es kelapa.",
			"Pakai gula merah atau sirup? Dua-duanya enak!",
		},
		Skin = SKIN[4],
		Shirt = rgb(240, 200, 80),
		Pants = rgb(60, 60, 70),
		Outfit = { "Topi" },
		Pose = "Idle",
	},
}

local byId: { [string]: NpcDef } = {}
for _, n in list do
	assert(byId[n.Id] == nil, "Id NPC ganda: " .. n.Id)
	byId[n.Id] = n
end

local NPCs = {}
NPCs.List = list
NPCs.ById = byId

function NPCs.Get(id: string): NpcDef?
	return byId[id]
end

-- NPC pertama dengan peran tertentu (mis. "Buyer" -> bu_rina).
function NPCs.ByRole(role: Types.NpcRole): NpcDef?
	for _, n in list do
		if n.Role == role then
			return n
		end
	end
	return nil
end

return NPCs
