#!/usr/bin/env bash
# Developer ID 签名 + 公证（分发给他人时使用）。
# 前置（一次性，需要你的 Apple ID 凭证）：
#   1. build_app.sh 已用 Developer ID 签名（改 SCRIPT 里 SIGN_IDENTITY 优先级即可）
#   2. 存凭证: xcrun notarytool store-credentials shortkey-notary \
#        --apple-id <你的AppleID> --team-id ALT44F9ZUY --password <App专用密码>
#   3. 运行: Scripts/notarize.sh build/ShortKey.app.zip
set -euo pipefail
FILE="${1:?用法: Scripts/notarize.sh <ShortKey.app.zip>}"
xcrun notarytool submit "$FILE" --keychain-profile shortkey-notary --wait
xcrun stapler staple "$FILE"
echo "✅ 公证完成，可对外分发"
