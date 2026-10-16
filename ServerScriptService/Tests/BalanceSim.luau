--!strict
-- BalanceSim: simulasi progres pemain memakai rumus & Config yang sama dengan game (Formulas, Balance, Fish,
-- Rods, Bait, Bags, Quests). Dipakai untuk mengecek target GDD 4.2: joran ke-2 ±5 mnt, ke-3 ±45 mnt,
-- ke-4 ±2,5 jam, ke-5 ±7 jam (joran beli ke-5 = Legenda Nusantara), Laguna ±30 mnt, Laut Dalam ±1 jam.
-- Jalankan: Lune `scripts/test.ps1 -Balance` atau di Studio: require(Tests.BalanceSim).PrintReport(RunDefault(8), print)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local Formulas = require(Shared.Formulas)
local Format = require(Shared.Util.Format)
local Balance = require(Shared.Config.Balance)
local Fish = require(Shared.Config.Fish)
local Rods = require(Shared.Config.Rods)
local Bait = require(Shared.Config.Bait)
local Bags = require(Shared.Config.Bags)
local Zones = require(Shared.Config.Zones)
local Quests = require(Shared.Config.Quests)

type FishSpecies = Types.FishSpecies

local BalanceSim = {}

export type SimProfile = { Name: string, CatchesPerMinute: number, Hours: number }

export type Report = {
	Profile: SimProfile,
	Runs: number,
	Milestones: { [string]: number? },
	MilestoneHits: { [string]: number },
	FinalLevel: number,
	FinalCoins: number,
	TotalEarned: number,
	TotalCaught: number,
	Species: number,
}

-- Kunci milestone → label & target (menit).
type Target = { Key: string, Label: string, Target: number? }
local TARGETS: { Target } = {
	{ Key = "rod_fiber", Label = "Joran ke-2 (Fiberglass)", Target = 5 },
	{ Key = "rod_karbon", Label = "Joran ke-3 (Karbon)", Target = 45 },
	{ Key = "rod_samudra", Label = "Joran ke-4 (Samudra)", Target = 150 },
	{ Key = "rod_legenda", Label = "Joran ke-5 (Legenda)", Target = 420 },
	{ Key = "rod_emas_bahari", Label = "Joran Emas Bahari (barter)", Target = nil },
	{ Key = "zone_Mangrove", Label = "Laguna Bakau terbuka (Lv 5)", Target = 30 },
	{ Key = "zone_DeepSea", Label = "Laut Dalam (Lv 10 + kapal)", Target = 60 },
}
BalanceSim.Targets = TARGETS

type State = {
	T: number,
	Coins: number,
	Earned: number,
	Level: number,
	XP: number,
	Rods: { [string]: boolean },
	Rod: string,
	Bait: { [string]: number },
	BagCap: number,
	Bag: { { Species: FishSpecies, Weight: number, Mutation: string } },
	Fishdex: { [string]: boolean },
	Claimed: { [string]: boolean },
	Caught: number,
	Story: number,
	StoryProgress: number,
	Daily: { { Id: string, Progress: number, Done: boolean } },
	Ferry: boolean,
	Points: number,
	Milestones: { [string]: number },
	Weather: string,
	WeatherEnds: number,
}

local function addXP(s: State, amount: number)
	local before = s.Level
	local lvl, xp, reached = Formulas.ApplyXP(s.Level, s.XP, amount)
	s.Level = lvl
	s.XP = xp
	for _, l in reached do
		local reward = Formulas.LevelUpReward(l)
		s.Coins += reward
		s.Earned += reward
	end
	if before < 5 and s.Level >= 5 and s.Milestones.zone_Mangrove == nil then
		s.Milestones.zone_Mangrove = s.T
	end
end

local function addCoins(s: State, n: number)
	s.Coins += n
	s.Earned += n
end

local function rodDef(s: State): Types.RodDef
	return Rods.Get(s.Rod) :: Types.RodDef
end

local function bestBait(s: State): Types.BaitDef?
	local best: Types.BaitDef? = nil
	for _, b in Bait.List do
		if (s.Bait[b.Id] or 0) > 0 then
			if best == nil or b.Luck > best.Luck then
				best = b
			end
		end
	end
	return best
end

-- Belanja: joran berikutnya, umpan, upgrade tas.
local function shop(s: State)
	for _, r in Rods.List do
		if r.Source == "Shop" and r.Price and not s.Rods[r.Id] and s.Level >= r.Level and s.Coins >= r.Price then
			s.Coins -= r.Price
			s.Rods[r.Id] = true
			if r.Order > (Rods.Get(s.Rod) :: Types.RodDef).Order then
				s.Rod = r.Id
			end
			s.Milestones["rod_" .. r.Id] = s.Milestones["rod_" .. r.Id] or s.T
		end
	end
	-- Umpan terbaik yang harganya ≤ 2% koin, dibeli 50 sekaligus.
	local pick: Types.BaitDef? = nil
	for _, b in Bait.List do
		if b.Source == "Shop" and b.Price and b.Price * 50 <= math.max(s.Coins * 0.1, 100) then
			if pick == nil or b.Luck > pick.Luck then
				pick = b
			end
		end
	end
	if pick and (s.Bait[pick.Id] or 0) < 10 and s.Coins >= (pick.Price :: number) * 50 then
		s.Coins -= (pick.Price :: number) * 50
		s.Bait[pick.Id] = (s.Bait[pick.Id] or 0) + 50
	end
	local nextBag = Bags.NextTier(s.BagCap)
	if nextBag and nextBag.Price <= s.Coins * 0.25 then
		s.Coins -= nextBag.Price
		s.BagCap = nextBag.Capacity
	end
end

local function sellAll(s: State)
	local kept = {}
	local total = 0
	local count = 0
	for _, f in s.Bag do
		if f.Species.Protected then
			table.insert(kept, f)
		else
			total += Formulas.SellPrice(f.Species, f.Weight, f.Mutation, 1)
			count += 1
		end
	end
	s.Bag = kept
	addCoins(s, total)
	s.T += 30
	return total, count
end

local function releaseProtected(s: State): number
	local kept = {}
	local released = 0
	for _, f in s.Bag do
		if f.Species.Protected then
			s.Points += Formulas.ConservationPoints(f.Species)
			released += 1
		else
			table.insert(kept, f)
		end
	end
	s.Bag = kept
	return released
end

local function zoneFor(s: State): string
	if s.Level >= 10 then
		if not s.Ferry then
			if s.Coins >= Balance.Ferry.Price then
				s.Coins -= Balance.Ferry.Price
				s.Ferry = true
				s.T += 30
				s.Milestones.zone_DeepSea = s.Milestones.zone_DeepSea or s.T
			else
				return "Mangrove"
			end
		end
		return "DeepSea"
	elseif s.Level >= 5 then
		return "Mangrove"
	end
	-- Quest 6 (Ujung Dermaga) sekali, sisanya pantai.
	local story = Quests.StoryAt(s.Story)
	if story and story.Objective.Type == "CatchInZone" and story.Objective.Zone == "Pier" then
		return "Pier"
	end
	return "Shore"
end

local function questEvent(s: State, kind: string, amount: number, species: FishSpecies?, zone: string?, weight: number?, night: boolean?, mutated: boolean?)
	-- Cerita (disederhanakan: quest diterima segera setelah syarat level).
	local q = Quests.StoryAt(s.Story)
	if q and (q.Level == nil or s.Level >= (q.Level :: number)) then
		local o = q.Objective
		local add = 0
		if o.Type == "CatchFish" and kind == "Catch" then
			add = 1
		elseif o.Type == "CatchInZone" and kind == "Catch" and zone == o.Zone then
			add = 1
		elseif o.Type == "CatchRarity" and kind == "Catch" and species and species.Rarity == o.Rarity then
			add = 1
		elseif o.Type == "SellCoins" and kind == "Sell" then
			add = amount
		elseif o.Type == "Ferry" and kind == "Ferry" then
			add = 1
		elseif o.Type == "ReleaseProtected" and kind == "ReleaseProtected" then
			add = amount
		elseif o.Type == "DiscoverSpecies" then
			local n = 0
			for _ in s.Fishdex do
				n += 1
			end
			s.StoryProgress = n
		elseif o.Type == "TalkNpc" or o.Type == "BuyBait" or o.Type == "BuyCosmetic" then
			add = o.Count
		end
		s.StoryProgress += add
		if s.StoryProgress >= o.Count then
			if q.Reward.Coins then
				addCoins(s, q.Reward.Coins)
			end
			if q.Reward.XP then
				addXP(s, q.Reward.XP)
			end
			if o.Type == "BuyCosmetic" then
				s.Coins = math.max(0, s.Coins - 250)
			elseif o.Type == "BuyBait" then
				s.Coins = math.max(0, s.Coins - 10)
				s.Bait.cacing = (s.Bait.cacing or 0) + 5
			end
			s.Story += 1
			s.StoryProgress = 0
		end
	end
	-- Harian
	for _, d in s.Daily do
		if not d.Done then
			local def = Quests.DailyById[d.Id]
			local o = def.Objective
			local add = 0
			if kind == "Catch" then
				if o.Type == "CatchFish" then
					add = 1
				elseif o.Type == "CatchRarityAtLeast" and species and (Balance.RarityRank[species.Rarity] or 0) >= (Balance.RarityRank[o.Rarity or "Rare"] or 3) then
					add = 1
				elseif o.Type == "CatchWeightAtLeast" and (weight or 0) >= (o.Weight or 10) then
					add = 1
				elseif o.Type == "CatchAtNight" and night then
					add = 1
				elseif o.Type == "CatchMutated" and mutated then
					add = 1
				end
			elseif kind == "Sell" and o.Type == "SellCoins" then
				add = amount
			elseif kind == "UseBait" and o.Type == "UseBait" then
				add = 1
			elseif kind == "Release" and o.Type == "ReleaseFish" then
				add = amount
			end
			d.Progress += add
			if d.Progress >= o.Count then
				d.Done = true
				local coins, xp = Formulas.DailyReward(s.Level)
				addCoins(s, coins)
				addXP(s, xp)
			end
		end
	end
end

local function checkFishdex(s: State)
	for _, z in Zones.List do
		if not s.Claimed[z.Id] then
			local complete = true
			for _, sp in Fish.InZone(z.Id) do
				if not s.Fishdex[sp.Id] then
					complete = false
					break
				end
			end
			if complete then
				s.Claimed[z.Id] = true
				addCoins(s, z.FishdexReward)
			end
		end
	end
end

local function tryBarterRod(s: State)
	if s.Rods.emas_bahari or s.Level < 20 or s.Coins < 2000 then
		return
	end
	for i, f in s.Bag do
		if f.Species.Rarity == "Epic" and not f.Species.Protected then
			table.remove(s.Bag, i)
			s.Coins -= 2000
			s.Rods.emas_bahari = true
			s.Milestones.rod_emas_bahari = s.T
			if (Rods.Get("emas_bahari") :: Types.RodDef).Order > (Rods.Get(s.Rod) :: Types.RodDef).Order then
				s.Rod = "emas_bahari"
			end
			return
		end
	end
end

function BalanceSim.RunOnce(profile: SimProfile, seed: number): State
	local rng = Random.new(seed)
	local s: State = {
		T = 0,
		Coins = Balance.StartCoins,
		Earned = 0,
		Level = 1,
		XP = 0,
		Rods = { [Balance.StartRod] = true },
		Rod = Balance.StartRod,
		Bait = {},
		BagCap = Balance.StartBagCapacity,
		Bag = {},
		Fishdex = {},
		Claimed = {},
		Caught = 0,
		Story = 1,
		StoryProgress = 0,
		Daily = {},
		Ferry = false,
		Points = 0,
		Milestones = {},
		Weather = "Cerah",
		WeatherEnds = 0,
	}
	local ids = {}
	for _, d in Quests.Daily do
		table.insert(ids, d.Id)
	end
	for _, id in Formulas.PickDaily(ids, Balance.DailyCount, seed) do
		table.insert(s.Daily, { Id = id, Progress = 0, Done = false })
	end
	-- Quest 1 & 2 di awal (bicara + beli cacing).
	questEvent(s, "Talk", 1)
	questEvent(s, "BuyBait", 5)

	local step = 60 / profile.CatchesPerMinute
	local limit = profile.Hours * 3600
	while s.T < limit do
		shop(s)
		tryBarterRod(s)
		if s.T >= s.WeatherEnds then
			local w = 0
			local r = rng:NextNumber()
			s.Weather = "Cerah"
			for _, id in Balance.WeatherOrder do
				w += Balance.WeatherChance[id]
				if r < w then
					s.Weather = id
					break
				end
			end
			s.WeatherEnds = s.T + rng:NextNumber(Balance.WeatherDurationMin, Balance.WeatherDurationMax)
		end
		local zone = zoneFor(s)
		if zone == "DeepSea" then
			questEvent(s, "Ferry", 1)
		end
		local clock = Formulas.ClockTime(s.T, 0, Balance.StartClockTime, Balance.DayLengthSeconds)
		local night = Formulas.IsNight(clock)
		local rod = rodDef(s)
		local bait = bestBait(s)
		if bait then
			s.Bait[bait.Id] -= 1
			questEvent(s, "UseBait", 1)
		end
		local ctx: Types.RollContext = {
			Zone = zone,
			IsNight = night,
			Weather = s.Weather,
			Event = "None",
			Luck = Formulas.EffectiveLuck(rod, bait, night, s.Weather, "None", zone),
			MutationMul = Formulas.MutationMultiplier(rod, bait, "None"),
		}
		local roll = Formulas.RollFish(rng, Fish.List, ctx)
		s.T += step
		if roll then
			-- Peluang lepas di minigame: makin tinggi rarity & mode Sulit makin sering gagal.
			local hard = Formulas.IsHard(roll.Weight, rod)
			local rank = Balance.RarityRank[roll.Rarity] or 1
			local failChance = 0.04 + rank * 0.03 + (if hard then 0.25 else 0)
			if rng:NextNumber() >= failChance then
				s.Caught += 1
				s.Fishdex[roll.Species.Id] = true
				addXP(s, Formulas.CatchXP(roll.Rarity, roll.Mutation))
				table.insert(s.Bag, { Species = roll.Species, Weight = roll.Weight, Mutation = roll.Mutation })
				questEvent(s, "Catch", 1, roll.Species, zone, roll.Weight, night, roll.Mutation ~= "None")
				checkFishdex(s)
				if roll.Species.Protected then
					local n = releaseProtected(s)
					questEvent(s, "ReleaseProtected", n)
					questEvent(s, "Release", n)
				end
			end
		end
		if #s.Bag >= s.BagCap then
			local total = sellAll(s)
			questEvent(s, "Sell", total)
		end
	end
	return s
end

function BalanceSim.Run(profile: SimProfile, runs: number?): Report
	local n = runs or 6
	local sums: { [string]: number } = {}
	local hits: { [string]: number } = {}
	local level, coins, earned, caught, species = 0, 0, 0, 0, 0
	for i = 1, n do
		local s = BalanceSim.RunOnce(profile, 1000 + i * 7919)
		for key, t in s.Milestones do
			sums[key] = (sums[key] or 0) + t
			hits[key] = (hits[key] or 0) + 1
		end
		level += s.Level
		coins += s.Coins
		earned += s.Earned
		caught += s.Caught
		local sp = 0
		for _ in s.Fishdex do
			sp += 1
		end
		species += sp
	end
	local milestones: { [string]: number? } = {}
	for key, total in sums do
		milestones[key] = total / hits[key] / 60
	end
	return {
		Profile = profile,
		Runs = n,
		Milestones = milestones,
		MilestoneHits = hits,
		FinalLevel = level / n,
		FinalCoins = coins / n,
		TotalEarned = earned / n,
		TotalCaught = caught / n,
		Species = species / n,
	}
end

function BalanceSim.RunDefault(hours: number?): { Report }
	local h = hours or 8
	return {
		BalanceSim.Run({ Name = "santai", CatchesPerMinute = 2, Hours = h }),
		BalanceSim.Run({ Name = "aktif", CatchesPerMinute = 4, Hours = h }),
	}
end

local function minutesText(m: number?): string
	if m == nil then
		return "tidak tercapai"
	end
	if m >= 90 then
		return Format.Decimal(m / 60, 1) .. " jam"
	end
	return Format.Decimal(m, 1) .. " mnt"
end

function BalanceSim.PrintReport(reports: { Report }, log: (...any) -> ())
	for _, r in reports do
		log(string.format(
			"[BALANCE] Profil %s (%d tangkapan/menit), %s jam, rata-rata %d simulasi",
			r.Profile.Name,
			r.Profile.CatchesPerMinute,
			Format.Decimal(r.Profile.Hours, 0),
			r.Runs
		))
		for _, target in TARGETS do
			local m = r.Milestones[target.Key]
			local hitText = if r.MilestoneHits[target.Key] and r.MilestoneHits[target.Key] < r.Runs
				then string.format(" (%d/%d simulasi)", r.MilestoneHits[target.Key], r.Runs)
				else ""
			local targetText = if target.Target then " | target ±" .. minutesText(target.Target) else ""
			log(string.format("[BALANCE]   %-30s %s%s%s", target.Label, minutesText(m), hitText, targetText))
		end
		log(string.format(
			"[BALANCE]   Akhir: Lv %s · koin %s · total pendapatan %s · %s ikan · %s spesies",
			Format.Decimal(r.FinalLevel, 1),
			Format.Int(r.FinalCoins),
			Format.Int(r.TotalEarned),
			Format.Int(r.TotalCaught),
			Format.Decimal(r.Species, 1)
		))
	end
end

return BalanceSim
