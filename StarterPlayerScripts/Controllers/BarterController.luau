--!strict
-- BarterController: panel Gubuk Barter Kakek Bahari. Daftar resep di kiri, detail di kanan. Server memilih ikan
-- bernilai terendah yang memenuhi syarat (BarterPreview) dan daftar itu ditampilkan sebelum konfirmasi.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Net = require(Shared.Net)
local Format = require(Shared.Util.Format)
local Balance = require(Shared.Config.Balance)
local Barter = require(Shared.Config.Barter)
local Fish = require(Shared.Config.Fish)
local Strings = require(Shared.Config.Strings)
local Theme = require(Shared.Config.Theme)
local UIController = require(script.Parent.UIController)
local NotificationController = require(script.Parent.NotificationController)
local DialogController = require(script.Parent.DialogController)
local DataController = require(script.Parent.DataController)
local UI = script.Parent.Parent:WaitForChild("UI")
local Style = require(UI:WaitForChild("Style"))
local Button = require(UI:WaitForChild("Button"))
local Modal = require(UI:WaitForChild("Modal"))
local ItemCard = require(UI:WaitForChild("ItemCard"))
local ConfirmDialog = require(UI:WaitForChild("ConfirmDialog"))

type BarterRecipe = Types.BarterRecipe

local BarterController = {}

type View = {
	Modal: Modal.Modal,
	List: ScrollingFrame,
	Detail: Frame,
	Selected: string,
	Cards: { ItemCard.ItemCard },
	Token: number,
}

local view: View? = nil

local renderDetail: (View) -> ()

local function renderList(v: View)
	for _, c in v.Cards do
		c:Destroy()
	end
	table.clear(v.Cards)
	local data = DataController.Get()
	for i, recipe in Barter.List do
		local done = data ~= nil and recipe.Once == true and data.BarterOnce[recipe.Id] == true
		local card = ItemCard.new({
			Title = recipe.Name,
			Subtitle = string.format("%d× %s", recipe.Count, Balance.RarityLabel[recipe.Rarity] or recipe.Rarity),
			Price = recipe.Coins,
			Currency = "Coins",
			Status = if done then "Owned" else "None",
			StatusText = if done then "Sudah ditukar" else nil,
			Rarity = recipe.Rarity,
			Icon = if recipe.GiveRod then "rod" elseif recipe.GiveBait then "bait" elseif recipe.GiveCosmetic then "shirt" else "swap",
			Selected = v.Selected == recipe.Id,
			LayoutOrder = i,
			Parent = v.List,
			OnActivated = function()
				v.Selected = recipe.Id
				renderList(v)
				renderDetail(v)
			end,
		})
		table.insert(v.Cards, card)
	end
end

renderDetail = function(v: View)
	local detail = v.Detail
	for _, child in detail:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local recipe = Barter.ById[v.Selected]
	if recipe == nil then
		return
	end
	Style.Label({ Text = recipe.Name, Font = "Display", TextSize = Theme.TextSize.Heading, Color = Theme.Color.Primary, AutoSize = "XY", LayoutOrder = 1, Parent = detail })
	Style.Label({ Text = recipe.Description, TextSize = Theme.TextSize.Body, Wrap = true, AutoSize = "Y", Size = UDim2.new(1, 0, 0, 0), LayoutOrder = 2, Parent = detail })
	local status = Style.Label({ Text = "Memeriksa tas...", TextSize = Theme.TextSize.Small, Color = Theme.Color.TextSecondary, Wrap = true, AutoSize = "Y", Size = UDim2.new(1, 0, 0, 0), LayoutOrder = 3, Parent = detail })
	local fishList = Style.Frame({ Size = UDim2.new(1, 0, 0, 0), AutoSize = "Y", LayoutOrder = 4, Parent = detail })
	Style.List(fishList, "Vertical", Theme.Space.XS)
	local actions = Style.Frame({ Size = UDim2.new(1, 0, 0, 0), AutoSize = "Y", LayoutOrder = 5, Parent = detail })
	v.Token += 1
	local token = v.Token
	task.spawn(function()
		local preview, err = Net.Invoke("BarterPreview", recipe.Id)
		if view ~= v or v.Token ~= token then
			return
		end
		if typeof(preview) ~= "table" then
			status.Text = if type(err) == "string" then err else "Gagal memeriksa tas. Coba lagi."
			status.TextColor3 = Theme.Color.DangerText
			return
		end
		local p = preview :: Types.BarterPreview
		if p.Ok then
			status.Text = Strings.BarterPreview .. (if p.Coins > 0 then string.format(" + %s koin", Format.Coins(p.Coins)) else "") .. ":"
			status.TextColor3 = Theme.Color.Text
		else
			status.Text = p.Reason or Strings.BarterNotEnough
			status.TextColor3 = Theme.Color.DangerText
		end
		for i, item in p.Fish do
			local species = Fish.Get(item.SpeciesId)
			Style.Label({
				Text = string.format("• %s %s%s", if species then species.Name else item.SpeciesId, Format.Kg(item.Weight), if item.Mutation ~= "None" then " (" .. item.Mutation .. ")" else ""),
				TextSize = Theme.TextSize.Small,
				Color = if species then (Theme.Rarity[species.Rarity] or Theme.Color.Text) else Theme.Color.Text,
				AutoSize = "XY",
				LayoutOrder = i,
				Parent = fishList,
			})
		end
		Button.new({
			Text = Strings.BarterDo,
			Variant = "Primary",
			Icon = "swap",
			Disabled = not p.Ok,
			Size = UDim2.new(1, 0, 0, Theme.Size.ButtonHeight),
			Parent = actions,
			OnActivated = function()
				ConfirmDialog.Show({
					Parent = UIController.Gui("Popup"),
					Title = Strings.BarterTitle,
					Body = string.format("Tukar %d ikan%s untuk %s?", #p.Fish, if p.Coins > 0 then " + " .. Format.Coins(p.Coins) .. " koin" else "", recipe.Name),
					ConfirmText = Strings.BarterDo,
					CancelText = Strings.Cancel,
					Variant = "Primary",
					OnConfirm = function()
						local ok, msg = Net.Invoke("BarterExecute", recipe.Id)
						NotificationController.Show(if type(msg) == "string" then msg else "", if ok then "Success" else "Warning")
						if view == v then
							renderList(v)
							renderDetail(v)
						end
					end,
				})
			end,
		})
	end)
end

function BarterController.Open()
	local modal = Modal.new({
		Title = Strings.BarterTitle,
		Subtitle = "Kakek Bahari · \"Laut menyimpan banyak rahasia, Nak.\"",
		Icon = "swap",
		Parent = UIController.Gui("Panel"),
		OnClose = function()
			UIController.ClosePanel()
		end,
	})
	local body = modal.Body
	local list = Style.Scroll({ Name = "Resep", Size = UDim2.new(0.55, -Theme.Space.M, 1, 0), Padding = Theme.Space.XS, Parent = body })
	Style.Grid(list, UDim2.fromOffset(176, 176), Theme.Space.S)
	local detail = Style.Card({ Name = "Detail", Size = UDim2.new(0.45, 0, 1, 0), Position = UDim2.fromScale(0.55, 0), Parent = body })
	Style.Padding(detail, Theme.Space.M)
	Style.List(detail, "Vertical", Theme.Space.S)
	local v: View = { Modal = modal, List = list, Detail = detail, Selected = Barter.List[1].Id, Cards = {}, Token = 0 }
	view = v
	renderList(v)
	renderDetail(v)
	UIController.OpenPanel({
		Name = "Barter",
		Panel = modal :: any,
		OnClosed = function()
			if view == v then
				view = nil
			end
		end,
	})
end

function BarterController.Start()
	DialogController.Action:Connect(function(_npcId, action)
		if action == "Barter" then
			BarterController.Open()
		end
	end)
end

return BarterController
