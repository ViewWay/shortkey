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

    private init() {
        let defaults = UserDefaults.standard
        triggerKind = TriggerKind(rawValue: defaults.string(forKey: "triggerKind") ?? "") ?? .hold
        thresholdMs = defaults.object(forKey: "thresholdMs") as? Double ?? 300
        appearance = Appearance(rawValue: defaults.string(forKey: "appearance") ?? "") ?? .system
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
