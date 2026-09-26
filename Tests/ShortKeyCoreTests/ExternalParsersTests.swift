import XCTest
@testable import ShortKeyCore

final class ExternalParsersTests: XCTestCase {
    func testSkhdParsing() {
        let text = """
        # 注释行
        cmd + shift - r : brew services restart skhd
        ctrl - return : open -a Terminal
        hyper - space : yabai -m toggle space
        cmd - f5 : displayplacer list
        """
        let items = SkhdParser.parse(text)
        XCTAssertEqual(items.count, 4)

        XCTAssertEqual(items[0].modifiers, [.shift, .command])
        XCTAssertEqual(items[0].key, "R")
        XCTAssertEqual(items[0].group, "skhd")

        XCTAssertEqual(items[1].modifiers, [.control])
        XCTAssertEqual(items[1].key, "↩")
        XCTAssertEqual(items[1].virtualKey, 36)

        XCTAssertEqual(items[2].modifiers, [.command, .option, .control, .shift])

        XCTAssertEqual(items[3].key, "F5")
        XCTAssertEqual(items[3].virtualKey, 96)
    }

    func testSkhdIgnoresInvalidLines() {
        let items = SkhdParser.parse("没有分隔符\n\n# 注释\n: 没有键\n")
        XCTAssertTrue(items.isEmpty)
    }

    func testCustomShortcutsParsing() {
        let json = """
        [
          {"title": "打开终端", "key": "T", "modifiers": ["cmd", "shift"], "group": "我的命令"},
          {"title": "锁定", "key": "space", "modifiers": ["ctrl"], "appId": "com.apple.finder"}
        ]
        """.data(using: .utf8)!
        let items = CustomShortcutsParser.parse(json)
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].group, "我的命令")
        XCTAssertEqual(items[0].modifiers, [.shift, .command])
        XCTAssertEqual(items[1].key, "␣")
        XCTAssertEqual(items[1].virtualKey, 49)
        XCTAssertEqual(items[1].modifiers, [.control])
    }

    func testSpecialKeyNames() {
        XCTAssertEqual(GlyphMap.specialKey(named: "forwarddelete")?.virtualKey, 117)
        XCTAssertEqual(GlyphMap.specialKey(named: "f12")?.virtualKey, 111)
        XCTAssertNil(GlyphMap.specialKey(named: "notakey"))
    }
}
