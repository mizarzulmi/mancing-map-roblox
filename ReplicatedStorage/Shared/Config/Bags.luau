--!strict
-- Tingkat kapasitas Tas Ikan (GDD 4.3). Tingkat pertama adalah kapasitas awal.

local Types = require(script.Parent.Parent.Types)

type BagTier = Types.BagTier

local tiers: { BagTier } = {
	{ Capacity = 20, Price = 0 },
	{ Capacity = 35, Price = 400 },
	{ Capacity = 60, Price = 2000 },
	{ Capacity = 100, Price = 9000 },
	{ Capacity = 150, Price = 30000 },
}

local Bags = {}
Bags.Tiers = tiers

-- Tingkat berikutnya setelah kapasitas saat ini; nil bila sudah maksimal.
function Bags.NextTier(capacity: number): BagTier?
	for _, t in tiers do
		if t.Capacity > capacity then
			return t
		end
	end
	return nil
end

function Bags.IsValidCapacity(capacity: number): boolean
	for _, t in tiers do
		if t.Capacity == capacity then
			return true
		end
	end
	return false
end

return Bags
