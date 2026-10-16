--!strict
-- NPCService: membangun NPC (R15) dari Config/NPCs di penanda BeachMap.NPCSpawns/NPCSpawn_<Id>.
-- Pakaian dari part (memakai CosmeticModels untuk caping/topi/kacamata), pose lewat Motor6D C0 (tanpa asset
-- animasi), nametag BillboardGui + tanda "!" (dinyalakan client), ProximityPrompt E jarak 10 tanpa tahan.
-- Penanda pose Idle/Fishing = posisi kaki; Sitting/Lounging = permukaan dudukan.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local Balance = require(Shared.Config.Balance)
local NPCs = require(Shared.Config.NPCs)
local Cosmetics = require(Shared.Config.Cosmetics)
local Rods = require(Shared.Config.Rods)
local Strings = require(Shared.Config.Strings)
local Theme = require(Shared.Config.Theme)
local CosmeticModels = require(Shared.Models.CosmeticModels)
local RodModel = require(Shared.Models.RodModel)
local BobberModel = require(Shared.Models.BobberModel)
local WorldService = require(script.Parent.WorldService)

type NpcDef = Types.NpcDef

local NPCService = {}

NPCService.Talked = Signal.new() :: Signal.Signal<Player, string>

local npcFolder: Folder? = nil
local spawnPositions: { [string]: Vector3 } = {}
local models: { [string]: Model } = {}

-- Pakaian yang memakai model kosmetik yang sudah ada.
local OUTFIT_COSMETIC: { [string]: string } = {
	Caping = "caping",
	TopiKapten = "topi_kapten",
	TopiRanger = "topi_ranger",
	Kacamata = "kacamata_hitam",
	Topi = "topi_jerami",
}

local function makePart(name: string, size: Vector3, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

local function weldTo(part: BasePart, target: BasePart, offset: CFrame)
	part.CFrame = target.CFrame * offset
	local w = Instance.new("Weld")
	w.Part0 = target
	w.Part1 = part
	w.C0 = offset
	w.Parent = part
end

-- Peci hitam: silinder pendek di atas kepala.
local function addPeci(model: Model, head: BasePart)
	local peci = makePart("Peci", Vector3.new(0.62, 1.12, 1.12), Color3.fromRGB(28, 28, 32), Enum.Material.Fabric)
	peci.Shape = Enum.PartType.Cylinder
	weldTo(peci, head, CFrame.new(0, head.Size.Y * 0.5 + 0.18, 0) * CFrame.Angles(0, 0, math.rad(90)))
	peci.Parent = model
end

-- Celemek: dua lembar kain tipis di depan badan atas & bawah.
local function addApron(model: Model, upper: BasePart, lower: BasePart)
	local color = Color3.fromRGB(236, 240, 244)
	local top = makePart("CelemekAtas", Vector3.new(upper.Size.X * 0.82, upper.Size.Y * 0.7, 0.08), color, Enum.Material.Fabric)
	weldTo(top, upper, CFrame.new(0, -upper.Size.Y * 0.1, -upper.Size.Z * 0.5 - 0.04))
	top.Parent = model
	local bottom = makePart("CelemekBawah", Vector3.new(lower.Size.X * 0.95, lower.Size.Y * 1.6, 0.08), color, Enum.Material.Fabric)
	weldTo(bottom, lower, CFrame.new(0, -lower.Size.Y * 0.45, -lower.Size.Z * 0.5 - 0.05))
	bottom.Parent = model
	local strap = makePart("TaliCelemek", Vector3.new(upper.Size.X * 1.02, 0.12, upper.Size.Z * 1.02), Color3.fromRGB(43, 179, 177), Enum.Material.Fabric)
	weldTo(strap, lower, CFrame.new(0, lower.Size.Y * 0.35, 0))
	strap.Parent = model
end

local function motor(model: Model, partName: string, motorName: string): Motor6D?
	local part = model:FindFirstChild(partName)
	local m = part and part:FindFirstChild(motorName)
	if m and m:IsA("Motor6D") then
		return m
	end
	return nil
end

local function rotateC0(model: Model, partName: string, motorName: string, rotation: CFrame)
	local m = motor(model, partName, motorName)
	if m then
		m.C0 = m.C0 * rotation
	end
end

local function legLength(model: Model): number
	local total = 0
	for _, name in { "RightUpperLeg", "RightLowerLeg", "RightFoot" } do
		local p = model:FindFirstChild(name)
		if p and p:IsA("BasePart") then
			total += p.Size.Y
		end
	end
	return if total > 0 then total else 2
end

-- Nelayan ambient: joran sebagai Tool yang di-equip (Grip R15 dari RodModel), pelampung diam di air di depannya,
-- tali Beam dari ujung joran, dan ember bertag FishBucket untuk efek "dapat ikan" di client.
-- Dipanggil setelah model berada di Workspace agar Humanoid:EquipTool membuat las genggaman.
local function addFishingGear(model: Model, def: NpcDef, root: BasePart, humanoid: Humanoid)
	local rodDef = Rods.Get("bambu")
	if rodDef == nil then
		return
	end
	local tool = RodModel.BuildTool(rodDef, nil)
	tool.CanBeDropped = false
	tool.Parent = model
	humanoid:EquipTool(tool)
	local facing = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	local floatPos = root.Position + (if facing.Magnitude > 0 then facing.Unit else Vector3.zAxis) * 9
	local bobber = BobberModel.Build(nil)
	bobber:PivotTo(CFrame.new(floatPos.X, 0, floatPos.Z))
	bobber:SetAttribute("NpcBobber", def.Id)
	bobber:SetAttribute("Amplitude", 0.08)
	CollectionService:AddTag(bobber, "Bobbing")
	bobber.Parent = model
	local tip = tool:FindFirstChild("TipAttachment", true)
	local lineAtt = bobber:FindFirstChild("LineAttachment", true)
	if tip and tip:IsA("Attachment") and lineAtt and lineAtt:IsA("Attachment") then
		local beam = Instance.new("Beam")
		beam.Attachment0 = tip
		beam.Attachment1 = lineAtt
		beam.Width0 = 0.04
		beam.Width1 = 0.04
		beam.CurveSize0 = 2
		beam.CurveSize1 = -1
		beam.Segments = 12
		beam.FaceCamera = true
		beam.Color = ColorSequence.new(Color3.fromRGB(235, 235, 230))
		beam.Transparency = NumberSequence.new(0.15)
		beam.Parent = lineAtt.Parent
	end
	local bucket = makePart("Ember", Vector3.new(1.3, 1.1, 1.1), Color3.fromRGB(43, 120, 170), Enum.Material.SmoothPlastic)
	bucket.Shape = Enum.PartType.Cylinder
	bucket.Anchored = true
	local side = root.CFrame.RightVector
	bucket.CFrame = CFrame.new(root.Position + side * 2.2 + Vector3.new(0, -root.Size.Y * 0.5 - legLength(model) + 0.55, 0))
		* CFrame.Angles(0, 0, math.rad(90))
	bucket:SetAttribute("NpcId", def.Id)
	CollectionService:AddTag(bucket, "FishBucket")
	bucket.Parent = model
end

local function applyPose(model: Model, def: NpcDef, root: BasePart)
	if def.Pose == "Fishing" then
		rotateC0(model, "RightUpperArm", "RightShoulder", CFrame.Angles(math.rad(75), 0, math.rad(-8)))
		rotateC0(model, "RightLowerArm", "RightElbow", CFrame.Angles(math.rad(20), 0, 0))
		rotateC0(model, "LeftUpperArm", "LeftShoulder", CFrame.Angles(math.rad(55), 0, math.rad(25)))
		rotateC0(model, "Head", "Neck", CFrame.Angles(math.rad(-10), 0, 0))
	elseif def.Pose == "Sitting" or def.Pose == "Lounging" then
		rotateC0(model, "RightUpperLeg", "RightHip", CFrame.Angles(math.rad(90), 0, math.rad(4)))
		rotateC0(model, "LeftUpperLeg", "LeftHip", CFrame.Angles(math.rad(90), 0, math.rad(-4)))
		rotateC0(model, "RightLowerLeg", "RightKnee", CFrame.Angles(math.rad(if def.Pose == "Sitting" then -85 else -12), 0, 0))
		rotateC0(model, "LeftLowerLeg", "LeftKnee", CFrame.Angles(math.rad(if def.Pose == "Sitting" then -85 else -12), 0, 0))
		rotateC0(model, "RightUpperArm", "RightShoulder", CFrame.Angles(math.rad(10), 0, math.rad(6)))
		rotateC0(model, "LeftUpperArm", "LeftShoulder", CFrame.Angles(math.rad(10), 0, math.rad(-6)))
	else
		-- Idle: sedikit variasi agar tidak kaku.
		rotateC0(model, "RightUpperArm", "RightShoulder", CFrame.Angles(math.rad(4), 0, math.rad(-3)))
		rotateC0(model, "LeftUpperArm", "LeftShoulder", CFrame.Angles(math.rad(4), 0, math.rad(3)))
	end
end

local function addNametag(model: Model, def: NpcDef, head: BasePart)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Nametag"
	gui.Size = UDim2.fromOffset(280, 72)
	gui.StudsOffset = Vector3.new(0, 2.4, 0)
	gui.MaxDistance = 70
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	gui.Adornee = head

	local mark = Instance.new("TextLabel")
	mark.Name = "QuestMark"
	mark.Size = UDim2.new(1, 0, 0, 36)
	mark.BackgroundTransparency = 1
	mark.FontFace = Theme.Font.Display
	mark.TextSize = 38
	mark.Text = "!"
	mark.TextColor3 = Theme.World.QuestMark
	mark.Visible = false
	local markStroke = Instance.new("UIStroke")
	markStroke.Color = Theme.World.NameStroke
	markStroke.Thickness = 2.5
	markStroke.Parent = mark
	mark.Parent = gui

	local label = Instance.new("TextLabel")
	label.Name = "NameLine"
	label.Size = UDim2.new(1, 0, 0, 30)
	label.Position = UDim2.fromOffset(0, 38)
	label.BackgroundTransparency = 1
	label.FontFace = Theme.Font.Bold
	label.TextSize = 22
	label.Text = if def.Title ~= "" then def.Name .. " · " .. def.Title else def.Name
	label.TextColor3 = Theme.World.NameText
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.World.NameStroke
	stroke.Thickness = 2
	stroke.Parent = label
	label.Parent = gui

	gui.Parent = head
end

local function addPrompt(model: Model, def: NpcDef, root: BasePart)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TalkPrompt"
	prompt.ActionText = Strings.Talk
	prompt.ObjectText = def.Name
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.MaxActivationDistance = Balance.NpcPromptDistance
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	prompt.Triggered:Connect(function(player: Player)
		NPCService.Talked:Fire(player, def.Id)
		Net.FireClient("OpenNpc", player, def.Id)
	end)
	prompt.Parent = root
end

local function buildNpc(def: NpcDef, spawnPart: BasePart)
	local desc = Instance.new("HumanoidDescription")
	desc.HeadColor = def.Skin
	desc.LeftArmColor = def.Skin
	desc.RightArmColor = def.Skin
	desc.TorsoColor = def.Shirt
	desc.LeftLegColor = def.Pants
	desc.RightLegColor = def.Pants

	local ok, result = pcall(function(): any
		return Players:CreateHumanoidModelFromDescriptionAsync(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok or typeof(result) ~= "Instance" or not (result :: Instance):IsA("Model") then
		warn("[NPCService] gagal membuat NPC " .. def.Id .. ": " .. tostring(result))
		return
	end
	local model = result :: Model
	model.Name = def.Name
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	local head = model:FindFirstChild("Head")
	if not (humanoid and root and root:IsA("BasePart") and head and head:IsA("BasePart")) then
		warn("[NPCService] rig NPC tidak lengkap: " .. def.Id)
		model:Destroy()
		return
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	root.Anchored = true

	-- Letakkan kaki (atau pinggul untuk pose duduk) tepat di penanda.
	local marker = spawnPart.CFrame
	local rootHalf = root.Size.Y * 0.5
	local yOffset: number
	if def.Pose == "Sitting" or def.Pose == "Lounging" then
		yOffset = rootHalf + 0.15
	else
		yOffset = humanoid.HipHeight + rootHalf
	end
	model:PivotTo(CFrame.new(marker.Position + Vector3.new(0, yOffset, 0)) * marker.Rotation)
	if def.Pose == "Lounging" then
		model:PivotTo(model:GetPivot() * CFrame.Angles(math.rad(-40), 0, 0))
	end

	for _, outfit in def.Outfit do
		local cosmeticId = OUTFIT_COSMETIC[outfit]
		if cosmeticId then
			local cosmetic = Cosmetics.Get(cosmeticId)
			local accessory = cosmetic and CosmeticModels.BuildAccessory(cosmetic)
			if accessory then
				humanoid:AddAccessory(accessory)
			end
		elseif outfit == "Peci" then
			addPeci(model, head)
		elseif outfit == "Celemek" then
			local upper = model:FindFirstChild("UpperTorso")
			local lower = model:FindFirstChild("LowerTorso")
			if upper and upper:IsA("BasePart") and lower and lower:IsA("BasePart") then
				addApron(model, upper, lower)
			end
		end
	end

	applyPose(model, def, root)
	addNametag(model, def, head)
	addPrompt(model, def, root)
	model:SetAttribute("NpcId", def.Id)
	model:SetAttribute("Role", def.Role)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	CollectionService:AddTag(model, "NPC")
	model.Parent = npcFolder
	models[def.Id] = model
	if def.Pose == "Fishing" then
		addFishingGear(model, def, root, humanoid)
	end
end

local function buildAll()
	if not WorldService.WaitForMap(180) then
		warn("[NPCService] map tidak siap; NPC tidak dibuat")
		return
	end
	local map = workspace:FindFirstChild("BeachMap")
	local spawns = map and map:FindFirstChild("NPCSpawns")
	if spawns == nil then
		warn("[NPCService] BeachMap.NPCSpawns tidak ditemukan")
		return
	end
	for _, def in NPCs.List do
		local marker = spawns:FindFirstChild("NPCSpawn_" .. def.Id)
		if marker and marker:IsA("BasePart") then
			spawnPositions[def.Id] = marker.Position
			task.spawn(buildNpc, def, marker)
		else
			warn("[NPCService] penanda NPCSpawn_" .. def.Id .. " tidak ditemukan")
		end
	end
end

-- Posisi NPC (dari penanda) untuk pemeriksaan jarak di server.
function NPCService.GetPosition(npcId: string): Vector3?
	return spawnPositions[npcId]
end

function NPCService.GetModel(npcId: string): Model?
	return models[npcId]
end

-- true bila karakter pemain berada dalam `range` stud dari NPC.
function NPCService.IsNear(player: Player, npcId: string, range: number?): boolean
	local pos: Vector3? = spawnPositions[npcId]
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if pos == nil or root == nil or not root:IsA("BasePart") then
		return false
	end
	return (root.Position - pos).Magnitude <= (range or Balance.NpcInteractRange)
end

function NPCService.Init()
	local folder = Instance.new("Folder")
	folder.Name = "NPCs"
	folder.Parent = workspace
	npcFolder = folder
end

function NPCService.Start()
	task.spawn(buildAll)
end

return NPCService
