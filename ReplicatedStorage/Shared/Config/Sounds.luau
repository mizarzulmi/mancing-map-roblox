--!strict
-- ID suara. Hanya ID terverifikasi yang boleh diisi (rbxasset:// bawaan yang dicek ada di folder content Studio,
-- atau rbxassetid hasil MCP search_asset). String kosong = diam tanpa error.

local Sounds = {
	-- Bawaan Roblox (terverifikasi ada di content/sounds, 2026-10-16)
	Splash = "rbxasset://sounds/impact_water.mp3",
	Swim = "rbxasset://sounds/action_swim.mp3",
	UiTick = "rbxasset://sounds/volume_slider.ogg",

	-- Menunggu verifikasi lewat MCP search_asset (lihat docs/PROGRESS.md)
	Music = "",
	Waves = "",
	Seagull = "",
	Rain = "",
	Thunder = "",
	Coin = "",
	Bite = "",
	Reel = "",
	Catch = "",
	LevelUp = "",
	Click = "",
}

-- Volume dasar per suara (dikali pengaturan Musik/SFX pemain).
local Volume = {
	Splash = 0.55,
	Swim = 0.4,
	UiTick = 0.35,
	Music = 0.35,
	Waves = 0.4,
	Seagull = 0.3,
	Rain = 0.5,
	Thunder = 0.7,
	Coin = 0.5,
	Bite = 0.6,
	Reel = 0.4,
	Catch = 0.6,
	LevelUp = 0.6,
	Click = 0.4,
}

return {
	Ids = Sounds,
	Volume = Volume,
	MusicKeys = { "Music", "Waves", "Rain" },
}
