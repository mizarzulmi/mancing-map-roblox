--!strict
-- Tabs: baris tab kategori. Tab aktif = teks terang + garis bawah emas 3 px (tumbuh dari tengah 0,18 dtk);
-- non-aktif = teks sekunder. Garis dasar tipis selebar baris. Setiap tab ≥ 48 px tinggi, jarak 8 px,
-- hover hanya pointer, tekan skala 0,97. Badge emas kecil opsional per tab (mis. hadiah siap diambil).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Theme = require(Shared.Config.Theme)
local TweenUtil = require(Shared.Util.TweenUtil)
local Style = require(script.Parent.Style)
local Icon = require(script.Parent.Icon)

export type TabItem = { Id: string, Label: string, Icon: Icon.IconName? }

export type TabsProps = {
	Items: { TabItem },
	Selected: string?,
	Parent: Instance?,
	LayoutOrder: number?,
	OnChanged: ((id: string) -> ())?,
}

export type Tabs = {
	Instance: Frame,
	Selected: string,
	Select: (self: Tabs, id: string, silent: boolean?) -> (),
	SetBadge: (self: Tabs, id: string, text: string?) -> (),
}

type TabView = {
	Button: TextButton,
	Skin: Frame,
	Label: TextLabel,
	Glyph: Frame?,
	Underline: Frame,
	Badge: Frame,
	BadgeText: TextLabel,
	Hover: boolean,
	Pressed: boolean,
	Focused: boolean,
}

local HEIGHT = Theme.Size.Touch
local PAD_X = Theme.Space.L
local GAP = Theme.Space.S
local ICON_SIZE = 22
local TEXT_SIZE = Theme.TextSize.Body
local UNDERLINE = 3
local BADGE_HEIGHT = 24

local Tabs = {}

function Tabs.new(props: TabsProps): Tabs
	local root = Style.Frame({ Name = "Tabs", Size = UDim2.new(1, 0, 0, HEIGHT) })
	if props.LayoutOrder then
		root.LayoutOrder = props.LayoutOrder
	end
	local row = Style.Frame({ Name = "Row" })
	Style.List(row, "Horizontal", GAP, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	row.Parent = root
	-- Garis dasar tipis tempat garis bawah emas duduk.
	local baseline = Style.Frame({
		Name = "Baseline",
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.fromScale(0, 1),
		AnchorPoint = Vector2.new(0, 1),
		Color = Theme.Color.Stroke,
		Transparency = Theme.Transparency.Stroke,
	})
	baseline.Parent = root

	local views: { [string]: TabView } = {}
	local firstId = if #props.Items > 0 then props.Items[1].Id else ""
	local selectedId = props.Selected or firstId

	local function widthFor(view: TabView): number
		local width = PAD_X * 2 + Style.Measure(view.Label.Text, TEXT_SIZE, "Bold").X + 2
		if view.Glyph then
			width += ICON_SIZE + GAP
		end
		if view.Badge.Visible then
			width += Style.BadgeWidth(view.BadgeText.Text, BADGE_HEIGHT) + GAP
		end
		return math.max(HEIGHT, width)
	end

	local function render(view: TabView, id: string, animate: boolean)
		local isSelected = id == selectedId
		local textColor = if isSelected or view.Hover or view.Focused then Theme.Color.Text else Theme.Color.TextSecondary
		view.Label.TextColor3 = textColor
		local glyph = view.Glyph
		if glyph then
			Icon.SetColor(glyph, textColor)
		end
		local lit = not isSelected and (view.Hover or view.Focused or view.Pressed)
		view.Skin.BackgroundColor3 = if view.Pressed then Theme.Color.CardPressed else Theme.Color.CardHover
		view.Skin.BackgroundTransparency = if lit then 0 else 1
		-- Garis bawah selebar isi tab (lebar tab dikurangi padding kiri-kanan).
		local target = if isSelected then UDim2.new(1, -PAD_X * 2, 0, UNDERLINE) else UDim2.fromOffset(0, UNDERLINE)
		if isSelected and animate then
			TweenUtil.Play(view.Underline, { Size = target }, Theme.Motion.Duration)
		else
			view.Underline.Size = target
		end
		view.Underline.Visible = isSelected
	end

	local object: Tabs

	for index, item in props.Items do
		local button = Instance.new("TextButton")
		button.Name = "Tab_" .. item.Id
		button.Text = ""
		button.AutoButtonColor = false
		button.BackgroundTransparency = 1
		button.BorderSizePixel = 0
		button.LayoutOrder = index
		button.Selectable = true
		button.SelectionImageObject = Style.SelectionImage()

		local skin = Style.Frame({
			Name = "Skin",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Color = Theme.Color.CardHover,
			Transparency = 1,
			Radius = Theme.Radius.Chip,
		})
		local content = Style.Frame({ Name = "Content" })
		Style.List(content, "Horizontal", GAP, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
		local glyph: Frame? = nil
		if item.Icon then
			local created = Icon.new(item.Icon, ICON_SIZE, Theme.Color.TextSecondary)
			created.LayoutOrder = 1
			created.Parent = content
			glyph = created
		end
		local label = Style.Label({
			Name = "Text",
			Text = item.Label,
			Font = "Bold",
			TextSize = TEXT_SIZE,
			Color = Theme.Color.TextSecondary,
			XAlign = Enum.TextXAlignment.Center,
			AutoSize = "X",
			Size = UDim2.fromScale(0, 1),
			LayoutOrder = 2,
			Parent = content,
		})
		local badge, badgeText = Style.Chip({
			Name = "Badge",
			Text = "",
			Height = BADGE_HEIGHT,
			Color = Theme.Color.Primary,
			TextColor = Theme.Color.TextOnAccent,
			LayoutOrder = 3,
			Parent = content,
		})
		badge.Visible = false
		content.Parent = skin
		skin.Parent = button

		local underline = Style.Frame({
			Name = "Underline",
			Size = UDim2.fromOffset(0, UNDERLINE),
			Position = UDim2.fromScale(0.5, 1),
			AnchorPoint = Vector2.new(0.5, 1),
			Color = Theme.Color.Primary,
			ZIndex = 2,
		})
		Style.Corner(underline, UNDERLINE)
		underline.Parent = button

		local view: TabView = {
			Button = button,
			Skin = skin,
			Label = label,
			Glyph = glyph,
			Underline = underline,
			Badge = badge,
			BadgeText = badgeText,
			Hover = false,
			Pressed = false,
			Focused = false,
		}
		views[item.Id] = view
		button.Size = UDim2.fromOffset(widthFor(view), HEIGHT)

		local id = item.Id
		Style.Interactive(button, skin, function(state: Style.InteractState)
			view.Hover, view.Pressed, view.Focused = state.Hover, state.Pressed, state.Focused
			render(view, id, false)
		end)
		button.Activated:Connect(function()
			object:Select(id)
		end)
		render(view, id, false)
		button.Parent = row
	end

	object = {
		Instance = root,
		Selected = selectedId,
		Select = function(self: Tabs, id: string, silent: boolean?)
			if views[id] == nil then
				warn("[Tabs] id tab tidak dikenal: " .. id)
				return
			end
			if id == selectedId then
				return
			end
			local previous = selectedId
			selectedId = id
			self.Selected = id
			local old = views[previous]
			if old then
				render(old, previous, false)
			end
			render(views[id], id, true)
			local callback = props.OnChanged
			if callback and not silent then
				callback(id)
			end
		end,
		SetBadge = function(_self: Tabs, id: string, text: string?)
			local view = views[id]
			if view == nil then
				return
			end
			Style.SetBadge(view.Badge, view.BadgeText, text, BADGE_HEIGHT)
			view.Button.Size = UDim2.fromOffset(widthFor(view), HEIGHT)
		end,
	}

	if props.Parent then
		root.Parent = props.Parent
	end
	return object
end

return Tabs
