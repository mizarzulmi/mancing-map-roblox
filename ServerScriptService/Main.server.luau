--!strict
-- Bootstrap server: membuat semua Remote, me-require semua service di folder Services,
-- memanggil semua Init (tanpa yield) lalu semua Start. Kegagalan satu modul dicatat dengan namanya.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

-- Urutan mengikuti lapisan dependensi (docs/PLAN.md §Lapisan). Modul baru yang tidak tercantum
-- tetap dimuat, setelah daftar ini, urut abjad.
local PRIORITY = {
	"DataService",
	"EconomyService",
	"InventoryService",
	"WorldService",
	"NPCService",
	"LevelService",
	"ConservationService",
	"FishingService",
	"ShopService",
	"SellService",
	"BarterService",
	"FishdexService",
	"FerryService",
	"CosmeticService",
	"TradeService",
	"QuestService",
	"AchievementService",
	"LeaderboardService",
	"DebugService",
}

type Module = {
	Init: (() -> ...any)?,
	Start: (() -> ...any)?,
}

local function collectOrder(folder: Instance): { ModuleScript }
	local byName: { [string]: ModuleScript } = {}
	for _, child in folder:GetChildren() do
		if child:IsA("ModuleScript") then
			byName[child.Name] = child
		end
	end
	local ordered: { ModuleScript } = {}
	local used: { [string]: boolean } = {}
	for _, name in PRIORITY do
		local m = byName[name]
		if m then
			table.insert(ordered, m)
			used[name] = true
		end
	end
	local extras: { string } = {}
	for name in byName do
		if not used[name] then
			table.insert(extras, name)
		end
	end
	table.sort(extras)
	for _, name in extras do
		table.insert(ordered, byName[name])
	end
	return ordered
end

local function boot()
	Net.Init()

	local servicesFolder = script.Parent:WaitForChild("Services")
	local loaded: { { Name: string, Module: Module } } = {}

	for _, moduleScript in collectOrder(servicesFolder) do
		local ok, result = pcall(require, moduleScript)
		if ok and type(result) == "table" then
			table.insert(loaded, { Name = moduleScript.Name, Module = result :: Module })
		else
			warn(string.format("[Main] gagal memuat %s: %s", moduleScript.Name, tostring(result)))
		end
	end

	for _, entry in loaded do
		local init = entry.Module.Init
		if init then
			local ok, err = pcall(init)
			if not ok then
				warn(string.format("[Main] %s.Init gagal: %s", entry.Name, tostring(err)))
			end
		end
	end

	for _, entry in loaded do
		local start = entry.Module.Start
		if start then
			local ok, err = pcall(start)
			if not ok then
				warn(string.format("[Main] %s.Start gagal: %s", entry.Name, tostring(err)))
			end
		end
	end

	print(string.format("[Main] server siap: %d service", #loaded))
end

boot()
