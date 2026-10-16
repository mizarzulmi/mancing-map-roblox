--!strict
-- CosmeticService: remote Equip (joran, umpan, dan 7 slot kosmetik), penerapan visual kosmetik ke karakter R15
-- (Accessory lewat Humanoid:AddAccessory, Trail, Aura; dilewati dengan aman bila attachment tidak ada),
-- serta nametag "Lv 12 · Nama" + gelar terpasang. Skin joran & pelampung dibaca FishingService dari data.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local Net = require(Shared.Net)
local Guard = require(Shared.Util.Guard)
local Cosmetics = require(Shared.Config.Cosmetics)
local Rods = require(Shared.Config.Rods)
local Bait = require(Shared.Config.Bait)
local Theme = require(Shared.Config.Theme)
local CosmeticModels = require(Shared.Models.CosmeticModels)
local DataService = require(script.Parent.DataService)
local InventoryService = require(script.Parent.InventoryService)
local LevelService = require(script.Parent.LevelService)
local FishingService = require(script.Parent.FishingService)

type CosmeticDef = Types.CosmeticDef

local CosmeticService = {}

local SLOTS = { "Rod", "Bait", "Hat", "Accessory", "RodSkin", "Bobber", "Trail", "Aura", "Title" }
local applied: { [Player]: { Instance } } = {}

-- Nama attachment yang dipakai kosmetik (untuk melepas aksesori avatar yang bertabrakan).
local function attachmentNameOf(accessory: Accessory): string?
	local handle = accessory:FindFirstChild("Handle")
	if handle then
		for _, child in handle:GetChildren() do
			if child:IsA("Attachment") then
				return child.Name
			end
		end
	end
	return nil
end

local function clearApplied(player: Player)
	local list = applied[player]
	if list then
		for _, inst in list do
			if inst.Parent then
				inst:Destroy()
			end
		end
	end
	applied[player] = {}
end

local function updateNametag(player: Player)
	local data = DataService.GetData(player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if data == nil or head == nil or not head:IsA("BasePart") then
		return
	end
	local gui = head:FindFirstChild("PlayerNametag")
	if gui == nil then
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "PlayerNametag"
		billboard.Size = UDim2.fromOffset(300, 64)
		billboard.StudsOffset = Vector3.new(0, 2.6, 0)
		billboard.MaxDistance = 90
		billboard.LightInfluence = 0
		billboard.Adornee = head

		local nameLine = Instance.new("TextLabel")
		nameLine.Name = "NameLine"
		nameLine.Size = UDim2.new(1, 0, 0, 30)
		nameLine.BackgroundTransparency = 1
		nameLine.FontFace = Theme.Font.Bold
		nameLine.TextSize = 22
		nameLine.TextColor3 = Theme.World.NameText
		local s1 = Instance.new("UIStroke")
		s1.Color = Theme.World.NameStroke
		s1.Thickness = 2
		s1.Parent = nameLine
		nameLine.Parent = billboard

		local titleLine = Instance.new("TextLabel")
		titleLine.Name = "TitleLine"
		titleLine.Size = UDim2.new(1, 0, 0, 24)
		titleLine.Position = UDim2.fromOffset(0, 30)
		titleLine.BackgroundTransparency = 1
		titleLine.FontFace = Theme.Font.Bold
		titleLine.TextSize = 19
		titleLine.TextColor3 = Theme.World.TitleText
		local s2 = Instance.new("UIStroke")
		s2.Color = Theme.World.NameStroke
		s2.Thickness = 2
		s2.Parent = titleLine
		titleLine.Parent = billboard

		billboard.Parent = head
		gui = billboard
	end
	local nameLine = (gui :: Instance):FindFirstChild("NameLine")
	local titleLine = (gui :: Instance):FindFirstChild("TitleLine")
	if nameLine and nameLine:IsA("TextLabel") then
		nameLine.Text = string.format("Lv %d · %s", data.Level, player.DisplayName)
	end
	if titleLine and titleLine:IsA("TextLabel") then
		local title = Cosmetics.Get(data.Cosmetics.Equipped.Title)
		titleLine.Text = if title then title.Name else ""
		titleLine.Visible = title ~= nil
	end
end

-- Menerapkan ulang semua kosmetik yang dipakai ke karakter saat ini.
function CosmeticService.Apply(player: Player)
	local data = DataService.GetData(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if data == nil or character == nil or humanoid == nil then
		return
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	clearApplied(player)
	local list = applied[player]
	local equipped = data.Cosmetics.Equipped

	for _, slot in { "Hat", "Accessory" } do
		local cosmetic = Cosmetics.Get((equipped :: any)[slot])
		if cosmetic then
			local accessory = CosmeticModels.BuildAccessory(cosmetic)
			if accessory then
				local attachName = attachmentNameOf(accessory)
				-- Lewati dengan aman bila rig tidak punya attachment yang dibutuhkan.
				if attachName == nil or character:FindFirstChild(attachName, true) ~= nil then
					-- Lepas aksesori avatar yang memakai attachment yang sama agar tidak tumpang tindih.
					for _, existing in humanoid:GetAccessories() do
						if existing:GetAttribute("CosmeticId") == nil and attachmentNameOf(existing) == attachName then
							existing:Destroy()
						end
					end
					accessory:SetAttribute("CosmeticId", cosmetic.Id)
					humanoid:AddAccessory(accessory)
					table.insert(list, accessory)
				else
					accessory:Destroy()
				end
			end
		end
	end

	local trail = Cosmetics.Get(equipped.Trail)
	if trail then
		for _, inst in CosmeticModels.ApplyTrail(character, trail) do
			table.insert(list, inst)
		end
	end
	local aura = Cosmetics.Get(equipped.Aura)
	if aura then
		for _, inst in CosmeticModels.ApplyAura(character, aura) do
			table.insert(list, inst)
		end
	end
	updateNametag(player)
end

local function equip(player: Player, slotRaw: unknown, itemRaw: unknown): (boolean, string)
	local slot = Guard.OneOf(slotRaw, SLOTS)
	local itemId: string? = if itemRaw == "" then "" else Guard.Str(itemRaw, 64)
	if slot == nil or itemId == nil then
		Guard.Reject(player, "Equip", "slot/item tidak valid")
		return false, "Permintaan tidak valid."
	end
	local data = DataService.GetData(player)
	if data == nil then
		return false, "Data belum siap."
	end
	local id = itemId :: string

	if slot == "Rod" then
		local rod = Rods.Get(id)
		if rod == nil or not InventoryService.HasRod(player, id) then
			Guard.Reject(player, "Equip", "joran tidak dimiliki")
			return false, "Kamu belum memiliki joran ini."
		end
		data.EquippedRod = id
		DataService.Replicate(player, "EquippedRod")
		FishingService.RefreshRod(player)
		return true, rod.Name .. " dipakai."
	elseif slot == "Bait" then
		if id == "" then
			data.EquippedBait = ""
			DataService.Replicate(player, "EquippedBait")
			return true, "Tanpa umpan."
		end
		local bait = Bait.Get(id)
		if bait == nil or (data.Bait[id] or 0) <= 0 then
			return false, "Umpan ini habis."
		end
		data.EquippedBait = id
		DataService.Replicate(player, "EquippedBait")
		return true, bait.Name .. " dipakai."
	end

	-- Slot kosmetik
	if id ~= "" then
		local cosmetic = Cosmetics.Get(id)
		if cosmetic == nil or cosmetic.Slot ~= slot or not data.Cosmetics.Owned[id] then
			Guard.Reject(player, "Equip", "kosmetik tidak dimiliki/slot salah")
			return false, "Kosmetik belum dimiliki."
		end
	elseif slot == "RodSkin" then
		id = "rodskin_kayu"
	elseif slot == "Bobber" then
		id = "bobber_merah_putih"
	end
	;(data.Cosmetics.Equipped :: any)[slot] = id
	DataService.Replicate(player, "Cosmetics")
	if slot == "RodSkin" then
		FishingService.RefreshRod(player)
	elseif slot ~= "Bobber" then
		CosmeticService.Apply(player)
	end
	local def = Cosmetics.Get(id)
	return true, if def then def.Name .. " dipakai." else "Dilepas."
end

local function onCharacter(player: Player, character: Model)
	local data = DataService.WaitForData(player, 30)
	if data == nil or player.Character ~= character then
		return
	end
	character:WaitForChild("Humanoid", 10)
	CosmeticService.Apply(player)
end

local function bindPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	-- Aksesori avatar dimuat async; terapkan ulang setelah penampilan selesai dimuat.
	player.CharacterAppearanceLoaded:Connect(function(character)
		if player.Character == character then
			CosmeticService.Apply(player)
		end
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
end

function CosmeticService.Start()
	Net.OnServerInvoke("Equip", function(player: Player, slot: unknown, itemId: unknown): any
		return equip(player, slot, itemId)
	end)
	LevelService.LevelChanged:Connect(function(player)
		updateNametag(player)
	end)
	-- Profil bisa siap setelah karakter muncul: terapkan kosmetik & nametag saat itu juga.
	DataService.ProfileLoaded:Connect(function(player)
		if player.Character then
			CosmeticService.Apply(player)
		end
	end)
	Players.PlayerAdded:Connect(bindPlayer)
	for _, player in Players:GetPlayers() do
		bindPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		applied[player] = nil
	end)
end

return CosmeticService
