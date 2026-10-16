--!strict
-- Toast: kartu notifikasi ringkas (radius kartu 10, bukan pill) — visual saja; antrean & timer diatur
-- NotificationController. Ikon per jenis di kiri (warna membawa makna bersama bentuk ikon, tidak sendirian),
-- teks di kanan (terbungkus maksimal ±420 px). Masuk: turun 8 px + fade 0,18 dtk. Dismiss: fade 0,12 dtk lalu
-- Destroy. Fade per properti (tanpa CanvasGroup) agar teks tetap tajam. Instan bila ReducedMotion.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Theme = require(Shared.Config.Theme)
local TweenUtil = require(Shared.Util.TweenUtil)
local Style = require(script.Parent.Style)
local Icon = require(script.Parent.Icon)

export type ToastKind = "Info" | "Success" | "Warning" | "Error" | "Reward" | "Achievement" | "Event"

export type ToastProps = {
	Text: string,
	Kind: ToastKind?,
	Parent: Instance,
	LayoutOrder: number?,
}

export type Toast = {
	Instance: Frame,
	Dismiss: (self: Toast) -> (),
}

type KindStyle = { Icon: Icon.IconName, Color: Color3? }

local KINDS: { [string]: KindStyle } = {
	Info = { Icon = "info", Color = Theme.Color.TealText },
	Success = { Icon = "check", Color = Theme.Color.Success },
	Warning = { Icon = "alert", Color = Theme.Color.DangerText },
	Error = { Icon = "close", Color = Theme.Color.DangerText },
	Reward = { Icon = "coin", Color = nil }, -- koin emas bawaan ikon
	Achievement = { Icon = "trophy", Color = Theme.Color.Primary },
	Event = { Icon = "star", Color = Theme.Color.TealText },
}

local ICON_SIZE = 26
local MAX_TEXT_WIDTH = 420
local SLIDE = Theme.Space.S

local Toast = {}

function Toast.new(props: ToastProps): Toast
	local kind = KINDS[props.Kind or "Info"] or KINDS.Info

	local root = Style.Frame({ Name = "Toast", Size = UDim2.fromOffset(0, 0), AutoSize = "XY" })
	if props.LayoutOrder then
		root.LayoutOrder = props.LayoutOrder
	end

	local card = Style.Frame({
		Name = "Card",
		Size = UDim2.fromOffset(0, 0),
		AutoSize = "XY",
		Color = Theme.Color.Panel,
		Transparency = Theme.Transparency.Panel,
		Radius = Theme.Radius.Card,
		Stroke = true,
	})
	Style.Shadow(card)
	Style.Padding(card, Theme.Space.M, Theme.Space.L)
	Style.List(card, "Horizontal", Theme.Space.M, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	local minimum = Instance.new("UISizeConstraint")
	minimum.MinSize = Vector2.new(0, Theme.Size.Touch)
	minimum.Parent = card

	local glyph = Icon.new(kind.Icon, ICON_SIZE, kind.Color)
	glyph.LayoutOrder = 1
	glyph.Parent = card

	local label = Style.Label({
		Name = "Text",
		Text = props.Text,
		TextSize = Theme.TextSize.Body,
		Wrap = true,
		AutoSize = "XY",
		LayoutOrder = 2,
	})
	local maxWidth = Instance.new("UISizeConstraint")
	maxWidth.MaxSize = Vector2.new(MAX_TEXT_WIDTH, math.huge)
	maxWidth.Parent = label
	label.Parent = card
	card.Parent = root

	local targets = Style.CollectFade(card)
	local dismissed = false

	-- Masuk: mulai transparan sedikit di atas posisi akhir.
	Style.Fade(targets, 1)
	card.Position = UDim2.fromOffset(0, -SLIDE)
	root.Parent = props.Parent
	TweenUtil.Play(card, { Position = UDim2.fromOffset(0, 0) }, Theme.Motion.Duration)
	Style.Fade(targets, 0, Theme.Motion.Duration)

	local object: Toast = {
		Instance = root,
		Dismiss = function(_self: Toast)
			if dismissed then
				return
			end
			dismissed = true
			local tween = Style.Fade(targets, 1, Theme.Motion.Exit)
			Style.After(tween, function()
				root:Destroy()
			end)
		end,
	}
	return object
end

return Toast
