import AppKit

/// 快捷键浮层：非激活面板，显示时不抢走前台应用焦点
final class OverlayPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        animationBehavior = .utilityWindow
    }

    override var canBecomeKey: Bool { true }

    /// 居中到鼠标所在屏幕（更贴近注意力焦点）
    func centerOnScreen() {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouseLocation) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        let x = visible.midX - frame.width / 2
        let y = visible.midY - frame.height / 2 + visible.height * 0.04
        setFrameOrigin(NSPoint(x: max(visible.minX, x), y: max(visible.minY, y)))
    }

    /// 出现在鼠标上方（跟随鼠标模式）
    func moveToCursor() {
        let mouse = NSEvent.mouseLocation
        guard let visible = (NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main)?.visibleFrame else { return }
        let size = frame.size
        let x = mouse.x - size.width / 2
        let y = mouse.y - size.height - 24
        let clampedX = min(max(visible.minX + 8, x), visible.maxX - size.width - 8)
        let clampedY = min(max(visible.minY + 8, y), visible.maxY - size.height - 8)
        setFrameOrigin(NSPoint(x: clampedX, y: clampedY))
    }
}
