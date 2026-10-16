--!strict
-- Rumus GDD 4.2: harga & XP monoton, kurva level, roll ikan menghormati syarat, waktu WIB, malam, lempar, minigame.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Formulas = require(Shared.Formulas)
local Balance = require(Shared.Config.Balance)
local Fish = require(Shared.Config.Fish)
local Rods = require(Shared.Config.Rods)
local Bait = require(Shared.Config.Bait)
local Types = require(Shared.Types)
local TestRunner = require(script.Parent.Parent.TestRunner)

local function ctx(zone: string, night: boolean, weather: Types.WeatherId, event: Types.EventId): Types.RollContext
	return { Zone = zone, IsNight = night, Weather = weather, Event = event, Luck = 0, MutationMul = 1 }
end

return function(t: TestRunner.T)
	local kakap = assert(Fish.Get("kakap_merah"))
	local napoleon = assert(Fish.Get("napoleon"))

	-- Harga monoton terhadap berat dan mutasi
	local p1 = Formulas.SellPrice(kakap, 1, "None", 1)
	local p2 = Formulas.SellPrice(kakap, 4, "None", 1)
	local p3 = Formulas.SellPrice(kakap, 8, "None", 1)
	t.Check(p1 < p2 and p2 < p3, "harga naik seiring berat", string.format("%d %d %d", p1, p2, p3))
	local avg = Formulas.AverageWeight(kakap)
	t.Equal(Formulas.SellPrice(kakap, avg, "None", 1), kakap.BasePrice, "berat rata-rata = harga dasar")
	local prevMut = 0
	local mutOrdered = true
	for _, m in { "None", "Berkilau", "Albino", "Emas", "Pelangi" } do
		local price = Formulas.SellPrice(kakap, avg, m :: Types.Mutation, 1)
		if price <= prevMut then
			mutOrdered = false
		end
		prevMut = price
	end
	t.Check(mutOrdered, "harga naik sesuai pengali mutasi")
	t.Equal(Formulas.SellPrice(kakap, avg, "Pelangi", 1), kakap.BasePrice * 10, "Pelangi ×10")
	t.Equal(Formulas.SellPrice(kakap, avg, "None", 1.25), math.floor(kakap.BasePrice * 1.25 + 0.5), "Musim Ikan ×1,25")
	t.Equal(Formulas.SellPrice(napoleon, 40, "None", 1), 0, "ikan Protected tidak bernilai jual")
	t.Equal(Formulas.ConservationPoints(napoleon), 25, "poin khusus Napoleon")
	t.Equal(Formulas.ConservationPoints(kakap), Balance.ConservationByRarity.Uncommon, "poin konservasi per rarity")

	-- XP monoton
	local prevXP = 0
	local xpOrdered = true
	for _, r in Balance.RarityOrder do
		local xp = Formulas.CatchXP(r :: Types.Rarity, "None")
		if xp <= prevXP then
			xpOrdered = false
		end
		prevXP = xp
	end
	t.Check(xpOrdered, "XP naik sesuai rarity")
	t.Equal(Formulas.CatchXP("Rare", "Emas"), 90, "XP Rare × Emas")
	t.Equal(Formulas.XPToNext(1), 40, "XP ke Lv 2 = 40")
	t.Equal(Formulas.XPToNext(10), math.floor(40 * 10 ^ 1.35), "XP Lv 10 sesuai rumus")
	local increasing = true
	for l = 1, Balance.MaxLevel - 1 do
		if Formulas.XPToNext(l + 1) <= Formulas.XPToNext(l) then
			increasing = false
		end
	end
	t.Check(increasing, "kurva XP naik")
	local lvl, rest, reached = Formulas.ApplyXP(1, 30, 120)
	t.Equal(lvl, 3, "ApplyXP melewati dua level")
	t.Equal(rest, 150 - 40 - Formulas.XPToNext(2), "sisa XP benar")
	t.Equal(#reached, 2, "daftar level tercapai")
	local maxL = Formulas.ApplyXP(Balance.MaxLevel, 0, 999999)
	t.Equal(maxL, Balance.MaxLevel, "level tidak melewati maksimum")
	t.Equal(Formulas.LevelUpReward(12), 300, "hadiah naik level 25 × L")

	-- Waktu
	t.Check(Formulas.IsNight(18.5) and Formulas.IsNight(23) and Formulas.IsNight(5.4), "malam ≥18,5 dan <5,5")
	t.Check(not Formulas.IsNight(5.5) and not Formulas.IsNight(12) and not Formulas.IsNight(18.49), "siang 5,5..18,5")
	-- 2026-10-15 17:00:00 UTC = 2026-10-16 00:00 WIB
	local boundary = 1792083600
	t.Equal(Formulas.WibDayIndex(boundary) - Formulas.WibDayIndex(boundary - 1), 1, "hari WIB berganti pukul 00:00 WIB")
	t.Equal(Formulas.WibDayIndex(boundary + 86399), Formulas.WibDayIndex(boundary), "satu hari WIB penuh")
	t.Near(Formulas.ClockTime(100 + 450, 100, 14, 900), 2, 1e-6, "ClockTime maju 12 jam dalam setengah hari game")

	-- Roll: berat dalam rentang dan condong kecil
	local rng = Random.new(2024)
	local inRange = true
	local below = 0
	for _ = 1, 4000 do
		local w = Formulas.RollWeight(rng, kakap)
		if w < kakap.MinWeight - 1e-9 or w > kakap.MaxWeight + 1e-9 then
			inRange = false
		end
		if w < avg then
			below += 1
		end
	end
	t.Check(inRange, "berat selalu dalam rentang min–max")
	t.Check(below / 4000 > 0.6, "berat condong kecil (r^2,2)", tostring(below / 4000))

	-- Mutasi: peluang total ≈ 5,8% dan ×2 menggandakan
	local mrng = Random.new(99)
	local mutated, mutated2 = 0, 0
	local n = 60000
	for _ = 1, n do
		if Formulas.RollMutation(mrng, 1) ~= "None" then
			mutated += 1
		end
		if Formulas.RollMutation(mrng, 2) ~= "None" then
			mutated2 += 1
		end
	end
	t.Near(mutated / n, 0.058, 0.006, "peluang mutasi dasar ≈ 5,8%")
	t.Near(mutated2 / n, 0.116, 0.008, "peluang mutasi ×2 ≈ 11,6%")

	-- Luck menaikkan peluang rarity tinggi
	local available = Formulas.AvailableByRarity(Fish.List, ctx("DeepSea", false, "Cerah", "None"))
	local w0 = Formulas.RarityWeights(0, available)
	local w1 = Formulas.RarityWeights(0.8, available)
	t.Check(w1.Legendary / w1.Common > w0.Legendary / w0.Common, "Luck menaikkan bobot Legendary relatif")
	t.Equal(w0.Mythic, 0, "Mythic dikeluarkan tanpa Badai di Laut Dalam")

	-- Syarat spesies
	local function canRoll(id: string, c: Types.RollContext): boolean
		local s = assert(Fish.Get(id))
		return Formulas.SpeciesAvailable(s, c)
	end
	t.Check(canRoll("naga_laut", ctx("DeepSea", false, "Badai", "None")), "Naga Laut muncul saat Badai")
	t.Check(not canRoll("naga_laut", ctx("DeepSea", false, "Hujan", "None")), "Naga Laut tidak muncul tanpa Badai")
	t.Check(canRoll("kristal_bulan", ctx("Mangrove", true, "Cerah", "BulanPurnama")), "Kristal Bulan saat malam + Purnama")
	t.Check(not canRoll("kristal_bulan", ctx("Mangrove", false, "Cerah", "BulanPurnama")), "Kristal Bulan tidak siang")
	t.Check(not canRoll("kristal_bulan", ctx("Mangrove", true, "Cerah", "None")), "Kristal Bulan butuh event")
	t.Check(not canRoll("cumi", ctx("Shore", false, "Cerah", "None")), "Cumi hanya malam")
	t.Check(not canRoll("badut", ctx("Shore", true, "Cerah", "None")), "Ikan Badut hanya siang")
	t.Check(not canRoll("bandeng", ctx("Shore", false, "Cerah", "None")), "Bandeng hanya di Laguna")

	-- RollFish hanya menghasilkan spesies valid
	local frng = Random.new(5)
	local valid = true
	local c = ctx("Shore", false, "Cerah", "None")
	for _ = 1, 3000 do
		local res = Formulas.RollFish(frng, Fish.List, c)
		if res == nil or not Formulas.SpeciesAvailable(res.Species, c) then
			valid = false
		end
	end
	t.Check(valid, "RollFish selalu valid untuk zona/waktu")

	-- Luck & mutasi efektif
	local fiber = assert(Rods.Get("fiber"))
	local kilau = assert(Bait.Get("kilau"))
	t.Near(Formulas.EffectiveLuck(fiber, kilau, true, "Hujan", "None", "Shore"), 0.1 + 0.3 + 0.2 + 0.1, 1e-9, "Luck malam + hujan")
	t.Near(Formulas.EffectiveLuck(nil, nil, false, "Cerah", "BulanPurnama", "Mangrove"), 0.3, 1e-9, "Luck Laguna saat Purnama")
	local emasRod = assert(Rods.Get("emas_bahari"))
	local emasBait = assert(Bait.Get("emas"))
	t.Near(Formulas.MutationMultiplier(emasRod, emasBait, "JamEmas"), 6, 1e-9, "mutasi ×1,5 × ×2 × ×2")

	-- Waktu tunggu dalam rentang
	local wrng = Random.new(3)
	local bambu = assert(Rods.Get("bambu"))
	local okWait = true
	for _ = 1, 500 do
		local w = Formulas.WaitTime(wrng, bambu, nil, "Cerah")
		if w < 4 * 1.15 - 1e-9 or w > 11 * 1.15 + 1e-9 then
			okWait = false
		end
	end
	t.Check(okWait, "waktu tunggu tanpa umpan 4–11 × 1,15")

	-- Lempar
	local origin = Vector3.new(0, 5, 0)
	t.Near((Formulas.CastLanding(origin, 0, 1, 0, 35) - origin).Magnitude, 8, 1e-6, "power 0 = 8 stud")
	t.Near((Formulas.CastLanding(origin, 0, 1, 1, 35) - origin).Magnitude, 35, 1e-6, "power 1 = jarak joran")
	t.Near((Formulas.CastLanding(origin, 0, 0, 0.5, 35) - origin).Z, 21.5, 1e-6, "arah nol → ke laut (+Z)")

	-- Minigame
	t.Near(Formulas.MinReelDuration(1), 2, 1e-9, "durasi minimum 0,7/0,35")
	t.Check(not (Formulas.ValidateReelClaim(1.7, 1)), "klaim terlalu cepat ditolak")
	t.Check((Formulas.ValidateReelClaim(5, 1)), "klaim wajar diterima")
	t.Check(not (Formulas.ValidateReelClaim(30, 1)), "klaim kedaluwarsa ditolak")
	t.Check(Formulas.IsHard(13, bambu) and not Formulas.IsHard(12, bambu), "mode Sulit bila berat > MaxWeight")

	-- Zona: volume terkecil yang menang
	local zones: { Formulas.ZoneBox } = {
		{ Id = "Shore", CFrame = CFrame.new(0, 0, 0), Size = Vector3.new(400, 40, 400) },
		{ Id = "Pier", CFrame = CFrame.new(10, 0, 10), Size = Vector3.new(50, 40, 50) },
	}
	t.Equal(Formulas.PickZone(Vector3.new(10, 0, 10), zones), "Pier", "zona terkecil menang bila tumpang tindih")
	t.Equal(Formulas.PickZone(Vector3.new(150, 0, 150), zones), "Shore", "zona besar di luar zona kecil")
	t.Equal(Formulas.PickZone(Vector3.new(900, 0, 0), zones), nil, "di luar semua zona")
end
