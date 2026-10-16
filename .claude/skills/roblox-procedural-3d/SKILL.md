---
name: roblox-procedural-3d
description: >
  Kerajinan dunia 3D prosedural Roblox yang TIDAK kotak-kotak memakai primitif (Ball/Cylinder/Wedge/
  CornerWedge, SpecialMesh Sphere), Terrain (FillBall/WriteVoxelChannels), Beam, dan Light: kurva Bezier
  bersegmen dengan taper, daun radial, elipsoid, kerucut bertingkat, tali kendur, jitter warna deterministik,
  penempatan menempel tanah, Poisson-disk; plus checklist review level designer dan anggaran part. Pakai saat
  membangun/merevisi map (ServerScriptService/World/*) atau model prosedural (Shared/Models/*).
---

# Dunia 3D prosedural yang tidak kotak-kotak

Arah dipatok pemilik: **stylized tropis membulat** (`docs/UI-DIRECTION.md`, `PRODUCT.md`). Gagasan pengikat:
*dunia buatan tangan nelayan — setiap bentuk punya lengkung, sedikit miring, warna hangat; aksen saturasi hanya
di perahu, payung, dan karang.*

## Prinsip
1. **Siluet dulu.** Dari 60 stud objek harus terbaca bentuknya. Blok telanjang hanya untuk lantai/papan/peti.
2. **Lengkung = rantai segmen.** Batang, akar, lambung, atap, tali: titik-titik kurva → silinder/papan antar titik.
3. **Taper.** Ujung mengecil (batang kelapa 1,6 → 0,9; joran; akar).
4. **Bulat dari Ball/elipsoid.** Kanopi, karang, batu kecil, kepala, pelampung: `Part.Shape = Ball` atau
   `SpecialMesh` MeshType Sphere dengan `Scale` untuk elipsoid.
5. **Organik besar dari Terrain.** Bukit, tanjung batu, gumuk, karang besar: `FillBall`/`FillWedge`/voxel.
6. **Variasi deterministik.** `Random.new(seed + i)` untuk rotasi ±2–4°, skala ±10%, warna ±4% (HSV value).
7. **Menempel tanah.** Dasar objek = `HeightAt(x,z) - 0.3`; tidak ada yang melayang/terkubur; tidak ada dua
   permukaan sebidang (z-fighting) — geser 0,02 atau ubah ukuran.
8. **Hemat part.** Target ≤ 6.000 di BeachMap. Detail kecil `CastShadow=false`; dekorasi tanpa collision/query/touch.

## Cuplikan inti (Luau)
```lua
-- Silinder/papan dari A ke B (sumbu panjang = X untuk Shape Cylinder).
local function segment(a: Vector3, b: Vector3, thickness: number, props): Part
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new((b - a).Magnitude, thickness, thickness)
	p.CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0)
	-- ...properti dekorasi, Parent terakhir
	return p
end

-- Bezier kuadrat → titik-titik kurva.
local function bezier(p0: Vector3, p1: Vector3, p2: Vector3, n: number): { Vector3 }
	local pts = {}
	for i = 0, n do
		local t = i / n
		table.insert(pts, (1 - t) ^ 2 * p0 + 2 * (1 - t) * t * p1 + t ^ 2 * p2)
	end
	return pts
end

-- Rantai melengkung dengan taper: tebal r0 → r1.
for i = 1, #pts - 1 do
	local r = r0 + (r1 - r0) * (i - 1) / (#pts - 2)
	segment(pts[i], pts[i + 1], r, props)
end

-- Elipsoid: Part + SpecialMesh Sphere (tanpa MeshId).
local mesh = Instance.new("SpecialMesh")
mesh.MeshType = Enum.MeshType.Sphere
mesh.Scale = Vector3.new(1, 0.6, 1.4)

-- Kerucut (caping/atap bulat): tumpukan silinder pipih mengecil.
for i = 0, 5 do
	local d = base * (1 - i / 6)
	-- silinder tebal 0,25 berdiameter d, naik 0,25 per lapis
end

-- Daun kelapa radial: per pelepah 3 wedge tipis yang melengkung turun.
for k = 1, fronds do
	local yaw = (k / fronds) * math.pi * 2 + jitter
	-- titik pelepah: naik sedikit lalu jatuh (bezier), tiap segmen WedgePart pipih lebar 1,2 → 0,4
end

-- Tali kendur antar tiang tanpa part: Beam + CurveSize0/1.
-- Jitter warna:
local function jitter(c: Color3, rng: Random): Color3
	local h, s, v = c:ToHSV()
	return Color3.fromHSV(h, s, math.clamp(v * rng:NextNumber(0.96, 1.04), 0, 1))
end
```

## Poisson-disk (pohon, batu, properti)
Kandidat acak deterministik dalam area; terima bila jarak ke semua titik ≥ `minDist` dan di luar kotak eksklusi
(jalur, bangunan, dermaga). Batasi percobaan (mis. 30 × target).

## Review level designer (setelah bake, 6 sudut)
Udara, pasar, dermaga, laguna, mercusuar, Laut Dalam (CFrame kamera di skill `roblox-studio-mcp`). Nilai:
- **Skala**: pintu ≥ 7 stud, pagar ±3, lantai dermaga Y 3, pohon 18–28 stud, mercusuar ±60.
- **Kepadatan**: tidak ada area luas kosong di jalur utama; tidak ada tumpukan berlebih di satu titik.
- **Komposisi**: dari spawn terlihat laut + dermaga + mercusuar (landmark penuntun); bingkai kelapa.
- **Melayang/terkubur**: periksa kaki tiang, perahu di pasir, batu, NPC.
- **Jalur**: Spawn → Pasar → Dermaga jelas (titian + papan arah); tidak ada rintangan tak terlihat.
- **Z-fighting / tumpang tindih** pada lantai dan papan.
Urutkan 5 masalah terbesar → perbaiki di `World/*` → bake ulang → screenshot sebelum–sesudah dari sudut sama.
