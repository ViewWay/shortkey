import Foundation
import ShortKeyCore

/// 读取 com.apple.symbolichotkeys 中用户自定义过的系统热键，
/// 覆盖静态表里的默认值（defaults 只存“改过”的项，未改的保留默认）。
enum SystemHotKeysReader {
    /// 高置信度的符号 ID → 我们静态表条目标题 的映射
    private static let idTitles: [(id: Int, title: String)] = [
        (28, "拍摄全屏幕照片"),
        (29, "拷贝全屏幕到剪贴板"),
        (30, "拍摄选定区域照片"),
        (31, "拷贝选定区域到剪贴板"),
        (32, "调度中心"),
        (33, "当前应用的所有窗口"),
        (34, "显示桌面"),
    ]

    static func mergedSystemItems() -> [ShortcutItem] {
        var items = SystemShortcuts.items
        guard let raw = CFPreferencesCopyAppValue("AppleSymbolicHotKeys" as CFString, "com.apple.symbolichotkeys" as CFString),
              let dict = raw as? [String: Any] else {
            return items
        }

        for (id, title) in idTitles {
            guard let entry = dict[String(id)] as? [String: Any],
                  let value = entry["value"] as? [String: Any],
                  (entry["enabled"] as? Int ?? 1) != 0,
                  let keycode = value["parameter1"] as? Int,
                  let mask = value["parameter2"] as? Int else { continue }

            var modifiers: ShortcutModifiers = []
            // 经验位定义：1<<16 shift, 1<<17 option, 1<<18 control, 1<<19 command
            if mask & (1 << 16) != 0 { modifiers.insert(.shift) }
            if mask & (1 << 17) != 0 { modifiers.insert(.option) }
            if mask & (1 << 18) != 0 { modifiers.insert(.control) }
            if mask & (1 << 19) != 0 { modifiers.insert(.command) }

            let key = GlyphMap.name(forVirtualKey: keycode)
                ?? GlyphMap.charKeyCodes.first(where: { $0.value == keycode })?.key.uppercased()
                ?? String(keycode)

            if let index = items.firstIndex(where: { $0.title == title }) {
                items[index].key = key
                items[index].modifiers = modifiers
                items[index].virtualKey = keycode
            }
        }
        return items
    }
}
