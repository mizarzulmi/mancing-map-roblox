--!strict
-- Style: helper pembuat instance UI bertema. Semua komponen di folder UI memakai helper ini agar warna, radius,
-- garis tepi, bayangan, tipografi, state interaksi, dan fade konsisten. Tidak ada hex mentah: semua dari Theme.
-- Komponen tidak membuat ScreenGui; UIController yang membuatnya.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local Theme = require(Shared.Config.Theme)
local TweenUtil = require(Shared.Util.TweenUtil)

export type FontName = "Display" | "Body" | "Bold"
export type AutoSize = "X" | "Y" | "XY"

export type LabelProps = {
	Text: string,
	Name: string?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	TextSize: number?,
	Font: FontName?,
	Color: Color3?,
	XAlign: Enum.TextXAlignment?,
	YAlign: Enum.TextYAlignment?,
	Wrap: boolean?,
	AutoSize: AutoSize?,
	LayoutOrder: number?,
	Parent: Instance?,
	RichText: boolean?,
}

export type FrameProps = {
	Name: string?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Color: Color3?,
	Transparency: number?,
	Radius: number?,
	Stroke: boolean?,
	LayoutOrder: number?,
	AutoSize: AutoSize?,
	Clip: boolean?,
	Parent: Instance?,
	ZIndex: number?,
}

export type ScrollProps = {
	Name: string?,
	Size: UDim2?,
	Position: UDim2?,
	Direction: ("Vertical" | "Horizontal")?,
	Gap: number?, -- jarak konten ke scrollbar (sisi scrollbar)
	Padding: number?, -- padding konten di semua sisi
	LayoutOrder: number?,
	Parent: Instance?,
}

export type ChipProps = {
	Text: string,
	Name: string?,
	Color: Color3?, -- latar; nil = transparan
	Transparency: number?,
	TextColor: Color3?,
	Stroke: boolean?,
	Height: number?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	ZIndex: number?,
	Parent: Instance?,
}

-- State interaksi tombol: Hover hanya untuk pointer (mouse), Pressed dari GuiState, Focused dari seleksi gamepad.
export type InteractState = { Hover: boolean, Pressed: boolean, Focused: boolean }

export type FadeTarget = { Instance: Instance, Property: string, Base: number }

local Style = {}

-- Skala tekan untuk umpan balik sentuh/klik (UIScale di dalam tombol).
Style.PressScale = 0.97
-- Ketebalan scrollbar tipis bertema (px sebelum UIScale global).
local SCROLLBAR_THICKNESS = 6

local function autoSizeEnum(value: AutoSize?): Enum.AutomaticSize
	if value == "X" then
		return Enum.AutomaticSize.X
	elseif value == "Y" then
		return Enum.AutomaticSize.Y
	elseif value == "XY" then
		return Enum.AutomaticSize.XY
	end
	return Enum.AutomaticSize.None
end

-- FontFace dari nama font tema.
function Style.FontFace(name: FontName?): Font
	if name == "Display" then
		return Theme.Font.Display
	elseif name == "Bold" then
		return Theme.Font.Bold
	end
	return Theme.Font.Body
end

-- Mengukur teks satu baris (px logis) dengan keluarga font yang sama dengan FontFace tema.
-- Dipakai komponen yang lebarnya dihitung (tombol, tab, chip) agar UIScale tekan tidak menggeser layout.
function Style.Measure(text: string, textSize: number, font: FontName?): Vector2
	local enumFont = if font == "Display"
		then Enum.Font.FredokaOne
		elseif font == "Bold" then Enum.Font.BuilderSansBold
		else Enum.Font.BuilderSansMedium
	local ok, size = pcall(function(): Vector2
		return TextService:GetTextSize(text, textSize, enumFont, Vector2.new(10000, 10000))
	end)
	if ok and typeof(size) == "Vector2" then
		return Vector2.new(math.ceil(size.X), math.ceil(size.Y))
	end
	local length = utf8.len(text) or #text
	return Vector2.new(math.ceil(length * textSize * 0.56), textSize)
end

function Style.Corner(parent: GuiObject, radius: number?): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or Theme.Radius.Card)
	corner.Parent = parent
	return corner
end

-- Garis tepi standar: putih, transparansi 0,85, 1 px, selalu di border (bukan di teks).
function Style.Stroke(parent: GuiObject, transparency: number?, thickness: number?, color: Color3?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Color = color or Theme.Color.Stroke
	stroke.Transparency = if transparency ~= nil then transparency else Theme.Transparency.Stroke
	stroke.Thickness = thickness or 1
	stroke.Parent = parent
	return stroke
end

-- Satu angka = semua sisi; urutan seperti CSS (atas, kanan, bawah, kiri).
function Style.Padding(parent: GuiObject, top: number, right: number?, bottom: number?, left: number?): UIPadding
	local r = if right ~= nil then right else top
	local b = if bottom ~= nil then bottom else top
	local l = if left ~= nil then left else r
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, top)
	padding.PaddingRight = UDim.new(0, r)
	padding.PaddingBottom = UDim.new(0, b)
	padding.PaddingLeft = UDim.new(0, l)
	padding.Parent = parent
	return padding
end

-- Bayangan lembut ber-offset (UIShadow). Kelas baru: dibuat dalam pcall; nil bila klien belum mendukung.
function Style.Shadow(parent: GuiObject): Instance?
	local ok, result = pcall(function(): Instance
		local shadow = Instance.new("UIShadow")
		shadow.Name = "Shadow"
		shadow.Color = Theme.Color.Shadow
		shadow.Transparency = Theme.Transparency.Shadow
		shadow.BlurRadius = UDim.new(0, Theme.Shadow.Blur)
		shadow.Offset = UDim2.fromOffset(0, Theme.Shadow.OffsetY)
		shadow.Spread = UDim2.fromOffset(0, 0)
		shadow.Parent = parent
		return shadow
	end)
	if ok and typeof(result) == "Instance" then
		return result
	end
	return nil
end

function Style.List(
	parent: GuiObject,
	direction: "Vertical" | "Horizontal",
	gap: number,
	hAlign: Enum.HorizontalAlignment?,
	vAlign: Enum.VerticalAlignment?
): UIListLayout
	local list = Instance.new("UIListLayout")
	list.FillDirection = if direction == "Horizontal" then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
	list.Padding = UDim.new(0, gap)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.HorizontalAlignment = hAlign or Enum.HorizontalAlignment.Left
	list.VerticalAlignment = vAlign or Enum.VerticalAlignment.Top
	list.Parent = parent
	return list
end

function Style.Grid(parent: GuiObject, cellSize: UDim2, gap: number): UIGridLayout
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = cellSize
	grid.CellPadding = UDim2.fromOffset(gap, gap)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Left
	grid.VerticalAlignment = Enum.VerticalAlignment.Top
	grid.Parent = parent
	return grid
end

function Style.Label(props: LabelProps): TextLabel
	local textSize = props.TextSize or Theme.TextSize.Body
	local lineHeight = math.ceil(textSize * 1.25)
	local label = Instance.new("TextLabel")
	label.Name = props.Name or "Label"
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.FontFace = Style.FontFace(props.Font)
	label.TextSize = textSize
	label.TextColor3 = props.Color or Theme.Color.Text
	label.Text = props.Text
	label.RichText = props.RichText == true
	label.TextXAlignment = props.XAlign or Enum.TextXAlignment.Left
	label.TextYAlignment = props.YAlign or Enum.TextYAlignment.Center
	label.TextWrapped = props.Wrap == true
	if props.Wrap then
		label.LineHeight = 1.1
	end
	local auto: AutoSize? = props.AutoSize
	label.AutomaticSize = autoSizeEnum(auto)
	-- Teks satu baris yang lebarnya tetap dipotong rapi (…) daripada meluber keluar kartu.
	if not props.Wrap and auto ~= "X" and auto ~= "XY" then
		label.TextTruncate = Enum.TextTruncate.AtEnd
	end
	if props.Size then
		label.Size = props.Size
	elseif auto == "XY" then
		label.Size = UDim2.fromOffset(0, 0)
	elseif auto == "X" then
		label.Size = UDim2.fromOffset(0, lineHeight)
	elseif auto == "Y" then
		label.Size = UDim2.fromScale(1, 0)
	else
		label.Size = UDim2.new(1, 0, 0, lineHeight)
	end
	if props.Position then
		label.Position = props.Position
	end
	if props.AnchorPoint then
		label.AnchorPoint = props.AnchorPoint
	end
	if props.LayoutOrder then
		label.LayoutOrder = props.LayoutOrder
	end
	if props.Parent then
		label.Parent = props.Parent
	end
	return label
end

-- Frame dasar; transparan bila Color nil.
function Style.Frame(props: FrameProps): Frame
	local frame = Instance.new("Frame")
	frame.Name = props.Name or "Frame"
	frame.BorderSizePixel = 0
	if props.Color then
		frame.BackgroundColor3 = props.Color
		frame.BackgroundTransparency = props.Transparency or 0
	else
		frame.BackgroundTransparency = 1
	end
	frame.Size = props.Size or UDim2.fromScale(1, 1)
	if props.Position then
		frame.Position = props.Position
	end
	if props.AnchorPoint then
		frame.AnchorPoint = props.AnchorPoint
	end
	if props.LayoutOrder then
		frame.LayoutOrder = props.LayoutOrder
	end
	if props.ZIndex then
		frame.ZIndex = props.ZIndex
	end
	frame.AutomaticSize = autoSizeEnum(props.AutoSize)
	frame.ClipsDescendants = props.Clip == true
	if props.Radius then
		Style.Corner(frame, props.Radius)
	end
	if props.Stroke then
		Style.Stroke(frame)
	end
	if props.Parent then
		frame.Parent = props.Parent
	end
	return frame
end

local function withSurface(props: FrameProps, color: Color3, transparency: number, radius: number): FrameProps
	return {
		Name = props.Name,
		Size = props.Size,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		Color = props.Color or color,
		Transparency = if props.Transparency ~= nil then props.Transparency else transparency,
		Radius = props.Radius or radius,
		Stroke = props.Stroke ~= false,
		LayoutOrder = props.LayoutOrder,
		AutoSize = props.AutoSize,
		Clip = props.Clip,
		Parent = nil, -- di-parent paling akhir oleh pemanggil
		ZIndex = props.ZIndex,
	}
end

-- Kartu: permukaan #16404D, radius 10, garis tepi tipis. Tanpa bayangan (kartu duduk di atas panel).
function Style.Card(props: FrameProps): Frame
	local frame = Style.Frame(withSurface(props, Theme.Color.Card, Theme.Transparency.Card, Theme.Radius.Card))
	if props.Parent then
		frame.Parent = props.Parent
	end
	return frame
end

-- Panel: permukaan #0F2F3A nyaris opak, radius 12, garis tepi tipis, bayangan lembut ber-offset.
function Style.Panel(props: FrameProps): Frame
	local frame = Style.Frame(withSurface(props, Theme.Color.Panel, Theme.Transparency.Panel, Theme.Radius.Panel))
	Style.Shadow(frame)
	if props.Parent then
		frame.Parent = props.Parent
	end
	return frame
end

-- ScrollingFrame bertema: canvas otomatis, scrollbar tipis. Layout (List/Grid) dipilih pemanggil.
function Style.Scroll(props: ScrollProps): ScrollingFrame
	local horizontal = props.Direction == "Horizontal"
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = props.Name or "Scroll"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Size = props.Size or UDim2.fromScale(1, 1)
	if props.Position then
		scroll.Position = props.Position
	end
	if props.LayoutOrder then
		scroll.LayoutOrder = props.LayoutOrder
	end
	scroll.CanvasSize = UDim2.fromOffset(0, 0)
	scroll.AutomaticCanvasSize = if horizontal then Enum.AutomaticSize.X else Enum.AutomaticSize.Y
	scroll.ScrollingDirection = if horizontal then Enum.ScrollingDirection.X else Enum.ScrollingDirection.Y
	scroll.ScrollBarThickness = SCROLLBAR_THICKNESS
	scroll.ScrollBarImageColor3 = Theme.Color.TextSecondary
	scroll.ScrollBarImageTransparency = 0.45
	scroll.VerticalScrollBarInset = if horizontal then Enum.ScrollBarInset.None else Enum.ScrollBarInset.Always
	scroll.HorizontalScrollBarInset = if horizontal then Enum.ScrollBarInset.Always else Enum.ScrollBarInset.None
	scroll.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
	-- Navigasi gamepad langsung ke isi (kartu/tombol), bukan ke bingkai scroll; mesin menggulir mengikuti seleksi.
	scroll.Selectable = false
	scroll.SelectionImageObject = Style.SelectionImage()
	local pad = props.Padding or 0
	local gap = props.Gap or Theme.Space.S
	if horizontal then
		Style.Padding(scroll, pad, pad, pad + gap, pad)
	else
		Style.Padding(scroll, pad, pad + gap, pad, pad)
	end
	if props.Parent then
		scroll.Parent = props.Parent
	end
	return scroll
end

-- Objek seleksi gamepad bertema: cincin emas tipis 2 px berjarak 2 px dari elemen. Satu instance dipakai ulang
-- oleh semua elemen (mesin hanya menggambarnya pada objek yang sedang terseleksi).
local selectionImage: Frame? = nil

function Style.SelectionImage(): GuiObject
	local existing = selectionImage
	if existing then
		return existing
	end
	local ring = Instance.new("Frame")
	ring.Name = "SelectionRing"
	ring.BackgroundTransparency = 1
	ring.BorderSizePixel = 0
	ring.Size = UDim2.new(1, 4, 1, 4)
	ring.Position = UDim2.fromOffset(-2, -2)
	Style.Corner(ring, Theme.Radius.Button + 2)
	Style.Stroke(ring, 0, 2, Theme.Color.Primary)
	selectionImage = ring
	return ring
end

-- Chip kecil (hotkey, badge, status). Radius chip 8 (bukan pill), lebar mengikuti teks.
function Style.Chip(props: ChipProps): (Frame, TextLabel)
	local height = props.Height or 26
	local chip = Instance.new("Frame")
	chip.Name = props.Name or "Chip"
	chip.BorderSizePixel = 0
	if props.Color then
		chip.BackgroundColor3 = props.Color
		chip.BackgroundTransparency = props.Transparency or 0
	else
		chip.BackgroundTransparency = 1
	end
	chip.AutomaticSize = Enum.AutomaticSize.X
	chip.Size = UDim2.fromOffset(0, height)
	if props.Position then
		chip.Position = props.Position
	end
	if props.AnchorPoint then
		chip.AnchorPoint = props.AnchorPoint
	end
	if props.LayoutOrder then
		chip.LayoutOrder = props.LayoutOrder
	end
	if props.ZIndex then
		chip.ZIndex = props.ZIndex
	end
	Style.Corner(chip, Theme.Radius.Chip)
	if props.Stroke then
		Style.Stroke(chip)
	end
	Style.Padding(chip, 0, Theme.Space.S)
	local minWidth = Instance.new("UISizeConstraint")
	minWidth.MinSize = Vector2.new(height, height)
	minWidth.Parent = chip
	local label = Style.Label({
		Name = "Text",
		Text = props.Text,
		Font = "Bold",
		TextSize = Theme.TextSize.Small,
		Color = props.TextColor or Theme.Color.Text,
		XAlign = Enum.TextXAlignment.Center,
		AutoSize = "X",
		Size = UDim2.fromScale(0, 1),
		Parent = chip,
	})
	if props.ZIndex then
		label.ZIndex = props.ZIndex
	end
	if props.Parent then
		chip.Parent = props.Parent
	end
	return chip, label
end

-- Badge pada chip dari Style.Chip: nil = sembunyi, "" = titik penanda kecil, teks = chip berisi teks.
function Style.SetBadge(chip: Frame, label: TextLabel, text: string?, height: number)
	if text == nil then
		chip.Visible = false
		return
	end
	label.Text = text
	local constraint = chip:FindFirstChildOfClass("UISizeConstraint")
	if text == "" then
		local dot = math.floor(height / 2)
		chip.AutomaticSize = Enum.AutomaticSize.None
		chip.Size = UDim2.fromOffset(dot, dot)
		if constraint then
			constraint.MinSize = Vector2.new(dot, dot)
		end
	else
		chip.AutomaticSize = Enum.AutomaticSize.X
		chip.Size = UDim2.fromOffset(0, height)
		if constraint then
			constraint.MinSize = Vector2.new(height, height)
		end
	end
	chip.Visible = true
end

-- Lebar chip badge untuk perhitungan lebar komponen (selaras dengan SetBadge).
function Style.BadgeWidth(text: string, height: number): number
	if text == "" then
		return math.floor(height / 2)
	end
	return math.max(height, Style.Measure(text, Theme.TextSize.Small, "Bold").X + Theme.Space.S * 2)
end

-- Input utama pemain (PreferredInput): hover hanya relevan untuk pointer; chip hotkey hanya untuk keyboard.
function Style.IsPointer(): boolean
	return UserInputService.PreferredInput == Enum.PreferredInput.KeyboardAndMouse
end

function Style.IsGamepad(): boolean
	local preferred = UserInputService.PreferredInput
	return preferred == Enum.PreferredInput.Gamepad or preferred == Enum.PreferredInput.MicroGamepad
end

function Style.OnInputChanged(fn: () -> ()): RBXScriptConnection
	return UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(fn)
end

local function isKeyOrPad(input: InputObject?): boolean
	if input == nil then
		return false
	end
	local inputType = input.UserInputType
	return inputType == Enum.UserInputType.Keyboard or string.find(inputType.Name, "^Gamepad") ~= nil
end

-- Mengikat state interaksi tombol: GuiState (Hover/Press) + seleksi gamepad + umpan balik tekan skala 0,97
-- pada scaleTarget (UIScale dibuat di dalamnya). Aktivasi lewat tombol A / Enter memberi denyut tekan singkat.
-- Mengembalikan fungsi pemutus; koneksi juga diputus otomatis saat tombol dihancurkan.
function Style.Interactive(button: GuiButton, scaleTarget: GuiObject?, onChange: ((state: InteractState) -> ())?): () -> ()
	local scale: UIScale? = nil
	if scaleTarget then
		local created = Instance.new("UIScale")
		created.Name = "PressScale"
		created.Parent = scaleTarget
		scale = created
	end
	local state: InteractState = { Hover = false, Pressed = false, Focused = false }
	local wasPressed = false

	local function update()
		local guiState = button.GuiState
		state.Pressed = guiState == Enum.GuiState.Press
		state.Hover = guiState == Enum.GuiState.Hover and Style.IsPointer()
		local target = scale
		if target and state.Pressed ~= wasPressed then
			if state.Pressed then
				TweenUtil.Play(target, { Scale = Style.PressScale }, Theme.Motion.Exit)
			else
				TweenUtil.Play(target, { Scale = 1 }, Theme.Motion.Duration)
			end
		end
		wasPressed = state.Pressed
		if onChange then
			onChange(state)
		end
	end

	local conns: { RBXScriptConnection } = {}
	table.insert(conns, button:GetPropertyChangedSignal("GuiState"):Connect(update))
	table.insert(
		conns,
		button.SelectionGained:Connect(function()
			state.Focused = true
			update()
		end)
	)
	table.insert(
		conns,
		button.SelectionLost:Connect(function()
			state.Focused = false
			update()
		end)
	)
	table.insert(
		conns,
		button.Activated:Connect(function(input: InputObject)
			local target = scale
			if target == nil or state.Pressed or not isKeyOrPad(input) then
				return
			end
			local tween = TweenUtil.Play(target, { Scale = Style.PressScale }, Theme.Motion.Exit)
			if tween then
				tween.Completed:Once(function(playback: Enum.PlaybackState)
					if playback == Enum.PlaybackState.Completed and not state.Pressed then
						TweenUtil.Play(target, { Scale = 1 }, Theme.Motion.Duration)
					end
				end)
			end
		end)
	)
	local inputConn = Style.OnInputChanged(update)
	local function cleanup()
		for _, conn in conns do
			conn:Disconnect()
		end
		table.clear(conns)
		inputConn:Disconnect()
	end
	table.insert(conns, button.Destroying:Connect(cleanup))
	return cleanup
end

-- Fade kelompok tanpa CanvasGroup (teks tetap tajam): kumpulkan semua properti transparansi beserta nilai dasarnya,
-- lalu Fade(alpha) menuju base + (1 - base) * alpha. alpha 0 = tampil normal, 1 = hilang.
function Style.CollectFade(root: Instance): { FadeTarget }
	local targets: { FadeTarget } = {}
	local function add(inst: Instance, property: string, base: number)
		if base < 1 then
			table.insert(targets, { Instance = inst, Property = property, Base = base })
		end
	end
	local function consider(inst: Instance)
		if inst:IsA("GuiObject") then
			add(inst, "BackgroundTransparency", inst.BackgroundTransparency)
			if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
				add(inst, "TextTransparency", (inst :: any).TextTransparency)
			elseif inst:IsA("ImageLabel") or inst:IsA("ImageButton") or inst:IsA("ViewportFrame") then
				add(inst, "ImageTransparency", (inst :: any).ImageTransparency)
			end
		elseif inst:IsA("UIStroke") or inst:IsA("UIShadow") then
			add(inst, "Transparency", (inst :: any).Transparency)
		end
	end
	consider(root)
	for _, descendant in root:GetDescendants() do
		consider(descendant)
	end
	return targets
end

-- Menerapkan fade; duration nil/0 = instan. Mengembalikan salah satu tween (semua berdurasi sama) atau nil bila
-- instan (termasuk ReducedMotion), agar pemanggil bisa menunggu selesai.
function Style.Fade(targets: { FadeTarget }, alpha: number, duration: number?): Tween?
	local first: Tween? = nil
	for _, target in targets do
		local value = target.Base + (1 - target.Base) * alpha
		if duration and duration > 0 then
			local tween = TweenUtil.Play(target.Instance, { [target.Property] = value }, duration)
			if first == nil then
				first = tween
			end
		else
			(target.Instance :: any)[target.Property] = value
		end
	end
	return first
end

-- Menjalankan fn setelah tween selesai normal (bukan dibatalkan tween baru); langsung bila tween nil (instan).
function Style.After(tween: Tween?, fn: () -> ())
	if tween == nil then
		fn()
		return
	end
	tween.Completed:Once(function(playback: Enum.PlaybackState)
		if playback == Enum.PlaybackState.Completed then
			fn()
		end
	end)
end

return Style
