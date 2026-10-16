--!strict
-- ProgressBar: bar kemajuan (XP, fishdex, quest). Track = sumur gelap Theme.Color.Inset dengan garis tepi tipis,
-- isi berwarna (default teal sekunder; emas dipakai pemanggil hanya untuk nilai). Label opsional di atas track
-- (teks sekunder kecil). Isi minimal setinggi track agar ujung membulat tidak gepeng; 0 = isi disembunyikan.
-- props.Size hanya menentukan lebar; tinggi mengikuti track + label.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Theme = require(Shared.Config.Theme)
local TweenUtil = require(Shared.Util.TweenUtil)
local Style = require(script.Parent.Style)

export type ProgressBarProps = {
	Fill: number?,
	Color: Color3?,
	Height: number?,
	Label: string?,
	Name: string?,
	Size: UDim2?,
	LayoutOrder: number?,
	Parent: Instance?,
}

export type ProgressBar = {
	Instance: Frame,
	SetFill: (self: ProgressBar, fill: number, animate: boolean?) -> (),
	SetColor: (self: ProgressBar, color: Color3) -> (),
	SetLabel: (self: ProgressBar, text: string?) -> (),
}

local DEFAULT_HEIGHT = 12

local ProgressBar = {}

local function clampFill(value: number): number
	if value ~= value then
		return 0
	end
	return math.clamp(value, 0, 1)
end

function ProgressBar.new(props: ProgressBarProps): ProgressBar
	local height = props.Height or DEFAULT_HEIGHT
	local width = props.Size or UDim2.fromScale(1, 0)
	local root = Style.Frame({
		Name = props.Name or "ProgressBar",
		Size = UDim2.new(width.X.Scale, width.X.Offset, 0, 0),
		AutoSize = "Y",
	})
	if props.LayoutOrder then
		root.LayoutOrder = props.LayoutOrder
	end
	Style.List(root, "Vertical", Theme.Space.XS)

	local label = Style.Label({
		Name = "Label",
		Text = props.Label or "",
		TextSize = Theme.TextSize.Small,
		Color = Theme.Color.TextSecondary,
		LayoutOrder = 1,
		Parent = root,
	})
	label.Visible = props.Label ~= nil

	local track = Style.Frame({
		Name = "Track",
		Size = UDim2.new(1, 0, 0, height),
		Color = Theme.Color.Inset,
		Radius = math.ceil(height / 2),
		LayoutOrder = 2,
	})
	Style.Stroke(track)
	local fillFrame = Style.Frame({
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		Color = props.Color or Theme.Color.Secondary,
		Radius = math.ceil(height / 2),
	})
	local minimum = Instance.new("UISizeConstraint")
	minimum.MinSize = Vector2.new(height, 0)
	minimum.Parent = fillFrame
	fillFrame.Parent = track
	track.Parent = root

	local function apply(value: number, animate: boolean)
		local current = clampFill(value)
		local target = UDim2.fromScale(current, 1)
		if current <= 0 then
			fillFrame.Visible = false
			fillFrame.Size = target
			return
		end
		if animate and fillFrame.Visible then
			TweenUtil.Play(fillFrame, { Size = target }, Theme.Motion.Duration)
		else
			fillFrame.Size = target
		end
		fillFrame.Visible = true
	end

	local object: ProgressBar = {
		Instance = root,
		SetFill = function(_self: ProgressBar, value: number, animate: boolean?)
			apply(value, animate == true)
		end,
		SetColor = function(_self: ProgressBar, color: Color3)
			fillFrame.BackgroundColor3 = color
		end,
		SetLabel = function(_self: ProgressBar, text: string?)
			label.Text = text or ""
			label.Visible = text ~= nil
		end,
	}

	apply(props.Fill or 0, false)
	if props.Parent then
		root.Parent = props.Parent
	end
	return object
end

return ProgressBar
