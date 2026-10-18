#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export DEVELOPER_DIR="${DEVELOPER_DIR:-$(xcode-select -p)}"
SOURCE="$ROOT/vendor-cache/mlx-serve"
OUTPUT_APP="$ROOT/build/Nightwave Radio.app"
mkdir -p "$ROOT/build"
STAGE=$(mktemp -d "$ROOT/build/staging.XXXXXX")
APP="$STAGE/Nightwave Radio.app"
bash scripts/prepare-backend.sh
bash scripts/prepare-portable-runtime.sh
swift build -c release
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/Licenses" "$APP/Contents/Frameworks" build/AppIcon.iconset
BIN="$(swift build -c release --show-bin-path)"
cp "$BIN/NightwaveRadio" "$APP/Contents/MacOS/NightwaveRadio"
cp "$ROOT/vendor-cache/portable-backend/bin/mlx-serve" "$APP/Contents/MacOS/"
# Convert build-machine install names to self-contained bundle paths.
python3 scripts/fix-backend-paths.py "$APP/Contents/MacOS/mlx-serve"
for file in libmlx.dylib libmlxc.dylib libjaccl.dylib mlx.metallib; do
  cp "$SOURCE/lib/mlx/lib/$file" "$APP/Contents/Frameworks/"
done
cp "$SOURCE/lib/llama/lib/libllama.dylib" "$APP/Contents/Frameworks/"
python3 scripts/fix-framework-paths.py "$APP/Contents/Frameworks"
# Replace Homebrew dylibs, whose deployment target follows the build machine.
cp "$ROOT/vendor-cache/webp-build/libwebp.dylib" "$APP/Contents/Frameworks/libwebp.dylib"
cp "$ROOT/vendor-cache/webp-build/libsharpyuv.dylib" "$APP/Contents/Frameworks/libsharpyuv.dylib"
install_name_tool -id '@rpath/libwebp.dylib' "$APP/Contents/Frameworks/libwebp.dylib"
install_name_tool -id '@rpath/libsharpyuv.dylib' "$APP/Contents/Frameworks/libsharpyuv.dylib"
WEBP_DEP="$(otool -L "$APP/Contents/Frameworks/libwebp.dylib" | awk '/libsharpyuv/ {print $1}')"
install_name_tool -change "$WEBP_DEP" '@loader_path/libsharpyuv.dylib' "$APP/Contents/Frameworks/libwebp.dylib"
ditto "$ROOT/vendor-cache/python" "$APP/Contents/Resources/python"
# -I ignores environment variables, so pass -B explicitly to keep runtime
# bytecode from changing the signed application bundle on its first use.
cat > "$APP/Contents/Resources/instrumental-python" <<'PYTHON_WRAPPER'
#!/bin/sh
exec "${0%/*}/python/bin/python3" -B "$@"
PYTHON_WRAPPER
chmod +x "$APP/Contents/Resources/instrumental-python"
cp "$ROOT/vendor-cache/python/lib/python3.12/LICENSE.txt" "$APP/Contents/Resources/Licenses/Python-LICENSE.txt"
cp "$ROOT/vendor-cache/libwebp-1.6.0/COPYING" "$APP/Contents/Resources/Licenses/WebP-COPYING"
cp "$ROOT/vendor-cache/ar_lora_inst_v3abc.bf16.safetensors" "$APP/Contents/Resources/"
for file in LICENSE LICENSE-APACHE-2.0 NOTICE; do
  cp "$SOURCE/$file" "$APP/Contents/Resources/Licenses/MLX-Serve-$file"
done
cp "$ROOT/LICENSE" "$APP/Contents/Resources/Licenses/Nightwave-Radio-LICENSE"
cp "$SOURCE/src/yue2_instrumental/LICENSE" "$APP/Contents/Resources/Licenses/YuE-Skill-LICENSE"
cp "$SOURCE/src/yue2_instrumental/PROVENANCE.txt" "$APP/Contents/Resources/Licenses/YuE-Skill-PROVENANCE.txt"
curl -fL --retry 2 -o "$APP/Contents/Resources/Licenses/LoRA-CC-BY-NC-4.0.txt" https://creativecommons.org/licenses/by-nc/4.0/legalcode.txt
cp -R "$ROOT/Licenses/." "$APP/Contents/Resources/Licenses/"
cp "$ROOT/THIRD_PARTY_NOTICES.md" "$APP/Contents/Resources/Licenses/"
swift scripts/Icon.swift "$ROOT/build/AppIcon.png"
for pixels in 16 32 128 256 512; do
  sips -z "$pixels" "$pixels" build/AppIcon.png --out "build/AppIcon.iconset/icon_${pixels}x${pixels}.png" >/dev/null
  double=$((pixels * 2))
  sips -z "$double" "$double" build/AppIcon.png --out "build/AppIcon.iconset/icon_${pixels}x${pixels}@2x.png" >/dev/null
done
iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleDevelopmentRegion</key><string>en</string>
<key>CFBundleLocalizations</key><array><string>en</string></array>
<key>CFBundleIdentifier</key><string>local.nightwave.radio</string>
<key>CFBundleName</key><string>Nightwave Radio</string>
<key>CFBundleDisplayName</key><string>Nightwave Radio</string>
<key>CFBundleExecutable</key><string>NightwaveRadio</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.3.1</string>
<key>CFBundleVersion</key><string>10</string>
<key>LSMinimumSystemVersion</key><string>26.2</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSAppTransportSecurity</key><dict><key>NSAllowsLocalNetworking</key><true/></dict>
<key>NSHumanReadableCopyright</key><string>Nightwave Radio. Includes MLX-Serve, YuE2 and Mothersuperior instrumental AR LoRA.</string>
</dict></plist>
PLIST
xattr -cr "$APP"
# Python binaries/extensions are nested code too; sign every actual Mach-O.
while IFS= read -r -d '' file; do
  if file -b "$file" | grep -q 'Mach-O'; then codesign --force --sign - "$file"; fi
done < <(find "$APP/Contents/Resources/python" -type f -print0)
for file in "$APP"/Contents/Frameworks/*.metallib "$APP"/Contents/Frameworks/*.dylib "$APP"/Contents/MacOS/*; do codesign --force --sign - "$file"; done
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
python3 scripts/audit-bundle.py "$APP" > "$ROOT/build/bundle-audit.json"
if [ -d "$OUTPUT_APP" ]; then mv "$OUTPUT_APP" "$ROOT/build/previous-app-$(date +%s)-$RANDOM.app"; fi
mv "$APP" "$OUTPUT_APP"
rmdir "$STAGE"
echo "READY: $OUTPUT_APP"
