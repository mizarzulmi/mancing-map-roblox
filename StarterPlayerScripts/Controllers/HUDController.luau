--!strict
-- HUDController: HUD utama (GDD Bagian 6).
-- Kiri atas: level + bar XP · kanan atas: Koin (angka paling menonjol, hitung naik), Poin Konservasi, tas "17/20"
-- · tengah atas: jam + ikon cuaca + banner event · kiri: tombol menu (kolom; baris saat layar pendek)
-- · bawah tengah: slot joran + umpan aktif (ganti cepat) · kanan bawah: tombol Lempar/Tarik (perangkat sentuh)
-- · perayaan naik level. Pelacak quest dipasang QuestController ke Container("Right").

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Format = require(Shared.Util.Format)
local Formulas = require(Shared.Formulas)
local TweenUtil = require(Shared.Util.TweenUtil)
local Balance = require(Shared.Config.Balance)
local Rods = require(Shared.Config.Rods)
local Bait = require(Shared.Config.Bait)
local Zones = require(Shared.Config.Zones)
local Strings = require(Shared.Config.Strings)
local Theme = require(Shared.Config.Theme)
local DataController = require(script.Parent.DataController)
local UIController = require(script.Parent.UIController)
local InputController = require(script.Parent.InputController)
local DayNightController = require(script.Parent.DayNightController)
local SoundController = require(script.Parent.SoundController)
local NotificationController = require(script.Parent.NotificationController)
local UI = script.Parent.Parent:WaitForChild("UI")
local Style = require(UI:WaitForChild("Style"))
local Icon = require(UI:WaitForChild("Icon"))
local IconButton = require(UI:WaitForChild("IconButton"))
local ProgressBar = require(UI:WaitForChild("ProgressBar"))

local HUDController = {}

type ContainerName = "TopLeft" | "TopRight" | "TopCenter" | "Right" | "Left" | "BottomCenter" | "AboveSlots" | "BottomRight"

local containers: { [string]: Frame } = {}
local menuButtons: { IconButton.IconButton } = {}
local menuList: UIListLayout? = nil

local levelBadge: TextLabel? = nil
local levelLabel: TextLabel? = nil
local xpLabel: TextLabel? = nil
local xpBar: ProgressBar.ProgressBar? = nil
local coinLabel: TextLabel? = nil
local pointsLabel: TextLabel? = nil
local bagLabel: TextLabel? = nil
local clockLabel: TextLabel? = nil
local weatherLabel: TextLabel? = nil
local weatherIconHolder: Frame? = nil
local eventBanner: Frame? = nil
local eventLabel: TextLabel? = nil
local rodName: TextLabel? = nil
local baitName: TextLabel? = nil
local castButton: TextButton? = nil
local castLabel: TextLabel? = nil
local baitPicker: Frame? = nil

local shownCoins: number? = nil

local MENU = {
	{ Id = "Bag", Icon = "bag", Label = Strings.MenuBag, Key = "B" },
	{ Id = "Fishdex", Icon = "book", Label = Strings.MenuFishdex, Key = "F" },
	{ Id = "Quest", Icon = "scroll", Label = Strings.MenuQuest, Key = "Q" },
	{ Id = "Cosmetic", Icon = "shirt", Label = Strings.MenuCosmetic, Key = "C" },
	{ Id = "Players", Icon = "users", Label = Strings.MenuPlayers, Key = "G" },
	{ Id = "Settings", Icon = "gear", Label = Strings.MenuSettings, Key = "P" },
}

function HUDController.Container(name: ContainerName): Frame
	return containers[name]
end

local function makeContainer(name: string, anchor: Vector2, position: UDim2, direction: ("Vertical" | "Horizontal")?, gap: number?): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.AnchorPoint = anchor
	f.Position = position
	f.BackgroundTransparency = 1
	f.Size = UDim2.fromOffset(0, 0)
	f.AutomaticSize = Enum.AutomaticSize.XY
	if direction then
		local list = Instance.new("UIListLayout")
		list.FillDirection = if direction == "Horizontal" then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Padding = UDim.new(0, gap or Theme.Space.S)
		list.HorizontalAlignment = if anchor.X >= 1 then Enum.HorizontalAlignment.Right elseif anchor.X > 0 then Enum.HorizontalAlignment.Center else Enum.HorizontalAlignment.Left
		list.VerticalAlignment = Enum.VerticalAlignment.Center
		list.Parent = f
	end
	f.Parent = UIController.Gui("HUD")
	containers[name] = f
	return f
end

local function panelRow(parent: Instance, name: string, order: number): Frame
	local p = Style.Panel({ Name = name, AutoSize = "XY", LayoutOrder = order, Parent = parent })
	Style.Padding(p, Theme.Space.S, Theme.Space.M, Theme.Space.S, Theme.Space.M)
	Style.List(p, "Horizontal", Theme.Space.M, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	return p
end

local function iconStat(parent: Instance, icon: Icon.IconName, size: number, color: Color3?, order: number): TextLabel
	local group = Style.Frame({ AutoSize = "XY", LayoutOrder = order, Parent = parent })
	Style.List(group, "Horizontal", Theme.Space.XS + 2, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	local ic = Icon.new(icon, size, color)
	ic.LayoutOrder = 1
	ic.Parent = group
	local label = Style.Label({
		Text = "0",
		Font = "Bold",
		TextSize = Theme.TextSize.Label,
		AutoSize = "XY",
		LayoutOrder = 2,
		Parent = group,
	})
	return label
end

-- ===================== Bangun HUD =====================

local function buildTopLeft()
	local tl = containers.TopLeft
	local panel = panelRow(tl, "LevelPanel", 1)
	local badge = Instance.new("Frame")
	badge.Name = "Badge"
	badge.Size = UDim2.fromOffset(52, 52)
	badge.BackgroundColor3 = Theme.Color.Card
	badge.LayoutOrder = 1
	Style.Corner(badge, Theme.Radius.Round)
	Style.Stroke(badge, 0.2, 2, Theme.Color.Secondary)
	local num = Style.Label({
		Text = "1",
		Font = "Display",
		TextSize = Theme.TextSize.Heading,
		Size = UDim2.fromScale(1, 1),
		XAlign = Enum.TextXAlignment.Center,
		Parent = badge,
	})
	badge.Parent = panel
	levelBadge = num

	local col = Style.Frame({ AutoSize = "XY", LayoutOrder = 2, Parent = panel })
	Style.List(col, "Vertical", Theme.Space.XS)
	levelLabel = Style.Label({ Text = "Level 1", Font = "Bold", TextSize = Theme.TextSize.Body, AutoSize = "XY", LayoutOrder = 1, Parent = col })
	xpBar = ProgressBar.new({ Fill = 0, Color = Theme.Color.Secondary, Height = 10, Size = UDim2.fromOffset(190, 10), LayoutOrder = 2, Parent = col })
	xpLabel = Style.Label({
		Text = "0/40 XP",
		TextSize = Theme.TextSize.Small,
		Color = Theme.Color.TextSecondary,
		AutoSize = "XY",
		LayoutOrder = 3,
		Parent = col,
	})
end

local function buildTopRight()
	local tr = containers.TopRight
	local panel = panelRow(tr, "WalletPanel", 1)
	local coinGroup = Style.Frame({ AutoSize = "XY", LayoutOrder = 1, Parent = panel })
	Style.List(coinGroup, "Horizontal", Theme.Space.S, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	local coinIcon = Icon.new("coin", 32, Theme.Color.Coin)
	coinIcon.LayoutOrder = 1
	coinIcon.Parent = coinGroup
	coinLabel = Style.Label({
		Text = "0",
		Font = "Display",
		TextSize = Theme.TextSize.Number,
		AutoSize = "XY",
		LayoutOrder = 2,
		Parent = coinGroup,
	})
	pointsLabel = iconStat(panel, "leaf", 24, Theme.Color.Leaf, 2)
	bagLabel = iconStat(panel, "bag", 24, nil, 3)
end

local function buildTopCenter()
	local tc = containers.TopCenter
	local chip = panelRow(tc, "ClockChip", 1)
	local holder = Style.Frame({ Size = UDim2.fromOffset(26, 26), LayoutOrder = 1, Parent = chip })
	weatherIconHolder = holder
	clockLabel = Style.Label({ Text = "14:00", Font = "Display", TextSize = Theme.TextSize.Heading, AutoSize = "XY", LayoutOrder = 2, Parent = chip })
	weatherLabel = Style.Label({
		Text = "Cerah",
		TextSize = Theme.TextSize.Small,
		Color = Theme.Color.TextSecondary,
		AutoSize = "XY",
		LayoutOrder = 3,
		Parent = chip,
	})

	local banner = Style.Panel({ Name = "EventBanner", AutoSize = "XY", LayoutOrder = 2, Parent = tc })
	Style.Padding(banner, Theme.Space.XS + 2, Theme.Space.M, Theme.Space.XS + 2, Theme.Space.M)
	Style.Stroke(banner, 0.1, 1.5, Theme.Color.Primary)
	Style.List(banner, "Horizontal", Theme.Space.S, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	local star = Icon.new("star", 20, Theme.Color.Primary)
	star.LayoutOrder = 1
	star.Parent = banner
	eventLabel = Style.Label({ Text = "", Font = "Bold", TextSize = Theme.TextSize.Small, AutoSize = "XY", LayoutOrder = 2, Parent = banner })
	banner.Visible = false
	eventBanner = banner
end

local function buildMenu()
	local left = containers.Left
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, Theme.Space.S)
	list.Parent = left
	menuList = list
	for i, item in MENU do
		local btn = IconButton.new({
			Icon = item.Icon :: Icon.IconName,
			Label = item.Label,
			Hotkey = item.Key,
			Name = "Menu_" .. item.Id,
			LayoutOrder = i,
			Parent = left,
			OnActivated = function()
				InputController.Hotkey:Fire(item.Id)
			end,
		})
		table.insert(menuButtons, btn)
	end
end

local function closeBaitPicker()
	local p = baitPicker
	if p then
		baitPicker = nil
		p:Destroy()
	end
end

local function openBaitPicker()
	if baitPicker then
		closeBaitPicker()
		return
	end
	local data = DataController.Get()
	if data == nil then
		return
	end
	local picker = Style.Panel({ Name = "BaitPicker", AutoSize = "XY", Parent = containers.AboveSlots })
	Style.Padding(picker, Theme.Space.S)
	Style.List(picker, "Vertical", Theme.Space.XS)
	local function option(id: string, label: string, order: number)
		local b = Instance.new("TextButton")
		b.Name = "Opsi_" .. (if id == "" then "none" else id)
		b.AutoButtonColor = false
		b.Text = ""
		b.Size = UDim2.fromOffset(240, Theme.Size.Touch)
		b.BackgroundColor3 = if data and data.EquippedBait == id then Theme.Color.CardHover else Theme.Color.Card
		b.LayoutOrder = order
		Style.Corner(b, Theme.Radius.Chip)
		Style.Padding(b, 0, Theme.Space.M, 0, Theme.Space.M)
		Style.Label({ Text = label, Font = "Bold", TextSize = Theme.TextSize.Body, Size = UDim2.fromScale(1, 1), Parent = b })
		b.Activated:Connect(function()
			closeBaitPicker()
			local ok, msg = Net.Invoke("Equip", "Bait", id)
			if not ok and type(msg) == "string" then
				NotificationController.Show(msg, "Warning")
			end
		end)
		b.Parent = picker
	end
	option("", Strings.NoBait, 0)
	for _, def in Bait.List do
		local qty = data.Bait[def.Id] or 0
		if qty > 0 then
			option(def.Id, string.format("%s  ×%s", def.Name, Format.Int(qty)), def.Order)
		end
	end
	baitPicker = picker
	UIController.FocusFirst(picker)
end

local function slotButton(name: string, icon: Icon.IconName, order: number, onActivated: () -> ()): TextLabel
	local b = Instance.new("TextButton")
	b.Name = name
	b.AutoButtonColor = false
	b.Text = ""
	b.BackgroundColor3 = Theme.Color.Panel
	b.BackgroundTransparency = Theme.Transparency.Panel
	b.Size = UDim2.fromOffset(230, 60)
	b.LayoutOrder = order
	Style.Corner(b, Theme.Radius.Card)
	Style.Stroke(b)
	Style.Padding(b, 0, Theme.Space.M, 0, Theme.Space.M)
	local row = Style.Frame({ Size = UDim2.fromScale(1, 1), Parent = b })
	Style.List(row, "Horizontal", Theme.Space.S, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	local ic = Icon.new(icon, 28, nil)
	ic.LayoutOrder = 1
	ic.Parent = row
	local label = Style.Label({
		Text = "",
		Font = "Bold",
		TextSize = Theme.TextSize.Body,
		Size = UDim2.new(1, -40, 1, 0),
		LayoutOrder = 2,
		Parent = row,
	})
	label.TextTruncate = Enum.TextTruncate.AtEnd
	b.MouseEnter:Connect(function()
		TweenUtil.Play(b, { BackgroundColor3 = Theme.Color.Card })
	end)
	b.MouseLeave:Connect(function()
		TweenUtil.Play(b, { BackgroundColor3 = Theme.Color.Panel })
	end)
	b.Activated:Connect(onActivated)
	b.Parent = containers.BottomCenter
	return label
end

local function buildSlots()
	rodName = slotButton("RodSlot", "rod", 1, function()
		closeBaitPicker()
		InputController.ToggleRod()
	end)
	baitName = slotButton("BaitSlot", "bait", 2, openBaitPicker)
end

local function buildCastButton()
	local b = Instance.new("TextButton")
	b.Name = "CastButton"
	b.AnchorPoint = Vector2.new(1, 1)
	b.Position = UDim2.new(1, -190, 1, -36)
	b.Size = UDim2.fromOffset(112, 112)
	b.AutoButtonColor = false
	b.Text = ""
	b.BackgroundColor3 = Theme.Color.Primary
	b.Visible = false
	Style.Corner(b, Theme.Radius.Round)
	Style.Shadow(b)
	local label = Style.Label({
		Text = Strings.Cast,
		Font = "Display",
		TextSize = Theme.TextSize.Heading,
		Color = Theme.Color.TextOnAccent,
		Size = UDim2.fromScale(1, 1),
		XAlign = Enum.TextXAlignment.Center,
		Parent = b,
	})
	b.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			InputController.TouchHold(true)
		end
	end)
	b.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			InputController.TouchHold(false)
		end
	end)
	b.Parent = containers.BottomRight
	castButton = b
	castLabel = label
end

-- Tombol Lempar/Tarik hanya untuk perangkat sentuh & saat joran dipegang.
function HUDController.SetCastLabel(text: string)
	local l = castLabel
	if l then
		l.Text = text
	end
end

local function refreshCastVisibility()
	local b = castButton
	if b then
		b.Visible = UserInputService.TouchEnabled and InputController.IsRodEquipped() and not UIController.IsPanelOpen()
	end
end

-- ===================== Pembaruan data =====================

local function refreshLevel()
	local data = DataController.Get()
	if data == nil then
		return
	end
	local need = Formulas.XPToNext(data.Level)
	if levelBadge then
		levelBadge.Text = tostring(data.Level)
	end
	if levelLabel then
		levelLabel.Text = "Level " .. tostring(data.Level)
	end
	if data.Level >= Balance.MaxLevel then
		if xpBar then
			xpBar:SetFill(1, true)
		end
		if xpLabel then
			xpLabel.Text = "Level maksimum"
		end
	else
		if xpBar then
			xpBar:SetFill(math.clamp(data.XP / need, 0, 1), true)
		end
		if xpLabel then
			xpLabel.Text = string.format("%s/%s XP", Format.Int(data.XP), Format.Int(need))
		end
	end
end

local function refreshWallet()
	local data = DataController.Get()
	if data == nil then
		return
	end
	local label = coinLabel
	if label then
		local from = shownCoins or data.Coins
		shownCoins = data.Coins
		TweenUtil.CountUp(label, from, data.Coins, if data.Coins > from then 0.6 else 0.25, Format.Coins)
		if data.Coins > from then
			SoundController.Play("Coin", 0.05)
		end
	end
	if pointsLabel then
		pointsLabel.Text = Format.Int(data.ConservationPoints)
	end
	if bagLabel then
		bagLabel.Text = string.format(Strings.BagCount, #data.Fish, data.BagCapacity)
		bagLabel.TextColor3 = if #data.Fish >= data.BagCapacity then Theme.Color.DangerText else Theme.Color.Text
	end
end

local function refreshSlots()
	local data = DataController.Get()
	if data == nil then
		return
	end
	local rod = Rods.Get(data.EquippedRod)
	if rodName then
		rodName.Text = (if rod then rod.Name else "Joran") .. (if InputController.IsRodEquipped() then "" else "  [1]")
	end
	if baitName then
		local bait = if data.EquippedBait ~= "" then Bait.Get(data.EquippedBait) else nil
		if bait then
			baitName.Text = string.format("%s ×%s", bait.Name, Format.Int(data.Bait[bait.Id] or 0))
		else
			baitName.Text = Strings.NoBait
		end
	end
end

local function refreshClock()
	local clock = DayNightController.Clock()
	if clockLabel then
		clockLabel.Text = Format.Clock(clock)
	end
	local weather = ReplicatedStorage:GetAttribute("Weather")
	local w = if type(weather) == "string" then weather else "Cerah"
	if weatherLabel then
		weatherLabel.Text = Balance.WeatherLabel[w] or w
	end
	local holder = weatherIconHolder
	if holder then
		local want = if w == "Hujan" then "rain" elseif w == "Badai" then "storm" elseif w == "Berawan" then "cloud" elseif DayNightController.IsNight() then "moon" else "sun"
		if holder:GetAttribute("Icon") ~= want then
			holder:ClearAllChildren()
			local ic = Icon.new(want :: Icon.IconName, 26, Theme.Weather[w])
			ic.Parent = holder
			holder:SetAttribute("Icon", want)
		end
	end
	local event = ReplicatedStorage:GetAttribute("Event")
	local ends = ReplicatedStorage:GetAttribute("EventEndsAt")
	local banner = eventBanner
	if banner then
		local active = type(event) == "string" and event ~= "None" and event ~= ""
		banner.Visible = active
		if active and eventLabel then
			local left = if type(ends) == "number" then ends - workspace:GetServerTimeNow() else 0
			eventLabel.Text = string.format(
				"%s · %s · %s",
				Balance.EventLabel[event :: string] or (event :: string),
				Balance.EventDescription[event :: string] or "",
				Format.Duration(math.max(0, left))
			)
		end
	end
end

-- Tata letak responsif: menu kiri kolom di layar tinggi, baris di bawah panel level di layar pendek.
local function layout()
	local inset = UIController.TopInset()
	local top = inset + Theme.Space.M
	local root = UIController.Gui("HUD")
	local height = root.AbsoluteSize.Y / math.max(UIController.Scale(), 0.01)
	local compact = height < 620
	containers.TopLeft.Position = UDim2.fromOffset(Theme.Space.L, top)
	containers.TopRight.Position = UDim2.new(1, -Theme.Space.L, 0, top)
	containers.TopCenter.Position = UDim2.new(0.5, 0, 0, top)
	containers.Right.Position = UDim2.new(1, -Theme.Space.L, 0, top + 84)
	local list = menuList
	if list then
		list.FillDirection = if compact then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
	end
	if compact then
		containers.Left.AnchorPoint = Vector2.new(0, 0)
		containers.Left.Position = UDim2.fromOffset(Theme.Space.L, top + 92)
	else
		containers.Left.AnchorPoint = Vector2.new(0, 0.5)
		containers.Left.Position = UDim2.new(0, Theme.Space.L, 0.5, 20)
	end
end

local function celebrateLevel(level: number, coins: number)
	local popup = UIController.Gui("Popup")
	local card = Style.Panel({
		Name = "LevelUp",
		AutoSize = "XY",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.32),
		Parent = popup,
	})
	Style.Padding(card, Theme.Space.L, Theme.Space.XL, Theme.Space.L, Theme.Space.XL)
	Style.List(card, "Vertical", Theme.Space.S, Enum.HorizontalAlignment.Center)
	Style.Stroke(card, 0.1, 2, Theme.Color.Primary)
	Style.Label({ Text = Strings.LevelUpTitle, Font = "Display", TextSize = Theme.TextSize.Hero, Color = Theme.Color.Primary, AutoSize = "XY", LayoutOrder = 1, Parent = card })
	Style.Label({
		Text = string.format(Strings.LevelUpBody, level, Format.Coins(coins)),
		Font = "Bold",
		TextSize = Theme.TextSize.Label,
		AutoSize = "XY",
		LayoutOrder = 2,
		Parent = card,
	})
	local unlocked: { string } = {}
	for _, rod in Rods.List do
		if rod.Level == level then
			table.insert(unlocked, rod.Name)
		end
	end
	for _, zone in Zones.List do
		if zone.Level == level then
			table.insert(unlocked, zone.Name)
		end
	end
	if level == Balance.Ferry.Level then
		table.insert(unlocked, "Kapal ke Laut Dalam")
	end
	if #unlocked > 0 then
		Style.Label({
			Text = string.format(Strings.Unlocked, table.concat(unlocked, ", ")),
			TextSize = Theme.TextSize.Body,
			Color = Theme.Color.TextSecondary,
			AutoSize = "XY",
			LayoutOrder = 3,
			Parent = card,
		})
	end
	local scale = Instance.new("UIScale")
	scale.Scale = if TweenUtil.ReducedMotion() then 1 else 0.85
	scale.Parent = card
	TweenUtil.Play(scale, { Scale = 1 }, 0.25, Enum.EasingStyle.Back)
	SoundController.Play("LevelUp")
	task.delay(2.8, function()
		TweenUtil.Play(scale, { Scale = 0.92 }, Theme.Motion.Exit)
		task.delay(Theme.Motion.Exit, function()
			card:Destroy()
		end)
	end)
end

function HUDController.Init()
	makeContainer("TopLeft", Vector2.new(0, 0), UDim2.fromOffset(16, 16), "Vertical")
	makeContainer("TopRight", Vector2.new(1, 0), UDim2.new(1, -16, 0, 16), "Vertical")
	makeContainer("TopCenter", Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 16), "Vertical", Theme.Space.XS)
	makeContainer("Right", Vector2.new(1, 0), UDim2.new(1, -16, 0, 100), "Vertical")
	makeContainer("Left", Vector2.new(0, 0.5), UDim2.new(0, 16, 0.5, 0), nil)
	makeContainer("BottomCenter", Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -Theme.Space.L), "Horizontal", Theme.Space.S)
	makeContainer("AboveSlots", Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -92), "Vertical", Theme.Space.S)
	makeContainer("BottomRight", Vector2.new(1, 1), UDim2.new(1, 0, 1, 0), nil)
	containers.BottomRight.Size = UDim2.fromScale(1, 1)
	containers.BottomRight.AutomaticSize = Enum.AutomaticSize.None
	buildTopLeft()
	buildTopRight()
	buildTopCenter()
	buildMenu()
	buildSlots()
	buildCastButton()
	layout()
end

function HUDController.Start()
	DataController.Observe({ "Level", "XP" }, function()
		refreshLevel()
	end)
	DataController.Observe({ "Coins", "ConservationPoints", "Fish", "BagCapacity" }, function()
		refreshWallet()
	end)
	DataController.Observe({ "EquippedRod", "EquippedBait", "Bait" }, function()
		refreshSlots()
	end)
	UIController.ScaleChanged:Connect(layout)
	UIController.InsetChanged:Connect(layout)
	UIController.Gui("HUD"):GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
	UIController.PanelChanged:Connect(function()
		closeBaitPicker()
		refreshCastVisibility()
	end)
	Net.OnClientEvent("LevelUp", function(level: unknown, coins: unknown)
		if type(level) == "number" and type(coins) == "number" then
			celebrateLevel(level, coins)
		end
	end)
	-- Joran dipegang/disimpan memengaruhi slot & tombol sentuh.
	local player = game:GetService("Players").LocalPlayer
	local function watchCharacter(character: Model)
		character.ChildAdded:Connect(function()
			refreshSlots()
			refreshCastVisibility()
		end)
		character.ChildRemoved:Connect(function()
			refreshSlots()
			refreshCastVisibility()
		end)
		refreshSlots()
		refreshCastVisibility()
	end
	player.CharacterAdded:Connect(watchCharacter)
	if player.Character then
		watchCharacter(player.Character)
	end
	task.spawn(function()
		while true do
			refreshClock()
			task.wait(1)
		end
	end)
end

return HUDController
