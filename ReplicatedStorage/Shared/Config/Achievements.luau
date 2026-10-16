--!strict
-- Achievement → gelar (GDD 4.6).

local Types = require(script.Parent.Parent.Types)

type AchievementDef = Types.AchievementDef

local list: { AchievementDef } = {
	{ Id = "ach_first", Name = "Tangkapan Pertama", Description = "Tangkap ikan pertamamu.",
		Title = "title_pemula_pantai", Stat = "TotalCaught", Count = 1 },
	{ Id = "ach_100", Name = "Seratus Ikan", Description = "Tangkap 100 ikan.",
		Title = "title_nelayan_tangguh", Stat = "TotalCaught", Count = 100 },
	{ Id = "ach_1000", Name = "Seribu Ikan", Description = "Tangkap 1.000 ikan.",
		Title = "title_raja_pancing", Stat = "TotalCaught", Count = 1000 },
	{ Id = "ach_fishdex_shore", Name = "Ahli Pantai", Description = "Lengkapi Fishdex Pantai Dangkal.",
		Title = "title_ahli_pantai", Stat = "FishdexZone", Count = 1, Arg = "Shore" },
	{ Id = "ach_pelangi", Name = "Pelangi Samudra", Description = "Tangkap ikan bermutasi Pelangi.",
		Title = "title_pelangi_samudra", Stat = "CaughtMutation", Count = 1, Arg = "Pelangi" },
	{ Id = "ach_juragan", Name = "Juragan Ikan", Description = "Kumpulkan total pendapatan 100.000 koin.",
		Title = "title_juragan_ikan", Stat = "TotalEarned", Count = 100000 },
	{ Id = "ach_sahabat", Name = "Sahabat Laut", Description = "Kumpulkan total 250 Poin Konservasi.",
		Title = "title_sahabat_laut", Stat = "TotalConservation", Count = 250 },
	{ Id = "ach_naga", Name = "Penakluk Naga", Description = "Tangkap Naga Laut Samudra.",
		Title = "title_penakluk_naga", Stat = "CaughtSpecies", Count = 1, Arg = "naga_laut" },
}

local byId: { [string]: AchievementDef } = {}
for _, a in list do
	byId[a.Id] = a
end

local Achievements = {}
Achievements.List = list
Achievements.ById = byId

return Achievements
