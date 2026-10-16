--!strict
-- Joran (GDD Bagian 5). WaitMul makin kecil makin cepat; Control = lebar zona tangkap (0..1).

local Types = require(script.Parent.Parent.Types)

type RodDef = Types.RodDef

local rgb = Color3.fromRGB

local list: { RodDef } = {
	{
		Id = "bambu",
		Name = "Joran Bambu",
		Price = nil,
		Level = 1,
		Luck = 0,
		WaitMul = 1.00,
		Control = 0.26,
		ReelSpeed = 1.00,
		MaxWeight = 12,
		CastDistance = 35,
		Source = "Starter",
		Order = 1,
		Description = "Joran warisan kampung. Ringan, jujur, cukup untuk ikan pantai.",
		Colors = { Shaft = rgb(201, 168, 106), Grip = rgb(122, 82, 48), Accent = rgb(84, 122, 62) },
		Material = Enum.Material.Wood,
	},
	{
		Id = "fiber",
		Name = "Joran Fiberglass",
		Price = 350,
		Level = 3,
		Luck = 0.10,
		WaitMul = 0.92,
		Control = 0.28,
		ReelSpeed = 1.08,
		MaxWeight = 30,
		CastDistance = 45,
		Source = "Shop",
		Order = 2,
		Description = "Lentur dan awet. Lemparan lebih jauh untuk ujung dermaga.",
		Colors = { Shaft = rgb(232, 238, 242), Grip = rgb(42, 42, 42), Accent = rgb(43, 179, 177) },
		Material = Enum.Material.SmoothPlastic,
	},
	{
		Id = "karbon",
		Name = "Joran Karbon",
		Price = 1500,
		Level = 8,
		Luck = 0.25,
		WaitMul = 0.85,
		Control = 0.30,
		ReelSpeed = 1.15,
		MaxWeight = 80,
		CastDistance = 55,
		Source = "Shop",
		Order = 3,
		Description = "Kaku dan sensitif. Siap melawan kerapu laguna.",
		Colors = { Shaft = rgb(43, 47, 54), Grip = rgb(160, 52, 44), Accent = rgb(242, 193, 78) },
		Material = Enum.Material.SmoothPlastic,
	},
	{
		Id = "samudra",
		Name = "Joran Samudra",
		Price = 6000,
		Level = 15,
		Luck = 0.45,
		WaitMul = 0.78,
		Control = 0.32,
		ReelSpeed = 1.25,
		MaxWeight = 200,
		CastDistance = 65,
		Source = "Shop",
		Order = 4,
		Description = "Dibuat untuk Laut Dalam: tuna dan layaran bukan masalah.",
		Colors = { Shaft = rgb(31, 127, 140), Grip = rgb(15, 47, 58), Accent = rgb(242, 237, 228) },
		Material = Enum.Material.SmoothPlastic,
	},
	{
		Id = "emas_bahari",
		Name = "Joran Emas Bahari",
		Price = nil,
		Level = 20,
		Luck = 0.60,
		WaitMul = 0.75,
		Control = 0.34,
		ReelSpeed = 1.30,
		MaxWeight = 300,
		CastDistance = 70,
		MutationMul = 1.5,
		Source = "Barter",
		Order = 5,
		Description = "Hadiah Kakek Bahari. Peluang mutasi ×1,5.",
		Colors = { Shaft = rgb(224, 176, 76), Grip = rgb(107, 66, 38), Accent = rgb(255, 242, 194) },
		Material = Enum.Material.Metal,
	},
	{
		Id = "legenda",
		Name = "Joran Legenda Nusantara",
		Price = 25000,
		Level = 25,
		Luck = 0.80,
		WaitMul = 0.70,
		Control = 0.35,
		ReelSpeed = 1.40,
		MaxWeight = 500,
		CastDistance = 75,
		Source = "Shop",
		Order = 6,
		Description = "Joran para legenda. Naga laut pun bisa ditarik.",
		Colors = { Shaft = rgb(58, 31, 43), Grip = rgb(26, 26, 26), Accent = rgb(242, 193, 78) },
		Material = Enum.Material.SmoothPlastic,
	},
}

local byId: { [string]: RodDef } = {}
for _, r in list do
	assert(byId[r.Id] == nil, "Id joran ganda: " .. r.Id)
	byId[r.Id] = r
end

local Rods = {}
Rods.List = list
Rods.ById = byId

function Rods.Get(id: string): RodDef?
	return byId[id]
end

return Rods
