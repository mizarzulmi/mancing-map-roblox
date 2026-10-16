// PreToolUse untuk mcp__Roblox_Studio__*: memblokir multi_edit (script hanya diedit lewat file disk)
// dan semua panggilan yang menyebut Workspace.CustomMap (milik pemilik proyek).
import { readFileSync } from "node:fs";

let input = {};
try {
	input = JSON.parse(readFileSync(0, "utf8") || "{}");
} catch {
	process.exit(0);
}
const tool = String(input.tool_name || "");
const payload = JSON.stringify(input.tool_input || {});

if (/multi_edit$/i.test(tool)) {
	process.stderr.write(
		"Diblokir: multi_edit dinonaktifkan di proyek ini. Edit script hanya lewat file .luau di disk " +
			"(Script Sync/Rojo) — lihat AGENTS.md §2.\n",
	);
	process.exit(2);
}
if (/CustomMap/i.test(payload)) {
	process.stderr.write(
		"Diblokir: Workspace.CustomMap milik pemilik proyek dan tidak boleh dibaca-tulis/dihapus/dipindah " +
			"(AGENTS.md §2). Ubah perintah agar tidak menyentuh CustomMap.\n",
	);
	process.exit(2);
}
process.exit(0);
