import Foundation

/// 单个快捷键条目（纯数据，供 Core 与 UI 共用）
public struct ShortcutItem: Identifiable, Hashable, Codable, Sendable {
    public var id: String
    public var title: String
    public var key: String
    public var modifiers: ShortcutModifiers
    public var group: String
    /// 完整菜单路径，如 ["文件", "导出", "导出为 PDF"]
    public var path: [String]
    public var isEnabled: Bool
    /// 特殊键（F 键/方向键/Space 等）的虚拟键码，用于浮层内「按下即执行」的匹配
    public var virtualKey: Int?

    public init(
        title: String,
        key: String,
        modifiers: ShortcutModifiers,
        group: String,
        path: [String],
        isEnabled: Bool = true,
        virtualKey: Int? = nil
    ) {
        self.title = title
        self.key = key
        self.modifiers = modifiers
        self.group = group
        self.path = path
        self.isEnabled = isEnabled
        self.virtualKey = virtualKey
        // 稳定 id：菜单路径 + 标题 + 键组合
        self.id = (path + [title, modifiers.symbols + key]).joined(separator: "\u{1F}")
    }
}

/// 修饰键集合
public struct ShortcutModifiers: OptionSet, Hashable, Codable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let control = ShortcutModifiers(rawValue: 1 << 0)
    public static let option = ShortcutModifiers(rawValue: 1 << 1)
    public static let shift = ShortcutModifiers(rawValue: 1 << 2)
    public static let command = ShortcutModifiers(rawValue: 1 << 3)

    /// macOS 惯例显示顺序：⌃ ⌥ ⇧ ⌘
    public var symbols: String {
        (contains(.control) ? "⌃" : "")
            + (contains(.option) ? "⌥" : "")
            + (contains(.shift) ? "⇧" : "")
            + (contains(.command) ? "⌘" : "")
    }

    /// 逐个修饰键符号（⌃ ⌥ ⇧ ⌘ 顺序），供 UI 按类别着色
    public var orderedSymbols: [String] {
        (contains(.control) ? ["⌃"] : [])
            + (contains(.option) ? ["⌥"] : [])
            + (contains(.shift) ? ["⇧"] : [])
            + (contains(.command) ? ["⌘"] : [])
    }

    /// 解析 `AXMenuItemCmdModifiers` 位掩码：
    /// shift = 1<<0，option = 1<<1，control = 1<<2，1<<3 = 无 ⌘
    public static func fromAXModifiers(_ value: Int) -> ShortcutModifiers {
        var m: ShortcutModifiers = []
        if value & 1 != 0 { m.insert(.shift) }
        if value & 2 != 0 { m.insert(.option) }
        if value & 4 != 0 { m.insert(.control) }
        if value & 8 == 0 { m.insert(.command) }
        return m
    }
}
