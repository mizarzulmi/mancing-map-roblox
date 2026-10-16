--!strict
-- FishingController (client): Idle → Charging → Casting → Waiting → Bite → Reeling → Idle.
-- Tahan (klik/Spasi/R2/tombol Lempar) mengisi bar tenaga ping-pong; lepas = kirim power + arah horizontal kamera.
-- Animasi busur pelampung lokal, 0–2 gigitan palsu (pelampung bergetar), tanda "!" saat gigitan asli
-- (klik dalam jendela), lalu minigame. Semua keputusan hasil ada di server (FishingService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Net = require(Shared.Net)
local TweenUtil = require(Shared.Util.TweenUtil)
local Format = require(Shared.Util.Format)
local Balance = require(Shared.Config.Balance)
local Strings = require(Shared.Config.Strings)
local Theme = require(Shared.Config.Theme)
local Cosmetics = require(Shared.Config.Cosmetics)
local BobberModel = require(Shared.Models.BobberModel)
local DataController = require(script.Parent.DataController)
local UIController = require(script.Parent.UIController)
local InputController = require(script.Parent.InputController)
local SoundController = require(script.Parent.SoundController)
local NotificationController = require(script.Parent.NotificationController)
local HUDController = require(script.Parent.HUDController)
local MinigameController = require(script.Parent.MinigameController)
local CatchPopupController = require(script.Parent.CatchPopupController)
local UI = script.Parent.Parent:WaitForChild("UI")
local Style = require(UI:WaitForChild("Style"))
local ProgressBar = require(UI:WaitForChild("ProgressBar"))

type State = "Idle" | "Charging" | "Casting" | "Waiting" | "Bite" | "Hooking" | "Reeling"

local FishingController = {}

local player = Players.LocalPlayer
local rng = Random.new()
local state: State = "Idle"
local sessionId: string? = nil
local chargeStart = 0
local power = 0
local castSentAt = 0
local fakeBites: { number } = {}
local waitStartedAt = 0
local biteMark: BillboardGui? = nil

local powerPanel: Frame? = nil
local powerBar: ProgressBar.ProgressBar? = nil
local powerText: TextLabel? = nil
local hintLabel: TextLabel? = nil

local POWER_PERIOD = 1.6

local function setState(s: State)
	state = s
	local label = if s == "Idle" or s == "Charging" then Strings.Cast
		elseif s == "Bite" then Strings.BiteNow
		elseif s == "Reeling" then "Tahan"
		else "Tunggu"
	HUDController.SetCastLabel(label)
	local hint = hintLabel
	if hint then
		hint.Visible = s == "Idle" and InputController.IsRodEquipped() and not UIController.IsPanelOpen()
	end
end

local function hintText(): string
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "Tahan tombol Lempar untuk mengisi tenaga, lepas untuk melempar"
	elseif UIController.IsGamepad() then
		return "Tahan R2 untuk mengisi tenaga, lepas untuk melempar"
	end
	return "Tahan klik kiri / Spasi untuk mengisi tenaga, lepas untuk melempar"
end

local function findBobber(id: string?): Model?
	if id == nil then
		return nil
	end
	local folder = workspace:FindFirstChild("Bobbers")
	if folder == nil then
		return nil
	end
	for _, m in folder:GetChildren() do
		if m:IsA("Model") and m:GetAttribute("SessionId") == id then
			return m
		end
	end
	return nil
end

local function clearBiteMark()
	local mark = biteMark
	biteMark = nil
	if mark then
		mark:Destroy()
	end
end

local function reset()
	sessionId = nil
	table.clear(fakeBites)
	clearBiteMark()
	local p = powerPanel
	if p then
		p.Visible = false
	end
	setState("Idle")
end

-- Pelampung dicelup lokal lewat atribut DipOffset (dibaca AmbientController).
local function dip(bobber: Model?, depth: number, duration: number)
	if bobber == nil then
		return
	end
	local start = os.clock()
	local conn: RBXScriptConnection? = nil
	conn = RunService.Heartbeat:Connect(function()
		local t = (os.clock() - start) / duration
		if t >= 1 or bobber.Parent == nil then
			bobber:SetAttribute("DipOffset", 0)
			if conn then
				conn:Disconnect()
			end
			return
		end
		bobber:SetAttribute("DipOffset", math.sin(t * math.pi * 3) * depth * (1 - t))
	end)
end

local function splashAt(position: Vector3, count: number)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(1, 1, 1)
	p.CFrame = CFrame.new(position)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(225, 245, 255))
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 0) })
	e.Lifetime = NumberRange.new(0.35, 0.6)
	e.Speed = NumberRange.new(5, 10)
	e.SpreadAngle = Vector2.new(40, 40)
	e.Acceleration = Vector3.new(0, -30, 0)
	e.EmissionDirection = Enum.NormalId.Top
	e.Rate = 0
	e.Parent = p
	p.Parent = workspace
	e:Emit(count)
	task.delay(1, function()
		p:Destroy()
	end)
end

local function tipPosition(): Vector3?
	local tool = InputController.RodTool()
	local tip = tool and tool:FindFirstChild("TipAttachment", true)
	if tip and tip:IsA("Attachment") then
		return tip.WorldPosition
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.Position + Vector3.new(0, 2, 0)
	end
	return nil
end

-- Busur pelampung lokal dari ujung joran ke titik jatuh.
local function animateCast(landPos: Vector3, flight: number)
	local from = tipPosition()
	if from == nil then
		return
	end
	local data = DataController.Get()
	local style = if data then Cosmetics.Get(data.Cosmetics.Equipped.Bobber) else nil
	local ghost = BobberModel.Build(style)
	ghost.Name = "PelampungTerbang"
	ghost.Parent = workspace
	local to = Vector3.new(landPos.X, 0, landPos.Z)
	local height = math.max(6, (to - from).Magnitude * 0.25)
	local start = os.clock()
	local conn: RBXScriptConnection? = nil
	conn = RunService.RenderStepped:Connect(function()
		local t = math.clamp((os.clock() - start) / math.max(flight, 0.05), 0, 1)
		local pos = from:Lerp(to, t) + Vector3.new(0, math.sin(t * math.pi) * height, 0)
		ghost:PivotTo(CFrame.new(pos))
		if t >= 1 then
			if conn then
				conn:Disconnect()
			end
			ghost:Destroy()
			splashAt(to, 16)
			SoundController.Play("Splash", 0.1, to)
		end
	end)
end

local function showBiteMark(bobber: Model?)
	clearBiteMark()
	if bobber == nil then
		return
	end
	local adornee = bobber.PrimaryPart
	if adornee == nil then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "TandaGigitan"
	gui.Size = UDim2.fromOffset(80, 80)
	gui.StudsOffset = Vector3.new(0, 3, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Adornee = adornee
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = Theme.Font.Display
	label.TextSize = 64
	label.Text = "!"
	label.TextColor3 = Theme.Color.Primary
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.World.NameStroke
	stroke.Thickness = 3
	stroke.Parent = label
	label.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
	biteMark = gui
	if not TweenUtil.ReducedMotion() then
		local scale = Instance.new("UIScale")
		scale.Scale = 0.4
		scale.Parent = label
		TweenUtil.Play(scale, { Scale = 1 }, 0.18, Enum.EasingStyle.Back)
	end
end

local function sendCast()
	local camera = workspace.CurrentCamera
	local dir = if camera then camera.CFrame.LookVector else Vector3.new(0, 0, 1)
	local flat = Vector3.new(dir.X, 0, dir.Z)
	if flat.Magnitude < 0.05 then
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		flat = if root and root:IsA("BasePart") then root.CFrame.LookVector * Vector3.new(1, 0, 1) else Vector3.new(0, 0, 1)
	end
	flat = flat.Unit
	setState("Casting")
	castSentAt = os.clock()
	Net.FireServer("CastLine", power, flat.X, flat.Z)
end

local function onCastBegan()
	if state == "Idle" then
		if not InputController.IsRodEquipped() then
			return
		end
		state = "Charging"
		chargeStart = os.clock()
		power = 0
		local p = powerPanel
		if p then
			p.Visible = true
		end
		if hintLabel then
			hintLabel.Visible = false
		end
	elseif state == "Bite" then
		state = "Hooking"
		clearBiteMark()
		Net.FireServer("HookFish", sessionId)
	elseif state == "Waiting" then
		-- Menarik sebelum gigitan asli: server memutuskan ikan kabur.
		Net.FireServer("HookFish", sessionId)
	end
end

local function onCastEnded()
	if state == "Charging" then
		local p = powerPanel
		if p then
			p.Visible = false
		end
		if InputController.IsFishingInputEnabled() then
			sendCast()
		else
			reset()
		end
	end
end

local function onFishingEvent(kind: string, data: any)
	if kind == "Casted" then
		sessionId = data.SessionId
		local flight = tonumber(data.FlightTime) or 0.6
		state = "Waiting"
		setState("Waiting")
		animateCast(data.LandPos, flight)
		waitStartedAt = os.clock() + flight
		table.clear(fakeBites)
		for _ = 1, rng:NextInteger(0, Balance.Fishing.FakeBitesMax) do
			table.insert(fakeBites, waitStartedAt + rng:NextNumber(1.2, 3.6))
		end
	elseif kind == "Bite" then
		if data.SessionId ~= sessionId then
			return
		end
		table.clear(fakeBites)
		setState("Bite")
		local bobber = findBobber(sessionId)
		dip(bobber, 0.6, 0.6)
		showBiteMark(bobber)
		if bobber and bobber.PrimaryPart then
			splashAt(bobber.PrimaryPart.Position, 10)
		end
		SoundController.Play("Bite")
	elseif kind == "Reel" then
		if data.SessionId ~= sessionId then
			return
		end
		clearBiteMark()
		setState("Reeling")
		local params = data :: Types.MinigameParams
		MinigameController.Run(params, function(success: boolean)
			if sessionId == params.SessionId then
				Net.FireServer("ReelFinished", params.SessionId, success)
				setState("Waiting")
			end
		end)
	elseif kind == "Caught" then
		MinigameController.Stop()
		reset()
		CatchPopupController.Show(data :: Types.CatchInfo)
	elseif kind == "Escaped" then
		MinigameController.Stop()
		local reason = if typeof(data) == "table" then data.Reason else nil
		reset()
		if reason == "Early" then
			NotificationController.Show("Terlalu cepat menarik! Ikannya kabur.", "Warning")
		elseif reason == "Lost" then
			NotificationController.Show(Strings.FishLost, "Warning")
		elseif reason == "Timeout" then
			NotificationController.Show("Kehabisan waktu, ikan lepas.", "Warning")
		elseif reason == "Late" then
			NotificationController.Show(Strings.FishEscaped, "Info")
		end
	elseif kind == "Cancelled" then
		MinigameController.Stop()
		reset()
		local reason = if typeof(data) == "table" then data.Reason else nil
		if type(reason) == "string" and reason ~= "" and reason ~= Strings.FishingCancelled then
			NotificationController.Show(reason, "Info")
		end
	end
end

local function build()
	local root = UIController.Gui("Minigame")
	local p = Style.Panel({
		Name = "PowerBar",
		Size = UDim2.fromOffset(380, 0),
		AutoSize = "Y",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -96),
		Parent = root,
	})
	Style.Padding(p, Theme.Space.S, Theme.Space.M, Theme.Space.S, Theme.Space.M)
	Style.List(p, "Vertical", Theme.Space.XS, Enum.HorizontalAlignment.Center)
	powerText = Style.Label({ Text = "Tenaga 0%", Font = "Bold", TextSize = Theme.TextSize.Body, AutoSize = "XY", LayoutOrder = 1, Parent = p })
	powerBar = ProgressBar.new({ Fill = 0, Color = Theme.Color.Primary, Height = 14, Size = UDim2.fromOffset(350, 14), LayoutOrder = 2, Parent = p })
	p.Visible = false
	powerPanel = p

	local hud = HUDController.Container("AboveSlots")
	hintLabel = Style.Label({
		Text = hintText(),
		TextSize = Theme.TextSize.Small,
		Color = Theme.Color.TextSecondary,
		AutoSize = "XY",
		LayoutOrder = 10,
		Parent = hud,
	})
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.World.NameStroke
	stroke.Thickness = 1.5
	stroke.Transparency = 0.3
	stroke.Parent = hintLabel
	if hintLabel then
		hintLabel.Visible = false
	end
end

function FishingController.State(): string
	return state
end

function FishingController.Init()
	build()
end

function FishingController.Start()
	InputController.CastBegan:Connect(onCastBegan)
	InputController.CastEnded:Connect(onCastEnded)
	InputController.CastCancelled:Connect(function()
		if state == "Charging" then
			reset()
		end
	end)
	Net.OnClientEvent("FishingEvent", onFishingEvent)
	UIController.PanelChanged:Connect(function(name)
		if name ~= nil and state == "Charging" then
			reset()
		elseif name ~= nil and (state == "Waiting" or state == "Bite") then
			-- Menu terbuka saat pelampung di air: gulung tali agar umpan tidak terbuang oleh gigitan yang tak bisa di-strike.
			Net.FireServer("CancelFishing")
			reset()
			NotificationController.Show("Tali digulung karena menu dibuka.", "Info")
		end
		setState(state)
	end)
	local function watch(character: Model)
		character.ChildRemoved:Connect(function(child)
			if child:IsA("Tool") and child:GetAttribute("RodId") ~= nil and state == "Charging" then
				reset()
			end
			setState(state)
		end)
		character.ChildAdded:Connect(function()
			if hintLabel then
				hintLabel.Text = hintText()
			end
			setState(state)
		end)
	end
	player.CharacterAdded:Connect(function(character)
		reset()
		watch(character)
	end)
	if player.Character then
		watch(player.Character)
	end

	RunService.RenderStepped:Connect(function()
		if state == "Charging" then
			local t = (os.clock() - chargeStart) % POWER_PERIOD / POWER_PERIOD * 2
			power = if t > 1 then 2 - t else t
			local bar = powerBar
			if bar then
				bar:SetFill(power, false)
			end
			if powerText then
				powerText.Text = "Tenaga " .. Format.Percent(power)
			end
		elseif state == "Casting" and os.clock() - castSentAt > 2 then
			-- Server menolak lemparan (pesan dikirim lewat Notify); kembali siap.
			reset()
		elseif state == "Waiting" and #fakeBites > 0 and os.clock() >= fakeBites[1] then
			table.remove(fakeBites, 1)
			dip(findBobber(sessionId), 0.25, 0.4)
		end
	end)
	setState("Idle")
end

return FishingController
