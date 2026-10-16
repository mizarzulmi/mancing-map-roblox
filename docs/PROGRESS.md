# PROGRESS — Pantai Mancing Nusantara

## Ringkasan status
- Tanggal: 2026-10-16. Mode kerja: autopilot ("gas loop"). Semua fase 0–8 sudah ditulis kodenya.
- Bukti: **Dicek statis** (luau-lsp 1.70.1 strict + definisi Roblox, Lune 0.10.5, Rojo build). **Belum dieksekusi
  di Studio** — server MCP Studio belum aktif di sesi ini (proxy `mcp.bat` jalan, Studio belum mendaftarkan tool).
- Berikutnya: aktifkan *Enable Studio as MCP server*, lalu `/sesi-baru` → `/bake` → `/review-map` → `/playtest`.
- Menunggu persetujuan: usulan balancing (lihat §Balancing).

## Fase
| Fase | Isi | Kode | Bukti |
|---|---|---|---|
| 0 Fondasi | struktur, AGENTS/CLAUDE/PRODUCT/docs, `.claude/` (skill, perintah, sub-agen, hook), toolchain & skrip, Util, Types, Net, Formulas, ProfileSchema, TradeLogic, Config, bootstrap | ✅ | statis ✅ · Lune 178/178 ✅ · Script Sync: disiapkan (TESTING §B) |
| 1 Map | Terrain, plaza & kios, dermaga T, gubuk barter, jetty kapal, platform Laut Dalam, mercusuar, pinisi, jukung, kelapa, bakau, properti, bawah laut, zona, titik NPC, batas, Lighting | ✅ | statis ✅ · dijalankan penuh di Lune (4.219 part) ✅ · bake & 6 screenshot Studio: belum (butuh MCP) |
| 2 Data & ekonomi | DataService (ProfileStore + mock), Economy, Inventory, leaderstats, DataController, UIController, HUD, toast | ✅ | statis ✅ |
| 3 Memancing | FishingService, RodModel/BobberModel/FishModel, Input/Fishing/Minigame/CatchPopup | ✅ | statis ✅ |
| 4 NPC & toko | NPCService, Dialog, Shop (joran/umpan/tas/kosmetik/poin), Sell, Cosmetic + equip | ✅ | statis ✅ |
| 5 RPG | Level/XP + gating, Quest cerita & harian, Fishdex + hadiah, Achievement → gelar, Konservasi | ✅ | statis ✅ |
| 6 Dunia hidup | siang–malam, cuaca + FX, event, kapal, ambient, suara (bawaan), papan peringkat | ✅ | statis ✅ |
| 7 Barter & trade | BarterService/Controller, TradeService/Controller, log, peringatan timpang | ✅ | statis ✅ · uji 2 pemain: disiapkan (TESTING §F) |
| 8 Polish | mobile/gamepad, pengaturan + grafis rendah, BalanceSim, SelfTest, README | ✅ | statis ✅ · BalanceSim ✅ · perangkat: disiapkan (TESTING §G) |

## Map (Fase 1) — jumlah part terukur (Lune)
Plaza 497 · Pier 787 · Palms 1.280 (40 kelapa × 32 part: batang 8 segmen, 7 pelepah × 3, 3 kelapa) · Mangroves 351 ·
Boats 247 · Pinisi 114 · Lighthouse 60 · BeachProps 338 · Underwater 461 · Zones 83 → **4.219** (batas 6.000).
Profil terrain sesuai GDD: plaza 5,5; pasir Z20 ≈ 5,5 → garis pantai ±Z117; −12 di Z200; −40 di Z320; laguna −6;
kanal −3; tanjung mercusuar ≈ 15,7. Papan peringkat dipindah ke (±22, 6, 5) agar tidak menutup laut dari spawn.
Dari spawn (menghadap +Z) dermaga & mercusuar tampak di kiri (koordinat GDD).

**Cek visual saat MCP aktif (`/review-map`):** hasil nyata WriteVoxelChannels (dasar laut, tepi laguna & kanal);
keterbacaan SurfaceGui siang/malam; LeafyGrass pada elipsoid kanopi bakau; bagian bawah kubah mercusuar vs kaca;
Lighting.Technology = Future; bukit rumput utara masih lapang (kandidat penambahan vegetasi).

## Review kode (independen)
Reviewer membaca 19 service, 23 controller, dan modul Shared: 0 Kritis, 1 Tinggi, 4 Sedang, 10 Rendah — **semua
diperbaiki** (commit `fix: perbaikan 15 temuan review kode`). Kontrak remote server↔client, urutan Init/Start, dan
validasi keamanan dinyatakan bersih.

## Keputusan & temuan teknis
- **API deprecated di spek diganti:** `Players:CreateHumanoidModelFromDescription` → `...Async`;
  `Humanoid:ApplyDescription` → `...Async` (dicek dari definisi luau-lsp `@deprecated`).
- **Lighting.Technology** non-scriptable saat runtime (dokumentasi API Studio): diset di `default.project.json`
  dan dicoba saat bake (pcall).
- **Solver tipe Luau baru:** singleton union melebar ke `string` lintas modul → tipe "enum" di `Types.luau` jadi
  alias `string` terdokumentasi; jebakan lain dicatat di skill `pantai-mancing`.
- **Terrain dasar laut:** `WriteVoxelChannels` (SolidMaterial/SolidOccupancy/LiquidOccupancy) agar voxel dasar laut
  berisi padatan + air tanpa kantong udara; fallback `WriteVoxels`.
- **UIShadow** tersedia resmi; dibuat lewat pcall. Ikon UI digambar dari Frame (tanpa emoji/rbxassetid).
- **Kontras** token Theme diverifikasi WCAG: teks 12,7:1 (panel) / 10,1:1 (kartu); sekunder 8,5 / 6,8; tombol
  gelap-di-terang 6,8–10,5. Bahaya/teal sebagai teks di kartu gagal (4,36/4,37) → varian `DangerText` #FF9A80
  (5,43:1) dan `TealText` #4FD1CE (6,05:1).
- **Tafsir "joran ke-5" (GDD 4.2):** joran ke-5 yang dibeli = Legenda Nusantara; Emas Bahari dilaporkan terpisah.
- **Quest cerita** diterima di Pak Lurah (tanda "!"), hadiah otomatis saat selesai. Ikan Protected masuk tas,
  tidak bisa dijual/ditukar/dibarter, tombol "Lepaskan" di popup & tas.

## Balancing
BalanceSim (rata-rata 6 simulasi, 8 jam, profil aktif 4/menit — target GDD untuk "bermain aktif"):

| Milestone | Target | Config sekarang | Opsi A: Laguna Lv 5→7 |
|---|---|---|---|
| Joran ke-2 Fiberglass | ±5 mnt | 4,3 mnt | 4,3 mnt |
| Joran ke-3 Karbon | ±45 mnt | 36,0 mnt | 41,8 mnt |
| Joran ke-4 Samudra | ±2,5 jam | 2,6 jam | 2,7 jam |
| Joran ke-5 Legenda | ±7 jam | 7,2 jam | 7,4 jam |
| Laguna terbuka | ±30 mnt | **9,7 mnt** | 27,8 mnt |
| Laut Dalam | ±60 mnt | 62,4 mnt | 70,2 mnt |

Profil santai (2/menit): Fiberglass 7,8 mnt, Karbon 76 mnt, Samudra 5,5 jam, Laguna 18,8 mnt, Laut Dalam 2,4 jam.
Usulan (belum diterapkan, menunggu persetujuan): `Config/Zones.luau` Mangrove `Level 5 → 7`,
`Config/Quests.luau` bakau_misterius `Level 5 → 7`, papan arah map "LAGUNA BAKAU (Lv 5)" → "(Lv 7)".
Alternatif yang ditolak: Laguna Lv 6 (17 mnt, masih terlalu cepat); Karbon Lv 9 (56 mnt, terlalu lambat).

## Fitur ditunda (dengan alasan)
- **Audio selain bawaan Roblox** — ID harus diverifikasi lewat MCP `search_asset`; sampai itu `Config/Sounds.luau`
  berisi string kosong (diam tanpa error). Bawaan terverifikasi: `impact_water`, `action_swim`, `volume_slider`.
- **Verifikasi Studio (bake, 6 screenshot, playtest, Output bersih, SelfTest di Studio)** — menunggu server MCP
  Studio aktif. Semua langkah sudah disiapkan (`/bake`, `/review-map`, `/playtest`, docs/TESTING.md).
- **Mesh Creator Store** — hanya dengan izin pemilik (`/model-cantik`).

## Verifikasi
- `scripts/check.ps1`: `[CHECK] luau-lsp: 0 masalah` (seluruh proyek, strict, definisi Roblox 1.70.1).
- `scripts/build.ps1`: `build/PantaiMancing.rbxl` valid (diperiksa Lune: 2 Script, 1 LocalScript, 111 ModuleScript,
  tanpa script ber-anak, Lighting.Technology = Future).
- Sub-agen: pustaka UI diuji asap di Lune 30/30 (normal & ReducedMotion); semua builder model & map dieksekusi di Lune
  dengan Config asli tanpa error.
- `scripts/test.ps1`: `[SELFTEST] LULUS 178/178` (WeightedRandom 100.000 sampel ±1,5%, rumus, ekonomi, trade, barter, Config).
- `scripts/test.ps1 -Balance`: tabel di atas.
