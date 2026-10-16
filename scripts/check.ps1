# Analisis statis seluruh kode Luau:
#   1) rojo sourcemap  -> agar luau-lsp paham script.Parent / require antar-modul
#   2) luau-lsp analyze -> type check strict + lint dengan definisi API Roblox resmi
#   3) selene (opsional) -> lint tambahan (API deprecated, dsb.)
# Pakai: powershell -ExecutionPolicy Bypass -File scripts/check.ps1 [-Selene] [-Files a.luau,b.luau]
param([switch]$Selene, [string[]]$Files, [string]$Sourcemap = 'sourcemap.json')

$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot
Push-Location $root
try {
	$bin = Join-Path $root '.tools\bin'
	if (-not (Test-Path (Join-Path $bin 'luau-lsp.exe'))) {
		Write-Output 'Toolchain belum ada. Jalankan dulu: scripts/setup-tools.ps1'
		exit 2
	}
	$smDir = Split-Path -Parent $Sourcemap
	if ($smDir -and -not (Test-Path $smDir)) { New-Item -ItemType Directory -Force -Path $smDir | Out-Null }
	& (Join-Path $bin 'rojo.exe') sourcemap default.project.json --output $Sourcemap
	if ($LASTEXITCODE -ne 0) { Write-Output 'rojo sourcemap gagal'; exit 1 }

	$targets = if ($Files) { $Files } else { @('ServerScriptService', 'ReplicatedStorage', 'StarterPlayerScripts') }
	& (Join-Path $bin 'luau-lsp.exe') analyze `
		--platform=roblox `
		--sourcemap=$Sourcemap `
		--definitions=@roblox=.tools/defs/globalTypes.d.luau `
		--base-luaurc=.luaurc `
		--ignore='**/Packages/**' `
		$targets
	$code = $LASTEXITCODE
	if ($code -eq 0) { Write-Output '[CHECK] luau-lsp: 0 masalah' } else { Write-Output "[CHECK] luau-lsp: ada masalah (exit $code)" }

	if ($Selene) {
		& (Join-Path $bin 'selene.exe') ServerScriptService/Services ServerScriptService/World ServerScriptService/Tests ReplicatedStorage StarterPlayerScripts
		if ($LASTEXITCODE -ne 0) { $code = 1 }
	}
	exit $code
}
finally {
	Pop-Location
}
