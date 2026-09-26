#!/usr/bin/env bash
# 本地交叉编译 Windows 版（需 brew install mingw-w64）
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> 检查 mingw-w64..."
command -v x86_64-w64-mingw32-gcc >/dev/null || {
  echo "未找到 mingw-w64，请先: brew install mingw-w64"; exit 1;
}

echo "==> 构建shortkey.exe (release, gui)..."
cd core-rust
cargo +stable build --release --target x86_64-pc-windows-gnu --features gui

EXE="target/x86_64-pc-windows-gnu/release/shortkey.exe"
cd ..
mkdir -p build/windows
cp "core-rust/$EXE" build/windows/shortkey.exe

ZIP="build/ShortKey-windows.zip"
rm -f "$ZIP"
(cd build/windows && zip -q ../ShortKey-windows.zip shortkey.exe)
echo "✅ $ZIP"
