import XCTest
@testable import ShortKeyCore

final class ShortcutModelTests: XCTestCase {
    func testAXModifiersParsing() {
        XCTAssertEqual(ShortcutModifiers.fromAXModifiers(0), [.command])
        XCTAssertEqual(ShortcutModifiers.fromAXModifiers(1), [.shift, .command])
        XCTAssertEqual(ShortcutModifiers.fromAXModifiers(2), [.option, .command])
        XCTAssertEqual(ShortcutModifiers.fromAXModifiers(4), [.control, .command])
        XCTAssertEqual(ShortcutModifiers.fromAXModifiers(3), [.shift, .option, .command])
        // 1<<3 = 无 ⌘
        XCTAssertEqual(ShortcutModifiers.fromAXModifiers(8), [])
        XCTAssertEqual(ShortcutModifiers.fromAXModifiers(9), [.shift])
    }

    func testSymbolsOrder() {
        // macOS 惯例：⌃ ⌥ ⇧ ⌘
        XCTAssertEqual(
            ShortcutModifiers.fromAXModifiers(1 | 2 | 4).symbols,
            "⌃⌥⇧⌘"
        )
        XCTAssertEqual(ShortcutModifiers.fromAXModifiers(0).symbols, "⌘")
    }

    func testOrderedSymbolsForColorCoding() {
        // UI 逐类别着色依赖的顺序符号（⌃ ⌥ ⇧ ⌘）
        XCTAssertEqual(
            ShortcutModifiers.fromAXModifiers(1 | 2 | 4).orderedSymbols,
            ["⌃", "⌥", "⇧", "⌘"]
        )
        let shiftCommand: ShortcutModifiers = [.shift, .command]
        XCTAssertEqual(shiftCommand.orderedSymbols, ["⇧", "⌘"])
        XCTAssertEqual(ShortcutModifiers().orderedSymbols, [])
    }

    func testItemIDIsStable() {
        let a = ShortcutItem(
            title: "新建标签页", key: "T",
            modifiers: [.command], group: "文件", path: ["文件"]
        )
        let b = ShortcutItem(
            title: "新建标签页", key: "T",
            modifiers: [.command], group: "文件", path: ["文件"]
        )
        XCTAssertEqual(a.id, b.id)
        XCTAssertEqual(a.id, "文件\u{1F}新建标签页\u{1F}⌘T")
    }

    func testGlyphMap() {
        XCTAssertEqual(GlyphMap.name(forVirtualKey: 122), "F1")
        XCTAssertEqual(GlyphMap.name(forVirtualKey: 123), "←")
        XCTAssertEqual(GlyphMap.name(forVirtualKey: 51), "⌫")
        XCTAssertNil(GlyphMap.name(forVirtualKey: 65_300))
    }
}
