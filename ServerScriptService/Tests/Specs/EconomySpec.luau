--!strict
-- Pembelian (koin kurang, level, kepemilikan), umpan "maks", tingkat tas, kosmetik poin, kapasitas tas.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Formulas = require(Shared.Formulas)
local Rods = require(Shared.Config.Rods)
local Bait = require(Shared.Config.Bait)
local Bags = require(Shared.Config.Bags)
local Cosmetics = require(Shared.Config.Cosmetics)
local ProfileSchema = require(Shared.ProfileSchema)
local TestRunner = require(script.Parent.Parent.TestRunner)

return function(t: TestRunner.T)
	local data = ProfileSchema.Template()
	local fiber = assert(Rods.Get("fiber"))

	-- Koin kurang
	data.Coins = 100
	data.Level = 5
	local r1 = Formulas.CheckRodPurchase(data, fiber)
	t.Check(not r1.Ok and r1.Reason == "Coins", "joran ditolak bila koin kurang", tostring(r1.Reason))
	-- Level kurang
	data.Coins = 1000
	data.Level = 2
	local r2 = Formulas.CheckRodPurchase(data, fiber)
	t.Check(not r2.Ok and r2.Reason == "Level", "joran ditolak bila level kurang", tostring(r2.Reason))
	-- Berhasil
	data.Level = 3
	local r3 = Formulas.CheckRodPurchase(data, fiber)
	t.Check(r3.Ok and r3.Price == 350, "joran dibeli bila syarat terpenuhi")
	-- Sudah dimiliki
	table.insert(data.Rods, "fiber")
	t.Check(not Formulas.CheckRodPurchase(data, fiber).Ok, "joran yang dimiliki tidak bisa dibeli lagi")
	-- Joran barter tidak dijual
	t.Check(not Formulas.CheckRodPurchase(data, assert(Rods.Get("emas_bahari"))).Ok, "joran barter tidak dijual di toko")

	-- Umpan
	local cacing = assert(Bait.Get("cacing"))
	data.Coins = 25
	local b1 = Formulas.CheckBaitPurchase(data, cacing, 10)
	t.Check(b1.Ok and b1.Price == 20 and b1.Quantity == 10, "beli 10 cacing = 20 koin")
	local b2 = Formulas.CheckBaitPurchase(data, cacing, 50)
	t.Check(not b2.Ok and b2.Reason == "Coins", "beli 50 cacing ditolak (koin kurang)")
	local b3 = Formulas.CheckBaitPurchase(data, cacing, 0)
	t.Check(b3.Ok and b3.Quantity == 12, "maks = floor(koin / harga)", tostring(b3.Quantity))
	data.Coins = 0
	t.Check(not Formulas.CheckBaitPurchase(data, cacing, 0).Ok, "maks dengan 0 koin ditolak")
	t.Check(not Formulas.CheckBaitPurchase(data, assert(Bait.Get("emas")), 1).Ok, "umpan barter tidak dijual")
	data.Coins = 100000
	data.Bait.cacing = 995
	local b4 = Formulas.CheckBaitPurchase(data, cacing, 10)
	t.Check(not b4.Ok and b4.Reason == "StackFull", "tumpukan umpan maks 999")

	-- Tas
	data.Coins = 399
	t.Check(not Formulas.CheckBagPurchase(data).Ok, "upgrade tas ditolak bila koin kurang")
	data.Coins = 400
	local g1 = Formulas.CheckBagPurchase(data)
	t.Check(g1.Ok and g1.Price == 400, "upgrade 20 → 35 seharga 400")
	t.Equal((Bags.NextTier(35) :: any).Capacity, 60, "tingkat setelah 35 adalah 60")
	t.Equal(Bags.NextTier(150), nil, "150 adalah kapasitas maksimum")
	data.BagCapacity = 150
	t.Check(not Formulas.CheckBagPurchase(data).Ok, "tas maksimal tidak bisa di-upgrade")
	t.Check(Formulas.CanAddFish(19, 20) and not Formulas.CanAddFish(20, 20), "kapasitas tas dihormati")

	-- Kosmetik koin & poin
	local jerami = assert(Cosmetics.Get("topi_jerami"))
	data.Coins = 249
	t.Check(not Formulas.CheckCosmeticPurchase(data, jerami).Ok, "kosmetik ditolak bila koin kurang")
	data.Coins = 250
	t.Check(Formulas.CheckCosmeticPurchase(data, jerami).Ok, "kosmetik dibeli dengan koin pas")
	local ranger = assert(Cosmetics.Get("topi_ranger"))
	data.ConservationPoints = 59
	local c1 = Formulas.CheckCosmeticPurchase(data, ranger)
	t.Check(not c1.Ok and c1.Reason == "Points", "kosmetik poin ditolak bila poin kurang")
	data.ConservationPoints = 60
	local c2 = Formulas.CheckCosmeticPurchase(data, ranger)
	t.Check(c2.Ok and c2.Currency == "Points", "kosmetik poin dibeli dengan poin")
	t.Check(not Formulas.CheckCosmeticPurchase(data, assert(Cosmetics.Get("aura_cahaya_samudra"))).Ok, "kosmetik barter tidak dijual")
	t.Check(not Formulas.CheckCosmeticPurchase(data, assert(Cosmetics.Get("rodskin_kayu"))).Ok, "kosmetik awal sudah dimiliki")
end
