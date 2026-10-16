--!strict
-- Rumus murni (tanpa service Roblox) agar bisa diuji SelfTest di Studio dan Lune di luar Studio.
-- Semua angka berasal dari Config/Balance.luau. RNG selalu diberikan pemanggil (Random.new(seed)).

local Types = require(script.Parent.Types)
local Balance = require(script.Parent.Config.Balance)
local Bags = require(script.Parent.Config.Bags)
local WeightedRandom = require(script.Parent.Util.WeightedRandom)

type Rarity = Types.Rarity
type Mutation = Types.Mutation
type FishSpecies = Types.FishSpecies
type FishItem = Types.FishItem
type RodDef = Types.RodDef
type BaitDef = Types.BaitDef
type CosmeticDef = Types.CosmeticDef
type BarterRecipe = Types.BarterRecipe
type TradeOffer = Types.TradeOffer
type RollContext = Types.RollContext
type WeatherId = Types.WeatherId
type EventId = Types.EventId

local Formulas = {}

-- =========================================================================
-- Waktu
-- =========================================================================

function Formulas.IsNight(clockTime: number): boolean
	local t = clockTime % 24
	return t >= Balance.NightStart or t < Balance.NightEnd
end

-- ClockTime saat `now` bila pada `refTime` jam menunjukkan `refClock`.
function Formulas.ClockTime(now: number, refTime: number, refClock: number, dayLength: number): number
	local elapsed = now - refTime
	return (refClock + elapsed / dayLength * 24) % 24
end

-- Indeks hari kalender WIB (UTC+7) dari unix time; berganti tepat pukul 00:00 WIB.
function Formulas.WibDayIndex(unixTime: number): number
	return math.floor((unixTime + Balance.WibOffsetSeconds) / 86400)
end

-- =========================================================================
-- Level & XP
-- =========================================================================

function Formulas.XPToNext(level: number): number
	return math.floor(Balance.XPCurveBase * level ^ Balance.XPCurveExponent)
end

-- Hadiah koin saat mencapai `newLevel`.
function Formulas.LevelUpReward(newLevel: number): number
	return Balance.LevelUpCoinsPerLevel * newLevel
end

-- Menambahkan XP. Mengembalikan level baru, sisa XP, dan daftar level yang baru dicapai.
function Formulas.ApplyXP(level: number, xp: number, gain: number): (number, number, { number })
	local reached: { number } = {}
	local lvl = level
	local cur = xp + math.max(0, gain)
	while lvl < Balance.MaxLevel do
		local need = Formulas.XPToNext(lvl)
		if cur < need then
			break
		end
		cur -= need
		lvl += 1
		table.insert(reached, lvl)
	end
	if lvl >= Balance.MaxLevel then
		cur = 0
	end
	return lvl, cur, reached
end

-- Total XP kumulatif yang dibutuhkan untuk mencapai `level` dari Lv 1.
function Formulas.TotalXPForLevel(level: number): number
	local total = 0
	for l = 1, level - 1 do
		total += Formulas.XPToNext(l)
	end
	return total
end

function Formulas.CatchXP(rarity: Rarity, mutation: Mutation): number
	local base = Balance.XPByRarity[rarity] or 0
	local mul = Balance.MutationXPMul[mutation] or 1
	return math.floor(base * mul + 0.5)
end

-- =========================================================================
-- Harga & poin
-- =========================================================================

function Formulas.AverageWeight(species: FishSpecies): number
	return (species.MinWeight + species.MaxWeight) / 2
end

-- Harga jual = round(base × (berat/rata-rata)^0,75 × pengali mutasi × pengali event). Protected = 0.
function Formulas.SellPrice(species: FishSpecies, weight: number, mutation: Mutation, eventPriceMul: number?): number
	if species.Protected then
		return 0
	end
	local avg = Formulas.AverageWeight(species)
	local ratio = if avg > 0 then math.max(weight, 0) / avg else 1
	local raw = species.BasePrice
		* ratio ^ Balance.SellWeightExponent
		* (Balance.MutationPriceMul[mutation] or 1)
		* (eventPriceMul or 1)
	return math.max(1, math.floor(raw + 0.5))
end

function Formulas.EventPriceMul(event: EventId): number
	return Balance.EventPriceMul[event] or 1
end

function Formulas.ConservationPoints(species: FishSpecies): number
	if species.Protected then
		return species.ProtectedPoints or 0
	end
	return Balance.ConservationByRarity[species.Rarity] or 0
end

-- =========================================================================
-- Luck, mutasi, waktu tunggu
-- =========================================================================

function Formulas.EffectiveLuck(
	rod: RodDef?,
	bait: BaitDef?,
	isNight: boolean,
	weather: WeatherId,
	event: EventId,
	zone: string
): number
	local luck = (if rod then rod.Luck else 0) + (if bait then bait.Luck else 0)
	if bait and bait.NightLuck and isNight then
		luck += bait.NightLuck
	end
	luck += Balance.WeatherLuck[weather] or 0
	local zoneLuck = Balance.EventZoneLuck[event]
	if zoneLuck and zoneLuck[zone] then
		luck += zoneLuck[zone]
	end
	return luck
end

function Formulas.MutationMultiplier(rod: RodDef?, bait: BaitDef?, event: EventId): number
	local m = 1
	if rod and rod.MutationMul then
		m *= rod.MutationMul
	end
	if bait and bait.MutationMul then
		m *= bait.MutationMul
	end
	m *= Balance.EventMutationMul[event] or 1
	return m
end

-- Waktu tunggu gigitan (detik).
function Formulas.WaitTime(rng: Random, rod: RodDef?, bait: BaitDef?, weather: WeatherId): number
	local f = Balance.Fishing
	local base = rng:NextNumber(f.WaitMin, f.WaitMax)
	local rodMul = if rod then rod.WaitMul else 1
	local baitMul = if bait then bait.WaitMul else f.NoBaitWaitMul
	local envMul = Balance.WeatherWaitMul[weather] or 1
	return base * rodMul * baitMul * envMul
end

-- =========================================================================
-- Roll ikan: rarity → spesies → berat → mutasi
-- =========================================================================

function Formulas.SpeciesAvailable(species: FishSpecies, ctx: RollContext): boolean
	if not table.find(species.Zones, ctx.Zone) then
		return false
	end
	if species.Time == "Day" and ctx.IsNight then
		return false
	end
	if species.Time == "Night" and not ctx.IsNight then
		return false
	end
	if species.Weather ~= nil and species.Weather ~= ctx.Weather then
		return false
	end
	if species.Event ~= nil and species.Event ~= ctx.Event then
		return false
	end
	return true
end

function Formulas.AvailableByRarity(speciesList: { FishSpecies }, ctx: RollContext): { [string]: { FishSpecies } }
	local out: { [string]: { FishSpecies } } = {}
	for _, s in speciesList do
		if Formulas.SpeciesAvailable(s, ctx) then
			local bucket = out[s.Rarity]
			if bucket == nil then
				bucket = {}
				out[s.Rarity] = bucket
			end
			table.insert(bucket, s)
		end
	end
	return out
end

-- Bobot efektif per rarity = dasar × (1 + Luck)^k; rarity tanpa spesies valid dikeluarkan.
function Formulas.RarityWeights(luck: number, available: { [string]: { FishSpecies } }): { [string]: number }
	local weights: { [string]: number } = {}
	local l = math.max(luck, 0)
	for _, rarity in Balance.RarityOrder do
		local bucket = available[rarity]
		if bucket ~= nil and #bucket > 0 then
			weights[rarity] = Balance.RarityBaseWeight[rarity] * (1 + l) ^ Balance.RarityLuckExponent[rarity]
		else
			weights[rarity] = 0
		end
	end
	return weights
end

function Formulas.RollRarity(rng: Random, luck: number, available: { [string]: { FishSpecies } }): Rarity?
	local weights = Formulas.RarityWeights(luck, available)
	local entries: { WeightedRandom.Entry<Rarity> } = {}
	for _, rarity in Balance.RarityOrder do
		local w = weights[rarity]
		if w ~= nil and w > 0 then
			table.insert(entries, { Item = rarity :: Rarity, Weight = w })
		end
	end
	local picked = WeightedRandom.Pick(entries, rng)
	return if picked == nil then nil else picked :: Rarity
end

function Formulas.RollSpecies(rng: Random, candidates: { FishSpecies }): FishSpecies?
	local entries: { WeightedRandom.Entry<FishSpecies> } = {}
	for _, s in candidates do
		table.insert(entries, { Item = s, Weight = s.SpawnWeight or 1 })
	end
	return WeightedRandom.Pick(entries, rng)
end

-- Berat = min + (max − min) × r^2,2, dibulatkan 0,001 kg.
function Formulas.RollWeight(rng: Random, species: FishSpecies): number
	local r = rng:NextNumber()
	local w = species.MinWeight + (species.MaxWeight - species.MinWeight) * r ^ Balance.WeightExponent
	return math.floor(w * 1000 + 0.5) / 1000
end

function Formulas.RollMutation(rng: Random, mutationMul: number): Mutation
	local r = rng:NextNumber()
	local acc = 0
	for _, m in Balance.MutationOrder do
		acc += (Balance.MutationChance[m] or 0) * mutationMul
		if r < acc then
			return m :: Mutation
		end
	end
	return "None"
end

export type RollResult = {
	Species: FishSpecies,
	Rarity: Rarity,
	Weight: number,
	Mutation: Mutation,
}

function Formulas.RollFish(rng: Random, speciesList: { FishSpecies }, ctx: RollContext): RollResult?
	local available = Formulas.AvailableByRarity(speciesList, ctx)
	local rarity = Formulas.RollRarity(rng, ctx.Luck, available)
	if rarity == nil then
		return nil
	end
	local species = Formulas.RollSpecies(rng, available[rarity])
	if species == nil then
		return nil
	end
	return {
		Species = species,
		Rarity = rarity :: Rarity,
		Weight = Formulas.RollWeight(rng, species),
		Mutation = Formulas.RollMutation(rng, ctx.MutationMul),
	}
end

-- =========================================================================
-- Lempar & minigame
-- =========================================================================

-- Titik jatuh horizontal: posisi + arah × lerp(8, CastDistance, power). Y mengikuti origin.
function Formulas.CastLanding(origin: Vector3, dirX: number, dirZ: number, power: number, castDistance: number): Vector3
	local dir = Vector3.new(dirX, 0, dirZ)
	if dir.Magnitude < 1e-3 then
		dir = Vector3.new(0, 0, 1)
	end
	dir = dir.Unit
	local p = math.clamp(power, 0, 1)
	local minD = Balance.Fishing.CastMinDistance
	local dist = minD + (castDistance - minD) * p
	return origin + dir * dist
end

function Formulas.FlightTime(power: number): number
	local f = Balance.Fishing
	return f.FlightTimeMin + (f.FlightTimeMax - f.FlightTimeMin) * math.clamp(power, 0, 1)
end

-- Waktu minimum teoretis menyelesaikan minigame (ikan selalu di dalam zona).
function Formulas.MinReelDuration(reelSpeed: number): number
	local f = Balance.Fishing
	return (1 - f.ReelStart) / (f.ReelGain * reelSpeed)
end

function Formulas.IsHard(weight: number, rod: RodDef): boolean
	return weight > rod.MaxWeight
end

-- Validasi klaim sukses minigame dari client.
function Formulas.ValidateReelClaim(elapsed: number, reelSpeed: number): (boolean, string?)
	local f = Balance.Fishing
	if elapsed < Formulas.MinReelDuration(reelSpeed) * f.MinDurationFactor then
		return false, "terlalu cepat"
	end
	if elapsed > f.ReelTimeLimit + f.ReelTimeTolerance then
		return false, "kedaluwarsa"
	end
	return true, nil
end

-- =========================================================================
-- Zona: pilih zona bervolume terkecil yang memuat titik.
-- =========================================================================

export type ZoneBox = { Id: string, CFrame: CFrame, Size: Vector3 }

function Formulas.PointInBox(point: Vector3, cf: CFrame, size: Vector3): boolean
	local rel = cf:PointToObjectSpace(point)
	return math.abs(rel.X) <= size.X / 2 and math.abs(rel.Y) <= size.Y / 2 and math.abs(rel.Z) <= size.Z / 2
end

function Formulas.PickZone(point: Vector3, zones: { ZoneBox }): string?
	local best: string? = nil
	local bestVolume = math.huge
	for _, z in zones do
		if Formulas.PointInBox(point, z.CFrame, z.Size) then
			local v = z.Size.X * z.Size.Y * z.Size.Z
			if v < bestVolume then
				bestVolume = v
				best = z.Id
			end
		end
	end
	return best
end

-- =========================================================================
-- Tas & pembelian
-- =========================================================================

function Formulas.CanAddFish(count: number, capacity: number, adding: number?): boolean
	return count + (adding or 1) <= capacity
end

export type PurchaseCheck = {
	Ok: boolean,
	Reason: string?,
	Price: number,
	Currency: "Coins" | "Points",
	Quantity: number,
}

-- Pemeriksaan pembelian murni terhadap data profil (dipakai ShopService & spesifikasi uji).
type DataLike = Types.ProfileData

local function fail(reason: string, price: number, currency: "Coins" | "Points", qty: number): PurchaseCheck
	return { Ok = false, Reason = reason, Price = price, Currency = currency, Quantity = qty }
end

function Formulas.CheckRodPurchase(data: DataLike, rod: RodDef): PurchaseCheck
	local price = rod.Price
	if rod.Source ~= "Shop" or price == nil then
		return fail("NotForSale", 0, "Coins", 1)
	end
	if table.find(data.Rods, rod.Id) then
		return fail("Owned", price, "Coins", 1)
	end
	if data.Level < rod.Level then
		return fail("Level", price, "Coins", 1)
	end
	if data.Coins < price then
		return fail("Coins", price, "Coins", 1)
	end
	return { Ok = true, Reason = nil, Price = price, Currency = "Coins", Quantity = 1 }
end

-- qty: 1/10/50 atau 0 = "maks" (sebanyak koin & tumpukan memungkinkan).
function Formulas.CheckBaitPurchase(data: DataLike, bait: BaitDef, qty: number): PurchaseCheck
	local price = bait.Price
	if bait.Source ~= "Shop" or price == nil or price <= 0 then
		return fail("NotForSale", 0, "Coins", 0)
	end
	local owned = data.Bait[bait.Id] or 0
	local room = Balance.BaitMaxStack - owned
	local want = qty
	if qty == 0 then
		want = math.min(math.floor(data.Coins / price), room)
	end
	if want <= 0 then
		if room <= 0 then
			return fail("StackFull", price, "Coins", 0)
		end
		return fail("Coins", price, "Coins", 0)
	end
	if want > room then
		return fail("StackFull", price * want, "Coins", want)
	end
	local total = price * want
	if data.Coins < total then
		return fail("Coins", total, "Coins", want)
	end
	return { Ok = true, Reason = nil, Price = total, Currency = "Coins", Quantity = want }
end

function Formulas.CheckBagPurchase(data: DataLike): PurchaseCheck
	local nextTier = Bags.NextTier(data.BagCapacity)
	if nextTier == nil then
		return fail("Maxed", 0, "Coins", 1)
	end
	if data.Coins < nextTier.Price then
		return fail("Coins", nextTier.Price, "Coins", 1)
	end
	return { Ok = true, Reason = nil, Price = nextTier.Price, Currency = "Coins", Quantity = 1 }
end

function Formulas.CheckCosmeticPurchase(data: DataLike, cosmetic: CosmeticDef): PurchaseCheck
	if data.Cosmetics.Owned[cosmetic.Id] then
		return fail("Owned", cosmetic.Price or cosmetic.PointsPrice or 0, "Coins", 1)
	end
	if cosmetic.Source == "Shop" and cosmetic.Price ~= nil then
		if data.Coins < cosmetic.Price then
			return fail("Coins", cosmetic.Price, "Coins", 1)
		end
		return { Ok = true, Reason = nil, Price = cosmetic.Price, Currency = "Coins", Quantity = 1 }
	elseif cosmetic.Source == "Points" and cosmetic.PointsPrice ~= nil then
		if data.ConservationPoints < cosmetic.PointsPrice then
			return fail("Points", cosmetic.PointsPrice, "Points", 1)
		end
		return { Ok = true, Reason = nil, Price = cosmetic.PointsPrice, Currency = "Points", Quantity = 1 }
	end
	return fail("NotForSale", 0, "Coins", 1)
end

-- =========================================================================
-- Quest harian
-- =========================================================================

function Formulas.DailyReward(level: number): (number, number)
	return Balance.DailyCoinBase + Balance.DailyCoinPerLevel * level, Balance.DailyXPBase + Balance.DailyXPPerLevel * level
end

-- Memilih `count` id unik dari pool secara deterministik dari seed (mis. UserId + hari WIB).
function Formulas.PickDaily(poolIds: { string }, count: number, seed: number): { string }
	local rng = Random.new(seed)
	local pool = table.clone(poolIds)
	local out: { string } = {}
	for _ = 1, math.min(count, #pool) do
		local i = rng:NextInteger(1, #pool)
		table.insert(out, pool[i])
		table.remove(pool, i)
	end
	return out
end

-- =========================================================================
-- Nilai ikan, barter, trade
-- =========================================================================

-- Nilai ikan untuk perbandingan (harga jual tanpa event). Protected bernilai 0.
function Formulas.FishValue(item: FishItem, speciesById: { [string]: FishSpecies }): number
	local species = speciesById[item.SpeciesId]
	if species == nil then
		return 0
	end
	return Formulas.SellPrice(species, item.Weight, item.Mutation, 1)
end

-- Memilih ikan bernilai terendah yang memenuhi resep (tidak terkunci, rarity cocok, bukan Protected bila dikecualikan).
function Formulas.SelectBarterFish(
	fish: { FishItem },
	recipe: BarterRecipe,
	speciesById: { [string]: FishSpecies }
): ({ FishItem }?, string?)
	local candidates: { FishItem } = {}
	for _, item in fish do
		local species = speciesById[item.SpeciesId]
		if species ~= nil and not item.Locked and species.Rarity == recipe.Rarity then
			if not (recipe.ExcludeProtected and species.Protected) then
				table.insert(candidates, item)
			end
		end
	end
	if #candidates < recipe.Count then
		return nil, "NotEnough"
	end
	table.sort(candidates, function(a, b)
		local va = Formulas.FishValue(a, speciesById)
		local vb = Formulas.FishValue(b, speciesById)
		if va ~= vb then
			return va < vb
		end
		if a.Weight ~= b.Weight then
			return a.Weight < b.Weight
		end
		return a.Uid < b.Uid
	end)
	local chosen: { FishItem } = {}
	for i = 1, recipe.Count do
		table.insert(chosen, candidates[i])
	end
	return chosen, nil
end

export type TradeInventory = {
	Fish: { FishItem },
	Bait: { [string]: number },
	Coins: number,
	BagCapacity: number,
}

-- Validasi satu sisi penawaran terhadap inventaris pemiliknya.
function Formulas.ValidateOffer(
	inv: TradeInventory,
	offer: TradeOffer,
	speciesById: { [string]: FishSpecies }
): (boolean, string?)
	if #offer.Fish > Balance.Trade.MaxFish then
		return false, "TooManyFish"
	end
	local byUid: { [string]: FishItem } = {}
	for _, item in inv.Fish do
		byUid[item.Uid] = item
	end
	local seen: { [string]: boolean } = {}
	for _, uid in offer.Fish do
		local item = byUid[uid]
		if item == nil then
			return false, "NotOwned"
		end
		if seen[uid] then
			return false, "Duplicate"
		end
		seen[uid] = true
		if item.Locked then
			return false, "Locked"
		end
		local species = speciesById[item.SpeciesId]
		if species == nil or species.Protected then
			return false, "Protected"
		end
	end
	for baitId, qty in offer.Bait do
		if qty < 0 or qty ~= math.floor(qty) then
			return false, "BadQuantity"
		end
		if (inv.Bait[baitId] or 0) < qty then
			return false, "NotEnoughBait"
		end
	end
	if offer.Coins < 0 or offer.Coins ~= math.floor(offer.Coins) then
		return false, "BadQuantity"
	end
	if offer.Coins > inv.Coins then
		return false, "NotEnoughCoins"
	end
	return true, nil
end

-- Validasi penuh kedua sisi termasuk kapasitas tas dan batas tumpukan umpan setelah pertukaran.
function Formulas.ValidateTrade(
	invA: TradeInventory,
	offerA: TradeOffer,
	invB: TradeInventory,
	offerB: TradeOffer,
	speciesById: { [string]: FishSpecies }
): (boolean, string?)
	local okA, reasonA = Formulas.ValidateOffer(invA, offerA, speciesById)
	if not okA then
		return false, "A:" .. tostring(reasonA)
	end
	local okB, reasonB = Formulas.ValidateOffer(invB, offerB, speciesById)
	if not okB then
		return false, "B:" .. tostring(reasonB)
	end
	if #invA.Fish - #offerA.Fish + #offerB.Fish > invA.BagCapacity then
		return false, "A:BagFull"
	end
	if #invB.Fish - #offerB.Fish + #offerA.Fish > invB.BagCapacity then
		return false, "B:BagFull"
	end
	for baitId, qty in offerB.Bait do
		if (invA.Bait[baitId] or 0) - (offerA.Bait[baitId] or 0) + qty > Balance.BaitMaxStack then
			return false, "A:StackFull"
		end
	end
	for baitId, qty in offerA.Bait do
		if (invB.Bait[baitId] or 0) - (offerB.Bait[baitId] or 0) + qty > Balance.BaitMaxStack then
			return false, "B:StackFull"
		end
	end
	return true, nil
end

-- Estimasi nilai penawaran: harga ikan + harga umpan (umpan barter dinilai 100) + koin.
function Formulas.OfferValue(
	inv: TradeInventory,
	offer: TradeOffer,
	speciesById: { [string]: FishSpecies },
	baitById: { [string]: BaitDef }
): number
	local byUid: { [string]: FishItem } = {}
	for _, item in inv.Fish do
		byUid[item.Uid] = item
	end
	local total = offer.Coins
	for _, uid in offer.Fish do
		local item = byUid[uid]
		if item then
			total += Formulas.FishValue(item, speciesById)
		end
	end
	for baitId, qty in offer.Bait do
		local def = baitById[baitId]
		local unit = if def and def.Price then def.Price else 100
		total += unit * qty
	end
	return total
end

function Formulas.IsTradeUnfair(valueA: number, valueB: number): boolean
	local hi = math.max(valueA, valueB)
	local lo = math.max(math.min(valueA, valueB), 1)
	return hi > 0 and hi / lo > Balance.Trade.ImbalanceRatio
end

return Formulas
