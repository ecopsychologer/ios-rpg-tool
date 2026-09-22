#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODULE_CACHE_ROOT="${TMPDIR:-/tmp}/solo-rpg-tool-module-cache"
export CLANG_MODULE_CACHE_PATH="$MODULE_CACHE_ROOT/clang"
export SWIFTPM_MODULECACHE_OVERRIDE="$MODULE_CACHE_ROOT/swiftpm"

if [[ -f "$ROOT_DIR/dnd-5e-srd/5esrd.json" ]]; then
  export SOLO_RPG_RULES_JSON="$ROOT_DIR/dnd-5e-srd/5esrd.json"
  export SOLO_RPG_RULES_PREFER_DEV=1
fi

echo "== TableEngine tests =="
swift test --disable-sandbox --package-path "$ROOT_DIR/Packages/TableEngine"

echo "== RPGEngine tests =="
swift test --disable-sandbox --package-path "$ROOT_DIR/Packages/RPGEngine"

echo "== NarratorAgent tests =="
swift test --disable-sandbox --package-path "$ROOT_DIR/Packages/NarratorAgent"
