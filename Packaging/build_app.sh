#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/ТаймТекст.app"
CONT="$APP/Contents"
MODEL="$ROOT/ThirdParty/ggml-large-v3-turbo-q5_0.bin"
GIGAAM_MODEL="$ROOT/ThirdParty/v3_e2e_rnnt.ckpt"
GIGAAM_TOKENIZER="$ROOT/ThirdParty/v3_e2e_rnnt_tokenizer.model"
GIGAAM_COMMIT="7447938d791c4f3e643386ee22c33777004293a5"
GIGAAM_RUNTIME="$ROOT/build/gigaam-dist/gigaam-transcribe"

if ! command -v python3.12 >/dev/null 2>&1; then
  echo "Для сборки GigaAM нужен Python 3.12 (brew install python@3.12)" >&2
  exit 1
fi

if [ ! -f "$GIGAAM_MODEL" ]; then
  curl -L --fail --retry 3 -o "$GIGAAM_MODEL" https://cdn.chatwm.opensmodel.sberdevices.ru/GigaAM/v3_e2e_rnnt.ckpt
fi
if [ ! -f "$GIGAAM_TOKENIZER" ]; then
  curl -L --fail --retry 3 -o "$GIGAAM_TOKENIZER" https://cdn.chatwm.opensmodel.sberdevices.ru/GigaAM/v3_e2e_rnnt_tokenizer.model
fi
test "$(md5 -q "$GIGAAM_MODEL")" = "2730de7545ac43ad256485a462b0a27a"
test "$(md5 -q "$GIGAAM_TOKENIZER")" = "3b3bf8370e882885d79731592fc99f98"

VENV="$ROOT/build/gigaam-venv"
if [ ! -x "$VENV/bin/pyinstaller" ]; then
  python3.12 -m venv "$VENV"
  "$VENV/bin/pip" install --upgrade pip
  "$VENV/bin/pip" install "git+https://github.com/salute-developers/GigaAM.git@$GIGAAM_COMMIT" pyinstaller
fi
if [ ! -x "$GIGAAM_RUNTIME/gigaam-transcribe" ] || [ "$ROOT/Packaging/gigaam_transcribe.py" -nt "$GIGAAM_RUNTIME/gigaam-transcribe" ]; then
  rm -rf "$ROOT/build/gigaam-dist" "$ROOT/build/gigaam-pyinstaller"
  "$VENV/bin/pyinstaller" --clean --noconfirm --onedir \
    --name gigaam-transcribe \
    --distpath "$ROOT/build/gigaam-dist" \
    --workpath "$ROOT/build/gigaam-pyinstaller" \
    --collect-all gigaam --collect-all torch --collect-all torchaudio \
    --collect-all hydra --collect-all omegaconf --collect-all sentencepiece \
    "$ROOT/Packaging/gigaam_transcribe.py"
fi

if [ ! -f "$MODEL" ]; then
  curl -L --fail --retry 3 -o "$MODEL" https://huggingface.co/adidsh/whisper.cpp/resolve/main/ggml-large-v3-turbo-q5_0.bin
fi
echo "394221709cd5ad1f40c46e6031ca61bce88931e6e088c188294c6d5a55ffa7e2  $MODEL" | shasum -a 256 -c -
rm -rf "$APP"
mkdir -p "$CONT/MacOS" "$CONT/Resources/bin" "$CONT/Resources/Frameworks" "$CONT/Resources/GigaAM" "$CONT/Resources/GigaAMRuntime"
cp /opt/homebrew/bin/ffmpeg "$CONT/Resources/bin/ffmpeg"
cp /opt/homebrew/bin/whisper-cli "$CONT/Resources/bin/whisper-cli"
cp "$ROOT/ThirdParty/ggml-large-v3-turbo-q5_0.bin" "$CONT/Resources/ggml-large-v3-turbo-q5_0.bin"
cp "$GIGAAM_MODEL" "$CONT/Resources/GigaAM/v3_e2e_rnnt.ckpt"
cp "$GIGAAM_TOKENIZER" "$CONT/Resources/GigaAM/v3_e2e_rnnt_tokenizer.model"
ditto "$GIGAAM_RUNTIME" "$CONT/Resources/GigaAMRuntime"
mkdir -p "$CONT/Resources/Licenses"
cp /opt/homebrew/Cellar/ffmpeg/9.0.2_1/COPYING.LGPLv2.1 "$CONT/Resources/Licenses/FFmpeg-LGPLv2.1.txt"
cp /opt/homebrew/Cellar/ffmpeg/9.0.2_1/COPYING.GPLv2 "$CONT/Resources/Licenses/FFmpeg-GPLv2.txt"
cp /opt/homebrew/Cellar/ffmpeg/9.0.2_1/LICENSE.md "$CONT/Resources/Licenses/FFmpeg-LICENSE.md"
cp /opt/homebrew/Cellar/whisper.cpp/1.9.5/LICENSE "$CONT/Resources/Licenses/whisper.cpp-MIT.txt"
cp /opt/homebrew/Cellar/ggml/0.26.0/LICENSE "$CONT/Resources/Licenses/ggml-MIT.txt"
cp "$ROOT/LICENSE" "$CONT/Resources/Licenses/ТаймТекст-MIT.txt"
curl -L --fail --retry 3 -o "$CONT/Resources/Licenses/GigaAM-MIT.txt" https://raw.githubusercontent.com/salute-developers/GigaAM/$GIGAAM_COMMIT/LICENSE
TORCH_LICENSES="$(find "$VENV/lib/python3.12/site-packages" -maxdepth 2 -type d -path '*/torch-*.dist-info/licenses' -print -quit)"
TORCHAUDIO_LICENSES="$(find "$VENV/lib/python3.12/site-packages" -maxdepth 2 -type d -path '*/torchaudio-*.dist-info/licenses' -print -quit)"
ditto "$TORCH_LICENSES" "$CONT/Resources/Licenses/PyTorch"
ditto "$TORCHAUDIO_LICENSES" "$CONT/Resources/Licenses/TorchAudio"
cat > "$CONT/Resources/Licenses/ThirdPartyNotices.txt" <<'NOTICE'
ТаймТекст включает FFmpeg 9.0.2_1, whisper.cpp 1.9.5, ggml 0.26.0, PyTorch и GigaAM-v3 e2e-RNNT от SberDevices.
Исходный код FFmpeg: https://ffmpeg.org/download.html
Исходный код whisper.cpp: https://github.com/ggml-org/whisper.cpp
Исходный код ggml: https://github.com/ggml-org/ggml
Исходный код и модель GigaAM: https://github.com/salute-developers/GigaAM
Проверенная ревизия GigaAM: https://github.com/salute-developers/GigaAM/tree/7447938d791c4f3e643386ee22c33777004293a5
Модель GigaAM-v3 e2e-RNNT: https://cdn.chatwm.opensmodel.sberdevices.ru/GigaAM/v3_e2e_rnnt.ckpt
Модель Whisper large-v3-turbo-q5_0: https://huggingface.co/ggerganov/whisper.cpp
Некоторые компоненты FFmpeg сборки Homebrew распространяются по GPLv2; другие по LGPLv2.1 или своим лицензиям.
Тексты лицензий FFmpeg и Whisper/ggml находятся в этой папке.
NOTICE

python3 - "$CONT" <<'PY'
import os, re, shutil, subprocess, sys
from pathlib import Path
contents = Path(sys.argv[1])
fw = contents / "Resources/Frameworks"
todo = [contents / "Resources/bin/ffmpeg", contents / "Resources/bin/whisper-cli"]
seen = set()

def out(*args):
    return subprocess.check_output(args, text=True, stderr=subprocess.DEVNULL)

def rpaths(binary):
    text = out("otool", "-l", str(binary))
    return re.findall(r"\s+path (.+?) \(offset", text)

def deps(binary):
    lines = out("otool", "-L", str(binary)).splitlines()[1:]
    values=[]
    for line in lines:
        name=line.strip().split(" (compatibility")[0]
        if name.startswith("/opt/homebrew/"):
            values.append(name)
        elif name.startswith("@rpath/"):
            depname = name.split("/",1)[1]
            if depname in seen or (fw / depname).exists():
                continue
            found = False
            for rp in rpaths(binary):
                base = str(binary.parent / rp[13:]) if rp.startswith("@loader_path/") else rp
                candidate = Path(base) / depname
                if candidate.exists():
                    values.append(str(candidate)); found = True; break
            if not found:
                matches = list(Path("/opt/homebrew/Cellar").glob(f"*/**/lib/{depname}"))
                matches += list(Path("/opt/homebrew/opt").glob(f"*/lib/{depname}"))
                if matches:
                    values.append(str(matches[0]))
    return values

while todo:
    current = todo.pop()
    for original in deps(current):
        source = Path(original).resolve()
        if not source.exists():
            raise RuntimeError(f"Missing dynamic library: {original}")
        name = Path(original).name
        target = fw / name
        if name not in seen:
            shutil.copy2(source, target)
            seen.add(name)
            todo.append(target)

for binary in [contents / "Resources/bin/ffmpeg", contents / "Resources/bin/whisper-cli", *[fw / n for n in sorted(seen)]]:
    for original in deps(binary):
        name = Path(original).name
        replacement = "@rpath/" + name
        if original != replacement:
            subprocess.run(["install_name_tool", "-change", original, replacement, str(binary)], check=True)
    if binary.parent == fw:
        subprocess.run(["install_name_tool", "-id", "@rpath/" + binary.name, str(binary)], check=True)
    subprocess.run(["install_name_tool", "-add_rpath", "@loader_path/../Frameworks", str(binary)], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    subprocess.run(["install_name_tool", "-add_rpath", "@loader_path", str(binary)], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
PY

cat > "$CONT/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>TimeText</string>
<key>CFBundleIdentifier</key><string>ru.seruyvodoley.timetext</string>
<key>CFBundleName</key><string>ТаймТекст</string>
<key>CFBundleDisplayName</key><string>ТаймТекст</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.1.0</string>
<key>CFBundleVersion</key><string>2</string>
<key>LSMinimumSystemVersion</key><string>27.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>NSAppleEventsUsageDescription</key><string></string>
<key>NSHumanReadableCopyright</key><string>2026 · ТаймТекст</string>
</dict></plist>
PLIST
printf 'APPL????' > "$CONT/PkgInfo"
swiftc -parse-as-library -O -target arm64-apple-macosx27.0 "$ROOT/Sources/TimeTextApp.swift" -o "$CONT/MacOS/TimeText" -framework SwiftUI -framework AppKit -framework UniformTypeIdentifiers
chmod +x "$CONT/Resources/bin/ffmpeg" "$CONT/Resources/bin/whisper-cli" "$CONT/MacOS/TimeText"
find "$CONT/Resources/bin" "$CONT/Resources/Frameworks" "$CONT/Resources/GigaAMRuntime" -type f \( -name '*.dylib' -o -name '*.so' -o -perm -111 \) -print0 | while IFS= read -r -d '' ITEM; do
  codesign --force --sign - "$ITEM"
done
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
echo "$APP"
