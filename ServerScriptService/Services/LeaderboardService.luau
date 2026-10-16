--!strict
-- LeaderboardService: papan peringkat fisik di plaza (SurfaceGui) — ikan terberat & total pendapatan koin.
-- Memakai OrderedDataStore, refresh tiap 5 menit. Nonaktif (dengan keterangan) di mode mock.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Util.Format)
local Balance = require(Shared.Config.Balance)
local Theme = require(Shared.Config.Theme)
local DataService = require(script.Parent.DataService)
local WorldService = require(script.Parent.WorldService)

local LeaderboardService = {}

type Board = {
	PointName: string,
	Title: string,
	StoreName: string,
	Rows: { TextLabel },
	Status: TextLabel?,
	Format: (number) -> string,
	Value: (Player) -> number?,
}

local nameCache: { [number]: string } = {}

local function nameOf(userId: number): string
	local cached = nameCache[userId]
	if cached then
		return cached
	end
	local p = Players:GetPlayerByUserId(userId)
	if p then
		nameCache[userId] = p.DisplayName
		return p.DisplayName
	end
	local ok, result = pcall(function(): any
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local name = if ok and type(result) == "string" then result else ("Pemain " .. tostring(userId))
	nameCache[userId] = name
	return name
end

local function label(parent: Instance, text: string, size: number, font: Font, color: Color3, y: number, height: number): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, -48, 0, height)
	l.Position = UDim2.fromOffset(24, y)
	l.FontFace = font
	l.TextSize = size
	l.TextColor3 = color
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = text
	l.Parent = parent
	return l
end

local function buildBoard(board: Board): boolean
	local map = workspace:FindFirstChild("BeachMap")
	local points = map and map:FindFirstChild("Points")
	local part = points and points:FindFirstChild(board.PointName)
	if part == nil or not part:IsA("BasePart") then
		warn("[LeaderboardService] papan " .. board.PointName .. " tidak ditemukan")
		return false
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Leaderboard"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.LightInfluence = 0.2
	gui.MaxDistance = 140

	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Theme.Color.Panel
	bg.BorderSizePixel = 0
	bg.Parent = gui

	label(bg, board.Title, 40, Theme.Font.Display, Theme.Color.Primary, 18, 48)
	local rows: { TextLabel } = {}
	for i = 1, Balance.Leaderboard.Top do
		local row = label(bg, "", 24, Theme.Font.Bold, if i <= 3 then Theme.Color.Text else Theme.Color.TextSecondary, 68 + (i - 1) * 30, 28)
		table.insert(rows, row)
	end
	board.Rows = rows
	board.Status = label(bg, "", 19, Theme.Font.Body, Theme.Color.TextSecondary, 68 + Balance.Leaderboard.Top * 30 + 4, 24)
	gui.Parent = part
	return true
end

local function render(board: Board, entries: { { key: string, value: number } })
	for i, row in board.Rows do
		local e = entries[i]
		if e then
			local uid = tonumber(e.key) or 0
			row.Text = string.format("%d. %s — %s", i, nameOf(uid), board.Format(e.value))
		else
			row.Text = string.format("%d. —", i)
		end
	end
end

local function refresh(board: Board)
	local store = DataStoreService:GetOrderedDataStore(board.StoreName)
	for _, player in Players:GetPlayers() do
		local v = board.Value(player)
		if v and v > 0 then
			pcall(function()
				store:SetAsync(tostring(player.UserId), math.floor(v))
			end)
		end
	end
	local ok, result = pcall(function(): any
		local pages = store:GetSortedAsync(false, Balance.Leaderboard.Top)
		return pages:GetCurrentPage()
	end)
	if ok and type(result) == "table" then
		render(board, result :: any)
		if board.Status then
			(board.Status :: TextLabel).Text = "Diperbarui tiap 5 menit"
		end
	elseif board.Status then
		(board.Status :: TextLabel).Text = "Gagal memuat papan peringkat, dicoba lagi nanti"
	end
end

local boards: { Board } = {
	{
		PointName = "Leaderboard_Heaviest",
		Title = "Ikan Terberat",
		StoreName = "Leaderboard_Heaviest_v1",
		Rows = {},
		Status = nil,
		-- Disimpan sebagai gram (integer) agar presisi terjaga di OrderedDataStore.
		Format = function(v: number): string
			return Format.Kg(v / 1000)
		end,
		Value = function(player: Player): number?
			local data = DataService.GetData(player)
			return if data then data.Stats.HeaviestKg * 1000 else nil
		end,
	},
	{
		PointName = "Leaderboard_Coins",
		Title = "Total Koin",
		StoreName = "Leaderboard_TotalCoins_v1",
		Rows = {},
		Status = nil,
		Format = function(v: number): string
			return Format.Coins(v) .. " koin"
		end,
		Value = function(player: Player): number?
			local data = DataService.GetData(player)
			return if data then data.Stats.TotalEarned else nil
		end,
	},
}

function LeaderboardService.Start()
	task.spawn(function()
		if not WorldService.WaitForMap(180) then
			return
		end
		local built = 0
		for _, board in boards do
			if buildBoard(board) then
				built += 1
			end
		end
		if built == 0 then
			return
		end
		-- Tunggu status DataStore terselesaikan.
		local deadline = os.clock() + 25
		while not DataService.IsMockResolved() and os.clock() < deadline do
			task.wait(0.5)
		end
		if DataService.IsMock() then
			for _, board in boards do
				render(board, {})
				if board.Status then
					(board.Status :: TextLabel).Text = "Aktif setelah game dipublish & API diaktifkan"
				end
			end
			return
		end
		while true do
			for _, board in boards do
				if #board.Rows > 0 then
					refresh(board)
				end
			end
			task.wait(Balance.Leaderboard.RefreshSeconds)
		end
	end)
end

return LeaderboardService
