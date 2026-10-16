--!strict
-- NPCController (client): kepala NPC menoleh ke pemain lokal saat dekat (Motor6D Neck, hanya visual lokal),
-- dan nelayan ambient sesekali "dapat ikan": ikan kecil melompat dari air ke ember bertag FishBucket
-- disertai cipratan. Mode grafis rendah mematikan efek ikan melompat.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Fish = require(Shared.Config.Fish)
local FishModel = require(Shared.Models.FishModel)
local SettingsController = require(script.Parent.SettingsController)
local SoundController = require(script.Parent.SoundController)

local NPCController = {}

local player = Players.LocalPlayer
local rng = Random.new()
local LOOK_RANGE = 18

type NeckState = { Motor: Motor6D, Base: CFrame, Yaw: number, Pitch: number }
local necks: { [Model]: NeckState } = {}

type Bucket = { Part: BasePart, NextAt: number }
local buckets: { [BasePart]: Bucket } = {}

local commons: { any } = {}
for _, s in Fish.List do
	if s.Rarity == "Common" or s.Rarity == "Uncommon" then
		table.insert(commons, s)
	end
end

local function addNpc(inst: Instance)
	if not inst:IsA("Model") or necks[inst] then
		return
	end
	task.spawn(function()
		local head = inst:WaitForChild("Head", 10)
		local neck = head and head:FindFirstChild("Neck")
		if neck and neck:IsA("Motor6D") then
			necks[inst] = { Motor = neck, Base = neck.C0, Yaw = 0, Pitch = 0 }
		end
	end)
end

local function addBucket(inst: Instance)
	if inst:IsA("BasePart") and buckets[inst] == nil then
		buckets[inst] = { Part = inst, NextAt = os.clock() + rng:NextNumber(8, 30) }
	end
end

local function splash(position: Vector3)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(1, 1, 1)
	p.CFrame = CFrame.new(position)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(220, 245, 255))
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	emitter.Lifetime = NumberRange.new(0.4, 0.7)
	emitter.Speed = NumberRange.new(6, 11)
	emitter.SpreadAngle = Vector2.new(35, 35)
	emitter.Acceleration = Vector3.new(0, -30, 0)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Rate = 0
	emitter.Parent = p
	p.Parent = workspace
	emitter:Emit(14)
	task.delay(1.2, function()
		p:Destroy()
	end)
end

-- Ikan melompat dari depan nelayan ke ember dalam lintasan parabola.
local function fishJump(bucket: BasePart)
	local npc = bucket.Parent
	local found: Vector3? = nil
	if npc then
		for _, child in npc:GetChildren() do
			if child:IsA("Model") and child:GetAttribute("NpcBobber") ~= nil then
				found = child:GetPivot().Position
			end
		end
	end
	local from: Vector3
	if found then
		from = found
	else
		local ahead = bucket.Position + bucket.CFrame.LookVector * 8
		from = Vector3.new(ahead.X, 0.2, ahead.Z)
	end
	local species = commons[rng:NextInteger(1, #commons)]
	if species == nil then
		return
	end
	local fish = FishModel.Build(species, { Length = 1.1 })
	fish.Parent = workspace
	splash(from)
	SoundController.Play("Splash", 0.15, from)
	local to = bucket.Position + Vector3.new(0, bucket.Size.Y * 0.5 + 0.3, 0)
	local duration = 0.85
	local start = os.clock()
	local conn: RBXScriptConnection? = nil
	conn = RunService.Heartbeat:Connect(function()
		local t = math.clamp((os.clock() - start) / duration, 0, 1)
		local pos = from:Lerp(to, t) + Vector3.new(0, math.sin(t * math.pi) * 5, 0)
		fish:PivotTo(CFrame.new(pos) * CFrame.Angles(t * math.pi * 2, t * math.pi, 0))
		if t >= 1 then
			if conn then
				conn:Disconnect()
			end
			splash(to)
			fish:Destroy()
		end
	end)
end

function NPCController.Start()
	for _, inst in CollectionService:GetTagged("NPC") do
		addNpc(inst)
	end
	CollectionService:GetInstanceAddedSignal("NPC"):Connect(addNpc)
	CollectionService:GetInstanceRemovedSignal("NPC"):Connect(function(inst)
		if inst:IsA("Model") then
			necks[inst] = nil
		end
	end)
	for _, inst in CollectionService:GetTagged("FishBucket") do
		addBucket(inst)
	end
	CollectionService:GetInstanceAddedSignal("FishBucket"):Connect(addBucket)
	CollectionService:GetInstanceRemovedSignal("FishBucket"):Connect(function(inst)
		if inst:IsA("BasePart") then
			buckets[inst] = nil
		end
	end)

	local accumulator = 0
	RunService.RenderStepped:Connect(function(dt: number)
		local character = player.Character
		local myHead = character and character:FindFirstChild("Head")
		local headPos = if myHead and myHead:IsA("BasePart") then myHead.Position else nil
		for model, state in necks do
			if model.Parent == nil or state.Motor.Parent == nil then
				necks[model] = nil
			else
				local head = state.Motor.Part1
				local torso = state.Motor.Part0
				local targetYaw, targetPitch = 0, 0
				if headPos and head and torso and (head.Position - headPos).Magnitude < LOOK_RANGE then
					local dir = torso.CFrame:VectorToObjectSpace((headPos - head.Position).Unit)
					targetYaw = math.clamp(math.atan2(-dir.X, -dir.Z), math.rad(-70), math.rad(70))
					targetPitch = math.clamp(math.asin(math.clamp(dir.Y, -1, 1)), math.rad(-25), math.rad(25))
				end
				local alpha = math.clamp(dt * 6, 0, 1)
				state.Yaw += (targetYaw - state.Yaw) * alpha
				state.Pitch += (targetPitch - state.Pitch) * alpha
				state.Motor.C0 = state.Base * CFrame.Angles(state.Pitch, state.Yaw, 0)
			end
		end

		accumulator += dt
		if accumulator < 0.5 then
			return
		end
		accumulator = 0
		if SettingsController.LowGfx() or headPos == nil then
			return
		end
		local now = os.clock()
		for part, b in buckets do
			if part.Parent == nil then
				buckets[part] = nil
			elseif now >= b.NextAt then
				b.NextAt = now + rng:NextNumber(25, 45)
				if (part.Position - (headPos :: Vector3)).Magnitude < 80 then
					fishJump(part)
				end
			end
		end
	end)
end

return NPCController
