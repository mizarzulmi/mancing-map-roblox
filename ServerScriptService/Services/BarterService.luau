--!strict
-- BarterService: resep Kakek Bahari (Config/Barter). Server memilih ikan bernilai terendah yang memenuhi syarat
-- (tidak terkunci, bukan Protected), menampilkan pratinjau, lalu saat eksekusi memvalidasi ulang dan menukar
-- tanpa yield di antaranya.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local Guard = require(Shared.Util.Guard)
local Formulas = require(Shared.Formulas)
local Balance = require(Shared.Config.Balance)
local Barter = require(Shared.Config.Barter)
local Fish = require(Shared.Config.Fish)
local NPCs = require(Shared.Config.NPCs)
local Strings = require(Shared.Config.Strings)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local InventoryService = require(script.Parent.InventoryService)
local NPCService = require(script.Parent.NPCService)

type BarterRecipe = Types.BarterRecipe
type FishItem = Types.FishItem

local BarterService = {}

BarterService.Bartered = Signal.new() :: Signal.Signal<Player, string>

local function barterNpcId(): string
	local npc = NPCs.ByRole("Barter")
	return if npc then npc.Id else "kakek_bahari"
end

-- Memeriksa resep untuk pemain. Mengembalikan pratinjau (Ok + daftar ikan) tanpa mengubah data.
local function evaluate(player: Player, recipe: BarterRecipe): Types.BarterPreview
	local data = DataService.GetData(player)
	local empty: Types.BarterPreview = { Ok = false, Reason = Strings.Loading, Fish = {}, Coins = recipe.Coins or 0 }
	if data == nil then
		return empty
	end
	local function fail(reason: string, fish: { FishItem }?): Types.BarterPreview
		return { Ok = false, Reason = reason, Fish = fish or {}, Coins = recipe.Coins or 0 }
	end
	if recipe.Once and data.BarterOnce[recipe.Id] then
		return fail(Strings.BarterOnce)
	end
	if recipe.GiveCosmetic and data.Cosmetics.Owned[recipe.GiveCosmetic] then
		return fail(Strings.BarterOwned)
	end
	if recipe.GiveRod and table.find(data.Rods, recipe.GiveRod) then
		return fail(Strings.BarterOwned)
	end
	if recipe.Level and data.Level < recipe.Level then
		return fail(string.format(Strings.LevelRequired, recipe.Level))
	end
	local chosen = Formulas.SelectBarterFish(data.Fish, recipe, Fish.ById)
	if chosen == nil then
		return fail(Strings.BarterNotEnough)
	end
	if recipe.Coins and data.Coins < recipe.Coins then
		return fail(Strings.NotEnoughCoins, chosen)
	end
	return { Ok = true, Reason = nil, Fish = chosen, Coins = recipe.Coins or 0 }
end

local function execute(player: Player, recipe: BarterRecipe): (boolean, string)
	local preview = evaluate(player, recipe)
	if not preview.Ok then
		return false, preview.Reason or Strings.BarterNotEnough
	end
	local data = DataService.GetData(player)
	if data == nil then
		return false, Strings.Loading
	end
	-- Mulai di sini tidak ada yield sampai selesai.
	if preview.Coins > 0 and not EconomyService.TrySpend(player, preview.Coins, "barter:" .. recipe.Id) then
		return false, Strings.NotEnoughCoins
	end
	local uids: { string } = {}
	for _, item in preview.Fish do
		table.insert(uids, item.Uid)
	end
	local removed = InventoryService.RemoveFish(player, uids)
	if #removed ~= recipe.Count then
		-- Pengaman: kembalikan semua bila ada yang tidak terhapus.
		for _, item in removed do
			InventoryService.AddFish(player, item)
		end
		if preview.Coins > 0 then
			EconomyService.Refund(player, preview.Coins, "barter:" .. recipe.Id)
		end
		return false, "Barter gagal, coba lagi."
	end
	if recipe.GiveBait then
		InventoryService.AddBait(player, recipe.GiveBait, recipe.GiveBaitQty or 1)
	end
	if recipe.GiveRod then
		InventoryService.GiveRod(player, recipe.GiveRod)
	end
	if recipe.GiveCosmetic then
		InventoryService.GiveCosmetic(player, recipe.GiveCosmetic)
	end
	if recipe.Once then
		data.BarterOnce[recipe.Id] = true
		DataService.Replicate(player, "BarterOnce")
	end
	BarterService.Bartered:Fire(player, recipe.Id)
	return true, string.format(Strings.BarterSuccess, recipe.Name)
end

function BarterService.Start()
	Net.OnServerInvoke("BarterPreview", function(player: Player, recipeId: unknown): any
		local id = Guard.Id(recipeId, Barter.ById)
		if id == nil then
			Guard.Reject(player, "BarterPreview", "resep tidak valid")
			return { Ok = false, Reason = "Resep tidak valid.", Fish = {}, Coins = 0 }
		end
		return evaluate(player, Barter.ById[id])
	end)
	Net.OnServerInvoke("BarterExecute", function(player: Player, recipeId: unknown): any
		local id = Guard.Id(recipeId, Barter.ById)
		if id == nil then
			Guard.Reject(player, "BarterExecute", "resep tidak valid")
			return false, "Resep tidak valid."
		end
		local npcId = barterNpcId()
		if not NPCService.IsNear(player, npcId, Balance.NpcInteractRange) then
			local npc = NPCs.Get(npcId)
			return false, string.format(Strings.TooFar, if npc then npc.Name else "Kakek Bahari")
		end
		return execute(player, Barter.ById[id])
	end)
end

return BarterService
