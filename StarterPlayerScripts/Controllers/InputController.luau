--!strict
-- InputController: satu pintu input memancing & pintasan. Tahan klik kiri / Spasi / R2 / tombol sentuh
-- "Lempar" = CastBegan; lepas = CastEnded. Spasi dan R2 hanya "ditelan" saat memegang joran dan tidak ada
-- panel terbuka, sehingga lompat tetap normal. Pintasan menu: B Tas, F Fishdex, Q Quest, C Kosmetik,
-- G Pemain, P Pengaturan; angka 1 / L1 = pegang/simpan joran.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Signal = require(Shared.Util.Signal)
local UIController = require(script.Parent.UIController)

local InputController = {}

InputController.CastBegan = Signal.new() :: Signal.Signal<>
InputController.CastEnded = Signal.new() :: Signal.Signal<>
-- Tahanan dibatalkan (mis. panel terbuka) — BUKAN lepas untuk melempar.
InputController.CastCancelled = Signal.new() :: Signal.Signal<>
InputController.Hotkey = Signal.new() :: Signal.Signal<string>

local player = Players.LocalPlayer
local holding = false
local holdSource: string? = nil

local HOTKEYS: { [Enum.KeyCode]: string } = {
	[Enum.KeyCode.B] = "Bag",
	[Enum.KeyCode.F] = "Fishdex",
	[Enum.KeyCode.Q] = "Quest",
	[Enum.KeyCode.C] = "Cosmetic",
	[Enum.KeyCode.G] = "Players",
	[Enum.KeyCode.P] = "Settings",
}

-- Pemblokir tambahan (mis. minigame aktif tidak memblokir; dialog/panel memblokir).
local blockers: { [string]: boolean } = {}

function InputController.SetBlocked(reason: string, blocked: boolean)
	if blocked then
		blockers[reason] = true
	else
		(blockers :: any)[reason] = nil
	end
end

local function blocked(): boolean
	if UIController.IsPanelOpen() or UserInputService:GetFocusedTextBox() ~= nil then
		return true
	end
	return next(blockers) ~= nil
end

-- Pemblokir pintasan menu (mis. selama minigame agar tidak membuka panel tanpa sengaja).
local hotkeyBlockers: { [string]: boolean } = {}

function InputController.SetHotkeysBlocked(reason: string, isBlocked: boolean)
	if isBlocked then
		hotkeyBlockers[reason] = true
	else
		(hotkeyBlockers :: any)[reason] = nil
	end
end

function InputController.IsFishingInputEnabled(): boolean
	return not blocked()
end

function InputController.RodTool(): Tool?
	local character = player.Character
	if character == nil then
		return nil
	end
	for _, child in character:GetChildren() do
		if child:IsA("Tool") and child:GetAttribute("RodId") ~= nil then
			return child
		end
	end
	return nil
end

function InputController.IsRodEquipped(): boolean
	return InputController.RodTool() ~= nil
end

function InputController.IsHolding(): boolean
	return holding
end

local function begin(source: string)
	if holding or blocked() then
		return
	end
	holding = true
	holdSource = source
	InputController.CastBegan:Fire()
end

local function finish(source: string)
	if not holding or holdSource ~= source then
		return
	end
	holding = false
	holdSource = nil
	InputController.CastEnded:Fire()
end

-- Dipanggil tombol sentuh "Lempar/Tarik" di HUD.
function InputController.TouchHold(down: boolean)
	if down then
		begin("touch")
	else
		finish("touch")
	end
end

-- Pegang / simpan joran (dipakai tombol slot joran di HUD dan tombol 1).
function InputController.ToggleRod()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		return
	end
	if InputController.RodTool() then
		humanoid:UnequipTools()
		return
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack == nil then
		return
	end
	for _, child in backpack:GetChildren() do
		if child:IsA("Tool") and child:GetAttribute("RodId") ~= nil then
			humanoid:EquipTool(child)
			return
		end
	end
end

function InputController.Start()
	UserInputService.InputBegan:Connect(function(input, processed)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			if not processed and InputController.IsRodEquipped() then
				begin("mouse")
			end
			return
		end
		if processed or UserInputService:GetFocusedTextBox() ~= nil then
			return
		end
		if input.KeyCode == Enum.KeyCode.One or input.KeyCode == Enum.KeyCode.ButtonL1 then
			if not UIController.IsPanelOpen() then
				InputController.ToggleRod()
			end
			return
		end
		local hotkey = HOTKEYS[input.KeyCode]
		if hotkey and next(hotkeyBlockers) == nil then
			InputController.Hotkey:Fire(hotkey)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			finish("mouse")
		end
	end)

	-- Spasi / R2: prioritas tinggi; diteruskan (Pass) bila tidak memancing agar lompat tetap berfungsi.
	ContextActionService:BindActionAtPriority("PMN_CastKey", function(_, state, input)
		local source = if input.KeyCode == Enum.KeyCode.ButtonR2 then "r2" else "space"
		if state == Enum.UserInputState.Begin then
			if blocked() or not InputController.IsRodEquipped() then
				return Enum.ContextActionResult.Pass
			end
			begin(source)
			return Enum.ContextActionResult.Sink
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			if holding and holdSource == source then
				finish(source)
				return Enum.ContextActionResult.Sink
			end
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Space, Enum.KeyCode.ButtonR2)

	-- Membuka panel saat sedang menahan: batalkan tahanan (tanpa melempar) agar status tidak menggantung.
	UIController.PanelChanged:Connect(function(name)
		if name ~= nil and holding then
			holding = false
			holdSource = nil
			InputController.CastCancelled:Fire()
		end
	end)
end

return InputController
