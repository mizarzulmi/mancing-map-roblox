--!strict
-- Tween standar proyek (0,18 dtk Quad Out) yang menghormati GuiService.ReducedMotionEnabled.

local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local TweenUtil = {}

TweenUtil.Duration = 0.18
TweenUtil.ExitDuration = 0.12

local forcedReduced = false

-- Pengaturan pemain (mode gerak minim) bisa memaksa motion dimatikan.
function TweenUtil.SetForcedReducedMotion(value: boolean)
	forcedReduced = value
end

function TweenUtil.ReducedMotion(): boolean
	if forcedReduced then
		return true
	end
	local ok, value = pcall(function()
		return GuiService.ReducedMotionEnabled
	end)
	return ok and value == true
end

function TweenUtil.Info(duration: number?, style: Enum.EasingStyle?, direction: Enum.EasingDirection?): TweenInfo
	return TweenInfo.new(
		duration or TweenUtil.Duration,
		style or Enum.EasingStyle.Quad,
		direction or Enum.EasingDirection.Out
	)
end

-- Memainkan tween; bila motion dikurangi, properti langsung diterapkan dan nil dikembalikan.
function TweenUtil.Play(
	instance: Instance,
	props: { [string]: any },
	duration: number?,
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?
): Tween?
	if TweenUtil.ReducedMotion() then
		for key, value in props do
			(instance :: any)[key] = value
		end
		return nil
	end
	local tween = TweenService:Create(instance, TweenUtil.Info(duration, style, direction), props)
	tween:Play()
	return tween
end

-- Animasi angka naik/turun pada label (mis. koin). formatter mengubah angka menjadi teks.
-- Mengembalikan fungsi pembatal; pemanggilan baru pada label yang sama membatalkan yang lama.
local activeCounters: { [Instance]: () -> () } = {}

function TweenUtil.CountUp(label: TextLabel, from: number, to: number, duration: number, formatter: (number) -> string): () -> ()
	local cancelOld = activeCounters[label]
	if cancelOld then
		cancelOld()
	end
	if TweenUtil.ReducedMotion() or duration <= 0 or from == to then
		label.Text = formatter(to)
		activeCounters[label] = nil
		return function() end
	end
	local start = os.clock()
	local conn: RBXScriptConnection? = nil
	local function cancel()
		if conn then
			conn:Disconnect()
			conn = nil
		end
		if activeCounters[label] == cancel then
			activeCounters[label] = nil
		end
	end
	conn = RunService.Heartbeat:Connect(function()
		local t = math.clamp((os.clock() - start) / duration, 0, 1)
		-- Ease-out eksponensial: cepat di awal, mengendap di akhir (seperti jarum timbangan).
		local eased = if t >= 1 then 1 else 1 - 2 ^ (-10 * t)
		label.Text = formatter(from + (to - from) * eased)
		if t >= 1 then
			label.Text = formatter(to)
			cancel()
		end
	end)
	activeCounters[label] = cancel
	return cancel
end

return TweenUtil
