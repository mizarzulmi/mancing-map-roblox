--!strict
-- Button: tombol teks bertema. Primary = emas (CTA utama, satu per layar), Secondary = teal, Danger = oranye
-- (jual/bahaya), Quiet = transparan + garis tepi tipis. Teks gelap di atas warna aksen (kontras ≥ 6,8:1).
-- State: hover (hanya pointer), tekan (skala 0,97 via UIScale di dalam tombol), fokus gamepad (cincin emas +
-- warna hover), nonaktif (transparansi Theme.Transparency.Disabled, tidak bisa ditekan/diseleksi), sibuk
-- (pemutar kecil menggantikan isi, lebar tetap). Lebar otomatis dihitung dari teks agar tekan tidak menggeser layout.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Theme = require(Shared.Config.Theme)
local TweenUtil = require(Shared.Util.TweenUtil)
local Style = require(script.Parent.Style)
local Icon = require(script.Parent.Icon)

export type Variant = "Primary" | "Secondary" | "Danger" | "Quiet"

export type ButtonProps = {
	Text: string,
	Variant: Variant?,
	Icon: Icon.IconName?,
	Size: UDim2?,
	Width: number?,
	Name: string?,
	LayoutOrder: number?,
	Disabled: boolean?,
	Hotkey: string?,
	Parent: Instance?,
	OnActivated: (() -> ())?,
}

export type Button = {
	Instance: TextButton,
	SetText: (self: Button, text: string) -> (),
	SetDisabled: (self: Button, disabled: boolean) -> (),
	SetVariant: (self: Button, variant: Variant) -> (),
	SetBusy: (self: Button, busy: boolean) -> (),
	Destroy: (self: Button) -> (),
}

type Palette = {
	Base: Color3,
	Hover: Color3,
	Pressed: Color3,
	Text: Color3,
	Fill: boolean,
}

local PALETTES: { [string]: Palette } = {
	Primary = {
		Base = Theme.Color.Primary,
		Hover = Theme.Color.PrimaryHover,
		Pressed = Theme.Color.PrimaryPressed,
		Text = Theme.Color.TextOnAccent,
		Fill = true,
	},
	Secondary = {
		Base = Theme.Color.Secondary,
		Hover = Theme.Color.SecondaryHover,
		Pressed = Theme.Color.SecondaryPressed,
		Text = Theme.Color.TextOnAccent,
		Fill = true,
	},
	Danger = {
		Base = Theme.Color.Danger,
		Hover = Theme.Color.DangerHover,
		Pressed = Theme.Color.DangerPressed,
		Text = Theme.Color.TextOnAccent,
		Fill = true,
	},
	Quiet = {
		Base = Theme.Color.Card,
		Hover = Theme.Color.CardHover,
		Pressed = Theme.Color.CardPressed,
		Text = Theme.Color.Text,
		Fill = false,
	},
}

local HEIGHT = Theme.Size.ButtonHeight
local PAD_X = Theme.Space.XL
local GAP = Theme.Space.S
local ICON_SIZE = 24
local TEXT_SIZE = Theme.TextSize.Label
local CHIP_HEIGHT = 26
local MIN_WIDTH = HEIGHT * 2
-- Tint gelap chip hotkey di atas tombol beraksen (teks tetap gelap → kontras tinggi).
local CHIP_TINT = 0.82

local Button = {}

local function fade(base: number, alpha: number): number
	return base + (1 - base) * alpha
end

-- Pemutar sibuk: cincin dengan UIGradient pada stroke membentuk busur; berputar kecuali ReducedMotion.
local function createSpinner(parent: GuiObject, color: Color3): (Frame, UIGradient)
	local spinner = Instance.new("Frame")
	spinner.Name = "Spinner"
	spinner.BackgroundTransparency = 1
	spinner.BorderSizePixel = 0
	spinner.AnchorPoint = Vector2.new(0.5, 0.5)
	spinner.Position = UDim2.fromScale(0.5, 0.5)
	spinner.Size = UDim2.fromOffset(20, 20)
	spinner.Visible = false
	Style.Corner(spinner, 10)
	local stroke = Style.Stroke(spinner, 0, 3, color)
	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.55, 0),
		NumberSequenceKeypoint.new(0.56, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Parent = stroke
	spinner.Parent = parent
	return spinner, gradient
end

function Button.new(props: ButtonProps): Button
	local variant: Variant = props.Variant or "Primary"
	local disabled = props.Disabled == true
	local busy = false
	local hover, pressed, focused = false, false, false
	local autoWidth = props.Size == nil and props.Width == nil

	local root = Instance.new("TextButton")
	root.Name = props.Name or "Button"
	root.Text = ""
	root.AutoButtonColor = false
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.Selectable = true
	root.SelectionImageObject = Style.SelectionImage()
	if props.LayoutOrder then
		root.LayoutOrder = props.LayoutOrder
	end
	if props.Size then
		root.Size = props.Size
	else
		root.Size = UDim2.fromOffset(props.Width or MIN_WIDTH, HEIGHT)
	end

	-- Kulit visual terpisah dari area sentuh: UIScale tekan mengecilkan kulit, bukan kotak layout.
	local skin = Style.Frame({ Name = "Skin", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
	skin.BackgroundTransparency = 0
	Style.Corner(skin, Theme.Radius.Button)
	local stroke = Style.Stroke(skin)

	local content = Style.Frame({ Name = "Content" })
	Style.List(content, "Horizontal", GAP, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
	Style.Padding(content, 0, PAD_X)

	local icon: Frame? = nil
	if props.Icon then
		local created = Icon.new(props.Icon, ICON_SIZE)
		created.LayoutOrder = 1
		created.Parent = content
		icon = created
	end

	local label = Style.Label({
		Name = "Text",
		Text = props.Text,
		Font = "Bold",
		TextSize = TEXT_SIZE,
		XAlign = Enum.TextXAlignment.Center,
		LayoutOrder = 2,
	})
	local shrink = Instance.new("UIFlexItem")
	shrink.FlexMode = Enum.UIFlexMode.Shrink
	shrink.Parent = label
	label.Parent = content

	local chip: Frame? = nil
	local chipText: TextLabel? = nil
	if props.Hotkey then
		local createdChip, createdText = Style.Chip({
			Name = "Hotkey",
			Text = props.Hotkey,
			Height = CHIP_HEIGHT,
			LayoutOrder = 3,
			Color = Theme.Color.Inset,
			Parent = content,
		})
		chip, chipText = createdChip, createdText
	end

	content.Parent = skin
	skin.Parent = root

	local spinner: Frame? = nil
	local spinnerGradient: UIGradient? = nil
	local spinTween: Tween? = nil
	-- Warna awal langsung diterapkan; render berikutnya hanya men-tween bila warna berubah.
	local shownColor = if PALETTES[variant].Fill then PALETTES[variant].Base else PALETTES[variant].Hover
	skin.BackgroundColor3 = shownColor

	local function chipVisible(): boolean
		return chip ~= nil and Style.IsPointer()
	end

	local function measureLabel()
		local textWidth = Style.Measure(label.Text, TEXT_SIZE, "Bold").X + 2
		label.Size = UDim2.new(0, textWidth, 1, 0)
		if not autoWidth then
			return
		end
		local width = PAD_X * 2 + textWidth
		if icon then
			width += ICON_SIZE + GAP
		end
		local hotkey = chipText
		if hotkey and chipVisible() then
			width += math.max(CHIP_HEIGHT, Style.Measure(hotkey.Text, Theme.TextSize.Small, "Bold").X + Theme.Space.S * 2) + GAP
		end
		root.Size = UDim2.fromOffset(math.max(MIN_WIDTH, width), HEIGHT)
	end

	local function render()
		local palette = PALETTES[variant]
		local alpha = if disabled then Theme.Transparency.Disabled else 0
		local active = not disabled and not busy
		local lit = active and (hover or focused)
		local down = active and pressed
		local fillColor: Color3
		local fillTransparency: number
		if palette.Fill then
			fillColor = if down then palette.Pressed elseif lit then palette.Hover else palette.Base
			fillTransparency = 0
		else
			fillColor = if down then palette.Pressed else palette.Hover
			fillTransparency = if down or lit then 0 else 1
		end
		if fillColor ~= shownColor then
			shownColor = fillColor
			TweenUtil.Play(skin, { BackgroundColor3 = fillColor }, Theme.Motion.Exit)
		end
		skin.BackgroundTransparency = fade(fillTransparency, alpha)
		stroke.Enabled = not palette.Fill
		stroke.Transparency = fade(Theme.Transparency.Stroke, alpha)

		label.TextColor3 = palette.Text
		label.TextTransparency = if busy then 1 else alpha
		local glyph = icon
		if glyph then
			Icon.SetColor(glyph, palette.Text)
			Icon.SetTransparency(glyph, if busy then 1 else alpha)
		end
		local hotkey, hotkeyText = chip, chipText
		if hotkey and hotkeyText then
			hotkey.Visible = chipVisible()
			if palette.Fill then
				hotkey.BackgroundColor3 = palette.Text
				hotkey.BackgroundTransparency = if busy then 1 else fade(CHIP_TINT, alpha)
				hotkeyText.TextColor3 = palette.Text
			else
				hotkey.BackgroundColor3 = Theme.Color.Inset
				hotkey.BackgroundTransparency = if busy then 1 else alpha
				hotkeyText.TextColor3 = Theme.Color.TextSecondary
			end
			hotkeyText.TextTransparency = if busy then 1 else alpha
		end
		local ring = spinner
		if ring then
			ring.Visible = busy
			local ringStroke = ring:FindFirstChildOfClass("UIStroke")
			if ringStroke then
				ringStroke.Color = palette.Text
			end
		end
		root.Interactable = active
		root.Selectable = not disabled
	end

	local function setSpinning(on: boolean)
		local current = spinTween
		if current then
			current:Cancel()
			spinTween = nil
		end
		local gradient = spinnerGradient
		if on and gradient and not TweenUtil.ReducedMotion() then
			gradient.Rotation = 0
			local tween = TweenService:Create(
				gradient,
				TweenInfo.new(0.9, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
				{ Rotation = 360 }
			)
			tween:Play()
			spinTween = tween
		end
	end

	Style.Interactive(root, skin, function(state: Style.InteractState)
		hover, pressed, focused = state.Hover, state.Pressed, state.Focused
		render()
	end)

	local inputConn = Style.OnInputChanged(function()
		measureLabel()
		render()
	end)
	root.Destroying:Connect(function()
		inputConn:Disconnect()
		setSpinning(false)
	end)

	root.Activated:Connect(function()
		if disabled or busy then
			return
		end
		local callback = props.OnActivated
		if callback then
			callback()
		end
	end)

	local object: Button = {
		Instance = root,
		SetText = function(_self: Button, text: string)
			label.Text = text
			measureLabel()
		end,
		SetDisabled = function(_self: Button, value: boolean)
			disabled = value
			render()
		end,
		SetVariant = function(_self: Button, value: Variant)
			variant = value
			render()
		end,
		SetBusy = function(_self: Button, value: boolean)
			if busy == value then
				return
			end
			busy = value
			if value and spinner == nil then
				local createdSpinner, createdGradient = createSpinner(skin, PALETTES[variant].Text)
				spinner, spinnerGradient = createdSpinner, createdGradient
			end
			setSpinning(value)
			render()
		end,
		Destroy = function(_self: Button)
			root:Destroy()
		end,
	}

	measureLabel()
	render()
	if props.Parent then
		root.Parent = props.Parent
	end
	return object
end

return Button
