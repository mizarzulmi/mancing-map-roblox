--!strict
-- CatchPopupController: popup tangkapan bergaya "kartu timbang" lapak ikan (momen signature, docs/UI-DIRECTION.md).
-- Kartu tergantung tali turun dari atas dan berayun pelan; ikan 3D berputar di ViewportFrame; berat menghitung
-- naik seperti jarum timbangan; lalu harga & XP. Label "BARU!" bila pertama di Fishdex. Ikan Protected
-- menampilkan tombol "Lepaskan" (Poin Konservasi). ReducedMotion → tampil instan.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Net = require(Shared.Net)
local Format = require(Shared.Util.Format)
local TweenUtil = require(Shared.Util.TweenUtil)
local Balance = require(Shared.Config.Balance)
local Fish = require(Shared.Config.Fish)
local Strings = require(Shared.Config.Strings)
local Theme = require(Shared.Config.Theme)
local FishModel = require(Shared.Models.FishModel)
local UIController = require(script.Parent.UIController)
local SoundController = require(script.Parent.SoundController)
local NotificationController = require(script.Parent.NotificationController)
local UI = script.Parent.Parent:WaitForChild("UI")
local Style = require(UI:WaitForChild("Style"))
local Icon = require(UI:WaitForChild("Icon"))
local Button = require(UI:WaitForChild("Button"))
local ViewportPreview = require(UI:WaitForChild("ViewportPreview"))

type CatchInfo = Types.CatchInfo

local CatchPopupController = {}

local current: Frame? = nil
local currentPreview: ViewportPreview.ViewportPreview? = nil
local dismissToken = 0

local CARD_WIDTH = 420

local function chip(parent: Instance, text: string, bg: Color3, fg: Color3, order: number)
	local c = Style.Frame({ AutoSize = "XY", Color = bg, Radius = Theme.Radius.Chip, LayoutOrder = order, Parent = parent })
	Style.Padding(c, 2, Theme.Space.S, 2, Theme.Space.S)
	Style.Label({ Text = text, Font = "Bold", TextSize = Theme.TextSize.Small, Color = fg, AutoSize = "XY", Parent = c })
	return c
end

function CatchPopupController.Dismiss()
	local card = current
	current = nil
	local preview = currentPreview
	currentPreview = nil
	if card == nil then
		return
	end
	local hanger = card.Parent
	TweenUtil.Play(card, { Position = UDim2.new(0.5, 0, 0, -40) }, Theme.Motion.Exit, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(Theme.Motion.Exit + 0.02, function()
		if preview then
			preview:Destroy()
		end
		if hanger and hanger:IsA("Frame") and hanger.Name == "CatchHanger" then
			hanger:Destroy()
		else
			card:Destroy()
		end
	end)
end

function CatchPopupController.Show(info: CatchInfo)
	CatchPopupController.Dismiss()
	local fish = info.Fish
	local species = Fish.Get(fish.SpeciesId)
	if species == nil then
		return
	end
	local root = UIController.Gui("Popup")
	local rarityColor = Theme.Rarity[species.Rarity] or Theme.Color.Text

	-- Gantungan: tali tipis dari atas layar ke lubang kartu.
	local hanger = Instance.new("Frame")
	hanger.Name = "CatchHanger"
	hanger.BackgroundTransparency = 1
	hanger.Size = UDim2.fromScale(1, 1)
	hanger.Parent = root
	local rope = Style.Frame({
		Name = "Tali",
		Size = UDim2.new(0, 2, 0, 0),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Color = Theme.Color.TextSecondary,
		Parent = hanger,
	})

	local card = Style.Panel({
		Name = "KartuTimbang",
		Size = UDim2.fromOffset(CARD_WIDTH, 0),
		AutoSize = "Y",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -460),
		Parent = hanger,
	})
	Style.Padding(card, Theme.Space.L)
	Style.List(card, "Vertical", Theme.Space.S, Enum.HorizontalAlignment.Center)
	if species.Rarity == "Legendary" or species.Rarity == "Mythic" then
		Style.Stroke(card, 0.05, 2, rarityColor)
	end

	-- Lubang label (seperti label harga bertali).
	local hole = Style.Frame({ Size = UDim2.fromOffset(14, 14), Color = Theme.Color.Inset, Radius = 7, LayoutOrder = 0, Parent = card })
	Style.Stroke(hole, 0.5, 1.5, Theme.Color.TextSecondary)

	local top = Style.Frame({ Size = UDim2.new(1, 0, 0, 24), LayoutOrder = 1, Parent = card })
	Style.Label({
		Text = Balance.RarityLabel[species.Rarity] or species.Rarity,
		Font = "Bold",
		TextSize = Theme.TextSize.Small,
		Color = rarityColor,
		Size = UDim2.fromScale(0.5, 1),
		Parent = top,
	})
	if info.IsNew then
		local badge = chip(top, Strings.NewSpecies, Theme.Color.Primary, Theme.Color.TextOnAccent, 1)
		badge.AnchorPoint = Vector2.new(1, 0.5)
		badge.Position = UDim2.fromScale(1, 0.5)
	end

	local model = FishModel.Build(species, { Mutation = fish.Mutation, Length = 3.2 })
	local preview = ViewportPreview.new({
		Model = model,
		Size = UDim2.new(1, 0, 0, 170),
		Spin = true,
		LayoutOrder = 2,
		Parent = card,
	})
	currentPreview = preview

	Style.Label({
		Text = species.Name,
		Font = "Display",
		TextSize = Theme.TextSize.Title,
		Color = rarityColor,
		AutoSize = "XY",
		LayoutOrder = 3,
		Parent = card,
	})
	local chips = Style.Frame({ AutoSize = "XY", LayoutOrder = 4, Parent = card })
	Style.List(chips, "Horizontal", Theme.Space.S, Enum.HorizontalAlignment.Center)
	if fish.Mutation ~= "None" then
		chip(chips, "Mutasi " .. fish.Mutation, Theme.Color.Card, Theme.Mutation[fish.Mutation] or Theme.Color.Text, 1)
	end
	if info.Hard then
		chip(chips, Strings.HardMode, Theme.Color.Danger, Theme.Color.TextOnAccent, 2)
	end
	if info.Protected then
		chip(chips, Strings.Protected, Theme.Color.Success, Theme.Color.TextOnAccent, 3)
	end

	-- Angka timbangan.
	local weightRow = Style.Frame({ AutoSize = "XY", LayoutOrder = 5, Parent = card })
	Style.List(weightRow, "Vertical", 0, Enum.HorizontalAlignment.Center)
	local weightLabel = Style.Label({ Text = Format.Kg(0), Font = "Display", TextSize = Theme.TextSize.Hero, AutoSize = "XY", LayoutOrder = 1, Parent = weightRow })
	Style.Label({ Text = Strings.Weight, TextSize = Theme.TextSize.Small, Color = Theme.Color.TextSecondary, AutoSize = "XY", LayoutOrder = 2, Parent = weightRow })

	local stats = Style.Frame({ AutoSize = "XY", LayoutOrder = 6, Parent = card })
	Style.List(stats, "Horizontal", Theme.Space.XL, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
	local priceGroup = Style.Frame({ AutoSize = "XY", LayoutOrder = 1, Parent = stats })
	Style.List(priceGroup, "Horizontal", Theme.Space.XS + 2, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
	if info.Protected then
		local leaf = Icon.new("leaf", 24, Theme.Color.Leaf)
		leaf.LayoutOrder = 1
		leaf.Parent = priceGroup
		Style.Label({ Text = "+" .. tostring(info.Points) .. " poin bila dilepas", Font = "Bold", TextSize = Theme.TextSize.Body, AutoSize = "XY", LayoutOrder = 2, Parent = priceGroup })
	else
		local coin = Icon.new("coin", 24, Theme.Color.Coin)
		coin.LayoutOrder = 1
		coin.Parent = priceGroup
		Style.Label({ Text = Format.Coins(info.Price), Font = "Display", TextSize = Theme.TextSize.Label, AutoSize = "XY", LayoutOrder = 2, Parent = priceGroup })
	end
	Style.Label({ Text = "+" .. tostring(info.XP) .. " XP", Font = "Bold", TextSize = Theme.TextSize.Body, Color = Theme.Color.TealText, AutoSize = "XY", LayoutOrder = 2, Parent = stats })

	if species.Fact then
		Style.Label({
			Text = species.Fact,
			TextSize = Theme.TextSize.Small,
			Color = Theme.Color.TextSecondary,
			Wrap = true,
			AutoSize = "Y",
			Size = UDim2.new(1, 0, 0, 0),
			XAlign = Enum.TextXAlignment.Center,
			LayoutOrder = 7,
			Parent = card,
		})
	end

	local actions = Style.Frame({ AutoSize = "XY", LayoutOrder = 8, Parent = card })
	Style.List(actions, "Horizontal", Theme.Space.S, Enum.HorizontalAlignment.Center)
	if info.Protected then
		Button.new({
			Text = Strings.Release,
			Variant = "Primary",
			Icon = "leaf",
			Width = 200,
			LayoutOrder = 1,
			Parent = actions,
			OnActivated = function()
				CatchPopupController.Dismiss()
				local ok, msg = Net.Invoke("ReleaseFish", { fish.Uid })
				NotificationController.Show(if type(msg) == "string" then msg else "", if ok then "Success" else "Warning")
			end,
		})
		Button.new({
			Text = "Nanti",
			Variant = "Quiet",
			Width = 140,
			LayoutOrder = 2,
			Parent = actions,
			OnActivated = function()
				CatchPopupController.Dismiss()
			end,
		})
	else
		Button.new({
			Text = Strings.Keep,
			Variant = "Secondary",
			Width = 200,
			LayoutOrder = 1,
			Parent = actions,
			OnActivated = function()
				CatchPopupController.Dismiss()
			end,
		})
	end

	current = card
	SoundController.Play("Catch")

	-- Animasi: turun & berayun, tali memanjang, angka timbangan naik.
	local reduced = TweenUtil.ReducedMotion()
	local targetY = UIController.TopInset() + 90
	if reduced then
		card.Position = UDim2.new(0.5, 0, 0, targetY)
		rope.Size = UDim2.new(0, 2, 0, targetY + 6)
		weightLabel.Text = Format.Kg(fish.Weight)
	else
		card.Rotation = 5
		TweenUtil.Play(card, { Position = UDim2.new(0.5, 0, 0, targetY) }, 0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		TweenUtil.Play(rope, { Size = UDim2.new(0, 2, 0, targetY + 6) }, 0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		TweenUtil.Play(card, { Rotation = 0 }, Theme.Motion.Catch, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)
		task.delay(0.35, function()
			TweenUtil.CountUp(weightLabel, 0, fish.Weight, 0.8, Format.Kg)
		end)
	end

	UIController.FocusFirst(actions)
	dismissToken += 1
	local token = dismissToken
	if not info.Protected then
		task.delay(6, function()
			if token == dismissToken and current == card then
				CatchPopupController.Dismiss()
			end
		end)
	end
end

return CatchPopupController
