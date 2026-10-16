--!strict
-- Format angka & waktu gaya Indonesia: pemisah ribuan titik, desimal koma.

local Format = {}

local function groupThousands(intStr: string): string
	local negative = string.sub(intStr, 1, 1) == "-"
	local digits = if negative then string.sub(intStr, 2) else intStr
	local out = {}
	local len = #digits
	for i = 1, len do
		table.insert(out, string.sub(digits, i, i))
		local remaining = len - i
		if remaining > 0 and remaining % 3 == 0 then
			table.insert(out, ".")
		end
	end
	return (if negative then "-" else "") .. table.concat(out)
end

-- 1500 -> "1.500"
function Format.Int(n: number): string
	local rounded = if n >= 0 then math.floor(n + 0.5) else -math.floor(-n + 0.5)
	return groupThousands(string.format("%d", rounded))
end

Format.Coins = Format.Int

-- 2.355, 2 -> "2,36"
function Format.Decimal(n: number, places: number): string
	local s = string.format("%." .. tostring(places) .. "f", n)
	local intPart, frac = string.match(s, "^(-?%d+)%.(%d+)$")
	if intPart == nil or frac == nil then
		return groupThousands(s)
	end
	return groupThousands(intPart) .. "," .. frac
end

-- Berat dalam kg dengan presisi menyesuaikan besar angka.
function Format.Kg(w: number): string
	if w < 0.1 then
		return Format.Decimal(w, 3) .. " kg"
	elseif w < 10 then
		return Format.Decimal(w, 2) .. " kg"
	elseif w < 100 then
		return Format.Decimal(w, 1) .. " kg"
	end
	return Format.Int(w) .. " kg"
end

-- ClockTime (0..24) -> "14:05"
function Format.Clock(clockTime: number): string
	local t = clockTime % 24
	local h = math.floor(t)
	local m = math.floor((t - h) * 60)
	return string.format("%02d:%02d", h, m)
end

-- Detik -> "4:05" atau "1:02:09"
function Format.Duration(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	local h = s // 3600
	local m = (s % 3600) // 60
	local sec = s % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, sec)
	end
	return string.format("%d:%02d", m, sec)
end

-- 0.45 -> "45%"
function Format.Percent(fraction: number, places: number?): string
	local p = places or 0
	if p == 0 then
		return Format.Int(fraction * 100) .. "%"
	end
	return Format.Decimal(fraction * 100, p) .. "%"
end

-- Angka bertanda: 0.1 -> "+0,10", -2 -> "-2"
function Format.Signed(n: number, places: number?): string
	local p = places or 0
	local body = if p == 0 then Format.Int(math.abs(n)) else Format.Decimal(math.abs(n), p)
	if n > 0 then
		return "+" .. body
	elseif n < 0 then
		return "-" .. body
	end
	return body
end

-- Pengali: 0.85 -> "×0,85"
function Format.Multiplier(n: number): string
	return "×" .. Format.Decimal(n, 2)
end

return Format
