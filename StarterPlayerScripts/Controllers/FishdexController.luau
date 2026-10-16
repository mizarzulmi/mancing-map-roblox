--!strict
-- FishdexController: panel Fishdex (Prof. Mina). Tab per zona, progres "x/y spesies", hadiah lengkap per zona
-- (diambil di Prof. Mina), per spesies: jumlah, berat terbaik, waktu pertama, petunjuk zona/waktu. Spesies yang
-- belum ditemukan tampil sebagai siluet dengan petunjuk.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Net = require(Shared.Net)
local Format = require(Shared.Util.Format)
local Balance = require(Shared.Config.Balance)
local Fish = require(Shared.Config.Fish)
local Zones = require(Shared.Config.Zones)
local Cosmetics = require(Shared.Config.Cosmetics)
local Strings = require(Shared.Config.Strings)
local Theme = require(Shared.Config.Theme)
local FishModel = require(Shared.Models.FishModel)
local DataController = require(script.Parent.DataController)
local UIController = require(script.Parent.UIController)
local InputController = require(script.Parent.InputController)
local NotificationController = require(script.Parent.NotificationController)
local DialogController = require(script.Parent.DialogController)
local UI = script.Parent.Parent:WaitForChild("UI")
local Style = require(UI:WaitForChild("Style"))
local Button = require(UI:WaitForChild("Button"))
local Modal = require(UI:WaitForChild("Modal"))
local Tabs = require(UI:WaitForChild("Tabs"))
local ItemCard = require(UI:WaitForChild("ItemCard"))
local StatRow = require(UI:WaitForChild("StatRow"))
local ProgressBar = require(UI:WaitForChild("ProgressBar"))
local ViewportPreview = require(UI:WaitForChild("ViewportPreview"))

type FishSpecies = Types.FishSpecies

local FishdexController = {}

type View = {
	Modal: Modal.Modal,
	Zone: string,
	Grid: ScrollingFrame,
	Detail: Frame,
	Header: Frame,
	Selected: string?,
	Cards: { ItemCard.ItemCard },
	Preview: ViewportPreview.ViewportPreview?,
	AtNpc: boolean,
}

local view: View? = nil

local function timeText(s: FishSpecies): string
	local parts: { string } = {}
	table.insert(parts, if s.Time == "Day" then "Siang" elseif s.Time == "Night" then "Malam" else "Kapan saja")
	if s.Weather then
		table.insert(parts, "saat " .. s.Weather)
	end
	if s.Event then
		table.insert(parts, "event " .. (Balance.EventLabel[s.Event :: string] or (s.Event :: string)))
	end
	return table.concat(parts, " · ")
end

local function zoneNames(s: FishSpecies): string
	local names: { string } = {}
	for _, z in s.Zones do
		local def = Zones.Get(z)
		table.insert(names, if def then def.Name else z)
	end
	return table.concat(names, ", ")
end

local render: (View) -> ()

local function renderDetail(v: View)
	local detail = v.Detail
	for _, child in detail:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	if v.Preview then
		(v.Preview :: ViewportPreview.ViewportPreview):Destroy()
		v.Preview = nil
	end
	local data = DataController.Get()
	local species = if v.Selected then Fish.Get(v.Selected :: string) else nil
	if data == nil or species == nil then
		return
	end
	local sp = species :: FishSpecies
	local entry = data.Fishdex[sp.Id]
	local known = entry ~= nil
	v.Preview = ViewportPreview.new({
		Model = FishModel.Build(sp, { Silhouette = not known, Length = 3 }),
		Size = UDim2.new(1, 0, 0, 130),
		Spin = known,
		LayoutOrder = 1,
		Parent = detail,
	})
	Style.Label({
		Text = if known then sp.Name else Strings.FishdexUnknown,
		Font = "Display",
		TextSize = Theme.TextSize.Heading,
		Color = if known then (Theme.Rarity[sp.Rarity] or Theme.Color.Text) else Theme.Color.TextSecondary,
		AutoSize = "XY",
		LayoutOrder = 2,
		Parent = detail,
	})
	local stats = Style.Frame({ Size = UDim2.new(1, 0, 0, 0), AutoSize = "Y", LayoutOrder = 3, Parent = detail })
	Style.List(stats, "Vertical", Theme.Space.XS)
	StatRow.new({ Label = "Rarity", Value = Balance.RarityLabel[sp.Rarity] or sp.Rarity, Parent = stats, LayoutOrder = 1 })
	StatRow.new({ Label = "Zona", Value = zoneNames(sp), Parent = stats, LayoutOrder = 2 })
	StatRow.new({ Label = "Waktu", Value = timeText(sp), Parent = stats, LayoutOrder = 3 })
	if entry then
		local e = entry :: Types.FishdexEntry
		StatRow.new({ Label = "Ditangkap", Value = Format.Int(e.Count) .. "×", Parent = stats, LayoutOrder = 4 })
		StatRow.new({ Label = "Terberat", Value = Format.Kg(e.BestWeight), Parent = stats, LayoutOrder = 5 })
		StatRow.new({ Label = "Pertama", Value = os.date("%d/%m/%Y", e.FirstAt) :: string, Parent = stats, LayoutOrder = 6 })
	end
	Style.Label({
		Text = if known then (sp.Fact or sp.Hint) else ("Petunjuk: " .. sp.Hint),
		TextSize = Theme.TextSize.Small,
		Color = Theme.Color.TextSecondary,
		Wrap = true,
		AutoSize = "Y",
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = 4,
		Parent = detail,
	})
end

local function renderHeader(v: View)
	local header = v.Header
	for _, child in header:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local data = DataController.Get()
	local zone = Zones.Get(v.Zone)
	if data == nil or zone == nil then
		return
	end
	local list = Fish.InZone(v.Zone)
	local found = 0
	for _, s in list do
		if data.Fishdex[s.Id] then
			found += 1
		end
	end
	Style.Label({ Text = string.format(Strings.FishdexProgress, found, #list), Font = "Bold", TextSize = Theme.TextSize.Body, AutoSize = "XY", LayoutOrder = 1, Parent = header })
	ProgressBar.new({ Fill = if #list > 0 then found / #list else 0, Color = Theme.Color.Secondary, Height = 10, Size = UDim2.fromOffset(220, 10), LayoutOrder = 2, Parent = header })
	local title = Cosmetics.Get(zone.FishdexTitle)
	local claimed = data.FishdexClaimed[v.Zone] == true
	local complete = found == #list and #list > 0
	local rewardText = string.format("Hadiah: %s koin + gelar \"%s\"", Format.Coins(zone.FishdexReward), if title then title.Name else "")
	Style.Label({ Text = rewardText, TextSize = Theme.TextSize.Small, Color = Theme.Color.TextSecondary, AutoSize = "XY", LayoutOrder = 3, Parent = header })
	if claimed then
		Style.Label({ Text = Strings.FishdexClaimed, Font = "Bold", TextSize = Theme.TextSize.Small, Color = Theme.Color.Success, AutoSize = "XY", LayoutOrder = 4, Parent = header })
	elseif complete then
		Button.new({
			Text = if v.AtNpc then Strings.FishdexClaim else "Ambil di Prof. Mina",
			Variant = "Primary",
			Disabled = not v.AtNpc,
			LayoutOrder = 4,
			Parent = header,
			OnActivated = function()
				local ok, msg = Net.Invoke("ClaimFishdex", v.Zone)
				NotificationController.Show(if type(msg) == "string" then msg else "", if ok then "Reward" else "Warning")
			end,
		})
	end
end

render = function(v: View)
	local data = DataController.Get()
	if data == nil then
		return
	end
	renderHeader(v)
	for _, c in v.Cards do
		c:Destroy()
	end
	table.clear(v.Cards)
	local list = Fish.InZone(v.Zone)
	table.sort(list, function(a, b)
		local ra, rb = Balance.RarityRank[a.Rarity] or 0, Balance.RarityRank[b.Rarity] or 0
		if ra ~= rb then
			return ra < rb
		end
		return a.Name < b.Name
	end)
	if v.Selected == nil or Fish.Get(v.Selected :: string) == nil or not table.find((Fish.Get(v.Selected :: string) :: FishSpecies).Zones, v.Zone) then
		v.Selected = if list[1] then list[1].Id else nil
	end
	for i, s in list do
		local entry = data.Fishdex[s.Id]
		local card = ItemCard.new({
			Title = if entry then s.Name else Strings.FishdexUnknown,
			Subtitle = if entry then string.format(Strings.FishdexCount, entry.Count) else s.Hint,
			Status = if entry then "Owned" else "None",
			StatusText = if entry then nil else "Belum ditemukan",
			Rarity = if entry then s.Rarity else nil,
			Icon = "fish",
			IconColor = if entry then s.Primary else Color3.fromRGB(11, 36, 45),
			Selected = v.Selected == s.Id,
			LayoutOrder = i,
			Parent = v.Grid,
			OnActivated = function()
				v.Selected = s.Id
				render(v)
			end,
		})
		table.insert(v.Cards, card)
	end
	renderDetail(v)
end

function FishdexController.Open(atNpc: boolean?)
	local modal = Modal.new({
		Title = Strings.FishdexTitle,
		Subtitle = "Catatan Prof. Mina",
		Icon = "book",
		Parent = UIController.Gui("Panel"),
		OnClose = function()
			UIController.ClosePanel()
		end,
	})
	local body = modal.Body
	Style.List(body, "Vertical", Theme.Space.S)
	local tabs: { Tabs.TabItem } = {}
	for _, z in Zones.List do
		table.insert(tabs, { Id = z.Id, Label = z.Name })
	end
	local header = Style.Frame({ Size = UDim2.new(1, 0, 0, 0), AutoSize = "Y", LayoutOrder = 2, Parent = body })
	Style.List(header, "Horizontal", Theme.Space.M, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	local content = Style.Frame({ Size = UDim2.new(1, 0, 1, -120), LayoutOrder = 3, Parent = body })
	local grid = Style.Scroll({ Name = "Grid", Size = UDim2.new(0.62, -Theme.Space.M, 1, 0), Padding = Theme.Space.XS, Parent = content })
	Style.Grid(grid, UDim2.fromOffset(160, 176), Theme.Space.S)
	local detail = Style.Card({ Name = "Detail", Size = UDim2.new(0.38, 0, 1, 0), Position = UDim2.fromScale(0.62, 0), Parent = content })
	Style.Padding(detail, Theme.Space.M)
	Style.List(detail, "Vertical", Theme.Space.S)
	local v: View = {
		Modal = modal,
		Zone = Zones.List[1].Id,
		Grid = grid,
		Detail = detail,
		Header = header,
		Selected = nil,
		Cards = {},
		Preview = nil,
		AtNpc = atNpc == true,
	}
	Tabs.new({
		Items = tabs,
		Selected = v.Zone,
		LayoutOrder = 1,
		Parent = body,
		OnChanged = function(id: string)
			v.Zone = id
			v.Selected = nil
			render(v)
		end,
	})
	view = v
	render(v)
	UIController.OpenPanel({
		Name = "Fishdex",
		Panel = modal :: any,
		OnClosed = function()
			if view == v then
				if v.Preview then
					(v.Preview :: ViewportPreview.ViewportPreview):Destroy()
				end
				view = nil
			end
		end,
	})
end

function FishdexController.Start()
	InputController.Hotkey:Connect(function(name)
		if name == "Fishdex" then
			if UIController.CurrentPanel() == "Fishdex" then
				UIController.ClosePanel()
			else
				FishdexController.Open(false)
			end
		end
	end)
	DialogController.Action:Connect(function(_npcId, action)
		if action == "Fishdex" then
			FishdexController.Open(true)
		end
	end)
	DataController.Changed:Connect(function(key)
		local v = view
		if v and (key == "Fishdex" or key == "FishdexClaimed") then
			render(v)
		end
	end)
end

return FishdexController
