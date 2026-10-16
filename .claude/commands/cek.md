---
description: Verifikasi statis lengkap — luau-lsp strict, uji Lune, build place file
---
Jalankan berurutan dan laporkan ringkas:
1. `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check.ps1` → harus `[CHECK] luau-lsp: 0 masalah` (perbaiki bila ada).
2. `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test.ps1` → `[SELFTEST] LULUS x/x`.
3. `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build.ps1` → build/PantaiMancing.rbxl.
Tingkat bukti: "Dicek statis" (bukan "diuji di Studio").
$ARGUMENTS
