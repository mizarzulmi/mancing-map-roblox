--!strict
-- Integritas Config: semua referensi silang valid, sehingga menambah konten lewat Config aman.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Config = Shared.Config
local Balance = require(Config.Balance)
local Fish = require(Config.Fish)
local Rods = require(Config.Rods)
local Bait = require(Config.Bait)
local Cosmetics = require(Config.Cosmetics)
local Zones = require(Config.Zones)
local NPCs = require(Config.NPCs)
local Quests = require(Config.Quests)
local Achievements = require(Config.Achievements)
local Barter = require(Config.Barter)
local ProfileSchema = require(Shared.ProfileSchema)
local TestRunner = require(script.Parent.Parent.TestRunner)

local VALID_SHAPES = {
	Ramping = true, Gemuk = true, Pipih = true, Belut = true, Paruh = true,
	Kepiting = true, Cumi = true, Lobster = true, Naga = true, Kristal = true,
}

return function(t: TestRunner.T)
	-- Ikan
	local fishOk = true
	local fishDetail = ""
	for _, s in Fish.List do
		local bad = Balance.RarityBaseWeight[s.Rarity] == nil
			or not VALID_SHAPES[s.Shape]
			or #s.Zones == 0
			or #s.Hint == 0
			or (not s.Protected and s.BasePrice <= 0)
			or (s.Protected and (s.ProtectedPoints or 0) <= 0)
		for _, z in s.Zones do
			if Zones.Get(z) == nil then
				bad = true
			end
		end
		if bad then
			fishOk = false
			fishDetail ..= s.Id .. " "
		end
	end
	t.Check(fishOk, "semua spesies ikan valid", fishDetail)
	t.Equal(#Fish.List, 28, "28 spesies sesuai GDD")

	-- Setiap zona punya ikan Common sepanjang hari & malam (memancing tidak pernah buntu)
	for _, z in Zones.List do
		for _, night in { false, true } do
			local hasCommon = false
			for _, s in Fish.InZone(z.Id) do
				if s.Rarity == "Common" and (s.Time == "Any" or (s.Time == "Night") == night) then
					hasCommon = true
				end
			end
			t.Check(hasCommon, string.format("zona %s punya ikan Common (%s)", z.Id, if night then "malam" else "siang"))
		end
		t.Check(Cosmetics.Get(z.FishdexTitle) ~= nil, "gelar Fishdex zona " .. z.Id .. " ada")
	end

	-- Joran & umpan
	for _, r in Rods.List do
		t.Check(r.Control > 0 and r.Control < 1 and r.CastDistance > Balance.Fishing.CastMinDistance, "joran " .. r.Id .. " valid")
	end
	t.Check(Rods.Get(Balance.StartRod) ~= nil, "joran awal ada")

	-- Kosmetik
	local slots: { [string]: boolean } = {}
	for _, s in Cosmetics.SlotOrder do
		slots[s] = true
	end
	local cosOk = true
	for _, c in Cosmetics.List do
		if not slots[c.Slot] then
			cosOk = false
		end
		if c.Source == "Shop" and (c.Price == nil or (c.Price :: number) <= 0) then
			cosOk = false
		end
		if c.Source == "Points" and c.PointsPrice == nil then
			cosOk = false
		end
	end
	t.Check(cosOk, "semua kosmetik punya slot & harga yang benar")
	for _, id in Balance.StartCosmetics do
		t.Check(Cosmetics.Get(id) ~= nil, "kosmetik awal " .. id .. " ada")
	end

	-- NPC
	t.Check(NPCs.Get("pak_lurah") ~= nil and NPCs.ByRole("Buyer") ~= nil, "NPC utama ada")
	for _, n in NPCs.List do
		if n.Role == "Ambient" then
			local count = #(n.Lines or {})
			t.Check(count >= 3 and count <= 5, "NPC ambient " .. n.Id .. " punya 3–5 kalimat")
		end
	end

	-- Quest
	t.Equal(#Quests.Story, 11, "11 quest cerita")
	for _, q in Quests.Story do
		local o = q.Objective
		local ok = o.Count > 0
		if o.Bait then
			ok = ok and Bait.Get(o.Bait) ~= nil
		end
		if o.Zone then
			ok = ok and Zones.Get(o.Zone) ~= nil
		end
		if o.Npc then
			ok = ok and NPCs.Get(o.Npc) ~= nil
		end
		if q.Reward.Title then
			ok = ok and Cosmetics.Get(q.Reward.Title) ~= nil
		end
		t.Check(ok, "quest " .. q.Id .. " valid")
	end
	t.Check(#Quests.Daily >= Balance.DailyCount, "pool harian cukup")

	-- Achievement & barter
	for _, a in Achievements.List do
		t.Check(Cosmetics.Get(a.Title) ~= nil, "gelar achievement " .. a.Id .. " ada")
	end
	for _, r in Barter.List do
		local ok = (r.GiveBait == nil or Bait.Get(r.GiveBait) ~= nil)
			and (r.GiveRod == nil or Rods.Get(r.GiveRod) ~= nil)
			and (r.GiveCosmetic == nil or Cosmetics.Get(r.GiveCosmetic) ~= nil)
		t.Check(ok, "barter " .. r.Id .. " mereferensikan item yang ada")
	end

	-- Profil
	local data = ProfileSchema.Template()
	t.Equal(data.Coins, 50, "koin awal 50")
	t.Equal(data.BagCapacity, 20, "kapasitas tas awal 20")
	t.Equal(data.EquippedRod, "bambu", "joran awal bambu")
	local migrated = ProfileSchema.Migrate({ Version = 1, Coins = 999, Stats = { TotalCaught = 7 } })
	t.Equal(migrated.Coins, 999, "migrasi mempertahankan nilai")
	t.Equal(migrated.Stats.TotalCaught, 7, "migrasi mempertahankan stat bersarang")
	t.Equal(migrated.Stats.HeaviestKg, 0, "migrasi mengisi stat bersarang yang hilang")
	t.Check(migrated.Cosmetics.Equipped.Bobber == "bobber_merah_putih", "migrasi mengisi slot kosmetik")
end
