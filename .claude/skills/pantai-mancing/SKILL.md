---
name: pantai-mancing
description: >
  Peta proyek Pantai Mancing Nusantara (Roblox, Luau --!strict): letak modul, lapisan service anti-siklus,
  remote di Net.luau, skema data ProfileSchema, kontrak dunia BeachMap (folder, penanda, tag), cara menambah
  ikan/item/quest/NPC lewat Config, perintah verifikasi (check.ps1, test.ps1, build.ps1), serta jebakan
  Luau strict yang sudah terverifikasi di repo ini. Pakai sebelum menulis/mengubah kode apa pun di repo ini.
---

# Pantai Mancing Nusantara — peta kerja

Baca dulu: `AGENTS.md` (aturan), `docs/GDD.md` (desain), `docs/PROGRESS.md` (status), `docs/PLAN.md` (kontrak).

## Letak & tanggung jawab
- Server: `ServerScriptService/Main.server.luau` (Net.Init → require semua Services → Init → Start).
  `Services/*Service.luau` (19), `World/*` (pembangun map, self-contained, hanya `script.Parent`),
  `Packages/ProfileStore.luau`, `Tests/{SelfTest.server, TestRunner, BalanceSim, Specs/*}`.
- Bersama: `ReplicatedStorage/Shared/{Types, Net, Formulas, ProfileSchema, TradeLogic}` + `Config/*` + `Models/*` + `Util/*`.
- Client: `StarterPlayerScripts/Main.client.luau` → `Controllers/*Controller.luau`; komponen `UI/*`.

## Lapisan service (require hanya ke bawah)
L0 Data · L1 Economy, Inventory, World, NPC · L2 Level, Conservation · L3 Fishing ·
L4 Shop, Sell, Barter, Fishdex, Ferry, Cosmetic, Trade · L5 Quest, Achievement, Leaderboard · L6 Debug.
Ke atas lewat Signal: `FishingService.FishCaught/BaitUsed/CastStarted`, `ShopService.Purchased`,
`SellService.Sold`, `ConservationService.Released/PointsChanged`, `FishdexService.Discovered/ZoneCompleted`,
`FerryService.Traveled`, `NPCService.Talked`, `LevelService.LevelChanged`, `EconomyService.CoinsChanged/Earned`,
`DataService.ProfileLoaded/ProfileReleasing`.

## Menambah konten (tanpa kode baru)
- Ikan: baris baru di `Config/Fish.luau` (Id unik, Rarity, Zones, Time, Weather?/Event?, berat, harga, Shape,
  Primary/Secondary, Hint, Fact). Protected = `Protected = true` + `ProtectedPoints`.
- Joran/umpan/kosmetik/tas: `Config/Rods|Bait|Cosmetics|Bags`. Kosmetik butuh `Style` yang dikenal
  `Models/CosmeticModels.luau`.
- Quest: `Config/Quests.luau` (Objective.Type yang didukung ada di `QuestService.contribution`).
- NPC: `Config/NPCs.luau` + penanda `NPCSpawn_<Id>` di `World/MapConfig.luau`.
- Setelah mengubah Config: `scripts/test.ps1` (ConfigSpec memeriksa semua referensi silang).

## Verifikasi
```
powershell -ExecutionPolicy Bypass -File scripts/check.ps1        # luau-lsp strict, harus 0 masalah
powershell -ExecutionPolicy Bypass -File scripts/test.ps1         # [SELFTEST] LULUS x/x (Lune)
powershell -ExecutionPolicy Bypass -File scripts/test.ps1 -Balance # BalanceSim santai & aktif 8 jam
powershell -ExecutionPolicy Bypass -File scripts/build.ps1        # build/PantaiMancing.rbxl
bash scripts/api.sh <Kelas> [regex]                               # cek API Roblox resmi
```

## Luau strict — jebakan terverifikasi (solver tipe baru, luau-lsp 1.70)
1. Singleton union melebar ke `string` saat lewat properti tabel modul (termasuk tipe kembalian fungsi
   modul). Karena itu tipe "enum" di `Types.luau` adalah alias `string` terdokumentasi. Jangan membuat union
   string baru untuk data lintas modul.
2. `pcall(f)` dengan `f: () -> ()` dianggap mengembalikan 1 nilai → `local ok, err = pcall(f)` error.
   Solusi: anotasi `-> ...any` atau `pcall(f :: () -> ...any)`.
3. Tabel invarian: `{T}` ≠ `{U}` walau T ⊂ U; tipe struktural parsial gagal bila ada properti tabel bersarang
   (pakai tipe penuh, mis. `Types.ProfileData`).
4. Menghapus kunci dari map bertipe `{[string]: number}`: `(map :: any)[k] = nil`.
5. Indeks map mengembalikan non-opsional; bandingkan dengan nil lewat anotasi eksplisit `local v: T? = map[k]`.
6. Iterasi atas union `{A} | {}` (mis. `x or {}`) error → `if x then for ... end end`.
7. `require` dinamis memicu "Unknown require" → `local dynamicRequire = require :: any`.
8. Fungsi kosong & placeholder dilarang: Init/Start opsional — hapus bila tidak ada pekerjaan.

## Konvensi data
- String kosong `""` = slot kosong (EquippedBait, kosmetik). Koin hanya lewat `EconomyService.Add/TrySpend`.
- Client menerima snapshot `GetInitialData` lalu `DataChanged` (`Set`/`FishAdd`/`FishRemove`/`FishUpdate`).
