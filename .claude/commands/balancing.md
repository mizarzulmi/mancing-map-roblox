---
description: Jalankan BalanceSim (santai 2/menit & aktif 4/menit, 8 jam), bandingkan target GDD 4.2, usulkan tabel lama→baru
---
[Balancing]
Jalankan BalanceSim untuk pemain santai (2 tangkapan/menit) dan aktif (4/menit) selama 8 jam (`powershell -ExecutionPolicy Bypass -File scripts/test.ps1 -Balance`, atau di Studio lewat execute_luau Server: require(game.ServerScriptService.Tests.BalanceSim).PrintReport(...RunDefault(8), print)). Bandingkan dengan target di GDD 4.2, usulkan perubahan angka Config dalam tabel (file · kunci · lama → baru · alasan · dampak terukur dari simulasi ulang), JANGAN terapkan sebelum saya setuju. Setelah saya setuju: terapkan, jalankan scripts/test.ps1 + check.ps1, catat perubahan lama→baru di PROGRESS.md, commit.
$ARGUMENTS
