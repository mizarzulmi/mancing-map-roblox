--!strict
-- Skema profil pemain: template Version terbaru + migrasi berurutan berdasarkan Version.
-- Murni (tanpa service) agar bisa diuji. DataService memakai Template() untuk ProfileStore lalu Migrate().

local Types = require(script.Parent.Types)
local Balance = require(script.Parent.Config.Balance)

type ProfileData = Types.ProfileData

local ProfileSchema = {}

ProfileSchema.CurrentVersion = 1

function ProfileSchema.Template(): ProfileData
	local owned: { [string]: boolean } = {}
	for _, id in Balance.StartCosmetics do
		owned[id] = true
	end
	return {
		Version = ProfileSchema.CurrentVersion,
		Coins = Balance.StartCoins,
		Level = 1,
		XP = 0,
		ConservationPoints = 0,
		BagCapacity = Balance.StartBagCapacity,
		Fish = {},
		Rods = { Balance.StartRod },
		EquippedRod = Balance.StartRod,
		Bait = {},
		EquippedBait = "",
		Cosmetics = {
			Owned = owned,
			Equipped = {
				Hat = "",
				Accessory = "",
				RodSkin = "rodskin_kayu",
				Bobber = "bobber_merah_putih",
				Trail = "",
				Aura = "",
				Title = "",
			},
		},
		Quests = {
			StoryIndex = 1,
			StoryProgress = 0,
			StoryAccepted = false,
			DailyDay = -1,
			Daily = {},
		},
		Fishdex = {},
		FishdexClaimed = {},
		Achievements = {},
		Stats = {
			TotalCaught = 0,
			TotalEarned = 0,
			TotalReleased = 0,
			HeaviestKg = 0,
			TotalConservation = 0,
			TotalSold = 0,
			MutatedCaught = 0,
		},
		BarterOnce = {},
		Settings = {
			Music = 0.6,
			Sfx = 0.8,
			LowGfx = false,
			UiScale = 1,
		},
		LastLogin = 0,
		CoinLog = {},
		TradeLog = {},
	}
end

-- Migrasi berurutan: migrations[v] mengubah data Version v menjadi v+1.
-- Version 1 adalah versi pertama; tambahkan entri baru di sini ketika skema berubah.
local migrations: { [number]: (any) -> () } = {}

-- Mengisi field yang hilang secara rekursif dari template (untuk tabel bersarang yang tidak
-- tercakup Reconcile ProfileStore, mis. Stats baru atau Cosmetics.Equipped slot baru).
local function fillMissing(target: { [any]: any }, template: { [any]: any })
	for key, value in template do
		if target[key] == nil then
			target[key] = if type(value) == "table" then table.clone(value) else value
		elseif type(value) == "table" and type(target[key]) == "table" and next(value) ~= nil then
			-- Hanya rekursi ke tabel kamus (bukan array data pemain seperti Fish/Rods).
			if #value == 0 then
				fillMissing(target[key], value)
			end
		end
	end
end

-- Mengembalikan data yang sudah dimigrasi ke CurrentVersion (dimodifikasi di tempat).
function ProfileSchema.Migrate(data: any): ProfileData
	local version = if type(data.Version) == "number" then data.Version else 0
	if version < 1 then
		version = 1
	end
	while version < ProfileSchema.CurrentVersion do
		local step = migrations[version]
		if step then
			step(data)
		end
		version += 1
	end
	data.Version = ProfileSchema.CurrentVersion
	fillMissing(data, ProfileSchema.Template() :: any)
	return data :: ProfileData
end

return ProfileSchema
