import Foundation

/// macOS 系统级快捷键静态表（KeyCue 的 System 区）。
/// 收录全系统生效、与具体应用无关的常用热键。
/// 特殊键（Space/方向键/Esc/F 键等）带虚拟键码，供浮层内「按下即执行」匹配。
public enum SystemShortcuts {
    public static let items: [ShortcutItem] = [
        // 截屏
        ShortcutItem(title: "拍摄全屏幕照片", key: "3", modifiers: [.shift, .command], group: "截屏", path: ["截屏"]),
        ShortcutItem(title: "拍摄选定区域照片", key: "4", modifiers: [.shift, .command], group: "截屏", path: ["截屏"]),
        ShortcutItem(title: "截屏与录屏选项", key: "5", modifiers: [.shift, .command], group: "截屏", path: ["截屏"]),
        ShortcutItem(title: "拷贝全屏幕到剪贴板", key: "3", modifiers: [.control, .shift, .command], group: "截屏", path: ["截屏"]),
        ShortcutItem(title: "拷贝选定区域到剪贴板", key: "4", modifiers: [.control, .shift, .command], group: "截屏", path: ["截屏"]),
        // Spotlight 与搜索
        ShortcutItem(title: "Spotlight 搜索", key: "␣", modifiers: [.command], group: "Spotlight", path: ["Spotlight"], virtualKey: 49),
        ShortcutItem(title: "Finder 搜索窗口", key: "␣", modifiers: [.option, .command], group: "Spotlight", path: ["Spotlight"], virtualKey: 49),
        // 系统
        ShortcutItem(title: "锁定屏幕", key: "Q", modifiers: [.control, .command], group: "系统", path: ["系统"]),
        ShortcutItem(title: "登出当前用户", key: "Q", modifiers: [.shift, .command], group: "系统", path: ["系统"]),
        ShortcutItem(title: "强制退出应用", key: "⎋", modifiers: [.option, .command], group: "系统", path: ["系统"], virtualKey: 53),
        ShortcutItem(title: "查词 / 词典", key: "D", modifiers: [.control, .command], group: "系统", path: ["系统"]),
        // 窗口与应用
        ShortcutItem(title: "隐藏当前应用窗口", key: "H", modifiers: [.command], group: "窗口与应用", path: ["窗口与应用"]),
        ShortcutItem(title: "隐藏其他应用窗口", key: "H", modifiers: [.option, .command], group: "窗口与应用", path: ["窗口与应用"]),
        ShortcutItem(title: "最小化窗口", key: "M", modifiers: [.command], group: "窗口与应用", path: ["窗口与应用"]),
        ShortcutItem(title: "关闭窗口", key: "W", modifiers: [.command], group: "窗口与应用", path: ["窗口与应用"]),
        ShortcutItem(title: "关闭全部窗口", key: "W", modifiers: [.option, .command], group: "窗口与应用", path: ["窗口与应用"]),
        ShortcutItem(title: "退出应用", key: "Q", modifiers: [.command], group: "窗口与应用", path: ["窗口与应用"]),
        ShortcutItem(title: "进入全屏", key: "F", modifiers: [.control, .command], group: "窗口与应用", path: ["窗口与应用"]),
        ShortcutItem(title: "切换同应用多窗口", key: "`", modifiers: [.command], group: "窗口与应用", path: ["窗口与应用"], virtualKey: 50),
        ShortcutItem(title: "切换应用", key: "⇥", modifiers: [.command], group: "窗口与应用", path: ["窗口与应用"], virtualKey: 48),
        ShortcutItem(title: "打开应用设置", key: ",", modifiers: [.command], group: "窗口与应用", path: ["窗口与应用"]),
        // 调度中心与空间
        ShortcutItem(title: "调度中心", key: "↑", modifiers: [.control], group: "调度中心", path: ["调度中心"], virtualKey: 126),
        ShortcutItem(title: "当前应用的所有窗口", key: "↓", modifiers: [.control], group: "调度中心", path: ["调度中心"], virtualKey: 125),
        ShortcutItem(title: "切换到左侧空间", key: "←", modifiers: [.control], group: "调度中心", path: ["调度中心"], virtualKey: 123),
        ShortcutItem(title: "切换到右侧空间", key: "→", modifiers: [.control], group: "调度中心", path: ["调度中心"], virtualKey: 124),
        ShortcutItem(title: "显示桌面", key: "F11", modifiers: [], group: "调度中心", path: ["调度中心"], virtualKey: 103),
        // 输入与字符
        ShortcutItem(title: "切换输入源", key: "␣", modifiers: [.control], group: "输入", path: ["输入"], virtualKey: 49),
        ShortcutItem(title: "字符表情面板", key: "␣", modifiers: [.control, .command], group: "输入", path: ["输入"], virtualKey: 49),
    ]
}
