# Mengunduh toolchain proyek ke .tools/ (lokal, tidak mengubah PATH sistem).
# Jalankan sekali:  powershell -ExecutionPolicy Bypass -File scripts/setup-tools.ps1
# Versi dipin agar hasil analisis sama di semua mesin. Ubah di sini jika ingin upgrade.
param([switch]$Force)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$root = Split-Path -Parent $PSScriptRoot
$toolsDir = Join-Path $root '.tools'
$binDir = Join-Path $toolsDir 'bin'
$defsDir = Join-Path $toolsDir 'defs'
New-Item -ItemType Directory -Force -Path $binDir, $defsDir | Out-Null

$tools = @(
	@{ Name = 'rojo';     Exe = 'rojo.exe';     Url = 'https://github.com/rojo-rbx/rojo/releases/download/v7.7.1/rojo-7.7.1-windows-x86_64.zip' },
	@{ Name = 'luau-lsp'; Exe = 'luau-lsp.exe'; Url = 'https://github.com/JohnnyMorganz/luau-lsp/releases/download/1.70.1/luau-lsp-win64.zip' },
	@{ Name = 'lune';     Exe = 'lune.exe';     Url = 'https://github.com/lune-org/lune/releases/download/v0.10.5/lune-0.10.5-windows-x86_64.zip' },
	@{ Name = 'selene';   Exe = 'selene.exe';   Url = 'https://github.com/Kampfkarren/selene/releases/download/0.31.0/selene-0.31.0-windows.zip' },
	@{ Name = 'stylua';   Exe = 'stylua.exe';   Url = 'https://github.com/JohnnyMorganz/StyLua/releases/download/v2.5.2/stylua-windows-x86_64.zip' }
)

foreach ($t in $tools) {
	$target = Join-Path $binDir $t.Exe
	if ((Test-Path $target) -and -not $Force) {
		Write-Output ("[ok] {0} sudah ada" -f $t.Name)
		continue
	}
	# Setiap arsip diekstrak ke folder kosong sendiri sebelum exe disalin ke bin.
	$work = Join-Path $toolsDir ("dl-" + $t.Name)
	if (Test-Path $work) { Remove-Item -Recurse -Force $work }
	New-Item -ItemType Directory -Force -Path $work | Out-Null
	$zip = Join-Path $work 'pkg.zip'
	Write-Output ("[..] mengunduh {0}" -f $t.Name)
	Invoke-WebRequest -Uri $t.Url -OutFile $zip -UseBasicParsing
	Expand-Archive -Path $zip -DestinationPath (Join-Path $work 'x') -Force
	$found = Get-ChildItem -Recurse -Path (Join-Path $work 'x') -Filter $t.Exe | Select-Object -First 1
	if (-not $found) { throw ("{0} tidak ditemukan di arsip" -f $t.Exe) }
	Copy-Item $found.FullName $target -Force
	Remove-Item -Recurse -Force $work
	Write-Output ("[ok] {0} -> {1}" -f $t.Name, $target)
}

# Definisi tipe Roblox untuk luau-lsp (dipin ke tag rilis yang sama).
$defs = @(
	@{ File = 'globalTypes.d.luau'; Url = 'https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/1.70.1/scripts/globalTypes.None.d.luau' }
)
foreach ($d in $defs) {
	$out = Join-Path $defsDir $d.File
	if ((Test-Path $out) -and -not $Force) { Write-Output ("[ok] {0} sudah ada" -f $d.File); continue }
	Invoke-WebRequest -Uri $d.Url -OutFile $out -UseBasicParsing
	Write-Output ("[ok] {0}" -f $d.File)
}

Write-Output ''
Write-Output 'Selesai. Cek: scripts/check.ps1 (analisis), scripts/build.ps1 (bikin .rbxl), scripts/test.ps1 (uji modul murni).'
