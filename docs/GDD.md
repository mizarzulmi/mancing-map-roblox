# Pantai Mancing Nusantara — Game Design Document

> Salinan utuh Bagian 3–7 dari dokumen spesifikasi proyek. Jangan diubah tanpa persetujuan;
> perubahan angka balancing dicatat di `docs/PROGRESS.md`, catatan implementasi di `docs/PLAN.md`.

# BAGIAN 3 — MAP PANTAI
Koordinat: Y = 0 permukaan laut, +Z ke arah laut (selatan), −Z ke daratan. Satuan stud. Posisi adalah perkiraan; rapikan agar natural.

Terrain: WriteVoxels per chunk, Region3 diselaraskan dengan ExpandToGrid(4). Per kolom voxel: di bawah tinggi tanah = Sand/Grass/Rock/Mud, antara tanah dan Y = 0 = Water, di atasnya Air.
- Laut: X dan Z ±1.200, dasar sampai Y −60.
- Pulau ±520 × 360 berpusat (0, 0, −40): bukit rumput di utara (sampai Y +24, math.noise), pita pasir Z 20→120 menurun landai dari Y +5 ke 0 di garis pantai, lanjut di bawah air sampai Y −12 di Z≈200, lalu turun ke −40 setelah Z≈320. Batu di tanjung timur dan tepi bukit.
- Laguna Bakau di barat (pusat −250, 0, 40): cekungan air dangkal ±120 × 100, tersambung ke laut lewat kanal sempit, dikelilingi bakau (akar tunjang melengkung), dengan titian kayu.
- Air tosca, transparansi sedang, ombak kecil (WaterWaveSize/WaterWaveSpeed lembut).

| Objek | Posisi | Catatan |
|---|---|---|
| Spawn | (0, 7, −40), menghadap laut | papan "Selamat Datang di Pantai Nusantara" |
| Pasar Pantai (plaza) | pusat (0, 6, −10), ±80 × 50 | lantai papan, lampu taman, papan nama SurfaceGui |
| Papan Pengumuman, Pak Lurah | (0, 6, −20) | papan quest |
| Toko Pancing, Pak Darto | (−30, 6, −15) | rak joran, tong umpan, atap terpal |
| Butik Pantai, Mbak Sari | (30, 6, −15) | payung warna-warni, pajangan topi |
| Pondok Riset, Prof. Mina | (−60, 6, 0) | meja, akuarium kaca |
| Pos Penjaga Pantai, Kak Laut | (−90, 5, 70) | menara jaga, pelampung penyelamat |
| Lapak Pengepul, Bu Rina | (75, 5, 95), pangkal dermaga | meja es, ikan pajangan, timbangan |
| Dermaga utama | (90, 3, 110) sampai Z 250, lebar 10, ujung bentuk T | tiang, pagar tali, ember, jaring, lampu |
| Gubuk Barter, Kakek Bahari | (90, 4, 255), ujung dermaga | gubuk kayu, lentera |
| Dermaga Kapal, Nahkoda Jaka | (140, 4, 120) | kapal feri kecil tertambat |
| Platform Laut Dalam | pusat (60, 4, 820), 70 × 70 | gubuk, NPC Awak Kapal, kapal pulang |
| Mercusuar | tanjung batu (220, 0, 180), tinggi ±60 | belang merah-putih, lampu berputar saat malam |
| Kapal Pinisi | berlabuh di (−60, 0, 360) | dua tiang, layar, bergoyang |
| Perahu jukung (bercadik) | 3 di pasir sekitar (−40…20, 2, 115), 2 tertambat di dermaga | warna cerah, cadik bambu |
| Area santai | X −150…−30, Z 30…90 | payung + kursi berjemur, net voli, api unggun + bangku kayu, istana pasir, rak papan selancar |
| Penjual es kelapa | (15, 5, 40) | gerobak + NPC ambient |
| Pohon kelapa | ±40, sebaran Poisson-disk (jarak min 14) | batang melengkung dari segmen silinder yang berotasi bertahap, daun wedge tipis melengkung radial, buah kelapa; hindari jalur dan bangunan |
| Bawah laut | zona Pantai dan sekitar dermaga | karang warna-warni, rumput laut, bintang laut, kerang |
| Jalur | Spawn → Pasar → Dermaga | titian kayu + papan arah: DERMAGA, LAGUNA BAKAU (Lv 5), KE LAUT DALAM |
| Batas dunia | radius 1.150 dari pusat | dinding tak terlihat atau dorong balik perenang |

- Zona memancing: Part tak terlihat (Transparency 1, CanCollide/CanQuery/CanTouch = false) bernama FishingZone_<ZoneId> dengan atribut ZoneId. Jika tumpang tindih, zona dengan volume terkecil yang berlaku.
- Titik NPC: Part penanda tak terlihat NPCSpawn_<NpcId>. NPC dibuat saat runtime oleh NPCService.
- Cahaya (titik awal, sesuaikan setelah melihat screenshot): ClockTime 14, Atmosphere (Density ±0,3, Haze ±1,5), Clouds di Terrain (Cover ±0,5), Bloom halus, SunRays tipis, ColorCorrection sedikit hangat (saturasi +0,1). Properti yang tidak bisa diubah script runtime (mis. Lighting.Technology = Future) di-set saat bake lewat execute_luau bila diizinkan; jika tidak, tulis langkah manualnya di README.
- Kehidupan ambient (client): camar berputar, kepiting berjalan menyamping dan kabur saat didekati, gerombolan ikan kecil di karang, perahu dan pinisi bergoyang, kunang-kunang di laguna saat malam, lampu taman dan mercusuar menyala malam, nelayan NPC sesekali "dapat ikan" (ikan melompat ke ember + cipratan). Mode grafis rendah di Pengaturan mematikan semua efek ini.

# BAGIAN 4 — SISTEM GAMEPLAY
4.1 Memancing (server-authoritative; state per pemain: Idle → Charging → Casting → Waiting → Bite → Reeling → Idle)
- Joran adalah Tool yang dibuat server dari Config/Rods + skin terpasang, diberikan ke Backpack. Tali pancing = Beam dari Attachment ujung joran ke Attachment pelampung, dengan CurveSize untuk efek kendur.
- Lempar: tahan klik kiri/Spasi/tombol "Lempar" (mobile) untuk mengisi bar power 0–100% (ping-pong selama ditahan), lepas untuk melempar. Client hanya mengirim power dan arah horizontal. Server menghitung titik jatuh = posisi pemain + arah × lerp(8, CastDistance joran, power), lalu raycast ke bawah dengan IgnoreWater = false; harus mengenai Material Water. Server menentukan zona dan mengecek syarat level zona, tas tidak penuh, serta cooldown. Animasi busur dibuat client; pelampung resmi dibuat server di titik valid agar terlihat pemain lain.
- Menunggu: 4–11 dtk × pengali tunggu joran × pengali tunggu umpan × modifikasi cuaca/event. Client boleh menampilkan 0–2 gigitan palsu (pelampung bergetar).
- Gigitan: umpan berkurang 1. Server menentukan ikan saat itu (rarity → spesies → berat → mutasi, lihat 4.2) dan menyimpannya di sesi. Client hanya menerima tanda "!" dan parameter minigame, bukan spesies. Pemain harus klik dalam 1,5 dtk (toleransi server +0,5 dtk); jika lewat, ikan kabur.
- Minigame reel (gaya Fisch/Stardew, bar horizontal di bawah tengah layar): zona tangkap (lebar = Control joran) bergerak ke kanan saat ditahan dan jatuh ke kiri saat dilepas, dengan inersia. Ikon ikan bergerak sesuai pola rarity: Common halus-lambat, Rare melesat, Epic acak, Legendary cepat dan berbalik mendadak, Mythic lonjakan. Progres mulai 30%, naik 0,35/dtk × ReelSpeed saat ikan di dalam zona, turun 0,25/dtk di luar zona (dua kali lipat bila berat ikan > MaxWeight joran = mode "Sulit"). 100% berhasil; 0% atau 25 dtk gagal. Server memberi seed dan parameter, lalu menolak klaim sukses jika durasi < waktu minimum teoretis × 0,9 atau sesi tidak valid/kedaluwarsa. Catat di README bahwa hasil minigame adalah klaim client yang dibatasi validasi waktu.
- Hasil: ikan masuk tas (Uid GUID, SpeciesId, Weight, Mutation, Zone, CaughtAt, Locked = false). Popup kartu tangkapan: ViewportFrame model 3D ikan berputar, nama, berat, rarity, mutasi, harga, XP, label "BARU!" bila pertama di Fishdex. Ikan Protected menampilkan tombol "Lepaskan".
- Batal otomatis bila tool dilepas, pemain menjauh dari pelampung, atau masuk air. Tas penuh: tidak bisa melempar, toast "Tas penuh! Jual atau lepaskan ikan dulu."

4.2 Rumus (konstanta di Config/Balance.luau)
- Bobot rarity dasar per 1.000: Common 600, Uncommon 250, Rare 100, Epic 38, Legendary 10, Mythic 2. Bobot efektif = dasar × (1 + Luck)^k, dengan k: Common 0, Uncommon 0,5, Rare 1, Epic 1,5, Legendary 2, Mythic 2,5. Luck = joran + umpan + cuaca + event. Rarity tanpa spesies valid di zona/waktu/cuaca saat itu dikeluarkan, lalu bobot dinormalisasi.
- Berat = min + (max − min) × r^2,2 (cenderung kecil, sesekali besar).
- Mutasi: Berkilau 4% (harga ×2, efek kilau), Albino 1,2% (×3, putih), Emas 0,6% (×5, material emas), Pelangi 0,2% (×10, warna berganti). Umpan Emas dan event Jam Emas: peluang mutasi ×2; Joran Emas Bahari: ×1,5.
- Harga jual = round(hargaDasar × (berat / beratRataRata)^0,75 × pengaliMutasi × pengaliEvent).
- XP tangkap: Common 5, Uncommon 12, Rare 30, Epic 80, Legendary 200, Mythic 600, dikali pengali mutasi (Berkilau 1,5; Albino 2; Emas 3; Pelangi 5). XP ke level berikut = floor(40 × L^1,35), level maksimum 50, hadiah naik level = 25 × L koin.
- Target balancing (cek dengan skrip BalanceSim yang mencetak hasil ke Output): joran ke-2 ±5 menit, ke-3 ±45 menit, ke-4 ±2,5 jam, ke-5 ±7 jam bermain aktif; Laguna terbuka ±30 menit, Laut Dalam ±1 jam.

4.3 Ekonomi, toko, inventaris
- Koin di leaderstats ("Koin", "Level"); koin awal 50. Semua perubahan koin lewat Economy.Add / Economy.TrySpend(player, amount, reason): tidak pernah negatif dan selalu tercatat alasannya.
- Pembelian: server mengambil harga dari Config, mengecek level, kepemilikan, dan jarak ke NPC penjual (≤ 20 stud), lalu mengurangi koin dan memberi item tanpa yield di antaranya.
- Tas Ikan: kapasitas 20 → 35 (400 koin) → 60 (2.000) → 100 (9.000) → 150 (30.000). Sortir (terbaru, harga, rarity, berat), filter rarity, kunci ikan (tidak bisa dijual/ditukar), multi-pilih.
- Jual di Bu Rina: jual terpilih, jual semua kecuali yang terkunci, atau jual per rarity; selalu dengan konfirmasi total.
- Lepaskan ikan di mana saja memberi Poin Konservasi (Common 0, Uncommon 1, Rare 3, Epic 8, Legendary 20, Mythic 50). Ikan Protected tidak bisa dijual atau ditrade, memberi poin khusus (lihat tabel ikan), dan tetap memberi XP serta entri Fishdex.
- Equip: joran, umpan aktif, dan kosmetik per slot (Topi, Aksesori, SkinJoran, Pelampung, Jejak, Aura, Gelar). Kosmetik dipasang ke attachment R15 standar (HatAttachment, FaceFrontAttachment, NeckAttachment, BodyBackAttachment) dan dilewati dengan aman bila attachment tidak ada.

4.4 Barter (Kakek Bahari; resep di Config/Barter)
- 5 ikan Rare apa saja → 3 Umpan Emas
- 1 ikan Epic + 2.000 koin → Joran Emas Bahari (sekali per akun, Lv 20)
- 10 ikan Uncommon → Topi Nelayan Tua (eksklusif)
- 1 ikan Legendary (bukan Protected) → Aura Cahaya Samudra (eksklusif)
Server otomatis memilih ikan bernilai terendah yang memenuhi syarat (tidak terkunci) dan menampilkan daftarnya sebelum konfirmasi.

4.5 Trade antar pemain
- Undangan dari menu "Pemain di Sekitar" (≤ 30 stud) atau ProximityPrompt "Ajak Tukar" di karakter pemain lain (disembunyikan di karakter sendiri). Undangan kedaluwarsa 20 dtk; cooldown 10 dtk.
- Bisa ditukar: ikan (maksimal 8, kecuali Protected dan yang terkunci), umpan (jumlah), koin. Joran dan kosmetik tidak bisa ditukar.
- Jendela dua kolom. Setiap perubahan isi mereset status "Siap" kedua pihak. Jika keduanya Siap → hitung mundur 5 dtk → server memvalidasi ulang kepemilikan, status terkunci, kapasitas tas, dan saldo → menukar secara atomik (tanpa yield) → menyimpan kedua profil → mencatat log trade (id, isi, waktu).
- Batal otomatis bila salah satu keluar, menjauh > 50 stud, atau mulai memancing. Tampilkan estimasi nilai kedua sisi dan peringatan bila timpang.

4.6 RPG
- Level membuka joran dan zona (lihat tabel di Bagian 5). Nametag di atas kepala: "Lv 12 · Nama" + gelar terpasang.
- Quest cerita dari Pak Lurah (berurutan):
  1. Selamat Datang — bicara dengan Pak Lurah → 50 koin
  2. Umpan Pertama — beli 5 Cacing di Pak Darto → 20 koin, 10 XP
  3. Tangkapan Perdana — tangkap 3 ikan → 50 koin, 30 XP
  4. Rezeki Nelayan — jual ikan total ≥ 100 koin di Bu Rina → 60 koin
  5. Gaya Pantai — beli 1 kosmetik → 100 koin + gelar "Anak Pantai"
  6. Ujung Dermaga — tangkap 1 ikan di zona Dermaga → 80 koin, 50 XP
  7. Peneliti Muda — temukan 8 spesies → 300 koin
  8. Bakau Misterius (Lv 5) — tangkap 3 ikan di Laguna → 400 koin
  9. Mengarungi Samudra (Lv 10) — naik kapal ke Laut Dalam → 200 koin
  10. Penjaga Laut — lepaskan 1 ikan Protected → 50 Poin Konservasi
  11. Sang Legenda — tangkap 1 ikan Legendary → 3.000 koin + gelar "Pemburu Legenda"
- Quest harian: 3 acak dari pool (tangkap 15 ikan; tangkap 3 ikan Rare+; jual total 1.000 koin; tangkap ikan ≥ 10 kg; tangkap 5 ikan saat malam; pakai 10 umpan; lepaskan 2 ikan; tangkap 1 ikan bermutasi). Reset 00:00 WIB (UTC+7). Hadiah: koin = 100 + 20 × Level, XP = 50 + 10 × Level.
- Fishdex (Prof. Mina): per spesies jumlah, berat terbaik, waktu pertama, petunjuk zona/waktu; siluet untuk yang belum ditemukan. Hadiah lengkap per zona: Pantai 500, Dermaga 1.000, Laguna 3.000, Laut Dalam 10.000 koin + gelar.
- Achievement → gelar: Tangkapan Pertama "Pemula Pantai"; 100 ikan "Nelayan Tangguh"; 1.000 ikan "Raja Pancing"; Fishdex Pantai lengkap "Ahli Pantai"; mutasi Pelangi "Pelangi Samudra"; total pendapatan 100.000 koin "Juragan Ikan"; total 250 Poin Konservasi "Sahabat Laut"; menangkap Naga Laut "Penakluk Naga".
- Papan peringkat fisik di plaza (SurfaceGui): ikan terberat dan total koin (OrderedDataStore, refresh 5 menit, nonaktif di mode mock).

4.7 Dunia hidup
- Siang–malam: satu hari game = 15 menit (Config). Server menyimpan waktu acuan sebagai atribut di ReplicatedStorage; tiap client menghitung ClockTime sendiri dari workspace:GetServerTimeNow(). Malam = ClockTime ≥ 18,5 atau < 5,5.
- Cuaca (atribut, durasi 4–8 menit): Cerah 55%, Berawan 25%, Hujan 15% (Luck +0,1), Badai 5% (Luck +0,2, ombak lebih tinggi, kilat, langit gelap; syarat Naga Laut). Efek visual dan suara di client.
- Event acak setiap ±30 menit: Jam Emas (10 menit, peluang mutasi ×2), Musim Ikan (harga jual +25%), Bulan Purnama (hanya malam; Ikan Kristal Bulan muncul, Luck Laguna +0,3). Banner event di HUD.
- Kapal: Nahkoda Jaka mengantar ke Platform Laut Dalam (Lv 10, 150 koin); pulang gratis lewat Awak Kapal. Layar fade + teleport server (PivotTo). Syarat level zona tetap dicek saat melempar, jadi pemain yang berenang ke sana tetap tidak bisa memancing sebelum Lv 10.
- DebugService (hanya bila RunService:IsStudio()): perintah chat /koin, /level, /cuaca, /event, /waktu, /isitas untuk mempercepat uji.

4.8 NPC
- Dibuat server dengan Players:CreateHumanoidModelFromDescription (R15) + warna tubuh dari Config. Detail pakaian dari part (caping untuk nelayan, celemek Bu Rina, topi kapten Nahkoda, topi ranger Kak Laut, kacamata Prof. Mina), tanpa asset pakaian.
- HumanoidRootPart di-anchor, nama bawaan disembunyikan. BillboardGui nametag "Pak Darto · Toko Pancing" + ikon "!" bila ada quest. ProximityPrompt (tombol E, jarak 10, tanpa tahan) membuka dialog lalu menu.
- Pose idle dan pose memancing lewat Motor6D C0 (tanpa asset animasi). Kepala menoleh ke pemain terdekat (client).

# BAGIAN 5 — DATA KONTEN AWAL (isi ke Config)
Zona:
| ZoneId | Nama | Lokasi | Syarat |
|---|---|---|---|
| Shore | Pantai Dangkal | perairan depan pantai pasir | – |
| Pier | Ujung Dermaga | sekitar ujung dermaga | – |
| Mangrove | Laguna Bakau | laguna barat | Lv 5 |
| DeepSea | Laut Dalam | radius ±150 dari platform | Lv 10 |

Ikan (R: C Common, U Uncommon, R Rare, E Epic, L Legendary, M Mythic). Tiap spesies juga punya warna primer/sekunder, bentuk untuk FishModel (Ramping, Gemuk, Pipih, Belut, Paruh, Kepiting, Cumi, Lobster, Naga, Kristal), dan teks petunjuk Fishdex.
| Id | Nama | R | Zona | Syarat | Berat (kg) | Harga dasar |
|---|---|---|---|---|---|---|
| teri | Ikan Teri | C | Shore, Pier | – | 0,02–0,08 | 4 |
| kembung | Ikan Kembung | C | Shore, Pier | – | 0,2–0,6 | 8 |
| belanak | Ikan Belanak | C | Shore, Mangrove | – | 0,3–1,5 | 10 |
| baronang | Ikan Baronang | C | Shore, Pier | siang | 0,3–1,2 | 12 |
| selar | Ikan Selar | C | Pier, DeepSea | – | 0,2–0,8 | 9 |
| bandeng | Ikan Bandeng | C | Mangrove | – | 0,5–2,5 | 14 |
| layang | Ikan Layang | C | DeepSea | – | 0,1–0,4 | 12 |
| rajungan | Rajungan | U | Shore | – | 0,1–0,5 | 26 |
| cumi | Cumi-cumi | U | Shore, Pier | malam | 0,2–1,5 | 28 |
| kakap_merah | Kakap Merah | U | Pier, DeepSea | – | 1–8 | 35 |
| kerapu_macan | Kerapu Macan | U | Pier, Mangrove | malam | 1–10 | 45 |
| tongkol | Ikan Tongkol | U | Pier, DeepSea | siang | 1–6 | 30 |
| kepiting_bakau | Kepiting Bakau | U | Mangrove | – | 0,3–2 | 40 |
| badut | Ikan Badut | R | Shore | siang | 0,05–0,25 | 90 |
| pari_totol | Pari Totol | R | Shore, Mangrove | – | 2–25 | 130 |
| barakuda | Barakuda | R | Pier, DeepSea | – | 3–20 | 110 |
| lobster_mutiara | Lobster Mutiara | R | Pier | malam | 0,5–4 | 140 |
| gt | Kuwe Raksasa (GT) | R | DeepSea | siang | 8–45 | 160 |
| napoleon | Ikan Napoleon | E | Pier, DeepSea | siang | 10–80 | Protected: 25 poin |
| kerapu_kertang | Kerapu Kertang | E | Mangrove, DeepSea | malam | 30–200 | 450 |
| layaran | Ikan Layaran | E | DeepSea | siang | 20–90 | 380 |
| tuna_sirip_kuning | Tuna Sirip Kuning | E | DeepSea | – | 20–120 | 420 |
| sidat_raksasa | Sidat Raksasa | L | Mangrove | malam | 5–20 | 1.300 |
| marlin_biru | Marlin Biru | L | DeepSea | siang | 80–400 | 1.500 |
| ikan_pedang | Ikan Pedang | L | DeepSea | malam | 60–300 | 1.800 |
| coelacanth | Raja Laut (Coelacanth) | L | DeepSea | malam | 30–90 | Protected: 120 poin ("fosil hidup dari perairan Sulawesi") |
| kristal_bulan | Ikan Kristal Bulan | M | Mangrove | malam + event Bulan Purnama | 5–20 | 7.000 |
| naga_laut | Naga Laut Samudra | M | DeepSea | cuaca Badai | 300–900 | 9.000 |

Joran (Tunggu × = pengali waktu tunggu, makin kecil makin cepat; Control = lebar zona tangkap):
| Id | Nama | Harga | Lv | Luck | Tunggu × | Control | ReelSpeed | MaxWeight | Jarak lempar |
|---|---|---|---|---|---|---|---|---|---|
| bambu | Joran Bambu | awal | 1 | 0 | 1,00 | 0,26 | 1,00 | 12 | 35 |
| fiber | Joran Fiberglass | 350 | 3 | 0,10 | 0,92 | 0,28 | 1,08 | 30 | 45 |
| karbon | Joran Karbon | 1.500 | 8 | 0,25 | 0,85 | 0,30 | 1,15 | 80 | 55 |
| samudra | Joran Samudra | 6.000 | 15 | 0,45 | 0,78 | 0,32 | 1,25 | 200 | 65 |
| emas_bahari | Joran Emas Bahari | barter | 20 | 0,60 | 0,75 | 0,34 | 1,30 | 300 | 70 |
| legenda | Joran Legenda Nusantara | 25.000 | 25 | 0,80 | 0,70 | 0,35 | 1,40 | 500 | 75 |

Umpan (dibeli 1/10/50/maks):
| Id | Nama | Harga | Luck | Tunggu × | Efek |
|---|---|---|---|---|---|
| – | Tanpa umpan | – | 0 | 1,15 | – |
| cacing | Cacing | 2 | 0 | 0,90 | – |
| udang | Udang Segar | 6 | 0,10 | 0,85 | – |
| cumi_potong | Potongan Cumi | 15 | 0,20 | 0,85 | – |
| kilau | Umpan Kilau | 40 | 0,30 | 0,80 | malam: Luck +0,2 |
| emas | Umpan Emas | barter | 0,80 | 0,75 | peluang mutasi ×2 |

Kosmetik (semua model prosedural):
- Topi: Topi Jerami 250, Caping 400 (kerucut dari 5–6 silinder bertingkat), Bandana Bajak Laut 600, Topi Kapten 1.200, Mahkota Kerang 5.000. Eksklusif: Topi Nelayan Tua (barter), Topi Ranger (60 poin konservasi).
- Aksesori: Kacamata Hitam 350, Kalung Kerang 450, Rompi Pelampung 900, Ransel Ikan 1.800.
- Skin joran: Kayu Klasik (awal), Neon Biru 800, Loreng Pantai 1.500, Emas 6.000, Pelangi 12.000 (warna berganti).
- Pelampung: Merah Putih (awal), Bebek Kuning 300, Bintang Laut 500, Semangka 700, Bola Api 2.500 (efek Fire). Eksklusif: Karang (40 poin).
- Jejak (Trail): Gelembung 1.000, Ombak 2.000, Pelangi 6.000. Eksklusif: Jejak Penyu (200 poin).
- Aura: Percikan Air 3.000, Kunang-kunang 5.000 (menyala saat malam). Eksklusif: Aura Penyu (150 poin), Cahaya Samudra (barter).
- Gelar: dari quest dan achievement, tidak dijual.

NPC:
| NpcId | Nama | Peran | Kalimat pembuka |
|---|---|---|---|
| pak_lurah | Pak Lurah | quest cerita & harian | "Selamat datang di Pantai Nusantara! Warga sini butuh bantuanmu." |
| pak_darto | Pak Darto | joran, umpan, upgrade tas | "Mau mancing? Joran kuat, umpan segar, harga bersahabat!" |
| mbak_sari | Mbak Sari | kosmetik | "Biar makin kece pas mancing, cobain koleksi baru!" |
| bu_rina | Bu Rina | membeli ikan | "Ikan segar? Sini, Ibu beli dengan harga pas." |
| kakek_bahari | Kakek Bahari | barter | "Laut menyimpan banyak rahasia, Nak." |
| nahkoda_jaka | Nahkoda Jaka | kapal ke Laut Dalam | "Laut Dalam menunggu. Siap berlayar?" |
| awak_kapal | Awak Kapal | kapal pulang | "Mau balik ke pantai? Naik saja." |
| kak_laut | Kak Laut | konservasi + toko poin | "Ikan dilindungi wajib dilepas. Bantu jaga laut kita, ya!" |
| prof_mina | Prof. Mina | Fishdex + hadiah koleksi | "Setiap ikan punya cerita. Catat semuanya!" |
Ambient: 4 nelayan (dermaga dan pantai), 3 wisatawan berjemur, 1 penjual es kelapa; masing-masing 3–5 kalimat acak tanpa menu.

# BAGIAN 6 — UI/UX
Prinsip:
- Semua UI dibuat lewat kode dari komponen di StarterPlayerScripts/UI dan satu modul Config/Theme. ScreenGui terpisah untuk HUD, Panel, Popup, dan Minigame; ResetOnSpawn = false; ScreenInsets = DeviceSafeInsets.
- Layout berbasis Scale + UIListLayout/UIGridLayout/UIPadding + UISizeConstraint/UIAspectRatioConstraint, dengan satu UIScale global sesuai ukuran layar (0,75–1,25). Harus rapi di 1920×1080, 1280×720, dan ponsel landscape ±844×390.
- Target sentuh ≥ 48 px. Teks minimal 14 px (UITextSizeConstraint); jangan TextScaled tanpa batas.
- Hanya satu panel besar terbuka dalam satu waktu (UIController mengelola stack; Esc, tombol X, atau ketuk di luar panel menutup). Saat panel terbuka, input memancing nonaktif.
- Animasi 0,15–0,2 dtk (Quad Out). Hormati GuiService.ReducedMotionEnabled bila tersedia.
- Input: PC (klik/Spasi, angka 1 untuk joran, huruf pintas menu), mobile (tombol besar Lempar/Tarik di kanan bawah), gamepad dasar (R2 lempar/tarik, B tutup panel, navigasi menu dengan GuiService.SelectedObject).

Token tema (kontras teks sudah dicek ≥ 4,5:1 di atas panel dan kartu):
- Font: FredokaOne untuk judul dan angka besar, BuilderSans (Medium/Bold) untuk teks. Maksimal dua font.
- Panel #0F2F3A (transparansi ≤ 0,08), kartu #16404D, teks #F7F3E8, teks sekunder #B7CDD3, stroke putih transparansi 0,85, radius 12 px (kartu 10 px), skala jarak 4/8/12/16/24.
- Tombol utama #F2C14E dengan teks #1A1A1A; sekunder #2BB3B1 dengan teks #1A1A1A; jual/bahaya #FF7A59 dengan teks #1A1A1A; sukses #6EE08A.
- Rarity: Common #C9D1D9, Uncommon #6EE08A, Rare #5AAEFF, Epic #C495FF, Legendary #FFC04D, Mythic #FF85B8 (Mythic boleh memakai UIGradient beranimasi asalkan semua warnanya tetap terang).
- Nametag di dunia: teks terang + UIStroke gelap agar terbaca di atas pasir maupun langit.
- Satu aksen utama (emas pasir). Hindari gradien ungu-biru generik, emoji berlebihan, bayangan tebal, dan terlalu banyak warna aksen sekaligus.

Layar:
- HUD: kiri atas level + bar XP; kanan atas Koin (angka paling menonjol, animasi hitung naik), Poin Konservasi, kapasitas tas "17/20"; tengah atas jam + ikon cuaca + banner event; kanan pelacak quest (bisa dilipat, maks 3); kiri tombol menu (Tas, Fishdex, Quest, Kosmetik, Pengaturan); bawah tengah slot joran + umpan aktif yang bisa diganti cepat; toast di atas tengah (maks 3, 3 dtk).
- Toko (Pak Darto, Mbak Sari, Kak Laut): header NPC + saldo, tab kategori, grid ItemCard (nama, harga, status Dimiliki/Dipakai/Terkunci Lv X), panel detail dengan ViewportFrame model berputar dan perbandingan stat terhadap yang sedang dipakai (naik hijau, turun merah), pemilih jumlah umpan, tombol Beli/Pakai.
- Juga: Tas Ikan, Jual (Bu Rina), Barter, Trade, Quest, Fishdex, Dialog NPC (kotak bawah, efek ketik, pilihan), Kapal, Pengaturan (volume musik/SFX, mode grafis rendah, skala UI), popup tangkapan, bar power lempar, overlay minigame, perayaan naik level.

# BAGIAN 7 — DATA & KEAMANAN
- Data pemain: ProfileStore (https://github.com/MadStudioRoblox/ProfileStore) disalin ke ServerScriptService/Packages, lisensinya di docs/licenses/. Jika tidak bisa diunduh, tulis DataService sendiri: UpdateAsync + session lock + retry dengan backoff + autosave 60 dtk + BindToClose.
- Template profil (Version = 1; migrasi berdasarkan Version; Reconcile untuk field baru): Coins = 50, Level = 1, XP = 0, ConservationPoints = 0, BagCapacity = 20, Fish = {Uid, SpeciesId, Weight, Mutation, Zone, CaughtAt, Locked}[], Rods = {"bambu"}, EquippedRod = "bambu", Bait = {[BaitId] = Qty}, EquippedBait, Cosmetics = {Owned, Equipped = {Hat, Accessory, RodSkin, Bobber, Trail, Aura, Title}}, Quests = {StoryIndex, StoryProgress, DailyDay, Daily}, Fishdex = {[SpeciesId] = {Count, BestWeight, FirstAt}}, FishdexClaimed, Achievements, Stats = {TotalCaught, TotalEarned, TotalReleased, HeaviestKg}, BarterOnce, Settings = {Music, Sfx, LowGfx, UiScale}, LastLogin.
- Client menerima snapshot awal lewat RemoteFunction GetInitialData, lalu perubahan lewat event DataChanged (delta). Data otoritatif hanya di server.
- Server memutuskan semuanya (hasil ikan, harga, hadiah, koin). Client hanya mengirim niat, tidak pernah harga, jumlah hadiah, atau data ikan.
- Setiap remote divalidasi: tipe (typeof), rentang, kepemilikan, state machine, jarak ke NPC/lokasi, dan rate limit token bucket. Pelanggaran → tolak + warn(UserId, remote, alasan), tanpa error yang menghentikan server.
- Sesi memancing memakai sessionId, satu sesi aktif per pemain, kedaluwarsa otomatis.
- Pembelian, jual, barter, trade: cek dan mutasi tanpa yield di antaranya; validasi ulang saat eksekusi.
- Perintah debug hanya aktif bila RunService:IsStudio().
