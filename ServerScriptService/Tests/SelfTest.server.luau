--!strict
-- SelfTest: hanya berjalan di Studio dan bila atribut Workspace.RunSelfTests = true.
-- Menjalankan semua spesifikasi murni di Tests/Specs dan mencetak "[SELFTEST] LULUS x/y".

local RunService = game:GetService("RunService")

if not RunService:IsStudio() or workspace:GetAttribute("RunSelfTests") ~= true then
	return
end

local TestRunner = require(script.Parent.TestRunner)

local specsFolder = script.Parent:WaitForChild("Specs")
local specs: { Instance } = {}
for _, child in specsFolder:GetChildren() do
	if child:IsA("ModuleScript") then
		table.insert(specs, child)
	end
end
table.sort(specs, function(a, b)
	return a.Name < b.Name
end)

task.defer(function()
	-- require dinamis: path modul spesifikasi baru diketahui saat runtime.
	local dynamicRequire = require :: any
	TestRunner.RunAll(specs, function(m: any): any
		return dynamicRequire(m)
	end, print)
end)
