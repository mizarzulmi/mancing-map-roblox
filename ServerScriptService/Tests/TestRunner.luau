--!strict
-- Penjalan spesifikasi uji murni. Dipakai SelfTest.server.luau (Studio) dan scripts/lune/run.luau (Lune).
-- Setiap modul Specs mengembalikan function(t: T).

export type T = {
	Check: (cond: boolean, name: string, detail: string?) -> (),
	Near: (actual: number, expected: number, tolerance: number, name: string) -> (),
	Equal: (actual: any, expected: any, name: string) -> (),
}

local TestRunner = {}

-- Menjalankan semua spesifikasi. Mengembalikan (lulus, total).
function TestRunner.RunAll(specModules: { any }, requireFn: (any) -> any, log: (...any) -> ()): (number, number)
	local passed = 0
	local total = 0
	local failures: { string } = {}
	local currentSpec = ""

	local function record(ok: boolean, name: string, detail: string?)
		total += 1
		if ok then
			passed += 1
		else
			table.insert(failures, string.format("%s › %s%s", currentSpec, name, if detail then " (" .. detail .. ")" else ""))
		end
	end

	local t: T = {
		Check = function(cond: boolean, name: string, detail: string?)
			record(cond == true, name, if cond then nil else detail)
		end,
		Near = function(actual: number, expected: number, tolerance: number, name: string)
			local ok = math.abs(actual - expected) <= tolerance
			record(ok, name, if ok then nil else string.format("dapat %.5f, harap %.5f ±%.5f", actual, expected, tolerance))
		end,
		Equal = function(actual: any, expected: any, name: string)
			local ok = actual == expected
			record(ok, name, if ok then nil else string.format("dapat %s, harap %s", tostring(actual), tostring(expected)))
		end,
	}

	for _, m in specModules do
		currentSpec = tostring(m.Name)
		local okLoad, spec = pcall(requireFn, m)
		if not okLoad or type(spec) ~= "function" then
			record(false, "memuat spesifikasi", tostring(spec))
		else
			local okRun, err = pcall(spec :: any, t)
			if not okRun then
				record(false, "spesifikasi crash", tostring(err))
			end
		end
	end

	log(string.format("[SELFTEST] %s %d/%d", if passed == total then "LULUS" else "GAGAL", passed, total))
	for _, f in failures do
		log("[SELFTEST]   gagal: " .. f)
	end
	return passed, total
end

return TestRunner
