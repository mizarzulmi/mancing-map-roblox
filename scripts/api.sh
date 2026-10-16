#!/usr/bin/env bash
# Tampilkan anggota kelas Roblox dari definisi luau-lsp (sumber kebenaran API, bukan tebakan).
# Pakai: bash scripts/api.sh Terrain [pola-grep]
D="$(dirname "$0")/../.tools/defs/globalTypes.d.luau"
awk -v c="$1" '$0 ~ "^declare extern type "c" extends" {p=1} p {print} p && /^end/ {exit}' "$D" | { if [ -n "$2" ]; then grep -E "$2"; else cat; fi; }
