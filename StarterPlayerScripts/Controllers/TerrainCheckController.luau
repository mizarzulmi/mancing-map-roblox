--!strict
-- TerrainCheckController (khusus Studio): diagnosis daratan di sisi client. Pemilik melihat pantai "tenggelam"
-- (permukaan berwarna air) padahal server membaca daratan padat & kering di titik yang sama (2026-10-16).
-- Raycast (dengan & tanpa air) + baca voxel di titik cek yang sama dengan server; hasil ke Output dengan awalan
-- "[Terrain/klien]" agar bisa dibandingkan dengan "[Terrain] cek darat" dari server.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local TerrainCheckController = {}

-- Titik darat yang sama dengan Terrain.luau (CHECK_POINTS) + satu titik laut sebagai pembanding.
local POINTS: { Vector2 } = {
	Vector2.new(0, 0),
	Vector2.new(0, 48),
	Vector2.new(-32, -16),
	Vector2.new(60, 40),
	Vector2.new(-60, 60),
	Vector2.new(220, 180),
	Vector2.new(0, 160),
}

local function describe(result: RaycastResult?): string
	if result == nil then
		return "kosong"
	end
	return string.format("%s/%s y=%.1f", result.Instance.Name, result.Material.Name, result.Position.Y)
end

local function columnReport(terrain: Terrain, p: Vector2): string
	local x0 = math.floor(p.X / 4) * 4
	local z0 = math.floor(p.Y / 4) * 4
	local region = Region3.new(Vector3.new(x0, 0, z0), Vector3.new(x0 + 4, 24, z0 + 4))
	local ok, data = pcall(function(): ...any
		return terrain:ReadVoxelChannels(region, 4, { "SolidOccupancy", "LiquidOccupancy" })
	end)
	if not ok or type(data) ~= "table" then
		return "voxel gagal dibaca"
	end
	local d = data :: any
	local solid, liquid = 0, 0
	for iy = 1, (d.Size :: Vector3).Y do
		solid += d.SolidOccupancy[1][iy][1] * 4
		liquid += d.LiquidOccupancy[1][iy][1] * 4
	end
	return string.format("voxel y0-24 padat %.1f air %.1f", solid, liquid)
end

local function check()
	local terrain = workspace.Terrain
	local withWater = RaycastParams.new()
	withWater.IgnoreWater = false
	local solidOnly = RaycastParams.new()
	solidOnly.IgnoreWater = true
	local lines: { string } = {}
	for _, p in POINTS do
		local origin = Vector3.new(p.X, 80, p.Y)
		local down = Vector3.new(0, -160, 0)
		table.insert(
			lines,
			string.format(
				"(%d,%d) pertama %s · padat %s · %s",
				p.X,
				p.Y,
				describe(workspace:Raycast(origin, down, withWater)),
				describe(workspace:Raycast(origin, down, solidOnly)),
				columnReport(terrain, p)
			)
		)
	end
	print("[Terrain/klien] StreamingEnabled=" .. tostring(workspace.StreamingEnabled) .. " | " .. table.concat(lines, " | "))
end

function TerrainCheckController.Start()
	if not RunService:IsStudio() then
		return
	end
	task.spawn(function()
		local player = Players.LocalPlayer
		local character = player.Character or player.CharacterAdded:Wait()
		if character:WaitForChild("HumanoidRootPart", 20) then
			task.wait(8) -- beri waktu streaming terrain di sekitar spawn
			check()
		end
	end)
end

return TerrainCheckController
