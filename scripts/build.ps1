# Membangun place file siap main: build/PantaiMancing.rbxl
# Buka file itu di Roblox Studio lalu tekan Play. Map dibangun otomatis saat server start
# bila Workspace.BeachMap belum ada (atau bake dulu lewat scripts/bake-command.luau).
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Push-Location $root
try {
	New-Item -ItemType Directory -Force -Path (Join-Path $root 'build') | Out-Null
	& (Join-Path $root '.tools\bin\rojo.exe') build default.project.json --output build/PantaiMancing.rbxl
	if ($LASTEXITCODE -ne 0) { throw 'rojo build gagal' }
	Write-Output ('[BUILD] OK -> ' + (Join-Path $root 'build\PantaiMancing.rbxl'))
}
finally {
	Pop-Location
}
