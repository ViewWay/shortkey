import ApplicationServices
import Foundation

/// 持有本次扫描到的菜单元素，支持用 AXPress 直接执行菜单命令（点击行 / 回车）。
/// 元素随扫描产生，应用切换后重新扫描即失效，无需长期管理生命周期。
@MainActor
final class MenuPerformer {
    private let elements: [String: AXUIElement]

    init(elements: [String: AXUIElement]) {
        self.elements = elements
    }

    var isEmpty: Bool { elements.isEmpty }

    /// 执行菜单命令；返回是否成功派发
    func perform(_ id: String) -> Bool {
        guard let element = elements[id] else { return false }
        return AXUIElementPerformAction(element, kAXPressAction as CFString) == .success
    }
}
