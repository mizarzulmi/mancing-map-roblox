--!strict
-- Validasi trade (terkunci, bukan milik, Protected, saldo, kapasitas) dan aturan "perubahan mereset Siap".

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Formulas = require(Shared.Formulas)
local TradeLogic = require(Shared.TradeLogic)
local Fish = require(Shared.Config.Fish)
local Bait = require(Shared.Config.Bait)
local Types = require(Shared.Types)
local TestRunner = require(script.Parent.Parent.TestRunner)

local function item(uid: string, species: string, weight: number, locked: boolean?): Types.FishItem
	return { Uid = uid, SpeciesId = species, Weight = weight, Mutation = "None", Zone = "Shore", CaughtAt = 0, Locked = locked == true }
end

return function(t: TestRunner.T)
	local invA: Formulas.TradeInventory = {
		Fish = { item("a1", "kembung", 0.4), item("a2", "kakap_merah", 3, true), item("a3", "napoleon", 30) },
		Bait = { cacing = 5 },
		Coins = 100,
		BagCapacity = 20,
	}
	local invB: Formulas.TradeInventory = {
		Fish = { item("b1", "teri", 0.05) },
		Bait = {},
		Coins = 0,
		BagCapacity = 1,
	}
	local function offer(fish: { string }, bait: { [string]: number }, coins: number): Types.TradeOffer
		return { Fish = fish, Bait = bait, Coins = coins }
	end

	t.Check((Formulas.ValidateOffer(invA, offer({ "a1" }, {}, 50), Fish.ById)), "penawaran valid diterima")
	local _, rLocked = Formulas.ValidateOffer(invA, offer({ "a2" }, {}, 0), Fish.ById)
	t.Equal(rLocked, "Locked", "ikan terkunci ditolak")
	local _, rOwn = Formulas.ValidateOffer(invA, offer({ "b1" }, {}, 0), Fish.ById)
	t.Equal(rOwn, "NotOwned", "ikan bukan milik ditolak")
	local _, rProt = Formulas.ValidateOffer(invA, offer({ "a3" }, {}, 0), Fish.ById)
	t.Equal(rProt, "Protected", "ikan Protected ditolak")
	local _, rCoins = Formulas.ValidateOffer(invA, offer({}, {}, 101), Fish.ById)
	t.Equal(rCoins, "NotEnoughCoins", "saldo kurang ditolak")
	local _, rBait = Formulas.ValidateOffer(invA, offer({}, { cacing = 6 }, 0), Fish.ById)
	t.Equal(rBait, "NotEnoughBait", "umpan kurang ditolak")
	local _, rDup = Formulas.ValidateOffer(invA, offer({ "a1", "a1" }, {}, 0), Fish.ById)
	t.Equal(rDup, "Duplicate", "Uid ganda ditolak")
	local many = {}
	for i = 1, 9 do
		table.insert(many, "x" .. i)
	end
	local _, rMany = Formulas.ValidateOffer(invA, offer(many, {}, 0), Fish.ById)
	t.Equal(rMany, "TooManyFish", "maksimal 8 ikan")

	-- Kapasitas: B (kapasitas 1, sudah 1 ikan) menerima 1 ikan tanpa memberi apa pun -> penuh
	local okCap, rCap = Formulas.ValidateTrade(invA, offer({ "a1" }, {}, 0), invB, offer({}, {}, 0), Fish.ById)
	t.Check(not okCap and rCap == "B:BagFull", "kapasitas tas penerima diperiksa", tostring(rCap))
	local okSwap = Formulas.ValidateTrade(invA, offer({ "a1" }, {}, 0), invB, offer({ "b1" }, {}, 0), Fish.ById)
	t.Check(okSwap, "tukar 1:1 valid walau tas B penuh")

	-- Nilai & peringatan timpang
	local vA = Formulas.OfferValue(invA, offer({ "a1" }, { cacing = 5 }, 0), Fish.ById, Bait.ById)
	t.Check(vA > 10, "estimasi nilai menghitung ikan + umpan", tostring(vA))
	t.Check(Formulas.IsTradeUnfair(1000, 100), "nilai timpang terdeteksi")
	t.Check(not Formulas.IsTradeUnfair(100, 90), "nilai seimbang tidak diperingatkan")

	-- Sesi: perubahan isi mereset Siap
	local s = TradeLogic.New("t1")
	TradeLogic.SetReady(s, "A", true, 0)
	TradeLogic.SetReady(s, "B", true, 0)
	t.Check(TradeLogic.BothReady(s) and s.CountdownEndsAt == 5, "keduanya Siap memulai hitung mundur 5 dtk")
	t.Check(not TradeLogic.ShouldExecute(s, 4.9), "belum dieksekusi sebelum hitung mundur selesai")
	t.Check(TradeLogic.ShouldExecute(s, 5), "dieksekusi saat hitung mundur selesai")
	local changed = TradeLogic.SetOffer(s, "B", offer({ "b1" }, {}, 0))
	t.Check(changed and not s.Ready.A and not s.Ready.B, "perubahan isi mereset Siap kedua pihak")
	t.Equal(s.CountdownEndsAt, nil, "perubahan isi membatalkan hitung mundur")
	t.Check(not TradeLogic.SetOffer(s, "B", offer({ "b1" }, {}, 0)), "penawaran identik bukan perubahan")
	TradeLogic.SetReady(s, "A", true, 10)
	TradeLogic.SetReady(s, "A", false, 11)
	t.Equal(s.CountdownEndsAt, nil, "membatalkan Siap menghentikan hitung mundur")
end
