--!strict
-- Token bucket per kunci (biasanya Player). Kapasitas = burst, isi ulang = rate token/detik.

export type RateLimiter = {
	Allow: (self: RateLimiter, key: any, cost: number?) -> boolean,
	Remove: (self: RateLimiter, key: any) -> (),
}

type Bucket = { tokens: number, updatedAt: number }

type Impl = {
	_rate: number,
	_burst: number,
	_buckets: { [any]: Bucket },
	_clock: () -> number,
}

local RateLimiter = {}
RateLimiter.__index = RateLimiter

function RateLimiter.Allow(self: Impl, key: any, cost: number?): boolean
	local need = cost or 1
	local now = self._clock()
	local b = self._buckets[key]
	if b == nil then
		b = { tokens = self._burst, updatedAt = now }
		self._buckets[key] = b
	end
	b.tokens = math.min(self._burst, b.tokens + (now - b.updatedAt) * self._rate)
	b.updatedAt = now
	if b.tokens < need then
		return false
	end
	b.tokens -= need
	return true
end

function RateLimiter.Remove(self: Impl, key: any)
	self._buckets[key] = nil
end

local module = {}

-- clock opsional untuk pengujian deterministik.
function module.new(rate: number, burst: number, clock: (() -> number)?): RateLimiter
	local self = setmetatable({
		_rate = rate,
		_burst = burst,
		_buckets = {},
		_clock = clock or os.clock,
	}, RateLimiter)
	return (self :: any) :: RateLimiter
end

return module
