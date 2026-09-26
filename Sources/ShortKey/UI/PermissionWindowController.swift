import AppKit
import SwiftUI

/// 权限引导窗口：图形化 + 动画的拖拽授权引导。
/// 循环播放四步示意动画（打开设置 → 访达定位 → 拖入列表 → 完成授权），
/// 实时检测授权状态，成功后自动收起。
@MainActor
final class PermissionWindowController {
    final class Status: ObservableObject {
        @Published var isTrusted = Permissions.isTrusted
        /// 是否为打包 App（swift run 裸二进制时拖拽不适用）
        let isBundleApp = Bundle.main.bundlePath.hasSuffix(".app")
    }

    private var window: NSWindow?
    private let status = Status()
    private var pollTimer: Timer?

    func show() {
        let window = self.window ?? makeWindow()
        self.window = window
        status.isTrusted = Permissions.isTrusted
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        startPolling()
    }

    private func makeWindow() -> NSWindow {
        let bundlePath = Bundle.main.bundlePath
        let view = OnboardingView(
            status: status,
            appIcon: bundlePath.hasSuffix(".app") ? NSWorkspace.shared.icon(forFile: bundlePath) : nil,
            onOpenSettings: { Permissions.openSystemSettings() },
            onRevealApp: {
                guard bundlePath.hasSuffix(".app") else { return }
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: bundlePath)])
            }
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "启用 ShortKey"
        window.contentView = NSHostingView(rootView: view)
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .floating
        return window
    }

    private func startPolling() {
        pollTimer?.invalidate()
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self?.checkOnce() }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    private func checkOnce() {
        let trusted = Permissions.isTrusted
        status.isTrusted = trusted

        if trusted {
            pollTimer?.invalidate()
            pollTimer = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
                MainActor.assumeIsolated {
                    guard Permissions.isTrusted else { return }
                    self?.window?.orderOut(nil)
                }
            }
        } else if window?.isVisible != true {
            pollTimer?.invalidate()
            pollTimer = nil
        }
    }
}

// MARK: - 引导视图

/// 四步动画引导：0 打开设置 → 1 访达定位 → 2 拖入列表 → 3 完成
struct OnboardingView: View {
    @ObservedObject var status: PermissionWindowController.Status
    let appIcon: NSImage?
    var onOpenSettings: () -> Void
    var onRevealApp: () -> Void

    @State private var step = 0
    private let stepCount = 4

    private let captions = [
        "① 打开「系统设置 → 隐私与安全性 → 辅助功能」",
        "② 点下方按钮，在访达中定位 ShortKey",
        "③ 把 ShortKey 拖进右侧的应用列表",
        "④ 打开开关，完成！",
    ]

    /// 已授权时定格在完成画面
    private var displayStep: Int { status.isTrusted ? 3 : step }

    var body: some View {
        VStack(spacing: 16) {
            header
            diagram
            caption
            actionArea
        }
        .padding(24)
        .frame(width: 540)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_400_000_000)
                withAnimation(.easeInOut(duration: 0.45)) {
                    step = (step + 1) % stepCount
                }
            }
        }
    }

    // MARK: 头部：图标 + 标题 + 实时状态

    private var header: some View {
        HStack(spacing: 12) {
            iconView(size: 34)
            Text("启用 ShortKey")
                .font(.system(size: 20, weight: .bold))
            Spacer()
            HStack(spacing: 6) {
                Circle()
                    .fill(status.isTrusted ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text(status.isTrusted ? "已授权" : "等待授权…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: 动画示意图

    private var diagram: some View {
        HStack(spacing: 0) {
            finderCard
            dragArrow
            settingsCard
        }
        .frame(height: 150)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.primary.opacity(0.04)))
        .overlay(alignment: .topTrailing) {
            Button {
                withAnimation(.easeInOut(duration: 0.4)) { step = 0 }
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .help("重播动画")
            .padding(8)
        }
    }

    /// 左：访达中的 ShortKey
    private var finderCard: some View {
        VStack(spacing: 6) {
            iconView(size: 36)
            Text("ShortKey")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.07)))
        .scaleEffect(displayStep == 1 ? 1.1 : 1.0)
        .opacity(displayStep == 3 ? 0.4 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: displayStep)
    }

    /// 中：虚线轨迹 + 飞行的图标
    private var dragArrow: some View {
        ZStack {
            HStack(spacing: 0) {
                Rectangle()
                    .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    .frame(height: 1)
                    .foregroundStyle(Color.secondary.opacity(0.6))
                Image(systemName: "arrow.right")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.secondary.opacity(0.6))
            }
            .padding(.horizontal, 6)

            iconView(size: 24)
                .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
                .offset(x: displayStep >= 2 ? 46 : -46)
                .opacity(displayStep == 3 ? 0 : 1)
                .animation(.easeInOut(duration: 1.1), value: displayStep)
        }
        .frame(width: 110)
    }

    /// 右：模拟的设置列表行
    private var settingsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("辅助功能")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        Color.accentColor.opacity(displayStep >= 2 ? 0.9 : 0.4),
                        style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
                    )
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(displayStep >= 3 ? 0.08 : 0.02)))
                HStack(spacing: 8) {
                    if displayStep >= 2 {
                        iconView(size: 16)
                            .transition(.scale.combined(with: .opacity))
                    }
                    Text("ShortKey")
                        .font(.caption)
                        .foregroundStyle(displayStep >= 2 ? .primary : .secondary)
                    Spacer()
                    toggleGraphic
                }
                .padding(.horizontal, 8)
            }
            .frame(width: 158, height: 36)

            if displayStep >= 3 {
                Label("授权完成", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.green)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.7), value: displayStep)
    }

    private var toggleGraphic: some View {
        ZStack {
            Capsule()
                .fill(displayStep >= 3 ? Color.green : Color.secondary.opacity(0.3))
                .frame(width: 28, height: 16)
            Circle()
                .fill(Color.white)
                .frame(width: 13, height: 13)
                .offset(x: displayStep >= 3 ? 6 : -6)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: displayStep)
    }

    // MARK: 字幕

    private var caption: some View {
        Text(captions[displayStep])
            .font(.system(size: 13, weight: .medium))
            .multilineTextAlignment(.center)
            .frame(height: 20)
            .id(displayStep)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
            .animation(.easeInOut(duration: 0.35), value: displayStep)
    }

    // MARK: 底部动作区

    @ViewBuilder
    private var actionArea: some View {
        if status.isTrusted {
            Label("授权成功，窗口即将自动关闭", systemImage: "checkmark.circle.fill")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.green)
                .frame(maxWidth: .infinity)
        } else {
            HStack(spacing: 10) {
                Button(action: onOpenSettings) {
                    Label("打开辅助功能设置", systemImage: "gearshape.fill")
                        .frame(maxWidth: .infinity)
                }
                .keyboardShortcut(.defaultAction)
                if status.isBundleApp {
                    Button(action: onRevealApp) {
                        Label("在访达中显示", systemImage: "folder")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            if !status.isBundleApp {
                Text("当前以 swift run 方式运行，请在列表中勾选你的终端应用")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: 图标

    @ViewBuilder
    private func iconView(size: CGFloat) -> some View {
        if let appIcon {
            Image(nsImage: appIcon)
                .resizable()
                .frame(width: size, height: size)
        } else {
            Image(systemName: "command.square.fill")
                .font(.system(size: size * 0.75))
                .foregroundStyle(Color.accentColor)
                .frame(width: size, height: size)
        }
    }
}
