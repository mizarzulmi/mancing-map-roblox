--!strict
-- Slider: baris pengaturan "Label  ━━━━●──────  75%". Seret dengan mouse/sentuh (UserInputService; posisi
-- dihitung dari titik awal seret + lebar track saat mulai, sehingga perubahan skala UI selama seret tidak
-- memantul balik), ketuk track untuk melompat. Gamepad/keyboard saat terseleksi: kiri/kanan (D-pad, stik kiri,
-- panah) menggeser satu langkah; ditahan = berulang. Nilai tampil di kanan. Set() tidak memanggil OnChanged
-- (dipakai untuk sinkron dari data). Area sentuh setinggi 48 px; kenop membesar saat disentuh/diseret.

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local Theme = require(Shared.Config.Theme)
local Format = require(Shared.Util.Format)
local TweenUtil = require(Shared.Util.TweenUtil)
local Style = require(script.Parent.Style)

export type SliderProps = {
	Label: string,
	Value: number,
	Min: number?,
	Max: number?,
	Step: number?,
	Format: ((value: number) -> string)?,
	Parent: Instance?,
	LayoutOrder: number?,
	OnChanged: ((value: number) -> ())?,
}

export type Slider = {
	Instance: Frame,
	Set: (self: Slider, value: number) -> (),
}

local HEIGHT = Theme.Size.Touch
local LABEL_SCALE = 0.38
local VALUE_WIDTH = 76
local TRACK_HEIGHT = 8
local KNOB = 24
local KNOB_ACTIVE = 1.15
local REPEAT_DELAY = 0.35
local REPEAT_INTERVAL = 0.08
local STICK_ON = 0.6
local STICK_OFF = 0.3

local Slider = {}

local function defaultFormat(min: number, max: number, step: number?): (value: number) -> string
	if min == 0 and max == 1 then
		return function(value: number): string
			return Format.Percent(value)
		end
	end
	if step and step % 1 == 0 then
		return function(value: number): string
			return Format.Int(value)
		end
	end
	return function(value: number): string
		return Format.Decimal(value, 2)
	end
end

function Slider.new(props: SliderProps): Slider
	local min = props.Min or 0
	local max = props.Max or 1
	if max <= min then
		max = min + 1
	end
	local step = props.Step
	local formatter = props.Format or defaultFormat(min, max, step)
	local padStep = if step and step > 0 then step else (max - min) / 20

	local function snap(raw: number): number
		local value = math.clamp(raw, min, max)
		if step and step > 0 then
			value = math.clamp(min + math.floor((value - min) / step + 0.5) * step, min, max)
		end
		-- Buang derau floating point (0,1 + 0,2 ≠ 0,3).
		return math.floor(value * 1e6 + 0.5) / 1e6
	end

	local value = snap(props.Value)

	local root = Style.Frame({ Name = "Slider_" .. props.Label, Size = UDim2.new(1, 0, 0, HEIGHT) })
	if props.LayoutOrder then
		root.LayoutOrder = props.LayoutOrder
	end
	Style.Label({
		Name = "Label",
		Text = props.Label,
		Size = UDim2.new(LABEL_SCALE, -Theme.Space.S, 1, 0),
		Parent = root,
	})
	local valueLabel = Style.Label({
		Name = "Value",
		Text = formatter(value),
		Font = "Bold",
		XAlign = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.new(0, VALUE_WIDTH, 1, 0),
		Parent = root,
	})

	local hit = Instance.new("TextButton")
	hit.Name = "Track"
	hit.Text = ""
	hit.AutoButtonColor = false
	hit.BackgroundTransparency = 1
	hit.BorderSizePixel = 0
	hit.Position = UDim2.fromScale(LABEL_SCALE, 0)
	hit.Size = UDim2.new(1 - LABEL_SCALE, -(VALUE_WIDTH + Theme.Space.M), 1, 0)
	hit.Selectable = true
	hit.SelectionImageObject = Style.SelectionImage()
	-- Kiri/kanan dipakai untuk mengubah nilai, bukan berpindah seleksi.
	hit.NextSelectionLeft = hit
	hit.NextSelectionRight = hit

	local track = Style.Frame({
		Name = "Rail",
		Size = UDim2.new(1, -KNOB, 0, TRACK_HEIGHT),
		Position = UDim2.new(0, KNOB / 2, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Color = Theme.Color.Inset,
		Radius = TRACK_HEIGHT / 2,
	})
	Style.Stroke(track)
	local fill = Style.Frame({
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		Color = Theme.Color.Secondary,
		Radius = TRACK_HEIGHT / 2,
	})
	fill.Parent = track
	local knob = Style.Frame({
		Name = "Knob",
		Size = UDim2.fromOffset(KNOB, KNOB),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Color = Theme.Color.Text,
		Radius = KNOB / 2,
		ZIndex = 2,
	})
	Style.Stroke(knob, 0.4, 1, Theme.Color.Inset)
	Style.Shadow(knob)
	local knobScale = Instance.new("UIScale")
	knobScale.Parent = knob
	knob.Parent = track
	track.Parent = hit
	hit.Parent = root

	local dragging = false
	local dragInput: InputObject? = nil
	local dragStartX = 0
	local dragStartRaw = 0
	local dragWidth = 1
	local hovering, focused = false, false
	local holdDir = 0
	local holdTimer = 0
	local holdConn: RBXScriptConnection? = nil

	local function render()
		local fraction = (value - min) / (max - min)
		fill.Size = UDim2.fromScale(fraction, 1)
		fill.Visible = fraction > 0
		knob.Position = UDim2.fromScale(fraction, 0.5)
		valueLabel.Text = formatter(value)
	end

	local function renderKnob()
		local target = if dragging or hovering or focused then KNOB_ACTIVE else 1
		TweenUtil.Play(knobScale, { Scale = target }, if target > 1 then Theme.Motion.Exit else Theme.Motion.Duration)
	end

	local function setValue(raw: number, notify: boolean)
		local snapped = snap(raw)
		if snapped == value then
			return
		end
		value = snapped
		render()
		local callback = props.OnChanged
		if notify and callback then
			callback(value)
		end
	end

	local function stopHold()
		holdDir = 0
		local conn = holdConn
		if conn then
			conn:Disconnect()
			holdConn = nil
		end
	end

	local function startHold(direction: number)
		if holdDir == direction then
			return
		end
		stopHold()
		holdDir = direction
		setValue(value + direction * padStep, true)
		holdTimer = -REPEAT_DELAY
		holdConn = RunService.Heartbeat:Connect(function(dt: number)
			holdTimer += dt
			while holdTimer >= REPEAT_INTERVAL do
				holdTimer -= REPEAT_INTERVAL
				setValue(value + holdDir * padStep, true)
			end
		end)
	end

	local function isPointerPress(input: InputObject): boolean
		return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
	end

	hit.InputBegan:Connect(function(input: InputObject)
		if not isPointerPress(input) then
			return
		end
		local left = track.AbsolutePosition.X
		local width = math.max(1, track.AbsoluteSize.X)
		local raw = min + math.clamp((input.Position.X - left) / width, 0, 1) * (max - min)
		dragging = true
		dragInput = input
		dragStartX = input.Position.X
		dragStartRaw = raw
		dragWidth = width
		setValue(raw, true)
		renderKnob()
	end)

	local conns: { RBXScriptConnection } = {}
	table.insert(
		conns,
		UserInputService.InputChanged:Connect(function(input: InputObject)
			if dragging then
				local moved = input.UserInputType == Enum.UserInputType.MouseMovement
					or (input.UserInputType == Enum.UserInputType.Touch and input == dragInput)
				if moved then
					local delta = (input.Position.X - dragStartX) / dragWidth * (max - min)
					setValue(dragStartRaw + delta, true)
				end
				return
			end
			if input.KeyCode == Enum.KeyCode.Thumbstick1 and GuiService.SelectedObject == hit then
				local x = input.Position.X
				if x > STICK_ON then
					startHold(1)
				elseif x < -STICK_ON then
					startHold(-1)
				elseif math.abs(x) < STICK_OFF then
					stopHold()
				end
			end
		end)
	)
	table.insert(
		conns,
		UserInputService.InputBegan:Connect(function(input: InputObject)
			if GuiService.SelectedObject ~= hit then
				return
			end
			local key = input.KeyCode
			if key == Enum.KeyCode.DPadLeft or key == Enum.KeyCode.Left then
				startHold(-1)
			elseif key == Enum.KeyCode.DPadRight or key == Enum.KeyCode.Right then
				startHold(1)
			end
		end)
	)
	table.insert(
		conns,
		UserInputService.InputEnded:Connect(function(input: InputObject)
			if dragging and (input == dragInput or input.UserInputType == Enum.UserInputType.MouseButton1) then
				dragging = false
				dragInput = nil
				renderKnob()
				return
			end
			local key = input.KeyCode
			if
				key == Enum.KeyCode.DPadLeft
				or key == Enum.KeyCode.DPadRight
				or key == Enum.KeyCode.Left
				or key == Enum.KeyCode.Right
			then
				stopHold()
			end
		end)
	)

	Style.Interactive(hit, nil, function(state: Style.InteractState)
		hovering, focused = state.Hover, state.Focused
		if not focused then
			stopHold()
		end
		renderKnob()
	end)

	root.Destroying:Connect(function()
		stopHold()
		for _, conn in conns do
			conn:Disconnect()
		end
		table.clear(conns)
	end)

	local object: Slider = {
		Instance = root,
		Set = function(_self: Slider, raw: number)
			value = snap(raw)
			render()
		end,
	}

	render()
	if props.Parent then
		root.Parent = props.Parent
	end
	return object
end

return Slider
