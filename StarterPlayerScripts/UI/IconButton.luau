--!strict
-- IconButton: tombol menu HUD. Ubin panel persegi berisi ikon garis, label kecil di bawah ubin (dengan garis
-- tepi teks gelap agar terbaca di atas pasir maupun langit), badge emas di sudut kanan atas (jumlah/penanda),
-- chip hotkey di sudut kanan bawah (hanya saat keyboard+mouse). Aktif (panelnya terbuka) = garis tepi emas 2 px.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Theme = require(Shared.Config.Theme)
local TweenUtil = require(Shared.Util.TweenUtil)
local Style = require(script.Parent.Style)
local Icon = require(script.Parent.Icon)

export type IconButtonProps = {
	Icon: Icon.IconName,
	Label: string,
	Hotkey: string?,
	Size: number?,
	Name: string?,
	LayoutOrder: number?,
	Parent: Instance?,
	OnActivated: (() -> ())?,
}

export type IconButton = {
	Instance: TextButton,
	SetBadge: (self: IconButton, text: string?) -> (),
	SetActive: (self: IconButton, active: boolean) -> (),
	Destroy: (self: IconButton) -> (),
}

local LABEL_SIZE = Theme.TextSize.Small
local LABEL_HEIGHT = math.ceil(LABEL_SIZE * 1.25)
local LABEL_GAP = Theme.Space.XS
local CHIP_HEIGHT = 24

local IconButton = {}

function IconButton.new(props: IconButtonProps): IconButton
	local tileSize = props.Size or Theme.Size.IconButton
	local labelWidth = Style.Measure(props.Label, LABEL_SIZE, "Bold").X
	local width = math.max(tileSize, labelWidth + Theme.Space.S)
	local active = false
	local hover, pressed, focused = false, false, false

	local root = Instance.new("TextButton")
	root.Name = props.Name or ("Menu_" .. props.Label)
	root.Text = ""
	root.AutoButtonColor = false
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.Size = UDim2.fromOffset(width, tileSize + LABEL_GAP + LABEL_HEIGHT)
	root.Selectable = true
	root.SelectionImageObject = Style.SelectionImage()
	if props.LayoutOrder then
		root.LayoutOrder = props.LayoutOrder
	end

	local tile = Style.Frame({
		Name = "Tile",
		Size = UDim2.fromOffset(tileSize, tileSize),
		Position = UDim2.new(0.5, 0, 0, tileSize / 2),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Color = Theme.Color.Panel,
		Transparency = Theme.Transparency.Panel,
		Radius = Theme.Radius.Panel,
	})
	local tileStroke = Style.Stroke(tile)
	Style.Shadow(tile)

	local glyph = Icon.new(props.Icon, Theme.Size.HudIcon)
	glyph.AnchorPoint = Vector2.new(0.5, 0.5)
	glyph.Position = UDim2.fromScale(0.5, 0.5)
	glyph.Parent = tile

	-- Badge emas: teks = jumlah/penanda; string kosong = titik kecil.
	local badge, badgeText = Style.Chip({
		Name = "Badge",
		Text = "",
		Height = CHIP_HEIGHT,
		Color = Theme.Color.Primary,
		TextColor = Theme.Color.TextOnAccent,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -Theme.Space.XS, 0, Theme.Space.XS),
		ZIndex = 3,
		Parent = tile,
	})
	badge.Visible = false

	local hotkeyChip: Frame? = nil
	if props.Hotkey then
		local chip = Style.Chip({
			Name = "Hotkey",
			Text = props.Hotkey,
			Height = CHIP_HEIGHT - 2,
			Color = Theme.Color.Inset,
			TextColor = Theme.Color.TextSecondary,
			Stroke = true,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -Theme.Space.XS, 1, -Theme.Space.XS),
			ZIndex = 3,
			Parent = tile,
		})
		hotkeyChip = chip
	end

	tile.Parent = root

	local label = Style.Label({
		Name = "Label",
		Text = props.Label,
		Font = "Bold",
		TextSize = LABEL_SIZE,
		XAlign = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, tileSize + LABEL_GAP),
		Size = UDim2.new(1, 0, 0, LABEL_HEIGHT),
	})
	label.TextTruncate = Enum.TextTruncate.None
	-- Garis tepi teks gelap tipis: label HUD duduk langsung di atas dunia 3D.
	local outline = Instance.new("UIStroke")
	outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	outline.Color = Theme.World.NameStroke
	outline.Thickness = 1.5
	outline.Transparency = 0.35
	outline.Parent = label
	label.Parent = root

	local shownColor = Theme.Color.Panel

	local function render()
		local fill = if pressed then Theme.Color.CardPressed elseif hover or focused then Theme.Color.CardHover else Theme.Color.Panel
		if fill ~= shownColor then
			shownColor = fill
			TweenUtil.Play(tile, { BackgroundColor3 = fill }, Theme.Motion.Exit)
		end
		tile.BackgroundTransparency = if fill == Theme.Color.Panel then Theme.Transparency.Panel else 0
		if active then
			tileStroke.Color = Theme.Color.Primary
			tileStroke.Thickness = 2
			tileStroke.Transparency = 0
		else
			tileStroke.Color = Theme.Color.Stroke
			tileStroke.Thickness = 1
			tileStroke.Transparency = Theme.Transparency.Stroke
		end
		local chip = hotkeyChip
		if chip then
			chip.Visible = Style.IsPointer()
		end
	end

	Style.Interactive(root, tile, function(state: Style.InteractState)
		hover, pressed, focused = state.Hover, state.Pressed, state.Focused
		render()
	end)
	local inputConn = Style.OnInputChanged(render)
	root.Destroying:Connect(function()
		inputConn:Disconnect()
	end)

	root.Activated:Connect(function()
		local callback = props.OnActivated
		if callback then
			callback()
		end
	end)

	local object: IconButton = {
		Instance = root,
		SetBadge = function(_self: IconButton, text: string?)
			Style.SetBadge(badge, badgeText, text, CHIP_HEIGHT)
		end,
		SetActive = function(_self: IconButton, value: boolean)
			active = value
			render()
		end,
		Destroy = function(_self: IconButton)
			root:Destroy()
		end,
	}

	render()
	if props.Parent then
		root.Parent = props.Parent
	end
	return object
end

return IconButton
