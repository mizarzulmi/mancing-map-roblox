--!strict
-- AmbientController: kehidupan dunia di client dengan SATU loop Heartbeat.
-- Tag map: Bobbing (perahu/pinisi/pelampung bergoyang), Spin (lampu mercusuar), Flicker (lentera/api),
-- Rainbow (part kosmetik/mutasi Pelangi berganti warna). Makhluk lokal di sekitar BeachMap.AmbientPoints:
-- camar berputar, kepiting berjalan menyamping & kabur saat didekati, kawanan ikan kecil, kunang-kunang malam.
-- Mode grafis rendah mematikan semuanya (posisi dasar dipulihkan).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local SettingsController = require(script.Parent.SettingsController)
local DayNightController = require(script.Parent.DayNightController)

local AmbientController = {}

local player = Players.LocalPlayer
local rng = Random.new(20261016)

type Bob = { Inst: Instance, Base: CFrame, Amp: number, Speed: number, Phase: number, Tilt: number }
type Spinner = { Inst: Instance, Base: CFrame, Speed: number }
type Flicker = { Light: Light, Base: number, Phase: number }

local bobs: { [Instance]: Bob } = {}
local spinners: { [Instance]: Spinner } = {}
local flickers: { [Instance]: Flicker } = {}
type Rainbow = { H: number, S: number, V: number, Phase: number }
local rainbows: { [BasePart]: Rainbow } = {}

type Creature = {
	Kind: string,
	Model: Model,
	Center: Vector3,
	Radius: number,
	Angle: number,
	Speed: number,
	Height: number,
	Target: Vector3?,
	Pos: Vector3,
	Timer: number,
	Wings: { BasePart },
}

local creatures: { Creature } = {}
local creatureFolder: Folder? = nil
local fireflyParts: { BasePart } = {}
local pointsSeen: { [Instance]: boolean } = {}
local enabled = true
local ACTIVE_RANGE = 320

local function pivotOf(inst: Instance): CFrame?
	if inst:IsA("Model") then
		return inst:GetPivot()
	elseif inst:IsA("BasePart") then
		return inst.CFrame
	end
	return nil
end

local function setPivot(inst: Instance, cf: CFrame)
	if inst:IsA("Model") then
		inst:PivotTo(cf)
	elseif inst:IsA("BasePart") then
		inst.CFrame = cf
	end
end

local function numAttr(inst: Instance, name: string, default: number): number
	local v = inst:GetAttribute(name)
	return if type(v) == "number" then v else default
end

local function phaseFrom(cf: CFrame): number
	local p = cf.Position
	return (p.X * 0.137 + p.Z * 0.071) % (math.pi * 2)
end

local function addBob(inst: Instance)
	local base = pivotOf(inst)
	if base == nil or bobs[inst] then
		return
	end
	bobs[inst] = {
		Inst = inst,
		Base = base,
		Amp = numAttr(inst, "Amplitude", 0.3),
		Speed = numAttr(inst, "Speed", 1.1),
		Phase = numAttr(inst, "Phase", phaseFrom(base)),
		Tilt = math.rad(numAttr(inst, "Tilt", 2.5)),
	}
end

local function addSpin(inst: Instance)
	local base = pivotOf(inst)
	if base == nil or spinners[inst] then
		return
	end
	spinners[inst] = { Inst = inst, Base = base, Speed = math.rad(numAttr(inst, "SpinSpeed", 40)) }
end

local function addFlicker(inst: Instance)
	local lights: { Light } = {}
	if inst:IsA("Light") then
		table.insert(lights, inst)
	end
	for _, d in inst:GetDescendants() do
		if d:IsA("Light") then
			table.insert(lights, d)
		end
	end
	for _, light in lights do
		if flickers[light] == nil then
			flickers[light] = { Light = light, Base = light.Brightness, Phase = rng:NextNumber(0, 10) }
		end
	end
end

-- Pelangi: hanya hue yang berputar; saturasi & kecerahan asli dipertahankan agar mata/detail gelap tetap terbaca.
local function addRainbow(inst: Instance)
	if inst:IsA("BasePart") and rainbows[inst] == nil then
		local h, sat, val = inst.Color:ToHSV()
		rainbows[inst] = { H = h, S = sat, V = val, Phase = numAttr(inst, "RainbowPhase", rng:NextNumber()) }
	end
end

local function restoreAll()
	for inst, b in bobs do
		if inst.Parent then
			setPivot(inst, b.Base)
		end
	end
	for inst, s in spinners do
		if inst.Parent then
			setPivot(inst, s.Base)
		end
	end
	for _, f in flickers do
		if f.Light.Parent then
			f.Light.Brightness = f.Base
		end
	end
end

-- ===================== Makhluk lokal =====================

local function part(size: Vector3, color: Color3, shape: Enum.PartType?, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

local function makeGull(): (Model, { BasePart })
	local m = Instance.new("Model")
	m.Name = "Camar"
	local body = part(Vector3.new(0.9, 0.8, 1.9), Color3.fromRGB(245, 246, 248), Enum.PartType.Ball)
	body.Name = "Body"
	body.Parent = m
	local head = part(Vector3.new(0.65, 0.65, 0.65), Color3.fromRGB(250, 250, 252), Enum.PartType.Ball)
	head.CFrame = body.CFrame * CFrame.new(0, 0.3, -0.95)
	head.Parent = m
	local beak = Instance.new("WedgePart")
	beak.Anchored = true
	beak.CanCollide = false
	beak.CanQuery = false
	beak.CanTouch = false
	beak.CastShadow = false
	beak.Size = Vector3.new(0.18, 0.18, 0.5)
	beak.Color = Color3.fromRGB(246, 178, 60)
	beak.CFrame = head.CFrame * CFrame.new(0, -0.05, -0.45) * CFrame.Angles(0, math.rad(180), 0)
	beak.Parent = m
	local wings: { BasePart } = {}
	for _, side in { -1, 1 } do
		local wing = part(Vector3.new(2.2, 0.08, 0.8), Color3.fromRGB(196, 204, 212))
		wing.Name = if side < 0 then "WingL" else "WingR"
		wing.CFrame = body.CFrame * CFrame.new(side * 1.2, 0.15, 0)
		wing.Parent = m
		local tip = part(Vector3.new(0.7, 0.08, 0.7), Color3.fromRGB(60, 64, 70))
		tip.CFrame = wing.CFrame * CFrame.new(side * 1.3, 0, 0)
		tip.Parent = wing
		table.insert(wings, wing)
	end
	m.PrimaryPart = body
	return m, wings
end

local function makeCrab(): Model
	local m = Instance.new("Model")
	m.Name = "Kepiting"
	local color = Color3.fromRGB(226, 96, 58)
	local body = part(Vector3.new(1.3, 0.45, 0.95), color, Enum.PartType.Ball)
	body.Name = "Body"
	body.Parent = m
	for _, side in { -1, 1 } do
		local claw = part(Vector3.new(0.42, 0.32, 0.42), color, Enum.PartType.Ball)
		claw.CFrame = body.CFrame * CFrame.new(side * 0.75, 0.05, -0.55)
		claw.Parent = m
		local eye = part(Vector3.new(0.14, 0.14, 0.14), Color3.fromRGB(20, 20, 24), Enum.PartType.Ball)
		eye.CFrame = body.CFrame * CFrame.new(side * 0.18, 0.3, -0.35)
		eye.Parent = m
		for i = -1, 1 do
			local leg = part(Vector3.new(0.5, 0.08, 0.08), color)
			leg.CFrame = body.CFrame * CFrame.new(side * 0.7, -0.15, i * 0.25) * CFrame.Angles(0, 0, side * math.rad(-25))
			leg.Parent = m
		end
	end
	m.PrimaryPart = body
	return m
end

local function makeSmallFish(): Model
	local m = Instance.new("Model")
	m.Name = "IkanKecil"
	local tint = if rng:NextNumber() < 0.5 then Color3.fromRGB(110, 170, 205) else Color3.fromRGB(240, 196, 92)
	local body = part(Vector3.new(0.35, 0.5, 1.1), tint, Enum.PartType.Ball)
	body.Name = "Body"
	body.Parent = m
	local tail = Instance.new("WedgePart")
	tail.Anchored = true
	tail.CanCollide = false
	tail.CanQuery = false
	tail.CanTouch = false
	tail.CastShadow = false
	tail.Size = Vector3.new(0.06, 0.5, 0.4)
	tail.Color = tint
	tail.CFrame = body.CFrame * CFrame.new(0, 0, 0.7)
	tail.Parent = m
	m.PrimaryPart = body
	return m
end

local function groundY(x: number, z: number, fallback: number): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	local hit = workspace:Raycast(Vector3.new(x, fallback + 30, z), Vector3.new(0, -80, 0), params)
	return if hit then hit.Position.Y else fallback
end

local function spawnFor(point: BasePart)
	if pointsSeen[point] or creatureFolder == nil then
		return
	end
	pointsSeen[point] = true
	local kind = point:GetAttribute("Kind")
	local radius = numAttr(point, "Radius", 20)
	local center = point.Position
	if kind == "Seagulls" then
		for _ = 1, 3 do
			local model, wings = makeGull()
			model.Parent = creatureFolder
			table.insert(creatures, {
				Kind = "Gull",
				Model = model,
				Center = center,
				Radius = radius * rng:NextNumber(0.6, 1),
				Angle = rng:NextNumber(0, math.pi * 2),
				Speed = rng:NextNumber(0.18, 0.3) * (if rng:NextNumber() < 0.5 then -1 else 1),
				Height = rng:NextNumber(-6, 6),
				Target = nil,
				Pos = center,
				Timer = 0,
				Wings = wings,
			})
		end
	elseif kind == "Crabs" then
		for _ = 1, 4 do
			local model = makeCrab()
			local start = center + Vector3.new(rng:NextNumber(-radius, radius), 0, rng:NextNumber(-radius, radius))
			local pos = Vector3.new(start.X, groundY(start.X, start.Z, center.Y) + 0.2, start.Z)
			model:PivotTo(CFrame.new(pos))
			model.Parent = creatureFolder
			table.insert(creatures, {
				Kind = "Crab",
				Model = model,
				Center = center,
				Radius = radius,
				Angle = 0,
				Speed = 3,
				Height = 0,
				Target = nil,
				Pos = pos,
				Timer = rng:NextNumber(0, 2),
				Wings = {},
			})
		end
	elseif kind == "FishSchool" then
		for _ = 1, 7 do
			local model = makeSmallFish()
			model.Parent = creatureFolder
			table.insert(creatures, {
				Kind = "Fish",
				Model = model,
				Center = center,
				Radius = radius * rng:NextNumber(0.4, 1),
				Angle = rng:NextNumber(0, math.pi * 2),
				Speed = rng:NextNumber(0.5, 0.8),
				Height = rng:NextNumber(-1.5, 1.5),
				Target = nil,
				Pos = center,
				Timer = 0,
				Wings = {},
			})
		end
	elseif kind == "Fireflies" then
		local holder = part(Vector3.new(radius * 2, 6, radius * 2), Color3.new(1, 1, 1))
		holder.Transparency = 1
		holder.CFrame = CFrame.new(center + Vector3.new(0, 3, 0))
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		emitter.Color = ColorSequence.new(Color3.fromRGB(220, 255, 120), Color3.fromRGB(255, 240, 150))
		emitter.LightEmission = 1
		emitter.Size = NumberSequence.new(0.35)
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.3, 0.1),
			NumberSequenceKeypoint.new(0.7, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		})
		emitter.Lifetime = NumberRange.new(3, 6)
		emitter.Rate = 10
		emitter.Speed = NumberRange.new(0.3, 1.2)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Shape = Enum.ParticleEmitterShape.Box
		emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		emitter.Enabled = DayNightController.IsNight()
		emitter.Parent = holder
		holder.Parent = creatureFolder
		table.insert(fireflyParts, holder)
	end
end

local function clearCreatures()
	for _, c in creatures do
		c.Model:Destroy()
	end
	table.clear(creatures)
	for _, p in fireflyParts do
		p:Destroy()
	end
	table.clear(fireflyParts)
	table.clear(pointsSeen)
end

local function scanPoints()
	local map = workspace:FindFirstChild("BeachMap")
	local folder = map and map:FindFirstChild("AmbientPoints")
	if folder == nil then
		return
	end
	for _, child in folder:GetChildren() do
		if child:IsA("BasePart") then
			spawnFor(child)
		end
	end
end

local function updateCreature(c: Creature, t: number, dt: number, camPos: Vector3, playerPos: Vector3?)
	if (c.Center - camPos).Magnitude > ACTIVE_RANGE then
		return
	end
	if c.Kind == "Gull" then
		c.Angle += c.Speed * dt
		local pos = c.Center + Vector3.new(math.cos(c.Angle) * c.Radius, c.Height + math.sin(t * 0.5 + c.Angle) * 2, math.sin(c.Angle) * c.Radius)
		local ahead = c.Center + Vector3.new(math.cos(c.Angle + 0.1 * math.sign(c.Speed)) * c.Radius, pos.Y - c.Center.Y, math.sin(c.Angle + 0.1 * math.sign(c.Speed)) * c.Radius)
		local bank = CFrame.Angles(0, 0, -0.35 * math.sign(c.Speed))
		c.Model:PivotTo(CFrame.lookAt(pos, ahead) * bank)
		local flap = math.sin(t * 7 + c.Angle * 3) * 0.5
		local body = c.Model.PrimaryPart
		if body then
			for i, wing in c.Wings do
				local side = if i == 1 then -1 else 1
				wing.CFrame = body.CFrame * CFrame.new(side * 0.5, 0.15, 0) * CFrame.Angles(0, 0, side * flap) * CFrame.new(side * 0.7, 0, 0)
			end
		end
	elseif c.Kind == "Fish" then
		c.Angle += c.Speed * dt
		local pos = c.Center + Vector3.new(math.cos(c.Angle) * c.Radius, c.Height + math.sin(t * 1.3 + c.Angle) * 0.6, math.sin(c.Angle) * c.Radius)
		local ahead = c.Center + Vector3.new(math.cos(c.Angle + 0.15) * c.Radius, pos.Y - c.Center.Y, math.sin(c.Angle + 0.15) * c.Radius)
		c.Model:PivotTo(CFrame.lookAt(pos, ahead) * CFrame.Angles(0, math.sin(t * 9 + c.Angle) * 0.25, 0))
	elseif c.Kind == "Crab" then
		c.Timer -= dt
		local fleeing = playerPos ~= nil and (playerPos - c.Pos).Magnitude < 8
		if fleeing then
			local away = (c.Pos - (playerPos :: Vector3)) * Vector3.new(1, 0, 1)
			if away.Magnitude < 0.1 then
				away = Vector3.new(1, 0, 0)
			end
			local dest = c.Pos + away.Unit * 6
			local fromCenter = (dest - c.Center) * Vector3.new(1, 0, 1)
			if fromCenter.Magnitude > c.Radius * 1.4 then
				dest = c.Center + fromCenter.Unit * c.Radius * 1.4
			end
			c.Target = dest
			c.Speed = 9
		elseif c.Target == nil and c.Timer <= 0 then
			c.Target = c.Center + Vector3.new(rng:NextNumber(-c.Radius, c.Radius), 0, rng:NextNumber(-c.Radius, c.Radius))
			c.Speed = 2.5
		end
		local target = c.Target
		if target then
			local flat = (target - c.Pos) * Vector3.new(1, 0, 1)
			if flat.Magnitude < 0.3 then
				c.Target = nil
				c.Timer = rng:NextNumber(1.5, 4)
			else
				local step = flat.Unit * math.min(flat.Magnitude, c.Speed * dt)
				local nx, nz = c.Pos.X + step.X, c.Pos.Z + step.Z
				local ny = groundY(nx, nz, c.Pos.Y) + 0.2
				c.Pos = Vector3.new(nx, ny, nz)
				-- Kepiting berjalan menyamping: badan tegak lurus arah gerak, kaki bergoyang.
				local facing = Vector3.new(-flat.Unit.Z, 0, flat.Unit.X)
				c.Model:PivotTo(CFrame.lookAt(c.Pos, c.Pos + facing) * CFrame.Angles(0, 0, math.sin(t * 16) * 0.08))
			end
		end
	end
end

local function setEnabled(on: boolean)
	if on == enabled then
		return
	end
	enabled = on
	if on then
		for inst, b in bobs do
			b.Base = pivotOf(inst) or b.Base
		end
		scanPoints()
	else
		restoreAll()
		clearCreatures()
	end
end

function AmbientController.Init()
	local folder = Instance.new("Folder")
	folder.Name = "PMN_AmbientLokal"
	folder.Parent = workspace
	creatureFolder = folder
end

function AmbientController.Start()
	local function bindTag(tag: string, add: (Instance) -> ())
		for _, inst in CollectionService:GetTagged(tag) do
			add(inst)
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(add)
	end
	bindTag("Bobbing", addBob)
	bindTag("Spin", addSpin)
	bindTag("Flicker", addFlicker)
	bindTag("Rainbow", addRainbow)
	CollectionService:GetInstanceRemovedSignal("Bobbing"):Connect(function(inst)
		bobs[inst] = nil
	end)
	CollectionService:GetInstanceRemovedSignal("Spin"):Connect(function(inst)
		spinners[inst] = nil
	end)
	CollectionService:GetInstanceRemovedSignal("Rainbow"):Connect(function(inst)
		if inst:IsA("BasePart") then
			rainbows[inst] = nil
		end
	end)

	DayNightController.NightChanged:Connect(function(isNight)
		for _, p in fireflyParts do
			local emitter = p:FindFirstChildOfClass("ParticleEmitter")
			if emitter then
				emitter.Enabled = isNight
			end
		end
	end)

	enabled = not SettingsController.LowGfx()
	SettingsController.Changed:Connect(function()
		setEnabled(not SettingsController.LowGfx())
	end)

	-- Titik ambient bisa muncul belakangan (streaming / map dibangun saat runtime).
	task.spawn(function()
		local map = workspace:WaitForChild("BeachMap", 180)
		local folder = map and map:WaitForChild("AmbientPoints", 30)
		if folder == nil then
			return
		end
		if enabled then
			scanPoints()
		end
		folder.ChildAdded:Connect(function(child)
			if enabled and child:IsA("BasePart") then
				spawnFor(child)
			end
		end)
	end)

	RunService.Heartbeat:Connect(function(dt)
		if not enabled then
			return
		end
		local t = os.clock()
		local camera = workspace.CurrentCamera
		local camPos = if camera then camera.CFrame.Position else Vector3.zero
		for inst, b in bobs do
			if inst.Parent == nil then
				bobs[inst] = nil
			elseif (b.Base.Position - camPos).Magnitude < ACTIVE_RANGE then
				local w = t * b.Speed + b.Phase
				-- DipOffset: pelampung dicelup lokal oleh FishingController saat gigitan.
				local dipOffset = numAttr(inst, "DipOffset", 0)
				local offset = CFrame.new(0, math.sin(w) * b.Amp - dipOffset, 0)
					* CFrame.Angles(math.sin(w * 0.8) * b.Tilt, 0, math.cos(w * 0.6) * b.Tilt * 0.7)
				setPivot(inst, b.Base * offset)
			end
		end
		for inst, s in spinners do
			if inst.Parent == nil then
				spinners[inst] = nil
			else
				setPivot(inst, s.Base * CFrame.Angles(0, t * s.Speed, 0))
			end
		end
		for key, f in flickers do
			if f.Light.Parent == nil then
				flickers[key] = nil
			else
				local n = math.noise(t * 3 + f.Phase, f.Phase) * 0.5 + 0.5
				f.Light.Brightness = f.Base * (0.75 + n * 0.45)
			end
		end
		for p, r in rainbows do
			if p.Parent == nil then
				rainbows[p] = nil
			else
				p.Color = Color3.fromHSV((r.H + r.Phase + t * 0.12) % 1, r.S, r.V)
			end
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local playerPos = if root and root:IsA("BasePart") then root.Position else nil
		for _, c in creatures do
			updateCreature(c, t, dt, camPos, playerPos)
		end
	end)

end

return AmbientController
