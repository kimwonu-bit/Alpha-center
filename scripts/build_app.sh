#!/bin/zsh
# Xcode로 앱 + 위젯 확장을 빌드해 build/코치조의 ALPHA 육성 센터.app 을 만든다.
# 사용법: scripts/build_app.sh [Release|Debug]
#   SIGN_IDENTITY="Developer ID Application: ..." 를 주면 그 인증서로 서명한다 (기본: ad-hoc).
set -euo pipefail

CONFIG="${1:-Release}"
ROOT="${0:A:h:h}"
APP_NAME="코치조의 ALPHA 육성 센터"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

cd "$ROOT"
# 빌드 산출물(DerivedData의 Debug/Release 복사본 등)이 Spotlight 검색에 중복으로 뜨지 않게 한다
mkdir -p build && touch build/.metadata_never_index
if command -v xcodegen >/dev/null; then
  xcodegen generate --quiet
fi

SIGN_ARGS=()
if [[ -n "${SIGN_IDENTITY:-}" ]]; then
  SIGN_ARGS=(CODE_SIGN_IDENTITY="$SIGN_IDENTITY")
fi

xcodebuild -project AlphaCenter.xcodeproj -scheme AlphaCenter -configuration "$CONFIG" \
  -derivedDataPath build/DerivedData "${SIGN_ARGS[@]}" build | grep -E "error:|warning: |BUILD" || true

PRODUCT="build/DerivedData/Build/Products/$CONFIG/AlphaCenter.app"
[[ -d "$PRODUCT" ]] || { echo "❌ 빌드 실패"; exit 1; }

# 폴더 이름만 바꿔도 서명은 유지된다
rm -rf "build/$APP_NAME.app"
ditto "$PRODUCT" "build/$APP_NAME.app"
echo "✅ $ROOT/build/$APP_NAME.app"
