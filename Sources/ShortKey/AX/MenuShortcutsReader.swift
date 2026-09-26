import ApplicationServices
import Foundation
import ShortKeyCore

/// 一次菜单扫描的结果：条目 + 可执行元素表（点击/回车执行用）
struct MenuScan: @unchecked Sendable {
    let items: [ShortcutItem]
    /// 条目 id → 菜单项元素（AXPress 执行用）
    let elements: [String: AXUIElement]
}

/// 通过 Accessibility API 读取前台应用菜单栏中的全部快捷键
enum MenuShortcutsReader {
    /// 递归深度上限，防异常 AX 树
    private static let maxDepth = 8

    static func read(pid: pid_t) -> [ShortcutItem] {
        scan(pid: pid).items
    }

    static func scan(pid: pid_t) -> MenuScan {
        let appElement = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(appElement, 3.0)

        guard let menuBar = element(appElement, kAXMenuBarAttribute) else {
            return MenuScan(items: [], elements: [:])
        }
        guard let topMenus = children(menuBar) else {
            return MenuScan(items: [], elements: [:])
        }

        var items: [ShortcutItem] = []
        var elements: [String: AXUIElement] = [:]
        var seen = Set<String>()
        for menu in topMenus {
            let group = string(menu, kAXTitleAttribute)
                ?? string(menu, kAXDescriptionAttribute)
                ?? "菜单"
            collect(from: menu, group: group, path: [group], into: &items, elements: &elements, seen: &seen, depth: 0)
        }
        return MenuScan(items: items, elements: elements)
    }

    private static func collect(
        from parent: AXUIElement,
        group: String,
        path: [String],
        into items: inout [ShortcutItem],
        elements: inout [String: AXUIElement],
        seen: inout Set<String>,
        depth: Int
    ) {
        guard depth < maxDepth else { return }
        for child in children(parent) ?? [] {
            switch string(child, kAXRoleAttribute) ?? "" {
            case "AXMenu":
                let title = string(child, kAXTitleAttribute) ?? ""
                collect(from: child, group: group, path: path + [title], into: &items, elements: &elements, seen: &seen, depth: depth + 1)
            case "AXMenuItem":
                if let item = shortcutItem(from: child, group: group, path: path) {
                    if seen.insert(item.id).inserted {
                        items.append(item)
                        elements[item.id] = child
                    }
                }
                // 部分应用把子菜单挂在菜单条目的 children 上
                let itemTitle = string(child, kAXTitleAttribute) ?? ""
                for grandchild in children(child) ?? [] {
                    if string(grandchild, kAXRoleAttribute) == "AXMenu" {
                        collect(from: grandchild, group: group, path: path + [itemTitle], into: &items, elements: &elements, seen: &seen, depth: depth + 1)
                    }
                }
            default:
                break
            }
        }
    }

    private static func shortcutItem(from element: AXUIElement, group: String, path: [String]) -> ShortcutItem? {
        let title = string(element, kAXTitleAttribute)
            ?? string(element, kAXDescriptionAttribute)
            ?? "（无标题）"

        let char = string(element, kAXMenuItemCmdCharAttribute) ?? ""
        let virtualKey = number(element, kAXMenuItemCmdVirtualKeyAttribute)
        let modifiersValue = number(element, kAXMenuItemCmdModifiersAttribute) ?? 0

        var key = ""
        if !char.isEmpty {
            key = char == " " ? "␣" : char.uppercased()
        } else if let vk = virtualKey, let name = GlyphMap.name(forVirtualKey: vk) {
            key = name
        } else {
            return nil // 无快捷键（或仅有未知 glyph），跳过
        }

        return ShortcutItem(
            title: title,
            key: key,
            modifiers: ShortcutModifiers.fromAXModifiers(modifiersValue),
            group: group,
            path: path,
            isEnabled: bool(element, kAXEnabledAttribute) ?? true,
            virtualKey: virtualKey
        )
    }

    // MARK: - AX 属性辅助

    /// 读取属性原始值；AX 常量在 Swift 中导入为 String
    private static func copyValue(_ parent: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(parent, attribute as CFString, &value)
        return result == .success ? value : nil
    }

    private static func element(_ parent: AXUIElement, _ attribute: String) -> AXUIElement? {
        guard let raw = copyValue(parent, attribute) else { return nil }
        return unsafeBitCast(raw, to: AXUIElement.self)
    }

    private static func children(_ parent: AXUIElement) -> [AXUIElement]? {
        guard let raw = copyValue(parent, kAXChildrenAttribute) else { return nil }
        return (raw as? [AnyObject])?.map { unsafeBitCast($0, to: AXUIElement.self) }
    }

    private static func string(_ parent: AXUIElement, _ attribute: String) -> String? {
        copyValue(parent, attribute) as? String
    }

    private static func number(_ parent: AXUIElement, _ attribute: String) -> Int? {
        (copyValue(parent, attribute) as? NSNumber)?.intValue
    }

    private static func bool(_ parent: AXUIElement, _ attribute: String) -> Bool? {
        (copyValue(parent, attribute) as? NSNumber)?.boolValue
    }
}
