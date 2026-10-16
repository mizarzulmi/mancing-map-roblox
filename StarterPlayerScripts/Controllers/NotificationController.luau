--!strict
-- NotificationController: toast di atas tengah layar (maks 3 sekaligus, masing-masing 3 dtk) dari remote
-- Notify server maupun dari controller lain. Tidak mencuri fokus.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Theme = require(Shared.Config.Theme)
local UIController = require(script.Parent.UIController)
local Toast = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Toast"))

local NotificationController = {}

local MAX_VISIBLE = 3
local DURATION = 3

local holder: Frame? = nil
local active: { Toast.Toast } = {}
local order = 0

local function position()
	local h = holder
	if h then
		h.Position = UDim2.new(0.5, 0, 0, UIController.TopInset() + 76)
	end
end

function NotificationController.Show(text: string, kind: Toast.ToastKind?)
	local h = holder
	if h == nil or text == "" then
		return
	end
	if #active >= MAX_VISIBLE then
		local oldest = table.remove(active, 1)
		if oldest then
			oldest:Dismiss()
		end
	end
	order += 1
	local toast = Toast.new({ Text = text, Kind = kind or "Info", Parent = h, LayoutOrder = order })
	table.insert(active, toast)
	task.delay(DURATION, function()
		local i = table.find(active, toast)
		if i then
			table.remove(active, i)
			toast:Dismiss()
		end
	end)
end

function NotificationController.Init()
	local root = UIController.Gui("Popup")
	local f = Instance.new("Frame")
	f.Name = "Toasts"
	f.AnchorPoint = Vector2.new(0.5, 0)
	f.BackgroundTransparency = 1
	f.Size = UDim2.fromOffset(520, 0)
	f.AutomaticSize = Enum.AutomaticSize.Y
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Padding = UDim.new(0, Theme.Space.S)
	list.Parent = f
	f.Parent = root
	holder = f
	position()
end

function NotificationController.Start()
	UIController.InsetChanged:Connect(position)
	Net.OnClientEvent("Notify", function(kind: unknown, text: unknown)
		if type(text) == "string" then
			NotificationController.Show(text, if type(kind) == "string" then kind :: any else "Info")
		end
	end)
end

return NotificationController
