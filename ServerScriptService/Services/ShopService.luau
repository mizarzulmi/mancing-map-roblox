--!strict
-- ShopService: pembelian di Pak Darto (joran, umpan, upgrade tas), Mbak Sari (kosmetik koin), dan Kak Laut
-- (kosmetik Poin Konservasi). Harga selalu dari Config; dicek level, kepemilikan, dan jarak ke NPC (≤ 20 stud);
-- pengurangan mata uang dan pemberian item dilakukan tanpa yield di antaranya.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local Guard = require(Shared.Util.Guard)
local Format = require(Shared.Util.Format)
local Formulas = require(Shared.Formulas)
local Balance = require(Shared.Config.Balance)
local Bags = require(Shared.Config.Bags)
local Rods = require(Shared.Config.Rods)
local Bait = require(Shared.Config.Bait)
local Cosmetics = require(Shared.Config.Cosmetics)
local NPCs = require(Shared.Config.NPCs)
local Strings = require(Shared.Config.Strings)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local InventoryService = require(script.Parent.InventoryService)
local NPCService = require(script.Parent.NPCService)
local ConservationService = require(script.Parent.ConservationService)

local ShopService = {}

-- (player, category, itemId, qty, price, currency)
ShopService.Purchased = Signal.new() :: Signal.Signal<Player, string, string, number, number, string>

local CATEGORIES = { "Rod", "Bait", "Bag", "Cosmetic" }
local BAIT_QTY_ALLOWED: { [number]: boolean } = { [0] = true }
for _, q in Balance.BaitBuyOptions do
	BAIT_QTY_ALLOWED[q] = true
end

local function reasonText(reason: string?, levelNeeded: number?): string
	if reason == "Coins" then
		return Strings.NotEnoughCoins
	elseif reason == "Points" then
		return Strings.NotEnoughPoints
	elseif reason == "Level" then
		return string.format(Strings.LevelRequired, levelNeeded or 1)
	elseif reason == "Owned" then
		return "Sudah kamu miliki."
	elseif reason == "Maxed" then
		return Strings.BagMaxed
	elseif reason == "StackFull" then
		return "Tumpukan umpan sudah penuh (maks " .. tostring(Balance.BaitMaxStack) .. ")."
	end
	return "Barang ini tidak dijual di sini."
end

local function npcSells(npc: Types.NpcDef, category: string, cosmetic: Types.CosmeticDef?): boolean
	if category == "Rod" or category == "Bait" or category == "Bag" then
		return npc.Role == "ShopFishing"
	end
	if category == "Cosmetic" and cosmetic then
		if npc.Role == "ShopCosmetic" then
			return cosmetic.Source == "Shop"
		elseif npc.Role == "Conservation" then
			return cosmetic.Source == "Points"
		end
	end
	return false
end

local function purchase(player: Player, npcIdRaw: unknown, categoryRaw: unknown, itemIdRaw: unknown, qtyRaw: unknown): (boolean, string)
	local npcId = Guard.Id(npcIdRaw, NPCs.ById)
	local category = Guard.OneOf(categoryRaw, CATEGORIES)
	if npcId == nil or category == nil then
		Guard.Reject(player, "Purchase", "npc/kategori tidak valid")
		return false, "Permintaan tidak valid."
	end
	local npc = NPCs.ById[npcId]
	local data = DataService.GetData(player)
	if data == nil then
		return false, Strings.Loading
	end
	if not NPCService.IsNear(player, npcId, Balance.NpcInteractRange) then
		return false, string.format(Strings.TooFar, npc.Name)
	end

	if category == "Rod" then
		local id = Guard.Id(itemIdRaw, Rods.ById)
		if id == nil or not npcSells(npc, category, nil) then
			Guard.Reject(player, "Purchase", "joran tidak valid")
			return false, reasonText(nil)
		end
		local rod = Rods.ById[id]
		local check = Formulas.CheckRodPurchase(data, rod)
		if not check.Ok then
			return false, reasonText(check.Reason, rod.Level)
		end
		if not EconomyService.TrySpend(player, check.Price, "shop:rod:" .. id) then
			return false, Strings.NotEnoughCoins
		end
		InventoryService.GiveRod(player, id)
		ShopService.Purchased:Fire(player, category, id, 1, check.Price, "Coins")
		return true, string.format(Strings.Purchased, rod.Name)
	elseif category == "Bait" then
		local id = Guard.Id(itemIdRaw, Bait.ById)
		local qty = Guard.Int(qtyRaw, 0, Balance.BaitMaxStack)
		if id == nil or qty == nil or not BAIT_QTY_ALLOWED[qty] or not npcSells(npc, category, nil) then
			Guard.Reject(player, "Purchase", "umpan/jumlah tidak valid")
			return false, reasonText(nil)
		end
		local bait = Bait.ById[id]
		local check = Formulas.CheckBaitPurchase(data, bait, qty)
		if not check.Ok then
			return false, reasonText(check.Reason)
		end
		if not EconomyService.TrySpend(player, check.Price, "shop:bait:" .. id) then
			return false, Strings.NotEnoughCoins
		end
		InventoryService.AddBait(player, id, check.Quantity)
		if data.EquippedBait == "" then
			data.EquippedBait = id
			DataService.Replicate(player, "EquippedBait")
		end
		ShopService.Purchased:Fire(player, category, id, check.Quantity, check.Price, "Coins")
		return true, string.format(Strings.Purchased, Format.Int(check.Quantity) .. " " .. bait.Name)
	elseif category == "Bag" then
		if not npcSells(npc, category, nil) then
			return false, reasonText(nil)
		end
		local check = Formulas.CheckBagPurchase(data)
		if not check.Ok then
			return false, reasonText(check.Reason)
		end
		local nextTier = Bags.NextTier(data.BagCapacity) :: Types.BagTier
		if not EconomyService.TrySpend(player, check.Price, "shop:bag:" .. tostring(nextTier.Capacity)) then
			return false, Strings.NotEnoughCoins
		end
		InventoryService.SetBagCapacity(player, nextTier.Capacity)
		ShopService.Purchased:Fire(player, category, tostring(nextTier.Capacity), 1, check.Price, "Coins")
		return true, string.format("Tas sekarang muat %d ikan.", nextTier.Capacity)
	else
		local id = Guard.Id(itemIdRaw, Cosmetics.ById)
		local cosmetic = if id then Cosmetics.ById[id] else nil
		if id == nil or cosmetic == nil or not npcSells(npc, category, cosmetic) then
			Guard.Reject(player, "Purchase", "kosmetik tidak valid")
			return false, reasonText(nil)
		end
		local check = Formulas.CheckCosmeticPurchase(data, cosmetic)
		if not check.Ok then
			return false, reasonText(check.Reason)
		end
		local paid = if check.Currency == "Points"
			then ConservationService.TrySpendPoints(player, check.Price, "shop:cosmetic:" .. id)
			else EconomyService.TrySpend(player, check.Price, "shop:cosmetic:" .. id)
		if not paid then
			return false, reasonText(check.Currency)
		end
		InventoryService.GiveCosmetic(player, id)
		ShopService.Purchased:Fire(player, category, id, 1, check.Price, check.Currency)
		return true, string.format(Strings.Purchased, cosmetic.Name)
	end
end

function ShopService.Start()
	Net.OnServerInvoke("Purchase", function(player: Player, npcId: unknown, category: unknown, itemId: unknown, qty: unknown): any
		return purchase(player, npcId, category, itemId, qty)
	end)
end

return ShopService
