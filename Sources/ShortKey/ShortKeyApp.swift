import AppKit
import SwiftUI
import ShortKeyCore

@main
struct ShortKeyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}

/// 应用装配：菜单栏、事件监听、浮层的生命周期接线
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var overlay: OverlayController?
    private var eventTap: EventTapController?
    private let store = ShortcutStore()
    /// 权限引导窗口（实时检测授权状态）
    private let permissionWindow = PermissionWindowController()
    /// 当前浮层条目快照：tap 线程上做组合键命中匹配用（值类型 + 锁）
    private let activeShortcuts = ShortcutBox()
    private var permissionRetryTask: Task<Void, Never>?
    /// 每次「请求显示」递增；AX 读取返回后校验，防止已取消的显示又冒出来
    private var showGeneration = 0
    /// App Nap 活动令牌：常驻无窗口应用被节流会让全局键盘回调延迟
    private var napActivity: NSObjectProtocol?
    /// CLI 启动时待处理的动作（无常驻实例时由本次启动代为执行）
    private var pendingCLIAction: CLI.Action?

    func applicationWillFinishLaunching(_ notification: Notification) {
        // CLI：--help 直接打印；--show/--export/--quit 有常驻实例则转发后退出
        if CommandLine.arguments.contains("--help") {
            print(CLI.usage())
            exit(0)
        }
        if let action = CLI.parseArguments() {
            if CLI.forwardIfResident(action) {
                exit(0)
            }
            pendingCLIAction = action
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // 禁用 App Nap，保证事件 tap 回调不被节流
        napActivity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated],
            reason: "ShortKey 全局键盘监听"
        )

        let controller = OverlayController(store: store)
        controller.onClose = { [weak self] in self?.hideOverlay() }
        overlay = controller

        let tap = EventTapController()
        tap.onTrigger = { [weak self] in self?.showOverlay() }
        tap.onCancel = { [weak self] in self?.hideOverlay() }
        tap.comboHandler = { [weak self] event, keyCode, flags in
            guard let self else { return false }
            return self.executeMatchedShortcut(event: event, keyCode: keyCode, flags: flags)
        }
        tap.onConfirm = { [weak self] in
            self?.confirmBestMatch()
        }
        eventTap = tap

        if !Permissions.isTrusted {
            // 只用自家的引导窗（拖拽流程），不再叠加系统弹窗
            permissionWindow.show()
        }
        if !tap.start() {
            schedulePermissionRetry()
        }

        SettingsStore.shared.onChange = { [weak self] in self?.applySettings() }
        applySettings()

        ShortcutCatalog.refresh()
        ExternalShortcuts.ensureCustomSample()
        if let overlay {
            overlay.model.skhdItems = ExternalShortcuts.loadSkhd()
            overlay.model.customItems = ExternalShortcuts.loadCustom()
        }
        UpdateChecker.shared.checkIfDue()

        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(appDidActivate(_:)),
            name: NSWorkspace.didActivateApplicationNotification, object: nil
        )
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(handleCLINotification(_:)),
            name: CLI.notificationName, object: nil
        )

        setupStatusItem()

        switch pendingCLIAction {
        case .show:
            showOverlay()
        case .quit:
            NSApp.terminate(nil)
        case .export(let path):
            exportMarkdownTo(path: path)
        case nil:
            break
        }
        pendingCLIAction = nil
    }

    func applicationWillTerminate(_ notification: Notification) {
        permissionRetryTask?.cancel()
        eventTap?.stop()
    }

    // MARK: - 浮层

    private func showOverlay() {
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        showGeneration += 1
        let generation = showGeneration
        let pid = app.processIdentifier
        let name = app.localizedName ?? ""
        let bundleID = app.bundleIdentifier ?? "pid-\(pid)"

        Task { @MainActor in
            let scan = await Task.detached(priority: .userInitiated) {
                MenuShortcutsReader.scan(pid: pid)
            }.value
            // 等待期间可能已关闭或重新触发，丢弃过期结果
            guard generation == self.showGeneration,
                  self.eventTap?.isOverlayRequested == true else { return }
            self.activeShortcuts.set(scan.items)
            let icon = NSRunningApplication(processIdentifier: pid)?.icon
            self.overlay?.show(appName: name, bundleID: bundleID, items: scan.items, icon: icon, performer: MenuPerformer(elements: scan.elements))
            self.eventTap?.setVisible(true)
        }
    }

    private func hideOverlay() {
        overlay?.hide()
        eventTap?.setVisible(false)
    }

    /// 设置变更 → 同步到事件监听
    private func applySettings() {
        guard let tap = eventTap else { return }
        let settings = SettingsStore.shared
        tap.setMode(settings.triggerKind == .hold ? .hold : .doubleTapHold)
        tap.setThreshold(settings.thresholdMs / 1000)
    }

    /// 其他应用激活 → 收起浮层
    @objc private func appDidActivate(_ notification: Notification) {
        guard overlay?.isVisible == true else { return }
        hideOverlay()
    }

    // MARK: - 权限重试

    private func schedulePermissionRetry() {
        guard permissionRetryTask == nil else { return }
        permissionRetryTask = Task { @MainActor [weak self] in
            defer { self?.permissionRetryTask = nil }
            while !Task.isCancelled {
                guard let self else { return }
                if Permissions.isTrusted && self.eventTap?.start() == true { return }
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    // MARK: - 状态栏

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            if let image = makeKeycapImage() {
                button.image = image
            } else {
                button.title = "⌘"
            }
        }

        let menu = NSMenu()

        let show = NSMenuItem(title: "显示快捷键面板", action: #selector(showPanelFromMenu(_:)), keyEquivalent: "")
        show.target = self
        menu.addItem(show)

        let settingsItem = NSMenuItem(title: "设置…", action: #selector(openSettings(_:)), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let exportItem = NSMenuItem(title: "导出当前应用快捷键…", action: #selector(exportFromMenu(_:)), keyEquivalent: "")
        exportItem.target = self
        menu.addItem(exportItem)

        let customItem = NSMenuItem(title: "编辑自定义快捷键…", action: #selector(editCustomShortcuts(_:)), keyEquivalent: "")
        customItem.target = self
        menu.addItem(customItem)

        let permissionTitle = Permissions.isTrusted ? "辅助功能权限：已授权" : "⚠️ 需要辅助功能权限"
        let permission = NSMenuItem(title: permissionTitle, action: #selector(openPermissionSettings(_:)), keyEquivalent: "")
        permission.target = self
        menu.addItem(permission)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出 ShortKey", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        item.menu = menu
        statusItem = item
    }

    @objc private func showPanelFromMenu(_ sender: Any?) {
        showOverlay()
    }

    /// 浮层显示期间按下已列出的组合键 → 隐藏浮层并原样转发给前台应用执行。
    /// 运行在 tap 线程：只碰锁保护的快照与纯数据匹配，UI 操作全部抛回主线程。
    fileprivate func executeMatchedShortcut(event: CGEvent, keyCode: Int64, flags: CGEventFlags) -> Bool {
        let mods = Self.modifiers(fromCGEvent: flags)
        guard mods.isEmpty == false else { return false }

        var chars = [UniChar](repeating: 0, count: 4)
        var length = 0
        event.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &length, unicodeString: &chars)
        let character: Character? = length > 0
            ? UnicodeScalar(chars[0]).map { Character($0) }
            : nil

        for item in activeShortcuts.get() where item.modifiers == mods && item.isEnabled {
            var matched = false
            if let vk = item.virtualKey, Int64(vk) == keyCode {
                matched = true
            }
            if !matched, let character, item.key.count == 1,
               item.key.uppercased() == character.uppercased() {
                matched = true
            }
            if !matched, let character, character == " ", item.key == "␣" {
                matched = true
            }
            guard matched else { continue }

            DispatchQueue.main.async {
                MainActor.assumeIsolated { self.hideOverlay() }
            }
            // 原样重发给前台应用执行；带标记防止本 tap 再次拦截
            if let repost = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(truncatingIfNeeded: keyCode), keyDown: true) {
                repost.flags = flags
                repost.setIntegerValueField(.eventSourceUserData, value: EventTapController.repostMarker)
                repost.post(tap: .cghidEventTap)
            }
            return true
        }
        return false
    }

    private static func modifiers(fromCGEvent flags: CGEventFlags) -> ShortcutModifiers {
        var m: ShortcutModifiers = []
        if flags.contains(.maskControl) { m.insert(.control) }
        if flags.contains(.maskAlternate) { m.insert(.option) }
        if flags.contains(.maskShift) { m.insert(.shift) }
        if flags.contains(.maskCommand) { m.insert(.command) }
        return m
    }

    /// 菜单栏图标：透明背景 + 白色 ⌘（轻投影保证浅色菜单栏可见）
    private func makeKeycapImage() -> NSImage? {
        let side: CGFloat = 20
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(side * 2), pixelsHigh: Int(side * 2),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        )
        guard let rep else { return nil }
        rep.size = NSSize(width: side, height: side)

        NSGraphicsContext.saveGraphicsState()
        guard let context = NSGraphicsContext(bitmapImageRep: rep) else {
            NSGraphicsContext.restoreGraphicsState()
            return nil
        }
        NSGraphicsContext.current = context

        let rect = NSRect(x: 0, y: 0, width: side, height: side)
        let font = NSFont.systemFont(ofSize: 19, weight: .semibold)
        let glyphSize = ("⌘" as NSString).size(withAttributes: [.font: font])
        let origin = NSPoint(x: rect.midX - glyphSize.width / 2, y: rect.midY - glyphSize.height / 2)

        // 轻投影：浅色菜单栏上仍可辨识
        NSGraphicsContext.current?.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.45)
        shadow.shadowBlurRadius = 1.4
        shadow.shadowOffset = NSSize(width: 0, height: -0.8)
        shadow.set()
        NSAttributedString(string: "⌘", attributes: [
            .font: font,
            .foregroundColor: NSColor.white,
        ]).draw(at: origin)
        NSGraphicsContext.current?.restoreGraphicsState()

        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: NSSize(width: side, height: side))
        image.addRepresentation(rep)
        return image
    }

    /// 回车：有搜索结果则执行最佳匹配，否则关闭浮层
    private func confirmBestMatch() {
        guard let overlay else {
            hideOverlay()
            return
        }
        if let item = overlay.model.bestMatchItem {
            overlay.perform(item)
        } else {
            hideOverlay()
        }
    }

    /// 非交互导出（CLI / 转发请求）
    private func exportMarkdownTo(path: String?) {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            NSApp.terminate(nil)
            return
        }
        let pid = app.processIdentifier
        let name = app.localizedName ?? "应用"
        let bundleID = app.bundleIdentifier ?? "pid-\(pid)"
        Task { @MainActor in
            let items = await Task.detached(priority: .userInitiated) {
                MenuShortcutsReader.read(pid: pid)
            }.value
            let target = URL(fileURLWithPath: path ?? FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Desktop/\(name) 快捷键.md").path)
            let document = MarkdownBuilder.build(
                appName: name,
                items: items,
                favorites: store.state(for: bundleID).favorites
            )
            try? document.write(to: target, atomically: true, encoding: .utf8)
            print("已导出: \(target.path)")
            NSApp.terminate(nil)
        }
    }

    @objc private func handleCLINotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let action = userInfo["action"] as? String else { return }
        switch action {
        case "show":
            showOverlay()
        case "quit":
            NSApp.terminate(nil)
        case "export":
            if let path = userInfo["path"] as? String, !path.isEmpty {
                exportMarkdownTo(path: path)
            }
        default:
            break
        }
    }

    @objc private func openPermissionSettings(_ sender: Any?) {
        permissionWindow.show()
    }

    @objc private func openSettings(_ sender: Any?) {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    @objc private func exportFromMenu(_ sender: Any?) {
        exportMarkdown()
    }

    @objc private func editCustomShortcuts(_ sender: Any?) {
        ExternalShortcuts.ensureCustomSample()
        NSWorkspace.shared.open(ExternalShortcuts.customFileURL)
    }

    /// 读取前台应用菜单快捷键并弹出保存面板
    private func exportMarkdown() {
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        let pid = app.processIdentifier
        let name = app.localizedName ?? "应用"
        let bundleID = app.bundleIdentifier ?? "pid-\(pid)"
        Task { @MainActor in
            let items = await Task.detached(priority: .userInitiated) {
                MenuShortcutsReader.read(pid: pid)
            }.value
            guard !items.isEmpty else {
                NSSound.beep()
                return
            }
            let favorites = store.state(for: bundleID).favorites
            MarkdownExporter.export(appName: name, items: items, favorites: favorites)
        }
    }
}

/// 跨线程共享的浮层条目快照（tap 线程读、主线程写）
private final class ShortcutBox: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [ShortcutItem] = []

    func set(_ value: [ShortcutItem]) {
        lock.lock(); items = value; lock.unlock()
    }

    func get() -> [ShortcutItem] {
        lock.lock(); defer { lock.unlock() }
        return items
    }
}
