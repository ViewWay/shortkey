#!/usr/bin/env bash
# 构建 ShortKey.app bundle
# 用法: Scripts/build_app.sh [release|debug]
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
swift build -c "$CONFIG"

BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"
APP_DIR="build/ShortKey.app"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
cp Resources/Info.plist "$APP_DIR/Contents/Info.plist"
mkdir -p "$APP_DIR/Contents/Resources"
[ -f Resources/AppIcon.icns ] && cp Resources/AppIcon.icns "$APP_DIR/Contents/Resources/"
cp "$BIN_DIR/ShortKey" "$APP_DIR/Contents/MacOS/ShortKey"

# 优先使用稳定签名身份（Developer ID / Apple Development）：
# 签名稳定 → 辅助功能授权跨构建永久有效，不必每次重新授权
SIGN_LINE="$(security find-identity -v -p codesigning 2>/dev/null | grep -E '"(Developer ID Application|Apple Development)' | head -1)"
if [ -n "$SIGN_LINE" ]; then
  SIGN_IDENTITY="${SIGN_LINE#*\"}"
  SIGN_IDENTITY="${SIGN_IDENTITY%\"}"
  codesign --force --sign "$SIGN_IDENTITY" "$APP_DIR"
  echo "   签名身份: ${SIGN_IDENTITY}（授权跨构建有效）"
else
  codesign --force --sign - "$APP_DIR"
  echo "   签名身份: ad-hoc（重建后需重新授权辅助功能）"
fi

echo "✅ 已生成 $APP_DIR"
echo "   运行: open $APP_DIR"
echo "   首次使用请在 系统设置 → 隐私与安全性 → 辅助功能 中授权 ShortKey"
