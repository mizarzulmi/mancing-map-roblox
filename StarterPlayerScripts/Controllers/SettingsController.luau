--!strict
-- SettingsController: pengaturan pemain (volume musik & efek, mode grafis rendah, skala UI). Diterapkan
-- langsung di client, disimpan ke server (SaveSettings) dengan debounce. Panel "Pengaturan" dibuka dari HUD.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local Format = require(Shared.Util.Format)
local Strings = require(Shared.Config.Strings)
local Theme = require(Shared.Config.Theme)
local DataController = require(script.Parent.DataController)
local UIController = require(script.Parent.UIController)
local SoundController = require(script.Parent.SoundController)
local InputController = require(script.Parent.InputController)
local UI = script.Parent.Parent:WaitForChild("UI")
local Modal = require(UI:WaitForChild("Modal"))
local Slider = require(UI:WaitForChild("Slider"))
local Toggle = require(UI:WaitForChild("Toggle"))
local Style = require(UI:WaitForChild("Style"))

type PlayerSettings = Types.PlayerSettings

local SettingsController = {}

SettingsController.Changed = Signal.new() :: Signal.Signal<PlayerSettings>

local settings: PlayerSettings = { Music = 0.6, Sfx = 0.8, LowGfx = false, UiScale = 1 }
local saveToken = 0

local function apply()
	SoundController.SetVolumes(settings.Music, settings.Sfx)
	UIController.SetUserScale(settings.UiScale)
	SettingsController.Changed:Fire(settings)
end

local function scheduleSave()
	saveToken += 1
	local token = saveToken
	task.delay(0.6, function()
		if token == saveToken then
			Net.Invoke("SaveSettings", {
				Music = settings.Music,
				Sfx = settings.Sfx,
				LowGfx = settings.LowGfx,
				UiScale = settings.UiScale,
			})
		end
	end)
end

local function set(key: string, value: any)
	(settings :: any)[key] = value
	apply()
	scheduleSave()
end

function SettingsController.Get(): PlayerSettings
	return settings
end

function SettingsController.LowGfx(): boolean
	return settings.LowGfx
end

function SettingsController.Open()
	local modal = Modal.new({
		Title = Strings.SettingsTitle,
		Icon = "gear",
		MaxSize = Vector2.new(560, 520),
		Parent = UIController.Gui("Panel"),
		OnClose = function()
			UIController.ClosePanel()
		end,
	})
	local body = modal.Body
	Style.List(body, "Vertical", Theme.Space.L)
	Slider.new({
		Label = Strings.SettingMusic,
		Value = settings.Music,
		Min = 0,
		Max = 1,
		Step = 0.05,
		Format = function(v: number): string
			return Format.Percent(v)
		end,
		Parent = body,
		LayoutOrder = 1,
		OnChanged = function(v: number)
			set("Music", v)
		end,
	})
	Slider.new({
		Label = Strings.SettingSfx,
		Value = settings.Sfx,
		Min = 0,
		Max = 1,
		Step = 0.05,
		Format = function(v: number): string
			return Format.Percent(v)
		end,
		Parent = body,
		LayoutOrder = 2,
		OnChanged = function(v: number)
			set("Sfx", v)
		end,
	})
	Toggle.new({
		Label = Strings.SettingLowGfx,
		Value = settings.LowGfx,
		Parent = body,
		LayoutOrder = 3,
		OnChanged = function(v: boolean)
			set("LowGfx", v)
		end,
	})
	Slider.new({
		Label = Strings.SettingUiScale,
		Value = settings.UiScale,
		Min = 0.85,
		Max = 1.15,
		Step = 0.05,
		Format = function(v: number): string
			return Format.Percent(v)
		end,
		Parent = body,
		LayoutOrder = 4,
		OnChanged = function(v: number)
			set("UiScale", v)
		end,
	})
	Style.Label({
		Text = "Mode grafis rendah mematikan camar, kepiting, ikan, kunang-kunang, hujan partikel, dan perahu bergoyang. Pengaturan tersimpan otomatis.",
		TextSize = Theme.TextSize.Small,
		Color = Theme.Color.TextSecondary,
		Wrap = true,
		AutoSize = "Y",
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = 5,
		Parent = body,
	})
	UIController.OpenPanel({ Name = "Settings", Panel = modal :: any })
end

function SettingsController.Start()
	InputController.Hotkey:Connect(function(name)
		if name == "Settings" then
			if UIController.CurrentPanel() == "Settings" then
				UIController.ClosePanel()
			else
				SettingsController.Open()
			end
		end
	end)
	DataController.Observe({ "Settings" }, function(data)
		local s = data.Settings
		settings = { Music = s.Music, Sfx = s.Sfx, LowGfx = s.LowGfx, UiScale = s.UiScale }
		apply()
	end)
end

return SettingsController
