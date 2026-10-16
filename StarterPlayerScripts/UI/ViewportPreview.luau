--!strict
-- ViewportPreview: pratinjau model 3D (ikan, joran, kosmetik) di ViewportFrame. Mengambil alih model (di-parent
-- ke WorldModel di dalam ViewportFrame; model lama dihancurkan saat diganti). Kamera dibingkai dari
-- GetBoundingBox: bola pembatas pas di FOV terkecil, dilihat dari samping sumbu horizontal terpanjang (ikan
-- tampak profil) sedikit dari atas-kanan. Cahaya hangat diturunkan dari token Theme.
-- Putar pelan: SATU koneksi Heartbeat bersama untuk semua pratinjau yang berputar (registry modul), tidak
-- berjalan saat ReducedMotion atau saat pratinjau tidak tampil; terputus otomatis bila tidak ada yang berputar.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Theme = require(Shared.Config.Theme)
local TweenUtil = require(Shared.Util.TweenUtil)

export type ViewportPreviewProps = {
	Model: Model?,
	Size: UDim2?,
	Spin: boolean?,
	Name: string?,
	LayoutOrder: number?,
	Parent: Instance?,
	ZIndex: number?,
}

export type ViewportPreview = {
	Instance: ViewportFrame,
	SetModel: (self: ViewportPreview, model: Model?) -> (),
	Destroy: (self: ViewportPreview) -> (),
}

type Entry = {
	Frame: ViewportFrame,
	Model: Model?,
	Center: Vector3,
	BasePivot: CFrame,
	Angle: number,
}

local FOV = 30
local FIT_MARGIN = 1.06
local SPIN_SPEED = math.rad(28) -- radian per detik: pelan, terbaca sebagai "dipajang"
local SIDE_BIAS = 0.35
local LIFT = 0.28

local ViewportPreview = {}

local spinning: { [Entry]: boolean } = {}
local heartbeat: RBXScriptConnection? = nil

-- Tampil = semua leluhur GuiObject Visible dan LayerCollector-nya Enabled.
local function isShown(gui: GuiObject): boolean
	local node: Instance? = gui
	while node do
		if node:IsA("GuiObject") then
			if not node.Visible then
				return false
			end
		elseif node:IsA("LayerCollector") then
			return node.Enabled
		end
		node = node.Parent
	end
	return false
end

local function step(dt: number)
	if TweenUtil.ReducedMotion() then
		return
	end
	for entry in spinning do
		local model = entry.Model
		if model and model.Parent and isShown(entry.Frame) then
			entry.Angle = (entry.Angle + SPIN_SPEED * dt) % (2 * math.pi)
			local about = CFrame.new(entry.Center) * CFrame.Angles(0, entry.Angle, 0) * CFrame.new(-entry.Center)
			model:PivotTo(about * entry.BasePivot)
		end
	end
end

local function register(entry: Entry)
	spinning[entry] = true
	if heartbeat == nil then
		heartbeat = RunService.Heartbeat:Connect(step)
	end
end

local function unregister(entry: Entry)
	spinning[entry] = nil
	local conn = heartbeat
	if conn and next(spinning) == nil then
		conn:Disconnect()
		heartbeat = nil
	end
end

local function flat(vector: Vector3): Vector3?
	local horizontal = Vector3.new(vector.X, 0, vector.Z)
	if horizontal.Magnitude < 1e-3 then
		return nil
	end
	return horizontal.Unit
end

local function boundsOf(model: Model): (CFrame, Vector3)
	local ok, cf, size = pcall(function(): (CFrame, Vector3)
		return model:GetBoundingBox()
	end)
	if ok and typeof(cf) == "CFrame" and typeof(size) == "Vector3" then
		return cf, size
	end
	return model:GetPivot(), Vector3.one
end

local function frameCamera(viewport: ViewportFrame, camera: Camera, model: Model)
	local cf, size = boundsOf(model)
	local center = cf.Position
	local radius = math.max(size.Magnitude / 2, 0.1)
	local absolute = viewport.AbsoluteSize
	local aspect = if absolute.X > 0 and absolute.Y > 0 then absolute.X / absolute.Y else 1
	local verticalHalf = math.rad(FOV / 2)
	local horizontalHalf = math.atan(math.tan(verticalHalf) * aspect)
	local distance = radius / math.sin(math.min(verticalHalf, horizontalHalf)) * FIT_MARGIN
	local lengthwise = size.X >= size.Z
	local side = flat(if lengthwise then cf.ZVector else cf.XVector) or Vector3.zAxis
	local across = flat(if lengthwise then cf.XVector else cf.ZVector) or Vector3.xAxis
	local direction = (side + across * SIDE_BIAS + Vector3.yAxis * LIFT).Unit
	camera.FieldOfView = FOV
	camera.CFrame = CFrame.lookAt(center + direction * distance, center)
	camera.Focus = CFrame.new(center)
end

function ViewportPreview.new(props: ViewportPreviewProps): ViewportPreview
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = props.Name or "Preview"
	viewport.BackgroundTransparency = 1
	viewport.BorderSizePixel = 0
	viewport.Size = props.Size or UDim2.fromScale(1, 1)
	if props.LayoutOrder then
		viewport.LayoutOrder = props.LayoutOrder
	end
	if props.ZIndex then
		viewport.ZIndex = props.ZIndex
	end
	-- Cahaya sore hangat: ambient krem-abu + cahaya utama krem keemasan dari kiri-atas-depan.
	viewport.Ambient = Theme.Color.Text:Lerp(Theme.Color.Scrim, 0.25)
	viewport.LightColor = Theme.Color.Text:Lerp(Theme.Color.Primary, 0.35):Lerp(Theme.Color.Scrim, 0.4)
	viewport.LightDirection = Vector3.new(-0.5, -1, -0.7)

	local world = Instance.new("WorldModel")
	world.Name = "World"
	world.Parent = viewport
	local camera = Instance.new("Camera")
	camera.Name = "PreviewCamera"
	camera.FieldOfView = FOV
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local entry: Entry = {
		Frame = viewport,
		Model = nil,
		Center = Vector3.zero,
		BasePivot = CFrame.identity,
		Angle = 0,
	}
	local spin = props.Spin == true
	local framedAspect = 0

	-- Skala seragam (UIScale transisi panel) tidak mengubah rasio; bingkai ulang hanya bila rasio berubah.
	local function reframe()
		local absolute = viewport.AbsoluteSize
		if absolute.X <= 0 or absolute.Y <= 0 then
			return
		end
		local aspect = absolute.X / absolute.Y
		if math.abs(aspect - framedAspect) < 0.01 then
			return
		end
		framedAspect = aspect
		local model = entry.Model
		if model and model.Parent then
			-- Bingkai dihitung pada pose dasar agar putaran tidak menggeser kamera.
			local current = model:GetPivot()
			model:PivotTo(entry.BasePivot)
			frameCamera(viewport, camera, model)
			model:PivotTo(current)
		end
	end

	local function setModel(model: Model?)
		local old = entry.Model
		if old and old ~= model then
			old:Destroy()
		end
		entry.Model = model
		entry.Angle = 0
		if model then
			model.Parent = world
			entry.BasePivot = model:GetPivot()
			local cf = boundsOf(model)
			entry.Center = cf.Position
			frameCamera(viewport, camera, model)
			local absolute = viewport.AbsoluteSize
			framedAspect = if absolute.X > 0 and absolute.Y > 0 then absolute.X / absolute.Y else 0
		end
	end

	viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(reframe)
	viewport.Destroying:Connect(function()
		unregister(entry)
	end)

	local object: ViewportPreview = {
		Instance = viewport,
		SetModel = function(_self: ViewportPreview, model: Model?)
			setModel(model)
		end,
		Destroy = function(_self: ViewportPreview)
			unregister(entry)
			viewport:Destroy()
		end,
	}

	setModel(props.Model)
	if spin then
		register(entry)
	end
	if props.Parent then
		viewport.Parent = props.Parent
	end
	return object
end

return ViewportPreview
