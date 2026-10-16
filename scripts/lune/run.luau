--!nocheck
-- Harness Lune: menjalankan modul murni proyek di luar Roblox Studio.
-- Meniru `script`, `require(instance)`, `game:GetService` dan `Random` agar modul
-- yang sama persis dengan versi Studio bisa diuji tanpa diubah.
-- Pakai: lune run scripts/lune/run.luau tests
--        lune run scripts/lune/run.luau balance [jam]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local taskLib = require("@lune/task")

-- Shim Random: L'Ecuyer combined LCG. Semua perkalian < 2^53 sehingga eksak di double.
local Random = {}
Random.__index = Random

function Random.new(seed: number?)
	local s = math.floor(seed or os.clock() * 1e6)
	local self = setmetatable({}, Random)
	self._s1 = (math.abs(s) % 2147483562) + 1
	self._s2 = (math.abs(s * 7 + 12345) % 2147483398) + 1
	for _ = 1, 8 do
		self:_next()
	end
	return self
end

function Random:_next(): number
	self._s1 = (40014 * self._s1) % 2147483563
	self._s2 = (40692 * self._s2) % 2147483399
	local z = self._s1 - self._s2
	if z < 1 then
		z += 2147483562
	end
	return z / 2147483563
end

function Random:NextNumber(min: number?, max: number?): number
	local r = self:_next()
	if min == nil then
		return r
	end
	return min + (max - min) * r
end

function Random:NextInteger(min: number, max: number): number
	return min + math.floor(self:_next() * (max - min + 1))
end

function Random:Clone()
	local c = setmetatable({}, Random)
	c._s1 = self._s1
	c._s2 = self._s2
	return c
end

-- Pohon DataModel tiruan berdasarkan default.project.json
local SERVICE_DIRS = {
	ServerScriptService = "ServerScriptService",
	ReplicatedStorage = "ReplicatedStorage",
}

local nodeCache: { [string]: any } = {}
local moduleCache: { [string]: any } = {}

-- Pindai seluruh pohon file sekali di awal: fungsi fs Lune bersifat async dan tidak boleh
-- dipanggil dari dalam metamethod (__index), jadi metamethod hanya membaca cache ini.
local dirSet: { [string]: boolean } = {}
local fileSource: { [string]: string } = {}
local dirEntries: { [string]: { string } } = {}

local function scan(path: string)
	dirSet[path] = true
	local entries = fs.readDir(path)
	table.sort(entries)
	dirEntries[path] = entries
	for _, entry in entries do
		local full = path .. "/" .. entry
		if fs.isDir(full) then
			scan(full)
		elseif string.sub(entry, -5) == ".luau" then
			fileSource[full] = fs.readFile(full)
		end
	end
end

for _, root in SERVICE_DIRS do
	scan(root)
end

local Node = {}

local function makeNode(name: string, path: string, kind: string, parent: any)
	local key = path .. "|" .. kind
	if nodeCache[key] then
		return nodeCache[key]
	end
	local node = setmetatable({ __name = name, __path = path, __kind = kind, __parent = parent }, Node)
	nodeCache[key] = node
	return node
end

local function childOf(node, childName: string)
	if node.__kind ~= "Folder" then
		return nil
	end
	local base = node.__path .. "/" .. childName
	if dirSet[base] then
		return makeNode(childName, base, "Folder", node)
	elseif fileSource[base .. ".luau"] then
		return makeNode(childName, base .. ".luau", "ModuleScript", node)
	elseif fileSource[base .. ".server.luau"] then
		return makeNode(childName, base .. ".server.luau", "Script", node)
	elseif fileSource[base .. ".client.luau"] then
		return makeNode(childName, base .. ".client.luau", "LocalScript", node)
	end
	return nil
end

local function childrenOf(node)
	local list = {}
	if node.__kind ~= "Folder" then
		return list
	end
	for _, entry in dirEntries[node.__path] or {} do
		local name = entry
		name = string.gsub(name, "%.server%.luau$", "")
		name = string.gsub(name, "%.client%.luau$", "")
		name = string.gsub(name, "%.luau$", "")
		local c = childOf(node, name)
		if c then
			table.insert(list, c)
		end
	end
	return list
end

Node.__index = function(self, key)
	if key == "Name" then
		return rawget(self, "__name")
	elseif key == "Parent" then
		return rawget(self, "__parent")
	elseif key == "ClassName" then
		return rawget(self, "__kind")
	elseif key == "WaitForChild" or key == "FindFirstChild" then
		return function(this, childName)
			local c = childOf(this, childName)
			if c == nil and key == "WaitForChild" then
				error("WaitForChild: tidak ada " .. childName .. " di " .. this.__path)
			end
			return c
		end
	elseif key == "GetChildren" then
		return childrenOf
	elseif key == "IsA" then
		return function(this, className)
			return this.__kind == className
		end
	elseif key == "GetAttribute" then
		return function()
			return nil
		end
	elseif key == "GetFullName" then
		return function(this)
			return this.__path
		end
	end
	local c = childOf(self, key)
	if c == nil then
		error(string.format("%s bukan anggota %s", tostring(key), rawget(self, "__path")))
	end
	return c
end
Node.__tostring = function(self)
	return rawget(self, "__name")
end

local stubServices = {
	RunService = {
		IsStudio = function()
			return true
		end,
		IsServer = function()
			return true
		end,
		IsClient = function()
			return false
		end,
	},
	HttpService = {
		GenerateGUID = function(_, wrap)
			local hex = "0123456789ABCDEF"
			local out = {}
			for i = 1, 32 do
				local n = math.random(1, 16)
				table.insert(out, string.sub(hex, n, n))
				if i == 8 or i == 12 or i == 16 or i == 20 then
					table.insert(out, "-")
				end
			end
			local s = table.concat(out)
			return if wrap == false then s else "{" .. s .. "}"
		end,
	},
}

local game = {
	GetService = function(_, name)
		if SERVICE_DIRS[name] then
			return makeNode(name, SERVICE_DIRS[name], "Folder", nil)
		end
		local s = stubServices[name]
		if s == nil then
			error("Layanan tiruan tidak tersedia di Lune: " .. tostring(name))
		end
		return s
	end,
}

local requireModule

local function makeEnv(scriptNode)
	return {
		script = scriptNode,
		require = function(target)
			return requireModule(target)
		end,
		game = game,
		print = print,
		warn = function(...)
			print("[WARN]", ...)
		end,
		error = error,
		assert = assert,
		pcall = pcall,
		xpcall = xpcall,
		select = select,
		type = type,
		typeof = typeof,
		tostring = tostring,
		tonumber = tonumber,
		pairs = pairs,
		ipairs = ipairs,
		next = next,
		setmetatable = setmetatable,
		getmetatable = getmetatable,
		rawget = rawget,
		rawset = rawset,
		rawequal = rawequal,
		rawlen = rawlen,
		unpack = table.unpack,
		math = math,
		string = string,
		table = table,
		os = os,
		bit32 = bit32,
		utf8 = utf8,
		buffer = buffer,
		coroutine = coroutine,
		debug = debug,
		task = taskLib,
		Random = Random,
		Vector3 = roblox.Vector3,
		Vector2 = roblox.Vector2,
		CFrame = roblox.CFrame,
		Color3 = roblox.Color3,
		ColorSequence = roblox.ColorSequence,
		ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
		NumberSequence = roblox.NumberSequence,
		NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
		NumberRange = roblox.NumberRange,
		UDim = roblox.UDim,
		UDim2 = roblox.UDim2,
		Rect = roblox.Rect,
		Region3 = roblox.Region3,
		BrickColor = roblox.BrickColor,
		Font = roblox.Font,
		Enum = roblox.Enum,
	}
end

requireModule = function(target)
	if type(target) ~= "table" or rawget(target, "__kind") ~= "ModuleScript" then
		error("require: target bukan ModuleScript (" .. tostring(target) .. ")")
	end
	local path = rawget(target, "__path")
	if moduleCache[path] ~= nil then
		return moduleCache[path]
	end
	local source = fileSource[path]
	if source == nil then
		error("require: berkas tidak ditemukan " .. path)
	end
	local fn = luau.load(source, { debugName = path, environment = makeEnv(target) })
	local result = fn()
	moduleCache[path] = result
	return result
end

local mode = process.args[1] or "tests"
local sss = game:GetService("ServerScriptService")
local tests = sss.Tests

if mode == "tests" then
	local Runner = requireModule(tests.TestRunner)
	local passed, total = Runner.RunAll(childrenOf(tests.Specs), requireModule, print)
	process.exit(if passed == total then 0 else 1)
elseif mode == "balance" then
	local hours = tonumber(process.args[2]) or 8
	local Sim = requireModule(tests.BalanceSim)
	Sim.PrintReport(Sim.RunDefault(hours), print)
	process.exit(0)
elseif mode == "tinggi" then
	-- Tinggi rancangan terrain di pasangan (x z): lune run scripts/lune/run.luau tinggi 0 0 60 40
	local Terrain = requireModule(sss.World.Terrain)
	local i = 2
	while process.args[i + 1] ~= nil do
		local x, z = tonumber(process.args[i]) or 0, tonumber(process.args[i + 1]) or 0
		local h, m = Terrain.HeightAt(x, z)
		print(string.format("(%g, %g) tinggi %.2f %s", x, z, h, tostring(m)))
		i += 2
	end
	process.exit(0)
else
	print("Mode tidak dikenal: " .. tostring(mode))
	process.exit(2)
end
