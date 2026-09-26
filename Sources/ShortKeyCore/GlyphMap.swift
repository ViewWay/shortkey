import Foundation

/// 虚拟键码 → 显示符号（HIToolbox kVK_ 常量子集，覆盖菜单里常见的功能键）。
/// 菜单项的按键优先取 AXMenuItemCmdChar，无字符时（F 键、方向键等）查此表。
public enum GlyphMap {
    public static let virtualKeyNames: [Int: String] = [
        // F 键
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
        105: "F13", 107: "F14", 113: "F15", 106: "F16", 64: "F17", 79: "F18",
        80: "F19", 90: "F20",
        // 编辑键
        51: "⌫", 117: "⌦", 53: "⎋", 36: "↩", 76: "⌅", 48: "⇥", 49: "␣",
        // 方向 / 翻页
        123: "←", 124: "→", 125: "↓", 126: "↑",
        115: "↖", 119: "↘", 116: "⇞", 121: "⇟", 114: "Help",
    ]

    public static func name(forVirtualKey keyCode: Int) -> String? {
        virtualKeyNames[keyCode]
    }

    /// ANSI 布局：字符 → 虚拟键码（合成按键执行系统/skhd/自定义热键时用）
    public static let charKeyCodes: [Character: Int] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9,
        "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17,
        "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "=": 24, "9": 25, "7": 26,
        "-": 27, "8": 28, "0": 29, "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35,
        "l": 37, "j": 38, "'": 39, "k": 40, ";": 41, "\\": 42, ",": 44, "/": 45, ".": 46,
        "`": 50, " ": 49,
    ]

    public static func virtualKey(forCharacter c: Character) -> Int? {
        let lower = c.lowercased().first ?? c
        return charKeyCodes[lower]
    }

    /// 特殊键名 → (显示符号, 虚拟键码)。skhd / 自定义快捷键的键名解析用。
    public static func specialKey(named name: String) -> (symbol: String, virtualKey: Int?)? {
        switch name.lowercased() {
        case "return", "enter": return ("↩", 36)
        case "space", "spacebar": return ("␣", 49)
        case "esc", "escape": return ("⎋", 53)
        case "tab": return ("⇥", 48)
        case "delete", "backspace": return ("⌫", 51)
        case "forwarddelete": return ("⌦", 117)
        case "up": return ("↑", 126)
        case "down": return ("↓", 125)
        case "left": return ("←", 123)
        case "right": return ("→", 124)
        case "home": return ("↖", 115)
        case "end": return ("↘", 119)
        case "pageup": return ("⇞", 116)
        case "pagedown": return ("⇟", 121)
        default:
            if name.lowercased().hasPrefix("f"),
               let number = Int(name.lowercased().dropFirst()), (1...20).contains(number) {
                let codes = [122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111, 105, 107, 113, 106, 64, 79, 80, 90]
                return ("F\(number)", codes[number - 1])
            }
            return nil
        }
    }
}
