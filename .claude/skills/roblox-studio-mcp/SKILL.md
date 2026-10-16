---
name: roblox-studio-mcp
description: >
  Cara memakai MCP bawaan Roblox Studio (server "Roblox_Studio") untuk proyek ini: cek koneksi, bake map dari
  clone folder World, screenshot 6 sudut kamera (udara, pasar, dermaga, laguna, mercusuar, Laut Dalam),
  playtest + baca Output server/client, navigasi karakter & input, pencarian audio, serta guardrail
  (CustomMap, multi_edit, insert_asset). Termasuk jembatan scripts/studio_mcp.py bila tool MCP native tidak
  tersedia. Pakai untuk verifikasi fase, review visual map, dan reproduksi error.
---

# MCP Roblox Studio

## Koneksi
- Studio: Assistant → ⋯ → Manage MCP Servers → **Enable Studio as MCP server** (Studio harus terbuka).
- Claude Code: server `Roblox_Studio` terdaftar di **cakupan user** (`claude mcp add --scope user Roblox_Studio --
  cmd.exe /c "%LOCALAPPDATA%\Roblox\mcp.bat"`). Entri `.mcp.json` proyek berstatus "⏸ Pending approval" bila
  dialog persetujuan belum pernah muncul — `enabledMcpjsonServers` di `.claude/settings*.json` tidak cukup
  (terverifikasi Claude Code 2.1.273). Cek: `claude mcp get Roblox_Studio`. Server dimuat saat sesi dimulai:
  setelah mengubah konfigurasi, buka percakapan baru agar tool `mcp__Roblox_Studio__*` muncul.
- "Connected · tools fetch failed / Request timed out" = proxy jalan, Studio tertutup atau sakelar MCP mati.
- Kode masuk Studio lewat Rojo (`.tools\bin\rojo.exe serve default.project.json` + Plugins → Rojo → Connect);
  bake memakai modul World yang sudah tersinkron.
- Tanpa tool native: `python scripts/studio_mcp.py status|tools|call|luau` (memanggil proxy yang sama).
- Setiap call menerima `studio_id` opsional; pakai `list_roblox_studios` bila beberapa jendela terbuka.

## Tool (nama dari dokumentasi Roblox; cek skema persis dengan `tools`)
| Langkah | Tool |
|---|---|
| status | `list_roblox_studios`, `get_studio_state` |
| inspeksi | `search_game_tree`, `inspect_instance`, `script_search`, `script_grep`, `script_read` |
| eksekusi | `execute_luau` (`datamodel_type`: `Edit` / `Server` / `Client`) |
| playtest | `start_stop_play`, `get_console_output`, `screen_capture`, `character_navigation`, `user_keyboard_input`, `user_mouse_input` |
| aset | `search_asset` (audio terverifikasi → `Config/Sounds.luau`), `insert_asset`, `generate_mesh` (**izin pemilik dulu**) |

## Guardrail (wajib)
- **Jangan** sentuh `Workspace.CustomMap` (baca/tulis/hapus). Hook `.claude/hooks/guard-studio.mjs` memblokir.
- **Jangan** `multi_edit` script — sumber kebenaran = file disk (Script Sync/Rojo).
- `insert_asset`/`generate_mesh`: hanya setelah pemilik setuju; hapus semua Script/LocalScript/ModuleScript di
  aset; simpan versi primitif sebagai cadangan (mis. `Workspace.BeachMap.Backup_<Nama>` atau ServerStorage).

## Bake map
`execute_luau` (Edit) dengan isi `scripts/bake-command.luau` (clone folder World → require MapBuilder dari clone →
`Bake()` → destroy clone). Bridge: `python scripts/studio_mcp.py luau scripts/bake-command.luau --dm Edit`.

## Screenshot 6 sudut (Edit mode)
Atur kamera lalu `screen_capture`:
```lua
local views = {
	udara      = CFrame.lookAt(Vector3.new(-260, 260, 520), Vector3.new(20, 0, 60)),
	pasar      = CFrame.lookAt(Vector3.new(0, 22, -75), Vector3.new(0, 6, -5)),
	dermaga    = CFrame.lookAt(Vector3.new(40, 18, 85), Vector3.new(95, 4, 225)),
	laguna     = CFrame.lookAt(Vector3.new(-140, 32, -40), Vector3.new(-250, 0, 40)),
	mercusuar  = CFrame.lookAt(Vector3.new(150, 30, 105), Vector3.new(220, 30, 180)),
	lautdalam  = CFrame.lookAt(Vector3.new(-30, 40, 715), Vector3.new(60, 4, 820)),
}
workspace.CurrentCamera.CFrame = views.udara  -- ganti per sudut, satu execute_luau per sudut
```
Simpan ke `build/captures/<fase>-<sudut>.png` (bridge: `--out`). Bandingkan sebelum–sesudah dari sudut yang sama.

## Playtest
1. `start_stop_play` (mulai) → tunggu ±8 dtk (map dibangun bila belum di-bake).
2. `get_console_output` → harus 0 error & 0 warning dari skrip kita (pengecualian: warn mode mock DataService).
   Cari juga `[SELFTEST] LULUS x/y`.
3. Alur: `character_navigation` ke NPC (Pak Darto (−30,6,−15)) → `user_keyboard_input` E → klik Beli Cacing →
   ke pantai (0,5,110) → tahan klik (`user_mouse_input`) → minigame → popup → jual di Bu Rina (75,5,95).
4. `screen_capture` di tiap langkah penting; `start_stop_play` (berhenti).
5. Tulis hasil + tingkat bukti di `docs/PROGRESS.md`.

## Uji yang tidak bisa otomatis
Trade dua pemain (Test → Clients and Servers, 2 pemain), perangkat sentuh (Device Emulator), gamepad (Controller
Emulator) → langkah manual di `docs/TESTING.md`.
