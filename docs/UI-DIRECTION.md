# Arah Visual (UI + Dunia 3D)

Surface brief untuk seluruh UI dalam game dan map prosedural. Produk: `PRODUCT.md`. Token: `ReplicatedStorage/Shared/Config/Theme.luau`.
Mode impeccable: **Operate** untuk panel/toko/tas (tugas jelas, cepat dipindai); **Experience** untuk dunia 3D dan
momen tangkapan.

Catatan proses: dunia visual UI **dipatok oleh brief** (GDD Bagian 6: palet, font, radius, jarak, anti-pola), sehingga
tidak ada "roll" arah baru — arah yang dipatok brief selalu menang. Dimensi yang dibiarkan terbuka oleh brief
(ikon, bentuk komponen, grammar motion, materi dunia 3D) diputuskan di kontrak di bawah.

## Direction contract

**THESIS.** Air di bawah dermaga saat sore: panel teal laut-dalam yang tenang, satu kilau emas pasir hanya untuk yang
bernilai (koin, aksi utama, ikan langka), dan dunia buatan tangan nelayan yang serba membulat. Menolak default game
Roblox: tombol neon ber-stroke hitam tebal, gradien di mana-mana, popup yang memantul, ikon emoji.

**OWN-WORLD.** UI: panel #0F2F3A nyaris opak, kartu #16404D, garis tepi putih 85% transparan 1 px, sudut 12/10,
bayangan lembut ber-offset (UIShadow, blur 12–18, offset 0,4). Emas #F2C14E hanya untuk koin, CTA utama, dan
Legendary; teal #2BB3B1 untuk aksi sekunder. Ikon digambar dari Frame (koin cincin ganda, daun konservasi, tas,
ikan, jam, gelombang) dengan satu bobot garis 2 px. Angka besar FredokaOne; teks BuilderSans Medium/Bold.
Dunia 3D: kayu lapuk hangat, pasir krem-keemasan, laut tosca bening, aksen saturasi hanya di perahu, payung, dan
karang; setiap bentuk punya lengkung (silinder/bola/terrain), sedikit miring buatan tangan (±2–4°).

**STORY.** Pemain langsung paham: koin (kanan atas) adalah nilai terpenting, tombol Lempar adalah aksi utama, dan
setiap tangkapan adalah "kartu timbang" lapak ikan — berat dulu, lalu harga. Mereka kembali ke plaza karena tanda
"!" Pak Lurah dan papan peringkat.

**FIRST VIEWPORT.** Spawn menghadap laut: dermaga di kanan memanjang ke horizon, kelapa melengkung membingkai plaza
di kiri, mercusuar belang di tanjung kanan jauh, pinisi berlabuh di tengah laut. HUD tipis di tepi: kiri atas level +
bar XP, kanan atas koin (angka terbesar di layar), bawah tengah slot joran + umpan, kanan bawah tombol Lempar (HP).

**FORM.** Kartu timbang lapak ikan sebagai bahasa komponen (label harga bertali, angka timbangan) di atas sistem panel
teal; posisi #1 dari daftar kandidat dunia (lapak pengepul, papan dermaga, jaring/tali, layar pinisi, perahu jukung,
papan pengumuman desa, buku catatan peneliti). Seed: tidak ada (arah dipatok brief, tanpa roll).

**SIGNATURE.** Momen tangkapan: kartu timbang turun dari atas seperti digantung, ikan 3D berputar di ViewportFrame,
angka berat menghitung naik seperti jarum timbangan, lalu harga muncul. Satu momen motion yang dirancang; semua
transisi lain 0,15–0,2 dtk Quad Out, instan bila ReducedMotion.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance

## Batasan
- Tanpa eyebrow/kicker di atas judul, tanpa teks gradien, tanpa border samping > 1 px, tanpa glass dekoratif.
- Satu panel besar sekaligus; scrim 50% hitam saat panel terbuka.
- Rarity selalu teks + warna; Mythic boleh UIGradient beranimasi dengan semua warna terang.
- Tidak ada raster yang dikirim (semua UI dari Frame/teks), jadi tidak ada provenance raster yang perlu dicatat.
