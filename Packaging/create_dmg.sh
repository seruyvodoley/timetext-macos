#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/ТаймТекст.app"
STAGE="$ROOT/build/dmg-root"
OUT="$ROOT/build/ТаймТекст-1.0.0-arm64.dmg"
rm -rf "$STAGE" "$OUT"
mkdir -p "$STAGE"
ditto "$APP" "$STAGE/ТаймТекст.app"
ln -s /Applications "$STAGE/Программы"
hdiutil create -volname "ТаймТекст" -srcfolder "$STAGE" -ov -format UDZO -imagekey zlib-level=9 "$OUT"
hdiutil verify "$OUT"
shasum -a 256 "$OUT" > "$OUT.sha256"
ls -lh "$OUT" "$OUT.sha256"
