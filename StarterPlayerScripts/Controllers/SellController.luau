--!strict
-- SellController: menghubungkan dialog NPC ke panel jual/lepas. Bu Rina → Tas mode Jual (jual terpilih,
-- semua kecuali terkunci, per rarity; selalu dengan konfirmasi total). Kak Laut "Lepaskan ikan" → Tas dengan
-- multi-pilih aktif untuk melepas ikan (termasuk ikan dilindungi) demi Poin Konservasi.

local DialogController = require(script.Parent.DialogController)
local BagController = require(script.Parent.BagController)

local SellController = {}

function SellController.Start()
	DialogController.Action:Connect(function(npcId, action)
		if action == "Sell" then
			BagController.Open("Sell", npcId)
		elseif action == "Release" then
			BagController.Open("Bag", nil, true)
		end
	end)
end

return SellController
