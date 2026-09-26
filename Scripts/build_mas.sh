#!/usr/bin/env bash
# Mac App Store 包：Apple Distribution 签名 + productbuild 出 .pkg
# 前置：开发者网站创建 "Apple Distribution" 证书（Xcode → Settings → Accounts 可自动生成）
set -euo pipefail
cd "$(dirname "$0")/.."

# 复用常规构建产物
bash Scripts/build_app.sh

TEAM_ID="ALT44F9ZUY"
SIGN_IDENTITY="Apple Distribution"
APP="build/ShortKey.app"
PKG="build/ShortKey-mas.pkg"

echo "==> MAS 沙盒 entitlements 签名..."
codesign --force --sign "$SIGN_IDENTITY" \
  --entitlements Resources/ShortKey.mas.entitlements \
  "$APP"

echo "==> productbuild 打包..."
productbuild --product "$APP/Contents/Info.plist" \
  --package-type application \
  --sign "3rd Party Mac Developer Installer: $TEAM_ID" \
  "$APP" "$PKG" 2>/dev/null || \
productbuild --product "$APP/Contents/Info.plist" \
  --package-type application \
  --sign "Apple Distribution: $(security find-identity -v -p codesigning | grep -o 'Apple Distribution[^"]*' | head -1 | sed 's/Apple Distribution: //')" \
  "$APP" "$PKG"

echo "✅ $PKG — 用 Transporter / altool 上传 App Store Connect"
