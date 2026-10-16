--!strict
-- Logika murni sesi trade dua pihak: penawaran, status Siap, dan hitung mundur.
-- Aturan GDD 4.5: setiap perubahan isi mereset "Siap" kedua pihak; keduanya Siap → hitung mundur.

local Types = require(script.Parent.Types)
local Balance = require(script.Parent.Config.Balance)

type TradeOffer = Types.TradeOffer

export type Side = "A" | "B"

export type Session = {
	Id: string,
	Offers: { A: TradeOffer, B: TradeOffer },
	Ready: { A: boolean, B: boolean },
	CountdownEndsAt: number?,
	Version: number,
}

local TradeLogic = {}

function TradeLogic.EmptyOffer(): TradeOffer
	return { Fish = {}, Bait = {}, Coins = 0 }
end

function TradeLogic.New(id: string): Session
	return {
		Id = id,
		Offers = { A = TradeLogic.EmptyOffer(), B = TradeLogic.EmptyOffer() },
		Ready = { A = false, B = false },
		CountdownEndsAt = nil,
		Version = 0,
	}
end

local function offersEqual(a: TradeOffer, b: TradeOffer): boolean
	if a.Coins ~= b.Coins or #a.Fish ~= #b.Fish then
		return false
	end
	for i, uid in a.Fish do
		if b.Fish[i] ~= uid then
			return false
		end
	end
	for k, v in a.Bait do
		if (b.Bait[k] or 0) ~= v then
			return false
		end
	end
	for k, v in b.Bait do
		if (a.Bait[k] or 0) ~= v then
			return false
		end
	end
	return true
end

-- Mengganti penawaran satu sisi. Bila isi berubah: kedua Siap direset dan hitung mundur dibatalkan.
-- Mengembalikan true bila ada perubahan.
function TradeLogic.SetOffer(s: Session, side: Side, offer: TradeOffer): boolean
	local current = if side == "A" then s.Offers.A else s.Offers.B
	if offersEqual(current, offer) then
		return false
	end
	if side == "A" then
		s.Offers.A = offer
	else
		s.Offers.B = offer
	end
	s.Ready.A = false
	s.Ready.B = false
	s.CountdownEndsAt = nil
	s.Version += 1
	return true
end

-- Mengatur Siap satu sisi. Bila keduanya Siap, hitung mundur dimulai pada `now`.
function TradeLogic.SetReady(s: Session, side: Side, ready: boolean, now: number)
	if side == "A" then
		s.Ready.A = ready
	else
		s.Ready.B = ready
	end
	if s.Ready.A and s.Ready.B then
		if s.CountdownEndsAt == nil then
			s.CountdownEndsAt = now + Balance.Trade.CountdownSeconds
		end
	else
		s.CountdownEndsAt = nil
	end
	s.Version += 1
end

function TradeLogic.BothReady(s: Session): boolean
	return s.Ready.A and s.Ready.B
end

-- true bila hitung mundur sudah selesai dan pertukaran boleh dieksekusi.
function TradeLogic.ShouldExecute(s: Session, now: number): boolean
	local ends = s.CountdownEndsAt
	return ends ~= nil and TradeLogic.BothReady(s) and now >= ends
end

return TradeLogic
