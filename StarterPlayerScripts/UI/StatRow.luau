--!strict
-- StatRow: baris perbandingan stat "Label ........ Nilai  ▲ +0,30". Delta lebih baik = Theme.Color.Success +
-- segitiga atas (digambar), lebih buruk = DangerText + segitiga bawah, nol = teks sekunder tanpa segitiga.
-- Warna tidak berdiri sendiri: arah segitiga + tanda angka ikut menyampaikan makna. Slot delta berlebar tetap
-- agar kolom nilai sejajar antar-baris; tanpa delta, nilai rata kanan penuh.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Theme = require(Shared.Config.Theme)
local Format = require(Shared.Util.Format)
local Style = require(script.Parent.Style)
local Icon = require(script.Parent.Icon)

export type Better = "Higher" | "Lower"

export type StatRowProps = {
	Label: string,
	Value: string,
	Delta: number?,
	Better: Better?,
	DeltaText: string?,
	Parent: Instance?,
	LayoutOrder: number?,
}

export type StatRow = {
	Instance: Frame,
	SetValue: (self: StatRow, text: string) -> (),
	SetDelta: (self: StatRow, delta: number?, better: Better?, text: string?) -> (),
}

local HEIGHT = 32
local DELTA_SLOT = 96
local TRIANGLE = 12

local StatRow = {}

local function deltaText(delta: number): string
	local places = if delta % 1 == 0 then 0 elseif math.abs(delta) < 1 then 2 else 1
	return Format.Signed(delta, places)
end

function StatRow.new(props: StatRowProps): StatRow
	local root = Style.Frame({ Name = "Stat_" .. props.Label, Size = UDim2.new(1, 0, 0, HEIGHT) })
	if props.LayoutOrder then
		root.LayoutOrder = props.LayoutOrder
	end

	Style.Label({
		Name = "Label",
		Text = props.Label,
		Color = Theme.Color.TextSecondary,
		Size = UDim2.fromScale(0.55, 1),
		Parent = root,
	})
	local value = Style.Label({
		Name = "Value",
		Text = props.Value,
		Font = "Bold",
		XAlign = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0.5),
		Parent = root,
	})

	local slot = Style.Frame({
		Name = "Delta",
		Size = UDim2.new(0, DELTA_SLOT, 1, 0),
		Position = UDim2.fromScale(1, 0.5),
		AnchorPoint = Vector2.new(1, 0.5),
	})
	Style.List(slot, "Horizontal", Theme.Space.XS, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	local up = Icon.Triangle("Up", TRIANGLE, Theme.Color.Success)
	up.LayoutOrder = 1
	up.Parent = slot
	local down = Icon.Triangle("Down", TRIANGLE, Theme.Color.DangerText)
	down.LayoutOrder = 1
	down.Parent = slot
	local deltaLabel = Style.Label({
		Name = "Text",
		Text = "",
		Font = "Bold",
		AutoSize = "X",
		Size = UDim2.fromScale(0, 1),
		LayoutOrder = 2,
		Parent = slot,
	})
	slot.Parent = root

	local function layout(withDelta: boolean)
		slot.Visible = withDelta
		local reserve = if withDelta then DELTA_SLOT + Theme.Space.S else 0
		value.Position = UDim2.new(1, -reserve, 0.5, 0)
		value.Size = UDim2.new(0.45, -reserve, 1, 0)
	end

	local function setDelta(delta: number?, better: Better?, text: string?)
		if delta == nil and text == nil then
			layout(false)
			return
		end
		layout(true)
		local amount = delta or 0
		local lowerIsBetter = better == "Lower"
		local improved = if lowerIsBetter then amount < 0 else amount > 0
		local worse = amount ~= 0 and not improved
		local color = if improved then Theme.Color.Success elseif worse then Theme.Color.DangerText else Theme.Color.TextSecondary
		up.Visible = improved
		down.Visible = worse
		deltaLabel.TextColor3 = color
		deltaLabel.Text = text or deltaText(amount)
	end

	local object: StatRow = {
		Instance = root,
		SetValue = function(_self: StatRow, text: string)
			value.Text = text
		end,
		SetDelta = function(_self: StatRow, delta: number?, better: Better?, text: string?)
			setDelta(delta, better, text)
		end,
	}

	setDelta(props.Delta, props.Better, props.DeltaText)
	if props.Parent then
		root.Parent = props.Parent
	end
	return object
end

return StatRow
