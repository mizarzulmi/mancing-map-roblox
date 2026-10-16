--!strict
-- Umpan (GDD Bagian 5). Tanpa umpan memakai Balance.Fishing.NoBaitWaitMul dan Luck 0.

local Types = require(script.Parent.Parent.Types)

type BaitDef = Types.BaitDef

local rgb = Color3.fromRGB

local list: { BaitDef } = {
	{
		Id = "cacing",
		Name = "Cacing",
		Price = 2,
		Luck = 0,
		WaitMul = 0.90,
		Source = "Shop",
		Order = 1,
		Description = "Umpan sejuta umat. Ikan lebih cepat menyambar.",
		Color = rgb(196, 112, 96),
	},
	{
		Id = "udang",
		Name = "Udang Segar",
		Price = 6,
		Luck = 0.10,
		WaitMul = 0.85,
		Source = "Shop",
		Order = 2,
		Description = "Aroma udang menarik ikan yang lebih besar.",
		Color = rgb(242, 150, 110),
	},
	{
		Id = "cumi_potong",
		Name = "Potongan Cumi",
		Price = 15,
		Luck = 0.20,
		WaitMul = 0.85,
		Source = "Shop",
		Order = 3,
		Description = "Kenyal dan tahan lama di kail. Disukai predator.",
		Color = rgb(242, 220, 205),
	},
	{
		Id = "kilau",
		Name = "Umpan Kilau",
		Price = 40,
		Luck = 0.30,
		WaitMul = 0.80,
		NightLuck = 0.20,
		Source = "Shop",
		Order = 4,
		Description = "Memantulkan cahaya. Malam hari: Luck +0,2.",
		Color = rgb(150, 230, 255),
	},
	{
		Id = "emas",
		Name = "Umpan Emas",
		Price = nil,
		Luck = 0.80,
		WaitMul = 0.75,
		MutationMul = 2,
		Source = "Barter",
		Order = 5,
		Description = "Hadiah barter Kakek Bahari. Peluang mutasi ×2.",
		Color = rgb(242, 193, 78),
	},
}

local byId: { [string]: BaitDef } = {}
for _, b in list do
	assert(byId[b.Id] == nil, "Id umpan ganda: " .. b.Id)
	byId[b.Id] = b
end

local Bait = {}
Bait.List = list
Bait.ById = byId
Bait.NoneName = "Tanpa umpan"

function Bait.Get(id: string): BaitDef?
	return byId[id]
end

return Bait
