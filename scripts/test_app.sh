#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-/private/tmp/ios-rpg-tool-derived}"
MODULE_CACHE_ROOT="$DERIVED_DATA_PATH/ModuleCaches"
export CLANG_MODULE_CACHE_PATH="$MODULE_CACHE_ROOT/clang"
export SWIFTPM_MODULECACHE_OVERRIDE="$MODULE_CACHE_ROOT/swiftpm"
export SWIFT_MODULE_CACHE_PATH="$MODULE_CACHE_ROOT/swift"

xcodebuild \
  -project "$ROOT_DIR/FoundationLab.xcodeproj" \
  -scheme "Solo RPG Tool" \
  -destination "generic/platform=iOS" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  CODE_SIGNING_ALLOWED=NO \
  build
