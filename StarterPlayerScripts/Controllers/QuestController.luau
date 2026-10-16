--!strict
-- QuestController: pelacak quest di HUD kanan (bisa dilipat, maks 3 baris), panel Quest (Cerita & Harian),
-- dan tanda "!" di atas Pak Lurah saat ada quest cerita yang siap diterima.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Format = require(Shared.Util.Format)
local Formulas = require(Shared.Formulas)
local Balance = require(Shared.Config.Balance)
local Quests = require(Shared.Config.Quests)
local Cosmetics = require(Shared.Config.Cosmetics)
local Strings = require(Shared.Config.Strings)
local Theme = require(Shared.Config.Theme)
local DataController = require(script.Parent.DataController)
local UIController = require(script.Parent.UIController)
local InputController = require(script.Parent.InputController)
local HUDController = require(script.Parent.HUDController)
local DialogController = require(script.Parent.DialogController)
local UI = script.Parent.Parent:WaitForChild("UI")
local Style = require(UI:WaitForChild("Style"))
local Icon = require(UI:WaitForChild("Icon"))
local Modal = require(UI:WaitForChild("Modal"))
local Tabs = require(UI:WaitForChild("Tabs"))
local ProgressBar = require(UI:WaitForChild("ProgressBar"))

type ProfileData = Types.ProfileData

local QuestController = {}

local trackerBody: Frame? = nil
local collapsed = false
local panelView: { Modal: Modal.Modal, Tab: string, List: ScrollingFrame }? = nil

local function rewardText(reward: Types.QuestReward): string
	local parts: { string } = {}
	if reward.Coins then
		table.insert(parts, Format.Coins(reward.Coins) .. " koin")
	end
	if reward.XP then
		table.insert(parts, tostring(reward.XP) .. " XP")
	end
	if reward.ConservationPoints then
		table.insert(parts, tostring(reward.ConservationPoints) .. " poin")
	end
	if reward.Title then
		local t = Cosmetics.Get(reward.Title)
		table.insert(parts, "gelar \"" .. (if t then t.Name else reward.Title) .. "\"")
	end
	return table.concat(parts, " · ")
end

local function storyAvailable(data: ProfileData): boolean
	local def = Quests.StoryAt(data.Quests.StoryIndex)
	return def ~= nil and not data.Quests.StoryAccepted and (def.Level == nil or data.Level >= (def.Level :: number))
end

-- Tanda "!" di nametag Pak Lurah (hanya tampilan lokal).
local function updateQuestMark()
	local data = DataController.Get()
	local show = data ~= nil and storyAvailable(data)
	for _, model in CollectionService:GetTagged("NPC") do
		if model:GetAttribute("NpcId") == "pak_lurah" then
			local head = model:FindFirstChild("Head")
			local tag = head and head:FindFirstChild("Nametag")
			local mark = tag and tag:FindFirstChild("QuestMark")
			if mark and mark:IsA("TextLabel") then
				mark.Visible = show
			end
		end
	end
end

local function trackerRow(parent: Instance, title: string, progress: number, count: number, order: number, done: boolean?)
	local row = Style.Frame({ Size = UDim2.new(1, 0, 0, 0), AutoSize = "Y", LayoutOrder = order, Parent = parent })
	Style.List(row, "Vertical", 2)
	Style.Label({
		Text = title,
		Font = "Bold",
		TextSize = Theme.TextSize.Small,
		Color = if done then Theme.Color.Success else Theme.Color.Text,
		Wrap = true,
		AutoSize = "Y",
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = 1,
		Parent = row,
	})
	if count > 0 then
		ProgressBar.new({
			Fill = math.clamp(progress / count, 0, 1),
			Color = if done then Theme.Color.Success else Theme.Color.Secondary,
			Height = 8,
			Size = UDim2.new(1, 0, 0, 8),
			Label = string.format("%s/%s", Format.Int(progress), Format.Int(count)),
			LayoutOrder = 2,
			Parent = row,
		})
	end
end

local function renderTracker()
	local body = trackerBody
	local data = DataController.Get()
	if body == nil or data == nil then
		return
	end
	for _, child in body:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	body.Visible = not collapsed
	local rows = 0
	local q = data.Quests
	local story = Quests.StoryAt(q.StoryIndex)
	if story then
		if q.StoryAccepted then
			trackerRow(body, story.Title, q.StoryProgress, story.Objective.Count, 1)
		elseif storyAvailable(data) then
			trackerRow(body, "Temui Pak Lurah: " .. story.Title, 0, 0, 1)
		else
			trackerRow(body, string.format("%s (%s)", story.Title, string.format(Strings.QuestLocked, story.Level or 1)), 0, 0, 1)
		end
		rows += 1
	end
	for _, d in q.Daily do
		if rows >= 3 then
			break
		end
		local def = Quests.DailyById[d.Id]
		if def and not d.Done then
			rows += 1
			trackerRow(body, def.Title, d.Progress, def.Objective.Count, rows)
		end
	end
	if rows == 0 then
		Style.Label({ Text = "Semua quest hari ini selesai!", TextSize = Theme.TextSize.Small, Color = Theme.Color.TextSecondary, AutoSize = "XY", Parent = body })
	end
end

local function buildTracker()
	local right = HUDController.Container("Right")
	local panel = Style.Panel({ Name = "QuestTracker", Size = UDim2.fromOffset(280, 0), AutoSize = "Y", LayoutOrder = 1, Parent = right })
	Style.Padding(panel, Theme.Space.S, Theme.Space.M, Theme.Space.S, Theme.Space.M)
	Style.List(panel, "Vertical", Theme.Space.S)
	local head = Instance.new("TextButton")
	head.Name = "Header"
	head.AutoButtonColor = false
	head.BackgroundTransparency = 1
	head.Text = ""
	head.Size = UDim2.new(1, 0, 0, 32)
	head.LayoutOrder = 1
	local row = Style.Frame({ Size = UDim2.fromScale(1, 1), Parent = head })
	Style.List(row, "Horizontal", Theme.Space.S, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	local ic = Icon.new("scroll", 22, Theme.Color.Primary)
	ic.LayoutOrder = 1
	ic.Parent = row
	Style.Label({ Text = Strings.QuestTracker, Font = "Display", TextSize = Theme.TextSize.Label, AutoSize = "XY", LayoutOrder = 2, Parent = row })
	local chevronHolder = Style.Frame({ Size = UDim2.fromOffset(22, 22), LayoutOrder = 3, Parent = row })
	local function setChevron()
		chevronHolder:ClearAllChildren()
		local c = Icon.new(if collapsed then "chevron_down" else "chevron_up", 20, Theme.Color.TextSecondary)
		c.Parent = chevronHolder
	end
	setChevron()
	head.Activated:Connect(function()
		collapsed = not collapsed
		setChevron()
		renderTracker()
	end)
	head.Parent = panel
	local body = Style.Frame({ Name = "Body", Size = UDim2.new(1, 0, 0, 0), AutoSize = "Y", LayoutOrder = 2, Parent = panel })
	Style.List(body, "Vertical", Theme.Space.S)
	trackerBody = body
end

local function questCard(parent: Instance, title: string, desc: string, reward: string, progress: number?, count: number?, state: string, order: number)
	local card = Style.Card({ Size = UDim2.new(1, 0, 0, 0), AutoSize = "Y", LayoutOrder = order, Parent = parent })
	Style.Padding(card, Theme.Space.M)
	Style.List(card, "Vertical", Theme.Space.XS)
	local head = Style.Frame({ Size = UDim2.new(1, 0, 0, 0), AutoSize = "Y", LayoutOrder = 1, Parent = card })
	Style.List(head, "Horizontal", Theme.Space.S, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	Style.Label({ Text = title, Font = "Bold", TextSize = Theme.TextSize.Label, AutoSize = "XY", LayoutOrder = 1, Parent = head })
	Style.Label({
		Text = state,
		Font = "Bold",
		TextSize = Theme.TextSize.Small,
		Color = if state == "Selesai" then Theme.Color.Success elseif state == "Aktif" then Theme.Color.TealText else Theme.Color.TextSecondary,
		AutoSize = "XY",
		LayoutOrder = 2,
		Parent = head,
	})
	Style.Label({ Text = desc, TextSize = Theme.TextSize.Small, Color = Theme.Color.TextSecondary, Wrap = true, AutoSize = "Y", Size = UDim2.new(1, 0, 0, 0), LayoutOrder = 2, Parent = card })
	if progress and count and count > 0 then
		ProgressBar.new({
			Fill = math.clamp(progress / count, 0, 1),
			Color = Theme.Color.Secondary,
			Height = 10,
			Size = UDim2.new(1, 0, 0, 10),
			Label = string.format("%s/%s", Format.Int(progress), Format.Int(count)),
			LayoutOrder = 3,
			Parent = card,
		})
	end
	Style.Label({ Text = Strings.Reward .. ": " .. reward, TextSize = Theme.TextSize.Small, Color = Theme.Color.Primary, Wrap = true, AutoSize = "Y", Size = UDim2.new(1, 0, 0, 0), LayoutOrder = 4, Parent = card })
end

local function renderPanel()
	local pv = panelView
	local data = DataController.Get()
	if pv == nil or data == nil then
		return
	end
	local list = pv.List
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local q = data.Quests
	if pv.Tab == "Story" then
		for i, def in Quests.Story do
			local state: string
			if i < q.StoryIndex then
				state = "Selesai"
			elseif i == q.StoryIndex then
				state = if q.StoryAccepted then "Aktif" elseif def.Level and data.Level < def.Level then string.format(Strings.QuestLocked, def.Level) else "Temui Pak Lurah"
			else
				state = if def.Level then string.format(Strings.QuestLocked, def.Level) else "Berikutnya"
			end
			questCard(list, string.format("%d. %s", i, def.Title), def.Description, rewardText(def.Reward), if i == q.StoryIndex and q.StoryAccepted then q.StoryProgress else nil, def.Objective.Count, state, i)
		end
	else
		local coins, xp = Formulas.DailyReward(data.Level)
		local now = math.floor(workspace:GetServerTimeNow())
		local nextReset = (Formulas.WibDayIndex(now) + 1) * 86400 - Balance.WibOffsetSeconds
		Style.Label({
			Text = string.format("%s · sisa %s", Strings.DailyReset, Format.Duration(nextReset - now)),
			TextSize = Theme.TextSize.Small,
			Color = Theme.Color.TextSecondary,
			AutoSize = "XY",
			LayoutOrder = 0,
			Parent = list,
		})
		for i, d in q.Daily do
			local def = Quests.DailyById[d.Id]
			if def then
				questCard(list, def.Title, "Quest harian", string.format("%s koin · %d XP", Format.Coins(coins), xp), d.Progress, def.Objective.Count, if d.Done then "Selesai" else "Aktif", i)
			end
		end
	end
end

function QuestController.Open(tab: string?)
	local modal = Modal.new({
		Title = Strings.QuestTitle,
		Icon = "scroll",
		MaxSize = Vector2.new(720, 640),
		Parent = UIController.Gui("Panel"),
		OnClose = function()
			UIController.ClosePanel()
		end,
	})
	local body = modal.Body
	Style.List(body, "Vertical", Theme.Space.S)
	local list = Style.Scroll({ Name = "Daftar", Size = UDim2.new(1, 0, 1, -64), Padding = Theme.Space.XS, LayoutOrder = 2, Parent = body })
	Style.List(list, "Vertical", Theme.Space.S)
	local pv = { Modal = modal, Tab = if tab == "Daily" then "Daily" else "Story", List = list }
	Tabs.new({
		Items = { { Id = "Story", Label = Strings.QuestStory }, { Id = "Daily", Label = Strings.QuestDaily } },
		Selected = pv.Tab,
		LayoutOrder = 1,
		Parent = body,
		OnChanged = function(id: string)
			pv.Tab = id
			renderPanel()
		end,
	})
	panelView = pv
	renderPanel()
	UIController.OpenPanel({
		Name = "Quest",
		Panel = modal :: any,
		OnClosed = function()
			if panelView == pv then
				panelView = nil
			end
		end,
	})
end

function QuestController.Init()
	buildTracker()
end

function QuestController.Start()
	DataController.Observe({ "Quests", "Level" }, function()
		renderTracker()
		updateQuestMark()
		renderPanel()
	end)
	CollectionService:GetInstanceAddedSignal("NPC"):Connect(function()
		task.delay(1, updateQuestMark)
	end)
	InputController.Hotkey:Connect(function(name)
		if name == "Quest" then
			if UIController.CurrentPanel() == "Quest" then
				UIController.ClosePanel()
			else
				QuestController.Open("Story")
			end
		end
	end)
	DialogController.Action:Connect(function(_npcId, action, arg)
		if action == "Quest" then
			QuestController.Open(arg)
		end
	end)
end

return QuestController
