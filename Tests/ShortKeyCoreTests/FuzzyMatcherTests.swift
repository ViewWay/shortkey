import XCTest
@testable import ShortKeyCore

final class FuzzyMatcherTests: XCTestCase {
    func testSubsequenceMatch() {
        let m = FuzzyMatcher.match(query: "sv", target: "Save")
        XCTAssertNotNil(m)
        XCTAssertEqual(m?.indices, [0, 2])
    }

    func testCaseInsensitive() {
        XCTAssertNotNil(FuzzyMatcher.match(query: "SAVE", target: "save"))
    }

    func testNoMatch() {
        XCTAssertNil(FuzzyMatcher.match(query: "zz", target: "Save"))
        XCTAssertNil(FuzzyMatcher.match(query: "", target: "Save"))
        XCTAssertNil(FuzzyMatcher.match(query: "saves", target: "Save"))
    }

    func testConsecutiveBeatsSpread() {
        let consecutive = FuzzyMatcher.match(query: "fil", target: "File Name")!
        let spread = FuzzyMatcher.match(query: "fne", target: "File Name")!
        XCTAssertGreaterThan(consecutive.score, spread.score)
    }

    func testChineseMatch() {
        XCTAssertNotNil(FuzzyMatcher.match(query: "文件", target: "文件"))
        XCTAssertNotNil(FuzzyMatcher.match(query: "文", target: "新建文件"))
        XCTAssertNil(FuzzyMatcher.match(query: "文件", target: "编辑"))
    }
}
