--!strict
-- Bootstrap client: me-require semua controller di folder Controllers, memanggil semua Init lalu Start.
-- Kegagalan satu controller dicatat dengan namanya dan tidak menghentikan yang lain.

local PRIORITY = {
	"DataController",
	"SettingsController",
	"UIController",
	"NotificationController",
	"SoundController",
	"DayNightController",
	"HUDController",
	"InputController",
	"FishingController",
	"MinigameController",
	"CatchPopupController",
	"DialogController",
	"ShopController",
	"BagController",
	"SellController",
	"BarterController",
	"TradeController",
	"QuestController",
	"FishdexController",
	"FerryController",
	"NPCController",
	"AmbientController",
	"WeatherFXController",
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
	local folder = script.Parent:WaitForChild("Controllers", 30)
	if folder == nil then
		warn("[Main] folder Controllers tidak ditemukan")
		return
	end
	local loaded: { { Name: string, Module: Module } } = {}

	for _, moduleScript in collectOrder(folder) do
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
end

boot()
