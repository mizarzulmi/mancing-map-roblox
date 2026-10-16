--!strict
-- Pemilihan ikan barter: bernilai terendah, tidak terkunci, bukan Protected, cukup jumlahnya.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Formulas = require(Shared.Formulas)
local Fish = require(Shared.Config.Fish)
local Barter = require(Shared.Config.Barter)
local Types = require(Shared.Types)
local TestRunner = require(script.Parent.Parent.TestRunner)

local function item(uid: string, species: string, weight: number, locked: boolean?, mutation: Types.Mutation?): Types.FishItem
	return {
		Uid = uid,
		SpeciesId = species,
		Weight = weight,
		Mutation = mutation or "None",
		Zone = "Shore",
		CaughtAt = 0,
		Locked = locked == true,
	}
end

return function(t: TestRunner.T)
	local rareRecipe = Barter.ById.barter_umpan_emas
	local fish = {
		item("r1", "pari_totol", 20),
		item("r2", "pari_totol", 3),
		item("r3", "barakuda", 4),
		item("r4", "badut", 0.1),
		item("r5", "gt", 40),
		item("r6", "lobster_mutiara", 1, true),
		item("r7", "barakuda", 18, false, "Emas"),
		item("c1", "kembung", 0.3),
	}
	local chosen = Formulas.SelectBarterFish(fish, rareRecipe, Fish.ById)
	t.Check(chosen ~= nil and #(chosen :: any) == 5, "memilih tepat 5 ikan Rare")
	local picked: { [string]: boolean } = {}
	if chosen then
		for _, f in chosen do
			picked[f.Uid] = true
		end
	end
	t.Check(not picked.r6, "ikan terkunci tidak dipilih")
	t.Check(not picked.c1, "ikan rarity lain tidak dipilih")
	t.Check(not picked.r7, "ikan bernilai tertinggi (Emas) tidak dipilih saat ada yang lebih murah")
	local maxChosen = 0
	if chosen then
		for _, f in chosen do
			maxChosen = math.max(maxChosen, Formulas.FishValue(f, Fish.ById))
		end
	end
	t.Check(maxChosen <= Formulas.FishValue(fish[7], Fish.ById), "yang dipilih bernilai terendah")

	-- Protected dikecualikan (Napoleon = Epic Protected)
	local epicRecipe = Barter.ById.barter_joran_emas
	local onlyNapoleon = { item("e1", "napoleon", 40) }
	local none, reason = Formulas.SelectBarterFish(onlyNapoleon, epicRecipe, Fish.ById)
	t.Check(none == nil and reason == "NotEnough", "ikan Protected tidak bisa dibarter")
	local withTuna = { item("e1", "napoleon", 40), item("e2", "tuna_sirip_kuning", 50) }
	local tuna = Formulas.SelectBarterFish(withTuna, epicRecipe, Fish.ById)
	t.Check(tuna ~= nil and (tuna :: any)[1].Uid == "e2", "ikan Epic non-Protected dipilih")

	-- Jumlah kurang
	local few = { item("u1", "rajungan", 0.3) }
	local nope = Formulas.SelectBarterFish(few, Barter.ById.barter_topi_tua, Fish.ById)
	t.Equal(nope, nil, "jumlah ikan kurang -> nil")
end
