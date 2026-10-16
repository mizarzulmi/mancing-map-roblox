// SessionStart: ingatkan aturan sesi & tampilkan ringkasan status dari docs/PROGRESS.md.
import { readFileSync, existsSync } from "node:fs";
import path from "node:path";

const root = process.env.CLAUDE_PROJECT_DIR || process.cwd();
const lines = [
	"Proyek: Pantai Mancing Nusantara (Roblox). Sebelum menulis kode: baca AGENTS.md, docs/GDD.md, docs/PROGRESS.md.",
	"Cek MCP Studio: tool mcp__Roblox_Studio__* (atau `python scripts/studio_mcp.py status`).",
	"Perintah: /sesi-baru /lanjut /autopilot /cek /bake /playtest /review-map /ada-error /balancing /tambah-ikan /model-cantik",
];
const progress = path.join(root, "docs", "PROGRESS.md");
if (existsSync(progress)) {
	const text = readFileSync(progress, "utf8");
	const start = text.indexOf("## Ringkasan status");
	if (start >= 0) {
		const rest = text.slice(start);
		const next = rest.indexOf("\n## ", 5);
		lines.push(rest.slice(0, next > 0 ? next : 1500).trim());
	}
}
process.stdout.write(lines.join("\n") + "\n");
