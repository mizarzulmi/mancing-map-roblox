--!strict
-- MinigameController: minigame reel (GDD 4.1). Bar horizontal di bawah tengah layar. Zona tangkap (lebar =
-- Control joran) bergerak ke kanan saat input ditahan dan jatuh ke kiri saat dilepas, dengan inersia.
-- Ikon ikan bergerak sesuai pola rarity dari seed server: Common halus-lambat, Rare melesat, Epic acak,
-- Legendary cepat & berbalik mendadak, Mythic lonjakan. Progres mulai 30%, naik Gain × ReelSpeed saat ikan di
-- dalam zona, turun Loss di luar zona (sudah ×2 untuk mode Sulit dari server). 100% = berhasil; 0% atau
-- batas waktu = gagal. Hasil adalah klaim client yang divalidasi waktu oleh server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Balance = require(Shared.Config.Balance)
local Strings = require(Shared.Config.Strings)
local Theme = require(Shared.Config.Theme)
local Format = require(Shared.Util.Format)
local TweenUtil = require(Shared.Util.TweenUtil)
local UIController = require(script.Parent.UIController)
local InputController = require(script.Parent.InputController)
local SoundController = require(script.Parent.SoundController)
local UI = script.Parent.Parent:WaitForChild("UI")
local Style = require(UI:WaitForChild("Style"))
local Icon = require(UI:WaitForChild("Icon"))
local ProgressBar = require(UI:WaitForChild("ProgressBar"))

type MinigameParams = Types.MinigameParams

local MinigameController = {}

type Pattern = {
	RetargetMin: number,
	RetargetMax: number,
	Speed: number,
	Smooth: number,
	Jitter: number,
	Dart: boolean,
	Reverse: number,
	Surge: boolean,
}

local PATTERNS: { [string]: Pattern } = {
	Common = { RetargetMin = 1.6, RetargetMax = 2.6, Speed = 0.22, Smooth = 2.2, Jitter = 0, Dart = false, Reverse = 0, Surge = false },
	Uncommon = { RetargetMin = 1.0, RetargetMax = 1.8, Speed = 0.32, Smooth = 3, Jitter = 0.015, Dart = false, Reverse = 0, Surge = false },
	Rare = { RetargetMin = 0.7, RetargetMax = 1.3, Speed = 0.6, Smooth = 7, Jitter = 0, Dart = true, Reverse = 0, Surge = false },
	Epic = { RetargetMin = 0.25, RetargetMax = 0.6, Speed = 0.45, Smooth = 6, Jitter = 0.05, Dart = false, Reverse = 0, Surge = false },
	Legendary = { RetargetMin = 0.35, RetargetMax = 0.8, Speed = 0.75, Smooth = 9, Jitter = 0.03, Dart = false, Reverse = 0.35, Surge = false },
	Mythic = { RetargetMin = 0.5, RetargetMax = 1.1, Speed = 0.5, Smooth = 5, Jitter = 0.03, Dart = false, Reverse = 0.15, Surge = true },
}

local TRACK_WIDTH = 600
local ZONE_ACCEL = 3.2
local ZONE_GRAVITY = 2.9
local ZONE_MAX_SPEED = 1.7

local panel: Frame? = nil
local zoneFrame: Frame? = nil
local fishIcon: Frame? = nil
local trackStroke: UIStroke? = nil
local progressBar: ProgressBar.ProgressBar? = nil
local titleLabel: TextLabel? = nil
local hardChip: Frame? = nil
local timerLabel: TextLabel? = nil
local conn: RBXScriptConnection? = nil
local running = false
local finishCallback: ((boolean) -> ())? = nil

local function build()
	local root = UIController.Gui("Minigame")
	local p = Style.Panel({
		Name = "Minigame",
		Size = UDim2.fromOffset(TRACK_WIDTH + 2 * Theme.Space.L, 0),
		AutoSize = "Y",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -96),
		Parent = root,
	})
	Style.Padding(p, Theme.Space.M, Theme.Space.L, Theme.Space.M, Theme.Space.L)
	Style.List(p, "Vertical", Theme.Space.S, Enum.HorizontalAlignment.Center)

	local head = Style.Frame({ Size = UDim2.new(1, 0, 0, 28), LayoutOrder = 1, Parent = p })
	titleLabel = Style.Label({
		Text = "",
		Font = "Display",
		TextSize = Theme.TextSize.Heading,
		Size = UDim2.new(0.6, 0, 1, 0),
		Parent = head,
	})
	local chip = Style.Frame({
		Name = "HardChip",
		AutoSize = "XY",
		Color = Theme.Color.Danger,
		Radius = Theme.Radius.Chip,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.72, 0.5),
		Parent = head,
	})
	Style.Padding(chip, 2, Theme.Space.S, 2, Theme.Space.S)
	Style.Label({ Text = Strings.HardMode, Font = "Bold", TextSize = Theme.TextSize.Small, Color = Theme.Color.TextOnAccent, AutoSize = "XY", Parent = chip })
	chip.Visible = false
	hardChip = chip
	timerLabel = Style.Label({
		Text = "",
		Font = "Bold",
		TextSize = Theme.TextSize.Body,
		Color = Theme.Color.TextSecondary,
		Size = UDim2.new(0.25, 0, 1, 0),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		XAlign = Enum.TextXAlignment.Right,
		Parent = head,
	})

	local track = Style.Frame({
		Name = "Track",
		Size = UDim2.fromOffset(TRACK_WIDTH, 46),
		Color = Theme.Color.Inset,
		Radius = Theme.Radius.Card,
		LayoutOrder = 2,
		Clip = true,
		Parent = p,
	})
	trackStroke = Style.Stroke(track, 0.6, 2, Theme.Color.Secondary)
	local zone = Style.Frame({
		Name = "Zone",
		Size = UDim2.fromOffset(TRACK_WIDTH * 0.26, 46),
		Color = Theme.Color.Secondary,
		Transparency = 0.45,
		Radius = Theme.Radius.Chip,
		Parent = track,
	})
	Style.Stroke(zone, 0.1, 2, Theme.Color.TealText)
	zoneFrame = zone
	local fish = Icon.new("fish", 34, Theme.Color.Text)
	fish.AnchorPoint = Vector2.new(0.5, 0.5)
	fish.Position = UDim2.new(0, TRACK_WIDTH / 2, 0.5, 0)
	fish.ZIndex = 3
	fish.Parent = track
	fishIcon = fish

	progressBar = ProgressBar.new({
		Fill = Balance.Fishing.ReelStart,
		Color = Theme.Color.Primary,
		Height = 14,
		Size = UDim2.fromOffset(TRACK_WIDTH, 14),
		LayoutOrder = 3,
		Parent = p,
	})
	Style.Label({
		Text = Strings.MinigameHint,
		TextSize = Theme.TextSize.Small,
		Color = Theme.Color.TextSecondary,
		AutoSize = "XY",
		LayoutOrder = 4,
		Parent = p,
	})
	p.Visible = false
	panel = p
end

local function finish(success: boolean)
	if not running then
		return
	end
	running = false
	local c = conn
	if c then
		c:Disconnect()
		conn = nil
	end
	SoundController.SetLoop("Reel", false)
	InputController.SetHotkeysBlocked("minigame", false)
	local p = panel
	if p then
		p.Visible = false
	end
	local cb = finishCallback
	finishCallback = nil
	if cb then
		cb(success)
	end
end

-- Menghentikan minigame tanpa mengirim hasil (mis. sesi dibatalkan server).
function MinigameController.Stop()
	if running then
		finishCallback = nil
		finish(false)
	end
end

function MinigameController.IsRunning(): boolean
	return running
end

function MinigameController.Run(params: MinigameParams, onDone: (boolean) -> ())
	MinigameController.Stop()
	local p = panel
	local zone = zoneFrame
	local fish = fishIcon
	local bar = progressBar
	if p == nil or zone == nil or fish == nil or bar == nil then
		onDone(false)
		return
	end
	running = true
	finishCallback = onDone
	InputController.SetHotkeysBlocked("minigame", true)
	local pattern = PATTERNS[params.Pattern] or PATTERNS.Common
	local rng = Random.new(params.Seed)
	local width = math.clamp(params.Control, 0.12, 0.6)
	zone.Size = UDim2.fromOffset(TRACK_WIDTH * width, 46)
	if titleLabel then
		titleLabel.Text = Balance.RarityLabel[params.Pattern] or params.Pattern
		titleLabel.TextColor3 = Theme.Rarity[params.Pattern] or Theme.Color.Text
	end
	Icon.SetColor(fish, Theme.Rarity[params.Pattern] or Theme.Color.Text)
	if hardChip then
		hardChip.Visible = params.Hard
	end
	local progress = params.StartProgress
	bar:SetFill(progress, false)
	local zonePos = 0.5 - width / 2
	local zoneVel = 0
	local fishPos = 0.5
	local fishVel = 0
	local target = 0.5
	local retargetAt = 0
	local surgeUntil = 0
	local elapsed = 0
	local wasInside = false

	p.Visible = true
	local scale = p:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = p
	scale.Scale = if TweenUtil.ReducedMotion() then 1 else 0.94
	TweenUtil.Play(scale, { Scale = 1 }, Theme.Motion.Duration)

	conn = RunService.RenderStepped:Connect(function(dt: number)
		if not running then
			return
		end
		-- dt nyata untuk waktu & progres (selaras jam server); dt dibatasi hanya untuk integrasi gerak.
		local step = math.min(dt, 1 / 20)
		elapsed += dt

		-- Zona tangkap dengan inersia.
		local accel = if InputController.IsHolding() then ZONE_ACCEL else -ZONE_GRAVITY
		zoneVel = math.clamp(zoneVel + accel * step, -ZONE_MAX_SPEED, ZONE_MAX_SPEED)
		zonePos += zoneVel * step
		if zonePos < 0 then
			zonePos = 0
			zoneVel = -zoneVel * 0.25
		elseif zonePos > 1 - width then
			zonePos = 1 - width
			zoneVel = -zoneVel * 0.25
		end

		-- Pola gerak ikan dari seed.
		if elapsed >= retargetAt then
			retargetAt = elapsed + rng:NextNumber(pattern.RetargetMin, pattern.RetargetMax)
			local candidate = rng:NextNumber(0.06, 0.94)
			if pattern.Dart then
				local tries = 0
				while math.abs(candidate - fishPos) < 0.35 and tries < 6 do
					candidate = rng:NextNumber(0.06, 0.94)
					tries += 1
				end
			end
			if pattern.Reverse > 0 and rng:NextNumber() < pattern.Reverse then
				candidate = math.clamp(fishPos - (candidate - fishPos), 0.06, 0.94)
				fishVel = -fishVel
			end
			target = candidate
			if pattern.Surge and rng:NextNumber() < 0.35 then
				surgeUntil = elapsed + rng:NextNumber(0.5, 0.9)
			end
		end
		local speedMax = pattern.Speed * (if elapsed < surgeUntil then 2.8 else 1)
		local desired = math.clamp((target - fishPos) * pattern.Smooth, -speedMax, speedMax)
		fishVel += (desired - fishVel) * math.clamp(step * 8, 0, 1)
		fishPos = math.clamp(fishPos + fishVel * step + (rng:NextNumber() - 0.5) * pattern.Jitter, 0.02, 0.98)

		-- Progres.
		local inside = fishPos >= zonePos and fishPos <= zonePos + width
		if inside then
			progress += params.Gain * params.ReelSpeed * dt
		else
			progress -= params.Loss * dt
		end
		progress = math.clamp(progress, 0, 1)
		if inside ~= wasInside then
			wasInside = inside
			SoundController.SetLoop("Reel", inside)
			local stroke = trackStroke
			if stroke then
				stroke.Transparency = if inside then 0.05 else 0.6
			end
		end

		zone.Position = UDim2.fromOffset(zonePos * TRACK_WIDTH, 0)
		fish.Position = UDim2.new(0, fishPos * TRACK_WIDTH, 0.5, 0)
		fish.Rotation = math.clamp(fishVel * 25, -20, 20)
		bar:SetFill(progress, false)
		if timerLabel then
			timerLabel.Text = Format.Duration(math.max(0, params.TimeLimit - elapsed))
		end

		if progress >= 1 then
			finish(true)
		elseif progress <= 0 or elapsed >= params.TimeLimit then
			finish(false)
		end
	end)
end

function MinigameController.Init()
	build()
end

return MinigameController
