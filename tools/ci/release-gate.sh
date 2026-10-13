#!/usr/bin/env bash
# Release gate: a public release must use the real player DataStores, never the live-test
# namespace. Run by .github/workflows/release.yml on `release-*` tags (not on RC tags).
set -euo pipefail
cd "$(dirname "$0")/../.."
line=$(grep -E '^Config\.LiveTestMode = ' src/shared/Config.luau || true)
if [ "$line" != "Config.LiveTestMode = false" ]; then
	echo "RELEASE BLOCKED: src/shared/Config.luau has '$line'. Set Config.LiveTestMode = false for a public release."
	exit 1
fi
if ! grep -qE '^Config\.ProductionPlaceIds = \{ 99653875913460 \}' src/shared/Config.luau; then
	echo "RELEASE BLOCKED: Config.ProductionPlaceIds is not exactly the confirmed live place (99653875913460)."
	exit 1
fi
echo "Release gate passed: real DataStores, confirmed live place."
