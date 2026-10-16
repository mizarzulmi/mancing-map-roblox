--!strict
-- RodModel: joran pancing prosedural (GDD 4.1). BuildTool → Tool untuk karakter R15; BuildDisplay → Model anchored
-- untuk viewport/rak. Hanya primitif Roblox (Part Cylinder/Ball), tanpa aset unggahan. 18 part per joran.
--
-- Ruang lokal Handle (pegangan):
--   • Batang sepanjang +X: pangkal (kenop) di x ≈ −0,96, ujung joran di x ≈ +6,45 → total ±7,4 stud.
--   • Reel, engkol, dan cincin pemandu menggantung di −Y; +Z = sisi kanan pemegang (engkol di −Z, kiri).
--   • Tool.Grip memiringkan +X ±35° ke atas-depan saat dipegang tangan kanan R15 dalam pose tool bawaan
--     (RightGripAttachment R15: Orientation (−90, 0, 0); saat lengan menjulur ke depan LookVector-nya = depan).
-- Attachment "TipAttachment" ada di part "Tip" (segmen terakhir, tepat di ujung): cari dengan
-- FindFirstChild("TipAttachment", true). Skin "Rainbow": segmen bertag "Rainbow" + atribut "RainbowPhase".

local CollectionService = game:GetService("CollectionService")

local Types = require(script.Parent.Parent.Types)

type RodDef = Types.RodDef
type CosmeticDef = Types.CosmeticDef

-- Tampilan akhir joran setelah skin diterapkan.
type Look = {
	Segments: { Color3 },
	ShaftMaterial: Enum.Material,
	ShaftReflectance: number,
	Tip: Color3?,
	Grip: Color3,
	GripMaterial: Enum.Material,
	Butt: Color3,
	Band: Color3,
	BandMaterial: Enum.Material,
	Guide: Color3,
	GuideMaterial: Enum.Material,
	Reel: Color3,
	ReelMaterial: Enum.Material,
	Hardware: Color3,
	HardwareMaterial: Enum.Material,
	Knob: Color3,
	KnobMaterial: Enum.Material,
	TrimReflectance: number,
	Rainbow: boolean,
}

type Joint = { Pos: Vector3, Angle: number, Diameter: number }

local RodModel = {}

local SEGMENT_COUNT = 6
local SEGMENT_LENGTH = 0.95
local SEGMENT_OVERLAP = 0.03
local SEGMENT_DIAMETERS = { 0.17, 0.145, 0.12, 0.097, 0.075, 0.055 }
local DROOP_PER_JOINT = math.rad(-1.25) -- lengkung halus: ujung sedikit merunduk
local SHAFT_START = 0.78
local HANDLE_LENGTH = 1.6
local HANDLE_DIAMETER = 0.27
local GUIDE_JOINTS = { 1, 3, 5 }
local GUIDE_DIAMETERS = { 0.17, 0.13, 0.1 }
local BAND_JOINTS = { 2, 4 }

local TILT = math.rad(35)
local GRIP_POINT = Vector3.new(0.12, 0, 0) -- titik genggam (tepat di belakang tangkai reel)

local HARDWARE = Color3.fromRGB(64, 68, 76)
local GUIDE_SILVER = Color3.fromRGB(200, 206, 214)
local RAINBOW_TAG = "Rainbow"

-- Orientasi Handle dalam bingkai RightGripAttachment: +X Handle = depan 35° ke atas, +Y Handle tegak lurus (atas-
-- belakang), +Z Handle = kanan. Grip = invers bingkai itu, digeser ke titik genggam.
local GRIP = CFrame.new(GRIP_POINT)
	* CFrame.fromMatrix(
		Vector3.zero,
		Vector3.new(0, math.sin(TILT), -math.cos(TILT)),
		Vector3.new(0, math.cos(TILT), math.sin(TILT))
	)
		:Inverse()

local function shade(c: Color3, factor: number): Color3
	return Color3.new(math.clamp(c.R * factor, 0, 1), math.clamp(c.G * factor, 0, 1), math.clamp(c.B * factor, 0, 1))
end

local function pick(colors: { Color3 }, index: number, fallback: Color3): Color3
	local c: Color3? = colors[index]
	return if c then c else fallback
end

local function baseLook(rod: RodDef): Look
	local bamboo = rod.Material == Enum.Material.Wood
	local segments: { Color3 } = {}
	for i = 1, SEGMENT_COUNT do
		-- Variasi kecerahan deterministik per ruas: ±4% untuk bambu, halus untuk bahan pabrikan.
		segments[i] = shade(rod.Colors.Shaft, 1 + (if bamboo then 0.04 else 0.015) * math.sin(i * 2.3))
	end
	return {
		Segments = segments,
		ShaftMaterial = rod.Material,
		ShaftReflectance = if rod.Material == Enum.Material.Metal then 0.25 else 0,
		Tip = nil,
		Grip = rod.Colors.Grip,
		GripMaterial = if bamboo then Enum.Material.Fabric else Enum.Material.SmoothPlastic,
		Butt = shade(rod.Colors.Grip, 0.7),
		-- Bambu: ruas = cincin gelap; lainnya: lilitan benang warna aksen.
		Band = if bamboo then shade(rod.Colors.Shaft, 0.45) else rod.Colors.Accent,
		BandMaterial = if bamboo then Enum.Material.Wood else Enum.Material.SmoothPlastic,
		Guide = GUIDE_SILVER,
		GuideMaterial = Enum.Material.Metal,
		Reel = rod.Colors.Accent,
		ReelMaterial = Enum.Material.SmoothPlastic,
		Hardware = HARDWARE,
		HardwareMaterial = Enum.Material.Metal,
		Knob = rod.Colors.Grip,
		KnobMaterial = Enum.Material.SmoothPlastic,
		TrimReflectance = 0.08,
		Rainbow = false,
	}
end

local function skinnedLook(rod: RodDef, skin: CosmeticDef?): Look
	local look = baseLook(rod)
	if skin == nil or skin.Slot ~= "RodSkin" then
		return look
	end
	local style = skin.Style
	local colors = skin.Colors
	if style == "Neon" then
		-- Badan gelap + garis Neon biru: lilitan, cincin pemandu, kenop engkol, dan ujung joran menyala.
		local body = pick(colors, 1, Color3.fromRGB(30, 40, 60))
		local glow = pick(colors, 2, Color3.fromRGB(80, 200, 255))
		for i = 1, SEGMENT_COUNT do
			look.Segments[i] = shade(body, 1 + 0.03 * math.sin(i * 1.7))
		end
		look.ShaftMaterial = Enum.Material.SmoothPlastic
		look.ShaftReflectance = 0.05
		look.Tip = glow
		look.Grip = shade(body, 0.8)
		look.GripMaterial = Enum.Material.SmoothPlastic
		look.Butt = shade(body, 0.65)
		look.Band = glow
		look.BandMaterial = Enum.Material.Neon
		look.Guide = glow
		look.GuideMaterial = Enum.Material.Neon
		look.Reel = shade(body, 1.25)
		look.Knob = glow
		look.KnobMaterial = Enum.Material.Neon
	elseif style == "Camo" then
		-- Pita selang-seling tiga warna sepanjang batang.
		local c1 = pick(colors, 1, rod.Colors.Shaft)
		local c2 = pick(colors, 2, rod.Colors.Accent)
		local c3 = pick(colors, 3, rod.Colors.Grip)
		local cycle = { c1, c2, c3 }
		for i = 1, SEGMENT_COUNT do
			look.Segments[i] = cycle[(i - 1) % 3 + 1]
		end
		look.ShaftMaterial = Enum.Material.SmoothPlastic
		look.ShaftReflectance = 0
		look.Grip = shade(c1, 0.62)
		look.GripMaterial = Enum.Material.Fabric
		look.Butt = shade(c1, 0.45)
		look.Band = shade(c2, 0.7)
		look.BandMaterial = Enum.Material.SmoothPlastic
		look.Reel = c2
		look.Knob = c3
	elseif style == "Gold" then
		local gold = pick(colors, 1, Color3.fromRGB(232, 182, 72))
		local light = pick(colors, 2, Color3.fromRGB(255, 236, 170))
		for i = 1, SEGMENT_COUNT do
			look.Segments[i] = shade(gold, 1 + 0.03 * math.sin(i * 1.9))
		end
		look.ShaftMaterial = Enum.Material.Metal
		look.ShaftReflectance = 0.3
		look.Grip = shade(gold, 0.75)
		look.GripMaterial = Enum.Material.Metal
		look.Butt = light
		look.Band = light
		look.BandMaterial = Enum.Material.Metal
		look.Guide = light
		look.GuideMaterial = Enum.Material.Metal
		look.Reel = gold
		look.ReelMaterial = Enum.Material.Metal
		look.Hardware = shade(gold, 0.7)
		look.Knob = light
		look.KnobMaterial = Enum.Material.Metal
		look.TrimReflectance = 0.35
	elseif style == "Rainbow" then
		look.Rainbow = true
	end
	-- "Wood" (Kayu Klasik) dan gaya tak dikenal memakai warna asli joran.
	return look
end

local function newPart(
	shape: Enum.PartType,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material,
	anchored: boolean,
	shadow: boolean
): Part
	local part = Instance.new("Part")
	part.Shape = shape
	part.Name = name
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = anchored
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = shadow
	return part
end

-- Membangun semua part joran dalam ruang Handle (Handle di CFrame identitas). Belum di-parent.
local function buildRod(rod: RodDef, skin: CosmeticDef?, anchored: boolean): (Part, { Part })
	local look = skinnedLook(rod, skin)
	local parts: { Part } = {}
	local function add(part: Part): Part
		table.insert(parts, part)
		return part
	end
	local cylinder = Enum.PartType.Cylinder

	-- Pegangan, kenop pangkal, dan cincin pembatas depan.
	local handle = add(
		newPart(
			cylinder,
			"Handle",
			Vector3.new(HANDLE_LENGTH, HANDLE_DIAMETER, HANDLE_DIAMETER),
			CFrame.identity,
			look.Grip,
			look.GripMaterial,
			anchored,
			true
		)
	)
	add(
		newPart(
			Enum.PartType.Ball,
			"ButtCap",
			Vector3.one * 0.32,
			CFrame.new(-HANDLE_LENGTH / 2, 0, 0),
			look.Butt,
			look.GripMaterial,
			anchored,
			false
		)
	)
	local foreRing = add(
		newPart(
			cylinder,
			"ForeRing",
			Vector3.new(0.1, 0.22, 0.22),
			CFrame.new(HANDLE_LENGTH / 2, 0, 0),
			look.Band,
			look.BandMaterial,
			anchored,
			false
		)
	)
	foreRing.Reflectance = look.TrimReflectance

	-- Reel: tangkai, badan gulungan (sumbu sejajar joran), engkol, dan kenop.
	local vertical = CFrame.Angles(0, 0, math.pi / 2)
	add(
		newPart(
			cylinder,
			"ReelStem",
			Vector3.new(0.2, 0.075, 0.075),
			CFrame.new(0.32, -0.215, 0) * vertical,
			look.Hardware,
			look.HardwareMaterial,
			anchored,
			false
		)
	)
	local reelBody = add(
		newPart(
			cylinder,
			"ReelBody",
			Vector3.new(0.3, 0.36, 0.36),
			CFrame.new(0.32, -0.47, 0),
			look.Reel,
			look.ReelMaterial,
			anchored,
			true
		)
	)
	reelBody.Reflectance = look.TrimReflectance
	add(
		newPart(
			cylinder,
			"ReelArm",
			Vector3.new(0.2, 0.05, 0.05),
			CFrame.new(0.32, -0.47, -0.25) * CFrame.Angles(0, math.pi / 2, 0),
			look.Hardware,
			look.HardwareMaterial,
			anchored,
			false
		)
	)
	add(
		newPart(
			Enum.PartType.Ball,
			"ReelKnob",
			Vector3.one * 0.12,
			CFrame.new(0.32, -0.42, -0.38),
			look.Knob,
			look.KnobMaterial,
			anchored,
			false
		)
	)

	-- Batang: rantai silinder meruncing yang merunduk bertahap.
	local joints: { Joint } = {}
	local segments: { Part } = {}
	local start = Vector3.new(SHAFT_START, 0, 0)
	local angle = 0
	for i = 1, SEGMENT_COUNT do
		local dir = Vector3.new(math.cos(angle), math.sin(angle), 0)
		local d = SEGMENT_DIAMETERS[i]
		local center = start + dir * ((SEGMENT_LENGTH - SEGMENT_OVERLAP) / 2)
		local isTip = i == SEGMENT_COUNT
		local color = look.Segments[i]
		local material = look.ShaftMaterial
		local tipColor = look.Tip
		if isTip and tipColor then
			color = tipColor
			material = Enum.Material.Neon
		end
		local hue = (i - 1) / SEGMENT_COUNT * 0.85
		if look.Rainbow then
			color = Color3.fromHSV(hue, 0.7, 1)
		end
		local segment = add(
			newPart(
				cylinder,
				if isTip then "Tip" else "Segment" .. i,
				Vector3.new(SEGMENT_LENGTH + SEGMENT_OVERLAP, d, d),
				CFrame.new(center) * CFrame.Angles(0, 0, angle),
				color,
				material,
				anchored,
				i <= 3
			)
		)
		segment.Reflectance = look.ShaftReflectance
		if look.Rainbow then
			segment:SetAttribute("RainbowPhase", hue)
			CollectionService:AddTag(segment, RAINBOW_TAG)
		end
		segments[i] = segment
		start += dir * SEGMENT_LENGTH
		joints[i] = { Pos = start, Angle = angle, Diameter = d }
		angle += DROOP_PER_JOINT
	end

	-- Ruas/lilitan pada sambungan dan cincin pemandu di sisi bawah.
	for _, j in BAND_JOINTS do
		local joint = joints[j]
		local d = joint.Diameter + 0.04
		local band = add(
			newPart(
				cylinder,
				"Band" .. j,
				Vector3.new(0.08, d, d),
				CFrame.new(joint.Pos) * CFrame.Angles(0, 0, joint.Angle),
				look.Band,
				look.BandMaterial,
				anchored,
				false
			)
		)
		band.Reflectance = look.TrimReflectance
	end
	for k, j in GUIDE_JOINTS do
		local joint = joints[j]
		local gd = GUIDE_DIAMETERS[k]
		local down = Vector3.new(math.sin(joint.Angle), -math.cos(joint.Angle), 0)
		local offset = joint.Diameter / 2 + gd / 2 - 0.012
		local guide = add(
			newPart(
				cylinder,
				"Guide" .. k,
				Vector3.new(0.028, gd, gd),
				CFrame.new(joint.Pos + down * offset) * CFrame.Angles(0, 0, joint.Angle),
				look.Guide,
				look.GuideMaterial,
				anchored,
				false
			)
		)
		guide.Reflectance = look.TrimReflectance
	end

	-- Titik tali di ujung batang.
	local tip = Instance.new("Attachment")
	tip.Name = "TipAttachment"
	tip.CFrame = CFrame.new((SEGMENT_LENGTH + SEGMENT_OVERLAP) / 2, 0, 0)
	tip.Parent = segments[SEGMENT_COUNT]
	return handle, parts
end

-- Tool joran untuk Backpack pemain: Handle = pegangan, part lain dilas WeldConstraint ke Handle.
function RodModel.BuildTool(rod: RodDef, skin: CosmeticDef?): Tool
	local tool = Instance.new("Tool")
	tool.Name = rod.Name
	tool.ToolTip = rod.Name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.Grip = GRIP
	tool:SetAttribute("RodId", rod.Id)
	if skin and skin.Slot == "RodSkin" then
		tool:SetAttribute("SkinId", skin.Id)
	end
	local handle, parts = buildRod(rod, skin, false)
	for _, part in parts do
		if part ~= handle then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = handle
			weld.Part1 = part
			weld.Parent = part
		end
	end
	for _, part in parts do
		part.Parent = tool
	end
	return tool
end

-- Versi pajangan anchored (viewport/rak). PrimaryPart = Handle di pivot; batang sepanjang +X.
function RodModel.BuildDisplay(rod: RodDef, skin: CosmeticDef?): Model
	local model = Instance.new("Model")
	model.Name = rod.Name
	model:SetAttribute("RodId", rod.Id)
	if skin and skin.Slot == "RodSkin" then
		model:SetAttribute("SkinId", skin.Id)
	end
	local handle, parts = buildRod(rod, skin, true)
	for _, part in parts do
		part.Parent = model
	end
	model.PrimaryPart = handle
	return model
end

return RodModel
