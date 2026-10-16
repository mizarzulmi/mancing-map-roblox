# Panduan Uji — Pantai Mancing Nusantara

Tingkat bukti yang dipakai di PROGRESS.md: **Dieksekusi di Studio** · **Dicek statis** · **Disiapkan, belum dijalankan**.

## A. Uji otomatis (tanpa Studio)

```powershell
powershell -ExecutionPolicy Bypass -File scripts/setup-tools.ps1   # sekali: Rojo, luau-lsp, Lune, Selene, StyLua
powershell -ExecutionPolicy Bypass -File scripts/check.ps1         # luau-lsp strict → "[CHECK] luau-lsp: 0 masalah"
powershell -ExecutionPolicy Bypass -File scripts/test.ps1          # spesifikasi murni → "[SELFTEST] LULUS x/x"
powershell -ExecutionPolicy Bypass -File scripts/test.ps1 -Balance # BalanceSim santai & aktif, 8 jam
powershell -ExecutionPolicy Bypass -File scripts/build.ps1         # build/PantaiMancing.rbxl
```

## B. Menyambungkan kode ke Studio

**Cara cepat (tanpa sinkronisasi):** buka `build/PantaiMancing.rbxl` di Studio → Play. Map dibangun otomatis saat
server start (±beberapa detik; karakter muncul setelah map siap).

**Setup yang dipakai di mesin pemilik (Rojo live + MCP):**
1. Place kerja: `place/PantaiMancing.rbxl` (salinan build; di-gitignore). Jangan bekerja di `build/` — ditimpa
   setiap `build.ps1`/`/cek`.
2. Plugin Rojo terpasang (`.tools\bin\rojo.exe plugin install` → `%LOCALAPPDATA%\Roblox\Plugins\RojoManagedPlugin.rbxm`).
3. Terminal: `.tools\bin\rojo.exe serve default.project.json` (localhost:34872). Studio: tab **Plugins → Rojo →
   Connect**, terima patch awal. `Workspace`/`Lighting` tanpa `$path` → `BeachMap`, `CustomMap`, Terrain aman.
4. MCP: Studio **Assistant → ⋯ → Manage MCP Servers → Enable Studio as MCP server**; Claude Code memakai server
   `Roblox_Studio` cakupan user. Cek: `claude mcp get Roblox_Studio` (harus "Connected", bukan "Pending approval")
   dan `python scripts/studio_mcp.py status` (harus mencantumkan studio, bukan "belum menyediakan tool").

**Script Sync (alternatif, beta):**
1. Studio: File → Beta Features → **Script Sync** → Save → restart Studio.
2. Buka place Anda (yang sudah dipublish).
3. Di Explorer, klik kanan **ServerScriptService** → *Sync with folder* (atau menu Script Sync) → pilih
   `E:\roblox\ServerScriptService`. Ulangi untuk **ReplicatedStorage** → `E:\roblox\ReplicatedStorage` dan
   **StarterPlayer › StarterPlayerScripts** → `E:\roblox\StarterPlayerScripts`.
4. Uji sinkronisasi: buat berkas `ServerScriptService/CekSync.server.luau` berisi `print("[SYNC] OK")`, Play,
   pastikan Output menampilkan `[SYNC] OK`, lalu **hapus** berkas itu.
   > Nama menu Script Sync bisa berbeda antar versi Studio beta; bila tidak ada opsi per-folder, pakai Rojo.

**Rojo (alternatif):** `.tools/bin/rojo.exe serve` lalu sambungkan plugin Rojo di Studio (plugin dipasang dari
Creator Store / `rojo plugin install`).

## C. Bake map ke Workspace (agar terlihat & bisa dirapikan di edit mode)
- Studio Command Bar (View → Command Bar): tempel isi `scripts/bake-command.luau` → Enter.
- Atau lewat MCP: `execute_luau` (datamodel_type `Edit`) dengan isi berkas yang sama.
- Hasil: `Workspace.BeachMap` + Terrain + Lighting. **Workspace.CustomMap tidak disentuh.**
- Set `Lighting.Technology = Future` (bake mencoba otomatis; bila gagal, set manual di Properties Lighting).

## D. Alur main tunggal (Play)
| # | Langkah | Hasil yang diharapkan |
|---|---|---|
| 1 | Play, tunggu karakter muncul | Output: `[Main] server siap: 19 service`, `[SELFTEST] LULUS x/x`; tanpa error. Di Studio tanpa API: satu warn `[DataService] ... mode uji` + toast "Mode uji: data tidak disimpan" |
| 2 | Lihat HUD | Kiri atas Lv 1 + XP; kanan atas Koin 50, poin 0, tas 0/20; tengah atas jam & cuaca; menu kiri; slot joran & umpan bawah |
| 3 | Jalan ke Pak Lurah (dekat spawn) → E | Dialog quest "Selamat Datang" → Terima → +50 koin, quest 2 ditawarkan |
| 4 | Ke Pak Darto (−30, 6, −15) → E → Lihat toko → Umpan → Cacing ×10 → Beli | Koin berkurang 20, umpan ×10, quest "Umpan Pertama" selesai |
| 5 | Tekan 1 (pegang joran), ke tepi pantai menghadap laut | Petunjuk "Tahan klik kiri / Spasi..." muncul |
| 6 | Tahan klik kiri, lepas di ±70% | Pelampung terbang, cipratan, pelampung di air dengan tali |
| 7 | Tunggu 4–11 dtk (abaikan getaran palsu) | Tanda "!" + "Strike!" → klik dalam 1,5 dtk |
| 8 | Minigame: tahan/lepas agar zona menutupi ikon ikan | Progres naik dari 30% → 100% → kartu timbang + ikan 3D + berat |
| 9 | Klik di luar air / di dek | Toast "Kail harus jatuh ke air." |
| 10 | Tas penuh (`/isitas`) lalu lempar | Toast "Tas penuh! Jual atau lepaskan ikan dulu." |
| 11 | Ke Bu Rina (75, 5, 95) → Jual ikan → Jual semua | Konfirmasi total → koin bertambah; quest "Rezeki Nelayan" |
| 12 | Lepas ikan di Tas (B) | Poin Konservasi bertambah sesuai rarity |
| 13 | Masuk air sambil memancing | Sesi batal: "Kamu masuk air, memancing dibatalkan." |

## E. Perintah debug (hanya Studio, ketik di chat)
`/koin 5000` · `/level 10` · `/cuaca Badai` · `/event JamEmas` (`MusimIkan`, `BulanPurnama`, `None`) ·
`/waktu 20` · `/isitas DeepSea`.

**`/semua`** — buka semua untuk menguji seluruh fitur: Level 50, +1.000.000 koin, +5.000 poin konservasi, tas 150,
semua joran, umpan ×999, semua kosmetik & gelar, Fishdex 28/28 (lewat jalur tangkapan → quest/achievement/hadiah zona
ikut teruji), satu ikan tiap spesies di tas (termasuk yang dilindungi, untuk uji Lepaskan). Lalu: ganti joran di toko
Pak Darto → **Pakai**, ambil hadiah Fishdex di Prof. Mina, coba kosmetik (C), jual/barter/trade. Di mode uji data
kembali awal setiap Play; untuk menguji alur beli joran/tas/kosmetik, Play ulang dan pakai `/koin` + `/level` saja.
Di place dengan DataStore asli perintah ini menolak kecuali `/semua paksa` (perubahan permanen).

## F. Trade dua pemain (Test → Clients and Servers, 2 pemain)
1. Test tab → **Clients and Servers** → 2 Players → Start.
2. Client 1: `/isitas`, dekati Client 2 (≤ 30 stud), tekan **G** → Ajak Tukar (atau tekan **T** di dekat karakter).
3. Client 2: kartu undangan → Terima (kedaluwarsa 20 dtk; ajakan ulang dibatasi 10 dtk).
4. Client 1 tambah 2 ikan + 5 umpan; Client 2 tambah 100 koin. Setiap perubahan → status Siap keduanya reset.
5. Keduanya Siap → hitung mundur 5 → tukar. Cek tas & koin di kedua client dan TradeLog (Output server `[Trade] ...`).
6. Uji batal: menjauh > 50 stud; salah satu mulai memancing; tutup jendela; keluar dari game.
7. Uji tolak: coba tawarkan ikan terkunci/dilindungi (tidak muncul di pemilih; server menolak bila dipaksa).

## G. Perangkat & input
- **Device Emulator**: iPhone landscape (±844×390), tablet, 1080p, 720p. Periksa HUD tidak tertutup topbar/
  thumbstick, menu kiri berubah menjadi baris di layar pendek, panel tidak terpotong, teks ≥ 14 px.
- **Sentuh**: tombol Lempar/Tarik (kanan bawah) muncul saat joran dipegang; tahan untuk tenaga & minigame.
- **Controller Emulator**: R2 lempar/tarik, L1 pegang joran, B tutup panel, navigasi menu dengan D-pad.
- **Pengaturan → Mode grafis rendah**: camar/kepiting/ikan/kunang-kunang/hujan partikel/perahu bergoyang mati.

## H. Persistensi data (place dipublish)
1. Game Settings → Security → **Enable Studio Access to API Services** ON.
2. Play → beli sesuatu / tangkap ikan → Stop → Play lagi → data tetap (tidak ada toast mode uji).
3. Papan peringkat plaza terisi setelah ±5 menit (refresh 5 menit).
