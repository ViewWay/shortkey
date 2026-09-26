import Foundation

/// 自定义快捷键 JSON 解析。
/// 文件：~/Library/Application Support/ShortKey/custom.json
/// 结构：
/// [
///   {
///     "title": "打开终端",
///     "key": "T",
///     "modifiers": ["cmd", "shift"],
///     "group": "我的命令",
///     "appId": "com.apple.Terminal"
///   }
/// ]
public enum CustomShortcutsParser {
    private struct Entry: Decodable {
        let title: String
        let key: String
        let modifiers: [String]?
        let group: String?
        let appId: String?
    }

    public static func parse(_ data: Data) -> [ShortcutItem] {
        guard let entries = try? JSONDecoder().decode([Entry].self, from: data) else { return [] }
        return entries.compactMap { entry in
            guard !entry.title.isEmpty, !entry.key.isEmpty else { return nil }
            var modifiers: ShortcutModifiers = []
            for name in entry.modifiers ?? [] {
                switch name.lowercased() {
                case "cmd", "command": modifiers.insert(.command)
                case "alt", "option": modifiers.insert(.option)
                case "ctrl", "control": modifiers.insert(.control)
                case "shift": modifiers.insert(.shift)
                default: break
                }
            }
            var display = entry.key
            var virtualKey: Int?
            if let special = GlyphMap.specialKey(named: entry.key) {
                display = special.symbol
                virtualKey = special.virtualKey
            } else if let first = entry.key.first {
                virtualKey = GlyphMap.virtualKey(forCharacter: first)
            }
            return ShortcutItem(
                title: entry.title,
                key: display,
                modifiers: modifiers,
                group: entry.group ?? "自定义",
                path: [entry.group ?? "自定义"],
                isEnabled: true,
                virtualKey: virtualKey
            )
        }
    }

    /// 生成示例文件内容
    public static func sampleJSON() -> String {
        """
        [
          {
            "title": "打开终端",
            "key": "T",
            "modifiers": ["cmd", "shift"],
            "group": "我的命令"
          }
        ]
        """
    }
}
