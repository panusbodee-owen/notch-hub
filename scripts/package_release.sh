#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

"$ROOT_DIR/scripts/build_app.sh"

APP_DIR="$ROOT_DIR/dist/NotchHub.app"
ZIP_OUT="$ROOT_DIR/dist/NotchHub-macOS-arm64.zip"
DMG_OUT="$ROOT_DIR/dist/NotchHub-macOS-arm64.dmg"
DMG_STAGE="$ROOT_DIR/dist/dmg_stage"

rm -f "$ZIP_OUT" "$DMG_OUT"
rm -rf "$DMG_STAGE"

echo "Creating ZIP archive..."
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ZIP_OUT"

echo "Creating DMG installer..."
mkdir -p "$DMG_STAGE"
cp -R "$APP_DIR" "$DMG_STAGE/NotchHub.app"
ln -s /Applications "$DMG_STAGE/Applications"

hdiutil create \
  -volname "NotchHub" \
  -srcfolder "$DMG_STAGE" \
  -ov \
  -format UDZO \
  "$DMG_OUT" >/dev/null

rm -rf "$DMG_STAGE"

ls -lh "$ZIP_OUT" "$DMG_OUT"
echo "Release artifacts ready!"
