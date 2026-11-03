#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/TimeText.app"
STAGE="$ROOT/build/dmg-root"
OUT="$ROOT/build/TimeText-1.2.0-arm64.dmg"
rm -rf "$STAGE" "$OUT"
mkdir -p "$STAGE"
ditto "$APP" "$STAGE/TimeText.app"
ln -s /Applications "$STAGE/Программы"
hdiutil create -volname "TimeText" -srcfolder "$STAGE" -ov -format UDZO -imagekey zlib-level=9 "$OUT"
hdiutil verify "$OUT"
shasum -a 256 "$OUT" > "$OUT.sha256"
ls -lh "$OUT" "$OUT.sha256"
