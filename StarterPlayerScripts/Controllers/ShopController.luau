--!strict
-- ShopController: panel toko (GDD Bagian 6) untuk Pak Darto (Joran, Umpan, Tas), Mbak Sari (kosmetik koin),
-- Kak Laut (kosmetik Poin Konservasi), dan Lemari Kosmetik (equip semua slot). Header NPC + saldo, tab
-- kategori, grid ItemCard (nama, harga, status Dimiliki/Dipakai/Terkunci Lv X), panel detail dengan pratinjau
-- 3D berputar, perbandingan stat terhadap yang dipakai (naik hijau, turun merah), pemilih jumlah umpan,
-- tombol Beli/Pakai. Harga di sini hanya tampilan; server memutuskan.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Net = require(Shared.Net)
local Format = require(Shared.Util.Format)
local Balance = require(Shared.Config.Balance)
local Bags = require(Shared.Config.Bags)
local Rods = require(Shared.Config.Rods)
local Bait = require(Shared.Config.Bait)
local Cosmetics = require(Shared.Config.Cosmetics)
local NPCs = require(Shared.Config.NPCs)
local Strings = require(Shared.Config.Strings)
local Theme = require(Shared.Config.Theme)
local RodModel = require(Shared.Models.RodModel)
local CosmeticModels = require(Shared.Models.CosmeticModels)
local DataController = require(script.Parent.DataController)
local UIController = require(script.Parent.UIController)
local InputController = require(script.Parent.InputController)
local NotificationController = require(script.Parent.NotificationController)
local DialogController = require(script.Parent.DialogController)
local UI = script.Parent.Parent:WaitForChild("UI")
local Style = require(UI:WaitForChild("Style"))
local Icon = require(UI:WaitForChild("Icon"))
local Button = require(UI:WaitForChild("Button"))
local Modal = require(UI:WaitForChild("Modal"))
local Tabs = require(UI:WaitForChild("Tabs"))
local ItemCard = require(UI:WaitForChild("ItemCard"))
local StatRow = require(UI:WaitForChild("StatRow"))
local QuantityPicker = require(UI:WaitForChild("QuantityPicker"))
local ViewportPreview = require(UI:WaitForChild("ViewportPreview"))

type ProfileData = Types.ProfileData
type Mode = "Shop" | "Wardrobe" | "Points"

type Entry = {
	Id: string,
	Title: string,
	Subtitle: string?,
	Price: number?,
	Currency: ("Coins" | "Points")?,
	Status: ItemCard.CardStatus,
	StatusText: string?,
	Rarity: string?,
	Icon: Icon.IconName?,
	IconColor: Color3?,
	Preview: (() -> Model?)?,
	Description: string,
	Stats: (Frame) -> (),
	Action: { Text: string, Variant: Button.Variant, Enabled: boolean, Run: (qty: number) -> () }?,
	Quantity: boolean?,
}

local ShopController = {}

type View = {
	NpcId: string,
	Mode: Mode,
	Modal: Modal.Modal,
	Tabs: Tabs.Tabs?,
	Tab: string,
	Grid: ScrollingFrame,
	Detail: Frame,
	Selected: string?,
	Cards: { ItemCard.ItemCard },
	Preview: ViewportPreview.ViewportPreview?,
	Qty: number,
}

local view: View? = nil

local function notifyResult(ok: any, msg: any)
	if type(msg) == "string" and msg ~= "" then
		NotificationController.Show(msg, if ok then "Success" else "Warning")
	end
end

local function rodSkin(data: ProfileData): Types.CosmeticDef?
	return Cosmetics.Get(data.Cosmetics.Equipped.RodSkin)
end

-- ===================== Penyedia isi tab =====================

local function rodEntries(data: ProfileData): { Entry }
	local out: { Entry } = {}
	local equipped = Rods.Get(data.EquippedRod) :: Types.RodDef
	for _, rod in Rods.List do
		local owned = table.find(data.Rods, rod.Id) ~= nil
		local isEquipped = data.EquippedRod == rod.Id
		local locked = data.Level < rod.Level
		local status: ItemCard.CardStatus = if isEquipped then "Equipped" elseif owned then "Owned" elseif locked then "Locked" else "None"
		local action
		if isEquipped then
			action = { Text = Strings.Equipped, Variant = "Quiet" :: Button.Variant, Enabled = false, Run = function(_q: number) end }
		elseif owned then
			action = {
				Text = Strings.Equip,
				Variant = "Secondary" :: Button.Variant,
				Enabled = true,
				Run = function(_q: number)
					notifyResult(Net.Invoke("Equip", "Rod", rod.Id))
				end,
			}
		elseif rod.Source == "Shop" and rod.Price then
			action = {
				Text = Strings.Buy .. " · " .. Format.Coins(rod.Price),
				Variant = "Primary" :: Button.Variant,
				Enabled = not locked and data.Coins >= rod.Price,
				Run = function(_q: number)
					notifyResult(Net.Invoke("Purchase", (view :: View).NpcId, "Rod", rod.Id, 1))
				end,
			}
		else
			action = { Text = "Hanya lewat barter", Variant = "Quiet" :: Button.Variant, Enabled = false, Run = function(_q: number) end }
		end
		table.insert(out, {
			Id = rod.Id,
			Title = rod.Name,
			Subtitle = "Lv " .. tostring(rod.Level),
			Price = if owned then nil else rod.Price,
			Currency = "Coins",
			Status = status,
			StatusText = if status == "Locked" then string.format(Strings.LockedLevel, rod.Level)
				elseif status == "Equipped" then Strings.Equipped
				elseif status == "Owned" then Strings.Owned
				elseif rod.Source == "Barter" then "Barter"
				else nil,
			Preview = function(): Model?
				return RodModel.BuildDisplay(rod, rodSkin(data))
			end,
			Description = rod.Description,
			Stats = function(parent: Frame)
				local function row(label: string, value: number, current: number, better: "Higher" | "Lower", fmt: (number) -> string, order: number)
					StatRow.new({
						Label = label,
						Value = fmt(value),
						Delta = if rod.Id == equipped.Id then nil else value - current,
						Better = better,
						DeltaText = if rod.Id == equipped.Id then nil else (if value - current >= 0 then "+" else "") .. fmt(value - current),
						Parent = parent,
						LayoutOrder = order,
					})
				end
				local function dec(n: number): string
					return Format.Decimal(n, 2)
				end
				local function int(n: number): string
					return Format.Int(n)
				end
				row(Strings.StatLuck, rod.Luck, equipped.Luck, "Higher", dec, 1)
				row(Strings.StatWait, rod.WaitMul, equipped.WaitMul, "Lower", dec, 2)
				row(Strings.StatControl, rod.Control, equipped.Control, "Higher", dec, 3)
				row(Strings.StatReel, rod.ReelSpeed, equipped.ReelSpeed, "Higher", dec, 4)
				row(Strings.StatMaxWeight, rod.MaxWeight, equipped.MaxWeight, "Higher", function(n)
					return Format.Int(n) .. " kg"
				end, 5)
				row(Strings.StatDistance, rod.CastDistance, equipped.CastDistance, "Higher", int, 6)
			end,
			Action = action,
		})
	end
	return out
end

local function baitEntries(data: ProfileData): { Entry }
	local out: { Entry } = {}
	local current = if data.EquippedBait ~= "" then Bait.Get(data.EquippedBait) else nil
	for _, bait in Bait.List do
		local qty = data.Bait[bait.Id] or 0
		local isEquipped = data.EquippedBait == bait.Id
		table.insert(out, {
			Id = bait.Id,
			Title = bait.Name,
			Subtitle = if qty > 0 then "Dimiliki ×" .. Format.Int(qty) else nil,
			Price = bait.Price,
			Currency = "Coins",
			Status = if isEquipped then "Equipped" elseif qty > 0 then "Owned" else "None",
			StatusText = if isEquipped then Strings.Equipped elseif bait.Source == "Barter" then "Barter" else nil,
			Icon = "bait",
			IconColor = bait.Color,
			Description = bait.Description,
			Quantity = bait.Source == "Shop",
			Stats = function(parent: Frame)
				local curLuck = if current then current.Luck else 0
				local curWait = if current then current.WaitMul else Balance.Fishing.NoBaitWaitMul
				StatRow.new({ Label = Strings.StatLuck, Value = Format.Decimal(bait.Luck, 2), Delta = bait.Luck - curLuck, Better = "Higher", DeltaText = Format.Signed(bait.Luck - curLuck, 2), Parent = parent, LayoutOrder = 1 })
				StatRow.new({ Label = Strings.StatWait, Value = Format.Multiplier(bait.WaitMul), Delta = bait.WaitMul - curWait, Better = "Lower", DeltaText = Format.Signed(bait.WaitMul - curWait, 2), Parent = parent, LayoutOrder = 2 })
			end,
			Action = if bait.Source == "Shop" and bait.Price
				then {
					Text = Strings.Buy,
					Variant = "Primary" :: Button.Variant,
					Enabled = data.Coins >= (bait.Price :: number),
					Run = function(q: number)
						notifyResult(Net.Invoke("Purchase", (view :: View).NpcId, "Bait", bait.Id, q))
					end,
				}
				elseif qty > 0 and not isEquipped then {
					Text = Strings.Equip,
					Variant = "Secondary" :: Button.Variant,
					Enabled = true,
					Run = function(_q: number)
						notifyResult(Net.Invoke("Equip", "Bait", bait.Id))
					end,
				}
				else nil,
		})
	end
	return out
end

local function bagEntries(data: ProfileData): { Entry }
	local out: { Entry } = {}
	local nextTier = Bags.NextTier(data.BagCapacity)
	for i, tier in Bags.Tiers do
		if i > 1 then
			local owned = data.BagCapacity >= tier.Capacity
			local isNext = nextTier ~= nil and nextTier.Capacity == tier.Capacity
			table.insert(out, {
				Id = "bag_" .. tostring(tier.Capacity),
				Title = string.format("Tas %d ikan", tier.Capacity),
				Subtitle = if owned then Strings.Owned else nil,
				Price = if owned then nil else tier.Price,
				Currency = "Coins",
				Status = if owned then "Owned" elseif isNext then "None" else "Locked",
				StatusText = if owned then Strings.Owned elseif isNext then nil else "Tingkat sebelumnya dulu",
				Icon = "bag",
				Description = string.format(Strings.BagUpgradeDesc, data.BagCapacity, tier.Capacity),
				Stats = function(parent: Frame)
					StatRow.new({
						Label = "Kapasitas",
						Value = string.format("%d ikan", tier.Capacity),
						Delta = tier.Capacity - data.BagCapacity,
						Better = "Higher",
						DeltaText = Format.Signed(tier.Capacity - data.BagCapacity),
						Parent = parent,
						LayoutOrder = 1,
					})
				end,
				Action = if isNext
					then {
						Text = Strings.Buy .. " · " .. Format.Coins(tier.Price),
						Variant = "Primary" :: Button.Variant,
						Enabled = data.Coins >= tier.Price,
						Run = function(_q: number)
							notifyResult(Net.Invoke("Purchase", (view :: View).NpcId, "Bag", "next", 1))
						end,
					}
					else nil,
			})
		end
	end
	return out
end

local function cosmeticEntries(data: ProfileData, slot: string, filter: (Types.CosmeticDef) -> boolean, wardrobe: boolean): { Entry }
	local out: { Entry } = {}
	for _, c in Cosmetics.InSlot(slot) do
		if filter(c) then
			local owned = data.Cosmetics.Owned[c.Id] == true
			local isEquipped = (data.Cosmetics.Equipped :: any)[c.Slot] == c.Id
			local currency: "Coins" | "Points" = if c.Source == "Points" then "Points" else "Coins"
			local price = if c.Source == "Points" then c.PointsPrice else c.Price
			local balance = if currency == "Points" then data.ConservationPoints else data.Coins
			local action
			if isEquipped then
				action = if c.Slot == "RodSkin" or c.Slot == "Bobber"
					then { Text = Strings.Equipped, Variant = "Quiet" :: Button.Variant, Enabled = false, Run = function(_q: number) end }
					else {
						Text = "Lepas",
						Variant = "Quiet" :: Button.Variant,
						Enabled = true,
						Run = function(_q: number)
							notifyResult(Net.Invoke("Equip", c.Slot, ""))
						end,
					}
			elseif owned then
				action = {
					Text = Strings.Equip,
					Variant = "Secondary" :: Button.Variant,
					Enabled = true,
					Run = function(_q: number)
						notifyResult(Net.Invoke("Equip", c.Slot, c.Id))
					end,
				}
			elseif not wardrobe and price then
				action = {
					Text = Strings.Buy .. " · " .. Format.Int(price) .. (if currency == "Points" then " poin" else ""),
					Variant = "Primary" :: Button.Variant,
					Enabled = balance >= price,
					Run = function(_q: number)
						notifyResult(Net.Invoke("Purchase", (view :: View).NpcId, "Cosmetic", c.Id, 1))
					end,
				}
			end
			table.insert(out, {
				Id = c.Id,
				Title = c.Name,
				Subtitle = Cosmetics.SlotLabel[c.Slot],
				Price = if owned then nil else price,
				Currency = currency,
				Status = if isEquipped then "Equipped" elseif owned then "Owned" else "None",
				StatusText = if isEquipped then Strings.Equipped elseif owned then Strings.Owned elseif c.Source == "Barter" then "Barter" else nil,
				Icon = if c.Slot == "Title" then "trophy" else nil,
				Preview = if c.Slot == "Title" then nil else function(): Model?
					return CosmeticModels.BuildPreview(c)
				end,
				Description = c.Description,
				Stats = function(_parent: Frame) end,
				Action = action,
			})
		end
	end
	return out
end

type TabItem = Tabs.TabItem

local FISHING_TABS: { TabItem } = { { Id = "Rod", Label = Strings.TabRods, Icon = "rod" }, { Id = "Bait", Label = Strings.TabBait, Icon = "bait" }, { Id = "Bag", Label = Strings.TabBag, Icon = "bag" } }

local function tabsFor(mode: Mode, npc: Types.NpcDef?): { TabItem }
	if mode == "Points" then
		local points: { TabItem } = { { Id = "Points", Label = Strings.TabPoints, Icon = "leaf" } }
		return points
	end
	if mode == "Wardrobe" then
		local list: { TabItem } = {}
		for _, slot in Cosmetics.SlotOrder do
			table.insert(list, { Id = slot, Label = Cosmetics.SlotLabel[slot] })
		end
		return list
	end
	if npc and npc.Role == "ShopFishing" then
		return FISHING_TABS
	end
	local list: { TabItem } = {}
	for _, slot in { "Hat", "Accessory", "RodSkin", "Bobber", "Trail", "Aura" } do
		table.insert(list, { Id = slot, Label = Cosmetics.SlotLabel[slot] })
	end
	return list
end

local function entriesFor(v: View, data: ProfileData): { Entry }
	if v.Mode == "Points" then
		local out: { Entry } = {}
		for _, slot in Cosmetics.SlotOrder do
			for _, e in cosmeticEntries(data, slot, function(c)
				return c.Source == "Points"
			end, false) do
				table.insert(out, e)
			end
		end
		return out
	elseif v.Mode == "Wardrobe" then
		return cosmeticEntries(data, v.Tab, function(c)
			return data.Cosmetics.Owned[c.Id] == true
		end, true)
	elseif v.Tab == "Rod" then
		return rodEntries(data)
	elseif v.Tab == "Bait" then
		return baitEntries(data)
	elseif v.Tab == "Bag" then
		return bagEntries(data)
	end
	return cosmeticEntries(data, v.Tab, function(c)
		return c.Source == "Shop"
	end, false)
end

-- ===================== Render =====================

local function subtitleFor(v: View, data: ProfileData): string
	local npc = NPCs.Get(v.NpcId)
	local who = if npc then npc.Name else ""
	if v.Mode == "Points" then
		return string.format("%s · %s Poin Konservasi", who, Format.Int(data.ConservationPoints))
	elseif v.Mode == "Wardrobe" then
		return "Pakai kosmetik yang sudah kamu miliki"
	end
	return string.format("%s · Saldo %s koin", who, Format.Coins(data.Coins))
end

local renderDetail: (View, Entry?) -> ()

renderDetail = function(v: View, entry: Entry?)
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
	if entry == nil then
		Style.Label({
			Text = "Pilih barang untuk melihat detail.",
			TextSize = Theme.TextSize.Body,
			Color = Theme.Color.TextSecondary,
			Wrap = true,
			AutoSize = "Y",
			Size = UDim2.new(1, 0, 0, 0),
			Parent = detail,
		})
		return
	end
	if entry.Preview then
		local model = entry.Preview()
		v.Preview = ViewportPreview.new({ Model = model, Size = UDim2.new(1, 0, 0, 150), Spin = true, LayoutOrder = 1, Parent = detail })
	elseif entry.Icon then
		local holder = Style.Frame({ Size = UDim2.new(1, 0, 0, 96), LayoutOrder = 1, Parent = detail })
		local ic = Icon.new(entry.Icon, 72, entry.IconColor)
		ic.AnchorPoint = Vector2.new(0.5, 0.5)
		ic.Position = UDim2.fromScale(0.5, 0.5)
		ic.Parent = holder
	end
	Style.Label({ Text = entry.Title, Font = "Display", TextSize = Theme.TextSize.Heading, AutoSize = "XY", LayoutOrder = 2, Parent = detail })
	Style.Label({
		Text = entry.Description,
		TextSize = Theme.TextSize.Small,
		Color = Theme.Color.TextSecondary,
		Wrap = true,
		AutoSize = "Y",
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = 3,
		Parent = detail,
	})
	local stats = Style.Frame({ Size = UDim2.new(1, 0, 0, 0), AutoSize = "Y", LayoutOrder = 4, Parent = detail })
	Style.List(stats, "Vertical", Theme.Space.XS)
	entry.Stats(stats)
	if entry.Quantity then
		QuantityPicker.new({
			Options = { 1, 10, 50, 0 },
			Selected = v.Qty,
			MaxLabel = Strings.Max,
			LayoutOrder = 5,
			Parent = detail,
			OnChanged = function(q: number)
				v.Qty = q
			end,
		})
	end
	local action = entry.Action
	if action then
		Button.new({
			Text = action.Text,
			Variant = action.Variant,
			Disabled = not action.Enabled,
			Size = UDim2.new(1, 0, 0, Theme.Size.ButtonHeight),
			LayoutOrder = 6,
			Parent = detail,
			OnActivated = function()
				action.Run(v.Qty)
			end,
		})
	end
end

local function renderGrid(v: View)
	local data = DataController.Get()
	if data == nil then
		return
	end
	v.Modal:SetSubtitle(subtitleFor(v, data))
	for _, card in v.Cards do
		card:Destroy()
	end
	table.clear(v.Cards)
	local entries = entriesFor(v, data)
	local selectedEntry: Entry? = nil
	for i, entry in entries do
		if v.Selected == entry.Id then
			selectedEntry = entry
		end
		local card = ItemCard.new({
			Title = entry.Title,
			Subtitle = entry.Subtitle,
			Price = entry.Price,
			Currency = entry.Currency,
			Status = entry.Status,
			StatusText = entry.StatusText,
			Rarity = entry.Rarity,
			Icon = entry.Icon,
			IconColor = entry.IconColor,
			Preview = entry.Preview,
			Selected = v.Selected == entry.Id,
			Name = "Item_" .. entry.Id,
			LayoutOrder = i,
			Parent = v.Grid,
			OnActivated = function()
				if v.Selected ~= entry.Id then
					v.Qty = 1
				end
				v.Selected = entry.Id
				for _, other in v.Cards do
					other:SetSelected(false)
				end
				renderGrid(v)
			end,
		})
		table.insert(v.Cards, card)
	end
	if #entries == 0 then
		Style.Label({
			Name = "Kosong",
			Text = if v.Mode == "Wardrobe" then "Belum ada kosmetik di slot ini. Kunjungi Butik Pantai Mbak Sari." else "Belum ada barang di kategori ini.",
			TextSize = Theme.TextSize.Body,
			Color = Theme.Color.TextSecondary,
			Wrap = true,
			AutoSize = "Y",
			Size = UDim2.new(1, 0, 0, 0),
			Parent = v.Grid,
		})
	end
	if selectedEntry == nil and #entries > 0 then
		v.Selected = entries[1].Id
		selectedEntry = entries[1]
		if v.Cards[1] then
			v.Cards[1]:SetSelected(true)
		end
	end
	renderDetail(v, selectedEntry)
end

function ShopController.Open(npcId: string, mode: Mode?)
	local m: Mode = mode or "Shop"
	local npc = NPCs.Get(npcId)
	local title = if m == "Points" then Strings.ShopPoints
		elseif m == "Wardrobe" then Strings.Wardrobe
		elseif npc and npc.Role == "ShopFishing" then Strings.ShopFishing
		else Strings.ShopCosmetic
	local modal = Modal.new({
		Title = title,
		Icon = if m == "Wardrobe" then "shirt" elseif m == "Points" then "leaf" else "coin",
		Parent = UIController.Gui("Panel"),
		OnClose = function()
			UIController.ClosePanel()
		end,
	})
	local body = modal.Body
	Style.List(body, "Vertical", Theme.Space.M)
	local tabItems = tabsFor(m, npc)
	local content = Style.Frame({ Name = "Konten", Size = UDim2.new(1, 0, 1, -64), LayoutOrder = 2, Parent = body })
	local grid = Style.Scroll({ Name = "Grid", Size = UDim2.new(0.62, -Theme.Space.M, 1, 0), Padding = Theme.Space.XS, Parent = content })
	Style.Grid(grid, UDim2.fromOffset(170, 196), Theme.Space.S)
	local detail = Style.Card({ Name = "Detail", Size = UDim2.new(0.38, 0, 1, 0), Position = UDim2.fromScale(0.62, 0), Parent = content })
	Style.Padding(detail, Theme.Space.M)
	Style.List(detail, "Vertical", Theme.Space.S)

	local v: View = {
		NpcId = npcId,
		Mode = m,
		Modal = modal,
		Tabs = nil,
		Tab = tabItems[1].Id,
		Grid = grid,
		Detail = detail,
		Selected = nil,
		Cards = {},
		Preview = nil,
		Qty = 1,
	}
	if #tabItems > 1 then
		v.Tabs = Tabs.new({
			Items = tabItems,
			Selected = tabItems[1].Id,
			LayoutOrder = 1,
			Parent = body,
			OnChanged = function(id: string)
				v.Tab = id
				v.Selected = nil
				renderGrid(v)
			end,
		})
	else
		content.Size = UDim2.new(1, 0, 1, 0)
	end
	view = v
	renderGrid(v)
	UIController.OpenPanel({
		Name = "Shop",
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

function ShopController.Start()
	DialogController.Action:Connect(function(npcId, action)
		if action == "Shop" then
			local npc = NPCs.Get(npcId)
			ShopController.Open(npcId, if npc and npc.Role == "Conservation" then "Points" else "Shop")
		elseif action == "PointsShop" then
			ShopController.Open(npcId, "Points")
		elseif action == "Wardrobe" then
			ShopController.Open(npcId, "Wardrobe")
		end
	end)
	InputController.Hotkey:Connect(function(name)
		if name == "Cosmetic" then
			if UIController.CurrentPanel() == "Shop" and view and view.Mode == "Wardrobe" then
				UIController.ClosePanel()
			else
				ShopController.Open("mbak_sari", "Wardrobe")
			end
		end
	end)
	DataController.Changed:Connect(function(key)
		local v = view
		if v and (key == "Coins" or key == "Rods" or key == "EquippedRod" or key == "Bait" or key == "EquippedBait" or key == "BagCapacity" or key == "Cosmetics" or key == "ConservationPoints" or key == "Level") then
			renderGrid(v)
		end
	end)
end

return ShopController
