--!strict
-- Net: satu-satunya tempat mendefinisikan Remote. Server membuat ReplicatedStorage.Remotes saat Init;
-- client mengambilnya dengan WaitForChild bertimeout. RemoteFunction hanya client→server (tanpa InvokeClient).
-- Setiap handler server dibungkus rate limit token bucket + pcall agar error tidak menghentikan server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RateLimiter = require(script.Parent.Util.RateLimiter)
local Guard = require(script.Parent.Util.Guard)

export type RemoteKind = "Event" | "Function"
export type Spec = {
	Kind: RemoteKind,
	Direction: "ToServer" | "ToClient",
	Rate: number,
	Burst: number,
}

local Net = {}

-- Daftar lengkap remote (lihat docs/PLAN.md §Remote untuk payload).
Net.Specs = {
	-- Data
	GetInitialData = { Kind = "Function", Direction = "ToServer", Rate = 1, Burst = 6 },
	DataChanged = { Kind = "Event", Direction = "ToClient", Rate = 0, Burst = 0 },
	Notify = { Kind = "Event", Direction = "ToClient", Rate = 0, Burst = 0 },
	-- Memancing
	CastLine = { Kind = "Event", Direction = "ToServer", Rate = 2, Burst = 3 },
	HookFish = { Kind = "Event", Direction = "ToServer", Rate = 4, Burst = 4 },
	ReelFinished = { Kind = "Event", Direction = "ToServer", Rate = 2, Burst = 3 },
	CancelFishing = { Kind = "Event", Direction = "ToServer", Rate = 3, Burst = 4 },
	FishingEvent = { Kind = "Event", Direction = "ToClient", Rate = 0, Burst = 0 },
	-- Toko, equip, inventaris
	Purchase = { Kind = "Function", Direction = "ToServer", Rate = 3, Burst = 6 },
	Equip = { Kind = "Function", Direction = "ToServer", Rate = 4, Burst = 8 },
	SellFish = { Kind = "Function", Direction = "ToServer", Rate = 2, Burst = 4 },
	ReleaseFish = { Kind = "Function", Direction = "ToServer", Rate = 2, Burst = 4 },
	SetFishLock = { Kind = "Function", Direction = "ToServer", Rate = 6, Burst = 10 },
	BarterPreview = { Kind = "Function", Direction = "ToServer", Rate = 2, Burst = 4 },
	BarterExecute = { Kind = "Function", Direction = "ToServer", Rate = 1, Burst = 2 },
	-- RPG & dunia
	AcceptStoryQuest = { Kind = "Function", Direction = "ToServer", Rate = 1, Burst = 3 },
	ClaimFishdex = { Kind = "Function", Direction = "ToServer", Rate = 1, Burst = 3 },
	FerryTravel = { Kind = "Function", Direction = "ToServer", Rate = 0.5, Burst = 2 },
	SaveSettings = { Kind = "Function", Direction = "ToServer", Rate = 1, Burst = 4 },
	OpenNpc = { Kind = "Event", Direction = "ToClient", Rate = 0, Burst = 0 },
	LevelUp = { Kind = "Event", Direction = "ToClient", Rate = 0, Burst = 0 },
	FerryEvent = { Kind = "Event", Direction = "ToClient", Rate = 0, Burst = 0 },
	-- Trade
	TradeInvite = { Kind = "Function", Direction = "ToServer", Rate = 0.5, Burst = 2 },
	TradeRespond = { Kind = "Function", Direction = "ToServer", Rate = 1, Burst = 3 },
	TradeUpdateOffer = { Kind = "Function", Direction = "ToServer", Rate = 4, Burst = 8 },
	TradeSetReady = { Kind = "Function", Direction = "ToServer", Rate = 3, Burst = 5 },
	TradeCancel = { Kind = "Function", Direction = "ToServer", Rate = 2, Burst = 3 },
	TradeEvent = { Kind = "Event", Direction = "ToClient", Rate = 0, Burst = 0 },
} :: { [string]: Spec }

local FOLDER_NAME = "Remotes"
local CLIENT_TIMEOUT = 30

local folder: Folder? = nil
local remotes: { [string]: Instance } = {}
local limiters: { [string]: RateLimiter.RateLimiter } = {}

local function specOf(name: string): Spec
	local spec = Net.Specs[name]
	if spec == nil then
		error("[Net] remote tidak terdaftar: " .. name, 3)
	end
	return spec
end

-- Server: membuat semua remote. Dipanggil sekali dari Main.server sebelum Init service.
function Net.Init()
	assert(RunService:IsServer(), "Net.Init hanya untuk server")
	if folder then
		return
	end
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing then
		existing:Destroy()
	end
	local f = Instance.new("Folder")
	f.Name = FOLDER_NAME
	for name, spec in Net.Specs do
		local remote: Instance
		if spec.Kind == "Function" then
			remote = Instance.new("RemoteFunction")
		else
			remote = Instance.new("RemoteEvent")
		end
		remote.Name = name
		remote.Parent = f
		remotes[name] = remote
		if spec.Direction == "ToServer" then
			limiters[name] = RateLimiter.new(spec.Rate, spec.Burst)
		end
	end
	f.Parent = ReplicatedStorage
	folder = f
end

local function getRemote(name: string): Instance
	specOf(name)
	local r = remotes[name]
	if r then
		return r
	end
	if RunService:IsServer() then
		error("[Net] Net.Init belum dipanggil (" .. name .. ")", 3)
	end
	local f = folder
	if f == nil then
		local found = ReplicatedStorage:WaitForChild(FOLDER_NAME, CLIENT_TIMEOUT)
		if found == nil or not found:IsA("Folder") then
			error("[Net] folder Remotes tidak ditemukan", 3)
		end
		f = found :: Folder
		folder = f
	end
	local inst = (f :: Folder):WaitForChild(name, CLIENT_TIMEOUT)
	if inst == nil then
		error("[Net] remote tidak ditemukan: " .. name, 3)
	end
	remotes[name] = inst
	return inst
end

local function asEvent(name: string): RemoteEvent
	local r = getRemote(name)
	assert(r:IsA("RemoteEvent"), "[Net] " .. name .. " bukan RemoteEvent")
	return r
end

local function asFunction(name: string): RemoteFunction
	local r = getRemote(name)
	assert(r:IsA("RemoteFunction"), "[Net] " .. name .. " bukan RemoteFunction")
	return r
end

-- Server: menghubungkan handler event client→server dengan rate limit + pcall.
function Net.OnServerEvent(name: string, handler: (Player, ...any) -> ...any)
	local spec = specOf(name)
	assert(spec.Direction == "ToServer" and spec.Kind == "Event", "[Net] " .. name .. " bukan event ToServer")
	local limiter = limiters[name]
	asEvent(name).OnServerEvent:Connect(function(player: Player, ...: any)
		if not limiter:Allow(player) then
			Guard.Reject(player, name, "rate limit")
			return
		end
		local ok, err = pcall(handler, player, ...)
		if not ok then
			warn(string.format("[Net] handler %s gagal untuk UserId=%d: %s", name, player.UserId, tostring(err)))
		end
	end)
end

-- Server: menghubungkan handler RemoteFunction. Bila ditolak/gagal, client menerima (false, pesan).
function Net.OnServerInvoke(name: string, handler: (Player, ...any) -> ...any)
	local spec = specOf(name)
	assert(spec.Direction == "ToServer" and spec.Kind == "Function", "[Net] " .. name .. " bukan function ToServer")
	local limiter = limiters[name]
	asFunction(name).OnServerInvoke = function(player: Player, ...: any): ...any
		if not limiter:Allow(player) then
			Guard.Reject(player, name, "rate limit")
			return false, "Terlalu cepat. Coba lagi sebentar."
		end
		local results = table.pack(pcall(handler, player, ...))
		if not results[1] then
			warn(string.format("[Net] handler %s gagal untuk UserId=%d: %s", name, player.UserId, tostring(results[2])))
			return false, "Terjadi kesalahan di server."
		end
		return table.unpack(results, 2, results.n)
	end
end

function Net.FireClient(name: string, player: Player, ...: any)
	local spec = specOf(name)
	assert(spec.Direction == "ToClient", "[Net] " .. name .. " bukan event ToClient")
	asEvent(name):FireClient(player, ...)
end

function Net.FireAllClients(name: string, ...: any)
	local spec = specOf(name)
	assert(spec.Direction == "ToClient", "[Net] " .. name .. " bukan event ToClient")
	asEvent(name):FireAllClients(...)
end

-- Client
function Net.FireServer(name: string, ...: any)
	local spec = specOf(name)
	assert(spec.Direction == "ToServer" and spec.Kind == "Event", "[Net] " .. name .. " bukan event ToServer")
	asEvent(name):FireServer(...)
end

-- Client: memanggil RemoteFunction dengan pcall. Mengembalikan hasil server, atau (false, pesan) bila gagal.
function Net.Invoke(name: string, ...: any): ...any
	local spec = specOf(name)
	assert(spec.Direction == "ToServer" and spec.Kind == "Function", "[Net] " .. name .. " bukan function ToServer")
	local results = table.pack(pcall(asFunction(name).InvokeServer, asFunction(name), ...))
	if not results[1] then
		warn("[Net] Invoke " .. name .. " gagal: " .. tostring(results[2]))
		return false, "Koneksi ke server bermasalah."
	end
	return table.unpack(results, 2, results.n)
end

function Net.OnClientEvent(name: string, handler: (...any) -> ()): RBXScriptConnection
	local spec = specOf(name)
	assert(spec.Direction == "ToClient", "[Net] " .. name .. " bukan event ToClient")
	return asEvent(name).OnClientEvent:Connect(handler)
end

-- Server: bersihkan bucket pemain yang keluar.
function Net.ForgetPlayer(player: Player)
	for _, limiter in limiters do
		limiter:Remove(player)
	end
	Guard.Forget(player)
end

return Net
