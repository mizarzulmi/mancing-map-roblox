--!strict
-- ConfirmDialog: dialog konfirmasi (jual semua, lepaskan ikan, dsb.). Scrim hitam 50% sendiri (ketuk di luar =
-- batal), kartu panel di tengah: judul FredokaOne, isi, tombol Batal (Quiet, kiri) + tombol konfirmasi (varian
-- pemanggil, kanan). Fokus gamepad ke tombol AMAN (Batal) dulu; navigasi terkurung di kartu (SelectionGroup).
-- Esc/ButtonB menutup (ContextActionService di-bind saat terbuka, di-unbind saat tutup).
-- Mengembalikan fungsi penutup: menutup tanpa memanggil OnConfirm/OnCancel (dipakai saat konteks berubah).

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Theme = require(Shared.Config.Theme)
local Strings = require(Shared.Config.Strings)
local TweenUtil = require(Shared.Util.TweenUtil)
local Style = require(script.Parent.Style)
local Button = require(script.Parent.Button)

export type ConfirmDialogProps = {
	Parent: Instance,
	Title: string,
	Body: string,
	ConfirmText: string,
	CancelText: string?,
	Variant: Button.Variant?,
	OnConfirm: () -> (),
	OnCancel: (() -> ())?,
}

type CloseReason = "Confirm" | "Cancel" | "Silent"

local CARD_MAX_WIDTH = 480
local PAD = Theme.Space.XL
-- Scrim melebar ke luar area aman agar tepi layar (notch) ikut tertutup.
local SCRIM_BLEED = 200
local Z_INDEX = 50
local ACTION_PRIORITY = Enum.ContextActionPriority.High.Value + 50

local ConfirmDialog = {}

local counter = 0

function ConfirmDialog.Show(props: ConfirmDialogProps): () -> ()
	counter += 1
	local actionName = "ConfirmDialogClose_" .. tostring(counter)
	local closed = false
	local previousSelection = GuiService.SelectedObject

	local scrim = Instance.new("TextButton")
	scrim.Name = "ConfirmDialog"
	scrim.Text = ""
	scrim.AutoButtonColor = false
	scrim.BorderSizePixel = 0
	scrim.BackgroundColor3 = Theme.Color.Scrim
	scrim.BackgroundTransparency = 1
	scrim.Size = UDim2.new(1, SCRIM_BLEED * 2, 1, SCRIM_BLEED * 2)
	scrim.Position = UDim2.fromOffset(-SCRIM_BLEED, -SCRIM_BLEED)
	scrim.ZIndex = Z_INDEX
	scrim.Selectable = false
	scrim.Active = true

	-- 90% lebar layar yang terlihat (scrim lebih lebar 2 × SCRIM_BLEED), dibatasi CARD_MAX_WIDTH.
	local card = Style.Panel({
		Name = "Card",
		Size = UDim2.new(0.9, -SCRIM_BLEED * 2 * 0.9, 0, 0),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		AutoSize = "Y",
		ZIndex = Z_INDEX,
	})
	card.Active = true
	card.SelectionGroup = true
	card.SelectionBehaviorUp = Enum.SelectionBehavior.Stop
	card.SelectionBehaviorDown = Enum.SelectionBehavior.Stop
	card.SelectionBehaviorLeft = Enum.SelectionBehavior.Stop
	card.SelectionBehaviorRight = Enum.SelectionBehavior.Stop
	local width = Instance.new("UISizeConstraint")
	width.MaxSize = Vector2.new(CARD_MAX_WIDTH, math.huge)
	width.Parent = card
	local pop = Instance.new("UIScale")
	pop.Name = "Pop"
	pop.Parent = card
	Style.Padding(card, PAD)
	Style.List(card, "Vertical", Theme.Space.M)

	Style.Label({
		Name = "Title",
		Text = props.Title,
		Font = "Display",
		TextSize = Theme.TextSize.Heading,
		Wrap = true,
		AutoSize = "Y",
		LayoutOrder = 1,
		Parent = card,
	})
	Style.Label({
		Name = "Body",
		Text = props.Body,
		TextSize = Theme.TextSize.Body,
		Wrap = true,
		AutoSize = "Y",
		LayoutOrder = 2,
		Parent = card,
	})

	local row = Style.Frame({
		Name = "Actions",
		Size = UDim2.new(1, 0, 0, Theme.Size.ButtonHeight + Theme.Space.M),
		LayoutOrder = 3,
	})
	Style.Padding(row, Theme.Space.M, 0, 0, 0)
	Style.List(row, "Horizontal", Theme.Space.M, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Bottom)

	local fadeTargets: { Style.FadeTarget } = {}

	local function close(reason: CloseReason)
		if closed then
			return
		end
		closed = true
		ContextActionService:UnbindAction(actionName)
		local selectedNow = GuiService.SelectedObject
		if selectedNow and selectedNow:IsDescendantOf(scrim) then
			local previous = previousSelection
			GuiService.SelectedObject = if previous and previous.Parent then previous else nil
		end
		scrim.Active = false
		TweenUtil.Play(scrim, { BackgroundTransparency = 1 }, Theme.Motion.Exit)
		TweenUtil.Play(pop, { Scale = Style.PressScale }, Theme.Motion.Exit)
		local tween = Style.Fade(fadeTargets, 1, Theme.Motion.Exit)
		Style.After(tween, function()
			scrim:Destroy()
		end)
		if reason == "Confirm" then
			props.OnConfirm()
		elseif reason == "Cancel" then
			local onCancel = props.OnCancel
			if onCancel then
				onCancel()
			end
		end
	end

	local cancelButton = Button.new({
		Name = "Cancel",
		Text = props.CancelText or Strings.Cancel,
		Variant = "Quiet",
		Size = UDim2.new(0.5, -Theme.Space.M / 2, 0, Theme.Size.ButtonHeight),
		LayoutOrder = 1,
		Parent = row,
		OnActivated = function()
			close("Cancel")
		end,
	})
	Button.new({
		Name = "Confirm",
		Text = props.ConfirmText,
		Variant = props.Variant or "Primary",
		Size = UDim2.new(0.5, -Theme.Space.M / 2, 0, Theme.Size.ButtonHeight),
		LayoutOrder = 2,
		Parent = row,
		OnActivated = function()
			close("Confirm")
		end,
	})
	row.Parent = card
	card.Parent = scrim

	-- Ketuk area gelap di luar kartu = batal.
	scrim.Activated:Connect(function()
		close("Cancel")
	end)
	-- Bila induknya dihancurkan selagi terbuka, binding Esc/B tidak boleh tertinggal.
	scrim.Destroying:Connect(function()
		if not closed then
			closed = true
			ContextActionService:UnbindAction(actionName)
		end
	end)

	-- Semua elemen di atas scrim memakai ZIndex yang sama agar tumpukannya konsisten.
	for _, descendant in card:GetDescendants() do
		if descendant:IsA("GuiObject") then
			descendant.ZIndex = Z_INDEX
		end
	end

	-- Masuk: scrim gelap 50%, kartu fade + skala 0,97→1.
	fadeTargets = Style.CollectFade(card)
	Style.Fade(fadeTargets, 1)
	pop.Scale = Style.PressScale
	scrim.Parent = props.Parent
	TweenUtil.Play(scrim, { BackgroundTransparency = Theme.Transparency.Scrim }, Theme.Motion.Duration)
	TweenUtil.Play(pop, { Scale = 1 }, Theme.Motion.Duration)
	Style.Fade(fadeTargets, 0, Theme.Motion.Duration)

	ContextActionService:BindActionAtPriority(
		actionName,
		function(_name: string, state: Enum.UserInputState, _input: InputObject): Enum.ContextActionResult?
			if state == Enum.UserInputState.Begin then
				close("Cancel")
			end
			return Enum.ContextActionResult.Sink
		end,
		false,
		ACTION_PRIORITY,
		Enum.KeyCode.Escape,
		Enum.KeyCode.ButtonB
	)

	if Style.IsGamepad() then
		GuiService.SelectedObject = cancelButton.Instance
	end

	return function()
		close("Silent")
	end
end

return ConfirmDialog
