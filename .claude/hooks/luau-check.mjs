// PostToolUse untuk Write/Edit: jalankan luau-lsp (strict + definisi Roblox) pada berkas .luau yang diubah.
// Bila ada error, keluar dengan kode 2 agar pesan dikirim balik ke Claude untuk diperbaiki.
import { readFileSync, existsSync, mkdirSync } from "node:fs";
import { spawnSync } from "node:child_process";
import path from "node:path";

let input = {};
try {
	input = JSON.parse(readFileSync(0, "utf8") || "{}");
} catch {
	process.exit(0);
}
const file = String(input.tool_input?.file_path || "");
if (!file.endsWith(".luau")) process.exit(0);
const norm = file.split(path.sep).join("/").split("\\").join("/");
if (/\/(Packages|\.tools|scripts\/lune|\.claude)\//.test(norm)) process.exit(0);

const root = process.env.CLAUDE_PROJECT_DIR || process.cwd();
const bin = path.join(root, ".tools", "bin");
const rojo = path.join(bin, "rojo.exe");
const lsp = path.join(bin, "luau-lsp.exe");
if (!existsSync(rojo) || !existsSync(lsp)) process.exit(0);

mkdirSync(path.join(root, "build"), { recursive: true });
const sourcemap = path.join(root, "build", "sourcemap-hook.json");
spawnSync(rojo, ["sourcemap", "default.project.json", "--output", sourcemap], { cwd: root, timeout: 30000 });
const res = spawnSync(
	lsp,
	[
		"analyze",
		"--platform=roblox",
		`--sourcemap=${sourcemap}`,
		"--definitions=@roblox=.tools/defs/globalTypes.d.luau",
		"--base-luaurc=.luaurc",
		"--ignore=**/Packages/**",
		file,
	],
	{ cwd: root, timeout: 60000, encoding: "utf8" },
);
const out = `${res.stdout || ""}${res.stderr || ""}`
	.split(/\r?\n/)
	.filter((l) => l.trim() && !l.startsWith("[INFO]") && !l.includes("didChangeWatchedFiles"))
	.slice(0, 40)
	.join("\n");
if (res.status && res.status !== 0 && out) {
	process.stderr.write(`luau-lsp menemukan masalah di ${path.basename(file)}:\n${out}\n`);
	process.exit(2);
}
process.exit(0);
