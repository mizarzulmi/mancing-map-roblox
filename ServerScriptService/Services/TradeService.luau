--!strict
-- TradeService: trade antar pemain (GDD 4.5). Undangan dari menu "Pemain di Sekitar" (≤ 30 stud) atau
-- ProximityPrompt "Ajak Tukar" di karakter (disembunyikan client di karakter sendiri). Undangan kedaluwarsa
-- 20 dtk; cooldown 10 dtk. Bisa ditukar: ikan (maks 8, bukan Protected/terkunci), umpan, koin.
-- Setiap perubahan isi mereset Siap; keduanya Siap → hitung mundur 5 dtk → validasi ulang → tukar atomik
-- (tanpa yield) → simpan kedua profil → log. Batal bila keluar, menjauh > 50 stud, atau mulai memancing.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local Net = require(Shared.Net)
local Guard = require(Shared.Util.Guard)
local Format = require(Shared.Util.Format)
local Formulas = require(Shared.Formulas)
local TradeLogic = require(Shared.TradeLogic)
local Balance = require(Shared.Config.Balance)
local Fish = require(Shared.Config.Fish)
local Bait = require(Shared.Config.Bait)
local Strings = require(Shared.Config.Strings)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local InventoryService = require(script.Parent.InventoryService)
local FishingService = require(script.Parent.FishingService)

type FishItem = Types.FishItem
type TradeOffer = Types.TradeOffer

type Invite = { Id: string, From: Player, To: Player, ExpiresAt: number }
type Trade = { Session: TradeLogic.Session, A: Player, B: Player, Executing: boolean }

local TradeService = {}

local T = Balance.Trade
local invites: { [string]: Invite } = {}
local lastInviteAt: { [Player]: number } = {}
local tradeOf: { [Player]: Trade } = {}

local REASON_TEXT: { [string]: string } = {
	TooManyFish = "Maksimal " .. tostring(Balance.Trade.MaxFish) .. " ikan per pertukaran.",
	NotOwned = "Ada ikan yang bukan milikmu.",
	Duplicate = "Ikan yang sama dipilih dua kali.",
	Locked = "Ikan terkunci tidak bisa ditukar.",
	Protected = "Ikan dilindungi tidak bisa ditukar.",
	BadQuantity = "Jumlah tidak valid.",
	NotEnoughBait = "Umpanmu tidak cukup.",
	NotEnoughCoins = "Koinmu tidak cukup.",
	BagFull = "Tas salah satu pemain akan penuh.",
	StackFull = "Tumpukan umpan salah satu pemain akan melebihi batas.",
}

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function reasonText(reason: string?): string
	if reason == nil then
		return "Pertukaran tidak valid."
	end
	local key = string.match(reason, "^[AB]:(.+)$") or reason
	return REASON_TEXT[key] or "Pertukaran tidak valid."
end

local function rootPos(player: Player): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.Position
	end
	return nil
end

local function distanceBetween(a: Player, b: Player): number
	local pa, pb = rootPos(a), rootPos(b)
	if pa == nil or pb == nil then
		return math.huge
	end
	return (pa - pb).Magnitude
end

local function inventoryOf(player: Player): Formulas.TradeInventory?
	local data = DataService.GetData(player)
	if data == nil then
		return nil
	end
	return { Fish = data.Fish, Bait = data.Bait, Coins = data.Coins, BagCapacity = data.BagCapacity }
end

local function sideOf(trade: Trade, player: Player): TradeLogic.Side
	return if trade.A == player then "A" else "B"
end

local function offeredItems(player: Player, offer: TradeOffer): { FishItem }
	local out: { FishItem } = {}
	local data = DataService.GetData(player)
	if data == nil then
		return out
	end
	local byUid: { [string]: FishItem } = {}
	for _, item in data.Fish do
		byUid[item.Uid] = item
	end
	for _, uid in offer.Fish do
		local item = byUid[uid]
		if item then
			table.insert(out, item)
		end
	end
	return out
end

local function sideView(player: Player, offer: TradeOffer, ready: boolean): Types.TradeSide
	local inv = inventoryOf(player)
	local value = if inv then Formulas.OfferValue(inv, offer, Fish.ById, Bait.ById) else 0
	return {
		UserId = player.UserId,
		Name = player.DisplayName,
		Offer = offer,
		Ready = ready,
		Value = value,
		FishItems = offeredItems(player, offer),
	}
end

local function buildView(trade: Trade): Types.TradeView
	local s = trade.Session
	local a = sideView(trade.A, s.Offers.A, s.Ready.A)
	local b = sideView(trade.B, s.Offers.B, s.Ready.B)
	return {
		Id = s.Id,
		A = a,
		B = b,
		CountdownEndsAt = s.CountdownEndsAt,
		Warning = if Formulas.IsTradeUnfair(a.Value, b.Value) then Strings.TradeUnfair else nil,
	}
end

local function broadcast(trade: Trade, kind: string)
	local view = buildView(trade)
	Net.FireClient("TradeEvent", trade.A, kind, view)
	Net.FireClient("TradeEvent", trade.B, kind, view)
end

local function endTrade(trade: Trade)
	if tradeOf[trade.A] == trade then
		tradeOf[trade.A] = nil
	end
	if tradeOf[trade.B] == trade then
		tradeOf[trade.B] = nil
	end
end

local function cancelTrade(trade: Trade, reason: string)
	endTrade(trade)
	for _, p in { trade.A, trade.B } do
		if p.Parent == Players then
			Net.FireClient("TradeEvent", p, "Cancelled", { Reason = reason })
		end
	end
end

function TradeService.IsTrading(player: Player): boolean
	return tradeOf[player] ~= nil
end

-- =========================================================================
-- Undangan
-- =========================================================================

local function invite(from: Player, to: Player): (boolean, string)
	if from == to then
		return false, "Tidak bisa bertukar dengan diri sendiri."
	end
	if not DataService.IsLoaded(from) or not DataService.IsLoaded(to) then
		return false, Strings.Loading
	end
	if tradeOf[from] or tradeOf[to] then
		return false, "Salah satu pemain sedang bertukar."
	end
	local now = serverNow()
	local last = lastInviteAt[from]
	if last ~= nil and now - last < T.InviteCooldown then
		return false, string.format("Tunggu %d detik sebelum mengajak lagi.", math.ceil(T.InviteCooldown - (now - last)))
	end
	if distanceBetween(from, to) > T.InviteRange then
		return false, "Terlalu jauh. Dekati pemain itu (≤ 30 stud)."
	end
	for id, inv in invites do
		if inv.From == from and inv.To == to then
			invites[id] = nil
		end
	end
	local inviteRecord: Invite = { Id = HttpService:GenerateGUID(false), From = from, To = to, ExpiresAt = now + T.InviteExpire }
	invites[inviteRecord.Id] = inviteRecord
	lastInviteAt[from] = now
	Net.FireClient("TradeEvent", to, "Invite", {
		InviteId = inviteRecord.Id,
		FromUserId = from.UserId,
		FromName = from.DisplayName,
		ExpiresAt = inviteRecord.ExpiresAt,
	})
	return true, "Ajakan tukar terkirim ke " .. to.DisplayName .. "."
end

local function respond(player: Player, inviteIdRaw: unknown, acceptRaw: unknown): (boolean, string)
	local inviteId = Guard.Str(inviteIdRaw, 64)
	local accept = Guard.Bool(acceptRaw)
	if inviteId == nil or accept == nil then
		Guard.Reject(player, "TradeRespond", "argumen tidak valid")
		return false, "Permintaan tidak valid."
	end
	local inv = invites[inviteId]
	if inv == nil or inv.To ~= player then
		return false, "Ajakan tidak ditemukan atau sudah kedaluwarsa."
	end
	invites[inviteId] = nil
	if serverNow() > inv.ExpiresAt then
		return false, "Ajakan sudah kedaluwarsa."
	end
	if not accept then
		if inv.From.Parent == Players then
			Net.FireClient("Notify", inv.From, "Info", player.DisplayName .. " menolak ajakan tukar.")
		end
		return true, "Ajakan ditolak."
	end
	if inv.From.Parent ~= Players then
		return false, "Pemain itu sudah keluar."
	end
	if tradeOf[inv.From] or tradeOf[player] then
		return false, "Salah satu pemain sedang bertukar."
	end
	if distanceBetween(inv.From, player) > T.CancelDistance then
		return false, "Terlalu jauh untuk bertukar."
	end
	local trade: Trade = {
		Session = TradeLogic.New(HttpService:GenerateGUID(false)),
		A = inv.From,
		B = player,
		Executing = false,
	}
	tradeOf[trade.A] = trade
	tradeOf[trade.B] = trade
	FishingService.Cancel(trade.A, "Memancing dihentikan untuk bertukar.")
	FishingService.Cancel(trade.B, "Memancing dihentikan untuk bertukar.")
	broadcast(trade, "Open")
	return true, "Pertukaran dimulai."
end

-- =========================================================================
-- Isi penawaran & Siap
-- =========================================================================

local function parseOffer(raw: unknown): TradeOffer?
	if typeof(raw) ~= "table" then
		return nil
	end
	local t = raw :: { [any]: any }
	local fish: { string }
	if t.Fish == nil or (typeof(t.Fish) == "table" and next(t.Fish) == nil) then
		fish = {}
	else
		local list = Guard.StrList(t.Fish, T.MaxFish, 64)
		if list == nil then
			return nil
		end
		fish = list
	end
	local bait: { [string]: number }
	if t.Bait == nil or (typeof(t.Bait) == "table" and next(t.Bait) == nil) then
		bait = {}
	else
		local map = Guard.IntMap(t.Bait, 10, Bait.ById, Balance.BaitMaxStack)
		if map == nil then
			return nil
		end
		bait = map
	end
	local coins = Guard.Int(if t.Coins == nil then 0 else t.Coins, 0, T.MaxCoins)
	if coins == nil then
		return nil
	end
	return { Fish = fish, Bait = bait, Coins = coins }
end

local function updateOffer(player: Player, raw: unknown): (boolean, string)
	local trade = tradeOf[player]
	if trade == nil or trade.Executing then
		return false, "Tidak sedang bertukar."
	end
	local offer = parseOffer(raw)
	if offer == nil then
		Guard.Reject(player, "TradeUpdateOffer", "penawaran tidak valid")
		return false, "Penawaran tidak valid."
	end
	local inv = inventoryOf(player)
	if inv == nil then
		return false, Strings.Loading
	end
	local ok, reason = Formulas.ValidateOffer(inv, offer, Fish.ById)
	if not ok then
		return false, reasonText(reason)
	end
	if TradeLogic.SetOffer(trade.Session, sideOf(trade, player), offer) then
		broadcast(trade, "State")
	end
	return true, ""
end

local function setReady(player: Player, readyRaw: unknown): (boolean, string)
	local ready = Guard.Bool(readyRaw)
	local trade = tradeOf[player]
	if ready == nil then
		Guard.Reject(player, "TradeSetReady", "argumen tidak valid")
		return false, "Permintaan tidak valid."
	end
	if trade == nil or trade.Executing then
		return false, "Tidak sedang bertukar."
	end
	TradeLogic.SetReady(trade.Session, sideOf(trade, player), ready, serverNow())
	broadcast(trade, "State")
	return true, ""
end

-- =========================================================================
-- Eksekusi atomik
-- =========================================================================

local function summarize(offer: TradeOffer, items: { FishItem }): string
	local parts: { string } = {}
	for _, item in items do
		local species = Fish.Get(item.SpeciesId)
		table.insert(parts, (if species then species.Name else item.SpeciesId) .. " " .. Format.Kg(item.Weight))
	end
	for baitId, qty in offer.Bait do
		local def = Bait.Get(baitId)
		table.insert(parts, tostring(qty) .. "× " .. (if def then def.Name else baitId))
	end
	if offer.Coins > 0 then
		table.insert(parts, Format.Coins(offer.Coins) .. " koin")
	end
	local s = table.concat(parts, ", ")
	return if s == "" then "-" else string.sub(s, 1, 180)
end

local function pushLog(player: Player, entry: Types.TradeLogEntry)
	local data = DataService.GetData(player)
	if data == nil then
		return
	end
	table.insert(data.TradeLog, entry)
	while #data.TradeLog > Balance.TradeLogSize do
		table.remove(data.TradeLog, 1)
	end
	DataService.Replicate(player, "TradeLog")
end

local function execute(trade: Trade)
	trade.Executing = true
	local s = trade.Session
	local A, B = trade.A, trade.B
	local invA, invB = inventoryOf(A), inventoryOf(B)
	if invA == nil or invB == nil then
		cancelTrade(trade, "Data pemain tidak siap.")
		return
	end
	local offerA, offerB = s.Offers.A, s.Offers.B
	local ok, reason = Formulas.ValidateTrade(invA, offerA, invB, offerB, Fish.ById)
	if not ok then
		cancelTrade(trade, reasonText(reason))
		return
	end
	-- Mulai di sini tidak ada yield sampai pertukaran selesai.
	local fishA = InventoryService.RemoveFish(A, offerA.Fish)
	local fishB = InventoryService.RemoveFish(B, offerB.Fish)
	for _, item in fishB do
		item.Locked = false
		InventoryService.AddFish(A, item)
	end
	for _, item in fishA do
		item.Locked = false
		InventoryService.AddFish(B, item)
	end
	for baitId, qty in offerA.Bait do
		if qty > 0 and InventoryService.ConsumeBait(A, baitId, qty) then
			InventoryService.AddBait(B, baitId, qty)
		end
	end
	for baitId, qty in offerB.Bait do
		if qty > 0 and InventoryService.ConsumeBait(B, baitId, qty) then
			InventoryService.AddBait(A, baitId, qty)
		end
	end
	local reasonTag = "trade:" .. s.Id
	if offerA.Coins > 0 and EconomyService.TrySpend(A, offerA.Coins, reasonTag) then
		EconomyService.Add(B, offerA.Coins, reasonTag)
	end
	if offerB.Coins > 0 and EconomyService.TrySpend(B, offerB.Coins, reasonTag) then
		EconomyService.Add(A, offerB.Coins, reasonTag)
	end
	local gaveA = summarize(offerA, fishA)
	local gaveB = summarize(offerB, fishB)
	local t = os.time()
	pushLog(A, { Id = s.Id, T = t, With = B.UserId, Gave = gaveA, Got = gaveB })
	pushLog(B, { Id = s.Id, T = t, With = A.UserId, Gave = gaveB, Got = gaveA })
	endTrade(trade)
	DataService.Save(A)
	DataService.Save(B)
	print(string.format("[Trade] %s | %d memberi [%s] | %d memberi [%s]", s.Id, A.UserId, gaveA, B.UserId, gaveB))
	Net.FireClient("TradeEvent", A, "Completed", { Id = s.Id })
	Net.FireClient("TradeEvent", B, "Completed", { Id = s.Id })
end

-- Satu loop untuk semua trade & undangan.
local accumulator = 0
local function step()
	local now = serverNow()
	for id, inv in invites do
		if now > inv.ExpiresAt or inv.From.Parent ~= Players or inv.To.Parent ~= Players then
			invites[id] = nil
		end
	end
	local seen: { [Trade]: boolean } = {}
	for _, trade in tradeOf do
		if not seen[trade] then
			seen[trade] = true
			if not trade.Executing then
				if trade.A.Parent ~= Players or trade.B.Parent ~= Players then
					cancelTrade(trade, "Pemain lain keluar.")
				elseif distanceBetween(trade.A, trade.B) > T.CancelDistance then
					cancelTrade(trade, "Kalian terlalu jauh (> 50 stud).")
				elseif TradeLogic.ShouldExecute(trade.Session, now) then
					execute(trade)
				end
			end
		end
	end
end

local function addPrompt(player: Player, character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if root == nil or not root:IsA("BasePart") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TradePrompt"
	prompt.ActionText = Strings.TradeInvite
	prompt.ObjectText = player.DisplayName
	prompt.KeyboardKeyCode = Enum.KeyCode.T
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonY
	prompt.HoldDuration = 0.25
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	prompt:SetAttribute("OwnerUserId", player.UserId)
	prompt.Triggered:Connect(function(triggerer: Player)
		if triggerer ~= player then
			local _, msg = invite(triggerer, player)
			Net.FireClient("Notify", triggerer, "Info", msg)
		end
	end)
	prompt.Parent = root
end

function TradeService.Start()
	Net.OnServerInvoke("TradeInvite", function(player: Player, targetUserId: unknown): any
		local uid = Guard.Int(targetUserId, 1, 2 ^ 53)
		local target = if uid then Players:GetPlayerByUserId(uid) else nil
		if target == nil then
			Guard.Reject(player, "TradeInvite", "target tidak valid")
			return false, "Pemain tidak ditemukan."
		end
		return invite(player, target)
	end)
	Net.OnServerInvoke("TradeRespond", function(player: Player, inviteId: unknown, accept: unknown): any
		return respond(player, inviteId, accept)
	end)
	Net.OnServerInvoke("TradeUpdateOffer", function(player: Player, offer: unknown): any
		return updateOffer(player, offer)
	end)
	Net.OnServerInvoke("TradeSetReady", function(player: Player, ready: unknown): any
		return setReady(player, ready)
	end)
	Net.OnServerInvoke("TradeCancel", function(player: Player): any
		local trade = tradeOf[player]
		if trade == nil or trade.Executing then
			return false, "Tidak sedang bertukar."
		end
		cancelTrade(trade, player.DisplayName .. " membatalkan.")
		return true, ""
	end)

	FishingService.CastStarted:Connect(function(player)
		local trade = tradeOf[player]
		if trade and not trade.Executing then
			cancelTrade(trade, player.DisplayName .. " mulai memancing.")
		end
	end)

	local function bind(player: Player)
		player.CharacterAdded:Connect(function(character)
			addPrompt(player, character)
		end)
		if player.Character then
			task.spawn(addPrompt, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(bind)
	for _, player in Players:GetPlayers() do
		bind(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local trade = tradeOf[player]
		if trade and not trade.Executing then
			cancelTrade(trade, player.DisplayName .. " keluar dari game.")
		end
		lastInviteAt[player] = nil
	end)

	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator >= 0.2 then
			accumulator = 0
			step()
		end
	end)
end

return TradeService
