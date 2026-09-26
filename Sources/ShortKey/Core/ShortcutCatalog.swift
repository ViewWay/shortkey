import Foundation
import ShortKeyCore

/// 系统侧快捷键目录：静态表 + 动态覆盖（用户改过系统快捷键时以实际为准）
@MainActor
enum ShortcutCatalog {
    /// macOS 系统热键（启动时经 SystemHotKeysReader 做动态覆盖）
    static private(set) var systemItems: [ShortcutItem] = SystemShortcuts.items
    /// 触控板 / 鼠标手势（纯展示，不可执行）
    static let gestureItems: [ShortcutItem] = [
        ShortcutItem(title: "调度中心", key: "三指上扫", modifiers: [], group: "触控板手势", path: ["触控板手势"]),
        ShortcutItem(title: "应用窗口", key: "三指下扫", modifiers: [], group: "触控板手势", path: ["触控板手势"]),
        ShortcutItem(title: "全屏应用之间切换", key: "三指左右扫", modifiers: [], group: "触控板手势", path: ["触控板手势"]),
        ShortcutItem(title: "显示桌面", key: "拇指+三指张开", modifiers: [], group: "触控板手势", path: ["触控板手势"]),
        ShortcutItem(title: "启动台", key: "捏拢", modifiers: [], group: "触控板手势", path: ["触控板手势"]),
        ShortcutItem(title: "通知中心", key: "双指从右缘轻扫", modifiers: [], group: "触控板手势", path: ["触控板手势"]),
        ShortcutItem(title: "查询数据检测词", key: "三指轻点", modifiers: [], group: "触控板手势", path: ["触控板手势"]),
        ShortcutItem(title: "页面缩放", key: "双指捏合", modifiers: [], group: "触控板手势", path: ["触控板手势"]),
        ShortcutItem(title: "网页后退 / 前进", key: "双指左右扫", modifiers: [], group: "触控板手势", path: ["触控板手势"]),
        ShortcutItem(title: "智能缩放", key: "双指双击", modifiers: [], group: "触控板手势", path: ["触控板手势"]),
    ]

    /// 启动时调用：用系统实际配置覆盖默认值
    static func refresh() {
        systemItems = SystemHotKeysReader.mergedSystemItems()
    }
}
