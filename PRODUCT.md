# Product

<!-- impeccable:product-schema 1 -->

## Platform

roblox

Roblox engine (bukan web/iOS/Android native). Klien target: HP, tablet, PC, dan konsol — prioritas setara
(dikonfirmasi pemilik, 2026-10-16: "rilis publik semua perangkat").

## Stack

Luau (`--!strict`) di Roblox Studio; kode di disk, disinkronkan via Script Sync atau Rojo 7.7.1.
Semua UI, NPC, dan model dibuat lewat kode (dipatok spesifikasi proyek).

## Users

Pemain Roblox umum di semua perangkat untuk rilis publik. Mereka datang untuk sesi santai–menengah:
memancing, mengoleksi spesies, naik level, dan berinteraksi/bertukar dengan pemain lain.
*(Inferensi berlabel: rentang usia mengikuti demografi Roblox umum — anak hingga dewasa muda; teks dibuat singkat
dan mudah dibaca.)*

## Product Purpose

"Pantai Mancing Nusantara" (judul kerja): RPG memancing bertema pantai tropis Indonesia yang langsung bisa
dimainkan dari tombol Play di Studio. Sukses = loop inti (lempar → tunggu → strike → tarik → koleksi → jual/upgrade)
terasa memuaskan, adil (server-authoritative), dan mudah dikembangkan lewat Config.

## Positioning

Dunia pesisir Nusantara yang spesifik: jukung bercadik, pinisi, caping nelayan, lapak pengepul, barter dengan
kakek nelayan, spesies perairan Indonesia (kembung, baronang, kerapu macan, Napoleon, coelacanth Sulawesi), dan
mekanik konservasi — ikan dilindungi wajib dilepas dan justru memberi hadiah.

## Operating Context

Sesi multipemain di server Roblox; data tersimpan lewat ProfileStore (mock di Studio tanpa akses API).
Siklus siang–malam 15 menit, cuaca, dan event acak mengubah peluang tangkapan. Pemain bertemu di plaza,
dermaga, laguna bakau, dan platform Laut Dalam.

## Capabilities and Constraints

- Lihat `docs/GDD.md` (Bagian 3–7) untuk seluruh fitur dan angka; `AGENTS.md` untuk aturan teknis & keamanan.
- Dilarang mengarang `rbxassetid`; visual dari primitif Roblox, Terrain, material bawaan, efek, dan `rbxasset://`
  bawaan. Audio hanya ID terverifikasi.
- Target ≤ 6.000 part pada map.
- Bahasa: komunikasi & teks dalam game Bahasa Indonesia; identifier kode Inggris.

## Brand Commitments

- Nama kerja: "Pantai Mancing Nusantara".
- Token UI dipatok brief (GDD Bagian 6): panel #0F2F3A, kartu #16404D, teks #F7F3E8 / #B7CDD3, aksen emas pasir
  #F2C14E, sekunder #2BB3B1, bahaya #FF7A59, sukses #6EE08A, warna rarity, FredokaOne + BuilderSans, radius 12/10,
  skala jarak 4/8/12/16/24.
- Arah dunia 3D (dikonfirmasi pemilik, 2026-10-16): **stylized tropis membulat** — bentuk lengkung & bulat,
  warna cerah tapi natural, lighting Future + atmosfer hangat. Hindari tampilan "kotak-kotak".

## Evidence on Hand

Belum ada aset nyata (foto, testimoni, logo resmi, audio terverifikasi). Jangan mengarang testimoni, statistik
pemain, atau klaim komersial. Nama spesies & fakta konservasi mengikuti tabel GDD.

## Product Principles

1. Server memutuskan semuanya; client hanya mengirim niat. Keadilan lebih penting daripada efek instan.
2. Konten bertambah lewat Config, bukan kode baru.
3. Budaya pesisir Nusantara yang spesifik, bukan "tropis generik".
4. Terbaca dan mudah disentuh di setiap perangkat: HP, PC, konsol.
5. Konservasi adalah hadiah, bukan hukuman.

## Accessibility & Inclusion

- Kontras teks ≥ 4,5:1 di atas panel & kartu (diverifikasi, lihat docs/PROGRESS.md).
- Target sentuh ≥ 48 px; teks ≥ 14 px setelah skala; navigasi gamepad lewat `GuiService.SelectedObject`.
- Hormati `GuiService.ReducedMotionEnabled`; rarity tidak hanya lewat warna (selalu ada label teks).
- Mode grafis rendah mematikan efek ambient.
