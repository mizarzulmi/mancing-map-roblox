--!strict
-- ItemCard: kartu barang untuk grid toko/lemari (bahasa "kartu timbang" lapak ikan). Ukuran diatur UIGridLayout
-- induk. Susunan: sumur pratinjau gelap di atas (ViewportPreview statis bila Preview diberikan, kalau tidak ikon),
-- nama, rarity sebagai TEKS + warna Theme.Rarity (bukan garis samping), lalu baris harga — angka FredokaOne emas
-- dengan koin digambar (atau daun hijau untuk Poin) — atau chip status Dimiliki/Dipakai/Terkunci.
-- Dipilih = garis tepi emas 2 px. Hover (pointer) hanya menegaskan garis tepi agar kontras teks rarity tetap
-- ≥ 4,5:1 (latar kartu tidak diganti). Tekan = skala 0,97.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Theme = require(Shared.Config.Theme)
local Balance = require(Shared.Config.Balance)
local Strings = require(Shared.Config.Strings)
local Format = require(Shared.Util.Format)
local TweenUtil = require(Shared.Util.TweenUtil)
local Style = require(script.Parent.Style)
local Icon = require(script.Parent.Icon)
local ViewportPreview = require(script.Parent.ViewportPreview)

export type CardStatus = "None" | "Owned" | "Equipped" | "Locked"
export type Currency = "Coins" | "Points"

export type ItemCardProps = {
	Title: string,
	Subtitle: string?,
	Price: number?,
	Currency: Currency?,
	Status: CardStatus?,
	StatusText: string?,
	Rarity: string?,
	Preview: (() -> Model?)?,
	Icon: Icon.IconName?,
	IconColor: Color3?,
	Selected: boolean?,
	Name: string?,
	LayoutOrder: number?,
	Parent: Instance?,
	OnActivated: (() -> ())?,
}

export type ItemCard = {
	Instance: TextButton,
	SetSelected: (self: ItemCard, selected: boolean) -> (),
	SetStatus: (self: ItemCard, status: CardStatus, text: string?) -> (),
	SetPrice: (self: ItemCard, price: number?, currency: Currency?) -> (),
	SetTitle: (self: ItemCard, title: string) -> (),
	Destroy: (self: ItemCard) -> (),
}

local PAD = Theme.Space.M
local ROW_HEIGHT = 30
local PRICE_ICON = 22
local CHIP_ICON = 18
local PREVIEW_ICON = 52
local HOVER_STROKE = 0.6
local LOCKED_DIM = 0.45
-- "Terkunci" diturunkan dari Strings.LockedLevel ("Terkunci Lv %d") bila StatusText tidak diberikan.
local LOCKED_FALLBACK = (string.gsub(Strings.LockedLevel, "%s*Lv%s*%%d", ""))

local ItemCard = {}

function ItemCard.new(props: ItemCardProps): ItemCard
	local status: CardStatus = props.Status or "None"
	local statusText: string? = props.StatusText
	local price: number? = props.Price
	local currency: Currency = props.Currency or "Coins"
	local selected = props.Selected == true
	local hover, pressed, focused = false, false, false

	local root = Instance.new("TextButton")
	root.Name = props.Name or "ItemCard"
	root.Text = ""
	root.AutoButtonColor = false
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.Size = UDim2.fromOffset(180, 236)
	root.Selectable = true
	root.SelectionImageObject = Style.SelectionImage()
	if props.LayoutOrder then
		root.LayoutOrder = props.LayoutOrder
	end

	local skin = Style.Frame({
		Name = "Skin",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Color = Theme.Color.Card,
		Radius = Theme.Radius.Card,
	})
	local stroke = Style.Stroke(skin)
	Style.Padding(skin, PAD)
	Style.List(skin, "Vertical", Theme.Space.S)

	-- Sumur pratinjau (inset gelap, bukan kartu bersarang): mengisi sisa tinggi kartu.
	local well = Style.Frame({
		Name = "Well",
		Size = UDim2.fromScale(1, 0),
		Color = Theme.Color.Inset,
		Radius = Theme.Radius.Chip,
		Clip = true,
		LayoutOrder = 1,
	})
	local fill = Instance.new("UIFlexItem")
	fill.FlexMode = Enum.UIFlexMode.Fill
	fill.Parent = well

	local preview: ViewportPreview.ViewportPreview? = nil
	local glyph: Frame? = nil
	local factory = props.Preview
	if factory then
		local ok, result = pcall(factory)
		if ok and typeof(result) == "Instance" and result:IsA("Model") then
			-- Sedikit menjorok dari tepi sumur agar model tidak menembus sudut membulat.
			local view = ViewportPreview.new({
				Model = result,
				Spin = false,
				Size = UDim2.new(1, -Theme.Space.S, 1, -Theme.Space.S),
			})
			view.Instance.AnchorPoint = Vector2.new(0.5, 0.5)
			view.Instance.Position = UDim2.fromScale(0.5, 0.5)
			view.Instance.Parent = well
			preview = view
		elseif not ok then
			warn("[ItemCard] pratinjau gagal dibuat: " .. tostring(result))
		end
	end
	if preview == nil then
		local created = Icon.new(props.Icon or "star", PREVIEW_ICON, props.IconColor or Theme.Color.TextSecondary)
		created.AnchorPoint = Vector2.new(0.5, 0.5)
		created.Position = UDim2.fromScale(0.5, 0.5)
		created.Parent = well
		glyph = created
	end
	well.Parent = skin

	local title = Style.Label({
		Name = "Title",
		Text = props.Title,
		Font = "Bold",
		TextSize = Theme.TextSize.Body,
		LayoutOrder = 2,
		Parent = skin,
	})

	local rarity = props.Rarity
	if rarity then
		Style.Label({
			Name = "Rarity",
			Text = Balance.RarityLabel[rarity] or rarity,
			Font = "Bold",
			TextSize = Theme.TextSize.Small,
			Color = Theme.Rarity[rarity] or Theme.Color.TextSecondary,
			LayoutOrder = 3,
			Parent = skin,
		})
	end
	if props.Subtitle and props.Subtitle ~= "" then
		Style.Label({
			Name = "Subtitle",
			Text = props.Subtitle,
			TextSize = Theme.TextSize.Small,
			Color = Theme.Color.TextSecondary,
			LayoutOrder = 4,
			Parent = skin,
		})
	end

	-- Baris bawah: harga ATAU chip status. Chip menyusut (flex) + teks terpotong rapi bila kartu sempit.
	local bottom = Style.Frame({ Name = "Bottom", Size = UDim2.new(1, 0, 0, ROW_HEIGHT), LayoutOrder = 5 })
	Style.List(bottom, "Horizontal", 0, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)

	local priceGroup = Style.Frame({ Name = "Price", Size = UDim2.fromScale(0, 1), AutoSize = "X" })
	Style.List(priceGroup, "Horizontal", Theme.Space.S, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	local priceIcon = Icon.new("coin", PRICE_ICON)
	priceIcon.LayoutOrder = 1
	priceIcon.Parent = priceGroup
	local priceLabel = Style.Label({
		Name = "Amount",
		Text = "",
		Font = "Display",
		TextSize = Theme.TextSize.Label,
		Color = Theme.Color.Primary,
		AutoSize = "X",
		Size = UDim2.fromScale(0, 1),
		LayoutOrder = 2,
		Parent = priceGroup,
	})
	priceGroup.Parent = bottom

	local chip = Style.Frame({
		Name = "Status",
		Size = UDim2.fromScale(0, 1),
		AutoSize = "X",
		Radius = Theme.Radius.Chip,
		Clip = true,
	})
	local chipShrink = Instance.new("UIFlexItem")
	chipShrink.FlexMode = Enum.UIFlexMode.Shrink
	chipShrink.Parent = chip
	local chipStroke = Style.Stroke(chip)
	Style.Padding(chip, 0, Theme.Space.S)
	Style.List(chip, "Horizontal", Theme.Space.XS, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	local chipIconSlot = Style.Frame({ Name = "IconSlot", Size = UDim2.fromOffset(CHIP_ICON, CHIP_ICON), LayoutOrder = 1 })
	chipIconSlot.Parent = chip
	local chipLabel = Style.Label({
		Name = "Text",
		Text = "",
		Font = "Bold",
		TextSize = Theme.TextSize.Small,
		AutoSize = "X",
		Size = UDim2.fromScale(0, 1),
		LayoutOrder = 2,
	})
	chipLabel.TextTruncate = Enum.TextTruncate.AtEnd
	local labelShrink = Instance.new("UIFlexItem")
	labelShrink.FlexMode = Enum.UIFlexMode.Shrink
	labelShrink.Parent = chipLabel
	chipLabel.Parent = chip
	chip.Parent = bottom
	bottom.Parent = skin
	skin.Parent = root

	local chipIcon: Frame? = nil
	local chipIconName: Icon.IconName? = nil

	local function setChipIcon(name: Icon.IconName?, color: Color3)
		if name ~= chipIconName then
			local old = chipIcon
			if old then
				old:Destroy()
			end
			chipIcon = nil
			chipIconName = name
			if name then
				local created = Icon.new(name, CHIP_ICON, color)
				created.Parent = chipIconSlot
				chipIcon = created
			end
		end
		local current = chipIcon
		if current then
			Icon.SetColor(current, color)
		end
		chipIconSlot.Visible = name ~= nil
	end

	local function renderBottom()
		local showStatus = status ~= "None"
		chip.Visible = showStatus
		priceGroup.Visible = not showStatus and price ~= nil
		bottom.Visible = chip.Visible or priceGroup.Visible
		if showStatus then
			if status == "Equipped" then
				chip.BackgroundColor3 = Theme.Color.Secondary
				chip.BackgroundTransparency = 0
				chipStroke.Enabled = false
				chipLabel.TextColor3 = Theme.Color.TextOnAccent
				chipLabel.Text = statusText or Strings.Equipped
				setChipIcon("check", Theme.Color.TextOnAccent)
			elseif status == "Owned" then
				chip.BackgroundTransparency = 1
				chipStroke.Enabled = true
				chipLabel.TextColor3 = Theme.Color.TextSecondary
				chipLabel.Text = statusText or Strings.Owned
				setChipIcon(nil, Theme.Color.TextSecondary)
			else
				chip.BackgroundColor3 = Theme.Color.Inset
				chip.BackgroundTransparency = 0
				chipStroke.Enabled = false
				chipLabel.TextColor3 = Theme.Color.TextSecondary
				chipLabel.Text = statusText or LOCKED_FALLBACK
				setChipIcon("lock", Theme.Color.TextSecondary)
			end
		end
		local amount = price
		if amount ~= nil then
			priceLabel.Text = Format.Int(amount)
			local points = currency == "Points"
			local wanted: Icon.IconName = if points then "leaf" else "coin"
			if priceIcon:GetAttribute("IconName") ~= wanted then
				priceIcon:Destroy()
				priceIcon = Icon.new(wanted, PRICE_ICON, if points then Theme.Color.Leaf else nil)
				priceIcon.LayoutOrder = 1
				priceIcon.Parent = priceGroup
			end
			priceLabel.TextColor3 = if points then Theme.Color.Leaf else Theme.Color.Primary
		end
		-- Terkunci: pratinjau diredupkan, teks tetap terbaca.
		local dim = if status == "Locked" then LOCKED_DIM else 0
		local view = preview
		if view then
			view.Instance.ImageTransparency = dim
		end
		local shape = glyph
		if shape then
			Icon.SetTransparency(shape, dim)
		end
	end

	local function renderFrame()
		if selected then
			stroke.Color = Theme.Color.Primary
			stroke.Thickness = 2
			stroke.Transparency = 0
		else
			stroke.Color = Theme.Color.Stroke
			stroke.Thickness = 1
			stroke.Transparency = if hover or focused then HOVER_STROKE else Theme.Transparency.Stroke
		end
		TweenUtil.Play(skin, { BackgroundColor3 = if pressed then Theme.Color.CardPressed else Theme.Color.Card }, Theme.Motion.Exit)
	end

	Style.Interactive(root, skin, function(state: Style.InteractState)
		hover, pressed, focused = state.Hover, state.Pressed, state.Focused
		renderFrame()
	end)

	root.Activated:Connect(function()
		local callback = props.OnActivated
		if callback then
			callback()
		end
	end)

	local object: ItemCard = {
		Instance = root,
		SetSelected = function(_self: ItemCard, value: boolean)
			selected = value
			renderFrame()
		end,
		SetStatus = function(_self: ItemCard, value: CardStatus, text: string?)
			status = value
			statusText = text
			renderBottom()
		end,
		SetPrice = function(_self: ItemCard, value: number?, valueCurrency: Currency?)
			price = value
			if valueCurrency then
				currency = valueCurrency
			end
			renderBottom()
		end,
		SetTitle = function(_self: ItemCard, text: string)
			title.Text = text
		end,
		Destroy = function(_self: ItemCard)
			local view = preview
			if view then
				view:Destroy()
			end
			root:Destroy()
		end,
	}

	renderBottom()
	renderFrame()
	if props.Parent then
		root.Parent = props.Parent
	end
	return object
end

return ItemCard
