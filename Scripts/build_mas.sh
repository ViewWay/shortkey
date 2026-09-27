#!/usr/bin/env bash
# Mac App Store 包：Apple Distribution 签 App + Mac Installer 证书签 pkg
# 前置证书（Xcode → Settings → Accounts → Manage Certificates → ＋ 可创建）：
#   1. Apple Distribution                          （签 App）
#   2. 3rd Party Mac Developer Installer           （签 .pkg）
set -euo pipefail
cd "$(dirname "$0")/.."

bash Scripts/build_app.sh

APP="build/ShortKey.app"
PKG="build/ShortKey-mas.pkg"

# 证书预检：缺什么直接说清楚
APP_CERT="$(security find-identity -v -p codesigning 2>/dev/null | grep -m1 'Apple Distribution' | sed 's/.*"\(.*\)"/\1/' || true)"
# 注意：Installer 证书用于签 .pkg，不出现在 codesigning 策略里，需不带 -p 查询
PKG_CERT="$(security find-identity 2>/dev/null | grep -m1 '3rd Party Mac Developer Installer' | sed 's/.*"\(.*\)"/\1/' || true)"

MISSING=()
[ -z "$APP_CERT" ] && MISSING+=("Apple Distribution        （用于签 App）")
[ -z "$PKG_CERT" ] && MISSING+=("3rd Party Mac Developer Installer   （用于签 .pkg 安装包）")
if [ "${#MISSING[@]}" -gt 0 ]; then
  echo "❌ 缺少 App Store 分发证书："
  printf '   - %s\n' "${MISSING[@]}"
  echo ""
  echo "创建方式（二选一）："
  echo "  A. Xcode → Settings → Accounts → 选账号 → Manage Certificates → 左下 ＋"
  echo "  B. developer.apple.com → Certificates, Identifiers & Profiles → ➕"
  exit 1
fi

echo "==> App 签名（沙盒 entitlements + ${APP_CERT}）..."
codesign --force --sign "$APP_CERT" \
  --entitlements Resources/ShortKey.mas.entitlements \
  "$APP"

echo "==> productbuild（${PKG_CERT}）..."
rm -f "$PKG"
productbuild \
  --component "$APP" /Applications \
  --sign "$PKG_CERT" \
  "$PKG"

echo "✅ $PKG"
echo "   上传：Transporter.app 拖入，或"
echo "   xcrun altool --upload-package -f $PKG --apiKey <KEY_ID> --apiIssuer <ISSUER_ID>"
