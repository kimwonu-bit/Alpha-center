#!/bin/zsh
# build/에 만든 앱을 "Applications로 드래그" 형태의 DMG로 묶는다.
set -euo pipefail
ROOT="${0:A:h:h}"
APP_NAME="코치조의 ALPHA 육성 센터"
"$ROOT/scripts/build_app.sh" Release
STAGE="$(mktemp -d)"
ditto "$ROOT/build/$APP_NAME.app" "$STAGE/$APP_NAME.app"
ln -s /Applications "$STAGE/Applications"
DMG="$ROOT/build/AlphaCenter.dmg"
rm -f "$DMG"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
rm -rf "$STAGE"
echo "✅ $DMG"
