--!strict
-- QuantityPicker: segmen jumlah beli (mis. 1 · 5 · 10 · Maks). Opsi 0 = "Maks" (props.MaxLabel atau Strings.Max).
-- Setiap segmen ≥ 48 × 64 px dengan jarak 8 px. Terpilih = garis tepi emas 2 px + latar terang + teks terang;
-- lainnya garis tepi tipis + teks sekunder. Select() terprogram memanggil OnChanged bila nilainya berubah
-- (sama seperti Tabs.Select tanpa silent).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Theme = require(Shared.Config.Theme)
local Strings = require(Shared.Config.Strings)
local Format = require(Shared.Util.Format)
local Style = require(script.Parent.Style)

export type QuantityPickerProps = {
	Options: { number },
	Selected: number?,
	MaxLabel: string?,
	Parent: Instance?,
	LayoutOrder: number?,
	OnChanged: ((value: number) -> ())?,
}

export type QuantityPicker = {
	Instance: Frame,
	Select: (self: QuantityPicker, value: number) -> (),
	Get: (self: QuantityPicker) -> number,
}

type Segment = {
	Value: number,
	Button: TextButton,
	Skin: Frame,
	Stroke: UIStroke,
	Label: TextLabel,
	Hover: boolean,
	Pressed: boolean,
	Focused: boolean,
}

local HEIGHT = Theme.Size.Touch
local MIN_WIDTH = 64
local PAD_X = Theme.Space.L
local HOVER_STROKE = 0.6

local QuantityPicker = {}

function QuantityPicker.new(props: QuantityPickerProps): QuantityPicker
	local root = Style.Frame({ Name = "QuantityPicker", Size = UDim2.fromOffset(0, HEIGHT), AutoSize = "X" })
	if props.LayoutOrder then
		root.LayoutOrder = props.LayoutOrder
	end
	Style.List(root, "Horizontal", Theme.Space.S, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)

	local segments: { Segment } = {}
	local current = props.Selected or props.Options[1] or 0

	local function render(segment: Segment)
		local isSelected = segment.Value == current
		local lit = segment.Hover or segment.Focused
		if isSelected then
			segment.Stroke.Color = Theme.Color.Primary
			segment.Stroke.Thickness = 2
			segment.Stroke.Transparency = 0
		else
			segment.Stroke.Color = Theme.Color.Stroke
			segment.Stroke.Thickness = 1
			segment.Stroke.Transparency = if lit then HOVER_STROKE else Theme.Transparency.Stroke
		end
		if segment.Pressed then
			segment.Skin.BackgroundColor3 = Theme.Color.CardPressed
			segment.Skin.BackgroundTransparency = 0
		elseif isSelected then
			segment.Skin.BackgroundColor3 = Theme.Color.CardHover
			segment.Skin.BackgroundTransparency = 0
		else
			segment.Skin.BackgroundTransparency = 1
		end
		segment.Label.TextColor3 = if isSelected or lit then Theme.Color.Text else Theme.Color.TextSecondary
	end

	local function renderAll()
		for _, segment in segments do
			render(segment)
		end
	end

	local object: QuantityPicker

	for index, option in props.Options do
		local text = if option == 0 then (props.MaxLabel or Strings.Max) else Format.Int(option)
		local width = math.max(MIN_WIDTH, Style.Measure(text, Theme.TextSize.Body, "Bold").X + PAD_X * 2)

		local button = Instance.new("TextButton")
		button.Name = "Option_" .. tostring(option)
		button.Text = ""
		button.AutoButtonColor = false
		button.BackgroundTransparency = 1
		button.BorderSizePixel = 0
		button.Size = UDim2.fromOffset(width, HEIGHT)
		button.LayoutOrder = index
		button.Selectable = true
		button.SelectionImageObject = Style.SelectionImage()

		local skin = Style.Frame({
			Name = "Skin",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Color = Theme.Color.CardHover,
			Transparency = 1,
			Radius = Theme.Radius.Button,
		})
		local stroke = Style.Stroke(skin)
		local label = Style.Label({
			Name = "Text",
			Text = text,
			Font = "Bold",
			TextSize = Theme.TextSize.Body,
			XAlign = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 1),
			Parent = skin,
		})
		skin.Parent = button

		local segment: Segment = {
			Value = option,
			Button = button,
			Skin = skin,
			Stroke = stroke,
			Label = label,
			Hover = false,
			Pressed = false,
			Focused = false,
		}
		table.insert(segments, segment)

		Style.Interactive(button, skin, function(state: Style.InteractState)
			segment.Hover, segment.Pressed, segment.Focused = state.Hover, state.Pressed, state.Focused
			render(segment)
		end)
		button.Activated:Connect(function()
			object:Select(option)
		end)
		button.Parent = root
	end

	object = {
		Instance = root,
		Select = function(_self: QuantityPicker, value: number)
			local known = false
			for _, segment in segments do
				if segment.Value == value then
					known = true
					break
				end
			end
			if not known or value == current then
				return
			end
			current = value
			renderAll()
			local callback = props.OnChanged
			if callback then
				callback(value)
			end
		end,
		Get = function(_self: QuantityPicker): number
			return current
		end,
	}

	renderAll()
	if props.Parent then
		root.Parent = props.Parent
	end
	return object
end

return QuantityPicker
