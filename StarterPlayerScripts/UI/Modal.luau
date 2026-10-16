--!strict
-- Modal: cangkang panel besar (toko, tas, quest, fishdex, pengaturan). Scrim dan tumpukan panel dikelola
-- UIController; modul ini hanya panelnya. Header: ikon + judul FredokaOne + subjudul + tombol X 48 px.
-- Body = area konten ber-padding (pemanggil menambah isi). Footer dibuat saat pertama diminta.
-- Transisi: Show = fade + skala 0,97→1 selama 0,18 dtk, Hide = 0,12 dtk (keluar lebih cepat), instan bila
-- ReducedMotion. CanvasGroup hanya dipakai SELAMA transisi; setelahnya panel dipindah keluar agar teks tetap
-- tajam (tekstur CanvasGroup dibatasi kualitas grafis) dan ViewportFrame di dalamnya tetap tergambar.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Theme = require(Shared.Config.Theme)
local TweenUtil = require(Shared.Util.TweenUtil)
local Style = require(script.Parent.Style)
local Icon = require(script.Parent.Icon)

export type ModalProps = {
	Title: string,
	Subtitle: string?,
	Icon: Icon.IconName?,
	MaxSize: Vector2?,
	Name: string?,
	Parent: Instance,
	OnClose: (() -> ())?,
}

export type Modal = {
	Root: Frame,
	Header: Frame,
	Body: Frame,
	CloseButton: TextButton,
	SetTitle: (self: Modal, title: string) -> (),
	SetSubtitle: (self: Modal, text: string?) -> (),
	GetFooter: (self: Modal) -> Frame,
	Show: (self: Modal) -> (),
	Hide: (self: Modal, instant: boolean?) -> (),
	Destroy: (self: Modal) -> (),
}

local PAD = Theme.Space.XL
local HEADER_HEIGHT = 80
local FOOTER_HEIGHT = Theme.Size.ButtonHeight + Theme.Space.M * 2
local CLOSE_SIZE = Theme.Size.Touch
local HEADER_ICON = 32
-- Ruang di sekeliling panel di dalam CanvasGroup agar bayangan tidak terpotong selama transisi.
local MARGIN = Theme.Shadow.Blur + Theme.Shadow.OffsetY + Theme.Space.S

local Modal = {}

local function createCloseButton(onActivated: () -> ()): TextButton
	local button = Instance.new("TextButton")
	button.Name = "Close"
	button.Text = ""
	button.AutoButtonColor = false
	button.BackgroundTransparency = 1
	button.BorderSizePixel = 0
	button.Size = UDim2.fromOffset(CLOSE_SIZE, CLOSE_SIZE)
	button.AnchorPoint = Vector2.new(1, 0.5)
	-- Ikon X sejajar padding kanan konten (tombol 48 px, ikon 24 px di tengah).
	button.Position = UDim2.new(1, -(PAD - (CLOSE_SIZE - 24) / 2), 0.5, 0)
	button.Selectable = true
	button.SelectionImageObject = Style.SelectionImage()

	local skin = Style.Frame({
		Name = "Skin",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Color = Theme.Color.CardHover,
		Transparency = 1,
		Radius = Theme.Radius.Button,
	})
	local glyph = Icon.new("close", 24)
	glyph.AnchorPoint = Vector2.new(0.5, 0.5)
	glyph.Position = UDim2.fromScale(0.5, 0.5)
	glyph.Parent = skin
	skin.Parent = button

	Style.Interactive(button, skin, function(state: Style.InteractState)
		local lit = state.Hover or state.Focused or state.Pressed
		skin.BackgroundColor3 = if state.Pressed then Theme.Color.CardPressed else Theme.Color.CardHover
		TweenUtil.Play(skin, { BackgroundTransparency = if lit then 0 else 1 }, Theme.Motion.Exit)
	end)
	button.Activated:Connect(onActivated)
	return button
end

function Modal.new(props: ModalProps): Modal
	local root = Style.Frame({
		Name = props.Name or "Modal",
		Size = UDim2.fromScale(0.94, 0.9),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
	})
	root.Visible = false
	-- Navigasi gamepad terkurung di dalam panel.
	root.SelectionGroup = true
	root.SelectionBehaviorUp = Enum.SelectionBehavior.Stop
	root.SelectionBehaviorDown = Enum.SelectionBehavior.Stop
	root.SelectionBehaviorLeft = Enum.SelectionBehavior.Stop
	root.SelectionBehaviorRight = Enum.SelectionBehavior.Stop
	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize = props.MaxSize or Vector2.new(Theme.Size.PanelMaxWidth, Theme.Size.PanelMaxHeight)
	constraint.Parent = root
	local pop = Instance.new("UIScale")
	pop.Name = "Pop"
	pop.Parent = root

	local canvas = Instance.new("CanvasGroup")
	canvas.Name = "Transition"
	canvas.BackgroundTransparency = 1
	canvas.BorderSizePixel = 0
	canvas.Size = UDim2.new(1, MARGIN * 2, 1, MARGIN * 2)
	canvas.Position = UDim2.fromOffset(-MARGIN, -MARGIN)
	canvas.Visible = false
	canvas.Parent = root

	local panel = Style.Panel({ Name = "Panel" })
	-- Klik di atas panel tidak tembus ke scrim di belakangnya.
	panel.Active = true

	-- Header
	local header = Style.Frame({ Name = "Header", Size = UDim2.new(1, 0, 0, HEADER_HEIGHT) })
	local titleX = PAD
	if props.Icon then
		local glyph = Icon.new(props.Icon, HEADER_ICON, Theme.Color.TealText)
		glyph.AnchorPoint = Vector2.new(0, 0.5)
		glyph.Position = UDim2.new(0, PAD, 0.5, 0)
		glyph.Parent = header
		titleX = PAD + HEADER_ICON + Theme.Space.M
	end
	local titleGroup = Style.Frame({
		Name = "TitleGroup",
		Size = UDim2.new(1, -(titleX + PAD + CLOSE_SIZE), 0, 0),
		Position = UDim2.new(0, titleX, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		AutoSize = "Y",
	})
	Style.List(titleGroup, "Vertical", 0)
	local title = Style.Label({
		Name = "Title",
		Text = props.Title,
		Font = "Display",
		TextSize = Theme.TextSize.Title,
		Size = UDim2.new(1, 0, 0, math.ceil(Theme.TextSize.Title * 1.2)),
		LayoutOrder = 1,
		Parent = titleGroup,
	})
	local subtitle = Style.Label({
		Name = "Subtitle",
		Text = props.Subtitle or "",
		Color = Theme.Color.TextSecondary,
		TextSize = Theme.TextSize.Body,
		LayoutOrder = 2,
		Parent = titleGroup,
	})
	subtitle.Visible = props.Subtitle ~= nil and props.Subtitle ~= ""
	titleGroup.Parent = header

	local object: Modal
	local closeButton = createCloseButton(function()
		local callback = props.OnClose
		if callback then
			callback()
		else
			object:Hide()
		end
	end)
	closeButton.Parent = header
	header.Parent = panel

	-- Body
	local body = Style.Frame({
		Name = "Body",
		Position = UDim2.fromOffset(0, HEADER_HEIGHT),
		Size = UDim2.new(1, 0, 1, -HEADER_HEIGHT),
	})
	local bodyPadding = Style.Padding(body, 0, PAD, PAD, PAD)
	body.Parent = panel

	local footer: Frame? = nil

	local function placePanel(inCanvas: boolean)
		if inCanvas then
			panel.Position = UDim2.fromOffset(MARGIN, MARGIN)
			panel.Size = UDim2.new(1, -MARGIN * 2, 1, -MARGIN * 2)
			panel.Parent = canvas
			canvas.Visible = true
		else
			panel.Position = UDim2.fromOffset(0, 0)
			panel.Size = UDim2.fromScale(1, 1)
			panel.Parent = root
			canvas.Visible = false
		end
	end

	local seq = 0

	object = {
		Root = root,
		Header = header,
		Body = body,
		CloseButton = closeButton,
		SetTitle = function(_self: Modal, text: string)
			title.Text = text
		end,
		SetSubtitle = function(_self: Modal, text: string?)
			subtitle.Text = text or ""
			subtitle.Visible = text ~= nil and text ~= ""
		end,
		GetFooter = function(_self: Modal): Frame
			local existing = footer
			if existing then
				return existing
			end
			local divider = Style.Frame({
				Name = "FooterDivider",
				Size = UDim2.new(1, -PAD * 2, 0, 1),
				Position = UDim2.new(0, PAD, 1, -FOOTER_HEIGHT),
				Color = Theme.Color.Stroke,
				Transparency = Theme.Transparency.Stroke,
			})
			divider.Parent = panel
			local created = Style.Frame({
				Name = "Footer",
				Size = UDim2.new(1, 0, 0, FOOTER_HEIGHT),
				Position = UDim2.fromScale(0, 1),
				AnchorPoint = Vector2.new(0, 1),
			})
			Style.Padding(created, 0, PAD)
			Style.List(created, "Horizontal", Theme.Space.M, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)
			created.Parent = panel
			body.Size = UDim2.new(1, 0, 1, -(HEADER_HEIGHT + FOOTER_HEIGHT))
			bodyPadding.PaddingBottom = UDim.new(0, Theme.Space.L)
			footer = created
			return created
		end,
		Show = function(_self: Modal)
			seq += 1
			local token = seq
			root.Visible = true
			if TweenUtil.ReducedMotion() then
				pop.Scale = 1
				canvas.GroupTransparency = 0
				placePanel(false)
				return
			end
			placePanel(true)
			canvas.GroupTransparency = 1
			pop.Scale = Style.PressScale
			TweenUtil.Play(pop, { Scale = 1 }, Theme.Motion.Duration)
			local tween = TweenUtil.Play(canvas, { GroupTransparency = 0 }, Theme.Motion.Duration)
			Style.After(tween, function()
				if seq == token then
					placePanel(false)
				end
			end)
		end,
		Hide = function(_self: Modal, instant: boolean?)
			seq += 1
			local token = seq
			local function finish()
				root.Visible = false
				placePanel(false)
				pop.Scale = 1
				canvas.GroupTransparency = 0
			end
			if instant or not root.Visible or TweenUtil.ReducedMotion() then
				finish()
				return
			end
			placePanel(true)
			TweenUtil.Play(pop, { Scale = Style.PressScale }, Theme.Motion.Exit)
			local tween = TweenUtil.Play(canvas, { GroupTransparency = 1 }, Theme.Motion.Exit)
			Style.After(tween, function()
				if seq == token then
					finish()
				end
			end)
		end,
		Destroy = function(_self: Modal)
			seq += 1
			root:Destroy()
		end,
	}

	placePanel(false)
	root.Parent = props.Parent
	return object
end

return Modal
