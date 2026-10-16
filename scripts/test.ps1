# Menjalankan uji modul murni di luar Studio dengan Lune (spesifikasi yang sama dengan SelfTest).
# Pakai:
#   powershell -ExecutionPolicy Bypass -File scripts/test.ps1            -> semua spesifikasi
#   powershell -ExecutionPolicy Bypass -File scripts/test.ps1 -Balance   -> BalanceSim (santai & aktif, 8 jam)
param([switch]$Balance, [double]$Hours = 8)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Push-Location $root
try {
	$lune = Join-Path $root '.tools\bin\lune.exe'
	if ($Balance) {
		& $lune run scripts/lune/run.luau balance $Hours
	}
	else {
		& $lune run scripts/lune/run.luau tests
	}
	exit $LASTEXITCODE
}
finally {
	Pop-Location
}
