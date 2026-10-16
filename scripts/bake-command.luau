--!strict
-- Bake map Pantai Nusantara ke Workspace.BeachMap + Workspace.Terrain + Lighting.
-- Jalankan di Command Bar Studio, atau lewat MCP:
--   python scripts/studio_mcp.py luau scripts/bake-command.luau --dm Edit
-- Memakai :Clone() folder ServerScriptService.World agar require tidak memakai cache modul lama.
-- Tidak menyentuh Workspace.CustomMap.

local ServerScriptService = game:GetService("ServerScriptService")

local source = ServerScriptService:FindFirstChild("World")
if not source then
	warn("[Bake] ServerScriptService.World tidak ditemukan — sinkronkan kode dulu (Script Sync / Rojo).")
	return
end

local clone = source:Clone()
local function run(): ...any
	local moduleScript = clone:FindFirstChild("MapBuilder")
	if not moduleScript or not moduleScript:IsA("ModuleScript") then
		error("ModuleScript MapBuilder tidak ada di folder World")
	end
	local MapBuilder = (require :: any)(moduleScript)
	return MapBuilder.Bake()
end

local ok, result = pcall(run)
clone:Destroy()

if ok and type(result) == "table" then
	local res = result :: { Parts: number, Seconds: number }
	print(
		string.format(
			"[Bake] BeachMap siap: %d part, %.1f dtk. Simpan place (Ctrl+S) agar hasil bake tersimpan.",
			res.Parts,
			res.Seconds
		)
	)
else
	warn("[Bake] gagal: " .. tostring(result))
end
