--!strict
-- BagController: panel Tas Ikan (GDD 4.3) dan mode Jual di lapak Bu Rina. Sortir (Terbaru, Harga, Rarity,
-- Berat), filter rarity, kunci ikan, multi-pilih, lepaskan (Poin Konservasi), dan jual terpilih / semua kecuali
-- terkunci / per rarity — selalu dengan konfirmasi total. Harga yang ditampilkan adalah estimasi; server
-- menghitung harga final (termasuk event Musim Ikan).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Net = require(Shared.Net)
local Format = require(Shared.Util.Format)
local Formulas = require(Shared.Formulas)
local Balance = require(Shared.Config.Balance)
local Fish = require(Shared.Config.Fish)
local Zones = require(Shared.Config.Zones)
local Strings = require(Shared.Config.Strings)
local Theme = require(Shared.Config.Theme)
local FishModel = require(Shared.Models.FishModel)
local DataController = require(script.Parent.DataController)
local UIController = require(script.Parent.UIController)
local InputController = require(script.Parent.InputController)
local NotificationController = require(script.Parent.NotificationController)
local UI = script.Parent.Parent:WaitForChild("UI")
local Style = require(UI:WaitForChild("Style"))
local Button = require(UI:WaitForChild("Button"))
local Modal = require(UI:WaitForChild("Modal"))
local Tabs = require(UI:WaitForChild("Tabs"))
local ItemCard = require(UI:WaitForChild("ItemCard"))
local StatRow = require(UI:WaitForChild("StatRow"))
local ConfirmDialog = require(UI:WaitForChild("ConfirmDialog"))
local ViewportPreview = require(UI:WaitForChild("ViewportPreview"))

type FishItem = Types.FishItem
type Mode = "Bag" | "Sell"

local BagController = {}

type View = {
	Mode: Mode,
	NpcId: string?,
	Modal: Modal.Modal,
	Grid: ScrollingFrame,
	Detail: Frame,
	Footer: Frame,
	Sort: string,
	Filter: string,
	Multi: boolean,
	Selected: { [string]: boolean },
	Focus: string?,
	Cards: { ItemCard.ItemCard },
	Preview: ViewportPreview.ViewportPreview?,
}

local view: View? = nil

local function eventMul(): number
	local e = ReplicatedStorage:GetAttribute("Event")
	return Formulas.EventPriceMul(if type(e) == "string" then e else "None")
end

local function priceOf(item: FishItem): number
	local species = Fish.Get(item.SpeciesId)
	if species == nil then
		return 0
	end
	return Formulas.SellPrice(species, item.Weight, item.Mutation, eventMul())
end

local function sellable(item: FishItem): boolean
	local species = Fish.Get(item.SpeciesId)
	return species ~= nil and not item.Locked and not species.Protected
end

local function sortedFish(v: View): { FishItem }
	local data = DataController.Get()
	if data == nil then
		return {}
	end
	local list: { FishItem } = {}
	for _, item in data.Fish do
		local species = Fish.Get(item.SpeciesId)
		if species and (v.Filter == "All" or species.Rarity == v.Filter) then
			table.insert(list, item)
		end
	end
	table.sort(list, function(a, b)
		if v.Sort == "Price" then
			return priceOf(a) > priceOf(b)
		elseif v.Sort == "Weight" then
			return a.Weight > b.Weight
		elseif v.Sort == "Rarity" then
			local ra = Balance.RarityRank[(Fish.Get(a.SpeciesId) :: Types.FishSpecies).Rarity] or 0
			local rb = Balance.RarityRank[(Fish.Get(b.SpeciesId) :: Types.FishSpecies).Rarity] or 0
			if ra ~= rb then
				return ra > rb
			end
			return a.Weight > b.Weight
		end
		return a.CaughtAt > b.CaughtAt
	end)
	return list
end

local function notifyResult(ok: any, msg: any)
	if type(msg) == "string" and msg ~= "" then
		NotificationController.Show(msg, if ok then "Success" else "Warning")
	end
end

local function confirm(title: string, body: string, confirmText: string, variant: Button.Variant, onConfirm: () -> ())
	ConfirmDialog.Show({
		Parent = UIController.Gui("Popup"),
		Title = title,
		Body = body,
		ConfirmText = confirmText,
		CancelText = Strings.Cancel,
		Variant = variant,
		OnConfirm = onConfirm,
	})
end

local function releaseUids(uids: { string })
	local data = DataController.Get()
	if data == nil or #uids == 0 then
		return
	end
	local points = 0
	for _, uid in uids do
		local item = DataController.FindFish(uid)
		local species = item and Fish.Get(item.SpeciesId)
		if species then
			points += Formulas.ConservationPoints(species)
		end
	end
	confirm(Strings.Release, string.format(Strings.ReleaseConfirm, #uids, points), Strings.Release, "Secondary", function()
		local ok, msg = Net.Invoke("ReleaseFish", uids)
		notifyResult(ok, msg)
		if ok and view then
			table.clear((view :: View).Selected)
		end
	end)
end

local function sellUids(v: View, mode: string, arg: any, items: { FishItem })
	local total = 0
	for _, item in items do
		total += priceOf(item)
	end
	if #items == 0 then
		NotificationController.Show(Strings.SellNothing, "Warning")
		return
	end
	local body = string.format(Strings.SellConfirm, #items, Format.Coins(total))
	if eventMul() > 1 then
		body ..= "\n" .. Strings.EventPriceBonus
	end
	confirm(Strings.SellTitle, body, "Jual", "Danger", function()
		local ok, msg = Net.Invoke("SellFish", v.NpcId or "bu_rina", mode, arg)
		notifyResult(ok, msg)
		if ok then
			table.clear(v.Selected)
		end
	end)
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
	local item = if v.Focus then DataController.FindFish(v.Focus :: string) else nil
	local species = item and Fish.Get(item.SpeciesId)
	if item == nil or species == nil then
		Style.Label({
			Text = "Pilih ikan untuk melihat detail.",
			TextSize = Theme.TextSize.Body,
			Color = Theme.Color.TextSecondary,
			Wrap = true,
			AutoSize = "Y",
			Size = UDim2.new(1, 0, 0, 0),
			Parent = detail,
		})
		return
	end
	local fish = item :: FishItem
	local sp = species :: Types.FishSpecies
	v.Preview = ViewportPreview.new({
		Model = FishModel.Build(sp, { Mutation = fish.Mutation, Length = 3 }),
		Size = UDim2.new(1, 0, 0, 140),
		Spin = true,
		LayoutOrder = 1,
		Parent = detail,
	})
	Style.Label({ Text = sp.Name, Font = "Display", TextSize = Theme.TextSize.Heading, Color = Theme.Rarity[sp.Rarity] or Theme.Color.Text, AutoSize = "XY", LayoutOrder = 2, Parent = detail })
	local stats = Style.Frame({ Size = UDim2.new(1, 0, 0, 0), AutoSize = "Y", LayoutOrder = 3, Parent = detail })
	Style.List(stats, "Vertical", Theme.Space.XS)
	StatRow.new({ Label = "Rarity", Value = Balance.RarityLabel[sp.Rarity] or sp.Rarity, Parent = stats, LayoutOrder = 1 })
	StatRow.new({ Label = Strings.Weight, Value = Format.Kg(fish.Weight), Parent = stats, LayoutOrder = 2 })
	if fish.Mutation ~= "None" then
		StatRow.new({ Label = Strings.Mutation, Value = fish.Mutation, Parent = stats, LayoutOrder = 3 })
	end
	StatRow.new({
		Label = Strings.Price,
		Value = if sp.Protected then Strings.Protected else Format.Coins(priceOf(fish)) .. " koin",
		Parent = stats,
		LayoutOrder = 4,
	})
	local zone = Zones.Get(fish.Zone)
	StatRow.new({ Label = "Zona", Value = if zone then zone.Name else fish.Zone, Parent = stats, LayoutOrder = 5 })
	StatRow.new({ Label = "Konservasi", Value = "+" .. tostring(Formulas.ConservationPoints(sp)) .. " poin", Parent = stats, LayoutOrder = 6 })
	if sp.Protected then
		Style.Label({ Text = Strings.ProtectedHint, TextSize = Theme.TextSize.Small, Color = Theme.Color.Success, Wrap = true, AutoSize = "Y", Size = UDim2.new(1, 0, 0, 0), LayoutOrder = 4, Parent = detail })
	end
	local actions = Style.Frame({ Size = UDim2.new(1, 0, 0, 0), AutoSize = "Y", LayoutOrder = 5, Parent = detail })
	Style.List(actions, "Vertical", Theme.Space.S)
	Button.new({
		Text = if fish.Locked then Strings.Unlock else Strings.Lock,
		Variant = "Quiet",
		Icon = "lock",
		Size = UDim2.new(1, 0, 0, Theme.Size.ButtonHeight),
		LayoutOrder = 1,
		Parent = actions,
		OnActivated = function()
			Net.Invoke("SetFishLock", fish.Uid, not fish.Locked)
		end,
	})
	Button.new({
		Text = Strings.Release,
		Variant = if sp.Protected then "Primary" else "Secondary",
		Icon = "leaf",
		Disabled = fish.Locked,
		Size = UDim2.new(1, 0, 0, Theme.Size.ButtonHeight),
		LayoutOrder = 2,
		Parent = actions,
		OnActivated = function()
			releaseUids({ fish.Uid })
		end,
	})
	if v.Mode == "Sell" then
		Button.new({
			Text = "Jual ikan ini",
			Variant = "Danger",
			Icon = "sell",
			Disabled = not sellable(fish),
			Size = UDim2.new(1, 0, 0, Theme.Size.ButtonHeight),
			LayoutOrder = 3,
			Parent = actions,
			OnActivated = function()
				sellUids(v, "Selected", { fish.Uid }, { fish })
			end,
		})
	end
end

local function selectedItems(v: View): ({ string }, { FishItem })
	local uids: { string } = {}
	local items: { FishItem } = {}
	for uid in v.Selected do
		local item = DataController.FindFish(uid)
		if item then
			table.insert(uids, uid)
			table.insert(items, item)
		end
	end
	return uids, items
end

local function renderFooter(v: View)
	local footer = v.Footer
	for _, child in footer:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local uids, items = selectedItems(v)
	Button.new({
		Text = if v.Multi then "Selesai memilih" else Strings.SelectMany,
		Variant = "Quiet",
		LayoutOrder = 1,
		Parent = footer,
		OnActivated = function()
			v.Multi = not v.Multi
			if not v.Multi then
				table.clear(v.Selected)
			end
			render(v)
		end,
	})
	if v.Multi then
		Style.Label({ Text = string.format(Strings.SelectedCount, #uids), Font = "Bold", TextSize = Theme.TextSize.Body, AutoSize = "XY", LayoutOrder = 2, Parent = footer })
		Button.new({
			Text = "Lepaskan terpilih",
			Variant = "Secondary",
			Icon = "leaf",
			Disabled = #uids == 0,
			LayoutOrder = 3,
			Parent = footer,
			OnActivated = function()
				releaseUids(uids)
			end,
		})
	end
	if v.Mode == "Sell" then
		if v.Multi then
			local sellableItems: { FishItem } = {}
			local sellableUids: { string } = {}
			for i, item in items do
				if sellable(item) then
					table.insert(sellableItems, item)
					table.insert(sellableUids, uids[i])
				end
			end
			Button.new({
				Text = Strings.SellSelected,
				Variant = "Danger",
				Icon = "sell",
				Disabled = #sellableUids == 0,
				LayoutOrder = 4,
				Parent = footer,
				OnActivated = function()
					sellUids(v, "Selected", sellableUids, sellableItems)
				end,
			})
		end
		Button.new({
			Text = Strings.SellAll,
			Variant = "Danger",
			Icon = "sell",
			LayoutOrder = 5,
			Parent = footer,
			OnActivated = function()
				local all: { FishItem } = {}
				local data = DataController.Get()
				if data then
					for _, item in data.Fish do
						if sellable(item) then
							table.insert(all, item)
						end
					end
				end
				sellUids(v, "AllUnlocked", nil, all)
			end,
		})
		if v.Filter ~= "All" then
			Button.new({
				Text = "Jual semua " .. (Balance.RarityLabel[v.Filter] or v.Filter),
				Variant = "Danger",
				LayoutOrder = 6,
				Parent = footer,
				OnActivated = function()
					local list: { FishItem } = {}
					local data = DataController.Get()
					if data then
						for _, item in data.Fish do
							local sp = Fish.Get(item.SpeciesId)
							if sp and sp.Rarity == v.Filter and sellable(item) then
								table.insert(list, item)
							end
						end
					end
					sellUids(v, "Rarity", v.Filter, list)
				end,
			})
		end
	end
end

render = function(v: View)
	local data = DataController.Get()
	if data == nil then
		return
	end
	v.Modal:SetSubtitle(string.format("%d/%d ikan%s", #data.Fish, data.BagCapacity, if eventMul() > 1 then " · " .. Strings.EventPriceBonus else ""))
	for _, card in v.Cards do
		card:Destroy()
	end
	table.clear(v.Cards)
	for _, child in v.Grid:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	local list = sortedFish(v)
	local focusValid = false
	for i, item in list do
		local species = Fish.Get(item.SpeciesId) :: Types.FishSpecies
		if v.Focus == item.Uid then
			focusValid = true
		end
		local card = ItemCard.new({
			Title = species.Name,
			Subtitle = Format.Kg(item.Weight) .. (if item.Mutation ~= "None" then " · " .. item.Mutation else ""),
			Price = if species.Protected then nil else priceOf(item),
			Currency = "Coins",
			Status = if item.Locked then "Locked" else "None",
			StatusText = if item.Locked then "Terkunci" elseif species.Protected then Strings.Protected else nil,
			Rarity = species.Rarity,
			Icon = "fish",
			IconColor = species.Primary,
			Selected = (v.Multi and v.Selected[item.Uid] == true) or (not v.Multi and v.Focus == item.Uid),
			Name = "Ikan_" .. item.Uid,
			LayoutOrder = i,
			Parent = v.Grid,
			OnActivated = function()
				if v.Multi then
					if v.Selected[item.Uid] then
						(v.Selected :: any)[item.Uid] = nil
					else
						v.Selected[item.Uid] = true
					end
				end
				v.Focus = item.Uid
				render(v)
			end,
		})
		table.insert(v.Cards, card)
	end
	if #list == 0 then
		Style.Label({
			Name = "Kosong",
			Text = if #data.Fish == 0 then Strings.BagEmpty else "Tidak ada ikan dengan filter ini.",
			TextSize = Theme.TextSize.Body,
			Color = Theme.Color.TextSecondary,
			Wrap = true,
			AutoSize = "Y",
			Size = UDim2.new(1, 0, 0, 0),
			Parent = v.Grid,
		})
	end
	if not focusValid then
		v.Focus = if list[1] then list[1].Uid else nil
	end
	renderDetail(v)
	renderFooter(v)
end

function BagController.Open(mode: Mode?, npcId: string?, multi: boolean?)
	local m: Mode = mode or "Bag"
	local modal = Modal.new({
		Title = if m == "Sell" then Strings.SellTitle else Strings.BagTitle,
		Icon = if m == "Sell" then "sell" else "bag",
		Parent = UIController.Gui("Panel"),
		OnClose = function()
			UIController.ClosePanel()
		end,
	})
	local body = modal.Body
	Style.List(body, "Vertical", Theme.Space.S)

	local v: View = {
		Mode = m,
		NpcId = npcId,
		Modal = modal,
		Grid = nil :: any,
		Detail = nil :: any,
		Footer = modal:GetFooter(),
		Sort = "Newest",
		Filter = "All",
		Multi = multi == true or m == "Sell",
		Selected = {},
		Focus = nil,
		Cards = {},
		Preview = nil,
	}
	Style.List(v.Footer, "Horizontal", Theme.Space.S, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)

	local toolbar = Style.Frame({ Size = UDim2.new(1, 0, 0, 0), AutoSize = "Y", LayoutOrder = 1, Parent = body })
	Style.List(toolbar, "Horizontal", Theme.Space.M, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	Tabs.new({
		Items = {
			{ Id = "Newest", Label = Strings.SortNewest },
			{ Id = "Price", Label = Strings.SortPrice },
			{ Id = "Rarity", Label = Strings.SortRarity },
			{ Id = "Weight", Label = Strings.SortWeight },
		},
		Selected = "Newest",
		LayoutOrder = 1,
		Parent = toolbar,
		OnChanged = function(id: string)
			v.Sort = id
			render(v)
		end,
	})
	local filterItems: { Tabs.TabItem } = { { Id = "All", Label = Strings.FilterAll } }
	for _, r in Balance.RarityOrder do
		table.insert(filterItems, { Id = r, Label = Balance.RarityLabel[r] or r })
	end
	Tabs.new({
		Items = filterItems,
		Selected = "All",
		LayoutOrder = 2,
		Parent = body,
		OnChanged = function(id: string)
			v.Filter = id
			render(v)
		end,
	})

	local content = Style.Frame({ Name = "Konten", Size = UDim2.new(1, 0, 1, -112), LayoutOrder = 3, Parent = body })
	local grid = Style.Scroll({ Name = "Grid", Size = UDim2.new(0.62, -Theme.Space.M, 1, 0), Padding = Theme.Space.XS, Parent = content })
	Style.Grid(grid, UDim2.fromOffset(160, 176), Theme.Space.S)
	local detail = Style.Card({ Name = "Detail", Size = UDim2.new(0.38, 0, 1, 0), Position = UDim2.fromScale(0.62, 0), Parent = content })
	Style.Padding(detail, Theme.Space.M)
	Style.List(detail, "Vertical", Theme.Space.S)
	v.Grid = grid
	v.Detail = detail
	view = v
	render(v)
	UIController.OpenPanel({
		Name = if m == "Sell" then "Sell" else "Bag",
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

function BagController.Start()
	InputController.Hotkey:Connect(function(name)
		if name == "Bag" then
			if UIController.CurrentPanel() == "Bag" then
				UIController.ClosePanel()
			else
				BagController.Open("Bag")
			end
		end
	end)
	DataController.Changed:Connect(function(key)
		local v = view
		if v and key == "Fish" then
			render(v)
		end
	end)
	ReplicatedStorage:GetAttributeChangedSignal("Event"):Connect(function()
		local v = view
		if v then
			render(v)
		end
	end)
end

return BagController
