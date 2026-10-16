--!strict
-- QuestService: quest cerita berurutan dari Pak Lurah (diterima saat bicara; hadiah otomatis saat selesai) dan
-- 3 quest harian acak (deterministik per pemain per hari WIB, reset 00:00 WIB). Progres dari Signal service lain.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local Format = require(Shared.Util.Format)
local Formulas = require(Shared.Formulas)
local Balance = require(Shared.Config.Balance)
local Quests = require(Shared.Config.Quests)
local Cosmetics = require(Shared.Config.Cosmetics)
local Strings = require(Shared.Config.Strings)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local InventoryService = require(script.Parent.InventoryService)
local NPCService = require(script.Parent.NPCService)
local LevelService = require(script.Parent.LevelService)
local ConservationService = require(script.Parent.ConservationService)
local FishingService = require(script.Parent.FishingService)
local ShopService = require(script.Parent.ShopService)
local SellService = require(script.Parent.SellService)
local FishdexService = require(script.Parent.FishdexService)
local FerryService = require(script.Parent.FerryService)

type QuestObjective = Types.QuestObjective
type QuestDef = Types.QuestDef

local QuestService = {}

-- (player, questId, kind "Story" | "Daily")
QuestService.QuestCompleted = Signal.new() :: Signal.Signal<Player, string, string>

local QUEST_NPC = "pak_lurah"

-- Event progres yang dikirim handler; objective menentukan apakah event itu dihitung.
type ProgressEvent = {
	Type: string,
	Amount: number,
	Npc: string?,
	Bait: string?,
	Zone: string?,
	Rarity: Types.Rarity?,
	Weight: number?,
	Night: boolean?,
	Mutated: boolean?,
	Protected: boolean?,
	Destination: string?,
	Absolute: number?,
}

local function rank(r: string?): number
	return if r then (Balance.RarityRank[r] or 0) else 0
end

-- Berapa progres yang diberikan event ini untuk objective (0 bila tidak relevan).
local function contribution(o: QuestObjective, e: ProgressEvent): number
	local t = o.Type
	if t == "TalkNpc" then
		return if e.Type == "Talk" and e.Npc == o.Npc then 1 else 0
	elseif t == "BuyBait" then
		return if e.Type == "BuyBait" and (o.Bait == nil or e.Bait == o.Bait) then e.Amount else 0
	elseif t == "BuyCosmetic" then
		return if e.Type == "BuyCosmetic" then 1 else 0
	elseif t == "SellCoins" then
		return if e.Type == "Sell" and (o.Npc == nil or e.Npc == o.Npc) then e.Amount else 0
	elseif t == "Ferry" then
		return if e.Type == "Ferry" and (o.Destination == nil or e.Destination == o.Destination) then 1 else 0
	elseif t == "ReleaseProtected" then
		return if e.Type == "Release" and e.Protected then 1 else 0
	elseif t == "ReleaseFish" then
		return if e.Type == "Release" then 1 else 0
	elseif t == "UseBait" then
		return if e.Type == "UseBait" then 1 else 0
	elseif e.Type == "Catch" then
		if t == "CatchFish" then
			return 1
		elseif t == "CatchInZone" then
			return if e.Zone == o.Zone then 1 else 0
		elseif t == "CatchRarity" then
			return if e.Rarity == o.Rarity then 1 else 0
		elseif t == "CatchRarityAtLeast" then
			return if rank(e.Rarity) >= rank(o.Rarity) then 1 else 0
		elseif t == "CatchWeightAtLeast" then
			return if (e.Weight or 0) >= (o.Weight or math.huge) then 1 else 0
		elseif t == "CatchAtNight" then
			return if e.Night then 1 else 0
		elseif t == "CatchMutated" then
			return if e.Mutated then 1 else 0
		end
	end
	return 0
end

local function grantReward(player: Player, reward: Types.QuestReward, reason: string): string
	local parts: { string } = {}
	if reward.Coins and reward.Coins > 0 then
		EconomyService.Add(player, reward.Coins, reason)
		table.insert(parts, "+" .. Format.Coins(reward.Coins) .. " koin")
	end
	if reward.XP and reward.XP > 0 then
		LevelService.AddXP(player, reward.XP, reason)
		table.insert(parts, "+" .. tostring(reward.XP) .. " XP")
	end
	if reward.ConservationPoints and reward.ConservationPoints > 0 then
		ConservationService.AddPoints(player, reward.ConservationPoints, reason)
		table.insert(parts, "+" .. tostring(reward.ConservationPoints) .. " Poin Konservasi")
	end
	if reward.Title then
		InventoryService.GiveCosmetic(player, reward.Title)
		local title = Cosmetics.Get(reward.Title)
		table.insert(parts, "gelar \"" .. (if title then title.Name else reward.Title) .. "\"")
	end
	return table.concat(parts, " · ")
end

-- Menyelesaikan quest cerita aktif bila progres cukup; langsung menyiapkan quest berikutnya.
local function checkStory(player: Player)
	local data = DataService.GetData(player)
	if data == nil then
		return
	end
	local q = data.Quests
	local def = Quests.StoryAt(q.StoryIndex)
	if def == nil or not q.StoryAccepted then
		return
	end
	if q.StoryProgress >= def.Objective.Count then
		local rewardText = grantReward(player, def.Reward, "quest:" .. def.Id)
		q.StoryIndex += 1
		q.StoryProgress = 0
		q.StoryAccepted = false
		DataService.Replicate(player, "Quests")
		Net.FireClient("Notify", player, "Reward", string.format(Strings.QuestCompleted, def.Title) .. " " .. rewardText)
		QuestService.QuestCompleted:Fire(player, def.Id, "Story")
		if Quests.StoryAt(q.StoryIndex) then
			Net.FireClient("Notify", player, "Info", Strings.QuestNew)
		end
	end
end

local function ensureDaily(player: Player): boolean
	local data = DataService.GetData(player)
	if data == nil then
		return false
	end
	local day = Formulas.WibDayIndex(os.time())
	if data.Quests.DailyDay == day and #data.Quests.Daily > 0 then
		return false
	end
	local ids: { string } = {}
	for _, d in Quests.Daily do
		table.insert(ids, d.Id)
	end
	local picked = Formulas.PickDaily(ids, Balance.DailyCount, (player.UserId % 1000003) * 1000 + day % 1000)
	local list: { Types.DailyQuestState } = {}
	for _, id in picked do
		table.insert(list, { Id = id, Progress = 0, Done = false })
	end
	data.Quests.DailyDay = day
	data.Quests.Daily = list
	DataService.Replicate(player, "Quests")
	return true
end

local function progress(player: Player, e: ProgressEvent)
	local data = DataService.GetData(player)
	if data == nil then
		return
	end
	ensureDaily(player)
	local changed = false
	local q = data.Quests
	local story = Quests.StoryAt(q.StoryIndex)
	if story and q.StoryAccepted then
		if story.Objective.Type == "DiscoverSpecies" then
			if e.Type == "Discover" and e.Absolute then
				q.StoryProgress = math.max(q.StoryProgress, e.Absolute)
				changed = true
			end
		else
			local add = contribution(story.Objective, e)
			if add > 0 then
				q.StoryProgress = math.min(story.Objective.Count, q.StoryProgress + add)
				changed = true
			end
		end
	end
	for _, state in q.Daily do
		local def = Quests.DailyById[state.Id]
		if def and not state.Done then
			local add = contribution(def.Objective, e)
			if add > 0 then
				state.Progress = math.min(def.Objective.Count, state.Progress + add)
				changed = true
				if state.Progress >= def.Objective.Count then
					state.Done = true
					local coins, xp = Formulas.DailyReward(data.Level)
					local text = grantReward(player, { Coins = coins, XP = xp }, "daily:" .. def.Id)
					Net.FireClient("Notify", player, "Reward", string.format(Strings.QuestCompleted, def.Title) .. " " .. text)
					QuestService.QuestCompleted:Fire(player, def.Id, "Daily")
				end
			end
		end
	end
	if changed then
		DataService.Replicate(player, "Quests")
		checkStory(player)
	end
end

-- Pemain menerima quest cerita saat ini di Pak Lurah.
local function accept(player: Player): (boolean, string)
	local data = DataService.GetData(player)
	if data == nil then
		return false, Strings.Loading
	end
	if not NPCService.IsNear(player, QUEST_NPC, Balance.NpcInteractRange) then
		return false, string.format(Strings.TooFar, "Pak Lurah")
	end
	local q = data.Quests
	local def: QuestDef? = Quests.StoryAt(q.StoryIndex)
	if def == nil then
		return false, Strings.QuestAllDone
	end
	if q.StoryAccepted then
		return false, "Quest ini sudah kamu terima."
	end
	if def.Level and data.Level < def.Level then
		return false, string.format(Strings.LevelRequired, def.Level)
	end
	q.StoryAccepted = true
	q.StoryProgress = 0
	local o = def.Objective
	if o.Type == "TalkNpc" and o.Npc == QUEST_NPC then
		-- Bicara dengan Pak Lurah: menerima quest = sudah bicara.
		q.StoryProgress = o.Count
	elseif o.Type == "DiscoverSpecies" then
		q.StoryProgress = math.min(o.Count, FishdexService.DiscoveredCount(player))
	end
	DataService.Replicate(player, "Quests")
	checkStory(player)
	return true, "Quest diterima: " .. def.Title
end

function QuestService.Start()
	Net.OnServerInvoke("AcceptStoryQuest", function(player: Player): any
		return accept(player)
	end)

	NPCService.Talked:Connect(function(player, npcId)
		progress(player, { Type = "Talk", Amount = 1, Npc = npcId })
	end)
	ShopService.Purchased:Connect(function(player, category, itemId, qty)
		if category == "Bait" then
			progress(player, { Type = "BuyBait", Amount = qty, Bait = itemId })
		elseif category == "Cosmetic" then
			progress(player, { Type = "BuyCosmetic", Amount = 1 })
		end
	end)
	FishingService.FishCaught:Connect(function(player, item, species, ctx)
		progress(player, {
			Type = "Catch",
			Amount = 1,
			Zone = item.Zone,
			Rarity = species.Rarity,
			Weight = item.Weight,
			Night = ctx.IsNight,
			Mutated = item.Mutation ~= "None",
		})
	end)
	FishingService.BaitUsed:Connect(function(player)
		progress(player, { Type = "UseBait", Amount = 1 })
	end)
	SellService.Sold:Connect(function(player, coins, _count, npcId)
		progress(player, { Type = "Sell", Amount = coins, Npc = npcId })
	end)
	ConservationService.Released:Connect(function(player, _item, species)
		progress(player, { Type = "Release", Amount = 1, Protected = species.Protected == true })
	end)
	FerryService.Traveled:Connect(function(player, destination)
		progress(player, { Type = "Ferry", Amount = 1, Destination = destination })
	end)
	FishdexService.Discovered:Connect(function(player)
		progress(player, { Type = "Discover", Amount = 1, Absolute = FishdexService.DiscoveredCount(player) })
	end)
	DataService.ProfileLoaded:Connect(function(player)
		ensureDaily(player)
	end)

	-- Pergantian hari WIB untuk pemain yang sedang online.
	task.spawn(function()
		while true do
			task.wait(30)
			for _, player in Players:GetPlayers() do
				if ensureDaily(player) then
					Net.FireClient("Notify", player, "Info", "Quest harian baru tersedia!")
				end
			end
		end
	end)
end

return QuestService
