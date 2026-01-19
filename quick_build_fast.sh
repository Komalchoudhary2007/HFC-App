#!/usr/bin/env bash
# Fast APK build (no SDK/bootstrap, no server)
# Usage: bash quick_build_fast.sh
# Produces split-per-ABI, tree-shaken, symbol-split release APKs

set -euo pipefail

PROJECT_DIR="/workspaces/HFC-App"
FLUTTER_BIN="${FLUTTER_BIN:-$(command -v flutter || true)}"
DEFAULT_FLUTTER="/tmp/flutter/bin/flutter"

if [[ -z "$FLUTTER_BIN" ]]; then
  if [[ -x "$DEFAULT_FLUTTER" ]]; then
    FLUTTER_BIN="$DEFAULT_FLUTTER"
  else
    echo "[fast-build] Flutter not found. Please install or set FLUTTER_BIN." >&2
    exit 1
  fi
fi

cd "$PROJECT_DIR"

echo "[fast-build] Using flutter at: $FLUTTER_BIN"

echo "[fast-build] Fetching dependencies (cached if already done)..."
"$FLUTTER_BIN" pub get

echo "[fast-build] Cleaning minimal (no android/gradle daemon stop)..."
"$FLUTTER_BIN" clean --verbose >/dev/null 2>&1 || true

# Output paths
SYM_DIR="build/symbols"
APK_OUT="build/app/outputs/flutter-apk"
mkdir -p "$SYM_DIR"

# Build flags for smaller APKs
# - split-per-abi: separate APKs per ABI (smaller download)
# - tree-shake-icons: remove unused icons
# - split-debug-info: generate symbols (keeps APK smaller, symbols in SYM_DIR)
# - target-platform: limit to arm/arm64 to reduce size (add x86 if you need emulators)

BUILD_CMD=(
  "$FLUTTER_BIN" build apk --release
  --split-per-abi
  --tree-shake-icons
  --split-debug-info="$SYM_DIR"
  --target-platform=android-arm,android-arm64
)

echo "[fast-build] Building release APKs..."
"${BUILD_CMD[@]}"

# Show resulting files
if ls "$APK_OUT"/*.apk >/dev/null 2>&1; then
  echo "[fast-build] Build artifacts:"
  ls -lh "$APK_OUT"/*.apk
else
  echo "[fast-build] No APKs found in $APK_OUT" >&2
  exit 1
fi

echo "[fast-build] Done. Use the per-ABI APKs above."
