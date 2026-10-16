--!strict
-- Pemilihan acak berbobot yang deterministik (urutan kunci eksplisit + Random yang diberikan pemanggil).

local WeightedRandom = {}

export type Entry<T> = { Item: T, Weight: number }

-- Memilih satu item dari daftar {Item, Weight}. Bobot <= 0 diabaikan. nil bila total bobot 0.
function WeightedRandom.Pick<T>(entries: { Entry<T> }, rng: Random): T?
	local total = 0
	for _, e in entries do
		if e.Weight > 0 then
			total += e.Weight
		end
	end
	if total <= 0 then
		return nil
	end
	local r = rng:NextNumber() * total
	local acc = 0
	local last: T? = nil
	for _, e in entries do
		if e.Weight > 0 then
			acc += e.Weight
			last = e.Item
			if r < acc then
				return e.Item
			end
		end
	end
	return last
end

-- Memilih kunci dari peta bobot dengan urutan iterasi tetap (order).
function WeightedRandom.PickKey(weights: { [string]: number }, order: { string }, rng: Random): string?
	local entries: { Entry<string> } = {}
	for _, key in order do
		local w = weights[key]
		if w ~= nil and w > 0 then
			table.insert(entries, { Item = key, Weight = w })
		end
	end
	return WeightedRandom.Pick(entries, rng)
end

-- Menormalkan peta bobot menjadi peluang (jumlah 1). Kunci berbobot 0 tetap 0.
function WeightedRandom.Normalize(weights: { [string]: number }): { [string]: number }
	local total = 0
	for _, w in weights do
		if w > 0 then
			total += w
		end
	end
	local out: { [string]: number } = {}
	for k, w in weights do
		out[k] = if total > 0 and w > 0 then w / total else 0
	end
	return out
end

return WeightedRandom
