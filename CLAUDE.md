# CLAUDE.md — Pantai Mancing Nusantara

@AGENTS.md

## Alur Claude Code di repo ini

- **Awal sesi:** baca AGENTS.md (dimuat otomatis di atas), `docs/GDD.md`, `docs/PROGRESS.md`; cek MCP Studio
  (`mcp__Roblox_Studio__list_roblox_studios`, atau `python scripts/studio_mcp.py status`). Pakai `/sesi-baru`.
- **Perintah proyek** (`.claude/commands/`): `/sesi-baru`, `/lanjut`, `/autopilot`, `/cek`, `/bake`, `/playtest`,
  `/review-map`, `/ada-error <output>`, `/balancing`, `/tambah-ikan <Zona>`, `/model-cantik`.
- **Skill proyek** (`.claude/skills/`): `roblox-game` (router & sharp edges), `pantai-mancing` (peta modul,
  kontrak, jebakan Luau strict), `roblox-procedural-3d` (map/model tidak kotak-kotak), `roblox-studio-mcp`
  (bake, 6 sudut kamera, playtest), plus skill Apache-2.0: `roblox-ui`, `roblox-luau`, `roblox-networking`,
  `roblox-datastores`, `roblox-studio-workflow`, `roblox-characters`, `roblox-physics`.
- **Sub-agen** (`.claude/agents/`): `level-designer` (review screenshot map), `luau-reviewer` (review kode vs
  AGENTS.md), `balance-analyst` (BalanceSim + usulan angka, tidak menerapkan).
- **UI / tampilan:** aturan global pemilik — WAJIB memuat skill `ui-ux-pro-max`, `impeccable`, dan
  `taste-design` sebelum perubahan visual (UI dalam game maupun tampilan map), lalu ikuti `docs/UI-DIRECTION.md`.
- **Hook** (`.claude/settings.json`): memblokir `multi_edit` dan semua panggilan MCP yang menyebut
  `CustomMap`; menjalankan luau-lsp pada setiap `.luau` yang diedit; mengingatkan pembersihan script setelah
  `insert_asset`/`generate_mesh`.
- **Bukti:** pisahkan "Dieksekusi di Studio" vs "Dicek statis" vs "Disiapkan, belum dijalankan".
  Jangan commit `.tools/` atau `build/`.
