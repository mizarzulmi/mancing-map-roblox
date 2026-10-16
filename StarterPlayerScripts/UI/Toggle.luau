--!strict
-- Toggle: baris pengaturan "Label ........ Nyala [●━]". Seluruh baris (48 px) adalah area sentuh & objek
-- seleksi gamepad. Nyala = track teal + kenop krem di kanan; Mati = track gelap bergaris tepi + kenop redup di
-- kiri; status juga tertulis (Nyala/Mati) agar tidak bergantung pada warna. Kenop bergeser 0,18 dtk Quad Out
-- (instan bila ReducedMotion); tekan = skala 0,97 pada sakelar. Set() tidak memanggil OnChanged.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Theme = require(Shared.Config.Theme)
local Strings = require(Shared.Config.Strings)
local TweenUtil = require(Shared.Util.TweenUtil)
local Style = require(script.Parent.Style)

export type ToggleProps = {
	Label: string,
	Value: boolean,
	Parent: Instance?,
	LayoutOrder: number?,
	OnChanged: ((value: boolean) -> ())?,
}

export type Toggle = {
	Instance: Frame,
	Set: (self: Toggle, value: boolean) -> (),
}

local HEIGHT = Theme.Size.Touch
local SWITCH_WIDTH = 52
local SWITCH_HEIGHT = 30
local KNOB = 22
local INSET = (SWITCH_HEIGHT - KNOB) / 2

local Toggle = {}

function Toggle.new(props: ToggleProps): Toggle
	local value = props.Value == true
	local hover, focused = false, false

	local root = Style.Frame({ Name = "Toggle_" .. props.Label, Size = UDim2.new(1, 0, 0, HEIGHT) })
	if props.LayoutOrder then
		root.LayoutOrder = props.LayoutOrder
	end

	local hit = Instance.new("TextButton")
	hit.Name = "Hit"
	hit.Text = ""
	hit.AutoButtonColor = false
	hit.BackgroundTransparency = 1
	hit.BorderSizePixel = 0
	hit.Size = UDim2.fromScale(1, 1)
	hit.Selectable = true
	hit.SelectionImageObject = Style.SelectionImage()

	local stateWidth = math.max(
		Style.Measure(Strings.On, Theme.TextSize.Small, "Bold").X,
		Style.Measure(Strings.Off, Theme.TextSize.Small, "Bold").X
	) + 2
	local labelReserve = SWITCH_WIDTH + Theme.Space.M + stateWidth + Theme.Space.M

	Style.Label({
		Name = "Label",
		Text = props.Label,
		Size = UDim2.new(1, -labelReserve, 1, 0),
		Parent = hit,
	})
	local stateLabel = Style.Label({
		Name = "State",
		Text = "",
		Font = "Bold",
		TextSize = Theme.TextSize.Small,
		Color = Theme.Color.TextSecondary,
		XAlign = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -(SWITCH_WIDTH + Theme.Space.M), 0.5, 0),
		Size = UDim2.new(0, stateWidth, 1, 0),
		Parent = hit,
	})

	local switch = Style.Frame({
		Name = "Switch",
		Size = UDim2.fromOffset(SWITCH_WIDTH, SWITCH_HEIGHT),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Color = Theme.Color.Inset,
		Radius = SWITCH_HEIGHT / 2,
	})
	local switchStroke = Style.Stroke(switch)
	local knob = Style.Frame({
		Name = "Knob",
		Size = UDim2.fromOffset(KNOB, KNOB),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, INSET, 0.5, 0),
		Color = Theme.Color.TextSecondary,
		Radius = KNOB / 2,
	})
	knob.Parent = switch
	switch.Parent = hit
	hit.Parent = root

	local function render(animate: boolean)
		local knobPosition = if value then UDim2.new(1, -(KNOB + INSET), 0.5, 0) else UDim2.new(0, INSET, 0.5, 0)
		local track = if value
			then (if hover or focused then Theme.Color.SecondaryHover else Theme.Color.Secondary)
			else (if hover or focused then Theme.Color.CardHover else Theme.Color.Inset)
		local knobColor = if value then Theme.Color.Text else Theme.Color.TextSecondary
		if animate then
			TweenUtil.Play(knob, { Position = knobPosition, BackgroundColor3 = knobColor }, Theme.Motion.Duration)
			TweenUtil.Play(switch, { BackgroundColor3 = track }, Theme.Motion.Duration)
		else
			knob.Position = knobPosition
			knob.BackgroundColor3 = knobColor
			switch.BackgroundColor3 = track
		end
		switchStroke.Enabled = not value
		stateLabel.Text = if value then Strings.On else Strings.Off
		stateLabel.TextColor3 = if value then Theme.Color.Text else Theme.Color.TextSecondary
	end

	Style.Interactive(hit, switch, function(state: Style.InteractState)
		hover, focused = state.Hover, state.Focused
		render(true)
	end)

	hit.Activated:Connect(function()
		value = not value
		render(true)
		local callback = props.OnChanged
		if callback then
			callback(value)
		end
	end)

	local object: Toggle = {
		Instance = root,
		Set = function(_self: Toggle, newValue: boolean)
			value = newValue
			render(false)
		end,
	}

	render(false)
	if props.Parent then
		root.Parent = props.Parent
	end
	return object
end

return Toggle
