#!/bin/zsh
# build/에 만든 앱을 "Applications로 드래그" 형태의 DMG로 묶는다.
set -euo pipefail
ROOT="${0:A:h:h}"
APP_NAME="AlphaCenter"  # 파일 이름은 영문이어야 위젯이 등록된다 (한글 경로는 위젯 시스템이 거부). 표시 이름은 Info.plist의 CFBundleDisplayName
"$ROOT/scripts/build_app.sh" Release
STAGE="$(mktemp -d)"
ditto "$ROOT/build/$APP_NAME.app" "$STAGE/$APP_NAME.app"
ln -s /Applications "$STAGE/Applications"
DMG="$ROOT/build/AlphaCenter.dmg"
rm -f "$DMG"
hdiutil create -volname "코치조의 ALPHA 육성 센터" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
rm -rf "$STAGE"
echo "✅ $DMG"
