--!strict
-- Validasi argumen remote di server. Semua fungsi mengembalikan nilai tervalidasi atau nil.
-- Penolakan dicatat lewat Guard.Reject agar format warn seragam: (UserId, remote, alasan).

local Guard = {}

local function isFinite(n: number): boolean
	return n == n and n ~= math.huge and n ~= -math.huge
end

function Guard.Num(v: unknown, min: number, max: number): number?
	if typeof(v) ~= "number" then
		return nil
	end
	local n = v :: number
	if not isFinite(n) or n < min or n > max then
		return nil
	end
	return n
end

function Guard.Int(v: unknown, min: number, max: number): number?
	local n = Guard.Num(v, min, max)
	if n == nil or n ~= math.floor(n) then
		return nil
	end
	return n
end

function Guard.Bool(v: unknown): boolean?
	if typeof(v) ~= "boolean" then
		return nil
	end
	return v :: boolean
end

function Guard.Str(v: unknown, maxLen: number): string?
	if typeof(v) ~= "string" then
		return nil
	end
	local s = v :: string
	if #s == 0 or #s > maxLen then
		return nil
	end
	return s
end

-- String yang harus menjadi kunci di tabel allowlist (mis. id Config).
function Guard.Id<T>(v: unknown, allow: { [string]: T }): string?
	local s = Guard.Str(v, 64)
	if s == nil or allow[s] == nil then
		return nil
	end
	return s
end

-- String yang harus salah satu dari daftar nilai.
function Guard.OneOf(v: unknown, options: { string }): string?
	local s = Guard.Str(v, 64)
	if s == nil then
		return nil
	end
	for _, o in options do
		if o == s then
			return s
		end
	end
	return nil
end

-- Array string unik (mis. daftar Uid ikan), panjang 1..maxCount.
function Guard.StrList(v: unknown, maxCount: number, maxLen: number): { string }?
	if typeof(v) ~= "table" then
		return nil
	end
	local t = v :: { [any]: any }
	local out: { string } = {}
	local seen: { [string]: boolean } = {}
	local count = 0
	for k, item in t do
		count += 1
		if count > maxCount or typeof(k) ~= "number" then
			return nil
		end
		local s = Guard.Str(item, maxLen)
		if s == nil or seen[s] then
			return nil
		end
		seen[s] = true
		table.insert(out, s)
	end
	if #out == 0 or #out ~= count then
		return nil
	end
	return out
end

-- Peta string -> bilangan bulat (mis. umpan yang ditawarkan di trade).
function Guard.IntMap(v: unknown, maxKeys: number, allow: { [string]: any }, maxValue: number): { [string]: number }?
	if typeof(v) ~= "table" then
		return nil
	end
	local out: { [string]: number } = {}
	local count = 0
	for k, value in v :: { [any]: any } do
		count += 1
		if count > maxKeys then
			return nil
		end
		local key = Guard.Id(k, allow)
		local n = Guard.Int(value, 0, maxValue)
		if key == nil or n == nil then
			return nil
		end
		if n > 0 then
			out[key] = n
		end
	end
	return out
end

-- Warn dibatasi: maksimal satu baris per (pemain, remote) tiap 5 detik, sisanya dihitung lalu dilaporkan.
local lastWarn: { [string]: number } = {}
local suppressed: { [string]: number } = {}
local WARN_INTERVAL = 5

function Guard.Reject(player: Player, remote: string, reason: string)
	local key = tostring(player.UserId) .. "|" .. remote
	local now = os.clock()
	local last = lastWarn[key]
	if last ~= nil and now - last < WARN_INTERVAL then
		suppressed[key] = (suppressed[key] or 0) + 1
		return
	end
	lastWarn[key] = now
	local extra = suppressed[key]
	suppressed[key] = nil
	warn(
		string.format(
			"[Guard] tolak UserId=%d remote=%s alasan=%s%s",
			player.UserId,
			remote,
			reason,
			if extra then string.format(" (+%d penolakan lain)", extra) else ""
		)
	)
end

-- Dipanggil saat pemain keluar agar tabel tidak tumbuh.
function Guard.Forget(player: Player)
	local prefix = tostring(player.UserId) .. "|"
	for key in lastWarn do
		if string.sub(key, 1, #prefix) == prefix then
			lastWarn[key] = nil
			suppressed[key] = nil
		end
	end
end

return Guard
