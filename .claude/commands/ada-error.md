---
description: Reproduksi & perbaiki error dari Output Studio sampai akar masalah, uji ulang, catat di PROGRESS.md
argument-hint: <tempel isi Output Studio>
---
[Ada error]
Ini isi Output Studio:
$ARGUMENTS

Reproduksi lewat playtest MCP (start_stop_play → get_console_output, server dan client), cari akar masalahnya (jangan cuma membungkam error — tidak boleh pcall kosong atau menghapus warn), perbaiki di file disk, jalankan scripts/check.ps1 dan scripts/test.ps1, uji ulang di Studio sampai Output bersih, lalu catat di docs/PROGRESS.md (gejala, akar masalah, perbaikan, bukti + tingkat bukti).
