--!strict
-- Zona memancing (GDD Bagian 5). Geometri zona ada di ServerScriptService/World/MapConfig.luau.

local Types = require(script.Parent.Parent.Types)

type ZoneDef = Types.ZoneDef

local list: { ZoneDef } = {
	{
		Id = "Shore",
		Name = "Pantai Dangkal",
		Level = 1,
		Order = 1,
		FishdexReward = 500,
		FishdexTitle = "title_ahli_pantai",
		Description = "Perairan jernih di depan pantai pasir.",
	},
	{
		Id = "Pier",
		Name = "Ujung Dermaga",
		Level = 1,
		Order = 2,
		FishdexReward = 1000,
		FishdexTitle = "title_ahli_dermaga",
		Description = "Air lebih dalam di sekitar ujung dermaga utama.",
	},
	{
		Id = "Mangrove",
		Name = "Laguna Bakau",
		Level = 5,
		Order = 3,
		FishdexReward = 3000,
		FishdexTitle = "title_penjaga_bakau",
		Description = "Laguna payau tenang yang dikelilingi bakau.",
	},
	{
		Id = "DeepSea",
		Name = "Laut Dalam",
		Level = 10,
		Order = 4,
		FishdexReward = 10000,
		FishdexTitle = "title_penjelajah_samudra",
		Description = "Perairan biru tua di sekitar Platform Laut Dalam.",
	},
}

local byId: { [string]: ZoneDef } = {}
for _, z in list do
	byId[z.Id] = z
end

local Zones = {}
Zones.List = list
Zones.ById = byId

function Zones.Get(id: string): ZoneDef?
	return byId[id]
end

return Zones
