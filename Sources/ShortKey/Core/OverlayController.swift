import AppKit
import SwiftUI
import ShortKeyCore

/// 浮层视图模型
@MainActor
final class OverlayModel: ObservableObject {
    @Published var appName = ""
    @Published var appIcon: NSImage?
    @Published var query = ""
    @Published var items: [ShortcutItem] = []
    @Published var favorites: Set<String> = []
    @Published var hidden: Set<String> = []
    /// 每次显示浮层时递增，用于驱动重新聚焦搜索框
    @Published private(set) var revision = 0
    /// 用户输入动作（打字），用于重置闲置自动关闭计时
    var onUserActivity: (() -> Void)?
    /// skhd 快捷键（启动时从 skhdrc 装载）
    @Published var skhdItems: [ShortcutItem] = []
    /// 自定义快捷键（custom.json）
    @Published var customItems: [ShortcutItem] = []
    /// 当前搜索的最佳匹配（回车执行）
    @Published var bestMatchItem: ShortcutItem?
    /// ↑↓ 选中的条目 id（跨列高亮）
    @Published var selectedItemId: String?
    /// 列数（设置可调）
    @Published var columnCount: Int = 4
    /// 行字号（设置可调）
    @Published var rowFontSize: Double = 13
    /// 修饰键按类别着色（设置可调）
    @Published var modifierColorCoding = true

    /// ↑↓ 导航：仅搜索态；对全部来源按标题模糊分排序，选中项随移动更新
    func navigate(_ delta: Int) {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        var pool = items + skhdItems + customItems + ShortcutCatalog.systemItems + ShortcutCatalog.gestureItems
        let hiddenSet = hidden
        pool = pool.filter { showHidden || !hiddenSet.contains($0.id) }
        guard !pool.isEmpty else { return }

        var ranked: [(ShortcutItem, Int)] = []
        for item in pool {
            guard let m = FuzzyMatcher.match(query: query, target: item.title) else { continue }
            ranked.append((item, m.score))
        }
        ranked.sort { $0.1 > $1.1 }
        guard !ranked.isEmpty else { return }

        let current = selectedItemId.flatMap { id in ranked.firstIndex { $0.0.id == id } }
        let next = current.map { max(0, min(ranked.count - 1, $0 + delta)) } ?? 0
        selectedItemId = ranked[next].0.id
        bestMatchItem = ranked[next].0
    }

    /// 是否显示已隐藏的快捷键
    @Published var showHidden = false
    /// 折叠的分组（全局持久化到 UserDefaults）
    @Published var collapsedGroups: Set<String>

    init() {
        collapsedGroups = Set(UserDefaults.standard.stringArray(forKey: "collapsedGroups") ?? [])
    }

    /// 折叠 / 展开分组并持久化
    func toggleCollapsed(_ group: String) {
        if collapsedGroups.contains(group) {
            collapsedGroups.remove(group)
        } else {
            collapsedGroups.insert(group)
        }
        UserDefaults.standard.set(Array(collapsedGroups), forKey: "collapsedGroups")
    }

    func update(appName: String, icon: NSImage?, items: [ShortcutItem], state: ShortcutStore.AppState) {
        self.appName = appName
        self.appIcon = icon
        self.items = items
        self.favorites = state.favorites
        self.hidden = state.hidden
        self.query = ""
        self.selectedItemId = nil
        self.revision += 1
    }
}

/// 浮层窗口控制器：组装 NSPanel + SwiftUI 内容
@MainActor
final class OverlayController: NSObject, NSWindowDelegate {
    let model = OverlayModel()
    private let store: ShortcutStore
    private var panel: OverlayPanel?
    private(set) var currentBundleID = ""
    /// 本次扫描的菜单元素表（点击行 / 回车执行）
    private var performer: MenuPerformer?

    /// 请求关闭浮层（由 AppDelegate 接线到 hideOverlay 与事件状态同步）
    var onClose: (() -> Void)?
    /// 请求导出 Markdown（由 AppDelegate 实现）
    var onExport: (() -> Void)?

    init(store: ShortcutStore) {
        self.store = store
        super.init()
        model.onUserActivity = { [weak self] in self?.scheduleIdleClose() }
    }

    var isVisible: Bool { panel?.isVisible ?? false }

    func show(appName: String, bundleID: String, items: [ShortcutItem], icon: NSImage?, performer: MenuPerformer) {
        self.performer = performer
        currentBundleID = bundleID
        let panel = ensurePanel()
        model.update(appName: appName, icon: icon, items: items, state: store.state(for: bundleID))
        model.columnCount = Int(SettingsStore.shared.columnCount)
        model.rowFontSize = SettingsStore.shared.rowFontSize
        model.modifierColorCoding = SettingsStore.shared.modifierColorCoding
        panel.setContentSize(overlaySize())
        if SettingsStore.shared.overlayPosition == .cursor {
            panel.moveToCursor()
        } else {
            panel.centerOnScreen()
        }
        panel.orderFrontRegardless()
        panel.makeKey()
        startMouseMonitoring()
        scheduleIdleClose()
    }

    /// KeyCue 式大浮层：占鼠标所在屏幕可视区 88% × 84%（上限 1500 × 840）
    private func overlaySize() -> NSSize {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouseLocation) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        return NSSize(width: min(visible.width * 0.88, 1500),
                      height: min(visible.height * 0.84, 840))
    }

    func hide() {
        stopMouseMonitoring()
        guard let panel, panel.isVisible else { return }
        panel.orderOut(nil)
    }

    func toggleFavorite(_ id: String) {
        store.toggleFavorite(id, bundleID: currentBundleID)
        model.favorites = store.state(for: currentBundleID).favorites
    }

    func toggleHidden(_ id: String) {
        store.toggleHidden(id, bundleID: currentBundleID)
        model.hidden = store.state(for: currentBundleID).hidden
    }

    /// 执行一个条目：应用菜单命令走 AXPress，系统/skhd/自定义走合成按键；
    /// 成功后关闭浮层
    func perform(_ item: ShortcutItem) {
        if let performer, performer.perform(item.id) {
            onClose?()
            return
        }
        if synthKey(for: item) {
            onClose?()
        } else {
            NSSound.beep() // 手势等纯展示条目无法执行
        }
    }

    /// 合成组合键发给前台应用（用于系统/skhd/自定义条目）
    private func synthKey(for item: ShortcutItem) -> Bool {
        var keyCode = item.virtualKey
        if keyCode == nil, let character = item.key.lowercased().first {
            keyCode = GlyphMap.virtualKey(forCharacter: character)
        }
        if keyCode == nil, item.key == "␣" { keyCode = 49 }
        guard let keyCode else { return false }

        var flags: CGEventFlags = []
        if item.modifiers.contains(.control) { flags.insert(.maskControl) }
        if item.modifiers.contains(.option) { flags.insert(.maskAlternate) }
        if item.modifiers.contains(.shift) { flags.insert(.maskShift) }
        if item.modifiers.contains(.command) { flags.insert(.maskCommand) }

        guard let down = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(truncatingIfNeeded: keyCode), keyDown: true),
              let up = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(truncatingIfNeeded: keyCode), keyDown: false) else {
            return false
        }
        for event in [down, up] {
            event.flags = flags
            event.setIntegerValueField(.eventSourceUserData, value: EventTapController.repostMarker)
            event.post(tap: .cghidEventTap)
        }
        return true
    }

    private func ensurePanel() -> OverlayPanel {
        if let panel { return panel }
        let panel = OverlayPanel(contentRect: NSRect(x: 0, y: 0, width: 980, height: 620))
        let rootView = ShortcutsView(
            model: model,
            onToggleFavorite: { [weak self] in self?.toggleFavorite($0) },
            onToggleHidden: { [weak self] in self?.toggleHidden($0) },
            onExecuteItem: { [weak self] in self?.perform($0) },
            onClose: { [weak self] in self?.close() },
            onExport: { [weak self] in self?.onExport?() }
        )
        panel.contentView = NSHostingView(rootView: rootView)
        panel.delegate = self
        self.panel = panel
        return panel
    }

    // MARK: - 鼠标驻留 / 自动关闭

    private var pollTimer: Timer?
    private var mouseInside = false
    private var mouseEverEntered = false
    private var exitWorkItem: DispatchWorkItem?
    private var idleWorkItem: DispatchWorkItem?

    /// 浮层显示期间轮询鼠标位置：
    /// - 进入过面板后移出（0.3s 缓冲）→ 关闭
    /// - 从未进入 → 交给 10s 闲置计时（打字会重置）
    private func startMouseMonitoring() {
        pollTimer?.invalidate()
        exitWorkItem?.cancel()
        idleWorkItem?.cancel()
        mouseInside = panel?.frame.contains(NSEvent.mouseLocation) ?? false
        mouseEverEntered = mouseInside

        let timer = Timer(timeInterval: 0.15, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self?.pollMouse() }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    private func stopMouseMonitoring() {
        pollTimer?.invalidate(); pollTimer = nil
        exitWorkItem?.cancel(); exitWorkItem = nil
        idleWorkItem?.cancel(); idleWorkItem = nil
        mouseInside = false
        mouseEverEntered = false
    }

    private func pollMouse() {
        guard let panel, panel.isVisible else { return }
        let inside = panel.frame.contains(NSEvent.mouseLocation)
        if inside {
            mouseEverEntered = true
            if !mouseInside {
                mouseInside = true
                scheduleIdleClose() // 鼠标在面板上＝用户在看，重置闲置计时
            }
            exitWorkItem?.cancel()
        } else if mouseInside {
            mouseInside = false
            scheduleExitClose()
        }
    }

    /// 移出 0.3s 后关闭（缓冲防误拂）
    private func scheduleExitClose() {
        guard mouseEverEntered else { return }
        exitWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.close() }
        }
        exitWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: item)
    }

    /// 闲置 10s 自动关闭（打字 / 鼠标在面板上会重置）
    private func scheduleIdleClose() {
        guard panel?.isVisible == true || panel == nil else { return }
        idleWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.close() }
        }
        idleWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: item)
    }

    private func close() {
        onClose?()
    }

    // MARK: - NSWindowDelegate

    /// 点击浮层以外的位置（其他窗口成为 key）→ 关闭
    func windowDidResignKey(_ notification: Notification) {
        guard isVisible else { return }
        close()
    }
}
