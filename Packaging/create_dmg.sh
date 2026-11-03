#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/TimeText.app"
STAGE="$ROOT/build/dmg-root"
OUT="$ROOT/build/TimeText-1.2.0-arm64.dmg"
python3 - "$STAGE" "$OUT" "$OUT.sha256" <<'PY'
import shutil, sys
from pathlib import Path
for value in sys.argv[1:]:
    path = Path(value)
    if path.is_dir() and not path.is_symlink():
        shutil.rmtree(path)
    elif path.exists() or path.is_symlink():
        path.unlink()
PY
mkdir -p "$STAGE"
ditto "$APP" "$STAGE/TimeText.app"
ln -s /Applications "$STAGE/Программы"
hdiutil create -volname "TimeText" -srcfolder "$STAGE" -ov -format ULFO "$OUT"
hdiutil verify "$OUT"
shasum -a 256 "$OUT" > "$OUT.sha256"
ls -lh "$OUT" "$OUT.sha256"
