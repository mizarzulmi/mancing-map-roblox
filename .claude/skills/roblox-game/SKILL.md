---
name: roblox-game
description: >
  Router pengembangan game Roblox untuk proyek ini: menentukan mode kerja (MCP Studio native, jembatan
  scripts/studio_mcp.py, atau offline), memilih alur (fitur baru, debug loop, audit performa, audit keamanan,
  checklist rilis, review kode), dan daftar "sharp edges" Roblox yang wajib diingat. Pakai saat memulai tugas
  Roblox/Luau apa pun di repo ini, saat debugging error Output Studio, sebelum publish, atau saat ragu skill
  mana yang dimuat.
---

# Roblox Game — router kerja

Proyek: **Pantai Mancing Nusantara**. Aturan wajib: `AGENTS.md`. Kontrak modul: `docs/PLAN.md`. Status: `docs/PROGRESS.md`.

## 1. Deteksi mode (lakukan pertama)

| Mode | Tanda | Cara kerja |
|---|---|---|
| **MCP native** | tool `mcp__Roblox_Studio__*` tersedia | `list_roblox_studios` → `get_studio_state` → kerja langsung |
| **Jembatan** | tool MCP tidak ada, tetapi Studio terbuka & "Enable Studio as MCP server" aktif | `python scripts/studio_mcp.py status` / `tools` / `call <tool> '<json>'` / `luau <file> --dm Edit` |
| **Offline** | Studio tertutup | verifikasi statis: `scripts/check.ps1`, `scripts/test.ps1`, `scripts/build.ps1`; tulis langkah manual di `docs/TESTING.md` |

Jangan pernah melaporkan "sudah diuji di Studio" dari mode offline.

## 2. Routing tugas

| Niat | Muat / lakukan |
|---|---|
| Fitur/sistem baru | `pantai-mancing` (peta & kontrak) → skill domain (`roblox-networking`, `roblox-datastores`, `roblox-characters`, `roblox-physics`) |
| UI/tampilan | WAJIB `ui-ux-pro-max` + `impeccable` + `taste-design` (aturan global pemilik) → `roblox-ui` → `docs/UI-DIRECTION.md` |
| Map / model 3D | `roblox-procedural-3d` → bake + screenshot (`roblox-studio-mcp`) |
| Error di Output | debug loop di bawah + `roblox-studio-mcp` |
| Performa | audit performa di bawah |
| Keamanan / exploit | audit keamanan di bawah + `roblox-networking` |
| Rilis / publish | checklist rilis di bawah |
| Konten (ikan/item/quest/NPC) | cukup Config → `scripts/test.ps1` (ConfigSpec) |

## 3. Debug loop (error Output)
1. Reproduksi: `start_stop_play` → `get_console_output` (server **dan** client).
2. Temukan baris & modul asal; baca kodenya; cari akar masalah (jangan membungkam error dengan pcall kosong).
3. Perbaiki di file disk → `scripts/check.ps1` → ulang playtest → Output bersih.
4. Catat di `docs/PROGRESS.md` (gejala, akar masalah, perbaikan, bukti).

## 4. Audit performa
- Hitung part BeachMap (MapBuilder mencetak total; target ≤ 6.000).
- Cari loop per objek (`while true` per instance) → ganti satu Heartbeat + CollectionService tag.
- Dekorasi: CanCollide/CanQuery/CanTouch=false, CastShadow=false untuk detail kecil.
- ViewportFrame & ParticleEmitter: batasi jumlah aktif; mode grafis rendah mematikan efek ambient.
- MicroProfiler (Ctrl+F6) saat playtest bila FPS turun.

## 5. Audit keamanan
- Setiap handler remote: Guard (tipe/finite/rentang/allowlist) → kepemilikan → state → jarak → cooldown → mutasi tanpa yield.
- Tidak ada harga/hadiah/data ikan dari client. Tidak ada `InvokeClient`. Debug hanya `RunService:IsStudio()`.
- Uji Server & Clients (2 klien) untuk trade, spam remote, keluar di tengah aksi.

## 6. Checklist rilis
- [ ] `scripts/check.ps1` 0 masalah · `scripts/test.ps1` LULUS · playtest Output bersih (server+client).
- [ ] Place dipublish, **Game Settings → Security → Enable Studio Access to API Services** menyala (untuk uji DataStore).
- [ ] Avatar R15. `Lighting.Technology = Future` (bake atau manual).
- [ ] Audio: hanya ID terverifikasi (`Config/Sounds.luau`). Tidak ada rbxassetid karangan.
- [ ] Workspace.RunSelfTests boleh tetap true (SelfTest hanya jalan di Studio).
- [ ] Uji perangkat: Device Emulator (ponsel landscape 844×390, tablet, 1080p) + Controller Emulator.

## 7. Sharp edges Roblox (selalu ingat)

| # | Bahaya | Pencegahan di proyek ini |
|---|---|---|
| 1 | Data hilang karena dua server menulis profil yang sama | ProfileStore session lock (`DataService`); jangan tulis DataStore profil manual |
| 2 | Client memalsukan koin/harga/hadiah | Semua lewat `EconomyService`; client hanya kirim niat |
| 3 | Remote dibanjiri | Token bucket di `Net.Specs` + `Guard.Reject` yang warn-nya dibatasi |
| 4 | Koneksi tidak diputus → memory leak | `Trove`, satu loop terpusat, bersihkan per `PlayerRemoving`/`CharacterRemoving` |
| 5 | Yield di antara cek dan mutasi → duplikasi item | Beli/jual/barter/trade tanpa `task.wait`/Async di antaranya; validasi ulang saat eksekusi |
| 6 | `require` siklik antar-service | Hanya require service lapisan lebih rendah (PLAN §2); ke atas lewat Signal |
| 7 | Client menunggu objek yang di-stream keluar | `WaitForChild(nama, timeout)` + tangani nil |
| 8 | API deprecated | `bash scripts/api.sh <Kelas>` + luau-lsp menandai `@deprecated` |
| 9 | Pemain jatuh sebelum map siap | `WorldService` menahan `CharacterAutoLoads` sampai map dibangun |
| 10 | Mengedit script di Studio lalu tertimpa sync | Edit hanya file disk; tidak ada `multi_edit` script |
| 11 | Properti non-scriptable (Lighting.Technology) | Set saat bake (pcall) / di `default.project.json` |
| 12 | Aset palsu/karangan | Hanya primitif + `rbxasset://` terverifikasi; Creator Store hanya dengan izin, script di dalamnya dihapus |
