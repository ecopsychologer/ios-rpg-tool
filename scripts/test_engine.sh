#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "== TableEngine tests =="
swift test --package-path "$ROOT_DIR/Packages/TableEngine"

echo "== RPGEngine tests =="
swift test --package-path "$ROOT_DIR/Packages/RPGEngine"

echo "== NarratorAgent build =="
swift build --package-path "$ROOT_DIR/Packages/NarratorAgent"

