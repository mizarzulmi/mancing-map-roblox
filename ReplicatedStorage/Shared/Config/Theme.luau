--!strict
-- Token tema UI (GDD Bagian 6). Komponen UI WAJIB mengambil warna/ukuran dari sini, bukan hex mentah.
-- Kontras diverifikasi (WCAG): teks #F7F3E8 12,7:1 di panel / 10,1:1 di kartu; teks sekunder 8,5 / 6,8;
-- teks gelap di tombol emas 10,4, teal 6,8, bahaya 6,8, sukses 10,5. Bahaya/teal sebagai TEKS di kartu
-- memakai varian DangerText (5,4:1) dan TealText (6,1:1).

local rgb = Color3.fromRGB

local Theme = {}

Theme.Color = {
	Panel = rgb(15, 47, 58), -- #0F2F3A
	Card = rgb(22, 64, 77), -- #16404D
	CardHover = rgb(29, 82, 99), -- #1D5263
	CardPressed = rgb(18, 56, 68),
	Inset = rgb(11, 36, 45), -- sumur gelap untuk bar/track
	Text = rgb(247, 243, 232), -- #F7F3E8
	TextSecondary = rgb(183, 205, 211), -- #B7CDD3
	TextOnAccent = rgb(26, 26, 26), -- #1A1A1A
	Stroke = rgb(255, 255, 255),
	Primary = rgb(242, 193, 78), -- #F2C14E emas pasir (satu aksen utama)
	PrimaryHover = rgb(246, 207, 110),
	PrimaryPressed = rgb(217, 170, 62),
	Secondary = rgb(43, 179, 177), -- #2BB3B1
	SecondaryHover = rgb(69, 195, 193),
	SecondaryPressed = rgb(34, 156, 154),
	Danger = rgb(255, 122, 89), -- #FF7A59
	DangerHover = rgb(255, 146, 119),
	DangerPressed = rgb(232, 102, 74),
	DangerText = rgb(255, 154, 128), -- teks bahaya di atas kartu/panel
	TealText = rgb(79, 209, 206), -- teks teal di atas kartu/panel
	Success = rgb(110, 224, 138), -- #6EE08A
	Scrim = rgb(0, 0, 0),
	Shadow = rgb(4, 16, 20),
	Coin = rgb(242, 193, 78),
	CoinDeep = rgb(196, 140, 40),
	Leaf = rgb(110, 224, 138),
	NightTint = rgb(150, 170, 255),
}

Theme.Rarity = {
	Common = rgb(201, 209, 217), -- #C9D1D9
	Uncommon = rgb(110, 224, 138), -- #6EE08A
	Rare = rgb(90, 174, 255), -- #5AAEFF
	Epic = rgb(196, 149, 255), -- #C495FF
	Legendary = rgb(255, 192, 77), -- #FFC04D
	Mythic = rgb(255, 133, 184), -- #FF85B8
} :: { [string]: Color3 }

-- Gradien Mythic: semua warna terang (boleh beranimasi).
Theme.MythicGradient = ColorSequence.new({
	ColorSequenceKeypoint.new(0, rgb(255, 133, 184)),
	ColorSequenceKeypoint.new(0.35, rgb(255, 214, 140)),
	ColorSequenceKeypoint.new(0.7, rgb(150, 230, 255)),
	ColorSequenceKeypoint.new(1, rgb(255, 133, 184)),
})

Theme.Mutation = {
	None = rgb(247, 243, 232),
	Berkilau = rgb(255, 240, 160),
	Albino = rgb(255, 255, 255),
	Emas = rgb(255, 204, 92),
	Pelangi = rgb(255, 160, 210),
} :: { [string]: Color3 }

Theme.Weather = {
	Cerah = rgb(255, 209, 102),
	Berawan = rgb(201, 209, 217),
	Hujan = rgb(90, 174, 255),
	Badai = rgb(196, 149, 255),
} :: { [string]: Color3 }

Theme.Transparency = {
	Panel = 0.04, -- ≤ 0,08 sesuai brief
	Card = 0,
	Stroke = 0.85,
	Scrim = 0.5,
	Disabled = 0.5,
	Shadow = 0.55,
}

Theme.Font = {
	Display = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular),
	Body = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Medium),
	Bold = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold),
}

-- Ukuran teks dasar (sebelum UIScale 0,75–1,25). Minimal 19 agar ≥ 14 px setelah skala terkecil.
Theme.TextSize = {
	Small = 19,
	Body = 20,
	Label = 22,
	Heading = 26,
	Title = 30,
	Number = 32,
	Hero = 40,
}

Theme.Radius = {
	Panel = 12,
	Card = 10,
	Button = 10,
	Chip = 8,
	Round = 999,
}

Theme.Space = {
	XS = 4,
	S = 8,
	M = 12,
	L = 16,
	XL = 24,
}

Theme.Size = {
	Touch = 48, -- target sentuh minimum
	ButtonHeight = 52,
	IconButton = 56,
	HudIcon = 28,
	PanelMaxWidth = 980,
	PanelMaxHeight = 640,
}

Theme.Shadow = {
	Blur = 16,
	OffsetY = 4,
}

Theme.Motion = {
	Duration = 0.18,
	Exit = 0.12,
	Catch = 0.9,
}

Theme.DisplayOrder = {
	HUD = 10,
	Minigame = 15,
	Panel = 20,
	Popup = 30,
	Overlay = 40,
}

-- Warna dunia untuk nametag & billboard (teks terang + stroke gelap agar terbaca di pasir maupun langit).
Theme.World = {
	NameText = rgb(255, 252, 242),
	NameStroke = rgb(10, 28, 34),
	TitleText = rgb(242, 193, 78),
	QuestMark = rgb(242, 193, 78),
}

return Theme
