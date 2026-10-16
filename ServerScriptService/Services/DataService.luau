--!strict
-- DataService: profil pemain lewat ProfileStore (session lock, autosave, BindToClose ditangani ProfileStore).
-- Studio tanpa "Enable Studio Access to API Services" → ProfileStore otomatis memakai mock in-memory;
-- DataService mencatat warn sekali dan menampilkan toast "Mode uji: data tidak disimpan".
-- Client menerima snapshot via GetInitialData lalu delta via DataChanged.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local Guard = require(Shared.Util.Guard)
local Balance = require(Shared.Config.Balance)
local Strings = require(Shared.Config.Strings)
local ProfileSchema = require(Shared.ProfileSchema)
local ProfileStore = require(ServerScriptService.Packages.ProfileStore) :: any

type ProfileData = Types.ProfileData
type FishItem = Types.FishItem

local DataService = {}

DataService.ProfileLoaded = Signal.new() :: Signal.Signal<Player, ProfileData>
DataService.ProfileReleasing = Signal.new() :: Signal.Signal<Player, ProfileData>

local store: any = nil
local profiles: { [Player]: any } = {}
local loading: { [Player]: boolean } = {}
local mockResolved = false
local isMock = false

local function keyFor(player: Player): string
	return "Player_" .. tostring(player.UserId)
end

local function createLeaderstats(player: Player, data: ProfileData)
	local old = player:FindFirstChild("leaderstats")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	local coins = Instance.new("IntValue")
	coins.Name = "Koin"
	coins.Value = data.Coins
	coins.Parent = folder
	local level = Instance.new("IntValue")
	level.Name = "Level"
	level.Value = data.Level
	level.Parent = folder
	folder.Parent = player
end

-- Data tidak boleh mengandung nilai rusak (mis. koin negatif dari versi lama).
local function sanitize(data: ProfileData)
	data.Coins = math.max(0, math.floor(data.Coins))
	data.Level = math.clamp(math.floor(data.Level), 1, Balance.MaxLevel)
	data.XP = math.max(0, math.floor(data.XP))
	data.ConservationPoints = math.max(0, math.floor(data.ConservationPoints))
	if #data.Rods == 0 then
		table.insert(data.Rods, Balance.StartRod)
	end
	if not table.find(data.Rods, data.EquippedRod) then
		data.EquippedRod = data.Rods[1]
	end
	if data.EquippedBait ~= "" and (data.Bait[data.EquippedBait] or 0) <= 0 then
		data.EquippedBait = ""
	end
end

local function onPlayerAdded(player: Player)
	if profiles[player] or loading[player] then
		return
	end
	loading[player] = true
	local profile = store:StartSessionAsync(keyFor(player), {
		Cancel = function(): boolean
			return player.Parent ~= Players
		end,
	})
	loading[player] = nil
	if profile == nil then
		if player.Parent == Players then
			player:Kick("Data gagal dimuat. Silakan masuk lagi sebentar lagi.")
		end
		return
	end
	profile:AddUserId(player.UserId)
	profile:Reconcile()
	ProfileSchema.Migrate(profile.Data)
	if player.Parent ~= Players then
		profile:EndSession()
		return
	end
	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		if player.Parent == Players then
			player:Kick("Data kamu sedang dibuka di server lain. Silakan masuk lagi.")
		end
	end)
	local data = profile.Data :: ProfileData
	sanitize(data)
	data.LastLogin = os.time()
	profiles[player] = profile
	createLeaderstats(player, data)
	DataService.ProfileLoaded:Fire(player, data)
	if mockResolved and isMock then
		Net.FireClient("Notify", player, "Warning", Strings.MockMode)
	end
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if profile then
		DataService.ProfileReleasing:Fire(player, profile.Data)
		profiles[player] = nil
		profile:EndSession()
	end
	loading[player] = nil
	Net.ForgetPlayer(player)
end

local function resolveMockMode()
	-- ProfileStore menentukan akses DataStore secara async di Studio.
	local deadline = os.clock() + 20
	while ProfileStore.DataStoreState == "NotReady" and os.clock() < deadline do
		task.wait(0.25)
	end
	isMock = ProfileStore.DataStoreState ~= "Access"
	mockResolved = true
	if isMock then
		warn("[DataService] DataStore tidak tersedia (" .. tostring(ProfileStore.DataStoreState) .. "): mode uji, data tidak disimpan.")
		for player in profiles do
			Net.FireClient("Notify", player, "Warning", Strings.MockMode)
		end
	end
end

function DataService.Init()
	ProfileStore.SetConstant("AUTO_SAVE_PERIOD", Balance.AutoSaveSeconds)
	store = ProfileStore.New(Balance.DataStoreName, ProfileSchema.Template())
end

function DataService.Start()
	Net.OnServerInvoke("GetInitialData", function(player: Player): any
		local profile = profiles[player]
		if profile == nil then
			return nil
		end
		local snapshot: Types.Snapshot = {
			Data = profile.Data,
			IsMock = isMock,
			ServerNow = workspace:GetServerTimeNow(),
		}
		return snapshot
	end)

	Net.OnServerInvoke("SaveSettings", function(player: Player, raw: unknown): any
		local data = DataService.GetData(player)
		if data == nil or typeof(raw) ~= "table" then
			return false
		end
		local t = raw :: { [any]: any }
		local music = Guard.Num(t.Music, 0, 1)
		local sfx = Guard.Num(t.Sfx, 0, 1)
		local lowGfx = Guard.Bool(t.LowGfx)
		local uiScale = Guard.Num(t.UiScale, 0.85, 1.15)
		if music == nil or sfx == nil or lowGfx == nil or uiScale == nil then
			Guard.Reject(player, "SaveSettings", "nilai pengaturan tidak valid")
			return false
		end
		data.Settings = { Music = music, Sfx = sfx, LowGfx = lowGfx, UiScale = uiScale }
		return true
	end)

	Players.PlayerAdded:Connect(function(player)
		task.spawn(onPlayerAdded, player)
	end)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	task.spawn(resolveMockMode)
end

function DataService.GetData(player: Player): ProfileData?
	local profile = profiles[player]
	if profile == nil then
		return nil
	end
	return profile.Data :: ProfileData
end

function DataService.IsLoaded(player: Player): boolean
	return profiles[player] ~= nil
end

-- Menunggu profil siap (hanya dipanggil dari task, boleh yield).
function DataService.WaitForData(player: Player, timeout: number?): ProfileData?
	local deadline = os.clock() + (timeout or 30)
	while player.Parent == Players and os.clock() < deadline do
		local data = DataService.GetData(player)
		if data then
			return data
		end
		task.wait(0.2)
	end
	return DataService.GetData(player)
end

-- true bila DataStore tidak tersedia (mode mock) — baru pasti setelah status ProfileStore terselesaikan.
function DataService.IsMock(): boolean
	return isMock
end

function DataService.IsMockResolved(): boolean
	return mockResolved
end

-- Mengirim nilai terbaru dari kunci-kunci tingkat atas ke client pemilik.
function DataService.Replicate(player: Player, ...: string)
	local data = DataService.GetData(player)
	if data == nil then
		return
	end
	local raw = data :: any
	local payload: { [string]: any } = {}
	for _, key in { ... } do
		payload[key] = raw[key]
	end
	Net.FireClient("DataChanged", player, "Set", payload)
end

function DataService.FishAdded(player: Player, item: FishItem)
	Net.FireClient("DataChanged", player, "FishAdd", item)
end

function DataService.FishRemoved(player: Player, uids: { string })
	if #uids > 0 then
		Net.FireClient("DataChanged", player, "FishRemove", uids)
	end
end

function DataService.FishUpdated(player: Player, item: FishItem)
	Net.FireClient("DataChanged", player, "FishUpdate", item)
end

function DataService.SetLeaderstat(player: Player, name: string, value: number)
	local folder = player:FindFirstChild("leaderstats")
	local stat = folder and folder:FindFirstChild(name)
	if stat and stat:IsA("IntValue") then
		stat.Value = math.floor(value)
	end
end

-- Simpan segera (mis. setelah trade). Tidak menunggu; ProfileStore menjadwalkan UpdateAsync sendiri.
function DataService.Save(player: Player)
	local profile = profiles[player]
	if profile and profile:IsActive() then
		task.spawn(function()
			profile:Save()
		end)
	end
end

return DataService
