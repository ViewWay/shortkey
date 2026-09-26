import Foundation
import ShortKeyCore

/// 外部快捷键来源装载：skhd 配置 / 自定义 JSON / Jitouch 配置嗅探
enum ExternalShortcuts {
    static func loadSkhd() -> [ShortcutItem] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates = [
            home.appendingPathComponent(".config/skhd/skhdrc"),
            home.appendingPathComponent(".skhdrc"),
        ]
        for url in candidates where FileManager.default.fileExists(atPath: url.path) {
            if let text = try? String(contentsOf: url, encoding: .utf8) {
                return SkhdParser.parse(text)
            }
        }
        return []
    }

    static func loadCustom() -> [ShortcutItem] {
        let url = Self.customFileURL
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else { return [] }
        return CustomShortcutsParser.parse(data)
    }

    static var customFileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ShortKey", isDirectory: true)
        return base.appendingPathComponent("custom.json")
    }

    /// 首次运行时写一份示例文件，方便用户照着改
    static func ensureCustomSample() {
        let url = customFileURL
        guard !FileManager.default.fileExists(atPath: url.path) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? CustomShortcutsParser.sampleJSON().write(to: url, atomically: true, encoding: .utf8)
    }

    /// Jitouch2 配置嗅探：格式未公开文档化，尽力解析；失败则返回空。
    static func loadJitouch() -> [ShortcutItem] {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences/com.charliemonroe.Jitouch.plist")
        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return []
        }
        var items: [ShortcutItem] = []
        func walk(_ value: Any) {
            if let dict = value as? [String: Any] {
                if let name = dict["name"] as? String,
                   let shortcut = dict["shortcut"] as? String, !shortcut.isEmpty {
                    items.append(ShortcutItem(
                        title: name,
                        key: shortcut,
                        modifiers: [],
                        group: "Jitouch",
                        path: ["Jitouch"]
                    ))
                }
                for child in dict.values { walk(child) }
            } else if let array = value as? [Any] {
                for child in array { walk(child) }
            }
        }
        walk(plist)
        return items
    }
}
