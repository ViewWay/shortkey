import Foundation

/// 解析 skhd 配置（~/.config/skhd/skhdrc）。
/// 行格式：`cmd + shift - r : brew services restart skhd`
public enum SkhdParser {
    public static func parse(_ text: String) -> [ShortcutItem] {
        var items: [ShortcutItem] = []
        var seen = Set<String>()

        for rawLine in text.split(separator: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }
            guard let colonRange = line.range(of: ":") else { continue }

            let command = String(line[colonRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            guard !command.isEmpty else { continue }

            let spec = String(line[..<colonRange.lowerBound])
            guard let dashRange = spec.range(of: "-") else { continue }
            let modsPart = String(spec[..<dashRange.lowerBound])
            let keyPart = String(spec[dashRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            guard !keyPart.isEmpty else { continue }

            var modifiers: ShortcutModifiers = []
            for token in modsPart.split(separator: "+") {
                switch token.trimmingCharacters(in: .whitespaces).lowercased() {
                case "cmd", "command": modifiers.insert(.command)
                case "alt", "option": modifiers.insert(.option)
                case "ctrl", "control": modifiers.insert(.control)
                case "shift": modifiers.insert(.shift)
                case "hyper": modifiers.formUnion([.command, .option, .control, .shift])
                case "meh": modifiers.formUnion([.command, .option, .control])
                default: break
                }
            }

            // 键名 → 显示符号 + 虚拟键码
            var display: String
            var virtualKey: Int?
            if let special = GlyphMap.specialKey(named: keyPart) {
                display = special.symbol
                virtualKey = special.virtualKey
            } else {
                display = keyPart.uppercased()
                virtualKey = GlyphMap.virtualKey(forCharacter: keyPart.first ?? " ")
            }

            let title = command
            let id = "skhd\u{1F}\(title)\u{1F}\(modifiers.symbols)\(display)"
            guard seen.insert(id).inserted else { continue }

            items.append(ShortcutItem(
                title: title,
                key: display,
                modifiers: modifiers,
                group: "skhd",
                path: ["skhd"],
                isEnabled: true,
                virtualKey: virtualKey
            ))
        }
        return items
    }
}
