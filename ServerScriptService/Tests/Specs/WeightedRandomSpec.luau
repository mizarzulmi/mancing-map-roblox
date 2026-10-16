--!strict
-- Distribusi WeightedRandom: 100.000 sampel, toleransi ±1,5 poin persen per kunci.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WeightedRandom = require(ReplicatedStorage.Shared.Util.WeightedRandom)
local TestRunner = require(script.Parent.Parent.TestRunner)

return function(t: TestRunner.T)
	local weights = { Common = 600, Uncommon = 250, Rare = 100, Epic = 38, Legendary = 10, Mythic = 2 }
	local order = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }
	local rng = Random.new(12345)
	local counts: { [string]: number } = {}
	local samples = 100000
	for _ = 1, samples do
		local k = WeightedRandom.PickKey(weights, order, rng)
		if k then
			counts[k] = (counts[k] or 0) + 1
		end
	end
	local norm = WeightedRandom.Normalize(weights)
	for _, k in order do
		t.Near((counts[k] or 0) / samples, norm[k], 0.015, "distribusi " .. k)
	end

	-- Bobot nol tidak pernah terpilih; semua nol -> nil.
	local zeroRng = Random.new(1)
	local onlyB = 0
	for _ = 1, 1000 do
		if WeightedRandom.PickKey({ A = 0, B = 5 }, { "A", "B" }, zeroRng) == "B" then
			onlyB += 1
		end
	end
	t.Equal(onlyB, 1000, "bobot nol tidak terpilih")
	t.Equal(WeightedRandom.PickKey({ A = 0 }, { "A" }, zeroRng), nil, "semua bobot nol -> nil")

	-- Deterministik untuk seed yang sama.
	local a = Random.new(777)
	local b = Random.new(777)
	local same = true
	for _ = 1, 200 do
		if WeightedRandom.PickKey(weights, order, a) ~= WeightedRandom.PickKey(weights, order, b) then
			same = false
		end
	end
	t.Check(same, "deterministik untuk seed sama")
end
