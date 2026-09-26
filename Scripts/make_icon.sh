#!/usr/bin/env bash
# 生成 App 图标：灰色键帽 + ⌘ 字形 → Resources/AppIcon.icns
set -euo pipefail
cd "$(dirname "$0")/.."

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/mkicon.swift" <<'SWIFT'
import AppKit

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
    // 灰色圆角键帽
    let inset = size * 0.09
    let keyRect = rect.insetBy(dx: inset, dy: inset)
    let radius = keyRect.width * 0.22
    let path = NSBezierPath(roundedRect: keyRect, xRadius: radius, yRadius: radius)
    NSColor(calibratedWhite: 0.80, alpha: 1).setFill()
    path.fill()
    NSColor(calibratedWhite: 0.60, alpha: 1).setStroke()
    path.lineWidth = size * 0.008
    path.stroke()

    // ⌘ 字形
    let font = NSFont.systemFont(ofSize: keyRect.width * 0.60, weight: .medium)
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor(calibratedWhite: 0.28, alpha: 1),
    ]
    let glyph = NSAttributedString(string: "⌘", attributes: attributes)
    let glyphSize = glyph.size()
    glyph.draw(at: NSPoint(x: keyRect.midX - glyphSize.width / 2,
                           y: keyRect.midY - glyphSize.height / 2))
    return true
}

let tiff = image.tiffRepresentation!
let rep = NSBitmapImageRep(data: tiff)!
let png = rep.representation(using: .png, properties: [:])!
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
SWIFT

mkdir -p "$TMP/AppIcon.iconset"
swift "$TMP/mkicon.swift" "$TMP/AppIcon.iconset/icon_512x512@2x.png"

# sips 缩出全部尺寸
sips -z 512 512 "$TMP/AppIcon.iconset/icon_512x512@2x.png" --out "$TMP/AppIcon.iconset/icon_512x512.png" >/dev/null
sips -z 256 256 "$TMP/AppIcon.iconset/icon_512x512@2x.png" --out "$TMP/AppIcon.iconset/icon_256x256@2x.png" >/dev/null
sips -z 128 128 "$TMP/AppIcon.iconset/icon_512x512@2x.png" --out "$TMP/AppIcon.iconset/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$TMP/AppIcon.iconset/icon_512x512.png" --out "$TMP/AppIcon.iconset/icon_256x256.png" >/dev/null
sips -z 128 128 "$TMP/AppIcon.iconset/icon_512x512.png" --out "$TMP/AppIcon.iconset/icon_128x128.png" >/dev/null
sips -z 64 64 "$TMP/AppIcon.iconset/icon_512x512@2x.png" --out "$TMP/AppIcon.iconset/icon_32x32@2x.png" >/dev/null
sips -z 32 32 "$TMP/AppIcon.iconset/icon_512x512.png" --out "$TMP/AppIcon.iconset/icon_32x32.png" >/dev/null
sips -z 32 32 "$TMP/AppIcon.iconset/icon_512x512.png" --out "$TMP/AppIcon.iconset/icon_16x16@2x.png" >/dev/null
sips -z 16 16 "$TMP/AppIcon.iconset/icon_512x512.png" --out "$TMP/AppIcon.iconset/icon_16x16.png" >/dev/null

mkdir -p Resources
iconutil -c icns "$TMP/AppIcon.iconset" -o Resources/AppIcon.icns
echo "✅ Resources/AppIcon.icns 已生成"
