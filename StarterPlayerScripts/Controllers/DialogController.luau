--!strict
-- DialogController: kotak dialog NPC di bawah layar dengan efek ketik dan pilihan. Dibuka oleh remote OpenNpc
-- (server memicu dari ProximityPrompt). Pilihan memancarkan DialogController.Action(npcId, action, arg) yang
-- didengar controller toko/jual/barter/kapal/Fishdex/quest. Pak Lurah: menerima quest cerita.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local Format = require(Shared.Util.Format)
local TweenUtil = require(Shared.Util.TweenUtil)
local Balance = require(Shared.Config.Balance)
local NPCs = require(Shared.Config.NPCs)
local Quests = require(Shared.Config.Quests)
local Cosmetics = require(Shared.Config.Cosmetics)
local Strings = require(Shared.Config.Strings)
local Theme = require(Shared.Config.Theme)
local DataController = require(script.Parent.DataController)
local UIController = require(script.Parent.UIController)
local NotificationController = require(script.Parent.NotificationController)
local UI = script.Parent.Parent:WaitForChild("UI")
local Style = require(UI:WaitForChild("Style"))
local Button = require(UI:WaitForChild("Button"))

type NpcDef = Types.NpcDef

local DialogController = {}

-- (npcId, action, arg?) — action: "Shop" | "Wardrobe" | "Sell" | "Barter" | "Ferry" | "Fishdex" | "Quest" | "PointsShop" | "Release"
DialogController.Action = Signal.new() :: Signal.Signal<string, string, string?>

local rng = Random.new()
local typing: RBXScriptConnection? = nil

type DialogPanel = {
	Root: Frame,
	Body: TextLabel,
	Choices: Frame,
	Show: (self: DialogPanel) -> (),
	Hide: (self: DialogPanel, instant: boolean?) -> (),
	Destroy: (self: DialogPanel) -> (),
}

local currentPanel: DialogPanel? = nil
local currentNpc: string? = nil

local function stopTyping()
	local t = typing
	typing = nil
	if t then
		t:Disconnect()
	end
end

local function typeText(label: TextLabel, text: string)
	stopTyping()
	label.Text = text
	if TweenUtil.ReducedMotion() then
		label.MaxVisibleGraphemes = -1
		return
	end
	local total = utf8.len(text) or #text
	label.MaxVisibleGraphemes = 0
	local start = os.clock()
	typing = RunService.RenderStepped:Connect(function()
		local shown = math.floor((os.clock() - start) * 55)
		if shown >= total then
			label.MaxVisibleGraphemes = -1
			stopTyping()
		else
			label.MaxVisibleGraphemes = shown
		end
	end)
end

local function makePanel(npc: NpcDef): DialogPanel
	local root = Style.Panel({
		Name = "Dialog_" .. npc.Id,
		Size = UDim2.new(0.92, 0, 0, 0),
		AutoSize = "Y",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -Theme.Space.L),
		Parent = UIController.Gui("Panel"),
	})
	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize = Vector2.new(880, math.huge)
	constraint.Parent = root
	Style.Padding(root, Theme.Space.L, Theme.Space.XL, Theme.Space.L, Theme.Space.XL)
	Style.List(root, "Vertical", Theme.Space.S)
	root.SelectionGroup = true

	local head = Style.Frame({ AutoSize = "XY", LayoutOrder = 1, Parent = root })
	Style.List(head, "Horizontal", Theme.Space.S, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Bottom)
	Style.Label({ Text = npc.Name, Font = "Display", TextSize = Theme.TextSize.Heading, Color = Theme.Color.Primary, AutoSize = "XY", LayoutOrder = 1, Parent = head })
	Style.Label({ Text = npc.Title, Font = "Bold", TextSize = Theme.TextSize.Small, Color = Theme.Color.TextSecondary, AutoSize = "XY", LayoutOrder = 2, Parent = head })

	local body = Style.Label({
		Text = "",
		TextSize = Theme.TextSize.Label,
		Wrap = true,
		AutoSize = "Y",
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = 2,
		Parent = root,
		RichText = true,
	})
	local choices = Style.Frame({ Size = UDim2.new(1, 0, 0, 0), AutoSize = "Y", LayoutOrder = 3, Parent = root })
	local list = Style.List(choices, "Horizontal", Theme.Space.S, Enum.HorizontalAlignment.Right)
	list.Wraps = true

	local panel = {} :: any
	panel.Root = root
	panel.Body = body
	panel.Choices = choices
	function panel.Show(self: DialogPanel)
		root.Visible = true
		local scale = Instance.new("UIScale")
		scale.Scale = if TweenUtil.ReducedMotion() then 1 else 0.96
		scale.Parent = root
		TweenUtil.Play(scale, { Scale = 1 }, Theme.Motion.Duration)
	end
	function panel.Hide(self: DialogPanel, _instant: boolean?)
		stopTyping()
		root.Visible = false
	end
	function panel.Destroy(self: DialogPanel)
		stopTyping()
		root:Destroy()
	end
	return panel :: DialogPanel
end

local function clearChoices(panel: DialogPanel)
	for _, child in panel.Choices:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function addChoice(panel: DialogPanel, text: string, variant: Button.Variant, order: number, onActivated: () -> ())
	Button.new({ Text = text, Variant = variant, LayoutOrder = order, Parent = panel.Choices, OnActivated = onActivated })
end

local function close()
	if currentPanel then
		UIController.ClosePanel()
	end
end

local function act(npcId: string, action: string, arg: string?)
	close()
	DialogController.Action:Fire(npcId, action, arg)
end

local function rewardText(reward: Types.QuestReward): string
	local parts: { string } = {}
	if reward.Coins then
		table.insert(parts, Format.Coins(reward.Coins) .. " koin")
	end
	if reward.XP then
		table.insert(parts, tostring(reward.XP) .. " XP")
	end
	if reward.ConservationPoints then
		table.insert(parts, tostring(reward.ConservationPoints) .. " Poin Konservasi")
	end
	if reward.Title then
		local t = Cosmetics.Get(reward.Title)
		table.insert(parts, "gelar \"" .. (if t then t.Name else reward.Title) .. "\"")
	end
	return table.concat(parts, " · ")
end

local renderQuestNpc: (DialogPanel, NpcDef) -> ()

renderQuestNpc = function(panel: DialogPanel, npc: NpcDef)
	clearChoices(panel)
	local data = DataController.Get()
	if data == nil then
		typeText(panel.Body, npc.Greeting)
		addChoice(panel, Strings.Close, "Quiet", 9, close)
		return
	end
	local q = data.Quests
	local def = Quests.StoryAt(q.StoryIndex)
	if def == nil then
		typeText(panel.Body, npc.Greeting .. "\n" .. Strings.QuestAllDone)
	elseif not q.StoryAccepted then
		local locked = def.Level ~= nil and data.Level < (def.Level :: number)
		local text = string.format(
			"%s\n<b>%s</b> — %s\nHadiah: %s",
			npc.Greeting,
			def.Title,
			def.Description,
			rewardText(def.Reward)
		)
		if locked then
			text ..= "\n" .. string.format(Strings.QuestLocked, def.Level :: number)
		end
		typeText(panel.Body, text)
		if not locked then
			addChoice(panel, Strings.QuestAccept, "Primary", 1, function()
				local ok, msg = Net.Invoke("AcceptStoryQuest")
				NotificationController.Show(if type(msg) == "string" then msg else "", if ok then "Success" else "Warning")
				-- Data diperbarui lewat DataChanged; tampilkan ulang setelah sejenak.
				task.delay(0.25, function()
					if currentPanel == panel then
						renderQuestNpc(panel, npc)
					end
				end)
			end)
		end
	else
		typeText(
			panel.Body,
			string.format(
				"Quest aktif: <b>%s</b>\n%s\nProgres: %s/%s",
				def.Title,
				def.Description,
				Format.Int(q.StoryProgress),
				Format.Int(def.Objective.Count)
			)
		)
	end
	addChoice(panel, "Quest Harian", "Secondary", 2, function()
		act(npc.Id, "Quest", "Daily")
	end)
	addChoice(panel, Strings.Close, "Quiet", 9, close)
end

local function render(panel: DialogPanel, npc: NpcDef)
	clearChoices(panel)
	local role = npc.Role
	if role == "Quest" then
		renderQuestNpc(panel, npc)
		return
	elseif role == "Ambient" then
		local lines = npc.Lines or { "..." }
		typeText(panel.Body, lines[rng:NextInteger(1, #lines)])
	elseif role == "Conservation" then
		local data = DataController.Get()
		typeText(panel.Body, string.format("%s\nPoin Konservasi kamu: <b>%s</b>", npc.Greeting, Format.Int(if data then data.ConservationPoints else 0)))
		addChoice(panel, "Toko Poin", "Primary", 1, function()
			act(npc.Id, "PointsShop")
		end)
		addChoice(panel, "Lepaskan ikan", "Secondary", 2, function()
			act(npc.Id, "Release")
		end)
	elseif role == "FerryOut" then
		local data = DataController.Get()
		local level = if data then data.Level else 1
		local text = npc.Greeting
		if level < Balance.Ferry.Level then
			text ..= "\n" .. string.format(Strings.LevelRequired, Balance.Ferry.Level)
		end
		typeText(panel.Body, text)
		addChoice(panel, string.format(Strings.FerryToDeep, Format.Coins(Balance.Ferry.Price)), "Primary", 1, function()
			act(npc.Id, "Ferry", "DeepSea")
		end)
	elseif role == "FerryBack" then
		typeText(panel.Body, npc.Greeting)
		addChoice(panel, Strings.FerryToShore, "Primary", 1, function()
			act(npc.Id, "Ferry", "Shore")
		end)
	else
		typeText(panel.Body, npc.Greeting)
		if role == "ShopFishing" then
			addChoice(panel, "Lihat toko", "Primary", 1, function()
				act(npc.Id, "Shop")
			end)
		elseif role == "ShopCosmetic" then
			addChoice(panel, "Lihat koleksi", "Primary", 1, function()
				act(npc.Id, "Shop")
			end)
			addChoice(panel, Strings.Wardrobe, "Secondary", 2, function()
				act(npc.Id, "Wardrobe")
			end)
		elseif role == "Buyer" then
			addChoice(panel, "Jual ikan", "Primary", 1, function()
				act(npc.Id, "Sell")
			end)
		elseif role == "Barter" then
			addChoice(panel, "Lihat barter", "Primary", 1, function()
				act(npc.Id, "Barter")
			end)
		elseif role == "Fishdex" then
			addChoice(panel, "Buka Fishdex", "Primary", 1, function()
				act(npc.Id, "Fishdex")
			end)
		end
	end
	addChoice(panel, Strings.Close, "Quiet", 9, close)
end

function DialogController.Open(npcId: string)
	local npc = NPCs.Get(npcId)
	if npc == nil then
		return
	end
	local panel = makePanel(npc)
	currentPanel = panel
	currentNpc = npcId
	render(panel, npc)
	UIController.OpenPanel({
		Name = "Dialog",
		Panel = panel :: any,
		Scrim = false,
		OnClosed = function()
			if currentPanel == panel then
				currentPanel = nil
				currentNpc = nil
			end
		end,
	})
end

function DialogController.CurrentNpc(): string?
	return currentNpc
end

function DialogController.Start()
	Net.OnClientEvent("OpenNpc", function(npcId: unknown)
		if type(npcId) == "string" then
			DialogController.Open(npcId)
		end
	end)
end

return DialogController
