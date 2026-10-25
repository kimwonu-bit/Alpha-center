#!/bin/zsh
# 빌드한 앱을 /Applications에 설치하고 위젯 확장을 등록한 뒤 실행한다.
# 위젯은 앱이 응용 프로그램 폴더에 있어야 위젯 갤러리에 안정적으로 나타난다.
set -euo pipefail
ROOT="${0:A:h:h}"
APP_NAME="코치조의 ALPHA 육성 센터"
DEST="/Applications/$APP_NAME.app"

"$ROOT/scripts/build_app.sh" "${1:-Release}"
osascript -e 'quit app id "kr.hs.bssm.alphacenter"' 2>/dev/null || true
sleep 1
rm -rf "$DEST"
ditto "$ROOT/build/$APP_NAME.app" "$DEST"
pluginkit -a "$DEST/Contents/PlugIns/AlphaWidgets.appex" || true
# 설치본만 Spotlight에 남도록 빌드 복사본 삭제
rm -rf "$ROOT/build/$APP_NAME.app" "$ROOT/build/DerivedData/Build/Products"
open "$DEST"
echo "✅ 설치됨: $DEST"
echo "   위젯 추가: 바탕화면 우클릭 → 위젯 편집 → '코치조의 ALPHA 육성 센터'"
