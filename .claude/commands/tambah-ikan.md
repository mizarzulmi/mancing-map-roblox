---
description: Tambah 4 spesies ikan baru untuk satu zona (1 Uncommon, 2 Rare, 1 Epic) hanya lewat Config, lalu SelfTest
argument-hint: <Zona: Shore | Pier | Mangrove | DeepSea>
---
[Tambah konten]
Tambahkan 4 spesies ikan baru untuk zona $ARGUMENTS (1 Uncommon, 2 Rare, 1 Epic) lengkap dengan warna Primary/Secondary, bentuk (Shape yang didukung FishModel), syarat waktu/cuaca, berat, harga dasar yang konsisten dengan spesies serarity, petunjuk Fishdex (Hint) dan Fact — spesies nyata perairan Indonesia bila memungkinkan. Cukup lewat ReplicatedStorage/Shared/Config/Fish.luau (tanpa kode baru). Lalu jalankan scripts/test.ps1 (ConfigSpec harus LULUS; perbarui jumlah spesies yang diharapkan di ConfigSpec bila perlu) dan SelfTest di Studio bila MCP terhubung. Catat di PROGRESS.md dan commit.
