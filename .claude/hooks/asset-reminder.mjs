// PostToolUse untuk insert_asset / generate_mesh: ingatkan kewajiban membersihkan script & menyimpan cadangan.
process.stderr.write(
	"Pengingat wajib (AGENTS.md §6): hapus SEMUA Script/LocalScript/ModuleScript di aset yang baru dimasukkan " +
		"(laporkan jumlahnya), simpan model primitif lama sebagai cadangan, dan jangan sentuh Workspace.CustomMap.\n",
);
process.exit(2);
