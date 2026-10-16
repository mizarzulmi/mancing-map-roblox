--!strict
-- FishingService (server-authoritative). State per pemain: Idle → Casting → Waiting → Bite → Reeling → Idle.
-- Client hanya mengirim niat (power + arah lempar, klik strike, klaim hasil minigame). Server menghitung titik
-- jatuh (raycast harus mengenai air), zona, syarat level, waktu tunggu, ikan saat gigitan, dan memvalidasi
-- durasi minigame (≥ minimum teoretis × 0,9). Satu loop Heartbeat memeriksa semua sesi (timeout, jarak, berenang).

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local Guard = require(Shared.Util.Guard)
local Formulas = require(Shared.Formulas)
local Balance = require(Shared.Config.Balance)
local Fish = require(Shared.Config.Fish)
local Rods = require(Shared.Config.Rods)
local Bait = require(Shared.Config.Bait)
local Zones = require(Shared.Config.Zones)
local Cosmetics = require(Shared.Config.Cosmetics)
local Strings = require(Shared.Config.Strings)
local RodModel = require(Shared.Models.RodModel)
local BobberModel = require(Shared.Models.BobberModel)
local DataService = require(script.Parent.DataService)
local InventoryService = require(script.Parent.InventoryService)
local WorldService = require(script.Parent.WorldService)
local LevelService = require(script.Parent.LevelService)

type FishItem = Types.FishItem
type FishSpecies = Types.FishSpecies
type RodDef = Types.RodDef
type BaitDef = Types.BaitDef
type RollContext = Types.RollContext

type SessionState = "Casting" | "Waiting" | "Bite" | "Reeling"

type Session = {
	Id: string,
	State: SessionState,
	Zone: string,
	LandPos: Vector3,
	CreatedAt: number,
	WaitEndsAt: number,
	BiteDeadline: number,
	ReelStartedAt: number,
	Rod: RodDef,
	BaitId: string,
	Roll: Formulas.RollResult?,
	Ctx: RollContext?,
	Hard: boolean,
	Bobber: Model?,
}

local FishingService = {}

FishingService.FishCaught = Signal.new() :: Signal.Signal<Player, FishItem, FishSpecies, RollContext>
FishingService.BaitUsed = Signal.new() :: Signal.Signal<Player, string>
FishingService.CastStarted = Signal.new() :: Signal.Signal<Player>

local F = Balance.Fishing
local rng = Random.new()
local sessions: { [Player]: Session } = {}
local lastCast: { [Player]: number } = {}
local bobberFolder: Folder? = nil

local function notify(player: Player, kind: string, text: string)
	Net.FireClient("Notify", player, kind, text)
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

local function equippedRodTool(player: Player): Tool?
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

local function isInWater(player: Player): boolean
	local humanoid = humanoidOf(player)
	if humanoid and humanoid:GetState() == Enum.HumanoidStateType.Swimming then
		return true
	end
	local root = rootOf(player)
	-- Permukaan laut di Y = 0; karakter yang berdiri di pasir/dek punya HumanoidRootPart jauh di atas ini.
	return root ~= nil and root.Position.Y < 1.2
end

local function currentRod(player: Player): RodDef
	local data = DataService.GetData(player)
	local rod = data and Rods.Get(data.EquippedRod)
	return rod or (Rods.Get(Balance.StartRod) :: RodDef)
end

local function destroySession(player: Player)
	local s = sessions[player]
	sessions[player] = nil
	if s and s.Bobber then
		s.Bobber:Destroy()
	end
	lastCast[player] = os.clock()
end

-- Membatalkan sesi aktif dan memberi tahu client.
function FishingService.Cancel(player: Player, reason: string)
	if sessions[player] == nil then
		return
	end
	destroySession(player)
	Net.FireClient("FishingEvent", player, "Cancelled", { Reason = reason })
end

function FishingService.IsFishing(player: Player): boolean
	return sessions[player] ~= nil
end

local function escape(player: Player, reason: string)
	destroySession(player)
	Net.FireClient("FishingEvent", player, "Escaped", { Reason = reason })
end

-- =========================================================================
-- Tool joran
-- =========================================================================

local function rodTools(player: Player): { Tool }
	local list: { Tool } = {}
	local containers: { Instance? } = { player:FindFirstChildOfClass("Backpack"), player.Character }
	for _, container in containers do
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") and child:GetAttribute("RodId") ~= nil then
					table.insert(list, child)
				end
			end
		end
	end
	return list
end

-- Membuat ulang Tool joran sesuai joran & skin yang dipakai (dipanggil saat spawn dan saat equip berubah).
function FishingService.RefreshRod(player: Player)
	local data = DataService.GetData(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if data == nil or backpack == nil then
		return
	end
	FishingService.Cancel(player, "Joran diganti")
	local wasEquipped = equippedRodTool(player) ~= nil
	for _, old in rodTools(player) do
		old:Destroy()
	end
	local rod = currentRod(player)
	local skin = Cosmetics.Get(data.Cosmetics.Equipped.RodSkin)
	local tool = RodModel.BuildTool(rod, skin)
	tool.Unequipped:Connect(function()
		if sessions[player] then
			FishingService.Cancel(player, Strings.FishingCancelled)
		end
	end)
	tool.Parent = backpack
	if wasEquipped then
		local humanoid = humanoidOf(player)
		if humanoid then
			humanoid:EquipTool(tool)
		end
	end
end

-- =========================================================================
-- Lempar
-- =========================================================================

local function raycastWater(origin: Vector3, landing: Vector3): RaycastResult?
	local exclude: { Instance } = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	local npcs = workspace:FindFirstChild("NPCs")
	if npcs then
		table.insert(exclude, npcs)
	end
	if bobberFolder then
		table.insert(exclude, bobberFolder)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	params.IgnoreWater = false
	local start = Vector3.new(landing.X, origin.Y + F.RaycastAbove, landing.Z)
	return workspace:Raycast(start, Vector3.new(0, -(F.RaycastAbove + F.RaycastDepth), 0), params)
end

local function spawnBobber(player: Player, s: Session)
	local data = DataService.GetData(player)
	local style = data and Cosmetics.Get(data.Cosmetics.Equipped.Bobber)
	local bobber = BobberModel.Build(style)
	bobber.Name = "Pelampung_" .. tostring(player.UserId)
	bobber:PivotTo(CFrame.new(s.LandPos.X, 0, s.LandPos.Z))
	bobber:SetAttribute("OwnerUserId", player.UserId)
	bobber:SetAttribute("SessionId", s.Id)
	CollectionService:AddTag(bobber, "Bobbing")
	bobber:SetAttribute("Amplitude", 0.06)
	local tool = equippedRodTool(player)
	local tip = tool and tool:FindFirstChild("TipAttachment", true)
	local lineAtt = bobber:FindFirstChild("LineAttachment", true)
	if tip and tip:IsA("Attachment") and lineAtt and lineAtt:IsA("Attachment") then
		local beam = Instance.new("Beam")
		beam.Name = "TaliPancing"
		beam.Attachment0 = tip
		beam.Attachment1 = lineAtt
		beam.Width0 = 0.035
		beam.Width1 = 0.035
		beam.CurveSize0 = 3
		beam.CurveSize1 = -1.5
		beam.Segments = 16
		beam.FaceCamera = true
		beam.LightInfluence = 0.6
		beam.Color = ColorSequence.new(Color3.fromRGB(240, 240, 235))
		beam.Transparency = NumberSequence.new(0.1)
		beam.Parent = lineAtt.Parent
	end
	bobber.Parent = bobberFolder
	s.Bobber = bobber
end

local function onCast(player: Player, power: unknown, dirX: unknown, dirZ: unknown)
	local p = Guard.Num(power, 0, 1)
	local dx = Guard.Num(dirX, -1.5, 1.5)
	local dz = Guard.Num(dirZ, -1.5, 1.5)
	if p == nil or dx == nil or dz == nil then
		Guard.Reject(player, "CastLine", "argumen tidak valid")
		return
	end
	local data = DataService.GetData(player)
	if data == nil then
		return
	end
	if sessions[player] then
		Guard.Reject(player, "CastLine", "sesi masih aktif")
		return
	end
	local nowClock = os.clock()
	if nowClock - (lastCast[player] or 0) < F.CastCooldown then
		notify(player, "Info", Strings.CastCooldown)
		return
	end
	local root = rootOf(player)
	local humanoid = humanoidOf(player)
	if root == nil or humanoid == nil or humanoid.Health <= 0 then
		return
	end
	if equippedRodTool(player) == nil then
		notify(player, "Warning", Strings.EquipRodFirst)
		return
	end
	if isInWater(player) then
		notify(player, "Warning", "Tidak bisa memancing sambil berenang.")
		return
	end
	if InventoryService.IsBagFull(player) then
		notify(player, "Warning", Strings.BagFull)
		return
	end
	local rod = currentRod(player)
	local landing = Formulas.CastLanding(root.Position, dx, dz, p, rod.CastDistance)
	local hit = raycastWater(root.Position, landing)
	if hit == nil or hit.Instance ~= workspace.Terrain or hit.Material ~= Enum.Material.Water then
		notify(player, "Warning", Strings.NotWater)
		lastCast[player] = nowClock
		return
	end
	local zoneId = WorldService.GetZoneAt(hit.Position)
	if zoneId == nil then
		notify(player, "Info", Strings.NoFishHere)
		lastCast[player] = nowClock
		return
	end
	local zone = Zones.Get(zoneId)
	if zone and data.Level < zone.Level then
		notify(player, "Warning", string.format(Strings.ZoneLocked, zone.Level, zone.Name))
		lastCast[player] = nowClock
		return
	end

	local baitId = data.EquippedBait
	if baitId ~= "" and (data.Bait[baitId] or 0) <= 0 then
		baitId = ""
	end
	local bait = if baitId ~= "" then Bait.Get(baitId) else nil
	local flight = Formulas.FlightTime(p)
	local wait = Formulas.WaitTime(rng, rod, bait, WorldService.GetWeather())
	local session: Session = {
		Id = HttpService:GenerateGUID(false),
		State = "Casting",
		Zone = zoneId,
		LandPos = hit.Position,
		CreatedAt = nowClock,
		WaitEndsAt = nowClock + flight + wait,
		BiteDeadline = 0,
		ReelStartedAt = 0,
		Rod = rod,
		BaitId = baitId,
		Roll = nil,
		Ctx = nil,
		Hard = false,
		Bobber = nil,
	}
	sessions[player] = session
	lastCast[player] = nowClock
	FishingService.CastStarted:Fire(player)
	Net.FireClient("FishingEvent", player, "Casted", {
		SessionId = session.Id,
		LandPos = hit.Position,
		FlightTime = flight,
		Zone = zoneId,
	})
	task.delay(flight, function()
		if sessions[player] == session and session.State == "Casting" then
			spawnBobber(player, session)
			session.State = "Waiting"
		end
	end)
end

-- =========================================================================
-- Gigitan, strike, minigame
-- =========================================================================

local function doBite(player: Player, s: Session)
	local data = DataService.GetData(player)
	if data == nil then
		FishingService.Cancel(player, Strings.FishingCancelled)
		return
	end
	local bait: BaitDef? = nil
	if s.BaitId ~= "" then
		if InventoryService.ConsumeBait(player, s.BaitId, 1) then
			bait = Bait.Get(s.BaitId)
			FishingService.BaitUsed:Fire(player, s.BaitId)
		else
			s.BaitId = ""
		end
	end
	local isNight = WorldService.IsNight()
	local weather = WorldService.GetWeather()
	local event = WorldService.GetEvent()
	local ctx: RollContext = {
		Zone = s.Zone,
		IsNight = isNight,
		Weather = weather,
		Event = event,
		Luck = Formulas.EffectiveLuck(s.Rod, bait, isNight, weather, event, s.Zone),
		MutationMul = Formulas.MutationMultiplier(s.Rod, bait, event),
	}
	local roll = Formulas.RollFish(rng, Fish.List, ctx)
	if roll == nil then
		FishingService.Cancel(player, Strings.NoFishHere)
		return
	end
	s.Roll = roll
	s.Ctx = ctx
	s.State = "Bite"
	s.BiteDeadline = os.clock() + F.BiteWindow + F.BiteTolerance
	Net.FireClient("FishingEvent", player, "Bite", { SessionId = s.Id, Window = F.BiteWindow })
end

local function onHook(player: Player, sessionId: unknown)
	local id = Guard.Str(sessionId, 64)
	local s = sessions[player]
	if id == nil or s == nil or s.Id ~= id then
		Guard.Reject(player, "HookFish", "sesi tidak valid")
		return
	end
	if s.State ~= "Bite" then
		-- Klik terlalu awal (sebelum gigitan) dianggap gagal: ikan kabur.
		if s.State == "Waiting" then
			escape(player, "Early")
		end
		return
	end
	if os.clock() > s.BiteDeadline then
		escape(player, "Late")
		return
	end
	local roll = s.Roll :: Formulas.RollResult
	s.State = "Reeling"
	s.ReelStartedAt = os.clock()
	s.Hard = Formulas.IsHard(roll.Weight, s.Rod)
	local params: Types.MinigameParams = {
		SessionId = s.Id,
		Seed = rng:NextInteger(1, 2147483646),
		Pattern = roll.Rarity,
		Hard = s.Hard,
		Control = s.Rod.Control,
		ReelSpeed = s.Rod.ReelSpeed,
		StartProgress = F.ReelStart,
		Gain = F.ReelGain,
		Loss = F.ReelLoss * (if s.Hard then F.HardLossMul else 1),
		TimeLimit = F.ReelTimeLimit,
	}
	Net.FireClient("FishingEvent", player, "Reel", params)
end

local function completeCatch(player: Player, s: Session)
	local data = DataService.GetData(player)
	local roll = s.Roll
	local ctx = s.Ctx
	if data == nil or roll == nil or ctx == nil then
		escape(player, "Invalid")
		return
	end
	local species = roll.Species
	local item: FishItem = {
		Uid = InventoryService.NewUid(),
		SpeciesId = species.Id,
		Weight = roll.Weight,
		Mutation = roll.Mutation,
		Zone = s.Zone,
		CaughtAt = os.time(),
		Locked = false,
	}
	local isNew = data.Fishdex[species.Id] == nil
	if not InventoryService.AddFish(player, item) then
		notify(player, "Warning", Strings.BagFull)
		escape(player, "BagFull")
		return
	end
	destroySession(player)

	data.Stats.TotalCaught += 1
	if item.Weight > data.Stats.HeaviestKg then
		data.Stats.HeaviestKg = item.Weight
	end
	if item.Mutation ~= "None" then
		data.Stats.MutatedCaught += 1
	end
	DataService.Replicate(player, "Stats")

	local xp = Formulas.CatchXP(roll.Rarity, roll.Mutation)
	LevelService.AddXP(player, xp, "catch")

	local info: Types.CatchInfo = {
		Fish = item,
		IsNew = isNew,
		Price = Formulas.SellPrice(species, item.Weight, item.Mutation, Formulas.EventPriceMul(WorldService.GetEvent())),
		XP = xp,
		Protected = species.Protected == true,
		Points = Formulas.ConservationPoints(species),
		Hard = s.Hard,
	}
	FishingService.FishCaught:Fire(player, item, species, ctx)
	Net.FireClient("FishingEvent", player, "Caught", info)
end

local function onReelFinished(player: Player, sessionId: unknown, success: unknown)
	local id = Guard.Str(sessionId, 64)
	local ok = Guard.Bool(success)
	local s = sessions[player]
	if id == nil or ok == nil or s == nil or s.Id ~= id or s.State ~= "Reeling" then
		Guard.Reject(player, "ReelFinished", "sesi tidak valid")
		return
	end
	if not ok then
		escape(player, "Lost")
		return
	end
	local valid, reason = Formulas.ValidateReelClaim(os.clock() - s.ReelStartedAt, s.Rod.ReelSpeed)
	if not valid then
		Guard.Reject(player, "ReelFinished", "klaim minigame " .. tostring(reason))
		escape(player, "Lost")
		return
	end
	completeCatch(player, s)
end

-- =========================================================================
-- Loop pemeriksa sesi (satu untuk semua pemain)
-- =========================================================================

local accumulator = 0

local function checkSessions()
	local t = os.clock()
	for player, s in sessions do
		local root = rootOf(player)
		local humanoid = humanoidOf(player)
		if root == nil or humanoid == nil or humanoid.Health <= 0 then
			FishingService.Cancel(player, Strings.FishingCancelled)
		elseif equippedRodTool(player) == nil then
			FishingService.Cancel(player, Strings.FishingCancelled)
		elseif isInWater(player) then
			FishingService.Cancel(player, "Kamu masuk air, memancing dibatalkan.")
		else
			local flat = Vector3.new(root.Position.X - s.LandPos.X, 0, root.Position.Z - s.LandPos.Z)
			if flat.Magnitude > s.Rod.CastDistance + F.CancelExtraDistance then
				FishingService.Cancel(player, "Kamu terlalu jauh dari pelampung.")
			elseif s.State == "Waiting" and t >= s.WaitEndsAt then
				doBite(player, s)
			elseif s.State == "Bite" and t > s.BiteDeadline then
				escape(player, "Late")
			elseif s.State == "Reeling" and t - s.ReelStartedAt > F.ReelTimeLimit + F.ReelTimeTolerance + 1 then
				escape(player, "Timeout")
			elseif (s.State == "Casting" or s.State == "Waiting") and t - s.CreatedAt > F.SessionMaxSeconds then
				FishingService.Cancel(player, Strings.FishingCancelled)
			end
		end
	end
end

local function onCharacterAdded(player: Player, character: Model)
	local data = DataService.WaitForData(player, 30)
	if data == nil or player.Character ~= character then
		return
	end
	character:WaitForChild("Humanoid", 10)
	FishingService.RefreshRod(player)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Died:Connect(function()
			FishingService.Cancel(player, Strings.FishingCancelled)
		end)
	end
end

local function bindPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

function FishingService.Init()
	local folder = Instance.new("Folder")
	folder.Name = "Bobbers"
	folder.Parent = workspace
	bobberFolder = folder
end

function FishingService.Start()
	Net.OnServerEvent("CastLine", onCast)
	Net.OnServerEvent("HookFish", onHook)
	Net.OnServerEvent("ReelFinished", onReelFinished)
	Net.OnServerEvent("CancelFishing", function(player: Player)
		FishingService.Cancel(player, Strings.FishingCancelled)
	end)

	Players.PlayerAdded:Connect(bindPlayer)
	for _, player in Players:GetPlayers() do
		bindPlayer(player)
	end
	-- Profil bisa siap setelah karakter muncul (mis. konflik sesi > 30 dtk): pasang joran saat itu juga.
	DataService.ProfileLoaded:Connect(function(player)
		if player.Character and #rodTools(player) == 0 then
			FishingService.RefreshRod(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		destroySession(player)
		lastCast[player] = nil
	end)

	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator >= 0.1 then
			accumulator = 0
			checkSessions()
		end
	end)
end

return FishingService
