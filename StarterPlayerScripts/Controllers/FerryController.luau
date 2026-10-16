--!strict
-- FerryController: kapal Nahkoda Jaka ↔ Awak Kapal. Konfirmasi biaya, lalu layar fade "Berlayar..." selama
-- server memindahkan karakter (PivotTo), dan fade keluar saat tiba.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Format = require(Shared.Util.Format)
local TweenUtil = require(Shared.Util.TweenUtil)
local Balance = require(Shared.Config.Balance)
local Strings = require(Shared.Config.Strings)
local Theme = require(Shared.Config.Theme)
local UIController = require(script.Parent.UIController)
local NotificationController = require(script.Parent.NotificationController)
local DialogController = require(script.Parent.DialogController)
local UI = script.Parent.Parent:WaitForChild("UI")
local Style = require(UI:WaitForChild("Style"))
local ConfirmDialog = require(UI:WaitForChild("ConfirmDialog"))

local FerryController = {}

local overlay: Frame? = nil
local overlayLabel: TextLabel? = nil

local function travel(destination: string)
	local ok, msg = Net.Invoke("FerryTravel", destination)
	if not ok and type(msg) == "string" then
		NotificationController.Show(msg, "Warning")
	end
end

function FerryController.Request(destination: string)
	if destination == "DeepSea" then
		ConfirmDialog.Show({
			Parent = UIController.Gui("Popup"),
			Title = Strings.FerryTitle,
			Body = string.format("Berlayar ke Platform Laut Dalam seharga %s koin? (butuh Lv %d)", Format.Coins(Balance.Ferry.Price), Balance.Ferry.Level),
			ConfirmText = "Berlayar",
			CancelText = Strings.Cancel,
			Variant = "Primary",
			OnConfirm = function()
				travel("DeepSea")
			end,
		})
	else
		travel("Shore")
	end
end

local function fade(visible: boolean, text: string?)
	local o = overlay
	if o == nil then
		return
	end
	if overlayLabel and text then
		overlayLabel.Text = text
	end
	if visible then
		o.Visible = true
		TweenUtil.Play(o, { BackgroundTransparency = 0 }, Balance.Ferry.FadeSeconds)
		if overlayLabel then
			TweenUtil.Play(overlayLabel, { TextTransparency = 0 }, Balance.Ferry.FadeSeconds)
		end
	else
		TweenUtil.Play(o, { BackgroundTransparency = 1 }, Balance.Ferry.FadeSeconds)
		if overlayLabel then
			TweenUtil.Play(overlayLabel, { TextTransparency = 1 }, Balance.Ferry.FadeSeconds * 0.6)
		end
		task.delay(Balance.Ferry.FadeSeconds, function()
			if o.BackgroundTransparency >= 0.99 then
				o.Visible = false
			end
		end)
	end
end

function FerryController.Init()
	local root = UIController.Gui("Overlay")
	local o = Style.Frame({ Name = "FerryFade", Size = UDim2.fromScale(1, 1), Color = Theme.Color.Panel, Parent = root })
	o.BackgroundTransparency = 1
	o.Visible = false
	overlayLabel = Style.Label({
		Text = Strings.FerryDeparting,
		Font = "Display",
		TextSize = Theme.TextSize.Hero,
		AutoSize = "XY",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Parent = o,
	})
	if overlayLabel then
		overlayLabel.TextTransparency = 1
	end
	overlay = o
end

function FerryController.Start()
	DialogController.Action:Connect(function(_npcId, action, arg)
		if action == "Ferry" and type(arg) == "string" then
			FerryController.Request(arg)
		end
	end)
	Net.OnClientEvent("FerryEvent", function(kind: unknown, data: unknown)
		local dest = if typeof(data) == "table" then (data :: any).Destination else nil
		if kind == "Depart" then
			fade(true, Strings.FerryDeparting)
		elseif kind == "Arrive" then
			fade(false)
			NotificationController.Show(if dest == "DeepSea" then Strings.FerryArrivedDeep else Strings.FerryArrivedShore, "Success")
		end
	end)
end

return FerryController
