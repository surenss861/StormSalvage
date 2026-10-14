#!/usr/bin/env bash
# Static checks for Storm Salvage: formatting, lint, types, and a Rojo build.
# Local: run from the repo root; uses .tools/bin if present (see tools/ci/README), else PATH.
# CI:    .github/workflows/ci.yml puts the pinned tools on PATH first.
set -euo pipefail
cd "$(dirname "$0")/../.."
if [ -d .tools/bin ]; then export PATH="$PWD/.tools/bin:$PATH"; fi
DEFS=".tools/globalTypes.d.luau"
if [ ! -f "$DEFS" ]; then
	mkdir -p .tools
	curl -sSL -o "$DEFS" https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau
fi
echo "== stylua";   stylua --check src
echo "== selene";   selene src
echo "== sourcemap"; rojo sourcemap default.project.json -o .tools/sourcemap.json
echo "== luau-lsp"
out=$(luau-lsp analyze --sourcemap=.tools/sourcemap.json --definitions="$DEFS" --no-strict-dm-types src 2>&1 | grep -v "^\[INFO\]\|^\[WARN\]" || true)
if [ -n "$out" ]; then echo "$out"; exit 1; fi
echo "== rojo build"; rojo build default.project.json -o .tools/build.rbxl
echo "== asset pivots"; lune run tools/assets/pivots check .tools/build.rbxl
echo "== world manifest"; lune run tools/assets/manifest .tools/build.rbxl
echo "== unit tests"; lune run tests/run
echo "All checks passed."
