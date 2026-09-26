import AppKit
import Foundation

/// 全局设置：UserDefaults 持久化，变更即时生效
@MainActor
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    enum TriggerKind: String, CaseIterable, Identifiable {
        case hold
        case doubleTapHold

        var id: String { rawValue }
        var label: String { self == .hold ? "按住 ⌘" : "连续按两次 ⌘ 并按住" }
    }

    enum Appearance: String, CaseIterable, Identifiable {
        case system, light, dark

        var id: String { rawValue }
        var label: String {
            switch self {
            case .system: return "跟随系统"
            case .light: return "浅色"
            case .dark: return "深色"
            }
        }
    }

    enum OverlayPosition: String, CaseIterable, Identifiable {
        case center
        case cursor

        var id: String { rawValue }
        var label: String {
            switch self {
            case .center: return "屏幕居中"
            case .cursor: return "跟随鼠标"
            }
        }
    }

    enum TriggerKey: String, CaseIterable, Identifiable {
        case command
        case option
        case control

        var id: String { rawValue }
        var label: String {
            switch self {
            case .command: return "⌘ Command"
            case .option: return "⌥ Option"
            case .control: return "⌃ Control"
            }
        }
    }

    /// 设置变更回调（AppDelegate 用于同步 EventTapController）
    var onChange: (() -> Void)?

    @Published var triggerKind: TriggerKind {
        didSet {
            UserDefaults.standard.set(triggerKind.rawValue, forKey: "triggerKind")
            onChange?()
        }
    }

    @Published var thresholdMs: Double {
        didSet {
            UserDefaults.standard.set(thresholdMs, forKey: "thresholdMs")
            onChange?()
        }
    }

    @Published var appearance: Appearance {
        didSet {
            UserDefaults.standard.set(appearance.rawValue, forKey: "appearance")
            applyAppearance()
        }
    }

    @Published var overlayPosition: OverlayPosition {
        didSet { UserDefaults.standard.set(overlayPosition.rawValue, forKey: "overlayPosition") }
    }

    @Published var triggerKey: TriggerKey {
        didSet {
            UserDefaults.standard.set(triggerKey.rawValue, forKey: "triggerKey")
            onChange?()
        }
    }

    @Published var columnCount: Double {
        didSet { UserDefaults.standard.set(columnCount, forKey: "columnCount") }
    }

    @Published var rowFontSize: Double {
        didSet { UserDefaults.standard.set(rowFontSize, forKey: "rowFontSize") }
    }

    private init() {
        let defaults = UserDefaults.standard
        triggerKind = TriggerKind(rawValue: defaults.string(forKey: "triggerKind") ?? "") ?? .hold
        thresholdMs = defaults.object(forKey: "thresholdMs") as? Double ?? 300
        appearance = Appearance(rawValue: defaults.string(forKey: "appearance") ?? "") ?? .system
        overlayPosition = OverlayPosition(rawValue: defaults.string(forKey: "overlayPosition") ?? "") ?? .center
        triggerKey = TriggerKey(rawValue: defaults.string(forKey: "triggerKey") ?? "") ?? .command
        columnCount = defaults.object(forKey: "columnCount") as? Double ?? 4
        rowFontSize = defaults.object(forKey: "rowFontSize") as? Double ?? 13
        applyAppearance()
    }

    private func applyAppearance() {
        switch appearance {
        case .system: NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}
