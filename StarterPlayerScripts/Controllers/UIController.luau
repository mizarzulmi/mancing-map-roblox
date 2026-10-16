--!strict
-- UIController: membuat ScreenGui terpisah (HUD, Minigame, Panel, Popup, Overlay; ResetOnSpawn=false,
-- ScreenInsets=DeviceSafeInsets), satu UIScale global (0,75–1,25 × skala pengguna) memakai root berukuran
-- 1/skala, inset topbar untuk elemen atas, dan stack panel: hanya satu panel besar terbuka; Esc / ButtonB /
-- klik di luar panel menutup. Selama panel terbuka, input memancing nonaktif (dibaca InputController).

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Signal = require(Shared.Util.Signal)
local TweenUtil = require(Shared.Util.TweenUtil)
local Theme = require(Shared.Config.Theme)

-- Objek panel apa pun (Modal dari UI/Modal atau dialog) yang punya Root + Show/Hide/Destroy.
export type PanelObject = {
	Root: GuiObject,
	Show: (self: any) -> (),
	Hide: (self: any, instant: boolean?) -> (),
	Destroy: (self: any) -> (),
}

export type PanelSpec = {
	Name: string,
	Panel: PanelObject,
	OnClosed: (() -> ())?,
	-- false = tanpa scrim & tidak tertutup oleh klik luar (mis. kotak dialog NPC di bawah layar).
	Scrim: boolean?,
}

type GuiName = "HUD" | "Minigame" | "Panel" | "Popup" | "Overlay"

local UIController = {}

UIController.PanelChanged = Signal.new() :: Signal.Signal<string?>
UIController.ScaleChanged = Signal.new() :: Signal.Signal<number>
UIController.InsetChanged = Signal.new() :: Signal.Signal<number>

local player = Players.LocalPlayer
local guis: { [string]: ScreenGui } = {}
local roots: { [string]: Frame } = {}
local scrim: TextButton? = nil
local current: PanelSpec? = nil
local userScale = 1
local currentScale = 1
local topInset = 0
local hudVisible = true

local CLOSE_ACTION = "UIController_ClosePanel"

local DISPLAY: { [string]: number } = {
	HUD = Theme.DisplayOrder.HUD,
	Minigame = Theme.DisplayOrder.Minigame,
	Panel = Theme.DisplayOrder.Panel,
	Popup = Theme.DisplayOrder.Popup,
	Overlay = Theme.DisplayOrder.Overlay,
}

local function computeScale(): number
	local camera = workspace.CurrentCamera
	local vp = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local base = math.min(vp.X / 1280, vp.Y / 720)
	return math.clamp(base * userScale, 0.75, 1.25)
end

local function applyScale()
	local s = computeScale()
	currentScale = s
	for _, root in roots do
		root.Size = UDim2.fromScale(1 / s, 1 / s)
		local ui = root:FindFirstChildOfClass("UIScale")
		if ui then
			ui.Scale = s
		end
	end
	-- Inset topbar dalam koordinat desain (setelah skala).
	local inset = GuiService.TopbarInset
	topInset = math.ceil(inset.Max.Y / s)
	UIController.ScaleChanged:Fire(s)
	UIController.InsetChanged:Fire(topInset)
end

local function makeGui(name: GuiName)
	local gui = Instance.new("ScreenGui")
	gui.Name = "PMN_" .. name
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = DISPLAY[name]

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	local scale = Instance.new("UIScale")
	scale.Parent = root
	root.Parent = gui

	gui.Parent = player:WaitForChild("PlayerGui")
	guis[name] = gui
	roots[name] = root
end

local function bindClose()
	ContextActionService:BindActionAtPriority(CLOSE_ACTION, function(_, state)
		if state == Enum.UserInputState.Begin and current ~= nil then
			UIController.ClosePanel()
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Escape, Enum.KeyCode.ButtonB)
end

local function unbindClose()
	ContextActionService:UnbindAction(CLOSE_ACTION)
end

local function gamepadActive(): boolean
	local last = UserInputService:GetLastInputType()
	return last == Enum.UserInputType.Gamepad1
		or last == Enum.UserInputType.Gamepad2
		or last == Enum.UserInputType.Gamepad3
		or last == Enum.UserInputType.Gamepad4
end

-- Memilih tombol pertama yang bisa dipilih di dalam root untuk navigasi gamepad.
function UIController.FocusFirst(root: GuiObject)
	if not gamepadActive() then
		return
	end
	task.spawn(function()
		RunService.RenderStepped:Wait()
		for _, d in root:GetDescendants() do
			if d:IsA("GuiButton") and d.Selectable and d.Visible then
				GuiService.SelectedObject = d
				return
			end
		end
	end)
end

function UIController.Gui(name: GuiName): Frame
	return roots[name]
end

function UIController.ScreenGui(name: GuiName): ScreenGui
	return guis[name]
end

function UIController.Scale(): number
	return currentScale
end

function UIController.TopInset(): number
	return topInset
end

function UIController.IsTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

function UIController.IsGamepad(): boolean
	return gamepadActive()
end

function UIController.SetUserScale(s: number)
	userScale = math.clamp(s, 0.85, 1.15)
	applyScale()
end

function UIController.IsPanelOpen(): boolean
	return current ~= nil
end

function UIController.CurrentPanel(): string?
	return if current then current.Name else nil
end

function UIController.SetHudVisible(visible: boolean)
	hudVisible = visible
	local hud = guis.HUD
	if hud then
		hud.Enabled = visible
	end
end

function UIController.IsHudVisible(): boolean
	return hudVisible
end

local function setScrim(visible: boolean)
	local s = scrim
	if s == nil then
		return
	end
	if visible then
		s.Visible = true
		TweenUtil.Play(s, { BackgroundTransparency = Theme.Transparency.Scrim }, Theme.Motion.Duration)
	else
		TweenUtil.Play(s, { BackgroundTransparency = 1 }, Theme.Motion.Exit)
		task.delay(Theme.Motion.Exit, function()
			if current == nil and scrim then
				scrim.Visible = false
			end
		end)
	end
end

-- Menutup panel aktif (bila ada).
function UIController.ClosePanel()
	local spec = current
	if spec == nil then
		return
	end
	current = nil
	unbindClose()
	GuiService.SelectedObject = nil
	spec.Panel:Hide(false)
	task.delay(Theme.Motion.Exit + 0.05, function()
		spec.Panel:Destroy()
	end)
	setScrim(false)
	if spec.OnClosed then
		task.spawn(spec.OnClosed)
	end
	UIController.PanelChanged:Fire(nil)
end

-- Membuka panel baru; panel lain yang sedang terbuka ditutup lebih dulu.
function UIController.OpenPanel(spec: PanelSpec)
	if current then
		UIController.ClosePanel()
	end
	current = spec
	if spec.Scrim ~= false then
		setScrim(true)
	end
	spec.Panel:Show()
	bindClose()
	UIController.FocusFirst(spec.Panel.Root)
	UIController.PanelChanged:Fire(spec.Name)
end

function UIController.Init()
	-- Backpack bawaan disembunyikan; slot joran & umpan ada di HUD (angka 1 untuk joran).
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)
	for _, name in { "HUD", "Minigame", "Panel", "Popup", "Overlay" } do
		makeGui(name :: GuiName)
	end
	local s = Instance.new("TextButton")
	s.Name = "Scrim"
	s.Text = ""
	s.AutoButtonColor = false
	s.BackgroundColor3 = Theme.Color.Scrim
	s.BackgroundTransparency = 1
	s.Size = UDim2.fromScale(1, 1)
	s.Visible = false
	s.Selectable = false
	s.ZIndex = 0
	s.Activated:Connect(function()
		if current and current.Scrim ~= false then
			UIController.ClosePanel()
		end
	end)
	s.Parent = roots.Panel
	scrim = s
	applyScale()
end

function UIController.Start()
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(applyScale)
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		local cam = workspace.CurrentCamera
		if cam then
			cam:GetPropertyChangedSignal("ViewportSize"):Connect(applyScale)
			applyScale()
		end
	end)
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(applyScale)
end

return UIController
