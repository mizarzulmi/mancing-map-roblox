# AGENTS.md — Pantai Mancing Nusantara

Aturan teknis & keamanan untuk semua agen (Claude Code, Antigravity, dll.). Desain lengkap: `docs/GDD.md`.
Kontrak modul/remote/data: `docs/PLAN.md`. Status: `docs/PROGRESS.md`. Uji manual: `docs/TESTING.md`.

## 1. Bahasa & alur kerja
- Komunikasi: Bahasa Indonesia. Identifier kode: Inggris. Komentar kode & semua teks dalam game: Bahasa Indonesia.
- Setiap sesi baru: baca AGENTS.md, docs/GDD.md, docs/PROGRESS.md sebelum menulis kode.
- Kerja per fase (PLAN.md §Fase). Fase selesai = verifikasi (§9) → PROGRESS.md → `git commit` konvensional
  (`feat(fishing): minigame reel`) → laporan singkat → berhenti tunggu "lanjut". "autopilot" = lanjut tanpa berhenti,
  verifikasi tetap wajib.
- Dilarang placeholder: tidak ada `-- TODO`, fungsi kosong, "sisanya sama". Fitur yang ditunda dicatat di PROGRESS.md + alasan.
- Jangan menebak API. Cek `bash scripts/api.sh <Kelas>` (definisi resmi luau-lsp), `content/api_docs` Studio,
  atau `https://create.roblox.com/docs/reference/engine/classes/<Kelas>.md`. Jangan pakai API deprecated.
- Tanya hanya bila benar-benar ambigu; selain itu ikuti default GDD. Angka balancing boleh disetel via BalanceSim
  (catat perubahan lama→baru di PROGRESS.md).

## 2. Sumber kebenaran & sinkronisasi
- Kode = file `.luau` di disk. Disinkronkan ke Studio via Rojo live (`rojo serve` + plugin, terpasang di mesin
  pemilik) atau Script Sync. Place kerja `place/PantaiMancing.rbxl`; `build/` boleh ditimpa kapan saja.
- Konvensi: `Nama.server.luau` = Script, `Nama.client.luau` = LocalScript, `Nama.luau` = ModuleScript, folder = Folder.
  **Tanpa** `init.luau`. Tidak ada script yang punya child script.
- Hanya tiga folder layanan: `ServerScriptService/`, `ReplicatedStorage/`, `StarterPlayerScripts/`.
  UI, NPC, model ikan/joran/kosmetik dibuat lewat kode.
- Edit kode hanya lewat file di disk. MCP Studio untuk membaca tree, `execute_luau` (bake), dan playtest.
  **Jangan** mengedit script lewat `multi_edit`.
- Map dibangun `ServerScriptService/World/MapBuilder.luau` (deterministik, seed tetap) lalu di-bake ke Workspace.
  Server start tanpa `Workspace.BeachMap` → bangun otomatis; dengan BeachMap (hasil bake) → terrain diverifikasi
  (`MapBuilder.EnsureTerrain`) dan dibangun ulang bila daratan salah; `Players.CharacterAutoLoads` ditahan sampai siap.
- Builder **hanya** menyentuh `Workspace.BeachMap`, `Workspace.Terrain`, dan `Lighting`.
  **`Workspace.CustomMap` milik pemilik proyek — jangan pernah dibaca-tulis/hapus/pindah.**
- Bake: require dari `:Clone()` folder World (hindari cache require). Modul di `World/` hanya saling require lewat
  `script.Parent`; konfigurasi map di `World/MapConfig.luau`. Perintah: `scripts/bake-command.luau`.
- Bake ulang menghapus `BeachMap` & menulis ulang Terrain area map → editan manual pemilik di sana hilang. Editan
  permanen pemilik ada di `Workspace.CustomMap`. Place yang sudah di-bake: **tanya pemilik dulu** sebelum bake ulang.

## 3. Arsitektur
- `--!strict` di semua file (kecuali `Packages/`). Tipe bersama diekspor dari `Shared/Types.luau`.
- Service (server) / Controller (client): `Init()` tanpa yield, `Start()` menghubungkan event & boleh `task.spawn`.
  `Main.server.luau` / `Main.client.luau` me-require semua modul di foldernya, memanggil semua `Init` lalu semua `Start`,
  masing-masing dalam `pcall` dengan log nama modul yang gagal. Urutan dari daftar prioritas di Main.
- **Aturan require antar-service (anti-siklus):** service hanya boleh me-require service di lapisan lebih rendah
  (lihat PLAN.md §Lapisan). Komunikasi ke atas lewat `Signal` (mis. `FishingService.FishCaught` → Level, Quest,
  Fishdex, Achievement).
- `Shared/Net.luau` satu-satunya tempat mendefinisikan Remote (server membuat `ReplicatedStorage.Remotes`).
  RemoteFunction hanya client→server. **Jangan pernah `InvokeClient`.**
- Rumus murni (harga, XP, roll rarity, validasi trade, pemilihan barter, indeks hari WIB) di `Shared/Formulas.luau`
  atau modul murni lain — tanpa service Roblox, agar bisa diuji SelfTest dan Lune.
- Semua angka gameplay di `Shared/Config/*`. Menambah ikan/item/quest/NPC = menambah baris Config.

## 4. API terlarang → pengganti
| Terlarang | Pakai |
|---|---|
| `wait`, `spawn`, `delay`, `tick` | `task.wait/spawn/delay/defer`, `os.clock`, `workspace:GetServerTimeNow()` |
| `Instance.new(class, parent)` | `Instance.new(class)` → set properti → `Parent` paling akhir |
| `BodyVelocity/BodyGyro/BodyPosition` | `LinearVelocity`, `AlignOrientation`, `AlignPosition` |
| `Humanoid:LoadAnimation` | `Animator:LoadAnimation` (proyek ini: pose via Motor6D C0, tanpa asset animasi) |
| `Players:CreateHumanoidModelFromDescription` (deprecated) | `Players:CreateHumanoidModelFromDescriptionAsync` |
| `Humanoid:ApplyDescription` (deprecated) | `Humanoid:ApplyDescriptionAsync` |
| objek `Mouse` lama | `UserInputService` / `ContextActionService` |
| `math.random` untuk gameplay | `Random.new(seed)` |
| `loadstring`, `getfenv`, `setfenv`, `require(angka)` | — |
| loop `while true` per objek di server | satu loop Heartbeat terpusat |
| `GuiService:AddSelectionParent/Tuple` (deprecated) | `SelectionGroup` + `SelectionBehavior*` |

## 5. Performa & streaming
- Animasi ambient (perahu bergoyang, camar, kepiting, lampu, nelayan) di client: **satu** loop Heartbeat + tag
  CollectionService (`Bobbing`, `Seagull`, `Crab`, `Flicker`, `Spin`). Bukan satu script per objek.
- Dekorasi: `Anchored = true`; `CanCollide/CanQuery/CanTouch = false` bila tidak perlu; `CastShadow = false` untuk detail kecil.
- Target ≤ 6.000 part di BeachMap (cek `MapBuilder` mencetak jumlah part). Model NPC & kios: `ModelStreamingMode = Persistent`.
- Client aman untuk streaming: `WaitForChild(nama, timeout)` + tangani nil; jangan menunggu selamanya.

## 6. Aset & visual 3D
- **Dilarang mengarang `rbxassetid`.** Visual dari Part (Block/Ball/Cylinder/Wedge/CornerWedge), WedgePart,
  CornerWedgePart, SpecialMesh `Sphere`/`Cylinder`/`Head` tanpa MeshId, Terrain, material bawaan, ParticleEmitter,
  Trail, Beam, Light, tekstur `rbxasset://` bawaan.
- `rbxasset://` terverifikasi ada (Studio 2026-10): `textures/particles/{sparkles_main,smoke_main,fire_main,
  fire_sparks_main,explosion01_implosion_main,forcefield_glow_main,common_alpha}.dds`,
  `sounds/{impact_water,action_swim,action_jump,volume_slider}`. Font: `fonts/families/{BuilderSans,FredokaOne}.json`.
- Audio lain hanya dari MCP `search_asset` yang terverifikasi → `Config/Sounds.luau`. ID kosong = diam tanpa error.
- Model Creator Store (`insert_asset`/`generate_mesh`) hanya dengan izin pemilik; hapus semua Script/LocalScript/
  ModuleScript di dalamnya; simpan versi primitif sebagai cadangan.
- **Jangan kotak-kotak.** Wajib: siluet dari silinder/bola/wedge; lengkung dari rantai segmen yang berotasi bertahap
  (batang kelapa, akar bakau, lambung perahu, atap); taper (ujung mengecil); variasi warna ±4% deterministik per bagian;
  bevel/trim dengan wedge kecil; bentuk organik (batu, bukit, karang besar) dari Terrain `FillBall/FillBlock/FillWedge`;
  objek duduk di tanah (tenggelam 0,2–0,5 stud, tidak melayang). Detail kecil boleh dibuang demi batas part.

## 7. Keamanan (server-authoritative)
- Server memutuskan semuanya: hasil ikan, harga, hadiah, koin. Client hanya mengirim niat (id + angka kecil),
  tidak pernah harga, jumlah hadiah, atau data ikan.
- Setiap remote divalidasi berlapis: `typeof`/finite/rentang → allowlist id Config → kepemilikan → state machine →
  jarak NPC (≤ 20 stud) / lokasi → cooldown → rate limit token bucket (di `Net`). Pelanggaran → tolak +
  `warn(UserId, remote, alasan)` (lewat `Guard.Reject`), tanpa error yang menghentikan server.
- Sesi memancing: `sessionId` GUID, satu sesi aktif per pemain, kedaluwarsa otomatis. Hasil minigame = klaim client
  yang dibatasi validasi waktu (durasi ≥ minimum teoretis × 0,9).
- Pembelian, jual, barter, trade: cek dan mutasi **tanpa yield** di antaranya; validasi ulang saat eksekusi.
- Koin hanya lewat `EconomyService.Add / TrySpend(player, amount, reason)` — tidak pernah negatif, selalu ada alasan.
- Perintah debug hanya bila `RunService:IsStudio()`.

## 8. Data
- ProfileStore (`ServerScriptService/Packages/ProfileStore.luau`, Apache-2.0, lisensi di `docs/licenses/`).
  Tanpa akses API Studio → ProfileStore otomatis memakai mock; DataService `warn` sekali + toast
  "Mode uji: data tidak disimpan".
- Template profil di `Shared/Config/Balance.luau` → `DataService`; `Version` + migrasi berurutan; `Reconcile()`.
  Jangan simpan Instance/userdata/fungsi, tabel campuran, atau array berlubang.
- Client: snapshot awal via `GetInitialData` (RemoteFunction), lalu delta `DataChanged`. Data otoritatif hanya server.

## 9. Verifikasi setiap fase (lihat juga docs/TESTING.md)
1. Statis (selalu, tanpa Studio): `powershell -ExecutionPolicy Bypass -File scripts/check.ps1` → 0 error luau-lsp;
   `scripts/test.ps1` → `[SELFTEST] LULUS x/x`; `scripts/build.ps1` → place file terbentuk.
2. Studio terhubung: `list_roblox_studios` / `get_studio_state` (atau `python scripts/studio_mcp.py status`).
3. Map berubah: bake via `execute_luau` (datamodel_type Edit), lalu `screen_capture` ≥ 5 sudut (udara, pasar, dermaga,
   laguna, Laut Dalam). Nilai seperti level designer: melayang/terkubur, skala, z-fighting, kepadatan, komposisi, jalur.
4. `start_stop_play` → `get_console_output`: 0 error & 0 warning dari skrip kita (warn mode mock adalah satu-satunya
   pengecualian yang diharapkan).
5. Uji alur dengan `character_navigation`, `user_keyboard_input`, `user_mouse_input`, `screen_capture`.
6. SelfTest (`Tests/SelfTest.server.luau`) hanya bila `RunService:IsStudio()` dan `Workspace.RunSelfTests = true`.
7. Yang tidak bisa otomatis → langkah manual di docs/TESTING.md.
- Laporkan tingkat bukti dengan jujur: **Dieksekusi di Studio** / **Dicek statis** / **Disiapkan, belum dijalankan**.
  Jangan menyebut "sudah diuji di Studio" bila hanya dicek statis.

## 10. UI
- Semua UI lewat kode dari komponen `StarterPlayerScripts/UI` + token `Shared/Config/Theme.luau` (jangan hardcode warna).
- ScreenGui terpisah: HUD, Panel, Popup, Minigame (+ Overlay); `ResetOnSpawn = false`; `ScreenInsets = DeviceSafeInsets`,
  elemen interaktif atas digeser sebesar `GuiService.TopbarInset`.
- Satu UIScale global 0,75–1,25 × skala pengguna. Target sentuh ≥ 48 px. Ukuran teks dasar ≥ 19 (≥ 14 px setelah skala).
- Satu panel besar sekaligus (UIController stack); Esc/X/klik luar menutup; panel terbuka → input memancing nonaktif.
- Animasi 0,15–0,2 dtk Quad Out; `GuiService.ReducedMotionEnabled` → perubahan instan.
- Kontras teks ≥ 4,5:1 di atas panel & kartu (token Theme sudah diverifikasi, lihat PROGRESS.md).
