#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
APP="$ROOT/build/Nightwave Radio.app"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")
RELEASE="$ROOT/release/$VERSION"
STAGE="$ROOT/build/installer-$VERSION"
mkdir -p "$STAGE" "$RELEASE"
codesign --verify --deep --strict "$APP"
python3 scripts/audit-bundle.py "$APP" > "$RELEASE/bundle-audit.json"
ditto "$APP" "$STAGE/Nightwave Radio.app"
cp INSTALL-FRIEND.txt "$STAGE/Installation.txt"
if [ ! -L "$STAGE/Applications" ]; then ln -s /Applications "$STAGE/Applications"; fi
hdiutil create -ov -fs HFS+ -volname 'Nightwave Radio' -srcfolder "$STAGE" -format UDZO -imagekey zlib-level=9 "$RELEASE/Nightwave-Radio-$VERSION-Apple-Silicon.dmg"
hdiutil verify "$RELEASE/Nightwave-Radio-$VERSION-Apple-Silicon.dmg"
cp INSTALL-FRIEND.txt "$RELEASE/Installation.txt"
(cd "$RELEASE" && shasum -a 256 "Nightwave-Radio-$VERSION-Apple-Silicon.dmg" > SHA256SUMS.txt)
echo "RELEASE: $RELEASE"
