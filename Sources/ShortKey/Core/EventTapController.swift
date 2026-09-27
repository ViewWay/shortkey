import AppKit
@preconcurrency import CoreGraphics

/// 全局键盘监听（CGEventTap）。
/// tap 运行在专用后台线程的 RunLoop 上，回调绝不阻塞主线程，
/// 键盘事件处理与 UI 完全解耦——否则全系统按键都会等待本进程。
final class EventTapController: @unchecked Sendable {
    /// 触发模式
    enum TriggerMode {
        case hold
        case doubleTapHold
    }

    /// 触发状态机状态
    private enum TapState {
        case idle              // 未在检测
        case pressed           // ⌘ 按住中：hold 等阈值；doubleTap 等第一次松开
        case waitingSecondTap  // doubleTap：第一次已松开，等第二次按下
        case armed             // doubleTap：第二次按住中，等阈值触发
    }

    private let lock = NSLock()
    private var mode: TriggerMode = .hold
    private var threshold: TimeInterval = 0.3
    /// 触发键（设置页可在 ⌘/⌥/⌃ 间切换）
    private var triggerCodes: Set<Int64> = [55, 54]
    private var triggerMask: CGEventFlags = .maskCommand
    private var tapState: TapState = .idle
    private var overlayRequested = false
    private var stateWorkItem: DispatchWorkItem?

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let timerQueue = DispatchQueue(label: "app.shortkey.trigger-timer")

    /// 主线程回调
    var onTrigger: (() -> Void)?
    /// 主线程回调（Esc / 点击外部）
    var onCancel: (() -> Void)?
    /// 主线程回调（回车：执行搜索最佳匹配）
    var onConfirm: (() -> Void)?
    /// 主线程回调（↑↓ 移动搜索选中项，±1）
    var onNavigate: ((Int) -> Void)?
    /// 浮层显示期间按下组合键时回调（tap 线程）：命中已列出快捷键返回 true 表示已转发执行并拦截
    var comboHandler: ((CGEvent, Int64, CGEventFlags) -> Bool)?
    /// 重发事件的标记：带此标记的事件直接放行，防止转发回环
    static let repostMarker: Int64 = 0x534B_4559 // "SKEY"

    private static let modifierFlags: CGEventFlags = [.maskCommand, .maskShift, .maskControl, .maskAlternate]
    /// 左 ⌘ = 55，右 ⌘ = 54
    private static let commandKeyCodes: Set<Int64> = [55, 54]
    private static let escapeKeyCode: Int64 = 53
    private static let returnKeyCode: Int64 = 36
    private static let tabKeyCode: Int64 = 48
    private static let upArrowKeyCode: Int64 = 126
    private static let downArrowKeyCode: Int64 = 125
    /// doubleTap：第一次按住超过此时长视为普通长按，不触发
    private static let maxFirstTapHold: TimeInterval = 0.5
    /// doubleTap：两次按下之间的最大间隔
    private static let doubleTapInterval: TimeInterval = 0.35

    // MARK: - 线程安全的配置入口

    func setMode(_ newMode: TriggerMode) {
        lock.lock(); mode = newMode; lock.unlock()
    }

    func setThreshold(_ seconds: TimeInterval) {
        lock.lock(); threshold = seconds; lock.unlock()
    }

    /// 由 AppDelegate 在浮层 show/hide 时同步状态
    func setVisible(_ visible: Bool) {
        lock.lock(); overlayRequested = visible; lock.unlock()
    }

    /// 设置触发键（设置页切换 ⌘/⌥/⌃ 时调用）
    func setTriggerKeys(_ codes: Set<Int64>, mask: CGEventFlags) {
        lock.lock()
        triggerCodes = codes
        triggerMask = mask
        lock.unlock()
    }

    var isOverlayRequested: Bool {
        lock.lock(); defer { lock.unlock() }
        return overlayRequested
    }

    // MARK: - 生命周期

    /// 创建并启动事件 tap；缺少辅助功能权限时返回 false
    @discardableResult
    func start() -> Bool {
        lock.lock()
        if tap != nil { lock.unlock(); return true }
        lock.unlock()

        let mask = CGEventMask(
            (1 << CGEventType.keyDown.rawValue)
                | (1 << CGEventType.keyUp.rawValue)
                | (1 << CGEventType.flagsChanged.rawValue)
        )
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: Self.tapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        let thread = Thread { [weak self] in
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CFRunLoopRun()
            _ = self // 保持引用语义清晰；线程随 App 生命周期常驻
        }
        thread.name = "app.shortkey.eventtap"
        thread.start()

        CGEvent.tapEnable(tap: tap, enable: true)
        lock.lock()
        self.tap = tap
        self.runLoopSource = source
        lock.unlock()
        return true
    }

    func stop() {
        lock.lock()
        let tap = self.tap
        self.tap = nil
        self.runLoopSource = nil
        stateWorkItem?.cancel()
        stateWorkItem = nil
        lock.unlock()
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
    }

    // MARK: - 事件回调（运行在 tap 线程）

    fileprivate nonisolated static let tapCallback: CGEventTapCallBack = { _, type, event, userInfo in
        guard let userInfo else { return Unmanaged.passUnretained(event) }
        let controller = Unmanaged<EventTapController>.fromOpaque(userInfo).takeUnretainedValue()
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            controller.reenableTap()
            return Unmanaged.passUnretained(event)
        }
        return controller.handle(event: event, type: type)
    }

    func reenableTap() {
        lock.lock(); let tap = self.tap; lock.unlock()
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }

    fileprivate func handle(event: CGEvent, type: CGEventType) -> Unmanaged<CGEvent>? {
        let pass = Unmanaged.passUnretained(event)
        // 自己重发的事件直接放行，避免转发回环
        if event.getIntegerValueField(.eventSourceUserData) == Self.repostMarker {
            return pass
        }
        switch type {
        case .flagsChanged:
            return handleFlagsChanged(event)
        case .keyDown:
            return handleKey(event, isDown: true)
        case .keyUp:
            return handleKey(event, isDown: false)
        default:
            return pass
        }
    }

    private func handleFlagsChanged(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let mods = event.flags.intersection(Self.modifierFlags)

        lock.lock()
        defer { lock.unlock() }

        if overlayRequested {
            // 浮层显示中：⌘ 松开不再关闭——由鼠标移出 / Esc / 点击外部 / 闲置超时关闭
            return Unmanaged.passUnretained(event)
        }

        if isTriggerKey(keyCode) {
            let hasTrigger = event.flags.contains(triggerMask)
            if hasTrigger {
                if mods == triggerMask {
                    commandPressedLocked() // 纯触发键按下
                } else {
                    cancelTriggerLocked() // 触发键+其它修饰 = 真实快捷键
                }
            } else {
                commandReleasedLocked()
            }
        } else if mods != triggerMask {
            // 其它修饰键参与进来，取消检测
            cancelTriggerLocked()
        }
        return Unmanaged.passUnretained(event)
    }

    private func handleKey(_ event: CGEvent, isDown: Bool) -> Unmanaged<CGEvent>? {
        lock.lock()
        let visible = overlayRequested
        // 未显示浮层：真实按键（如快速 ⌘C）取消检测
        if !visible && isDown && tapState != .idle {
            cancelTriggerLocked()
        }
        lock.unlock()

        if visible {
            return captureWhileVisible(event, keyCode: event.getIntegerValueField(.keyboardEventKeycode), mods: event.flags.intersection(Self.modifierFlags), isDown: isDown)
        }
        return Unmanaged.passUnretained(event)
    }

    /// 浮层显示期间的按键接管
    private func captureWhileVisible(_ event: CGEvent, keyCode: Int64, mods: CGEventFlags, isDown: Bool) -> Unmanaged<CGEvent>? {
        let pass = Unmanaged.passUnretained(event)

        guard isDown else {
            // keyUp 与 keyDown 对称地剥离 ⌘，保持按键状态一致
            if mods.contains(.maskCommand),
               mods.subtracting(.maskCommand).isSubset(of: [.maskShift]) {
                event.flags = event.flags.subtracting(.maskCommand)
            }
            return pass
        }

        switch keyCode {
        case Self.escapeKeyCode:
            notifyMainClose()
            return nil
        case Self.returnKeyCode:
            notifyMainConfirm()
            return nil
        case Self.upArrowKeyCode:
            notifyMainNavigate(-1)
            return nil
        case Self.downArrowKeyCode:
            notifyMainNavigate(1)
            return nil
        case Self.tabKeyCode:
            return nil
        default:
            break
        }

        // 命中已列出的快捷键组合 → 转发给前台应用执行
        if mods.isEmpty == false, comboHandler?(event, keyCode, mods) == true {
            return nil
        }

        if mods.contains(triggerMask) {
            let others = mods.subtracting(triggerMask)
            if others.isSubset(of: [.maskShift]) {
                // 触发键(+⇧) + 字符 → 剥离触发键后继续派发，输入进搜索框
                event.flags = event.flags.subtracting(triggerMask)
                return pass
            }
            return nil // 其它修饰组合在浮层显示期间拦截
        }
        return pass
    }

    // MARK: - 触发状态机（调用方需持有 lock）

    private func commandPressedLocked() {
        switch mode {
        case .hold:
            tapState = .pressed
            scheduleStateLocked(after: threshold)
        case .doubleTapHold:
            switch tapState {
            case .idle:
                tapState = .pressed
                scheduleStateLocked(after: Self.maxFirstTapHold)
            case .waitingSecondTap:
                tapState = .armed
                scheduleStateLocked(after: threshold)
            case .pressed, .armed:
                break
            }
        }
    }

    private func commandReleasedLocked() {
        switch tapState {
        case .pressed:
            if mode == .doubleTapHold {
                tapState = .waitingSecondTap
                scheduleStateLocked(after: Self.doubleTapInterval)
            } else {
                cancelTriggerLocked()
            }
        case .armed:
            cancelTriggerLocked()
        case .idle, .waitingSecondTap:
            break
        }
    }

    /// 统一的定时检查：hold 模式 pressed 到点触发；
    /// doubleTap 模式 armed 到点触发、第一按 pressed 超时放弃
    private func scheduleStateLocked(after: TimeInterval) {
        stateWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.lock.lock()
            defer { self.lock.unlock() }
            switch self.tapState {
            case .armed:
                self.finishTriggerLocked()
            case .pressed where self.mode == .doubleTapHold:
                self.tapState = .idle // 第一按超时，放弃
            case .pressed:
                self.finishTriggerLocked()
            case .idle, .waitingSecondTap:
                break
            }
        }
        stateWorkItem = item
        timerQueue.asyncAfter(deadline: .now() + after, execute: item)
    }

    private func finishTriggerLocked() {
        tapState = .idle
        overlayRequested = true
        DispatchQueue.main.async {
            MainActor.assumeIsolated { self.onTrigger?() }
        }
    }

    private func notifyMainClose() {
        DispatchQueue.main.async {
            MainActor.assumeIsolated { self.onCancel?() }
        }
    }

    private func notifyMainConfirm() {
        DispatchQueue.main.async {
            MainActor.assumeIsolated { self.onConfirm?() }
        }
    }

    private func notifyMainNavigate(_ delta: Int) {
        DispatchQueue.main.async {
            MainActor.assumeIsolated { self.onNavigate?(delta) }
        }
    }

    private func isTriggerKey(_ keyCode: Int64) -> Bool {
        triggerCodes.contains(keyCode)
    }

    private func cancelTriggerLocked() {
        stateWorkItem?.cancel()
        stateWorkItem = nil
        tapState = .idle
    }
}
