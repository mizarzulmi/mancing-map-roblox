# Pantai Mancing Nusantara

RPG memancing bertema pantai tropis Indonesia untuk Roblox: memancing dengan minigame reel, 28 spesies dengan
rarity/berat/mutasi, jual–barter–trade antar pemain, level & quest, Fishdex, kosmetik, siang–malam, cuaca,
event, kapal ke Laut Dalam, dan penyimpanan data (ProfileStore). Semua kode Luau (`--!strict`), server-authoritative,
dan diatur lewat Config.

Dokumen: [AGENTS.md](AGENTS.md) (aturan teknis) · [docs/GDD.md](docs/GDD.md) (desain) · [docs/PLAN.md](docs/PLAN.md)
(kontrak modul) · [docs/PROGRESS.md](docs/PROGRESS.md) (status) · [docs/TESTING.md](docs/TESTING.md) (uji) ·
[docs/UI-DIRECTION.md](docs/UI-DIRECTION.md) (arah visual).

## 1. Persiapan (sekali)
1. Roblox Studio terpasang. Buat/buka place → **File → Publish to Roblox**.
2. **Game Settings → Security → Enable Studio Access to API Services** (wajib agar DataStore jalan di Studio).
3. **Game Settings → Avatar → R15**.
4. Toolchain lokal (Rojo, luau-lsp, Lune, Selene, StyLua ke `.tools/`, tidak mengubah PATH):
   `powershell -ExecutionPolicy Bypass -File scripts/setup-tools.ps1`
5. (Opsional, untuk agen AI) Studio: **Assistant → ⋯ → Manage MCP Servers → Enable Studio as MCP server**.

## 2. Mulai cepat
```powershell
powershell -ExecutionPolicy Bypass -File scripts/build.ps1     # → build/PantaiMancing.rbxl
```
Buka `build/PantaiMancing.rbxl` di Studio → **Play**. Map dibangun otomatis saat server start bila
`Workspace.BeachMap` belum ada (pemain ditahan sampai map siap). Untuk melihat/merapikan map di edit mode,
jalankan isi [scripts/bake-command.luau](scripts/bake-command.luau) di Command Bar.

Sinkronisasi live ke place Anda: **Script Sync** (File → Beta Features) untuk folder `ServerScriptService`,
`ReplicatedStorage`, `StarterPlayer/StarterPlayerScripts`, atau **Rojo** (`default.project.json`). Langkah rinci
di [docs/TESTING.md](docs/TESTING.md#b-menyambungkan-kode-ke-studio).

**Lighting.Technology = Future** tidak bisa diubah script saat runtime. Bake mencoba mengaturnya; bila gagal, pilih
Lighting di Explorer → Properties → Technology → Future. `build/PantaiMancing.rbxl` sudah memakai Future.

## 3. Cara main
| Aksi | PC | HP/Tablet | Gamepad |
|---|---|---|---|
| Pegang/simpan joran | `1` atau klik slot joran | ketuk slot joran | L1 |
| Lempar (tahan = tenaga, lepas = lempar) | tahan klik kiri / Spasi | tahan tombol **Lempar** | tahan R2 |
| Strike saat "!" | klik / Spasi | ketuk **Tarik** | R2 |
| Minigame (zona ke kanan saat ditahan) | tahan klik / Spasi | tahan **Tahan** | tahan R2 |
| Bicara dengan NPC | `E` | ketuk prompt | X |
| Ajak tukar pemain | `T` di dekat pemain / `G` menu | ketuk prompt | Y |
| Menu: Tas / Fishdex / Quest / Kosmetik / Pemain / Pengaturan | `B` / `F` / `Q` / `C` / `G` / `P` | tombol kiri | D-pad + A |
| Tutup panel | `Esc` / X / klik luar | X / ketuk luar | B |

Alur: Pak Lurah (quest) → Pak Darto (joran, umpan, tas) → mancing di Pantai Dangkal → jual ke Bu Rina →
Laguna Bakau (Lv 5) → Nahkoda Jaka ke Laut Dalam (Lv 10, 150 koin). Ikan **dilindungi** (Napoleon, Coelacanth)
dilepas untuk Poin Konservasi (toko poin Kak Laut). Kakek Bahari menerima barter di ujung dermaga.

## 4. Menambah konten lewat Config (tanpa kode baru)
| Konten | Berkas | Catatan |
|---|---|---|
| Ikan | `ReplicatedStorage/Shared/Config/Fish.luau` | Id unik, Rarity, Zones, Time (`Any/Day/Night`), opsional Weather/Event, MinWeight/MaxWeight, BasePrice, Shape (`Ramping, Gemuk, Pipih, Belut, Paruh, Kepiting, Cumi, Lobster, Naga, Kristal`), Primary/Secondary, Hint, Fact. Dilindungi: `Protected = true, ProtectedPoints = n` |
| Joran / umpan / tas | `Config/Rods.luau`, `Config/Bait.luau`, `Config/Bags.luau` | Harga, level, stat |
| Kosmetik | `Config/Cosmetics.luau` | `Style` harus dikenal `Shared/Models/CosmeticModels.luau` |
| Quest | `Config/Quests.luau` | Objective.Type yang didukung: TalkNpc, BuyBait, CatchFish, SellCoins, BuyCosmetic, CatchInZone, DiscoverSpecies, Ferry, ReleaseProtected, CatchRarity, CatchRarityAtLeast, CatchWeightAtLeast, CatchAtNight, UseBait, ReleaseFish, CatchMutated |
| NPC | `Config/NPCs.luau` + titik `NpcSpawns` di `ServerScriptService/World/MapConfig.luau` | Penanda `NPCSpawn_<Id>` dibuat World/Zones |
| Angka gameplay | `Config/Balance.luau` | Rumus di `Shared/Formulas.luau`; cek dengan `scripts/test.ps1 -Balance` |

Setelah mengubah Config jalankan `scripts/test.ps1` — **ConfigSpec** memeriksa semua referensi silang (zona, gelar,
umpan, NPC, kosmetik) dan **FormulasSpec/EconomySpec/TradeSpec/BarterSpec** menguji rumus.

## 5. Bekerja dengan Claude Code
Buka folder ini di VS Code/Claude Code. `CLAUDE.md` memuat AGENTS.md otomatis; `.mcp.json` mendaftarkan server
MCP **Roblox_Studio** (setujui saat diminta, Studio harus terbuka dengan MCP aktif). Perintah:

| Perintah | Fungsi |
|---|---|
| `/sesi-baru` | baca konteks, cek MCP, ringkas status, lanjut fase |
| `/lanjut`, `/autopilot` | kerjakan fase berikutnya (berhenti per fase / tanpa berhenti) |
| `/cek` | luau-lsp + uji Lune + build |
| `/bake`, `/review-map` | bake map + screenshot 6 sudut + kritik level designer + perbaikan |
| `/playtest` | Play lewat MCP + alur beli → mancing → jual |
| `/ada-error <Output>` | reproduksi & perbaiki akar masalah |
| `/balancing` | BalanceSim + usulan angka (diterapkan setelah disetujui) |
| `/tambah-ikan <Zona>` | 4 spesies baru lewat Config + SelfTest |
| `/model-cantik` | usulan mesh pengganti (izin dulu, hapus script aset, simpan cadangan) |

Skill proyek di `.claude/skills/` (roblox-game, pantai-mancing, roblox-procedural-3d, roblox-studio-mcp + skill
Roblox Apache-2.0), sub-agen di `.claude/agents/` (level-designer, luau-reviewer, balance-analyst), dan hook di
`.claude/settings.json` (memblokir `multi_edit` & semua perintah MCP yang menyentuh `Workspace.CustomMap`, cek
luau-lsp otomatis setiap kali berkas `.luau` diedit). Tanpa MCP native, pakai `python scripts/studio_mcp.py`.

## 6. Batasan yang diketahui
- **Hasil minigame adalah klaim client** yang dibatasi validasi server: sesi harus valid & belum kedaluwarsa, dan
  durasi ≥ waktu minimum teoretis × 0,9 (dari ReelSpeed joran). Ikan, berat, mutasi, dan harga tetap ditentukan
  server sebelum minigame dimulai.
- **Audio**: hanya suara bawaan Roblox yang terverifikasi (`rbxasset://sounds/impact_water.mp3` dll.). ID lain di
  `Config/Sounds.luau` kosong (= diam) sampai diverifikasi lewat MCP `search_asset`.
- **Visual**: semua model dari primitif, Terrain, efek bawaan — tanpa mesh/aset karangan. Penggantian dengan mesh
  Creator Store hanya dengan izin pemilik (`/model-cantik`).
- **Papan peringkat** nonaktif di mode uji (Studio tanpa akses API).
- Nama menu **Script Sync** di Studio masih beta dan bisa berubah; Rojo tersedia sebagai alternatif.

## 7. Lisensi pihak ketiga
- ProfileStore © MadStudioRoblox (loleris), Apache-2.0 — `docs/licenses/ProfileStore-LICENSE.txt`.
- Skill Roblox dari AbhishekBarali/awesome-gamedev-agent-skills, Apache-2.0 —
  `docs/licenses/awesome-gamedev-agent-skills-LICENSE.txt`, rincian di `.claude/skills/THIRD_PARTY_NOTICES.md`.
