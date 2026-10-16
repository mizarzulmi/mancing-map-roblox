--!strict
-- TradeController: trade antar pemain (GDD 4.5) di sisi client.
-- Menu "Pemain di Sekitar" (≤ 30 stud) + ProximityPrompt "Ajak Tukar" (disembunyikan di karakter sendiri),
-- kartu undangan dengan hitung mundur, jendela dua kolom (ikan maks 8, umpan, koin) dengan estimasi nilai,
-- peringatan nilai timpang, status Siap kedua pihak, dan hitung mundur 5 dtk. Semua validasi di server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Net = require(Shared.Net)
local Format = require(Shared.Util.Format)
local Balance = require(Shared.Config.Balance)
local Fish = require(Shared.Config.Fish)
local Bait = require(Shared.Config.Bait)
local Strings = require(Shared.Config.Strings)
local Theme = require(Shared.Config.Theme)
local DataController = require(script.Parent.DataController)
local UIController = require(script.Parent.UIController)
local InputController = require(script.Parent.InputController)
local NotificationController = require(script.Parent.NotificationController)
local UI = script.Parent.Parent:WaitForChild("UI")
local Style = require(UI:WaitForChild("Style"))
local Button = require(UI:WaitForChild("Button"))
local Modal = require(UI:WaitForChild("Modal"))

type TradeView = Types.TradeView
type TradeOffer = Types.TradeOffer
type FishItem = Types.FishItem

local TradeController = {}

local player = Players.LocalPlayer
local current: TradeView? = nil
local modal: Modal.Modal? = nil
local columns: { Mine: Frame?, Theirs: Frame?, Footer: Frame?, Warning: TextLabel?, Countdown: TextLabel? } = {}
local picking = false
local ending = false

local function mySideKey(view: TradeView): "A" | "B"
	return if view.A.UserId == player.UserId then "A" else "B"
end

local function sides(view: TradeView): (Types.TradeSide, Types.TradeSide)
	if mySideKey(view) == "A" then
		return view.A, view.B
	end
	return view.B, view.A
end

local function copyOffer(o: TradeOffer): TradeOffer
	local bait: { [string]: number } = {}
	for k, v in o.Bait do
		bait[k] = v
	end
	return { Fish = table.clone(o.Fish), Bait = bait, Coins = o.Coins }
end

local function send(offer: TradeOffer)
	task.spawn(function()
		local ok, msg = Net.Invoke("TradeUpdateOffer", offer)
		if not ok and type(msg) == "string" and msg ~= "" then
			NotificationController.Show(msg, "Warning")
		end
	end)
end

local function clear(frame: Instance?)
	if frame == nil then
		return
	end
	for _, child in frame:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function fishLine(parent: Instance, item: FishItem, order: number, onRemove: (() -> ())?)
	local species = Fish.Get(item.SpeciesId)
	local row = Style.Card({ Size = UDim2.new(1, 0, 0, Theme.Size.Touch), LayoutOrder = order, Parent = parent })
	Style.Padding(row, 0, Theme.Space.S, 0, Theme.Space.M)
	Style.Label({
		Text = string.format("%s · %s%s", if species then species.Name else item.SpeciesId, Format.Kg(item.Weight), if item.Mutation ~= "None" then " · " .. item.Mutation else ""),
		Font = "Bold",
		TextSize = Theme.TextSize.Small,
		Color = if species then (Theme.Rarity[species.Rarity] or Theme.Color.Text) else Theme.Color.Text,
		Size = UDim2.new(1, -60, 1, 0),
		Parent = row,
	})
	if onRemove then
		local b = Button.new({ Text = "", Variant = "Quiet", Icon = "close", Width = 48, Parent = row, OnActivated = onRemove })
		b.Instance.AnchorPoint = Vector2.new(1, 0.5)
		b.Instance.Position = UDim2.new(1, 0, 0.5, 0)
	end
end

local render: () -> ()

local function openFishPicker()
	local view = current
	local data = DataController.Get()
	local mine = columns.Mine
	if view == nil or data == nil or mine == nil or picking then
		return
	end
	local my = sides(view)
	if #my.Offer.Fish >= Balance.Trade.MaxFish then
		NotificationController.Show("Maksimal " .. tostring(Balance.Trade.MaxFish) .. " ikan.", "Warning")
		return
	end
	picking = true
	local overlay = Style.Panel({ Name = "PilihIkan", Size = UDim2.fromScale(1, 1), ZIndex = 20, Parent = mine })
	Style.Padding(overlay, Theme.Space.S)
	local list = Style.Scroll({ Size = UDim2.new(1, 0, 1, -60), Padding = Theme.Space.XS, Parent = overlay })
	Style.List(list, "Vertical", Theme.Space.XS)
	local offered: { [string]: boolean } = {}
	for _, uid in my.Offer.Fish do
		offered[uid] = true
	end
	local count = 0
	for _, item in data.Fish do
		local species = Fish.Get(item.SpeciesId)
		if species and not item.Locked and not species.Protected and not offered[item.Uid] then
			count += 1
			local b = Instance.new("TextButton")
			b.AutoButtonColor = false
			b.Text = ""
			b.Size = UDim2.new(1, 0, 0, Theme.Size.Touch)
			b.BackgroundColor3 = Theme.Color.Card
			b.LayoutOrder = count
			Style.Corner(b, Theme.Radius.Chip)
			Style.Padding(b, 0, Theme.Space.M, 0, Theme.Space.M)
			Style.Label({
				Text = string.format("%s · %s", species.Name, Format.Kg(item.Weight)),
				Font = "Bold",
				TextSize = Theme.TextSize.Small,
				Color = Theme.Rarity[species.Rarity] or Theme.Color.Text,
				Size = UDim2.fromScale(1, 1),
				Parent = b,
			})
			b.Activated:Connect(function()
				local offer = copyOffer(my.Offer)
				table.insert(offer.Fish, item.Uid)
				picking = false
				overlay:Destroy()
				send(offer)
			end)
			b.Parent = list
		end
	end
	if count == 0 then
		Style.Label({ Text = "Tidak ada ikan yang bisa ditukar (ikan terkunci & dilindungi tidak bisa).", TextSize = Theme.TextSize.Small, Color = Theme.Color.TextSecondary, Wrap = true, AutoSize = "Y", Size = UDim2.new(1, 0, 0, 0), Parent = list })
	end
	local close = Button.new({
		Text = Strings.Back,
		Variant = "Quiet",
		Size = UDim2.new(1, 0, 0, Theme.Size.ButtonHeight),
		Parent = overlay,
		OnActivated = function()
			picking = false
			overlay:Destroy()
		end,
	})
	close.Instance.AnchorPoint = Vector2.new(0, 1)
	close.Instance.Position = UDim2.fromScale(0, 1)
end

local function renderColumn(frame: Frame, side: Types.TradeSide, editable: boolean)
	clear(frame)
	picking = false
	local data = DataController.Get()
	Style.Label({
		Text = (if editable then Strings.TradeYou else side.Name) .. (if side.Ready then "  ·  Siap" else ""),
		Font = "Display",
		TextSize = Theme.TextSize.Label,
		Color = if side.Ready then Theme.Color.Success else Theme.Color.Text,
		AutoSize = "XY",
		LayoutOrder = 1,
		Parent = frame,
	})
	Style.Label({ Text = string.format(Strings.TradeValue, Format.Coins(side.Value) .. " koin"), TextSize = Theme.TextSize.Small, Color = Theme.Color.TextSecondary, AutoSize = "XY", LayoutOrder = 2, Parent = frame })
	local fishBox = Style.Frame({ Size = UDim2.new(1, 0, 0, 0), AutoSize = "Y", LayoutOrder = 3, Parent = frame })
	Style.List(fishBox, "Vertical", Theme.Space.XS)
	for i, item in side.FishItems do
		fishLine(fishBox, item, i, if editable then function()
			local view = current
			if view == nil then
				return
			end
			local my = sides(view)
			local offer = copyOffer(my.Offer)
			local idx = table.find(offer.Fish, item.Uid)
			if idx then
				table.remove(offer.Fish, idx)
			end
			send(offer)
		end else nil)
	end
	if editable then
		Button.new({
			Text = Strings.TradeAddFish .. string.format(" (%d/%d)", #side.Offer.Fish, Balance.Trade.MaxFish),
			Variant = "Secondary",
			Icon = "plus",
			Size = UDim2.new(1, 0, 0, Theme.Size.ButtonHeight),
			LayoutOrder = 4,
			Parent = frame,
			OnActivated = openFishPicker,
		})
		-- Umpan: tombol − / + per jenis yang dimiliki.
		if data then
			for _, def in Bait.List do
				local owned = data.Bait[def.Id] or 0
				local offered = side.Offer.Bait[def.Id] or 0
				if owned > 0 or offered > 0 then
					local row = Style.Frame({ Size = UDim2.new(1, 0, 0, Theme.Size.Touch), LayoutOrder = 10 + def.Order, Parent = frame })
					Style.List(row, "Horizontal", Theme.Space.S, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
					Style.Label({ Text = string.format("%s: %d", def.Name, offered), Font = "Bold", TextSize = Theme.TextSize.Small, Size = UDim2.new(1, -120, 1, 0), LayoutOrder = 1, Parent = row })
					local function change(delta: number)
						local view = current
						if view == nil then
							return
						end
						local my = sides(view)
						local offer = copyOffer(my.Offer)
						local n = math.clamp((offer.Bait[def.Id] or 0) + delta, 0, owned)
						if n > 0 then
							offer.Bait[def.Id] = n
						else
							(offer.Bait :: any)[def.Id] = nil
						end
						send(offer)
					end
					Button.new({ Text = "", Variant = "Quiet", Icon = "minus", Width = 52, LayoutOrder = 2, Parent = row, OnActivated = function()
						change(-1)
					end })
					Button.new({ Text = "", Variant = "Quiet", Icon = "plus", Width = 52, LayoutOrder = 3, Parent = row, OnActivated = function()
						change(1)
					end })
				end
			end
		end
		-- Koin
		local coinRow = Style.Frame({ Size = UDim2.new(1, 0, 0, Theme.Size.Touch), LayoutOrder = 40, Parent = frame })
		Style.List(coinRow, "Horizontal", Theme.Space.S, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
		Style.Label({ Text = Strings.TradeCoins, Font = "Bold", TextSize = Theme.TextSize.Small, AutoSize = "XY", LayoutOrder = 1, Parent = coinRow })
		local box = Instance.new("TextBox")
		box.Name = "KoinInput"
		box.Size = UDim2.fromOffset(160, Theme.Size.Touch)
		box.BackgroundColor3 = Theme.Color.Inset
		box.TextColor3 = Theme.Color.Text
		box.PlaceholderColor3 = Theme.Color.TextSecondary
		box.PlaceholderText = "0"
		box.FontFace = Theme.Font.Bold
		box.TextSize = Theme.TextSize.Body
		box.ClearTextOnFocus = false
		box.Text = if side.Offer.Coins > 0 then tostring(side.Offer.Coins) else ""
		box.LayoutOrder = 2
		Style.Corner(box, Theme.Radius.Chip)
		box.FocusLost:Connect(function()
			local view = current
			if view == nil then
				return
			end
			task.defer(render)
			local n = math.floor(tonumber(box.Text) or 0)
			local maxCoins = if data then data.Coins else 0
			n = math.clamp(n, 0, maxCoins)
			box.Text = if n > 0 then tostring(n) else ""
			local my = sides(view)
			if n ~= my.Offer.Coins then
				local offer = copyOffer(my.Offer)
				offer.Coins = n
				send(offer)
			end
		end)
		box.Parent = coinRow
	else
		for baitId, qty in side.Offer.Bait do
			local def = Bait.Get(baitId)
			Style.Label({ Text = string.format("%d× %s", qty, if def then def.Name else baitId), TextSize = Theme.TextSize.Small, AutoSize = "XY", LayoutOrder = 20, Parent = frame })
		end
		if side.Offer.Coins > 0 then
			Style.Label({ Text = Format.Coins(side.Offer.Coins) .. " koin", Font = "Bold", TextSize = Theme.TextSize.Body, Color = Theme.Color.Primary, AutoSize = "XY", LayoutOrder = 40, Parent = frame })
		end
	end
end

render = function()
	local view = current
	if view == nil then
		return
	end
	local my, their = sides(view)
	local mine = columns.Mine
	local focused = UserInputService:GetFocusedTextBox()
	-- Jangan hancurkan kotak koin yang sedang diketik; kolom sendiri dirender ulang setelah fokus lepas.
	if mine and not (focused and focused:IsDescendantOf(mine)) then
		renderColumn(mine, my, true)
	end
	if columns.Theirs then
		renderColumn(columns.Theirs :: Frame, their, false)
	end
	if columns.Warning then
		(columns.Warning :: TextLabel).Text = view.Warning or ""
	end
	local footer = columns.Footer
	if footer then
		clear(footer)
		Button.new({
			Text = if my.Ready then "Batal siap" else Strings.TradeReady,
			Variant = if my.Ready then "Quiet" else "Primary",
			Icon = "check",
			LayoutOrder = 2,
			Parent = footer,
			OnActivated = function()
				task.spawn(function()
					Net.Invoke("TradeSetReady", not my.Ready)
				end)
			end,
		})
		Button.new({
			Text = "Batalkan",
			Variant = "Danger",
			LayoutOrder = 3,
			Parent = footer,
			OnActivated = function()
				UIController.ClosePanel()
			end,
		})
		local cd = Style.Label({ Text = "", Font = "Bold", TextSize = Theme.TextSize.Body, Color = Theme.Color.Primary, AutoSize = "XY", LayoutOrder = 1, Parent = footer })
		columns.Countdown = cd
	end
end

local function openWindow(view: TradeView)
	local _, their = sides(view)
	local m = Modal.new({
		Title = Strings.TradeTitle,
		Subtitle = "Bertukar dengan " .. their.Name,
		Icon = "swap",
		Parent = UIController.Gui("Panel"),
		OnClose = function()
			UIController.ClosePanel()
		end,
	})
	local body = m.Body
	local mine = Style.Card({ Name = "Kamu", Size = UDim2.new(0.5, -Theme.Space.S, 1, -36), Parent = body })
	Style.Padding(mine, Theme.Space.M)
	Style.List(mine, "Vertical", Theme.Space.S)
	local theirs = Style.Card({ Name = "Mereka", Size = UDim2.new(0.5, -Theme.Space.S, 1, -36), Position = UDim2.new(0.5, Theme.Space.S, 0, 0), Parent = body })
	Style.Padding(theirs, Theme.Space.M)
	Style.List(theirs, "Vertical", Theme.Space.S)
	local warning = Style.Label({
		Text = "",
		Font = "Bold",
		TextSize = Theme.TextSize.Small,
		Color = Theme.Color.DangerText,
		Size = UDim2.new(1, 0, 0, 28),
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Parent = body,
	})
	local footer = m:GetFooter()
	Style.List(footer, "Horizontal", Theme.Space.S, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)
	columns = { Mine = mine, Theirs = theirs, Footer = footer, Warning = warning, Countdown = nil }
	modal = m
	ending = false
	UIController.OpenPanel({
		Name = "Trade",
		Panel = m :: any,
		Locked = true,
		OnClosed = function()
			if modal == m then
				modal = nil
				columns = {}
				if current and not ending then
					current = nil
					task.spawn(function()
						Net.Invoke("TradeCancel")
					end)
				end
				current = nil
			end
		end,
	})
end

local function closeWindow()
	ending = true
	current = nil
	if modal and UIController.CurrentPanel() == "Trade" then
		UIController.ClosePanel()
	end
end

-- ===================== Undangan =====================

local function showInvite(data: any)
	local root = UIController.Gui("Popup")
	local card = Style.Panel({
		Name = "UndanganTukar",
		AutoSize = "XY",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -Theme.Space.L, 0, UIController.TopInset() + 230),
		Parent = root,
	})
	Style.Padding(card, Theme.Space.M)
	Style.List(card, "Vertical", Theme.Space.S)
	Style.Stroke(card, 0.2, 1.5, Theme.Color.Secondary)
	Style.Label({ Text = string.format(Strings.TradeInviteFrom, tostring(data.FromName)), Font = "Bold", TextSize = Theme.TextSize.Body, AutoSize = "XY", LayoutOrder = 1, Parent = card })
	local timer = Style.Label({ Text = "", TextSize = Theme.TextSize.Small, Color = Theme.Color.TextSecondary, AutoSize = "XY", LayoutOrder = 2, Parent = card })
	local row = Style.Frame({ AutoSize = "XY", LayoutOrder = 3, Parent = card })
	Style.List(row, "Horizontal", Theme.Space.S)
	local done = false
	local function respond(accept: boolean)
		if done then
			return
		end
		done = true
		card:Destroy()
		task.spawn(function()
			local ok, msg = Net.Invoke("TradeRespond", data.InviteId, accept)
			if not ok and type(msg) == "string" then
				NotificationController.Show(msg, "Warning")
			end
		end)
	end
	Button.new({ Text = Strings.TradeAccept, Variant = "Primary", LayoutOrder = 1, Parent = row, OnActivated = function()
		respond(true)
	end })
	Button.new({ Text = Strings.TradeDecline, Variant = "Quiet", LayoutOrder = 2, Parent = row, OnActivated = function()
		respond(false)
	end })
	task.spawn(function()
		while not done and card.Parent do
			local left = (tonumber(data.ExpiresAt) or 0) - workspace:GetServerTimeNow()
			if left <= 0 then
				done = true
				card:Destroy()
				return
			end
			timer.Text = string.format("Kedaluwarsa dalam %d dtk", math.ceil(left))
			task.wait(0.25)
		end
	end)
end

-- ===================== Pemain di Sekitar =====================

function TradeController.OpenNearby()
	local m = Modal.new({
		Title = Strings.PlayersNearby,
		Icon = "users",
		MaxSize = Vector2.new(560, 560),
		Parent = UIController.Gui("Panel"),
		OnClose = function()
			UIController.ClosePanel()
		end,
	})
	local list = Style.Scroll({ Size = UDim2.fromScale(1, 1), Padding = Theme.Space.XS, Parent = m.Body })
	Style.List(list, "Vertical", Theme.Space.S)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local origin = if root and root:IsA("BasePart") then root.Position else nil
	local entries: { { Player: Player, Distance: number } } = {}
	if origin then
		for _, other in Players:GetPlayers() do
			if other ~= player then
				local oc = other.Character
				local orRoot = oc and oc:FindFirstChild("HumanoidRootPart")
				if orRoot and orRoot:IsA("BasePart") then
					local d = (orRoot.Position - origin).Magnitude
					if d <= Balance.Trade.InviteRange then
						table.insert(entries, { Player = other, Distance = d })
					end
				end
			end
		end
	end
	table.sort(entries, function(a, b)
		return a.Distance < b.Distance
	end)
	for i, e in entries do
		local row = Style.Card({ Size = UDim2.new(1, 0, 0, 64), LayoutOrder = i, Parent = list })
		Style.Padding(row, 0, Theme.Space.M, 0, Theme.Space.M)
		Style.Label({ Text = string.format("%s · %d stud", e.Player.DisplayName, math.floor(e.Distance)), Font = "Bold", TextSize = Theme.TextSize.Body, Size = UDim2.new(1, -180, 1, 0), Parent = row })
		local b = Button.new({
			Text = Strings.TradeInvite,
			Variant = "Secondary",
			Icon = "swap",
			Width = 170,
			Parent = row,
			OnActivated = function()
				task.spawn(function()
					local ok, msg = Net.Invoke("TradeInvite", e.Player.UserId)
					NotificationController.Show(if type(msg) == "string" then msg else "", if ok then "Success" else "Warning")
				end)
			end,
		})
		b.Instance.AnchorPoint = Vector2.new(1, 0.5)
		b.Instance.Position = UDim2.new(1, 0, 0.5, 0)
	end
	if #entries == 0 then
		Style.Label({ Text = Strings.PlayersNone .. " Dekati pemain lain atau tekan T di dekat mereka.", TextSize = Theme.TextSize.Body, Color = Theme.Color.TextSecondary, Wrap = true, AutoSize = "Y", Size = UDim2.new(1, 0, 0, 0), Parent = list })
	end
	UIController.OpenPanel({ Name = "Players", Panel = m :: any })
end

local function hideOwnPrompt(character: Model)
	task.spawn(function()
		local root = character:WaitForChild("HumanoidRootPart", 15)
		local prompt = root and root:WaitForChild("TradePrompt", 15)
		if prompt and prompt:IsA("ProximityPrompt") then
			prompt.Enabled = false
		end
	end)
end

function TradeController.Start()
	player.CharacterAdded:Connect(hideOwnPrompt)
	if player.Character then
		hideOwnPrompt(player.Character)
	end
	InputController.Hotkey:Connect(function(name)
		if name == "Players" then
			if UIController.CurrentPanel() == "Players" then
				UIController.ClosePanel()
			else
				TradeController.OpenNearby()
			end
		end
	end)
	Net.OnClientEvent("TradeEvent", function(kind: unknown, data: any)
		if kind == "Invite" then
			showInvite(data)
		elseif kind == "Open" or kind == "State" then
			local view = data :: TradeView
			if current == nil or modal == nil then
				current = view
				openWindow(view)
			end
			current = view
			render()
		elseif kind == "Completed" then
			closeWindow()
			NotificationController.Show(Strings.TradeDone, "Success")
		elseif kind == "Cancelled" then
			closeWindow()
			NotificationController.Show(string.format(Strings.TradeCancelled, tostring(if typeof(data) == "table" then data.Reason else "")), "Warning")
		end
	end)
	RunService.Heartbeat:Connect(function()
		local view = current
		local cd = columns.Countdown
		if view and cd then
			local ends = view.CountdownEndsAt
			cd.Text = if ends then string.format(Strings.TradeCountdown, math.max(0, math.ceil(ends - workspace:GetServerTimeNow()))) else ""
		end
	end)
end

return TradeController
