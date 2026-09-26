import XCTest
@testable import ShortKeyCore

final class MarkdownBuilderTests: XCTestCase {
    func testBuildContainsGroupsAndRows() {
        let items = [
            ShortcutItem(title: "新建标签页", key: "T", modifiers: [.command], group: "文件", path: ["文件"]),
            ShortcutItem(title: "复制", key: "C", modifiers: [.command], group: "编辑", path: ["编辑"]),
        ]
        let doc = MarkdownBuilder.build(
            appName: "测试应用",
            items: items,
            favorites: [items[1].id],
            date: Date(timeIntervalSince1970: 0)
        )
        XCTAssertTrue(doc.hasPrefix("# 测试应用 快捷键"))
        XCTAssertTrue(doc.contains("## 文件"))
        XCTAssertTrue(doc.contains("| ⌘T | 新建标签页 |"))
        XCTAssertTrue(doc.contains("| ★ ⌘C | 复制 |"))
        XCTAssertTrue(doc.contains("共 2 个快捷键"))
    }

    func testPipeCharacterEscaped() {
        let items = [
            ShortcutItem(title: "a|b", key: "K", modifiers: [], group: "G", path: ["G"]),
        ]
        let doc = MarkdownBuilder.build(appName: "App", items: items)
        XCTAssertTrue(doc.contains("a\\|b"))
    }
}
